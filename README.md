# socam

**Smack Open-Code Assistance Mechanism** — a native macOS assistance CLI and bridge for the Krypton + SmackUI stack.

`socam` gives you a fast, local-only command line for working with `.k` sources, the krypton compiler pipeline, and the broader SmackUI toolkit. No network calls, no AI back-ends; everything runs against the toolchain you have on disk.

## Usage

```
socam                       Show this help
socam -h | --help           Show this help
socam version               Print version
socam explain <file.k>      Compile <file.k> to IR and print statistics
socam grep <pat> <file>     Matches lines in <file> (prefix match, no regex)
socam list [<dir>]          Enumerate .k files under <dir> (default: .)
socam gen <name>            Emit a starter module <name>.k
```

Environment variables:

```
KRYPTON_ROOT          Repo root override (first try)
KCC_FRONTEND          Absolute path to kcc-arm64 (wins over KRYPTON_ROOT)
```

Toolchain resolution order (first match wins):

1. `$KRYPTON_ROOT/compiler/macos_arm64/kcc-arm64`
2. `/usr/local/krypton/compiler/macos_arm64/kcc-arm64` (installed toolchain)
3. `<cwd>/compiler/macos_arm64/kcc-arm64` (running inside a krypton checkout)
4. `<cwd>/../krypton/compiler/macos_arm64/kcc-arm64` (sibling checkout)

## Build

```
KRYPTON_ROOT=/path/to/krypton  ./bootstrap/kcc_driver_macos_aarch64 bin/socam.k -o socam
```

## Layout

```
bin/socam.k          CLI dispatcher / argument parser
core/assistance.k    Bridge into the krypton compiler (read-IR, count FUNCs)
core/dispatch.k      Route names and shared context
tests/test_socam.k         Smoke tests (help, version, list, gen)
tests/test_socam_bridge.k  Mock bridge round-trip: dump | status | border | reload | quit
tests/fixtures/mock_bridge.k  Minimal socam/command bridge used by the round-trip test
```


## Milestones 6 and 10 (v0.6.0)

* `socam repl` — interactive IPC session talking to a running bridged app. One-shot form: `socam repl dump` (also `status`, `border`, `reload`, `quit`).
* `socam new app <Name> --bridge` — scaffolds a Krypton AppKit app with a runtime bridge listening on `socam/command` (via `NSDistributedNotificationCenter`). Commands: `dump`, `status`, `border`, `reload`, `quit`.
* `socam gen menu --title=… --items=…` — NSMenu + NSMenuItem stub with optional `--keys=…`.
* `socam gen statusbar --title=… --icon=… --menu=…` — NSStatusBar + NSStatusItem scaffold.

## Bridge state verification (proof of life)

Socam's REPL communicates through `NSDistributedNotificationCenter`; the bridged app registers to receive `socam/command` and writes / responds with `/tmp/socam.reply`. Round-trip verified on the new AppKit scaffold:

```
BridgeAppDemo running (pid <yours>)
$ socam repl dump
windows=1
$ socam repl border
border-on
$ socam repl status
windows=1
$ socam repl quit
quit
```

## Status

Actively scaffolding. Nothing here is stable, but everything listed above works
against a stock krypton build.
