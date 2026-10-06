"""Separate-process ONNX CPU benchmark; memory measures are process approximations."""
import ctypes
import json
import platform
import time
from pathlib import Path
import numpy as np
import onnxruntime as ort


def memory():
    if platform.system()=="Windows":
        from ctypes import wintypes
        class Counters(ctypes.Structure):
            _fields_=[("cb",wintypes.DWORD),("PageFaultCount",wintypes.DWORD)]+[(key,ctypes.c_size_t) for key in
                     ("PeakWorkingSetSize","WorkingSetSize","QuotaPeakPagedPoolUsage","QuotaPagedPoolUsage",
                      "QuotaPeakNonPagedPoolUsage","QuotaNonPagedPoolUsage","PagefileUsage","PeakPagefileUsage")]
        counters=Counters();counters.cb=ctypes.sizeof(counters)
        kernel=ctypes.WinDLL("kernel32",use_last_error=True)
        kernel.GetCurrentProcess.restype=wintypes.HANDLE
        psapi=ctypes.WinDLL("psapi",use_last_error=True)
        psapi.GetProcessMemoryInfo.argtypes=[wintypes.HANDLE,ctypes.POINTER(Counters),wintypes.DWORD]
        if not psapi.GetProcessMemoryInfo(kernel.GetCurrentProcess(),ctypes.byref(counters),counters.cb):
            raise OSError("process memory measurement failed")
        return {"workingSetBytes":counters.WorkingSetSize,"peakWorkingSetBytes":counters.PeakWorkingSetSize}
    import resource
    peak=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*(1 if platform.system()=="Darwin" else 1024)
    return {"peakWorkingSetBytes":peak}


def measure(path):
    before=memory()
    config=ort.SessionOptions();config.intra_op_num_threads=1;config.inter_op_num_threads=1
    start=time.perf_counter()
    session=ort.InferenceSession(str(path),sess_options=config,providers=["CPUExecutionProvider"])
    load=(time.perf_counter()-start)*1000
    dim=session.get_inputs()[0].shape[1]
    # Benchmark only, no performance/quality labels are assigned to this finite vector.
    values=np.array([[.3,90,90,10,1]+([30,2,.5] if dim==8 else [])],dtype=np.float32)
    for _ in range(10): session.run(None,{session.get_inputs()[0].name:values})
    timings=[]
    for _ in range(500):
        start=time.perf_counter_ns();session.run(None,{session.get_inputs()[0].name:values});timings.append((time.perf_counter_ns()-start)/1e6)
    after=memory()
    return {"status":"PASS","provider":"CPUExecutionProvider","platform":platform.platform(),"runs":500,"warmup":10,
            "loadMs":load,"p50Ms":float(np.percentile(timings,50)),"p95Ms":float(np.percentile(timings,95)),
            "fileBytes":Path(path).stat().st_size,"before":before,"after":after,
            "memoryInterpretation":"separate-process working set includes Python/NumPy/ORT; not exact model allocator memory",
            "deviceBenchmark":"NOT RUN"}
