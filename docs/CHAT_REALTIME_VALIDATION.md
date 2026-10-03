# 真人即時聊天實作與驗證紀錄

日期：2026-10-03。Frontend master 基準 `6bafcdaecf574d7bf86b4752911222fd05f1aac1`；Backend main 基準 `07f5e3b082c953fae5703880d4abf8b7fbac4f3f`。
兩個工作樹開始時乾淨。本次成果尚未 commit／push／部署；真實 Render + 兩手機端到端驗收 **NOT TESTED**。

## 實作

- 沿用 `ChatBackend` streams／REST，新增獨立 STOMP transport 和單一連線 owner。
- `stomp_dart_client: 2.0.0`，相容既有 `web_socket_channel 2.4.0`，不升級其他套件。2.1.3 與現有 websocket 版本約束不相容，故未使用。
- 私人 `/user/queue/chat-events`；CONNECT 使用現有身分 headers，URL 由 ApiConfig 推導，不含 Token 或資料庫 IP。
- 私人訂閱收到 CONNECTION_READY 才補同步。事件只刷新有訂閱的對應 messages 和本人列表／未讀數，沒有 contacts／無關聊天室查詢。
- dirty coalescing 修正請求中 refresh 遺失；REST 回傳全量最近 200 則取代 snapshot，沒有 append 重複訊息。
- 按最後更新時間排序 contacts；原訊息 UI、頭像、已讀樣式、主藍發送按鈕保持不變。
- 開啟中的目前 route 才自動標記讀取；背景／被其他 route 覆蓋時不自動讀。
- 非前景、無訂閱者或 dispose 停止 socket；AppSession 變更立即關閉舊連線、忽略舊回應。AppSession 僅新增變更 notifier，未改驗證／ZEGO 邏輯。
- bounded backoff／20 秒握手 timeout／25 秒 heartbeat，無持續 REST polling。REST fallback 為既有傳送、讀取及手動刷新，沒有背景 timer。

## 變更檔案

Frontend：

- `lib/features/chat/chat_realtime_connection.dart`（新增）
- `lib/features/chat/rest_chat_backend.dart`
- `lib/features/chat/chat_home_screen.dart`
- `lib/features/chat/remote_chat_screen.dart`
- `lib/features/account/app_session.dart`
- `pubspec.yaml`
- `pubspec.lock`
- `test/features/chat/chat_realtime_test.dart`（新增）
- `docs/CHAT_REALTIME_VALIDATION.md`（新增）

Backend：

- `pom.xml`
- `src/main/java/com/example/trainingsystems/service/ChatService.java`
- `src/main/java/com/example/trainingsystems/chat/ChatRealtimeEvent.java`（新增）
- `src/main/java/com/example/trainingsystems/chat/ChatRealtimeNotifier.java`（新增）
- `src/main/java/com/example/trainingsystems/chat/ChatStompInterceptor.java`（新增）
- `src/main/java/com/example/trainingsystems/chat/ChatWebSocketConfiguration.java`（新增）
- `src/test/java/com/example/trainingsystems/service/ChatServiceTest.java`
- `src/test/java/com/example/trainingsystems/chat/ChatStompInterceptorTest.java`（新增）
- `src/test/java/com/example/trainingsystems/chat/ChatRealtimeTransactionTest.java`（新增）
- `src/test/java/com/example/trainingsystems/chat/ChatWebSocketIntegrationTest.java`（新增）
- `docs/CHAT_REALTIME.md`（新增；契約、安全、Render 部署及人工清單）

沒有修改 Docker、Tailscale、JDBC、Entity、Controller、Schema、migration、Android native、AI Chat、ZEGO、TV 或復健演算法。

## 實際驗證

| 指令 | 結果 | 本機證據 |
|---|---|---|
| `flutter pub get` | PASS | 只新增 stomp 2.0.0，既有 websocket 2.4.0 保留 |
| changed Dart files `dart format` | PASS | 限本次 6 個 Dart 檔 |
| `flutter test test/features/chat test/features/account/therapist_chat_navigation_test.dart --reporter expanded` | PASS 40/40 | `build/g35/chat-flutter-focused.log` |
| `flutter analyze lib/features/chat test/features/chat lib/features/account/app_session.dart` | PASS 0 issues | 2026-10-03 最終 console |
| `flutter test --reporter expanded` | FAIL：458 PASS / 7 FAIL | `build/g35/chat-full-flutter-test.log` |
| `flutter analyze` | 47 既有診斷：44 info、3 warning、0 error | `build/g35/chat-full-analyze.log`；全部在此次未修改的其他檔案 |
| Backend focused tests | PASS 31/31 | backend `target/chat-focused.log` |
| Backend full `mvn test`（本機 MySQL wrapper） | PASS 276/276、0 skip | backend `target/chat-full-mysql.log` |
| Backend `mvn package -DskipTests` | PASS | backend `target/chat-package.log` |
| `git diff --check`（兩個 repository） | PASS | 最終 console；只有既有 autocrlf 換行提示 |

新 Dart 測試 9 項，含實際 Dart STOMP SDK 對 localhost WebSocket fake server 的 wire 協議；其餘用可注入 transport／Mock HTTP 驗證事件、未讀／已讀、無重複 snapshot、dirty race、斷線重連、前景／登出、無訂閱不查詢和 REST fallback。
Backend localhost TCP WebSocket 使用真 Spring broker、mock identity；transaction 測試是隔離 H2。完整後端 suite 另含原 21 項真 MySQL integration，不能混稱正式端到端驗收。
未執行新 APK build／Android 真機／正式部署；本次沒有 native／推論／打包設定變更。

## 七項既有失敗：完整保留，不宣稱全數通過

| Test / case | 本次重現原因 |
|---|---|
| `account_info_screen_test`：Google/account ID display | 原 AppSession.save 的 ZEGO 800ms timer 殘留於 teardown |
| `account_info_screen_test`：account ID update | 同上 |
| `account_recovery_therapist_registration_test`：successful registration | 同上 |
| `friend_management_screen_test`：API friend-code refresh | 同上 |
| `training_result_history_page_test`：selected patient | 預期 legacy repository，但目前使用 REST training history |
| `patient_training_videos_card_test`：reps/play | 舊 `1次失誤` 與目前 `1項訓練修正紀錄` 文字不同 |
| `dual_screen_assisted_training_ui_test`：phone port | 測試把獨立 label 當成 TextField label |

同樣七個 case／原因已在 `docs/G35_VALIDATION.md` 以舊 master `a413cd8` 匯出快照實測；當前未修改相關測試或上述功能。此次 full suite 從基準的 449/7 增為 458/7；不刪除、跳過或放寬測試。
Full analyze 47 項與基準記錄相同；新增範圍 0 issues。

## 待人工驗收

先 review／由使用者部署 Backend，再安裝新手機端；不執行任何 SQL 或改 Render secrets。詳細順序見 backend `docs/CHAT_REALTIME.md`。
兩支手機以合法綁定／好友帳號驗證 Hello 即時抵達、已讀、列表排序／未讀、斷線及前景補同步、登出／換帳號、解除關係拒絕、無輪詢，另回歸 AI／ZEGO。
沒有驗收前，狀態為「本機實作與聚焦驗證完成；正式 E2E 待驗收」，不是已部署成功。
