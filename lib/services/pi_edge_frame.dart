import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:crypto/crypto.dart';

enum PiInferencePath {
  edgeRoi,
  fullFrameFallback,
  edgeUnavailable,
  noPerson,
  invalidRoi;

  String get diagnostic => switch (this) {
        edgeRoi => 'EDGE_ROI',
        fullFrameFallback => 'FULL_FRAME_FALLBACK',
        edgeUnavailable => 'EDGE_UNAVAILABLE',
        noPerson => 'NO_PERSON',
        invalidRoi => 'INVALID_ROI',
      };
}

/// Integer pixel crop, shared by tensor extraction and full-frame remapping.
/// No display mirroring or anatomical index swapping belongs in this layer.
class PiCropRegion {
  const PiCropRegion(this.left, this.top, this.right, this.bottom,
      this.fullWidth, this.fullHeight);
  final int left, top, right, bottom, fullWidth, fullHeight;
  int get width => right - left;
  int get height => bottom - top;
  Rect get normalized => Rect.fromLTRB(left / fullWidth, top / fullHeight,
      right / fullWidth, bottom / fullHeight);

  static PiCropRegion? fromPixels(Object? value, int w, int h) {
    if (value is! Map || w <= 0 || h <= 0) return null;
    final coords = ['left', 'top', 'right', 'bottom'].map((k) => value[k]);
    if (coords.any((v) => v is! num || !v.toDouble().isFinite)) return null;
    final v = coords.cast<num>().map((n) => n.toDouble()).toList();
    // Reject out-of-bounds protocol values, rather than trusting broken transforms.
    if (v[0] < 0 ||
        v[1] < 0 ||
        v[2] > w ||
        v[3] > h ||
        v[2] <= v[0] ||
        v[3] <= v[1]) {
      return null;
    }
    final crop = PiCropRegion(
        v[0].floor(), v[1].floor(), v[2].ceil(), v[3].ceil(), w, h);
    return crop.width >= 16 && crop.height >= 16 ? crop : null;
  }
}

Offset remapPiRoiPoint(Offset point, Rect? region) => region == null
    ? point
    : Offset(region.left + point.dx * region.width,
        region.top + point.dy * region.height);

class PiEdgeMetadata {
  PiEdgeMetadata._(
      this.frameId,
      this.timestamp,
      this.width,
      this.height,
      this.available,
      this.personDetected,
      this.roi,
      this.jpegLength,
      this.digest);
  final int frameId, timestamp, width, height, jpegLength;
  final bool available, personDetected;
  final PiCropRegion? roi;
  final String digest;
  PiInferencePath get path => !available
      ? PiInferencePath.edgeUnavailable
      : !personDetected
          ? PiInferencePath.noPerson
          : roi == null
              ? PiInferencePath.invalidRoi
              : PiInferencePath.edgeRoi;

  static PiEdgeMetadata? parse(String text) {
    if (text.length > 8192) return null;
    try {
      final m = jsonDecode(text);
      if (m is! Map || m['protocolVersion'] != 'edge-v1') return null;
      int? integer(String key, int maximum) {
        final v = m[key];
        return v is int && v >= 0 && v <= maximum ? v : null;
      }

      final id = integer('frameId', 9007199254740991);
      final ts = integer('monotonicTimestamp', 9007199254740991);
      final w = integer('imageWidth', 8192), h = integer('imageHeight', 8192);
      final len = integer('jpegByteLength', 8 * 1024 * 1024);
      final digest = m['jpegSha256'];
      if (id == null ||
          ts == null ||
          w == null ||
          w == 0 ||
          h == null ||
          h == 0 ||
          len == null ||
          len == 0 ||
          digest is! String ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(digest) ||
          m['edgeAiAvailable'] is! bool ||
          m['personDetected'] is! bool ||
          m['edgeModelName'] is! String ||
          m['edgeModelVersion'] is! String) {
        return null;
      }
      PiCropRegion? roi;
      final confidence = m['personConfidence'];
      if (m['personDetected'] == true &&
          confidence is num &&
          confidence.isFinite &&
          confidence >= .55 &&
          confidence <= 1 &&
          m['roiPaddingPolicyVersion'] == 'person-padding-v1' &&
          PiCropRegion.fromPixels(m['personBBoxPixels'], w, h) != null) {
        roi = PiCropRegion.fromPixels(m['roiRecommended'], w, h);
        final body = PiCropRegion.fromPixels(m['personBBoxPixels'], w, h)!;
        if (roi != null &&
            (roi.left > body.left ||
                roi.top > body.top ||
                roi.right < body.right ||
                roi.bottom < body.bottom)) {
          roi = null;
        }
      }
      return PiEdgeMetadata._(id, ts, w, h, m['edgeAiAvailable'],
          m['personDetected'], roi, len, digest);
    } on FormatException {
      return null;
    }
  }
}

/// Ordered WS messages plus a JPEG digest make pairing explicit even if metadata
/// is missing/replaced. Invalid metadata never suppresses a usable legacy JPEG.
class PiEdgePairer {
  PiEdgePairer({this.maxPairAgeMs = 500});
  final int maxPairAgeMs;
  PiEdgeMetadata? _pending;
  int _received = 0, _lastId = -1, _lastTimestamp = -1;
  void reset() {
    _pending = null;
    _received = 0;
    _lastId = _lastTimestamp = -1;
  }

  void receiveMetadata(String text, int nowMs) {
    _pending = null;
    final meta = PiEdgeMetadata.parse(text);
    if (meta == null ||
        meta.frameId <= _lastId ||
        meta.timestamp <= _lastTimestamp) {
      return;
    }
    _lastId = meta.frameId;
    _lastTimestamp = meta.timestamp;
    _received = nowMs;
    _pending = meta;
  }

  PiEdgeMetadata? pair(Uint8List jpeg, int nowMs) {
    final meta = _pending;
    _pending = null; // Never reuse a detection for another JPEG.
    if (meta == null ||
        nowMs - _received > maxPairAgeMs ||
        nowMs < _received ||
        jpeg.length != meta.jpegLength ||
        sha256.convert(jpeg).toString() != meta.digest) {
      return null;
    }
    return meta;
  }
}
