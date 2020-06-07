# Installation

Upgrading requires a complete reinstall (save `header.txt`, `setting.rc`,
and any files you wish to keep in the `data/` directory, although in
theory these should not be overwritten).

Please direct any help requests to the
[DP forum Guiguts thread](http://www.pgdp.net/phpBB2/viewtopic.php?t=3075).

See also http://www.pgdp.net/wiki/PPTools/Guiguts/Install

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

To install Guiguts on MacOS, first install [Homebrew](https://brew.sh/):

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
```

Then use Homebrew to install Perl. This is necessary because the version of Perl
that comes with MacOS does not have the necessary header files to build the
Guiguts Perl package dependencies.

```
brew install perl
brew install cpanm
```

Close the Terminal and open a new one to ensure that the brew-installed perl
is on your path. Then install all the necessary [Perl modules](#perl-modules)
using `cpanm`.

For example:
```
cpanm --notest --install Tk
```

Now unzip `guiguts-n.n.n.zip` and start Guiguts with:
```
perl guiguts.pl
```

## Other

For other platforms, you will need to install Perl and the necessary
[Perl modules](#perl-modules). Then extract `guiguts-n.n.n.zip` and run
```
perl guiguts.pl
```

## Perl Modules

Guiguts requires the following Perl modules to be installed via CPAN:

* HTML::TokeParser
* LWP::UserAgent
* Tk
* Tk::ToolBar
