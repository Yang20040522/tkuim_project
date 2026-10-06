"""Subject holdout plus grouped development validation; strict linkage guards."""
from collections import Counter
import numpy as np
from sklearn.model_selection import GroupShuffleSplit, GroupKFold
from .features import LABELS


class DataInsufficient(ValueError):
    pass


def sufficient(rows):
    for label in LABELS:
        selected = [r for r in rows if r["label"]==label]
        if len(selected)<10 or len({r["subjectId"] for r in selected})<5:
            raise DataInsufficient("DATA_INSUFFICIENT: engineering minimum 10 attempts / 5 subjects per class, NOT clinical validity")
    if len({r["subjectId"] for r in rows})<10:
        raise DataInsufficient("DATA_INSUFFICIENT: cannot reserve final subject holdout and grouped development folds")


def guard(rows, partitions):
    if sorted(i for ids in partitions.values() for i in ids)!=list(range(len(rows))):
        raise ValueError("split_missing_or_duplicate_row")
    locations = {}
    by_id = {r["sampleId"]:i for i,r in enumerate(rows)}
    if len(by_id)!=len(rows):
        raise ValueError("duplicate_sample_id")
    for name, indices in partitions.items():
        for i in indices:
            r = rows[i]
            for key in ("subjectId","sessionId","attemptId","contentFingerprint"):
                value = (key,r[key])
                if value in locations and locations[value]!=name:
                    raise ValueError(key+"_leakage")
                locations[value] = name
            for key in ("resampleOfSampleId","augmentationOfSampleId"):
                parent = r.get(key)
                if parent and parent in by_id and by_id[parent] not in indices:
                    raise ValueError(key+"_leakage")


def build(rows, seed=42):
    sufficient(rows)
    y = np.array([LABELS.index(r["label"]) for r in rows])
    groups = np.array([r["subjectId"] for r in rows])
    for offset in range(20):
        development,test = next(GroupShuffleSplit(n_splits=1,test_size=.2,random_state=seed+offset).split(y,y,groups))
        train_local,val_local = next(GroupShuffleSplit(n_splits=1,test_size=.25,random_state=seed+offset).split(y[development],y[development],groups[development]))
        train,val = development[train_local],development[val_local]
        parts = {"train":sorted(train.tolist()),"validation":sorted(val.tolist()),"test":sorted(test.tolist())}
        if all(set(y[indices])=={0,1,2} and len(set(groups[indices]))>=2 for indices in parts.values()):
            guard(rows,parts)
            # All outer CV training folds must retain every class; no hidden sample split fallback.
            folds = list(GroupKFold(n_splits=3).split(y[train],y[train],groups[train]))
            if any(set(y[train[a]])!={0,1,2} or set(y[train[b]])!={0,1,2} for a,b in folds):
                continue
            manifest = {"splitVersion":"subject-holdout-v1","randomSeed":seed,"selectedSplitSeed":seed+offset,
                        "groupStrategy":"subject; 60/20/20 nominal, 3-fold GroupKFold on train only",
                        "finalHoldoutPolicy":"winner only, one evaluation; debug rerun is NOT a pristine new study"}
            for name,ids in parts.items():
                manifest[name+"SubjectIds"] = sorted(set(groups[ids]))
                manifest[name+"SampleIds"] = [rows[i]["sampleId"] for i in ids]
                manifest[name+"Counts"] = dict(Counter(rows[i]["label"] for i in ids))
            return parts,manifest
    raise DataInsufficient("DATA_INSUFFICIENT: grouped class coverage / holdout unavailable (20 bounded seeds)")
