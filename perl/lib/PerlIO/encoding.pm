package PerlIO::encoding;
use strict;
our $VERSION = '0.07';
our $DEBUG = 0;
$DEBUG and warn __PACKAGE__, " called by ", join(", ", caller), "\n";

#
# Equivalent of this is done in encoding.xs - do not uncomment.
#
# use Encode ();

use XSLoader ();
XSLoader::load(__PACKAGE__, $VERSION);

our $fallback = Encode::PERLQQ()|Encode::WARN_ON_ERR();

1;
__END__

