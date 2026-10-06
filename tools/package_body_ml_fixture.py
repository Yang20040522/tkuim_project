"""Derive an isolated, synthetic engineering bundle. Never train or approve.

Usage: python tools/package_body_ml_fixture.py <R4 artifact dir> <ignored destination>
The destination MUST be under .dart_tool; normal app assets are never modified.
"""
import hashlib
import json
from pathlib import Path
import shutil
import sys


def digest(data):
    return hashlib.sha256(data).hexdigest()


def package(source, destination):
    source, destination = Path(source).resolve(), Path(destination).resolve()
    root = Path(__file__).resolve().parents[1]
    if not destination.is_relative_to(root / '.dart_tool'):
        raise ValueError('Engineering bundle destination must be under .dart_tool')
    artifact = json.loads((source / 'artifact_manifest.json').read_text('utf-8'))
    if artifact['origin'] != 'SYNTHETIC_ENGINEERING_ONLY' or artifact['deploymentApproved']:
        raise ValueError('Only explicitly synthetic unapproved fixtures accepted')
    names = ['model.onnx', 'feature_schema.json', 'label_mapping.json', 'parity_vectors.json']
    for name in names:
        if digest((source / name).read_bytes()) != artifact['hashes'][name]:
            raise ValueError(f'R4 source integrity mismatch: {name}')
    destination.mkdir(parents=True, exist_ok=True)
    for name in names:
        shutil.copyfile(source / name, destination / name)
    hashes = {name: digest((destination / name).read_bytes()) for name in names[:3]}
    artifact_hash = digest('\n'.join(f'{name}:{hashes[name]}' for name in names[:3]).encode())
    manifest = {key: artifact[key] for key in ['actionId', 'schemaVersion', 'modality',
        'actionDefinitionVersion', 'extractorVersion', 'featureSchemaVersion',
        'modelInputVersion', 'labelMappingVersion', 'poseModelVersion', 'featureNames']}
    manifest.update(manifestVersion=1, modelId='r4-synthetic-rf', modelVersion='r5-engineering-fixture-v1',
        modelStatus='EXPERIMENTAL', dataOrigin='SYNTHETIC', deploymentApproved=False,
        sourceDomain='tv_pi', featureOrder=manifest['featureNames'],
        inputDimension=5, inputShape=[1, 5], inputDtype='float32', inputName='features',
        labelOutputName='label', probabilityOutputName='probabilities', labelEncoding='int64',
        classOrder=['meets_requirement', 'insufficient_range', 'trunk_compensation'],
        modelHash=hashes['model.onnx'], artifactHash=artifact_hash,
        abstentionThreshold=None, calibrationValidated=False,
        engineeringNotice='SYNTHETIC MODEL / ENGINEERING ONLY / NOT FOR CLINICAL USE',
        r4SourceCommit=artifact['gitCommit'])
    content = json.dumps(manifest, ensure_ascii=False, sort_keys=True, separators=(',', ':')).encode()
    (destination / 'manifest.json').write_bytes(content)
    hashes['manifest.json'] = digest(content)
    (destination / 'checksums.json').write_text(json.dumps(hashes, sort_keys=True), encoding='utf-8')
    print('ENGINEERING ONLY bundle packaged; production assets/approval unchanged')


if __name__ == '__main__':
    package(*sys.argv[1:])
