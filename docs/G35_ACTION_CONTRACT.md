# G3.5 versioned research action contract

## Production and safety

Only `standing_knee_raise`, schema 1, definition `standing-knee-raise-v1` is registered in production. Registration is not professional validation, consent, review authority, or permission to collect. General 3D CUSTOM exercises are not automatically ML-capable. No model is trained in G3.5.

## Shared flow

Action-specific completed-rep collector/extractor → `MlResearchSample` → `MlSampleRepository` → existing account-scoped consent/queue → HMAC upload → `ResearchSampleValidator` → existing payload JSON table → existing binding/grant-gated annotation and independent review → action-scoped manager export → Python action registry/extractor.

- All actions use 17 normalized RTMPose COCO 2D points and confidence per frame, anatomical side, camera view, monotonic timestamps and segment. No raw images or invented world depth.
- Metadata: `actionId`, `schemaVersion`, `actionDefinitionVersion`, exact ordered `featureNames`. Each registered definition supplies its feature extractor, required confidence joints, angle fields/ranges and label vocabulary. Completion/segmentation stays action-specific, not derived from pose presence.
- Old standing schema1 files without `actionDefinitionVersion` resolve to standing-knee-raise-v1. Explicit wrong versions are rejected. Backend preserves the field's absence on canonical legacy upload payloads to retain retry hashes; export makes the resolved version explicit.
- Backend list adds action metadata from payload, without schema changes. Unknown/unsupported detail contracts cannot be newly labeled in Flutter. Backend validates label vocabulary and definition version against the sample; approved old mismatched labels are excluded from export.
- `GET /api/ml-research/management/export?actionId=standing_knee_raise` returns only that registered action/definition. Omitted action defaults to standing for compatibility. Authorization, independent review, active consent, retention and withdrawal gates remain.
- ZIP keeps `samples/*.json`, `labels.csv`; manifest now also gives action, definition and ordered features. Python `--action` selects a registered definition and rejects mixed action/feature/label-definition versions; participant groups remain separate. Missing model is still a safe fallback.

## Adding an action later

1. Obtain approved action/label definitions and implement a completed-rep collector + feature extractor. Do not repurpose the standing model.
2. Register the same ID, schema, version, ordered features and labels in Dart, Java and Python. Java registration also specifies angle bounds, required joints, duration feature and recomputation extractor.
3. Add cross-language golden fixtures and shared storage/sync/review/export tests before enabling any patient entry. ActionDefinition registry constructors are injectable for tests; production contains no fictional second action.
4. Maintain versioned model metadata (action, features, normalization and labels), grouped evaluation and device validation before deploying a real model.

Synthetic contracts under `test/`, `src/test/`, `ml/tests/` prove reuse only; they are not rehabilitation prescriptions or trained models. No migration is required: contracts remain in validated existing research payload JSON, with existing tables/FKs unchanged.
