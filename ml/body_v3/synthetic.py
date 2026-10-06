"""Explicit SYNTHETIC/ENGINEERING_ONLY fixtures. Never a professional annotation."""
import copy
import hashlib
import io
import json
import zipfile
from pathlib import Path

from . import features as f
from .dataset import canonical


def sample(fixture, subject=0, label=0, attempt=0, source="tv_pi"):
    case = copy.deepcopy(fixture["cases"][1 if label==1 else 0])
    delta = subject*.0003 + attempt*.0001
    case["width"], case["height"] = 640, 480
    case["steps"] = case["steps"] + [{} for _ in range(4)]
    for i,step in enumerate(case["steps"]):
        # Perturb deterministic anonymous geometry, not copied subjects or random landmarks.
        points = step.setdefault("points",{})
        for index in (5,6):
            base = fixture["baseKeypoints"][index]
            points[str(index)] = [base[0]+delta+(.1 if label==2 else 0),base[1]]
        step["timeMs"] = i*(100+subject+attempt)
    frames = f.fixture_frames(fixture,case)
    sid, subject_id, session, stream = (f"SYNTHETIC-{subject:02d}-{label}-{attempt}",
                                      f"SYNTHETIC-SUBJECT-{subject:02d}",f"session-{subject:02d}",f"stream-{subject:02d}")
    for frame in frames:
        projected = f.frame_features(frame,"left")
        frame.update(streamSessionId=stream,source=source,poseModelVersion=f.POSE,coordinateTransformVersion=f.COORDINATES,
                     timestampOrigin=("tv" if source=="tv_pi" else "phone")+"_receive_monotonic",scoreSemantics="simcc_peak_mean_uncalibrated",captureTimestamp=None,
                     validity=[p is not None and s is not None and s>=.3 for p,s in zip(frame["keypoints"],frame["scores"])],
                     angles=dict(zip(("legHeight","hipDeg","kneeDeg","trunkLeanDeg"),projected)) if projected else None)
    result = f.extract(frames,"left")
    return {"sampleId":sid,"subjectId":subject_id,"sessionId":session,"attemptId":sid,
            "schemaVersion":3,"modality":"body","source":source,"platform":"android_tv" if source=="tv_pi" else "android_phone",
            "exerciseType":"DEFAULT","exerciseId":"synthetic-exercise","actionId":f.ACTION,
            "actionDefinitionVersion":f.DEFINITION,"extractorVersion":f.EXTRACTOR,"modelInputVersion":f.INPUT,
            "poseModelVersion":f.POSE,"coordinateTransformVersion":f.COORDINATES,"streamSessionId":stream,
            "frameId":len(frames)-1,"timestampOrigin":("tv" if source=="tv_pi" else "phone")+"_receive_monotonic","movementSide":"left","cameraView":"front",
            "capturedAt":"2026-01-01T00:00:00Z","featureNames":list(f.NAMES),"features":result["values"],
            "featuresStatus":result["status"],"duration":result["values"][4],"terminationReason":"RETURNED_TO_BASELINE",
            "setIndex":1,"completedRepsBefore":0,"completedRepsAfter":0,"intendedRepetition":1,
            "trackingQuality":{"validFrameRatio":result["validFrameRatio"]},"frames":frames}


def export_bytes(fixture, subjects=12, source="tv_pi", transform=None):
    labels = "sampleId,label,annotatorId,labelVersion,actionDefinitionVersion\n"
    groups, bodies = [], {}
    for subject in range(subjects):
        for label in range(3):
            for attempt in range(2):
                p = sample(fixture,subject,label,attempt,source)
                sid = p["sampleId"]
                g = {"sampleId":sid,"subjectPseudonym":p["subjectId"],"sessionGrouping":p["sessionId"],
                     "attemptGrouping":p["attemptId"],"source":source,"platform":p["platform"],"annotationStatus":"APPROVED",
                     "disposition":"ACTIVE","consentActive":True,"consentVersion":"SYNTHETIC-NOT-CONSENT",
                     "expiresAt":"2099-01-01T00:00:00Z","independentReview":True,"synthetic":True,"deleted":False,
                     "labelVersion":f.LABEL_VERSION,"reviewedAt":"2026-01-02T00:00:00Z"}
                if transform:
                    transform(p,g)
                body = canonical(p)
                g["payloadSha256"] = hashlib.sha256(body).hexdigest()
                bodies["samples/"+sid+".json"] = body
                groups.append(g)
                labels += f"{sid},{f.LABELS[label]},synthetic-annotator,{f.LABEL_VERSION},{f.DEFINITION}\n"
    manifest = {"schemaVersion":3,"modality":"body","actionId":f.ACTION,"actionDefinitionVersion":f.DEFINITION,
                "extractorVersion":f.EXTRACTOR,"modelInputVersion":f.INPUT,"poseModelVersion":f.POSE,"featureNames":list(f.NAMES),
                "labelMappingVersion":f.LABEL_VERSION,"exportContractVersion":"body-approved-export-v1",
                "origin":"SYNTHETIC_ENGINEERING_ONLY","source":source,"groups":groups,"sampleCount":len(groups),
                "exportedAt":"2026-01-03T00:00:00Z","eligibilityCheckedAt":"2026-01-03T00:00:00Z"}
    out = io.BytesIO()
    with zipfile.ZipFile(out,"w",zipfile.ZIP_DEFLATED) as archive:
        # Fixed ZIP timestamps and deterministic file order, no patient data.
        for name,body in sorted({**bodies,"manifest.json":canonical(manifest),"labels.csv":labels.encode()}.items()):
            entry = zipfile.ZipInfo(name,date_time=(2026,1,3,0,0,0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(entry,body)
    return out.getvalue()


def write(path, fixture_path):
    dest = Path(path)
    dest.parent.mkdir(parents=True,exist_ok=True)
    with dest.open("xb") as stream:
        stream.write(export_bytes(json.loads(Path(fixture_path).read_text(encoding="utf-8"))))
