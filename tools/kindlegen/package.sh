#!/bin/bash

OS=$1
DEST=$2

# Exit on any failure
set -e

DEST=$DEST/kindlegen
mkdir $DEST
cp README.md $DEST

if [[ $OS == "win" ]]; then
    URL=http://kindlegen.s3.amazonaws.com/kindlegen_win32_v2_9.zip
elif [[ $OS == "mac" ]]; then
    URL=http://kindlegen.s3.amazonaws.com/KindleGen_Mac_i386_v2_9.zip
fi

if [[ $URL != "" ]]; then
    curl -L -o kindlegen.zip $URL
    unzip kindlegen.zip -d $DEST
    rm -rf kindlegen.zip
fi
