#
# EventLog.pm
#
# Creates an object oriented interface to the Windows NT Evenlog
# Written by Jesse Dougherty
#

package Win32::EventLog;

use strict;
use vars qw($VERSION $AUTOLOAD @ISA @EXPORT $GetMessageText);
$VERSION = '0.074';

require Exporter;
require DynaLoader;

die "The Win32::Eventlog module works only on Windows NT"
	unless Win32::IsWinNT();

@ISA= qw(Exporter DynaLoader);
@EXPORT = qw(
	EVENTLOG_AUDIT_FAILURE
	EVENTLOG_AUDIT_SUCCESS
	EVENTLOG_BACKWARDS_READ
	EVENTLOG_END_ALL_PAIRED_EVENTS
	EVENTLOG_END_PAIRED_EVENT
	EVENTLOG_ERROR_TYPE
	EVENTLOG_FORWARDS_READ
	EVENTLOG_INFORMATION_TYPE
	EVENTLOG_PAIRED_EVENT_ACTIVE
	EVENTLOG_PAIRED_EVENT_INACTIVE
	EVENTLOG_SEEK_READ
	EVENTLOG_SEQUENTIAL_READ
	EVENTLOG_START_PAIRED_EVENT
	EVENTLOG_SUCCESS
	EVENTLOG_WARNING_TYPE
);

$GetMessageText=0;

sub AUTOLOAD {
    my($constname);
    ($constname = $AUTOLOAD) =~ s/.*:://;
    # reset $! to zero to reset any current errors.
    local $! = 0;
    my $val = constant($constname, @_ ? $_[0] : 0);
    if ($!) {
	if ($! =~ /Invalid/) {
	    $AutoLoader::AUTOLOAD = $AUTOLOAD;
	    goto &AutoLoader::AUTOLOAD;
	}
	else {
	    my ($pack,$file,$line) = caller;
	    die "Unknown Win32::EventLog macro $constname, at $file line $line.\n";
	}
    }
    eval "sub $AUTOLOAD { $val }";
    goto &$AUTOLOAD;
}

#
# new()
#
#   Win32::EventLog->new("source name", "ServerName");
#
sub new {
    die "usage: PACKAGE->new(SOURCENAME[, SERVERNAME])\n" unless @_ > 1;
    my ($class,$source,$server) = @_;
    my $handle;

    # Create new handle
    if ($source !~ /\\/) {
	OpenEventLog($handle, $server, $source);
    }
    else {
	OpenBackupEventLog($handle, $server, $source);
    }
    return bless {handle   => $handle,
                  Source   => $source,
                  Computer => $server} => $class;
}

sub DESTROY {shift->Close}

#
# Open (the rather braindead old way)
# A variable initialized to empty must be supplied as the first
# arg, followed by whatever new() takes
#
sub Open {
    $_[0] = Win32::EventLog->new($_[1],$_[2]);
}

sub OpenBackup {
    my ($class,$source,$server) = @_;
    OpenBackupEventLog(my $handle, $server, $source);
    return bless {handle   => $handle,
		  Source   => $source,
		  Computer => $server} => $class;
}

sub Backup {
    die " usage: OBJECT->Backup(FILENAME)\n" unless @_ == 2;
    my ($self,$file) = @_;
    return BackupEventLog($self->{handle}, $file);
}

sub Close {
    my $self = shift;
    CloseEventLog($self->{handle});
    $self->{handle} = 0;
}

# Read
# Note: the EventInfo arguement requires a hash reference.
sub Read {
    my $self = shift;

    die "usage: OBJECT->Read(FLAGS, RECORDOFFSET, HASHREF)\n" unless @_ == 3;

    my ($readflags,$recordoffset) = @_;
    # The following is stolen shamelessly from Wyt's tests for the registry.
    my $result = ReadEventLog($self->{handle}, $readflags, $recordoffset,
			      my $header, my $source, my $computer, my $sid,
			      my $data, my $strings);
    my ($length,
	$reserved,
	$recordnumber,
	$timegenerated,
	$timewritten,
	$eventid,
	$eventtype,
	$numstrings,
	$eventcategory,
	$reservedflags,
	$closingrecordnumber,
	$stringoffset,
	$usersidlength,
	$usersidoffset,
	$datalength,
	$dataoffset) = unpack('l6s4l6', $header);

    # make a hash out of the values returned from ReadEventLog.
    my %h = ( Source              => $source,
              Computer            => $computer,
              Length              => $datalength,
              Category            => $eventcategory,
              RecordNumber        => $recordnumber,
              TimeGenerated       => $timegenerated,
              Timewritten         => $timewritten,
              EventID             => $eventid,
              EventType           => $eventtype,
              ClosingRecordNumber => $closingrecordnumber,
              User                => $sid,
              Strings             => $strings,
              Data                => $data,
            );

    # get the text message here
    if ($result and $GetMessageText) {
	GetEventLogText($source, $eventid, $strings, $numstrings, my $message);
	$h{Message} = $message;
    }

    if (ref($_[2]) eq 'HASH') {
	%{$_[2]} = %h;		# this needed for Read(...,\%foo) case
    }
    else {
	$_[2] = \%h;
    }
    return $result;
}

sub GetMessageText {
    my $self = shift;
    local $^W;
    GetEventLogText($self->{Source},
		    $self->{EventID},
		    $self->{Strings},
		    $self->{Strings} =~ tr/\0/\0/,
		    my $message);

    $self->{Message} = $message;
    return $message;
}

sub Report {
    die "usage: OBJECT->Report( HASHREF )\n" unless @_ == 2;
    my ($self,$EventInfo) = @_;

    die "Win32::EventLog::Report requires a hash reference as arg 2\n"
	unless ref($EventInfo) eq "HASH";

    my $computer = $EventInfo->{Computer} ? $EventInfo->{Computer}
                                          : $self->{Computer};
    my $source   = exists($EventInfo->{Source}) ? $EventInfo->{Source}
                                                : $self->{Source};

    return WriteEventLog($computer, $source, $EventInfo->{EventType},
			 $EventInfo->{Category}, $EventInfo->{EventID}, 0,
			 $EventInfo->{Data}, split(/\0/, $EventInfo->{Strings}));

}

sub GetOldest {
    my $self = shift;
    die "usage: OBJECT->GetOldest( SCALAREF )\n" unless @_ == 1;
    return GetOldestEventLogRecord($self->{handle},$_[0]);
}

sub GetNumber {
    my $self = shift;
    die "usage: OBJECT->GetNumber( SCALARREF )\n" unless @_ == 1;
    return GetNumberOfEventLogRecords($self->{handle}, $_[0]);
}

sub Clear {
    my ($self,$file) = @_;
    die "usage: OBJECT->Clear( FILENAME )\n" unless @_ == 2;
    return ClearEventLog($self->{handle}, $file);
}

bootstrap Win32::EventLog;

1;
__END__

