#
# $Id: Encoder.pm,v 0.7 2003/07/08 21:52:14 dankogai Exp $
#
package Encode::Encoder;
use strict;
use warnings;
our $VERSION = do { my @r = (q$Revision: 0.7 $ =~ /\d+/g); sprintf "%d."."%02d"  x $#r, @r };

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw ( encoder );

our $AUTOLOAD;
sub DEBUG () { 0 }
use Encode qw(encode decode find_encoding from_to);
use Carp;

sub new{
    my ($class, $data, $encname) = @_;
    unless($encname){
	$encname = Encode::is_utf8($data) ? 'utf8' : '';
    }else{
	my $obj = find_encoding($encname) 
	    or croak __PACKAGE__, ": unknown encoding: $encname";
	$encname = $obj->name;
    }
    my $self = {
		data     => $data,
		encoding => $encname,
	       };
    bless $self => $class;
}

sub encoder{ __PACKAGE__->new(@_) }

sub data{
    my ($self, $data) = @_;
    if (defined $data){
	$self->{data} = $data;
	return $data;
    }else{
	return $self->{data};
    }
}

sub encoding{
    my ($self, $encname) = @_;
    if ($encname){
	my $obj = find_encoding($encname) 
	    or confess __PACKAGE__, ": unknown encoding: $encname";
	$self->{encoding} = $obj->name;
	return $self;
    }else{
	return $self->{encoding}
    }
}

sub bytes {
    my ($self, $encname) = @_;
    $encname ||= $self->{encoding};
    my $obj = find_encoding($encname) 
	    or confess __PACKAGE__, ": unknown encoding: $encname";
    $self->{data} = $obj->decode($self->{data}, 1);
    $self->{encoding} = '' ;
    return $self;
}

sub DESTROY{ # defined so it won't autoload.
    DEBUG and warn shift;
}

sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self)
	or confess "$self is not an object";
    my $myname = $AUTOLOAD;
    $myname =~ s/.*://;   # strip fully-qualified portion
    my $obj = find_encoding($myname) 
	    or confess __PACKAGE__, ": unknown encoding: $myname";
    DEBUG and warn $self->{encoding}, " => ", $obj->name;
    if ($self->{encoding}){
	from_to($self->{data}, $self->{encoding}, $obj->name, 1);
    }else{
	$self->{data} = $obj->encode($self->{data}, 1);
    }
    $self->{encoding} = $obj->name;
    return $self;
}

use overload 
    q("") => sub { $_[0]->{data} },
    q(0+) => sub { use bytes (); bytes::length($_[0]->{data}) },
    fallback => 1,
    ;

1;
__END__

