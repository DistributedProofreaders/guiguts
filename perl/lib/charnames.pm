package charnames;
use strict;
use warnings;
use Carp;
use File::Spec;
our $VERSION = '1.02';

use bytes ();		# for $bytes::hint_bits
$charnames::hint_bits = 0x20000; # HINT_LOCALIZE_HH

my %alias1 = (
		# Icky 3.2 names with parentheses.
		'LINE FEED'		=> 'LINE FEED (LF)',
		'FORM FEED'		=> 'FORM FEED (FF)',
		'CARRIAGE RETURN'	=> 'CARRIAGE RETURN (CR)',
		'NEXT LINE'		=> 'NEXT LINE (NEL)',
		# Convenience.
		'LF'			=> 'LINE FEED (LF)',
		'FF'			=> 'FORM FEED (FF)',
		'CR'			=> 'CARRIAGE RETURN (CR)',
		'NEL'			=> 'NEXT LINE (NEL)',
	        # More convenience.  For futher convencience,
	        # it is suggested some way using using the NamesList
		# aliases is implemented.
	        'ZWNJ'			=> 'ZERO WIDTH NON-JOINER',
	        'ZWJ'			=> 'ZERO WIDTH JOINER',
		'BOM'			=> 'BYTE ORDER MARK',
	    );

my %alias2 = (
		# Pre-3.2 compatibility (only for the first 256 characters).
		'HORIZONTAL TABULATION'	=> 'CHARACTER TABULATION',
		'VERTICAL TABULATION'	=> 'LINE TABULATION',
		'FILE SEPARATOR'	=> 'INFORMATION SEPARATOR FOUR',
		'GROUP SEPARATOR'	=> 'INFORMATION SEPARATOR THREE',
		'RECORD SEPARATOR'	=> 'INFORMATION SEPARATOR TWO',
		'UNIT SEPARATOR'	=> 'INFORMATION SEPARATOR ONE',
		'PARTIAL LINE DOWN'	=> 'PARTIAL LINE FORWARD',
		'PARTIAL LINE UP'	=> 'PARTIAL LINE BACKWARD',
	    );

my %alias3 = (
		# User defined aliasses. Even more convenient :)
	    );
my $txt;

sub alias (@)
{
  @_ or return %alias3;
  my $alias = ref $_[0] ? $_[0] : { @_ };
  @alias3{keys %$alias} = values %$alias;
} # alias

sub alias_file ($)
{
  my ($arg, $file) = @_;
  if (-f $arg && File::Spec->file_name_is_absolute ($arg)) {
    $file = $arg;
  }
  elsif ($arg =~ m/^\w+$/) {
    $file = "unicore/${arg}_alias.pl";
  }
  else {
    croak "Charnames alias files can only have identifier characters";
  }
  if (my @alias = do $file) {
    @alias == 1 && !defined $alias[0] and
      croak "$file cannot be used as alias file for charnames";
    @alias % 2 and
      croak "$file did not return a (valid) list of alias pairs";
    alias (@alias);
    return (1);
  }
  0;
} # alias_file

# This is not optimized in any way yet
sub charnames
{
  my $name = shift;

  if (exists $alias1{$name}) {
    $name = $alias1{$name};
  }
  elsif (exists $alias2{$name}) {
    require warnings;
    warnings::warnif('deprecated', qq{Unicode character name "$name" is deprecated, use "$alias2{$name}" instead});
    $name = $alias2{$name};
  }
  elsif (exists $alias3{$name}) {
    $name = $alias3{$name};
  }

  my $ord;
  my @off;
  my $fname;

  if ($name eq "BYTE ORDER MARK") {
    $fname = $name;
    $ord = 0xFEFF;
  } else {
    ## Suck in the code/name list as a big string.
    ## Lines look like:
    ##     "0052\t\tLATIN CAPITAL LETTER R\n"
    $txt = do "unicore/Name.pl" unless $txt;

    ## @off will hold the index into the code/name string of the start and
    ## end of the name as we find it.

    ## If :full, look for the name exactly
    if ($^H{charnames_full} and $txt =~ /\t\t\Q$name\E$/m) {
      @off = ($-[0], $+[0]);
    }

    ## If we didn't get above, and :short allowed, look for the short name.
    ## The short name is like "greek:Sigma"
    unless (@off) {
      if ($^H{charnames_short} and $name =~ /^(.+?):(.+)/s) {
	my ($script, $cname) = ($1, $2);
	my $case = $cname =~ /[[:upper:]]/ ? "CAPITAL" : "SMALL";
	if ($txt =~ m/\t\t\U$script\E (?:$case )?LETTER \U\Q$cname\E$/m) {
	  @off = ($-[0], $+[0]);
	}
      }
    }

    ## If we still don't have it, check for the name among the loaded
    ## scripts.
    if (not @off) {
      my $case = $name =~ /[[:upper:]]/ ? "CAPITAL" : "SMALL";
      for my $script (@{$^H{charnames_scripts}}) {
	if ($txt =~ m/\t\t$script (?:$case )?LETTER \U\Q$name\E$/m) {
	  @off = ($-[0], $+[0]);
	  last;
	}
      }
    }

    ## If we don't have it by now, give up.
    unless (@off) {
      carp "Unknown charname '$name'";
      return "\x{FFFD}";
    }

    ##
    ## Now know where in the string the name starts.
    ## The code, in hex, is before that.
    ##
    ## The code can be 4-6 characters long, so we've got to sort of
    ## go look for it, just after the newline that comes before $off[0].
    ##
    ## This would be much easier if unicore/Name.pl had info in
    ## a name/code order, instead of code/name order.
    ##
    ## The +1 after the rindex() is to skip past the newline we're finding,
    ## or, if the rindex() fails, to put us to an offset of zero.
    ##
    my $hexstart = rindex($txt, "\n", $off[0]) + 1;

    ## we know where it starts, so turn into number -
    ## the ordinal for the char.
    $ord = hex substr($txt, $hexstart, $off[0] - $hexstart);
  }

  if ($^H & $bytes::hint_bits) {	# "use bytes" in effect?
    use bytes;
    return chr $ord if $ord <= 255;
    my $hex = sprintf "%04x", $ord;
    if (not defined $fname) {
      $fname = substr $txt, $off[0] + 2, $off[1] - $off[0] - 2;
    }
    croak "Character 0x$hex with name '$fname' is above 0xFF";
  }

  no warnings 'utf8'; # allow even illegal characters
  return pack "U", $ord;
} # charnames

sub import
{
  shift; ## ignore class name

  if (not @_) {
    carp("`use charnames' needs explicit imports list");
  }
  $^H |= $charnames::hint_bits;
  $^H{charnames} = \&charnames ;

  ##
  ## fill %h keys with our @_ args.
  ##
  my ($promote, %h, @args) = (0);
  while (@_ and $_ = shift) {
    if ($_ eq ":alias") {
      @_ or
	croak ":alias needs an argument in charnames";
      my $alias = shift;
      if (ref $alias) {
	ref $alias eq "HASH" or
	  croak "Only HASH reference supported as argument to :alias";
	alias ($alias);
	next;
      }
      if ($alias =~ m{:(\w+)$}) {
	$1 eq "full" || $1 eq "short" and
	  croak ":alias cannot use existing pragma :$1 (reversed order?)";
	alias_file ($1) and $promote = 1;
	next;
      }
      alias_file ($alias);
      next;
    }
    if (m/^:/ and ! ($_ eq ":full" || $_ eq ":short")) {
      warn "unsupported special '$_' in charnames";
      next;
    }
    push @args, $_;
  }
  @args == 0 && $promote and @args = (":full");
  @h{@args} = (1) x @args;

  $^H{charnames_full} = delete $h{':full'};
  $^H{charnames_short} = delete $h{':short'};
  $^H{charnames_scripts} = [map uc, keys %h];

  ##
  ## If utf8? warnings are enabled, and some scripts were given,
  ## see if at least we can find one letter of each script.
  ##
  if (warnings::enabled('utf8') && @{$^H{charnames_scripts}}) {
    $txt = do "unicore/Name.pl" unless $txt;

    for my $script (@{$^H{charnames_scripts}}) {
      if (not $txt =~ m/\t\t$script (?:CAPITAL |SMALL )?LETTER /) {
	warnings::warn('utf8',  "No such script: '$script'");
      }
    }
  }
} # import

require Unicode::UCD; # for Unicode::UCD::_getcode()

my %viacode;

sub viacode
{
  if (@_ != 1) {
    carp "charnames::viacode() expects one argument";
    return ()
  }

  my $arg = shift;
  my $code = Unicode::UCD::_getcode($arg);

  my $hex;

  if (defined $code) {
    $hex = sprintf "%04X", $arg;
  } else {
    carp("unexpected arg \"$arg\" to charnames::viacode()");
    return;
  }

  if ($code > 0x10FFFF) {
    carp sprintf "Unicode characters only allocated up to U+10FFFF (you asked for U+%X)", $hex;
    return;
  }

  return $viacode{$hex} if exists $viacode{$hex};

  $txt = do "unicore/Name.pl" unless $txt;

  if ($txt =~ m/^$hex\t\t(.+)/m) {
    return $viacode{$hex} = $1;
  } else {
    return;
  }
} # viacode

my %vianame;

sub vianame
{
  if (@_ != 1) {
    carp "charnames::vianame() expects one name argument";
    return ()
  }

  my $arg = shift;

  return chr hex $1 if $arg =~ /^U\+([0-9a-fA-F]+)$/;

  return $vianame{$arg} if exists $vianame{$arg};

  $txt = do "unicore/Name.pl" unless $txt;

  my $pos = index $txt, "\t\t$arg\n";
  if ($[ <= $pos) {
    my $posLF = rindex $txt, "\n", $pos;
    (my $code = substr $txt, $posLF + 1, 6) =~ tr/\t//d;
    return $vianame{$arg} = hex $code;

    # If $pos is at the 1st line, $posLF must be $[ - 1 (not found);
    # then $posLF + 1 equals to $[ (at the beginning of $txt).
    # Otherwise $posLF is the position of "\n";
    # then $posLF + 1 must be the position of the next to "\n"
    # (the beginning of the line).
    # substr($txt, $posLF + 1, 6) may be "0000\t\t", "00A1\t\t",
    # "10300\t", "100000", etc. So we can get the code via removing TAB.
  } else {
    return;
  }
} # vianame


1;
__END__

