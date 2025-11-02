#!/usr/bin/with-contenv bash
# shellcheck shell=bash

# simple logger
# AGPL-3.0-or-later	© feederbox826
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
  # write to local file for debugging
  echo "[${_LEVEL_TEXT[$1]}][$date_text] $2" >> /config/stash-s6.log
}

debug () { log 0 "$*"; }
info  () { log 1 "$*"; }
warn  () { log 2 "$*"; }
error () { log 3 "$*"; }