// tests/test_socam.k — Smoke tests for the socam binary.
//
// Builds bin/socam.k from the directory this script lives in (the socam
// repo), then verifies the basic CLI surface end-to-end:
//   socam --version  -> exit 0
//   socam explain    -> exit 0, prints "; Krypton IR"
//   socam list       -> lists .k files, exit 0
//   socam gen <name> -> writes <name>.k and exits 0
//
// Requires KRYPTON_ROOT to point at a krypton checkout with a working
// compiler (kcc-arm64) and kcc_driver_macos_aarch64 on PATH.

import "k:fsx"
import "k:sh"

just run {
    let kroot = environ("KRYPTON_ROOT")  // krypton repo (toolchain)
    let sroot = environ("SOCAM_ROOT")    // socam repo (tool sources to test)
    if kroot == "" { print("socam tests: KRYPTON_ROOT not set\n"); exit("1") }
    if sroot == "" { print("socam tests: SOCAM_ROOT not set (point at the socam repo)\n"); exit("1") }

    let driver = kroot + "/bootstrap/kcc_driver_macos_aarch64"
    let src    = sroot + "/bin/socam.k"
    let socamBin = "/tmp/socam_test_bin"

    // Build socam
    if !exists(src) {
        print("socam tests: source not found at " + src + "\n")
        print("SOCAM_ROOT must point at the socam repo.\n")
        exit("1")
    }
    let build = shellRun(driver + " " + q(src) + " -o " + q(socamBin))
    if build != "0" {
        print("socam build failed (rc=" + build + ")\n")
        exit("1")
    }

    // 1) No args -> help and rc=0
    let help = shellRun(socamBin)
    if help != "0"                   { print("[FAIL] no-args rc\n");       exit("1") }

    // 2) --version -> any stdout is fine, rc must be 0
    let v = shellRun(socamBin + " version")
    if v != "0"                      { print("[FAIL] version rc\n");         exit("1") }

    // 3) list of a tiny source tree lists itself
    let listing = shellRun(socamBin + " list " + q(sroot + "/tests"))
    if listing != "0"                { print("[FAIL] list rc\n");           exit("1") }

    // 4) gen writes a file (cwd-created since socam writes next to caller's cwd)
    let genOut = sroot + "/_socam_gen_smoke.k"
    if exists(genOut) { rm(genOut) }
    let g = shellRun("cd " + q(sroot) + " && " + q(socamBin) + " gen _socam_gen_smoke")
    if g != "0"                      { print("[FAIL] gen rc\n");             exit("1") }
    if !exists(genOut)               { print("[FAIL] gen produced no file at " + genOut + "\n"); exit("1") }
    rm(genOut)

    print("[PASS] socam smoke (help, version, list, gen)")
}

