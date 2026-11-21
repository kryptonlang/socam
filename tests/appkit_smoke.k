// tests/appkit_smoke.k — exercise the socam AppKit adapter end-to-end on screen.
//
// Builds a window through appkitWindow/appkitAddBox, runs the scene+scheduler
// core through the adapter, and auto-quits after 1.5s. Mirror of
// examples/socam_macos_smoke.k but routed through the adapter boundary.
//
//   KRYPTON_ROOT=/…/krypton kcc tests/appkit_smoke.k -o /tmp/appkit_smoke && /tmp/appkit_smoke
//
// Expected: window appears ~1.5s, auto-quit, rc=0.

import "src/socam/appkit_adapter.k"
import "src/socam/geometry.k"
import "src/socam/layout.k"
import "src/socam/view.k"
import "src/socam/dirtyrect.k"
import "src/socam/scheduler.k"
import "k:choc_macos"

just run {
    // — headless scene-core checks (same assertions as view_test) —
    let scene = sceneNew()
    let r = createView(scene, 0 - 1, 0, 0, 480, 320, 0, 1, "root")
    scene = getField(r, "scene")
    let rootIdx = getField(r, "idx")
    let c1 = createView(scene, rootIdx, 24, 24, 160, 120, AUTORESIZE_WidthSizable, 1, "flex")
    scene = getField(c1, "scene")
    let flexIdx = getField(c1, "idx")
    if sceneCount(scene) == 2 { print("appkit-smoke: scene core OK") }
    scene = sceneResize(scene, rootIdx, 520, 320)
    if W(viewFrame(scene, flexIdx)) == 296 { print("appkit-smoke: springs OK") }

    // — on-screen adapter —
    let w = appkitWindow("socam — adapter smoke", 480, 320)
    let app = getField(w, "app")
    let win = getField(w, "win")
    let sched = getField(w, "sched")
    scene = getField(w, "scene")
    let viewReg = getField(w, "viewReg")
    rootIdx = getField(w, "rootIdx")

    let red   = chocRGB(217, 89, 77)
    let blue  = chocRGB(77, 140, 230)
    let green = chocRGB(77, 191, 102)

    let b1 = appkitAddBox(viewReg, scene, rootIdx, 24, 24, 160, 120, AK_MASK_FIXED, red, "red")
    scene = getField(b1, "scene")
    viewReg = getField(b1, "viewReg")
    let b2 = appkitAddBox(viewReg, scene, rootIdx, 200, 24, 256, 120, AK_MASK_FLEX_W, blue, "blue")
    scene = getField(b2, "scene")
    viewReg = getField(b2, "viewReg")
    let b3 = appkitAddBox(viewReg, scene, rootIdx, 24, 212, 432, 56, AK_MASK_FLEX_TOP, green, "green")
    scene = getField(b3, "scene")
    viewReg = getField(b3, "viewReg")

    // resize window: flex box should grow 256 → 296 via adapter setFrame
    scene = appkitSetFrame(scene, viewReg, getField(b2, "viewIdx"), Rect(200, 24, 296, 120))

    // invalidate red box → damage queued
    let inv = appkitInvalidate(scene, sched, viewReg, getField(b1, "viewIdx"), Rect(0, 0, 10, 10))
    scene = getField(inv, "scene")
    sched = getField(inv, "sched")

    // one render frame: scheduler begins, NSViews invalidated, ends
    sched = appkitRenderFrame(sched, scene, viewReg)

    // text field with change callback
    let tf = appkitAddTextField(viewReg, scene, rootIdx, 24, 280, 200, 24, "input")
    scene = getField(tf, "scene")
    viewReg = getField(tf, "viewReg")
    let tfView = getField(tf, "textField")
    appkitTextFieldOnChange(tfView, funcptr(_akTextChanged))
    appkitSetTextFieldValue(tfView, "hello")
    if appkitTextFieldValue(tfView) == "hello" { print("appkit-smoke: text field OK") }

    appkitShow(app, win)
    print("appkit-smoke: window shown")

    // auto-quit timer
    let tcls = chocClassNew("SocamAppKitTimer")
    chocClassAddMethod(tcls, "krAutoQuit:", funcptr(_akAutoQuit), "v@:@")
    chocClassRegister(tcls)
    chocTimer(chocNew(tcls), "krAutoQuit:", 1500)

    appkitRun(app)
    print("appkit-smoke: PASS")
}

func _akAutoQuit(self, cmd, sender) {
    chocQuit(chocSharedApp())
    emit 0
}

func _akTextChanged(textField) {
    print("appkit-smoke: text changed -> " + appkitTextFieldValue(textField))
    emit 0
}
