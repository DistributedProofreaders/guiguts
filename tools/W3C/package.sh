#!/bin/bash

OS=$1
DEST=$2

# Exit on any failure
set -e

DEST=$DEST/W3C
mkdir $DEST
cp README.md $DEST

# css-validator.jar is the same for all systems
curl -L -o $DEST/css-validator.jar https://github.com/w3c/css-validator/releases/download/cssval-20190320/css-validator.jar

# For OpenSP we only have the pre-built Windows files
if [[ $OS == "win" ]]; then
    VERSION=1.5.2
    curl -L -o opensp.zip https://sourceforge.net/projects/openjade/files/opensp/$VERSION/OpenSP-$VERSION-win32.zip/download
    # we only want onsgmls.exe and it's dependency DLL
    unzip opensp.zip onsgmls.exe osp152.dll -d $DEST
    rm opensp.zip
    # and the xhtml DTDs and related files
    cp xhtml* $DEST
fi
