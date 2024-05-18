| technology | lscr    | jellyfin | base  |
|------------|---------|----------|-------|
| vvapi g5+  | ✅[^1] | ✅[^1]  |  ✅   |
| vaapi g8+  | ~[^5]   | ~[^5]    | ~[^5] |
| qsv        | ❌       | ✅[^4]  | ✅[^6]|
| cuda       | ❌[^2]   | ✅      | ✅ |
| v4l2       | ?       | ?        | ?     |

# notes
AMF (AMD) is not supported by stash so it was not tested

[^1]: works without intel-compute-runtime  
[^2]: no support for `scale-cuda` so NVENC is not loaded  
[^4]: requires intel-compute-runtime  
[^5]: stash defers to QSV, it errors out  
[^6]: works with `intel-media-va-driver-non-free` installed  

## architecture matrix
amd64: vaapi, qsv, cuda  
armhf: v4l2  
aarch: cuda, v4l2  

## upstream arch support
| upstream | amd64 | armv6 (armel) | armv7 (armhf) | aarch64 |
|---|---|---|---|---|
| alpine | ✅ | ✅ | ✅ | ✅ |
| jellyfin | ✅ | ❌ | ✅ | ✅ |
| cuda | ✅ | ❌ | ❌ | ✅ |
| qsv | ✅ | ❌ | ❌ | ❌ |

## qsv support
- kabylake (7XXX+)

## test platforms
- cuda - RTX 3060 | W10 | R5 3600
- cuda - GTX 1065 | debian bookwork | R7 2700
- vaapi g5+ - debian bookworm | i5-3570K
- vaapi g8+ / QSV - debian bookworm | i5-1135G7

## misc notes