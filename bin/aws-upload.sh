#!/bin/bash

#set -x

DIRLIST="$1"
BUCKET="${2:-offsite2018.library.arizona.edu}"
PROFILE="--profile ${3:-wasabi}"

# Validate $DIRLIST

TESTLIST="GOOD"

if [ "xx$DIRLIST" = "xx" ]; then
  TESTLIST="FALSE"  
fi

for DIRPATH in $DIRLIST; do
  if [ ! -d "/$DIRPATH" ]; then
    TESTLIST="FALSE"  
  fi
done

if [ "$TESTLIST" != "GOOD" ]; then
  echo "ERROR: need to specifiy a list of root directories to upload. "
  echo "EXAMPLE: ./aws-upload.sh data-continuity preservation-continuity <optional_bucket> <optional_aws_profile>"
  exit 1
fi

DATETIME=`date +%Y-%m-%d.%H.%M.%S`

LOGFILE=aws-upload-$DATETIME.log

cd /var/log/continuity/sync-wasabi

touch $LOGFILE
ln -sf $LOGFILE sync-latest.log

for DIRPATH in $DIRLIST; do
  /usr/bin/time -a -o $LOGFILE aws $PROFILE --color auto s3 sync /$DIRPATH/ s3://$BUCKET/$DIRPATH --no-progress > $LOGFILE 2>&1
done

# When a preservation share is sync'd, use the following to ensure nothing is ever deleted or changed
#/usr/bin/time -a -o $LOGFILE aws s3 sync --no-progress --delete false ----profile wasabi /preservation-continuity/ s3://offsite2018.library.arizona.edu/preservation-continuity > $LOGFILE 2>&1
