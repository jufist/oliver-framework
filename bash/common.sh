#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
. ${SCRIPT_DIR}/auto.sh
OLIVER_DIR="$(dirname ${SCRIPT_DIR})"

uri_escape() {
  echo "$@" | ${OLIVER_DIR}/scripts/urlencode
}

# P1. Convert star since assign like will cause asterisk to expand
function asterisk() {
  local data
  while read -r data; do
    [[ "$1" == "encode" ]] && {
        echo "$data" | sed 's~*~ @ST@R ~g'
    }
    [[ "$1" == "decode" ]] && {
        echo "$data" | sed 's~ @ST@R ~*~g'
    }
  done
}

function jsonmerge() {
  jq -s 'def deepmerge(a;b):
  reduce b[] as $item (a;
    reduce ($item | keys_unsorted[]) as $key (.;
      $item[$key] as $val | ($val | type) as $type | .[$key] = if ($type == "object") then
        deepmerge({}; [if .[$key] == null then {} else .[$key] end, $val])
      elif ($type == "array") then
        (.[$key] + $val | unique)
      else
        $val
      end)
    );
  deepmerge({}; .)' $@
}

funclock() {
  local lockName lockFile lockParam timeout ss
  local uniqueFN
  lockParam=$1
  shift
  timeout=$1
  shift
  lockName="$(printf "%s\n" "${lockParam^^}" | tr -cd '[:alnum:]\n' | xargs)"
  lockFile="/tmp/lock.${lockName:-noname}"
  touch /tmp/lock.alls
  uniqueFN=$(cat /tmp/lock.alls | grep -F -- "$lockFile" | cut -d '|' -f 1)
  [[ "$uniqueFN" == "" ]] && {
    uniqueFN=$(mktemp /tmp/lock.XXXXXXXXXXXX)
    echo "$uniqueFN|$lockFile" >> /tmp/lock.alls
  }
  lockFile="$uniqueFN"
  (
      while ! flock -n 9
      do
        echo -en "\rFunclock waiting ${timeout}." >&2
        # echo -n "." >&2
        sleep 1
        timeout=$((timeout-1))
        # To check timeout
        [[ "$timeout" == "0" ]] && return 9
      done

      basheval "$@"
      return $?
  ) 9>"$lockFile"
  ss=$?

  if [ $ss -eq 9 ]
  then
      echo "Failed to acquire lock $lockFile" >&2
  fi

  # Remove the lock file
  rm "$lockFile"

  return $ss
}

function textBetweenTag() {
  local tag=$2
  echo "$1" | sedd -n "/<$tag/,/\/$tag>/p"
}

function addQuote() {
  local C=''
  local i
  for i in "$@"; do
    i="${i//\\/\\\\}"
    C="$C \"${i//\"/\\\"}\""
  done
  echo "$C"
}

seddable() {
  echo "$1" | sed '$!s/$/\\/' | sed 's/\//\\\//g' | sed "s/\&/\\\&/g"
}

addSingleQuote() {
  echo "$1" | sed 's/\\/\\\\/g'
}

filter_object() {
  local content search exp
  content=$(</dev/stdin)
  exp=$1
  echo "$content" | node -e "let out=require('fs').readFileSync(0, 'utf-8');
let _orig = out;
let obj = out;
try {
  out=JSON.parse(out);
}
catch (e) {
  console.error('Cannot convert array')
  console.error(_orig);
  out=[];
}
obj=out;
$exp
console.log(JSON.stringify(obj));
"
}

replace_vianode() {
  local content search replace raw
  content=$(</dev/stdin)
  search=$(addSingleQuote "$1")
  replace=$2
  raw=$3
  echo "$content" | node -e "
	search=process.argv[1];
	replace=process.argv[2];
	raw=process.argv[3];
	// process.stderr.write(search);
	// console.error([search, replace]);
      let content=require('fs').readFileSync(0, 'utf-8');
      if (!raw) {
        let re = new RegExp(search, 'g');
        content = content.replace(re, replace);
      }
    else {
        content = content.replace(search, replace);
    }
	    process.stdout.write(content);
    " "$search" "$replace" "$raw"
}

# remove specified host from /etc/hosts
function removehost() {
  if [[ "$1" ]]; then
    HOSTNAME=$1

    if [ -n "$(grep $HOSTNAME /etc/hosts)" ]; then
      ech "log" "$HOSTNAME Found in your /etc/hosts, Removing now..."
      sudo sed -i".bak" "/$HOSTNAME/d" /etc/hosts
    else
      ech "log" "$HOSTNAME was not found in your /etc/hosts"
    fi
  else
    ech "error" "Error: missing required parameters."
    ech "error" "Usage: "
    ech "error" "  removehost domain"
  fi
}

#add new ip host pair to /etc/hosts
function addhost() {
  if [[ "$1" && "$2" ]]; then
    IP=$1
    HOSTNAME=$2
    OVERWRITE=${3:-"0"}

    if [[ "$OVERWRITE" == "0" && -n "$(grep $HOSTNAME /etc/hosts)" ]]; then
      ech "error" "$HOSTNAME already exists:"
      ech "error" $(grep $HOSTNAME /etc/hosts)
    else
      removehost "$HOSTNAME"
      ech "log" "Adding $HOSTNAME to your /etc/hosts"
      printf "%s\t%s\n" "$IP" "$HOSTNAME" | sudo tee -a /etc/hosts >/dev/null

      if [ -n "$(grep $HOSTNAME /etc/hosts)" ]; then
        echo "$HOSTNAME was added succesfully:"
        echo $(grep $HOSTNAME /etc/hosts)
      else
        echo "Failed to Add $HOSTNAME, Try again!"
      fi
    fi
  else
    echo "Error: missing required parameters."
    echo "Usage: "
    echo "  addhost ip domain"
  fi
}

forceup() {
  ech "log" "[Ok] Service up"
  if [ "$TEST" != "1" ]; then
    include/folderexec.sh up
  else
    ech "notice" "[Notice] Ignore executing by option -t"
  fi
}

forcedown() {
  echo "[Error] Service down"
  if [ "$TEST" != "1" ]; then
    include/folderexec.sh down
  else
    echo "[Notice] Ignore executing by option -t"
  fi
}

iptablekill() {
  ip=$2
  type=$1
  linenumber=$(sudo iptables -L $type --line-numbers | grep -F "$ip" | head -1 | awk '{print $1}')
  if [ "$linenumber" != "" ]; then
    sudo iptables -D $type $linenumber
    # Continue erasing until finishing
    iptablekill $type $ip
  fi
}

rootcheck() {
  if [ $(id -u) != "0" ]; then
    sudo "$0" "$@" # Modified as suggested below.
    exit $?
  fi
}

myhelp() {
  # TODO
  echo ""
}

sshexec() {
  local sshhost=$1
  local sshscript=$2
  ssh $sshhost "bash -s" -- --time "bye" <"$sshscript"
}

mongoexec() {

  # Mongo access
  mongocmd="mongo --port ${mongo[port]}"
  if [ ${mongo[ignore_auth]} != 1 ]; then
    mongocmd="mongo --port ${mongo[port]} -u ${mongo[user]} -p ${mongo[password]}"
  fi

  #if [ ${mongo[authenticationDatabase]} != 1 ] ; then
  #	mongocmd+=" --authenticationDatabase '${mongo[authenticationDatabase]}'"
  #fi

  if [ ${mongo[authenticationDatabase]} != "" ]; then
    mongocmd+=" --authenticationDatabase ${mongo[authenticationDatabase]}"
  fi

  queries=$mongoexecqueries
  queries+="\nexit\n"
  #echo -e "$queries"
  outp=$(echo -e "$queries" | $mongocmd)
}

sitetodo() {
  if [ "$site" == "dr" ]; then
    drhosts=("${dchosts[@]}")
    dbarbiter=$dcarbiter
    drbctmp=("${drbc[@]}")
    drbc=("${bc[@]}")
    bc=("${drbctmp[@]}")
    dr=("${dc[@]}")
  fi
}

myconfirm() {
  read -p "Afraid? [Nn}" -n 1 -r
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    #
    echo ""
    echo "Good bye"
    exit 1
  fi
}

# How to use:
# definedargs=("l|local" "r|rsync")
# definedparams=("one", "two")
# inputargs=("$@")
# myargs inputargs definedargs
# Now we have:
# Using: $MA_local and MP_one
# Also we have ${newargs[@]}
# inputargs=("$@")
# definedargs=("n|number", "s|sudo", "p|path")
# definedparams=("one", "two")
# myargs inputargs definedargs 
# set -- "${newargs[@]}"
myargs() {
  local isV4
  isV4="$(bash --version | grep version | grep -F "4." | grep -vF "4.4" | wc -l)"
  [ "$isV4" == "1" ] && {
    echo "Please upgrade bash to 5" >&2
    local arr
    eval "arr=(\${$1[@]})"
    local args
    eval "args=(\${$2[@]})"
    local params
    eval "params=(\${$3[@]})"
  }
  [ "$isV4" == "1" ] || {
    local -n arr=$1
    local -n args=$2
    local -n params=${3:-"no"}
  }
  local short=""
  local long=""
  local varname="x"
  export newargs=()
  local found=""
  local i
  local j
  local more
  # Reset 
  for j in "${args[@]}"; do
    [[ "${j: -1}" == "*" ]] && {
      j=${j::-1}
    }

    short="$(echo $j | cut -d'|' -f1)"
    long="$(echo $j | cut -d'|' -f2 | sed 's/[-]/_/g')"
    varname="MA_$long"
    export "$varname="
  done

  for j in "${params[@]}"; do
    [[ "${j: -1}" == "*" ]] && {
      j=${j::-1}
    }

    export "MP_$j="
  done

  for i in "${arr[@]}"; do
    found=""
    for j in "${args[@]}"; do
      [[ "${j: -1}" == "*" ]] && {
        j=${j::-1}
      }

      short="$(echo $j | cut -d'|' -f1)"
      long="$(echo $j | cut -d'|' -f2)"
      # echo "$short:$long"
      case $i in
      -$short | --$long | -$short=* | --$long=*)
        varname="MA_$long"
        varname=$(echo "$varname" | sed 's/[-]/_/g' | sed 's/[^0-9a-zA-Z_]//g')
        export "$varname=${i#*=}"
        found="yes"
        ;;
      esac
    done

    # If not found
    if [[ "$found" == "" ]]; then
      newargs+=("${i}")
    fi
  done

  i=0
  for j in "${params[@]}"; do
    [[ "${j: -1}" == "*" ]] && {
      j=${j::-1}
    }

    export "MP_$j=${newargs[$i]}"
    i=$((i+1))
  done

  # Required arguments
  for j in "${args[@]}"; do
    more=""
    [[ "${j: -1}" == "*" ]] && {
      more="required"
      j=${j::-1}
    }
    short="$(echo $j | cut -d'|' -f1)"
    long="$(echo $j | cut -d'|' -f2)"
    varname="MA_$long"
    eval "i=\$$varname"
    [[ "$more" == "required" ]] && {
      [[ "$i" == "" ]] && echo "Please fill --$long=..." && return 1
    }
  done

  # Required params
  for j in "${params[@]}"; do
    more=""
    [[ "${j: -1}" == "*" ]] && {
      more="required"
      j=${j::-1}
    }
    long="$j"
    varname="MP_$long"
    eval "i=\$$varname"
    [[ "$more" == "required" ]] && {
      [[ "$i" == "" ]] && echo "Please enter param to $0 ..." && return 1
    }
  done
  return 0
}

preventExist() {
  arg=$1
  shift
  export M0="$0"
  export M1="$1"
  export M2="$2"
  export M3="$3"
  printarg=$(echo "$arg" | envsubst | xargs)
  u=$(whoami)
  d=$(ps aux)
  e=$(echo "$d" | grep "$u" | grep -- "$printarg" | grep -v "$PPID" | grep -v "grep " | grep -v -e "^[[:space:]]*$" | wc -l)

  if [ "$e" -gt "1" ]; then
    echo "[Error] Someone is running this process but this allows to run only one instance at a time. Please try again later!"
    exit 1
  fi
}

is_valid_number() {
  case "$1" in
  [1-9][0-9][0-9]-[0-9][0-9][0-9]-[0-9][0-9][0-9][0-9])
    return 0
    ;;
  *)
    return 1
    ;;
  esac
}

verify_phone() {
  if ! [[ "$1" =~ ^[0-9]{6,13}$ ]]; then
    echo "[Error] Verify your phone number $1"
    exit
  fi
}

fn_exists() { test x$(type -t $1) = xfunction; }

exechelplist() {
  local cmd=$(basename $0)
  local funcs=($(declare -F | grep exec-- | sed 's/declare -f exec//'))
  local i
  for i in "${funcs[@]}"; do
    local cmd2="$cmd $i"
    echo "------------"
    echo "$cmd2"
    i="vars_parse$i"
    ! fn_exists $i && continue
    local def=$(type $i)
    echo ""
    echo "$def" | grep 'defined'
    echo "$def" | grep -F "\$" | grep -v -F "\$@"
  done
}

urldecode() {
  : "${*//+/ }"
  echo -e -n "${_//%/\\x}"
}

base64fix() {
  if [[ "$1" == "--base64" ]]; then
    local s
    s=$(echo $2 | base64 -d | jq -r '.[] | "echo -e \"$(urldecode \"\(.)\")\" ; echo -n \" \" "')
    s="${s//\!/\\\!}"

    # Debug
    # echo "Extracted arguments:" >&2
    # echo "$s" >&2
    # eval "$s" | sed 's/\\\!/\!/g' >&2

    eval "$s" | sed 's/\\\!/\!/g'
    return 0
  fi
  return 1
}

evalable() {
  local s
  s=$@
  s="${s//\`/\\\`}"
  s="${s//\$/\\\$}"
  s="${s//\!/\\\!}"
  echo "${s[@]}"
}

oliver-common-exec() {
  SETUPDIR=$(dirname $(realpath "$0"))
  if [[ "$1" == "--check-existed" ]]; then
    arg=$2
    shift
    shift
    preventExist "$arg" "$@"
  fi

  local x
  local s
  local sr
  s=$(base64fix "$@")
  sr=$?
  eval "x=( $(evalable "$s" | sed 's/\\\!/\!/g') )"

  # Debug
  # echo "$s">&2
  # echo "0:">&2
  # echo "${x[0]}">&2
  # echo "2:">&2
  # echo "${x[2]}">&2
  # echo "All:">&2
  # echo "${x[@]}">&2
  # exit 1
  if [[ "${sr}" == "0" ]]; then
    set -- "${x[@]}"
  fi

  action="$1"
  local fullaction="exec$action"
  if [[ $action =~ "--" ]] && fn_exists "exec$action"; then
    shift
  else
    action="--main"
  fi

  if [[ "$fullaction" == "exec--help" ]] && ! fn_exists "$fullaction"; then
    fullaction="exechelplist"
    action="--help"
  else
    fullaction="exec$action"
  fi

  local cd
  parseaction="vars_parse$action"
  fn_exists $parseaction && {
    $parseaction "$@"
    [[ "$?" != "0" ]] && return 1
  }

  verifyaction="vars_verify$action"
  fn_exists $verifyaction && $verifyaction "$@"

  action="exec$action"
  local ret
  fn_exists $fullaction && $fullaction "$@"
  ret=$?
  fn_exists $fullaction || exechelplist
  return $ret
}

execIET() {
  local item=$1
  local callback=$2
  local command=$3
  local user=$4
  local dry_run=$5
  local shellarg=$6
  local localenv=$7
  local simulate=$8
  [[ "$command" == "" ]] && command="/bin/bash"

  [[ "$simulate" != "" ]] && {
    genKey --init --raw "String ssh $shellarg $item"
    genKey Return
    genKey --raw Delay 3
    genKey --raw "String ${localenv}$command"
    genKey Return
    command="playKey --nohup"
  }
  [[ "$simulate" == "" ]] && {
    if [[ "$user" == "" ]]; then
      command="ssh $shellarg $item '${localenv}$command'"
    else
      # Allow other users to run, not just root
      # "sudo -s su kazoo -c '
      command="ssh $shellarg $item 'sudo -s su $user -c \"${localenv}${command}\"'"
    fi
  }

  ech "log" "[Exec] $command"
  [[ "$dry_run" == "" ]] && eval $command
  [[ "$dry_run" != "" ]] && ech log $command
}

execIETdocker() {
  local item=$1
  local callback=$2
  local command=$3
  local user=$4
  local dry_run=$5
  local shellarg=$6
  local localenv=$7
  local dcommand
  local arg
  arg="-i"

  if [[ "$callback" == "" ]]; then
    ech "log" "[docker] Docker to $item"
    arg="-ti"
  fi
  ech "log" "[exec] $command $localenv"
  if [[ "$user" == "" ]]; then
    [ "$command" == "" ] && dcommand="docker exec $arg $shellarg $item /bin/bash -c '${localenv}\$SHELL'"
    [ "$command" != "" ] && dcommand="docker exec $arg $shellarg $item /bin/bash -c '${localenv}$command'"
    command="${dcommand}"
  else
    # Allow other users to run, not just root
    # "sudo -s su kazoo -c '
    [ "$command" == "" ] && dcommand="docker exec $arg $shellarg -u root $item /bin/bash -c '${localenv}\$SHELL'"
    [ "$command" != "" ] && dcommand="docker exec $arg $shellarg -u root $item /bin/bash -c '${localenv}$command'"
    command="${dcommand}"
  fi

  [[ "$dry_run" == "" ]] && eval $command
  [[ "$dry_run" != "" ]] && echo $command
}

execInEachType() {
  local origtype="$1"
  local type="nodes_${origtype}s"
  #local -n typevar
  eval "typevar=(\${${type}[@]})"
  local callback=$2
  local command=""
  local MA_number=$3
  local user=$4
  local dry_run=$5
  local shellarg=$6
  local localenv=$7
  local simulate=$8

  if [[ "$MA_number" != "" ]]; then
    typevar=(${typevar[$MA_number]})
  fi
  local NODETYPE
  [[ "${typevar[@]}" == "" ]] && ech "error" "$type is not available" && return 1
  for item in "${typevar[@]}"; do
    NODETYPE=$(echo "$item::" | cut -d ":" -f 2)
    item=$(echo "$item::" | cut -d ":" -f 1)
    command="${callback//NODE/$item}"
    execIET$NODETYPE "$item" "$callback" "$command" "$user" "$dry_run" "$shellarg" "$localenv" "$simulate"
  done
}

# Example basheval echo "1"
# basheval "echo 1 | grep 1"
# basheval --dry-run echo 1
basheval() {
  dry_run=""
  if [[ "$1" == "--dry-run" ]]; then
    dry_run=$1
    shift
  fi

  local cmd1=$1
  shift
  local cmd=$(addQuote "$@")
  ech "log" "full" "[exec] $cmd1 $cmd"
  [[ "$dry_run" == "" ]] && {
    eval "$cmd1 $cmd"
    return $?
  }
  return 0
}

ech() {
  local data
  [[ "$1" == "--pipe" ]] && {
    shift
    while read -r data; do
      ech $@ "$data"
    done
    return 0
  }
  local type=$1
  if [[ "$2" != "" ]]; then
    shift
  else
    type="debug"
  fi

  local short=$1
  if [[ 'head tail full' =~ "$short" ]]; then
    shift
  else
    short="head"
  fi
  local withtime
  withtime=""
  [[ "$WITHTIME" != "" ]] && withtime="[$(date +%T)] "

  #if [[ "$DEBUG" == "" && "$type" == "debug" ]]; then
  #    return
  # fi

  #    if [[ "$type" == "error" ]]; then
  #       echo "[${type}] $@" >&2
  #      return
  # fi

  local out="$@"
  if [[ "$short" == "head" ]]; then
    out=$(echo "$out" | head -c 300)"..."
  fi
  if [[ "$short" == "tail" ]]; then
    out=$(echo "$out" | tail -c 300)"..."
  fi
  export DEBUG="${DEBUG}"

  [ "$QUIET" == "" ] && [ "$DEBUG" != "" ] && [ "$DEBUGUSEBASH" != "" ] && (
    cd ${OLIVERDIR}
    cd ../../
    echo "$out" >&2
  )
  [ "$QUIET" == "" ] && [ "$DEBUG" != "" ] && [ "$DEBUGUSEBASH" == "" ] && (
    cd ${OLIVERDIR}
    cd ../../
    echo "${withtime}$out" | node -e "let out=require('fs').readFileSync(0, 'utf-8'); var debug = require('debug')('ech:$type'); debug(out.trim());" >&2
  )
  return 0
}

# insert_after_token "content" "token" "piecetoadd"
# use ^^: start of content
# use $$: end of content
# Be careful of $$. Use singlequote for '$$'
insert_after_token() {
  # local args=$(addQuote "$@")
  insert_token_help "a" "$@"
}

insert_before_token() {
  # local args=$(addQuote "$@")
  insert_token_help "i" "$@"
}

insert_token_help() {
  local method=$1
  shift
  local token=$2
  local toadd=$3
  local seddable=$(echo "$toadd" | sed '$!s/$/\\/')
  local tkseddable=$(echo "$token" | sed '$!s/$/\\/' | sed 's/\//\\\//g')
  case $token in
  "^^")
    echo "$toadd"
    echo "$1"
    ;;
  '$$')
    echo "$1"
    echo "$toadd"
    ;;
  *)
    echo "$1" | sed -e "/$tkseddable/${method} $seddable"
    ;;
  esac
}

# replace_at_token "content" "token" "piecetoreplace"
replace_at_token() {
  local token=$2
  local toadd=$3
  local seddable=$(echo "$toadd" | sed '$!s/$/\\/')
  local tkseddable=$(echo "$token" | sed '$!s/$/\\/' | sed 's/\//\\\//g')
  case $token in
  *)
    local out=$(echo "$1" | sed 's/^.*'$tkseddable'.*$/myspecialratk/g')
    echo "$out" | sed -e "/myspecialratk/a $seddable" | grep -v "myspecialratk"
    ;;
  esac
}

# replace_after_token "content" "token" "replacetoken" "piecetoadd"
replace_after_token() {
  local newout=$(echo "$1" | grep -v -F "$3")
  insert_after_token "$newout" "$2" "$4"
}

# replace_between_token "content" "token" "# replacetoken" "piecetoadd"
replace_between_token() {
  local tksed=$(echo "$3" | sed '$!s/$/\\/' | sed 's/\//\\\//g')
  local newout=$(echo "$1" | sed "/$tksed start/,/$tksed end/d")
  local toreplace="$3 start
$4
$3 end"
  insert_after_token "$newout" "$2" "$toreplace"
}

switchenv() {
  [ -f .env.${namespace} ] && cp .env.${namespace} .env
  [ -f .control.${namespace}.js ] && cp .control.${namespace}.js .control.js
  [ -f config.${namespace}.js ] && cp config.${namespace}.js config.js
}

loadenvf() {
  . $1
  eval "$(cat $1 | grep -E '^[A-Z_][A-Z0-9_]*=' | sed 's/^/export /g')"
}

loadenv() {
  [ -f ./.env.all ] && loadenvf ./.env.all
  [[ "${namespace}" == "" || ! -f ./.env.${namespace} ]] && [ -f ./.env ] && loadenvf ./.env
  [ -f ./.env.${namespace} ] && loadenvf ./.env.${namespace}
}

pids_list_descendants() {
  local children=$(ps -o pid= --ppid "$1")

  for pid in $children; do
    pids_list_descendants "$pid"
  done

  echo "$children"
}

pids_kill() {
  kill $(pids_list_descendants $1)
}

alias rsync="rsync -ravzpt"
alias rsyncroot='rsync --rsync-path="sudo rsync"'
alias rsyncputty="pscp -v -load"
CTLWORKINGDIR="${PWD}"
OLIVERDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && cd ../ >/dev/null && pwd)"
# PATH="$PATH:$OLIVERDIR/scripts"
