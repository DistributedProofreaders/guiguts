# Installation

Upgrading requires a complete reinstall (save `header.txt`, `setting.rc`,
and any files you wish to keep in the `data/` directory, although in
theory these should not be overwritten).

Please direct any help requests to the
[DP forum Guiguts thread](https://www.pgdp.net/phpBB2/viewtopic.php?t=3075).

See also https://www.pgdp.net/wiki/PPTools/Guiguts/Install

## Windows

The Windows release includes:
* Guiguts
* a bundled version of Perl

It does not include an image viewer or a spell checker.

To install, unzip the the file `guiguts-win-n.n.n.zip` into a directory. This
extracts Guiguts as well as a bundled version of Perl 5.8. To run Guiguts, change
into the directory you extracted the files into and run `run_guiguts.bat`. This
batch file prepends the bundled version of Perl onto your path and starts the
program.

Other distributions of versions of Perl, such as
[Strawberry Perl](http://strawberryperl.com/) or
[ActiveState Perl](https://www.activestate.com/products/perl/) may be used
after installing additional [Perl modules](#perl-modules). Strawberry Perl 5.12
or earlier and ActiveState Perl 5.10 or earlier, are both known to work. Later
versions of ActiveState Perl will not successfully install Tk and cannot be used
with Guiguts.

You will also need to install helper applications to view images and to
spell check.

## MacOS

To use Guiguts you need to be running macOS High Sierra (10.13) or higher.
Running Guiguts on MacOS requires installing the following pieces of software.
The list may seem intimidating but it's rather straightforward and only needs
to be done once. These instructions walk you through it.

* [Xcode Command Line Tools](https://developer.apple.com/library/archive/technotes/tn2339/_index.html)
* [Homebrew](https://brew.sh/)
* Perl & [Perl modules](#perl-modules)
* [XQuartz](https://www.xquartz.org/)

This is necessary because the version of Perl that comes with MacOS does not
have the necessary header files to build the Perl package dependencies that
Guiguts requires.

### XCode Command Line Tools

Homebrew requires either the
[Xcode Command Line Tools](https://developer.apple.com/library/archive/technotes/tn2339/_index.html)
or full [Xcode](https://apps.apple.com/us/app/xcode/id497799835). If you
have the full Xcode installed, skip this step. Otherwise, install the Xcode
Command Line tools by opening Terminal.app and running:

```
xcode-select --install
```

### Homebrew

[Homebrew](https://brew.sh/) is a package manager for MacOS that provides the
version of Perl and relevant Perl modules that Guiguts needs. To install it,
your user account must have Administrator rights on the computer.

Open Terminal.app and install Homebrew with:

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
```

You will be prompted for your password and walked through the installation.
You can accept the defaults it presents to you.

### Perl & Perl modules

Using Terminal.app, use Homebrew to install Perl and cpanm:

```
brew install perl
brew pin perl
brew install cpanm
```

Close Terminal.app and reopen it to ensure that the brew-installed perl is on
your path. Then install all the necessary [Perl modules](#perl-modules). This
is most easily done by running the helper script:

```
perl install_cpan_modules.pl
```

You can install them manually with `cpanm` however if you want, for example:
```
cpanm --notest --install LWP::UserAgent
```

### XQuartz

[XQuartz](https://www.xquartz.org/) is an X11 windows manager. If you don't
have it installed already, you can either download and install it manually
via the link _or_ install it with Homebrew using:

```
brew cask install xquartz
```

After you install XQuartz, you must **log out and back in** before Guiguts can
use it as the X11 server.

### Extracting & running Guiguts

Finally, unzip `guiguts-n.n.n.zip` to some location on your computer (double
click the zip file in Finder or run `unzip guiguts-n.n.n.zip` on the command
line).

Start Guiguts with:
```
perl guiguts.pl &
```

## Other

For other platforms, you will need to install Perl and the necessary
[Perl modules](#perl-modules). Then extract `guiguts-n.n.n.zip` and run
```
perl guiguts.pl
```

## Perl Modules

Guiguts requires the following Perl modules to be installed via CPAN:

* LWP::UserAgent
* Tk
* Tk::ToolBar
