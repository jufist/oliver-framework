#!/bin/bash

LOCKFILE="$1"
shift
INITTIMEOUT=$1
shift
QUEUEFILE="$LOCKFILE.queue"

[[ ! -f "$LOCKFILE" ]] && {
  mkdir -p "$(dirname $LOCKFILE)"
  touch "$LOCKFILE"
}

# Use flock to obtain an exclusive lock on the lock file
exec 9<"$LOCKFILE"

# Function to clean up the QUEUEFILE
queue_script_cleanup() {
    echo "[$$] Received CtrlC. Cleaning">&2
    rm -f "$QUEUEFILE"
    exit
}

# Trap the CtrlC signal and call the cleanup function
trap queue_script_cleanup SIGINT

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
if ! flock -n 9; then
    [[ ! -f "$QUEUEFILE" ]] && touch "$QUEUEFILE"
    echo "$$" >> "$QUEUEFILE"
    count=0
    cur_queue_pos=$(queue_pos "$$" "$QUEUEFILE")
    timeout=$((INITTIMEOUT * cur_queue_pos))
    echo "[$$] Another instance is running. Waiting for the lock in $timeout" >&2
    while ! flock -n 9; do
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

# Add this instance to the queue
[[ "$added_to_queue" == "no" ]] && echo "$$" >> "$QUEUEFILE"

# Wait for our turn in the queue
while [ "$(head -n 1 "$QUEUEFILE")" != "$$" ]; do
    # All should have the same position so this position is not needed
    break 
    sleep 1
done

# Your code to be executed goes here
echo "[$$] $(date '+%F %T') Starting the job for process $$..." >&2
eval "$@"
ret=$?
echo "[$$] $(date '+%F %T') Job completed for process $$." >&2

# Release the lock and remove ourselves from the queue
exec 9>&-

# Remove $$ out of QUEUEFILE
sed -i "/^$$\$/d" "$QUEUEFILE"
exit $ret
