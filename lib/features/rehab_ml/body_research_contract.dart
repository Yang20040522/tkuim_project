import 'dart:ui';
import '../../models/body_pose_observation.dart';
import 'body_research_feature_extractor.dart';

/// Local v3 validation, including deterministic feature recomputation. Server
/// independently checks authorization/assignment and recomputes geometry.
class BodyResearchContract {
  static bool accepts(Map<String, dynamic> json) {
    try {
      if (json['schemaVersion'] != 3 ||
          json['modality'] != 'body' ||
          json['poseModelVersion'] != 'rtmpose-wholebody-133-v1' ||
          json['coordinateTransformVersion'] != 'rtmpose-image-normalized-v1' ||
          json['actionId'] != 'standing_knee_raise' ||
          json['actionDefinitionVersion'] !=
              BodyResearchFeatureExtractor.actionDefinitionVersion ||
          json['extractorVersion'] != BodyResearchFeatureExtractor.version ||
          json['modelInputVersion'] !=
              BodyResearchFeatureExtractor.modelInputVersion ||
          !const {'DEFAULT', 'CUSTOM'}.contains(json['exerciseType']) ||
          !const {'left', 'right'}.contains(json['movementSide']) ||
          !const {'front', 'rear'}.contains(json['cameraView']) ||
          !const {'android_phone', 'android_tv'}.contains(json['platform']) ||
          json.containsKey('patientId') ||
          json.containsKey('therapistId')) {
        return false;
      }
      if (!const {'phone', 'tv_pi'}.contains(json['source']) ||
          json['source'] == 'tv_pi' &&
              (json['platform'] != 'android_tv' ||
                  json['timestampOrigin'] != 'tv_receive_monotonic') ||
          json['source'] == 'phone' &&
              (json['platform'] != 'android_phone' ||
                  json['timestampOrigin'] != 'phone_receive_monotonic')) {
        return false;
      }
      for (final key in [
        'sampleId',
        'sessionId',
        'attemptId',
        'exerciseId',
        'streamSessionId'
      ]) {
        if (json[key] is! String ||
            !RegExp(r'^[A-Za-z0-9_-]{1,100}$').hasMatch(json[key] as String)) {
          return false;
        }
      }
      if (!const {
        'RETURNED_TO_BASELINE',
        'USER_FINISHED',
        'INTERRUPTED',
        'TRACKING_LOST',
        'TIMEOUT'
      }.contains(json['terminationReason'])) {
        return false;
      }
      if (DateTime.tryParse(json['capturedAt'] as String) == null) return false;
      final raw = json['frames'] as List;
      if (raw.isEmpty || raw.length > 200) return false;
      final frames = <BodyPoseObservation>[];
      int time = -1, id = -1;
      for (final dynamic item in raw) {
        final f = Map<String, dynamic>.from(item as Map);
        if (f['timestampMs'] is! int ||
            f['frameId'] is! int ||
            (f['timestampMs'] as int) <= time ||
            (f['frameId'] as int) <= id ||
            f['captureTimestamp'] != null ||
            f['scoreSemantics'] != BodyPoseObservation.scoreSemantics ||
            f['streamSessionId'] != json['streamSessionId'] ||
            f['source'] != json['source'] ||
            f['timestampOrigin'] != json['timestampOrigin'] ||
            f['mirrored'] is! bool ||
            f['poseModelVersion'] != json['poseModelVersion'] ||
            f['coordinateTransformVersion'] !=
                json['coordinateTransformVersion']) {
          return false;
        }
        time = f['timestampMs'] as int;
        id = f['frameId'] as int;
        final points = f['keypoints'] as List, scores = f['scores'] as List;
        if (points.length != 17 || scores.length != 17) return false;
        if (points.any((dynamic p) =>
                p != null &&
                (p is! List ||
                    p.length != 2 ||
                    p.any((dynamic v) =>
                        v is! num || !v.isFinite || v < 0 || v > 1))) ||
            scores.any((dynamic s) =>
                s != null && (s is! num || !s.isFinite || s < 0 || s > 1e6))) {
          return false;
        }
        final observation = BodyPoseObservation(
            frameId: id,
            streamSessionId: f['streamSessionId'] as String,
            receivedAtMs: time,
            imageWidth: f['imageWidth'] as int,
            imageHeight: f['imageHeight'] as int,
            source: f['source'] as String,
            timestampOrigin: f['timestampOrigin'] as String,
            keypoints: points
                .map((dynamic p) => p == null
                    ? null
                    : Offset(
                        (p[0] as num).toDouble(), (p[1] as num).toDouble()))
                .toList(),
            scores: scores.map((dynamic s) => (s as num?)?.toDouble()).toList(),
            mirrored: f['mirrored'] as bool,
            rotationDegrees: f['rotationDegrees'] as int);
        if (f['validity'] is! List ||
            (f['validity'] as List).join('|') !=
                observation.validity.join('|')) {
          return false;
        }
        final expected = BodyResearchFeatureExtractor.frame(
                observation, json['movementSide'] as String)
            ?.toJson();
        if (expected == null
            ? f['angles'] != null
            : f['angles'] is! Map ||
                expected.entries.any(
                    (e) => !_close((f['angles'] as Map)[e.key], e.value))) {
          return false;
        }
        frames.add(observation);
      }
      final computed = BodyResearchFeatureExtractor.extract(
          frames, json['movementSide'] as String);
      final duration =
          (frames.last.receivedAtMs - frames.first.receivedAtMs) / 1000;
      final features = json['features'] as List;
      return json['frameId'] == id &&
          duration <= 20 &&
          computed.validFrameRatio > 0 &&
          _close(json['duration'], duration) &&
          json['featuresStatus'] == computed.status &&
          features.length == 5 &&
          (json['featureNames'] as List).join('|') ==
              BodyResearchFeatureExtractor.featureNames.join('|') &&
          List.generate(
              5,
              (i) => computed.values[i] == null
                  ? features[i] == null
                  : _close(features[i], computed.values[i]!)).every((v) => v) &&
          _close((json['trackingQuality'] as Map)['validFrameRatio'],
              computed.validFrameRatio) &&
          (json['setIndex'] as int) > 0 &&
          (json['completedRepsBefore'] as int) >= 0 &&
          (json['completedRepsAfter'] as int) >=
              (json['completedRepsBefore'] as int) &&
          json['intendedRepetition'] ==
              (json['completedRepsBefore'] as int) + 1;
    } on FormatException {
      return false;
    } on TypeError {
      return false;
    } on RangeError {
      return false;
    }
  }

  static bool _close(dynamic value, double expected) =>
      value is num && value.isFinite && (value - expected).abs() <= 1e-5;
}
