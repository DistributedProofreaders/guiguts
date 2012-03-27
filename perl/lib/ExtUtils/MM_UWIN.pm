package ExtUtils::MM_UWIN;

use strict;
use vars qw($VERSION @ISA);
$VERSION = 0.02;

require ExtUtils::MM_Unix;
@ISA = qw(ExtUtils::MM_Unix);


sub os_flavor {
    return('Unix', 'U/WIN');
}


sub replace_manpage_separator {
    my($self, $man) = @_;

    $man =~ s,/+,.,g;
    return $man;
}

1;
