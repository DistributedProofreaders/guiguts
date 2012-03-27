package ExtUtils::MakeMaker::vmsish;

use vars qw($VERSION);
$VERSION = 0.01;

my $IsVMS = $^O eq 'VMS';

require vmsish if $IsVMS;


sub import {
    return unless $IsVMS;

    shift;
    unshift @_, 'vmsish';

    goto &vmsish::import;
}

1;


