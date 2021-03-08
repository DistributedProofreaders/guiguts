#!/bin/bash

# This script builds the relevant tools in this directory
# by delegating to other build.sh scripts.

OS=$1

if [[ -z $OS ]]; then
    echo "Usage: $0 OS"
    exit 1
fi

# Exit on any failure
set -e

BASE_DIR=$(pwd)
TOOLS_DIR=$(dirname $0)

BUILDS=$(find $TOOLS_DIR -name build.sh)
for build in $BUILDS; do
    build=$(dirname $build)
    echo "--------------------------------------------------------------------"
    echo "Building $build"
    cd $BASE_DIR/$build
    ./build.sh $OS
done
