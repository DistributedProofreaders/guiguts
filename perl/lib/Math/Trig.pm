#
# Trigonometric functions, mostly inherited from Math::Complex.
# -- Jarkko Hietaniemi, since April 1997
# -- Raphael Manfredi, September 1996 (indirectly: because of Math::Complex)
#

require Exporter;
package Math::Trig;

use 5.006;
use strict;

use Math::Complex qw(:trig);

our($VERSION, $PACKAGE, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);

@ISA = qw(Exporter);

$VERSION = 1.02;

my @angcnv = qw(rad2deg rad2grad
		deg2rad deg2grad
		grad2rad grad2deg);

@EXPORT = (@{$Math::Complex::EXPORT_TAGS{'trig'}},
	   @angcnv);

my @rdlcnv = qw(cartesian_to_cylindrical
		cartesian_to_spherical
		cylindrical_to_cartesian
		cylindrical_to_spherical
		spherical_to_cartesian
		spherical_to_cylindrical);

@EXPORT_OK = (@rdlcnv, 'great_circle_distance', 'great_circle_direction');

%EXPORT_TAGS = ('radial' => [ @rdlcnv ]);

sub pi2  () { 2 * pi }
sub pip2 () { pi / 2 }

sub DR  () { pi2/360 }
sub RD  () { 360/pi2 }
sub DG  () { 400/360 }
sub GD  () { 360/400 }
sub RG  () { 400/pi2 }
sub GR  () { pi2/400 }

#
# Truncating remainder.
#

sub remt ($$) {
    # Oh yes, POSIX::fmod() would be faster. Possibly. If it is available.
    $_[0] - $_[1] * int($_[0] / $_[1]);
}

#
# Angle conversions.
#

sub rad2rad($)     { remt($_[0], pi2) }

sub deg2deg($)     { remt($_[0], 360) }

sub grad2grad($)   { remt($_[0], 400) }

sub rad2deg ($;$)  { my $d = RD * $_[0]; $_[1] ? $d : deg2deg($d) }

sub deg2rad ($;$)  { my $d = DR * $_[0]; $_[1] ? $d : rad2rad($d) }

sub grad2deg ($;$) { my $d = GD * $_[0]; $_[1] ? $d : deg2deg($d) }

sub deg2grad ($;$) { my $d = DG * $_[0]; $_[1] ? $d : grad2grad($d) }

sub rad2grad ($;$) { my $d = RG * $_[0]; $_[1] ? $d : grad2grad($d) }

sub grad2rad ($;$) { my $d = GR * $_[0]; $_[1] ? $d : rad2rad($d) }

sub cartesian_to_spherical {
    my ( $x, $y, $z ) = @_;

    my $rho = sqrt( $x * $x + $y * $y + $z * $z );

    return ( $rho,
             atan2( $y, $x ),
             $rho ? acos( $z / $rho ) : 0 );
}

sub spherical_to_cartesian {
    my ( $rho, $theta, $phi ) = @_;

    return ( $rho * cos( $theta ) * sin( $phi ),
             $rho * sin( $theta ) * sin( $phi ),
             $rho * cos( $phi   ) );
}

sub spherical_to_cylindrical {
    my ( $x, $y, $z ) = spherical_to_cartesian( @_ );

    return ( sqrt( $x * $x + $y * $y ), $_[1], $z );
}

sub cartesian_to_cylindrical {
    my ( $x, $y, $z ) = @_;

    return ( sqrt( $x * $x + $y * $y ), atan2( $y, $x ), $z );
}

sub cylindrical_to_cartesian {
    my ( $rho, $theta, $z ) = @_;

    return ( $rho * cos( $theta ), $rho * sin( $theta ), $z );
}

sub cylindrical_to_spherical {
    return ( cartesian_to_spherical( cylindrical_to_cartesian( @_ ) ) );
}

sub great_circle_distance {
    my ( $theta0, $phi0, $theta1, $phi1, $rho ) = @_;

    $rho = 1 unless defined $rho; # Default to the unit sphere.

    my $lat0 = pip2 - $phi0;
    my $lat1 = pip2 - $phi1;

    return $rho *
        acos(cos( $lat0 ) * cos( $lat1 ) * cos( $theta0 - $theta1 ) +
             sin( $lat0 ) * sin( $lat1 ) );
}

sub great_circle_direction {
    my ( $theta0, $phi0, $theta1, $phi1 ) = @_;

    my $distance = &great_circle_distance;

    my $lat0 = pip2 - $phi0;
    my $lat1 = pip2 - $phi1;

    my $direction =
	acos((sin($lat1) - sin($lat0) * cos($distance)) /
	     (cos($lat0) * sin($distance)));

    $direction = pi2 - $direction
	if sin($theta1 - $theta0) < 0;

    return rad2rad($direction);
}

1;

__END__
=pod

# eof
