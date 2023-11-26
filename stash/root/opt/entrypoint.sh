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
  local old_root="${3}" # old "config" storage directory
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
  # only touch files in old_root
  elif ! [[ "${old_path}" == *"${old_root}"* ]]; then
    info "not migrating ${key} as it is not in ${old_root}"
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
  if ! mountpoint -q "${CONFIG_ROOT}"; then
    warn "not migrating from stashapp/stash as ${CONFIG_ROOT} is not mounted"
    return 1
  elif check_dir_perms "${CONFIG_ROOT}"; then
    warn_dir_perms "${CONFIG_ROOT}"
  fi
  info "migrating from stashapp/stash"
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
  # migrate all other misc files
  info "leftover files:"
  ls -la "${old_root}"
  # reown files
  reown_r "${CONFIG_ROOT}"
  # symlink old directory for compatibility
  info "symlinking ${old_root} to ${CONFIG_ROOT}"
  rmdir "${old_root}" && \
    ln -s "${CONFIG_ROOT}" "${old_root}"
}
# detect if migration is needed and migrate
try_migrate() {
  local stashapp_root="/root/.stash"
  # run if MIGRATE is set
  if [ -n "${MIGRATE}" ]; then
    if [ -e "/config/.stash" ]; then
      hotio_stash_migration
    elif [ -e "${stashapp_root}" ] && [ -f "${stashapp_root}/config.yml" ]; then
      stashapp_stash_migration
    else
      warn "MIGRATE is set, but no migration is needed"
    fi
  # MIGRATE not set but might be needed
  elif [ -e "${stashapp_root}" ]; then
    warn "${stashapp_root} exists, but MIGRATE is not set. This may cause issues."
    (reown "/root/" && safe_reown "${stashapp_root}") || \
      warn_dir_perms "${stashapp_root}"
    export STASH_CONFIG_FILE="${stashapp_root}/config.yml"
  fi
}
get_config_key() {
  local key="${1}"
  local default="${2}"
  value=$(yq -r ".${key}" "${STASH_CONFIG_FILE}")
  if [ "${value}" = "null" ]; then
    value="${default}"
  fi
  echo "${value}"
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
# parse requirements
parse_reqs() {
  local file="$1"
  info "Parsing ${file}"
  echo "# ${file}" >> "${PYTHON_REQS}"
  while IFS="" read -r p || [ -n "$p" ]
  do
    [[ "${p}" = \#* ]] && continue # skip comments
    read -r -a pkgarg <<< "$p"
    debug "Adding ${pkgarg[0]} to requirements.txt"
    echo "${pkgarg[0]}" >> "${PYTHON_REQS}"
  done < "$file"
}
# search directory for requirements.txt
search_dir_reqs() {
  local target_dir="$1"
  if [ ! -d "${target_dir}" ]; then
    warn "${target_dir} not found, skipping"
    return 0
  fi
  find "${target_dir}" -type f -name "requirements.txt" -print0 | while IFS= read -r -d '' file
  do
    parse_reqs "$file"
  done
}
# dedupe requirements.txt
dedupe_reqs() {
  awk '!seen[$0]++' "${PYTHON_REQS}" > "${PYTHON_REQS}.tmp"
  mv "${PYTHON_REQS}.tmp" "${PYTHON_REQS}"
}
find_reqs() {
  # check that config.yml exists
  if [ ! -f "${STASH_CONFIG_FILE}" ]; then
    warn "config.yml not found, skipping requirements.txt generation"
    return 0
  fi
  # iterate over plugins
  search_dir_reqs "$(get_config_key "plugins_path"  "${CONFIG_ROOT}/plugins")"
  # iterate over scrapers
  search_dir_reqs "$(get_config_key "scrapers_path" "${CONFIG_ROOT}/scrapers")"
  dedupe_reqs "${PYTHON_REQS}"
}
# install python dependencies
install_python_deps() {
  # copy over /defaults/requirements if it doesn't exist
  if [ ! -f "${PYTHON_REQS}" ]; then
    debug "Copying default requirements.txt"
    cp "/defaults/requirements.txt" "${PYTHON_REQS}" && \
      reown "${PYTHON_REQS}"
  fi
  # fix /pip-install directory
  info "Installing/upgrading python requirements..."
  safe_reown "${PIP_INSTALL_TARGET}" && \
    mkown "${PIP_CACHE_DIR}" && \
    runas pip3 install \
      --upgrade -q \
      --exists-action i \
      --target "${PIP_INSTALL_TARGET}" \
      --requirement "${PYTHON_REQS}"
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
# Check if the container is running as root
if [ "$(id -u)" -eq 0 ]; then
    # Running as root, execute usermod and groupmod
    groupmod -o -g "$PGID" stash
    usermod -o -u "$PUID" stash
else
    # Not running as root, print a message
    echo "Not running as root. User and group modification skipped."
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
find_reqs
install_python_deps
patch_nvidia
info "Creating ${CONFIG_ROOT}"
safe_reown "${CONFIG_ROOT}"
# finally start stash
echo '
Starting stash...
───────────────────────────────────────
'
trap - EXIT
runas '/app/stash' '--nobrowser'
#}}}