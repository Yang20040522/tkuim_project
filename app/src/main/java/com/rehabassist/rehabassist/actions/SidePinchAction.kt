package com.rehabassist.rehabassist.actions

import android.os.SystemClock
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark

class SidePinchAction(
    callback: RehabActionCallback,
    private val startingLevel: Int = 1 // 🌟 接收首頁傳來的難度
) : BaseRehabAction(callback) {

    // ✨ 保留同學的優秀設計：側捏專屬的筆記本與計時器
    private val mistakeLogs = mutableListOf<String>()
    private var sessionStartTime = System.currentTimeMillis()

    private var smoothedPinchDistance = 0.0
    private var pinchStateBuffer = mutableListOf<String>()
    private var lastConfirmedPinchState = ""

    // 🌟 RPG 升級與轉場變數
    private var currentLevel = 1
    private var isTransitioning = false
    private var transitionStartTime = 0L
    private var lastCountdownSec = -1

    // 🌟 Lv3 懸空偵測用的手腕座標 (用來抓代償動作)
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

        // 🎙️ 語音同步：關卡開始提示
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

        val thumbTip = landmarks[4]
        val indexPip = landmarks[6]
        val wrist = landmarks[0]
        val middleMcp = landmarks[9]

        // ✨ 保留同學的完美數學算法：掌長比例計算
        val palmLen = Math.sqrt(Math.pow((middleMcp.x() - wrist.x()).toDouble(), 2.0) + Math.pow((middleMcp.y() - wrist.y()).toDouble(), 2.0))
        val pinchDist = Math.sqrt(Math.pow((thumbTip.x() - indexPip.x()).toDouble(), 2.0) + Math.pow((thumbTip.y() - indexPip.y()).toDouble(), 2.0))
        val ratio = (pinchDist / palmLen) * 100

        smoothedPinchDistance = (smoothingFactor * ratio) + ((1 - smoothingFactor) * smoothedPinchDistance)
        callback.updateUI(accuracy = "捏合度: ${String.format("%.1f", smoothedPinchDistance)}")

        // 🌟 難度參數動態調整 (比例值越小代表捏越緊)
        val pinchThreshold = when (currentLevel) {
            1 -> 55.0 // Lv1: 沒力氣也沒關係，動一下就算捏
            2 -> 45.0 // Lv2: 採用同學設定的標準門檻
            3 -> 40.0 // Lv3: 要求捏得非常緊密
            else -> 45.0
        }
        val openThreshold = when (currentLevel) {
            1 -> 58.0
            2 -> 65.0 // 同學的標準
            3 -> 65.0
            else -> 65.0
        }

        val currentState = when {
            smoothedPinchDistance < pinchThreshold -> "PINCHED"
            smoothedPinchDistance > openThreshold -> "OPENED"
            else -> "MID"
        }

        pinchStateBuffer.add(currentState)
        if (pinchStateBuffer.size > 8) pinchStateBuffer.removeAt(0)

        val isStablePinch = pinchStateBuffer.count { it == "PINCHED" } >= 5
        val isStableOpen = pinchStateBuffer.count { it == "OPENED" } >= 5

        // 動作判斷核心
        if (isStablePinch && lastConfirmedPinchState != "PINCHED") {
            if (lastConfirmedPinchState == "OPENED") {
                val now = SystemClock.uptimeMillis()
                val duration = now - lastRepTime

                // 同學設定的防作弊時間
                if (duration > 1200L) {
                    repCount++
                    lastRepTime = now

                    // ✨ 評分系統與筆記本連動
                    var score = 100
                    if (currentLevel == 3) {
                        val wristMove = Math.hypot(wrist.x() - repStartWristX, wrist.y() - repStartWristY)
                        if (wristMove > 0.05) {
                            score -= 20
                            mistakeLogs.add("第 $repCount 次：手腕晃動過大，未保持穩定") // 寫入同學的筆記本
                        }
                        if (duration > 2000L) {
                            score -= 15
                            mistakeLogs.add("第 $repCount 次：側捏動作不夠流暢")
                        }
                    }

                    score = maxOf(score, 60)
                    repScores.add(score)

                    // 🎙️ 語音同步：只報數字，不加台詞防吞字
                    callback.speakCount(repCount)
                    callback.updateUI(feedback = "✅ 捏緊了！(本次: $score 分)", instruction = "請將手指完全打開", repCount = "$repCount / 10")

                    // 判斷是否做滿 10 下
                    if (repCount >= 10) {
                        checkLevelUp()
                    }
                } else {
                    lastRepTime = now
                    // ✨ 整合同學的錯誤紀錄與語音
                    mistakeLogs.add("未計入次數：開合動作過快，請確實停留")
                    callback.speak("太快了", isUrgent = true)
                    callback.updateUI(feedback = "⚠️ 動作太快", instruction = "請放慢速度，重新打開")
                }
            } else {
                callback.updateUI(feedback = "✅ 捏緊完成", instruction = "請將手指完全打開")
            }
            lastConfirmedPinchState = "PINCHED"

        } else if (isStableOpen && lastConfirmedPinchState != "OPENED") {
            callback.updateUI(feedback = "✅ 已打開", instruction = "請用力側捏")

            // 紀錄打開瞬間的手腕座標，為 Lv3 抓晃動作準備
            repStartWristX = wrist.x().toDouble()
            repStartWristY = wrist.y().toDouble()

            lastConfirmedPinchState = "OPENED"

        } else if (!isStablePinch && !isStableOpen) {
            if (lastConfirmedPinchState == "OPENED") {
                callback.updateUI(instruction = "捏合中...")
            } else if (lastConfirmedPinchState == "PINCHED") {
                callback.updateUI(instruction = "打開中...")
            }
        }
    }

    private fun handleTransition() {
        val elapsed = SystemClock.uptimeMillis() - transitionStartTime
        if (elapsed < 3000L) {
            val remain = 3 - (elapsed / 1000).toInt()
            if (remain != lastCountdownSec && remain > 0) {
                // 🎙️ 語音倒數
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
            // 🎙️ 分數夠高，帶著筆記本直接晉級！
            callback.speak("恭喜過關，進入下一階段", isUrgent = true)
            startLevel(currentLevel + 1)
        } else {
            // ✨ 保留同學打包成績單的邏輯！把最終報告交給主機
            val durationInSeconds = (System.currentTimeMillis() - sessionStartTime) / 1000
            val report = TrainingReport(
                actionName = "手部精細動作 - 側捏",
                difficulty = currentLevel,
                totalReps = repCount,
                durationSeconds = durationInSeconds,
                mistakeLogs = mistakeLogs.toList()
            )

            callback.updateUI(feedback = "🎉 訓練結束！總平均: $finalScore 分")
            // ✨ 這裡使用同學的寫法，帶著報告收尾
            callback.onTrainingComplete(report)
        }
    }
}