package Net::HTTP::NB;

# $Id: NB.pm,v 1.5 2001/08/28 03:03:42 gisle Exp $

use strict;
use vars qw($VERSION @ISA);

$VERSION = "0.02";
require Net::HTTP;
@ISA=qw(Net::HTTP);

sub sysread {
    my $self = $_[0];
    if (${*$self}{'httpnb_read_count'}++) {
	${*$self}{'http_buf'} = ${*$self}{'httpnb_save'};
	die "Multi-read\n";
    }
    my $buf;
    my $offset = $_[3] || 0;
    my $n = sysread($self, $_[1], $_[2], $offset);
    ${*$self}{'httpnb_save'} .= substr($_[1], $offset);
    return $n;
}

sub read_response_headers {
    my $self = shift;
    ${*$self}{'httpnb_read_count'} = 0;
    ${*$self}{'httpnb_save'} = ${*$self}{'http_buf'};
    my @h = eval { $self->SUPER::read_response_headers(@_) };
    if ($@) {
	return if $@ eq "Multi-read\n";
	die;
    }
    return @h;
}

sub read_entity_body {
    my $self = shift;
    ${*$self}{'httpnb_read_count'} = 0;
    ${*$self}{'httpnb_save'} = ${*$self}{'http_buf'};
    # XXX I'm not so sure this does the correct thing in case of
    # transfer-encoding tranforms
    my $n = eval { $self->SUPER::read_entity_body(@_); };
    if ($@) {
	$_[0] = "";
	return -1;
    }
    return $n;
}

1;

__END__

