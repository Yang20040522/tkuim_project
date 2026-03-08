package com.rehabassist.rehabassist

import android.content.Intent
import android.os.Bundle
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.Spinner
import androidx.appcompat.app.AppCompatActivity

class MainActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        val spinnerAction = findViewById<Spinner>(R.id.spinnerAction)
        val btnStartTraining = findViewById<Button>(R.id.btnStartTraining)

        // 1. 設定下拉選單的選項 (未來有第三、第四個動作直接加在這裡)
        val actionOptions = arrayOf("初階翻掌訓練", "手部精細動作 - 側捏")
        val adapter = ArrayAdapter(this, android.R.layout.simple_spinner_dropdown_item, actionOptions)
        spinnerAction.adapter = adapter

        // 2. 按下開始按鈕時的處理邏輯
        btnStartTraining.setOnClickListener {
            // 取得目前下拉選單選到了什麼字
            val selectedAction = spinnerAction.selectedItem.toString()

            // 改用 when 語法！根據選擇的字串，決定傳送的暗號
            val actionCode = when (selectedAction) {
                "初階翻掌訓練" -> "TURN_PALM"
                "手部精細動作 - 側捏" -> "SECOND_ACTION"
                else -> "TURN_PALM" // 防呆機制：萬一發生例外，預設跑翻掌
            }

            // 夾帶暗號跳轉到訓練頁面
            val intent = Intent(this, TrainingActivity::class.java)
            intent.putExtra("ACTION_TYPE", actionCode)
            startActivity(intent)
        }
    }
}