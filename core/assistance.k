// core/assistance.k — Open-Code Assistance primitives for socam.
//
// Bridge into the checked-out Krypton compiler: invokes the frontendBinary
// to compile a .k source file into IR, then returns that IR text for the
// caller to inspect. Used by `socam explain` today; future socam commands
// (trace, profile, diff) will consume the same primitive.

module assistance

import "k:fsx"

// Compile `srcPath` to Krypton IR via the checked-out frontend and return
// the full IR text on stdout. The KRYPTON_ROOT environment variable is
// required (tells the frontend where its stdlib lives). On failure prints
// stderr verbatim and exits with rc=1 — never silently swallows the compiler
// error.
// Candidate toolchain roots, in priority order:
//   1. $KRYPTON_ROOT (user override; may point at a checkout or an install)
//   2. /usr/local/krypton                          (installed toolchain)
//   3. <caller-cwd>/compiler/macos_arm64/kcc-arm64 (running inside krypton)
//   4. <caller-cwd>/../krypton/compiler/...        (sibling checkout)
// Resolution succeeds only if the frontend binary exists there; otherwise
// returns "" and the caller reports the probing order.
func resolveRoot() {
    let tried = ""
    let envRoot = environ("KRYPTON_ROOT")
    if envRoot != "" {
        let cand = envRoot + "/compiler/macos_arm64/kcc-arm64"
        tried = tried + " $KRYPTON_ROOT -> " + cand + "\n"
        if exists(cand) == "1" { emit envRoot }
    } else {
        tried = tried + " $KRYPTON_ROOT (not set)\n"
    }
    let inst = "/usr/local/krypton/compiler/macos_arm64/kcc-arm64"
    tried = tried + " /usr/local/krypton/compiler/macos_arm64/kcc-arm64\n"
    if exists(inst) == "1" { emit "/usr/local/krypton" }
    let cwd = trim(exec("pwd"))
    let cwdCand = cwd + "/compiler/macos_arm64/kcc-arm64"
    tried = tried + " " + cwdCand + "\n"
    if exists(cwdCand) == "1" { emit cwd }
    let up = cwd + "/../krypton/compiler/macos_arm64/kcc-arm64"
    tried = tried + " " + up + "\n"
    if exists(up) == "1" { emit cwd + "/../krypton" }
    if tried != "" { print(tried) }
    emit ""
}

// Path of the frontend (kcc-arm64) given a krypton root. KCC_FRONTEND overrides.
func kccFrontend(root) {
    let fe = environ("KCC_FRONTEND")
    if fe != "" { emit fe }
    if root == "" { emit "" } else { emit root + "/compiler/macos_arm64/kcc-arm64" }
}

func compileToIR(srcPath) {
    let root = resolveRoot()
    if root == "" {
        print("socam explain: no krypton toolchain found (probed in order):\n")
        print("  1. $KRYPTON_ROOT/compiler/macos_arm64/kcc-arm64\n")
        print("  2. /usr/local/krypton/compiler/macos_arm64/kcc-arm64\n")
        print("  3. <cwd>/compiler/macos_arm64/kcc-arm64 (relative to caller)\n")
        print("  4. <cwd>/../krypton/compiler/macos_arm64/kcc-arm64 (sibling checkout)\n")
        print("set KRYPTON_ROOT=<krypton-repo> or KCC_FRONTEND=<frontend-binary> to override.\n")
        exit("1")
    }
    let fe = kccFrontend(root)
    let tmpir  = "/tmp/_socam_ir_" + replace(srcPath, "/", "_")
    let tmperr = "/tmp/_socam_err_" + replace(srcPath, "/", "_")
    let cmd = "KRYPTON_ROOT=" + root + " " + qRaw(fe) +
              " --ir " + qRaw(srcPath) +
              " > " + qRaw(tmpir) +
              " 2> " + qRaw(tmperr)
    let rc = shellRun(cmd)
    if rc != "0" {
        let errText = readText(tmperr)
        if errText != "" { print(errText) } else { print("socam explain: compile failed (rc=" + rc + ")\n") }
        rm(tmpir)
        rm(tmperr)
        exit("1")
    }
    let ir = readText(tmpir)
    rm(tmpir)
    rm(tmperr)
    emit ir
}

// Count the number of `FUNC ` lines in an IR string.
func countFuncsIR(ir) {
    let nl = lineCount(ir)
    let n = 0
    let i = 0
    while i < nl {
        let line = getLine(ir, i)
        let j = 0
        while j < len(line) && line[j] != " " { j += 1 }
        if substring(line, 0, j) == "FUNC" { n += 1 }
        i += 1
    }
    emit n
}

// Shell-quote a value with single quotes (POSIX-portable, safe for any chars).
func qRaw(s) {
    emit "'" + replace(s, "'", "'\\'\\''") + "'"
}
