# Oliver Framework

## Setup

- lib:
  - Alpine: apk add --virtual build_deps gettext
  - Debian: apt intall gettext
- package.json

```
  "dependencies": {
    "oliver-framework": "git@github.com:antbuddy-share/oliver-framework.git"
  }
```

- `npm install`

## Using bash structure exec

```bash
#!/bin/bash

SCRIPT=$(readlink -f "$0")
# No sym
# SCRIPT=`realpath -s $0`
SCRIPTPATH=$(dirname $SCRIPT)
WORKINGDIR=$(pwd)

exec--test() {
  echo "Testing calls"
}

exec--main() {
  local cmd=$(basename $0)
  declare -F | grep exec-- | sed 's/declare -f exec/'$cmd' /'
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

MYHOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

. $MYHOME/node_modules/oliver-framework/bash/common.sh
oliver-common-exec --check-existed '$M0 $M1' "$@"
```

## Some more user cases

```bash
#!/bin/bash

SCRIPT=$(readlink -f "$0")
# No sym
# SCRIPT=`realpath -s $0`
SCRIPTPATH=$(dirname $SCRIPT)
WORKINGDIR=$(pwd)
MYHOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

shopt -s expand_aliases

export DEBUG=${DEBUG:-"*"}

vars_parse--main() {
  definedargs=("v|version*" "e|extra")
  definedparams=("one", "two")
  inputargs=("$@")
  myargs inputargs definedargs definedparams
  [[ "$?" != "0" ]] && return 1
  set -- "${newargs[@]}"

  RESTARGS=("$@")
}

exec--main() {
  # Use rest parameters by RESTARGS instead of $@ normally here or override $@ by following command
  set -- "${RESTARGS[@]}"
  echo "Param: $MP_one"
  echo "Arg version: $MA_version"
  echo "Main"
  exit
}
```

# Using Docker Oliver Stack

`. node_modules/oliver-framework/bash/oliverstack.sh` `oliver-stack --help`

# Variables

OLIVERDIR
