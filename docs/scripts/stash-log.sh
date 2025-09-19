#!/bin/sh
# AGPL-3.0-or-later	OR MIT © feederbox826
# version 1.0

# log: creates log messages in stash log
# Usage:
#   log <level> <message>
#   d <message>
#   i <message>
#   w <message>
#   e <message>
# set APP_NAME to customize the prefix (default: script filename)

# log_proxy: redirects stdout/ stederr to stash logger
# Usage:
#   some_command 2>&1 | log_proxy <level>


# feederbox826 | MIT or AGPL3 | https://u.feederbox.cc/stash-log | v1.0
APP_NAME=${APP_NAME:-$(basename "$0")}
log() { level="$1"; shift; printf >&2 "\001%s\002%s: %s\n" "$level" "$APP_NAME" "$*"; }
log_proxy() { while IFS= read -r line; do log "$1" "$line"; done }