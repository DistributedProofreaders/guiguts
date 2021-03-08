# jeebies

Tool created by Jim Tinsley to detect common stealth scannos.
https://www.pgdp.net/wiki/PPTools/Jeebies

## Packaging

We include a pre-built binary for Windows. For other platforms we
ship the files necessary to build Jeebies.

We no longer include a macOS binary in the Guiguts download. In modern
versions of macOS, binaries downloaded from the internet won't run unless
signed by a developer certificate. Since Guiguts is maintained by volunteers
(and we don't maintain the Jeebies code), we're including the source code for
users to build themselves.

## Building

Building Jeebies is very simple, as it only has the single `jeebies.c` source
file. A `Makefile` is included to make this brainless, however:

```
make build
```
