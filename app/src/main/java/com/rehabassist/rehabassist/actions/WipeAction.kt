package com.rehabassist.rehabassist.actions

import android.os.SystemClock
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import java.util.Locale
import kotlin.math.abs

class WipeAction(
    callback: RehabActionCallback,
    startingLevel: Int = 1
) : BaseRehabAction(callback) {

    private val mistakeLogs = mutableListOf<String>()
    private var sessionStartTime = System.currentTimeMillis()

    private var currentLevel = 1
    private var isTransitioning = false
    private var transitionStartTime = 0L
    private var lastCountdownSec = -1

    private var currentState = "WAIT_START"

    // ✨ OT 大綱專屬變數：核心穩定、側傾追蹤
    private var startShoulderX = 0.0f
    private var activeSide: String? = null

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

        callback.setGuideLineVisible(false)
        callback.setPinchGuideEnabled(false)
        callback.setSkeletonMode("UPPER_BODY")
        callback.updateProgress(0f, 0)

        // 💡 UI 與語音全面升級為「桌面左右擦拭」
        val levelName = when (level) {
            1 -> "初階 (桌面小幅左右擦拭)"
            2 -> "中階 (桌面大幅向外擦拭)"
            3 -> "進階 (核心穩定抗側傾)"
            else -> "初階"
        }

        callback.updateUI(
            title = "水平擦拭訓練 Lv.$level - $levelName",
            instruction = "準備進入關卡...",
            repCount = "0 / 10",
            accuracy = "--"
        )

        val speech = when (level) {
            1 -> "第一關，請將手平貼桌面，輕輕向外側滑動擦拭"
            2 -> "第二關，請沿著桌面，大幅度向外側擦拭到底"
            3 -> "第三關，向外擦拭時，身體請保持挺直，不要跟著歪斜"
            else -> "開始"
        }
        callback.speak(speech, isUrgent = true)
    }

    override fun processLandmarks(landmarks: List<NormalizedLandmark>) {
        if (landmarks.size < 33) return

        if (isTransitioning) {
            handleTransition()
            return
        }

        val leftShoulder = landmarks[11]
        val rightShoulder = landmarks[12]
        val leftWrist = landmarks[15]
        val rightWrist = landmarks[16]

        // ✨ 專注於 X 軸水平距離 (Horizontal Extension) 來判斷擦拭進度
        val leftHorizontalExt = abs(leftWrist.x() - leftShoulder.x())
        val rightHorizontalExt = abs(rightWrist.x() - rightShoulder.x())

        // ==========================================
        // ✨ 秒綁定：哪隻手先往外滑，就鎖定哪隻！
        // ==========================================
        if (activeSide == null) {
            callback.updateUI(instruction = "👀 請將【要訓練的那隻手】向外側滑動來綁定")

            if (leftHorizontalExt > 0.25f) {
                activeSide = "LEFT"
                callback.speak("已鎖定左手", isUrgent = true)
            } else if (rightHorizontalExt > 0.25f) {
                activeSide = "RIGHT"
                callback.speak("已鎖定右手", isUrgent = true)
            }
            return
        }

        val shoulder = if (activeSide == "LEFT") leftShoulder else rightShoulder
        val horizontalExt = if (activeSide == "LEFT") leftHorizontalExt else rightHorizontalExt

        callback.updateUI(accuracy = "水平伸展度: ${String.format(Locale.US, "%.2f", horizontalExt)}")

        // 動態難度門檻：X軸距離越遠，代表手往外滑得越直
        val wipeInThreshold = 0.15f // 靠近身體前方
        val wipeOutThreshold = when (currentLevel) {
            1 -> 0.35f
            2 -> 0.45f // 需要大幅度外展
            3 -> 0.45f // 重點在防身體歪斜
            else -> 0.45f
        }

        // 計算滑順的進度條
        val totalDistance = wipeOutThreshold - wipeInThreshold
        var currentProgress = 0f
        if (totalDistance > 0.01f) {
            val currentDistance = horizontalExt - wipeInThreshold
            currentProgress = (currentDistance / totalDistance).coerceIn(0.0f, 1.0f)
        }

        val now = SystemClock.uptimeMillis()

        when (currentState) {
            "WAIT_START" -> {
                callback.updateProgress(0f, 0)
                if (horizontalExt < wipeInThreshold + 0.05f) {
                    currentState = "WIPING_OUT"
                    startShoulderX = shoulder.x() // 紀錄起點肩膀的X座標，用來抓身體歪斜
                    callback.updateUI(feedback = "✅ 預備完成", instruction = "請將手沿著桌面往外側平擦")
                } else {
                    callback.updateUI(instruction = "請先將手收回至胸前")
                }
            }

            "WIPING_OUT" -> {
                callback.updateProgress(currentProgress, 0)
                callback.updateUI(instruction = "繼續往外擦... 完成度 ${(currentProgress * 100).toInt()}%")

                // ✨ OT 大綱重點：核心與姿勢維持 (防側傾代償)
                if (currentLevel >= 2) {
                    val shoulderLean = abs(shoulder.x() - startShoulderX)

                    if (shoulderLean > 0.08f) { // 身體跟著往外歪
                        callback.speak("身體請挺直", isUrgent = true)
                        callback.updateUI(feedback = "⚠️ 身體歪斜代償！", instruction = "請用手臂力量向外擦，身體不要跟著倒過去")
                    }
                }

                if (horizontalExt > wipeOutThreshold) {
                    currentState = "WIPING_IN"
                    callback.updateUI(feedback = "✅ 擦到外側頂點！", instruction = "請平穩地將手收回胸前")
                    callback.speak("很好，收回來", isUrgent = true)
                }
            }

            "WIPING_IN" -> {
                callback.updateProgress(currentProgress, 0)
                callback.updateUI(instruction = "慢慢收回... 剩餘 ${(currentProgress * 100).toInt()}%")

                if (horizontalExt < wipeInThreshold + 0.05f) {
                    val duration = now - lastRepTime
                    if (duration > 1200L) {
                        repCount++
                        lastRepTime = now
                        currentState = "WIPING_OUT"

                        var score = 100
                        if (currentLevel >= 2) {
                            if (abs(shoulder.x() - startShoulderX) > 0.08f) {
                                score -= 20
                                mistakeLogs.add("第 $repCount 次：身體側傾代償 (未穩定核心)")
                            }
                        }
                        if (duration > 4000L) {
                            score -= 10
                            mistakeLogs.add("第 $repCount 次：動作流暢度較低")
                        }
                        score = maxOf(score, 60)
                        repScores.add(score)

                        // 更新下一輪起點
                        startShoulderX = shoulder.x()

                        callback.speakCount(repCount)
                        callback.updateUI(feedback = "🎉 完成一次！(本次: $score 分)", repCount = "$repCount / 10")

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

            if (activeSide == null) {
                callback.updateUI(instruction = "👀 請將【要訓練的那隻手】往外側平移來綁定")
            } else {
                callback.updateUI(instruction = "請先將手收回胸前")
            }
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
                actionName = "水平擦拭訓練",
                difficulty = currentLevel,
                totalReps = repCount,
                durationSeconds = durationInSeconds,
                mistakeLogs = mistakeLogs.toList()
            )
            callback.updateUI(feedback = "🎉 訓練結束！總平均: $finalScore 分")
            callback.setSkeletonMode("FULL_BODY")
            callback.onTrainingComplete(report)
        }
    }
}