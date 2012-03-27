package Unicode::UCD;

use strict;
use warnings;

our $VERSION = '0.21';

use Storable qw(dclone);

require Exporter;

our @ISA = qw(Exporter);

our @EXPORT_OK = qw(charinfo
		    charblock charscript
		    charblocks charscripts
		    charinrange
		    compexcl
		    casefold casespec);

use Carp;

my $UNICODEFH;
my $BLOCKSFH;
my $SCRIPTSFH;
my $VERSIONFH;
my $COMPEXCLFH;
my $CASEFOLDFH;
my $CASESPECFH;

sub openunicode {
    my ($rfh, @path) = @_;
    my $f;
    unless (defined $$rfh) {
	for my $d (@INC) {
	    use File::Spec;
	    $f = File::Spec->catfile($d, "unicore", @path);
	    last if open($$rfh, $f);
	    undef $f;
	}
	croak __PACKAGE__, ": failed to find ",
              File::Spec->catfile(@path), " in @INC"
	    unless defined $f;
    }
    return $f;
}

sub _getcode {
    my $arg = shift;

    if ($arg =~ /^[1-9]\d*$/) {
	return $arg;
    } elsif ($arg =~ /^(?:[Uu]\+|0[xX])?([[:xdigit:]]+)$/) {
	return hex($1);
    }

    return;
}

# Lingua::KO::Hangul::Util not part of the standard distribution
# but it will be used if available.

eval { require Lingua::KO::Hangul::Util };
my $hasHangulUtil = ! $@;
if ($hasHangulUtil) {
    Lingua::KO::Hangul::Util->import();
}

sub hangul_decomp { # internal: called from charinfo
    if ($hasHangulUtil) {
	my @tmp = decomposeHangul(shift);
	return sprintf("%04X %04X",      @tmp) if @tmp == 2;
	return sprintf("%04X %04X %04X", @tmp) if @tmp == 3;
    }
    return;
}

sub hangul_charname { # internal: called from charinfo
    return sprintf("HANGUL SYLLABLE-%04X", shift);
}

sub han_charname { # internal: called from charinfo
    return sprintf("CJK UNIFIED IDEOGRAPH-%04X", shift);
}

my @CharinfoRanges = (
# block name
# [ first, last, coderef to name, coderef to decompose ],
# CJK Ideographs Extension A
  [ 0x3400,   0x4DB5,   \&han_charname,   undef  ],
# CJK Ideographs
  [ 0x4E00,   0x9FA5,   \&han_charname,   undef  ],
# Hangul Syllables
  [ 0xAC00,   0xD7A3,   $hasHangulUtil ? \&getHangulName : \&hangul_charname,  \&hangul_decomp ],
# Non-Private Use High Surrogates
  [ 0xD800,   0xDB7F,   undef,   undef  ],
# Private Use High Surrogates
  [ 0xDB80,   0xDBFF,   undef,   undef  ],
# Low Surrogates
  [ 0xDC00,   0xDFFF,   undef,   undef  ],
# The Private Use Area
  [ 0xE000,   0xF8FF,   undef,   undef  ],
# CJK Ideographs Extension B
  [ 0x20000,  0x2A6D6,  \&han_charname,   undef  ],
# Plane 15 Private Use Area
  [ 0xF0000,  0xFFFFD,  undef,   undef  ],
# Plane 16 Private Use Area
  [ 0x100000, 0x10FFFD, undef,   undef  ],
);

sub charinfo {
    my $arg  = shift;
    my $code = _getcode($arg);
    croak __PACKAGE__, "::charinfo: unknown code '$arg'"
	unless defined $code;
    my $hexk = sprintf("%06X", $code);
    my($rcode,$rname,$rdec);
    foreach my $range (@CharinfoRanges){
      if ($range->[0] <= $code && $code <= $range->[1]) {
        $rcode = $hexk;
	$rcode =~ s/^0+//;
	$rcode =  sprintf("%04X", hex($rcode));
        $rname = $range->[2] ? $range->[2]->($code) : '';
        $rdec  = $range->[3] ? $range->[3]->($code) : '';
        $hexk  = sprintf("%06X", $range->[0]); # replace by the first
        last;
      }
    }
    openunicode(\$UNICODEFH, "UnicodeData.txt");
    if (defined $UNICODEFH) {
	use Search::Dict 1.02;
	if (look($UNICODEFH, "$hexk;", { xfrm => sub { $_[0] =~ /^([^;]+);(.+)/; sprintf "%06X;$2", hex($1) } } ) >= 0) {
	    my $line = <$UNICODEFH>;
	    return unless defined $line;
	    chomp $line;
	    my %prop;
	    @prop{qw(
		     code name category
		     combining bidi decomposition
		     decimal digit numeric
		     mirrored unicode10 comment
		     upper lower title
		    )} = split(/;/, $line, -1);
	    $hexk =~ s/^0+//;
	    $hexk =  sprintf("%04X", hex($hexk));
	    if ($prop{code} eq $hexk) {
		$prop{block}  = charblock($code);
		$prop{script} = charscript($code);
		if(defined $rname){
                    $prop{code} = $rcode;
                    $prop{name} = $rname;
                    $prop{decomposition} = $rdec;
                }
		return \%prop;
	    }
	}
    }
    return;
}

sub _search { # Binary search in a [[lo,hi,prop],[...],...] table.
    my ($table, $lo, $hi, $code) = @_;

    return if $lo > $hi;

    my $mid = int(($lo+$hi) / 2);

    if ($table->[$mid]->[0] < $code) {
	if ($table->[$mid]->[1] >= $code) {
	    return $table->[$mid]->[2];
	} else {
	    _search($table, $mid + 1, $hi, $code);
	}
    } elsif ($table->[$mid]->[0] > $code) {
	_search($table, $lo, $mid - 1, $code);
    } else {
	return $table->[$mid]->[2];
    }
}

sub charinrange {
    my ($range, $arg) = @_;
    my $code = _getcode($arg);
    croak __PACKAGE__, "::charinrange: unknown code '$arg'"
	unless defined $code;
    _search($range, 0, $#$range, $code);
}

my @BLOCKS;
my %BLOCKS;

sub _charblocks {
    unless (@BLOCKS) {
	if (openunicode(\$BLOCKSFH, "Blocks.txt")) {
	    local $_;
	    while (<$BLOCKSFH>) {
		if (/^([0-9A-F]+)\.\.([0-9A-F]+);\s+(.+)/) {
		    my ($lo, $hi) = (hex($1), hex($2));
		    my $subrange = [ $lo, $hi, $3 ];
		    push @BLOCKS, $subrange;
		    push @{$BLOCKS{$3}}, $subrange;
		}
	    }
	    close($BLOCKSFH);
	}
    }
}

sub charblock {
    my $arg = shift;

    _charblocks() unless @BLOCKS;

    my $code = _getcode($arg);

    if (defined $code) {
	_search(\@BLOCKS, 0, $#BLOCKS, $code);
    } else {
	if (exists $BLOCKS{$arg}) {
	    return dclone $BLOCKS{$arg};
	} else {
	    return;
	}
    }
}

my @SCRIPTS;
my %SCRIPTS;

sub _charscripts {
    unless (@SCRIPTS) {
	if (openunicode(\$SCRIPTSFH, "Scripts.txt")) {
	    local $_;
	    while (<$SCRIPTSFH>) {
		if (/^([0-9A-F]+)(?:\.\.([0-9A-F]+))?\s+;\s+(\w+)/) {
		    my ($lo, $hi) = (hex($1), $2 ? hex($2) : hex($1));
		    my $script = lc($3);
		    $script =~ s/\b(\w)/uc($1)/ge;
		    my $subrange = [ $lo, $hi, $script ];
		    push @SCRIPTS, $subrange;
		    push @{$SCRIPTS{$script}}, $subrange;
		}
	    }
	    close($SCRIPTSFH);
	    @SCRIPTS = sort { $a->[0] <=> $b->[0] } @SCRIPTS;
	}
    }
}

sub charscript {
    my $arg = shift;

    _charscripts() unless @SCRIPTS;

    my $code = _getcode($arg);

    if (defined $code) {
	_search(\@SCRIPTS, 0, $#SCRIPTS, $code);
    } else {
	if (exists $SCRIPTS{$arg}) {
	    return dclone $SCRIPTS{$arg};
	} else {
	    return;
	}
    }
}

sub charblocks {
    _charblocks() unless %BLOCKS;
    return dclone \%BLOCKS;
}

sub charscripts {
    _charscripts() unless %SCRIPTS;
    return dclone \%SCRIPTS;
}

my %COMPEXCL;

sub _compexcl {
    unless (%COMPEXCL) {
	if (openunicode(\$COMPEXCLFH, "CompositionExclusions.txt")) {
	    local $_;
	    while (<$COMPEXCLFH>) {
		if (/^([0-9A-F]+)\s+\#\s+/) {
		    my $code = hex($1);
		    $COMPEXCL{$code} = undef;
		}
	    }
	    close($COMPEXCLFH);
	}
    }
}

sub compexcl {
    my $arg  = shift;
    my $code = _getcode($arg);
    croak __PACKAGE__, "::compexcl: unknown code '$arg'"
	unless defined $code;

    _compexcl() unless %COMPEXCL;

    return exists $COMPEXCL{$code};
}

my %CASEFOLD;

sub _casefold {
    unless (%CASEFOLD) {
	if (openunicode(\$CASEFOLDFH, "CaseFolding.txt")) {
	    local $_;
	    while (<$CASEFOLDFH>) {
		if (/^([0-9A-F]+); ([CFSI]); ([0-9A-F]+(?: [0-9A-F]+)*);/) {
		    my $code = hex($1);
		    $CASEFOLD{$code} = { code    => $1,
					 status  => $2,
					 mapping => $3 };
		}
	    }
	    close($CASEFOLDFH);
	}
    }
}

sub casefold {
    my $arg  = shift;
    my $code = _getcode($arg);
    croak __PACKAGE__, "::casefold: unknown code '$arg'"
	unless defined $code;

    _casefold() unless %CASEFOLD;

    return $CASEFOLD{$code};
}

my %CASESPEC;

sub _casespec {
    unless (%CASESPEC) {
	if (openunicode(\$CASESPECFH, "SpecialCasing.txt")) {
	    local $_;
	    while (<$CASESPECFH>) {
		if (/^([0-9A-F]+); ([0-9A-F]+(?: [0-9A-F]+)*)?; ([0-9A-F]+(?: [0-9A-F]+)*)?; ([0-9A-F]+(?: [0-9A-F]+)*)?; (\w+(?: \w+)*)?/) {
		    my ($hexcode, $lower, $title, $upper, $condition) =
			($1, $2, $3, $4, $5);
		    my $code = hex($hexcode);
		    if (exists $CASESPEC{$code}) {
			if (exists $CASESPEC{$code}->{code}) {
			    my ($oldlower,
				$oldtitle,
				$oldupper,
				$oldcondition) =
				    @{$CASESPEC{$code}}{qw(lower
							   title
							   upper
							   condition)};
			    if (defined $oldcondition) {
				my ($oldlocale) =
				($oldcondition =~ /^([a-z][a-z](?:_\S+)?)/);
				delete $CASESPEC{$code};
				$CASESPEC{$code}->{$oldlocale} =
				{ code      => $hexcode,
				  lower     => $oldlower,
				  title     => $oldtitle,
				  upper     => $oldupper,
				  condition => $oldcondition };
			    }
			}
			my ($locale) =
			    ($condition =~ /^([a-z][a-z](?:_\S+)?)/);
			$CASESPEC{$code}->{$locale} =
			{ code      => $hexcode,
			  lower     => $lower,
			  title     => $title,
			  upper     => $upper,
			  condition => $condition };
		    } else {
			$CASESPEC{$code} =
			{ code      => $hexcode,
			  lower     => $lower,
			  title     => $title,
			  upper     => $upper,
			  condition => $condition };
		    }
		}
	    }
	    close($CASESPECFH);
	}
    }
}

sub casespec {
    my $arg  = shift;
    my $code = _getcode($arg);
    croak __PACKAGE__, "::casespec: unknown code '$arg'"
	unless defined $code;

    _casespec() unless %CASESPEC;

    return ref $CASESPEC{$code} ? dclone $CASESPEC{$code} : $CASESPEC{$code};
}

my $UNICODEVERSION;

sub UnicodeVersion {
    unless (defined $UNICODEVERSION) {
	openunicode(\$VERSIONFH, "version");
	chomp($UNICODEVERSION = <$VERSIONFH>);
	close($VERSIONFH);
	croak __PACKAGE__, "::VERSION: strange version '$UNICODEVERSION'"
	    unless $UNICODEVERSION =~ /^\d+(?:\.\d+)+$/;
    }
    return $UNICODEVERSION;
}

1;
