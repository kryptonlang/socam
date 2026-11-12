#!/usr/bin/env kr
// socam - Smart assistance CLI for the Krypton + SmackUI stack.
//
// Commands:
//   socam [--help|-h|help|version]
//   socam explain <file.k>      Print IR stats for a source file
//   socam grep <pattern> <file> [file ...]
//   socam list [<dir>]          List .k files under <dir> (default: .)
//   socam gen <name>            Emit starter module <name>.k
//
// Exit codes: 0 ok, 1 user/usage error, 2 internal failure.

import "./core/assistance.k"
import "./core/dispatch.k"
import "./core/scaffold.k"
import "./core/gen.k"
import "./core/watch.k"
import "./core/pack.k"
import "k:okui"
import "k:cocoa"
import "k:fsx"
import "k:sh"
import "./core/repl.k"

func showHelp() {
    print("socam (Smack Open-Code Assistance Mechanism)")
    print("")
    print("usage:")
    print("  socam | -h | --help        This help")
    print("  socam version              Print version and exit")
    print("  socam explain <file.k>     Print IR summary for <file.k>")
    print("  socam grep <pat> <file>    Print matching lines (prefix match)")
    print("  socam list [<dir>]         List .k files recursively")
    print("  socam gen <name>           Emit starter module <name>.k")
    print("  socam new app <Name>       Scaffold a new AppKit-ready Krypton app")
    print("  socam gen window           Print window snippet")
    print("  socam gen stack            NSStackView snippet")
    print("  socam gen split            NSSplitView snippet (sidebar|content)")
    print("  socam gen table            NSTableView snippet (auto-columns from --columns=)")
    print("  socam gen button           Print button-initialization snippet")
    print("  socam gen label            Print label-initialization snippet")
    print("  socam gen delegate         Print objk delegate stub (--protocol=NSWindowDelegate)")
    print("  socam gen binding          Print KVO binding stub (--target=… --property=…)")
    print("  socam gen menu             Print NSMenu + NSMenuItem allocations (--title=… --items=…)")
    print("  socam gen statusbar        Print NSStatusBar + NSStatusItem stub (--title=… --icon=… --menu=A,B)")
    print("  socam gen asset            Typed NSImage/NSColor accessors")
    print("  socam asset icons <png>    make .iconset folder + Contents.json from a master PNG")
    print("  socam pack [--app=Foo.app] [--sign] [--dmg] [--iconset=iconset]  sign + dmg-ify")
    print("  socam repl                 Live IPC session to the running app (dump|border|reload|status|quit)")
    print("  socam watch                Watch main.k, rebuild and relaunch on change")
    print("")
    print("environment:")
    print("  KRYPTON_ROOT       Override the repo root (for kcc-arm64)")
    print("  KCC_FRONTEND       Override the frontend binary (wins over KRYPTON_ROOT)")
    print("")
    print("resolution order for the compiler (first match wins):")
    print("  1. $KRYPTON_ROOT/compiler/macos_arm64/kcc-arm64")
    print("  2. /usr/local/krypton/compiler/macos_arm64/kcc-arm64")
    print("  3. <cwd>/compiler/macos_arm64/kcc-arm64")
    print("  4. <cwd>/../krypton/compiler/macos_arm64/kcc-arm64")
}

func showVersion() {
    print("socam 0.6.0 (Krypton + SmackUI)")
}

func cmdExplain() {
    if argCount() < 2 {
        print("usage: socam explain <file.k>\n")
        exit("1")
    }
    let path = arg(1)
    if !exists(path) {
        print("socam: " + path + " does not exist\n")
        exit("1")
    }
    let ir = compileToIR(path)
    let fcount = countFuncsIR(ir)
    print("; Source: " + path)
    print("; Functions: " + fcount)
    print("")
    print(ir)
}

func cmdGrep() {
    if argCount() < 3 {
        print("usage: socam grep <pattern> <file> [file ...]\n")
        exit("1")
    }
    let pat = arg(1)
    let i = 2
    let total = 0
    while i < argCount() {
        let path = arg(i)
        let text = readText(path)
        let n = lineCount(text)
        let j = 0
        while j < n {
            let line = getLine(text, j)
            if indexOf(line, pat) >= 0 {
                print(path + ":" + (j + 1) + ": " + line)
                total = total + 1
            }
            j += 1
        }
        i += 1
    }
    print("socam: " + total + " matches")
    if total == 0 { exit("1") }
}

func cmdList() {
    let target = "."
    if argCount() >= 2 { target = arg(1) }
    let cmd = "cd " + qRaw(target) + " && find . -name '*.k' -type f | sort"
    let out = trim(exec(cmd))
    if out == "" {
        print("socam: no .k files under " + target)
    } else {
        print(out)
    }
}

func nameFromArgs(startIdx) {
    let map = ""
    let i = startIdx
    while i < argCount() {
        let tok = arg(i)
        let eq = indexOf(tok, "=")
        if startsWith(tok, "--") && eq > 2 {
            let key = substring(tok, 2, eq)
            let val = substring(tok, eq + 1, len(tok))
            map = map + "|" + key + "=" + val
        }
        i += 1
    }
    emit map
}

func flagValue(map, key, defVal) {
    let needle = "|" + key + "="
    let idx = indexOf(map, needle)
    if idx < 0 { emit defVal }
    let start = idx + len(needle)
    let end = indexOf(map, "|", start)
    if end < 0 { emit substring(map, start, len(map)) }
    emit substring(map, start, end)
}

func cmdGen() {
    if argCount() < 2 {
        print("usage: socam gen <name|window|button|label|watch> [--key=value ...]\n")
        exit("1")
    }
    let target = arg(1)
    if target == "window" || target == "button" || target == "label" || target == "stack" || target == "split" || target == "table" || target == "delegate" || target == "binding" || target == "menu" || target == "statusbar" {
        let flags = nameFromArgs(2)
        emitSnippet(target, flags)
        exit("0")
    }
    if target == "watch" {
        watchLoop("main.k", "main")
        exit("0")
    }
    let name = target
    let outPath = name + ".k"
    if exists(outPath) {
        print("socam: " + outPath + " already exists\n")
        exit("1")
    }
    if exists(name) {
        print("socam: " + name + " already exists\n")
        exit("1")
    }
    let body = "// " + name + " - generated by socam gen\n" +
               "\n" +
               "module " + name + "\n" +
               "\n" +
               "func placeholder() {\n" +
               "    emit 0\n" +
               "}\n"
    writeText(outPath, body)
    print("socam: wrote " + outPath)
}

func cmdPack() {
    if argCount() < 2 {
        print("usage: socam pack [--app=Foo.app] [--sign [ID|auto]] [--dmg [out.dmg]] [--iconset=icon.iconset]\n")
        exit("1")
    }
    doPack()
    exit("0")
}

func cmdAsset() {
    if argCount() < 2 {
        print("usage: socam asset icons <source.png>\n")
        exit("1")
    }
    let sub = arg(1)
    if sub == "icons" {
        if argCount() < 3 {
            print("usage: socam asset icons <source.png>\n")
            exit("1")
        }
        buildIconset(arg(2))
        exit("0")
    }
    print("socam asset: unknown subcommand '" + sub + "'\n")
    exit("1")
}

func cmdNew() {
    if argCount() < 3 {
        print("usage: socam new app <ProjectName>\n")
        exit("1")
    }
    let kind = arg(1)
    if kind != "app" {
        print("socam new: only 'app' is supported\n")
        exit("1")
    }
    let name = arg(2)
    newAppApp(name)
}

func cmdWatch() {
    watchLoop("main.k", "main")
}

just run {
    let n = argCount()
    if n == 0 {
        showHelp()
        exit("0")
    }

    let route = matchRoute(arg(0))
    if route == "help" {
        showHelp()
        exit("0")
    }
    if route == "version" {
        showVersion()
        exit("0")
    }
    if route == "new" {
        cmdNew()
        exit("0")
    }
    if route == "pack" {
        cmdPack()
        exit("0")
    }
    if route == "asset" {
        cmdAsset()
        exit("0")
    }
    if route == "watch" {
        cmdWatch()
        exit("0")
    }
    if route == "repl" {
        cmdRepl()
        exit("0")
    }
    if route == "explain" {
        cmdExplain()
        exit("0")
    }
    if route == "grep" {
        cmdGrep()
        exit("0")
    }
    if route == "list" {
        cmdList()
        exit("0")
    }
    if route == "gen" {
        cmdGen()
        exit("0")
    }

    print("socam: unknown command '" + arg(0) + "'\n")
    showHelp()
    exit("1")
}
