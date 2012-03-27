package SDBM_File;

use strict;
use warnings;

require Tie::Hash;
use XSLoader ();

our @ISA = qw(Tie::Hash);
our $VERSION = "1.04" ;

XSLoader::load 'SDBM_File', $VERSION;

1;

__END__

