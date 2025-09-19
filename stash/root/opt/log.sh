#!/usr/bin/env bash
# shellcheck shell=bash
#
# Author: feederbox826
# Path: /opt/log.sh
# Description: Simple logger script to emulate stash
# License: AGPL-3.0
_COLORS=("37" "36" "33" "31")
_LEVEL_TEXT=("DEBU" "INFO" "WARN" "ERRO")
LOGGER_LEVEL=${LOGGER_LEVEL:-1}

log() {
  # if level < LOGGER_LEVEL, ignore
  [ "$1" -lt "$LOGGER_LEVEL" ] && return
  local date_text
  printf -v date_text '%(%Y-%m-%d %H:%M:%S)T' -1
  # output to stderr if >= WARN
  local out=$(($1>=2?2:1))
  printf "\e[%sm%s\e[0m[%s] %s\n" "${_COLORS[$1]}" "${_LEVEL_TEXT[$1]}" "$date_text" "$2" >&"$out"
}

debug () { log 0 "$*"; }
info  () { log 1 "$*"; }
warn  () { log 2 "$*"; }
error () { log 3 "$*"; }