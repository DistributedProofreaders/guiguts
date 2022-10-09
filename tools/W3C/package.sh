#!/bin/bash

OS=$1
DEST=$2

# Exit on any failure
set -e

DEST=$DEST/W3C
mkdir $DEST
cp README.md $DEST

# css-validator.jar is the same for all systems
curl -L -o $DEST/css-validator.jar https://github.com/w3c/css-validator/releases/download/cssval-20211112/css-validator.jar

# vnu.jar is the same for all systems
VERSION=20.6.30
URL=https://github.com/validator/validator/releases/download/$VERSION/vnu.jar_$VERSION.zip
curl -L -o vnu.zip $URL
unzip vnu.zip -d .
mv dist/vnu.jar $DEST
mv dist/LICENSE $DEST/vnu-LICENSE
rm -rf dist vnu.zip

# epubcheck.jar is the same for all systems
VERSION=4.2.6
URL=https://github.com/w3c/epubcheck/releases/download/v$VERSION/epubcheck-$VERSION.zip
curl -L -o epubcheck.zip $URL
unzip epubcheck.zip -d .
mv epubcheck-$VERSION $DEST/epubcheck
rm -f epubcheck.zip 
