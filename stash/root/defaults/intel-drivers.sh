#!/usr/bin/with-contenv bash
# shellcheck shell=bash
#
# Author: feederbox826
# Path: /defaults/intel-drivers.sh
# Description: Install Intel compute-runtime and non-free drivers

install_nonfree_drivers() {
  if [ "$(uname -m)" != "x86_64" ]; then
    return 0
  fi
  apt install -y \
    --no-install-recommends \
    i965-va-driver-shaders \
    intel-media-va-driver-non-free \
    intel-opencl-icd
}
install_nonfree_drivers