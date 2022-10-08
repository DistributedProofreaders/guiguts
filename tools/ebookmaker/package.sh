#!/bin/bash

OS=$1
DEST=$2

# Exit on any failure
set -e

DEST=$DEST/ebookmaker
mkdir $DEST
cp README.md $DEST

if [[ $OS == "win" ]]; then
    VERSION=0.12.17
    URL=https://github.com/DistributedProofreaders/ebm_builder/releases/download/v$VERSION/ebookmaker-$VERSION.zip
    curl -L -o ebookmaker.zip $URL
    unzip ebookmaker.zip -d $DEST
    rm -rf ebookmaker.zip
elif [[ $OS == "mac" ]]; then
    cp add_ebookmaker_to_path.sh $DEST
fi
