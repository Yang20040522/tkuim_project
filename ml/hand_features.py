"""MediaPipe21 image-space proxies, not clinical wrist angles/force/world depth."""
import math

SOURCE = 'mediapipe_hand_21'
PREPROCESSING = 'mediapipe21-image-proxy-v1;features-identity;float32'
HAND_FEATURES = {
    'turnPalm': ('axis_x_range', 'palm_normal_z_range', 'orientation_range_deg', 'orientation_step_mean_deg', 'duration_seconds'),
    'sidePinch': ('minimum_pinch_ratio', 'maximum_pinch_ratio', 'pinch_range', 'wrist_travel_ratio', 'duration_seconds'),
    'wristExtension': ('minimum_relative_axis_deg', 'maximum_relative_axis_deg', 'axis_range_deg', 'axis_step_mean_deg', 'duration_seconds'),
    'wristSideBend': ('minimum_relative_axis_deg', 'maximum_relative_axis_deg', 'axis_range_deg', 'axis_step_mean_deg', 'duration_seconds'),
}

def distance(a, b):
    return math.hypot(a[0]-b[0], a[1]-b[1])

def valid_points(p):
    if not isinstance(p, list) or len(p) != 21 or any(not isinstance(v, list) or len(v) != 3 or
        any(type(n) not in (float, int) or not math.isfinite(n) for n in v) or
        not 0 <= v[0] <= 1 or not 0 <= v[1] <= 1 or abs(v[2]) > 5 for v in p):
        return False
    scale = distance(p[0], p[9])
    return 0.02 <= scale <= 0.8 and distance(p[5], p[17])/scale >= 0.1

def hand_features(sample):
    action = sample.get('actionId')
    if action not in HAND_FEATURES or sample.get('schemaVersion') != 2 or sample.get('landmarkSource') != SOURCE or \
        sample.get('extractorVersion') != 'hand-image-proxy-v1' or sample.get('modelInputVersion') != 'hand-features-v1' or \
        sample.get('timestampOrigin') != 'channel-arrival-stopwatch' or \
        sample.get('featureNames') != list(HAND_FEATURES[action]) or sample.get('orderedFeatureNames') != list(HAND_FEATURES[action]):
        raise ValueError('hand source/version/features mismatch')
    if sample.get('movementSide') != 'unknown' or sample.get('anatomicalSide') != 'unknown' or \
        sample.get('cameraView') not in ('front', 'rear') or not sample.get('sampleId') or not sample.get('subjectId'):
        raise ValueError('invalid hand metadata')
    frames = sample.get('frames')
    if not isinstance(frames, list) or not 4 <= len(frames) <= 200:
        raise ValueError('incomplete hand motion')
    previous = -1
    points = []
    for frame in frames:
        t, p = frame.get('timestampMs'), frame.get('landmarks')
        if set(frame) != {'timestampMs', 'landmarks'} or type(t) is not int or t < 0 or t <= previous or \
            (previous >= 0 and t-previous > 350) or not valid_points(p):
            raise ValueError('invalid hand observation')
        previous = t
        points.append(p)
    duration = (frames[-1]['timestampMs']-frames[0]['timestampMs'])/1000
    segment = sample.get('segment', {})
    if not 0.3 <= duration <= 20 or sample.get('timestampMs') != previous or \
        segment != {'startMs': frames[0]['timestampMs'], 'endMs': previous, 'kind': 'rule-rep-boundaries', 'completedReps': 1}:
        raise ValueError('incomplete hand segment')
    bearings = [math.degrees(math.atan2(p[9][1]-p[0][1], p[9][0]-p[0][0])) for p in points]
    axis = [0.0]
    for a,b in zip(bearings, bearings[1:]):
        axis.append(axis[-1]+(b-a+540)%360-180)
    spread = lambda values: max(values)-min(values)
    step = sum(abs(b-a) for a,b in zip(axis,axis[1:]))/(len(axis)-1)
    if action == 'sidePinch':
        ratios = [distance(p[4],p[6])/distance(p[0],p[9]) for p in points]
        if spread(ratios) < 0.01:
            raise ValueError('missing pinch movement')
        result = [min(ratios), max(ratios), spread(ratios),
            max(distance(p[0],points[0][0])/distance(points[0][0],points[0][9]) for p in points), duration]
    else:
        if spread(axis) < 1:
            raise ValueError('missing orientation movement')
        if spread(axis) > 360 or any(abs(v) > 360 for v in axis):
            raise ValueError('orientation exceeds feature contract')
        if action == 'turnPalm':
            normal = []
            for p in points:
                u=[p[5][i]-p[0][i] for i in range(3)]
                v=[p[17][i]-p[0][i] for i in range(3)]
                cross=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
                length=math.sqrt(sum(n*n for n in cross))
                if length < 1e-8:
                    raise ValueError('degenerate palm plane')
                normal.append(cross[2]/length)
            result=[spread([(p[9][0]-p[0][0])/distance(p[0],p[9]) for p in points]),spread(normal),spread(axis),step,duration]
        else:
            result=[min(axis),max(axis),spread(axis),step,duration]
    saved=sample.get('features')
    if not isinstance(saved,list) or len(saved)!=5 or any(type(v) not in (int,float) or not math.isfinite(v) or
        abs(v-expected)>1e-5 for v,expected in zip(saved,result)):
        raise ValueError('Flutter/Python hand feature mismatch')
    return result
