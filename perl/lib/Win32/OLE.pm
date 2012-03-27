# The documentation is at the __END__

package Win32::OLE;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK @EXPORT_FAIL $AUTOLOAD
	    $CP $LCID $Warn $LastError $_NewEnum $_Unique);

$VERSION = '0.1701';

use Carp;
use Exporter;
use DynaLoader;
@ISA = qw(Exporter DynaLoader);

@EXPORT = qw();
@EXPORT_OK = qw(in valof with HRESULT EVENTS OVERLOAD
                CP_ACP CP_OEMCP CP_MACCP CP_UTF7 CP_UTF8
		DISPATCH_METHOD DISPATCH_PROPERTYGET
		DISPATCH_PROPERTYPUT DISPATCH_PROPERTYPUTREF);
@EXPORT_FAIL = qw(EVENTS OVERLOAD);

sub export_fail {
    shift;
    my @unknown;
    while (@_) {
	my $symbol = shift;
	if ($symbol eq 'OVERLOAD') {
	    eval <<'OVERLOAD';
	        use overload '""'     => \&valof,
	                     '0+'     => \&valof,
	                     fallback => 1;
OVERLOAD
	}
	elsif ($symbol eq 'EVENTS') {
	    Win32::OLE->Initialize(Win32::OLE::COINIT_OLEINITIALIZE());
	}
	else {
	    push @unknown, $symbol;
	}
    }
    return @unknown;
}

unless (defined &Dispatch) {
    # Use regular DynaLoader if XS part is not yet initialized
    bootstrap Win32::OLE;
    require Win32::OLE::Lite;
}

1;

########################################################################

__END__

