# Installation

These instructions cover a fresh install of Guiguts. If you are upgrading,
see [UPGRADE.md](UPGRADE.md) before beginning.

Please direct any help requests to the
[DP forum Help with: guiguts thread](https://www.pgdp.net/phpBB2/viewtopic.php?t=11466).

See also https://www.pgdp.net/wiki/PPTools/Guiguts/Install

## Windows

Using Guiguts on Windows requires installing the following pieces:

* Guiguts
* Perl
* [Perl modules](#perl-modules)

These instructions walk you through using
[Strawberry Perl](http://strawberryperl.com/). Strawberry Perl is the
recommended Perl interpreter as that is what the developers have tested, it
supports the latest version of Perl, and includes all necessary Perl modules.
It can coexist along side other interpreters.

_If you have an existing Perl distribution installed (including if you are
hoping to use the Perl distributed with a previous Guiguts release),
read [Other Perl distributions](#other-perl-distributions) before following
the Recommended installation procedure below, as it describes edits you may
need to make if not using the standard setup. If following the standard
procedure below, there is no need to remove your old version of Guiguts - it
should continue to use its own bundled Perl._

### Recommended installation procedure

Unless you are confident with editing `.bat` files and altering the system
PATH variable, please use the recommended instructions and directory names
below. 

_Note that you must do step 6, even if you have done it previously, as
the version of Guiguts you are installing may require additional Perl modules
to any previous versions._

1. Download the latest `guiguts-win-n.n.n.zip` from the
   [Guiguts releases](https://github.com/DistributedProofreaders/guiguts/releases) page.
2. Unzip `guiguts-win-n.n.n.zip` to some location on your computer (double click
   the zip file). A common place for this is `c:\guiguts` although it can be placed
   anywhere.
3. Download [Strawberry Perl](http://strawberryperl.com/).
4. Double click the downloaded file to install Strawberry Perl. It is
   recommended that you install in the default folder `c:\Strawberry`.
5. Using File Explorer, navigate to the `guiguts` folder you unzipped earlier.
6. Double click the file `install_cpan_modules.pl`. This should display a command
   window listing the Perl modules as it installs them. Note that this can take
   several minutes to complete.
   (If instead, Windows says it does not know how to run that file, then right-click
   `install_cpan_modules.pl`, and choose `Open with`. Then choose `More apps`,
   scroll to the bottom then choose `Look for another app on this PC`, navigate to
   `c:\Strawberry\perl\bin` and choose `perl.exe`.)
7. Double click the `run_guiguts.bat` file in the same folder, and Guiguts should
   start up and be ready for use.
8. See the [Guiguts Windows Installation](https://www.pgdp.net/wiki/PPTools/Guiguts/Install)
   wiki page for information on installing the Aspell spell checker and an image
   viewer to display scans and edit images.


### Other Perl distributions

_This section is for advanced users only. Most Guiguts Windows users should follow the
[Recommended installation procedure](#recommended-installation-procedure) above and
can skip this section._

When installing the Perl modules, either with the helper script or manually
running `cpanm`, ensure that the Strawberry Perl versions of `perl` and `cpanm`
are the ones being run. Both programs have a `--version` argument you can use
to see which version of perl is being run. Ensure the version matches that of
Strawberry Perl you installed. Note that ActiveState Perl puts its directories
at the front of the path and Strawberry Perl puts its directories at the end
of the path.

If you have multiple Perl distributions installed you should edit the
`run_guiguts.bat` file and adjust the PATH to the version you want to run
Guiguts. The batch file prepends the default Strawberry Perl directories to the
path and will preferentially use it if available. If your setup is complex, it
may be easiest to clear your path in `run_guiguts.bat` before directories are
added. To do this, directly below the line which saves your existing path,
`set OLDPATH=%PATH%`
add the following line
`set PATH=`

Other Perl distributions, such as
[ActiveState Perl](https://www.activestate.com/products/perl/), may be used
to run Guiguts after installing additional [Perl modules](#perl-modules). Note
that ActiveState Perl versions after 5.10 will not successfully install Tk and
cannot be used with Guiguts.

The bundled perl interpreter included with Guiguts 1.0.25 may also work but
is no longer maintained. The bundled perl includes the required modules
used in 1.0.25 which may not be the full set needed by later versions.

While not officially supported, if you wish to use the perl included with
Guiguts 1.0.25, copy the `perl` directory from the top level directory of
your 1.0.25 installation to the top level of your new installation,
e.g. copy the `perl` directory from `C:\dp\guiguts\guiguts-win-1.0.25` to
`C:\dp\guiguts\guiguts-win-1.1.0`. You also need to copy the `Tk` directory
from the old `lib` directory to the new one, e.g. copy the `Tk` directory from
`C:\dp\guiguts\guiguts-win-1.0.25\lib` to `C:\dp\guiguts\guiguts-win-1.1.0\lib`


## MacOS

To use Guiguts you need to be running macOS High Sierra (10.13) or higher.
Running Guiguts on MacOS requires installing the following pieces of software.
The list may seem intimidating but it's rather straightforward and only needs
to be done once. These instructions walk you through it.

* Guiguts code
* [Xcode Command Line Tools](https://developer.apple.com/library/archive/technotes/tn2339/_index.html)
* [Homebrew](https://brew.sh/)
* Perl & [Perl modules](#perl-modules)
* [XQuartz](https://www.xquartz.org/)

This is necessary because the version of Perl that comes with MacOS does not
have the necessary header files to build the Perl package dependencies that
Guiguts requires.

### Extracting Guiguts

Unzip `guiguts-mac-n.n.n.zip` to some location on your computer (double click the
zip file in Finder or run `unzip guiguts-mac-n.n.n.zip` on the command line). You
can move the `guiguts` directory it creates to anywhere you want. A common place
for this is your home directory.

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

### XQuartz

[XQuartz](https://www.xquartz.org/) is an X11 windows manager. If you don't
have it installed already, you can either download and install it manually
via the link _or_ install it with Homebrew using:

```
brew cask install xquartz
```

After you install XQuartz, you must **log out and back in** before Guiguts can
use it as the X11 server.

### Starting Guiguts

Start Guiguts with:
```
perl guiguts.pl &
```

### Helper applications

Homebrew provides some additional helper applications you might find useful:

```
brew install aspell
brew install bookloupe
brew install tidy-html5
brew install open-sp
```

See also the [EBookMaker installation instructions](tools/ebookmaker/README.md).

## Other

For other platforms, you will need to install Perl and the necessary
[Perl modules](#perl-modules). Then extract `guiguts-generic-n.n.n.zip` and run
```
perl guiguts.pl
```

## Using Guiguts from a Git checkout

_This section is for advanced users who want to run the latest in-development
version of Guiguts and are comfortable with git._

You can run Guiguts directly from the git repo with a few small changes.

1. Clone the [Guiguts repo](https://github.com/DistributedProofreaders/guiguts)
   somewhere. You'll find the main Guiguts files (`guigut.pl`,
   `install_cpan_modules.pl`) in `src/`.
2. Install the necessary system dependencies (perl, perl modules, etc) as
   specified in the sections above.
3. Create a fully-populated `src/tools/` directory by copying one from a full
   release.
4. (optional) Run Guiguts once from `src/` to create the initial Guiguts data
   files (`header.txt`, etc). Copy any manual edits you had made to these files
   into the new versions of the files in `src/` if you want to retain them.

You can now run Guiguts from the `src/` directory.

Git will ignore the `src/tools/` directory as well as the files that Guiguts
creates allowing you to work with a pristine checkout for pulling updates and
other git activities.

## Perl Modules

Guiguts requires the following Perl modules to be installed via CPAN:

* LWP::UserAgent
* Tk
* Tk::ToolBar

The following modules are optional but recommended in order to provide
all available functionality, such as auto-generating HTML image sizes, 
online HTML validation, checking for updates, etc:

* Text::LevenshteinXS
* File::Which
* Image::Size
* LWP::Protocol::https
* WebService::Validator::HTML::W3C
* XML::XPath

The required Perl modules can be installed with the included helper script:
```
perl install_cpan_modules.pl
```

*Or* you can install them individually using `cpanm`. For example:
```
cpanm --notest --install LWP::UserAgent
```
