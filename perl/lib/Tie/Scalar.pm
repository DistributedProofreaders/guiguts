package Tie::Scalar;

our $VERSION = '1.00';

use Carp;
use warnings::register;

sub new {
    my $pkg = shift;
    $pkg->TIESCALAR(@_);
}

# "Grandfather" the new, a la Tie::Hash

sub TIESCALAR {
    my $pkg = shift;
	if ($pkg->can('new') and $pkg ne __PACKAGE__) {
	warnings::warnif("WARNING: calling ${pkg}->new since ${pkg}->TIESCALAR is missing");
	$pkg->new(@_);
    }
    else {
	croak "$pkg doesn't define a TIESCALAR method";
    }
}

sub FETCH {
    my $pkg = ref $_[0];
    croak "$pkg doesn't define a FETCH method";
}

sub STORE {
    my $pkg = ref $_[0];
    croak "$pkg doesn't define a STORE method";
}

#
# The Tie::StdScalar package provides scalars that behave exactly like
# Perl's built-in scalars. Good base to inherit from, if you're only going to
# tweak a small bit.
#
package Tie::StdScalar;
@ISA = (Tie::Scalar);

sub TIESCALAR {
    my $class = shift;
    my $instance = shift || undef;
    return bless \$instance => $class;
}

sub FETCH {
    return ${$_[0]};
}

sub STORE {
    ${$_[0]} = $_[1];
}

sub DESTROY {
    undef ${$_[0]};
}

1;
