package com.rehabassist.rehabassist.actions

import android.os.SystemClock
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark


class WipeAction(
    callback: RehabActionCallback,
    private val startingLevel: Int = 1
) : BaseRehabAction(callback) {

    // ✨ 成績單與計時器
    private val mistakeLogs = mutableListOf<String>()
    private var sessionStartTime = System.currentTimeMillis()

    // 🌟 關卡與狀態變數
    private var currentLevel = 1
    private var isTransitioning = false
    private var transitionStartTime = 0L
    private var lastCountdownSec = -1

    // 狀態機：等待出發 -> 往前推 (擦拭) -> 往回收回
    private var currentState = "WAIT_START"

    // 紀錄起點的肩膀高度，用來抓代償 (Level 3)
    private var startShoulderY = 0.0

    init {
        startLevel(startingLevel)
    }

    private fun startLevel(level: Int) {
        currentLevel = level
        repCount = 0
        repScores.clear()
        currentState = "WAIT_START"
        isTransitioning = true
        transitionStartTime = SystemClock.uptimeMillis()
        mistakeLogs.clear()
        sessionStartTime = System.currentTimeMillis()

        val levelName = when (level) {
            1 -> "初階 (微幅擦拭)"
            2 -> "中階 (標準來回擦拭)"
            3 -> "進階 (抗重力穩定擦拭)"
            else -> "初階"
        }

        callback.updateUI(
            title = "功能性擦拭 Lv.$level - $levelName",
            instruction = "準備進入關卡...",
            repCount = "0 / 10",
            accuracy = "--"
        )

        val speech = when (level) {
            1 -> "第一關，初階擦拭，請將手輕輕往前滑"
            2 -> "第二關，中階擦拭，請大範圍來回擦拭"
            3 -> "第三關，進階擦拭，請維持身體挺直不要塌陷"
            else -> "開始"
        }
        callback.speak(speech, isUrgent = true)
    }

    override fun processLandmarks(landmarks: List<NormalizedLandmark>) {
        // 防呆：如果傳進來的點位不到 33 個，代表主機引擎裝錯了！
        if (landmarks.size < 33) return

        if (isTransitioning) {
            handleTransition()
            return
        }

        // 🌟 全身骨架點位 (MediaPipe Pose)
        // 預設抓取「左手」進行復健：11(左肩膀), 13(左手肘), 15(左手腕)
        // 💡 如果奶奶是要練右手，請把數字改成 12, 14, 16！
        val shoulder = landmarks[11]
        val elbow = landmarks[13]
        val wrist = landmarks[15]

        // 計算肩膀到手腕的直線距離 (代表手臂伸直的程度)
        val armExtension = Math.hypot((wrist.x() - shoulder.x()).toDouble(), (wrist.y() - shoulder.y()).toDouble())

        callback.updateUI(accuracy = "手臂伸展度: ${String.format("%.2f", armExtension)}")

        // 動態難度門檻：決定擦拭要推多遠才算數
        val wipeOutThreshold = when (currentLevel) {
            1 -> 0.35 // 初階：稍微往前推就好
            2 -> 0.45 // 中階：要推得比較遠 (手肘要伸直)
            3 -> 0.45 // 進階：推遠，且身體要穩
            else -> 0.45
        }
        val wipeInThreshold = 0.25 // 收回來的門檻

        val now = SystemClock.uptimeMillis()

        when (currentState) {
            "WAIT_START" -> {
                if (armExtension < wipeInThreshold) {
                    currentState = "WIPING_OUT"
                    startShoulderY = shoulder.y().toDouble() // 紀錄起始肩膀高度
                    callback.updateUI(feedback = "✅ 預備完成", instruction = "請將手往前推")
                } else {
                    callback.updateUI(instruction = "請先將手收回靠近身體")
                }
            }

            "WIPING_OUT" -> {
                if (armExtension > wipeOutThreshold) {
                    currentState = "WIPING_IN"
                    callback.updateUI(feedback = "✅ 推到頂點！", instruction = "請將手收回")
                }

                // Lv3 防作弊：肩膀有沒有往下掉 (身體往前傾或塌陷)
                if (currentLevel == 3) {
                    val shoulderDrop = shoulder.y().toDouble() - startShoulderY
                    if (shoulderDrop > 0.05) { // Y值變大代表在畫面上往下掉
                        callback.speak("身體請挺直", isUrgent = true)
                        callback.updateUI(feedback = "⚠️ 身體塌陷！", instruction = "請用核心撐住，不要駝背")
                    }
                }
            }

            "WIPING_IN" -> {
                if (armExtension < wipeInThreshold) {
                    val duration = now - lastRepTime
                    if (duration > 1500L) { // 防作弊：動作太快
                        repCount++
                        lastRepTime = now
                        currentState = "WIPING_OUT"
                        startShoulderY = shoulder.y().toDouble() // 更新下一輪的高度

                        // 結算這一次的分數與筆記
                        var score = 100
                        if (currentLevel == 3 && (shoulder.y().toDouble() - startShoulderY) > 0.05) {
                            score -= 20
                            mistakeLogs.add("第 $repCount 次：身體前傾代償，核心未維持穩定")
                        }
                        if (duration > 4000L) {
                            score -= 10
                            mistakeLogs.add("第 $repCount 次：動作流暢度較低")
                        }
                        score = maxOf(score, 60)
                        repScores.add(score)

                        callback.speakCount(repCount)
                        callback.updateUI(feedback = "🎉 完成一次！(本次: $score 分)", repCount = "$repCount / 10", instruction = "請繼續往前擦拭")

                        if (repCount >= 10) {
                            checkLevelUp()
                        }
                    } else {
                        lastRepTime = now
                        currentState = "WAIT_START"
                        mistakeLogs.add("未計入次數：動作過快，未達復健效果")
                        callback.speak("太快了", isUrgent = true)
                        callback.updateUI(feedback = "⚠️ 動作太快", instruction = "請放慢速度，重新準備")
                    }
                }
            }
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
            callback.updateUI(instruction = "請先將手收回身體旁")
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
                actionName = "功能性擦拭訓練",
                difficulty = currentLevel,
                totalReps = repCount,
                durationSeconds = durationInSeconds,
                mistakeLogs = mistakeLogs.toList()
            )
            callback.updateUI(feedback = "🎉 訓練結束！總平均: $finalScore 分")
            callback.onTrainingComplete(report)
        }
    }
}