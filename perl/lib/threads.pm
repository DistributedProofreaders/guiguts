package threads;

use 5.008;
use strict;
use warnings;
use Config;

BEGIN {
    unless ($Config{useithreads}) {
	my @caller = caller(2);
        die <<EOF;
$caller[1] line $caller[2]:

This Perl hasn't been configured and built properly for the threads
module to work.  (The 'useithreads' configuration option hasn't been used.)

Having threads support requires all of Perl and all of the XS modules in
the Perl installation to be rebuilt, it is not just a question of adding
the threads module.  (In other words, threaded and non-threaded Perls
are binary incompatible.)

If you want to the use the threads module, please contact the people
who built your Perl.

Cannot continue, aborting.
EOF
    }
}

use overload
    '==' => \&equal,
    'fallback' => 1;

BEGIN {
    warn "Warning, threads::shared has already been loaded. ".
       "To enable shared variables for these modules 'use threads' ".
       "must be called before any of those modules are loaded\n"
               if($threads::shared::threads_shared);
}

require Exporter;
require DynaLoader;

our @ISA = qw(Exporter DynaLoader);

our %EXPORT_TAGS = ( all => [qw(yield)]);

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
async	
);
our $VERSION = '1.02';


# || 0 to ensure compatibility with previous versions
sub equal { ($_[0]->tid == $_[1]->tid) || 0 }

# use "goto" trick to avoid pad problems from 5.8.1 (fixed in 5.8.2)
# should also be faster
sub async (&;@) { unshift @_,'threads'; goto &new }

sub object {
    return undef unless @_ > 1;
    foreach (threads->list) {
        return $_ if $_->tid == $_[1];
    }
    return undef;
}

$threads::threads = 1;

bootstrap threads $VERSION;

# why document 'new' then use 'create' in the tests!
*create = \&new;

# Preloaded methods go here.

1;
__END__

