// tests/view_test.k — view tree + springs layout + damage + responder chain.
// Headless: no OS calls. Pure Krypton.
import "socam/geometry.k"
import "socam/layout.k"
import "socam/dirtyrect.k"
import "socam/view.k"
import "k:assert"

just run {
    let scene = sceneNew()

    let r = createView(scene, 0 - 1, 0, 0, 200, 100, 0, 1, "root")
    scene = getField(r, "scene")
    let root = getField(r, "idx")

    let c1 = createView(scene, root, 10, 10, 50, 30, AUTORESIZE_WidthSizable, 1, "flexbtn")
    scene = getField(c1, "scene")
    let flexBtn = getField(c1, "idx")

    let c2 = createView(scene, root, 150, 10, 40, 30, AUTORESIZE_MinXMargin, 1, "pinright")
    scene = getField(c2, "scene")
    let pinBtn = getField(c2, "idx")

    let c3 = createView(scene, root, 10, 60, 60, 20, AUTORESIZE_MaxXMargin, 1, "topleft")
    scene = getField(c3, "scene")
    let staticBtn = getField(c3, "idx")

    let rc = createView(scene, flexBtn, 2, 2, 10, 10, 0, 1, "nested")
    scene = getField(rc, "scene")
    let nested = getField(rc, "idx")

    assertEqual(sceneCount(scene), 5, "five views created")

    // root resize 200 → 300 wide: flex grows 50→150, pinright moves +100, static stays
    scene = sceneResize(scene, root, 300, 100)
    let f1 = viewFrame(scene, flexBtn)
    assertEqual(W(f1), 150, "flex button absorbs width delta")
    assertEqual(X(f1), 10, "flex button anchored left")
    let f2 = viewFrame(scene, pinBtn)
    assertEqual(X(f2), 250, "pinright keeps distance to right edge")
    let f3 = viewFrame(scene, staticBtn)
    assertEqual(X(f3), 10, "MaxXMargin stays put")

    // nested abs rect: root(0,0) + flexBtn(10,10) + nested(2,2) = (12,12)
    let absn = viewAbsRect(scene, nested)
    assertEqual(X(absn), 12, "nested abs x accumulates ancestors")
    assertEqual(Y(absn), 12, "nested abs y accumulates ancestors")

    // responder chain: nested → flexBtn → root
    let chain = viewResponderChain(scene, nested)
    assertEqual(chain, toStr(nested) + "," + toStr(flexBtn) + "," + toStr(root), "responder chain walks to root")

    // hit test: point inside nested view → nested; point in static area → root
    let hitNested = viewHitTest(scene, Point(13, 13))
    assertEqual(hitNested, nested, "hit test picks deepest view")
    let hitRoot = viewHitTest(scene, Point(295, 95))
    assertEqual(hitRoot, root, "hit test falls back to root")

    // damage was accumulated by the resize
    let dmg = sceneDamage(scene)
    assertTrue(damageCount(dmg) >= 2, "resize queued damage rects")
    scene = sceneClearDamage(scene)
    assertEqual(damageCount(sceneDamage(scene)), 0, "sceneClearDamage empties the set")

    // setNeedsDisplayInRect marks view + queues rect
    scene = viewSetNeedsDisplayInRect(scene, flexBtn, Rect(0, 0, 5, 5))
    assertEqual(viewNeedsDisplay(scene, flexBtn), 1, "needsDisplay flag set")
    assertTrue(damageCount(sceneDamage(scene)) >= 1, "partial invalidation queued damage")

    print("--- view suite finished")
}
