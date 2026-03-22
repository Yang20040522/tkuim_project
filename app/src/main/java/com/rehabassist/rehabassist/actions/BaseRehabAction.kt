package com.rehabassist.rehabassist.actions

import com.google.mediapipe.tasks.components.containers.NormalizedLandmark

abstract class BaseRehabAction(protected val callback: RehabActionCallback) {

    protected var repCount = 0
    protected var lastRepTime = 0L
    protected val smoothingFactor = 0.2

    // ✨ 專題核心：動態評分系統 (儲存每次的分數)
    protected val repScores = mutableListOf<Int>()
    // ✨ 專題核心：代償動作偵測 (紀錄單次動作中，手腕的最大晃動角度)
    protected var currentRepMaxWobble = 0.0

    // 取得平均總分
    fun getFinalScore(): Int {
        if (repScores.isEmpty()) return 0
        return repScores.average().toInt()
    }

    abstract fun processLandmarks(landmarks: List<NormalizedLandmark>)
}