#!/bin/sh

TAPE=$1
TAR_CMD=${2:-tf}

if [ ! -f "$TAPE" ]; then
  echo "ERROR: cannot open amanda tape file $TAPE"
  exit 1
fi

dd if=$TAPE bs=32k skip=1 | /bin/tar -${TAR_CMD} -
