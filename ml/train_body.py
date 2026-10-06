"""Round 4 body-v3 CLI. Existing train.py (body v1 / hand v2) remains untouched."""
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path
from body_v3 import dataset, parity, synthetic, training
from body_v3.split import DataInsufficient


def main():
    cli=argparse.ArgumentParser(description=__doc__)
    sub=cli.add_subparsers(dest="command",required=True)
    synth=sub.add_parser("synthetic");synth.add_argument("--output",type=Path,required=True)
    synth.add_argument("--fixture",type=Path,default=Path("test/fixtures/body_v3_parity.json"))
    builder=sub.add_parser("build");builder.add_argument("--export",dest="export",type=Path,required=True)
    builder.add_argument("--datasets",type=Path,required=True);builder.add_argument("--engineering",action="store_true")
    builder.add_argument("--attestation",type=Path)
    trainer=sub.add_parser("train");trainer.add_argument("--dataset",type=Path,required=True)
    trainer.add_argument("--output",type=Path,required=True);trainer.add_argument("--run-id",required=True)
    trainer.add_argument("--dart-parity",type=Path,required=True)
    trainer.add_argument("--fixture",type=Path,default=Path("test/fixtures/body_v3_parity.json"));trainer.add_argument("--seed",type=int,default=42)
    trainer.add_argument("--debug-replay",action="store_true",help="Explicitly mark repeated real final evaluation NON-PRISTINE")
    bench=sub.add_parser("benchmark");bench.add_argument("--model",type=Path,required=True)
    args=cli.parse_args()
    try:
        if args.command=="synthetic":
            synthetic.write(args.output,args.fixture)
            print("PASS: SYNTHETIC / ENGINEERING_ONLY export created")
        elif args.command=="build":
            sha=subprocess.check_output(["git","rev-parse","HEAD"],text=True).strip()
            result=dataset.build(args.export,engineering=args.engineering,git_commit=sha,
                                 professional_attestation=json.loads(args.attestation.read_text()) if args.attestation else None)
            path=dataset.save(result,args.datasets)
            print(json.dumps({"status":"PASS","dataset":str(path),"origin":result["origin"],"counts":result["counts"]}))
        elif args.command=="train":
            if not re.fullmatch(r"[A-Za-z0-9_-]{1,80}",args.run_id):
                raise ValueError("invalid_run_id")
            receipt=parity.check(args.dart_parity,args.fixture)
            result=json.loads(args.dataset.read_text(encoding="utf-8"))
            path=training.train(result,args.output,args.run_id,receipt,args.seed,args.debug_replay)
            print(json.dumps({"status":"PASS","artifact":str(path),"modelStatus":"EXPERIMENTAL","origin":result["origin"],
                              "REAL_DATA_TRAINING":"DATA_INSUFFICIENT" if args.dataset and result["origin"]=="SYNTHETIC_ENGINEERING_ONLY" else "EXECUTED_NOT_CLINICALLY_VALIDATED"}))
        else:
            from body_v3.benchmark import measure
            print(json.dumps(measure(args.model)))
    except DataInsufficient:
        print("DATA_INSUFFICIENT: no model created; engineering minimum is NOT a clinical sufficiency threshold",file=sys.stderr)
        return 2
    except Exception as error:
        # Never expose export data, exception messages, identifiers or credentials.
        print("FAIL: "+type(error).__name__+"; consult contract/tests; artifacts never overwritten",file=sys.stderr)
        return 1
    return 0


if __name__=="__main__":
    raise SystemExit(main())
