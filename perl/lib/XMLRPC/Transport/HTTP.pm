# ======================================================================
#
# Copyright (C) 2000-2001 Paul Kulchenko (paulclinger@yahoo.com)
# SOAP::Lite is free software; you can redistribute it
# and/or modify it under the same terms as Perl itself.
#
# $Id: HTTP.pm,v 1.5 2001/10/14 18:11:27 paulk Exp $
#
# ======================================================================

package XMLRPC::Transport::HTTP;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%s", map {s/_//g; $_} q$Name: release-0_55-public $ =~ /-(\d+)_([\d_]+)/);

use XMLRPC::Lite;
use SOAP::Transport::HTTP;

# ======================================================================

package XMLRPC::Transport::HTTP::CGI;

@XMLRPC::Transport::HTTP::CGI::ISA = qw(SOAP::Transport::HTTP::CGI);

sub initialize; *initialize = \&XMLRPC::Server::initialize;

sub make_fault { 
  local $SOAP::Constants::HTTP_ON_FAULT_CODE = 200;
  shift->SUPER::make_fault(@_);
}

sub make_response { 
  local $SOAP::Constants::DO_NOT_USE_CHARSET = 1;
  shift->SUPER::make_response(@_);
}

# ======================================================================

package XMLRPC::Transport::HTTP::Daemon;

@XMLRPC::Transport::HTTP::Daemon::ISA = qw(SOAP::Transport::HTTP::Daemon);

sub initialize; *initialize = \&XMLRPC::Server::initialize;
sub make_fault; *make_fault = \&XMLRPC::Transport::HTTP::CGI::make_fault;
sub make_response; *make_response = \&XMLRPC::Transport::HTTP::CGI::make_response; 

# ======================================================================

package XMLRPC::Transport::HTTP::Apache;

@XMLRPC::Transport::HTTP::Apache::ISA = qw(SOAP::Transport::HTTP::Apache);

sub initialize; *initialize = \&XMLRPC::Server::initialize;
sub make_fault; *make_fault = \&XMLRPC::Transport::HTTP::CGI::make_fault;
sub make_response; *make_response = \&XMLRPC::Transport::HTTP::CGI::make_response; 

# ======================================================================

1;

__END__

