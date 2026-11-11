// core/repl.k — Milestone 6 (Redux): Live Runtime REPL & IPC Bridge
//
// Talking to the running app:
//   socam repl           — interactive (type dump|border|reload|quit), Ctrl-D or empty input to leave
//   socam repl <cmd>     — send one command (dump|border|reload|quit) and print reply if any
//
// The running app must be scaffolded with socam --bridge and started.
// Reply channel: /tmp/socam.reply written by the bridge target.

import "k:okui"
import "k:cocoa"
import "k:fsx"
import "k:sh"

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
        sleepUs(25000, 0)
        i += 1
    }
    emit "0"
}

func sendAndReport(cmd) {
    rm("/tmp/socam.reply")
    sendReplCommand(cmd)
    let got = pollReplyFile(80)
    if got == "1" {
        print(readFile("/tmp/socam.reply"))
    } else {
        print("(no reply; is the app running with --bridge?)\n")
    }
}

func cmdRepl() {
    let argc = argCount()
    if argc >= 2 {
        // one-shot: Cmd
        let cmd = arg(1)
        if cmd != "dump" && cmd != "border" && cmd != "reload" && cmd != "quit" {
            print("usage: socam repl [dump|border|reload|quit]\n")
            exit("1")
        }
        sendAndReport(cmd)
        exit("0")
    }
    print("socam repl — connected to the running app (Ctrl-D / empty line to leave)\n")
    print("commands: dump | border | reload | quit\n")
    while true {
        let line = trim(readLine("socam> "))
        if line == "" { print("\nbye\n"); exit("0") }
        if line == "quit" {
            sendAndReport("quit")
            print("bye\n")
            exit("0")
        }
        if line != "dump" && line != "border" && line != "reload" {
            print("unknown: " + line + "  (known: dump border reload quit)\n")
            continue
        }
        sendAndReport(line)
    }
}
