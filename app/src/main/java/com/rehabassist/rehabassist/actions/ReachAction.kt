package com.rehabassist.rehabassist.actions

import android.os.SystemClock
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import java.util.Locale

class ReachAction(
    callback: RehabActionCallback,
    startingLevel: Int = 1
) : BaseRehabAction(callback) {

    private val mistakeLogs = mutableListOf<String>()
    private var sessionStartTime = System.currentTimeMillis()

    private var currentLevel = 1
    private var isTransitioning = false
    private var transitionStartTime = 0L
    private var lastCountdownSec = -1

    // 狀態機：等待放下 -> 往上舉高 -> (Lv3 空中定格) -> 放下收回
    private var currentState = "WAIT_START"
    private var activeSide: String? = null // 自動偵測 "LEFT" 或 "RIGHT"

    private var holdStartTime = 0L // 用於 Lv3 的空中定格計時

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

        // 關閉特效，開啟上半身骨架
        callback.setGuideLineVisible(false)
        callback.setPinchGuideEnabled(false)
        callback.setSkeletonMode("UPPER_BODY")

        val levelName = when (level) {
            1 -> "初階 (舉至眼部)"
            2 -> "中階 (完全舉過頭頂)"
            3 -> "進階 (過頭頂並嚴格定格 3 秒)"
            else -> "初階"
        }

        callback.updateUI(
            title = "手臂上舉 Lv.$level - $levelName",
            instruction = "準備進入關卡...",
            repCount = "0 / 10",
            accuracy = "--"
        )

        // 🎙️ 語音提示也同步變嚴格
        val speech = when (level) {
            1 -> "第一關，初階上舉，請將手抬高至眼睛高度"
            2 -> "第二關，中階上舉，請將手完全舉高超過頭頂"
            3 -> "第三關，進階上舉，請舉過頭頂並在空中撐住三秒鐘"
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
        val nose = landmarks[0] // 用鼻子當作「頭部高度」的參考點

        // ==========================================
        // ✨ 自動偵測患側手：哪隻手先舉起來，就鎖定哪隻！
        // ==========================================
        if (activeSide == null) {
            callback.updateUI(instruction = "👀 請將【要訓練的那隻手】稍微舉高以進行綁定")
            if (leftWrist.y() < leftShoulder.y()) {
                activeSide = "LEFT"
                callback.speak("已鎖定左手", isUrgent = true)
            } else if (rightWrist.y() < rightShoulder.y()) {
                activeSide = "RIGHT"
                callback.speak("已鎖定右手", isUrgent = true)
            }
            return
        }

        val shoulder = if (activeSide == "LEFT") leftShoulder else rightShoulder
        val wrist = if (activeSide == "LEFT") leftWrist else rightWrist

        val heightDiff = wrist.y() - shoulder.y()
        callback.updateUI(accuracy = "上舉高度: ${String.format(Locale.US, "%.2f", -heightDiff)}")

        // ==========================================
        // 😈 魔鬼教練難度參數設定 (Y值越小代表越高)
        // ==========================================
        val targetHeightY = when (currentLevel) {
            1 -> nose.y() + 0.05f     // Lv1：必須舉到大約鼻子/眼睛的高度
            2 -> nose.y() - 0.15f     // Lv2：必須舉超過頭頂！
            3 -> nose.y() - 0.20f     // Lv3：必須舉得非常直、非常高
            else -> nose.y()
        }

        // 嚴格要求：放下時必須真的垂下來，不能偷懶停在胸口 (數值加大)
        val restingHeightY = shoulder.y() + 0.20f

        val now = SystemClock.uptimeMillis()

        when (currentState) {
            "WAIT_START" -> {
                if (wrist.y() > restingHeightY) {
                    currentState = "REACHING_UP"
                    callback.updateUI(feedback = "✅ 預備完成", instruction = "請將手用力往上舉高")
                } else {
                    callback.updateUI(instruction = "請先將手完全放下，自然垂在身體旁")
                }
            }

            "REACHING_UP" -> {
                if (wrist.y() < targetHeightY) {
                    if (currentLevel == 3) {
                        currentState = "HOLDING"
                        holdStartTime = now
                        callback.updateUI(feedback = "⏳ 撐住 3 秒！", instruction = "請維持最高點不要掉下來")
                        callback.speak("撐住", isUrgent = true)
                    } else {
                        currentState = "PULLING_DOWN"
                        callback.updateUI(feedback = "✅ 舉到頂點！", instruction = "請將手慢慢放下")
                    }
                }
            }

            "HOLDING" -> {
                // 😈 更嚴格：定格容錯率從 0.05 縮小到 0.03，稍微往下掉就不算！
                if (wrist.y() > targetHeightY + 0.03f) {
                    // 掉下來了
                    currentState = "REACHING_UP"
                    callback.updateUI(feedback = "⚠️ 手掉下來了", instruction = "請再次舉高並撐住")
                    callback.speak("掉下來了，再舉高", isUrgent = true)
                } else {
                    // 😈 更嚴格：撐滿時間延長到 3 秒 (3000ms)
                    val holdDuration = now - holdStartTime
                    if (holdDuration > 3000L) {
                        currentState = "PULLING_DOWN"
                        callback.updateUI(feedback = "✅ 非常穩定！", instruction = "請將手慢慢放下")
                        callback.speak("很好，慢慢放下", isUrgent = true)
                    } else {
                        // ✨ 加入倒數 UI，讓患者知道還要撐多久
                        val remain = 3 - (holdDuration / 1000).toInt()
                        callback.updateUI(feedback = "⏳ 撐住... 剩 $remain 秒", instruction = "保持最高點不要動")
                    }
                }
            }

            "PULLING_DOWN" -> {
                if (wrist.y() > restingHeightY) {
                    val duration = now - lastRepTime
                    if (duration > 1500L) {
                        repCount++
                        lastRepTime = now
                        currentState = "REACHING_UP"

                        var score = 100
                        if (duration > 6000L) { // 因為舉很高又撐很久，放寬一點整套動作的時間限制
                            score -= 15
                            mistakeLogs.add("第 $repCount 次：動作較緩慢吃力")
                        }
                        score = maxOf(score, 60)
                        repScores.add(score)

                        callback.speakCount(repCount)
                        callback.updateUI(feedback = "🎉 完成一次！(本次: $score 分)", repCount = "$repCount / 10", instruction = "請繼續往上舉")

                        if (repCount >= 10) {
                            checkLevelUp()
                        }
                    } else {
                        lastRepTime = now
                        currentState = "WAIT_START"
                        mistakeLogs.add("未計入次數：放下速度過快 (甩手)，恐造成關節受傷")
                        callback.speak("太快了，請控制力道", isUrgent = true)
                        callback.updateUI(feedback = "⚠️ 放下太快", instruction = "請用肌肉控制慢慢放下")
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
                callback.updateUI(instruction = "👀 請將【要訓練的那隻手】稍微舉高")
            } else {
                callback.updateUI(instruction = "請先將手完全自然放下")
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
                actionName = "手臂上舉訓練",
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