#!/bin/bash

set -x

DATETIME=`date +%Y-%m-%d.%H.%M.%S`

LOGFILE=download-$DATETIME.log

cd /var/log/continuity/sync-wasabi

touch $LOGFILE
ln -sf $LOGFILE download-latest.log

/usr/bin/time -a -o $LOGFILE aws s3 sync --no-progress --profile wasabi s3://2018/data-continuity /continuity/restore/ > $LOGFILE 2>&1

#/usr/bin/time -a -o $LOGFILE aws s3 sync --no-progress --profile wasabi s3://2018/preservation-continuity /continuity/restore/ > $LOGFILE 2>&1
