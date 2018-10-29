#!/bin/bash

BACKUP_SET=${1:-preserve}
HOST=${2:-localhost}
AMANDA_CMD="amdump $BACKUP_SET $HOST"
MAX_PARALLEL=$((4))
PARALLEL=$((0))

DISKLIST="\
/mnt/nfs/preserve/dsk05 \
/mnt/nfs/ftdca \
/mnt/nfs/afghan \
/mnt/nfs/ddat \
/mnt/nfs/review \
/mnt/nfs/preserve/dsk04 \
/mnt/nfs/preserve/dsk01 \
/mnt/nfs/preserve/dsk07 \
/mnt/nfs/preserve/dsk03 \
/mnt/nfs/preserve/dsk02 \
/mnt/nfs/preserve/dsk06 \
/mnt/nfs/preserve/dsk08 \
"

for DISK in $DISKLIST; do
  SHARE="${DISK##*/}"
  TIME_FILE="/var/log/continuity/$BACKUP_SET-$SHARE.txt"
  echo > "$TIME_FILE"
  /usr/bin/time -a -o $TIME_FILE $AMANDA_CMD $DISK &
  PARALLEL=$(($PARALLEL + 1))
  sleep 10
  # Similuting inserting a new virtual tape is the trick
  # that allows multiple amdumps to be launched
  amtape preserve slot next >/dev/null 2>&1
  
  if [ "$PARALLEL" -gt "$MAX_PARALLEL" ]; then
    # Wait until one of the background jobs is done ( ie -n )
    wait -n
    PARALLEL=$(($PARALLEL - 1))
  fi
done

# Wait for all remaining jobs to complete ( ie no -n )
wait
