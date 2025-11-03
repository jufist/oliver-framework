# Oliver Framework

## Setup

- `yarn add git+https://github.com/jufist/oliver-framework.git`

### Python package

The repository also distributes a Python helper package that mirrors the JavaScript tooling. Install the package
directly from the repository:

```bash
python -m pip install --upgrade git+https://github.com/jufist/oliver-framework.git
```

The module exposes a colour-aware logger:

```python
from oliver_framework import getlogger

logger = getlogger("workers")
logger.info("Dispatcher started")
```

The logger reads optional environment variables that can be configured in an `.env` file at the repository root:

| Variable       | Description                                                           |
| -------------- | --------------------------------------------------------------------- |
| `LOGGINGLEVEL` | Logging verbosity, e.g. `INFO`, `DEBUG`, `WARNING`.                   |
| `NAMESPACE`    | Text prepended to the department name in every log entry.             |
| `GUI_LOG_PATH` | Override the log forwarding file (defaults to `<repo>/logs/gui.log`). |

All log messages are written to the console with colour formatting and mirrored to `GUI_LOG_PATH` when provided.

## Using bash structure exec

```bash
#!/bin/bash

export YARNGLOBALDIR=${YARNGLOBALDIR:-"$(yarn global dir)"}
globaldir=${YARNGLOBALDIR:-"$YARNGLOBALDIR"}
if [[ -d "$globaldir/node_modules/oliver-framework" ]]; then
  . "$globaldir/node_modules/oliver-framework/bash/common.sh"
else
  . $(dirname $(node -e "console.log('path: \'' + require.resolve('oliver-framework'))" | grep -F "path: '" | cut -d "'" -f 2))/bash/common.sh
fi
# If this is a script file
. $OFSCRIPTPATH/includes/common.sh
# If this is a source file
# . $OFSOURCESCRIPTPATH/includes/common.sh

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

oliver-common-exec --check-existed '$M0 $M1 $M2 $M3' "$@"
```

## Some more user cases

```bash
#!/bin/bash

export YARNGLOBALDIR=${YARNGLOBALDIR:-"$(yarn global dir)"}
globaldir=${YARNGLOBALDIR:-"$YARNGLOBALDIR"}

# Optional
shopt -s expand_aliases
if [[ -d "$globaldir/node_modules/oliver-framework" ]]; then
  . "$globaldir/node_modules/oliver-framework/bash/common.sh"
else
  . $(dirname $(node -e "console.log('path: \'' + require.resolve('oliver-framework'))" | grep -F "path: '" | cut -d "'" -f 2))/bash/common.sh
fi
# If this is a script file
. $OFSCRIPTPATH/includes/common.sh
# If this is a source file
# . $OFSOURCESCRIPTPATH/includes/common.sh

loadenv

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

oliver-common-exec "$@"
```

# Using Docker Oliver Stack

`. node_modules/oliver-framework/bash/oliverstack.sh` `oliver-stack --help`

# Variables

OLIVERDIR
