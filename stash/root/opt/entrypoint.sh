#!/usr/bin/with-contenv bash
# shellcheck shell=bash
#
# Author: feederbox826
# Path: /opt/entrypoint.sh
# Description: Entrypoint script for stash docker container

#{{{ environment variables
# MIGRATE
# SKIP_CHOWN
# SKIP_NVIDIA_PATCH
# PUID
# PGID
#}}}
#{{{ variables and setup
# setup UID/GID
PUID=${PUID:-911}
PGID=${PGID:-911}
# shellcheck disable=SC1091
source "/opt/shell-logger.sh"
export LOGGER_COLOR="always"
export LOGGER_SHOW_FILE="0"
#}}}
#{{{ helper functions
# run as stash user if not rootless
runas() {
  if [ ${ROOTLESS} -eq 1 ]; then
    "$@"
  else
    su-exec stash "$@"
  fi
}
# non-recursive chown
reown() {
  if [ -n "${SKIP_CHOWN}" ]; then
    return
  fi
  chown stash:stash "$1"
}
# recursive chown
reown_r() {
  if [ -n "${SKIP_CHOWN}" ]; then
    return
  fi
  chown -Rh stash:stash "$1"
  chmod -R "=rwx" "$1"
}
# mkdir and chown
mkown() {
  mkdir -p "$1"
  reown_r "$1"
}
## migration helpers
# move and update key to new path
migrate_update() {
  local key="${1}"
  local old_path="${2}"
  local new_path="${3}"
  # old path doesn't exist, create instead
  if [ -e "${old_path}" ]; then
    mv -n "${old_path}" "${new_path}"
    reown_r "${new_path}"
  else
    mkown "${new_path}"
  fi
  yq -i ".${key} = \"${new_path}\"" "${CONFIG_YAML}"
}
# check if path in key can be migrated
check_migrate() {
  local key="${1}" # key in yaml config
  local config_path="${2}" # new /config path
  local old_config_root="${3}" # old "config" storage directory
  local env_path="${4}" # environment variable to override path of
  # get value of key
  local old_path
  old_path=$(yq ."${key}" "${CONFIG_YAML}")
  # remove quotes
  old_path="${old_path%\"}"
  old_path="${old_path#\"}"
  # if not set, skip
  if [ "${old_path}" = "null" ]; then
    info "not migrating ${key}" as it is not set
  # only touch files in old_config_root
  elif ! [[ "${old_path}" == *"${old_config_root}"* ]]; then
    info "not migrating ${key} as it is not in ${old_config_root}"
  # check if path is a mount
  elif mountpoint -q "${old_path}"; then
    info "not migrating ${key} as it is a mount"
  # move to path defined in environment variable if it is mounted
  elif [ -n "${env_path}" ] && [ -e "${env_path}" ] && mountpoint -q "${env_path}"; then
    info "migrating ${key} to ${env_path}"
    migrate_update "${key}" "${old_path}" "${env_path}"
  # move to /config if /config is mounted
  elif [ -e "/config" ] && mountpoint -q "/config"; then
    info "migrating ${key} to ${config_path}"
    migrate_update "${key}" "${old_path}" "${config_path}"
  else
    info "not migrating ${key} as /config is not mounted"
  fi
}
# migrate from hotio/stash
hotio_stash_migration() {
  info "migrating from hotio/stash"
  # hotio doesn't need file migrations, just delete symlinks from .stash
  unlink "/config/.stash/ffmpeg"
  unlink "/config/.stash/ffprobe"
  rmdir "/config/.stash" # remove .stash at the very end
}
# migrate from stashapp/stash
stashapp_stash_migration() {
  info "migrating from stashapp/stash"
  local old_config_root="/root/.stash"
  # set config yaml path for re-use
  CONFIG_YAML="${old_config_root}/config.yml"
  # migrate and check all paths in yml
  check_migrate "generated" "/config/generated" "${old_config_root}" "${STASH_GENERATED}"
  check_migrate "cache" "/config/cache" "${old_config_root}" "${STASH_CACHE}"
  check_migrate "blobs_path" "/config/blobs" "${old_config_root}" "${STASH_BLOBS}"
  check_migrate "plugins_path" "/config/plugins" "${old_config_root}"
  check_migrate "scrapers_path" "/config/scrapers" "${old_config_root}"
  check_migrate "database" "/config/stash-go.sqlite" "${old_config_root}"
  # forcefully move config.yml
  mv -n "${old_config_root}/config.yml" "/config/config.yml" "${STASH_CONFIG_FILE}"
  # migrate all other misc files
  info "leftover files:"
  ls -la "${old_config_root}"
  # reown files
  reown_r "/config"
  # symlink old directory for compatibility
  info "symlinking ${old_config_root} to /config"
  rmdir "${old_config_root}" && ln -s "/config" "${old_config_root}"
}
# detect if migration is needed and migrate
try_migrate() {
  if [ -n "${MIGRATE}" ]; then
    if [ -e "/config/.stash" ]; then
      hotio_stash_migration
    elif [ -e "/root/.stash" ] && [ -f "/root/.stash/config.yml" ]; then
      stashapp_stash_migration
    else
      warn "MIGRATE is set, but no migration is needed"
    fi
  elif [ -e "/root/.stash" ]; then
    warn "/root/.stash exists, but MIGRATE is not set. This may cause issues."
    reown "/root/"
    reown_r "/root/.stash"
    export STASH_CONFIG_FILE="/root/.stash/config.yml"
  fi
}
# patch multistream NVNEC from keylase/nvidia-patch
patch_nvidia() {
  if [ -n "${SKIP_NVIDIA_PATCH}" ]; then
    debug "Skipping nvidia patch because of SKIP_NVIDIA_PATCH"
    return 0
  elif [ $ROOTLESS -eq 0 ]; then
    warn "Skipping nvidia patch as it requires root"
    return 0
  fi
  debug "Patching nvidia libraries for multi-stream..."
  wget \
    --quiet \
    --timestamping \
    --O "/usr/local/bin/patch.sh" \
    "https://raw.githubusercontent.com/keylase/nvidia-patch/master/patch.sh"
  chmod "+x" "/usr/local/bin/patch.sh"
  PATCH_OUTPUT_DIR="/patched-lib"
  mkdir -p "${PATCH_OUTPUT_DIR}"
  echo "${PATCH_OUTPUT_DIR}" > "etc/ld.so.conf.d/000-patched-lib.conf"
  PATCH_OUTPUT_DIR=/patched-lib /usr/local/bin/patch.sh -s
  cd /patched-lib && \
  for f in * ; do
    suffix="${f##*.so}"
    name="$(basename "$f" "$suffix")"
    [ -h "$name" ] || ln -sf "$f" "$name"
    [ -h "$name" ] || ln -sf "$f" "$name.1"
  done
  ldconfig
}
# chown directory, warn if not writeable
fix_chown() {
  local chkdir="${1}"
  if [ -n "${SKIP_CHOWN}" ]; then
    err "${chkdir} is not writable by stash user and SKIP_CHOWN is set"
    err "Please run 'chown -R ${CHUSR}:${CHGRP} ${chkdir}' to fix this"
    exit 1
  elif [ $ROOTLESS -eq 0 ]; then
    warn "${chkdir} is not writable by stash"
    warn "Attempting to fix permissions..."
    chown -R stash:stash "${chkdir}"
  else
    err "${chkdir} is not writable by stash"
    err "Please run 'chown -R ${CHUSR}:${CHGRP} ${chkdir}' to fix this"
    exit 1
  fi
}
# check if stash can write to directory, try to fix if not
check_chown() {
  local chkdir="${1}"
  # check that stash cannot write to CHKDIR
  if [ "$(runas touch "${chkdir}/.test" 2>&1 | grep -c "Permission denied")" -eq 1 ]; then
    fix_chown "${chkdir}"
  fi
  # clean up test file
  rm "${chkdir}/.test" 2> /dev/null
}
# install python dependencies
install_python_deps() {
  # copy over /defaults/requirements if it doesn't exist
  if [ ! -f "/config/requirements.txt" ]; then
    debug "Copying default requirements.txt"
    chown "stash:stash" "/defaults/requirements.txt"
    cp "/defaults/requirements.txt" "/config/requirements.txt"
  fi
  # fix /pip-install directory
  info "Installing/upgrading python requirements..."
  mkown "${PIP_CACHE_DIR}"
  reown "${PIP_INSTALL_TARGET}" &&
    runas pip3 install \
      --upgrade -q \
      --exists-action i \
      --target "${PIP_INSTALL_TARGET}" \
      --requirement /config/requirements.txt
  export PYTHONPATH="${PYTHONPATH}:${PIP_INSTALL_TARGET}"
}
# trap exit and error
finish() {
  result=$?
  exit ${result}
}
#}}}
#{{{ main
trap finish EXIT
# set UID/GID
groupmod -o -g "${PGID}" stash
usermod -o -u "${PUID}" stash
# check if running as rootless
if [ "$(id -u)" -ne 0 ]; then
  ROOTLESS=1
  CURUSR="$(id -u)"
  CURGRP="$(id -g)"
else # if root, use PUID/PGID
  ROOTLESS=0
  CURUSR="${PUID}"
  CURGRP="${PGID}"
fi
# print branding and donation info
cat /opt/branding
cat /opt/donate
# print UID/GID
echo '
───────────────────────────────────────
GID/UID
───────────────────────────────────────'
echo "
User UID:    ${CURUSR}
User GID:    ${CURGRP}
HW Accel:    ${HWACCEL}
$(if [ $ROOTLESS -eq 1 ]; then
  echo "Rootless:    TRUE"
fi)"
echo '
───────────────────────────────────────
entrypoint.sh

'
try_migrate
install_python_deps
patch_nvidia
info 'Creating /config'
check_chown '/config'
# finally start stash
echo '
Starting stash...
───────────────────────────────────────
'
trap - EXIT
runas '/app/stash' '--nobrowser'
#}}}