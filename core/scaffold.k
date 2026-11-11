// core/scaffold.k — project scaffolding for the app template.
//
// Milestone 1: `socam new app <Name>` generates a self-contained AppKit-ready
// Krypton workspace: main.k (NSApplication boilerplate), Info.plist (bundle
// metadata) and Makefile (one-command build with kcc).

module scaffold

import "k:fsx"

func writeOnce(path, body) {
    if exists(path) == "1" {
        printErr("socam: " + path + " already exists\n")
        exit("1")
    }
    writeText(path, body)
}

func newAppApp(name) {
    if exists(name) == "1" {
        print("socam new app: " + name + " already exists\n")
        exit("1")
    }
    if contains(name, "/") || contains(name, " ") {
        print("socam new app: project name must not contain spaces or slashes\n")
        exit("1")
    }

    // Self-creating parent directory from caller cwd
    mkdirp(name)

    let main =
        "// " + name + " - Krypton AppKit starter\n" +
        "\n" +
        "import \"k:okui\"\n" +
        "\n" +
        "func target() {\n" +
        "    print(\"click!\")\n" +
        "    emit 0\n" +
        "}\n" +
        "\n" +
        "just run {\n" +
        "    let pool = okAutoreleasePool()\n" +
        "    let app = okApp()\n" +
        "    let win = okWindow(app, \"" + name + "\", 460, 240)\n" +
        "    let label = okLabel(win, \"" + name + " — rendered by Krypton + Objective-K\", 20, 20, 420, 28)\n" +
        "    okShow(win, app)\n" +
        "    okRun(app)\n" +
        "    okDrainPool(pool)\n" +
        "}\n"

    let plist =
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
        "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n" +
        "<plist version=\"1.0\">\n" +
        "<dict>\n" +
        "    <key>CFBundleIdentifier</key><string>com.example." + name + "</string>\n" +
        "    <key>CFBundleShortVersionString</key><string>0.1.0</string>\n" +
        "    <key>CFBundleVersion</key><string>0.1.0</string>\n" +
        "    <key>CFBundleName</key><string>" + name + "</string>\n" +
        "    <key>CFBundleExecutable</key><string>" + name + "</string>\n" +
        "    <key>CFBundlePackageType</key><string>APPL</string>\n" +
        "    <key>LSMinimumSystemVersion</key><string>14.0</string>\n" +
        "    <key>NSPrincipalClass</key><string>NSApplication</string>\n" +
        "</dict>\n" +
        "</plist>\n"

    let makefile =
        "KRYPTON_ROOT ?= /usr/local/krypton\n" +
        "APP          := " + name + "\n" +
        "\n" +
        ".PHONY: build run clean\n" +
        "\n" +
        "build: main.k\n" +
        "\tKRYPTON_ROOT=$(KRYPTON_ROOT) $(KRYPTON_ROOT)/bootstrap/kcc_driver_macos_aarch64 main.k -o $(APP)\n" +
        "\n" +
        "run: build\n" +
        "\t./$(APP)\n" +
        "\n" +
        "clean:\n" +
        "\trm -f $(APP)\n" +
        "\n"

    writeOnce(name + "/main.k", main)
    writeOnce(name + "/Info.plist", plist)
    writeOnce(name + "/Makefile", makefile)
    print("socam: scaffolded " + name + "/  (main.k, Info.plist, Makefile)")
    print("run:     cd " + name + " && make")
}
