# Standing knee raise pilot dataset plan (NOT a request to collect now)

REAL_DATASET=NONE locally supplied; DATA_INSUFFICIENT. No valid real model exists. Round 3 test-motion/fake account records are excluded; no consent/policy/participant was created in Round 4.

## Governance before any real collection

Qualified physical therapist must approve observable label definitions and safe movement protocol, recruitment/voluntary consent, permitted study/source scope, retention/withdrawal procedures and review qualifications. Appropriate institutional/ethical procedures are still required; this software plan does not supply them. Do not force unsafe compensation/painful motion to balance labels. Independent review; never auto-label from rep count/rules/model output. Participants may decline research while continuing rehabilitation.

## Exploratory engineering plan, not statistical power or clinical validity

- First select ONE source distribution (phone-only OR tv_pi-only), not pooled. Prefer a standardized camera setup suitable for clinician-observable image-plane motion; current Pi demonstration angle is NOT ground truth.
- Suggested planning target: 60 distinct consenting subjects for a first exploratory single-domain pilot; two sessions each, ~6–10 safely performed attempts/session. Clinician reviews may yield fewer eligible labeled attempts.
- Keep labels balanced where clinically safe/observable. Plan at least 15 distinct subjects represented in each observable error class, rather than repeatedly copying one person's attempts. Do not force every participant to exhibit every error. Label insufficient/unassessable captures honestly and request a safe resample.
- Separate clinical label counts from dataset QC exclusions. Track label/class/subject/session/source/side/camera-view and valid coverage/gaps. Keep review disagreement and unassessable rates.
- Pre-reserve subject holdouts, nominal 36 training / 12 development validation / 12 final subjects. Actual stratified group coverage may require more subjects. Holdout participants must never inform parameter tuning/feature selection.
- With 12 final subjects, subject-bootstrap gate (20 held-out subjects) remains DATA_INSUFFICIENT. A later larger plan would require separately qualified statistical advice; do not infer a sufficient cohort from this example.
- Only after first-domain validation, plan a separately collected/held-out second-domain cohort (phone vs tv_pi) under its own consent/quality checks. Report each domain separately. No cross-device generalization claim from this pilot.

## Professional label review

Existing Registry labels: meets_requirement, insufficient_range, trunk_compensation; unassessable retained for review but not classifier training. Before collection, clinicians must document what the particular 2D camera view can reliably observe; terms are not clinical 3D ROM or diagnoses. Keep body-attempt-label-v1 and action/extractor versions frozen; changed definitions require a new explicit contract and dataset/model version.

## Release gates

Fresh authorized approved export; valid current consent/retention; independent qualified review; no DEMO; deterministic feature parity/split/leakage tests; actual domain/class sufficiency; frozen final holdout; ONNX parity; human governance approval. A pilot training run remains EXPERIMENTAL. No automatic activation or modification of rehab plans/counters.

Deletion of main rows does not guarantee removal from old exports, backups or local models; keep governed copy inventory and withdrawal handling. No raw photos/video/name/email collected by this pipeline.
