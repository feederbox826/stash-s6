#!/usr/bin/with-contenv bash
# shellcheck shell=bash
#
# Author: feederbox826
# Path: /opt/entrypoint.sh
# Description: Entrypoint script for stash docker container

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
  if [ -n "${SKIP_CHOWN}" ] || [ ${ROOTLESS} -eq 1 ]; then
    return
  fi
  info "reowning $1"
  chown stash:stash "$1"
}
# recursive chown
reown_r() {
  if [ -n "${SKIP_CHOWN}" ] || [ ${ROOTLESS} -eq 1 ]; then
    return
  fi
  info "reowning_r $1"
  chown -Rh stash:stash "$1" && \
    chmod -R "=rwx" "$1"
}
# mkdir and chown
mkown() {
  runas mkdir -p "$1" || \
    (mkdir -p "$1" && reown_r "$1")
}
## migration helpers
# move and update key to new path
migrate_update() {
  info "migrating ${1} to ${3}"
  local key="${1}"
  local old_path="${2}"
  local new_path="${3}"
  # old path doesn't exist, create instead
  if [ -e "${old_path}" ]; then
    mv -n "${old_path}" "${new_path}" && \
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
    migrate_update "${key}" "${old_path}" "${env_path}"
  # move to /config if /config is mounted
  elif [ -e "/config" ] && mountpoint -q "/config"; then
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
  # check if /config is mounted
  local new_config_root="/config"
  if ! mountpoint -q "${new_config_root}"; then
    warn "not migrating from stashapp/stash as ${new_config_root} is not mounted"
    return 1
  elif check_dir_perms "${new_config_root}"; then
    warn_dir_perms "${new_config_root}"
  fi
  info "migrating from stashapp/stash"
  local old_config_root="/root/.stash"
  # set config yaml path for re-use
  CONFIG_YAML="${old_config_root}/config.yml"
  # migrate and check all paths in yml
  check_migrate "generated"     "${new_config_root}/generated"        "${old_config_root}"  "${STASH_GENERATED}"
  check_migrate "cache"         "${new_config_root}/cache"            "${old_config_root}"  "${STASH_CACHE}"
  check_migrate "blobs_path"    "${new_config_root}/blobs"            "${old_config_root}"  "${STASH_BLOBS}"
  check_migrate "plugins_path"  "${new_config_root}/plugins"          "${old_config_root}"
  check_migrate "scrapers_path" "${new_config_root}/scrapers"         "${old_config_root}"
  check_migrate "database"      "${new_config_root}/stash-go.sqlite"  "${old_config_root}"
  # forcefully move config.yml
  mv -n \
    "${old_config_root}/config.yml" \
    "${STASH_CONFIG_FILE}"
  # migrate all other misc files
  info "leftover files:"
  ls -la "${old_config_root}"
  # reown files
  reown_r "${new_config_root}"
  # symlink old directory for compatibility
  info "symlinking ${old_config_root} to ${new_config_root}"
  rmdir "${old_config_root}" && \
    ln -s "${new_config_root}" "${old_config_root}"
}
# detect if migration is needed and migrate
try_migrate() {
  # run if MIGRATE is set
  if [ -n "${MIGRATE}" ]; then
    if [ -e "/config/.stash" ]; then
      hotio_stash_migration
    elif [ -e "/root/.stash" ] && [ -f "/root/.stash/config.yml" ]; then
      stashapp_stash_migration
    else
      warn "MIGRATE is set, but no migration is needed"
    fi
  # MIGRATE not set but might be needed
  elif [ -e "/root/.stash" ]; then
    warn "/root/.stash exists, but MIGRATE is not set. This may cause issues."
    (reown "/root/" && safe_reown "/root/.stash") || \
      warn_dir_perms "/root/.stash"
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
  echo "${PATCH_OUTPUT_DIR}" > "/etc/ld.so.conf.d/000-patched-lib.conf"
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
# warn about directory permissions
warn_dir_perms() {
  local chkdir="${1}"
  local msg="${chkdir} is not writeable by stash"
  if [ -n "${SKIP_CHOWN}" ]; then
    msg="${msg} and SKIP_CHOWN is set"
  fi
  warn "${msg}"
  warn "Please run 'chown -R ${CHUSR}:${CHGRP} ${chkdir}' to fix this"
  exit 1
}
# check directory permissions
check_dir_perms() {
  local chkdir="${1}"
  touch "${chkdir}/.test" 2> /dev/null && rm "${chkdir}/.test" 2> /dev/null
  return $?
}
# check directory permissions and warn if needed
safe_reown() {
  local chkdir="${1}"
  if check_dir_perms "${chkdir}"; then
    reown_r "${chkdir}"
  else
    warn_dir_perms "${chkdir}"
  fi
}
# install python dependencies
install_python_deps() {
  # copy over /defaults/requirements if it doesn't exist
  if [ ! -f "/config/requirements.txt" ]; then
    debug "Copying default requirements.txt"
    cp "/defaults/requirements.txt" "/config/requirements.txt" && \
      reown "/config/requirements.txt"
  fi
  # fix /pip-install directory
  info "Installing/upgrading python requirements..."
  safe_reown "${PIP_INSTALL_TARGET}" && \
    mkown "${PIP_CACHE_DIR}" && \
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
if [ "$(id -u stash 2>/dev/null)" -ne "${PUID}" ]; then
  warn "User ID for 'stash' is not ${PUID}. If needed, adjust the user manually on the host system."
fi
if [ "$(id -g stash 2>/dev/null)" -ne "${PGID}" ]; then
  warn "Group ID for 'stash' is not ${PGID}. If needed, adjust the group manually on the host system."
fi
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
safe_reown "/config"
# finally start stash
echo '
Starting stash...
───────────────────────────────────────
'
trap - EXIT
runas '/app/stash' '--nobrowser'
#}}}