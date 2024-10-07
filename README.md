# stashapp/stash with(out) s6
![](docs/icon/horiz-bg.svg)
for [stashapp/stash#4300](https://github.com/stashapp/stash/issues/4300)
- non-root user support
  - PUID/ PGID switching support
- TZ settings
- CUDA/ QSV images
  - NVENV encoding session patches
- automatic dependency installs

## latest/ alpine
- built on alpine linux, no hardware acceleration support
```
docker pull ghcr.io/feederbox826/stash-s6:alpine
```

## hwaccel
- built on debian, hardware acceration support via jellyfin-ffmpeg
- utilizes [jellyfin-ffmpeg](https://jellyfin.org/docs/general/administration/hardware-acceleration/)
```
docker pull ghcr.io/feederbox826/stash-s6:hwaccel
```

## Deprecation warning
The following image aliases will be removed
- hwaccel-amd64
- hwaccel-armv7
- hwaccel-arm64
- hwaccel-armv6
- hwaccel-jf-amd64
- hwaccel-jf-armv7
- hwaccel-jf-arm64
- hwaccel-jf

## Jellyfin-ffmpeg7 alpha
- same as hwaccel, uses jellyfin-ffmpeg7
- could possibly break and blow up, but just replace with `hwaccel-develop` to revert
```
docker pull ghcr.io/feederbox826/stash-s6:hwaccel-develop-jf7
```

## environment variables
`PUID` - Process User ID  
`PGID` - Process Group ID  
`SKIP_NVIDIA_PATCH` - skips patching nvidia driver for multi-stream nvenc. see [keylase/nvidia-patch](https://github.com/keylase/nvidia-patch?tab=readme-ov-file#version-table) for supported drivers  
`TZ` - timezone  
`CUSTOM_CERT_PATH` - Path to custom root certificates to be added to stash (defaults to `/config/certs`)  

## migration-specific environment variables
`MIGRATE` - automatic migration from `stashapp/stash` or `hotio/stash`  
`SKIP_CHOWN` - skips chown operations for /config directory  

## Run modes
### `stashapp/stash compatibility`
I want to keep using the `stashapp/stash` image or possibly switch back
- Replace `image: stashapp/stash` with your desired image
- You will see a message `Running in stashapp/stash compatibility mode...`

### Migration from `stashapp/stash` or `hotio/stash`

> [!WARNING]
> Switching back is difficult and requires manual configuration

- Replace `image: stashapp/stash` with your desired image
- Set the environment variables
  ```
  MIGRATE=TRUE
  ```
- Add the following volumes alongside your existing mounts. It should look like
```
volumes:
  - /data/old-stash/config:/root/.stash
  - /data/new-stash/config:/config
  - /data/new-stash/pip-install:/pip-install
```