# File/Copy.pm. Written in 1994 by Aaron Sherman <ajs@ajs.com>. This
# source code has been placed in the public domain by the author.
# Please be kind and preserve the documentation.
#
# Additions copyright 1996 by Charles Bailey.  Permission is granted
# to distribute the revised code under the same terms as Perl itself.

package File::Copy;

use 5.006;
use strict;
use warnings;
use Carp;
use File::Spec;
use Config;
our(@ISA, @EXPORT, @EXPORT_OK, $VERSION, $Too_Big, $Syscopy_is_copy);
sub copy;
sub syscopy;
sub cp;
sub mv;

# Note that this module implements only *part* of the API defined by
# the File/Copy.pm module of the File-Tools-2.0 package.  However, that
# package has not yet been updated to work with Perl 5.004, and so it
# would be a Bad Thing for the CPAN module to grab it and replace this
# module.  Therefore, we set this module's version higher than 2.0.
$VERSION = '2.07';

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(copy move);
@EXPORT_OK = qw(cp mv);

$Too_Big = 1024 * 1024 * 2;

my $macfiles;
if ($^O eq 'MacOS') {
	$macfiles = eval { require Mac::MoreFiles };
	warn 'Mac::MoreFiles could not be loaded; using non-native syscopy'
		if $@ && $^W;
}

sub _catname {
    my($from, $to) = @_;
    if (not defined &basename) {
	require File::Basename;
	import  File::Basename 'basename';
    }

    if ($^O eq 'MacOS') {
	# a partial dir name that's valid only in the cwd (e.g. 'tmp')
	$to = ':' . $to if $to !~ /:/;
    }

    return File::Spec->catfile($to, basename($from));
}

sub copy {
    croak("Usage: copy(FROM, TO [, BUFFERSIZE]) ")
      unless(@_ == 2 || @_ == 3);

    my $from = shift;
    my $to = shift;

    my $from_a_handle = (ref($from)
			 ? (ref($from) eq 'GLOB'
			    || UNIVERSAL::isa($from, 'GLOB')
                            || UNIVERSAL::isa($from, 'IO::Handle'))
			 : (ref(\$from) eq 'GLOB'));
    my $to_a_handle =   (ref($to)
			 ? (ref($to) eq 'GLOB'
			    || UNIVERSAL::isa($to, 'GLOB')
                            || UNIVERSAL::isa($to, 'IO::Handle'))
			 : (ref(\$to) eq 'GLOB'));

    if ($from eq $to) { # works for references, too
	croak("'$from' and '$to' are identical (not copied)");
    }

    if ((($Config{d_symlink} && $Config{d_readlink}) || $Config{d_link}) &&
	!($^O eq 'MSWin32' || $^O eq 'os2' || $^O eq 'vms')) {
	my @fs = stat($from);
	if (@fs) {
	    my @ts = stat($to);
	    if (@ts && $fs[0] == $ts[0] && $fs[1] == $ts[1]) {
		croak("'$from' and '$to' are identical (not copied)");
	    }
	}
    }

    if (!$from_a_handle && !$to_a_handle && -d $to && ! -d $from) {
	$to = _catname($from, $to);
    }

    if (defined &syscopy && !$Syscopy_is_copy
	&& !$to_a_handle
	&& !($from_a_handle && $^O eq 'os2' )	# OS/2 cannot handle handles
	&& !($from_a_handle && $^O eq 'mpeix')	# and neither can MPE/iX.
	&& !($from_a_handle && $^O eq 'MSWin32')
	&& !($from_a_handle && $^O eq 'MacOS')
	&& !($from_a_handle && $^O eq 'NetWare')
       )
    {
	return syscopy($from, $to);
    }

    my $closefrom = 0;
    my $closeto = 0;
    my ($size, $status, $r, $buf);
    local($\) = '';

    my $from_h;
    if ($from_a_handle) {
       $from_h = $from;
    } else {
	$from = _protect($from) if $from =~ /^\s/s;
       $from_h = \do { local *FH };
       open($from_h, "< $from\0") or goto fail_open1;
       binmode $from_h or die "($!,$^E)";
	$closefrom = 1;
    }

    my $to_h;
    if ($to_a_handle) {
       $to_h = $to;
    } else {
	$to = _protect($to) if $to =~ /^\s/s;
       $to_h = \do { local *FH };
       open($to_h,"> $to\0") or goto fail_open2;
       binmode $to_h or die "($!,$^E)";
	$closeto = 1;
    }

    if (@_) {
	$size = shift(@_) + 0;
	croak("Bad buffer size for copy: $size\n") unless ($size > 0);
    } else {
	$size = tied(*$from_h) ? 0 : -s $from_h || 0;
	$size = 1024 if ($size < 512);
	$size = $Too_Big if ($size > $Too_Big);
    }

    $! = 0;
    for (;;) {
	my ($r, $w, $t);
       defined($r = sysread($from_h, $buf, $size))
	    or goto fail_inner;
	last unless $r;
	for ($w = 0; $w < $r; $w += $t) {
           $t = syswrite($to_h, $buf, $r - $w, $w)
		or goto fail_inner;
	}
    }

    close($to_h) || goto fail_open2 if $closeto;
    close($from_h) || goto fail_open1 if $closefrom;

    # Use this idiom to avoid uninitialized value warning.
    return 1;

    # All of these contortions try to preserve error messages...
  fail_inner:
    if ($closeto) {
	$status = $!;
	$! = 0;
       close $to_h;
	$! = $status unless $!;
    }
  fail_open2:
    if ($closefrom) {
	$status = $!;
	$! = 0;
       close $from_h;
	$! = $status unless $!;
    }
  fail_open1:
    return 0;
}

sub move {
    my($from,$to) = @_;
    my($fromsz,$tosz1,$tomt1,$tosz2,$tomt2,$sts,$ossts);

    if (-d $to && ! -d $from) {
	$to = _catname($from, $to);
    }

    ($tosz1,$tomt1) = (stat($to))[7,9];
    $fromsz = -s $from;
    if ($^O eq 'os2' and defined $tosz1 and defined $fromsz) {
      # will not rename with overwrite
      unlink $to;
    }
    return 1 if rename $from, $to;

    # Did rename return an error even though it succeeded, because $to
    # is on a remote NFS file system, and NFS lost the server's ack?
    return 1 if defined($fromsz) && !-e $from &&           # $from disappeared
                (($tosz2,$tomt2) = (stat($to))[7,9]) &&    # $to's there
                ($tosz1 != $tosz2 or $tomt1 != $tomt2) &&  #   and changed
                $tosz2 == $fromsz;                         # it's all there

    ($tosz1,$tomt1) = (stat($to))[7,9];  # just in case rename did something
    return 1 if copy($from,$to) && unlink($from);
    ($sts,$ossts) = ($! + 0, $^E + 0);

    ($tosz2,$tomt2) = ((stat($to))[7,9],0,0) if defined $tomt1;
    unlink($to) if !defined($tomt1) or $tomt1 != $tomt2 or $tosz1 != $tosz2;
    ($!,$^E) = ($sts,$ossts);
    return 0;
}

*cp = \&copy;
*mv = \&move;


if ($^O eq 'MacOS') {
    *_protect = sub { MacPerl::MakeFSSpec($_[0]) };
} else {
    *_protect = sub { "./$_[0]" };
}

# &syscopy is an XSUB under OS/2
unless (defined &syscopy) {
    if ($^O eq 'VMS') {
	*syscopy = \&rmscopy;
    } elsif ($^O eq 'mpeix') {
	*syscopy = sub {
	    return 0 unless @_ == 2;
	    # Use the MPE cp program in order to
	    # preserve MPE file attributes.
	    return system('/bin/cp', '-f', $_[0], $_[1]) == 0;
	};
    } elsif ($^O eq 'MSWin32') {
	*syscopy = sub {
	    return 0 unless @_ == 2;
	    return Win32::CopyFile(@_, 1);
	};
    } elsif ($macfiles) {
	*syscopy = sub {
	    my($from, $to) = @_;
	    my($dir, $toname);

	    return 0 unless -e $from;

	    if ($to =~ /(.*:)([^:]+):?$/) {
		($dir, $toname) = ($1, $2);
	    } else {
		($dir, $toname) = (":", $to);
	    }

	    unlink($to);
	    Mac::MoreFiles::FSpFileCopy($from, $dir, $toname, 1);
	};
    } else {
	$Syscopy_is_copy = 1;
	*syscopy = \&copy;
    }
}

1;

__END__

