package Win32::PerfLib;

use strict;
use Carp;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK $AUTOLOAD);

require Exporter;
require DynaLoader;
require AutoLoader;

@ISA = qw(Exporter DynaLoader);

@EXPORT = qw(
	     PERF_100NSEC_MULTI_TIMER
	     PERF_100NSEC_MULTI_TIMER_INV
	     PERF_100NSEC_TIMER
	     PERF_100NSEC_TIMER_INV
	     PERF_AVERAGE_BASE
	     PERF_AVERAGE_BULK
	     PERF_AVERAGE_TIMER
	     PERF_COUNTER_BASE
	     PERF_COUNTER_BULK_COUNT
	     PERF_COUNTER_COUNTER
	     PERF_COUNTER_DELTA
	     PERF_COUNTER_ELAPSED
	     PERF_COUNTER_FRACTION
	     PERF_COUNTER_HISTOGRAM
	     PERF_COUNTER_HISTOGRAM_TYPE
	     PERF_COUNTER_LARGE_DELTA
	     PERF_COUNTER_LARGE_QUEUELEN_TYPE
	     PERF_COUNTER_LARGE_RAWCOUNT
	     PERF_COUNTER_LARGE_RAWCOUNT_HEX
	     PERF_COUNTER_MULTI_BASE
	     PERF_COUNTER_MULTI_TIMER
	     PERF_COUNTER_MULTI_TIMER_INV
	     PERF_COUNTER_NODATA
	     PERF_COUNTER_QUEUELEN
	     PERF_COUNTER_QUEUELEN_TYPE
	     PERF_COUNTER_RATE
	     PERF_COUNTER_RAWCOUNT
	     PERF_COUNTER_RAWCOUNT_HEX
	     PERF_COUNTER_TEXT
	     PERF_COUNTER_TIMER
	     PERF_COUNTER_TIMER_INV
	     PERF_COUNTER_VALUE
	     PERF_DATA_REVISION
	     PERF_DATA_VERSION
	     PERF_DELTA_BASE
	     PERF_DELTA_COUNTER
	     PERF_DETAIL_ADVANCED
	     PERF_DETAIL_EXPERT
	     PERF_DETAIL_NOVICE
	     PERF_DETAIL_WIZARD
	     PERF_DISPLAY_NOSHOW
	     PERF_DISPLAY_NO_SUFFIX
	     PERF_DISPLAY_PERCENT
	     PERF_DISPLAY_PER_SEC
	     PERF_DISPLAY_SECONDS
	     PERF_ELAPSED_TIME
	     PERF_INVERSE_COUNTER
	     PERF_MULTI_COUNTER
	     PERF_NO_INSTANCES
	     PERF_NO_UNIQUE_ID
	     PERF_NUMBER_DECIMAL
	     PERF_NUMBER_DEC_1000
	     PERF_NUMBER_HEX
	     PERF_OBJECT_TIMER
	     PERF_RAW_BASE
	     PERF_RAW_FRACTION
	     PERF_SAMPLE_BASE
	     PERF_SAMPLE_COUNTER
	     PERF_SAMPLE_FRACTION
	     PERF_SIZE_DWORD
	     PERF_SIZE_LARGE
	     PERF_SIZE_VARIABLE_LEN
	     PERF_SIZE_ZERO
	     PERF_TEXT_ASCII
	     PERF_TEXT_UNICODE
	     PERF_TIMER_100NS
	     PERF_TIMER_TICK
	     PERF_TYPE_COUNTER
	     PERF_TYPE_NUMBER
	     PERF_TYPE_TEXT
	     PERF_TYPE_ZERO
	    );

$VERSION = '0.05';

sub AUTOLOAD {
   
    my $constname;
    ($constname = $AUTOLOAD) =~ s/.*:://;
    local $! = 0;
    my $val = constant($constname);
    if ($! != 0) {
	if ($! =~ /Invalid/) {
	    $AutoLoader::AUTOLOAD = $AUTOLOAD;
	    goto &AutoLoader::AUTOLOAD;
	}
	else {
	    croak "Your vendor has not defined Win32::PerfLib macro $constname";
	}
    }
    eval "sub $AUTOLOAD { $val }";
    goto &$AUTOLOAD;
}

bootstrap Win32::PerfLib $VERSION;

# Preloaded methods go here.

sub new
{
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $comp = shift;
    my $handle;
    my $self = {};
    if(PerfLibOpen($comp,$handle))
    {
	$self->{handle} = $handle;
	bless $self, $class;
	return $self;
    }
    else
    {
	return undef;
    }
    
}

sub Close
{
    my $self = shift;
    return PerfLibClose($self->{handle});
}

sub DESTROY
{
    my $self = shift;
    if(!PerfLibClose($self->{handle}))
    {
	croak "Error closing handle!\n";
    }
}

sub GetCounterNames
{
    my($machine,$href) = @_;
    if(ref $href ne "HASH")
    {
	croak("usage: Win32::PerfLib::GetCounterNames(machine,hashRef)\n");
    }
    my($data,@data,$num,$name);
    my $retval = PerfLibGetNames($machine,$data);
    if($retval)
    {
	@data = split(/\0/, $data);
	while(@data)
	{
	    $num = shift @data;
	    $name = shift @data;
	    $href->{$num} = $name;
	}
    }
    $retval;
}

sub GetCounterHelp
{
    my($machine,$href) = @_;
    if(ref $href ne "HASH")
    {
	croak("usage: Win32::PerfLib::GetCounterHelp(machine,hashRef)\n");
    }
    my($data,@data,$num,$name);
    my $retval = PerfLibGetHelp($machine,$data);
    if($retval)
    {
	@data = split(/\0/, $data);
	while(@data)
	{
	    $num = shift @data;
	    $name = shift @data;
	    $href->{$num} = $name;
	}
    }
    $retval;
}

sub GetObjectList
{
    my $self = shift;
    my $object = shift;
    my $data = shift;
    if(ref $data ne "HASH")
    {
	croak("reference isn't a hash reference!\n");
    }
    return PerfLibGetObjects($self->{handle}, $object, $data);
}

sub GetCounterType
{
    my $type = shift;
    my $retval;
    if( &Win32::PerfLib::PERF_100NSEC_MULTI_TIMER == $type )
    {
	$retval = "PERF_100NSEC_MULTI_TIMER";
    }
    elsif( &Win32::PerfLib::PERF_100NSEC_MULTI_TIMER_INV == $type )
    {
	$retval = "PERF_100NSEC_MULTI_TIMER_INV";
    }
    elsif( &Win32::PerfLib::PERF_100NSEC_TIMER == $type )
    {
	$retval = "PERF_100NSEC_TIMER";
    }
    elsif( &Win32::PerfLib::PERF_100NSEC_TIMER_INV == $type )
    {
	$retval = "PERF_100NSEC_TIMER_INV";
    }
    elsif( &Win32::PerfLib::PERF_AVERAGE_BASE == $type )
    {
	$retval = "PERF_AVERAGE_BASE";
    }
    elsif( &Win32::PerfLib::PERF_AVERAGE_BULK == $type )
    {
	$retval = "PERF_AVERAGE_BULK";
    }
    elsif( &Win32::PerfLib::PERF_AVERAGE_TIMER == $type )
    {
	$retval = "PERF_AVERAGE_TIMER";
    }
    elsif( &Win32::PerfLib::PERF_COUNTER_BULK_COUNT == $type )
    {
	$retval = "PERF_COUNTER_BULK_COUNT";
    }
    elsif( &Win32::PerfLib::PERF_COUNTER_COUNTER == $type )
    {
	$retval = "PERF_COUNTER_COUNTER";
    }
    elsif( &Win32::PerfLib::PERF_COUNTER_DELTA == $type )
    {
	$retval = "PERF_COUNTER_DELTA";
    }
    elsif( &Win32::PerfLib::PERF_COUNTER_LARGE_DELTA == $type )
    {
	$retval = "PERF_COUNTER_LARGE_DELTA";
    }
    elsif( &Win32::PerfLib::PERF_COUNTER_LARGE_QUEUELEN_TYPE == $type )
    {
	$retval = "PERF_COUNTER_LARGE_QUEUELEN_TYPE";
    }
    elsif( &Win32::PerfLib::PERF_COUNTER_LARGE_RAWCOUNT == $type )
    {
	$retval = "PERF_COUNTER_LARGE_RAWCOUNT";
    }
    elsif( &Win32::PerfLib::PERF_COUNTER_LARGE_RAWCOUNT_HEX == $type )
    {
	$retval = "PERF_COUNTER_LARGE_RAWCOUNT_HEX";
    }
    elsif( &Win32::PerfLib::PERF_COUNTER_MULTI_BASE == $type )
    {
	$retval = "PERF_COUNTER_MULTI_BASE";
    }
    elsif( &Win32::PerfLib::PERF_COUNTER_MULTI_TIMER == $type )
    {
	$retval = "PERF_COUNTER_MULTI_TIMER";
    }
    elsif( &Win32::PerfLib::PERF_COUNTER_MULTI_TIMER_INV == $type )
    {
	$retval = "PERF_COUNTER_MULTI_TIMER_INV";
    }
    elsif( &Win32::PerfLib::PERF_COUNTER_NODATA == $type )
    {
	$retval = "PERF_COUNTER_NODATA";
    }
    elsif( &Win32::PerfLib::PERF_COUNTER_QUEUELEN_TYPE == $type )
    {
	$retval = "PERF_COUNTER_QUEUELEN_TYPE";
    }
    elsif( &Win32::PerfLib::PERF_COUNTER_RAWCOUNT == $type )
    {
	$retval = "PERF_COUNTER_RAWCOUNT";
    }
    elsif( &Win32::PerfLib::PERF_COUNTER_RAWCOUNT_HEX == $type )
    {
	$retval = "PERF_COUNTER_RAWCOUNT_HEX";
    }
    elsif( &Win32::PerfLib::PERF_COUNTER_TEXT == $type )
    {
	$retval = "PERF_COUNTER_TEXT";
    }
    elsif( &Win32::PerfLib::PERF_COUNTER_TIMER == $type )
    {
	$retval = "PERF_COUNTER_TIMER";
    }
    elsif( &Win32::PerfLib::PERF_COUNTER_TIMER_INV == $type )
    {
	$retval = "PERF_COUNTER_TIMER_INV";
    }
    elsif( &Win32::PerfLib::PERF_ELAPSED_TIME == $type )
    {
	$retval = "PERF_ELAPSED_TIME";
    }
    elsif( &Win32::PerfLib::PERF_RAW_BASE == $type )
    {
	$retval = "PERF_RAW_BASE";
    }
    elsif( &Win32::PerfLib::PERF_RAW_FRACTION == $type )
    {
	$retval = "PERF_RAW_FRACTION";
    }
    elsif( &Win32::PerfLib::PERF_SAMPLE_BASE == $type )
    {
	$retval = "PERF_SAMPLE_BASE";
    }
    elsif( &Win32::PerfLib::PERF_SAMPLE_COUNTER == $type )
    {
	$retval = "PERF_SAMPLE_COUNTER";
    }
    elsif( &Win32::PerfLib::PERF_SAMPLE_FRACTION == $type )
    {
	$retval = "PERF_SAMPLE_FRACTION";
    }
    $retval;
}



1;
__END__

