#!/bin/bash

# This script packages up all of the relevant tools in this directory
# by delegating to other package.sh scripts.

OS=$1
DEST=$2

if [[ -z $OS || -z $DEST ]]; then
    echo "Usage: $0 OS DEST_DIR"
    exit 1
fi

# Exit on any failure
set -e

BASE_DIR=$(pwd)
TOOLS_DIR=$(dirname $0)

if [[ $OS != "win" ]]; then
    cp $(TOOLS_DIR)/build-tools.sh $DEST
fi

PACKAGES=$(find $TOOLS_DIR -name package.sh)
for package in $PACKAGES; do
    package=$(dirname $package)
    echo "--------------------------------------------------------------------"
    echo Packaging $package
    cd $BASE_DIR/$package
    ./package.sh $OS $DEST
done
