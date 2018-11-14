#!/bin/bash

CURRENT=$(df  |grep /dev/mapper/lvm_raidarray-preservation--continuity | awk '{ print $5}' | sed 's/%//g')
THRESHOLD=85

if [ "$CURRENT" -gt "$THRESHOLD" ] ; then
#   mail -s 'Disk Space Alert - Backup1' rgrunloh@email.arizona.edu, enazar@email.arizona.edu << EOF
   mail -s 'Disk Space Alert - Backup1' LBRY-OPS-LCU@distribution.arizona.edu << EOF
Your preservation-continuity partition is $CURRENT% full.
EOF
fi


