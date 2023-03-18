#!/bin/bash

DEBUG=${DEBUG:-""}
[[ "$1" == "--debug" ]] && {
  DEBUG="yes"
  shift
}

[ -f $1 ] && {
  file=$1
  id="/tmp/cmd.$(date +%s)"

  # trap 'kill %1; kill %2' SIGINT
  cmd="trap '"$(cat $file | jq -r 'to_entries | map("kill %" + ( .key + 1 | tostring)) | join ("; ")')"' SIGINT"
  echo "$cmd" >${id}
  # [x] command1 | tee 1.log | sed -e 's/^/[Command1] /' & command2 | tee 2.log | sed -e 's/^/[Command2] /' & command3 | tee 3.log | sed -e 's/^/[Command3] /'
  cmd=$(cat $file | jq -r $'to_entries | map("bash -c \'" + (.value | tojson | .[1:-1] ) + "\' | tee " + (.key|tostring) + ".log" + " | sed -e " + ("s/^/[Command" + (.key|tostring) + "] /" | tojson)) | join (" & ")')"& wait"
  echo "$cmd" >>${id}
  chmod +x ${id}
  [[ "$DEBUG" != "" ]] && {
    echo "[DEBUG] $id"
    exit 0
  }
  ${id}
  rm ${id}
}
