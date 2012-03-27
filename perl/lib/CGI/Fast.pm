package CGI::Fast;

# See the bottom of this file for the POD documentation.  Search for the
# string '=head'.

# You can run this file through either pod2man or pod2html to produce pretty
# documentation in manual or html file format (these utilities are part of the
# Perl 5 distribution).

# Copyright 1995,1996, Lincoln D. Stein.  All rights reserved.
# It may be used and modified freely, but I do request that this copyright
# notice remain attached to the file.  You may modify this module as you 
# wish, but if you redistribute a modified version, please attach a note
# listing the modifications you have made.

# The most recent version and complete docs are available at:
#   http://www.genome.wi.mit.edu/ftp/pub/software/WWW/cgi_docs.html
#   ftp://ftp-genome.wi.mit.edu/pub/software/WWW/
$CGI::Fast::VERSION='1.05';

use CGI;
use FCGI;
@ISA = ('CGI');

# workaround for known bug in libfcgi
while (($ignore) = each %ENV) { }

# override the initialization behavior so that
# state is NOT maintained between invocations 
sub save_request {
    # no-op
}

# If ENV{FCGI_SOCKET_PATH} is specified, we maintain a FCGI Request handle
# in this package variable.
use vars qw($Ext_Request);
BEGIN {
   # If ENV{FCGI_SOCKET_PATH} is given, explicitly open the socket,
   # and keep the request handle around from which to call Accept().
   if ($ENV{FCGI_SOCKET_PATH}) {
	my $path    = $ENV{FCGI_SOCKET_PATH};
	my $backlog = $ENV{FCGI_LISTEN_QUEUE} || 100;
	my $socket  = FCGI::OpenSocket( $path, $backlog );
	$Ext_Request = FCGI::Request( \*STDIN, \*STDOUT, \*STDERR, 
					\%ENV, $socket, 1 );
   }
}

# New is slightly different in that it calls FCGI's
# accept() method.
sub new {
     my ($self, $initializer, @param) = @_;
     unless (defined $initializer) {
	if ($Ext_Request) {
          return undef unless $Ext_Request->Accept() >= 0;
	} else {
         return undef unless FCGI::accept() >= 0;
     }
     }
     return $CGI::Q = $self->SUPER::new($initializer, @param);
}

1;

