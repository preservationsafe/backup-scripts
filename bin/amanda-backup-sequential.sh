#!/bin/bash

BACKUP_SET=${1:-data-continuity}
HOST=$2
SHARE=$3

echo > /var/log/continuity/$BACKUP_SET-full-dump-time.txt
/usr/bin/time -o /var/log/continuity/$BACKUP_SET-full-dump-time.txt -a amdump $BACKUP_SET $HOST $SHARE
