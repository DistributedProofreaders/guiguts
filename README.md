# Guiguts

Guiguts is a Perl/Tk text editor designed for editing and formatting public
domain material for inclusion at [Project Gutenberg](http://www.gutenberg.org).
Features are provided for editing text files produced by
[Distributed Proofreaders](https://www.pgdp.net).

For help or to contact the developers, see the
[Help with: guiguts forum](https://www.pgdp.net/phpBB3/viewtopic.php?t=11466)
hosted at Distributed Proofreaders.

This code was originally hosted at
[Sourceforge](https://sourceforge.net/projects/guiguts/).

## Download

Download Guiguts from the project's
[GitHub releases](https://github.com/DistributedProofreaders/guiguts/releases) page.

Older binaries are still available from the deprecated
[Guiguts project at Sourceforge](https://sourceforge.net/projects/guiguts/files/guiguts/).

## Installation

If you are upgrading from an earlier version of Guiguts, see
[UPGRADE.md](UPGRADE.md).

To install Guiguts see [INSTALL.md](INSTALL.md).

For troubleshooting tips, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md).

## Development

### Code style

Guiguts uses [perltidy](https://metacpan.org/pod/Perl::Tidy) for consistent
styling using configuration options in `.perltidyrc`. You can install perltidy
with `cpanm --installdeps --notest --with-develop .` including the dot at the end.

`format_files.sh` can be used to format one or more files. If used with
`--check` it will validate that the files match the perltidy format.

This project uses Travis CI to validate formatting for each MR.
