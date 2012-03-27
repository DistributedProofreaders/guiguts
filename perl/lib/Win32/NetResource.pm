package Win32::NetResource;

require Exporter;
require DynaLoader;
require AutoLoader;

$VERSION = '0.053';

@ISA = qw(Exporter DynaLoader);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw(
    RESOURCEDISPLAYTYPE_DOMAIN
    RESOURCEDISPLAYTYPE_FILE
    RESOURCEDISPLAYTYPE_GENERIC
    RESOURCEDISPLAYTYPE_GROUP
    RESOURCEDISPLAYTYPE_SERVER
    RESOURCEDISPLAYTYPE_SHARE
    RESOURCEDISPLAYTYPE_TREE
    RESOURCETYPE_ANY
    RESOURCETYPE_DISK
    RESOURCETYPE_PRINT
    RESOURCETYPE_UNKNOWN
    RESOURCEUSAGE_CONNECTABLE
    RESOURCEUSAGE_CONTAINER
    RESOURCEUSAGE_RESERVED
    RESOURCE_CONNECTED
    RESOURCE_GLOBALNET
    RESOURCE_REMEMBERED
    STYPE_DISKTREE
    STYPE_PRINTQ
    STYPE_DEVICE
    STYPE_IPC
    STYPE_SPECIAL
    SHARE_NETNAME_PARMNUM
    SHARE_TYPE_PARMNUM
    SHARE_REMARK_PARMNUM
    SHARE_PERMISSIONS_PARMNUM
    SHARE_MAX_USES_PARMNUM
    SHARE_CURRENT_USES_PARMNUM
    SHARE_PATH_PARMNUM
    SHARE_PASSWD_PARMNUM
    SHARE_FILE_SD_PARMNUM
);

@EXPORT_OK = qw(
    GetSharedResources
    AddConnection
    CancelConnection
    WNetGetLastError
    GetError
    GetUNCName
    NetShareAdd
    NetShareCheck
    NetShareDel
    NetShareGetInfo
    NetShareSetInfo
);

sub AUTOLOAD {
    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.  If a constant is not found then control is passed
    # to the AUTOLOAD in AutoLoader.

    my($constname);
    ($constname = $AUTOLOAD) =~ s/.*:://;
    #reset $! to zero to reset any current errors.
    local $! = 0;
    my $val = constant($constname, @_ ? $_[0] : 0);
    if ($! != 0) {
        if ($! =~ /Invalid/) {
            $AutoLoader::AUTOLOAD = $AUTOLOAD;
            goto &AutoLoader::AUTOLOAD;
        }
        else {
            ($pack,$file,$line) = caller;
            die "Your vendor has not defined Win32::NetResource macro $constname, used at $file line $line.
";
        }
    }
    eval "sub $AUTOLOAD { $val }";
    goto &$AUTOLOAD;
}

sub AddConnection
{
    my $h = $_[0];
    die "AddConnection: HASH reference required" unless ref($h) eq "HASH";

    #
    # The last four items *must* not be deallocated until the
    # _AddConnection() completes (since the packed structure is
    # pointing into these values.
    #
    my $netres = pack( 'i4 p4', $h->{Scope},
    				$h->{Type},
				$h->{DisplayType},
				$h->{Usage},
				$h->{LocalName},
				$h->{RemoteName},
				$h->{Comment},
				$h->{Provider});
    _AddConnection($netres,$_[1],$_[2],$_[3]);
}

#use Data::Dumper;

sub GetSharedResources
{
    die "GetSharedResources: ARRAY reference required"
	if defined $_[0] and ref($_[0]) ne "ARRAY";

    my $aref = [];

    # Get the shared resources.

    my $ret;

    if (@_ > 2 and $_[2]) {
	my $netres = pack('i4 p4', @{$_[2]}{qw(Scope
					       Type
					       DisplayType
					       Usage
					       LocalName
					       RemoteName
					       Comment
					       Provider)});
	$ret = _GetSharedResources( $aref , $_[1], $netres );
    }
    else {
	$ret = _GetSharedResources( $aref , $_[1] );
    }
    
    # build the array of hashes in $_[0]
#   print Dumper($aref);    
    foreach ( @$aref ) {
	my %hash;
	@hash{'Scope',
	      'Type',
	      'DisplayType',
	      'Usage',
	      'LocalName',
	      'RemoteName',
	      'Comment',
	      'Provider'} = split /\001/, $_;
	push @{$_[0]}, \%hash;
    }

    $ret;
}

sub NetShareAdd
{
    my $shareinfo = _hash2SHARE( $_[0] );
    _NetShareAdd($shareinfo,$_[1], $_[2] || "");
}

sub NetShareGetInfo
{
    my ($netinfo,$val);
    $val = _NetShareGetInfo( $_[0],$netinfo,$_[2] || "");
    %{$_[1]} = %{_SHARE2hash( $netinfo )};    
    $val;
}

sub NetShareSetInfo
{
    my $shareinfo = _hash2SHARE( $_[1] );
    _NetShareSetInfo( $_[0],$shareinfo,$_[2],$_[3] || "");
}


# These are private functions to work with the ShareInfo structure.
# please note that the implementation of these calls requires the
# SHARE_INFO_502 level of information.

sub _SHARE2hash
{
    my %hash = ();
    @hash{'type',
          'permissions',
          'maxusers',
          'current-users',
          'remark',
          'netname',
          'path',
          'passwd'} = unpack('i4 A257 A81 A257 A257',$_[0]);

    return \%hash;
}

sub _hash2SHARE
{
    my $h = $_[0];
    die "Argument must be a HASH reference" unless ref($h) eq "HASH";

    return pack 'i4 a257 a81 a257 a257',
		 @$h{'type',
		    'permissions',
		    'maxusers',
		    'current-users',
		    'remark',
		    'netname',
		    'path',
		    'passwd'};
}


bootstrap Win32::NetResource;

1;
__END__
