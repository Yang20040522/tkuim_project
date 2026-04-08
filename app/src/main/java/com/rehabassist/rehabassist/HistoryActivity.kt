package com.rehabassist.rehabassist

import android.os.Bundle
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.ListView
import androidx.appcompat.app.AppCompatActivity
import com.github.mikephil.charting.charts.LineChart
import com.github.mikephil.charting.components.XAxis
import com.github.mikephil.charting.data.Entry
import com.github.mikephil.charting.data.LineData
import com.github.mikephil.charting.data.LineDataSet
import org.json.JSONArray

class HistoryActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_history)

        val lineChart = findViewById<LineChart>(R.id.lineChart)
        val listViewHistory = findViewById<ListView>(R.id.listViewHistory)
        val btnClose = findViewById<Button>(R.id.btnClose)

        btnClose.setOnClickListener { finish() }

        val sharedPref = getSharedPreferences("RehabRecords", MODE_PRIVATE)
        val historyJson = sharedPref.getString("history", "[]")
        val jsonArray = JSONArray(historyJson)

        val entries = ArrayList<Entry>()
        val listData = ArrayList<String>()

        for (i in 0 until jsonArray.length()) {
            val record = jsonArray.getJSONObject(i)
            val time = record.getString("timestamp")
            val action = record.getString("actionName")
            val diff = record.getInt("difficulty")
            val duration = record.getInt("durationSeconds")
            val mistakes = record.getJSONArray("mistakeLogs")

            // ✨ 圖表核心：計算「完美動作次數」 (總共 10 次 - 失誤次數)
            val perfectCount = 10 - mistakes.length()
            // 把第 i 次訓練的分數，加進折線圖的點位裡
            entries.add(Entry(i.toFloat(), perfectCount.toFloat()))

            // 準備下方的文字列表
            val mistakeText = if (mistakes.length() == 0) "✅ 完美無失誤" else "❌ 失誤 ${mistakes.length()} 次"
            listData.add("🕒 $time | $action (Lv.$diff)\n⏱️ 花費: $duration 秒 | $mistakeText")
        }

        // 把最新的紀錄反轉到最上面顯示
        listData.reverse()
        listViewHistory.adapter = ArrayAdapter(this, android.R.layout.simple_list_item_1, listData)

        // ==========================================
        // ✨ 設定 MPAndroidChart 圖表樣式與動畫
        // ==========================================
        if (entries.isNotEmpty()) {
            val dataSet = LineDataSet(entries, "完美動作次數 (滿分 10次)")
            dataSet.color = android.graphics.Color.parseColor("#4A65FF") // 線條顏色
            dataSet.valueTextColor = android.graphics.Color.BLACK
            dataSet.valueTextSize = 12f
            dataSet.lineWidth = 3f
            dataSet.circleRadius = 5f
            dataSet.setCircleColor(android.graphics.Color.parseColor("#FF4B4B")) // 點的顏色
            dataSet.mode = LineDataSet.Mode.CUBIC_BEZIER // 平滑曲線
            dataSet.setDrawFilled(true) // 底部填滿半透明顏色
            dataSet.fillColor = android.graphics.Color.parseColor("#804A65FF")

            lineChart.data = LineData(dataSet)

            // 隱藏不必要的網格線
            lineChart.description.isEnabled = false
            lineChart.xAxis.position = XAxis.XAxisPosition.BOTTOM
            lineChart.xAxis.setDrawGridLines(false)
            lineChart.axisRight.isEnabled = false
            lineChart.axisLeft.axisMinimum = 0f // 最低 0 次
            lineChart.axisLeft.axisMaximum = 10f // 最高 10 次

            // 加上從左畫到右的滑順動畫 (1秒)
            lineChart.animateX(1000)
            lineChart.invalidate()
        }
    }
}