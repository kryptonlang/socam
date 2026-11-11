// core/gen.k — typed UI snippet generators for Objective-K apps.
//
// Milestone 2: `socam gen window|button|label ...` emits ready-to-paste
// Krypton AppKit snippets. Flags are parsed by the caller.

module gen

import "k:fsx"
import "k:sh"

func emitSnippet(target, flags) {
    if target == "window" { emitWindow(flags); emit "" }
    if target == "button" { emitButton(flags); emit "" }
    if target == "label"  { emitLabel(flags);  emit "" }
    emit target + " - unknown snippet target"
}

func _findFrom(s, needle, from) {
    let n = len(needle)
    let i = from
    let end = len(s) - n
    while i <= end {
        if substring(s, i, i + n) == needle { emit i }
        i += 1
    }
    emit 0 - 1
}

func flag(map, key, def) {
    let needle = "|" + key + "="
    let idx = indexOf(map, needle)
    if idx < 0 { emit def }
    let start = idx + len(needle)
    let end = _findFrom(map, "|", start)
    if end < 0 { emit substring(map, start, len(map)) }
    emit substring(map, start, end)
}

func emitWindow(f) {
    let title = flag(f, "title", "Dashboard")
    let w = flag(f, "w", "800")
    let h = flag(f, "h", "600")
    print("let pool = okAutoreleasePool()")
    print("let app = okApp()")
    print("let win = okWindow(app, \"" + title + "\", " + w + ", " + h + ")")
    print("okShow(win, app)")
    print("okRun(app)")
    print("okDrainPool(pool)")
}

func emitButton(f) {
    let label = flag(f, "label", "Button")
    let x = flag(f, "x", "50")
    let y = flag(f, "y", "100")
    let action = flag(f, "action", "onClick")
    print("// in your just run block, after okWindow is ready:")
    print("func " + action + "(sender) {")
    print("    print(\"" + label + " clicked\")")
    print("    emit 0")
    print("}")
    print("let btn = okButton(win, \"" + label + "\", " + x + ", " + y + ", 120, 28)")
    print("okOn(btn, \"" + action + "\", funcptr(" + action + "))")
}

func emitLabel(f) {
    let text = flag(f, "text", "Status: Ready")
    let x = flag(f, "x", "50")
    let y = flag(f, "y", "150")
    let w = flag(f, "w", "300")
    let h = flag(f, "h", "24")
    print("let lbl = okLabel(win, \"" + text + "\", " + x + ", " + y + ", " + w + ", " + h + ")")
}
