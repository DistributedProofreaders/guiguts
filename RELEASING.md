# Cutting a release

This provides instructions for publishing a new guiguts release on
Github.

1. Update the version. This needs to happen in two places:
	* `Makefile`
	* `guiguts.pl`

2. Update the `CHANGELOG.md`

3. Commit the version update changes and tag the release
   (ie: `git tag r<version>`) and push it up to github

4. From a Linux or Mac OS X system, build the generic and Windows
   releases with `make all`. This creates two .zip files:

     * one with perl scripts only
     * another with perl scripts + perl + Python + many other Windows executables

   Be certain to keep the format
   `guiguts-1.0.0.zip` (version number will vary) in order for
   the update mechanism to work correctly. Do not include
   `settings.rc` or `header.txt` as these may have been modified
   by the user and will be created if they do not exist.
   The `Makefile` takes care of this.

5. If possible, [build the MacOS X package](#macos-x-packaging-instructions).

6. Publish the release on Github.com
	1. Log into [github.com](https://github.com)
	2. Access the [guiguts releases](https://github.com/DistributedProofreaders/guiguts/releases)
	3. Select *Draft a new release*
	4. Specify the tag (ie: `r<version>`)
	5. Specify the title (ie: `<version>`)
	6. Describe the release - can be a copy/paste of the `CHANGELOG.md`
	   details for the release
	7. Attach the .zip files
	8. Publish release

## MacOS X packaging instructions
_courtesy of Frau Sma_

1. First install Getopt::ArgvFile, Module::ScanDeps, PAR::Dist and PAR
from CPAN. You may need to force install Getopt::ArgvFile.

2. Grab the [Par Packager](http://search.cpan.org/~rschupp/PAR-Packer-1.010/lib/pp.pm)
and install it.

3. Manually edit `/usr/local/bin/pp` so that it uses `/usr/bin/perl5.10`
instead of `/usr/bin/perl`; this is only necessary if you're running GG
using a non-default (to the system) Perl--as I am on my Lion
installation. (OS X usually comes with two versions of Perl. For Lion,
that's 5.10 and 5.12, 5.12 being the system default. I couldn't get GG
to work in 5.12, so I'm using 5.10 for it, but I didn't want to change
the system default just for that.)

4. Copy `trans_cur.xbm` and `trans_cur.mask` from
`/Library/Perl/<Perl version>/darwin-thread-multi-2level/Tk/` to `lib/Tk/`
inside the GG folder. This was necessary because otherwise it would
complain at run-time that it couldn't find these, and I couldn't find
another way to easily include them; and this works, so I didn't care to
experiment with it any more than this.

5. Run pp, using the following command:
```
pp -a lib/Tk/ToolBar/tkIcons -a lib/Tk/trans_cur.xbm \
   -a lib/Tk/trans_cur.mask -I lib -M Tk::Image -M Tk::Bitmap \
   -M Tk::JPEG -M Tk::Pane -M Tk::PNG -M Tk::ToolBar \
   -M Tk::ProgressBar -M Tk::CursorControl \
   -o ../Guiguts-pp/guiguts guiguts.pl
```

They say that pp will automagically detect dependencies, but that didn't
work for some of them for me, so I had to manually add them to the list.
I'm not sure whether all of them are really needed, I haven't gone back
and tried removing any to see whether it would break. I think
Tk::CursorControl might not be necessary after all. But again, it worked
like that, so I left it like that.

You need to include `headerdefault.txt`.
