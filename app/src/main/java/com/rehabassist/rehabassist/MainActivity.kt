package com.rehabassist.rehabassist

import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.AdapterView
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.Spinner
import androidx.appcompat.app.AppCompatActivity

class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        val spinnerAction = findViewById<Spinner>(R.id.spinnerAction)
        val spinnerDifficulty = findViewById<Spinner>(R.id.spinnerDifficulty)
        val btnStartTraining = findViewById<Button>(R.id.btnStartTraining)

        // ✨ 新增：綁定歷史紀錄按鈕
        val btnHistory = findViewById<Button>(R.id.btnHistory)

        val actionOptions = arrayOf("翻掌訓練", "手部精細動作 - 側捏")
        spinnerAction.adapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, actionOptions)

        spinnerAction.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
            override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
                val selectedAction = actionOptions[position]
                val difficultyOptions = if (selectedAction == "翻掌訓練") {
                    arrayOf("Level 1 (初階 - 容錯較高)", "Level 2 (中階 - 要求嚴格)")
                } else {
                    arrayOf("Level 1 (標準側捏)")
                }
                spinnerDifficulty.adapter = ArrayAdapter(this@MainActivity, android.R.layout.simple_spinner_dropdown_item, difficultyOptions)
            }
            override fun onNothingSelected(parent: AdapterView<*>?) {}
        }

        btnStartTraining.setOnClickListener {
            val selectedAction = spinnerAction.selectedItem.toString()
            val selectedDifficultyPos = spinnerDifficulty.selectedItemPosition
            val actionCode = when (selectedAction) {
                "翻掌訓練" -> "TURN_PALM"
                "手部精細動作 - 側捏" -> "SECOND_ACTION"
                else -> "TURN_PALM"
            }
            val difficultyLevel = selectedDifficultyPos + 1
            val intent = Intent(this, TrainingActivity::class.java)
            intent.putExtra("ACTION_TYPE", actionCode)
            intent.putExtra("DIFFICULTY_LEVEL", difficultyLevel)
            startActivity(intent)
        }

        // ==========================================
        // ✨ 新增：當點擊「查看歷史紀錄」按鈕時
        // ==========================================
        btnHistory.setOnClickListener {
            showHistoryDialog()
        }
    }

    // ✨ 讀取存檔並顯示「紀錄列表」
    private fun showHistoryDialog() {
        val sharedPref = getSharedPreferences("RehabRecords", android.content.Context.MODE_PRIVATE)
        val historyJson = sharedPref.getString("history", "[]")
        val jsonArray = org.json.JSONArray(historyJson)

        if (jsonArray.length() == 0) {
            android.app.AlertDialog.Builder(this)
                .setTitle("訓練紀錄")
                .setMessage("目前還沒有任何訓練紀錄喔！趕快開始第一次復健吧。")
                .setPositiveButton("確定", null)
                .show()
            return
        }

        val options = mutableListOf<String>()
        val recordObjects = mutableListOf<org.json.JSONObject>()

        // 把紀錄一筆一筆抓出來
        for (i in 0 until jsonArray.length()) {
            val record = jsonArray.getJSONObject(i)
            recordObjects.add(record)
            val time = record.getString("timestamp")
            val action = record.getString("actionName")
            options.add("🕒 $time - $action")
        }

        // 把最新的紀錄放在最上面
        options.reverse()
        recordObjects.reverse()

        android.app.AlertDialog.Builder(this)
            .setTitle("📋 歷史訓練紀錄")
            .setItems(options.toTypedArray()) { _, which ->
                // 使用者點擊了某個紀錄，就打開詳細報告！
                showRecordDetail(recordObjects[which])
            }
            .setNegativeButton("關閉", null)
            .show()
    }

    // ✨ 顯示單筆紀錄的「詳細失敗原因報告」
    private fun showRecordDetail(record: org.json.JSONObject) {
        val time = record.getString("timestamp")
        val action = record.getString("actionName")
        val diff = record.getInt("difficulty")
        val duration = record.getInt("durationSeconds")
        val mistakes = record.getJSONArray("mistakeLogs")

        // 組裝詳細報告的文字
        val sb = java.lang.StringBuilder()
        sb.append("難度：Level $diff\n")
        sb.append("花費時間：$duration 秒\n\n")
        sb.append("【AI 姿勢分析報告】\n")

        if (mistakes.length() == 0) {
            sb.append("✅ 完美！本次訓練動作非常標準，沒有任何失誤。")
        } else {
            for (i in 0 until mistakes.length()) {
                sb.append("❌ ").append(mistakes.getString(i)).append("\n")
            }
        }

        android.app.AlertDialog.Builder(this)
            .setTitle("$action ($time)")
            .setMessage(sb.toString())
            .setPositiveButton("確定", null)
            .show()
    }
}