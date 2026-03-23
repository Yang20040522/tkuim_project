package com.rehabassist.rehabassist.actions

import android.os.SystemClock
import com.google.mediapipe.tasks.components.containers.NormalizedLandmark

class SidePinchAction(callback: RehabActionCallback) : BaseRehabAction(callback) {

    // ✨ 新增：側捏專屬的筆記本與計時器
    private val mistakeLogs = mutableListOf<String>()
    private var sessionStartTime = System.currentTimeMillis()

    // 這些變數現在只屬於側捏，不會再弄髒外面的 Activity 啦！
    private var smoothedPinchDistance = 0.0
    private var pinchStateBuffer = mutableListOf<String>()
    private var lastConfirmedPinchState = ""

    // init 區塊：當這個卡匣一插上去時，馬上把畫面設定成側捏的專屬文字
    init {
        callback.updateUI(
            title = "手部精細動作 - 側捏訓練",
            instruction = "請先將手指完全打開",
            repCount = "0 / 10",
            accuracy = "--"
        )
    }

    // 核心大腦：專門處理側捏的骨架邏輯
    override fun processLandmarks(landmarks: List<NormalizedLandmark>) {
        val thumbTip = landmarks[4]
        val indexPip = landmarks[6]
        val wrist = landmarks[0]
        val middleMcp = landmarks[9]

        // 數學計算：掌長與捏合距離比例
        val palmLen = Math.sqrt(Math.pow((middleMcp.x() - wrist.x()).toDouble(), 2.0) + Math.pow((middleMcp.y() - wrist.y()).toDouble(), 2.0))
        val pinchDist = Math.sqrt(Math.pow((thumbTip.x() - indexPip.x()).toDouble(), 2.0) + Math.pow((thumbTip.y() - indexPip.y()).toDouble(), 2.0))
        val ratio = (pinchDist / palmLen) * 100

        smoothedPinchDistance = (smoothingFactor * ratio) + ((1 - smoothingFactor) * smoothedPinchDistance)

        // 遙控主機更新 UI：顯示捏合度
        callback.updateUI(accuracy = "捏合度: ${String.format("%.1f", smoothedPinchDistance)}")

        val pinchThreshold = 45.0
        val openThreshold = 65.0
        val currentState = when {
            smoothedPinchDistance < pinchThreshold -> "PINCHED"
            smoothedPinchDistance > openThreshold -> "OPENED"
            else -> "MID"
        }

        pinchStateBuffer.add(currentState)
        if (pinchStateBuffer.size > 8) pinchStateBuffer.removeAt(0)

        val isStablePinch = pinchStateBuffer.count { it == "PINCHED" } >= 5
        val isStableOpen = pinchStateBuffer.count { it == "OPENED" } >= 5

        // 動作邏輯判斷
        if (isStablePinch && lastConfirmedPinchState != "PINCHED") {
            lastConfirmedPinchState = "PINCHED"
            callback.updateUI(feedback = "✅ 捏緊了！", instruction = "很好，請將手指完全打開")

        } else if (isStableOpen && lastConfirmedPinchState != "OPENED") {
            if (lastConfirmedPinchState == "PINCHED") {
                val now = SystemClock.uptimeMillis()
                if (now - lastRepTime > 1200L) {
                    repCount++
                    lastRepTime = now

                    // 遙控主機講話與更新次數
                    callback.speakCount(repCount)
                    callback.updateUI(feedback = "✅ 完成一次！", instruction = "請再次將手指捏緊", repCount = "$repCount / 10")

                    // 判斷是否達標
                    if (repCount >= 10) {
                        // ✨ 新增：打包側捏的成績單！
                        val durationInSeconds = (System.currentTimeMillis() - sessionStartTime) / 1000
                        val report = TrainingReport(
                            actionName = "手部精細動作 - 側捏",
                            difficulty = 1, // 側捏目前預設為 Level 1
                            totalReps = repCount,
                            durationSeconds = durationInSeconds,
                            mistakeLogs = mistakeLogs.toList() // 交出筆記本
                        )
                        // ✨ 帶著成績單呼叫主機！
                        callback.onTrainingComplete(report)
                    }
                } else {
                    lastRepTime = now

                    // ✨ 新增紀錄：側捏動作過快
                    mistakeLogs.add("未計入次數：開合動作過快，請確實停留")

                    callback.speak("太快了", isUrgent = true)
                    callback.updateUI(feedback = "⚠️ 動作太快", instruction = "請放慢速度，重新捏合")
                }
            } else {
                callback.updateUI(feedback = "✅ 起始動作完成", instruction = "請開始將手指捏緊")
            }
            lastConfirmedPinchState = "OPENED"

        } else if (!isStablePinch && !isStableOpen) {
            if (lastConfirmedPinchState == "OPENED") {
                callback.updateUI(instruction = "捏合中...")
            } else if (lastConfirmedPinchState == "PINCHED") {
                callback.updateUI(instruction = "打開中...")
            }
        }
    }
}