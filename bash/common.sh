#!/bin/bash

function addQuote() {
  local C=''
  local i
  for i in "$@"; do
      i="${i//\\/\\\\}"
      C="$C \"${i//\"/\\\"}\""
  done
  echo "$C"
}

# remove specified host from /etc/hosts
function removehost() {
    if [[ "$1" ]]
    then
        HOSTNAME=$1

        if [ -n "$(grep $HOSTNAME /etc/hosts)" ]
        then
            echo "$HOSTNAME Found in your /etc/hosts, Removing now...";
            sudo sed -i".bak" "/$HOSTNAME/d" /etc/hosts
        else
            echo "$HOSTNAME was not found in your /etc/hosts";
        fi
    else
        echo "Error: missing required parameters."
        echo "Usage: "
        echo "  removehost domain"
    fi
}

#add new ip host pair to /etc/hosts
function addhost() {
    if [[ "$1" && "$2" ]]
    then
        IP=$1
        HOSTNAME=$2
        OVERWRITE=${3:-"0"}


        if [[ "$OVERWRITE" == "0"  && -n "$(grep $HOSTNAME /etc/hosts)" ]]
            then
                echo "$HOSTNAME already exists:";
                echo $(grep $HOSTNAME /etc/hosts);
            else
                removehost "$HOSTNAME"
                echo "Adding $HOSTNAME to your /etc/hosts";
                printf "%s\t%s\n" "$IP" "$HOSTNAME" | sudo tee -a /etc/hosts > /dev/null;

                if [ -n "$(grep $HOSTNAME /etc/hosts)" ]
                    then
                        echo "$HOSTNAME was added succesfully:";
                        echo $(grep $HOSTNAME /etc/hosts);
                    else
                        echo "Failed to Add $HOSTNAME, Try again!";
                fi
        fi
    else
        echo "Error: missing required parameters."
        echo "Usage: "
        echo "  addhost ip domain"
    fi
}

forceup () {
	echo "[Ok] Service up"
	if [ "$TEST" != "1" ] ; then
		include/folderexec.sh up
	else
		echo "[Notice] Ignore executing by option -t"
	fi
}

forcedown () {
	echo "[Error] Service down"
	if [ "$TEST" != "1" ] ; then
		include/folderexec.sh down
	else
		echo "[Notice] Ignore executing by option -t"
	fi
}

iptablekill() {
	ip=$2
	type=$1
	linenumber=`sudo iptables -L $type --line-numbers | grep -F "$ip" | head -1 | awk '{print $1}'`
	if [ "$linenumber" != "" ] ; then
		sudo iptables -D $type $linenumber
		# Continue erasing until finishing
		iptablekill $type $ip
	fi
}

rootcheck () {
    if [ $(id -u) != "0" ]
    then
        sudo "$0" "$@"  # Modified as suggested below.
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
	ssh $sshhost "bash -s" -- < "$sshscript" --time "bye"
}

mongoexec() {

	# Mongo access
	mongocmd="mongo --port ${mongo[port]}"
	if [ ${mongo[ignore_auth]} != 1 ] ; then
		mongocmd="mongo --port ${mongo[port]} -u ${mongo[user]} -p ${mongo[password]}"
	fi

	#if [ ${mongo[authenticationDatabase]} != 1 ] ; then
  	#	mongocmd+=" --authenticationDatabase '${mongo[authenticationDatabase]}'"
	#fi

	if [ ${mongo[authenticationDatabase]} != "" ] ; then
  		mongocmd+=" --authenticationDatabase ${mongo[authenticationDatabase]}"
	fi

	queries=$mongoexecqueries
	queries+="\nexit\n"
	#echo -e "$queries"
	outp=$(echo -e "$queries" | $mongocmd)
}

sitetodo () {
	if [ "$site" == "dr" ] ; then
		drhosts=("${dchosts[@]}")
		dbarbiter=$dcarbiter
		drbctmp=("${drbc[@]}")
		drbc=("${bc[@]}")
		bc=("${drbctmp[@]}")
		dr=("${dc[@]}")
	fi
}

myconfirm () {
	read -p "Afraid? [Nn}" -n 1 -r
	if [[ $REPLY =~ ^[Yy]$ ]]
	then
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
myargs () {
	local -n arr=$1
	local -n args=$2
	local short=""
	local long=""
	local varname="x"

	for i in "${arr[@]}"
	do
		for j in "${args[@]}"
		do
			short="$(echo $j | cut -d'|' -f1)"
			long="$(echo $j | cut -d'|' -f2)"
			# echo "$short:$long"
			case $i in
				    -$short|--$long|-$short=*|--$long=*)
					varname="MA_$long"
				    export $varname="${i#*=}"
			    ;;
			esac
		done
	done
}

preventExist() {
  arg=$1
  shift
  export M0="$0"; export M1="$1"; export M2="$2"; export M3="$3"
  printarg=$(echo "$arg" | envsubst)
  u=`whoami`
  d=$(ps aux)
  e=$(echo "$d" | grep "$u" | grep "$printarg " | grep -v "$PPID" | grep -v "grep " | grep -v -e "^[[:space:]]*$" | wc -l)

  if [ "$e" -gt "1" ]; then
    echo "[Error] Someone is running this process but this allows to run only one instance at a time. Please try again later!"
    exit 0
  fi
}

is_valid_number () {
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
  if ! [[ "$1" =~ ^[0-9]{6,13}$ ]]
  then
      echo "[Error] Verify your phone number $1"
      exit
  fi
}

fn_exists() { test x$(type -t $1) = xfunction; }

exechelplist() {
  local cmd=`basename $0`
  declare -F | grep exec-- | sed 's/declare -f exec/'$cmd' /'
}

oliver-common-exec() {
  SETUPDIR=$( dirname $(realpath "$0") )
  if [[ "$1" == "--check-existed" ]]; then
    arg=$2
    shift
    shift
    preventExist "$arg" "$@"
  fi
  action="$1"
  if [[ $action =~ "--" ]]; then
    shift
  else
    action="--main"
  fi

  parseaction="vars_parse$action"
  fn_exists $parseaction && $parseaction "$@"

  verifyaction="vars_verify$action"
  fn_exists $verifyaction && $verifyaction "$@"

  action="exec$action"
  fn_exists $action && $action "$@"
  fn_exists $action || exechelplist
}

execIET() {
    local item=$1
    local callback=$2
    local command=$3
    local user=$4
    if [[ "$user" == "" ]]; then
        command="ssh $item '$command'"
    else
        # Allow other users to run, not just root
        # "sudo -s su kazoo -c '
        command="ssh $item 'sudo $command'"
    fi

    if [[ "$callback" != "" ]] ; then
        echo "[Exec] $command"
        eval $command
    else
        echo "[SSH] SSH to $item"
        ssh $item
    fi
}


execIETdocker() {
    local item=$1
    local callback=$2
    local command=$3
    local user=$4
    if [[ "$user" == "" ]]; then
        command="docker exec -ti $item /bin/bash -c '$command'"
    else
        # Allow other users to run, not just root
        # "sudo -s su kazoo -c '
        command="docker exec -ti -u root $item /bin/bash -c '$command'"
    fi

    if [[ "$callback" != "" ]] ; then
        echo "[Exec] $command"
        eval $command
    else
        echo "[Docker] Docker to $item"
        docker exec -ti $item /bin/bash
    fi
}

execInEachType () {
    local origtype="$1"
    local type="nodes_${origtype}s"
    #local -n typevar
    eval "typevar=(\${${type}[@]})"
    local callback=$2
    local command=""
    local MA_number=$3
    local user=$4
    if [[ "$MA_number" != "" ]] ; then
        typevar=(${typevar[$MA_number]})
    fi
    local NODETYPE
    for item in "${typevar[@]}"
    do

        NODETYPE=$(echo "$item::" | cut -d ":" -f 2)
        item=$(echo "$item::" | cut -d ":" -f 1)
        command="${callback//NODE/$item}"
        execIET$NODETYPE "$item" "$callback" "$command" "$user"
    done
}

# Example basheval echo "1"
# basheval "echo 1 | grep 1"
basheval() {
    local cmd1=$1
    shift
    local cmd=$(addQuote "$@")
    echo "[Exec] $cmd1 $cmd"
    eval "$cmd1 $cmd"
}

OLIVERDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && cd ../ >/dev/null && pwd )"
# PATH="$PATH:$OLIVERDIR/scripts"
