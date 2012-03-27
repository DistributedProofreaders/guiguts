# File.pm -- Low-level access to Win32 file/dir functions/constants.

package Win32API::File;

use strict;
use Carp;
use Fcntl qw( O_RDONLY O_RDWR O_WRONLY O_APPEND O_BINARY O_TEXT );
use vars qw( $VERSION @ISA );
use vars qw( @EXPORT @EXPORT_OK @EXPORT_FAIL %EXPORT_TAGS );
$VERSION= '0.09';

use base qw( Exporter DynaLoader );

@EXPORT= qw();
%EXPORT_TAGS= (
    Func =>	[qw(		attrLetsToBits		createFile
    	fileConstant		fileLastError		getLogicalDrives
	CloseHandle		CopyFile		CreateFile
	DefineDosDevice		DeleteFile		DeviceIoControl
	FdGetOsFHandle		GetDriveType		GetFileType
	GetHandleInformation	GetLogicalDrives	GetLogicalDriveStrings
	GetOsFHandle		GetVolumeInformation	IsRecognizedPartition
	IsContainerPartition	MoveFile		MoveFileEx
	OsFHandleOpen		OsFHandleOpenFd		QueryDosDevice
	ReadFile		SetErrorMode		SetFilePointer
	SetHandleInformation	WriteFile )],
    FuncA =>	[qw(
	CopyFileA		CreateFileA		DefineDosDeviceA
	DeleteFileA		GetDriveTypeA		GetLogicalDriveStringsA
	GetVolumeInformationA	MoveFileA		MoveFileExA
	QueryDosDeviceA )],
    FuncW =>	[qw(
	CopyFileW		CreateFileW		DefineDosDeviceW
	DeleteFileW		GetDriveTypeW		GetLogicalDriveStringsW
	GetVolumeInformationW	MoveFileW		MoveFileExW
	QueryDosDeviceW )],
    Misc =>		[qw(
	CREATE_ALWAYS		CREATE_NEW		FILE_BEGIN
	FILE_CURRENT		FILE_END		INVALID_HANDLE_VALUE
	OPEN_ALWAYS		OPEN_EXISTING		TRUNCATE_EXISTING )],
    DDD_ =>	[qw(
	DDD_EXACT_MATCH_ON_REMOVE			DDD_RAW_TARGET_PATH
	DDD_REMOVE_DEFINITION )],
    DRIVE_ =>	[qw(
	DRIVE_UNKNOWN		DRIVE_NO_ROOT_DIR	DRIVE_REMOVABLE
	DRIVE_FIXED		DRIVE_REMOTE		DRIVE_CDROM
	DRIVE_RAMDISK )],
    FILE_ =>	[qw(
	FILE_READ_DATA			FILE_LIST_DIRECTORY
	FILE_WRITE_DATA			FILE_ADD_FILE
	FILE_APPEND_DATA		FILE_ADD_SUBDIRECTORY
	FILE_CREATE_PIPE_INSTANCE	FILE_READ_EA
	FILE_WRITE_EA			FILE_EXECUTE
	FILE_TRAVERSE			FILE_DELETE_CHILD
	FILE_READ_ATTRIBUTES		FILE_WRITE_ATTRIBUTES
	FILE_ALL_ACCESS			FILE_GENERIC_READ
	FILE_GENERIC_WRITE		FILE_GENERIC_EXECUTE )],
    FILE_ATTRIBUTE_ =>	[qw(
	FILE_ATTRIBUTE_ARCHIVE		FILE_ATTRIBUTE_COMPRESSED
	FILE_ATTRIBUTE_HIDDEN		FILE_ATTRIBUTE_NORMAL
	FILE_ATTRIBUTE_OFFLINE		FILE_ATTRIBUTE_READONLY
	FILE_ATTRIBUTE_SYSTEM		FILE_ATTRIBUTE_TEMPORARY )],
    FILE_FLAG_ =>	[qw(
	FILE_FLAG_BACKUP_SEMANTICS	FILE_FLAG_DELETE_ON_CLOSE
	FILE_FLAG_NO_BUFFERING		FILE_FLAG_OVERLAPPED
	FILE_FLAG_POSIX_SEMANTICS	FILE_FLAG_RANDOM_ACCESS
	FILE_FLAG_SEQUENTIAL_SCAN	FILE_FLAG_WRITE_THROUGH )],
    FILE_SHARE_ =>	[qw(
	FILE_SHARE_DELETE	FILE_SHARE_READ		FILE_SHARE_WRITE )],
    FILE_TYPE_ =>	[qw(
	FILE_TYPE_CHAR		FILE_TYPE_DISK		FILE_TYPE_PIPE
	FILE_TYPE_UNKNOWN )],
    FS_ =>	[qw(
	FS_CASE_IS_PRESERVED		FS_CASE_SENSITIVE
	FS_UNICODE_STORED_ON_DISK	FS_PERSISTENT_ACLS 
	FS_FILE_COMPRESSION		FS_VOL_IS_COMPRESSED )],
    HANDLE_FLAG_ =>	[qw(
	HANDLE_FLAG_INHERIT		HANDLE_FLAG_PROTECT_FROM_CLOSE )],
    IOCTL_STORAGE_ =>	[qw(
	IOCTL_STORAGE_CHECK_VERIFY	IOCTL_STORAGE_MEDIA_REMOVAL
	IOCTL_STORAGE_EJECT_MEDIA	IOCTL_STORAGE_LOAD_MEDIA
	IOCTL_STORAGE_RESERVE		IOCTL_STORAGE_RELEASE
	IOCTL_STORAGE_FIND_NEW_DEVICES	IOCTL_STORAGE_GET_MEDIA_TYPES
	)],
    IOCTL_DISK_ =>	[qw(
	IOCTL_DISK_FORMAT_TRACKS	IOCTL_DISK_FORMAT_TRACKS_EX
	IOCTL_DISK_GET_DRIVE_GEOMETRY	IOCTL_DISK_GET_DRIVE_LAYOUT
	IOCTL_DISK_GET_MEDIA_TYPES	IOCTL_DISK_GET_PARTITION_INFO
	IOCTL_DISK_HISTOGRAM_DATA	IOCTL_DISK_HISTOGRAM_RESET
	IOCTL_DISK_HISTOGRAM_STRUCTURE	IOCTL_DISK_IS_WRITABLE
	IOCTL_DISK_LOGGING		IOCTL_DISK_PERFORMANCE
	IOCTL_DISK_REASSIGN_BLOCKS	IOCTL_DISK_REQUEST_DATA
	IOCTL_DISK_REQUEST_STRUCTURE	IOCTL_DISK_SET_DRIVE_LAYOUT
	IOCTL_DISK_SET_PARTITION_INFO	IOCTL_DISK_VERIFY )],
    GENERIC_ =>		[qw(
	GENERIC_ALL			GENERIC_EXECUTE
	GENERIC_READ			GENERIC_WRITE )],
    MEDIA_TYPE =>	[qw(
	Unknown			F5_1Pt2_512		F3_1Pt44_512
	F3_2Pt88_512		F3_20Pt8_512		F3_720_512
	F5_360_512		F5_320_512		F5_320_1024
	F5_180_512		F5_160_512		RemovableMedia
	FixedMedia		F3_120M_512 )],
    MOVEFILE_ =>	[qw(
	MOVEFILE_COPY_ALLOWED		MOVEFILE_DELAY_UNTIL_REBOOT
	MOVEFILE_REPLACE_EXISTING	MOVEFILE_WRITE_THROUGH )],
    SECURITY_ =>	[qw(
	SECURITY_ANONYMOUS		SECURITY_CONTEXT_TRACKING
	SECURITY_DELEGATION		SECURITY_EFFECTIVE_ONLY
	SECURITY_IDENTIFICATION		SECURITY_IMPERSONATION
	SECURITY_SQOS_PRESENT )],
    SEM_ =>		[qw(
	SEM_FAILCRITICALERRORS		SEM_NOGPFAULTERRORBOX
	SEM_NOALIGNMENTFAULTEXCEPT	SEM_NOOPENFILEERRORBOX )],
    PARTITION_ =>	[qw(
	PARTITION_ENTRY_UNUSED		PARTITION_FAT_12
	PARTITION_XENIX_1		PARTITION_XENIX_2
	PARTITION_FAT_16		PARTITION_EXTENDED
	PARTITION_HUGE			PARTITION_IFS
	PARTITION_FAT32			PARTITION_FAT32_XINT13
	PARTITION_XINT13		PARTITION_XINT13_EXTENDED
	PARTITION_PREP			PARTITION_UNIX
	VALID_NTFT			PARTITION_NTFT )],
);
@EXPORT_OK= ();
{
    my $key;
    foreach $key (  keys(%EXPORT_TAGS)  ) {
	push( @EXPORT_OK, @{$EXPORT_TAGS{$key}} );
	#push( @EXPORT_FAIL, @{$EXPORT_TAGS{$key}} )   unless  $key =~ /^Func/;
    }
}
$EXPORT_TAGS{ALL}= \@EXPORT_OK;

bootstrap Win32API::File $VERSION;

# Preloaded methods go here.

# To convert C constants to Perl code in cFile.pc
# [instead of C or C++ code in cFile.h]:
#    * Modify F<Makefile.PL> to add WriteMakeFile() =>
#      CONST2PERL/postamble => [[ "Win32API::File" => ]] WRITE_PERL => 1.
#    * Either comment out C<#include "cFile.h"> from F<File.xs>
#      or make F<cFile.h> an empty file.
#    * Make sure the following C<if> block is not commented out.
#    * "nmake clean", "perl Makefile.PL", "nmake"

if(  ! defined &GENERIC_READ  ) {
    require "Win32API/File/cFile.pc";
}

sub fileConstant
{
    my( $name )= @_;
    if(  1 != @_  ||  ! $name  ||  $name =~ /\W/  ) {
	require Carp;
	Carp::croak( 'Usage: ',__PACKAGE__,'::fileConstant("CONST_NAME")' );
    }
    my $proto= prototype $name;
    if(  defined \&$name
     &&  defined $proto
     &&  "" eq $proto  ) {
	no strict 'refs';
	return &$name;
    }
    return undef;
}

# We provide this for backwards compatibility:
sub constant
{
    my( $name )= @_;
    my $value= fileConstant( $name );
    if(  defined $value  ) {
	$!= 0;
	return $value;
    }
    $!= 11; # EINVAL
    return 0;
}

BEGIN {
    my $code= 'return _fileLastError(@_)';
    local( $!, $^E )= ( 1, 1 );
    if(  $! ne $^E  ) {
	$code= '
	    local( $^E )= _fileLastError(@_);
	    my $ret= $^E;
	    return $ret;
	';
    }
    eval "sub fileLastError { $code }";
    die "$@"   if  $@;
}

# Since we ISA DynaLoader which ISA AutoLoader, we ISA AutoLoader so we
# need this next chunk to prevent Win32API::File->nonesuch() from
# looking for "nonesuch.al" and producing confusing error messages:
use vars qw($AUTOLOAD);
sub AUTOLOAD {
    require Carp;
    Carp::croak(
      "Can't locate method $AUTOLOAD via package Win32API::File" );
}

# Replace "&rout;" with "goto &rout;" when that is supported on Win32.

# Aliases for non-Unicode functions:
sub CopyFile			{ &CopyFileA; }
sub CreateFile			{ &CreateFileA; }
sub DefineDosDevice		{ &DefineDosDeviceA; }
sub DeleteFile			{ &DeleteFileA; }
sub GetDriveType		{ &GetDriveTypeA; }
sub GetLogicalDriveStrings	{ &GetLogicalDriveStringsA; }
sub GetVolumeInformation	{ &GetVolumeInformationA; }
sub MoveFile			{ &MoveFileA; }
sub MoveFileEx			{ &MoveFileExA; }
sub QueryDosDevice		{ &QueryDosDeviceA; }

sub OsFHandleOpen {
    if(  3 != @_  ) {
	croak 'Win32API::File Usage:  ',
	      'OsFHandleOpen(FILE,$hNativeHandle,"rwatb")';
    }
    my( $fh, $osfh, $access )= @_;
    if(  ! ref($fh)  ) {
	if(  $fh !~ /('|::)/  ) {
	    $fh= caller() . "::" . $fh;
	}
	no strict "refs";
	$fh= \*{$fh};
    }
    my( $mode, $pref );
    if(  $access =~ /r/i  ) {
	if(  $access =~ /w/i  ) {
	    $mode= O_RDWR;
	    $pref= "+<";
	} else {
	    $mode= O_RDONLY;
	    $pref= "<";
	}
    } else {
	if(  $access =~ /w/i  ) {
	    $mode= O_WRONLY;
	    $pref= ">";
	} else {
	#   croak qq<Win32API::File::OsFHandleOpen():  >,
	#	  qq<Access ($access) missing both "r" and "w">;
	    $mode= O_RDONLY;
	    $pref= "<";
	}
    }
    $mode |= O_APPEND   if  $access =~ /a/i;
    #$mode |= O_TEXT   if  $access =~ /t/i;
    # Some versions of the Fcntl module are broken and won't autoload O_TEXT:
    if(  $access =~ /t/i  ) {
	my $o_text= eval "O_TEXT";
	$o_text= 0x4000   if  $@;
	$mode |= $o_text;
    }
    $mode |= O_BINARY   if  $access =~ /b/i;
    my $fd= OsFHandleOpenFd( $osfh, $mode );
    return  undef   if  $fd < 0;
    return  open( $fh, $pref."&=".$fd );
}

sub GetOsFHandle {
    if(  1 != @_  ) {
	croak 'Win32API::File Usage:  $OsFHandle= GetOsFHandle(FILE)';
    }
    my( $file )= @_;
    if(  ! ref($file)  ) {
	if(  $file !~ /('|::)/  ) {
	    $file= caller() . "::" . $file;
	}
	no strict "refs";
	$file= \*{$file};
    }
    my( $fd )= fileno($file);
    if(  ! defined( $fd )  ) {
	if(  $file =~ /^\d+\Z/  ) {
	    $fd= $file;
	} else {
	    return ();	# $! should be set by fileno().
	}
    }
    my $h= FdGetOsFHandle( $fd );
    if(  INVALID_HANDLE_VALUE() == $h  ) {
	$h= "";
    } elsif(  "0" eq $h  ) {
	$h= "0 but true";
    }
    return $h;
}

sub attrLetsToBits
{
    my( $lets )= @_;
    my( %a )= (
      "a"=>FILE_ATTRIBUTE_ARCHIVE(),	"c"=>FILE_ATTRIBUTE_COMPRESSED(),
      "h"=>FILE_ATTRIBUTE_HIDDEN(),	"o"=>FILE_ATTRIBUTE_OFFLINE(),
      "r"=>FILE_ATTRIBUTE_READONLY(),	"s"=>FILE_ATTRIBUTE_SYSTEM(),
      "t"=>FILE_ATTRIBUTE_TEMPORARY() );
    my( $bits )= 0;
    foreach(  split(//,$lets)  ) {
	croak "Win32API::File::attrLetsToBits: Unknown attribute letter ($_)"
	  unless  exists $a{$_};
	$bits |= $a{$_};
    }
    return $bits;
}

use vars qw( @_createFile_Opts %_createFile_Opts );
@_createFile_Opts= qw( Access Create Share Attributes
		       Flags Security Model );
@_createFile_Opts{@_createFile_Opts}= (1) x @_createFile_Opts;

sub createFile
{
    my $opts= "";
    if(  2 <= @_  &&  "HASH" eq ref($_[$#_])  ) {
	$opts= pop( @_ );
    }
    my( $sPath, $svAccess, $svShare )= @_;
    if(  @_ < 1  ||  3 < @_  ) {
	croak "Win32API::File::createFile() usage:  \$hObject= createFile(\n",
	      "  \$sPath, [\$svAccess_qrw_ktn_ce,[\$svShare_rwd,]]",
	      " [{Option=>\$Value}] )\n",
	      "    options: @_createFile_Opts\nCalled";
    }
    my( $create, $flags, $sec, $model )= ( "", 0, [], 0 );
    if(  ref($opts)  ) {
        my @err= grep( ! $_createFile_Opts{$_}, keys(%$opts) );
	@err  and  croak "_createFile:  Invalid options (@err)";
	$flags= $opts->{Flags}		if  exists( $opts->{Flags} );
	$flags |= attrLetsToBits( $opts->{Attributes} )
					if  exists( $opts->{Attributes} );
	$sec= $opts->{Security}		if  exists( $opts->{Security} );
	$model= $opts->{Model}		if  exists( $opts->{Model} );
	$svAccess= $opts->{Access}	if  exists( $opts->{Access} );
	$create= $opts->{Create}	if  exists( $opts->{Create} );
	$svShare= $opts->{Share}	if  exists( $opts->{Share} );
    }
    $svAccess= "r"		unless  defined($svAccess);
    $svShare= "rw"		unless  defined($svShare);
    if(  $svAccess =~ /^[qrw ktn ce]*$/i  ) {
	( my $c= $svAccess ) =~ tr/qrw QRW//d;
	$create= $c   if  "" ne $c  &&  "" eq $create;
	local( $_ )= $svAccess;
	$svAccess= 0;
	$svAccess |= GENERIC_READ()   if  /r/i;
	$svAccess |= GENERIC_WRITE()   if  /w/i;
    } elsif(  "?" eq $svAccess  ) {
	croak
	  "Win32API::File::createFile:  \$svAccess can use the following:\n",
	      "    One or more of the following:\n",
	      "\tq -- Query access (same as 0)\n",
	      "\tr -- Read access (GENERIC_READ)\n",
	      "\tw -- Write access (GENERIC_WRITE)\n",
	      "    At most one of the following:\n",
	      "\tk -- Keep if exists\n",
	      "\tt -- Truncate if exists\n",
	      "\tn -- New file only (fail if file already exists)\n",
	      "    At most one of the following:\n",
	      "\tc -- Create if doesn't exist\n",
	      "\te -- Existing file only (fail if doesn't exist)\n",
	      "  ''   is the same as 'q  k e'\n",
	      "  'r'  is the same as 'r  k e'\n",
	      "  'w'  is the same as 'w  t c'\n",
	      "  'rw' is the same as 'rw k c'\n",
	      "  'rt' or 'rn' implies 'c'.\n",
	      "  Or \$svAccess can be numeric.\n", "Called from";
    } elsif(  $svAccess == 0  &&  $svAccess !~ /^[-+.]*0/  ) {
	croak "Win32API::File::createFile:  Invalid \$svAccess ($svAccess)";
    }
    if(  $create =~ /^[ktn ce]*$/  ) {
        local( $_ )= $create;
        my( $k, $t, $n, $c, $e )= ( scalar(/k/i), scalar(/t/i),
	  scalar(/n/i), scalar(/c/i), scalar(/e/i) );
	if(  1 < $k + $t + $n  ) {
	    croak "Win32API::File::createFile: \$create must not use ",
	      qq<more than one of "k", "t", and "n" ($create)>;
	}
	if(  $c  &&  $e  ) {
	    croak "Win32API::File::createFile: \$create must not use ",
	      qq<both "c" and "e" ($create)>;
	}
	my $r= ( $svAccess & GENERIC_READ() ) == GENERIC_READ();
	my $w= ( $svAccess & GENERIC_WRITE() ) == GENERIC_WRITE();
	if(  ! $k  &&  ! $t  &&  ! $n  ) {
	    if(  $w  &&  ! $r  ) {		$t= 1;
	    } else {				$k= 1; }
	}
	if(  $k  ) {
	    if(  $c  ||  $w && ! $e  ) {	$create= OPEN_ALWAYS();
	    } else {				$create= OPEN_EXISTING(); }
	} elsif(  $t  ) {
	    if(  $e  ) {			$create= TRUNCATE_EXISTING();
	    } else {				$create= CREATE_ALWAYS(); }
	} else { # $n
	    if(  ! $e  ) {			$create= CREATE_NEW();
	    } else {
		croak "Win32API::File::createFile: \$create must not use ",
		  qq<both "n" and "e" ($create)>;
	    }
	}
    } elsif(  "?" eq $create  ) {
	croak 'Win32API::File::createFile: $create !~ /^[ktn ce]*$/;',
	      ' pass $svAccess as "?" for more information.';
    } elsif(  $create == 0  &&  $create ne "0"  ) {
	croak "Win32API::File::createFile: Invalid \$create ($create)";
    }
    if(  $svShare =~ /^[drw]*$/  ) {
        my %s= ( "d"=>FILE_SHARE_DELETE(), "r"=>FILE_SHARE_READ(),
	         "w"=>FILE_SHARE_WRITE() );
        my @s= split(//,$svShare);
	$svShare= 0;
	foreach( @s ) {
	    $svShare |= $s{$_};
	}
    } elsif(  $svShare == 0  &&  $svShare !~ /^[-+.]*0/  ) {
	croak "Win32API::File::createFile: Invalid \$svShare ($svShare)";
    }
    return  CreateFileA(
	      $sPath, $svAccess, $svShare, $sec, $create, $flags, $model );
}


sub getLogicalDrives
{
    my( $ref )= @_;
    my $s= "";
    if(  ! GetLogicalDriveStringsA( 256, $s )  ) {
	return undef;
    }
    if(  ! defined($ref)  ) {
	return  split( /\0/, $s );
    } elsif(  "ARRAY" ne ref($ref)  ) {
	croak 'Usage:  C<@arr= getLogicalDrives()> ',
	      'or C<getLogicalDrives(\\@arr)>', "\n";
    }
    @$ref= split( /\0/, $s );
    return $ref;
}

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__

