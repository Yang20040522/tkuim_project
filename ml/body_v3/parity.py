"""A training prerequisite: actual Dart output against independent Python math."""
import json
from pathlib import Path
from . import features as f
from .dataset import digest


def check(dart_path, fixture_path):
    fixture = json.loads(Path(fixture_path).read_text(encoding="utf-8"))
    dart = json.loads(Path(dart_path).read_text(encoding="utf-8"))
    if dart.get("fixture")!=fixture or dart.get("extractorVersion")!=f.EXTRACTOR or dart.get("featureNames")!=list(f.NAMES) or dart.get("extendedNames")!=list(f.NAMES+f.EXTENDED):
        raise ValueError("Dart/Python fixture/version/order mismatch")
    if fixture["units"]!=list(f.UNITS) or fixture["extendedVersion"]!=f.EXTENDED_VERSION:
        raise ValueError("units/extension mismatch")
    max_error = 0.
    for case in fixture["cases"]:
        actual = dart["results"][case["name"]]
        baseline = f.extract(f.fixture_frames(fixture,case),"left")
        extended = f.extract(f.fixture_frames(fixture,case),"left",True)
        if actual["status"]!=baseline["status"] or abs(actual["validFrameRatio"]-baseline["validFrameRatio"])>f.TOLERANCE:
            raise ValueError("Dart/Python availability mismatch")
        for expected,values in ((baseline["values"],actual["values"]),(extended["values"],actual["extendedValues"])):
            if len(expected)!=len(values):
                raise ValueError("dimension mismatch")
            for a,b in zip(expected,values):
                if a is None or b is None:
                    if a!=b:
                        raise ValueError("missing semantics mismatch")
                elif not f.finite(b) or abs(a-b)>f.TOLERANCE:
                    raise ValueError("Dart/Python numeric mismatch")
                else:
                    max_error = max(max_error,abs(a-b))
    return {"status":"PASS","cases":len(fixture["cases"]),"maxAbsoluteError":max_error,
            "tolerance":f.TOLERANCE,"fixtureSha256":digest(fixture),"dartOutputSha256":digest(dart)}
