package Win32::NetAdmin;

#
#NetAdmin.pm
#Written by Douglas_Lankshear@ActiveWare.com
#

$VERSION = '0.08';

require Exporter;
require DynaLoader;

die "The Win32::NetAdmin module works only on Windows NT" if(!Win32::IsWinNT() );

@ISA= qw( Exporter DynaLoader );
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw(
	DOMAIN_ALIAS_RID_ACCOUNT_OPS
	DOMAIN_ALIAS_RID_ADMINS
	DOMAIN_ALIAS_RID_BACKUP_OPS
	DOMAIN_ALIAS_RID_GUESTS
	DOMAIN_ALIAS_RID_POWER_USERS
	DOMAIN_ALIAS_RID_PRINT_OPS
	DOMAIN_ALIAS_RID_REPLICATOR
	DOMAIN_ALIAS_RID_SYSTEM_OPS
	DOMAIN_ALIAS_RID_USERS
	DOMAIN_GROUP_RID_ADMINS
	DOMAIN_GROUP_RID_GUESTS
	DOMAIN_GROUP_RID_USERS
	DOMAIN_USER_RID_ADMIN
	DOMAIN_USER_RID_GUEST
	FILTER_TEMP_DUPLICATE_ACCOUNT
	FILTER_NORMAL_ACCOUNT
	FILTER_INTERDOMAIN_TRUST_ACCOUNT
	FILTER_WORKSTATION_TRUST_ACCOUNT
	FILTER_SERVER_TRUST_ACCOUNT
	SV_TYPE_WORKSTATION
	SV_TYPE_SERVER
	SV_TYPE_SQLSERVER
	SV_TYPE_DOMAIN_CTRL
	SV_TYPE_DOMAIN_BAKCTRL
	SV_TYPE_TIMESOURCE
	SV_TYPE_AFP
	SV_TYPE_NOVELL
	SV_TYPE_DOMAIN_MEMBER
	SV_TYPE_PRINT
	SV_TYPE_PRINTQ_SERVER
	SV_TYPE_DIALIN
	SV_TYPE_DIALIN_SERVER
	SV_TYPE_XENIX_SERVER
	SV_TYPE_NT
	SV_TYPE_WFW
	SV_TYPE_POTENTIAL_BROWSER
	SV_TYPE_BACKUP_BROWSER
	SV_TYPE_MASTER_BROWSER
	SV_TYPE_DOMAIN_MASTER
	SV_TYPE_DOMAIN_ENUM
	SV_TYPE_SERVER_UNIX
	SV_TYPE_SERVER_MFPN
	SV_TYPE_SERVER_NT
	SV_TYPE_SERVER_OSF
	SV_TYPE_SERVER_VMS
	SV_TYPE_WINDOWS
	SV_TYPE_DFS
	SV_TYPE_ALTERNATE_XPORT
	SV_TYPE_LOCAL_LIST_ONLY
	SV_TYPE_ALL
	UF_TEMP_DUPLICATE_ACCOUNT
	UF_NORMAL_ACCOUNT
	UF_INTERDOMAIN_TRUST_ACCOUNT
	UF_WORKSTATION_TRUST_ACCOUNT
	UF_SERVER_TRUST_ACCOUNT
	UF_MACHINE_ACCOUNT_MASK
	UF_ACCOUNT_TYPE_MASK
	UF_DONT_EXPIRE_PASSWD
	UF_SETTABLE_BITS
	UF_SCRIPT
	UF_ACCOUNTDISABLE
	UF_HOMEDIR_REQUIRED
	UF_LOCKOUT
	UF_PASSWD_NOTREQD
	UF_PASSWD_CANT_CHANGE
	USE_FORCE
	USE_LOTS_OF_FORCE
	USE_NOFORCE
	USER_PRIV_MASK
	USER_PRIV_GUEST
	USER_PRIV_USER
	USER_PRIV_ADMIN
);

@EXPORT_OK = qw(
    GetError
    GetDomainController
    GetAnyDomainController
    UserCreate
    UserDelete
    UserGetAttributes
    UserSetAttributes
    UserChangePassword
    UsersExist
    GetUsers
    GroupCreate
    GroupDelete
    GroupGetAttributes
    GroupSetAttributes
    GroupAddUsers
    GroupDeleteUsers
    GroupIsMember
    GroupGetMembers
    LocalGroupCreate
    LocalGroupDelete
    LocalGroupGetAttributes
    LocalGroupSetAttributes
    LocalGroupIsMember
    LocalGroupGetMembers
    LocalGroupGetMembersWithDomain
    LocalGroupAddUsers
    LocalGroupDeleteUsers
    GetServers
    GetTransports
    LoggedOnUsers
    GetAliasFromRID
    GetUserGroupFromRID
    GetServerDisks
);
$EXPORT_TAGS{ALL}= \@EXPORT_OK;

sub AUTOLOAD {
    my($constname);
    ($constname = $AUTOLOAD) =~ s/.*:://;
    #reset $! to zero to reset any current errors.
    local $! = 0;
    my $val = constant($constname);
    if ($! != 0) {
	if ($! =~ /Invalid/) {
	    $AutoLoader::AUTOLOAD = $AUTOLOAD;
	    goto &AutoLoader::AUTOLOAD;
	}
	else {
	    ($pack,$file,$line) = caller;
	    die "Your vendor has not defined Win32::NetAdmin macro $constname, used in $file at line $line.";
	}
    }
    eval "sub $AUTOLOAD { $val }";
    goto &$AUTOLOAD;
}

$SidTypeUser = 1;
$SidTypeGroup = 2;
$SidTypeDomain = 3;
$SidTypeAlias = 4;
$SidTypeWellKnownGroup = 5;
$SidTypeDeletedAccount = 6;
$SidTypeInvalid = 7;
$SidTypeUnknown = 8;

sub GetError() {
    our $__lastError;
    $__lastError;
}

bootstrap Win32::NetAdmin;

1;
__END__

