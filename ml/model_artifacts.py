"""ONNX parity + deployment-unapproved artifact contract. No patient data logs."""
import hashlib
import json
import platform
from pathlib import Path

PARITY_ABSOLUTE_TOLERANCE = 1e-5
PREPROCESSING = "rtmpose17-normalized-2d-v1;features-identity;float32"


def validate_input(values, dimensions=5):
    import numpy as np
    with np.errstate(over="ignore", invalid="ignore"):
        array = np.asarray(values, dtype=np.float32)
    if array.ndim != 2 or array.shape[1] != dimensions or not array.shape[0] or not np.isfinite(array).all():
        raise ValueError("invalid finite float32 tensor")
    return array


def verify_parity(model, model_bytes, values):
    import numpy as np
    import onnxruntime as ort
    x = validate_input(values, model.n_features_in_)
    session = ort.InferenceSession(model_bytes, providers=["CPUExecutionProvider"])
    input_info = session.get_inputs()[0]
    if input_info.type != "tensor(float)" or input_info.shape != [None, model.n_features_in_]:
        raise ValueError("ONNX input contract mismatch")
    outputs = session.run(None, {input_info.name: x})
    expected = model.predict_proba(x)
    if len(outputs) != 2 or outputs[1].shape != expected.shape or not np.isfinite(outputs[1]).all():
        raise ValueError("ONNX output shape/value mismatch")
    if not np.array_equal(outputs[0], model.predict(x)):
        raise ValueError("ONNX label order/prediction mismatch")
    error = float(np.max(np.abs(outputs[1] - expected)))
    if error > PARITY_ABSOLUTE_TOLERANCE:
        raise ValueError("ONNX probabilities exceed parity tolerance")
    if not np.array_equal(model.classes_[np.argmax(outputs[1], axis=1)], outputs[0]):
        raise ValueError("ONNX class/probability order mismatch")
    return session, {"status": "PASS", "absoluteTolerance": PARITY_ABSOLUTE_TOLERANCE, "maxAbsoluteError": error, "rows": len(x)}


def export_verified(model, values, definition, metrics, output):
    import sklearn
    import skl2onnx
    import onnxruntime
    from skl2onnx import convert_sklearn
    from skl2onnx.common.data_types import FloatTensorType
    onnx = convert_sklearn(model, name=f"{definition.action_id}_{definition.version}",
        initial_types=[("input", FloatTensorType([None, len(definition.feature_names)]))],
        options={id(model): {"zipmap": False}}, target_opset=15)
    data = onnx.SerializeToString()
    session, parity = verify_parity(model, data, values)
    model_hash = hashlib.sha256(data).hexdigest()
    metrics['modelVersion'] = f"{definition.action_id}_rf_{definition.version}_{model_hash[:12]}"
    metrics["onnxParity"] = parity
    manifest = {k: metrics[k] for k in ("modelVersion", "actionId", "schemaVersion", "actionDefinitionVersion", "labelVersion", "featureNames", "classes", "dataOrigin")}
    manifest.update({"manifestVersion": 1, "inputName": session.get_inputs()[0].name,
        "labelOutputName": session.get_outputs()[0].name, "probabilityOutputName": session.get_outputs()[1].name,
        "inputDimension": len(definition.feature_names), "inputShape": [None, len(definition.feature_names)],
        "inputDtype": "float32", "preprocessing": PREPROCESSING,
        "modelSha256": model_hash, "validationStatus": "parity_verified",
        "deploymentApproved": False, "onnxParity": parity,
        "confidenceThreshold": None, "confidenceThresholdValidated": False,
        "runtimeVersions": {"python": platform.python_version(), "sklearn": sklearn.__version__,
            "skl2onnx": skl2onnx.__version__, "onnxruntime": onnxruntime.__version__}})
    output = Path(output)
    if output.exists() and any(output.iterdir()):
        raise ValueError("artifact output must be empty; do not overwrite model versions")
    output.mkdir(parents=True, exist_ok=True)
    (output / "model.onnx").write_bytes(data)
    for name, value in (("metrics.json", metrics), ("model_manifest.json", manifest)):
        (output / name).write_text(json.dumps(value, ensure_ascii=False, indent=2, allow_nan=False), encoding="utf-8")
    # No joblib deserialization needed for phone deployment.
