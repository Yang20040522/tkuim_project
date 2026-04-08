package com.rehabassist.rehabassist.actions

import android.os.SystemClock
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark

class SidePinchAction(
    callback: RehabActionCallback,
    private val startingLevel: Int = 1 // 🌟 接收首頁傳來的難度
) : BaseRehabAction(callback) {

    private val mistakeLogs = mutableListOf<String>()
    private var sessionStartTime = System.currentTimeMillis()

    private var smoothedPinchDistance = 0.0
    private var pinchStateBuffer = mutableListOf<String>()
    private var lastConfirmedPinchState = ""

    private var currentLevel = 1
    private var isTransitioning = false
    private var transitionStartTime = 0L
    private var lastCountdownSec = -1

    // Lv3 懸空偵測用的手腕座標
    private var repStartWristX = 0.0
    private var repStartWristY = 0.0

    init {
        startLevel(startingLevel)
    }

    private fun startLevel(level: Int) {
        currentLevel = level
        repCount = 0
        repScores.clear()
        pinchStateBuffer.clear()
        lastConfirmedPinchState = ""
        isTransitioning = true
        transitionStartTime = SystemClock.uptimeMillis()
        mistakeLogs.clear()
        sessionStartTime = System.currentTimeMillis()

        // ✨ 告訴主機打開側捏視覺引導
        callback.setPinchGuideEnabled(true)

        val levelName = when (level) {
            1 -> "初階 (微幅動作)"
            2 -> "中階 (標準側捏)"
            3 -> "進階 (懸空連擊)"
            else -> "初階"
        }

        callback.updateUI(
            title = "側捏訓練 Lv.$level - $levelName",
            instruction = "準備進入關卡...",
            repCount = "0 / 10",
            accuracy = "--"
        )

        val speech = when (level) {
            1 -> "第一關，初階側捏"
            2 -> "第二關，中階標準側捏，請確實張開"
            3 -> "第三關，進階連續側捏，請保持手腕懸空"
            else -> "開始"
        }
        callback.speak(speech, isUrgent = true)
    }

    override fun processLandmarks(landmarks: List<NormalizedLandmark>) {
        if (isTransitioning) {
            handleTransition()
            return
        }

        val thumbTip = landmarks[4] // 大拇指指尖
        val indexPip = landmarks[6] // 食指第二關節 (側捏接觸點)
        val wrist = landmarks[0]
        val middleMcp = landmarks[9]

        // 掌長與捏合距離計算
        val palmLen = Math.hypot((middleMcp.x() - wrist.x()).toDouble(), (middleMcp.y() - wrist.y()).toDouble())
        val pinchDist = Math.hypot((thumbTip.x() - indexPip.x()).toDouble(), (thumbTip.y() - indexPip.y()).toDouble())
        val ratio = (pinchDist / palmLen) * 100

        smoothedPinchDistance = (smoothingFactor * ratio) + ((1 - smoothingFactor) * smoothedPinchDistance)
        callback.updateUI(accuracy = "捏合度: ${String.format("%.1f", smoothedPinchDistance)}")

        // 難度參數
        val pinchThreshold = when (currentLevel) {
            1 -> 55.0; 2 -> 45.0; 3 -> 40.0; else -> 45.0
        }
        val openThreshold = when (currentLevel) {
            1 -> 58.0; 2 -> 65.0; 3 -> 65.0; else -> 65.0
        }

        // ==========================================
        // ✨ 新增：計算視覺進度百分比 (0.0~1.0)
        // ==========================================
        // 我們定義：0.0 代表完全張開(openThreshold)，1.0 代表完全捏緊(pinchThreshold)
        val totalRange = openThreshold - pinchThreshold
        val currentFromPinch = smoothedPinchDistance - pinchThreshold
        // 算出目前的距離佔總範圍的比例，並反轉它（距離越小，百分比越高）
        val rawProgress = 1.0 - (currentFromPinch / totalRange)
        val progress = Math.max(0.0f, Math.min(1.0f, rawProgress.toFloat()))

        // 傳給主機更新畫布
        callback.updateProgress(progress, 0) // 側捏暫時不抓速度
        // ==========================================

        val currentState = when {
            smoothedPinchDistance < pinchThreshold -> "PINCHED"
            smoothedPinchDistance > openThreshold -> "OPENED"
            else -> "MID"
        }

        pinchStateBuffer.add(currentState)
        if (pinchStateBuffer.size > 8) pinchStateBuffer.removeAt(0)

        val isStablePinch = pinchStateBuffer.count { it == "PINCHED" } >= 5
        val isStableOpen = pinchStateBuffer.count { it == "OPENED" } >= 5

        if (isStablePinch && lastConfirmedPinchState != "PINCHED") {
            if (lastConfirmedPinchState == "OPENED") {
                val now = SystemClock.uptimeMillis()
                val duration = now - lastRepTime

                if (duration > 1200L) {
                    repCount++
                    lastRepTime = now

                    var score = 100
                    if (currentLevel == 3) {
                        val wristMove = Math.hypot(wrist.x() - repStartWristX, wrist.y() - repStartWristY)
                        if (wristMove > 0.05) {
                            score -= 20
                            mistakeLogs.add("第 $repCount 次：手腕晃動過大，未保持穩定")
                        }
                        if (duration > 2000L) {
                            score -= 15
                            mistakeLogs.add("第 $repCount 次：側捏動作不夠流暢")
                        }
                    }

                    score = maxOf(score, 60)
                    repScores.add(score)

                    callback.speakCount(repCount)
                    callback.updateUI(feedback = "✅ 捏緊了！(本次: $score 分)", instruction = "請將手指完全打開", repCount = "$repCount / 10")

                    if (repCount >= 10) { checkLevelUp() }
                } else {
                    lastRepTime = now
                    mistakeLogs.add("未計入次數：開合動作過快，請確實停留")
                    callback.speak("太快了", isUrgent = true)
                    callback.updateUI(feedback = "⚠️ 動作太快", instruction = "請放慢速度，重新打開")
                }
            } else {
                callback.updateUI(feedback = "✅ 捏緊完成", instruction = "請將手指完全打開")
            }
            lastConfirmedPinchState = "PINCHED"

        } else if (isStableOpen && lastConfirmedPinchState != "OPENED") {
            callback.updateUI(feedback = "✅ 已張開", instruction = "請用力側捏")
            repStartWristX = wrist.x().toDouble()
            repStartWristY = wrist.y().toDouble()
            lastConfirmedPinchState = "OPENED"
        }
    }

    private fun handleTransition() {
        val elapsed = SystemClock.uptimeMillis() - transitionStartTime
        if (elapsed < 3000L) {
            val remain = 3 - (elapsed / 1000).toInt()
            if (remain != lastCountdownSec && remain > 0) {
                callback.speak(remain.toString(), isUrgent = true)
                lastCountdownSec = remain
            }
            callback.updateUI(instruction = "請在 $remain 秒後開始練習")
        } else {
            isTransitioning = false
            lastRepTime = SystemClock.uptimeMillis()
            lastCountdownSec = -1
            callback.speak("開始", isUrgent = true)
            callback.updateUI(instruction = "請先將手指完全打開")
        }
    }

    private fun checkLevelUp() {
        val finalScore = getFinalScore()
        if (currentLevel < 3 && finalScore >= 80) {
            callback.speak("恭喜過關，進入下一階段", isUrgent = true)
            startLevel(currentLevel + 1)
        } else {
            val durationInSeconds = (System.currentTimeMillis() - sessionStartTime) / 1000
            val report = TrainingReport(
                actionName = "手部精細動作 - 側捏",
                difficulty = currentLevel,
                totalReps = repCount,
                durationSeconds = durationInSeconds,
                mistakeLogs = mistakeLogs.toList()
            )
            callback.updateUI(feedback = "🎉 訓練結束！總平均: $finalScore 分")
            // ✨ 完成後關閉側捏特效
            callback.setPinchGuideEnabled(false)
            callback.onTrainingComplete(report)
        }
    }
}