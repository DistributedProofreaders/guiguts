#!/bin/bash

OS=$1
DEST=$2

# Exit on any failure
set -e

DEST=$DEST/DPCustomMono2
mkdir $DEST
cp README.md $DEST

# Just copy the font over
cp DPCustomMono2.ttf $DEST
