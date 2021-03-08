#!/bin/bash

OS=$1

# Exit on any failure
set -e

if [[ $OS == "win" ]]; then
    echo "Nothing to build on Windows. Use jeebies.exe"
else
    make build
fi

