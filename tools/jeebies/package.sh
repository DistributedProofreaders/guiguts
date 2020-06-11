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
elif [[ $OS == "mac" ]]; then
    cp jeebies-mac $DEST/jeebies
else
    # copy over everything they need to build the tool
    cp README.md Makefile jeebies.c $DEST
fi

# MacOS ships with tidy and Linux users can easily get it so nothing to do
# for those.
