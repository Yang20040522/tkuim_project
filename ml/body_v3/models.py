"""Finite CPU baselines, group-aware SVM calibration; no patient-facing decisions."""
import numpy as np
from sklearn.calibration import CalibratedClassifierCV
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import GroupKFold
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.svm import SVC

CANDIDATES = (
    ("rf-small", "RandomForest", {"n_estimators":64,"max_depth":4,"min_samples_leaf":2,"min_samples_split":2,"max_features":"sqrt","class_weight":"balanced"}),
    ("rf-deeper", "RandomForest", {"n_estimators":128,"max_depth":8,"min_samples_leaf":1,"min_samples_split":4,"max_features":1.,"class_weight":"balanced"}),
    ("xgb-small", "XGBoost", {"n_estimators":40,"max_depth":2,"learning_rate":.1,"subsample":.8,"colsample_bytree":.8}),
    ("xgb-deeper", "XGBoost", {"n_estimators":60,"max_depth":3,"learning_rate":.05,"subsample":1.,"colsample_bytree":1.}),
    ("svm-linear-1", "SVM", {"kernel":"linear","C":1.,"gamma":"scale"}),
    ("svm-linear-4", "SVM", {"kernel":"linear","C":4.,"gamma":"scale"}),
    ("svm-rbf-1", "SVM", {"kernel":"rbf","C":1.,"gamma":"scale"}),
    ("svm-rbf-4", "SVM", {"kernel":"rbf","C":4.,"gamma":.1}),
)


def make(family,params,seed,y,groups):
    if family=="RandomForest":
        return RandomForestClassifier(**params,random_state=seed,n_jobs=1)
    if family=="XGBoost":
        from xgboost import XGBClassifier
        return XGBClassifier(**params,random_state=seed,n_jobs=1,objective="multi:softprob",num_class=3,eval_metric="mlogloss")
    if family!="SVM":
        raise ValueError("unsupported model family")
    folds = list(GroupKFold(n_splits=2).split(y,y,groups))
    if any(set(y[a])!={0,1,2} or set(y[b])!={0,1,2} for a,b in folds):
        raise ValueError("DATA_INSUFFICIENT: SVM grouped calibration class coverage")
    # Scale is fitted WITHIN each calibration fold, not before calibration.
    estimator = Pipeline([("scaler",StandardScaler()),("svc",SVC(**params,probability=False,class_weight="balanced",random_state=seed))])
    return CalibratedClassifierCV(estimator,method="sigmoid",cv=folds,ensemble=True,n_jobs=1)


def convert(model,family,dimension):
    if family=="XGBoost":
        from onnxmltools import convert_xgboost
        from onnxmltools.convert.common.data_types import FloatTensorType
        return convert_xgboost(model,initial_types=[("features",FloatTensorType([None,dimension]))],target_opset=15)
    from skl2onnx import convert_sklearn
    from skl2onnx.common.data_types import FloatTensorType
    return convert_sklearn(model,initial_types=[("features",FloatTensorType([None,dimension]))],
                           target_opset=15,options={id(model):{"zipmap":False}})


def checked_input(values,dimension):
    x = np.asarray(values,dtype=np.float32)
    if x.ndim!=2 or x.shape[1]!=dimension or not np.isfinite(x).all():
        raise ValueError("missing/invalid features are rejected, NOT imputed")
    return x
