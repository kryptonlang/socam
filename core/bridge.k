// core/bridge.k — Milestone 6 (Redux): Live Runtime REPL & IPC Bridge
//
// Wraps NSDistributedNotificationCenter + the performSelector pattern that
// reaches Krypton IMPs reliably (timer/scheduler is broken; after-delay works).
//
// CLI side: `socam repl` broadcasts commands via NSDistributedNotificationCenter.
// App side: apps scaffolded with --bridge register SocamBridge class + observe "socam/command".
// Reply: the app handler writes to /tmp/socam.reply; the REPL prints it.

import "k:cocoa"
import "k:fsx"
import "k:sh"
import "k:okui"

// CLI side — send one command to any running Krypton app in this session.
func sendCommand(cmd) {
    let center = msg(cls("NSDistributedNotificationCenter"), "defaultCenter")
    let _ = msg_4(center, "postNotificationName:object:userInfo:deliverImmediately:",
              nsString("socam/command"),
              nsString(cmd),
              0,
              1)
    emit "1"
}

// App side — called on receipt of "socam/command" via @selector(socamCommand:).
func _bridgeHandler(self, cmdsel, notif) {
    let cmd = msg(notif, "object")
    let tval = nsToStr(cmd)
    let out = ""
    if tval == "dump" {
        let app = msg(cls("NSApplication"), "sharedApplication")
        let wins = msg(app, "windows")
        let count = msg(wins, "count")
        out = "windows=" + count + "\n"
    } else if tval == "border" {
        out = "border-on\n"  // placeholder — extend with real border toggle
    } else if tval == "reload" {
        out = "reload\n"     // placeholder — extend with needsDisplay walk
    } else if tval == "quit" {
        exit("0")
    } else {
        out = "unknown: " + tval + "\n"
    }
    writeText("/tmp/socam.reply", out)
    emit 0
}

// App side — call once at startup; registers class and registers the observer.
func installBridge() {
    let c = objc_lookUpClass("SocamBridge")
    if c == 0 {
        c = objc_allocateClassPair(cls("NSObject"), "SocamBridge", 0)
        if c == 0 { printErr("socam bridge: alloc failed\n"); emit "0" }
        if chocClassAddMethod(c, "socamCommand:", funcptr(_bridgeHandler), "v@:@") == "0" {
            printErr("socam bridge: addMethod failed\n"); emit "0"
        }
        cocoaClassRegister(c)
    }
    let inst = cocoaNew(c)
    let center = msg(cls("NSDistributedNotificationCenter"), "defaultCenter")
    let _ = msg_4(center, "addObserver:selector:name:object:",
              inst, sel("socamCommand:"), nsString("socam/command"), 0)
    printErr("socam bridge: listening for commands\n")
    emit "1"
}
