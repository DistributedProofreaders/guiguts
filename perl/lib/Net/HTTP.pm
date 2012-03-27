package Net::HTTP;

# $Id: HTTP.pm,v 1.43 2002/12/26 09:13:53 gisle Exp $

use strict;
use vars qw($VERSION @ISA);

$VERSION = "1.00";
eval { require IO::Socket::INET } || require IO::Socket;
require Net::HTTP::Methods;

@ISA=qw(IO::Socket::INET Net::HTTP::Methods);

sub configure {
    my($self, $cnf) = @_;
    $self->http_configure($cnf);
}

sub http_connect {
    my($self, $cnf) = @_;
    $self->SUPER::configure($cnf);
}

1;

__END__

