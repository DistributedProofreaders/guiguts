# ======================================================================
#
# Copyright (C) 2000-2001 Paul Kulchenko (paulclinger@yahoo.com)
# SOAP::Lite is free software; you can redistribute it
# and/or modify it under the same terms as Perl itself.
#
# $Id: TCP.pm,v 1.3 2001/08/11 19:09:58 paulk Exp $
#
# ======================================================================

package XMLRPC::Transport::TCP;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%s", map {s/_//g; $_} q$Name: release-0_55-public $ =~ /-(\d+)_([\d_]+)/);

use XMLRPC::Lite;
use SOAP::Transport::TCP;

# ======================================================================

package XMLRPC::Transport::TCP::Server;

@XMLRPC::Transport::TCP::Server::ISA = qw(SOAP::Transport::TCP::Server);

sub initialize; *initialize = \&XMLRPC::Server::initialize;

# ======================================================================

1;

__END__

