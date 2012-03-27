package Win32::FileSecurity;

#
# FileSecurity.pm
# By Monte Mitzelfelt, monte@conchas.nm.org
# Larry Wall's Artistic License applies to all related Perl
#  and C code for this module
# Thanks to the guys at ActiveWare!
# ver 0.67 ALPHA 1997.07.07
#

require Exporter;
require DynaLoader;
use Carp ;

$VERSION = '1.04';

croak "The Win32::FileSecurity module works only on Windows NT" if (!Win32::IsWinNT()) ;

@ISA= qw( Exporter DynaLoader );

require Exporter ;
require DynaLoader ;

@ISA = qw(Exporter DynaLoader) ;
@EXPORT_OK = qw(
	Get
	Set
	EnumerateRights
	MakeMask
	DELETE
	READ_CONTROL
	WRITE_DAC
	WRITE_OWNER
	SYNCHRONIZE
	STANDARD_RIGHTS_REQUIRED
	STANDARD_RIGHTS_READ
	STANDARD_RIGHTS_WRITE
	STANDARD_RIGHTS_EXECUTE
	STANDARD_RIGHTS_ALL
	SPECIFIC_RIGHTS_ALL
	ACCESS_SYSTEM_SECURITY
	MAXIMUM_ALLOWED
	GENERIC_READ
	GENERIC_WRITE
	GENERIC_EXECUTE
	GENERIC_ALL
	F
	FULL
	R
	READ
	C
	CHANGE
	A
	ADD
	       ) ;

sub AUTOLOAD {
    local($constname);
    ($constname = $AUTOLOAD) =~ s/.*:://;
    #reset $! to zero to reset any current errors.
    local $! = 0;
    $val = constant($constname);
    if($! != 0) {
	if($! =~ /Invalid/) {
	    $AutoLoader::AUTOLOAD = $AUTOLOAD;
	    goto &AutoLoader::AUTOLOAD;
	}
	else {
	    ($pack,$file,$line) = caller;
	    die "Your vendor has not defined Win32::FileSecurity macro "
	       ."$constname, used in $file at line $line.";
	}
    }
    eval "sub $AUTOLOAD { $val }";
    goto &$AUTOLOAD;
}

bootstrap Win32::FileSecurity;

1;

__END__

