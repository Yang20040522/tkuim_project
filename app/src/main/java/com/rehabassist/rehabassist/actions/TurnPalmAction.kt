package com.rehabassist.rehabassist.actions

import android.os.SystemClock
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark

class TurnPalmAction(
    callback: RehabActionCallback,
    private val startingLevel: Int = 1
) : BaseRehabAction(callback) {

    private val mistakeLogs = mutableListOf<String>()
    private var sessionStartTime = 0L
    private var currentLevel = 1
    private var currentStage = 1
    private var isTransitioning = false
    private var transitionStartTime = 0L
    private var lastCountdownSec = -1

    private var smoothedAngleStage1 = 0.0
    private var holdStartTime = 0L
    private var isCurrentlyStable = false

    private var palmStateBuffer = mutableListOf<String>()
    private var lastConfirmedState = ""

    init {
        startLevel(startingLevel)
    }

    private fun startLevel(level: Int) {
        currentLevel = level
        repCount = 0
        repScores.clear()
        palmStateBuffer.clear()
        lastConfirmedState = ""
        currentStage = 1
        mistakeLogs.clear()
        sessionStartTime = System.currentTimeMillis()

        // ✨ 階段一開始：打開輔助線
        callback.setGuideLineVisible(true)

        val difficultyText = if (level == 1) "初階" else "中階 (幅度加大)"
        callback.updateUI(
            title = "$difficultyText 翻掌 - 階段一：穩定棍子",
            instruction = "請握住短棍，對齊虛線保持直立 5 秒",
            repCount = "0.0s / 5.0s",
            accuracy = "--"
        )
        val levelSpeech = if (level == 1) "第一關，請拿穩短棍，對齊中間虛線" else "第二關，難度提升，請拿穩"
        callback.speak(levelSpeech, isUrgent = true)
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
            callback.updateUI(feedback = "⏳ 準備進入階段二", instruction = "請在 $remain 秒後開始練習內外轉")
            if (remain != lastCountdownSec && remain > 0) {
                callback.speak(remain.toString(), isUrgent = true)
                lastCountdownSec = remain
            }
        } else {
            isTransitioning = false
            currentStage = 2
            lastRepTime = SystemClock.uptimeMillis()

            callback.updateUI(title = "翻掌 Lv.$currentLevel - 階段二：內外翻轉", repCount = "0 / 10", instruction = "請握住短棍，輕輕向內轉")
            callback.speak("開始轉動", isUrgent = true)
        }
    }

    private fun detectStage1(landmarks: List<NormalizedLandmark>) {
        val indexMcp = landmarks[5]
        val pinkyMcp = landmarks[17]

        val dx = (indexMcp.x() - pinkyMcp.x()).toDouble()
        val dy = (indexMcp.y() - pinkyMcp.y()).toDouble()
        val angle = Math.toDegrees(Math.atan2(dy, dx))
        val deviation = Math.abs(angle - (-90.0))
        val rawDev = if (deviation > 180) 360 - deviation else deviation

        smoothedAngleStage1 = (smoothingFactor * rawDev) + ((1 - smoothingFactor) * smoothedAngleStage1)
        val displayAngle = smoothedAngleStage1.toInt()

        callback.updateUI(accuracy = "傾斜: ${displayAngle}°")

        val wobbleTolerance = if (currentLevel == 1) 25 else 15

        if (displayAngle < wobbleTolerance) {
            if (!isCurrentlyStable) {
                isCurrentlyStable = true
                holdStartTime = SystemClock.uptimeMillis()
                callback.updateUI(feedback = "✅ 很好！穩住棍子")
            } else {
                val duration = SystemClock.uptimeMillis() - holdStartTime
                callback.updateUI(instruction = "請出點力，保持直立不要晃動", repCount = String.format("%.1fs / 5.0s", duration / 1000.0))
                if (duration >= 5000L) {
                    isCurrentlyStable = false
                    isTransitioning = true
                    transitionStartTime = SystemClock.uptimeMillis()
                    callback.updateUI(title = "階段一完成", feedback = "🎉 穩定度測試通過！", repCount = "")

                    // ✨ 階段一通過：關閉輔助線
                    callback.setGuideLineVisible(false)
                    callback.speak("穩定通過，準備轉場", isUrgent = true)
                }
            }
        } else {
            isCurrentlyStable = false
            val direction = if (dx > 0) "棍子歪了！" else "棍子歪了！"
            callback.updateUI(feedback = "⚠️ $direction", instruction = "請拉正短棍，對齊虛線", repCount = "0.0s / 5.0s")
        }
    }

    private fun detectStage2(landmarks: List<NormalizedLandmark>) {
        val wrist = landmarks[0]
        val middleMcp = landmarks[9]
        val indexMcp = landmarks[5]
        val pinkyMcp = landmarks[17]

        val wobbleDx = (middleMcp.x() - wrist.x()).toDouble()
        val wobbleDy = (middleMcp.y() - wrist.y()).toDouble()
        val currentWobbleAngle = Math.abs(Math.toDegrees(Math.atan2(wobbleDy, wobbleDx)) - (-90.0))
        val rawWobble = if (currentWobbleAngle > 180) 360 - currentWobbleAngle else currentWobbleAngle
        if (rawWobble > currentRepMaxWobble) currentRepMaxWobble = rawWobble

        val targetDx = if (currentLevel == 1) 0.04 else 0.08
        val dx = pinkyMcp.x() - indexMcp.x()

        // ==========================================
        // ✨ 新增：計算進度條百分比與動態配速警告
        // ==========================================
        val rawProgress = Math.abs(dx) / targetDx
        val progress = Math.min(rawProgress.toFloat(), 1.0f) // 最高 1.0 (100%)

        val now = SystemClock.uptimeMillis()
        val duration = now - lastRepTime

        // 如果轉超過一半，但花的時間不到 0.6 秒，顯示橘色警告
        val speedState = if (progress > 0.5f && duration < 600L) 1 else 0
        callback.updateProgress(progress, speedState)
        // ==========================================

        val state = when {
            dx > targetDx -> "OUTWARD"
            dx < -targetDx -> "INWARD"
            else -> "NEUTRAL"
        }

        palmStateBuffer.add(state)
        if (palmStateBuffer.size > 8) palmStateBuffer.removeAt(0)

        val isStableInward = palmStateBuffer.count { it == "INWARD" } >= 5
        val isStableOutward = palmStateBuffer.count { it == "OUTWARD" } >= 5

        if (isStableInward && lastConfirmedState != "INWARD") {
            if (lastConfirmedState == "OUTWARD") {
                if (duration > 1200L) {
                    repCount++
                    lastRepTime = now

                    var score = 100
                    if (currentRepMaxWobble > 25.0) {
                        score -= 20
                        mistakeLogs.add("第 ${repCount} 次：嚴重晃動 (偏移 ${currentRepMaxWobble.toInt()} 度)")
                    } else if (currentRepMaxWobble > 15.0) {
                        score -= 10
                        mistakeLogs.add("第 ${repCount} 次：輕微晃動")
                    }

                    if (duration < 2000L) {
                        score -= 10
                        mistakeLogs.add("第 ${repCount} 次：動作略快，未達標準復健節奏")
                    }

                    score = maxOf(score, 60)
                    repScores.add(score)
                    currentRepMaxWobble = 0.0

                    callback.speakCount(repCount)
                    callback.updateUI(feedback = "✅ 完成一次！(本次: $score 分)", instruction = "很好，現在請向外轉")
                } else {
                    lastRepTime = now
                    mistakeLogs.add("未計入次數：動作過快 (僅花費 ${duration} 毫秒)")
                    callback.speak("太快了", isUrgent = true)
                    callback.updateUI(feedback = "⚠️ 動作太快", instruction = "請慢慢轉動")
                }
            } else {
                callback.updateUI(feedback = "✅ 已向內轉", instruction = "很好，請向外轉")
            }
            lastConfirmedState = "INWARD"
            callback.updateProgress(0f, 0) // 狀態改變時重置一下視覺

        } else if (isStableOutward && lastConfirmedState != "OUTWARD") {
            callback.updateUI(feedback = "✅ 已向外轉", instruction = "很好，請向內轉")
            callback.speak("向內", isUrgent = true)
            lastConfirmedState = "OUTWARD"
            callback.updateProgress(0f, 0) // 狀態改變時重置一下視覺
        }

        callback.updateUI(repCount = "$repCount / 10", accuracy = "扭轉值: ${String.format("%.2f", dx)}")

        if (repCount >= 10) {
            val finalScore = getFinalScore()
            if (currentLevel == 1 && finalScore >= 80) {
                callback.speak("恭喜表現優異，進入中階挑戰", isUrgent = true)
                startLevel(2)
            } else {
                callback.updateUI(feedback = "🎉 訓練結束！總平均: $finalScore 分")
                val endTime = System.currentTimeMillis()
                val durationInSeconds = (endTime - sessionStartTime) / 1000
                val report = TrainingReport(
                    actionName = "翻掌訓練",
                    difficulty = currentLevel,
                    totalReps = repCount,
                    durationSeconds = durationInSeconds,
                    mistakeLogs = this.mistakeLogs.toList()
                )
                callback.onTrainingComplete(report)
            }
        }
    }
}