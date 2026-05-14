package com.example.flutter_body.actions

data class TrainingReport(
    val actionName: String,
    val difficulty: Int,
    val totalReps: Int,
    val durationSeconds: Long,
    val mistakeLogs: List<String>
)