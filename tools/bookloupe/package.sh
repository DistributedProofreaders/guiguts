#!/bin/bash

OS=$1
DEST=$2

# Exit on any failure
set -e

DEST=$DEST/bookloupe
mkdir $DEST
cp README.md $DEST

if [[ $OS == "win" ]]; then
    URL=http://www.juiblex.co.uk/pgdp/bookloupe/bookloupe-2.0-win32.zip
    curl -L -o bookloupe.zip $URL
    unzip bookloupe.zip -d $DEST
    rm -rf bookloupe.zip
    rm -f $DEST/loupe-test.* $DEST/*.tst    # Don't package test files
fi

# bookloupe is available via Homebrew on MacOS
# Linux users will need to download and build it manually.
