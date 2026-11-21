# AppKit bridge findings — macOS arm64 Socam (kcc/kr native ObjC runtime)

Durable record of what was proven and what quirks exist, for parity into the Socam
AppKit adapter and the future linux_x86_64 Wayland adapter. Source of truth for
the working mechanics: `examples/socam_macos_smoke.k` (on-screen, rc=0) plus the
headless suites `tests/geometry_test.k` (35/35), `tests/view_test.k` (14/14),
`tests/scheduler_test.k` (27/27).

## 1. Toolchain setup (pin these, never drift)

- `KRYPTON_ROOT=/Users/t3m3d/Documents/GitHub/krypton` — export before every
  `kcc`/`kcc_driver` call. `/usr/bin/kcc` is Apple's unrelated Kerberos tool.
- Driver: `$KRYPTON_ROOT/bootstrap/kcc_driver_macos_aarch64`
- Frontend: `$KRYPTON_ROOT/compiler/macos_arm64/kcc-arm64` (emits arch-agnostic IR)
- Backend host: `$KRYPTON_ROOT/compiler/macos_arm64/macho_host` (native x86_64→arm64
  Mach-O emitter; no C/clang involved)

## 2. Regression fixed (working tree, uncommitted)

`dc7ba697` made `END` emit `SYS_exit(0)` for *every* function; `17742b93` then
"fixed" non-main `END` with `pop_x0()` + `ret`, but void functions leave the eval
stack balanced/empty, so `pop_x0` reads garbage and `ret()` jumps there → SIGBUS
(rc=138). Fix: non-main `END` = `add_sp(frame)` + `movz_w0_zero()` (clean w0=0
null-handle return) + `ldp fp,lr post16` + `ret` — **no pop**. `__main__` keeps
`SYS_exit(0)`. Matches pre-regression `c3a4df21` behavior.

File: `compiler/macos_arm64/macho_arm64_self.k`, `opTok == "END"` branch. Uncommitted
in working tree — ready to commit when you are.

## 3. Proven AppKit ABI patterns (from socam_macos_smoke.k)

All of these compile and run on macOS arm64 today:

### App lifecycle
```
let app = chocInit()                        // sharedApplication, activation policy
let win = chocWindow(app, title, w, h)      // NSWindow, mask 15 (titled|closable|mini|resizable)
chocShow(win, app)                          // makeKeyAndOrderFront:
chocRun(app)                                // [app run] — blocks until quit
chocQuit(app)                               // terminate:
```

### Views & flipped (y-down) container — matches Socam geometry contract
```
let cls = chocViewClassNew("Name")          // objc_allocateClassPair(NSView, name, 0)
chocClassAddMethod(cls, "isFlipped", funcptr(isFlipped), "c@:")
chocClassRegister(cls)                      // objc_registerClassPair
let v = chocCustomView(win, cls, x, y, w, h) // alloc/initWithFrame:, mask 18, addSubview
msg_1(v, "setWantsLayer:", 1)
let layer = msg(v, "layer")
msg_1(layer, "setBackgroundColor:", msg(chocRGB(r, g, b), "CGColor"))
```
- `isFlipped` returning 1 gives top-left origin y-down — identical to Socam's
  geometry contract (`geometry.k` top-left origin, +y down).
- Springs mask `AUTORESIZE_*` maps 1:1 to `NSAutoresizingMask` (`WidthSizable=2`,
  `MinYMargin=8`, etc.).

### Controls + actions (Krypton IMPs via funcptr)
```
chocOnClick(btn, funcptr(onClick))          // objk_dispatch: selector via synthetic NSObject class
// handler signature: func onClick(self, cmd, sender) { ... emit 0 }
```
- `cocoaSetAssoc(control, value)` / `cocoaGetAssoc(control)` — Obj-C associated
  objects keyed by stable `sel("kr.assoc")`; the closure-capture pattern used by
  `cocoa_hello.ks`.
- `chocWindowShouldClose(win, fnPtr)` / `chocWindowOnClose(win, fnPtr)` —
  lifecycle proxy pattern available (`_chocLifecycleClass`).

### Timers & event pump
```
chocTimer(target, "sel:", ms)               // NSTimer scheduledTimer...:repeats:
chocFinishLaunching(app)                    // finishLaunching + activateIgnoringOtherApps
chocPumpEvent(app) / chocPumpEvents(app)    // manual non-blocking event dispatch
```

### Text/fonts/color (existing primitives to reuse)
- `chocRGB(r, g, b)` — ints 0–255 (NOT floats; `colorWithRed:green:blue:alpha:`)
- `chocSystemWindowBg()`, `chocSystemText()`, `chocSystemSecondaryText()`, `chocSystemTextBg()`
- `chocMonoFont(size)` / `chocFontFamily(base, family)` / `chocSetFont(view, font)`
- `chocSetTextColor(view, color)`, `chocSetBg(view, color)`, `chocSetWindowBg(win, color)`
- `chocTextAttrs(font, color)` / `chocDrawText(str, x, y, w, h, attrs)` — for drawRect:

### Things verified NOT to do
- Do **not** use bare `min`/`max`/`abs` on macOS arm64 — the aarch64 backend has no
  handler; bare calls emit `BUILTIN max 2` with zero instructions → stack
  corruption → segfault. Use local `socamMin`/`socamMax` (defined in `geometry.k`).
- Do **not** use `&` as an operator — Krypton has none; use `k:bitwise` (`bitAnd`,
  `bitOr`, `bitXor`, `shiftLeft`, `shiftRight`, `bitTest`, …).
- Do **not** use decimal float literals (`0.09`) — Krypton ints only; pass 0–255
  ints to `chocRGB`/`msg_rgb` instead.

## 4. Implemented AppKit adapter — `socam/src/socam/appkit_adapter.k`

The adapter boundary is implemented and verified on-screen (`tests/appkit_smoke.k`, rc=0).
Call words (clean, no OS leakage):

```
// appkitWindow(title, w, h)
//     -> { app, win, sched, scene, rootIdx, viewReg, fcls }
//   Window close + resize handled automatically by an NSWindowDelegate:
//     - windowWillClose:  → schedCancel (teardown safety)
//     - windowDidResize:  → sceneResize on root view (springs respond)
//
// appkitAddBox(viewReg, scene, parentIdx, x, y, w, h, mask, color, tag)
//     -> { scene, viewIdx, nsView, viewReg }
// appkitAddTextField(viewReg, scene, parentIdx, x, y, w, h, tag)
//     -> { scene, viewIdx, nsView, textField, viewReg }
// appkitSetFrame(scene, viewReg, viewIdx, newFrame) -> scene
// appkitInvalidate(scene, sched, viewReg, viewIdx, localRect) -> { scene, sched }
// appkitRenderFrame(sched, scene, viewReg) -> sched   (one scheduler tick)
// appkitShow(app, win) / appkitRun(app) / appkitQuit(app)
// appkitTextFieldOnChange(textField, fnPtr)   // fnPtr: func handler(textField)
// appkitTextFieldValue(textField) / appkitSetTextFieldValue(textField, value)
//
// NSAutoresizingMask values (identical to socam AUTORESIZE_* bits):
//   MASK_FIXED = 0  MASK_FLEX_W = 2  MASK_FLEX_TOP = 8  MASK_FLEX_H = 16
```

Key design decisions:
- **Scene/scheduler are the source of truth** — AppKit is just the render target.
  `scene.dmg` is synced into `sched.pending` at the start of each `appkitRenderFrame`.
- **NSView registry** — parallel comma-list of NSView handles indexed by Socam view
  index (`_akRegSet`/`_akRegGet`). Krypton comma-lists can't hold structs, so this
  is the workaround.
- **Flipped container view** — `isFlipped` returns 1, giving top-left origin y-down,
  matching `geometry.k`'s contract exactly.
- **Window delegate** — single `SocamWindowDelegate` class handles both
  `windowWillClose:` (→ `schedCancel`) and `windowDidResize:` (→ `sceneResize`).
  Scene/scheduler/registry/rootIdx are stored as NSValue-boxed handles on the window
  via associated objects.
- **Text fields** — `NSTextField` with `controlTextDidChange:` delegate →
  `chocFieldOnChange` → Krypton IMP via funcptr. Handler signature: `func(textField)`.

## 5. Verification status

| Suite | Result | Target |
|-------|--------|--------|
| `tests/geometry_test.k` | 35/35 PASS, rc=0 | macOS arm64 pipeline |
| `tests/view_test.k` | 14/14 PASS, rc=0 | macOS arm64 pipeline |
| `tests/scheduler_test.k` | 27/27 PASS, rc=0 | macOS arm64 pipeline |
| `tests/appkit_smoke.k` | rc=0, on-screen window | macOS arm64 pipeline |
| `examples/socam_macos_smoke.k` | rc=0, on-screen window | macOS arm64 pipeline |
| `examples/cocoa_hello.ks` | rc=124 (window holds) | macOS arm64 pipeline |
| Linux x86_64 compile | not yet (no x86 metal/qemu) | pending Lima/kryptos VM |

## 6. Regression fixed (working tree, uncommitted)

`dc7ba697` made `END` emit `SYS_exit(0)` for *every* function; `17742b93` then
"fixed" non-main `END` with `pop_x0()` + `ret`, but void functions leave the eval
stack balanced/empty, so `pop_x0` reads garbage and `ret()` jumps there → SIGBUS
(rc=138). Fix: non-main `END` = `add_sp(frame)` + `movz_w0_zero()` (clean w0=0
null-handle return) + `ldp fp,lr post16` + `ret` — **no pop**. `__main__` keeps
`SYS_exit(0)`. Matches pre-regression `c3a4df21` behavior.

File: `compiler/macos_arm64/macho_arm64_self.k`, `opTok == "END"` branch. Uncommitted
in working tree — ready to commit when you are.

## 7. Toolchain setup (pin these, never drift)

- `KRYPTON_ROOT=/Users/t3m3d/Documents/GitHub/krypton` — export before every
  `kcc`/`kcc_driver` call. `/usr/bin/kcc` is Apple's unrelated Kerberos tool.
- Driver: `$KRYPTON_ROOT/bootstrap/kcc_driver_macos_aarch64`
- Frontend: `$KRYPTON_ROOT/compiler/macos_arm64/kcc-arm64` (emits arch-agnostic IR)
- Backend host: `$KRYPTON_ROOT/compiler/macos_arm64/macho_host` (native x86_64→arm64
  Mach-O emitter; no C/clang involved)

## 8. Proven AppKit ABI patterns

### Views & flipped (y-down) container — matches Socam geometry contract
```
let cls = chocViewClassNew("Name")          // objc_allocateClassPair(NSView, name, 0)
chocClassAddMethod(cls, "isFlipped", funcptr(isFlipped), "c@:")
chocClassRegister(cls)                      // objc_registerClassPair
let v = chocCustomView(win, cls, x, y, w, h) // alloc/initWithFrame:, mask 18, addSubview
msg_1(v, "setWantsLayer:", 1)
let layer = msg(v, "layer")
msg_1(layer, "setBackgroundColor:", msg(chocRGB(r, g, b), "CGColor"))
```
- `isFlipped` returning 1 gives top-left origin y-down — identical to Socam's
  geometry contract (`geometry.k` top-left origin, +y down).
- Springs mask `AUTORESIZE_*` maps 1:1 to `NSAutoresizingMask` (`WidthSizable=2`,
  `MinYMargin=8`, etc.).

### Controls + actions (Krypton IMPs via funcptr)
```
chocOnClick(btn, funcptr(onClick))          // objk_dispatch: selector via synthetic NSObject class
// handler signature: func onClick(self, cmd, sender) { ... emit 0 }
```
- `cocoaSetAssoc(control, value)` / `cocoaGetAssoc(control)` — Obj-C associated
  objects keyed by stable `sel("kr.assoc")`.
- `chocFieldOnChange(field, funcptr(handler))` — NSTextField change callback,
  handler signature: `func(textField)`.

### Text/fonts/color (existing primitives to reuse)
- `chocRGB(r, g, b)` — ints 0–255 (NOT floats)
- `chocSystemWindowBg()`, `chocSystemText()`, `chocSystemSecondaryText()`, `chocSystemTextBg()`
- `chocMonoFont(size)` / `chocFontFamily(base, family)` / `chocSetFont(view, font)`
- `chocSetTextColor(view, color)`, `chocSetBg(view, color)`, `chocSetWindowBg(win, color)`

### Things verified NOT to do
- Do **not** use bare `min`/`max`/`abs` on macOS arm64 — the aarch64 backend has no
  handler; bare calls emit `BUILTIN max 2` with zero instructions → stack
  corruption → segfault. Use local `socamMin`/`socamMax` (defined in `geometry.k`).
- Do **not** use `&` as an operator — Krypton has none; use `k:bitwise`.
- Do **not** use decimal float literals (`0.09`) — Krypton ints only; pass 0–255
  ints to `chocRGB`/`msg_rgb`.

## 9. Linux_x86_64 Wayland contract (design, no x86 metal needed)

From `design-frame-scheduler.md` — same scheduler, different adapter:

- Loop: `wl_display` dispatch + poll fds; per iteration dispatch events → fold
  damage via `schedAddDamage` → `if schedNeedsFrame: schedBeginFrame` → attach
  buffer, `wl_surface_damage_buffer` per snapshot rect × `wl_output` scale **at
  commit only** (logical → buffer pixels) → `wl_surface.commit` + `wl_surface.frame`
  callback → `schedEndFrame` → immediate next-iteration render if damage arrived
  in flight.
- `wl_surface_destroy` path calls `schedCancel` before freeing views/buffers.
- Buffer policy v0: double-buffered `wl_shm` ARGB8888 in-arena back buffer.

Input/event mapping to plan:
- `wl_pointer`/`wl_keyboard` → Socam responder chain (`viewHitTest` →
  `viewResponderChain`).
- `text-input-v3` (IME) on Linux ↔ `NSTextInputClient` on macOS — one unified
  text-input API behind the adapter.

## 10. Platform gating

No `#if target_os` in the compiler — gating works through imports:
`k:choc_macos` only exists on macOS, `k:choc_linux` on Linux. Shared core modules
(`geometry.k`, `layout.k`, `dirtyrect.k`, `view.k`, `scheduler.k`) have no platform
imports and compile identically on both targets. Platform-specific adapters
(`appkit_adapter.k` on macOS, Wayland adapter on Linux) fail to compile on the wrong
platform because their imports don't exist — this is the gating mechanism.

Nothing is committed yet — the END fix, `appkit_adapter.k`, and this doc are
working-tree changes; commits are yours to make.
