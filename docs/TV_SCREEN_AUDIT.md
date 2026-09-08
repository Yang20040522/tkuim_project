# TV screen audit

TV 可達主流程：Splash → 患者入口 → 帳密 Login → TV Home → Plan / Action selection → 3D preview → Body / Hand external training → Results / History。Settings 保留 Pi IP 與登出。

TV 分支不顯示手機 bottom navigation、QR pairing、local-camera body test、即時骨架 3D camera viewer、通知、視訊通話、聊天、好友、治療師管理、自訂動作編輯、手機註冊與帳號復原。3D 示教由既有 TrainingPreviewScreen 的模型對照提供。Shared models / repositories 仍保留。

Audit 覆蓋專案中所有 Screen/Page 宣告。下表是路由可達性與 presentation 處置；不表示每個被隱藏的 legacy screen 都經過實機測試。

| File | TV disposition |
| --- | --- |
| `lib/core/ui/tv_ui.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/account/account_info_screen.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/account/bind_patient_page.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/account/forgot_password_page.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/account/login_screen.dart` | TV capability 分流至橫向 presentation；核心 service / model 沿用 |
| `lib/features/account/patient_management_page.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/account/profile_screen.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/account/register_screen.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/account/role_select_screen.dart` | TV capability 分流至橫向 presentation；核心 service / model 沿用 |
| `lib/features/account/therapist_home_screen.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/account/therapist_login_screen.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/account/therapist_register_screen.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/analysis/comparison_report_screen.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/analysis/hand_comparison_report_screen.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/analysis/standard_analysis_screen.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/body_test/body_test_screen.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/call/video_call_screen.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/chat/chat_home_screen.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/chat/chat_screen.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/chat/remote_chat_screen.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/custom_exercise/assigned_default_exercise_page.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/custom_exercise/custom_exercise_assignment_page.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/custom_exercise/custom_exercise_editor_page.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/custom_exercise/custom_exercise_list_page.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/custom_exercise/custom_exercise_playback_page.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/custom_exercise/patient_assigned_exercise_list_page.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/custom_exercise/patient_custom_exercise_list_page.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/custom_exercise/unified_exercise_assignment_page.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/demo/bone_viewer_screen.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/demo/demo_library_screen.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/friends/friend_management_screen.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/history/history_screen.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/history/training_result_history_page.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/history/video_playback_screen.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/home/home_screen.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/notification/notification_screen.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/notification/notification_settings_screen.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/plan/plan_builder_screen.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/plan/plan_screen.dart` | TV capability 分流至橫向 presentation；核心 service / model 沿用 |
| `lib/features/plan/therapist_plan_management_page.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/pose_measurement/pose_training_page.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/rehab/body_training_screen.dart` | TV capability 分流至橫向 presentation；核心 service / model 沿用 |
| `lib/features/rehab/training_screen.dart` | TV capability 分流至橫向 presentation；核心 service / model 沿用 |
| `lib/features/splash/splash_screen.dart` | TV capability 分流至橫向 presentation；核心 service / model 沿用 |
| `lib/features/stats/stats_screen.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/stats/therapist_patient_stats_screen.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/training/action_list_screen.dart` | TV capability 分流至橫向 presentation；核心 service / model 沿用 |
| `lib/features/training/training_preview_screen.dart` | TV capability 分流至橫向 presentation；核心 service / model 沿用 |
| `lib/features/tv/tv_home_screen.dart` | TV 專用首頁／紀錄／設定 |
| `lib/features/tv_cast/connection_status_screen.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/tv_cast/phone_connection_screen.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
| `lib/features/tv_cast/remote_controller_screen.dart` | 不納入 TV 導覽；保留手機／治療師／編輯／分析／投放介面原檔 |
