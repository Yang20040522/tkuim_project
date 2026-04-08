package com.rehabassist.rehabassist.actions

import android.os.SystemClock
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark
import java.util.Locale
import kotlin.math.hypot

class WipeAction(
    callback: RehabActionCallback,
    startingLevel: Int = 1 // 💡 移除了 private val 解決警告
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

    // ✨ 治療師升級：自動偵測患側手
    private var activeSide: String? = null // "LEFT" 或 "RIGHT"

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

        // ✨ 畫面設定：關閉不相關的特效，並啟動「上半身骨架模式」
        callback.setGuideLineVisible(false)
        callback.setPinchGuideEnabled(false)
        callback.setSkeletonMode("UPPER_BODY")

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

        // 🌟 抓出左右手的關鍵點
        val leftShoulder = landmarks[11]
        val rightShoulder = landmarks[12]
        val leftWrist = landmarks[15]
        val rightWrist = landmarks[16]

        // 💡 修正黃色警告：改用 Kotlin 的 hypot 函數
        val leftExtension = hypot((leftWrist.x() - leftShoulder.x()).toDouble(), (leftWrist.y() - leftShoulder.y()).toDouble())
        val rightExtension = hypot((rightWrist.x() - rightShoulder.x()).toDouble(), (rightWrist.y() - rightShoulder.y()).toDouble())

        // ==========================================
        // ✨ 自動偵測患側手邏輯 (只在剛開始時執行一次)
        // ==========================================
        if (activeSide == null) {
            callback.updateUI(instruction = "👀 請將【要訓練的那隻手】往前推以進行綁定")
            if (leftExtension > 0.3) {
                activeSide = "LEFT"
                callback.speak("已鎖定左手", isUrgent = true)
            } else if (rightExtension > 0.3) {
                activeSide = "RIGHT"
                callback.speak("已鎖定右手", isUrgent = true)
            }
            return // 還沒綁定前，先不要跑後面的計數邏輯
        }

        // ==========================================
        // 綁定完成後，根據 activeSide 拿出對應的點位
        // ==========================================
        val shoulder = if (activeSide == "LEFT") leftShoulder else rightShoulder
        // 💡 刪除沒有用到的 elbow 和 wrist 變數，解決黃色警告

        val armExtension = if (activeSide == "LEFT") leftExtension else rightExtension

        // 💡 加上 Locale.US 解決 String.format 的黃色警告
        callback.updateUI(accuracy = "手臂伸展度: ${String.format(Locale.US, "%.2f", armExtension)}")

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

            // ✨ 如果還沒綁定，就提示他綁定
            if (activeSide == null) {
                callback.updateUI(instruction = "👀 請將【要訓練的那隻手】往前推")
            } else {
                callback.updateUI(instruction = "請先將手收回身體旁")
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
                actionName = "功能性擦拭訓練",
                difficulty = currentLevel,
                totalReps = repCount,
                durationSeconds = durationInSeconds, // 🔴 解決紅色錯誤：移除了 .toInt()
                mistakeLogs = mistakeLogs.toList()
            )
            callback.updateUI(feedback = "🎉 訓練結束！總平均: $finalScore 分")

            // ✨ 結束時切回全身模式，避免影響下一個動作
            callback.setSkeletonMode("FULL_BODY")
            callback.onTrainingComplete(report)
        }
    }
}