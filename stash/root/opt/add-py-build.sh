#!/bin/sh

# feederbox826 | MIT or AGPL3 | https://u.feederbox.cc/stash-log | v1.0
log() { level="$1"; shift; printf >&2 "\001%s\002%s: %s\n" "$level" "add-py-build" "$*"; }

# check for rootless as arg
ROOTLESS="$1"
if [ "$ROOTLESS" -eq 1 ]; then
  echo "INSTALL_PY_DEPS cannot be ran in a rootless container. Add root permission and try again."
  exit 1
fi

# check for rootful
if [ "$(id -u)" -ne 0 ]; then
  log "e" "This script must be run as root."
  log "e" "Please enter the container interactively and run the script with: sh /opt/add-py-build.sh"
  exit 1
fi

# install dependencies in a virtual package to make removal easier
# virtual package contains:
#  - build-case: gcc, make, development tools
#  - git: for pip installs from git repos
#  - python3-dev: python headers
#  - musl-dev: c headers
#  - linux-headers: kernel headers
echo "Installing virtual package 'stash-py-build'"
apk add \
  --no-cache \
  --virtual stash-py-build \
  build-base \
  git \
  python3-dev \
  musl-dev \
  linux-headers

echo "To remove build tools, run: apk del stash-py-build"
