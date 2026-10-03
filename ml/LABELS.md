# 站姿抬腳研究標註規格（待物理治療師審核）

此檔是**待審核草案**，不是已經取得專業核定的臨床標準。標註者應先確認動作定義、鏡頭角度與三類判準，並將核定版編號填入 `actionDefinitionVersion` 及 `labelVersion`。

每筆 JSON 是一次由現有規則式計次界定的完整動作。`subjectId` 是研究匿名代碼，同一受試者跨次應一致；不可填姓名、電話、帳號。Flutter 僅保存 17 個 RTMPose 身體關節的正規化 2D 坐標、信心值、局部角度、時間與分段；不附帶照片、影片或身分資料。匯出須由使用者主動執行，並安全交付標註者。

`labels_template.csv` 每列對應一個 `sampleId`，三種候選標籤（互斥）為：

- `meets_requirement`：符合核定的站姿抬腳要求。
- `insufficient_range`：抬腳活動幅度不足。
- `trunk_compensation`：核定定義的軀幹側傾或前後傾代償。

模糊、遮擋、低信心或不完整資料不要強行歸類；應先排除並記錄原因。不同標註者分歧須由專業人員裁決。`annotatorId` 用非個人化工作代碼。不要把真實受試者 JSON 或已填寫標籤 CSV 提交 Git。

Flutter/Python 固定特徵順序（v1）：最高相對抬腿高度、最小髖角、最小膝角、最大軀幹傾角絕對值、動作秒數。前四項由經肩寬／軀幹尺度正規化的 2D 骨架計算。這是研究性影像平面特徵，**不是 3D／醫療級關節角度**。前鏡頭顯示鏡像不會交換 RTMPose 解剖學左右側。

G4 執行：`python ml/train.py --samples ml/data/export/samples --labels ml/data/export/labels.csv --export-manifest ml/data/export/manifest.json --approval ml/data/governance.json --output ml/output/<unique-model-version>`。資料僅可由現有管理者已審核匯出 API 取得；不要把本機未審核 export 當成正式訓練資料。

治理確認檔由可信研究負責人於匯出後核對並建立，不提交 Git。須包含 `authorizedExportVerified`、`consentAndRetentionVerified`、`professionalDefinitionsApproved`、`independentReviewVerified`（全部 true），以及 `verifiedBy`（工作匿名代碼）、`verifiedAt`、`retentionPolicyVersion`、`labelVersion`、`actionDefinitionVersion`、`exportManifestSha256` 和 `datasetSha256`。後者使用 `train.dataset_digest(samples_dir, labels_csv)` 計算；前者為原匯出 manifest bytes SHA256。先核對授權、倫理、定義、保存政策及獨立審核，不能為通過檢查任意填 true。

這是可信操作員的離線內容確認，**不是**數位簽章、專業資格認證或目前後端同意狀態的重新驗證。每次訓練應取新的授權匯出；已撤回／到期資料與舊副本須依政策處理。沒有上述證據就保持 NOT READY。

資料不足時不輸出模型或準確率。每類 10 筆／5 受試者只是最低工程門檻，非臨床可靠性。固定 200 trees、balanced weights、model seed42；分組 seed0..99 只挑類別覆盖的切分，不依最終測試指標選參數。儲存 metrics 包含混淆矩陣、各類 precision/recall/F1、macroF1、樣本／受試者數、切分與套件版本。synthetic fixture 指標不作真實研究報告。

ONNX 輸出前以 float32 holdout 比較標籤、機率維度／類別順序與最大絕對誤差（≤1e-5）。輸出 `model.onnx`、`model_manifest.json`、`metrics.json`，不覆蓋非空的版本目錄。即使 parity PASS，manifest 仍為 `parity_verified`、`deploymentApproved=false`；必須另做真實資料評估、人工核准及 Android 驗證後，才能納入 App。
