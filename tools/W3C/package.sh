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
