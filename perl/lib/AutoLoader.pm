package AutoLoader;

use strict;
use 5.006_001;

our($VERSION, $AUTOLOAD);

my $is_dosish;
my $is_epoc;
my $is_vms;
my $is_macos;

BEGIN {
    $is_dosish = $^O eq 'dos' || $^O eq 'os2' || $^O eq 'MSWin32' || $^O eq 'NetWare';
    $is_epoc = $^O eq 'epoc';
    $is_vms = $^O eq 'VMS';
    $is_macos = $^O eq 'MacOS';
    $VERSION = '5.60';
}

AUTOLOAD {
    my $sub = $AUTOLOAD;
    my $filename;
    # Braces used to preserve $1 et al.
    {
	# Try to find the autoloaded file from the package-qualified
	# name of the sub. e.g., if the sub needed is
	# Getopt::Long::GetOptions(), then $INC{Getopt/Long.pm} is
	# something like '/usr/lib/perl5/Getopt/Long.pm', and the
	# autoload file is '/usr/lib/perl5/auto/Getopt/Long/GetOptions.al'.
	#
	# However, if @INC is a relative path, this might not work.  If,
	# for example, @INC = ('lib'), then $INC{Getopt/Long.pm} is
	# 'lib/Getopt/Long.pm', and we want to require
	# 'auto/Getopt/Long/GetOptions.al' (without the leading 'lib').
	# In this case, we simple prepend the 'auto/' and let the
	# C<require> take care of the searching for us.

	my ($pkg,$func) = ($sub =~ /(.*)::([^:]+)$/);
	$pkg =~ s#::#/#g;
	if (defined($filename = $INC{"$pkg.pm"})) {
	    if ($is_macos) {
		$pkg =~ tr#/#:#;
		$filename =~ s#^(.*)$pkg\.pm\z#$1auto:$pkg:$func.al#s;
	    } else {
		$filename =~ s#^(.*)$pkg\.pm\z#$1auto/$pkg/$func.al#s;
	    }

	    # if the file exists, then make sure that it is a
	    # a fully anchored path (i.e either '/usr/lib/auto/foo/bar.al',
	    # or './lib/auto/foo/bar.al'.  This avoids C<require> searching
	    # (and failing) to find the 'lib/auto/foo/bar.al' because it
	    # looked for 'lib/lib/auto/foo/bar.al', given @INC = ('lib').

	    if (-r $filename) {
		unless ($filename =~ m|^/|s) {
		    if ($is_dosish) {
			unless ($filename =~ m{^([a-z]:)?[\\/]}is) {
			     if ($^O ne 'NetWare') {
					$filename = "./$filename";
				} else {
					$filename = "$filename";
				}
			}
		    }
		    elsif ($is_epoc) {
			unless ($filename =~ m{^([a-z?]:)?[\\/]}is) {
			     $filename = "./$filename";
			}
		    }
		    elsif ($is_vms) {
			# XXX todo by VMSmiths
			$filename = "./$filename";
		    }
		    elsif (!$is_macos) {
			$filename = "./$filename";
		    }
		}
	    }
	    else {
		$filename = undef;
	    }
	}
	unless (defined $filename) {
	    # let C<require> do the searching
	    $filename = "auto/$sub.al";
	    $filename =~ s#::#/#g;
	}
    }
    my $save = $@;
    local $!; # Do not munge the value. 
    eval { local $SIG{__DIE__}; require $filename };
    if ($@) {
	if (substr($sub,-9) eq '::DESTROY') {
	    no strict 'refs';
	    *$sub = sub {};
	    $@ = undef;
	} elsif ($@ =~ /^Can't locate/) {
	    # The load might just have failed because the filename was too
	    # long for some old SVR3 systems which treat long names as errors.
	    # If we can successfully truncate a long name then it's worth a go.
	    # There is a slight risk that we could pick up the wrong file here
	    # but autosplit should have warned about that when splitting.
	    if ($filename =~ s/(\w{12,})\.al$/substr($1,0,11).".al"/e){
		eval { local $SIG{__DIE__}; require $filename };
	    }
	}
	if ($@){
	    $@ =~ s/ at .*\n//;
	    my $error = $@;
	    require Carp;
	    Carp::croak($error);
	}
    }
    $@ = $save;
    goto &$sub;
}

sub import {
    my $pkg = shift;
    my $callpkg = caller;

    #
    # Export symbols, but not by accident of inheritance.
    #

    if ($pkg eq 'AutoLoader') {
	no strict 'refs';
	*{ $callpkg . '::AUTOLOAD' } = \&AUTOLOAD
	    if @_ and $_[0] =~ /^&?AUTOLOAD$/;
    }

    #
    # Try to find the autosplit index file.  Eg., if the call package
    # is POSIX, then $INC{POSIX.pm} is something like
    # '/usr/local/lib/perl5/POSIX.pm', and the autosplit index file is in
    # '/usr/local/lib/perl5/auto/POSIX/autosplit.ix', so we require that.
    #
    # However, if @INC is a relative path, this might not work.  If,
    # for example, @INC = ('lib'), then
    # $INC{POSIX.pm} is 'lib/POSIX.pm', and we want to require
    # 'auto/POSIX/autosplit.ix' (without the leading 'lib').
    #

    (my $calldir = $callpkg) =~ s#::#/#g;
    my $path = $INC{$calldir . '.pm'};
    if (defined($path)) {
	# Try absolute path name.
	if ($is_macos) {
	    (my $malldir = $calldir) =~ tr#/#:#;
	    $path =~ s#^(.*)$malldir\.pm\z#$1auto:$malldir:autosplit.ix#s;
	} else {
	    $path =~ s#^(.*)$calldir\.pm\z#$1auto/$calldir/autosplit.ix#;
	}

	eval { require $path; };
	# If that failed, try relative path with normal @INC searching.
	if ($@) {
	    $path ="auto/$calldir/autosplit.ix";
	    eval { require $path; };
	}
	if ($@) {
	    my $error = $@;
	    require Carp;
	    Carp::carp($error);
	}
    } 
}

sub unimport {
    my $callpkg = caller;

    no strict 'refs';
    my $symname = $callpkg . '::AUTOLOAD';
    undef *{ $symname } if \&{ $symname } == \&AUTOLOAD;
    *{ $symname } = \&{ $symname };
}

1;

__END__

