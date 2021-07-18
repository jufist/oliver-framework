#!/bin/bash

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

replace_vianode() {
  local content search replace
  content=$(</dev/stdin)
  search=$(addSingleQuote "$1")
  replace=$2
  echo "$content" | node -e "
	search=process.argv[1];
	replace=process.argv[2];
	// process.stderr.write(search);
	// console.error([search, replace]);
        let content=require('fs').readFileSync(0, 'utf-8');
            let re = new RegExp(search, 'g');
            content = content.replace(re, replace);
	    process.stdout.write(content);
    " "$search" "$replace"
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
# inputargs=("$@")
# myargs inputargs definedargs
# Now we have:
# Using: $MA_local
# Also we have ${newargs[@]}
# inputargs=("$@")
# definedargs=("n|number", "s|sudo", "p|path")
# myargs inputargs definedargs
# set -- "${newargs[@]}"
myargs() {
  local -n arr=$1
  local -n args=$2
  local short=""
  local long=""
  local varname="x"
  export newargs=()
  local found=""
  for i in "${arr[@]}"; do

    found=""
    for j in "${args[@]}"; do
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
}

preventExist() {
  arg=$1
  shift
  export M0="$0"
  export M1="$1"
  export M2="$2"
  export M3="$3"
  printarg=$(echo "$arg" | envsubst)
  u=$(whoami)
  d=$(ps aux)
  e=$(echo "$d" | grep "$u" | grep "$printarg " | grep -v "$PPID" | grep -v "grep " | grep -v -e "^[[:space:]]*$" | wc -l)

  if [ "$e" -gt "1" ]; then
    echo "[Error] Someone is running this process but this allows to run only one instance at a time. Please try again later!"
    exit 0
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
  fn_exists $parseaction && $parseaction "$@"

  verifyaction="vars_verify$action"
  fn_exists $verifyaction && $verifyaction "$@"

  action="exec$action"
  fn_exists $fullaction && $fullaction "$@"
  fn_exists $fullaction || exechelplist
}

execIET() {
  local item=$1
  local callback=$2
  local command=$3
  local user=$4
  local dry_run=$5
  local shellarg=$6
  if [[ "$user" == "" ]]; then
    command="ssh $shellarg $item '$command'"
  else
    # Allow other users to run, not just root
    # "sudo -s su kazoo -c '
    command="ssh $shellarg $item 'sudo $command'"
  fi

  if [[ "$callback" != "" ]]; then
    ech "log" "[Exec] $command"
    [[ "$dry_run" == "" ]] && eval $command
    [[ "$dry_run" != "" ]] && echo $command
  else
    ech "log" "[SSH] SSH to $item"
    [[ "$dry_run" == "" ]] && ssh $shellarg $item
    [[ "$dry_run" != "" ]] && echo "ssh $item"
  fi
}

execIETdocker() {
  local item=$1
  local callback=$2
  local command=$3
  local user=$4
  local dry_run=$5
  local shellarg=$6

  if [[ "$user" == "" ]]; then
    command="docker exec -i $shellarg $item /bin/bash -c '$command'"
  else
    # Allow other users to run, not just root
    # "sudo -s su kazoo -c '
    command="docker exec -i -u root $shellarg $item /bin/bash -c '$command'"
  fi

  if [[ "$callback" != "" ]]; then
    ech "log" "[exec] $command"
    [[ "$dry_run" == "" ]] && eval $command
    [[ "$dry_run" != "" ]] && echo $command
  else
    ech "log" "[docker] Docker to $item"
    [[ "$dry_run" == "" ]] && docker exec -ti $shellarg $item /bin/bash
    [[ "$dry_run" != "" ]] && echo "docker exec -ti $item /bin/bash"
  fi
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

  if [[ "$MA_number" != "" ]]; then
    typevar=(${typevar[$MA_number]})
  fi
  local NODETYPE
  [[ "${typevar[@]}" == "" ]] && ech "error" "$type is not available" && return 1
  for item in "${typevar[@]}"; do

    NODETYPE=$(echo "$item::" | cut -d ":" -f 2)
    item=$(echo "$item::" | cut -d ":" -f 1)
    command="${callback//NODE/$item}"
    execIET$NODETYPE "$item" "$callback" "$command" "$user" "$dry_run" "$shellarg"
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
  ech "log" "[exec] $cmd1 $cmd"
  [[ "$dry_run" == "" ]] && eval "$cmd1 $cmd"
}

ech() {
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

  [ "$QUIET" == "" ] && [ "$DEBUG" != "" ] && [ "$DEBUGUSEBASH" != "" ] && (
    cd ${OLIVERDIR}
    cd ../../
    echo "$out" >&2
  )
  [ "$QUIET" == "" ] && [ "$DEBUG" != "" ] && [ "$DEBUGUSEBASH" == "" ] && (
    cd ${OLIVERDIR}
    cd ../../
    echo "$out" | node -e "let out=require('fs').readFileSync(0, 'utf-8'); var debug = require('debug')('ech:$type'); debug(out.trim());" >&2
  )
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

loadenv() {
  [ -f ./.env.all ] && . ./.env.all
  [[ "${namespace}" == "" || ! -f ./.env.${namespace} ]] && [ -f ./.env ] && . ./.env
  [ -f ./.env.${namespace} ] && . ./.env.${namespace}
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
