#!/usr/bin/with-contenv ash
# shellcheck shell=ash

## environment variables
# MIGRATE
# SKIP_CHOWN
# SKIP_NVIDIA_PATCH
# PUID
# PGID

# setup UID/GID
PUID=${PUID:-911}
PGID=${PGID:-911}
UMASK=${UMASK:-002}

###
# FUNCTIONS
###

reown() {
  if [ -n "$SKIP_CHOWN" ]; then
    return
  fi
  chown -Rh stash:stash "$1"
  chmod -R "=rwx" "$1"
}

mkown() {
  mkdir -p "$1"
  reown "$1"
}

check_path_mounted() {
  return "$(mount | grep "$1")"
}

## migration helpers
# move and update key to new path
migrate_update() {
  KEY="$1"
  OLD_PATH="$2"
  NEW_PATH="$3"
  mv "$OLD_PATH" "$NEW_PATH"
  reown "$NEW_PATH"
  yq -i ".${KEY} = \"${NEW_PATH}\"" "${CONFIG_YAML}"
}

# check and migrate
check_migrate() {
  KEY="$1" # key in yaml config
  CONFIG_PATH="$2" # new /config path
  OLD_CONFIG_ROOT="$3" # old "config" storage directory
  ENV_PATH="$4" # environment variable to check path of
  # get value of key
  OLD_PATH=$(yq ."$KEY" "${CONFIG_YAML}")
  # remove quotes
  OLD_PATH="${OLD_PATH%\"#\"}"
  # if not set, skip
  if [ "$OLD_PATH" = "null" ]; then
    echo "not migrating $KEY" as it is not set
    return 1
  # only touch files in OLD_CONFIG_ROOT
  elif [ "$(test "${OLD_PATH#*"$OLD_CONFIG_ROOT"}" != "$OLD_PATH")" -ne 0 ]; then
    echo "not migrating $KEY as it is not in /root/.stash"
    return 1
  # check if path is a mount
  elif [ "$(mount | grep "$OLD_PATH")" -eq 0 ]; then
    echo "not migrating $KEY as it is a mount"
    return 1
  # move to path defined in environment variable if it is mounted
  elif [ -e "$ENV_PATH" ] && [ "$(check_path_mounted "$ENV_PATH")" -eq 0 ]; then
    echo "migrating $KEY to $ENV_PATH"
    migrate_update "$KEY" "$OLD_PATH" "$ENV_PATH"
    return 0
  # move to /config if /config is mounted
  elif [ -e "/config" ] && [ "$(check_path_mounted "/config")" -eq 0 ]; then
    echo "migrating $KEY to $CONFIG_PATH"
    migrate_update "$KEY" "$OLD_PATH" "$CONFIG_PATH"
    return 0
  else
    echo "not migrating $KEY as /config is not mounted"
    return 1
  fi
}

hotio_stash_migration() {
  echo "migrating from hotio/stash"
  # hotio doesn't need file migrations, just delete symlinks from .stash
  unlink "/config/.stash/ffmpeg"
  unlink "/config/.stash/ffprobe"
  rmdir "/config/.stash" # remove .stash at the very end
}

stashapp_stash_migration() {
  echo "migrating from stashapp/stash"
  CONFIG_ROOT="/root/.stash"
  CONFIG_YAML="$CONFIG_ROOT/config.yml"
  # check for /generated mount
  echo "migrating generated"
  check_migrate "generated" "/config/generated" "$CONFIG_ROOT" "$STASH_GENERATED"
  echo "migrating cache"
  check_migrate "cache" "/config/cache" "$CONFIG_ROOT" "$STASH_CACHE"
  echo "migrating blobs"
  check_migrate "blobs" "/config/blobs" "$CONFIG_ROOT" "$STASH_BLOBS"
  echo "migrating plugins"
  check_migrate "plugins_path" "/config/plugins" "$CONFIG_ROOT"
  echo "migrating scrapers"
  check_migrate "scrapers_path" "/config/scrapers" "$CONFIG_ROOT"
  echo "migrating database"
  check_migrate "database" "/config/stash-go.sqlite" "$CONFIG_ROOT"
  # migrate all other misc files
  echo "moving leftover files"
  mv "$CONFIG_ROOT/*.*" "/config/"
  # reown files
  reown "/config"
  # symlink old directory for compatibility
  echo "symlinking $CONFIG_ROOT to /config"
  rmdir "$CONFIG_ROOT"
  ln -s "/config" "$CONFIG_ROOT"
}

try_migrate() {
  if [ -n "$MIGRATE" ]; then
    if [ -e "/config/.stash" ]; then
      hotio_stash_migration
    elif [ -e "/root/.stash" ] && [ -f "/root/.stash/config.yml" ]; then
      stashapp_stash_migration
    fi
  else
    if [ -e "/config/.stash" ]; then
      echo "WARNING: /config/.stash exists, but MIGRATE is not set. This may cause issues."
      export STASH_CONFIG_FILE="/config/.stash/config.yml"
    fi
  fi
}

patch_nvidia() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "Skipping nvidia patch as it requires root"
    return 0
  fi
  wget -qNO /usr/local/bin/patch.sh https://raw.githubusercontent.com/keylase/nvidia-patch/master/patch.sh
  chmod "+x" /usr/local/bin/patch.sh
  # copied from https://github.com/keylase/nvidia-patch/blob/master/docker-entrypoint.sh
  mkdir -p "/patched-lib"
  echo "/patched-lib" > /etc/ld.so.conf.d/000-patched-lib.conf
  PATCH_OUTPUT_DIR=/patched-lib /usr/local/bin/patch.sh
  cd /patched-lib || exit
  for f in * ; do
    suffix="${f##*.so}"
    name="$(basename "$f" "$suffix")"
    [ -h "$name" ] || ln -sf "$f" "$name"
    [ -h "$name" ] || ln -sf "$f" "$name.1"
  done
  ldconfig
}

check_chown() {
  CHKDIR="$1"
  if [ ! -w "$CHKDIR" ]; then
    if [ "$(touch ".test" 2>&1 | grep -c "Permission denied")" -eq 1 ]; then
      if [ -n "$SKIP_CHOWN" ]; then
        echo "WARNING: $CHKDIR is not writable by stash user and SKIP_CHOWN is set"
        echo "Please run 'chown -R $(id -u stash):$(id -g stash) $CHKDIR' to fix this"
        exit 1
      elif [ "$(id -u)" -eq 0 ]; then
        echo "WARNING: $CHKDIR is not writable by stash"
        echo "Attempting to fix permissions..."
        chown -R stash:stash "$CHKDIR"
        rm "$CHKDIR/.test"
      else
        echo "WARNING: $CHKDIR is not writable by stash"
        echo "Please run 'chown -R $(id -u stash):$(id -g stash) $CHKDIR' to fix this"
        exit 1
      fi
    fi
  fi
}

install_python_deps() {
  # copy over default /requirements if it doesn't exist
  if [ ! -f "/config/requirements.txt" ]; then
    echo "Copying default requirements.txt"
    chown "stash:stash" "/defaults/requirements.txt"
    cp "/defaults/requirements.txt" "/config/requirements.txt"
  fi
  # fix /pip-install directory
  echo "Installing/upgrading python requirements..."
  check_chown "/pip-install" &&
    su-exec stash pip3 install --upgrade -q --exists-action i --target "$PIP_INSTALL_TARGET" -r /config/requirements.txt
  export PYTHONPATH="$PYTHONPATH:$PIP_INSTALL_TARGET"
}

###
# SCRIPT START
###

groupmod -o -g "$PGID" stash
usermod -o -u "$PUID" stash

# print branding and donation info
cat /opt/branding
cat /opt/donate
# print UID/GID
echo '
───────────────────────────────────────
GID/UID
───────────────────────────────────────'
echo "
User UID:    $(id -u stash)
User GID:    $(id -g stash)
───────────────────────────────────────
"
echo "Hardware Acceleration image support: $HWACCEL"

# run migrations if desired
try_migrate

# set up and install python dependencies
install_python_deps

# create and own directories
echo "Creating Directories"
# check if /config permissions are dubious
check_chown "/config"

# download and run nvidia patch
if [ -z "$SKIP_NVIDIA_PATCH" ]; then
  patch_nvidia
fi

# finally start stash
if [ "$(id -u)" -ne 0 ]; then
  echo "Starting stash as $(id -u):$(id -g)"
  /app/stash --nobrowser
else
  echo "Starting stash as stash ($(id -u stash):$(id -g stash))"
  su-exec stash /app/stash --nobrowser
fi