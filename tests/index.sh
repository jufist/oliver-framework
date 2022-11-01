#!/bin/bash

# Test: MP_two=222 MA_extra=xx ./index.sh --test --version=x 11
SCRIPT=$(readlink -f "$0")
# No sym
# SCRIPT=`realpath -s $0`
SCRIPTPATH=$(dirname $SCRIPT)
WORKINGDIR=$(pwd)
MYHOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

shopt -s expand_aliases

export DEBUG=${DEBUG:-"*"}

vars_parse--test() {
  definedargs=("v|version*" "e|extra")
  definedparams=("one*" "two")
  inputargs=("$@")
  myargs inputargs definedargs definedparams
  [[ "$?" != "0" ]] && return 1
  set -- "${newargs[@]}"

  RESTARGS=("$@")
}

exec--test() {
  # Use rest parameters by RESTARGS instead of $@ normally here or override $@ by following command
  set -- "${RESTARGS[@]}"
  echo "Param: $MP_one"
  echo "Arg version: $MA_version"
  echo "Main"
  echo "Ensure variable to rest: MA_extra: $MA_extra MP_two: $MP_two"
  exit
}

. ../bash/common.sh
oliver-common-exec --check-existed '$M0 $M1' "$@"
