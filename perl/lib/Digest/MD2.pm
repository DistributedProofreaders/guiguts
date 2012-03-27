package Digest::MD2;

use strict;
use vars qw($VERSION @ISA @EXPORT_OK);

$VERSION = '2.03';  # $Date: 2003/07/23 06:33:38 $

require Exporter;
*import = \&Exporter::import;
@EXPORT_OK = qw(md2 md2_hex md2_base64);

require DynaLoader;
@ISA=qw(DynaLoader);
Digest::MD2->bootstrap($VERSION);

*reset = \&new;

1;
__END__

