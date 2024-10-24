# I want hardware acceleration and I want it now!

## Step 1: compatible image
replace the following in your `docker-compose.yml` with one of the following images
```diff
services:
  stash:
-   image: stashapp/stash
+   image: nerethos/stash-jellyfin-ffmpeg

-   image: stashapp/stash
+   image: ghcr.io/feederbox826/stash-s6:hwaccel
...
```

Both use jellyfin under the hood

## Step 2: Hardware-specific configuration
### NVIDIA CUDA/ NVENC
- Make sure you have the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) installed

add the following snippets to your `docker-compose.yml`
```yml
x-nvenc: &nvenc
  runtime: nvidia
  deploy:
    resources:
      reservations:
        devices:
          - driver: nvidia
            count: 1
            capabilities: [gpu]

services:
  stash:
    <<: *nvenc
    ...
```

### Intel VAAPI / QuickSync
add the following to your `docker-compose.yml`

```yml
x-quicksync: &quicksync
  devices:
    - /dev/dri:/dev/dri
  group_add:
    - 109
    - 44
    - 103
    - 226

services:
  stash:
    <<: *quicksync
    ...
```

If you are on Arc/ Flex, make sure that you have installed all the necessary drivers on your host system  
https://dgpu-docs.intel.com/driver/client/overview.html

see [arc-troubleshooting](./arc-troubleshooting.md) if you run into more problem

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
3. Validation
   1. If you are still not getting `[InitHWSupport]`, check that you don't have ffmpeg in your local directory. stash-s6 will also warn you if you do.

## Step 4: Profit
Try streaming an incompatible scene and check your GPU activity with  
`nvidia-smi` or `nvtop` for NVIDIA  
`vainfo` or `intel_gpu_top` for Intel  