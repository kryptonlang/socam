// core/assistance.k — Open-Code Assistance primitives for socam.
//
// Bridge into the checked-out Krypton compiler: invokes the frontendBinary
// to compile a .k source file into IR, then returns that IR text for the
// caller to inspect. Used by `socam explain` today; future socam commands
// (trace, profile, diff) will consume the same primitive.

module assistance

// Compile `srcPath` to Krypton IR via the checked-out frontend and return
// the full IR text on stdout. The KRYPTON_ROOT environment variable is
// required (tells the frontend where its stdlib lives). On failure prints
// stderr verbatim and exits with rc=1 — never silently swallows the compiler
// error.
func compileToIR(srcPath) {
    let root = environ("KRYPTON_ROOT")
    if root == "" {
        print("socam explain: KRYPTON_ROOT not set\n")
        exit("1")
    }
    let fe = root + "/compiler/macos_arm64/kcc-arm64"
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
