"""Train only on professionally labeled, participant-grouped real samples."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

from feature_schema import ACTION_ID, FEATURE_NAMES, SCHEMA_VERSION, features_from_sample

LABELS = ("meets_requirement", "insufficient_range", "trunk_compensation")
MIN_SAMPLES_PER_CLASS = 10
MIN_SUBJECTS_PER_CLASS = 5


def load_dataset(samples_dir: Path, labels_csv: Path):
    labels = {}
    with labels_csv.open(newline="", encoding="utf-8-sig") as source:
        for row in csv.DictReader(source):
            sample_id = row["sampleId"].strip()
            if sample_id in labels:
                raise ValueError("duplicate label sample ID")
            if row["label"] not in LABELS or not all(
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

    features, targets, groups, ids = [], [], [], []
    for path in sorted(samples_dir.glob("*.json")):
        with path.open(encoding="utf-8") as source:
            sample = json.load(source)
        sample_id = sample.get("sampleId")
        if sample_id not in labels:
            continue
        row = labels.pop(sample_id)
        features.append(features_from_sample(sample))
        targets.append(row["label"])
        groups.append(sample["subjectId"])
        ids.append(sample_id)
    if labels:
        raise ValueError("some labels have no matching valid sample")
    if len(ids) != len(set(ids)):
        raise ValueError("duplicate sample ID")
    return features, targets, groups, label_versions.pop(), definition_versions.pop()


def check_sufficiency(targets, groups):
    counts = Counter(targets)
    subjects = defaultdict(set)
    for label, group in zip(targets, groups):
        subjects[label].add(group)
    if any(counts[label] < MIN_SAMPLES_PER_CLASS or
           len(subjects[label]) < MIN_SUBJECTS_PER_CLASS for label in LABELS):
        raise ValueError(
            "等待標註資料：每類至少需要 10 筆、5 位不同受試者；不輸出模型或準確率"
        )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--samples", required=True, type=Path)
    parser.add_argument("--labels", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    x, y, groups, label_version, definition_version = load_dataset(args.samples, args.labels)
    check_sufficiency(y, groups)

    # Imported only after data validation so an empty dataset needs no ML stack.
    import joblib
    import numpy as np
    from sklearn.ensemble import RandomForestClassifier
    from sklearn.metrics import classification_report, confusion_matrix
    from sklearn.model_selection import GroupShuffleSplit
    from skl2onnx import convert_sklearn
    from skl2onnx.common.data_types import FloatTensorType

    x = np.asarray(x, dtype=np.float32)
    y = np.asarray(y)
    groups = np.asarray(groups)
    split = None
    for seed in range(100):
        candidate = next(GroupShuffleSplit(n_splits=1, test_size=0.25,
                                           random_state=seed).split(x, y, groups))
        train_indices, test_indices = candidate
        if set(y[train_indices]) == set(LABELS) and set(y[test_indices]) == set(LABELS):
            split = candidate
            break
    if split is None:
        raise ValueError("受試者分組後無法讓三類同時出現在訓練與測試集；不輸出模型")
    train_indices, test_indices = split
    if set(groups[train_indices]) & set(groups[test_indices]):
        raise AssertionError("participant leakage")
    model = RandomForestClassifier(n_estimators=200, class_weight="balanced",
                                   random_state=42, n_jobs=1)
    model.fit(x[train_indices], y[train_indices])
    predictions = model.predict(x[test_indices])
    report = {
        "modelVersion": "standing_knee_raise_rf_v1",
        "labelVersion": label_version,
        "actionDefinitionVersion": definition_version,
        "actionId": ACTION_ID,
        "schemaVersion": SCHEMA_VERSION,
        "featureNames": FEATURE_NAMES,
        "classes": list(model.classes_),
        "sampleCounts": dict(Counter(y.tolist())),
        "trainSubjects": len(set(groups[train_indices])),
        "testSubjects": len(set(groups[test_indices])),
        "confusionMatrixLabels": list(LABELS),
        "confusionMatrix": confusion_matrix(y[test_indices], predictions,
                                             labels=LABELS).tolist(),
        "classificationReport": classification_report(
            y[test_indices], predictions, labels=LABELS,
            output_dict=True, zero_division=0),
        "medicalDisclaimer": "Research aid only; not a medical diagnosis or training gate.",
    }
    # Write artifacts only after a real grouped hold-out evaluation succeeds.
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / "metrics.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    joblib.dump(model, args.output / "model.joblib")
    onnx = convert_sklearn(model,
        initial_types=[("input", FloatTensorType([None, len(FEATURE_NAMES)]))],
        options={id(model): {"zipmap": False}}, target_opset=15)
    (args.output / "model.onnx").write_bytes(onnx.SerializeToString())
    print("已完成真實分組測試；指標與混淆矩陣位於輸出目錄。部署前仍須審核與裝置端驗證。")


if __name__ == "__main__":
    try:
        main()
    except ValueError as error:
        print(str(error), file=sys.stderr)
        raise SystemExit(2) from None
