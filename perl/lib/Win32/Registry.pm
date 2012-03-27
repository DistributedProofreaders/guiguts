package Win32::Registry;

use strict;
require Exporter;
require DynaLoader;
use Win32::WinError;

use vars qw($VERSION $AUTOLOAD @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION = '0.07';

@ISA	= qw( Exporter DynaLoader );
@EXPORT = qw(
	HKEY_CLASSES_ROOT
	HKEY_CURRENT_USER
	HKEY_LOCAL_MACHINE
	HKEY_PERFORMANCE_DATA
	HKEY_CURRENT_CONFIG
	HKEY_DYN_DATA
	HKEY_USERS
	KEY_ALL_ACCESS
	KEY_CREATE_LINK
	KEY_CREATE_SUB_KEY
	KEY_ENUMERATE_SUB_KEYS
	KEY_EXECUTE
	KEY_NOTIFY
	KEY_QUERY_VALUE
	KEY_READ
	KEY_SET_VALUE
	KEY_WRITE
	REG_BINARY
	REG_CREATED_NEW_KEY
	REG_DWORD
	REG_DWORD_BIG_ENDIAN
	REG_DWORD_LITTLE_ENDIAN
	REG_EXPAND_SZ
	REG_FULL_RESOURCE_DESCRIPTOR
	REG_LEGAL_CHANGE_FILTER
	REG_LEGAL_OPTION
	REG_LINK
	REG_MULTI_SZ
	REG_NONE
	REG_NOTIFY_CHANGE_ATTRIBUTES
	REG_NOTIFY_CHANGE_LAST_SET
	REG_NOTIFY_CHANGE_NAME
	REG_NOTIFY_CHANGE_SECURITY
	REG_OPENED_EXISTING_KEY
	REG_OPTION_BACKUP_RESTORE
	REG_OPTION_CREATE_LINK
	REG_OPTION_NON_VOLATILE
	REG_OPTION_RESERVED
	REG_OPTION_VOLATILE
	REG_REFRESH_HIVE
	REG_RESOURCE_LIST
	REG_RESOURCE_REQUIREMENTS_LIST
	REG_SZ
	REG_WHOLE_HIVE_VOLATILE
);

@EXPORT_OK = qw(
    RegCloseKey
    RegConnectRegistry
    RegCreateKey
    RegCreateKeyEx
    RegDeleteKey
    RegDeleteValue
    RegEnumKey
    RegEnumValue
    RegFlushKey
    RegGetKeySecurity
    RegLoadKey
    RegNotifyChangeKeyValue
    RegOpenKey
    RegOpenKeyEx
    RegQueryInfoKey
    RegQueryValue
    RegQueryValueEx
    RegReplaceKey
    RegRestoreKey
    RegSaveKey
    RegSetKeySecurity
    RegSetValue
    RegSetValueEx
    RegUnLoadKey
);
$EXPORT_TAGS{ALL}= \@EXPORT_OK;

bootstrap Win32::Registry;

sub import {
    my $pkg = shift;
    if ($_[0] && "Win32" eq $_[0]) {
	Exporter::export($pkg, "Win32", @EXPORT_OK);
	shift;
    }
    Win32::Registry->export_to_level(1+$Exporter::ExportLevel, $pkg, @_);
}

#######################################################################
# This AUTOLOAD is used to 'autoload' constants from the constant()
# XS function.  If a constant is not found then control is passed
# to the AUTOLOAD in AutoLoader.

sub AUTOLOAD {
    my($constname);
    ($constname = $AUTOLOAD) =~ s/.*:://;
    #reset $! to zero to reset any current errors.
    local $! = 0;
    my $val = constant($constname, 0);
    if ($! != 0) {
	if ($! =~ /Invalid/) {
	    $AutoLoader::AUTOLOAD = $AUTOLOAD;
	    goto &AutoLoader::AUTOLOAD;
	}
	else {
	    my ($pack,$file,$line) = caller;
	    die "Unknown constant $constname in Win32::Registry "
	       . "at $file line $line.\n";
	}
    }
    eval "sub $AUTOLOAD { $val }";
    goto &$AUTOLOAD;
}

#######################################################################
# _new is a private constructor, not intended for public use.
#

sub _new {
    my $self;
    if ($_[0]) {
	$self->{'handle'} = $_[0];
	bless $self;
    }
    $self;
}

#define the basic registry objects to be exported.
#these had to be hardwired unfortunately.
# XXX Yuck!

{
    package main;
    use vars qw(
		$HKEY_CLASSES_ROOT
		$HKEY_CURRENT_USER
		$HKEY_LOCAL_MACHINE
		$HKEY_USERS
		$HKEY_PERFORMANCE_DATA
		$HKEY_CURRENT_CONFIG
		$HKEY_DYN_DATA
	       );
}

$::HKEY_CLASSES_ROOT		= _new(&HKEY_CLASSES_ROOT);
$::HKEY_CURRENT_USER		= _new(&HKEY_CURRENT_USER);
$::HKEY_LOCAL_MACHINE		= _new(&HKEY_LOCAL_MACHINE);
$::HKEY_USERS			= _new(&HKEY_USERS);
$::HKEY_PERFORMANCE_DATA	= _new(&HKEY_PERFORMANCE_DATA);
$::HKEY_CURRENT_CONFIG		= _new(&HKEY_CURRENT_CONFIG);
$::HKEY_DYN_DATA		= _new(&HKEY_DYN_DATA);

sub Open {
    my $self = shift;
    die 'usage: $obj->Open($sub_key_name, $sub_reg_obj)' if @_ != 2;
    
    my ($subkey) = @_;
    my ($result,$subhandle);

    $result = RegOpenKey($self->{'handle'},$subkey,$subhandle);
    $_[1] = _new($subhandle);
    
    return 0 unless $_[1];
    $! = Win32::GetLastError() unless $result;
    return $result;
}

sub Close {
    my $self = shift;
    die 'usage: $obj->Close()' if @_ != 0;

    return unless exists $self->{'handle'};
    my $result = RegCloseKey($self->{'handle'});
    if ($result) {
	delete $self->{'handle'};
    }
    else {
	$! = Win32::GetLastError();
    }
    return $result;
}

sub DESTROY {
    my $self = shift;
    return unless exists $self->{'handle'};
    RegCloseKey($self->{'handle'});
    delete $self->{'handle'};
}


sub Connect {
    my $self = shift;
    die 'usage: $obj->Connect($node_name, $new_reg_obj)' if @_ != 2;
     
    my ($node) = @_;
    my ($result,$subhandle);

    $result = RegConnectRegistry ($node, $self->{'handle'}, $subhandle);
    $_[1] = _new($subhandle);

    return 0 unless $_[1];
    $! = Win32::GetLastError() unless $result;
    return $result;
}  

sub Create {
    my $self = shift;
    die 'usage: $obj->Create($sub_key_name, $new_reg_obj)' if @_ != 2;

    my ($subkey) = @_;
    my ($result,$subhandle);

    $result = RegCreateKey($self->{'handle'},$subkey,$subhandle);
    $_[1] = _new ($subhandle);

    return 0 unless $_[1];
    $! = Win32::GetLastError() unless $result;
    return $result;
}

sub SetValue {
    my $self = shift;
    die 'usage: $obj->SetValue($subkey, $type, $value)' if @_ != 3;
    my $result = RegSetValue($self->{'handle'}, @_);
    $! = Win32::GetLastError() unless $result;
    return $result;
}

sub SetValueEx {
    my $self = shift;
    die 'usage: $obj->SetValueEx($value_name, $reserved, $type, $value)' if @_ != 4;
    my $result = RegSetValueEx($self->{'handle'}, @_);
    $! = Win32::GetLastError() unless $result;
    return $result;
}

sub QueryValue {
    my $self = shift;
    die 'usage: $obj->QueryValue($sub_key_name, $value)' if @_ != 2;
    my $result = RegQueryValue($self->{'handle'}, $_[0], $_[1]);
    $! = Win32::GetLastError() unless $result;
    return $result;
}

sub QueryKey {
    my $garbage;
    my $self = shift;
    die 'usage: $obj->QueryKey($classref, $number_of_subkeys, $number_of_values)'
    	if @_ != 3;

    my $result = RegQueryInfoKey($self->{'handle'}, $_[0],
    				 $garbage, $garbage, $_[1],
			         $garbage, $garbage, $_[2],
			         $garbage, $garbage, $garbage, $garbage);

    $! = Win32::GetLastError() unless $result;
    return $result;
}

sub QueryValueEx {
    my $self = shift;
    die 'usage: $obj->QueryValueEx($value_name, $type, $value)' if @_ != 3;
    my $result = RegQueryValueEx($self->{'handle'}, $_[0], undef, $_[1], $_[2]);
    $! = Win32::GetLastError() unless $result;
    return $result;
}

sub GetKeys {
    my $self = shift;
    die 'usage: $obj->GetKeys($arrayref)' if @_ != 1 or ref($_[0]) ne 'ARRAY';

    my ($result, $i, $keyname);
    $keyname = "DummyVal";
    $i = 0;
    $result = 1;
    
    while ( $result ) {
	$result = RegEnumKey( $self->{'handle'},$i++, $keyname );
	if ($result) {
	    push( @{$_[0]}, $keyname );
	}
    }
    return(1);
}

sub GetValues {
    my $self = shift;
    die 'usage: $obj->GetValues($hashref)' if @_ != 1;

    my ($result,$name,$type,$data,$i);
    $name = "DummyVal";
    $i = 0;
    while ( $result=RegEnumValue( $self->{'handle'},
				  $i++,
				  $name,
				  undef,
				  $type,
				  $data ))
    {
	$_[0]->{$name} = [ $name, $type, $data ];
    }
    return(1);
}

sub DeleteKey {
    my $self = shift;
    die 'usage: $obj->DeleteKey($sub_key_name)' if @_ != 1;
    my $result = RegDeleteKey($self->{'handle'}, @_);
    $! = Win32::GetLastError() unless $result;
    return $result;
}

sub DeleteValue {
    my $self = shift;
    die 'usage: $obj->DeleteValue($value_name)' if @_ != 1;
    my $result = RegDeleteValue($self->{'handle'}, @_);
    $! = Win32::GetLastError() unless $result;
    return $result;
}

sub Save {
    my $self = shift;
    die 'usage: $obj->Save($filename)' if @_ != 1;
    my $result = RegSaveKey($self->{'handle'}, @_);
    $! = Win32::GetLastError() unless $result;
    return $result;
}

sub Load {
    my $self = shift;
    die 'usage: $obj->Load($sub_key_name, $file_name)' if @_ != 2;
    my $result = RegLoadKey($self->{'handle'}, @_);
    $! = Win32::GetLastError() unless $result;
    return $result;
}

sub UnLoad {
    my $self = shift;
    die 'usage: $obj->UnLoad($sub_key_name)' if @_ != 1;
    my $result = RegUnLoadKey($self->{'handle'}, @_);
    $! = Win32::GetLastError() unless $result;
    return $result;
}

1;
__END__
