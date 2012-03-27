# Net::POP3.pm
#
# Copyright (c) 1995-1997 Graham Barr <gbarr@pobox.com>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package Net::POP3;

use strict;
use IO::Socket;
use vars qw(@ISA $VERSION $debug);
use Net::Cmd;
use Carp;
use Net::Config;

$VERSION = "2.24"; # $Id: //depot/libnet/Net/POP3.pm#24 $

@ISA = qw(Net::Cmd IO::Socket::INET);

sub new
{
 my $self = shift;
 my $type = ref($self) || $self;
 my $host = shift if @_ % 2;
 my %arg  = @_; 
 my $hosts = defined $host ? [ $host ] : $NetConfig{pop3_hosts};
 my $obj;
 my @localport = exists $arg{ResvPort} ? ( LocalPort => $arg{ResvPort} ): ();

 my $h;
 foreach $h (@{$hosts})
  {
   $obj = $type->SUPER::new(PeerAddr => ($host = $h), 
			    PeerPort => $arg{Port} || 'pop3(110)',
			    Proto    => 'tcp',
			    @localport,
			    Timeout  => defined $arg{Timeout}
						? $arg{Timeout}
						: 120
			   ) and last;
  }

 return undef
	unless defined $obj;

 ${*$obj}{'net_pop3_host'} = $host;

 $obj->autoflush(1);
 $obj->debug(exists $arg{Debug} ? $arg{Debug} : undef);

 unless ($obj->response() == CMD_OK)
  {
   $obj->close();
   return undef;
  }

 ${*$obj}{'net_pop3_banner'} = $obj->message;

 $obj;
}

##
## We don't want people sending me their passwords when they report problems
## now do we :-)
##

sub debug_text { $_[2] =~ /^(pass|rpop)/i ? "$1 ....\n" : $_[2]; }

sub login
{
 @_ >= 1 && @_ <= 3 or croak 'usage: $pop3->login( USER, PASS )';
 my($me,$user,$pass) = @_;

 if (@_ <= 2) {
   ($user, $pass) = $me->_lookup_credentials($user);
 }

 $me->user($user) and
    $me->pass($pass);
}

sub apop
{
 @_ >= 1 && @_ <= 3 or croak 'usage: $pop3->apop( USER, PASS )';
 my($me,$user,$pass) = @_;
 my $banner;
 my $md;

 if (eval { local $SIG{__DIE__}; require Digest::MD5 }) {
   $md = Digest::MD5->new();
 } elsif (eval { local $SIG{__DIE__}; require MD5 }) {
   $md = MD5->new();
 } else {
   carp "You need to install Digest::MD5 or MD5 to use the APOP command";
   return undef;
 }

 return undef
   unless ( $banner = (${*$me}{'net_pop3_banner'} =~ /(<.*>)/)[0] );

 if (@_ <= 2) {
   ($user, $pass) = $me->_lookup_credentials($user);
 }

 $md->add($banner,$pass);

 return undef
    unless($me->_APOP($user,$md->hexdigest));

 $me->_get_mailbox_count();
}

sub user
{
 @_ == 2 or croak 'usage: $pop3->user( USER )';
 $_[0]->_USER($_[1]) ? 1 : undef;
}

sub pass
{
 @_ == 2 or croak 'usage: $pop3->pass( PASS )';

 my($me,$pass) = @_;

 return undef
   unless($me->_PASS($pass));

 $me->_get_mailbox_count();
}

sub reset
{
 @_ == 1 or croak 'usage: $obj->reset()';

 my $me = shift;

 return 0 
   unless($me->_RSET);

 if(defined ${*$me}{'net_pop3_mail'})
  {
   local $_;
   foreach (@{${*$me}{'net_pop3_mail'}})
    {
     delete $_->{'net_pop3_deleted'};
    }
  }
}

sub last
{
 @_ == 1 or croak 'usage: $obj->last()';

 return undef
    unless $_[0]->_LAST && $_[0]->message =~ /(\d+)/;

 return $1;
}

sub top
{
 @_ == 2 || @_ == 3 or croak 'usage: $pop3->top( MSGNUM [, NUMLINES ])';
 my $me = shift;

 return undef
    unless $me->_TOP($_[0], $_[1] || 0);

 $me->read_until_dot;
}

sub popstat
{
 @_ == 1 or croak 'usage: $pop3->popstat()';
 my $me = shift;

 return ()
    unless $me->_STAT && $me->message =~ /(\d+)\D+(\d+)/;

 ($1 || 0, $2 || 0);
}

sub list
{
 @_ == 1 || @_ == 2 or croak 'usage: $pop3->list( [ MSGNUM ] )';
 my $me = shift;

 return undef
    unless $me->_LIST(@_);

 if(@_)
  {
   $me->message =~ /\d+\D+(\d+)/;
   return $1 || undef;
  }

 my $info = $me->read_until_dot
	or return undef;

 my %hash = map { (/(\d+)\D+(\d+)/) } @$info;

 return \%hash;
}

sub get
{
 @_ == 2 or @_ == 3 or croak 'usage: $pop3->get( MSGNUM [, FH ])';
 my $me = shift;

 return undef
    unless $me->_RETR(shift);

 $me->read_until_dot(@_);
}

sub getfh
{
 @_ == 2 or croak 'usage: $pop3->getfh( MSGNUM )';
 my $me = shift;

 return unless $me->_RETR(shift);
 return        $me->tied_fh;
}



sub delete
{
 @_ == 2 or croak 'usage: $pop3->delete( MSGNUM )';
 $_[0]->_DELE($_[1]);
}

sub uidl
{
 @_ == 1 || @_ == 2 or croak 'usage: $pop3->uidl( [ MSGNUM ] )';
 my $me = shift;
 my $uidl;

 $me->_UIDL(@_) or
    return undef;
 if(@_)
  {
   $uidl = ($me->message =~ /\d+\s+([\041-\176]+)/)[0];
  }
 else
  {
   my $ref = $me->read_until_dot
	or return undef;
   my $ln;
   $uidl = {};
   foreach $ln (@$ref) {
     my($msg,$uid) = $ln =~ /^\s*(\d+)\s+([\041-\176]+)/;
     $uidl->{$msg} = $uid;
   }
  }
 return $uidl;
}

sub ping
{
 @_ == 2 or croak 'usage: $pop3->ping( USER )';
 my $me = shift;

 return () unless $me->_PING(@_) && $me->message =~ /(\d+)\D+(\d+)/;

 ($1 || 0, $2 || 0);
}

sub _lookup_credentials
{
  my ($me, $user) = @_;

  require Net::Netrc;

  $user ||= eval { local $SIG{__DIE__}; (getpwuid($>))[0] } ||
    $ENV{NAME} || $ENV{USER} || $ENV{LOGNAME};

  my $m = Net::Netrc->lookup(${*$me}{'net_pop3_host'},$user);
  $m ||= Net::Netrc->lookup(${*$me}{'net_pop3_host'});

  my $pass = $m ? $m->password || ""
                : "";

  ($user, $pass);
}

sub _get_mailbox_count
{
  my ($me) = @_;
  my $ret = ${*$me}{'net_pop3_count'} = ($me->message =~ /(\d+)\s+message/io)
	  ? $1 : ($me->popstat)[0];

  $ret ? $ret : "0E0";
}


sub _STAT { shift->command('STAT')->response() == CMD_OK }
sub _LIST { shift->command('LIST',@_)->response() == CMD_OK }
sub _RETR { shift->command('RETR',$_[0])->response() == CMD_OK }
sub _DELE { shift->command('DELE',$_[0])->response() == CMD_OK }
sub _NOOP { shift->command('NOOP')->response() == CMD_OK }
sub _RSET { shift->command('RSET')->response() == CMD_OK }
sub _QUIT { shift->command('QUIT')->response() == CMD_OK }
sub _TOP  { shift->command('TOP', @_)->response() == CMD_OK }
sub _UIDL { shift->command('UIDL',@_)->response() == CMD_OK }
sub _USER { shift->command('USER',$_[0])->response() == CMD_OK }
sub _PASS { shift->command('PASS',$_[0])->response() == CMD_OK }
sub _APOP { shift->command('APOP',@_)->response() == CMD_OK }
sub _PING { shift->command('PING',$_[0])->response() == CMD_OK }

sub _RPOP { shift->command('RPOP',$_[0])->response() == CMD_OK }
sub _LAST { shift->command('LAST')->response() == CMD_OK }

sub quit
{
 my $me = shift;

 $me->_QUIT;
 $me->close;
}

sub DESTROY
{
 my $me = shift;

 if(defined fileno($me))
  {
   $me->reset;
   $me->quit;
  }
}

##
## POP3 has weird responses, so we emulate them to look the same :-)
##

sub response
{
 my $cmd = shift;
 my $str = $cmd->getline() || return undef;
 my $code = "500";

 $cmd->debug_print(0,$str)
   if ($cmd->debug);

 if($str =~ s/^\+OK\s*//io)
  {
   $code = "200"
  }
 else
  {
   $str =~ s/^-ERR\s*//io;
  }

 ${*$cmd}{'net_cmd_resp'} = [ $str ];
 ${*$cmd}{'net_cmd_code'} = $code;

 substr($code,0,1);
}

1;

__END__

