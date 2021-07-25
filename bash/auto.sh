#!/bin/bash

focusChrome() {
  ech2 "Focus chrome and maximize"
  wmctrl -a "Google Chrome" -b add,maximized_vert,maximized_horz
  wmctrl -a "Google Chrome"
}

ech3() {
  while read -r line; do
    ech notice full "($(date +%T)) $line"
  done
}

ech2() {
  ech notice full "($(date +%T)) $@"
}

playKey() {
  xmacroplay $DISPLAY <${WORKINGDIR}/tmp/genKey >/dev/null
}

keyecho() {
  echo "$@" >>${WORKINGDIR}/tmp/genKey
}

genKey() {
  # Cleanup
  if [[ "$1" == "--init" ]]; then
    shift
    mkdir -p ${WORKINGDIR}/tmp
    echo "" >${WORKINGDIR}/tmp/genKey
  fi

  # Raw
  if [[ "$1" == "--raw" ]]; then
    shift
    keyecho "$@"
    return
  fi

  local withCtrl
  withCtrl="NO"
  if [[ "$1" == "--ctrl" ]]; then
    withCtrl="YES"
    shift
  fi

  local withShift
  withShift="NO"
  if [[ "$1" == "--shift" ]]; then
    withShift="YES"
    shift
  fi

  if [[ "$withCtrl" == "YES" ]]; then
    keyecho "KeyStrPress Control_L"
  fi

  if [[ "$withShift" == "YES" ]]; then
    keyecho "KeyStrPress Shift_L"
  fi

  keyecho "KeyStrPress $1
KeyStrRelease $1
"

  if [[ "$withCtrl" == "YES" ]]; then
    keyecho "KeyStrRelease Control_L"
  fi

  if [[ "$withShift" == "YES" ]]; then
    keyecho "KeyStrRelease Shift_L"
  fi
}

docrconsole() {
  local timeout
  local TAB
  local CMD
  local PID
  local ret
  local FCMD
  timeout=20
  if [[ "$1" == "--timeout" ]]; then
    shift
    timeout=$1
    shift
  fi

  # Load tabs
  echo ".tabs
console.log('OLIVERTABS'); setTimeout(console.clear, 500);" | npx crconsole | tee ./tmp/crtabs | ech3 2>/dev/null &
  PID=$(jobs -l | awk '{if ($2 ~ /[[:digit:]+]/) {$1 = "";} else {}; print $0;}' | grep -F "npx crconsole" | awk '{print $1;}')
  tail -F ./tmp/crtabs | sed '/OLIVERTABS/ q' >/dev/null 2>&1
  kill $(pids_list_descendants $PID)
  kill $PID

  # Print tabs out
  TAB=$(cat ./tmp/crtabs | grep -F " https://www.facebook" | head -n 1 | cut -d"[" -f2 | cut -d "]" -f 1)

  echo "" >./tmp/crconsole
  # For console to be clear before next session
  sleep 1
  CMD="$@"
  FCMD=$(echo "
function gexit(isError=false){
  console.log('OLIVERSTOPPED' + (isError ? '|OLIVERERROR' : '|') + '|COMMON|$timeout' );
  setTimeout(console.clear, 2000);
};
(async ()=>{
  console.log('OLIVERACTION');
  const to=setTimeout(gexit.bind({}, true), $timeout * 1000);
  ${CMD};
  clearTimeout(to);
  gexit();
})();0;" | tr '\n' ' ')
  ech2 "[crconsole] Executing in console ${FCMD}"
  echo "" >./tmp/crinput
  tail -F ./tmp/crinput | npx crconsole | tee ./tmp/crconsole | ech3 &
  echo ".switch $TAB" >>./tmp/crinput
  sleep 2
  echo "${FCMD}" >>./tmp/crinput
  PID=$(jobs -l | awk '{if ($2 ~ /[[:digit:]+]/) {$1 = "";} else {}; print $0;}' | grep -F "npx crconsole" | awk '{print $1;}')
  ech2 "Sent the crconsole to background. Doing tail $PWD/tmp/crconsole with timeout $timeout"
  tail -F ./tmp/crconsole | sed '/OLIVERSTOPPED/ q' >/dev/null 2>&1
  kill $(pids_list_descendants $PID)
  kill $PID
  ret=$(cat ./tmp/crconsole)
  local out
  out=$(echo "$ret" | grep -v "OLIVERACTION" | grep -v "OLIVERSTOPPED" | grep -v "console.clear")
  echo "$out"
  ech2 "[crconsole] Executed in console and killing crconsole $PID"
  echo "$ret" | grep "OLIVERERROR" >/dev/null && return 1
  return 0
}

waitChromeTillTimeout() {
  local timeout
  timeout=100
  if [[ "$1" == "--timeout" ]]; then
    shift
    timeout=$1
    shift
  fi
  docrconsole --timeout $timeout "await new Promise((res, rej) => {
const cb = $1;
const itv = setInterval(() => {if (cb()) {
  res();
  clearTimeout(itv);
}}, 1000);
setTimeout(clearTimeout.bind({}, itv), $timeout * 1000);
})"
  return $?
}
