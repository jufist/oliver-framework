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
exec--test() {
  echo "Testing calls"
}
exec--main() {  
  echo "Main calls"
}

. node_modules/oliver-framework/bash/common.sh
oliver-common-exec --check-existed '$M0 $M1' "$@"
```
