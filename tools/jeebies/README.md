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

The `jeebies` executable is built from a single C source file that requires
two include files created from the original `he.jee` and `be.jee` data files.
Use the included `Makefile` to build the executable:

```
make build
```

### Moving to a better location

Building Jeebies will create a `jeebies` executable in the `tools/jeebies`
directory. Installing newer versions of Guiguts will require rebuilding the
tool unless you move it someplace outside of the Guiguts directory.

To persist the tool across Guiguts upgrades you can move the `jeebies` binary
to any location outside the Guiguts directory and point Guiguts to it.
On macOS the following are some reasonable locations:
* Intel-based: `/usr/local/bin`
* M1-based: `/opt/homebrew/bin`
