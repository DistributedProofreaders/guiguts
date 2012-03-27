package Shell;
use 5.006_001;
use strict;
use warnings;
our($capture_stderr, $VERSION, $AUTOLOAD);

$VERSION = '0.5';

sub new { bless \my $foo, shift }
sub DESTROY { }

sub import {
    my $self = shift;
    my ($callpack, $callfile, $callline) = caller;
    my @EXPORT;
    if (@_) {
	@EXPORT = @_;
    } else {
	@EXPORT = 'AUTOLOAD';
    }
    foreach my $sym (@EXPORT) {
        no strict 'refs';
        *{"${callpack}::$sym"} = \&{"Shell::$sym"};
    }
}

sub AUTOLOAD {
    shift if ref $_[0] && $_[0]->isa( 'Shell' );
    my $cmd = $AUTOLOAD;
    $cmd =~ s/^.*:://;
    eval <<"*END*";
	sub $AUTOLOAD {
	    shift if ref \$_[0] && \$_[0]->isa( 'Shell' );
	    if (\@_ < 1) {
		\$Shell::capture_stderr ? `$cmd 2>&1` : `$cmd`;
	    } elsif ('$^O' eq 'os2') {
		local(\*SAVEOUT, \*READ, \*WRITE);

		open SAVEOUT, '>&STDOUT' or die;
		pipe READ, WRITE or die;
		open STDOUT, '>&WRITE' or die;
		close WRITE;

		my \$pid = system(1, '$cmd', \@_);
		die "Can't execute $cmd: \$!\\n" if \$pid < 0;

		open STDOUT, '>&SAVEOUT' or die;
		close SAVEOUT;

		if (wantarray) {
		    my \@ret = <READ>;
		    close READ;
		    waitpid \$pid, 0;
		    \@ret;
		} else {
		    local(\$/) = undef;
		    my \$ret = <READ>;
		    close READ;
		    waitpid \$pid, 0;
		    \$ret;
		}
	    } else {
		my \$a;
		my \@arr = \@_;
		if ('$^O' eq 'MSWin32') {
		    # XXX this special-casing should not be needed
		    # if we do quoting right on Windows. :-(
		    #
		    # First, escape all quotes.  Cover the case where we
		    # want to pass along a quote preceded by a backslash
		    # (i.e., C<"param \\""" end">).
		    # Ugly, yup?  You know, windoze.
		    # Enclose in quotes only the parameters that need it:
		    #   try this: c:\> dir "/w"
		    #   and this: c:\> dir /w
		    for (\@arr) {
			s/"/\\\\"/g;
			s/\\\\\\\\"/\\\\\\\\"""/g;
			\$_ = qq["\$_"] if /\\s/;
		    }
		} else {
		    for (\@arr) {
			s/(['\\\\])/\\\\\$1/g;
			\$_ = \$_;
		    }
		}
		push \@arr, '2>&1' if \$Shell::capture_stderr;
		open(SUBPROC, join(' ', '$cmd', \@arr, '|'))
		    or die "Can't exec $cmd: \$!\\n";
		if (wantarray) {
		    my \@ret = <SUBPROC>;
		    close SUBPROC;	# XXX Oughta use a destructor.
		    \@ret;
		} else {
		    local(\$/) = undef;
		    my \$ret = <SUBPROC>;
		    close SUBPROC;
		    \$ret;
		}
	    }
	}
*END*

    die "$@\n" if $@;
    goto &$AUTOLOAD;
}

1;

__END__

