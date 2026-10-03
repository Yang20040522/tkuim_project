import copy
import json
import math
import unittest
from pathlib import Path
from feature_schema import features_from_sample


class GoldenTest(unittest.TestCase):
    def test_shared_dart_python_fixture(self):
        golden = json.loads((Path(__file__).parent / "fixtures/g4_features.json").read_text())
        for case in golden["cases"]:
            with self.subTest(case=case["name"]):
                points = copy.deepcopy(golden["rawPoints"])
                for index, point in case.get("overrides", {}).items(): points[int(index)] = point
                # The shared raw skeleton has hip midpoint (0,0), shoulder width 2.
                points = [[x / 2, y / 2] for x, y in points]
                if case.get("mutation") == "nan": points[13][0] = math.nan
                sample = {k: golden[k] for k in ("actionId", "schemaVersion", "actionDefinitionVersion", "featureNames")}
                sample.update(sampleId="synthetic", subjectId="synthetic_group", movementSide=case["side"], cameraView="front",
                    features=case.get("features", [-0.5, 180, 180, 0, 0.3]),
                    frames=[{"timestampMs": i * 100, "landmarks": points, "confidence": [case.get("confidence", 0.9)] * 17} for i in range(case.get("frameCount", 4))])
                if case.get("legacy"): sample.pop("actionDefinitionVersion")
                if "version" in case: sample["actionDefinitionVersion"] = case["version"]
                if case.get("reverseFeatures"): sample["featureNames"] = list(reversed(sample["featureNames"]))
                if "features" in case and not ("version" in case or case.get("reverseFeatures")):
                    for actual, expected in zip(features_from_sample(sample), case["features"]): self.assertAlmostEqual(actual, expected, places=5)
                else:
                    with self.assertRaises(ValueError): features_from_sample(sample)
