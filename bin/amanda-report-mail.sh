#!/bin/sh

BACKUP_SET=${1:-data-continuity}
amreport --mail-text=  $BACKUP_SET
