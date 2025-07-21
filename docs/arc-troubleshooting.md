# Common Pitfalls
- make sure you install all the recommended intel packages. I don't know why but doing this solved most of my problems. for me, it was
```sh
sudo apt install -y \
  intel-opencl-icd intel-level-zero-gpu level-zero intel-level-zero-gpu-raytracing \
  intel-media-va-driver-non-free libmfx1 libmfxgen1 libvpl2 \
  libegl-mesa0 libegl1-mesa libegl1-mesa-dev libgbm1 libgl1-mesa-dev libgl1-mesa-dri \
  libglapi-mesa libgles2-mesa-dev libglx-mesa0 libigdgmm12 libxatracker2 mesa-va-drivers \
  mesa-vdpau-drivers mesa-vulkan-drivers va-driver-all vainfo hwinfo clinfo 
```
- make sure you have other competing drivers (NVIDIA) uninstalled
- make sure you did not set the `LIBVA_DRIVER_NAME_JELLYFIN` or `LIBVA_DRIVER_NAME` to i915
- reboot, reboot, reboot
- if there is something akin to permission denied
  - safe ☮️: `getent group render | cut -d: -f3` to get the group ID of "render" or "video"
    - Add it to the `group_add` block in `docker-compose`
    - Add it to `AVGID` if using `PUID/PGID`
  - dangerous ⚠️: `chmod -R 666 /dev/dri` to open up permissions to the video cards (resets on reboot)

- appeal to other resources: [jellyfin](https://jellyfin.org/docs/general/administration/hardware-acceleration/intel) [intel](https://dgpu-docs.intel.com/driver/client/overview.html)