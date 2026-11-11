// core/watch.k — live rebuild loop.
//
// Milestone 3: `socam watch` polls main.k mtime in a loop, and on change
// rebuilds an existing binary via kcc, kills the running instance, and
// launches the fresh binary. Prints errors, never panics.

module watch

import "k:fsx"
import "k:sh"

func _mtimeSecs(path) {
    let out = exec("stat -f %m " + q(path))
    // strip trailing newline
    let n = len(out)
    while n > 0 && (out[n-1] == "\n" || out[n-1] == "\r") { n = n - 1 }
    emit substring(out, 0, n)
}

func _killApp(app) {
    // exact-name kill; returns empty output.
    let _ = shellRun("pkill -x " + q(app) + " || true")
}

func watchLoop(mainPath, appName) {
    let kroot = environ("KRYPTON_ROOT")
    if kroot == "" { kroot = "/usr/local/krypton" }
    let driver = kroot + "/bootstrap/kcc_driver_macos_aarch64"
    if !exists(driver) {
        printErr("socam watch: driver not found at " + driver + "\n")
        exit("1")
    }
    if !exists(mainPath) {
        printErr("socam watch: " + mainPath + " not found in cwd\n")
        exit("1")
    }
    let last = _mtimeSecs(mainPath)
    print("socam watch: monitoring " + mainPath + " (Ctrl-C to stop)")
    while true {
        let now = _mtimeSecs(mainPath)
        if now != last {
            print("socam watch: change detected (" + now + "), rebuilding...")
            _killApp(appName)
            let rc = shellRun(q(driver) + " " + q(mainPath) + " -o " + q(appName))
            if rc == "0" {
                print("socam watch: build ok — launching " + appName)
                let _ = shellRun("nohup ./" + q(appName) + " > /tmp/" + appName + ".log 2>&1 &")
            } else {
                printErr("socam watch: build FAILED (rc=" + rc + ")\n")
            }
            last = now
        }
        let _ = shellRun("sleep 1")
    }
}
