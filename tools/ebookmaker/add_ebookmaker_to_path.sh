#!/bin/sh

PYTHON_PATH=~/Library/Python/3.7/bin

# Check to see if the path has already been updated. This only checks if the
# current env variable is correct, but it's something.
if [[ $(echo $PATH | grep -c $PYTHON_PATH) -ge 1 ]]; then
    echo "PATH appears to have been updated already"
    exit 1
fi

# Find the right shell
if [[ $SHELL == "/bin/zsh" ]]; then
    PROFILE=~/.zprofile
elif [[ $SHELL == "/bin/bash" ]]; then
    if [[ -e ~/.profile ]]; then
        PROFILE=~/.profile
    else
        PROFILE=~/.bash_profile
    fi
else
    echo "Unable to determine your profile location based on your shell"
    exit 1
fi

# Do the update
echo "Updating $PROFILE with PATH $PYTHON_PATH"
echo "export PATH=\$PATH:$PYTHON_PATH" >> $PROFILE

echo "Close this terminal and open a new one to pick up the updated path"