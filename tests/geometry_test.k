// tests/geometry_test.k — cross-platform Socam geometry/layout/dirtyrect core.
// Pure Krypton: no OS calls; runs on macos_arm64 and linux_x86_64 alike.
//   kcc src/tests/geometry_test.k -o /tmp/geom_test && /tmp/geom_test
// Prints PASS/FAIL per assertion.

import "socam/geometry.k"
import "socam/layout.k"
import "socam/dirtyrect.k"
import "k:assert"

just run {
    let r = Rect(10, 20, 100, 50)
    assertEqual(X(r), 10, "x")
    assertEqual(Y(r), 20, "y")
    assertEqual(W(r), 100, "w")
    assertEqual(H(r), 50, "h")

    let i = RectIntersection(Rect(0, 0, 60, 60), Rect(30, 30, 100, 100))
    assertEqual(X(i), 30, "intersection x")
    assertEqual(Y(i), 30, "intersection y")
    assertEqual(W(i), 30, "intersection w")
    assertEqual(H(i), 30, "intersection h")

    let u = RectUnion(Rect(0, 0, 10, 10), Rect(25, 10, 5, 5))
    assertEqual(X(u), 0, "union x")
    assertEqual(W(u), 30, "union w")

    let e = RectIntersection(Rect(0, 0, 0, 0), Rect(5, 5, 5, 5))
    assertTrue(RectEmpty(e) == 1, "empty intersection is empty")
    assertTrue(RectContains(Point(3, 3), Rect(0, 0, 10, 10)) == 1, "contains inside")
    assertFalse(RectContains(Point(10, 3), Rect(0, 0, 10, 10)) == 1, "contains on exclusive edge")
    assertTrue(RectContainsRect(Rect(0, 0, 10, 10), Rect(2, 2, 3, 3)) == 1, "rect-in-rect contained")
    assertTrue(RectContainsRect(Rect(0, 0, 10, 10), Rect(8, 8, 5, 5)) == 0, "rect-in-rect overflowing")

    // layout — horizontal springs
    let child = Rect(10, 10, 50, 20)
    let grown = layoutChild(child, AUTORESIZE_WidthSizable, 100, 100, 120, 100)
    assertEqual(W(grown), 70, "WidthSizable absorbs container growth")
    assertEqual(X(grown), 10, "WidthSizable keeps left margin")

    let fixed = layoutChild(child, 0, 100, 100, 120, 100)
    assertEqual(X(fixed), 10, "no springs: x unchanged")
    assertEqual(W(fixed), 50, "no springs: w unchanged")

    let minXm = layoutChild(child, AUTORESIZE_MinXMargin, 100, 100, 120, 100)
    assertEqual(X(minXm), 30, "MinXMargin absorbs growth (pins to right)")

    let maxXm = layoutChild(child, AUTORESIZE_MaxXMargin, 100, 100, 120, 100)
    assertEqual(X(maxXm), 10, "MaxXMargin pins to left")

    let both = layoutChild(child, AUTORESIZE_MinXMargin + AUTORESIZE_MaxXMargin, 100, 100, 120, 100)
    assertEqual(X(both), 20, "both margins split growth equally")

    let mixed = layoutChild(child, AUTORESIZE_MinXMargin + AUTORESIZE_WidthSizable, 100, 100, 120, 100)
    assertEqual(X(mixed), 20, "mixed springs: margin share")
    assertEqual(W(mixed), 60, "mixed springs: width share")

    let shrunk = layoutChild(child, AUTORESIZE_WidthSizable, 100, 100, 80, 100)
    assertEqual(W(shrunk), 30, "WidthSizable shrinks with container")

    // layout — vertical springs
    let vchild = Rect(10, 10, 50, 20)
    let vgrown = layoutChild(vchild, AUTORESIZE_HeightSizable, 100, 100, 100, 130)
    assertEqual(H(vgrown), 50, "HeightSizable absorbs vertical growth")
    let vmove = layoutChild(vchild, AUTORESIZE_MinYMargin, 100, 100, 100, 130)
    assertEqual(Y(vmove), 40, "MinYMargin absorbs vertical growth")
    let vpin = layoutChild(vchild, AUTORESIZE_MaxYMargin, 100, 100, 100, 130)
    assertEqual(Y(vpin), 10, "MaxYMargin pins to top")

    // dirty-rect coalescing
    let d = damageNew()
    d = damageAdd(d, Rect(0, 0, 10, 10))
    d = damageAdd(d, Rect(5, 5, 10, 10))   // overlaps first? no: extends to 15 — kept
    d = damageAdd(d, Rect(1, 1, 2, 2))     // fully inside first — dropped
    let c = damageCoalesce(d)
    assertEqual(damageCount(c), 2, "fully-contained rect dropped")

    let d2 = damageNew()
    let k = 0
    while k < 9 {
        d2 = damageAdd(d2, Rect(k * 10, 0, 5, 5))
        k = k + 1
    }
    let c2 = damageCoalesce(d2)
    assertEqual(damageCount(c2), 1, "overflow coalesces to one bounding rect")
    assertEqual(W(damageRectAt(c2, 0)), 85, "bounding union width")

    let d3 = damageNew()
    d3 = damageAdd(d3, Rect(0, 0, 0, 5))   // empty w — dropped
    assertEqual(damageCount(d3), 0, "empty rect not queued")

    print("--- geometry/layout/dirtyrect suite finished")
}
