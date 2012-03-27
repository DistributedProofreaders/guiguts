package Win32::Process;

require Exporter;
require DynaLoader;
@ISA = qw(Exporter DynaLoader);

$VERSION = '0.09';

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw(
	CREATE_DEFAULT_ERROR_MODE
	CREATE_NEW_CONSOLE
	CREATE_NEW_PROCESS_GROUP
	CREATE_NO_WINDOW
	CREATE_SEPARATE_WOW_VDM
	CREATE_SUSPENDED
	CREATE_UNICODE_ENVIRONMENT
	DEBUG_ONLY_THIS_PROCESS
	DEBUG_PROCESS
	DETACHED_PROCESS
	HIGH_PRIORITY_CLASS
	IDLE_PRIORITY_CLASS
	INFINITE
	NORMAL_PRIORITY_CLASS
	REALTIME_PRIORITY_CLASS
	THREAD_PRIORITY_ABOVE_NORMAL
	THREAD_PRIORITY_BELOW_NORMAL
	THREAD_PRIORITY_ERROR_RETURN
	THREAD_PRIORITY_HIGHEST
	THREAD_PRIORITY_IDLE
	THREAD_PRIORITY_LOWEST
	THREAD_PRIORITY_NORMAL
	THREAD_PRIORITY_TIME_CRITICAL
);

sub AUTOLOAD {
    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.
    my($constname);
    ($constname = $AUTOLOAD) =~ s/.*:://;
    local $! = 0;
    my $val = constant($constname);
    if ($! != 0) {
        my ($pack,$file,$line) = caller;
        die "Your vendor has not defined Win32::Process macro $constname, used at $file line $line.";
    }
    eval "sub $AUTOLOAD { $val }";
    goto &$AUTOLOAD;
} # end AUTOLOAD

bootstrap Win32::Process;

1;
__END__

# Local Variables:
# tmtrack-file-task: "Win32::Process"
# End:
