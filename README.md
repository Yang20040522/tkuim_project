# RehabAssist

RehabAssist 是一套以 Flutter 開發的復健輔助系統，主要提供患者與治療師使用。

患者可以透過系統查看復健計畫、進行復健訓練，並利用 AI 人體姿態辨識協助判斷動作是否正確。治療師則可以管理患者、安排復健計畫，以及建立自訂復健動作。

目前系統仍在持續開發與調整中。

## 主要功能

### 患者端

* 查看復健計畫
* 進行每日復健訓練
* AI 人體姿態辨識
* 動作姿勢判斷
* 查看訓練紀錄
* 查看訓練統計
* 與治療師聊天
* 視訊通話
* 個人資料與頭像設定
* 通知功能

### 治療師端

* 患者管理
* 患者與治療師綁定
* 建立及管理復健計畫
* 建立自訂復健動作
* 查看患者資料
* 與患者聊天
* 視訊通話

## AI 姿態辨識

系統使用 ONNX Runtime 在裝置端執行人體姿態辨識模型。

目前使用：

* RTMDet
* RTMPose WholeBody

主要流程為透過手機相機取得畫面，再進行人體偵測與關節點辨識，取得人體姿態資訊後，用於後續的復健動作判斷。

模型檔案放置於：

```text
assets/
├── rtmdet.onnx
└── rtmpose_wholebody.onnx
```

## 自訂復健動作

治療師可以使用系統中的 3D 人體模型建立自訂動作。

目前包含：

* 上肢與下肢關節調整
* 關節角度設定
* Keyframe 編輯
* 動作播放預覽
* 動作時間設定
* 每組次數設定
* 組數設定
* 保持時間設定
* 自訂動作儲存與載入

## 使用技術

* Flutter
* Dart
* Provider
* ONNX Runtime
* RTMDet
* RTMPose WholeBody
* REST API
* Google Sign-In
* WebRTC
* ZEGO UIKit
* SharedPreferences
* Flutter Local Notifications

## 專案結構

```text
lib/
├── actions/
├── controllers/
├── core/
├── features/
│   ├── account/
│   ├── analysis/
│   ├── call/
│   ├── chat/
│   ├── custom_exercise/
│   ├── friends/
│   ├── history/
│   ├── home/
│   ├── notification/
│   ├── plan/
│   ├── pose_measurement/
│   ├── rehab/
│   ├── stats/
│   └── training/
├── models/
├── services/
├── widgets/
└── main.dart
```

## Backend

Backend 專案：

https://github.com/Andrew05049487/trianing-system

前端主要透過 API 與後端交換帳號、患者資料、復健計畫及聊天等資料。

## 執行方式

先確認已安裝 Flutter 開發環境。

```bash
flutter doctor
```

Clone 專案：

```bash
git clone https://github.com/Yang20040522/tkuim_project.git
cd tkuim_project
```

安裝套件：

```bash
flutter pub get
```

執行：

```bash
flutter run
```

## 系統畫面

之後會補上主要功能畫面，例如：

* 患者首頁
* AI 復健訓練
* 治療師首頁
* 3D 自訂動作編輯器
* 聊天功能
* 復健計畫

## 專題說明

本系統主要希望讓患者在居家環境中也能依照治療師安排的復健內容進行訓練。

治療師可以安排患者的訓練內容，患者則可以透過系統查看示範並完成復健動作，系統會記錄相關訓練資料，方便後續查看。

## 注意事項

本專案目前為學術專題用途。

系統中的姿態辨識與動作判斷功能僅作為復健輔助，不能取代醫師或物理治療師的專業判斷。

## 開發狀態

目前持續開發中。

主要功能已完成，後續會繼續進行功能整合、介面調整與實機測試。

## Team

Tamkang University
Graduation Project

