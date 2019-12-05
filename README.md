# Oliver Framework
## Setup
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

exec--test() {
  echo "Testing calls"
}

exec--main() {
  local cmd=`basename $0`
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

. node_modules/oliver-framework/bash/common.sh

oliver-common-exec --check-existed '$M0 $M1' "$@"

```
