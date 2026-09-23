import math
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from feature_schema import FEATURE_NAMES, features_from_sample
from train import check_sufficiency


class FeatureSchemaTest(unittest.TestCase):
    def sample(self):
        points = [[0.0, 0.0] for _ in range(17)]
        points[5], points[6] = [-0.3, -1.0], [0.3, -1.0]
        points[11], points[12] = [-0.3, 0.0], [0.3, 0.0]
        points[13], points[14] = [-0.3, 0.5], [0.3, 0.5]
        points[15], points[16] = [-0.3, 1.0], [0.3, 1.0]
        frame = {"landmarks": points, "confidence": [0.9] * 17}
        frames = [{**frame, "timestampMs": n * 100} for n in range(4)]
        return {
            "schemaVersion": 1, "actionId": "standing_knee_raise",
            "sampleId": "test", "subjectId": "research_1",
            "movementSide": "left", "cameraView": "front",
            "featureNames": FEATURE_NAMES, "frames": frames,
            "features": [-0.5, 180.0, 180.0, 0.0, 0.3],
        }

    def test_golden_feature_contract(self):
        sample = self.sample()
        self.assertEqual(features_from_sample(sample), sample["features"])

    def test_low_confidence_rejected(self):
        sample = self.sample()
        sample["frames"][0]["confidence"] = [0.1] * 17
        with self.assertRaises(ValueError):
            features_from_sample(sample)

    def test_non_finite_rejected(self):
        sample = self.sample()
        sample["frames"][0]["landmarks"][0] = [math.nan, 0]
        with self.assertRaises(ValueError):
            features_from_sample(sample)

    def test_feature_order_mismatch_rejected(self):
        sample = self.sample()
        sample["featureNames"] = list(reversed(FEATURE_NAMES))
        with self.assertRaises(ValueError):
            features_from_sample(sample)

    def test_insufficient_labeled_subjects_rejected(self):
        with self.assertRaisesRegex(ValueError, "等待標註資料"):
            check_sufficiency(["meets_requirement"] * 10, ["one"] * 10)


if __name__ == "__main__":
    unittest.main()
