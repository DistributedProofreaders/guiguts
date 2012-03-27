package threads::shared;

use 5.008;
use strict;
use warnings;
BEGIN {
    require Exporter;
    our @ISA = qw(Exporter);
    our @EXPORT = qw(share cond_wait cond_timedwait cond_broadcast cond_signal);
    our $VERSION = '0.92';

    if ($threads::threads) {
	*cond_wait = \&cond_wait_enabled;
	*cond_timedwait = \&cond_timedwait_enabled;
	*cond_signal = \&cond_signal_enabled;
	*cond_broadcast = \&cond_broadcast_enabled;
	require XSLoader;
	XSLoader::load('threads::shared',$VERSION);
	push @EXPORT,'bless';
    }
    else {

# String eval is generally evil, but we don't want these subs to exist at all
# if threads are loaded successfully.  Vivifying them conditionally this way
# saves on average about 4K of memory per thread.

        eval <<'EOD';
sub cond_wait      (\[$@%];\[$@%])  { undef }
sub cond_timedwait (\[$@%]$;\[$@%]) { undef }
sub cond_signal    (\[$@%])         { undef }
sub cond_broadcast (\[$@%])         { undef }
sub share          (\[$@%])         { return $_[0] }
EOD
    }
}

$threads::shared::threads_shared = 1;

sub threads::shared::tie::SPLICE
{
 die "Splice not implemented for shared arrays";
}

__END__

