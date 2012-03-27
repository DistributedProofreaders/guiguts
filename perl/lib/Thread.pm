package Thread;

use strict;

our($VERSION, $ithreads, $othreads);

BEGIN {
    $VERSION = '2.00';
    use Config;
    $ithreads = $Config{useithreads};
    $othreads = $Config{use5005threads};
}

require Exporter;
use XSLoader ();
our(@ISA, @EXPORT, @EXPORT_OK);

@ISA = qw(Exporter);

BEGIN {
    if ($ithreads) {
	@EXPORT = qw(cond_wait cond_broadcast cond_signal)
    } elsif ($othreads) {
	@EXPORT_OK = qw(cond_signal cond_broadcast cond_wait);
    }
    push @EXPORT_OK, qw(async yield);
}

#
# Methods
#

#
# Exported functions
#

sub async (&) {
    return Thread->new($_[0]);
}

sub eval {
    return eval { shift->join; };
}

sub unimplemented {
    print $_[0], " unimplemented with ",
          $Config{useithreads} ? "ithreads" : "5005threads", "\n";

}

sub unimplement {
    for my $m (@_) {
	no strict 'refs';
	*{"Thread::$m"} = sub { unimplemented $m };
    }
}

BEGIN {
    if ($ithreads) {
	if ($othreads) {
	    require Carp;
	    Carp::croak("This Perl has both ithreads and 5005threads (serious malconfiguration)");
	}
	XSLoader::load 'threads';
	for my $m (qw(new join detach yield self tid equal list)) {
	    no strict 'refs';
	    *{"Thread::$m"} = \&{"threads::$m"};
	}
	require 'threads/shared.pm';
	for my $m (qw(cond_signal cond_broadcast cond_wait)) {
	    no strict 'refs';
	    *{"Thread::$m"} = \&{"threads::shared::${m}_enabled"};
	}
	# trying to unimplement eval gives redefined warning
	unimplement(qw(done flags));
    } elsif ($othreads) {
	XSLoader::load 'Thread';
    } else {
	require Carp;
	Carp::croak("This Perl has neither ithreads nor 5005threads");
    }
}

1;
