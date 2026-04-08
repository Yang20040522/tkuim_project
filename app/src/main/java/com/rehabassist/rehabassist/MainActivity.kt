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
        val btnHistory = findViewById<Button>(R.id.btnHistory)

        val actionOptions = arrayOf("翻掌訓練", "手部精細動作 - 側捏", "功能性擦拭訓練")
        spinnerAction.adapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, actionOptions)

        spinnerAction.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
            override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
                val selectedAction = actionOptions[position]

                val difficultyOptions = when (selectedAction) {
                    "翻掌訓練" -> arrayOf("Level 1 (初階 - 容錯較高)", "Level 2 (中階 - 要求嚴格)")
                    "手部精細動作 - 側捏" -> arrayOf("Level 1 (初階微幅)", "Level 2 (中階標準)", "Level 3 (進階連擊)")
                    "功能性擦拭訓練" -> arrayOf("Level 1 (微幅擦拭)", "Level 2 (標準來回)", "Level 3 (抗重力穩定)")
                    else -> arrayOf("Level 1")
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
                "功能性擦拭訓練" -> "WIPE_ACTION"
                else -> "TURN_PALM"
            }

            val difficultyLevel = selectedDifficultyPos + 1
            val intent = Intent(this, TrainingActivity::class.java)
            intent.putExtra("ACTION_TYPE", actionCode)
            intent.putExtra("DIFFICULTY_LEVEL", difficultyLevel)
            startActivity(intent)
        }

        // ==========================================
        // ✨ 第四步：修改這裡！
        // 點擊按鈕直接跳轉到專屬的圖表頁面，舊的彈出視窗邏輯都刪掉了！
        // ==========================================
        btnHistory.setOnClickListener {
            val intent = Intent(this, HistoryActivity::class.java)
            startActivity(intent)
        }
    }
}