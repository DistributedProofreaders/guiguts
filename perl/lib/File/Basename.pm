package File::Basename;


## use strict;
# A bit of juggling to insure that C<use re 'taint';> always works, since
# File::Basename is used during the Perl build, when the re extension may
# not be available.
BEGIN {
  unless (eval { require re; })
    { eval ' sub re::import { $^H |= 0x00100000; } ' } # HINT_RE_TAINT
  import re 'taint';
}



use 5.006;
use warnings;
our(@ISA, @EXPORT, $VERSION, $Fileparse_fstype, $Fileparse_igncase);
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(fileparse fileparse_set_fstype basename dirname);
$VERSION = "2.72";


#   fileparse_set_fstype() - specify OS-based rules used in future
#                            calls to routines in this package
#
#   Currently recognized values: VMS, MSDOS, MacOS, AmigaOS, os2, RISCOS
#       Any other name uses Unix-style rules and is case-sensitive

sub fileparse_set_fstype {
  my @old = ($Fileparse_fstype, $Fileparse_igncase);
  if (@_) {
    $Fileparse_fstype = $_[0];
    $Fileparse_igncase = ($_[0] =~ /^(?:MacOS|VMS|AmigaOS|os2|RISCOS|MSWin32|MSDOS)/i);
  }
  wantarray ? @old : $old[0];
}

#   fileparse() - parse file specification
#
#   Version 2.4  27-Sep-1996  Charles Bailey  bailey@genetics.upenn.edu


sub fileparse {
  my($fullname,@suffices) = @_;
  unless (defined $fullname) {
      require Carp;
      Carp::croak("fileparse(): need a valid pathname");
  }
  my($fstype,$igncase) = ($Fileparse_fstype, $Fileparse_igncase);
  my($dirpath,$tail,$suffix,$basename);
  my($taint) = substr($fullname,0,0);  # Is $fullname tainted?

  if ($fstype =~ /^VMS/i) {
    if ($fullname =~ m#/#) { $fstype = '' }  # We're doing Unix emulation
    else {
      ($dirpath,$basename) = ($fullname =~ /^(.*[:>\]])?(.*)/s);
      $dirpath ||= '';  # should always be defined
    }
  }
  if ($fstype =~ /^MS(DOS|Win32)|epoc/i) {
    ($dirpath,$basename) = ($fullname =~ /^((?:.*[:\\\/])?)(.*)/s);
    $dirpath .= '.\\' unless $dirpath =~ /[\\\/]\z/;
  }
  elsif ($fstype =~ /^os2/i) {
    ($dirpath,$basename) = ($fullname =~ m#^((?:.*[:\\/])?)(.*)#s);
    $dirpath = './' unless $dirpath;	# Can't be 0
    $dirpath .= '/' unless $dirpath =~ m#[\\/]\z#;
  }
  elsif ($fstype =~ /^MacOS/si) {
    ($dirpath,$basename) = ($fullname =~ /^(.*:)?(.*)/s);
    $dirpath = ':' unless $dirpath;
  }
  elsif ($fstype =~ /^AmigaOS/i) {
    ($dirpath,$basename) = ($fullname =~ /(.*[:\/])?(.*)/s);
    $dirpath = './' unless $dirpath;
  }
  elsif ($fstype !~ /^VMS/i) {  # default to Unix
    ($dirpath,$basename) = ($fullname =~ m#^(.*/)?(.*)#s);
    if ($^O eq 'VMS' and $fullname =~ m:^(/[^/]+/000000(/|$))(.*):) {
      # dev:[000000] is top of VMS tree, similar to Unix '/'
      # so strip it off and treat the rest as "normal"
      my $devspec  = $1;
      my $remainder = $3;
      ($dirpath,$basename) = ($remainder =~ m#^(.*/)?(.*)#s);
      $dirpath ||= '';  # should always be defined
      $dirpath = $devspec.$dirpath;
    }
    $dirpath = './' unless $dirpath;
  }

  if (@suffices) {
    $tail = '';
    foreach $suffix (@suffices) {
      my $pat = ($igncase ? '(?i)' : '') . "($suffix)\$";
      if ($basename =~ s/$pat//s) {
        $taint .= substr($suffix,0,0);
        $tail = $1 . $tail;
      }
    }
  }

  $tail .= $taint if defined $tail; # avoid warning if $tail == undef
  wantarray ? ($basename .= $taint, $dirpath .= $taint, $tail)
            : ($basename .= $taint);
}


#   basename() - returns first element of list returned by fileparse()

sub basename {
  my($name) = shift;
  (fileparse($name, map("\Q$_\E",@_)))[0];
}


#    dirname() - returns device and directory portion of file specification
#        Behavior matches that of Unix dirname(1) exactly for Unix and MSDOS
#        filespecs except for names ending with a separator, e.g., "/xx/yy/".
#        This differs from the second element of the list returned
#        by fileparse() in that the trailing '/' (Unix) or '\' (MSDOS) (and
#        the last directory name if the filespec ends in a '/' or '\'), is lost.

sub dirname {
    my($basename,$dirname) = fileparse($_[0]);
    my($fstype) = $Fileparse_fstype;

    if ($fstype =~ /VMS/i) { 
        if ($_[0] =~ m#/#) { $fstype = '' }
        else { return $dirname || $ENV{DEFAULT} }
    }
    if ($fstype =~ /MacOS/i) {
	if( !length($basename) && $dirname !~ /^[^:]+:\z/) {
	    $dirname =~ s/([^:]):\z/$1/s;
	    ($basename,$dirname) = fileparse $dirname;
	}
	$dirname .= ":" unless $dirname =~ /:\z/;
    }
    elsif ($fstype =~ /MS(DOS|Win32)|os2/i) { 
        $dirname =~ s/([^:])[\\\/]*\z/$1/;
        unless( length($basename) ) {
	    ($basename,$dirname) = fileparse $dirname;
	    $dirname =~ s/([^:])[\\\/]*\z/$1/;
	}
    }
    elsif ($fstype =~ /AmigaOS/i) {
        if ( $dirname =~ /:\z/) { return $dirname }
        chop $dirname;
        $dirname =~ s#[^:/]+\z## unless length($basename);
    }
    else {
        $dirname =~ s:(.)/*\z:$1:s;
        unless( length($basename) ) {
	    local($File::Basename::Fileparse_fstype) = $fstype;
	    ($basename,$dirname) = fileparse $dirname;
	    $dirname =~ s:(.)/*\z:$1:s;
	}
    }

    $dirname;
}

fileparse_set_fstype $^O;

1;
