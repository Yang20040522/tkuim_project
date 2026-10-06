"""Actual Python ORT check against R4 native predictions; not clinical metrics."""
import base64
import hashlib
import json
from pathlib import Path
import numpy as np
import onnxruntime as ort

root = Path(__file__).resolve().parents[1]
fixture = json.loads((root / 'test/fixtures/body_ml_engineering_bundle.json').read_text('utf-8'))
for name, expected in fixture['checksums'].items():
    if hashlib.sha256(base64.b64decode(fixture[name])).hexdigest() != expected:
        raise ValueError('Synthetic fixture integrity mismatch')
manifest = json.loads(base64.b64decode(fixture['manifest.json']))
if manifest['modelStatus'] != 'EXPERIMENTAL' or manifest['dataOrigin'] != 'SYNTHETIC' or manifest['deploymentApproved']:
    raise ValueError('Fixture lifecycle mismatch')
session = ort.InferenceSession(base64.b64decode(fixture['model.onnx']), providers=['CPUExecutionProvider'])
vectors = fixture['parity']
labels, probabilities = session.run(['label', 'probabilities'], {'features': np.asarray(vectors['input'], dtype=np.float32)})
assert len(labels) == 56
assert np.array_equal(labels, vectors['nativeLabels'])
error = float(np.max(np.abs(probabilities - np.asarray(vectors['nativeProbabilities']))))
assert np.isfinite(probabilities).all() and error <= 1e-5
print(f'SYNTHETIC ENGINEERING ONLY Python ORT/native parity PASS rows=56 maxError={error}')
