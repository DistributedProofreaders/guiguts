# ======================================================================
#
# Copyright (C) 2000-2001 Paul Kulchenko (paulclinger@yahoo.com)
# SOAP::Lite is free software; you can redistribute it
# and/or modify it under the same terms as Perl itself.
#
# $Id: IO.pm,v 1.3 2001/08/11 19:09:57 paulk Exp $
#
# ======================================================================

package SOAP::Transport::IO;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%s", map {s/_//g; $_} q$Name: release-0_55-public $ =~ /-(\d+)_([\d_]+)/);

use IO::File;
use SOAP::Lite;

# ======================================================================

package SOAP::Transport::IO::Server;

use strict;
use Carp ();
use vars qw(@ISA);
@ISA = qw(SOAP::Server);

sub new {
  my $self = shift;
    
  unless (ref $self) {
    my $class = ref($self) || $self;
    $self = $class->SUPER::new(@_);
  }
  return $self;
}

sub BEGIN {
  no strict 'refs';
  my %modes = (in => '<', out => '>');
  for my $method (keys %modes) {
    my $field = '_' . $method;
    *$method = sub {
      my $self = shift->new;
      return $self->{$field} unless @_;

      my $file = shift;
      if (defined $file && !ref $file && !defined fileno($file)) {
        my $name = $file;
        open($file = new IO::File, $modes{$method} . $name) or Carp::croak "$name: $!";
      }
      $self->{$field} = $file;
      return $self;
    }
  }
}

sub handle {
  my $self = shift->new;

  $self->in(*STDIN)->out(*STDOUT) unless defined $self->in;
  my $in = $self->in;
  my $out = $self->out;

  my $result = $self->SUPER::handle(join '', <$in>);
  no strict 'refs'; print {$out} $result if defined $out;
}

# ======================================================================

1;

__END__

