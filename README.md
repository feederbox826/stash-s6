# stashapp/stash with s6

for [stashapp/stash#4300](https://github.com/stashapp/stash/issues/4300)

## latest/ alpine/ arm
- built on alpine linux, no hardware acceleration support
```
docker pull ghcr.io/feederbox826/stash-s6:alpine
```

## hwaccel
- built on ubuntu, hardware acceration support via multiple ffmpeg builds
- only works on amd64
- standard ubuntu ffmpeg
    ```
    docker pull ghcr.io/feederbox826/stash-s6:hwaccel
    ```
- utilizes [jellyfin-ffmpeg](https://jellyfin.org/docs/general/administration/hardware-acceleration/)
    ```
    docker pull ghcr.io/feederbox826/stash-s6:hwaccel-jf
    ```
- utilizes [linuxserver.io ffmpeg](https://github.com/linuxserver/docker-ffmpeg)
    - has specific additional support for iHD and i965
    ```
    docker pull ghcr.io/feederbox826/stash-s6:hwaccel-lscr
    ```