# Guiguts Tools

This directory contains tools, or pointers to tools, that are bundled with
Guiguts releases. Each tool has its own directory that includes:

* `README.md` describing the tool, where it is, how it is built, etc
* `package.sh` script used by the release process to package the tool in
  the release

For executable tools we refer to official release binaries where possible.
For tools without official release (i.e. Jeebies) we compile and check in
binaries for Windows and Mac distributions and simply bundle the source code
itself for the Linux distributions.

## Packaging scripts

`package.sh` scripts are passed two arguments: `OS` and `DEST_DIR`. The script
is expected to place the tool into a reasonable subdirectory of `$DEST_DIR`,
including the tool's `README.md`.

`OS` values that the script can expect:
* win
* mac
* generic

## Building scripts
`build.sh` scripts are passed one argument: `OS`. The script is expected to
perform the reasonable build steps for that platform.

`OS` values that the script can expect:
* win
* mac
* generic
