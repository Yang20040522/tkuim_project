import copy
import json
import math
import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from feature_schema import ACTION_REGISTRY, features_from_sample

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
