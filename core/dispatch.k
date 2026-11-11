// core/dispatch.k — Minimal command dispatcher for socam.
//
// Maps recognized sub-commands to their handler names. The CLI binary
// (bin/socam.k) consults `matchRoute(cmd)` to pick a route, then invokes the
// corresponding handler.

module dispatch

// Return the canonical route for a CLI token, or "" if unknown.
// Routes are the canonical names used by the dispatcher in socam.k.
func matchRoute(cmd) {
    if cmd == "explain" { emit "explain" }
    if cmd == "grep"    { emit "grep" }
    if cmd == "list"    { emit "list" }
    if cmd == "gen"     { emit "gen" }
    if cmd == "new"     { emit "new" }
    if cmd == "watch"   { emit "watch" }
    if cmd == "version" { emit "version" }
    if cmd == "help" || cmd == "--help" || cmd == "-h" { emit "help" }
    emit ""
}
