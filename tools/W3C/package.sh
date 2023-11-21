#!/bin/bash

OS=$1
DEST=$2

# Exit on any failure
set -e

DEST=$DEST/W3C
mkdir $DEST
cp README.md $DEST

# css-validator.jar is the same for all systems
VERSION=20220105
curl -L -o $DEST/css-validator.jar https://github.com/w3c/css-validator/releases/download/cssval-$VERSION/css-validator.jar

# vnu.jar is the same for all systems
TAG=23.4.11
VDEST=$DEST/validator
git clone --branch $TAG https://github.com/validator/validator.git $VDEST
pushd $VDEST
python ./checker.py update-shallow build jar
mv build/dist/vnu.jar $DEST
mv LICENSE $DEST/vnu-LICENSE
popd
rm -rf $VDEST

# epubcheck.jar is the same for all systems
VERSION=5.1.0
URL=https://github.com/w3c/epubcheck/releases/download/v$VERSION/epubcheck-$VERSION.zip
curl -L -o epubcheck.zip $URL
unzip epubcheck.zip -d .
mv epubcheck-$VERSION $DEST/epubcheck
rm -f epubcheck.zip 
