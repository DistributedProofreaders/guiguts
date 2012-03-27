package Win32::Service;

#
# Service.pm
# Written by Douglas_Lankshear@ActiveWare.com
#
# subsequently hacked by Gurusamy Sarathy <gsar@activestate.com>
#

$VERSION = '0.05';

require Exporter;
require DynaLoader;

die "The Win32::Service module works only on Windows NT" if(!Win32::IsWinNT());

@ISA= qw( Exporter DynaLoader );
@EXPORT_OK =
    qw(
	StartService
	StopService
	GetStatus
	PauseService
	ResumeService
	GetServices
    );

sub AUTOLOAD
{
    my($constname);
    ($constname = $AUTOLOAD) =~ s/.*:://;
    #reset $! to zero to reset any current errors.
    local $! = 0;
    my $val = constant($constname);
    if ($! != 0) {
	if($! =~ /Invalid/) {
	    $AutoLoader::AUTOLOAD = $AUTOLOAD;
	    goto &AutoLoader::AUTOLOAD;
	}
	else {
	    ($pack,$file,$line) = caller;
	    die "Your vendor has not defined Win32::Service macro $constname, used in $file at line $line.";
	}
    }
    eval "sub $AUTOLOAD { $val }";
    goto &$AUTOLOAD;
}

bootstrap Win32::Service;

1;
__END__
