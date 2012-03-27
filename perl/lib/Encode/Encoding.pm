package Encode::Encoding;
# Base class for classes which implement encodings
use strict;
our $VERSION = do { my @r = (q$Revision: 1.33 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

require Encode;

sub Define
{
    my $obj = shift;
    my $canonical = shift;
    $obj = bless { Name => $canonical },$obj unless ref $obj;
    # warn "$canonical => $obj\n";
    Encode::define_encoding($obj, $canonical, @_);
}

sub name  { return shift->{'Name'} }

sub renew { return $_[0] }
*new_sequence = \&renew;

sub needs_lines { 0 };

sub perlio_ok { 
    eval{ require PerlIO::encoding };
    return $@ ? 0 : 1;
}

# (Temporary|legacy) methods

sub toUnicode    { shift->decode(@_) }
sub fromUnicode  { shift->encode(@_) }

#
# Needs to be overloaded or just croak
#

sub encode {
    require Carp;
    my $obj = shift;
    my $class = ref($obj) ? ref($obj) : $obj;
    Carp::croak $class, "->encode() not defined!";
}

sub decode{
    require Carp;
    my $obj = shift;
    my $class = ref($obj) ? ref($obj) : $obj;
    Carp::croak $class, "->encode() not defined!";
}

sub DESTROY {}

1;
__END__

