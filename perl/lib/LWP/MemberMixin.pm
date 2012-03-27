package LWP::MemberMixin;

# $Id: MemberMixin.pm,v 1.7 2003/10/23 18:56:01 uid39246 Exp $

sub _elem
{
    my $self = shift;
    my $elem = shift;
    my $old = $self->{$elem};
    $self->{$elem} = shift if @_;
    return $old;
}

1;

__END__

