#!/bin/bash

OS=$1
DEST=$2

# Exit on any failure
set -e

DEST=$DEST/kindlegen
mkdir $DEST
cp README.md $DEST

if [[ $OS == "win" ]]; then
    URL=https://github.com/DistributedProofreaders/guiguts/releases/download/r1.1.0/guiguts-win-1.1.0.zip
    BINARY=kindlegen.exe
elif [[ $OS == "mac" ]]; then
    URL=https://github.com/DistributedProofreaders/guiguts/releases/download/r1.1.0/guiguts-mac-1.1.0.zip
    BINARY=kindlegen
fi

if [[ $URL != "" ]]; then
    curl -L -o guiguts.zip $URL
    unzip guiguts.zip guiguts/tools/kindlegen/$BINARY -d .
    cp guiguts/tools/kindlegen/$BINARY $DEST
    rm -rf guiguts
    rm -rf guiguts.zip
fi
