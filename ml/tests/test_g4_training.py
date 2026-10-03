"""Synthetic fixtures only: any computed metric is not a real research result."""
import copy
import csv
import hashlib
import json
import math
import tempfile
import unittest
from pathlib import Path
import numpy as np
import test_feature_schema as fixtures
from feature_schema import STANDING_DEFINITION as definition
from train import load_dataset, train_artifacts, dataset_digest, verify_export
from model_artifacts import validate_input, verify_parity


class G4TrainingTest(unittest.TestCase):
    def dataset(self, root):
        sample = fixtures.FeatureSchemaTest().sample()
        (root / "one.json").write_text(json.dumps(sample))
        labels = root / "labels.csv"
        labels.write_text("sampleId,label,annotatorId,labelVersion,actionDefinitionVersion\ntest,meets_requirement,synthetic_labeler,research-v1,standing-knee-raise-v1\n")
        return sample, labels

    def test_duplicate_json_id_not_silently_skipped(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d); sample, labels = self.dataset(root)
            (root / "two.json").write_text(json.dumps(sample))
            with self.assertRaisesRegex(ValueError, "duplicate sample"):
                load_dataset(root, labels)

    def test_duplicate_labels_and_unassessable_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d); _, labels = self.dataset(root)
            text = labels.read_text()
            labels.write_text(text + text.splitlines()[1] + "\n")
            with self.assertRaises(ValueError): load_dataset(root, labels)
            labels.write_text(text.replace("meets_requirement", "unassessable"))
            with self.assertRaises(ValueError): load_dataset(root, labels)

    def test_mixed_version_and_feature_order_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d); sample, labels = self.dataset(root)
            for changes in ({"actionId": "unknown"}, {"featureNames": list(reversed(sample["featureNames"]))}, {"actionDefinitionVersion": "v2"}):
                bad = {**sample, **changes}
                (root / "one.json").write_text(json.dumps(bad))
                with self.assertRaises(ValueError): load_dataset(root, labels)

    def test_governance_and_content_commitment_required(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d); _, labels = self.dataset(root)
            manifest = root.parent / (root.name + "_manifest.json")
            approval = root.parent / (root.name + "_approval.json")
            try:
                manifest.write_text(json.dumps({"studyId": "synthetic-only", "exportedAt": "2026-01-01T00:00:00Z", "sampleCount": 1,
                    "actionId": definition.action_id, "schemaVersion": 1, "actionDefinitionVersion": definition.version, "featureNames": list(definition.feature_names)}))
                evidence = {k: True for k in ("authorizedExportVerified", "consentAndRetentionVerified", "professionalDefinitionsApproved", "independentReviewVerified")}
                evidence.update(verifiedBy="synthetic_operator", verifiedAt="2026-01-01", retentionPolicyVersion="synthetic-only", labelVersion="research-v1", actionDefinitionVersion=definition.version,
                    exportManifestSha256=hashlib.sha256(manifest.read_bytes()).hexdigest(), datasetSha256=dataset_digest(root, labels))
                approval.write_text(json.dumps(evidence))
                verify_export(root, labels, manifest, approval, definition, 1, "research-v1")
                evidence["professionalDefinitionsApproved"] = False
                approval.write_text(json.dumps(evidence))
                with self.assertRaises(ValueError): verify_export(root, labels, manifest, approval, definition, 1, "research-v1")
                evidence["professionalDefinitionsApproved"] = True
                approval.write_text(json.dumps(evidence)); labels.write_text(labels.read_text() + "\n")
                with self.assertRaises(ValueError): verify_export(root, labels, manifest, approval, definition, 1, "research-v1")
            finally:
                manifest.unlink(missing_ok=True); approval.unlink(missing_ok=True)

    def test_invalid_onnx_inputs_fail_before_runtime(self):
        for data in ([[1] * 4], [[1, 2, math.nan, 4, 5]], [[1, 2, math.inf, 4, 5]], [1, 2, 3, 4, 5], [[1e100] * 5]):
            with self.assertRaises(ValueError): validate_input(data)

    def test_synthetic_rf_grouped_export_parity_and_reproducibility(self):
        # Ten subjects, two repeats in each class. Never formal Ground Truth.
        x, y, groups = [], [], []
        for subject in range(10):
            for cls, label in enumerate(definition.labels):
                for rep in range(2):
                    x.append([float(cls), 100 - 10 * cls, 130 - cls, 5 * cls, 1 + subject / 100 + rep / 1000])
                    y.append(label); groups.append(f"synthetic_{subject}")
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            a = train_artifacts(x, y, groups, "synthetic-only", definition, root / "a", data_origin="synthetic_fixture")
            b = train_artifacts(x, y, groups, "synthetic-only", definition, root / "b", data_origin="synthetic_fixture")
            self.assertEqual(a, b)
            self.assertEqual(a["trainSubjects"] + a["testSubjects"], 10)
            self.assertEqual(a["onnxParity"]["status"], "PASS")
            manifest = json.loads((root / "a/model_manifest.json").read_text())
            self.assertFalse(manifest["deploymentApproved"])
            self.assertEqual(manifest["dataOrigin"], "synthetic_fixture")
            self.assertEqual(manifest["modelSha256"], hashlib.sha256((root / "a/model.onnx").read_bytes()).hexdigest())
            self.assertEqual(manifest["classes"], sorted(definition.labels))
            with self.assertRaises(ValueError): train_artifacts(x, y, groups, "synthetic-only", definition, root / "a", data_origin="synthetic_fixture")

    def test_insufficient_data_no_output(self):
        with tempfile.TemporaryDirectory() as d:
            output = Path(d) / "none"
            with self.assertRaises(ValueError): train_artifacts([[1] * 5], [definition.labels[0]], ["synthetic"], "test", definition, output)
            self.assertFalse(output.exists())
