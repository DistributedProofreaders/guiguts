# Troubleshooting

Here are some troubleshooting tips for getting Guiguts running.

## macOS

### Unable to start Guiguts

If Guiguts shows errors connecting to the X11 server, try starting Guiguts
from within an X11 terminal instead of Terminal.app. To do this:

1. Start XQuartz with Applications -> Utilities -> XQuartz
2. Open a terminal from the XQuartz menu with Applications -> Terminal
3. Within the xterm terminal, navigate to your Guiguts install directory
4. Start guiguts with `perl guiguts.pl`

### Guiguts no longer runs after a macOS upgrade

After upgrading macOS, either to a new release of an existing version or to
an entirely new version of the operating system, Guiguts may no longer start.
One thing to try is to reinstall and upgrade some of the Guiguts dependencies.
In Terminal.app, run:

```bash
# uninstall and re-install the XCode CLI
sudo rm -rf /Library/Developer/CommandLineTools
sudo xcode-select --install

# update homebrew and all packages, including perl
brew update
brew unpin perl
brew upgrade

# re-pin perl
brew pin perl

# re-install the Guiguts packages using install_cpan_modules.pl
# see INSTALL.md for more information on installing packages
perl install_cpan_modules.pl
```

If the above did not fix the problem, also upgrade XQuartz:
* If you installed XQuartz from homebrew, the steps above will have updated
  it for you.
* If you installed XQuartz manually from [xquartz.org](https://www.xquartz.org/),
  download and install the latest version.
