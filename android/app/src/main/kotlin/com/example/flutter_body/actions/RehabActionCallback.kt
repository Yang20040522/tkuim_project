package com.example.flutter_body.actions

interface RehabActionCallback {
    fun updateUI(title: String? = null, instruction: String? = null, feedback: String? = null, repCount: String? = null, accuracy: String? = null)
    fun speak(text: String, isUrgent: Boolean = false)
    fun speakCount(count: Int)
    fun onTrainingComplete(report: TrainingReport)
    fun setGuideLineVisible(visible: Boolean)
    fun setPinchGuideEnabled(visible: Boolean)
    fun updateProgress(progress: Float, speedState: Int)
    fun setSkeletonMode(mode: String = "FULL_BODY")
}