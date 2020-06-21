#!/bin/bash

CHECK=0
if [[ $1 == "--check" ]]; then
    CHECK=1
    shift
fi

FILES=$*

if [[ ! $FILES ]]; then
    FILES=$(find . -name '*.pl' -o -name '*.pm')
fi

for file in $FILES; do
    echo $file
    perltidy --profile=.../.perltidyrc $file
    if [[ $CHECK == 1 ]]; then
        diff $file $file.tdy 2>&1
        DIFF_RESULT=$?
        rm $file.tdy
        if [[ $DIFF_RESULT -ne 0 ]]; then
            echo $file formatting does not match
            exit 1
        fi
    else
        cmp -s $file $file.tdy
        CMP_RESULT=$?
        if [[ $CMP_RESULT -ne 0 ]]; then
            echo $file tidied
            mv $file.tdy $file
        else
            rm $file.tdy
        fi
    fi
done
