package Encode::EBCDIC;
use Encode;
our $VERSION = do { my @r = (q$Revision: 1.21 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

use XSLoader;
XSLoader::load(__PACKAGE__,$VERSION);

1;
__END__

