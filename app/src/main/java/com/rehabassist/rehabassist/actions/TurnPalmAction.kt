package com.rehabassist.rehabassist.actions

import android.os.SystemClock
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark

class TurnPalmAction(callback: RehabActionCallback) : BaseRehabAction(callback) {

    // 狀態與階段控制
    private var currentStage = 1
    private var isTransitioning = false
    private var transitionStartTime = 0L
    private var lastCountdownSec = -1

    // 階段一：穩定度專用變數
    private var smoothedAngleStage1 = 0.0
    private var holdStartTime = 0L
    private var isCurrentlyStable = false

    // 階段二：翻掌專用變數
    private var smoothedAngleStage2 = 0.0
    private var palmStateBuffer = mutableListOf<String>()
    private var lastConfirmedState = ""

    init {
        // 卡匣一插上，立刻設定階段一的畫面
        callback.updateUI(
            title = "初階翻掌訓練 - 階段一：穩定度",
            instruction = "請握住棍子保持直立 5 秒",
            repCount = "0.0s / 5.0s",
            accuracy = "--"
        )
    }

    override fun processLandmarks(landmarks: List<NormalizedLandmark>) {
        if (isTransitioning) {
            handleTransition()
            return
        }

        when (currentStage) {
            1 -> detectStage1(landmarks)
            2 -> detectStage2(landmarks)
        }
    }

    private fun handleTransition() {
        val elapsed = SystemClock.uptimeMillis() - transitionStartTime
        if (elapsed < 3000L) {
            val remain = 3 - (elapsed / 1000).toInt()
            callback.updateUI(
                feedback = "⏳ 準備進入階段二",
                instruction = "請在 $remain 秒後開始上下翻掌"
            )

            // 倒數語音
            if (remain != lastCountdownSec && remain > 0) {
                callback.speak(remain.toString(), isUrgent = true)
                lastCountdownSec = remain
            }
        } else {
            // 轉場結束，進入階段二
            isTransitioning = false
            currentStage = 2
            repCount = 0
            lastRepTime = SystemClock.uptimeMillis()
            palmStateBuffer.clear()
            lastConfirmedState = ""
            lastCountdownSec = -1

            callback.updateUI(
                title = "初階翻掌訓練 - 階段二：翻掌",
                repCount = "0 / 10",
                instruction = "請將掌心朝上作為起點"
            )
            callback.speak("開始翻掌", isUrgent = true)
        }
    }

    private fun detectStage1(landmarks: List<NormalizedLandmark>) {
        val wrist = landmarks[0]
        val middleMcp = landmarks[9]
        val dx = (middleMcp.x() - wrist.x()).toDouble()
        val dy = (middleMcp.y() - wrist.y()).toDouble()
        val angle = Math.toDegrees(Math.atan2(dy, dx))
        val deviation = Math.abs(angle - (-90.0))
        val rawDev = if (deviation > 180) 360 - deviation else deviation

        smoothedAngleStage1 = (smoothingFactor * rawDev) + ((1 - smoothingFactor) * smoothedAngleStage1)
        val displayAngle = smoothedAngleStage1.toInt()

        callback.updateUI(accuracy = "${displayAngle}°")

        val targetHoldTime = 5000L

        if (displayAngle < 20) {
            if (!isCurrentlyStable) {
                isCurrentlyStable = true
                holdStartTime = SystemClock.uptimeMillis()
                callback.updateUI(feedback = "✅ 很好！保持住")
            } else {
                val duration = SystemClock.uptimeMillis() - holdStartTime
                val seconds = duration / 1000.0
                callback.updateUI(
                    instruction = "請保持直立不要晃動",
                    repCount = String.format("%.1fs / 5.0s", seconds)
                )

                if (duration >= targetHoldTime) {
                    isCurrentlyStable = false
                    isTransitioning = true
                    transitionStartTime = SystemClock.uptimeMillis()

                    callback.updateUI(
                        title = "初階翻掌訓練 - 階段一完成",
                        feedback = "🎉 穩定度測試通過！",
                        repCount = ""
                    )
                    callback.speak("穩定度通過，準備轉場", isUrgent = true)
                }
            }
        } else {
            isCurrentlyStable = false
            val direction = if (dx > 0) "往右倒了" else "往左倒了"
            callback.updateUI(
                feedback = "⚠️ $direction",
                instruction = "請拉正以恢復計時",
                repCount = "0.0s / 5.0s"
            )
            callback.speak("請拿正", isUrgent = true)
        }
    }

    private fun detectStage2(landmarks: List<NormalizedLandmark>) {
        val indexMcp = landmarks[5]
        val pinkyMcp = landmarks[17]
        val dx = (pinkyMcp.x() - indexMcp.x()).toDouble()
        val dy = (pinkyMcp.y() - indexMcp.y()).toDouble()
        val rawAngle = Math.toDegrees(Math.atan2(dy, dx))
        val normAngle = (rawAngle + 360) % 360

        smoothedAngleStage2 = (smoothingFactor * normAngle) + ((1 - smoothingFactor) * smoothedAngleStage2)
        callback.updateUI(accuracy = "${smoothedAngleStage2.toInt()}°")

        val state = when {
            smoothedAngleStage2 in 140.0..220.0 -> "UP"
            smoothedAngleStage2 < 40.0 || smoothedAngleStage2 > 320.0 -> "DOWN"
            else -> "MID"
        }

        palmStateBuffer.add(state)
        if (palmStateBuffer.size > 8) palmStateBuffer.removeAt(0)

        // 核心邏輯：DOWN -> UP 算 1 個循環
        if (palmStateBuffer.count { it == "UP" } >= 6 && lastConfirmedState != "UP") {
            if (lastConfirmedState == "DOWN") {
                val now = SystemClock.uptimeMillis()
                if (now - lastRepTime > 1200L) {
                    repCount++
                    lastRepTime = now
                    callback.speakCount(repCount)
                    callback.updateUI(feedback = "✅ 完成一次！")
                } else {
                    lastRepTime = now
                    callback.speak("太快了", isUrgent = true)
                    callback.updateUI(feedback = "⚠️ 動作太快")
                }
            } else {
                callback.updateUI(feedback = "✅ 掌心朝上")
            }
            lastConfirmedState = "UP"
            callback.updateUI(instruction = "請將掌心往下翻")

        } else if (palmStateBuffer.count { it == "DOWN" } >= 6 && lastConfirmedState != "DOWN") {
            callback.updateUI(feedback = "✅ 掌心朝下", instruction = "很好，請將掌心往上翻")
            lastConfirmedState = "DOWN"

        } else if (state == "MID") {
            if (lastConfirmedState == "UP") callback.updateUI(instruction = "往下翻轉中...")
            else if (lastConfirmedState == "DOWN") callback.updateUI(instruction = "往上翻轉中...")
        }

        callback.updateUI(repCount = "$repCount / 10")

        // 判斷是否訓練結束
        if (repCount >= 10) {
            callback.onTrainingComplete()
        }
    }
}