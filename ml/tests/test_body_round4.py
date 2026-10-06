"""Round 4 synthetic engineering tests; no patient data, network or database."""
import copy
import hashlib
import io
import json
import sys
import tempfile
import unittest
import zipfile
from datetime import datetime, timezone
from pathlib import Path

import numpy as np

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from body_v3 import dataset, features as f, models, parity, split, synthetic, training

ROOT=Path(__file__).resolve().parents[2]
FIXTURE=ROOT/"test/fixtures/body_v3_parity.json"
DART=ROOT/".dart_tool/body-r4/dart_parity.json"


class FeaturesTest(unittest.TestCase):
    def setUp(self): self.fixture=json.loads(FIXTURE.read_text())

    def test_actual_dart_python_parity_required(self):
        self.assertTrue(DART.exists(),"Run flutter test test/features/rehab_ml/body_v3_ml_parity_test.dart first")
        result=parity.check(DART,FIXTURE)
        self.assertEqual(result["status"],"PASS")
        self.assertEqual(result["cases"],8)

    def test_feature_schema_order_units_missing(self):
        contract=f.schema()
        self.assertEqual(contract["featureNames"],list(f.NAMES))
        self.assertEqual(contract["units"],self.fixture["units"])
        self.assertEqual(len(f.schema(True)["featureNames"]),8)
        self.assertIn("never zero",contract["missing"])

    def test_aspect_not_raw_normalized_angles(self):
        cases=self.fixture["cases"]
        a=f.extract(f.fixture_frames(self.fixture,cases[0]),"left")
        b=f.extract(f.fixture_frames(self.fixture,cases[6]),"left")
        self.assertGreater(abs(a["values"][1]-b["values"][1]),1)

    def test_display_mirror_rotation_never_reapplied(self):
        cases=self.fixture["cases"]
        self.assertEqual(f.extract(f.fixture_frames(self.fixture,cases[0]),"left"),
                         f.extract(f.fixture_frames(self.fixture,cases[7]),"left"))

    def test_anatomical_left_right_not_swapped(self):
        frames=f.fixture_frames(self.fixture,self.fixture["cases"][0])
        self.assertGreater(f.extract(frames,"left")["values"][0],0)
        self.assertEqual(f.extract(frames,"right")["values"][0],0)

    def test_nan_infinity_low_score_missing_ignored(self):
        frame=f.fixture_frames(self.fixture,self.fixture["cases"][0])[0]
        for value in (float("nan"),float("inf"),-1,2):
            with self.subTest(value=value):
                bad=copy.deepcopy(frame);bad["keypoints"][13][0]=value
                self.assertIsNone(f.frame_features(bad,"left"))
        frame["scores"][13]=.29
        self.assertIsNone(f.frame_features(frame,"left"))

    def test_missing_unavailable_never_zero(self):
        frames=f.fixture_frames(self.fixture,self.fixture["cases"][5])
        self.assertEqual(f.extract(frames,"left")["values"],[None]*5)
        self.assertEqual(f.extract(frames,"left",True)["values"],[None]*8)

    def test_zero_torso_safe(self):
        frame=f.fixture_frames(self.fixture,self.fixture["cases"][0])[0]
        frame["keypoints"][5]=frame["keypoints"][11]
        frame["keypoints"][6]=frame["keypoints"][12]
        self.assertIsNone(f.frame_features(frame,"left"))

    def test_simcc_greater_than_one_valid_not_probability(self):
        frame=f.fixture_frames(self.fixture,self.fixture["cases"][0])[0]
        self.assertIsNotNone(f.frame_features(frame,"left"))
        self.assertEqual(frame["scores"][5],1.4)


class ExportFixture:
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.fixture=json.loads(FIXTURE.read_text());self.path=Path(self.temp.name)/"export.zip"

    def build(self,transform=None,subjects=12,**kwargs):
        self.path.write_bytes(synthetic.export_bytes(self.fixture,subjects=subjects,transform=transform))
        return dataset.build(self.path,engineering=True,**kwargs)


class DatasetTest(ExportFixture,unittest.TestCase):

    def test_deterministic_dataset_hash_order(self):
        a=self.build();b=self.build()
        self.assertEqual(a,b);self.assertEqual(a["counts"]["samples"],72)
        self.assertEqual(a["counts"]["subjects"],12)
        self.assertEqual(a["rows"],sorted(a["rows"],key=lambda r:r["sampleId"]))

    def test_change_sample_set_new_dataset_version(self):
        self.assertNotEqual(self.build()["datasetVersion"],self.build(subjects=11)["datasetVersion"])

    def test_manifest_immutable_no_overwrite(self):
        data=self.build();dataset.save(data,self.temp.name)
        with self.assertRaises(FileExistsError): dataset.save(data,self.temp.name)

    def test_synthetic_cannot_be_real(self):
        self.build()
        with self.assertRaisesRegex(ValueError,"synthetic_real_isolation"):
            dataset.build(self.path)

    def test_real_requires_fresh_professional_governance_attestation(self):
        self.build()
        with zipfile.ZipFile(self.path) as source:
            entries={name:source.read(name) for name in source.namelist()}
        manifest=json.loads(entries["manifest.json"]);manifest.pop("origin")
        entries["manifest.json"]=dataset.canonical(manifest)
        with zipfile.ZipFile(self.path,"w") as target:
            for name,body in entries.items(): target.writestr(name,body)
        with self.assertRaisesRegex(ValueError,"professional_attestation_required"): dataset.build(self.path)
        attestation={"exportSha256":hashlib.sha256(self.path.read_bytes()).hexdigest(),"professionallyReviewed":True,
                     "currentConsentRechecked":True,"governanceReference":"internal-fixture-not-approval"}
        with self.assertRaisesRegex(ValueError,"stale_export"): dataset.build(self.path,professional_attestation=attestation)

    def test_resample_parent_cross_subject_rejected(self):
        def mutate(p,g):
            if p["sampleId"]=="SYNTHETIC-01-0-0": p["resampleOfSampleId"]="SYNTHETIC-00-0-0"
        with self.assertRaisesRegex(ValueError,"resample_cross_subject"): self.build(mutate)

    def test_body_hand_isolation(self):
        result=self.build(lambda p,g:p.update(modality="hand",schemaVersion=2))
        self.assertEqual(result["counts"]["samples"],0)

    def test_ineligible_states(self):
        for key,value in (("annotationStatus","UNLABELED"),("annotationStatus","DRAFT"),("annotationStatus","SUBMITTED"),
                          ("annotationStatus","RETURNED"),("annotationStatus","REJECTED"),("annotationStatus","NEEDS_RESAMPLE"),
                          ("disposition","REJECTED"),("disposition","NEEDS_RESAMPLE"),("consentActive",False),("deleted",True),
                          ("independentReview",False),("expiresAt","2000-01-01T00:00:00Z")):
            with self.subTest(key=key,value=value):
                result=self.build(lambda p,g:g.update({key:value}),subjects=1)
                self.assertEqual(result["counts"]["samples"],0)
                self.assertEqual(len(result["exclusions"]),6)

    def test_tampered_payload_hash_excluded(self):
        self.build(subjects=1)
        with zipfile.ZipFile(self.path) as z: entries={n:z.read(n) for n in z.namelist()}
        name=next(n for n in entries if n.startswith("samples/"));p=json.loads(entries[name]);p["duration"]=2
        entries[name]=dataset.canonical(p)
        with zipfile.ZipFile(self.path,"w") as z:
            for n,b in entries.items(): z.writestr(n,b)
        result=dataset.build(self.path,engineering=True)
        self.assertEqual(result["exclusionCounts"]["payload_hash"],1)

    def test_unknown_sensitive_payload_never_exported(self):
        result=self.build(lambda p,g:p.update(email="SYNTHETIC-NOT-AN-EMAIL"),subjects=1)
        self.assertNotIn("SYNTHETIC-NOT-AN-EMAIL",json.dumps(result))
        self.assertEqual(result["counts"]["samples"],0)

    def test_duplicate_geometry_retry_deduplicated(self):
        def mutate(p,g):
            reference=synthetic.sample(self.fixture,0,0,0)
            p["frames"]=reference["frames"];p["streamSessionId"]=reference["streamSessionId"]
            p["features"]=reference["features"];p["duration"]=reference["duration"]
        result=self.build(mutate,subjects=2)
        self.assertEqual(result["counts"]["samples"],1)
        self.assertIn("duplicate_geometry_cross_subject",result["exclusionCounts"])
        self.assertIn("duplicate_geometry_retry",result["exclusionCounts"])


def invalid_sample_test(key,value):
    def test(self):
        result=self.build(lambda p,g:p.update({key:value}),subjects=1)
        self.assertEqual(result["counts"]["samples"],0)
    return test

for _key,_value in (("actionDefinitionVersion","v0"),("extractorVersion","v0"),("modelInputVersion","v0"),
                    ("poseModelVersion","v0"),("schemaVersion",1),("featureNames",list(reversed(f.NAMES))),
                    ("featuresStatus","unavailable"),("features",[0]*5),("terminationReason","TRACKING_LOST"),
                    ("source","phone"),("platform","android_phone"),("trackingQuality",{"validFrameRatio":0.1})):
    setattr(DatasetTest,"test_reject_"+_key,invalid_sample_test(_key,_value))


class SplitTest(ExportFixture,unittest.TestCase):
    def test_grouped_reproducible_no_overlap(self):
        rows=self.build()["rows"];a,ma=split.build(rows);b,mb=split.build(rows)
        self.assertEqual(ma,mb);self.assertEqual(a,b);split.guard(rows,a)
        self.assertFalse(set(ma["trainSubjectIds"])&set(ma["testSubjectIds"]))
        self.assertFalse(set(ma["validationSubjectIds"])&set(ma["testSubjectIds"]))

    def test_small_subject_guard(self):
        with self.assertRaises(split.DataInsufficient): split.build(self.build(subjects=4)["rows"])

    def test_small_label_guard(self):
        rows=[r for r in self.build()["rows"] if r["label"]!="trunk_compensation"]
        with self.assertRaises(split.DataInsufficient): split.build(rows)

    def test_linkage_guards(self):
        rows=self.build()["rows"];parts,_=split.build(rows)
        a,b=parts["train"][0],parts["test"][0]
        for key in ("subjectId","sessionId","attemptId","contentFingerprint","sampleId"):
            with self.subTest(key=key):
                bad=copy.deepcopy(rows);bad[b][key]=bad[a][key]
                with self.assertRaises(ValueError): split.guard(bad,parts)
        for key in ("resampleOfSampleId","augmentationOfSampleId"):
            bad=copy.deepcopy(rows);bad[b][key]=bad[a]["sampleId"]
            with self.assertRaisesRegex(ValueError,"leakage"): split.guard(bad,parts)

    def test_missing_duplicate_partition_rows(self):
        rows=self.build()["rows"];parts,_=split.build(rows);parts["test"].append(parts["train"][0])
        with self.assertRaises(ValueError):split.guard(rows,parts)

    def test_same_subject_resample_stays_same_partition(self):
        rows=self.build()["rows"];rows[1]["resampleOfSampleId"]=rows[0]["sampleId"]
        parts,_=split.build(rows);split.guard(rows,parts)


class ModelTest(unittest.TestCase):
    def setUp(self):
        fixture=json.loads(FIXTURE.read_text())
        ps=[synthetic.sample(fixture,s,l) for s in range(6) for l in range(3)]
        self.x=np.array([p["features"] for p in ps],dtype=np.float32)
        self.y=np.array([l for s in range(6) for l in range(3)]);self.groups=np.repeat(np.arange(6),3)

    def test_rf_actual_onnx_parity(self):self.check_family("RandomForest")
    def test_xgboost_actual_onnx_parity(self):self.check_family("XGBoost")
    def test_svm_actual_onnx_parity(self):self.check_family("SVM")

    def check_family(self,family):
        _,_,params=next(c for c in models.CANDIDATES if c[1]==family)
        model=models.make(family,params,42,self.y,self.groups);model.fit(self.x,self.y)
        graph=models.convert(model,family,5)
        receipt=training.onnx_check(model,graph,self.x,5)
        self.assertEqual(receipt["status"],"PASS")
        self.assertEqual(receipt["predictedClasses"],[0,1,2])

    def test_missing_and_shape_reject_before_inference(self):
        for x in ([[None]*5],[[float("inf")]*5],[[0]*4],[0]*5):
            with self.assertRaises(ValueError):models.checked_input(x,5)

    def test_scaler_calibration_fits_only_group_training_fold(self):
        model=models.make("SVM",models.CANDIDATES[4][2],42,self.y,self.groups);model.fit(self.x,self.y)
        for calibrated,(indices,unused) in zip(model.calibrated_classifiers_,model.cv):
            np.testing.assert_allclose(calibrated.estimator.named_steps["scaler"].mean_,self.x[indices].mean(axis=0),atol=1e-5)
            self.assertFalse(set(self.groups[indices])&set(self.groups[unused]))

    def test_domain_metrics_and_calibration_are_explicit(self):
        rows=[{"source":"tv_pi","subjectId":f"anon-{i//3}","sampleId":f"s-{i}","trackingQuality":1.,"featuresStatus":"available","features":[0,90,90,0,1]} for i in range(6)]
        y=np.array([0,1,2]*2);pred=np.array([0,1,0]*2);prob=np.eye(3)[pred]*.8+.2/3
        report=training.metrics(y,pred,prob,rows)
        self.assertEqual(report["phone"]["status"],"DATA_INSUFFICIENT")
        self.assertEqual(len(report["errors"]),2)
        self.assertIn("multiclassBrier",report["calibration"])

    def test_immutable_artifact_and_all_required_files(self):
        fixture=json.loads(FIXTURE.read_text())
        with tempfile.TemporaryDirectory() as temp:
            export=Path(temp)/"export.zip";export.write_bytes(synthetic.export_bytes(fixture))
            data=dataset.build(export,engineering=True)
            receipt=parity.check(DART,FIXTURE)
            output=training.train(data,temp,"synthetic-test",receipt)
            required={"dataset_manifest.json","dataset_hash.txt","split_manifest.json","feature_schema.json","label_mapping.json",
                      "training_config.json","environment.json","metrics.json","classification_report.json","confusion_matrix.csv",
                      "ablation_results.json","model.joblib","model.onnx","onnx_parity.json","training.log","MODEL_CARD.md","artifact_manifest.json"}
            self.assertTrue(required <= {p.name for p in output.iterdir()})
            manifest=json.loads((output/"artifact_manifest.json").read_text())
            self.assertFalse(manifest["deploymentApproved"]);self.assertEqual(manifest["modelStatus"],"EXPERIMENTAL")
            for name,sha in manifest["hashes"].items(): self.assertEqual(hashlib.sha256((output/name).read_bytes()).hexdigest(),sha)
            self.assertEqual(json.loads((output/"metrics.json").read_text())["finalTestEvaluations"],1)
            with self.assertRaises(FileExistsError): training.train(data,temp,"synthetic-test",receipt)

    def test_tampered_dataset_cannot_train(self):
        with self.assertRaisesRegex(ValueError,"tampered"):
            training.train({"rows":[],"exclusions":[],"exportSha256":"fake","builderVersion":"fake","datasetHash":"fake"},"unused","unused",{"status":"PASS"})


if __name__=="__main__":unittest.main()
