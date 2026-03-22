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
        // ✨ 新增：抓取畫面上的「難度」下拉選單
        val spinnerDifficulty = findViewById<Spinner>(R.id.spinnerDifficulty)
        val btnStartTraining = findViewById<Button>(R.id.btnStartTraining)

        // 1. 設定主動作選項
        val actionOptions = arrayOf("翻掌訓練", "手部精細動作 - 側捏")
        spinnerAction.adapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, actionOptions)

        // 2. ✨ 核心魔法：連動機制！當主動作被選擇時，動態替換難度選單的內容
        spinnerAction.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
            override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
                val selectedAction = actionOptions[position]

                // 根據選到的動作，準備對應的難度選項
                val difficultyOptions = if (selectedAction == "翻掌訓練") {
                    arrayOf("Level 1 (初階 - 容錯較高)", "Level 2 (中階 - 要求嚴格)")
                } else {
                    // 假設側捏目前只有一個難度，未來可以再擴充
                    arrayOf("Level 1 (標準側捏)")
                }

                // 把準備好的難度選項塞進第二個下拉選單裡
                spinnerDifficulty.adapter = ArrayAdapter(
                    this@MainActivity,
                    android.R.layout.simple_spinner_dropdown_item,
                    difficultyOptions
                )
            }

            override fun onNothingSelected(parent: AdapterView<*>?) {}
        }

        // 3. 按下開始按鈕時的處理邏輯
        btnStartTraining.setOnClickListener {
            val selectedAction = spinnerAction.selectedItem.toString()

            // 取得難度選單目前選的是第幾個 (0 代表第一個選項，也就是 Lv1)
            val selectedDifficultyPos = spinnerDifficulty.selectedItemPosition

            val actionCode = when (selectedAction) {
                "翻掌訓練" -> "TURN_PALM"
                "手部精細動作 - 側捏" -> "SECOND_ACTION"
                else -> "TURN_PALM"
            }

            // 算出實際難度等級 (因為程式從 0 開始數，所以加 1 變成 Lv1, Lv2)
            val difficultyLevel = selectedDifficultyPos + 1

            // 夾帶動作暗號與難度等級，跳轉到訓練頁面
            val intent = Intent(this, TrainingActivity::class.java)
            intent.putExtra("ACTION_TYPE", actionCode)
            intent.putExtra("DIFFICULTY_LEVEL", difficultyLevel) // 傳送難度！
            startActivity(intent)
        }
    }
}