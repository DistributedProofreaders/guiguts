# IO::Zlib.pm
#
# Copyright (c) 1998-2001 Tom Hughes <tom@compton.nu>.
# All rights reserved. This program is free software; you can redistribute
# it and/or modify it under the same terms as Perl itself.

package IO::Zlib;

require 5.004;

use strict;
use vars qw($VERSION $AUTOLOAD @ISA);

use Carp;
use Compress::Zlib;
use Symbol;
use Tie::Handle;

$VERSION = "1.01";

@ISA = qw(Tie::Handle);

sub TIEHANDLE
{
    my $class = shift;
    my @args = @_;

    my $self = bless {}, $class;

    return @args ? $self->OPEN(@args) : $self;
}

sub DESTROY
{
}

sub OPEN
{
    my $self = shift;
    my $filename = shift;
    my $mode = shift;

    croak "open() needs a filename" unless defined($filename);

    $self->{'file'} = gzopen($filename,$mode);
    $self->{'eof'} = 0;

    return defined($self->{'file'}) ? $self : undef;
}

sub CLOSE
{
    my $self = shift;

    return undef unless defined($self->{'file'});

    my $status = $self->{'file'}->gzclose();

    delete $self->{'file'};
    delete $self->{'eof'};

    return ($status == 0) ? 1 : undef;
}

sub READ
{
    my $self = shift;
    my $bufref = \$_[0];
    my $nbytes = $_[1];
    my $offset = $_[2];

    croak "NBYTES must be specified" unless defined($nbytes);
    croak "OFFSET not supported" if defined($offset) && $offset != 0;

    return 0 if $self->{'eof'};

    my $bytesread = $self->{'file'}->gzread($$bufref,$nbytes);

    return undef if $bytesread < 0;

    $self->{'eof'} = 1 if $bytesread < $nbytes;

    return $bytesread;
}

sub READLINE
{
    my $self = shift;

    my $line;

    return () if $self->{'file'}->gzreadline($line) <= 0;

    return $line unless wantarray;

    my @lines = $line;

    while ($self->{'file'}->gzreadline($line) > 0)
    {
        push @lines, $line;
    }

    return @lines;
}

sub WRITE
{
    my $self = shift;
    my $buf = shift;
    my $length = shift;
    my $offset = shift;

    croak "bad LENGTH" unless $length <= length($buf);
    croak "OFFSET not supported" if defined($offset) && $offset != 0;

    return $self->{'file'}->gzwrite(substr($buf,0,$length));
}

sub EOF
{
    my $self = shift;

    return $self->{'eof'};
}

sub new
{
    my $class = shift;
    my @args = @_;

    my $self = gensym();

    tie *{$self}, $class, @args;

    return tied(${$self}) ? bless $self, $class : undef;
}

sub getline
{
    my $self = shift;

    return scalar tied(*{$self})->READLINE();
}

sub getlines
{
    my $self = shift;

    croak unless wantarray;

    return tied(*{$self})->READLINE();
}

sub opened
{
    my $self = shift;

    return defined tied(*{$self})->{'file'};
}

sub AUTOLOAD
{
    my $self = shift;

    $AUTOLOAD =~ s/.*:://;
    $AUTOLOAD =~ tr/a-z/A-Z/;

    return tied(*{$self})->$AUTOLOAD(@_);
}

1;
