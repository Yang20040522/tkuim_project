package com.rehabassist.rehabassist.actions

// 這是動作卡匣用來遙控 TrainingActivity (主機) 的遙控器
interface RehabActionCallback {
    // 控制畫面上的文字
    fun updateUI(title: String? = null, instruction: String? = null, feedback: String? = null, repCount: String? = null, accuracy: String? = null)

    // 控制語音播報
    fun speak(text: String, isUrgent: Boolean = false)
    fun speakCount(count: Int)

    // ✨ 這裡修改了！通知主機：訓練完成，並且「繳交這回合的訓練紀錄」
    fun onTrainingComplete(report: TrainingReport)
}