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
PYTHON_REQS="$CONFIG_ROOT/requirements.txt"
STASHAPP_STASH_ROOT="/root/.stash"
STASHAPP_STASH_CONFIG="$STASHAPP_STASH_ROOT/config.yml"
COMPAT_MODE=0
ROOTLESS=0
# shellcheck disable=SC1091
source "/opt/shell-logger.sh"
export LOGGER_COLOR="always"
export LOGGER_SHOW_FILE="0"
#}}}

# 🎭 run as CURUSR if possible
runas() {
  if [[ $ROOTLESS -eq 1 ]] || [[ $(id -u) -eq 1 ]]; then
    "$@"
  else
    # shellcheck disable=SC2068
    su-exec "stash" $@
  fi
}

#{{{🔑 permission functions
# recursive chown as CURUSR
reown_r() {
  # if ROOTLESS cannot chown
  if [[ $ROOTLESS -eq 1 ]] ; then
    return 1
  fi
  info "🔑 fixing permissions on $1"
  # if DNE, assume and create directory
  [ ! -e "$1" ] && mkdir -p "$1"
  # change owner and permissions for owner
  chown -R "$CURUSR" "$1" && \
    chmod -R "u=rwx" "$1"
}
# non-recursive chown as CURUSR
reown() {
  # if ROOTLESS cannot chown
  if [[ $ROOTLESS -eq 1 ]] ; then
    return 1
  fi
  info "🔑 fixing permissions on $1"
  # change owner and permissions for owner
  chown "$CURUSR" "$1" && \
    chmod "u=rwx" "$1"
}
# check that directory is writeable
check_dir_perms() {
  runas test -w "$1"
}
# check file is writeable and executable
check_file_perms() {
  runas test -w "$1" && runas stat "$1" >/dev/null 2>&1
}
# try to access dir as user and reown if necessary
try_reown_r() {
  local chkdir="$1"
  # if permission issues and reown fails, warn
  if ! check_dir_perms "$chkdir" && ! reown_r "$chkdir"; then
    error "⚠️ $chkdir is not accessible by stash"
    error "💻 Please run 'chown -R $CURUSR:$CURGRP $chkdir' on the host to fix this"
    return 1
  fi
}
# try to access as user and reown if necessary
try_reown() {
  local chkfile="$1"
  # if permission issues and reown fails, warn
  if ! check_file_perms "$chkfile" && ! reown "$chkfile"; then
    error "⚠️ $chkfile is not accessible by stash"
    error "💻 Please run 'chown -$ $CURUSR:$CURGRP $chkfile' on the host to fix this"
    return 1
  fi
}
#}}} /🔑

#{{{🚛 migration helpers
# check if path in key can be migrated
get_config_key() {
  local key="$1"
  local default="$2"
  value=$(yq -r ".$key" "$STASH_CONFIG_FILE")
  if [ "$value" = "null" ]; then
    value="$default"
  fi
  echo "$value"
}
# move and update key to new path
migrate_update() {
  local key="$1"
  local old_path="$2"
  local new_path="$3"
  info "🚚 migrating $key to $new_path"
  # move & reown if old path exists
  [ -e "$old_path" ] && mv -n "$old_path" "$new_path"
  # if doesn't exist, just create and reown
  reown_r "$new_path"
  yq -i ".$key = \"$new_path\"" "$STASHAPP_STASH_CONFIG"
}
# check config value and migrate if possible
check_migrate() {
  local key="$1" # key in yaml config
  local config_path="$2" # new /config path
  local old_root="$3" # old "config" storage directory
  local env_path="$4" # environment variable to override path of
  # get value of key
  local old_path
  old_path=$(yq ."$key" "$STASHAPP_STASH_CONFIG")
  # remove quotes
  old_path="${old_path%\"}"
  old_path="${old_path#\"}"
  # SKIP if not set
  if [ "$old_path" = "null" ]; then
    info "⏩🚛 skip migrating $key" as it is not set
  # SKIP if not in old_root
  elif ! [[ "$old_path" == *"$old_root"* ]]; then
    info "⏩🚛 not migrating $key as it is not in $old_root"
  # SKIP if path is a mount
  elif mountpoint -q "$old_path"; then
    warn "⏩🚛 skip migrating $key as it is a mount"
  # MOVE to path defined in environment variable if mounted
  elif [ -n "$env_path" ] && [ -e "$env_path" ] && mountpoint -q "$env_path"; then
    migrate_update "$key" "$old_path" "$env_path"
  # MOVE to /config if /config is mounted
  elif [ -e "/config" ] && mountpoint -q "/config"; then
    migrate_update "$key" "$old_path" "$config_path"
  # /config not mounted, skip
  else
    warn "🛑🚛 not migrating $key as /config is not mounted"
  fi
}
# detect if migration is needed and migrate
try_migrate() {
  # run if MIGRATE is set
  if [[ "$MIGRATE" == "TRUE" || "$MIGRATE" == "true" ]]; then
    if [ -e "/config/.stash" ]; then
      hotio_stash_migration
    elif [ -e "$STASHAPP_STASH_ROOT" ] && [ -f "$STASHAPP_STASH_CONFIG" ]; then
      stashapp_stash_migration
    else
      warn "⏩🚚 MIGRATE is set, but no migration is needed"
    fi
  # MIGRATE not set but might be needed
  elif [ -e "$STASHAPP_STASH_ROOT" ]; then
    warn "🧩 $STASHAPP_STASH_ROOT exists, but MIGRATE is not set. Running in COMPAT_MODE"
    export STASH_CONFIG_FILE="$STASHAPP_STASH_CONFIG"
  fi
}
# check if permissions for common directories are correct
check_common_perms() {
  info "📋 checking common directory permissions"
  # Check if CONFIG_ROOT is writable
  try_reown "$CONFIG_ROOT" || return 1
  # check if config file exists and is writeable
  if [ -f "$STASH_CONFIG_FILE" ]; then
    try_reown "$STASH_CONFIG_FILE" || return 1
  fi
  # check if envvars are writeable
  local envvars=("$STASH_BLOBS" "$STASH_CACHE" "$STASH_GENERATED")
  for envvar in "${envvars[@]}"; do
    if [ -d "$envvar" ] && ! try_reown_r "$envvar"; then
      return 1
    fi
  done
  info "📋✅ common directories are accessible"
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
  if ! mountpoint -q "$CONFIG_ROOT"; then
    error "🛑🚚 aborting migration from stashapp/stash as $CONFIG_ROOT is not mounted"
    return 1
  fi
  try_reown_r "$CONFIG_ROOT"
  info "🚚 migrating from stashapp/stash"
  # migrate and check all paths in yml
  check_migrate "generated" \
    "$CONFIG_ROOT/generated" "$STASHAPP_STASH_ROOT" \
    "$STASH_GENERATED"
  check_migrate "cache" \
    "$CONFIG_ROOT/cache" "$STASHAPP_STASH_ROOT" \
    "$STASH_CACHE"
  check_migrate "blobs_path" \
    "$CONFIG_ROOT/blobs" "$STASHAPP_STASH_ROOT" \
    "$STASH_BLOBS"
  check_migrate "plugins_path" \
    "$CONFIG_ROOT/plugins" "$STASHAPP_STASH_ROOT"
  check_migrate "scrapers_path" \
    "$CONFIG_ROOT/scrapers" "$STASHAPP_STASH_ROOT"
  check_migrate "database" \
    "$CONFIG_ROOT/stash-go.sqlite" "$STASHAPP_STASH_ROOT"
  # forcefully move config.yml
  mv -n "$STASHAPP_STASH_CONFIG" "$STASH_CONFIG_FILE"
  # forcefully move database backups
  mv -n "$STASHAPP_STASH_ROOT/stash-go.sqlite*" "$CONFIG_ROOT"
  # forcefully move config backups
  mv -n "$STASHAPP_STASH_ROOT/config.yml.*" "$CONFIG_ROOT"
  # forcefully move misc files
  mv -n \
    "$STASHAPP_STASH_ROOT/icon.png" \
    "$STASHAPP_STASH_ROOT/custom.css" \
    "$STASHAPP_STASH_ROOT/custom.js" \
    "$STASHAPP_STASH_ROOT/custom-locales.json" \
    "$CONFIG_ROOT"
  # migrate all other misc files
  info "🚚‼️ leftover files:"
  ls -la "$STASHAPP_STASH_ROOT"
  # reown files
  reown_r "$CONFIG_ROOT"
  # symlink old directory for compatibility
  info "🚚 symlinking $STASHAPP_STASH_ROOT to $CONFIG_ROOT"
  rmdir "$STASHAPP_STASH_ROOT" && \
    ln -s "$CONFIG_ROOT" "$STASHAPP_STASH_ROOT"
}
#}}} /🚚

#{{{🐍 python helpers
# search directory for requirements.txt
search_dir_reqs() {
  local target_dir="$1"
  if [ ! -d "$target_dir" ]; then
    warn "🐍 $target_dir not found, skipping requirement search"
    return 0
  fi
  find "$target_dir" -type f -name "requirements.txt" -print0 | while IFS= read -r -d '' file
  do
    parse_reqs "$file"
  done
}
# parse requirements
parse_reqs() {
  local file="$1"
  info "🐍 Parsing $file"
  printf "\n# %s \n" "$file" >> "$PYTHON_REQS"
  while IFS="" read -r p || [ -n "$p" ]
  do
    [[ "$p" = \#* ]] && continue # skip comments
    read -r -a pkgarg <<< "$p"
    debug "🐍 Adding ${pkgarg[0]} to requirements.txt"
    echo "${pkgarg[0]}" >> "$PYTHON_REQS"
  done < "$file"
}
find_reqs() {
  # check that config.yml exists
  if [ ! -f "$STASH_CONFIG_FILE" ]; then
    warn "🐍 config.yml not found, skipping requirements.txt generation"
    return 0
  fi
  # iterate over plugins and scrapers
  search_dir_reqs "$(get_config_key "plugins_path"  "$CONFIG_ROOT/plugins")"
  search_dir_reqs "$(get_config_key "scrapers_path" "$CONFIG_ROOT/scrapers")"
}
# dedupe requirements.txt
dedupe_reqs() {
  awk '!seen[$0]++' "$PYTHON_REQS" > "$PYTHON_REQS.tmp"
  mv "$PYTHON_REQS.tmp" "$PYTHON_REQS"
}
# install python dependencies
install_python_deps() {
  # copy over /defaults/requirements if it doesn't exist
  if [ ! -f "$PYTHON_REQS" ] || [ ! -s "$PYTHON_REQS" ]; then
    debug "🐍 Copying default requirements.txt"
    cp "/defaults/requirements.txt" "$PYTHON_REQS" && \
      try_reown_r "$PYTHON_REQS"
  fi
  # check permission of requirements.txt
  if ! try_reown_r "$PYTHON_REQS"; then
    error "🐍 requirements.txt is not writeable, skipping search"
  else
    find_reqs
    dedupe_reqs
  fi
  # fix /pip-install directory
  info "🐍 Installing/upgrading python requirements..."
  # UV_CACHE_DIR = /pip-install/cache
  try_reown_r "$UV_TARGET" && \
    try_reown_r "$UV_CACHE_DIR" && \
    runas uv pip install \
      --system \
      --target "$UV_TARGET" \
      --requirement "$PYTHON_REQS"
}
#}}} /🐍

#{{{ misc helpers
# trap exit and error
finish() {
  exit $?
}
# check if local ffmpeg is present
check_ffmpeg() {
  if [ -e "$1/ffmpeg" ] || [ -e "$1/ffprobe" ]; then
    error "💥 ffmpeg/ffprobe is present at $1, this will likely cause issues. Please remove it"
  fi
}
# patch multistream NVENC from keylase/nvidia-patch
patch_nvidia() {
  if [[ $SKIP_NVIDIA_PATCH ]]; then
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
  mkdir -p "$PATCH_OUTPUT_DIR"
  echo "$PATCH_OUTPUT_DIR" > "/etc/ld.so.conf.d/000-patched-lib.conf"
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
  if [ -d "$CERT_PATH" ]; then
    info "🛡️ Installing custom certificates from $CERT_PATH"
    cp -r "$CERT_PATH"/* /usr/local/share/ca-certificates/
    update-ca-certificates
  fi
}
# status of UID and GID changes
user_status() {
  # COMPAT_MODE
  if [ $COMPAT_MODE -eq 1 ]; then
    # running as root since no PUID/PGID access
    if [ "$CURUSR" -eq 0 ]; then
      warn "🧩⚠️ COMPAT_MODE running as root since PUID/PGID missing write/ stat permissions"
    else
      info "🧩🎭 COMPAT_MODE running as $CURUSR:$CURGRP"
    fi
  else
    # running as rootless
    if [ $ROOTLESS -eq 1 ]; then
      info "⏩🎭 Running as docker user, migration and PUID/PGID not possible"
      if ! check_common_perms; then
        error "⛔ Running as rootless, but common directories are not writeable"
        error "💻 Please follow the preceding CHOWN instructions to resolve this"
      fi
    # with root, running as PUID/PGID
    else
      info "🎭 Running as $CURUSR:$CURGRP from PUID/PGID"
      check_common_perms
    fi
  fi
}
#}}}

#{{{ main
trap finish EXIT
# user setup
# check if running in stashapp/stash compatibility mode
if [ -e "$STASHAPP_STASH_ROOT" ] && [[ "$MIGRATE" != "TRUE" ]] && [[ "$MIGRATE" != "true" ]]; then
  COMPAT_MODE=1
  # change UID/GID for test
  CURUSR="$PUID"
  CURGRP="$PGID"
  # check if directories and config file is writeable
  if ! check_file_perms "$STASHAPP_STASH_CONFIG"; then
    # revert changes, warn later
    CURUSR="$(id -u)"
    CURGRP="$(id -g)"
  else
    if [ -n "$AVGID" ]; then
      # add group for AVGID
      addgroup --gid "$AVGID" addl_video
      usermod -a -G addl_video stash
    fi
    # commit PUID/PGID changes
    groupmod -o -g "$PGID" stash
    usermod  -o -u "$PUID" stash
    usermod  -a -G stash stash
  fi
# check if running with or without root
elif [ "$(id -u)" -ne 0 ]; then
  ROOTLESS=1
  CURUSR="$(id -u)"
  CURGRP="$(id -g)"
# if root, use PUID/PGID
else
  ROOTLESS=0
  if [ -n "$AVGID" ]; then
    # add group for AVGID
    addgroup --gid "$AVGID" addl_video
    usermod -a -G addl_video stash
  fi
  groupmod -o -g "$PGID" stash
  usermod  -o -u "$PUID" stash
  usermod  -a -G stash stash
  CURUSR="$PUID"
  CURGRP="$PGID"
fi
# print branding and donation info
cat /opt/branding
cat /opt/donate
# print UID/GID
echo "
───────────────────────────────────────
GID/UID
───────────────────────────────────────
User UID:    $CURUSR
User GID:    $CURGRP
HW Accel:    $HWACCEL"
if [ $ROOTLESS -eq 1 ]; then
  echo "Rootless:    TRUE"
elif [ $COMPAT_MODE -eq 1 ]; then
  echo "stashapp/stash mode: TRUE"
fi
echo '
───────────────────────────────────────
entrypoint.sh

'
user_status
try_migrate
install_python_deps
patch_nvidia
install_custom_certs
# danger if ffmpeg present locally
check_ffmpeg "$CONFIG_ROOT"
check_ffmpeg "$STASHAPP_STASH_ROOT"
# finally start stash
echo '
Starting stash...
───────────────────────────────────────
'
trap - EXIT
runas '/app/stash' '--nobrowser'
#}}}