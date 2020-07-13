#!/bin/bash

OS=$1
DEST=$2

# Exit on any failure
set -e

DEST=$DEST/DPSansMono
mkdir $DEST
cp README.md $DEST
