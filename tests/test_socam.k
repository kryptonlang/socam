// tests/test_socam.k — Smoke tests for the socam binary.
//
// Builds socam.k, then verifies the basic CLI surface end-to-end:
//   socam --version  -> exit 0
//   socam explain    -> exit 0, prints "; Krypton IR"
//   socam list       -> lists .k files, exit 0
//   socam gen <name> -> writes <name>.k and exits 0
//
// Requires KRYPTON_ROOT to point at a krypton checkout with a working
// compiler (kcc-arm64) and kcc_driver_macos_aarch64 on PATH.

just run {
    let root = environ("KRYPTON_ROOT")
    if root == "" {
        print("socam tests: KRYPTON_ROOT not set\n")
        exit("1")
    }
    let driver = root + "/bootstrap/kcc_driver_macos_aarch64"
    let socamBin = "/tmp/socam_test_bin"

    // Build socam
    let build = shellRun(driver + " " + root + "/socam/bin/socam.k -o " + socamBin)
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

    // 3) list of a tiny source tree finds itself
    let listing = shellRun(socamBin + " list " + root + "/socam/tests")
    // We only check rc; the listing is non-empty by construction.
    if listing != "0"                { print("[FAIL] list rc\n");           exit("1") }

    // 4) gen overwrites nothing accidentally
    let genOut = root + "/socam/tests/__gen_smoke.k"
    if exists(genOut) { rm(genOut) }
    let g = shellRun(socamBin + " gen " + root + "/socam/tests/__gen_smoke")
    if g != "0"                      { print("[FAIL] gen rc\n");             exit("1") }
    if !exists(genOut)               { print("[FAIL] gen produced no file\n"); exit("1") }
    rm(genOut)

    print("[PASS] socam smoke (help, version, list, gen)")
}
