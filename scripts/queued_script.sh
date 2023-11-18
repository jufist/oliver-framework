#!/bin/bash

check=""
[[ "$1" == "--check" ]] && {
  check="yes"
  shift
}

LOCKFILE="$1"
shift
INITTIMEOUT=$1
shift
QUEUEFILE="$LOCKFILE.queue"
LOCKSFILE="/dev/shm/mylocks"

[[ ! -f "$LOCKFILE" ]] && {
  mkdir -p "$(dirname $LOCKFILE)"
  touch "$LOCKFILE"
}
[[ ! -f "$LOCKSFILE" ]] && touch "$LOCKSFILE"

get_lock_fd() {
  local lock_fd
  lock_fd=$(cat "$LOCKSFILE" | grep -F "$LOCKFILE|" | cut -d "|" -f 2)
    
  if [[ "$lock_fd" == "" ]]; then
    # Find available unique lock_fd
    for i in {9..100}; do  # Adjust the range as needed
      # Check if the lock_fd is not in use
      if ! grep -qF "|$i|" "$LOCKSFILE"; then
        lock_fd=$i
        break
      fi
    done
    echo "$LOCKFILE|$lock_fd|" >> "$LOCKSFILE"
  fi
  
  echo "$lock_fd" | head -n 1
}

lock_fd=$(get_lock_fd)

# Use flock to obtain an exclusive lock on the lock file
eval "exec ${lock_fd}<$LOCKFILE"

# Function to clean up the QUEUEFILE
queue_script_cleanup() {
    echo "[$$] Received CtrlC. Cleaning with queue $QUEUEFILE">&2
    rm -f "$QUEUEFILE"

    # Escape slashes in the LOCKFILE variable and remove LOCKFILE entry from LOCKSFILE, using the escaped variable
    escaped_LOCKFILE=$(sed 's/\//\\\//g' <<< "$LOCKFILE")
    sed -i "/^$escaped_LOCKFILE/d" "$LOCKSFILE"
    exit
}

[[ "$check" == "" ]] && trap queue_script_cleanup SIGINT

queue_pos() {
    local queue_position queuefile pid queue_length
    pid="$1"
    queuefile="$2"
    # Calculate the position of $pid in the queue
    queue_position=$(grep -n "^$pid" "$queuefile" | cut -d: -f1)

    if [ -z "$queue_position" ]; then
        # $pid not found in the queue
        echo "$pid" >> "$queuefile"
        queue_length=$(wc -l < "$queuefile")
    else
        # $$ found in the queue, calculate queue_length based on position
        queue_length="$queue_position"
    fi
    echo "$queue_length"
}

# Try to obtain the lock with a timeout (in seconds)
# Calculate the timeout based on the number of items in the queue
added_to_queue=no
# echo "XXX INSIDE queue_script checking. check=$check">&2
if ! flock -n "${lock_fd}"; then
    # echo "XXX [queue_script] waiting for flock. checking not good check=$check">&2
    [[ "$check" != "" ]] && exit 1
    [[ ! -f "$QUEUEFILE" ]] && touch "$QUEUEFILE"
    echo "$$" >> "$QUEUEFILE"
    count=0
    cur_queue_pos=$(queue_pos "$$" "$QUEUEFILE")
    timeout=$((INITTIMEOUT * cur_queue_pos))
    echo "[$$] Another instance is running at ${lock_fd}. Waiting for the lock in $timeout with queue $QUEUEFILE" >&2
    while ! flock -n "${lock_fd}"; do
        new_queue_pos=$(queue_pos "$$" "$QUEUEFILE")
        if [[ "$cur_queue_pos" != "$new_queue_pos" ]]; then
          # Refresh the timeout
          cur_queue_pos="$new_queue_pos"
          timeout=$((INITTIMEOUT * cur_queue_pos))
          count=0
          echo "[$$] Timeout changed $timeout." >&2
        fi
        sleep 1
        ((count++))
        if [ "$count" -ge "$timeout" ]; then
            echo "[$$] Timeout reached $timeout. Exiting..." >&2

            # Remove $$ out of QUEUEFILE
            sed -i "/^$$\$/d" "$QUEUEFILE"

            exit 1
        fi
    done
    added_to_queue=yes
fi
[[ "$check" != "" ]] && exit 0

# echo "[queue_script] Add this instance to the queue $$">&2
[[ "$added_to_queue" == "no" ]] && echo "$$" >> "$QUEUEFILE"

# Wait for our turn in the queue
while [ "$(head -n 1 "$QUEUEFILE")" != "$$" ]; do
    # All should have the same position so this position is not needed
    break 
    sleep 1
done

# Your code to be executed goes here
echo "[$$] $(date '+%F %T') Starting the job for process $$ with queue $QUEUEFILE" >&2
eval "$@"
ret=$?
echo "[$$] $(date '+%F %T') Job completed for process $$ with queue $QUEUEFILE." >&2

# Release the lock and remove ourselves from the queue
eval "exec ${lock_fd}>&-"

# Remove $$ out of QUEUEFILE
sed -i "/^$$\$/d" "$QUEUEFILE"

# Escape slashes in the LOCKFILE variable and remove LOCKFILE entry from LOCKSFILE, using the escaped variable
escaped_LOCKFILE=$(sed 's/\//\\\//g' <<< "$LOCKFILE")
sed -i "/^$escaped_LOCKFILE/d" "$LOCKSFILE"

exit $ret
