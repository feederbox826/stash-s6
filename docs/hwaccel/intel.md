# setup
add the following to your `docker-compose.yml`

```yml
x-quicksync: &quicksync
  devices:
    - /dev/dri
  group_add:
    - 44
    - 109
    - 103
    - 226

services:
  stash:
    <<: *quicksync
    environment:
      - AVGID=22
      - AUTO_AVGID=TRUE
```
## windows
make sure that:
- [Intel drivers](https://www.intel.com/content/www/us/en/download-center/home.html) are up to date
- [WSL2](https://learn.microsoft.com/en-us/windows/wsl/install) is installed and up to date (`wsl --update`)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) is up to date

# troubleshooting

## AVGID
If you are running under PUID/PGID or [rootless `user:`](../advanced/rootless.md), you need to add the GID that has access to `/dev/dri`.
Some common AVGIDs include:
- 44
- 103
- 109
- 226

You can find this on your system with the following command
```sh
getent group render | cut -d: -f3
```
PUID/PGID
---
If you're using PUID/PGID, you can add `AUTO_AVGID=true` alongside `AVGID` and it will automatically determine and correct permissions for AVGID.
```
INFO 🎭 Running as 911:911 from PUID/PGID
INFO 🎭🎞️ Additional GID from AVGID: 22
INFO 🎭🎞️ updating AVGID to 103 to access /dev/dri/renderD128
```

rootless `user:`
---
To add additional groups, add the following to your `docker-compose.yml` service:
```yml
services:
  stash:
    ...
    group_add:
      - 44
      - 103
      - 109
      - 226
      - MY_AVGID
    ...
```

## ARC Drivers
Make sure you don't have any competing drivers such as NVIDIA installed, as these tend to caus conflicts

Follow the steps for Intel Client GPUs: https://dgpu-docs.intel.com/driver/client/overview.html

For Ubuntu:
```sh
sudo apt-get update
sudo apt-get install -y software-properties-common
# add intel-graphics ppa
sudo add-apt-repository -y ppa:kobuk-team/intel-graphics
# install compute-related packages
# sudo apt-get install -y libze-intel-gpu1 libze1 intel-metrics-discovery intel-opencl-icd clinfo intel-gsc
# instal media-related packages
sudo apt-get install -y intel-media-va-driver-non-free libmfx-gen1 libvpl2 libvpl-tools libva-glx2 va-driver-all vainfo
```

If issues persist after rebotos, also install the compute-related packages and optionally follow the Data Center GPU installation guide which uses the same core drivers: https://dgpu-docs.intel.com/driver/installation-lts2.html

After installing drivers, make sure to **fully reboot your host system** as this catches many stray issues.

## LIBVA_DRIER_NAME
This is usually not recommended unless you are on older hardware (5xxx-8xxx) AND your GPU is not being detected. Make sure to **REMOVE** this variable entirely, setting it to an empty value **WILL NOT** effectively disables drivers.

Valid values:
- `i965`
  - Older iGPUs (5xxx-8xxx)
- `iHD`
  - (8xxx+)
  - Also supports most older generations
```
LIBVA_DRIVER_NAME=iHD
LIBVA_DRIVER_NAME_JELLYFIN=iHD
```

## Additional sources
- [debian wiki - HardwareVideoAcceleration](https://wiki.debian.org/HardwareVideoAcceleration)
- [Intel dGPU docs](https://dgpu-docs.intel.com/driver/client/overview.html)
- [Jellyfin Intel HWA](https://jellyfin.org/docs/general/post-install/transcoding/hardware-acceleration/intel/)
- [Arch Wiki - Hardware video acceleration](https://wiki.archlinux.org/title/Hardware_video_acceleration)