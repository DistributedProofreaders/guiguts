package Win32::File;

#
# File.pm
# Written by Douglas_Lankshear@ActiveWare.com
#
# subsequent hacks:
#   Gurusamy Sarathy
#

$VERSION = '0.05';

require Exporter;
require DynaLoader;

@ISA= qw( Exporter DynaLoader );
@EXPORT = qw(
		ARCHIVE
		COMPRESSED
		DIRECTORY
		HIDDEN
		NORMAL
		OFFLINE
		READONLY
		SYSTEM
		TEMPORARY
	    );
@EXPORT_OK = qw(GetAttributes SetAttributes);

sub AUTOLOAD 
{
    my($constname);
    ($constname = $AUTOLOAD) =~ s/.*:://;
    #reset $! to zero to reset any current errors.
    local $! = 0;
    my $val = constant($constname);
    if($! != 0)
	{
		if($! =~ /Invalid/)
		{
			$AutoLoader::AUTOLOAD = $AUTOLOAD;
			goto &AutoLoader::AUTOLOAD;
		}
		else 
		{
			($pack,$file,$line) = caller;
			die "Your vendor has not defined Win32::File macro $constname, used in $file at line $line.";
		}
    }
    eval "sub $AUTOLOAD { $val }";
    goto &$AUTOLOAD;
}

bootstrap Win32::File;

1;
__END__
