# Net::Time.pm
#
# Copyright (c) 1995-1998 Graham Barr <gbarr@pobox.com>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package Net::Time;

use strict;
use vars qw($VERSION @ISA @EXPORT_OK $TIMEOUT);
use Carp;
use IO::Socket;
require Exporter;
use Net::Config;
use IO::Select;

@ISA = qw(Exporter);
@EXPORT_OK = qw(inet_time inet_daytime);

$VERSION = "2.09"; # $Id: //depot/libnet/Net/Time.pm#9 $

$TIMEOUT = 120;

sub _socket
{
 my($pname,$pnum,$host,$proto,$timeout) = @_;

 $proto ||= 'udp';

 my $port = (getservbyname($pname, $proto))[2] || $pnum;

 my $hosts = defined $host ? [ $host ] : $NetConfig{$pname . '_hosts'};

 my $me;

 foreach $host (@$hosts)
  {
   $me = IO::Socket::INET->new(PeerAddr => $host,
    	    	    	       PeerPort => $port,
    	    	    	       Proto    => $proto
    	    	    	      ) and last;
  }

 return unless $me;

 $me->send("\n")
	if $proto eq 'udp';

 $timeout = $TIMEOUT
	unless defined $timeout;

 IO::Select->new($me)->can_read($timeout)
	? $me
	: undef;
}

sub inet_time
{
 my $s = _socket('time',37,@_) || return undef;
 my $buf = '';
 my $offset = 0 | 0;

 return undef
	unless $s->recv($buf, length(pack("N",0)));

 # unpack, we | 0 to ensure we have an unsigned
 my $time = (unpack("N",$buf))[0] | 0;

 # the time protocol return time in seconds since 1900, convert
 # it to a the required format

 if($^O eq "MacOS") {
   # MacOS return seconds since 1904, 1900 was not a leap year.
   $offset = (4 * 31536000) | 0;
 }
 else {
   # otherwise return seconds since 1972, there were 17 leap years between
   # 1900 and 1972
   $offset =  (70 * 31536000 + 17 * 86400) | 0;
 }

 $time - $offset;
}

sub inet_daytime
{
 my $s = _socket('daytime',13,@_) || return undef;
 my $buf = '';

 $s->recv($buf, 1024) ? $buf
    	              : undef;
}

1;

__END__

