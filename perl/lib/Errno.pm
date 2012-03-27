#
# This file is auto-generated. ***ANY*** changes here will be lost
#

package Errno;
our (@EXPORT_OK,%EXPORT_TAGS,@ISA,$VERSION,%errno,$AUTOLOAD);
use Exporter ();
use Config;
use strict;

"$Config{'archname'}-$Config{'osvers'}" eq
"MSWin32-x86-multi-thread-4.0" or
	die "Errno architecture (MSWin32-x86-multi-thread-4.0) does not match executable architecture ($Config{'archname'}-$Config{'osvers'})";

$VERSION = "1.09_00";
$VERSION = eval $VERSION;
@ISA = qw(Exporter);

@EXPORT_OK = qw(EROFS ESHUTDOWN EPROTONOSUPPORT ENFILE ENOLCK
	EADDRINUSE ECONNABORTED EBADF EDEADLK ENOTDIR EINVAL ENOTTY EXDEV
	ELOOP ECONNREFUSED EISCONN EFBIG ECONNRESET EPFNOSUPPORT ENOENT
	EDISCON EWOULDBLOCK EDOM EMSGSIZE EDESTADDRREQ ENOTSOCK EIO ENOSPC
	ENOBUFS EINPROGRESS ERANGE EADDRNOTAVAIL EAFNOSUPPORT ENOSYS EINTR
	EHOSTDOWN EREMOTE EILSEQ ENOMEM ENOTCONN ENETUNREACH EPIPE ESTALE
	EDQUOT EUSERS EOPNOTSUPP ESPIPE EALREADY EMFILE ENAMETOOLONG EACCES
	ENOEXEC EISDIR EPROCLIM EBUSY E2BIG EPERM EEXIST ETOOMANYREFS
	ESOCKTNOSUPPORT ETIMEDOUT ENXIO ESRCH ENODEV EFAULT EAGAIN EMLINK
	EDEADLOCK ENOPROTOOPT ECHILD ENETDOWN EHOSTUNREACH EPROTOTYPE
	ENETRESET ENOTEMPTY);

%EXPORT_TAGS = (
    POSIX => [qw(
	E2BIG EACCES EADDRINUSE EADDRNOTAVAIL EAFNOSUPPORT EAGAIN EALREADY
	EBADF EBUSY ECHILD ECONNABORTED ECONNREFUSED ECONNRESET EDEADLK
	EDESTADDRREQ EDOM EDQUOT EEXIST EFAULT EFBIG EHOSTDOWN EHOSTUNREACH
	EINPROGRESS EINTR EINVAL EIO EISCONN EISDIR ELOOP EMFILE EMLINK
	EMSGSIZE ENAMETOOLONG ENETDOWN ENETRESET ENETUNREACH ENFILE ENOBUFS
	ENODEV ENOENT ENOEXEC ENOLCK ENOMEM ENOPROTOOPT ENOSPC ENOSYS ENOTCONN
	ENOTDIR ENOTEMPTY ENOTSOCK ENOTTY ENXIO EOPNOTSUPP EPERM EPFNOSUPPORT
	EPIPE EPROCLIM EPROTONOSUPPORT EPROTOTYPE ERANGE EREMOTE EROFS
	ESHUTDOWN ESOCKTNOSUPPORT ESPIPE ESRCH ESTALE ETIMEDOUT ETOOMANYREFS
	EUSERS EWOULDBLOCK EXDEV
    )]
);

sub EPERM () { 1 }
sub ENOENT () { 2 }
sub ESRCH () { 3 }
sub EINTR () { 4 }
sub EIO () { 5 }
sub ENXIO () { 6 }
sub E2BIG () { 7 }
sub ENOEXEC () { 8 }
sub EBADF () { 9 }
sub ECHILD () { 10 }
sub EAGAIN () { 11 }
sub ENOMEM () { 12 }
sub EACCES () { 13 }
sub EFAULT () { 14 }
sub EBUSY () { 16 }
sub EEXIST () { 17 }
sub EXDEV () { 18 }
sub ENODEV () { 19 }
sub ENOTDIR () { 20 }
sub EISDIR () { 21 }
sub EINVAL () { 22 }
sub ENFILE () { 23 }
sub EMFILE () { 24 }
sub ENOTTY () { 25 }
sub EFBIG () { 27 }
sub ENOSPC () { 28 }
sub ESPIPE () { 29 }
sub EROFS () { 30 }
sub EMLINK () { 31 }
sub EPIPE () { 32 }
sub EDOM () { 33 }
sub ERANGE () { 34 }
sub EDEADLK () { 36 }
sub EDEADLOCK () { 36 }
sub ENAMETOOLONG () { 38 }
sub ENOLCK () { 39 }
sub ENOSYS () { 40 }
sub ENOTEMPTY () { 41 }
sub EILSEQ () { 42 }
sub EWOULDBLOCK () { 10035 }
sub EINPROGRESS () { 10036 }
sub EALREADY () { 10037 }
sub ENOTSOCK () { 10038 }
sub EDESTADDRREQ () { 10039 }
sub EMSGSIZE () { 10040 }
sub EPROTOTYPE () { 10041 }
sub ENOPROTOOPT () { 10042 }
sub EPROTONOSUPPORT () { 10043 }
sub ESOCKTNOSUPPORT () { 10044 }
sub EOPNOTSUPP () { 10045 }
sub EPFNOSUPPORT () { 10046 }
sub EAFNOSUPPORT () { 10047 }
sub EADDRINUSE () { 10048 }
sub EADDRNOTAVAIL () { 10049 }
sub ENETDOWN () { 10050 }
sub ENETUNREACH () { 10051 }
sub ENETRESET () { 10052 }
sub ECONNABORTED () { 10053 }
sub ECONNRESET () { 10054 }
sub ENOBUFS () { 10055 }
sub EISCONN () { 10056 }
sub ENOTCONN () { 10057 }
sub ESHUTDOWN () { 10058 }
sub ETOOMANYREFS () { 10059 }
sub ETIMEDOUT () { 10060 }
sub ECONNREFUSED () { 10061 }
sub ELOOP () { 10062 }
sub EHOSTDOWN () { 10064 }
sub EHOSTUNREACH () { 10065 }
sub EPROCLIM () { 10067 }
sub EUSERS () { 10068 }
sub EDQUOT () { 10069 }
sub ESTALE () { 10070 }
sub EREMOTE () { 10071 }
sub EDISCON () { 10101 }

sub TIEHASH { bless [] }

sub FETCH {
    my ($self, $errname) = @_;
    my $proto = prototype("Errno::$errname");
    my $errno = "";
    if (defined($proto) && $proto eq "") {
	no strict 'refs';
	$errno = &$errname;
        $errno = 0 unless $! == $errno;
    }
    return $errno;
}

sub STORE {
    require Carp;
    Carp::confess("ERRNO hash is read only!");
}

*CLEAR = \&STORE;
*DELETE = \&STORE;

sub NEXTKEY {
    my($k,$v);
    while(($k,$v) = each %Errno::) {
	my $proto = prototype("Errno::$k");
	last if (defined($proto) && $proto eq "");
    }
    $k
}

sub FIRSTKEY {
    my $s = scalar keys %Errno::;	# initialize iterator
    goto &NEXTKEY;
}

sub EXISTS {
    my ($self, $errname) = @_;
    my $proto = prototype($errname);
    defined($proto) && $proto eq "";
}

tie %!, __PACKAGE__;

1;
__END__

