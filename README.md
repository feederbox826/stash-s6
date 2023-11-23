# stashapp/stash with(out) s6
## s6 was removed, will keep the naming for now...

for [stashapp/stash#4300](https://github.com/stashapp/stash/issues/4300)

## latest/ alpine/ arm
- built on alpine linux, no hardware acceleration support
```
docker pull ghcr.io/feederbox826/stash-s6:alpine
```

## hwaccel
- built on debian, hardware acceration support via multiple ffmpeg builds
- only works on amd64
- standard debian ffmpeg
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

## internal packages
`hwaccel-base` - shared base image for hardware acceleration

## Other environment variables
`SKIP_CHOWN` - skips chown operations for /config directory  
`SKIP_NVIDIA_PATCH` - skips patching nvidia driver for multi-stream nvenc  
`MIGRATE` - automatic migration from stashapp/stash or hotio/stash  