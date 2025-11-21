# I want hardware acceleration and I want it now!

## Step 1: compatible image
replace `stashapp/stash` in your docker image with
[`nerethos/stash-jellyfin-ffmpeg`](https://hub.docker.com/r/nerethos/stash-jellyfin-ffmpeg)
or `ghcr.io/feederbox826/stash-s6:hwaccel`

```diff
services:
  stash:
-   image: stashapp/stash
+   image: nerethos/stash-jellyfin-ffmpeg

-   image: stashapp/stash
+   image: ghcr.io/feederbox826/stash-s6:hwaccel
...
```
Both use jellyfin under the hood and provide hardware acceleration.

## Step 2: hardware-specific configuration
If you already have hardware acceleration configured for the system (`--device /dev/dri`) or `--gpus=all` you can safely skip this step.

[Intel (QSV)](intel.md) | [NVIDIA (CUDA)](nvidia.md)

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
   1. If you are still not getting `[InitHWSupport]`, check that you don't have ffmpeg at `/config/ffmpeg` or `/root/.stash/ffmpeg`. stash-s6 will also warn you if you do.

## Step 4: Profit
Try streaming an incompatible scene and check your GPU activity with  
`nvidia-smi` or `nvtop` for NVIDIA  
`vainfo` or `intel_gpu_top` for Intel  