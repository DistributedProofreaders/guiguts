# Installation

These instructions cover a fresh install of Guiguts. If you are upgrading,
see [UPGRADE.md](UPGRADE.md) before beginning.

Please direct any help requests to the
[DP forum Help with: guiguts thread](https://www.pgdp.net/phpBB2/viewtopic.php?t=11466).

See also https://www.pgdp.net/wiki/PPTools/Guiguts/Install

## Windows

Using Guiguts on Windows requires installing the following pieces:

* Perl
* Guiguts
* [Perl modules](#perl-modules)
* [Java](#java) (if you want to use the bundled HTML and CSS checkers)

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

1. Download [Strawberry Perl](http://strawberryperl.com/).
2. Double click the downloaded file to install Strawberry Perl. It is
   recommended that you install in the default folder `c:\Strawberry`.
3. Download the latest `guiguts-win-n.n.n.zip` from the
   [Guiguts releases](https://github.com/DistributedProofreaders/guiguts/releases) page.
4. Unzip `guiguts-win-n.n.n.zip` to some location on your computer (double
   click the zip file). A common place for this is `c:\guiguts` although it can
   be placed anywhere.
5. Using File Explorer, navigate to the `guiguts` folder you unzipped earlier.
6. Double click the file `install_cpan_modules.pl`. This should display a
   command window listing the Perl modules as it installs them. Note that this
   can take several minutes to complete.
   If instead, Windows says it does not know how to run that file, or it opens
   the file in a text editor like Notepad, you will need to re-associate `.pl` 
   files with the Perl program/app. Follow the steps in the footnote below[^1],
   then return to re-try this step.
7. Double click the `run_guiguts.bat` file in the same folder, and Guiguts
   should start up and be ready for use. Open the `Preferences` menu, then
   `File Paths`, then select `Copy Settings From A Release`. Use the dialog
   that pops up to select the top level of the release (eg: `c:\guiguts`).
   This should be the folder that contains `guiguts.pl`, `headerdefault.txt`,
   etc. Using this option will copy necessary configuration files from the
   release into a new folder named `%HOMEPATH%\Documents\GGprefs` where
   %HOMEPATH% is your home directory, e.g. `C:\Users\user1\Documents\GGprefs`.
   When you have done this once, you will not normally need to do it again
   because all your settings will be safe in the `GGprefs` folder.
8. If you want to use the Spell Check tool, see the
   [Guiguts Windows Installation](https://www.pgdp.net/wiki/PPTools/Guiguts/Install)
   wiki page for information on installing the Aspell spell checker. If you
   intend to use the new Spell Query tool instead, you do not need Aspell.
   The same wiki page describes how to install an image viewer to display scans
   and edit images. You can also find out how to obtain the Calibre e-book
   software suite if you want your local version of ebookmaker to create Kindle
   files in addition to epub files.
9. Install [Java](#java) to be able to check your HTML and CSS from within
   Guiguts.

[^1]: _Only needed if double-clicking `install_cpan_modules.pl` was
unsuccessful,_ (may vary slightly for different versions of Windows):
   1. Right-click `install_cpan_modules.pl` in File Explorer, and choose
      `Open with`.
   2. Choose `More apps` (may say "Choose Default Program" on some systems)
   3. Scroll to the bottom then choose `Look for another app on this PC`
      (may say "Browse" on some systems)
   4. Navigate to `c:\Strawberry\perl\bin` and choose `perl.exe`.
   5. Return to re-attempt the "Double-click `install_cpan_modules.pl`" step.


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


## macOS

To use Guiguts you need to be running macOS High Sierra (10.13) or higher.
If you're running a version of macOS that is newer than that, but out of
support by Apple, you may get warnings about some components no longer
working. Running Guiguts on macOS requires installing the following pieces
of software. The list may seem intimidating but it's rather straightforward
and only needs to be done once. These instructions walk you through it.

* Guiguts code
* [Xcode Command Line Tools](https://developer.apple.com/library/archive/technotes/tn2339/_index.html)
* [Homebrew](https://brew.sh/)
* [XQuartz](https://www.xquartz.org/)
* Perl & [Perl modules](#perl-modules)

This is necessary because the version of Perl that comes with macOS does not
have the necessary header files to build the Perl package dependencies that
Guiguts requires.

### Extracting Guiguts

Download and unzip `guiguts-mac-n.n.n.zip` to some location on your
computer (double click the zip file in Finder or run
`unzip guiguts-mac-n.n.n.zip` on the command line). You can move the
`guiguts` directory it creates to anywhere you want. A common place
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

[Homebrew](https://brew.sh/) is a package manager for macOS that provides the
version of Perl and relevant Perl modules that Guiguts needs. To install it,
your user account must have Administrator rights on the computer.

Open Terminal.app and install Homebrew with:

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
```

You will be prompted for your password and walked through the installation.
You can accept the defaults it presents to you. The prompt for your password
will probably show a small key icon, and will not display any characters as
you type in your password.

If you already have homebrew installed, it's a good idea to update/upgrade
it before starting this process.

### XQuartz

XQuartz is an X11 windows manager. If you don't have it installed already, you
can either:
* Download and install it manually from [xquartz.org](https://www.xquartz.org/)
* Install it with Homebrew using
  ```
  brew install --cask xquartz
  ```

After you install XQuartz, you must ***log out and back in*** to your account
on your computer, or reboot, before Guiguts can use it as the X11 server.

There are a couple of X11 preferences that can be useful for GG users.

* Under the `Input` tab, check the "Follow system keyboard layout" option.
  This will allow you to type in Greek.
* Under the `Windows` tab, click the "Click-through Inactive Windows" tab.
  This will allow clicking in popup windows (such as Spell Query) to pass
  the command straight through to the open document.

### Perl & Perl modules

Using Terminal.app, use Homebrew to install Perl and cpanm:

```
brew install perl
brew pin perl
brew install cpanm
```

Close Terminal.app and reopen it to ensure that the brew-installed perl is on
your path.

Then install all the necessary [Perl modules](#perl-modules).

In a Terminal window, navigate to your guiguts folder. There should be a
file named `install_cpan_modules.pl` in the directory. Installing these
modules is most easily done by running the helper script:

```
perl install_cpan_modules.pl
```

### Starting Guiguts

Guiguts can be started directly from the Terminal with:
```
perl guiguts.pl &
```

To add it to your Dock, you can use the `guiguts.command` file. First, remove
it from Apple's quarantine with:
```
xattr -d com.apple.quarantine guiguts.command
```

Now you can double click it to run Guiguts or drag the file to your Dock
for a one-click start.

### Preserving settings and customizations

Once you are in Guiguts, open the `Preferences` menu, then `File Paths`,
then select `Copy Settings From A Release`. Use the dialog that pops up to
select the top level guiguts directory you created earlier. This should be
the folder that contains `guiguts.pl`, `headerdefault.txt`, etc. Using this
option will copy necessary configuration files from the release into a new
folder named `HOME/Documents/GGprefs` where `HOME` is your home directory.
When you have done this once, you will not normally need to do it again
because all your settings will be safe in the `GGprefs` folder.

### Helper applications

Homebrew provides some additional helper applications you might find useful
(aspell is used for Spell Check, but not the new Spell Query tool):

```
brew install aspell
brew install bookloupe
brew install tidy-html5
brew install open-sp
```

See also the [Jeebies installation instructions](tools/jeebies/README.md).

See also the [EBookMaker installation instructions](tools/ebookmaker/README.md).

You will also need to obtain the
[Calibre e-book software suite](https://calibre-ebook.com/download) if you want your
local version of ebookmaker to create Kindle files in addition to epub files.

Install [Java](#java) to be able to check your HTML and CSS from within
Guiguts.
   
## Other

For other platforms, you will need to install Perl, the necessary
[Perl modules](#perl-modules) and possibly [Java](#java).
Then extract `guiguts-generic-n.n.n.zip` and run
```
perl guiguts.pl
```

Follow the instructions in the
[Preserving settings and customizations](#preserving-settings-and-customizations) 
section for macOS above. Your GGprefs folder will be `$HOME/.GGprefs`.

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
4. (optional) Follow the instructions in [UPGRADE.md](UPGRADE.md) that describe
   how to set up a `GGprefs` directory and customize `header.txt`.

You can now run Guiguts from the `src/` directory.

Git will ignore the `src/tools/` directory as well as the files that Guiguts
creates allowing you to work with a pristine checkout for pulling updates and
other git activities.

## Perl Modules

Guiguts requires several Perl modules to be installed via CPAN:

The required Perl modules can be installed with the included helper script:
```
perl install_cpan_modules.pl
```

*Or* you can install them individually using `cpanm`. You should refer to the
helper script `install_cpan_modules.pl` for an up-to-date list of the modules
required, and then install each one, for example:
```
cpanm --notest --install File::HomeDir
cpanm --notest --install Tk
etc...
```

On some systems (reported by Ubuntu user) it may be necessary to install
`perl-tk` and `zlib1g-dev` using the following commands before installing the
Perl modules above, 
```
sudo apt-get update
sudo apt-get install perl-tk 
sudo apt-get install zlib1g-dev
```

## Java

Follow the instructions at [java.com](https://java.com) to install the
Java Runtime Environment if you want to be able to check your HTML and CSS
from within Guiguts. Java is free for personal use, and is used by many
applications and some websites, so you may already have it installed on
your system. Without Java, you will need to check your HTML and CSS using
the W3C online validators.