package com.rehabassist.rehabassist.actions

// 這是動作卡匣用來遙控 TrainingActivity (主機) 的遙控器
interface RehabActionCallback {
    // 控制畫面上的文字
    fun updateUI(title: String? = null, instruction: String? = null, feedback: String? = null, repCount: String? = null, accuracy: String? = null)

    // 控制語音播報
    fun speak(text: String, isUrgent: Boolean = false)
    fun speakCount(count: Int)

    // 通知主機：訓練完成，並且「繳交這回合的訓練紀錄」
    fun onTrainingComplete(report: TrainingReport)

    // 控制翻掌準備階段的輔助對齊線
    fun setGuideLineVisible(visible: Boolean)

    // ✨ 控制側捏準備與特效階段的開關
    fun setPinchGuideEnabled(visible: Boolean)

    // 更新進度條與速度狀態 (0:正常, 1:太快警告)
    fun updateProgress(progress: Float, speedState: Int)

    // ✨ 新增這行：控制要顯示哪種骨架模式 ("FULL_BODY", "UPPER_BODY", "ARMS_ONLY")
    fun setSkeletonMode(mode: String = "FULL_BODY")
}