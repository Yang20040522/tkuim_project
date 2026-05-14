package com.example.flutter_body.actions

import com.google.mediapipe.tasks.components.containers.NormalizedLandmark

abstract class BaseRehabAction(protected val callback: RehabActionCallback) {

    protected var repCount = 0
    protected var lastRepTime = 0L
    protected val smoothingFactor = 0.2

    protected val repScores = mutableListOf<Int>()
    protected var currentRepMaxWobble = 0.0

    fun getFinalScore(): Int {
        if (repScores.isEmpty()) return 0
        return repScores.average().toInt()
    }

    abstract fun processLandmarks(landmarks: List<NormalizedLandmark>)
}