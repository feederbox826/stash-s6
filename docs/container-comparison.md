# A (biased) comparison of stash containers

## Images
| Name | DockerHub | GitHub | Size |
|---|---|---|---|
| stashapp/stash (official) | [`stashapp/stash`](https://hub.docker.com/r/stashapp/stash) | https://github.com/stashapp/stash | ![Docker Image Size](https://img.shields.io/docker/image-size/stashapp/stash?style=flat-square&label=%20) |
| hotio/stash | N/A | [`ghcr.io/hotio/stash`](https://github.com/hotio/stash) | ? |
| nerethos/stash | [`nerethos/stash`](https://hub.docker.com/r/nerethos/stash) | [`ghcr.io/nerethos/stash`](https://github.com/nerethos/docker-stash) | ![Docker Image Size](https://img.shields.io/docker/image-size/nerethos/stash?style=flat-square&label=%20) |
| nerethos/stash:lite | [`nerethos/stash:lite`](https://hub.docker.com/r/nerethos/stash/tags?name=lite) | [`ghcr.io/nerethos/stash`](https://github.com/nerethos/docker-stash) | ![Docker Image Size](https://img.shields.io/docker/image-size/nerethos/stash/lite?style=flat-square&label=%20) |
| feederbox826/stash-s6 | [`feederbox826/stash-s6`](https://hub.docker.com/r/feederbox826/stash-s6) | [`ghcr.io/feederbox826/stash-s6`](https://github.com/feederbox826/stash-s6) | ![Docker Image Size (tag)](https://img.shields.io/docker/image-size/feederbox826/stash-s6/hwaccel?style=flat-square&label=%20) |
| feederbox826/stash-s6:hwaccel | [`feederbox826/stash-s6:hwaccel`](https://hub.docker.com/r/feederbox826/stash-s6/tags?name=hwaccel) | [`ghcr.io/feederbox826/stash-s6:hwaccel`](https://github.com/feederbox826/stash-s6) | ![Docker Image Size (tag)](https://img.shields.io/docker/image-size/feederbox826/stash-s6/hwaccel?style=flat-square&label=%20) |
| feederbox826/stash-s6:alpine | [`feederbox826/stash-s6:alpine`](https://hub.docker.com/r/feederbox826/stash-s6/tags?name=alpine) | [`ghcr.io/feederbox826/stash-s6:alpine`](https://github.com/feederbox826/stash-s6) | ![Docker Image Size (tag)](https://img.shields.io/docker/image-size/feederbox826/stash-s6/alpine?style=flat-square&label=%20) |
| stash-cuda (manual) | | https://github.com/stashapp/stash/tree/develop/docker/build/x86_64 | ![Docker Image Size (tag)](https://img.shields.io/docker/image-size/nvidia/cuda/12.8.0-base-ubuntu24.04?arch=amd64&style=flat-square&label=%20)+ |

## Feature Breakdown

| Name | hardware acceleration | ARM support| python dependency installer |
|---|---|---|---|
| baremetal | ✅ + VideoToolbox | ✅ | system |
| stashapp/stash (official) | ✖️ | ✅ | ✖️ |
| hotio/stash | ✅ | arm64 | ✖️ |
| nerethos/stash | ✅ | v7,arm64 | ✅ venv |
| nerethos/stash:lite | ✖️ | ✅ | ✅ venv |
| feederbox826/stash-s6:hwaccel | ✅ | ✅ | ✅ uv |
| feederbox826/stash-s6:alpine | ✖️ | ✅ | ✅ uv |
| stash-cuda | NVENC | ✖️ | ✖️ |

### Convergence
  - Hardware Acceleration ✅
    - [`jellyfin-ffmpeg`](https://github.com/jellyfin/jellyfin-ffmpeg)
    - NVENC (NVIDIA), QSV (Intel 8000+), VAAPI, V4L2 (Raspberry Pi) and AMF (AMD)
    - no VideoToolBox (Mac M*) support
  - ARM support
    - Unless otherwise specified, armv6, armv7, armv8 are all supported

## Packaging

| Host | Name | Upstream Image | Documentation/Support |
|---|---|---|---|
| TrueNAS Scale | stash | stashapp/stash | https://truecharts.org/charts/stable/stash/ |
| Unraid | CorneliousJD stash | stashapp/stash | https://forums.unraid.net/topic/90861-support-stash-corneliousjd-repo/ |
| Unraid | hotio stash | hotio/stash | https://github.com/hotio/unraid-templates/blob/master/hotio/stash.xml |
| Unraid | feederbox826 stash | feederbox826 | https://github.com/feederbox826/unraid-templates |

## Other
`binarygeek119/stash-cuda`
[DockerHub](https://hub.docker.com/r/binarygeek119/stash-cuda) | [GitHub](https://github.com/binarygeek119/stash-cuda)
- Excluded since it's last update was over 1y ago (2023-03-30) and there is no CI to keep it updated

`treefiddy/stash-cuda-build` [DockerHub](https://hub.docker.com/r/treefiddy/stash-cuda-build)
- Excluded since no source available