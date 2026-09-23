"""Versioned standing-knee-raise feature contract shared with Flutter JSON.

Only normalized RTMPose COCO body landmarks (indices 0..16) are accepted.
No raw image data or personally identifying fields are part of this schema.
"""

from __future__ import annotations

import math

ACTION_ID = "standing_knee_raise"
SCHEMA_VERSION = 1
FEATURE_NAMES = [
    "peak_leg_height",
    "minimum_hip_angle_deg",
    "minimum_knee_angle_deg",
    "peak_abs_trunk_lean_deg",
    "duration_seconds",
]
REQUIRED_CONFIDENCE = 0.3


def _angle(a: list[float], center: list[float], b: list[float]) -> float:
    u = (a[0] - center[0], a[1] - center[1])
    v = (b[0] - center[0], b[1] - center[1])
    length = math.hypot(*u) * math.hypot(*v)
    if length < 1e-6:
        raise ValueError("degenerate joint angle")
    cosine = max(-1.0, min(1.0, (u[0] * v[0] + u[1] * v[1]) / length))
    return math.degrees(math.acos(cosine))


def features_from_sample(sample: dict) -> list[float]:
    if sample.get("schemaVersion") != SCHEMA_VERSION or sample.get("actionId") != ACTION_ID:
        raise ValueError("unsupported sample schema/action")
    if sample.get("featureNames") != FEATURE_NAMES:
        raise ValueError("feature order mismatch")
    if sample.get("movementSide") not in ("left", "right"):
        raise ValueError("missing anatomical side")
    if sample.get("cameraView") not in ("front", "rear"):
        raise ValueError("unsupported camera view")
    if not sample.get("subjectId") or not sample.get("sampleId"):
        raise ValueError("missing pseudonymous grouping key")
    frames = sample.get("frames")
    if not isinstance(frames, list) or len(frames) < 4:
        raise ValueError("incomplete motion")
    side = [5, 11, 13, 15] if sample["movementSide"] == "left" else [6, 12, 14, 16]
    required = {5, 6, 11, 12, *side}
    heights, hips, knees, leans = [], [], [], []
    timestamps = []
    for frame in frames:
        p, scores = frame["landmarks"], frame["confidence"]
        timestamp = frame["timestampMs"]
        if len(p) != 17 or len(scores) != 17 or not isinstance(timestamp, int):
            raise ValueError("invalid frame shape")
        if timestamps and timestamp <= timestamps[-1]:
            raise ValueError("non-monotonic timestamps")
        timestamps.append(timestamp)
        for i in range(17):
            if len(p[i]) != 2 or not all(math.isfinite(float(x)) for x in p[i]):
                raise ValueError("non-finite joint")
            if not math.isfinite(float(scores[i])) or not 0 <= scores[i] <= 1:
                raise ValueError("invalid confidence")
        if any(scores[i] < REQUIRED_CONFIDENCE for i in required):
            raise ValueError("low-confidence key joint")
        hips.append(_angle(p[side[0]], p[side[1]], p[side[2]]))
        knees.append(_angle(p[side[1]], p[side[2]], p[side[3]]))
        heights.append(p[side[1]][1] - p[side[2]][1])
        shoulder_x = (p[5][0] + p[6][0]) / 2
        shoulder_y = (p[5][1] + p[6][1]) / 2
        hip_x = (p[11][0] + p[12][0]) / 2
        hip_y = (p[11][1] + p[12][1]) / 2
        leans.append(abs(math.degrees(math.atan2(shoulder_x - hip_x, hip_y - shoulder_y))))
    duration = (timestamps[-1] - timestamps[0]) / 1000
    if not 0.3 <= duration <= 8:
        raise ValueError("invalid movement duration")
    result = [max(heights), min(hips), min(knees), max(leans), duration]
    saved = sample.get("features")
    if not isinstance(saved, list) or len(saved) != len(result):
        raise ValueError("missing Flutter features")
    if any(not math.isfinite(float(v)) or abs(float(v) - expected) > 1e-5
           for v, expected in zip(saved, result)):
        raise ValueError("Flutter/Python feature mismatch")
    return result
