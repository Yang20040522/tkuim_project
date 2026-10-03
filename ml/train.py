"""Train only on professionally labeled, participant-grouped real samples."""

from __future__ import annotations

import argparse
import csv
import json
import sys
import hashlib
from collections import Counter, defaultdict
from pathlib import Path

from feature_schema import ACTION_ID, ACTION_REGISTRY, action_definition, features_from_sample

LABELS = ("meets_requirement", "insufficient_range", "trunk_compensation")
MIN_SAMPLES_PER_CLASS = 10
MIN_SUBJECTS_PER_CLASS = 5


def load_dataset(samples_dir: Path, labels_csv: Path, action_id=ACTION_ID, registry=None):
    registry = ACTION_REGISTRY if registry is None else registry
    definition = registry.get(action_id)
    if definition is None:
        raise ValueError("unsupported research action")
    labels = {}
    with labels_csv.open(newline="", encoding="utf-8-sig") as source:
        for row in csv.DictReader(source):
            sample_id = row["sampleId"].strip()
            if sample_id in labels:
                raise ValueError("duplicate label sample ID")
            if row["label"] not in definition.labels or not all(
                row.get(field, "").strip() for field in
                ("annotatorId", "labelVersion", "actionDefinitionVersion")
            ):
                raise ValueError("label requires reviewed class and provenance")
            labels[sample_id] = row
    if not labels:
        raise ValueError("等待標註資料：沒有可用的專業標籤")
    label_versions = {row["labelVersion"] for row in labels.values()}
    definition_versions = {row["actionDefinitionVersion"] for row in labels.values()}
    if len(label_versions) != 1 or len(definition_versions) != 1:
        raise ValueError("混合標註或動作定義版本；請分開訓練")

    features, targets, groups, ids, seen = [], [], [], [], set()
    for path in sorted(samples_dir.glob("*.json")):
        with path.open(encoding="utf-8") as source:
            sample = json.load(source)
        sample_id = sample.get("sampleId")
        if not isinstance(sample_id, str) or not sample_id.strip() or sample_id in seen:
            raise ValueError("invalid or duplicate sample ID")
        seen.add(sample_id)
        if sample_id not in labels:
            continue
        row = labels.pop(sample_id)
        sample_definition = action_definition(sample, registry)
        if not isinstance(sample.get("subjectId"), str) or not sample["subjectId"].strip():
            raise ValueError("missing anonymous subject grouping")
        if sample_definition != definition or row["actionDefinitionVersion"] != definition.version:
            raise ValueError("mixed action/definition versions; train separately")
        features.append(features_from_sample(sample, registry))
        targets.append(row["label"])
        groups.append(sample["subjectId"])
        ids.append(sample_id)
    if labels:
        raise ValueError("some labels have no matching valid sample")
    if len(ids) != len(set(ids)):
        raise ValueError("duplicate sample ID")
    return features, targets, groups, label_versions.pop(), definition_versions.pop()


def check_sufficiency(targets, groups, labels=LABELS):
    if len(targets) != len(groups) or set(targets) != set(labels):
        raise ValueError("等待標註資料：類別不完整或不支援")
    counts = Counter(targets)
    subjects = defaultdict(set)
    for label, group in zip(targets, groups):
        subjects[label].add(group)
    if any(counts[label] < MIN_SAMPLES_PER_CLASS or
           len(subjects[label]) < MIN_SUBJECTS_PER_CLASS for label in labels):
        raise ValueError(
            "等待標註資料：每類至少需要 10 筆、5 位不同受試者；不輸出模型或準確率"
        )


def dataset_digest(samples_dir, labels_csv):
    """Content commitment for a trusted operator's private export verification."""
    digest = hashlib.sha256()
    for path in [labels_csv, *sorted(samples_dir.glob("*.json"))]:
        digest.update(path.name.encode("utf-8"))
        digest.update(b"\0")
        digest.update(path.read_bytes())
        digest.update(b"\0")
    return digest.hexdigest()


def verify_export(samples_dir, labels_csv, export_manifest, approval, definition, count, label_version):
    """Offline attestation is not authentication: only a trusted operator may supply it.

    Backend export remains the authority for consent/review/retention. Obtain a
    fresh export before each run; this cannot discover subsequent withdrawals.
    """
    manifest_bytes = export_manifest.read_bytes()
    manifest = json.loads(manifest_bytes)
    evidence = json.loads(approval.read_text(encoding="utf-8"))
    if (manifest.get("actionId") != definition.action_id or
        manifest.get("schemaVersion") != definition.schema_version or
        manifest.get("actionDefinitionVersion") != definition.version or
        manifest.get("featureNames") != list(definition.feature_names) or
        type(manifest.get("sampleCount")) is not int or manifest["sampleCount"] != count or
        not manifest.get("studyId") or not manifest.get("exportedAt")):
        raise ValueError("authorized export contract/count mismatch")
    if (not all(evidence.get(k) is True for k in
                ("authorizedExportVerified", "consentAndRetentionVerified", "professionalDefinitionsApproved", "independentReviewVerified")) or
        not all(isinstance(evidence.get(k), str) and evidence[k].strip() for k in
                ("verifiedBy", "verifiedAt", "retentionPolicyVersion")) or
        evidence.get("labelVersion") != label_version or
        evidence.get("actionDefinitionVersion") != definition.version or
        evidence.get("exportManifestSha256") != hashlib.sha256(manifest_bytes).hexdigest() or
        evidence.get("datasetSha256") != dataset_digest(samples_dir, labels_csv)):
        raise ValueError("NOT READY: missing approved export/governance verification")
    return evidence


def train_artifacts(x, y, groups, label_version, definition, output, *, data_origin="reviewed_export"):
    """Executable engine; synthetic fixtures are explicitly marked nondeployable."""
    check_sufficiency(y, groups, definition.labels)
    import numpy as np
    from sklearn.ensemble import RandomForestClassifier
    from sklearn.metrics import classification_report, confusion_matrix
    from sklearn.model_selection import GroupShuffleSplit
    from model_artifacts import export_verified

    x = np.asarray(x, dtype=np.float32)
    if x.ndim != 2 or x.shape != (len(y), len(definition.feature_names)) or not np.isfinite(x).all():
        raise ValueError("invalid float32 feature matrix")
    y, groups = np.asarray(y), np.asarray(groups)
    split = None
    for seed in range(100):
        candidate = next(GroupShuffleSplit(n_splits=1, test_size=0.25,
                                           random_state=seed).split(x, y, groups))
        train_indices, test_indices = candidate
        if set(y[train_indices]) == set(definition.labels) and set(y[test_indices]) == set(definition.labels):
            split = candidate
            break
    if split is None:
        raise ValueError("受試者分組後類別不足；不輸出模型")
    train_indices, test_indices = split
    if set(groups[train_indices]) & set(groups[test_indices]):
        raise AssertionError("participant leakage")
    model = RandomForestClassifier(n_estimators=200, class_weight="balanced", random_state=42, n_jobs=1)
    model.fit(x[train_indices], y[train_indices])
    predictions = model.predict(x[test_indices])
    report = {
        "dataOrigin": data_origin,
        "modelVersion": f"{definition.action_id}_rf_{definition.version}",
        "labelVersion": label_version, "actionDefinitionVersion": definition.version,
        "actionId": definition.action_id, "schemaVersion": definition.schema_version,
        "featureNames": list(definition.feature_names), "classes": model.classes_.tolist(),
        "sampleCounts": dict(Counter(y.tolist())),
        "trainSampleCounts": dict(Counter(y[train_indices].tolist())),
        "testSampleCounts": dict(Counter(y[test_indices].tolist())),
        "trainSubjects": len(set(groups[train_indices])), "testSubjects": len(set(groups[test_indices])),
        "splitSeed": seed, "testFraction": 0.25, "modelSeed": 42,
        "hyperparameters": model.get_params(),
        "confusionMatrixLabels": list(definition.labels),
        "confusionMatrix": confusion_matrix(y[test_indices], predictions, labels=definition.labels).tolist(),
        "classificationReport": classification_report(y[test_indices], predictions,
            labels=definition.labels, output_dict=True, zero_division=0),
        "medicalDisclaimer": "研究輔助，非診斷或計次門檻；最低資料量不是臨床可靠性證明。",
    }
    report["macroF1"] = report["classificationReport"]["macro avg"]["f1-score"]
    # Validate parity before writing any model/report; holdout never tunes parameters.
    export_verified(model, x[test_indices], definition, report, output)
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--samples", required=True, type=Path)
    parser.add_argument("--labels", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--action", default=ACTION_ID, choices=tuple(ACTION_REGISTRY))
    parser.add_argument("--export-manifest", required=True, type=Path)
    parser.add_argument("--approval", required=True, type=Path)
    args = parser.parse_args()
    definition = ACTION_REGISTRY[args.action]
    x, y, groups, label_version, definition_version = load_dataset(args.samples, args.labels, args.action)
    verify_export(args.samples, args.labels, args.export_manifest, args.approval, definition, len(y), label_version)
    report = train_artifacts(x, y, groups, label_version, definition, args.output)
    print(f"已完成受試者分組評估；Macro F1={report['macroF1']:.4f}，結果限本次資料。模型仍未核准部署。")


if __name__ == "__main__":
    try:
        main()
    except ValueError as error:
        print(str(error), file=sys.stderr)
        raise SystemExit(2) from None
