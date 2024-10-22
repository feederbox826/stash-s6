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
# environment variables
CONFIG_ROOT="/config"
PYTHON_REQS="${CONFIG_ROOT}/requirements.txt"
STASHAPP_STASH_ROOT="/root/.stash"
COMPAT_MODE=0
# shellcheck disable=SC1091
source "/opt/shell-logger.sh"
export LOGGER_COLOR="always"
export LOGGER_SHOW_FILE="0"
#}}}

#{{{🔑 permission functions
# run as CURUSR if possible
runas() {
  if [[ ${ROOTLESS} -eq 1 ]]; then
    "$@"
  else
    su-exec "${CURUSR}:${CURGRP}" "$@"
  fi
}
# recursive chown as CURUSR:CURGRP
reown_r() {
  # if forced, chown is necessary for function, so SKIP_CHOWN is ignored
  local force=$1
  if [ ${ROOTLESS} -eq 1 ]; then
    return
  # if not forced and SKIP_CHOWN, return
  elif [[ ! $force ]] && [[ $SKIP_CHOWN ]]; then
    return
  fi
  info "🔑 owning $1"
  # if DNE, assume and create directory
  [ ! -e "$1" ] && mkdir -p "$1"
  chown -R "${CURUSR}:${CURGRP}" "$1" && \
    chmod -R "=rwx" "$1"
}
# check directory permissions
check_dir_perms() {
  [ -w "${1}" ] && return 0 || return 1
}
# warn about directory permissions
warn_dir_perms() {
  local chkdir="${1}"
  local msg="⚠️ ${chkdir} is not writeable by stash"
  if [ -n "${SKIP_CHOWN}" ]; then
    msg="${msg} and SKIP_CHOWN is set"
  fi
  warn "${msg}"
  warn "💻 Please run 'chown -R ${CURUSR}:${CURGRP} ${chkdir}' on the host to fix this"
  exit 1
}
# try to access and reown if necessary
try_reown() {
  local chkdir="$1"
  local force="$2"
  # if permission issues and reown fails, warn
  if ! check_dir_perms "${chkdir}" && ! reown_r "${chkdir}" "${force}"; then
    warn_dir_perms "${chkdir}"
  fi
}
#}}} /🔑

#{{{🚛 migration helpers
# check if path in key can be migrated
get_config_key() {
  local key="${1}"
  local default="${2}"
  value=$(yq -r ".${key}" "${STASH_CONFIG_FILE}")
  if [ "${value}" = "null" ]; then
    value="${default}"
  fi
  echo "${value}"
}
# move and update key to new path
migrate_update() {
  info "🚚 migrating ${1} to ${3}"
  local key="${1}"
  local old_path="${2}"
  local new_path="${3}"
  # old path doesn't exist, create instead
  if [ -e "${old_path}" ]; then
    mv -n "${old_path}" "${new_path}" && \
      reown_r "${new_path}" "FORCE"
  else
    reown_r "${new_path}" "FORCE"
  fi
  yq -i ".${key} = \"${new_path}\"" "${CONFIG_YAML}"
}
check_migrate() {
  local key="${1}" # key in yaml config
  local config_path="${2}" # new /config path
  local old_root="${3}" # old "config" storage directory
  local env_path="${4}" # environment variable to override path of
  # get value of key
  local old_path
  old_path=$(yq ."${key}" "${CONFIG_YAML}")
  # remove quotes
  old_path="${old_path%\"}"
  old_path="${old_path#\"}"
  # SKIP if not set
  if [ "${old_path}" = "null" ]; then
    info "⏩🚛 skip migrating ${key}" as it is not set
  # SKIP if not in old_root
  elif ! [[ "${old_path}" == *"${old_root}"* ]]; then
    info "⏩🚛 not migrating ${key} as it is not in ${old_root}"
  # SKIP if path is a mount
  elif mountpoint -q "${old_path}"; then
    warn "⏩🚛 skip migrating ${key} as it is a mount"
  # MOVE to path defined in environment variable if mounted
  elif [ -n "${env_path}" ] && [ -e "${env_path}" ] && mountpoint -q "${env_path}"; then
    migrate_update "${key}" "${old_path}" "${env_path}"
  # MOVE to /config if /config is mounted
  elif [ -e "/config" ] && mountpoint -q "/config"; then
    migrate_update "${key}" "${old_path}" "${config_path}"
  # /config not mounted, error
  else
    info "🛑🚛 not migrating ${key} as /config is not mounted"
  fi
}
# detect if migration is needed and migrate
try_migrate() {
  # run if MIGRATE is set
  if [ "${MIGRATE}" == "TRUE" ] || [ "${MIGRATE}" == "true" ]; then
    if [ -e "/config/.stash" ]; then
      hotio_stash_migration
    elif [ -e "${STASHAPP_STASH_ROOT}" ] && [ -f "${STASHAPP_STASH_ROOT}/config.yml" ]; then
      stashapp_stash_migration
    else
      warn "⏩🚚 MIGRATE is set, but no migration is needed"
    fi
  # MIGRATE not set but might be needed
  elif [ -e "${STASHAPP_STASH_ROOT}" ]; then
    warn "⚙️ ${STASHAPP_STASH_ROOT} exists, but MIGRATE is not set. Running in stashapp/stash compatibility mode"
    export STASH_CONFIG_FILE="${STASHAPP_STASH_ROOT}/config.yml"
  fi
}
#}}} /🚛

#{{{🚚 migration
# migrate from hotio/stash
hotio_stash_migration() {
  info "🚚 migrating from hotio/stash"
  # hotio doesn't need file migrations, just delete symlinks
  unlink "/config/.stash"
  unlink "/config/ffmpeg"
  unlink "/config/ffprobe"
}
# migrate from stashapp/stash
stashapp_stash_migration() {
  # check if /config is mounted
  if ! mountpoint -q "${CONFIG_ROOT}"; then
    warn "🛑🚚 aborting migration from stashapp/stash as ${CONFIG_ROOT} is not mounted"
    return 1
  else
    try_reown "${CONFIG_ROOT}" "FORCE"
  fi
  info "🚚 migrating from stashapp/stash"
  local old_root="/root/.stash"
  # set config yaml path for re-use
  CONFIG_YAML="${old_root}/config.yml"
  # migrate and check all paths in yml
  check_migrate "generated"     "${CONFIG_ROOT}/generated"        "${old_root}"  "${STASH_GENERATED}"
  check_migrate "cache"         "${CONFIG_ROOT}/cache"            "${old_root}"  "${STASH_CACHE}"
  check_migrate "blobs_path"    "${CONFIG_ROOT}/blobs"            "${old_root}"  "${STASH_BLOBS}"
  check_migrate "plugins_path"  "${CONFIG_ROOT}/plugins"          "${old_root}"
  check_migrate "scrapers_path" "${CONFIG_ROOT}/scrapers"         "${old_root}"
  check_migrate "database"      "${CONFIG_ROOT}/stash-go.sqlite"  "${old_root}"
  # forcefully move config.yml
  mv -n "${old_root}/config.yml" "${STASH_CONFIG_FILE}"
  # forcefully move database backups
  mv -n "${old_root}/stash-go.sqlite*" "${CONFIG_ROOT}"
  # forcefully move misc files
  mv -n \
    "${old_root}/custom.css" \
    "${old_root}/custom.js" \
    "${old_root}/custom-locales.json" \
    "${CONFIG_ROOT}"
  # migrate all other misc files
  info "🚚‼️ leftover files:"
  ls -la "${old_root}"
  # reown files
  reown_r "${CONFIG_ROOT}" "FORCE"
  # symlink old directory for compatibility
  info "🚛 symlinking ${old_root} to ${CONFIG_ROOT}"
  rmdir "${old_root}" && \
    ln -s "${CONFIG_ROOT}" "${old_root}"
}
#}}} /🚚

#{{{🐍 python helpers
# search directory for requirements.txt
search_dir_reqs() {
  local target_dir="$1"
  if [ ! -d "${target_dir}" ]; then
    warn "🐍 ${target_dir} not found, skipping requirement search"
    return 0
  fi
  find "${target_dir}" -type f -name "requirements.txt" -print0 | while IFS= read -r -d '' file
  do
    parse_reqs "$file"
  done
}
# parse requirements
parse_reqs() {
  local file="$1"
  info "🐍 Parsing ${file}"
  echo "# ${file}" >> "${PYTHON_REQS}"
  while IFS="" read -r p || [ -n "$p" ]
  do
    [[ "${p}" = \#* ]] && continue # skip comments
    read -r -a pkgarg <<< "$p"
    debug "🐍 Adding ${pkgarg[0]} to requirements.txt"
    echo "${pkgarg[0]}" >> "${PYTHON_REQS}"
  done < "$file"
}
find_reqs() {
  # check that config.yml exists
  if [ ! -f "${STASH_CONFIG_FILE}" ]; then
    warn "🐍 config.yml not found, skipping requirements.txt generation"
    return 0
  fi
  # iterate over plugins
  search_dir_reqs "$(get_config_key "plugins_path"  "${CONFIG_ROOT}/plugins")"
  # iterate over scrapers
  search_dir_reqs "$(get_config_key "scrapers_path" "${CONFIG_ROOT}/scrapers")"
}
# dedupe requirements.txt
dedupe_reqs() {
  awk '!seen[$0]++' "${PYTHON_REQS}" > "${PYTHON_REQS}.tmp"
  mv "${PYTHON_REQS}.tmp" "${PYTHON_REQS}"
}
# install python dependencies
install_python_deps() {
  # copy over /defaults/requirements if it doesn't exist
  if [ ! -f "${PYTHON_REQS}" ] || [ ! -s "${PYTHON_REQS}" ]; then
    debug "🐍 Copying default requirements.txt"
    cp "/defaults/requirements.txt" "${PYTHON_REQS}" && \
      reown_r "${PYTHON_REQS}" "FORCE"
  fi
  find_reqs
  dedupe_reqs
  # fix /pip-install directory
  info "🐍 Installing/upgrading python requirements..."
  # UV_CACHE_DIR = /pip-install/cache
  reown_r "${UV_TARGET}" "FORCE" && \
    reown_r "${UV_CACHE_DIR}" "FORCE" && \
    runas uv pip install \
      --system \
      --target "${UV_TARGET}" \
      --requirement "${PYTHON_REQS}"
}
#}}} /🐍

#{{{ misc helpers
# trap exit and error
finish() {
  result=$?
  exit ${result}
}
# check if local ffmpeg is present
check_ffmpeg() {
  if [ -e "$1/ffmpeg" ] || [ -e "$1/ffprobe" ]; then
    err "💥 ffmpeg/ffprobe is present at $1, this will likely cause issues. Please remove it"
  fi
}
# patch multistream NVENC from keylase/nvidia-patch
patch_nvidia() {
  if [ -n "${SKIP_NVIDIA_PATCH}" ]; then
    debug "⏩🖥️ Skipping nvidia patch because of SKIP_NVIDIA_PATCH"
    return 0
  elif [ $ROOTLESS -eq 1 ]; then
    warn "⏩🖥️ Skipping nvidia patch as it requires root"
    return 0
  fi
  debug "🛠️🖥️ Patching nvidia libraries for multi-stream..."
  wget \
    --quiet \
    --timestamping \
    -O "/usr/local/bin/nv-patch.sh" \
    "https://raw.githubusercontent.com/keylase/nvidia-patch/master/patch.sh"
  chmod "+x" "/usr/local/bin/nv-patch.sh"
  local PATCH_OUTPUT_DIR="/patched-lib"
  mkdir -p "${PATCH_OUTPUT_DIR}"
  echo "${PATCH_OUTPUT_DIR}" > "/etc/ld.so.conf.d/000-patched-lib.conf"
  PATCH_OUTPUT_DIR=/patched-lib /usr/local/bin/nv-patch.sh -s
  cd /patched-lib && \
  for f in * ; do
    suffix="${f##*.so}"
    name="$(basename "$f" "$suffix")"
    [ -h "$name" ] || ln -sf "$f" "$name"
    [ -h "$name" ] || ln -sf "$f" "$name.1"
  done
  ldconfig
}
# install custom certificates
install_custom_certs() {
  CERT_PATH="${CUSTOM_CERT_PATH:-/config/certs}"
  if [ -d "${CERT_PATH}" ]; then
    info "🛡️ Installing custom certificates from ${CERT_PATH}"
    cp -r "${CERT_PATH}"/* /usr/local/share/ca-certificates/
    update-ca-certificates
  fi
}
#}}}

#{{{ main
trap finish EXIT
# user setup
# check if running in stashapp/stash compatibility mode
if [ -e "${STASHAPP_STASH_ROOT}" ] && [ "${MIGRATE}" != "TRUE" ] && [ "${MIGRATE}" != "true" ]; then
  COMPAT_MODE=1
  ROOTLESS=0
  # check if /root is writeable, if not warn
  # change UID/GID for test
  groupmod -o -g "$PGID" stash
  usermod  -o -u "$PUID" stash
  if ! runas check_dir_perms "${STASHAPP_STASH_ROOT}"; then
    warn "🛑🔑 Could not change to PUID/PGID due to ${STASHAPP_STASH_ROOT} not being writeable"
    CURUSR="$(id -u)"
    CURGRP="$(id -g)"
  else
    info "🎭 Changing to PUID/PGID since ${STASHAPP_STASH_ROOT} is writeable"
    CURUSR="${PUID}"
    CURGRP="${PGID}"
  fi
  info "⚙️ Running in stashapp/stash full compatibility mode. CHOWN, migration and PUID/PGID skipped."
# check if running with or without root
elif [ "$(id -u)" -ne 0 ]; then
  ROOTLESS=1
  CURUSR="$(id -u)"
  CURGRP="$(id -g)"
  info "⏩ Not running as root. CHOWN, migration and PUID/PGID skipped."
else # if root, use PUID/PGID
  ROOTLESS=0
  CURUSR="${PUID}"
  CURGRP="${PGID}"
  # change UID/GID accordingly
  groupmod -o -g "$PGID" stash
  usermod  -o -u "$PUID" stash
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
elif [ $COMPAT_MODE -eq 1 ]; then
  echo "stashapp/stash mode: TRUE"
fi)"
echo '
───────────────────────────────────────
entrypoint.sh

'
try_migrate
install_python_deps
patch_nvidia
install_custom_certs
# only chown if not in stashapp/stash compatibility mode
if [ $COMPAT_MODE -ne 1 ]; then
  info "🔑 Creating ${CONFIG_ROOT}"
  try_reown "${CONFIG_ROOT}"
  # move to CONFIG_ROOT
  cd "${CONFIG_ROOT}" || exit 1
fi
# danger if ffmpeg present locally
check_ffmpeg "${CONFIG_ROOT}"
check_ffmpeg "${STASHAPP_STASH_ROOT}"
# finally start stash
echo '
Starting stash...
───────────────────────────────────────
'
trap - EXIT
runas '/app/stash' '--nobrowser'
#}}}