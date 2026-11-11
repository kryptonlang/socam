// core/gen.k — typed UI snippet generators for Objective-K apps.
//
// Milestone 2: `socam gen window|button|label ...` emits ready-to-paste
// Krypton AppKit snippets. Flags are parsed by the caller.

module gen

import "k:fsx"
import "k:sh"

func emitSnippet(target, flags) {
    if target == "window" { emitWindow(flags); emit "" }
    else if target == "button" { emitButton(flags); emit "" }
    else if target == "label"  { emitLabel(flags);  emit "" }
    else if target == "stack"  { emitStack(flags);  emit "" }
    else if target == "split"  { emitSplit(flags);  emit "" }
    else if target == "table"  { emitTable(flags);  emit "" }
    else if target == "delegate" { emitDelegate(flags); emit "" }
    else { printErr("socam gen: unknown target '" + target + "'\n"); exit("1") }
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

func _layoutOrientationAlType(axis) {
    if axis == "horizontal" || axis == "h" { emit "1" }
    emit "0"
}

func _layoutAttribute(align) {
    if align == "left" { emit "1" }   // NSLayoutAttributeLeft
    if align == "right" { emit "2" }  // NSLayoutAttributeRight
    if align == "leading" { emit "5" } // NSLayoutAttributeLeading
    if align == "trailing" { emit "6" } // NSLayoutAttributeTrailing
    if align == "centerX" || align == "center" { emit "9" } // NSLayoutAttributeCenterX
    if align == "top" { emit "3" }    // NSLayoutAttributeTop
    if align == "bottom" { emit "4" } // NSLayoutAttributeBottom
    if align == "centerY" { emit "10" } // NSLayoutAttributeCenterY
    emit "9"
}

func _distributionConst(distrib) {
    if distrib == "equalSpacing" { emit "3" }
    if distrib == "equalCentering" { emit "4" }
    if distrib == "fillEqually" { emit "1" }
    if distrib == "fillProportionally" { emit "2" }
    emit "0" // fill
}

func emitStack(f) {
    let axis = flag(f, "axis", "vertical")
    let spacing = flag(f, "spacing", "12")
    let alignment = flag(f, "alignment", "centerX")
    let distrib = flag(f, "distribution", "fill")
    print("// NSStackView (" + axis + ", spacing " + spacing + ")")
    print("let sv = msg(cls(\"NSStackView\"), \"new\")")
    print("msg_1(sv, \"setOrientation:\", " + _layoutOrientationAlType(axis) + ")")
    print("msg_1(sv, \"setSpacing:\", " + spacing + ")")
    print("msg_1(sv, \"setAlignment:\", " + _layoutAttribute(alignment) + ")")
    print("msg_1(sv, \"setDistribution:\", " + _distributionConst(distrib) + ")")
    print("// addArrangedSubview for each child in display order:")
    print("msg_1(sv, \"addArrangedSubview:\", childView)")
    print("_addToContentView(win, sv)")
}

func emitSplit(f) {
    let x = toInt(flag(f, "x", "0"))
    let y = toInt(flag(f, "y", "0"))
    let w = toInt(flag(f, "w", "460"))
    let h = toInt(flag(f, "h", "240"))
    let sidebarW = toInt(flag(f, "sidebar", "150"))
    print("// NSSplitView — sidebar/content master layout")
    print("let split = okSplit(win, " + x + ", " + y + ", " + w + ", " + h + ")")
    print("let sidebar = okLabel(win, \"Sidebar\", " + x + ", " + y + ", " + sidebarW + ", " + h + ")")
    print("let content = okLabel(win, \"Content\", " + (x + sidebarW) + ", " + y + ", " + (w - sidebarW) + ", " + h + ")")
    print("okSplitAdd(split, sidebar)")
    print("okSplitAdd(split, content)")
}

func emitTable(f) {
    let columns = flag(f, "columns", "Name,Status,Date")
    let x = flag(f, "x", "0")
    let y = flag(f, "y", "0")
    let w = flag(f, "w", "460")
    let h = flag(f, "h", "200")
    print("// NSTableView in an okTable-wrapped NSScrollView with one column per identifier")
    print("let table = okTable(win, " + x + ", " + y + ", " + w + ", " + h + ")")
    let rest = columns
    while rest != "" {
        let comma = indexOf(rest, ",")
        let col = ""
        if comma == 0 - 1 { col = rest; rest = "" } else { col = substring(rest, 0, comma); rest = substring(rest, comma + 1, len(rest)) }
        let ident = trim(col)
        print("let col_" + ident + " = msg_1(msg(cls(\"NSTableColumn\"), \"alloc\"), \"initWithIdentifier:\", nsString(\"" + ident + "\"))")
        print("msg_d1(col_" + ident + ", \"setWidth:\", 160)")
        print("msg_1(table, \"addTableColumn:\", col_" + ident + ")")
        print("msg(col_" + ident + ", \"release\")")
    }
    print("// Point table at your data source after creating it:")
    print("// msg_1(table, \"setDataSource:\", myDataSource)")
    print("// msg(table, \"reloadData\")")
}

func emitDelegate(f) {
    let proto = flag(f, "protocol", "NSWindowDelegate")
    print("// Krypton objk delegate stub for " + proto)
    print("objk object " + proto + "Impl conforms " + proto + " {")
    if proto == "NSWindowDelegate" {
        print("    method windowShouldClose(sender: text) -> bool = windowShouldCloseImpl")
        print("    method windowDidResize(notification: text) = windowDidResizeImpl")
        print("    method windowWillEnterFullScreen(notification: text) = windowWillEnterFullScreenImpl")
        print("}")
        print("")
        print("func windowShouldCloseImpl(runtime, self, sender) { emit 1 }")
        print("func windowDidResizeImpl(runtime, self, sender) { emit 0 }")
        print("func windowWillEnterFullScreenImpl(runtime, self, sender) { emit 0 }")
    } else if proto == "NSApplicationDelegate" {
        print("    method applicationDidFinishLaunching(notification: text) = appDidFinishLaunchingImpl")
        print("    method applicationWillTerminate(notification: text) = appWillTerminateImpl")
        print("}")
        print("")
        print("func appDidFinishLaunchingImpl(runtime, self, sender) { emit 0 }")
        print("func appWillTerminateImpl(runtime, self, sender) { emit 0 }")
    } else if proto == "NSTableViewDataSource" {
        print("    method numberOfRowsInTableView(tableView: text) -> int = numberOfRowsInTableViewImpl")
        print("    method tableView(tableView: text, objectValueForTableColumn: text, row: int) -> text = tableViewObjectValueForRowImpl")
        print("}")
        print("")
        print("func numberOfRowsInTableViewImpl(runtime, self, tableView) { emit 0 }")
        print("func tableViewObjectValueForRowImpl(runtime, self, tableView, column, row) { emit \"\" }")
    } else {
        printErr("socam gen delegate: unknown protocol '" + proto + "' (supported: NSWindowDelegate, NSApplicationDelegate, NSTableViewDataSource)\n")
    }
}

