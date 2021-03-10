#!/bin/bash

OS=$1
DEST=$2

# Exit on any failure
set -e

DEST=$DEST/jeebies
mkdir $DEST
cp README.md $DEST

# Always copy the data files over
cp *e.jee $DEST

if [[ $OS == "win" ]]; then
    cp jeebies.exe $DEST
else
    # copy over everything they need to build the tool
    cp README.md Makefile jeebies.c build.sh $DEST
fi

