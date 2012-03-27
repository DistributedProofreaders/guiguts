# spawn.pl: Unix-only script to start a command in the background.

# We can't call perl fork() in the main GUI process, because Tk crashes
# (even on Linux).  Instead, the GUI process runs this script
# using system().

use strict;
use warnings;

my $pid = fork();
die "fork(): $!" unless defined $pid;

# Original process returns immediately
exit if $pid;

# No need to bother user with filename + line number messages
no warnings 'exec';

if ( (exec {$ARGV[0]} @ARGV) < 0 ) {
	print STDERR qq/Error running "$ARGV[0]": $!\n/;
}
