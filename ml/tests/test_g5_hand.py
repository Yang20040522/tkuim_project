import copy
import json
import math
import sys
import unittest
import tempfile
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from feature_schema import ACTION_REGISTRY, features_from_sample
from train import load_dataset, train_artifacts

def sample(action):
    g=json.loads((Path(__file__).parent/'fixtures/g5_hand_motion.json').read_text())
    frames=[]
    for i, angle in enumerate(g['anglesDeg']):
        p=copy.deepcopy(g['basePoints']); p[4][0]=p[6][0]+g['pinchRatios'][i]*0.2
        rad=math.radians(angle)
        p=[[0.5+(x-0.5)*math.cos(rad)-(y-0.5)*math.sin(rad),0.5+(x-0.5)*math.sin(rad)+(y-0.5)*math.cos(rad),z] for x,y,z in p]
        frames.append({'timestampMs':i*g['frameStepMs'],'landmarks':p})
    d=ACTION_REGISTRY[action]
    return {'sampleId':'synthetic','subjectId':'synthetic_group','actionId':action,'schemaVersion':2,
        'actionDefinitionVersion':d.version,'featureNames':list(d.feature_names),'orderedFeatureNames':list(d.feature_names),
        'features':g['expected'][action],'landmarkSource':'mediapipe_hand_21','extractorVersion':'hand-image-proxy-v1',
        'modelInputVersion':'hand-features-v1','timestampOrigin':'channel-arrival-stopwatch','timestampMs':1500,
        'movementSide':'unknown','anatomicalSide':'unknown','cameraView':'front','capturedAt':'2026-01-01T00:00:00Z',
        'segment':{'startMs':0,'endMs':1500,'kind':'rule-rep-boundaries','completedReps':1},'frames':frames}

class HandTests(unittest.TestCase):
    def test_independent_synthetic_rf_onnx_contracts_never_deployment_approved(self):
        for action in ('turnPalm','sidePinch','wristExtension','wristSideBend'):
            with self.subTest(action=action), tempfile.TemporaryDirectory() as d:
                definition=ACTION_REGISTRY[action]
                # Pipeline exercise only: artificial features, not clinical samples/accuracy.
                x,y,groups=[],[],[]
                for subject in range(10):
                    for cls,label in enumerate(definition.labels):
                        for rep in range(2):
                            x.append([float(cls),1+cls,2+cls,3+cls,1+subject/100+rep/1000])
                            y.append(label); groups.append(f'synthetic_{subject}')
                metrics=train_artifacts(x,y,groups,'hand-research-v1',definition,Path(d),data_origin='synthetic_fixture')
                manifest=json.loads((Path(d)/'model_manifest.json').read_text())
                self.assertEqual(metrics['onnxParity']['status'],'PASS')
                self.assertEqual(manifest['actionId'],action)
                self.assertEqual(manifest['preprocessing'],definition.preprocessing)
                self.assertEqual(manifest['landmarkSource'],'mediapipe_hand_21')
                self.assertFalse(manifest['deploymentApproved'])
                self.assertEqual(manifest['dataOrigin'],'synthetic_fixture')
    def test_labels_action_and_definition_isolation(self):
        for action in ('turnPalm','sidePinch','wristExtension','wristSideBend'):
            with self.subTest(action=action), tempfile.TemporaryDirectory() as d:
                root=Path(d); s=sample(action); (root/'s.json').write_text(json.dumps(s))
                labels=root/'labels.csv'
                header='sampleId,label,annotatorId,labelVersion,actionDefinitionVersion\n'
                labels.write_text(header+f'synthetic,meets_requirement,synthetic_labeler,hand-research-v1,{s["actionDefinitionVersion"]}\n')
                self.assertEqual(load_dataset(root,labels,action)[2],['synthetic_group'])
                labels.write_text(labels.read_text().replace('hand-research-v1','research-v1'))
                with self.assertRaisesRegex(ValueError,'label definition'): load_dataset(root,labels,action)
    def test_all_golden(self):
        for a in ('turnPalm','sidePinch','wristExtension','wristSideBend'):
            with self.subTest(action=a):
                s=sample(a)
                for actual,expected in zip(features_from_sample(s),s['features']):
                    self.assertAlmostEqual(actual,expected,places=5)
    def test_quality_and_contract_fail_closed(self):
        for mutation in ('shape','confidence','nan','gap','source','order','version','segment','side'):
            with self.subTest(case=mutation):
                s=sample('turnPalm')
                if mutation=='shape': s['frames'][0]['landmarks'].pop()
                if mutation=='confidence': s['frames'][0]['confidence']=[1]*21
                if mutation=='nan': s['frames'][0]['landmarks'][0][0]=float('nan')
                if mutation=='gap': s['frames'][1]['timestampMs']=800
                if mutation=='source': s['landmarkSource']='rtmpose'
                if mutation=='order': s['orderedFeatureNames']=list(reversed(s['featureNames']))
                if mutation=='version': s['actionDefinitionVersion']='unsupported'
                if mutation=='segment': s['segment']['completedReps']=0
                if mutation=='side': s['movementSide']='left'
                with self.assertRaises(ValueError): features_from_sample(s)
