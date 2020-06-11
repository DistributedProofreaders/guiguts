#!/bin/bash

OS=$1
DEST=$2

# Exit on any failure
set -e

DEST=$DEST/ppvimage
mkdir $DEST

# It's a perl script, so just copy it into $DEST for all OSs
cp README.md ppvimage.pl $DEST
