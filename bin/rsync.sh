#!/bin/bash

SRC_DIR="/mnt/nfs"
DST_DIR="/preservation-continuity"
ROGROUP=amandabackup

DATETIME=`date +%Y-%m-%d.%H.%M.%S`
LOGBASE="/var/log/continuity/preservation-continuity/rsync-preservation-continuity"
LOGFILE="$LOGBASE-$DATETIME.log"

# Note: we don't want it to do checksum to see if something should get transfered, only rely on date and filesize. We'll rely on the fixity service to notice a checksum difference.
CHECKSUM="" #"--checksum"
ITEMIZE="--itemize_changes"

SHARE_LIST="\
sequoia"

touch $LOGFILE
ln -sf $LOGFILE $LOGBASE.log

for SHARE in $SHARE_LIST; do
  echo "SAFE_SYNC $SHARE" >> $LOGFILE
  #/usr/bin/time -o $LOGFILE -a cp -van "$SRC_DIR/$SHARE" "$DST_DIR" >> $LOGFILE 2>&1
  /usr/bin/time -o $LOGFILE -a rsync $DEBUG $CHECKSUM -arvh --delete-before --chown=root:disk --chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r --stats "$SRC_DIR/$SHARE" "$DST_DIR" >> $LOGFILE 2>&1
done

# Ensure the amandabackup group has read access to all the files
#chown -R $ROGROUP $DST_DIR
#chmod -R g+r $DST_DIR
