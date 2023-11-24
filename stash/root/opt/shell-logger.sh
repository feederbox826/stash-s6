#!/usr/bin/env bash

## Description {{{
#
# Logger for shell script.
#
# Homepage: https://github.com/rcmdnk/shell-logger
# Forked for stash: https://github.com/feederbox826/shell-logger
#
_LOGGER_NAME="shell-logger"
_LOGGER_VERSION="v0.2.1"
_LOGGER_DATE="04/Feb/2019"
# }}}

## License {{{
#
#MIT License
#
#Copyright (c) 2017 rcmdnk
#
#Permission is hereby granted, free of charge, to any person obtaining a copy
#of this software and associated documentation files (the "Software"), to deal
#in the Software without restriction, including without limitation the rights
#to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#copies of the Software, and to permit persons to whom the Software is
#furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all
#copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#SOFTWARE.
# }}}

# Default variables {{{
LOGGER_DATE_FORMAT=${LOGGER_DATE_FORMAT:-'%Y-%m-%d %H:%M:%S'}
LOGGER_LEVEL=${LOGGER_LEVEL:-1} # 0: debug, 1: info, 2: warning, 3: error
LOGGER_STDERR_LEVEL=${LOGGER_STDERR_LEVEL:-4}
LOGGER_DEBUG_COLOR=${LOGGER_DEBUG_COLOR:-"37"}
LOGGER_INFO_COLOR=${LOGGER_INFO_COLOR:-"36"}
LOGGER_WARNING_COLOR=${LOGGER_WARNING_COLOR:-"33"}
LOGGER_ERROR_COLOR=${LOGGER_ERROR_COLOR:-"31"}
LOGGER_COLOR=${LOGGER_COLOR:-auto}
LOGGER_COLORS=("$LOGGER_DEBUG_COLOR" "$LOGGER_INFO_COLOR" "$LOGGER_WARNING_COLOR" "$LOGGER_ERROR_COLOR")
if [ "${LOGGER_LEVELS:-}" = "" ];then
  LOGGER_LEVELS=("DEBUG" "INFO" "WARN" "ERR")
fi
LOGGER_SHOW_TIME=${LOGGER_SHOW_TIME:-1}
LOGGER_SHOW_FILE=${LOGGER_SHOW_FILE:-1}
LOGGER_SHOW_LEVEL=${LOGGER_SHOW_LEVEL:-1}
LOGGER_ERROR_RETURN_CODE=${LOGGER_ERROR_RETURN_CODE:-100}
LOGGER_ERROR_TRACE=${LOGGER_ERROR_TRACE:-1}
# }}}

# Other global variables {{{
_LOGGER_WRAP=0
#}}}

# Functions {{{
_logger_version () {
  printf "%s %s %s\\n" "$_LOGGER_NAME" "$_LOGGER_VERSION" "$_LOGGER_DATE"
}

_get_level () {
  if [ $# -eq 0 ];then
    local level=1
  else
    local level=$1
  fi
  if ! expr "$level" : '[0-9]*' >/dev/null;then
    [ -z "${ZSH_VERSION:-}" ] || emulate -L ksh
    local i=0
    while [ $i -lt ${#LOGGER_LEVELS[@]} ];do
      if [ "$level" = "${LOGGER_LEVELS[$i]}" ];then
        level=$i
        break
      fi
      ((i++))
    done
  fi
  echo $level
}

_logger_level () {
  [ "$LOGGER_SHOW_LEVEL" -ne 1 ] && return
  if [ $# -eq 1 ];then
    local level=$1
  else
    local level=1
  fi
  [ -z "${ZSH_VERSION:-}" ] || emulate -L ksh
  printf "${LOGGER_LEVELS[$level]}"
}

_logger_time () {
  [ "$LOGGER_SHOW_TIME" -ne 1 ] && return
  printf "[$(date +"$LOGGER_DATE_FORMAT")]"
}

_logger_file () {
  [ "$LOGGER_SHOW_FILE" -ne 1 ] && return
  local i=0
  if [ $# -ne 0 ];then
    i=$1
  fi
  if [ -n "$BASH_VERSION" ];then
    printf "[${BASH_SOURCE[$((i+1))]}:${BASH_LINENO[$i]}]"
  else
    emulate -L ksh
    printf "[${funcfiletrace[$i]}]"
  fi
}

_logger () {
  ((_LOGGER_WRAP++)) || true
  local wrap=${_LOGGER_WRAP}
  _LOGGER_WRAP=0
  if [ $# -eq 0 ];then
    return
  fi
  local level="$1"
  shift
  if [ "$level" -lt "$(_get_level "$LOGGER_LEVEL")" ];then
    return
  fi
  local msg_prefix="$(_logger_time)$(_logger_file "$wrap")"
  local msg="${msg_prefix:+$msg_prefix }$*" # add prefix with a space only if prefix not is empty
  msg="${msg/\$/\\\$}" # escape $ is msg to be able to use eval below without trying to resolve a variable
  local _logger_printf=printf
  local out=1
  if [ "$level" -ge "$LOGGER_STDERR_LEVEL" ];then
    out=2
    _logger_printf=">&2 printf"
  fi
  if [ "$LOGGER_COLOR" = "always" ] || { test "$LOGGER_COLOR" = "auto"  && test  -t $out ; };then
    [ -z "${ZSH_VERSION:-}" ] || emulate -L ksh
    eval "$_logger_printf \"\\e[${LOGGER_COLORS[$level]}m$(_logger_level "$level")\\e[m%s\\n\"  \"$msg\""
  else
    eval "$_logger_printf \"%s\\n\" \"$msg\""
  fi
}

debug () {
  ((_LOGGER_WRAP++)) || true
  _logger 0 "$*"
}

information () {
  ((_LOGGER_WRAP++)) || true
  _logger 1 "$*"
}
info () {
  ((_LOGGER_WRAP++)) || true
  information "$*"
}

warning () {
  ((_LOGGER_WRAP++)) || true
  _logger 2 "$*"
}
warn () {
  ((_LOGGER_WRAP++)) || true
  warning "$*"
}

error () {
  ((_LOGGER_WRAP++)) || true
  _logger 3 "$*"
  return "$LOGGER_ERROR_RETURN_CODE"
}
err () {
  ((_LOGGER_WRAP++)) || true
  error "$*"
}
# }}}
