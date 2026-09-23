# 站姿抬腳研究標註規格（待物理治療師審核）

此檔是**待審核草案**，不是已經取得專業核定的臨床標準。標註者應先確認動作定義、鏡頭角度與三類判準，並將核定版編號填入 `actionDefinitionVersion` 及 `labelVersion`。

每筆 JSON 是一次由現有規則式計次界定的完整動作。`subjectId` 是研究匿名代碼，同一受試者跨次應一致；不可填姓名、電話、帳號。Flutter 僅保存 17 個 RTMPose 身體關節的正規化 2D 坐標、信心值、局部角度、時間與分段；不附帶照片、影片或身分資料。匯出須由使用者主動執行，並安全交付標註者。

`labels_template.csv` 每列對應一個 `sampleId`，三種候選標籤（互斥）為：

- `meets_requirement`：符合核定的站姿抬腳要求。
- `insufficient_range`：抬腳活動幅度不足。
- `trunk_compensation`：核定定義的軀幹側傾或前後傾代償。

模糊、遮擋、低信心或不完整資料不要強行歸類；應先排除並記錄原因。不同標註者分歧須由專業人員裁決。`annotatorId` 用非個人化工作代碼。不要把真實受試者 JSON 或已填寫標籤 CSV 提交 Git。

Flutter/Python 固定特徵順序（v1）：最高相對抬腿高度、最小髖角、最小膝角、最大軀幹傾角絕對值、動作秒數。前四項由經肩寬／軀幹尺度正規化的 2D 骨架計算。這是研究性影像平面特徵，**不是 3D／醫療級關節角度**。前鏡頭顯示鏡像不會交換 RTMPose 解剖學左右側。

執行：`python ml/train.py --samples <private-json-directory> --labels <private-labels.csv> --output <private-output-directory>`。資料不足時訓練程式拒絕產生模型或準確率；測試集按受試者分組。實際部署 ONNX 前須另做裝置端輸入／輸出與真機驗證。
