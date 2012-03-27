# ======================================================================
#
# Copyright (C) 2000-2001 Paul Kulchenko (paulclinger@yahoo.com)
# SOAP::Lite is free software; you can redistribute it
# and/or modify it under the same terms as Perl itself.
#
# $Id: Lite.pm,v 1.3 2001/08/11 19:09:57 paulk Exp $
#
# ======================================================================

package Apache::XMLRPC::Lite;

use strict;
use vars qw(@ISA $VERSION);
use XMLRPC::Transport::HTTP;

@ISA = qw(XMLRPC::Transport::HTTP::Apache);
$VERSION = sprintf("%d.%s", map {s/_//g; $_} q$Name: release-0_55-public $ =~ /-(\d+)_([\d_]+)/);

my $server = __PACKAGE__->new;

sub handler {
  $server->configure(@_);
  $server->SUPER::handler(@_);
}

# ======================================================================

1;

__END__

