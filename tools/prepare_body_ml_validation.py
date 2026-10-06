"""Prepare ignored compile defines from committed, synthetic-only test fixture.
Never changes pubspec assets, signing, model approvals or production configuration.
"""
import base64
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
fixture = (root / 'test/fixtures/body_ml_engineering_bundle.json').read_bytes()
data = json.loads(fixture)
manifest = json.loads(base64.b64decode(data['manifest.json']))
assert manifest['dataOrigin'] == 'SYNTHETIC'
assert manifest['modelStatus'] == 'EXPERIMENTAL'
assert manifest['deploymentApproved'] is False
destination = root / '.dart_tool/body-r5'
destination.mkdir(parents=True, exist_ok=True)
(destination / 'validation-defines.json').write_text(json.dumps({
    'BODY_ML_ENGINEERING_VALIDATION': 'true',
    'BODY_ML_ENGINEERING_BUNDLE': base64.b64encode(fixture).decode(),
}), encoding='utf-8')
print('Prepared isolated validation defines; normal builds remain OFF')
