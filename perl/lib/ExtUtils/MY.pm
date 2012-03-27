package ExtUtils::MY;

use strict;
require ExtUtils::MM;

use vars qw(@ISA $VERSION);
$VERSION = 0.01;
@ISA = qw(ExtUtils::MM);

{
    package MY;
    use vars qw(@ISA);
    @ISA = qw(ExtUtils::MY);
}

sub DESTROY {}


