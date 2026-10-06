"""Bounded, deterministic consumer of the EXISTING authorized approved-export ZIP."""
import csv
import hashlib
import io
import json
import re
import zipfile
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

from . import features as f

BUILDER = "body-dataset-builder-v1"
ROOT_FIELDS = set("sampleId subjectId sessionId attemptId schemaVersion modality source platform exerciseType exerciseId actionId actionDefinitionVersion extractorVersion modelInputVersion poseModelVersion coordinateTransformVersion streamSessionId frameId timestampOrigin movementSide cameraView capturedAt featureNames features featuresStatus duration terminationReason setIndex completedRepsBefore completedRepsAfter intendedRepetition trackingQuality frames resampleOfSampleId".split())
FRAME_FIELDS = set("frameId streamSessionId timestampMs timestampOrigin captureTimestamp imageWidth imageHeight source poseModelVersion coordinateTransformVersion mirrored rotationDegrees scoreSemantics keypoints scores validity angles".split())


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False, allow_nan=False).encode()


def digest(value):
    return hashlib.sha256(canonical(value)).hexdigest()


def instant(value):
    dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if dt.tzinfo is None:
        raise ValueError("timezone required")
    return dt.astimezone(timezone.utc)


def identifier(value):
    return isinstance(value, str) and re.fullmatch(r"[A-Za-z0-9_-]{1,100}", value) and not value.isdecimal()


def validate_sample(p):
    """Fail closed on schema drift, malformed geometry, inconsistent derived values."""
    if not isinstance(p, dict) or set(p)-ROOT_FIELDS:
        raise ValueError("schema_or_private_field")
    expected = {"schemaVersion": 3, "modality": "body", "actionId": f.ACTION,
                "actionDefinitionVersion": f.DEFINITION, "extractorVersion": f.EXTRACTOR,
                "modelInputVersion": f.INPUT, "poseModelVersion": f.POSE,
                "coordinateTransformVersion": f.COORDINATES, "featureNames": list(f.NAMES)}
    for key, value in expected.items():
        if p.get(key) != value:
            raise ValueError("version_or_feature_order:"+key)
    source = p.get("source")
    if source not in ("phone", "tv_pi") or p.get("platform") != {"phone":"android_phone", "tv_pi":"android_tv"}[source]:
        raise ValueError("source_platform")
    if p.get("movementSide") not in ("left", "right") or p.get("cameraView") not in ("front", "rear"):
        raise ValueError("side_camera")
    for key in ("sampleId", "subjectId", "sessionId", "attemptId", "streamSessionId"):
        if not identifier(p.get(key)):
            raise ValueError("anonymous_identifier:"+key)
    if not isinstance(p.get("exerciseId"),str) or not re.fullmatch(r"[A-Za-z0-9_-]{1,100}",p["exerciseId"]) or p.get("exerciseType") not in ("DEFAULT","CUSTOM"):
        raise ValueError("exercise_context")
    try:
        instant(p["capturedAt"])
    except (KeyError,ValueError,TypeError):
        raise ValueError("capture_time") from None
    if (type(p.get("setIndex")) is not int or not 1<=p["setIndex"]<=10000 or
        type(p.get("completedRepsBefore")) is not int or not 0<=p["completedRepsBefore"]<=100000 or
        type(p.get("completedRepsAfter")) is not int or not p["completedRepsBefore"]<=p["completedRepsAfter"]<=100000 or
        type(p.get("intendedRepetition")) is not int or p["intendedRepetition"]!=p["completedRepsBefore"]+1):
        raise ValueError("attempt_context")
    frames = p.get("frames", [])
    if not isinstance(frames, list) or not 1 <= len(frames) <= 200:
        raise ValueError("frame_count")
    prev_time, prev_id = -1, -1
    for frame in frames:
        if not isinstance(frame, dict) or set(frame)-FRAME_FIELDS:
            raise ValueError("frame_private_field")
        for key in ("streamSessionId", "source", "poseModelVersion", "coordinateTransformVersion", "timestampOrigin"):
            if frame.get(key) != p.get(key):
                raise ValueError("frame_context")
        if p.get("timestampOrigin") != ("tv" if source=="tv_pi" else "phone")+"_receive_monotonic":
            raise ValueError("timestamp_origin")
        time, frame_id = frame.get("timestampMs"), frame.get("frameId")
        if (type(time) is not int or type(frame_id) is not int or time <= prev_time or frame_id <= prev_id):
            raise ValueError("monotonic_sequence")
        prev_time, prev_id = time, frame_id
        if frame.get("scoreSemantics") != "simcc_peak_mean_uncalibrated" or frame.get("captureTimestamp", "absent") is not None:
            raise ValueError("score_capture_semantics")
        if type(frame.get("mirrored")) is not bool or frame.get("rotationDegrees") not in (0,90,180,270):
            raise ValueError("display_metadata")
        if any(type(frame.get(k)) is not int or not 1 <= frame[k] <= 8192 for k in ("imageWidth", "imageHeight")):
            raise ValueError("image_size")
        points, scores, mask = frame.get("keypoints"), frame.get("scores"), frame.get("validity")
        if any(not isinstance(v, list) or len(v) != 17 for v in (points, scores, mask)):
            raise ValueError("body17_required")
        for point, score, valid in zip(points, scores, mask):
            if point is not None and (not isinstance(point, list) or len(point)!=2 or not all(f.finite(v) and 0<=v<=1 for v in point)):
                raise ValueError("invalid_point")
            if score is not None and not (f.finite(score) and 0<=score<=1e6):
                raise ValueError("invalid_score")
            if type(valid) is not bool or valid != (point is not None and score is not None and score>=.3):
                raise ValueError("invalid_mask")
        projected = f.frame_features(frame, p["movementSide"])
        angles = frame.get("angles")
        if projected is None:
            if angles is not None:
                raise ValueError("unavailable_angles")
        elif (not isinstance(angles, dict) or set(angles)!=set(("legHeight","hipDeg","kneeDeg","trunkLeanDeg")) or
              any(not f.finite(angles[k]) or abs(angles[k]-v)>f.TOLERANCE for k,v in zip(("legHeight","hipDeg","kneeDeg","trunkLeanDeg"),projected))):
            raise ValueError("angle_parity")
    result = f.extract(frames, p["movementSide"])
    if (p.get("featuresStatus") != result["status"] or
        not f.finite(p.get("duration")) or abs(p["duration"]-(prev_time-frames[0]["timestampMs"])/1000)>f.TOLERANCE or
        not 0<p["duration"]<=20 or p.get("frameId")!=prev_id):
        raise ValueError("duration_status")
    if not isinstance(p.get("features"), list) or len(p["features"])!=5:
        raise ValueError("feature_dimension")
    for actual, expected_value in zip(p["features"],result["values"]):
        if expected_value is None:
            if actual is not None:
                raise ValueError("missing_is_not_zero")
        elif not f.finite(actual) or abs(actual-expected_value)>f.TOLERANCE:
            raise ValueError("feature_parity")
    if not isinstance(p.get("trackingQuality"),dict) or set(p["trackingQuality"])!={"validFrameRatio"}:
        raise ValueError("quality_contract")
    quality = p["trackingQuality"].get("validFrameRatio")
    if not f.finite(quality) or abs(quality-result["validFrameRatio"])>f.TOLERANCE:
        raise ValueError("tracking_quality")
    return result


def build(export_path, *, checked_at=None, professional_attestation=None, engineering=False, git_commit="unknown"):
    now = checked_at or datetime.now(timezone.utc)
    raw = Path(export_path).read_bytes()
    source_hash = hashlib.sha256(raw).hexdigest()
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        names = archive.namelist()
        if (len(names)!=len(set(names)) or len(names)>5005 or
                sum(i.file_size for i in archive.infolist())>64*1024*1024):
            raise ValueError("invalid_or_oversized_archive")
        if any(n not in ("manifest.json","labels.csv") and not re.fullmatch(r"samples/[A-Za-z0-9_-]{1,100}\.json",n) for n in names):
            raise ValueError("unexpected_archive_entry")
        manifest = json.loads(archive.read("manifest.json"))
        for key,value in {"schemaVersion":3,"modality":"body","actionId":f.ACTION,"actionDefinitionVersion":f.DEFINITION,
                          "extractorVersion":f.EXTRACTOR,"modelInputVersion":f.INPUT,"poseModelVersion":f.POSE,
                          "labelMappingVersion":f.LABEL_VERSION,"exportContractVersion":"body-approved-export-v1",
                          "featureNames":list(f.NAMES)}.items():
            if manifest.get(key)!=value:
                raise ValueError("export_contract:"+key)
        synthetic = manifest.get("origin")=="SYNTHETIC_ENGINEERING_ONLY"
        if synthetic != engineering:
            raise ValueError("synthetic_real_isolation")
        if not engineering:
            attested = professional_attestation or {}
            if (attested.get("exportSha256")!=source_hash or attested.get("professionallyReviewed") is not True or
                    attested.get("currentConsentRechecked") is not True or not identifier(attested.get("governanceReference"))):
                raise ValueError("fresh_authorized_export_and_professional_attestation_required")
            # A file is an operator attestation, NOT an authentication/IRB credential.
            if abs((now-instant(manifest["eligibilityCheckedAt"])).total_seconds())>86400:
                raise ValueError("stale_export_recheck_consent")
        if manifest.get("source") not in ("phone","tv_pi"):
            raise ValueError("single_domain_required")
        label_rows = list(csv.DictReader(io.StringIO(archive.read("labels.csv").decode())))
        if len({r["sampleId"] for r in label_rows})!=len(label_rows):
            raise ValueError("duplicate_label_id")
        groups = manifest.get("groups",[])
        if len({g["sampleId"] for g in groups})!=len(groups):
            raise ValueError("duplicate_group_id")
        groups = {g["sampleId"]:g for g in groups}
        if set(groups)!={r["sampleId"] for r in label_rows} or len(label_rows)!=manifest.get("sampleCount"):
            raise ValueError("export_count_groups")
        if set(names)!={"manifest.json","labels.csv"}|{"samples/"+r["sampleId"]+".json" for r in label_rows}:
            raise ValueError("extra_or_missing_samples")
        rows, excluded, seen = [], [], {}
        for label in sorted(label_rows,key=lambda r:r["sampleId"]):
            sid = label["sampleId"]
            body = archive.read("samples/"+sid+".json")
            p, g = json.loads(body), groups[sid]
            try:
                if g.get("payloadSha256")!=hashlib.sha256(body).hexdigest():
                    raise ValueError("payload_hash")
                if (g.get("annotationStatus")!="APPROVED" or g.get("disposition")!="ACTIVE" or
                    g.get("consentActive") is not True or g.get("deleted") is not False or
                    g.get("independentReview") is not True):
                    raise ValueError("ineligible_review_consent_disposition")
                if instant(g["expiresAt"])<=now or not g.get("consentVersion") or instant(g["reviewedAt"])>now:
                    raise ValueError("expired_or_invalid_review")
                if not engineering and (g.get("synthetic") is not False or any(str(p.get(k,"")).upper().startswith(("DEMO","DEV-","SYNTHETIC")) for k in ("sampleId","subjectId"))):
                    raise ValueError("demo_excluded")
                if label["label"] not in f.LABELS or label["labelVersion"]!=f.LABEL_VERSION or label["actionDefinitionVersion"]!=f.DEFINITION or g.get("labelVersion")!=f.LABEL_VERSION:
                    raise ValueError("label_contract")
                if (g.get("annotatorAlias")!=label.get("annotatorId") or
                    not re.fullmatch(r"annotator_[0-9]+|synthetic-annotator",str(g.get("annotatorAlias"))) or
                    not re.fullmatch(r"reviewer_[0-9]+|synthetic-reviewer",str(g.get("reviewerAlias"))) or
                    type(g.get("annotationRevision")) is not int or g["annotationRevision"]<0):
                    raise ValueError("annotation_provenance")
                if p.get("source")!=manifest["source"] or g.get("source")!=p.get("source"):
                    raise ValueError("domain_mismatch")
                result = validate_sample(p)
                if result["status"]!="available" or result["validFrameRatio"]<.8 or p.get("terminationReason") not in ("RETURNED_TO_BASELINE","USER_FINISHED"):
                    raise ValueError("tracking_or_incomplete_attempt")
                if any(b["timestampMs"]-a["timestampMs"]>1000 for a,b in zip(p["frames"],p["frames"][1:])):
                    raise ValueError("tracking_gap_over_1000ms")
                if (p["sampleId"]!=sid or p["subjectId"]!=g.get("subjectPseudonym") or p["sessionId"]!=g.get("sessionGrouping") or p["attemptId"]!=g.get("attemptGrouping") or p["platform"]!=g.get("platform")):
                    raise ValueError("group_context")
                geometry = [{k:frame[k] for k in ("keypoints","scores","imageWidth","imageHeight")} for frame in p["frames"]]
                fingerprint = digest({"geometry":geometry,"times":[v["timestampMs"]-p["frames"][0]["timestampMs"] for v in p["frames"]],"side":p["movementSide"]})
                if fingerprint in seen:
                    if seen[fingerprint]!=p["subjectId"]:
                        raise ValueError("duplicate_geometry_cross_subject")
                    raise ValueError("duplicate_geometry_retry")
                seen[fingerprint]=p["subjectId"]
                rows.append({"sampleId":sid,"subjectId":p["subjectId"],"sessionId":p["sessionId"],"attemptId":p["attemptId"],
                             "source":p["source"],"platform":p["platform"],"domain":p["source"],"label":label["label"],
                             "labelMappingVersion":f.LABEL_VERSION,"features":result["values"],
                             "extendedFeatures":f.extract(p["frames"],p["movementSide"],True)["values"],
                             "trackingQuality":result["validFrameRatio"],"featuresStatus":"available",
                             "resampleOfSampleId":p.get("resampleOfSampleId"),"contentFingerprint":fingerprint,
                             "annotationProvenance":{"annotatorAlias":g["annotatorAlias"],"reviewerAlias":g["reviewerAlias"],
                                  "revision":g["annotationRevision"],"reviewedAt":g["reviewedAt"],"labelVersion":g["labelVersion"]},
                             "eligibility":{"consentActive":True,"annotationStatus":"APPROVED","disposition":"ACTIVE",
                                            "independentReview":True,"expiresAt":g["expiresAt"]},
                             "payloadSha256":g["payloadSha256"]})
            except (ValueError, KeyError, TypeError) as error:
                # Never print payload, exception repr or potentially identifying field values.
                reason = str(error) if isinstance(error,ValueError) else "malformed_contract"
                excluded.append({"sampleId":sid if identifier(sid) else "invalid-id", "reason":reason})
    by_id = {r["sampleId"]:r for r in rows}
    for r in rows:
        parent = by_id.get(r["resampleOfSampleId"])
        if parent and parent["subjectId"]!=r["subjectId"]:
            raise ValueError("resample_cross_subject")
    contract = f.schema()
    data_hash = digest({"rows":rows,"schema":contract,"labelMapping":list(f.LABELS),"exclusions":excluded,
                        "exportSha256":source_hash,"builderVersion":BUILDER})
    output = {"datasetVersion":"body-v3-"+data_hash[:16],"datasetHash":data_hash,
              "datasetCreatedAt":manifest["exportedAt"],"eligibilityCheckedAt":manifest["eligibilityCheckedAt"],
              "origin":"SYNTHETIC_ENGINEERING_ONLY" if engineering else "APPROVED_EXPORT_ATTESTED",
              "builderVersion":BUILDER,"gitCommit":git_commit,"exportSha256":source_hash,
              **contract,"labelMappingVersion":f.LABEL_VERSION,"labelMapping":dict(enumerate(f.LABELS)),
              "domain":manifest["source"],"rows":rows,"exclusions":excluded,
              "exclusionCounts":dict(Counter(e["reason"] for e in excluded)),
              "backendFilteredApprovedCount":manifest.get("filteredApprovedCount",0),
              "backendExclusionCounts":manifest.get("exclusionCounts",{}),
              "trackingEligibilityPolicy":"valid >=80%; max inter-observation gap <=1000ms; complete termination; engineering QC not clinical validity",
              "eligibilitySummary":"snapshot only; re-export before real training; no future withdrawal guarantee",
              "professionalReviewAttestation":None if engineering else {
                  k:professional_attestation[k] for k in ("exportSha256","professionallyReviewed","currentConsentRechecked","governanceReference")},
              "counts":{"samples":len(rows),"subjects":len({r["subjectId"] for r in rows}),
                        "labels":dict(Counter(r["label"] for r in rows)),"domains":dict(Counter(r["source"] for r in rows)),
                        "subjectsPerLabel":{label:len({r["subjectId"] for r in rows if r["label"]==label}) for label in f.LABELS},
                        "sessions":len({r["sessionId"] for r in rows}),"attempts":len({r["attemptId"] for r in rows})}}
    return output


def save(dataset, root):
    path = Path(root)/dataset["datasetVersion"]
    path.mkdir(parents=True,exist_ok=False)
    (path/"dataset_manifest.json").write_bytes(canonical(dataset))
    (path/"dataset_hash.txt").write_text(dataset["datasetHash"]+"\n",encoding="utf-8")
    return path
