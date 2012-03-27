package Tk::JPEG;
require DynaLoader;

use vars qw($VERSION);
$VERSION = sprintf '4.%03d', q$Revision: #2$ =~ /\D(\d+)\s*$/;
use Tk 800.015;
require Tk::Image;
require Tk::Photo;
require DynaLoader;

use vars qw($VERSION $XS_VERSION);

@ISA = qw(DynaLoader);

$XS_VERSION = $Tk::VERSION;
bootstrap Tk::JPEG;

1;

__END__


