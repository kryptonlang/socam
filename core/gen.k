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
    else if target == "asset" { emitAsset(flags); emit "" }
    else if target == "binding" { emitBinding(flags); emit "" }
    else if target == "menu" { emitMenu(flags); emit "" }
    else if target == "statusbar" { emitStatusbar(flags); emit "" }
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

func _makePng(sipsBin, src, dst, w, h) {
    let cmd = q(sipsBin) + " -z " + h + " " + w + " " + q(src) + " --out " + q(dst)
    let rc = shellRun(cmd)
    if rc != "0" { printErr("socam asset: sips failed for " + dst + "\n"); exit("1") }
}

// Build a .iconset folder + Contents.json from a source PNG.
func buildIconset(srcPng) {
    if !exists(srcPng) { printErr("socam asset icons: source not found: " + srcPng + "\n"); exit("1") }
    if !exists("/usr/bin/sips") { printErr("socam asset icons: /usr/bin/sips not found (macOS only)\n"); exit("1") }

    let root = replace(srcPng, ".png", ".iconset")
    if exists(root) == "1" { print("socam asset icons: removing existing " + root); rmrf(root) }
    mkdirp(root)

    // mac iconset sizes: 16, 16@2x=32, 32, 32@2x=64, 128, 128@2x=256, 256, 256@2x=512, 512, 512@2x=1024
    let sips = "/usr/bin/sips"
    _makePng(sips, srcPng, root + "/icon_16x16.png",       16, 16)
    _makePng(sips, srcPng, root + "/icon_16x16@2x.png",    32, 32)
    _makePng(sips, srcPng, root + "/icon_32x32.png",       32, 32)
    _makePng(sips, srcPng, root + "/icon_32x32@2x.png",    64, 64)
    _makePng(sips, srcPng, root + "/icon_128x128.png",    128, 128)
    _makePng(sips, srcPng, root + "/icon_128x128@2x.png", 256, 256)
    _makePng(sips, srcPng, root + "/icon_256x256.png",    256, 256)
    _makePng(sips, srcPng, root + "/icon_256x256@2x.png", 512, 512)
    _makePng(sips, srcPng, root + "/icon_512x512.png",    512, 512)
    _makePng(sips, srcPng, root + "/icon_512x512@2x.png",1024,1024)

    let manifest =
        "{\n" +
        "  \"images\" : [\n" +
        "    { \"size\" : \"16x16\"   , \"idiom\" : \"mac\", \"filename\" : \"icon_16x16.png\"       , \"scale\" : \"1x\" },\n" +
        "    { \"size\" : \"16x16\"   , \"idiom\" : \"mac\", \"filename\" : \"icon_16x16@2x.png\"    , \"scale\" : \"2x\" },\n" +
        "    { \"size\" : \"32x32\"   , \"idiom\" : \"mac\", \"filename\" : \"icon_32x32.png\"       , \"scale\" : \"1x\" },\n" +
        "    { \"size\" : \"32x32\"   , \"idiom\" : \"mac\", \"filename\" : \"icon_32x32@2x.png\"    , \"scale\" : \"2x\" },\n" +
        "    { \"size\" : \"128x128\" , \"idiom\" : \"mac\", \"filename\" : \"icon_128x128.png\"     , \"scale\" : \"1x\" },\n" +
        "    { \"size\" : \"128x128\" , \"idiom\" : \"mac\", \"filename\" : \"icon_128x128@2x.png\"  , \"scale\" : \"2x\" },\n" +
        "    { \"size\" : \"256x256\" , \"idiom\" : \"mac\", \"filename\" : \"icon_256x256.png\"     , \"scale\" : \"1x\" },\n" +
        "    { \"size\" : \"256x256\" , \"idiom\" : \"mac\", \"filename\" : \"icon_256x256@2x.png\"  , \"scale\" : \"2x\" },\n" +
        "    { \"size\" : \"512x512\" , \"idiom\" : \"mac\", \"filename\" : \"icon_512x512.png\"     , \"scale\" : \"1x\" },\n" +
        "    { \"size\" : \"512x512\" , \"idiom\" : \"mac\", \"filename\" : \"icon_512x512@2x.png\"  , \"scale\" : \"2x\" }\n" +
        "  ],\n" +
        "  \"info\" : { \"version\" : 1, \"author\" : \"socam\" }\n" +
        "}\n"
    writeText(root + "/Contents.json", manifest)
    print("socam asset icons: wrote " + root + "/Contents.json")
    print("socam asset icons: 10 icon variants in " + root)
    print("next step:  iconutil -c icns " + root)
}

func emitAsset(f) {
    print("// Generated by socam gen asset")
    print("// drop into your app next to the .xcassets or wherever you import k:objk_runtime_macos")
    print("// Wraps NSImage/NSColor lookups against the main bundle + system colors")
    print("")
    print("func krAssetImage(name)  { emit msg_1(cls(\"NSImage\"), \"imageNamed:\", nsString(name)) }")
    print("func krAssetSystemBlue() { emit msg(cls(\"NSColor\"), \"systemBlueColor\") }")
    print("func krAssetLabelColor() { emit msg(cls(\"NSColor\"), \"labelColor\") }")
    print("func krAssetPrimaryColor() { emit msg(cls(\"NSColor\"), \"controlAccentColor\") }")
    print("")
    print("// usage:")
    print("//   let icon = krAssetImage(\"AppIcon\")")
    print("//   let primary = krAssetPrimaryColor()")
}

func emitBinding(f) {
    let target = flag(f, "target", "slider")
    let property = flag(f, "property", "value")
    let handler = flag(f, "handler", "updateLabel")
    let ctx = flag(f, "context", "KrBinding")
    print("// Generated by socam gen binding")
    print("// target: " + target + "   property: " + property + "   handler: " + handler)
    print("import \"k:okui\"")
    print("import \"k:cocoa\"")
    print("import \"k:objk_runtime_macos\"")
    print("")
    print("func " + handler + "(keyPath, object, change, context) {")
    print("    // user hook — fill in behavior")
    print("    if nsToStr(keyPath) == \"" + property + "\" {")
    print("        print(\"observed " + target + "." + property + " -> " + handler + "\")")
    print("    }")
    print("    emit 0")
    print("}")
    print("")
    print("func " + handler + "Notify(self, cmdsel, keyPath, object, change, context) {")
    print("    " + handler + "(keyPath, object, change, context)")
    print("    emit 0")
    print("}")
    print("")
    let upper = toUpper(substring(target, 0, 1)) + substring(target, 1, len(target))
    print("func bind" + upper + "ToObserver(" + target + ") {")
    print("    let c = objc_lookUpClass(\"KrBinding_" + upper + "\")")
    print("    if c == 0 {")
    print("        c = objc_allocateClassPair(cls(\"NSObject\"), \"KrBinding_" + upper + "\", 0)")
    print("    }")
    print("    chocClassAddMethod(c, \"observeValueForKeyPath:ofObject:change:context:\", funcptr(" + handler + "Notify), \"v@:@@@@\")")
    print("    cocoaClassRegister(c)")
    print("    let inst = cocoaNew(c)")
    print("    let opts = 1  // NSKeyValueObservingOptionNew")
    print("    let _ = msg_4(" + target + ", \"addObserver:forKeyPath:options:context:\",")
    print("                      inst, nsString(\"" + property + "\"), opts, nsString(\"" + ctx + "\"))")
    print("}")
}

func emitMenu(f) {
    let title = flag(f, "title", "Edit")
    let items = flag(f, "items", "Undo,-,Redo")
    let keys  = flag(f, "keys", "")
    print("// Generated by socam gen menu")
    print("let bar = okMenuBar(app)")
    print("let " + title + "Menu = okMenuAdd(bar, \"" + title + "\")")
    let rest = items
    let ki = 0
    while rest != "" {
        // split on comma
        let comma = -1
        let nn = len(rest)
        let j = 0
        while j < nn {
            if rest[j] == "," { comma = j; break }
            j += 1
        }
        let part = ""
        if comma == 0 - 1 { part = rest; rest = "" }
        else { part = substring(rest, 0, comma); rest = substring(rest, comma + 1, len(rest)) }
        let link = trim(part)
        if link == "-" {
            print("okMenuSeparator(" + title + "Menu)")
            ki += 1
            continue
        }
        // key from --keys or empty
        let keyLink = ""
        if keys != "" {
            let kr = keys
            let kList = ""
            let krest = kr
            let kk = 0
            while krest != "" {
                let kc = indexOf(krest, ",")
                let kp = ""
                if kc == 0 - 1 { kp = krest; krest = "" } else { kp = substring(krest, 0, kc); krest = substring(krest, kc + 1, len(krest)) }
                if kk == ki { keyLink = trim(kp) }
                kList = kList + kp + "|"
                kk += 1
            }
        }
        let funcName = camelLower(link) + "Impl"
        if keyLink != "" {
            print("okMenuAction(" + title + "Menu, \"" + link + "\", \"" + keyLink + "\", funcptr(" + funcName + "))")
        } else {
            print("okMenuAction(" + title + "Menu, \"" + link + "\", \"\", funcptr(" + funcName + "))")
        }
        ki += 1
    }
    // placeholder functions
    rest = items
    while rest != "" {
        let comma = indexOf(rest, ",")
        let part = ""
        if comma == 0 - 1 { part = rest; rest = "" } else { part = substring(rest, 0, comma); rest = substring(rest, comma + 1, len(rest)) }
        let t = trim(part)
        if t == "-" { continue }
        print("")
        print("func " + camelLower(t) + "Impl(self, command, sender) {")
        print("    emit 0")
        print("}")
    }
}

func camelLower(s) {
    if len(s) == 0 { emit s }
    let out = ""
    let cap = 0
    let i = 0
    while i < len(s) {
        let c = substring(s, i, i + 1)
        if c == " " { cap = 1; i += 1; continue }
        if cap == 1 {
            out = out + toUpper(c)
            cap = 0
        } else {
            out = out + toLower(c)
        }
        i += 1
    }
    emit out
}

func emitStatusbar(f) {
    let title = flag(f, "title", "★")
    let icon = flag(f, "icon", "")
    let menu = flag(f, "menu", "")
    print("// Generated by socam gen statusbar")
    // NSStatusBar bridge: shared system status bar → status item
    print("let statusBar = msg(cls(\"NSStatusBar\"), \"systemStatusBar\")")
    print("let statusItem = msg_1(statusBar, \"statusItemWithLength:\", -2)")
    if icon != "" {
        if !exists(icon) { printErr("socam gen statusbar: icon not found: " + icon + "\n"); exit("1") }
        print("let statusIcon = msg_1(msg(cls(\"NSImage\"), \"alloc\"), \"initWithContentsOfFile:\", nsString(\"" + icon + "\"))")
        print("msg_1(statusItem, \"setImage:\", statusIcon)")
    } else {
        print("msg_1(statusItem, \"setTitle:\", nsString(\"" + title + "\"))")
    }
    print("let statusMenu = msg(msg(cls(\"NSMenu\"), \"alloc\"), \"initWithTitle:\", nsString(\"" + title + "\"))")
    if menu != "" {
        // parse comma-separated items
        let rest = menu
        while rest != "" {
            let comma = indexOf(rest, ",")
            let part = ""
            if comma == 0 - 1 { part = rest; rest = "" } else { part = substring(rest, 0, comma); rest = substring(rest, comma + 1, len(rest)) }
            let m = trim(part)
            let nm = camelLower(m)
            print("let item_" + nm + " = msg_3(msg(cls(\"NSMenuItem\"), \"alloc\"), \"initWithTitle:action:keyEquivalent:\", nsString(\"" + m + "\"), 0, nsString(\"\"))")
            print("msg_1(statusMenu, \"addItem:\", item_" + nm + ")")
        }
    }
    print("msg_1(statusItem, \"setMenu:\", statusMenu)")
    print("// status item persists for as long as statusItem binding is alive")
}

