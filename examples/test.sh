#!/bin/bash

exec--test() {
  echo "Testing calls $@"
}

exec--main() {
  echo "Arguments: ${@}"
  echo "End"
  local cmd=`basename $0`
  declare -F | grep exec-- | sed 's/declare -f exec/'$cmd' /'
  echo $OLIVERDIR
}

vars_parse--add() {
  FORMUSERNAME="$1"
  FORMPWD="$2"
}

vars_verify--add() {
  if [[ "$FORMUSERNAME" == "" || "$FORMPWD" == "" ]]; then
    echo "[Error] Please verify your input data"
    exit 1
  fi
}

exec--add() {
  echo "Main calls"
  echo "$@"
}

. ../bash/common.sh
oliver-common-exec --check-existed '$M0 $M1' "$@"
