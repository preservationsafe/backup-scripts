#!/bin/bash

export PATH="/opt/amanda/bin:$PATH"

RUNFILE="/var/log/continuity/run-full-backup.run"

if [ -f "$RUNFILE" ]; then
  date >> "$RUNFILE"
  echo "Already running, exiting..." >> "$RUNFILE"
  exit 1
fi

date > "$RUNFILE"

/opt/amanda/bin/amanda-backup-sequential.sh data-continuity

/opt/amanda/bin/aaws-upload.sh "data-continuity preservation-continuity/sequoia" offsite2018.library.arizona.edu wasabi > /var/log/continuity/sync-wasabi/aws-upload.out 2>&1

/opt/amanda/bin/aaws-upload-only-new.pl "preservation-continuity/ftdca preservation-continuity/preservation-prd-archive preservation-continuity/preserve preservation-continuity/textmining" > /var/log/continuity/sync-wasabi/aws-upload-only-new.out 2>&1

rm -f "$RUNFILE"
