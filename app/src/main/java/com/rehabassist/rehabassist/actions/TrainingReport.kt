package com.rehabassist.rehabassist.actions

// 這是專門用來裝載「訓練紀錄」的資料結構
data class TrainingReport(
    val actionName: String,         // 動作名稱 (例如: 翻掌訓練)
    val difficulty: Int,            // 難度等級 (例如: 1)
    val totalReps: Int,             // 完成總次數 (例如: 10)
    val durationSeconds: Long,      // 這次訓練花了幾秒
    val mistakeLogs: List<String>   // 🌟 失敗或錯誤的詳細紀錄清單！
)