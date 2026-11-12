// mock_bridge.k — minimal socam/command bridge for the bridge protocol test.
//
// Stands in for a real bridged app (see `socam new app --bridge`): registers
// on NSDistributedNotificationCenter for "socam/command" and answers with the
// same reply protocol as a real bridge — writes /tmp/socam.reply.
//
//   socam repl dump   -> windows=1 panes=2 secure=0 master=3
//   socam repl status -> ok stem=0.1.0 panes=2 secure=0 master=3
//   socam repl border -> repaint panes=4
//   socam repl reload -> reload
//   socam repl quit   -> quit (then exits)
//   anything else     -> unknown: <cmd>
//
// The test driver kills this process via `socam repl quit`.

import "k:cocoa"
import "k:objc"
import "k:fsx"
import "k:okui"

func _mockBridgeHandler(self, cmdsel, notif) {
    let cmd = nsToStr(msg(notif, "object"))
    let out = ""
    if cmd == "dump" {
        out = "windows=1 panes=2 secure=0 master=3\n"
    } else if cmd == "status" {
        out = "ok stem=0.1.0 panes=2 master=3 secure=0\n"
    } else if cmd == "border" {
        out = "repaint panes=4\n"
    } else if cmd == "reload" {
        out = "reload\n"
    } else if cmd == "quit" {
        out = "quit\n"
    } else {
        out = "unknown: " + cmd + "\n"
    }
    writeFile("/tmp/socam.reply", out)
    if cmd == "quit" { exit("0") }
    emit 0
}
func installMockBridge() {
    let c = objc_lookUpClass("SocamMockBridge")
    if c == 0 {
        c = cocoaClassNew("SocamMockBridge")
        if c == 0 { printErr("mock bridge: class alloc failed\n"); emit "0" }
        if cocoaClassAddMethod(c, "socamCommand:", funcptr(_mockBridgeHandler), "v@:@") == "0" { printErr("mock bridge: addMethod failed\n"); emit "0" }
        cocoaClassRegister(c)
    }
    let inst = cocoaNew(c)
    let center = msg(cls("NSDistributedNotificationCenter"), "defaultCenter")
    let _ = msg_4(center, "addObserver:selector:name:object:", inst, sel("socamCommand:"), nsString("socam/command"), 0)
    print("mock bridge ready\n")
    emit "1"
}
just run {
    let pool = okAutoreleasePool()
    let app = cocoaInit()
    cocoaFinishLaunching(app)
    installMockBridge()
    // Keep pumping events so the distributed notification source fires.
    let i = 0
    while i < 30000 {
        cocoaPumpEvents(app)
        sleepUs(0, 10000)
        i += 1
    }
    okDrainPool(pool)
}
