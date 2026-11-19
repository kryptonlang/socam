// tests/scheduler_test.k — frame redraw scheduler state machine, headless.
// Simulates a compositor: bursts of damage, single-flight gating, follow-up
// frames, teardown. No OS calls; platform backends plug into the same contract.
import "socam/geometry.k"
import "socam/dirtyrect.k"
import "socam/scheduler.k"
import "k:assert"

just run {
    let sched = schedNew()
    assertEqual(schedState(sched), SCHED_IDLE, "fresh scheduler is IDLE")
    assertEqual(schedNeedsFrame(sched), 0, "no damage, no frame")
    assertEqual(schedFrameCount(sched), 0, "zero frames committed")

    // burst of damage: 5 overlapping + 1 disjoint rect
    sched = schedAddDamage(sched, Rect(0, 0, 10, 10))
    sched = schedAddDamage(sched, Rect(2, 2, 20, 20))
    sched = schedAddDamage(sched, Rect(4, 4, 30, 30))
    sched = schedAddDamage(sched, Rect(1, 1, 5, 5))
    sched = schedAddDamage(sched, Rect(500, 500, 10, 10))
    assertEqual(schedIsDirty(sched), 1, "damage marks dirty")
    assertEqual(schedNeedsFrame(sched), 1, "dirty + IDLE -> frame owed")

    // begin: snapshot is coalesced, gate flips to IN_FLIGHT
    let b = schedBeginFrame(sched)
    sched = getField(b, "sched")
    let snap = getField(b, "damage")
    assertEqual(getField(b, "started"), 1, "frame started")
    assertEqual(schedState(sched), SCHED_IN_FLIGHT, "in flight after begin")
    assertEqual(schedFrameCount(sched), 1, "one frame counted")
    assertTrue(damageCount(snap) >= 1, "snapshot carries damage")
    assertTrue(damageCount(snap) <= 8, "snapshot respects the cap")
    assertEqual(schedIsDirty(sched), 0, "dirty cleared at frame start")

    // damage DURING flight: no new frame until completion
    sched = schedAddDamage(sched, Rect(800, 800, 40, 40))
    assertEqual(schedState(sched), SCHED_IN_FLIGHT, "still in flight")
    assertEqual(schedNeedsFrame(sched), 0, "single-flight gate holds")

    // begin called while in flight: no-op
    let b2 = schedBeginFrame(sched)
    sched = getField(b2, "sched")
    assertEqual(getField(b2, "started"), 0, "begin during flight is a no-op")

    // compositor fires frame-done: back to IDLE, follow-up frame owed
    sched = schedEndFrame(sched)
    assertEqual(schedState(sched), SCHED_IDLE, "idle after frame done")
    assertEqual(schedNeedsFrame(sched), 1, "damage during flight owes a follow-up frame")

    // render the follow-up frame
    let b3 = schedBeginFrame(sched)
    sched = getField(b3, "sched")
    assertEqual(getField(b3, "started"), 1, "follow-up frame started")
    sched = schedEndFrame(sched)
    assertEqual(schedNeedsFrame(sched), 0, "no damage left — loop can idle")
    assertEqual(schedFrameCount(sched), 2, "two frames committed")

    // stale callback on CANCELLED scheduler: no state change
    let sched2 = schedNew()
    sched2 = schedAddDamage(sched2, Rect(0, 0, 10, 10))
    sched2 = schedCancel(sched2)
    assertEqual(schedIsCancelled(sched2), 1, "cancel transitions to CANCELLED")
    assertEqual(schedIsDirty(sched2), 0, "cancel drops pending damage")
    sched2 = schedAddDamage(sched2, Rect(10, 10, 5, 5))
    assertEqual(schedIsDirty(sched2), 0, "damage after cancel is dropped")
    assertEqual(schedNeedsFrame(sched2), 0, "no frame owed after cancel")
    let b4 = schedBeginFrame(sched2)
    assertEqual(getField(b4, "started"), 0, "begin after cancel is a no-op")
    let sched3 = schedEndFrame(sched2)
    assertEqual(schedState(sched3), SCHED_CANCELLED, "stale frame-done cannot resurrect scheduler")

    // cancel MID-flight: in-flight state collapses to CANCELLED
    let sched4 = schedNew()
    sched4 = schedAddDamage(sched4, Rect(0, 0, 10, 10))
    let b5 = schedBeginFrame(sched4)
    sched4 = getField(b5, "sched")
    sched4 = schedCancel(sched4)
    assertEqual(schedState(sched4), SCHED_CANCELLED, "cancel wins over in-flight")
    let sched5 = schedEndFrame(sched4)
    assertEqual(schedState(sched5), SCHED_CANCELLED, "frame-done after cancel stays CANCELLED")

    print("--- scheduler suite finished")
}
