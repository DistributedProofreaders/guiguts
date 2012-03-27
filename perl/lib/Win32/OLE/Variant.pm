# The documentation is at the __END__

package Win32::OLE::Variant;
require Win32::OLE;  # Make sure the XS bootstrap has been called

use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK);

use Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(
	     Variant
	     VT_EMPTY VT_NULL VT_I2 VT_I4 VT_R4 VT_R8 VT_CY VT_DATE VT_BSTR
	     VT_DISPATCH VT_ERROR VT_BOOL VT_VARIANT VT_UNKNOWN VT_DECIMAL VT_UI1
	     VT_ARRAY VT_BYREF
	    );

@EXPORT_OK = qw(CP_ACP CP_OEMCP nothing nullstring);

# Automation data types.
sub VT_EMPTY {0;}
sub VT_NULL {1;}
sub VT_I2 {2;}
sub VT_I4 {3;}
sub VT_R4 {4;}
sub VT_R8 {5;}
sub VT_CY {6;}
sub VT_DATE {7;}
sub VT_BSTR {8;}
sub VT_DISPATCH {9;}
sub VT_ERROR {10;}
sub VT_BOOL {11;}
sub VT_VARIANT {12;}
sub VT_UNKNOWN {13;}
sub VT_DECIMAL {14;}	# Officially not allowed in VARIANTARGs
sub VT_UI1 {17;}

sub VT_ARRAY {0x2000;}
sub VT_BYREF {0x4000;}


# For backward compatibility
sub CP_ACP   {0;}     # ANSI codepage
sub CP_OEMCP {1;}     # OEM codepage

use overload
    # '+' => 'Add', '-' => 'Sub', '*' => 'Mul', '/' => 'Div',
    '""'     => sub {$_[0]->As(VT_BSTR)},
    '0+'     => sub {$_[0]->As(VT_R8)},
    fallback => 1;

sub Variant {
    return Win32::OLE::Variant->new(@_);
}

sub nothing {
    return Win32::OLE::Variant->new(VT_DISPATCH);
}

sub nullstring {
    return Win32::OLE::Variant->new(VT_BSTR);
}

1;

__END__

