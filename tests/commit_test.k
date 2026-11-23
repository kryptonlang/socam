// tests/commit_test.k — pure-Krypton commit planning, headless.
//   KRYPTON_ROOT=/Users/t3m3d/Documents/GitHub/krypton \\
//     kcc tests/commit_test.k -o /tmp/ct && /tmp/ct
import "src/socam/geometry.k"
import "src/socam/dirtyrect.k"
import "src/socam/scheduler.k"
import "src/socam/commit.k"
import "k:assert"

just run {
    // — scale —
    let r = commitScaleRect(2, Rect(10, 20, 30, 40))
    assertEqual(X(r), 20, "scale x")
    assertEqual(Y(r), 40, "scale y")
    assertEqual(W(r), 60, "scale w")
    assertEqual(H(r), 80, "scale h")
    let r1 = commitScaleRect(1, Rect(5, 6, 7, 8))
    assertEqual(X(r1), 5, "scale1 x")
    assertEqual(Y(r1), 6, "scale1 y")
    assertEqual(W(r1), 7, "scale1 w")
    assertEqual(H(r1), 8, "scale1 h")

    // — union area —
    let s = schedNew()
    assertEqual(commitUnionArea(s), 0, "empty area is 0")
    s = schedAddDamage(s, Rect(0, 0, 1600, 1000))
    // 1,600,000 * 10 > 1920 * 1080 * 7 -> full
    assertEqual(commitFullDamage(s, 1920, 1080), 1, "big rect is full damage")
    s = schedNew()
    s = schedAddDamage(s, Rect(0, 0, 100, 100))
    s = schedAddDamage(s, Rect(900, 900, 50, 50))
    // union area = 950 * 950 = 902,500 * 10 = 9,025,000 < 14,515,200 -> partial
    assertEqual(commitFullDamage(s, 1920, 1080), 0, "small rects are partial damage")

    // — configure (xdg_toplevel.configure, client response) —
    let c1 = commitConfigure(480, 320, 520, 340)
    assertEqual(toInt(getField(c1, "changed")), 1, "configure changed")
    assertEqual(toInt(getField(c1, "w")), 520, "configure w")
    assertEqual(toInt(getField(c1, "h")), 340, "configure h")
    // zero = compositor chose, keep current size
    let c2 = commitConfigure(480, 320, 0, 0)
    assertEqual(toInt(getField(c2, "changed")), 0, "configure zero is no-op")
    assertEqual(toInt(getField(c2, "w")), 480, "configure keeps w")
    // same size
    let c3 = commitConfigure(480, 320, 480, 320)
    assertEqual(toInt(getField(c3, "changed")), 0, "configure same size")

    print("commit-test: PASS")
}
