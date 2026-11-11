// core/pack.k — Milestone 9: local signing + dmg of a built .app
//
// `socam pack` calls the macOS toolchain (codesign/iconutil/hdiutil) via shell utilities.

module pack

import "k:fsx"
import "k:sh"

func doPack() {
    let app = ""
    let signId = ""
    let outDmg = ""
    let iconset = ""
    let i = 2
    while i < argCount() {
        let tok = arg(i)
        if startsWith(tok, "--app=")   { app = substring(tok, 6, len(tok)) }
        else if startsWith(tok, "--sign=") { signId = substring(tok, 7, len(tok)) }
        else if startsWith(tok, "--dmg=")  { outDmg = substring(tok, 6, len(tok)) }
        else if tok == "--sign" { signId = "_DEFAULT_" }
        else if tok == "--dmg"  { outDmg = "auto" }
        else if startsWith(tok, "--iconset=") { iconset = substring(tok, 10, len(tok)) }
        i += 1
    }
    if app == "" {
        // heuristic: first .app in cwd
        let out = exec("ls -1d *.app 2>/dev/null | head -1")
        app = trim(out)
    }
    if app == "" { printErr("socam pack: no .app given and none found in cwd (use --app=Foo.app)\n"); exit("1") }

    if iconset != "" {
        if !exists(iconset) { printErr("socam pack: iconset not found: " + iconset + "\n"); exit("1") }
        let r = shellRun("iconutil -c icns " + q(iconset) + " -o /tmp/_socam_pack_icon.icns")
        if r != "0" { printErr("socam pack: iconutil failed\n"); exit("1") }
        let dst = app + "/Contents/Resources/AppIcon.icns"
        mkdirp(app + "/Contents/Resources")
        exec("cp /tmp/_socam_pack_icon.icns " + q(dst))
        print("icon: wrote " + dst)
        rm("/tmp/_socam_pack_icon.icns")
    }

    if signId == "_DEFAULT_" {
        // pick the first Developer ID Application identity
        let idOut = exec("security find-identity -v -p codesigning | grep -m 1 'Developer ID Application:' | awk '{print $2}'")
        signId = trim(idOut)
        if signId == "" { signId = "-" } // fall back to ad-hoc
    }
    if signId != "" {
        let cmd = "codesign --force --deep --strict --options runtime --timestamp --sign " + q(signId) + " " + q(app)
        print("signing: " + cmd)
        let rc = shellRun(cmd)
        if rc != "0" { printErr("socam pack: codesign failed\n"); exit("1") }
        print("signed " + app)
    }

    if outDmg == "auto" { outDmg = replace(app, ".app", ".dmg") }
    if outDmg != "" {
        let r = shellRun("hdiutil create -volname " + q(baseName(app, ".app")) + " -srcfolder " + q(app) + " -ov -format UDZO " + q(outDmg))
        if r != "0" { printErr("socam pack: hdiutil failed\n"); exit("1") }
        print("dmg: wrote " + outDmg)
    }
}

func baseName(path, ext) {
    let base = replace(path, ext, "")
    let i = len(base) - 1
    while i >= 0 && base[i] != "/" { i = i - 1 }
    if i < 0 { emit base } emit substring(base, i + 1, len(base))
}

