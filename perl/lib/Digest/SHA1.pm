package Digest::SHA1;

use strict;
use vars qw($VERSION @ISA @EXPORT_OK);

$VERSION = '2.06';  # $Date: 2003/10/13 07:11:18 $

require Exporter;
*import = \&Exporter::import;
@EXPORT_OK = qw(sha1 sha1_hex sha1_base64 sha1_transform);

require DynaLoader;
@ISA=qw(DynaLoader);
Digest::SHA1->bootstrap($VERSION);

*reset = \&new;

1;
__END__

