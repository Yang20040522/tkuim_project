# Round 8 — 全身研究審核與跨裝置隱私主開關

## 範圍與架構

Round 7 的 IMX500 → Pi JPEG/edge-v1 → TV ROI 還原 → RTMPose WholeBody 133 → `BodyPoseObservation` 路徑維持原樣；Pi、網路、影像傳輸與計數狀態機均未修改。研究收集從已還原到原始完整影格座標的觀測資料讀取 17 個身體點，不保存 JPEG、影片、裁切圖、IMX500 框或 edge-v1 中繼資料。

原本僅 `standing_knee_raise` 可在 TV 上保存研究樣本。現在七種正式復健動作均在 `BodyResearchActionRegistry` 中明確登錄；`body_skeleton_test` 不在登錄表中。六種新增動作由有界的 `BodyReviewRepCollector` 被動取樣，只在既有 `RehabFeedback.scored` 完成次數邊界產生樣本。研究開關不產生次數、不變更 hold、難度、語音與完成狀態。未完成次數不產生 v4 樣本；站姿抬腳仍使用原本較完整的 v3 attempt 路徑。

| 動作 ID | 版本 | 研究 schema | 側別 |
| --- | --- | ---: | --- |
| `standing_knee_raise` | `standing-knee-raise-body-v2` | 3 | 原有左右腳語意 |
| `draw_circle` | `draw-circle-body-review-v1` | 4 | 實際使用手臂左右 |
| `overhead_reach` | `overhead-reach-body-review-v1` | 4 | 選定訓練手左右 |
| `raise_both_arms` | `raise-both-arms-body-review-v1` | 4 | `bilateral` |
| `elbow_forward` | `elbow-forward-body-review-v1` | 4 | `bilateral` |
| `sit_to_stand` | `sit-to-stand-body-review-v1` | 4 | `bilateral` |
| `lateral_step` | `lateral-step-body-review-v1` | 4 | 原訓練腳左右 |

側別無法由動作權威狀態決定時，該次研究樣本不建立。側跨步的 `simple`/`hard` 直接取自動作狀態；難度標籤亦取自動作。鏡像顯示不反轉解剖左右。

## 契約、後端與審核

站姿抬腳 v3 的 schema、版本、五項 frozen 特徵、R4 匯出與 R5 適用條件維持不變。新增六種動作使用獨立的 body schema 4：`featureNames=[]`、`features=[]`、`featuresStatus=not_applicable`、`body-review-label-v1`，可選 `meets_requirement`、`needs_correction`、`unassessable`；`trainableLabels` 為空。這些是治療師研究審核標註，尚無已驗證的此類動作 ML 模型。R4/R5 站姿模型不得套用到 v4，正式 ML 匯出明確拒絕 schema 4。

v4 樣本記錄動作/練習/attempt、來源 `tv_pi`、平台 `android_tv`、側別、可用的模式與難度、次數與組數、品質、時間及 17 點影格。影格包含單調 `frameId`/`timestampMs`、尺寸、鏡像/旋轉、來源與姿勢版本、關鍵點、分數和有效遮罩；無效點位置為 `null`。每 100 ms 最多取一影格、最多 20 秒與 200 影格，路由離開、停用、帳戶變動與狀態重置時清空。

後端使用獨立 `ResearchBodyReviewValidator` 白名單驗證 schema 4，包括確切動作版本、來源/平台、17 點、數值與遮罩、影格順序、時長、近年拍攝、無客戶端身分欄位等。既有資料表的 schema version、action ID、JSON payload、側別足夠；**沒有資料庫 migration**。每次上傳必須有同一患者、同一 DEFAULT 動作的有效持久治療師指派；CUSTOM 拒絕。審核沿用 DRAFT → SUBMITTED → 獨立 reviewer APPROVE/RETURN/NEEDS_RESAMPLE/REJECT、修訂版檢查與原樣本不可變；重採樣必須同患者、同動作、同練習情境與待重採樣母樣本。

後端 `research.body-available-actions` 是明確的 body 範圍清單，預設僅 `standing_knee_raise`。要在未來部署時開放六種新動作，先由部署管理者審核設定為 `standing_knee_raise,draw_circle,overhead_reach,raise_both_arms,elbow_forward,sit_to_stand,lateral_step`；本 Round **未部署**，現有環境不會自動啟用新範圍。手部仍需獨立的 `handAvailable` 授權，主開關不能越過它。

## 統一隱私同意

手機與 TV 使用同一患者帳戶的後端同意狀態。正常使用者介面顯示單一「允許匿名復健研究資料收集」開關；刪除既有研究資料是獨立確認動作。開啟前先 GET 最新同意版本，再 PUT；關閉立即停止本地新收集，隨後 PUT 撤回。OFF 仍可進行復健與計數，已存本機樣本保留至使用者自行刪除；不回溯上傳原先未經授權收集的樣本。

`ResearchCollectionGate` 的正面授權快取最多有效 **25 秒**，活動中的研究 session 每 **20 秒**刷新；頁面重新顯示也強制刷新。因此遠端撤回對活動 session 的正常收斂界限為 25 秒內，且超過 25 秒、網路失敗或無法確認時新樣本與新佇列項目均 fail closed。登出或切換帳戶立即清空授權與 collector；上傳仍須通過後端當下的有效同意。不同裝置共用 server consent row，沒有裝置別 subject ID。

## 驗證與交付邊界

- Backend：`mvn -q test` 完成，340 tests；33 個需另啟用的整合測試為 skipped。`mvn -q -DskipTests package` 完成。
- Flutter master 聚焦測試：196 tests 通過；TV 聚焦測試：137 tests 通過，另 action registry 2 tests 通過。最後 UI 文案與遙控器按鍵調整後重新執行聚焦測試/分析。
- 本地合成流程涵蓋後端 consent、schema 4 上傳、治療師清單/詳情、草稿、提交、獨立審核、NEEDS_RESAMPLE 與跨動作拒絕；TV 合成觀測資料驗證 17 點、六動作 scored 邊界與主開關 OFF。這是分層 synthetic 驗證，**不是**實體裝置、真實 HTTP/資料庫或臨床驗證。
- 四個 Android Debug/Release APK 均已建置；最後增量建置結果與 Release SHA-256 另於最終報告列出。
- 已知未納入本次變更的廣域 account 測試有 3 個 Zego session pending timer 失敗；本 Round 聚焦測試通過。未執行 Lab DB、Render、Pi、push 或實機七動作測試。

部署狀態：本地程式碼與 APK；**未 push、未部署、未遷移 Lab DB**。啟用 v4 生產上傳仍需先部署後端並設定明確 body 可用動作清單。
