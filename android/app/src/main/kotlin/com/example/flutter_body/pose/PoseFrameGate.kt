package com.example.flutter_body.pose

/** One outstanding inference per camera session. Closing never permits a late acquisition. */
internal class PoseFrameGate(private val minimumIntervalMs: Long = 67L) {
    private var closed = false
    private var pendingTimestamp: Long? = null
    private var lastAccepted: Long? = null

    @Synchronized
    fun acquire(timestampMs: Long): Boolean {
        if (closed || pendingTimestamp != null) return false
        val previous = lastAccepted
        if (previous != null && timestampMs - previous < minimumIntervalMs) return false
        lastAccepted = timestampMs
        pendingTimestamp = timestampMs
        return true
    }

    @Synchronized
    fun release(timestampMs: Long) {
        if (pendingTimestamp == timestampMs) pendingTimestamp = null
    }

    @Synchronized
    fun close() {
        closed = true
        pendingTimestamp = null
    }
}
