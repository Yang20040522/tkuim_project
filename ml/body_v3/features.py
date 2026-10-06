"""Frozen Dart/Java-compatible image-plane features. Never use display transforms."""
import math

ACTION = "standing_knee_raise"
DEFINITION = "standing-knee-raise-body-v2"
EXTRACTOR = "standing-knee-raise-aspect-2d-v2"
INPUT = "body-attempt-features-v1"
POSE = "rtmpose-wholebody-133-v1"
COORDINATES = "rtmpose-image-normalized-v1"
LABEL_VERSION = "body-attempt-label-v1"
LABELS = ("meets_requirement", "insufficient_range", "trunk_compensation")
NAMES = ("peak_leg_height", "minimum_hip_angle_deg", "minimum_knee_angle_deg",
         "peak_abs_trunk_lean_deg", "duration_seconds")
EXTENDED = ("hip_range_deg", "trunk_lean_std_deg", "time_to_peak_seconds")
UNITS = ("torso_length_ratio", "degrees_2d", "degrees_2d", "degrees_2d", "seconds")
SCHEMA = "body-aspect-baseline-v1"
EXTENDED_VERSION = "body-aspect-extended-v1"
TOLERANCE = 1e-5


def finite(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def frame_features(frame, side):
    if side not in ("left", "right"):
        return None
    points, scores = frame.get("keypoints", []), frame.get("scores", [])
    width, height = frame.get("imageWidth"), frame.get("imageHeight")
    if (len(points) < 17 or len(scores) != len(points) or
            not finite(width) or not finite(height) or width <= 0 or height <= 0):
        return None
    sh, hip, knee, ankle = (5, 11, 13, 15) if side == "left" else (6, 12, 14, 16)

    def point(index):
        p, s = points[index], scores[index]
        if (not isinstance(p, list) or len(p) != 2 or
                not all(finite(v) and 0 <= v <= 1 for v in p) or
                not finite(s) or s < .3):
            return None
        return p[0] * width, p[1] * height

    values = {i: point(i) for i in {5, 6, 11, 12, sh, hip, knee, ankle}}
    if any(v is None for v in values.values()):
        return None
    top = tuple((values[5][i] + values[6][i]) / 2 for i in (0, 1))
    bottom = tuple((values[11][i] + values[12][i]) / 2 for i in (0, 1))
    torso = math.dist(top, bottom)
    if torso <= 1e-6:
        return None

    def angle(a, b, c):
        u, v = tuple(a[i] - b[i] for i in (0, 1)), tuple(c[i] - b[i] for i in (0, 1))
        denominator = math.hypot(*u) * math.hypot(*v)
        if denominator < 1e-6:
            return None
        return math.degrees(math.acos(max(-1, min(1, sum(u[i]*v[i] for i in (0, 1))/denominator))))

    ha, ka = angle(values[sh], values[hip], values[knee]), angle(values[hip], values[knee], values[ankle])
    if ha is None or ka is None:
        return None
    return (max(0, (values[hip][1] - values[knee][1]) / torso), ha, ka,
            math.degrees(math.atan2(top[0]-bottom[0], bottom[1]-top[1])))


def extract(frames, side, extended=False):
    valid = [(f["timestampMs"], v) for f in frames if (v := frame_features(f, side)) is not None]
    ratio = len(valid) / len(frames) if frames else 0.
    duration = (frames[-1]["timestampMs"]-frames[0]["timestampMs"])/1000 if frames else 0.
    available = len(valid) >= 4 and ratio >= .6 and duration > 0
    if not available:
        return {"values": [None] * (8 if extended else 5), "validFrameRatio": ratio, "status": "unavailable"}
    vectors = [v for _, v in valid]
    result = [max(v[0] for v in vectors), min(v[1] for v in vectors), min(v[2] for v in vectors),
              max(abs(v[3]) for v in vectors), duration]
    if extended:
        mean = sum(v[3] for v in vectors) / len(vectors)
        peak = max(v[0] for v in vectors)
        result += [max(v[1] for v in vectors)-min(v[1] for v in vectors),
                   math.sqrt(sum((v[3]-mean)**2 for v in vectors)/len(vectors)),
                   (next(t for t, v in valid if v[0] == peak)-frames[0]["timestampMs"])/1000]
    return {"values": result, "validFrameRatio": ratio, "status": "available"}


def schema(extended=False):
    return {"schemaVersion": 3, "modality": "body", "actionId": ACTION,
            "actionDefinitionVersion": DEFINITION, "extractorVersion": EXTRACTOR,
            "modelInputVersion": "body-attempt-features-extended-v1" if extended else INPUT, "poseModelVersion": POSE,
            "featureSchemaVersion": EXTENDED_VERSION if extended else SCHEMA,
            "extendedExtractorVersion": EXTENDED_VERSION if extended else None,
            "featureNames": list(NAMES + (EXTENDED if extended else ())),
            "units": list(UNITS + (("degrees_2d", "degrees_2d", "seconds") if extended else ())),
            "dtype": "float32", "missing": "reject; never zero/impute unavailable attempts",
            "ranges": ["finite >=0", "0..180", "0..180", "0..180", "0..20"] +
                      (["0..180", "0..180", "0..duration"] if extended else []),
            "geometry": "2D projected image plane, x*imageWidth/y*imageHeight; anatomical indices; no UI mirror/rotation",
            "extensionDefinitions": {"hip_range_deg": "max(valid hip)-min(valid hip)",
                                    "trunk_lean_std_deg": "population standard deviation of valid signed trunk lean",
                                    "time_to_peak_seconds": "first max leg-height timestamp minus first frame timestamp"},
            "parityTolerance": TOLERANCE}


def fixture_frames(fixture, case):
    """Shared compact deterministic fixture expansion, not a patient-data generator."""
    import copy
    frames = []
    for i, step in enumerate(case["steps"]):
        points = copy.deepcopy(fixture["baseKeypoints"])
        for index, point in step.get("points", {}).items():
            points[int(index)] = point
        scores = [1.4] * 17  # SimCC peaks explicitly NOT calibrated probabilities.
        for index in step.get("missing", []):
            points[index], scores[index] = None, None
        frames.append({"frameId": i, "timestampMs": step.get("timeMs", i*100),
                       "imageWidth": case.get("width", 640), "imageHeight": case.get("height", 480),
                       "keypoints": points, "scores": scores,
                       "mirrored": case.get("mirrored", False), "rotationDegrees": case.get("rotation", 0)})
    return frames
