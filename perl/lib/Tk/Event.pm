package Tk::Event;
use vars qw($VERSION $XS_VERSION @EXPORT_OK);
END { CleanupGlue() }
$VERSION = sprintf '4.%03d', q$Revision: #14 $ =~ /\D(\d+)\s*$/;
$XS_VERSION = '804.026';
use base  qw(Exporter);
use XSLoader;
@EXPORT_OK = qw($XS_VERSION DONT_WAIT WINDOW_EVENTS  FILE_EVENTS
                TIMER_EVENTS IDLE_EVENTS ALL_EVENTS);
XSLoader::load 'Tk::Event',$XS_VERSION;
require   Tk::Event::IO;
1;
__END__
