package strict;

$strict::VERSION = "1.03";

my %bitmask = (
refs => 0x00000002,
subs => 0x00000200,
vars => 0x00000400
);

sub bits {
    my $bits = 0;
    my @wrong;
    foreach my $s (@_) {
	push @wrong, $s unless exists $bitmask{$s};
        $bits |= $bitmask{$s} || 0;
    }
    if (@wrong) {
        require Carp;
        Carp::croak("Unknown 'strict' tag(s) '@wrong'");
    }
    $bits;
}

my $default_bits = bits(qw(refs subs vars));

sub import {
    shift;
    $^H |= @_ ? bits(@_) : $default_bits;
}

sub unimport {
    shift;
    $^H &= ~ (@_ ? bits(@_) : $default_bits);
}

1;
__END__

