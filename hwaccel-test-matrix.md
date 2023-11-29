| technology | lscr    | jellyfin | base  |
|------------|---------|----------|-------|
| vvapi g5+  | ✅[^1] | ✅[^1]  |  ✅   |
| vaapi g8+  | ~[^5]   | ~[^5]    | ~[^5] |
| qsv        | ❌       | ✅[^4]  | ✅    |
| cuda       | ❌[^2]   | ✅      | ❌[^3] |
| v4l2       | ?       | ?        | ?     |

# notes
[^1]: works without intel-compute-runtime  
[^2]: no support for `scale-cuda` so NVENC is not loaded  
[^3]: no audio for transcodes  
[^4]: requires intel-compute-runtime  
[^5]: stash defers to QSV, it errors out  

## architecture matrix
amd64: vaapi, qsv, cuda  
armhf: v4l2  
aarch: cuda, v4l2  

## qsv support
- kabylake (7XXX+)

## test platforms
- cuda - RTX 3060 | W10 | R5 3600
- vaapi g5+ - debian bookworm | i5-3570K
- vaapi g8+ / QSV - debian bookworm | i5-1135G7

## misc notes
```
  echo "**** install intel compute-runtime ****" && \
    cd /tmp && \
    wget https://github.com/intel/intel-graphics-compiler/releases/download/igc-1.0.14828.8/intel-igc-core_1.0.14828.8_amd64.deb && \
    wget https://github.com/intel/intel-graphics-compiler/releases/download/igc-1.0.14828.8/intel-igc-opencl_1.0.14828.8_amd64.deb && \
    wget https://github.com/intel/compute-runtime/releases/download/${COMPUTE_RUNTIME_VERSION}/intel-level-zero-gpu-dbgsym_1.3.26918.9_amd64.ddeb && \
    wget https://github.com/intel/compute-runtime/releases/download/${COMPUTE_RUNTIME_VERSION}/intel-level-zero-gpu_1.3.26918.9_amd64.deb &&\
    wget https://github.com/intel/compute-runtime/releases/download/${COMPUTE_RUNTIME_VERSION}/intel-opencl-icd-dbgsym_${COMPUTE_RUNTIME_VERSION}_amd64.ddeb && \
    wget https://github.com/intel/compute-runtime/releases/download/${COMPUTE_RUNTIME_VERSION}/intel-opencl-icd_${COMPUTE_RUNTIME_VERSION}_amd64.deb && \
    wget https://github.com/intel/compute-runtime/releases/download/${COMPUTE_RUNTIME_VERSION}/libigdgmm12_22.3.0_amd64.deb && \
```

