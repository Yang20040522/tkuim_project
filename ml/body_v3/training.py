"""Software-only research model selection and immutable artifact packaging."""
import csv
import importlib.metadata
import json
import platform
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import joblib
import numpy as np
import onnx
import onnxruntime as ort
from sklearn.metrics import (balanced_accuracy_score, classification_report, confusion_matrix,
                             f1_score, log_loss)
from sklearn.model_selection import GroupKFold

from . import features as f, models, split
from .dataset import canonical, digest, instant


def metrics(y,pred,prob,rows):
    report = classification_report(y,pred,labels=[0,1,2],target_names=f.LABELS,output_dict=True,zero_division=0)
    def calculate(indices):
        if not indices or len({rows[i]["subjectId"] for i in indices})<2 or set(y[indices])!={0,1,2}:
            return {"status":"DATA_INSUFFICIENT"}
        return {"status":"PASS","macroF1":float(f1_score(y[indices],pred[indices],labels=[0,1,2],average="macro",zero_division=0)),
                "weightedF1":float(f1_score(y[indices],pred[indices],labels=[0,1,2],average="weighted",zero_division=0)),
                "balancedAccuracy":float(balanced_accuracy_score(y[indices],pred[indices])),
                "samples":len(indices),"subjects":len({rows[i]["subjectId"] for i in indices})}
    onehot = np.eye(3)[y]
    calibration = {"multiclassBrier":float(np.mean(np.sum((prob-onehot)**2,axis=1))),
                   "logLoss":float(log_loss(y,prob,labels=[0,1,2])),
                   "interpretation":"diagnostic only, NOT proven calibrated clinical confidence"}
    errors = []
    for i,r in enumerate(rows):
        if y[i]!=pred[i]:
            errors.append({"sampleId":r["sampleId"],"subjectGroup":r["subjectId"],"source":r["source"],
                           "trueLabel":f.LABELS[y[i]],"predictedLabel":f.LABELS[pred[i]],
                           "falsePositiveFor":f.LABELS[pred[i]],"falseNegativeFor":f.LABELS[y[i]],
                           "trackingQuality":r["trackingQuality"],"featuresStatus":r["featuresStatus"],"duration":r["features"][4]})
    return {"overall":calculate(list(range(len(rows)))),"phone":calculate([i for i,r in enumerate(rows) if r["source"]=="phone"]),
            "tv_pi":calculate([i for i,r in enumerate(rows) if r["source"]=="tv_pi"]),"classificationReport":report,
            "confusionMatrix":confusion_matrix(y,pred,labels=[0,1,2]).tolist(),"calibration":calibration,
            "bootstrapCI":{"status":"DATA_INSUFFICIENT","reason":"pilot gate requires >=20 held-out subjects; no frame-level resampling"},
            "rejectPolicy":"invalid features rejected before inference; no probability threshold calibrated yet",
            "coverage":1.,"rejectionRate":0.,"errors":errors}


def onnx_check(model,graph,vectors,dimension):
    onnx.checker.check_model(graph)
    options = ort.SessionOptions()
    options.intra_op_num_threads = 1
    options.inter_op_num_threads = 1
    start=time.perf_counter()
    session=ort.InferenceSession(graph.SerializeToString(),sess_options=options,providers=["CPUExecutionProvider"])
    load_ms=(time.perf_counter()-start)*1000
    values=models.checked_input(vectors,dimension)
    actual=session.run(None,{session.get_inputs()[0].name:values})
    pred,prob=model.predict(values),model.predict_proba(values)
    error=float(np.max(np.abs(np.asarray(actual[1])-prob)))
    if not np.array_equal(pred,np.asarray(actual[0]).ravel()) or error>1e-5:
        raise ValueError("ONNX_PARITY_FAIL")
    for bad in ([None]*dimension,[float("nan")]*dimension,[float("inf")]*dimension):
        try:
            models.checked_input([bad],dimension)
        except ValueError:
            continue
        raise ValueError("missing guard failed")
    timings=[]
    one=values[:1]
    for _ in range(10):
        session.run(None,{session.get_inputs()[0].name:one})
    for _ in range(200):
        start=time.perf_counter_ns();session.run(None,{session.get_inputs()[0].name:one});timings.append((time.perf_counter_ns()-start)/1e6)
    return {"status":"PASS","vectors":len(values),"classOrder":model.classes_.tolist(),"predictedClasses":sorted(set(pred.tolist())),
            "maxProbabilityError":error,"probabilityTolerance":1e-5,"missingHandling":"reject before native AND ONNX inference",
            "inputNames":[i.name for i in session.get_inputs()],"outputNames":[o.name for o in session.get_outputs()],
            "opsets":{o.domain:o.version for o in graph.opset_import},
            "benchmark":{"provider":"CPUExecutionProvider","hardware":platform.machine(),"runs":200,"warmup":10,
                         "loadMs":load_ms,"p50Ms":float(np.percentile(timings,50)),"p95Ms":float(np.percentile(timings,95)),
                         "modelBytes":len(graph.SerializeToString()),"memoryMethod":"separate process peak working set (see CLI benchmark)",
                         "deviceAcceptance":"NOT RUN; software benchmark only"}}


def train(dataset,root,run_id,parity_receipt,seed=42):
    if parity_receipt.get("status")!="PASS":
        raise ValueError("DART_PYTHON_PARITY_REQUIRED")
    if digest({"rows":dataset["rows"],"schema":f.schema(),"labelMapping":list(f.LABELS),"exclusions":dataset["exclusions"],
               "exportSha256":dataset["exportSha256"],"builderVersion":dataset["builderVersion"]})!=dataset["datasetHash"]:
        raise ValueError("dataset_manifest_tampered")
    rows=dataset["rows"]
    if dataset["origin"]!="SYNTHETIC_ENGINEERING_ONLY":
        now=datetime.now(timezone.utc)
        if abs((now-instant(dataset["eligibilityCheckedAt"])).total_seconds())>86400 or any(instant(r["eligibility"]["expiresAt"])<=now for r in rows):
            raise ValueError("fresh_export_required_before_real_training")
    parts,split_manifest=split.build(rows,seed)
    output=Path(root)/f.ACTION/run_id
    # Exclusive reservation means rerun cannot overwrite OR reuse a final test artifact.
    output.mkdir(parents=True,exist_ok=False)
    def write(name,value):
        (output/name).write_bytes(canonical(value))
    write("dataset_manifest.json",dataset)
    (output/"dataset_hash.txt").write_text(dataset["datasetHash"]+"\n",encoding="utf-8")
    write("split_manifest.json",split_manifest)
    write("dart_python_parity.json",parity_receipt)
    write("label_mapping.json",{"version":f.LABEL_VERSION,"classOrder":list(f.LABELS),"unassessable":"excluded"})
    environment={"python":platform.python_version(),"platform":platform.platform(),"packages":{p:importlib.metadata.version(p) for p in
                 ("numpy","scipy","scikit-learn","skl2onnx","onnxmltools","onnx","onnxruntime","xgboost","protobuf","joblib")}}
    write("environment.json",environment)
    config={"seed":seed,"candidates":models.CANDIDATES,"domain":dataset["domain"],
            "origin":dataset["origin"],"modelStatus":"EXPERIMENTAL","deploymentApproved":False,
            "timestamp":datetime.now(timezone.utc).isoformat(),"gitCommit":dataset["gitCommit"],
            "selection":"validation macro-F1, grouped-CV macro-F1, balanced accuracy, worst-class recall, then simpler baseline/family",
            "preprocessing":"SVM scaling inside subject-grouped sigmoid calibration folds; no imputation; no test fitting",
            "engineeringMinimum":"10 attempts and 5 subjects per label; 10 total subjects, NOT scientific sufficiency"}
    write("training_config.json",config)
    log=[]
    def record(message):
        log.append(message)
        (output/"training.log").write_text("\n".join(log)+"\n",encoding="utf-8")
    record("EXPERIMENTAL / "+dataset["origin"]+"; no clinical accuracy claim")
    train_ids,val_ids,test_ids=(np.array(parts[k]) for k in ("train","validation","test"))
    y=np.array([f.LABELS.index(r["label"]) for r in rows])
    groups=np.array([r["subjectId"] for r in rows])
    results=[]
    candidates={}
    try:
        for extended in (False,True):
            feature_set="extended" if extended else "baseline"
            x=models.checked_input([r["extendedFeatures" if extended else "features"] for r in rows],8 if extended else 5)
            for order,(name,family,params) in enumerate(models.CANDIDATES):
                began=time.perf_counter()
                cv_scores=[]
                for a,b in GroupKFold(n_splits=3).split(x[train_ids],y[train_ids],groups[train_ids]):
                    fold=models.make(family,params,seed,y[train_ids[a]],groups[train_ids[a]])
                    fold.fit(x[train_ids[a]],y[train_ids[a]])
                    cv_scores.append(float(f1_score(y[train_ids[b]],fold.predict(x[train_ids[b]]),labels=[0,1,2],average="macro",zero_division=0)))
                model=models.make(family,params,seed,y[train_ids],groups[train_ids])
                model.fit(x[train_ids],y[train_ids])
                pred=model.predict(x[val_ids]);prob=model.predict_proba(x[val_ids])
                summary=metrics(y[val_ids],pred,prob,[rows[i] for i in val_ids])
                # Export-compatibility is considered BEFORE final holdout access.
                try:
                    graph=models.convert(model,family,x.shape[1])
                    vectors=np.vstack([x[train_ids],x[val_ids],np.zeros((1,x.shape[1]),dtype=np.float32),
                                       np.mean(x[train_ids],axis=0,keepdims=True)])
                    parity=onnx_check(model,graph,vectors,x.shape[1])
                    compatible=True
                except (ValueError,RuntimeError,NotImplementedError,AssertionError) as error:
                    compatible=False;parity={"status":"FAIL","exceptionType":type(error).__name__,"reason":"conversion_or_parity_technical_limitation"}
                    graph=None
                native_path=output/(feature_set+"-"+name+".joblib")
                joblib.dump(model,native_path)
                score=summary["overall"]["macroF1"]
                result={"name":name,"family":family,"featureSet":feature_set,"hyperparameters":params,
                        "cvMacroF1":float(np.mean(cv_scores)),"cvFoldScores":cv_scores,"validation":summary,
                        "fitAndCheckSeconds":time.perf_counter()-began,"nativeBytes":native_path.stat().st_size,
                        "onnx":parity,"onnxCompatible":compatible}
                results.append(result)
                candidates[(feature_set,name)]=(model,graph,x,parity)
                record(feature_set+" "+name+" grouped validation complete; ONNX="+str(compatible))
        eligible=[r for r in results if r["onnxCompatible"]]
        if not eligible:
            raise ValueError("NO_ONNX_COMPATIBLE_MODEL")
        def rank(r):
            recalls=[r["validation"]["classificationReport"][label]["recall"] for label in f.LABELS]
            return (r["validation"]["overall"]["macroF1"],r["cvMacroF1"],r["validation"]["overall"]["balancedAccuracy"],min(recalls),
                    r["featureSet"]=="baseline",-next(i for i,c in enumerate(models.CANDIDATES) if c[0]==r["name"]))
        winner=max(eligible,key=rank)
        model,graph,x,parity=candidates[(winner["featureSet"],winner["name"])]
        # This is the ONLY final holdout evaluation, after immutable candidate selection.
        write("selection.json",{"winner":winner["name"],"featureSet":winner["featureSet"],"testUsedForSelection":False})
        record("selection frozen; final subject holdout evaluated once")
        pred=model.predict(x[test_ids]);prob=model.predict_proba(x[test_ids])
        final=metrics(y[test_ids],pred,prob,[rows[i] for i in test_ids])
        final.update(origin=dataset["origin"],modelStatus="EXPERIMENTAL",finalTestEvaluations=1,
                     realFinalTestStatus="NOT RUN" if dataset["origin"]=="SYNTHETIC_ENGINEERING_ONLY" else "PASS")
        write("metrics.json",final)
        write("classification_report.json",final["classificationReport"])
        write("error_analysis.json",final["errors"])
        with (output/"confusion_matrix.csv").open("w",newline="",encoding="utf-8") as stream:
            writer=csv.writer(stream);writer.writerow(["actual/predicted",*f.LABELS])
            writer.writerows([[label,*row] for label,row in zip(f.LABELS,final["confusionMatrix"])])
        write("ablation_results.json",{"origin":dataset["origin"],"comparisons":results,
              "policy":"extended retained only if grouped validation improves; ties prefer baseline; no test-based ablation"})
        write("feature_schema.json",f.schema(winner["featureSet"]=="extended"))
        if hasattr(model,"feature_importances_"):
            write("feature_importance.json",{"values":dict(zip(f.schema(winner["featureSet"]=="extended")["featureNames"],map(float,model.feature_importances_))),
                                           "interpretation":"non-causal model debugging, NOT clinical factors"})
        joblib.dump(model,output/"model.joblib")
        onnx.helper.set_model_props(graph,{k:str(v) for k,v in {**f.schema(winner["featureSet"]=="extended"),"labelMappingVersion":f.LABEL_VERSION,
                                                              "origin":dataset["origin"],"modelStatus":"EXPERIMENTAL","deploymentApproved":False}.items()})
        (output/"model.onnx").write_bytes(graph.SerializeToString())
        write("onnx_parity.json",parity)
        measured=subprocess.run([sys.executable,str(Path(__file__).resolve().parents[1]/"train_body.py"),
                                "benchmark","--model",str(output/"model.onnx")],capture_output=True,text=True,check=True)
        write("benchmark.json",json.loads(measured.stdout))
        (output/"MODEL_CARD.md").write_text("# EXPERIMENTAL\n\n"+dataset["origin"]+"\n\nNot deployed or approved. No clinical validation.\n"
          "2D projected geometry, not clinical 3D ROM. Models do not control rehabilitation counting.\n"
          "Fresh consent/retention/qualification review required before real training.\n"
          "Synthetic performance is engineering-only and cannot estimate patient outcomes.\n",encoding="utf-8")
        record("PASS; engineering artifact complete; no activation")
        write("artifact_manifest.json",{**f.schema(winner["featureSet"]=="extended"),"labelMappingVersion":f.LABEL_VERSION,
              "datasetHash":dataset["datasetHash"],"gitCommit":dataset["gitCommit"],"timestamp":config["timestamp"],"randomSeed":seed,
              "origin":dataset["origin"],"sourceDomains":[dataset["domain"]],"modelStatus":"EXPERIMENTAL","deploymentApproved":False,
              "hashes":{p.name:__import__("hashlib").sha256(p.read_bytes()).hexdigest() for p in sorted(output.iterdir()) if p.is_file()}})
        return output
    except Exception as error:
        write("failure.json",{"status":"FAIL","exceptionType":type(error).__name__,"stage":"training/export"})
        record("FAIL; partial artifact retained; do not reuse run ID")
        raise
