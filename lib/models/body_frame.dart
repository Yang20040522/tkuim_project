// lib/models/body_frame.dart
//
// ══════════════════════════════════════════════════════════════════
//  全身復健專用的資料契約
//  - 全身偵測 (RTMPose) 與全身復健邏輯 (WipeBodyAction 等) 之間的橋樑
//  - 不依賴任何模型、不碰 mediapipe,完全獨立
// ══════════════════════════════════════════════════════════════════

import 'dart:ui';

// 全身復健統一關節命名 (與底層模型 index 無關)
enum RehabJoint {
  leftShoulder,
  rightShoulder,
  leftElbow,
  rightElbow,
  leftWrist,
  rightWrist,
  leftHip,
  rightHip,

  // 下肢(新增,給坐站訓練等下肢動作用)
  leftKnee,
  rightKnee,
  leftAnkle,
  rightAnkle,
}

// 一幀全身姿勢結果 — 全身復健邏輯只讀這個
class BodyFrame {
  // 標準化關節座標 (正規化 0~1)
  final Map<RehabJoint, Offset> joints;

  const BodyFrame({this.joints = const {}});

  factory BodyFrame.empty() => const BodyFrame();
}