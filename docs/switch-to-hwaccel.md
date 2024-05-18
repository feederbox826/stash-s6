# I want hardware acceleration and I want it now!

## Step 1: compatible image
replace the following in your `docker-compose.yml`
```diff
services:
  stash:
-   image: stashapp/stash
+   image: nerethos/stash-jellyfin-ffmpeg
+   image: ghcr.io/feederbox826/stash-s6:hwaccel-jf
...
```

Both use jellyfin under the hood

## Step 2: Hardware-specific configuration
### NVIDIA CUDA/ NVENC
- Make sure you have the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) installed

add the following to your `docker-compose.yml`
```yml
services:
  stash:
    ...
    runtime: nvidia
    deploy:
      resources:
        reservations:
          devices:
            - capabilities: [gpu]
    ...
```

### Intel VAAPI / QuickSync
add the following to your `docker-compose.yml`

```yml
services:
  stash:
    ...
    devices:
      - /dev/dri:/dev/dri
```

If you are on Intel 5xxx to 8xxx
Add the following
```yml
services:
  stash:
    environment:
    ...
    LIBVA_DRIVER_NAME_JELLYFIN=i965
    LIBVA_DRIVER_NAME=i965
```

## Step 3: Stash Configuration
1. Verify your hardware support
    1. This is under logs and you should see a line similar to
    ```
    [InitHWSupport] Supported HW codecs:
	  h264_nvenc
    ```
2. Enable hardware acceleration
    1. Settings -> System -> Transcoding -> FFmpeg hardware encoding

## Step 4: Profit
Try streaming an incompatible scene and check your GPU activity with `nvidia-smi` or `nvtop` for NVIDIA or `vainfo` for Intel