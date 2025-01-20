# A (biased) comparison of stash containers

## Images
| Name | DockerHub | GitHub | Size |
|---|---|---|---|
| stashapp/stash (official) | [`stashapp/stash`](https://hub.docker.com/r/stashapp/stash) | https://github.com/stashapp/stash | ![Docker Image Size](https://img.shields.io/docker/image-size/stashapp/stash?style=flat-square&label=%20) |
| hotio | [`hotio/stash`](https://hub.docker.com/r/hotio/stash) | [`ghcr.io/hotio/stash`](https://github.com/hotio/stash) | ![Docker Image Size](https://img.shields.io/docker/image-size/hotio/stash?style=flat-square&label=%20) |
| nerethos | [`nerethos/stash-jellyfin-ffmpeg`](https://hub.docker.com/r/nerethos/stash-jellyfin-ffmpeg) | [`ghcr.io/nerethos/stash`](https://github.com/nerethos/docker-stash) | ![Docker Image Size](https://img.shields.io/docker/image-size/nerethos/stash-jellyfin-ffmpeg?style=flat-square&label=%20) |
| feederbox826 | [`feederbox826/stash-s6`](https://hub.docker.com/r/feederbox826/stash-s6) | [`ghcr.io/feederbox826/stash-s6`](https://github.com/feederbox826/stash-s6) | ![Docker Image Size (tag)](https://img.shields.io/docker/image-size/feederbox826/stash-s6/latest?style=flat-square&label=%20) to ![Docker Image Size (tag)](https://img.shields.io/docker/image-size/feederbox826/stash-s6/hwaccel?style=flat-square&label=%20) |
| stash-cuda (manual) | | https://github.com/stashapp/stash/tree/develop/docker/build/x86_64 | ![Docker Image Size (tag)](https://img.shields.io/docker/image-size/nvidia/cuda/12.0.1-base-ubuntu22.04?arch=amd64&style=flat-square&label=%20)+ |

## Feature Breakdown
| Name | hardware acceleration | ARM support | ffmpeg | python version | python dependency installer |
|---|---|---|---|---|---|
| baremetal | CUDA,QSV,VAAPI,V4L2 | v6,v7,arm64 | 6.1[^5] / 7.1[^6] | system | system |
| stashapp/stash (official) | ❌ | v6,v7,arm64 | 6.1.1[^4] | 3.12[^1] | ❌ |
| hotio | ❌ | arm64 | 6.1.2[^4] | 3.12[^1] | ❌ |
| nerethos | CUDA,QSV,VAAPI,V4L2 | v6[^9],v7,arm64 | 6.1.2[^4] / 7-jellyfin[^7] | 3.12[^2] | ✅ venv |
| feederbox826 | CUDA,QSV,VAAPI,V4L2 | v6[^9],v7,arm64 | 6.1.2[^4] / 7-jellyfin[^7] | 3.12[^1] / 3.14[^3] | ✅ uv |
| stash-cuda | CUDA | ❌ | 4.4.2[^8] | ❌ | ❌ | ![Docker Image Size (tag)](https://img.shields.io/docker/image-size/nvidia/cuda/12.0.1-base-ubuntu22.04?arch=amd64&style=flat-square&label=%20) |

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

## Footnotes
[^1]: [python3 @ Alpine 3.21](https://pkgs.alpinelinux.org/packages?name=python3&branch=v3.21)  
[^2]: [python3 @ Ubuntu noble](https://packages.ubuntu.com/noble/python3)  
[^3]: [python:slim-bookworm](https://hub.docker.com/_/python/tags?name=3.14-slim-bookworm)  
[^4]: [ffmpeg @ Alpine 3.21](https://pkgs.alpinelinux.org/packages?name=ffmpeg&branch=v3.21)  
[^5]: [ffbinaries](https://github.com/stashapp/stash/blob/develop/pkg/ffmpeg/downloader.go#L12-L20)  
[^6]: [gyan.dev release](https://github.com/stashapp/stash/blob/develop/pkg/ffmpeg/downloader.go#L21-L22)  
[^7]: [jellyfin-ffmpeg7](https://github.com/jellyfin/jellyfin-ffmpeg)  
[^8]: [ffmpeg @ Ubuntu Jammy (22.04)](https://packages.ubuntu.com/jammy/ffmpeg)  
[^9]: ARMv6 support without hwaccel  
