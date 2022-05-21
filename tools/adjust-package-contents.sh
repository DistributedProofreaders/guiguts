#!/bin/bash

# Adjust package contents, useful for adding or removing files based
# on the operating system.

OS=$1
DEST=$2

if [[ -z $OS || -z $DEST ]]; then
    echo "Usage: $0 OS DEST_DIR"
    exit 1
fi

# Exit on any failure
set -e

if [[ $OS = "win" ]]; then
    rm $DEST/guiguts.command
elif [[ $OS = "mac" ]]; then
    rm $DEST/run_guiguts.bat
fi
