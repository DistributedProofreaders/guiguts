# ======================================================================
#
# Copyright (C) 2000-2001 Paul Kulchenko (paulclinger@yahoo.com)
# SOAP::Lite is free software; you can redistribute it
# and/or modify it under the same terms as Perl itself.
#
# $Id: POP3.pm,v 1.3 2001/08/11 19:09:57 paulk Exp $
#
# ======================================================================

package SOAP::Transport::POP3;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%s", map {s/_//g; $_} q$Name: release-0_55-public $ =~ /-(\d+)_([\d_]+)/);

use Net::POP3; 
use URI; 
use SOAP::Lite;

# ======================================================================

package SOAP::Transport::POP3::Server;

use Carp ();
use vars qw(@ISA $AUTOLOAD);
@ISA = qw(SOAP::Server);

sub DESTROY { my $self = shift; $self->quit if $self->{_pop3server} }

sub new {
  my $self = shift;
    
  unless (ref $self) {
    my $class = ref($self) || $self;
    my $address = shift;
    Carp::carp "URLs without 'pop://' scheme are deprecated. Still continue" 
      if $address =~ s!^(pop://)?!pop://!i && !$1;
    my $server = URI->new($address);
    $self = $class->SUPER::new(@_);
    $self->{_pop3server} = Net::POP3->new($server->host_port) or Carp::croak "Can't connect to '@{[$server->host_port]}': $!";
    my $method = !$server->auth || $server->auth eq '*' ? 'login' : 
                  $server->auth eq '+APOP' ? 'apop' : 
                  Carp::croak "Unsupported authentication scheme '@{[$server->auth]}'";
    $self->{_pop3server}->$method(split /:/, $server->user) or Carp::croak "Can't authenticate to '@{[$server->host_port]}' with '$method' method"
      if defined $server->user;
  }
  return $self;
}

sub AUTOLOAD {
  my $method = substr($AUTOLOAD, rindex($AUTOLOAD, '::') + 2);
  return if $method eq 'DESTROY';

  no strict 'refs';
  *$AUTOLOAD = sub { shift->{_pop3server}->$method(@_) };
  goto &$AUTOLOAD;
}

sub handle {
  my $self = shift->new;
  my $messages = $self->list or return;
  foreach my $msgid (keys %$messages) {
    $self->SUPER::handle(join '', @{$self->get($msgid)});
  } continue {
    $self->delete($msgid);
  }
  return scalar keys %$messages;
}

sub make_fault { return }

# ======================================================================

1;

__END__

