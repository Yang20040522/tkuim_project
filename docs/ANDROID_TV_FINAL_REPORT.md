# Android TV Client — Final Report

## Status

實作已完成；本機 Dart/UI 與模擬 Pi 測試通過。UBOX 實機驗收與 Raspberry Pi end-to-end 尚未完成，不宣稱已在實機驗證。

- Baseline commit: `79bce366321f20f79574ed7863b6f3e8d9b04940`
- Branch: `codex/android-tv-client`
- 沒有 commit 或 push。
- 保留工作目錄原先停用 `NotificationService.init()` 的修改意圖，改為正式 capability gating。

## TV architecture changes

`AppPlatform.configure()` 在 entry point 選擇 capability；此 branch 預設 `TV_CLIENT=true`。`AppCapabilities` 集中提供 isTv、supportsLocalCamera、supportsNotifications、supportsGoogleSignIn、supportsTouchInput、supportsDpad、supportsVideoCalls、supportsScreenRecording。未加入 state-management framework，未改 backend、資料模型或 inference engine。

`TV_CLIENT=false` 可用於檢查保留的 Dart 手機介面；Android manifest 仍屬此 TV branch 的 landscape 設定，不應視為完整手機發行配置。

TV 選擇患者入口，登入與 session 寫入仍使用 AuthService / PatientLoginSession / AppSession；治療師、註冊與復原提示改引導使用手機。Home 改側邊導覽，保留計畫、自由訓練、歷史紀錄與設定。

## Notification crash fix

啟動前先選定 TV capability；TV 不執行 notification plugin 初始化。NotificationService 的初始化與 enable 路徑也設 capability guard。非 TV 的 optional initialization 保留 exception/stack 診斷。登入與 session restore 的 ZEGO invitation initialization 在 TV 跳過；螢幕錄影／權限流程在 TV 跳過。TTS 設定、停止與播放失敗保留 logging，不阻擋訓練。

UBOX 通知 A/B crash 是使用者提供的實機證據；本次驗證實際 main 在 notification method channel 不可用時仍能進入患者入口，未宣稱此次已完成 UBOX 重測。

## Camera / external-frame fix

- 全身 TV route 建立既有 BodyPoseEngine，等待使用者連線後呼叫 `initForExternalFrames()`；不呼叫 local camera init/start/switch，也不偽造 CameraController。
- 手部 TV route 選用既有 PiPoseModel，不請求 camera permission、不建立 native camera PlatformView。
- 無 Pi 時顯示等待／未連線；連線狀態區分 connecting、connected、failed、disconnected，提供重新連線。
- Pi IP 做 IPv4 驗證、IME done 確認、focus 與記憶功能。原先只存於頁面 `_lastPiIp`，現在沿用頁面記憶並加 `tv_pi_camera_ip` preferences；沒有改患者或計畫資料格式。
- TV ONNX 初始化途中離開頁面時，先等初始化完成／失敗，再釋放 engine，避免 init 與 dispose 競爭。

## D-pad / focus implementation

共用 `TvRemoteScope` 將 Select、Enter、numpad Enter 映射到 ActivateIntent，使用 ReadingOrderTraversalPolicy 與 Flutter FocusTraversalGroup。TV 按鈕有明確 4px 橘色 focus 邊框；tap-only 的訓練選側控制改成 FocusableActionDetector，focus 動畫 130ms，並讓捲動區顯示目前焦點。

登入使用明確上下 traversal，帳號 → 密碼 → 登入；數字/IP 輸入使用 TvTextNavigation，上下鍵離開編輯，左右鍵保留游標編輯。頁面設合理 autofocus，取消／繼續等安全 dialog action 取得焦點。對話框關閉由 Navigator/FocusScope 恢復焦點。Back 沿用 Navigator/PopScope；活動訓練時開暫停選單。

## TV UI redesign / screen audit

- Splash：landscape branding，避免手機直式 splash 拉伸。
- Role：患者專用可 focus 入口。
- Login：16:9 雙欄；輸入區可捲动，登入按鈕固定在鍵盤上方的可用空間。
- Home：側邊功能導覽與大字流程。
- Plan：左側日期，右側計畫內容；沿用 patient-scoped repository 與既有開始訓練路徑。
- Training selection：動作區與難度／次數／開始操作區分欄。
- Body/hand training：影像區約 75%、狀態及操作區約 25%，清楚的等待／連線／次數／提示／暫停按鈕。
- IP dialog：IPv4 輸入、validation、focus、IME done。
- Results/history：結果 dialog、大字紀錄與明細，沿用 HistoryService 上傳待同步紀錄。
- 3D：保留 model_viewer_plus、既有 GLB 和各動作相機設定；增加載入、切換左右模型、旋轉、放大縮小、reset、播放暫停與開始訓練按鈕。20 秒 readiness timeout 後顯示文字 fallback／retry；WebView 不搶遙控器焦點。
- Settings：Pi IP、操作說明、可取消的登出。

所有 Screen/Page 宣告的可達性處置列於 `TV_SCREEN_AUDIT.md`。手機通知、QR pairing、聊天／視訊、治療師管理、local-camera body test、live bone viewer、自訂動作編輯等不納入 TV 導覽；shared models 和原始手機介面保留。

## Raspberry Pi pipeline confirmation

WebSocket URI 仍為 `ws://$ip:$port`，預設 port 8765。仍接 binary JPEG。Body 仍使用 `img.decodeJpg` → 3-channel RGB → `processExternalFrame(rgbBytes, width, height, isMirror: false, needsRotation: false)`；手部仍呼叫原有 `detectHandInImage`。decode/inference 呼叫區塊與 baseline 逐字比對相同。

修改限 consumer 生命週期、連線狀態及 bounded pending frame：在握手成功後才標記 connected；失敗的 channel 清理有 timeout；dispose idempotent 且不再更新已 dispose notifier。這是既有錯誤處理修正，不修改 server protocol。

`tv_contract_verification.json` 包含 frozen 檔案差異、ONNX/MediaPipe asset git blob hashes、Pi decode/inference block 比對，以及 body pose callback 在僅替換 rebuild notification 後與 baseline 相同的證據。

## Performance optimizations

- Body pose callback 的評分計算與動作判定完整保留；TV 只在可見提示／次數等變化時更新狀態區 notifier。
- Hand 的高頻 state 更新在專用 ValueListenableBuilder 內，影像與 skeleton 在 JPEG 發布區更新，不重建整個頁面及按鈕。
- 影像 RepaintBoundary；TV body 不對每個 keypoint 跑 tween。
- Pi consumer 忙碌時最多保留一張最新 pending JPEG；不建立無限 queue、不重入 inference，且 inference 完成前不發布 JPEG。
- 全身 TV 畫面使用既有 RTMPose 身體骨架，不另開僅供手機共用殼疊手部骨架的第二條 PiHandSource 連線。
- 手部 TV 停止背景 pulse 裝飾動畫；3D 不自動旋轉，使用者主動載入。
- 沒有變更 ONNX threads/providers、模型、input/output、image rotation、keypoint contract 或判定閾值；沒有無 profiling 證據的大型 image pipeline 改寫。

這些是程式結構及 mock 測試驗證，不是 UBOX FPS、frame latency 或 ONNX 實際效能測量。

## AndroidManifest / package ID

camera、camera.any、camera.autofocus、microphone、touchscreen、Bluetooth、Wi-Fi 均為 optional hardware；leanback optional。APK 實際 manifest 檢查發現 camera_android_camerax 會合併出 required camera.any，已用 tools:replace 明確覆寫為 optional；Wi-Fi/Bluetooth optional 也讓 Ethernet/IR 裝置不受不必要的硬體條件限制。保留 LAUNCHER，增加 LEANBACK_LAUNCHER 與 TV banner。Activity landscape-first，保留 adjustResize 與 cleartext LAN transport。

Package ID 保留 `com.example.flutter_body`。已檢查 namespace/applicationId、native MethodChannels、Google OAuth client configuration 和 API 設定；外部 Google/backend package 註冊狀態無法在 repository 內完整確認，因此沒有自行改成 `.tv`。目前 APK 會使用原 application ID，不能與同 ID 主版並存；安裝與資料共存需要實機核對。

## Tests and verification

TV 新增測試位於 `test/features/tv`，覆蓋：optional notification、實際 main startup、capabilities、IPv4、登入 default focus/上下順序/Select、Enter、Back/焦點恢復、software keyboard 版面、body/hand camera-free waiting、IP persistence、TV home→selection、numeric field traversal，以及 960×540 / 1920×1080 各頁無 overflow。

本機 WebSocket 假伺服器與 FakeEngine 測試驗證 JPEG→RGB 參數、握手失敗、latest-frame-wins、不重入／不提前發布及 dispose during inference。測試沒有載入或執行實際 ONNX inference，並非 native / Pi integration test。

本次新增 16 項 TV/模擬 Pi tests，完整 suite 共 **394 項全部通過**。

| Command | Final result |
| --- | --- |
| flutter clean | 成功；第一次有 Windows 鎖檔提示，待程序結束後已完整重跑成功 |
| flutter pub get | 成功，無依賴版本變更 |
| flutter analyze | 0 errors / 1 existing warning / 44 existing infos；exit 1，與 baseline 相同 |
| flutter test | 394 passed，exit 0 |
| flutter build apk --debug | 成功，exit 0；其後針對 manifest 合併修正又重建並檢查實際 APK |

最終命令 exit code 列於 `tv_verification_results.json`。完整 console logs 位於 workspace 的 `tv-clean.log`、`tv-pub-get.log`、`tv-analyze.log`、`tv-all-tests.log`、`tv-build.log`。

Analyzer 有 45 項 baseline 既有診斷：0 errors、1 warning、44 infos。依 file + diagnostic code + severity 比對，新增 0、移除 0；因此 analyzer exit 1 是既有 warning/info，不能宣稱為零警告。詳細見 `tv_analyzer_comparison.json`；baseline 暫存抽取沒有帶 assets，該暫存目錄額外的 9 項 asset-missing 提示已在比較中明確排除。

## Remaining real-device tests / known risks

1. **NEEDS REAL DEVICE VALIDATION**：UBOX 安裝、冷啟動、通知缺失、無 Google services、真實帳密 API 登入、Android TV IME、實際 DPAD_CENTER/Back、launcher banner、overscan 與不同 display density。
2. **NEEDS REAL DEVICE VALIDATION**：Android TV WebView/GLB 載入與控制、WebGL/原生 plugin 初始化錯誤、20 秒 fallback、GPU 記憶體與長時間播放。Dart timeout 無法保證攔截 OS/native process crash。
3. **NEEDS REAL HARDWARE VALIDATION**：Raspberry Pi IP → 真實 JPEG stream → ONNX/MediaPipe inference → pose → training judgment 全鏈路；本次沒有 Raspberry Pi。
4. UBOX 上的實際 FPS、p95 inference/frame latency、長時間 RSS、熱節流與網路重連仍未量測。不得把 bounded-queue 測試解讀成辨識準確率不變的實機證明。
5. APK 仍包含既有模型、素材與 native plugins，debug universal APK 約 566 MiB，包含 arm64-v8a、armeabi-v7a、x86_64；未為減小體積而刪除 frozen assets 或改依賴。
6. 保留原 package ID，不支援同 ID 主版共存。後端 live API 與 OAuth 外部註冊未連線驗證。
7. 原有計畫完成、訓練記錄、retry/action reset 與判定策略沿用 baseline，未藉 TV 改造重寫；無影像時結束／退回等邊界仍應列入實機業務驗收。

## Explicit frozen confirmation

| Contract | 結論 | 證據 / 限制 |
| --- | --- | --- |
| Raspberry Pi connection protocol | 保持不變 | URI/port/binary JPEG；本機 WS mock 已測，真 Pi E2E 未驗證 |
| External-frame format | 保持不變 | decode/inference block 相同；RGB shape、mirror/rotation 參數 mock 已測 |
| RTMPose / ONNX models | 保持不變 | 所有 tracked `.onnx` / `.task` hash 與 baseline 一致 |
| Pose result / keypoint contract | 保持不變 | BodyPoseEngine、PoseData、models/interfaces/controller 未修改 |
| Training judgment logic | 保持不變 | lib/actions、controller、pose measurement 核心未改；body callback 只換 UI notification |

上述「保持不變」是程式碼／檔案與契約核對結論；真正 Raspberry Pi end-to-end 一律 **NEEDS REAL HARDWARE VALIDATION**。

## Changed files

### Existing files modified

- `android/app/src/main/AndroidManifest.xml`
- `lib/features/account/home_router.dart`
- `lib/features/account/login_screen.dart`
- `lib/features/account/role_select_screen.dart`
- `lib/features/call/zego_call_invitation_service.dart`
- `lib/features/notification/notification_service.dart`
- `lib/features/plan/plan_screen.dart`
- `lib/features/rehab/body_training_screen.dart`
- `lib/features/rehab/training_screen.dart`
- `lib/features/splash/splash_screen.dart`
- `lib/features/training/action_list_screen.dart`
- `lib/features/training/training_preview_screen.dart`
- `lib/main.dart`
- `lib/services/pi_camera_source.dart`
- `lib/services/pi_hand_source.dart`
- `lib/services/screen_recorder_service.dart`
- `lib/services/voice_service.dart`
- `lib/widgets/completion_dialog.dart`
- `lib/widgets/pi_ip_dialog.dart`

### TV-specific files added / tests / evidence

- `android/app/src/main/res/drawable/tv_banner.xml`
- `docs/ANDROID_TV_FINAL_REPORT.md`
- `docs/TV_SCREEN_AUDIT.md`
- `docs/tv_analyzer_comparison.json`
- `docs/tv_contract_verification.json`
- `docs/tv_verification_results.json`
- `lib/core/platform/app_platform.dart`
- `lib/core/ui/tv_ui.dart`
- `lib/features/tv/tv_demo_viewer.dart`
- `lib/features/tv/tv_home_screen.dart`
- `lib/features/tv/tv_login_form.dart`
- `test/features/tv/fixtures/frame.jpg`
- `test/features/tv/pi_camera_source_test.dart`
- `test/features/tv/tv_client_test.dart`

## APK artifact

- Path: `E:/tkuim_project-tv/build/app/outputs/flutter-apk/app-debug.apk`
- SHA-256: `553e37bdf11491284ba1e6fc7e9cb98ddcd2aa4f4d1f63a84428eae0eb659307`
- 實際 APK 經 aapt badging/xmltree 核對：package ID、兩種 launcher、landscape 與 camera/camera.any/touchscreen 等 optional hardware 正確。
- 產物大小及 command exit codes：`tv_verification_results.json`。
- `git diff --check` 通過；沒有 commit / push。
