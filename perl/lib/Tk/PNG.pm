package Tk::PNG;
require DynaLoader;

use vars qw($VERSION);
$VERSION = sprintf '4.%03d', q$Revision: #3 $ =~ /\D(\d+)\s*$/;

use Tk 800.005;
require Tk::Image;
require Tk::Photo;

use base qw(DynaLoader);

bootstrap Tk::PNG $Tk::VERSION;

1;

__END__


