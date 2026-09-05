# Milestone 8.1 — 即時人體姿勢量測

本功能只量測人體姿勢，不判斷復健動作是否正確、不計次、不錄影、不上傳相機畫面或量測結果。DEFAULT 與 CUSTOM 的既有示範／訓練／播放仍使用原本入口。

## 模型來源

- 官方文件：<https://ai.google.dev/edge/mediapipe/solutions/vision/pose_landmarker>
- 官方文件中的 Pose Landmarker Lite 下載連結：<https://storage.googleapis.com/mediapipe-models/pose_landmarker/pose_landmarker_lite/float16/latest/pose_landmarker_lite.task>
- 取得日期：2026-09-05。
- 隨 Android App 打包：`android/app/src/main/assets/pose_landmarker_lite.task`，不在執行時下載。
- 檔案大小：5,777,746 bytes。
- SHA-256：`59929e1d1ee95287735ddd833b19cf4ac46d29bc7afddbbf6753c459690d574a`。
- 已檢查 task bundle 包含 `pose_detector.tflite` 與 `pose_landmarks_detector.tflite`。
- 下載網址包含 `latest`；本次提交的二進位資產以此雜湊固定，不是 build 時自動更新。

## 邊界

新頁面只有一個 native CameraX camera owner，不建立 Flutter `CameraController`，不呼叫既有 RTMPose／Hand Landmarker／訓練引擎。

CameraX PreviewView + ImageAnalysis → Pose Landmarker LIVE_STREAM → EventChannel → Flutter measurement models。

Flutter 再分兩條互不混用的資料流：

- normalized landmarks → native 提供的實際 preview matrix → skeleton painter。
- world landmarks → JointAngleCalculator → 角度文字。

不修改既有 Editor local bone rotation，也不使用 `EvaluationRule.passes()`。

## Native／Flutter 契約

PlatformView type：`com.rehabassist/pose_measurement/preview`。

每個 view 有獨立 channels，避免與舊手部 detector 共用狀態：

- `com.rehabassist/pose_measurement/{viewId}/control`：`start`、`stop`。
- `com.rehabassist/pose_measurement/{viewId}/events`：狀態或量測 frame。

Frame 保留 normalized 與 world 的 33 個 anatomical landmark index、x/y/z、可用的 visibility/presence、單調 timestamp、inference time 及 geometry。無人體時兩個 landmark list 都是空的。

Geometry 的 `matrix` 是 9 個 row-major 數字，將「upright、unmirrored 推論影像的 normalized x/y」映射至「實際 PreviewView 的 normalized x/y」。旋轉、crop、preview mirror 已在 native 合成，不得在 Dart 重複套用。

`imageWidth`／`imageHeight` 是 upright 推論影像尺寸；`rotationDegrees` 是 CameraX 原始 buffer 轉正使用的旋轉量；`previewWidth`／`previewHeight` 是 native preview 實際 pixel 尺寸。Flutter 僅將矩陣結果換算成該 view 的 logical pixels，不根據 aspect ratio 猜 crop。尺寸／transform 尚未就緒時不顯示推測的骨架位置。

CameraX 參考：<https://developer.android.com/media/camera/camerax/transform-output>。

## 既有原生依賴

本輪不升級 MediaPipe／CameraX，不新增 Flutter 相機或 Pose package。

`tasks-vision` 維持 `0.10.9`。雖然 app Gradle 宣告 CameraX `1.3.1`，實作前已透過 `dependencyInsight` 確認現有 `camera_android_camerax` plugin 與 CameraX atomic-group constraints 將實際版本解析為 `1.5.0-beta01`。這是本輪開始前的解析結果，不是本次引入的升級。

`minSdk = 24`、`compileSdk = targetSdk = 36`、既有 CAMERA permission 保持不變。native prebuilt libraries 的 16 KB page-size 相容性仍需另外在目標裝置驗證。

## 量測定義

左右側永遠以被拍攝者自身為準，前鏡頭 mirror 不交換 landmark enum。

三點 A–B–C，以 B 為頂點，利用 world-space 向量 dot product／acos 計算 0–180 度內角：

- 左／右肘：肩–肘–腕。
- 左／右膝：髖–膝–踝。
- 肩軀幹角：肘–肩–髖，僅為幾何夾角。
- 髖軀幹角：肩–髖–膝，僅為幾何夾角。

缺少 world landmark、信心不足、無效數值或零長度向量時顯示 `--`，不回零、不沿用舊角度、不退回螢幕座標。這不是 shoulder/hip flexion 或 abduction，也不是醫療級精度承諾。

## 人工 Android 驗收

1. 以 `flutter run` 啟動 App，登入患者，進入「我的復健動作」。如果同時要測試 Google 登入，沿用原本 `--dart-define=GOOGLE_SERVER_CLIENT_ID=...` 公開 client ID 設定。
2. 分別從 DEFAULT 與 CUSTOM 卡片的「姿勢量測」進入，確認標題帶入正確動作；原卡片點擊仍走原本流程。
3. 初次拒絕相機權限，確認顯示清楚訊息且不 crash；允許後確認前鏡頭啟動。
4. 一人站入鏡頭，確認「已偵測人體」，肩、肘、腕、髖、膝、踝骨架貼合。
5. 在不同畫面比例與直／橫向旋轉下確認骨架不漂移；切換尺寸途中不應顯示使用過期 transform 的骨架。
6. 抬自己的左手／右手，確認鏡像只改畫面位置，不交換左右文字與 landmark identity。
7. 彎左肘，左肘角度下降；手臂伸直接近 180 度。左右膝重複驗證。
8. 遮住局部關節／離開畫面，確認無效角度是 `--`；部分遮擋不把整個人誤報成未偵測。
9. 快速移動，確認畫面不隨時間愈來愈延遲、不 crash。
10. App 切背景／鎖屏，確認相機關閉；回前景可重新初始化。
11. 離開量測頁，確認相機使用指示結束；再次進入可啟動。快速退出正在初始化的頁面後再進入亦須正常。
12. 回歸既有 DEFAULT 手部／全身訓練與 CUSTOM Three.js 播放，確認不受影響。

真機未驗收前，不宣稱 overlay 對齊、實際 inference FPS、熱穩定性或 16 KB 裝置相容性已通過。
