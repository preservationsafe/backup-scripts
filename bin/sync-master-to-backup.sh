#!/bin/bash

RUNFILE="/var/log/continuity/preservation-continuity/sync-master-to-backup.run"

if [ -f "$RUNFILE" ]; then
  date >> "$RUNFILE"
  echo "Already running, exiting..." >> "$RUNFILE"
  exit 1
fi

date > "$RUNFILE"

/opt/amanda/bin/rsync-only-new.sh
/opt/amanda/bin/rsync.sh

rm -f "$RUNFILE"
