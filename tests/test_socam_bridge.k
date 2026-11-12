// tests/test_socam_bridge.k — end-to-end socam/command bridge protocol test.
//
// Stands up a mock bridged app (fixtures/mock_bridge.k) that registers on
// NSDistributedNotificationCenter for "socam/command" and answers with the
// same reply protocol as a real bridged app: writing /tmp/socam.reply.
//
// Then drives it through the socam CLI:
//   socam repl dump   -> windows=1 panes=2 ...
//   socam repl status -> ok stem=... panes=2 ...
//   socam repl border -> repaint panes=4
//   socam repl reload -> reload
//   socam repl quit   -> quit   (and the mock process must exit)
//
// Verifies the full round-trip out-of-process: socam (client) -> distributed
// notification -> bridge (mock app) -> /tmp/socam.reply -> socam (prints).
//
// Requires KRYPTON_ROOT (krypton toolchain) and SOCAM_ROOT (this repo).

import "k:fsx"
import "k:sh"

func fail(msg) { print("[FAIL] " + msg + "\n"); exit("1") }

// Poll until `path` contains `needle`, or iters x 250ms pass. Emits "1" on hit.
func waitForContent(path, needle, iters) {
    let i = 0
    while i < iters {
        if exists(path) == "1" {
            if contains(readText(path), needle) { emit "1" }
        }
        sleepUs(0, 250000)
        i += 1
    }
    emit "0"
}

// "1" while a process of exactly `name` exists.
func processAlive(name) {
    if shellRun("pgrep -x " + q(name) + " > /dev/null 2>&1") == "0" { emit "1" }
    emit "0"
}

just run {
    let kroot = environ("KRYPTON_ROOT")
    let sroot = environ("SOCAM_ROOT")
    if kroot == "" { print("socam bridge tests: KRYPTON_ROOT not set\n"); exit("1") }
    if sroot == "" { print("socam bridge tests: SOCAM_ROOT not set (point at the socam repo)\n"); exit("1") }

    let driver   = kroot + "/bootstrap/kcc_driver_macos_aarch64"
    let socamSrc = sroot + "/bin/socam.k"
    let mockSrc  = sroot + "/tests/fixtures/mock_bridge.k"
    let socamBin = "/tmp/socam_bridge_test_bin"
    let mockBin  = "/tmp/socambridge"
    let mockLog  = "/tmp/socam_bridge_mock.log"

    if !exists(driver)  { print("socam bridge tests: driver not found at " + driver + "\n"); exit("1") }
    if !exists(socamSrc) { print("socam bridge tests: " + socamSrc + " not found\n"); exit("1") }
    if !exists(mockSrc)  { print("socam bridge tests: fixture not found at " + mockSrc + "\n"); exit("1") }

    // Build socam
    let build = shellRun("cd " + q(sroot) + " && " + q(driver) + " " + q(socamSrc) + " -o " + q(socamBin))
    if build != "0" { fail("socam build failed") }

    // Build the mock bridge app
    let mb = shellRun("cd " + q(sroot) + " && " + q(driver) + " " + q(mockSrc) + " -o " + q(mockBin))
    if mb != "0" { fail("mock bridge build failed") }

    // Launch the mock and wait for it to install its bridge
    rm(mockLog)
    shellRun("nohup " + q(mockBin) + " > " + q(mockLog) + " 2>&1 &")
    if waitForContent(mockLog, "mock bridge ready", 60) != "1" {
        print(readText(mockLog))
        fail("mock bridge never became ready (see " + mockLog + ")")
    }

    // dump — reply structure must match the documented protocol
    let dump = exec(q(socamBin) + " repl dump")
    if !contains(dump, "windows=1") || !contains(dump, "panes=2") || !contains(dump, "secure=0") {
        fail("dump: unexpected reply: " + dump)
    }
    print("OK dump\n")

    // status — health/status reply with the pane count
    let status = exec(q(socamBin) + " repl status")
    if !contains(status, "ok stem=") || !contains(status, "panes=2") {
        fail("status: unexpected reply: " + status)
    }
    print("OK status\n")

    // border — forces a repaint
    let border = exec(q(socamBin) + " repl border")
    if !contains(border, "repaint panes=4") { fail("border: unexpected reply: " + border) }
    print("OK border\n")

    // reload — config reload
    let reload = exec(q(socamBin) + " repl reload")
    if !contains(reload, "reload") { fail("reload: unexpected reply: " + reload) }
    print("OK reload\n")

    // quit — the mock exits after acknowledging
    let quit = exec(q(socamBin) + " repl quit")
    if !contains(quit, "quit") { fail("quit: unexpected reply: " + quit) }
    print("OK quit\n")

    let i = 0
    let alive = "1"
    while i < 40 {
        if processAlive("socambridge") == "0" { alive = "0"  break }
        sleepUs(0, 250000)
        i += 1
    }
    if alive == "1" {
        shellRun("pkill -x socambridge || true")
        fail("mock bridge still running 10s after 'quit'")
    }

    print("[PASS] socam bridge round-trip (dump, status, border, reload, quit)\n")
}
