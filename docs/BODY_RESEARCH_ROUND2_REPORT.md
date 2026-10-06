# Round 2 — Body Research Pipeline Foundation Implementation Report

日期：2026-10-06。狀態：PARTIAL（程式／聚焦測試／Debug Build 完成；實機與 MySQL 驗收尚未完成）。
只使用 synthetic fixtures；未執行正式研究收集、模型訓練、部署或 production SQL。

## 1. Implementation Summary
正式 TV/Pi 路徑：
Pi JPEG WebSocket → PiCameraSource → 同一 BodyPoseEngine/RTMPose →
immutable BodyPoseObservation → passive BodyResearchAttemptCollector →
body schema v3 → owner-local repository → consent-controlled upload queue →
既有 research Backend。

JPEG、frameId、尺寸、receipt monotonic timestamp、overlay、research observation 原子配對。
不額外開 RTMPose/camera session。未更改正式復健計次演算法。
master 保留 phone body v1 / MediaPipe hand v2；TV 只有 body 正式研究。
Phone v3 共用基礎具備，但未新增另一個手機 camera training route。

## 2. Files Added
以下檔名均為 repository-relative，可由相應工作樹開啟。

### Flutter master 與 TV 共同新增
- lib/models/body_pose_observation.dart
- lib/features/rehab_ml/body_research_assignment_client.dart
- lib/features/rehab_ml/body_research_attempt_collector.dart
- lib/features/rehab_ml/body_research_context.dart
- lib/features/rehab_ml/body_research_contract.dart
- lib/features/rehab_ml/body_research_feature_extractor.dart
- lib/features/rehab_ml/body_research_sample.dart
- lib/features/rehab_ml/body_research_session.dart
- lib/features/rehab_ml/body_research_settings_page.dart
- lib/features/rehab_ml/research_owner_scope.dart
- test/features/rehab_ml/body_research_contract_test.dart
- test/features/rehab_ml/body_research_foundation_test.dart
- test/features/rehab_ml/body_research_owner_test.dart
- test/features/rehab_ml/body_research_session_test.dart
- test/features/rehab_ml/pi_body_observation_test.dart
- test/fixtures/body_attempt_v3_synthetic.json
- docs/BODY_RESEARCH_ROUND2_PROGRESS.md

### TV 額外新增（master 原本存在，逐檔相容移植）
- lib/features/rehab_ml/ml_action_definition.dart
- lib/features/rehab_ml/ml_research_api.dart
- lib/features/rehab_ml/ml_research_sync.dart
- lib/features/rehab_ml/ml_sample_repository.dart

### master 額外新增
- docs/BODY_RESEARCH_ROUND2_REPORT.md（本報告）

### Backend main 新增
- docs/BODY_RESEARCH_ROUND2_PROGRESS.md
- docs/database-rebuild/mysql/V004__body_attempt_research.sql
- src/main/java/com/example/trainingsystems/service/ResearchBodyAssignmentService.java
- src/main/java/com/example/trainingsystems/service/ResearchBodyAttemptValidator.java
- src/test/java/com/example/trainingsystems/service/ResearchBodyAttemptTest.java
- src/test/java/com/example/trainingsystems/service/ResearchBodyMigrationTest.java
- src/test/resources/body_attempt_v3_synthetic.json

## 3. Files Modified
### Flutter master
- .gitignore：忽略安全 TV 工作樹 /.worktrees/，不再置於 flutter clean 會刪除的 .dart_tool。
- lib/features/rehab_ml/hand_research_session.dart：owner/generation 與 logout guards，不改 hand 特徵或計次。
- lib/features/rehab_ml/ml_action_definition.dart：明確 v3 dispatch，v1/v2 不變。
- lib/features/rehab_ml/ml_research_api.dart：immutable identity、await guards。
- lib/features/rehab_ml/ml_research_sync.dart：per-owner queue/ACK、停止與 consent guards。
- lib/features/rehab_ml/ml_sample_repository.dart：owner 路徑/envelope、未歸屬資料隔離、原子序列化寫入。
- lib/features/rehab_ml/ml_sample_sheet.dart：owner/cache/非同步同意 guards。
- lib/services/body_pose_engine.dart：相容 observation callback、外部 frame generation、finite checks；保留 mobile path。
- lib/services/pi_camera_source.dart：atomic frame/generation/isolate/latest-pending/throttle。
- pubspec.yaml
- pubspec.lock
- test/features/rehab_ml/ml_research_cloud_test.dart：改為真正 owner-bound fixture。
- test/features/rehab_ml/standing_knee_raise_sample_test.dart：加入登入身分 fixture。

### Flutter TV
- lib/actions/standing_knee_raise_action.dart：唯讀 movingLegIsLeft getter，源自現有 action mapping。
- lib/features/account/app_session.dart：identity generation notifier。
- lib/features/rehab/body_training_screen.dart：opt-in body research、真實 assignment、lifecycle、同幀 overlay。
- lib/services/body_pose_engine.dart：保留 TV compute isolate，加入相容 observation/generation/finite checks。
- lib/services/pi_camera_source.dart
- pubspec.yaml
- pubspec.lock
- test/features/tv/pi_camera_source_test.dart：配合 atomic packet 測試。
pub get 後下列 tracked generated files 顯示 M，但 git diff 無語意內容差異（換行/stat）；
未 restore 或手動更改：
- linux/flutter/generated_plugin_registrant.cc
- linux/flutter/generated_plugin_registrant.h
- linux/flutter/generated_plugins.cmake
- macos/Flutter/GeneratedPluginRegistrant.swift
- windows/flutter/generated_plugin_registrant.cc
- windows/flutter/generated_plugin_registrant.h
- windows/flutter/generated_plugins.cmake

### Backend main
- src/main/java/com/example/trainingsystems/entity/ResearchSampleEntity.java
- src/main/java/com/example/trainingsystems/entity/ResearchAnnotationEntity.java
- src/main/java/com/example/trainingsystems/entity/ResearchAnnotationRevisionEntity.java
- src/main/java/com/example/trainingsystems/entity/ResearchAuditEntity.java
- src/main/java/com/example/trainingsystems/repository/ResearchSampleRepository.java
- src/main/java/com/example/trainingsystems/service/ResearchActionRegistry.java
- src/main/java/com/example/trainingsystems/service/ResearchDataService.java
- src/main/java/com/example/trainingsystems/service/ResearchSampleValidator.java

## 4. Branch Capability Migration Summary
| 工作樹 | 基準／目前 HEAD | 新 Commit | 結果 |
|---|---|---|---|
| Flutter master | 91fdd2ba1b7406b83406bbd45af76ff1ebd91584 | 無 | shared/mobile 修改未提交 |
| Flutter codex/android-tv-client | 2f3b67e544475ba3b35de129c8964f1ec3042635 | 無 | TV/shared 修改未提交 |
| Backend main | c5fa9eb6243f14923fc0b3f0cefce5db254d5a67 | 無 | backend 修改未提交 |

工作流修正前曾建立 codex/body-research-foundation 空分支（兩個 repo），只有基準，
沒有 implementation commits；修正後未再建分支，實作位於指定 master/TV/main。
沒有整支 merge/cherry-pick、force reset、遺失工作、push/deploy。
TV checkout 位於 C:/Users/kuoja/Documents/GitHub/tkuim_project/.worktrees/round2-tv。
搬移僅改 checkout 位置，不更改 branch/程式內容；Windows Gradle daemon 已停止釋放鎖。
TV login/DPAD/main/manifest 保持 TV 版本，mobile manifest/Release keep rules 保持原版。
image 4.8.0 及 TV crypto 3.0.7 是既有鎖定版本轉 direct dependency，沒有 dependency upgrade。

## 5. Schema v3 Final Contract
- schemaVersion=3、modality=body；source=phone|tv_pi；動作 standing_knee_raise。
- actionDefinitionVersion=standing-knee-raise-body-v2。
- extractorVersion=standing-knee-raise-aspect-2d-v2。
- modelInputVersion=body-attempt-features-v1。
- poseModelVersion=rtmpose-wholebody-133-v1。
- coordinateTransformVersion=rtmpose-image-normalized-v1。
- sampleId=attempt UUID；sessionId、attemptId、exerciseType、真實 exerciseId、source/platform。
- streamSessionId、末 frameId；frames 每幀含 frameId/streamSessionId/timestampMs、
  timestampOrigin、captureTimestamp、尺寸、mirror/rotation、source/model/transform metadata。
- Pi captureTimestamp=null、timestampOrigin=tv_receive_monotonic，不是 sensor timestamp。
- 僅傳前 17 個 body points；normalized image XY 或 null；raw scores、
  validity；scoreSemantics=simcc_peak_mean_uncalibrated，值可大於 1，並非 probability。
- 2D projected angles（hip/knee/trunk）、featureNames/features/status、duration、
  terminationReason、setIndex、completedRepsBefore/After、intendedRepetition、trackingQuality。
- capturedAt 是 session UTC metadata，與 receipt monotonic frame timing 分開。
- client 不傳 patientId/therapistId/token；backend 依 auth/assignment/binding 判定。
- 先還原 image width/height aspect，再做角度及 torso-length normalization；
  不產生 world coordinates/3D ROM，也不再次交換 anatomical LR。
- score>=0.3 的有效 geometry；至少 4 valid frames、有效比例>=0.6、
  duration>0 才提供五個 features，否則 features 全 null/unavailable。
- Dart/Java 同一 synthetic fixture 重算契約通過；Python 留待後續，未聲稱已驗證。
- v3 與 body v1/hand v2 分開 dispatch；v3 不能進入既有 v1 classifier/export。

## 6. Attempt Collector Behavior
DISABLED → READY → RECORDING → FINALIZING → READY。
movement confirmation=200ms、pre-roll=500ms、baseline confirmation=300ms、
tracking loss=500ms、max duration=20s、max observations=200。
READY 的長 receive gap 會清 movement confirmation，不以斷訊時間建立假 attempt。
終止原因：RETURNED_TO_BASELINE、USER_FINISHED、INTERRUPTED、TRACKING_LOST、TIMEOUT。
有效但未成功計次的 attempt 仍保存；沒有成立的有效 pose 不製造樣本。
training rep/set 唯讀；pause/background/reconnect/logout 中斷研究，不回寫正式計次。
TV 依既有 moving-leg selection，不雙重 LR swap。研究 hip<165° movement /
>=172° baseline 是獨立工程分段，非臨床判定。

## 7. Backend Changes
沿用既有 samples endpoints、auth/HMAC、consent、binding、authority、review。
v3 strict validator 限定欄位/metadata/大小/frames/version，重算 validity/geometry/features。
DEFAULT assignment 必須 active、exercise 真實 ID/站姿抬腳目錄名稱、
assigning therapist 現有 binding。
CUSTOM 缺可信任 action-definition mapping，目前拒絕，不用 GLB 或任意 index 冒充。
same owner/sample 或 owner/attempt、same canonical payload idempotent；
不同 payload 409、invalid schema 400、invalid assignment 403。
新增 metadata/SampleView，review/revision/audit schemaVersion nullable，舊資料相容。
v1/v2 聚焦測試仍通過；未新增平行 sample table。

## 8. DB Migration Result
V004 新增 research_samples modality/source/schema_version/action_id/session_id/
attempt_id/exercise_type/exercise_id/disposition。
annotation/revision/audit nullable schema_version。
participant+attempt UNIQUE；source/modality index；v3 completeness CHECK 明確檢查
IS NOT NULL，避免 SQL NULL 使 CHECK 漏驗。
disposition=ACTIVE|EXCLUDED|NEEDS_RESAMPLE，預設 ACTIVE。
V001/V002/V003 未改。
PASS：2 項 migration static compatibility tests。
NOT RUN：V004 實際 MySQL、Hibernate validate、舊 row live compatibility。
原因：測試環境 DB_URL 未提供；沒有連 production 或擅自套用 DDL。

## 9. Account Isolation Result
immutable owner/user/token/generation snapshot；SHA256 owner-specific local directory/queue。
constructor 已有 session 時立即綁 owner，避免尚未首存就換帳號被繼承。
async 前後檢查 owner/generation；A→B→A 也失效；登出停 collector/sync/清 UI。
舊 unowned root samples 原地隔離，不自動歸給下一帳號或使用其 token。
本機 consent 和 cloud consent 分開；拒絕 cloud 仍可本機收集。
queue 只接受目前 owner 已保存且匹配的 payload；ACK 不跨 owner。
PASS：account races/concurrent save/idempotency/export/legacy quarantine 聚焦測試。
帳號切換與真實裝置 storage 仍需 runtime acceptance。

## 10. Test Results
### 最終 master 聚焦：PASS 58/58
指令（同一次 flutter test 呼叫，下列九檔）：
- test/features/rehab_ml/body_research_foundation_test.dart
- test/features/rehab_ml/body_research_owner_test.dart
- test/features/rehab_ml/pi_body_observation_test.dart
- test/features/rehab_ml/body_research_session_test.dart
- test/features/rehab_ml/body_research_contract_test.dart
- test/features/rehab_ml/ml_action_contract_test.dart
- test/features/rehab_ml/ml_research_cloud_test.dart
- test/features/rehab_ml/g5_hand_session_test.dart
- test/features/rehab_ml/standing_knee_raise_sample_test.dart
命令末尾 --no-pub。
58 是實際通過測試數，不是檔案數。

### TV 聚焦：PASS 57/57
flutter test test/features/rehab_ml test/features/tv --no-pub

### Flutter scoped analyze：PASS 0 issues，各分支各一次最終 run
master：
flutter analyze lib/features/rehab_ml lib/models/body_pose_observation.dart
lib/services/body_pose_engine.dart lib/services/pi_camera_source.dart
test/features/rehab_ml --no-pub
TV：
flutter analyze lib/features/rehab_ml lib/features/rehab/body_training_screen.dart
lib/features/account/app_session.dart lib/actions/standing_knee_raise_action.dart
lib/models/body_pose_observation.dart lib/services/body_pose_engine.dart
lib/services/pi_camera_source.dart test/features/rehab_ml
test/features/tv/pi_camera_source_test.dart --no-pub

### master full suite：FAIL 524 PASS / 7 FAIL
flutter test --no-pub --reporter expanded；只跑一次。
在六項最終新增 test 與最終 owner/UI guards 前執行；
其後最終聚焦 58/58 通過，不假稱完整 suite 再跑或全部通過。
證據：.dart_tool/round2-full-flutter.log；7 項見第13節。
TV 全量所有測試 NOT RUN；TV research+既有 TV tests 全數已跑。

### Backend
PASS：mvn '-Dtest=ResearchBodyAttemptTest,ResearchBodyMigrationTest,ResearchDataServiceTest,ResearchHandContractTest' test
33 tests / 0 failures/errors/skips（7+2+22+2）。
PASS：mvn test，303 run / 0 failure/error / 23 skipped，即 280 PASS。
22 個 MySqlMigrationIntegrationTest 因 DB_URL 未提供跳過；
1 個 ResearchActivationSetupTest 因受控設定未提供跳過。
full run 在最後一項 shared fixture test 之前，最終聚焦含該 test；
不虛報 full suite 304 或 skipped 為 PASS。
PASS：mvn package -DskipTests。
證據：backend target/round2-full-test.log、target/surefire-reports。

### 其他
PASS：synthetic localhost WebSocket generation/stale/dispose/same-frame tests。
PASS：final git diff --check，三個工作樹。
NOT RUN：真實 MySQL、Android/Pi 硬體、production upload、第二 reviewer E2E。
早期 nullable/SDK compile、validation priority/settings test timing 問題均修正，
最終聚焦通過；不刪除/skip/放寬舊測試。

## 11. Android Phone Build Result
PASS：flutter build apk --debug --no-pub，最終 31.5s。
APK：C:/Users/kuoja/Documents/GitHub/tkuim_project/build/app/outputs/flutter-apk/app-debug.apk
620578846 bytes。
NOT RUN：本輪 Release build/真機；native/R8/MediaPipe/ONNX dependency 未改。

## 12. Android TV Build Result
PASS：flutter build apk --debug --no-pub，最終 65.6s。
建置 cwd 原 .dart_tool/round2-tv；之後安全移動 worktree，內容不變。
APK：C:/Users/kuoja/Documents/GitHub/tkuim_project/.worktrees/round2-tv/build/app/outputs/flutter-apk/app-debug.apk
593553917 bytes。
NOT RUN：本輪 Release/TV/Pi 真機。移動 checkout 後如需再建置，先 flutter pub get
重新產生含絕對路徑的工具快取；不表示已再建置。不要與 phone 同時安裝同 application ID。

## 13. Known Failures
以下符合原 G4/G5 文件的已知案例及原因，未冒稱全部成功：
1. account_info_screen_test.dart「帳號資訊顯示 Google 狀態、Google Email 與帳號 ID」：
   AppSession ZEGO 800ms pending timer。
2. 同檔「帳號 ID 前端驗證且成功更新」：相同 pending timer。
3. account_recovery_therapist_registration_test.dart「successful therapist registration saves existing session」：
   相同 pending timer。
4. friend_management_screen_test.dart「AppSession 無代碼時由 account API 取得並同步」：
   相同 pending timer。
5. training_result_history_page_test.dart「therapist history requests selected patient only」：
   legacy expectation patientId=15，但現行 REST/mock 捕捉為 null。
6. patient_training_videos_card_test.dart「shows actual completed reps and play action」：
   舊「1次失誤」斷言與現行「1項訓練修正紀錄」不一致。
7. dual_screen_assisted_training_ui_test.dart「輔助螢幕 IP 連線頁使用新名稱並適應手機尺寸」：
   「通訊埠」label 的 TextField ancestor finder 不符現行獨立 label。
本輪未變更這些畫面/測試；沒有改斷言以製造 PASS。
無最終聚焦新增 regression；但未獨立重跑 clean baseline，歷史比對依 G4/G5 紀錄。

## 14. Technical Debt
- Isolated MySQL V004/live Hibernate/現有 rows 尚未驗證，不能先部署新 entity。
- 必須實機驗證 Pi throughput、overlay 對齊、angle/LR、背景/重連/登出、queue retry。
- v3 therapist modality-aware 顯示/重採樣/核准 export 及 Python extractor parity 待後續。
- CUSTOM 無可信任 persisted action mapping，明確 fail closed。
- raw SimCC 為 uncalibrated；2D projected features 不能宣稱 3D 臨床 ROM。
- Concurrent backend identical upload 的 DB uniqueness race 未實測；retry 可遇 409，
  sequential idempotency 已測。需 live MySQL 併發驗收。
- 舊 unowned local samples 不自動搬 owner；後續若要復原需明確人工身份處理。
- 工作樹尚未提交；TV cached absolute paths 在 worktree 搬移後需 pub get。

## 15. Git Diff Summary
各 branch 未提交、HEAD 未變。完整檔案清單見第2/3節。
git diff --check 三處 PASS；Git status 包含上述實作/文件/fixture，
TV 另有無語意差异 generated files。
沒有 Git add/commit/push、whole-branch merge、reset/restore/drop，無 production SQL/deploy。
未改 PiHandSource、Pi server/network、native manifests、phone Release keep rules。
舊臨時空分支仍保留，沒有未經授權刪除。

## 16. Round 3 Readiness
Foundation 已可 code review，聚焦 synthetic/runtime-boundary 測試與兩個 Debug APK 完成。
尚不滿足「端到端 production/真機完成」。
Round 3 前：隔離 MySQL V004、Hibernate、真實 Pi/TV sample/upload 的人工驗收。
停止於本輪，不訓練模型、不部署、不開始 Round 3。

### 最小人工驗收
1. 先 review 三個 working-tree diff；隔離 DB 備份/套用 V004，跑 live MySQL tests。
2. TV patient 正常登入，有已綁定治療師的 DEFAULT 站姿抬腳指派。
3. 既有 Pi camera IP 接入 TV body screen，確認 JPEG/skeleton 對齊與 LR。
4. 研究設定只開本機 consent：成功與未成功動作皆存 attempt，無 pose 不存。
5. 暫停、斷線重連、背景/恢復、換帳號：無舊幀、重複 inference/跨帳號 sample。
6. 有自願 cloud consent 後手動同步，backend 可讀 v3；未同意不得上传。
7. 手機 body v1/hand v2 的骨架、語音、計次與本機/cloud consent 照舊。
8. 舊 therapist phone review 路線不冒稱完整 v3 UI；新 UI/export 留 Round 3。
