# Net::SMTP.pm
#
# Copyright (c) 1995-1997 Graham Barr <gbarr@pobox.com>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package Net::SMTP;

require 5.001;

use strict;
use vars qw($VERSION @ISA);
use Socket 1.3;
use Carp;
use IO::Socket;
use Net::Cmd;
use Net::Config;

$VERSION = "2.26"; # $Id: //depot/libnet/Net/SMTP.pm#31 $

@ISA = qw(Net::Cmd IO::Socket::INET);

sub new
{
 my $self = shift;
 my $type = ref($self) || $self;
 my $host = shift if @_ % 2;
 my %arg  = @_; 
 my $hosts = defined $host ? $host : $NetConfig{smtp_hosts};
 my $obj;

 my $h;
 foreach $h (@{ref($hosts) ? $hosts : [ $hosts ]})
  {
   $obj = $type->SUPER::new(PeerAddr => ($host = $h), 
			    PeerPort => $arg{Port} || 'smtp(25)',
			    LocalAddr => $arg{LocalAddr},
			    LocalPort => $arg{LocalPort},
			    Proto    => 'tcp',
			    Timeout  => defined $arg{Timeout}
						? $arg{Timeout}
						: 120
			   ) and last;
  }

 return undef
	unless defined $obj;

 $obj->autoflush(1);

 $obj->debug(exists $arg{Debug} ? $arg{Debug} : undef);

 unless ($obj->response() == CMD_OK)
  {
   $obj->close();
   return undef;
  }

 ${*$obj}{'net_smtp_exact_addr'} = $arg{ExactAddresses};
 ${*$obj}{'net_smtp_host'} = $host;

 (${*$obj}{'net_smtp_banner'}) = $obj->message;
 (${*$obj}{'net_smtp_domain'}) = $obj->message =~ /\A\s*(\S+)/;

 unless($obj->hello($arg{Hello} || ""))
  {
   $obj->close();
   return undef;
  }

 $obj;
}

##
## User interface methods
##

sub banner
{
 my $me = shift;

 return ${*$me}{'net_smtp_banner'} || undef;
}

sub domain
{
 my $me = shift;

 return ${*$me}{'net_smtp_domain'} || undef;
}

sub etrn {
    my $self = shift;
    defined($self->supports('ETRN',500,["Command unknown: 'ETRN'"])) &&
	$self->_ETRN(@_);
}

sub auth {
    my ($self, $username, $password) = @_;

    require MIME::Base64;
    require Authen::SASL;

    my $mechanisms = $self->supports('AUTH',500,["Command unknown: 'AUTH'"]);
    return unless defined $mechanisms;

    my $sasl;

    if (ref($username) and UNIVERSAL::isa($username,'Authen::SASL')) {
      $sasl = $username;
      $sasl->mechanism($mechanisms);
    }
    else {
      die "auth(username, password)" if not length $username;
      $sasl = Authen::SASL->new(mechanism=> $mechanisms,
				callback => { user => $username,
                                              pass => $password,
					      authname => $username,
                                            });
    }

    # We should probably allow the user to pass the host, but I don't
    # currently know and SASL mechanisms that are used by smtp that need it
    my $client = $sasl->client_new('smtp',${*$self}{'net_smtp_host'},0);
    my $str    = $client->client_start;
    # We dont support sasl mechanisms that encrypt the socket traffic.
    # todo that we would really need to change the ISA hierarchy
    # so we dont inherit from IO::Socket, but instead hold it in an attribute

    my @cmd = ("AUTH", $client->mechanism);
    my $code;

    push @cmd, MIME::Base64::encode_base64($str,'')
      if defined $str and length $str;

    while (($code = $self->command(@cmd)->response()) == CMD_MORE) {
      @cmd = (MIME::Base64::encode_base64(
	$client->client_step(
	  MIME::Base64::decode_base64(
	    ($self->message)[0]
	  )
	), ''
      ));
    }

    $code == CMD_OK;
}

sub hello
{
 my $me = shift;
 my $domain = shift || "localhost.localdomain";
 my $ok = $me->_EHLO($domain);
 my @msg = $me->message;

 if($ok)
  {
   my $h = ${*$me}{'net_smtp_esmtp'} = {};
   my $ln;
   foreach $ln (@msg) {
     $h->{uc $1} = $2
	if $ln =~ /(\w+)\b[= \t]*([^\n]*)/;
    }
  }
 elsif($me->status == CMD_ERROR) 
  {
   @msg = $me->message
	if $ok = $me->_HELO($domain);
  }

 return undef unless $ok;

 $msg[0] =~ /\A\s*(\S+)/;
 return ($1 || " ");
}

sub supports {
    my $self = shift;
    my $cmd = uc shift;
    return ${*$self}{'net_smtp_esmtp'}->{$cmd}
	if exists ${*$self}{'net_smtp_esmtp'}->{$cmd};
    $self->set_status(@_)
	if @_;
    return;
}

sub _addr {
  my $self = shift;
  my $addr = shift;
  $addr = "" unless defined $addr;

  if (${*$self}{'net_smtp_exact_addr'}) {
    return $1 if $addr =~ /^\s*(<.*>)\s*$/s;
  }
  else {
    return $1 if $addr =~ /(<[^>]*>)/;
    $addr =~ s/^\s+|\s+$//sg;
  }

  "<$addr>";
}

sub mail
{
 my $me = shift;
 my $addr = _addr($me, shift);
 my $opts = "";

 if(@_)
  {
   my %opt = @_;
   my($k,$v);

   if(exists ${*$me}{'net_smtp_esmtp'})
    {
     my $esmtp = ${*$me}{'net_smtp_esmtp'};

     if(defined($v = delete $opt{Size}))
      {
       if(exists $esmtp->{SIZE})
        {
         $opts .= sprintf " SIZE=%d", $v + 0
        }
       else
        {
	 carp 'Net::SMTP::mail: SIZE option not supported by host';
        }
      }

     if(defined($v = delete $opt{Return}))
      {
       if(exists $esmtp->{DSN})
        {
	 $opts .= " RET=" . ((uc($v) eq "FULL") ? "FULL" : "HDRS");
        }
       else
        {
	 carp 'Net::SMTP::mail: DSN option not supported by host';
        }
      }

     if(defined($v = delete $opt{Bits}))
      {
       if($v eq "8")
        {
         if(exists $esmtp->{'8BITMIME'})
          {
	 $opts .= " BODY=8BITMIME";
          }
         else
          {
	 carp 'Net::SMTP::mail: 8BITMIME option not supported by host';
          }
        }
       elsif($v eq "binary")
        {
         if(exists $esmtp->{'BINARYMIME'} && exists $esmtp->{'CHUNKING'})
          {
   $opts .= " BODY=BINARYMIME";
   ${*$me}{'net_smtp_chunking'} = 1;
          }
         else
          {
   carp 'Net::SMTP::mail: BINARYMIME option not supported by host';
          }
        }
       elsif(exists $esmtp->{'8BITMIME'} or exists $esmtp->{'BINARYMIME'})
        {
   $opts .= " BODY=7BIT";
        }
       else
        {
   carp 'Net::SMTP::mail: 8BITMIME and BINARYMIME options not supported by host';
        }
      }

     if(defined($v = delete $opt{Transaction}))
      {
       if(exists $esmtp->{CHECKPOINT})
        {
	 $opts .= " TRANSID=" . _addr($me, $v);
        }
       else
        {
	 carp 'Net::SMTP::mail: CHECKPOINT option not supported by host';
        }
      }

     if(defined($v = delete $opt{Envelope}))
      {
       if(exists $esmtp->{DSN})
        {
	 $v =~ s/([^\041-\176]|=|\+)/sprintf "+%02x", ord($1)/sge;
	 $opts .= " ENVID=$v"
        }
       else
        {
	 carp 'Net::SMTP::mail: DSN option not supported by host';
        }
      }

     carp 'Net::SMTP::recipient: unknown option(s) '
		. join(" ", keys %opt)
		. ' - ignored'
	if scalar keys %opt;
    }
   else
    {
     carp 'Net::SMTP::mail: ESMTP not supported by host - options discarded :-(';
    }
  }

 $me->_MAIL("FROM:".$addr.$opts);
}

sub send	  { my $me = shift; $me->_SEND("FROM:" . _addr($me, $_[0])) }
sub send_or_mail  { my $me = shift; $me->_SOML("FROM:" . _addr($me, $_[0])) }
sub send_and_mail { my $me = shift; $me->_SAML("FROM:" . _addr($me, $_[0])) }

sub reset
{
 my $me = shift;

 $me->dataend()
	if(exists ${*$me}{'net_smtp_lastch'});

 $me->_RSET();
}


sub recipient
{
 my $smtp = shift;
 my $opts = "";
 my $skip_bad = 0;

 if(@_ && ref($_[-1]))
  {
   my %opt = %{pop(@_)};
   my $v;

   $skip_bad = delete $opt{'SkipBad'};

   if(exists ${*$smtp}{'net_smtp_esmtp'})
    {
     my $esmtp = ${*$smtp}{'net_smtp_esmtp'};

     if(defined($v = delete $opt{Notify}))
      {
       if(exists $esmtp->{DSN})
        {
	 $opts .= " NOTIFY=" . join(",",map { uc $_ } @$v)
        }
       else
        {
	 carp 'Net::SMTP::recipient: DSN option not supported by host';
        }
      }

     carp 'Net::SMTP::recipient: unknown option(s) '
		. join(" ", keys %opt)
		. ' - ignored'
	if scalar keys %opt;
    }
   elsif(%opt)
    {
     carp 'Net::SMTP::recipient: ESMTP not supported by host - options discarded :-(';
    }
  }

 my @ok;
 my $addr;
 foreach $addr (@_) 
  {
    if($smtp->_RCPT("TO:" . _addr($smtp, $addr) . $opts)) {
      push(@ok,$addr) if $skip_bad;
    }
    elsif(!$skip_bad) {
      return 0;
    }
  }

 return $skip_bad ? @ok : 1;
}

BEGIN {
  *to  = \&recipient;
  *cc  = \&recipient;
  *bcc = \&recipient;
}

sub data
{
 my $me = shift;

 if(exists ${*$me}{'net_smtp_chunking'})
  {
   carp 'Net::SMTP::data: CHUNKING extension in use, must call bdat instead';
  }
 else
  {
   my $ok = $me->_DATA() && $me->datasend(@_);

   $ok && @_ ? $me->dataend
	     : $ok;
  }
}

sub bdat
{
 my $me = shift;

 if(exists ${*$me}{'net_smtp_chunking'})
  {
   my $data = shift;

   $me->_BDAT(length $data) && $me->rawdatasend($data) &&
     $me->response() == CMD_OK;
  }
 else
  {
   carp 'Net::SMTP::bdat: CHUNKING extension is not in use, call data instead';
  }
}

sub bdatlast
{
 my $me = shift;

 if(exists ${*$me}{'net_smtp_chunking'})
  {
   my $data = shift;

   $me->_BDAT(length $data, "LAST") && $me->rawdatasend($data) &&
     $me->response() == CMD_OK;
  }
 else
  {
   carp 'Net::SMTP::bdat: CHUNKING extension is not in use, call data instead';
  }
}

sub datafh {
  my $me = shift;
  return unless $me->_DATA();
  return $me->tied_fh;
}

sub expand
{
 my $me = shift;

 $me->_EXPN(@_) ? ($me->message)
		: ();
}


sub verify { shift->_VRFY(@_) }

sub help
{
 my $me = shift;

 $me->_HELP(@_) ? scalar $me->message
	        : undef;
}

sub quit
{
 my $me = shift;

 $me->_QUIT;
 $me->close;
}

sub DESTROY
{
# ignore
}

##
## RFC821 commands
##

sub _EHLO { shift->command("EHLO", @_)->response()  == CMD_OK }   
sub _HELO { shift->command("HELO", @_)->response()  == CMD_OK }   
sub _MAIL { shift->command("MAIL", @_)->response()  == CMD_OK }   
sub _RCPT { shift->command("RCPT", @_)->response()  == CMD_OK }   
sub _SEND { shift->command("SEND", @_)->response()  == CMD_OK }   
sub _SAML { shift->command("SAML", @_)->response()  == CMD_OK }   
sub _SOML { shift->command("SOML", @_)->response()  == CMD_OK }   
sub _VRFY { shift->command("VRFY", @_)->response()  == CMD_OK }   
sub _EXPN { shift->command("EXPN", @_)->response()  == CMD_OK }   
sub _HELP { shift->command("HELP", @_)->response()  == CMD_OK }   
sub _RSET { shift->command("RSET")->response()	    == CMD_OK }   
sub _NOOP { shift->command("NOOP")->response()	    == CMD_OK }   
sub _QUIT { shift->command("QUIT")->response()	    == CMD_OK }   
sub _DATA { shift->command("DATA")->response()	    == CMD_MORE } 
sub _BDAT { shift->command("BDAT", @_) }
sub _TURN { shift->unsupported(@_); } 			   	  
sub _ETRN { shift->command("ETRN", @_)->response()  == CMD_OK }
sub _AUTH { shift->command("AUTH", @_)->response()  == CMD_OK }   

1;

__END__

