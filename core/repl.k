// core/repl.k — Milestone 6 (Redux): Live Runtime REPL & IPC Bridge
//
// Talking to the running app:
//   socam repl           — interactive (type dump|border|reload|status|quit), Ctrl-D or empty input to leave
//   socam repl <cmd>     — send one command (dump|border|reload|status|quit) and print reply if any
//
// The running app must be scaffolded with socam --bridge and started.
// Reply channel: /tmp/socam.reply written by the bridge target.

import "k:okui"
import "k:cocoa"
import "k:fsx"
import "k:sh"

// Reply wait budget: socam repl prompts for /tmp/socam.reply for ~5s
// (200 x 25ms). The reply normally lands in well under a second — a local
// AppKit app just needs to pump its event loop once. A missing reply after
// the full budget means the bridge is not installed, the app hung, or it
// crashed; failing with a clear message beats blocking forever.

func sendReplCommand(cmd) {
    let center = msg(cls("NSDistributedNotificationCenter"), "defaultCenter")
    let _ = msg_4(center, "postNotificationName:object:userInfo:deliverImmediately:",
              nsString("socam/command"),
              nsString(cmd),
              0,
              1)
    emit "1"
}

func pollReplyFile(ntimes) {
    let i = 0
    while i < ntimes {
        if exists("/tmp/socam.reply") == "1" { emit "1" }
        sleepUs(0, 25000)
        i += 1
    }
    emit "0"
}

// One command round-trip. Emits "1" and prints the reply on success, emits
// "0" and prints a diagnostic on timeout.
func sendAndReport(cmd) {
    rm("/tmp/socam.reply")
    sendReplCommand(cmd)
    if pollReplyFile(200) == "1" {
        print(readFile("/tmp/socam.reply"))
        emit "1"
    } else {
        print("socam: no reply after ~5s — is the app running with the socam bridge armed?\n")
        emit "0"
    }
}

func cmdRepl() {
    let argc = argCount()
    if argc >= 2 {
        // one-shot: Cmd
        let cmd = arg(1)
        if cmd != "dump" && cmd != "border" && cmd != "reload" && cmd != "status" && cmd != "quit" {
            print("usage: socam repl [dump|border|reload|status|quit]\n")
            exit("1")
        }
        if sendAndReport(cmd) != "1" { exit("1") }
        exit("0")
    }
    print("socam repl — connected to the running app (Ctrl-D / empty line to leave)\n")
    print("commands: dump | border | reload | status | quit\n")
    while true {
        let line = trim(readLine("socam> "))
        if line == "" { print("\nbye\n"); exit("0") }
        if line == "quit" {
            sendAndReport("quit")
            print("bye\n")
            exit("0")
        }
        if line != "dump" && line != "border" && line != "reload" && line != "status" {
            print("unknown: " + line + "  (known: dump border reload status quit)\n")
            continue
        }
        sendAndReport(line)
    }
}
