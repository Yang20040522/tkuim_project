"""Versioned standing-knee-raise feature contract shared with Flutter JSON.

Only normalized RTMPose COCO body landmarks (indices 0..16) are accepted.
No raw image data or personally identifying fields are part of this schema.
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Callable

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


def _standing_features(sample: dict) -> list[float]:
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


@dataclass(frozen=True)
class ActionDefinition:
    action_id: str
    version: str
    feature_names: tuple[str, ...]
    labels: tuple[str, ...]
    extractor: Callable[[dict], list[float]]
    required_left: tuple[int, ...]
    required_right: tuple[int, ...]
    schema_version: int = 1
    accept_legacy_version: bool = False
    preprocessing: str = 'rtmpose17-normalized-2d-v1;features-identity;float32'


STANDING_DEFINITION = ActionDefinition(
    ACTION_ID, "standing-knee-raise-v1", tuple(FEATURE_NAMES),
    ("meets_requirement", "insufficient_range", "trunk_compensation"),
    _standing_features, (5, 6, 11, 12, 13, 15), (5, 6, 11, 12, 14, 16),
    accept_legacy_version=True)
# Synthetic contracts are injected by tests, never exposed to patients/training CLI.
ACTION_REGISTRY = {ACTION_ID: STANDING_DEFINITION}
from hand_features import HAND_FEATURES, PREPROCESSING, hand_features
for hand_id, names in HAND_FEATURES.items():
    limitation = ('limited_rotation_proxy' if hand_id == 'turnPalm' else
                  'limited_pinch_motion' if hand_id == 'sidePinch' else 'limited_wrist_motion')
    ACTION_REGISTRY[hand_id] = ActionDefinition(hand_id, f'{hand_id}-hand-v1', names,
        ('meets_requirement', limitation, 'unstable_motion'), hand_features, (), (),
        schema_version=2, preprocessing=PREPROCESSING)


def action_definition(sample: dict, registry=None) -> ActionDefinition:
    registry = ACTION_REGISTRY if registry is None else registry
    definition = registry.get(sample.get("actionId"))
    if definition is None or sample.get("schemaVersion") != definition.schema_version:
        raise ValueError("unsupported sample schema/action")
    version = sample.get("actionDefinitionVersion")
    if version != definition.version and not (
        definition.accept_legacy_version and "actionDefinitionVersion" not in sample
    ):
        raise ValueError("action definition version mismatch")
    return definition


def features_from_sample(sample: dict, registry=None) -> list[float]:
    """Shared skeleton validation plus explicit per-action feature extractor."""
    definition = action_definition(sample, registry)
    if definition.schema_version == 2:
        return definition.extractor(sample)
    if sample.get("featureNames") != list(definition.feature_names):
        raise ValueError("feature order mismatch")
    if sample.get("movementSide") not in ("left", "right") or sample.get("cameraView") not in ("front", "rear"):
        raise ValueError("invalid anatomical side/camera")
    if not sample.get("sampleId") or not sample.get("subjectId"):
        raise ValueError("missing pseudonymous grouping key")
    frames = sample.get("frames")
    if not isinstance(frames, list) or not 4 <= len(frames) <= 80:
        raise ValueError("incomplete motion")
    required = definition.required_left if sample["movementSide"] == "left" else definition.required_right
    previous = -1
    for frame in frames:
        points, scores, timestamp = frame.get("landmarks"), frame.get("confidence"), frame.get("timestampMs")
        if not isinstance(points, list) or len(points) != 17 or not isinstance(scores, list) or len(scores) != 17:
            raise ValueError("invalid frame shape")
        if type(timestamp) is not int or timestamp <= previous:
            raise ValueError("non-monotonic timestamps")
        previous = timestamp
        if any(not isinstance(p, list) or len(p) != 2 or any(
            type(v) not in (int, float) or not math.isfinite(v) or abs(v) > 30 for v in p
        ) for p in points):
            raise ValueError("invalid joint")
        if any(type(v) not in (int, float) or not math.isfinite(v) or not 0 <= v <= 1 for v in scores):
            raise ValueError("invalid confidence")
        if any(scores[i] < REQUIRED_CONFIDENCE for i in required):
            raise ValueError("low-confidence key joint")
    if not 300 <= frames[-1]["timestampMs"] - frames[0]["timestampMs"] <= 8000:
        raise ValueError("invalid movement duration")
    result = definition.extractor(sample)
    saved = sample.get("features")
    if len(result) != len(definition.feature_names) or not isinstance(saved, list) or len(saved) != len(result):
        raise ValueError("missing action features")
    if any(type(v) not in (int, float) or not math.isfinite(v) or not math.isfinite(expected)
           or abs(v - expected) > 1e-5 for v, expected in zip(saved, result)):
        raise ValueError("Flutter/Python feature mismatch")
    return result
