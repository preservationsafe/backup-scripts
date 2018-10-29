#!/bin/bash

#set -x

DIRPATH="$1"
NODRYRUN="$2"
BUCKET="${3:-offsite2018.library.arizona.edu}"
PROFILE="--profile ${4:-wasabi}"

if [ "$DIRPATH" = "/" ] || [ ! -d "$DIRPATH" ]; then
  echo "ERROR: need to specifiy the directory path to delete. "
  echo "ERROR: default is to do a dryrun in the foreground, to actually"
  echo "ERROR: do the delete backgrounded with logging add the keyword DOIT. "
  echo "EXAMPLE: ./amanda-wasabi-rmdir.sh /preservation-continuity/preserve/afghan <DOIT> <optional_bucket> <optional_aws_profile>"
  exit 1
fi

# Remove leading slash
DIRPATH="${1#/}"

CMD="aws $PROFILE --color auto s3 rm s3://$BUCKET/$DIRPATH --recursive"

if [ "$2" != "DOIT" ]; then
  $CMD --dryrun
else

DATETIME=`date +%Y-%m-%d.%H.%M.%S`

LOGFILE=rmdir-$DATETIME.log

cd /var/log/continuity/sync-wasabi

touch $LOGFILE
ln -sf $LOGFILE rmdir-latest.log

/usr/bin/time -a -o $LOGFILE $CMD > $LOGFILE 2>&1

fi
