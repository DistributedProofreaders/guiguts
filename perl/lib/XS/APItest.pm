package XS::APItest;

use 5.008;
use strict;
use warnings;
use Carp;

use base qw/ DynaLoader Exporter /;

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# Export everything since these functions are only used by a test script
our @EXPORT = qw( print_double print_int print_long
		  print_float print_long_double have_long_double print_flush
);

our $VERSION = '0.03';

bootstrap XS::APItest $VERSION;

1;
__END__

