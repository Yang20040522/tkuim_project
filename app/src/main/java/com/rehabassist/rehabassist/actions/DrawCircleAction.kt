package com.rehabassist.rehabassist.actions

import android.os.SystemClock
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark

class DrawCircleAction(
    callback: RehabActionCallback,
    startingLevel: Int = 1 // 💡 移除了 private val 解決黃色警告
) : BaseRehabAction(callback) {

    private val mistakeLogs = mutableListOf<String>()
    private var sessionStartTime = 0L
    private var currentLevel = 1

    // 💡 移除了 repCount 和 lastRepTime，因為 BaseRehabAction 已經內建了！

    // ✨ 畫圓專屬變數
    private var sweptAngle = 0.0 // 已經轉了多少度
    private var lastAngle = Double.NaN // 上一次的角度

    init {
        startLevel(startingLevel)
    }

    private fun startLevel(level: Int) {
        currentLevel = level
        repCount = 0 // 直接呼叫父類別的變數
        sweptAngle = 0.0
        lastAngle = Double.NaN
        mistakeLogs.clear()
        sessionStartTime = System.currentTimeMillis()
        lastRepTime = SystemClock.uptimeMillis() // 直接呼叫父類別的變數

        // 關閉其他不相關的輔助線
        callback.setGuideLineVisible(false)
        callback.setPinchGuideEnabled(false)

        // ✨ 卡匣自己決定：我只要畫手臂就好！
        callback.setSkeletonMode("ARMS_ONLY")

        val difficultyText = if (level == 1) "初階 (小方向盤)" else "中階 (大方向盤，需伸直手臂)"
        callback.updateUI(
            title = "畫圓訓練 - $difficultyText",
            instruction = "請想像面前有個大方向盤，手伸長畫一個大圓",
            repCount = "0 / 10",
            accuracy = "完成度: 0%"
        )
        callback.speak("請伸長手臂，畫一個大圓", isUrgent = true)
    }

    override fun processLandmarks(landmarks: List<NormalizedLandmark>) {
        // 我們追蹤食指根部 (5) 比較像握著方向盤
        val targetPoint = landmarks[5]

        // 螢幕中心點 (0.5, 0.5)
        val centerX = 0.5
        val centerY = 0.5

        // 1. 計算半徑 (手離中心的距離)
        val dx = (targetPoint.x() - centerX).toDouble()
        val dy = (targetPoint.y() - centerY).toDouble()
        val radius = Math.hypot(dx, dy)

        // 難度設定：Lv1 半徑大於 0.15 即可，Lv2 需要伸長一點大於 0.25
        val requiredRadius = if (currentLevel == 1) 0.15 else 0.25

        if (radius < requiredRadius) {
            callback.updateUI(feedback = "⚠️ 手臂伸得不夠長！", instruction = "請把手臂向外伸直一點")
            lastAngle = Double.NaN // 太靠近中心時，不計算角度
            return
        }

        // 2. 計算角度 (用 atan2 算出 -180 到 180 度的方位)
        val currentAngle = Math.toDegrees(Math.atan2(dy, dx))

        if (!lastAngle.isNaN()) {
            // 計算角度差
            var deltaAngle = currentAngle - lastAngle

            // 處理跨越 180 度到 -180 度的邊界問題
            if (deltaAngle > 180) deltaAngle -= 360
            if (deltaAngle < -180) deltaAngle += 360

            // 把移動的絕對角度加起來 (不管順時針或逆時針，只要有動就算)
            sweptAngle += Math.abs(deltaAngle)

            // 算一下進度給畫面顯示 (0.0 ~ 1.0)
            val progress = Math.min(sweptAngle / 360.0, 1.0).toFloat()
            callback.updateProgress(progress, 0)
            callback.updateUI(
                feedback = "✅ 很好，繼續畫圓...",
                instruction = "保持手臂伸展，轉動方向盤",
                accuracy = "完成度: ${(progress * 100).toInt()}%"
            )

            // 3. 判斷是否完成一圈 (360度)
            if (sweptAngle >= 360.0) {
                repCount++
                sweptAngle = 0.0 // 歸零，準備畫下一圈
                lastRepTime = SystemClock.uptimeMillis()

                callback.speakCount(repCount)
                callback.updateUI(repCount = "$repCount / 10", feedback = "🎉 完美畫完一圈！")

                if (repCount >= 10) {
                    finishTraining()
                }
            }
        }
        lastAngle = currentAngle
    }

    private fun finishTraining() {
        val durationInSeconds = (System.currentTimeMillis() - sessionStartTime) / 1000
        val report = TrainingReport(
            actionName = "方向盤畫圓訓練",
            difficulty = currentLevel,
            totalReps = repCount,
            durationSeconds = durationInSeconds, // 💡 移除了 .toInt()，完美符合 Long 型別！
            mistakeLogs = mistakeLogs.toList()
        )
        callback.onTrainingComplete(report)
    }
}