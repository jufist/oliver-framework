# Oliver Framework

## Using bash structure exec

exec--test() {
  echo "Testing calls"
}
exec--main() {  
  echo "Main calls"
}

. node_modules/oliver-framework/bash/common.sh
oliver-common-exec --check-existed '$M0 $M1' "$@"
