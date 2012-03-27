package Win32API::Net;

use strict;
use Carp;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $AUTOLOAD);

require Exporter;
require DynaLoader;

@ISA = qw(Exporter DynaLoader);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw();	# don't pollute callees namespace

%EXPORT_TAGS=(
    User => [ qw(
        FILTER_INTERDOMAIN_TRUST_ACCOUNT FILTER_NORMAL_ACCOUNT
        FILTER_SERVER_TRUST_ACCOUNT FILTER_TEMP_DUPLICATE_ACCOUNTS
        FILTER_WORKSTATION_TRUST_ACCOUNT
        USER_ACCT_EXPIRES_PARMNUM USER_AUTH_FLAGS_PARMNUM
        USER_CODE_PAGE_PARMNUM USER_COMMENT_PARMNUM USER_COUNTRY_CODE_PARMNUM
        USER_FLAGS_PARMNUM USER_FULL_NAME_PARMNUM USER_HOME_DIR_DRIVE_PARMNUM
        USER_HOME_DIR_PARMNUM USER_LAST_LOGOFF_PARMNUM USER_LAST_LOGON_PARMNUM
        USER_LOGON_HOURS_PARMNUM USER_LOGON_SERVER_PARMNUM
        USER_MAX_STORAGE_PARMNUM USER_NAME_PARMNUM USER_NUM_LOGONS_PARMNUM
        USER_PAD_PW_COUNT_PARMNUM USER_PARMS_PARMNUM USER_PASSWORD_AGE_PARMNUM
        USER_PASSWORD_PARMNUM USER_PRIMARY_GROUP_PARMNUM USER_PRIV_ADMIN
        USER_PRIV_GUEST USER_PRIV_MASK USER_PRIV_PARMNUM USER_PRIV_USER
        USER_PROFILE_PARMNUM USER_PROFILE_PARMNUM USER_SCRIPT_PATH_PARMNUM
        USER_UNITS_PER_WEEK_PARMNUM USER_USR_COMMENT_PARMNUM
        USER_WORKSTATIONS_PARMNUM USER_BAD_PW_COUNT_PARMNUM LG_INCLUDE_INDIRECT
        UF_ACCOUNTDISABLE UF_ACCOUNT_TYPE_MASK UF_DONT_EXPIRE_PASSWD
        UF_HOMEDIR_REQUIRED UF_INTERDOMAIN_TRUST_ACCOUNT UF_LOCKOUT
        UF_MACHINE_ACCOUNT_MASK UF_NORMAL_ACCOUNT UF_PASSWD_CANT_CHANGE
        UF_PASSWD_NOTREQD UF_SCRIPT UF_SERVER_TRUST_ACCOUNT UF_SETTABLE_BITS
        UF_TEMP_DUPLICATE_ACCOUNT UF_WORKSTATION_TRUST_ACCOUNT
        UserAdd UserChangePassword UserDel UserEnum UserGetGroups UserGetInfo 
        UserGetLocalGroups UserModalsGet UserModalsSet UserSetGroups
        UserSetInfo
    )],
    Get => [ qw(
        GetDCName
    )],
    Group => [ qw(
        GROUP_ATTRIBUTES_PARMNUM GROUP_COMMENT_PARMNUM GROUP_NAME_PARMNUM
        GroupAdd GroupAddUser GroupDel GroupDelUser GroupEnum GroupGetInfo 
        GroupGetUsers GroupSetInfo GroupSetUsers 
    )],
    LocalGroup => [ qw(
        LOCALGROUP_COMMENT_PARMNUM LOCALGROUP_NAME_PARMNUM
        LocalGroupAdd LocalGroupAddMember LocalGroupAddMembers LocalGroupDel 
        LocalGroupDelMember LocalGroupDelMembers LocalGroupEnum 
        LocalGroupGetInfo LocalGroupGetMembers LocalGroupSetInfo 
        LocalGroupSetMembers 
    )],
);

@EXPORT_OK= ();
{ my $ref;
    foreach $ref (  values(%EXPORT_TAGS)  ) {
        push( @EXPORT_OK, @$ref );
    }
}
$EXPORT_TAGS{ALL}= \@EXPORT_OK;

$VERSION = '0.09';

sub AUTOLOAD {
    my $constname;
    ($constname = $AUTOLOAD) =~ s/.*:://;
    local $! = 0;
    my $val = constant($constname, @_ ? $_[0] : 0);
    if ($! != 0) {
	if ($! =~ /Invalid/) {
	    $AutoLoader::AUTOLOAD = $AUTOLOAD;
	    goto &AutoLoader::AUTOLOAD;
	}
	else {
		croak "Your vendor has not defined Win32API::Net macro $constname";
	}
    }
    eval "sub $AUTOLOAD { $val }";
    goto &$AUTOLOAD;
}

bootstrap Win32API::Net $VERSION;

1;
__END__

