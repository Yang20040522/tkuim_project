package com.rehabassist.rehabassist.actions

import com.google.mediapipe.tasks.components.containers.NormalizedLandmark

// 這是所有復健動作的「共同樣板」
abstract class BaseRehabAction(protected val callback: RehabActionCallback) {

    // 每個動作共用的變數（可以根據需要增加）
    protected var repCount = 0
    protected var lastRepTime = 0L
    protected val smoothingFactor = 0.2

    // 強制規定：每一個繼承這個樣板的動作，都必須自己寫一套處理骨架的邏輯
    abstract fun processLandmarks(landmarks: List<NormalizedLandmark>)
}