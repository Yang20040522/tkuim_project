import csv
import json
import tempfile
import unittest
from pathlib import Path
import test_feature_schema as fixtures
from feature_schema import ACTION_REGISTRY, ActionDefinition, action_definition, features_from_sample
from train import load_dataset


class ActionContractTest(unittest.TestCase):
    def synthetic(self):
        definition = ActionDefinition("synthetic_test_only", "synthetic-v1",
            ("duration_seconds",), ("test_match",),
            lambda s: [(s["frames"][-1]["timestampMs"] - s["frames"][0]["timestampMs"]) / 1000],
            (5, 6), (5, 6))
        sample = fixtures.FeatureSchemaTest().sample()
        sample.update(actionId=definition.action_id, actionDefinitionVersion=definition.version,
                      featureNames=list(definition.feature_names), features=[0.3])
        return definition, sample, {**ACTION_REGISTRY, definition.action_id: definition}

    def test_synthetic_contract_extractor_not_in_production(self):
        definition, sample, registry = self.synthetic()
        self.assertNotIn(definition.action_id, ACTION_REGISTRY)
        with self.assertRaises(ValueError):
            features_from_sample(sample)
        self.assertEqual(features_from_sample(sample, registry), [0.3])
        sample["features"] = [1.5]
        with self.assertRaises(ValueError):
            features_from_sample(sample, registry)

    def test_legacy_standing_and_wrong_version(self):
        sample = fixtures.FeatureSchemaTest().sample()
        self.assertEqual(action_definition(sample).version, "standing-knee-raise-v1")
        sample["actionDefinitionVersion"] = "synthetic-v1"
        with self.assertRaises(ValueError):
            features_from_sample(sample)

    def test_dataset_retains_subject_and_rejects_cross_action_or_label_version(self):
        definition, sample, registry = self.synthetic()
        with tempfile.TemporaryDirectory() as root:
            root = Path(root)
            (root / "sample.json").write_text(json.dumps(sample), encoding="utf-8")
            labels = root / "labels.csv"
            def write(version):
                with labels.open("w", newline="", encoding="utf-8") as output:
                    writer = csv.writer(output)
                    writer.writerow(["sampleId", "label", "annotatorId", "labelVersion", "actionDefinitionVersion"])
                    writer.writerow([sample["sampleId"], "test_match", "fake_labeler", "test-v1", version])
            write(definition.version)
            x, y, subjects, _, version = load_dataset(root, labels, definition.action_id, registry)
            self.assertEqual((x, y, subjects, version), ([[0.3]], ["test_match"], ["research_1"], definition.version))
            write("another-v1")
            with self.assertRaises(ValueError):
                load_dataset(root, labels, definition.action_id, registry)
            with self.assertRaises(ValueError):
                load_dataset(root, labels)


if __name__ == "__main__":
    unittest.main()
