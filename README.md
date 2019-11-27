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

parseVariables() {
  FORMUSERNAME="$1"
  FORMPWD="$2"
}

verifyVariables() {
  if [[ "$FORMUSERNAME" == "" || "$FORMPWD" == "" ]]; then
    echo "[Error] Please verify your input data"
    exit 1
  fi
}

exec--test() {
  echo "Testing calls"
}
exec--main() {  
  echo "Main calls"
}

. node_modules/oliver-framework/bash/common.sh

parseVariables "$@"
verifyVariables
oliver-common-exec --check-existed '$M0 $M1' "$@"
```
