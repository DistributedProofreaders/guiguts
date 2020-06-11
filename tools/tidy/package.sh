#!/bin/bash

OS=$1
DEST=$2

# Exit on any failure
set -e

DEST=$DEST/tidy
mkdir $DEST
cp README.md $DEST

if [[ $OS == "win" ]]; then
    VERSION=5.6.0
    FLAVOR=tidy-$VERSION-vc14-32b
    URL=https://github.com/htacg/tidy-html5/releases/download/$VERSION/$FLAVOR.zip
    curl -L -o tidy.zip $URL
    unzip tidy.zip $FLAVOR/bin/tidy.exe -d .
    mv $FLAVOR/bin/tidy.exe $DEST
    rm -rf $FLAVOR tidy.zip
fi

# MacOS users can get tidy from homebrew and Linux users can get it via
# their package manager.
