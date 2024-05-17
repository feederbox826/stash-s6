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
- standard debian ffmpeg
    ```
    docker pull ghcr.io/feederbox826/stash-s6:hwaccel
    ```
- utilizes [jellyfin-ffmpeg](https://jellyfin.org/docs/general/administration/hardware-acceleration/)
    ```
    docker pull ghcr.io/feederbox826/stash-s6:hwaccel-jf
    ```

## internal packages
`hwaccel-base` - shared base image for hardware acceleration

## environment variables
`PUID` - Process User ID  
`PGID` - Process Group ID  
`SKIP_NVIDIA_PATCH` - skips patching nvidia driver for multi-stream nvenc  
`TZ` - timezone  

## migration-specific environment variables
`MIGRATE` - automatic migration from `stashapp/stash` or `hotio/stash`  
`SKIP_CHOWN` - skips chown operations for /config directory  

## Run modes
### `stashapp/stash compatibility`
I want to keep using the `stashapp/stash` image or possibly switch back
- Replace `image: stashapp/stash` with your desired image
- You will see a message `Running in stashapp/stash compatibility mode...`

### Migration from `stashapp/stash` or `hotio/stash`
!!! I don't want the option to switch back !!!
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