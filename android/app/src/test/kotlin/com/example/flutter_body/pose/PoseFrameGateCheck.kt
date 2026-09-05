package com.example.flutter_body.pose

/** Dependency-free JVM checks. Run through tools/test_pose_frame_gate.ps1. */
fun main() {
    val gate = PoseFrameGate(67L)
    check(gate.acquire(1000L)) { "first frame must be accepted" }
    check(!gate.acquire(1100L)) { "busy detector must drop a later frame" }
    gate.release(999L)
    check(!gate.acquire(1200L)) { "stale callback must not release current inference" }
    gate.release(1000L)
    check(!gate.acquire(1000L)) { "duplicate timestamp must be rejected" }
    check(!gate.acquire(999L)) { "timestamp must be monotonic" }
    check(!gate.acquire(1066L)) { "camera preview FPS must not drive inference FPS" }
    check(gate.acquire(1067L)) { "next frame at throttle boundary must be accepted" }
    gate.close()
    gate.release(1067L)
    check(!gate.acquire(2000L)) { "late callback must never reopen a closed session" }
    gate.close()
    val reopened = PoseFrameGate(67L)
    check(reopened.acquire(2000L)) { "a new session must initialize independently" }
    reopened.release(2000L)
    check(reopened.acquire(2067L)) { "new session must continue normally" }
    println("PoseFrameGate: 10 checks passed")
}
