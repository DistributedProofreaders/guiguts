package Net::Ping;

require 5.002;
require Exporter;

use strict;
use vars qw(@ISA @EXPORT $VERSION
            $def_timeout $def_proto $def_factor
            $max_datasize $pingstring $hires $source_verify $syn_forking);
use Fcntl qw( F_GETFL F_SETFL O_NONBLOCK );
use Socket qw( SOCK_DGRAM SOCK_STREAM SOCK_RAW PF_INET SOL_SOCKET SO_ERROR
               inet_aton inet_ntoa sockaddr_in );
use POSIX qw( ENOTCONN ECONNREFUSED ECONNRESET EINPROGRESS EWOULDBLOCK EAGAIN WNOHANG );
use FileHandle;
use Carp;

@ISA = qw(Exporter);
@EXPORT = qw(pingecho);
$VERSION = "2.31";

sub SOL_IP { 0; };
sub IP_TOS { 1; };

# Constants

$def_timeout = 5;           # Default timeout to wait for a reply
$def_proto = "tcp";         # Default protocol to use for pinging
$def_factor = 1.2;          # Default exponential backoff rate.
$max_datasize = 1024;       # Maximum data bytes in a packet
# The data we exchange with the server for the stream protocol
$pingstring = "pingschwingping!\n";
$source_verify = 1;         # Default is to verify source endpoint
$syn_forking = 0;

if ($^O =~ /Win32/i) {
  # Hack to avoid this Win32 spewage:
  # Your vendor has not defined POSIX macro ECONNREFUSED
  *ECONNREFUSED = sub {10061;}; # "Unknown Error" Special Win32 Response?
  *ENOTCONN     = sub {10057;};
  *ECONNRESET   = sub {10054;};
  *EINPROGRESS  = sub {10036;};
  *EWOULDBLOCK  = sub {10035;};
#  $syn_forking = 1;    # XXX possibly useful in < Win2K ?
};

# h2ph "asm/socket.h"
# require "asm/socket.ph";
sub SO_BINDTODEVICE {25;}

# Description:  The pingecho() subroutine is provided for backward
# compatibility with the original Net::Ping.  It accepts a host
# name/IP and an optional timeout in seconds.  Create a tcp ping
# object and try pinging the host.  The result of the ping is returned.

sub pingecho
{
  my ($host,              # Name or IP number of host to ping
      $timeout            # Optional timeout in seconds
      ) = @_;
  my ($p);                # A ping object

  $p = Net::Ping->new("tcp", $timeout);
  $p->ping($host);        # Going out of scope closes the connection
}

# Description:  The new() method creates a new ping object.  Optional
# parameters may be specified for the protocol to use, the timeout in
# seconds and the size in bytes of additional data which should be
# included in the packet.
#   After the optional parameters are checked, the data is constructed
# and a socket is opened if appropriate.  The object is returned.

sub new
{
  my ($this,
      $proto,             # Optional protocol to use for pinging
      $timeout,           # Optional timeout in seconds
      $data_size,         # Optional additional bytes of data
      $device,            # Optional device to use
      $tos,               # Optional ToS to set
      ) = @_;
  my  $class = ref($this) || $this;
  my  $self = {};
  my ($cnt,               # Count through data bytes
      $min_datasize       # Minimum data bytes required
      );

  bless($self, $class);

  $proto = $def_proto unless $proto;          # Determine the protocol
  croak('Protocol for ping must be "icmp", "udp", "tcp", "syn", "stream", or "external"')
    unless $proto =~ m/^(icmp|udp|tcp|syn|stream|external)$/;
  $self->{"proto"} = $proto;

  $timeout = $def_timeout unless $timeout;    # Determine the timeout
  croak("Default timeout for ping must be greater than 0 seconds")
    if $timeout <= 0;
  $self->{"timeout"} = $timeout;

  $self->{"device"} = $device;

  $self->{"tos"} = $tos;

  $min_datasize = ($proto eq "udp") ? 1 : 0;  # Determine data size
  $data_size = $min_datasize unless defined($data_size) && $proto ne "tcp";
  croak("Data for ping must be from $min_datasize to $max_datasize bytes")
    if ($data_size < $min_datasize) || ($data_size > $max_datasize);
  $data_size-- if $self->{"proto"} eq "udp";  # We provide the first byte
  $self->{"data_size"} = $data_size;

  $self->{"data"} = "";                       # Construct data bytes
  for ($cnt = 0; $cnt < $self->{"data_size"}; $cnt++)
  {
    $self->{"data"} .= chr($cnt % 256);
  }

  $self->{"local_addr"} = undef;              # Don't bind by default
  $self->{"retrans"} = $def_factor;           # Default exponential backoff rate
  $self->{"econnrefused"} = undef;            # Default Connection refused behavior

  $self->{"seq"} = 0;                         # For counting packets
  if ($self->{"proto"} eq "udp")              # Open a socket
  {
    $self->{"proto_num"} = (getprotobyname('udp'))[2] ||
      croak("Can't udp protocol by name");
    $self->{"port_num"} = (getservbyname('echo', 'udp'))[2] ||
      croak("Can't get udp echo port by name");
    $self->{"fh"} = FileHandle->new();
    socket($self->{"fh"}, PF_INET, SOCK_DGRAM,
           $self->{"proto_num"}) ||
             croak("udp socket error - $!");
    if ($self->{'device'}) {
      setsockopt($self->{"fh"}, SOL_SOCKET, SO_BINDTODEVICE(), pack("Z*", $self->{'device'}))
        or croak "error binding to device $self->{'device'} $!";
    }
    if ($self->{'tos'}) {
      setsockopt($self->{"fh"}, SOL_IP, IP_TOS(), pack("I*", $self->{'tos'}))
        or croak "error configuring tos to $self->{'tos'} $!";
    }
  }
  elsif ($self->{"proto"} eq "icmp")
  {
    croak("icmp ping requires root privilege") if ($> and $^O ne 'VMS' and $^O ne 'cygwin');
    $self->{"proto_num"} = (getprotobyname('icmp'))[2] ||
      croak("Can't get icmp protocol by name");
    $self->{"pid"} = $$ & 0xffff;           # Save lower 16 bits of pid
    $self->{"fh"} = FileHandle->new();
    socket($self->{"fh"}, PF_INET, SOCK_RAW, $self->{"proto_num"}) ||
      croak("icmp socket error - $!");
    if ($self->{'device'}) {
      setsockopt($self->{"fh"}, SOL_SOCKET, SO_BINDTODEVICE(), pack("Z*", $self->{'device'}))
        or croak "error binding to device $self->{'device'} $!";
    }
    if ($self->{'tos'}) {
      setsockopt($self->{"fh"}, SOL_IP, IP_TOS(), pack("I*", $self->{'tos'}))
        or croak "error configuring tos to $self->{'tos'} $!";
    }
  }
  elsif ($self->{"proto"} eq "tcp" || $self->{"proto"} eq "stream")
  {
    $self->{"proto_num"} = (getprotobyname('tcp'))[2] ||
      croak("Can't get tcp protocol by name");
    $self->{"port_num"} = (getservbyname('echo', 'tcp'))[2] ||
      croak("Can't get tcp echo port by name");
    $self->{"fh"} = FileHandle->new();
  }
  elsif ($self->{"proto"} eq "syn")
  {
    $self->{"proto_num"} = (getprotobyname('tcp'))[2] ||
      croak("Can't get tcp protocol by name");
    $self->{"port_num"} = (getservbyname('echo', 'tcp'))[2] ||
      croak("Can't get tcp echo port by name");
    if ($syn_forking) {
      $self->{"fork_rd"} = FileHandle->new();
      $self->{"fork_wr"} = FileHandle->new();
      pipe($self->{"fork_rd"}, $self->{"fork_wr"});
      $self->{"fh"} = FileHandle->new();
      $self->{"good"} = {};
      $self->{"bad"} = {};
    } else {
      $self->{"wbits"} = "";
      $self->{"bad"} = {};
    }
    $self->{"syn"} = {};
    $self->{"stop_time"} = 0;
  }
  elsif ($self->{"proto"} eq "external")
  {
    # No preliminary work needs to be done.
  }

  return($self);
}

# Description: Set the local IP address from which pings will be sent.
# For ICMP and UDP pings, this calls bind() on the already-opened socket;
# for TCP pings, just saves the address to be used when the socket is
# opened.  Returns non-zero if successful; croaks on error.
sub bind
{
  my ($self,
      $local_addr         # Name or IP number of local interface
      ) = @_;
  my ($ip                 # Packed IP number of $local_addr
      );

  croak("Usage: \$p->bind(\$local_addr)") unless @_ == 2;
  croak("already bound") if defined($self->{"local_addr"}) &&
    ($self->{"proto"} eq "udp" || $self->{"proto"} eq "icmp");

  $ip = inet_aton($local_addr);
  croak("nonexistent local address $local_addr") unless defined($ip);
  $self->{"local_addr"} = $ip; # Only used if proto is tcp

  if ($self->{"proto"} eq "udp" || $self->{"proto"} eq "icmp")
  {
  CORE::bind($self->{"fh"}, sockaddr_in(0, $ip)) ||
    croak("$self->{'proto'} bind error - $!");
  }
  elsif (($self->{"proto"} ne "tcp") && ($self->{"proto"} ne "syn"))
  {
    croak("Unknown protocol \"$self->{proto}\" in bind()");
  }

  return 1;
}

# Description: A select() wrapper that compensates for platform
# peculiarities.
sub mselect
{
    if ($_[3] > 0 and $^O eq 'MSWin32') {
	# On windows, select() doesn't process the message loop,
	# but sleep() will, allowing alarm() to interrupt the latter.
	# So we chop up the timeout into smaller pieces and interleave
	# select() and sleep() calls.
	my $t = $_[3];
	my $gran = 0.5;  # polling granularity in seconds
	my @args = @_;
	while (1) {
	    $gran = $t if $gran > $t;
	    my $nfound = select($_[0], $_[1], $_[2], $gran);
	    $t -= $gran;
	    return $nfound if $nfound or !defined($nfound) or $t <= 0;

	    sleep(0);
	    ($_[0], $_[1], $_[2]) = @args;
	}
    }
    else {
	return select($_[0], $_[1], $_[2], $_[3]);
    }
}

# Description: Allow UDP source endpoint comparision to be
#              skipped for those remote interfaces that do
#              not response from the same endpoint.

sub source_verify
{
  my $self = shift;
  $source_verify = 1 unless defined
    ($source_verify = ((defined $self) && (ref $self)) ? shift() : $self);
}

# Description: Set whether or not the connect
# behavior should enforce remote service
# availability as well as reachability.

sub service_check
{
  my $self = shift;
  $self->{"econnrefused"} = 1 unless defined
    ($self->{"econnrefused"} = shift());
}

sub tcp_service_check
{
  service_check(@_);
}

# Description: Set exponential backoff for retransmission.
# Should be > 1 to retain exponential properties.
# If set to 0, retransmissions are disabled.

sub retrans
{
  my $self = shift;
  $self->{"retrans"} = shift;
}

# Description: allows the module to use milliseconds as returned by
# the Time::HiRes module

$hires = 0;
sub hires
{
  my $self = shift;
  $hires = 1 unless defined
    ($hires = ((defined $self) && (ref $self)) ? shift() : $self);
  require Time::HiRes if $hires;
}

sub time
{
  return $hires ? Time::HiRes::time() : CORE::time();
}

# Description: Sets or clears the O_NONBLOCK flag on a file handle.
sub socket_blocking_mode
{
  my ($self,
      $fh,              # the file handle whose flags are to be modified
      $block) = @_;     # if true then set the blocking
                        # mode (clear O_NONBLOCK), otherwise
                        # set the non-blocking mode (set O_NONBLOCK)

  my $flags;
  if ($^O eq 'MSWin32' || $^O eq 'VMS') {
      # FIONBIO enables non-blocking sockets on windows and vms.
      # FIONBIO is (0x80000000|(4<<16)|(ord('f')<<8)|126), as per winsock.h, ioctl.h
      my $f = 0x8004667e;
      my $v = pack("L", $block ? 0 : 1);
      ioctl($fh, $f, $v) or croak("ioctl failed: $!");
      return;
  }
  if ($flags = fcntl($fh, F_GETFL, 0)) {
    $flags = $block ? ($flags & ~O_NONBLOCK) : ($flags | O_NONBLOCK);
    if (!fcntl($fh, F_SETFL, $flags)) {
      croak("fcntl F_SETFL: $!");
    }
  } else {
    croak("fcntl F_GETFL: $!");
  }
}

# Description: Ping a host name or IP number with an optional timeout.
# First lookup the host, and return undef if it is not found.  Otherwise
# perform the specific ping method based on the protocol.  Return the
# result of the ping.

sub ping
{
  my ($self,
      $host,              # Name or IP number of host to ping
      $timeout,           # Seconds after which ping times out
      ) = @_;
  my ($ip,                # Packed IP number of $host
      $ret,               # The return value
      $ping_time,         # When ping began
      );

  croak("Usage: \$p->ping(\$host [, \$timeout])") unless @_ == 2 || @_ == 3;
  $timeout = $self->{"timeout"} unless $timeout;
  croak("Timeout must be greater than 0 seconds") if $timeout <= 0;

  $ip = inet_aton($host);
  return () unless defined($ip);      # Does host exist?

  # Dispatch to the appropriate routine.
  $ping_time = &time();
  if ($self->{"proto"} eq "external") {
    $ret = $self->ping_external($ip, $timeout);
  }
  elsif ($self->{"proto"} eq "udp") {
    $ret = $self->ping_udp($ip, $timeout);
  }
  elsif ($self->{"proto"} eq "icmp") {
    $ret = $self->ping_icmp($ip, $timeout);
  }
  elsif ($self->{"proto"} eq "tcp") {
    $ret = $self->ping_tcp($ip, $timeout);
  }
  elsif ($self->{"proto"} eq "stream") {
    $ret = $self->ping_stream($ip, $timeout);
  }
  elsif ($self->{"proto"} eq "syn") {
    $ret = $self->ping_syn($host, $ip, $ping_time, $ping_time+$timeout);
  } else {
    croak("Unknown protocol \"$self->{proto}\" in ping()");
  }

  return wantarray ? ($ret, &time() - $ping_time, inet_ntoa($ip)) : $ret;
}

# Uses Net::Ping::External to do an external ping.
sub ping_external {
  my ($self,
      $ip,                # Packed IP number of the host
      $timeout            # Seconds after which ping times out
     ) = @_;

  eval { require Net::Ping::External; }
    or croak('Protocol "external" not supported on your system: Net::Ping::External not found');
  return Net::Ping::External::ping(ip => $ip, timeout => $timeout);
}

use constant ICMP_ECHOREPLY => 0; # ICMP packet types
use constant ICMP_ECHO      => 8;
use constant ICMP_STRUCT    => "C2 n3 A";  # Structure of a minimal ICMP packet
use constant SUBCODE        => 0; # No ICMP subcode for ECHO and ECHOREPLY
use constant ICMP_FLAGS     => 0; # No special flags for send or recv
use constant ICMP_PORT      => 0; # No port with ICMP

sub ping_icmp
{
  my ($self,
      $ip,                # Packed IP number of the host
      $timeout            # Seconds after which ping times out
      ) = @_;

  my ($saddr,             # sockaddr_in with port and ip
      $checksum,          # Checksum of ICMP packet
      $msg,               # ICMP packet to send
      $len_msg,           # Length of $msg
      $rbits,             # Read bits, filehandles for reading
      $nfound,            # Number of ready filehandles found
      $finish_time,       # Time ping should be finished
      $done,              # set to 1 when we are done
      $ret,               # Return value
      $recv_msg,          # Received message including IP header
      $from_saddr,        # sockaddr_in of sender
      $from_port,         # Port packet was sent from
      $from_ip,           # Packed IP of sender
      $from_type,         # ICMP type
      $from_subcode,      # ICMP subcode
      $from_chk,          # ICMP packet checksum
      $from_pid,          # ICMP packet id
      $from_seq,          # ICMP packet sequence
      $from_msg           # ICMP message
      );

  $self->{"seq"} = ($self->{"seq"} + 1) % 65536; # Increment sequence
  $checksum = 0;                          # No checksum for starters
  $msg = pack(ICMP_STRUCT . $self->{"data_size"}, ICMP_ECHO, SUBCODE,
              $checksum, $self->{"pid"}, $self->{"seq"}, $self->{"data"});
  $checksum = Net::Ping->checksum($msg);
  $msg = pack(ICMP_STRUCT . $self->{"data_size"}, ICMP_ECHO, SUBCODE,
              $checksum, $self->{"pid"}, $self->{"seq"}, $self->{"data"});
  $len_msg = length($msg);
  $saddr = sockaddr_in(ICMP_PORT, $ip);
  $self->{"from_ip"} = undef;
  $self->{"from_type"} = undef;
  $self->{"from_subcode"} = undef;
  send($self->{"fh"}, $msg, ICMP_FLAGS, $saddr); # Send the message

  $rbits = "";
  vec($rbits, $self->{"fh"}->fileno(), 1) = 1;
  $ret = 0;
  $done = 0;
  $finish_time = &time() + $timeout;      # Must be done by this time
  while (!$done && $timeout > 0)          # Keep trying if we have time
  {
    $nfound = mselect((my $rout=$rbits), undef, undef, $timeout); # Wait for packet
    $timeout = $finish_time - &time();    # Get remaining time
    if (!defined($nfound))                # Hmm, a strange error
    {
      $ret = undef;
      $done = 1;
    }
    elsif ($nfound)                     # Got a packet from somewhere
    {
      $recv_msg = "";
      $from_pid = -1;
      $from_seq = -1;
      $from_saddr = recv($self->{"fh"}, $recv_msg, 1500, ICMP_FLAGS);
      ($from_port, $from_ip) = sockaddr_in($from_saddr);
      ($from_type, $from_subcode) = unpack("C2", substr($recv_msg, 20, 2));
      if ($from_type == ICMP_ECHOREPLY) {
        ($from_pid, $from_seq) = unpack("n3", substr($recv_msg, 24, 4))
          if length $recv_msg >= 28;
      } else {
        ($from_pid, $from_seq) = unpack("n3", substr($recv_msg, 52, 4))
          if length $recv_msg >= 56;
      }
      $self->{"from_ip"} = $from_ip;
      $self->{"from_type"} = $from_type;
      $self->{"from_subcode"} = $from_subcode;
      if (($from_pid == $self->{"pid"}) && # Does the packet check out?
          ($from_seq == $self->{"seq"})) {
        if ($from_type == ICMP_ECHOREPLY){
          $ret = 1;
        }
        $done = 1;
      }
    } else {     # Oops, timed out
      $done = 1;
    }
  }
  return $ret;
}

sub icmp_result {
  my ($self) = @_;
  my $ip = $self->{"from_ip"} || "";
  $ip = "\0\0\0\0" unless 4 == length $ip;
  return (inet_ntoa($ip),($self->{"from_type"} || 0), ($self->{"from_subcode"} || 0));
}

# Description:  Do a checksum on the message.  Basically sum all of
# the short words and fold the high order bits into the low order bits.

sub checksum
{
  my ($class,
      $msg            # The message to checksum
      ) = @_;
  my ($len_msg,       # Length of the message
      $num_short,     # The number of short words in the message
      $short,         # One short word
      $chk            # The checksum
      );

  $len_msg = length($msg);
  $num_short = int($len_msg / 2);
  $chk = 0;
  foreach $short (unpack("n$num_short", $msg))
  {
    $chk += $short;
  }                                           # Add the odd byte in
  $chk += (unpack("C", substr($msg, $len_msg - 1, 1)) << 8) if $len_msg % 2;
  $chk = ($chk >> 16) + ($chk & 0xffff);      # Fold high into low
  return(~(($chk >> 16) + $chk) & 0xffff);    # Again and complement
}


# Description:  Perform a tcp echo ping.  Since a tcp connection is
# host specific, we have to open and close each connection here.  We
# can't just leave a socket open.  Because of the robust nature of
# tcp, it will take a while before it gives up trying to establish a
# connection.  Therefore, we use select() on a non-blocking socket to
# check against our timeout.  No data bytes are actually
# sent since the successful establishment of a connection is proof
# enough of the reachability of the remote host.  Also, tcp is
# expensive and doesn't need our help to add to the overhead.

sub ping_tcp
{
  my ($self,
      $ip,                # Packed IP number of the host
      $timeout            # Seconds after which ping times out
      ) = @_;
  my ($ret                # The return value
      );

  $! = 0;
  $ret = $self -> tcp_connect( $ip, $timeout);
  if (!$self->{"econnrefused"} &&
      $! == ECONNREFUSED) {
    $ret = 1;  # "Connection refused" means reachable
  }
  $self->{"fh"}->close();
  return $ret;
}

sub tcp_connect
{
  my ($self,
      $ip,                # Packed IP number of the host
      $timeout            # Seconds after which connect times out
      ) = @_;
  my ($saddr);            # Packed IP and Port

  $saddr = sockaddr_in($self->{"port_num"}, $ip);

  my $ret = 0;            # Default to unreachable

  my $do_socket = sub {
    socket($self->{"fh"}, PF_INET, SOCK_STREAM, $self->{"proto_num"}) ||
      croak("tcp socket error - $!");
    if (defined $self->{"local_addr"} &&
        !CORE::bind($self->{"fh"}, sockaddr_in(0, $self->{"local_addr"}))) {
      croak("tcp bind error - $!");
    }
    if ($self->{'device'}) {
      setsockopt($self->{"fh"}, SOL_SOCKET, SO_BINDTODEVICE(), pack("Z*", $self->{'device'}))
        or croak("error binding to device $self->{'device'} $!");
    }
    if ($self->{'tos'}) {
      setsockopt($self->{"fh"}, SOL_IP, IP_TOS(), pack("I*", $self->{'tos'}))
        or croak "error configuring tos to $self->{'tos'} $!";
    }
  };
  my $do_connect = sub {
    $self->{"ip"} = $ip;
    # ECONNREFUSED is 10061 on MSWin32. If we pass it as child error through $?,
    # we'll get (10061 & 255) = 77, so we cannot check it in the parent process.
    return ($ret = connect($self->{"fh"}, $saddr) || ($! == ECONNREFUSED && !$self->{"econnrefused"}));
  };
  my $do_connect_nb = sub {
    # Set O_NONBLOCK property on filehandle
    $self->socket_blocking_mode($self->{"fh"}, 0);

    # start the connection attempt
    if (!connect($self->{"fh"}, $saddr)) {
      if ($! == ECONNREFUSED) {
        $ret = 1 unless $self->{"econnrefused"};
      } elsif ($! != EINPROGRESS && ($^O ne 'MSWin32' || $! != EWOULDBLOCK)) {
        # EINPROGRESS is the expected error code after a connect()
        # on a non-blocking socket.  But if the kernel immediately
        # determined that this connect() will never work,
        # Simply respond with "unreachable" status.
        # (This can occur on some platforms with errno
        # EHOSTUNREACH or ENETUNREACH.)
        return 0;
      } else {
        # Got the expected EINPROGRESS.
        # Just wait for connection completion...
        my ($wbits, $wout, $wexc);
        $wout = $wexc = $wbits = "";
        vec($wbits, $self->{"fh"}->fileno, 1) = 1;

        my $nfound = mselect(undef,
			    ($wout = $wbits),
			    ($^O eq 'MSWin32' ? ($wexc = $wbits) : undef),
			    $timeout);
        warn("select: $!") unless defined $nfound;

        if ($nfound && vec($wout, $self->{"fh"}->fileno, 1)) {
          # the socket is ready for writing so the connection
          # attempt completed. test whether the connection
          # attempt was successful or not

          if (getpeername($self->{"fh"})) {
            # Connection established to remote host
            $ret = 1;
          } else {
            # TCP ACK will never come from this host
            # because there was an error connecting.

            # This should set $! to the correct error.
            my $char;
            sysread($self->{"fh"},$char,1);
            $! = ECONNREFUSED if ($! == EAGAIN && $^O =~ /cygwin/i);

            $ret = 1 if (!$self->{"econnrefused"}
                         && $! == ECONNREFUSED);
          }
        } else {
          # the connection attempt timed out (or there were connect
	  # errors on Windows)
	  if ($^O =~ 'MSWin32') {
	      # If the connect will fail on a non-blocking socket,
	      # winsock reports ECONNREFUSED as an exception, and we
	      # need to fetch the socket-level error code via getsockopt()
	      # instead of using the thread-level error code that is in $!.
	      if ($nfound && vec($wexc, $self->{"fh"}->fileno, 1)) {
		  $! = unpack("i", getsockopt($self->{"fh"}, SOL_SOCKET,
			                      SO_ERROR));
	      }
	  }
        }
      }
    } else {
      # Connection established to remote host
      $ret = 1;
    }

    # Unset O_NONBLOCK property on filehandle
    $self->socket_blocking_mode($self->{"fh"}, 1);
    $self->{"ip"} = $ip;
    return $ret;
  };

  if ($syn_forking) {
    # Buggy Winsock API doesn't allow nonblocking connect.
    # Hence, if our OS is Windows, we need to create a separate
    # process to do the blocking connect attempt.
    # XXX Above comments are not true at least for Win2K, where
    # nonblocking connect works.

    $| = 1; # Clear buffer prior to fork to prevent duplicate flushing.
    $self->{'tcp_chld'} = fork;
    if (!$self->{'tcp_chld'}) {
      if (!defined $self->{'tcp_chld'}) {
        # Fork did not work
        warn "Fork error: $!";
        return 0;
      }
      &{ $do_socket }();

      # Try a slow blocking connect() call
      # and report the status to the parent.
      if ( &{ $do_connect }() ) {
        $self->{"fh"}->close();
        # No error
        exit 0;
      } else {
        # Pass the error status to the parent
        # Make sure that $! <= 255
        exit($! <= 255 ? $! : 255);
      }
    }

    &{ $do_socket }();

    my $patience = &time() + $timeout;

    my ($child, $child_errno);
    $? = 0; $child_errno = 0;
    # Wait up to the timeout
    # And clean off the zombie
    do {
      $child = waitpid($self->{'tcp_chld'}, &WNOHANG());
      $child_errno = $? >> 8;
      select(undef, undef, undef, 0.1);
    } while &time() < $patience && $child != $self->{'tcp_chld'};

    if ($child == $self->{'tcp_chld'}) {
      if ($self->{"proto"} eq "stream") {
        # We need the socket connected here, in parent
        # Should be safe to connect because the child finished
        # within the timeout
        &{ $do_connect }();
      }
      # $ret cannot be set by the child process
      $ret = !$child_errno;
    } else {
      # Time must have run out.
      # Put that choking client out of its misery
      kill "KILL", $self->{'tcp_chld'};
      # Clean off the zombie
      waitpid($self->{'tcp_chld'}, 0);
      $ret = 0;
    }
    delete $self->{'tcp_chld'};
    $! = $child_errno;
  } else {
    # Otherwise don't waste the resources to fork

    &{ $do_socket }();

    &{ $do_connect_nb }();
  }

  return $ret;
}

sub DESTROY {
  my $self = shift;
  if ($self->{'proto'} eq 'tcp' &&
      $self->{'tcp_chld'}) {
    # Put that choking client out of its misery
    kill "KILL", $self->{'tcp_chld'};
    # Clean off the zombie
    waitpid($self->{'tcp_chld'}, 0);
  }
}

# This writes the given string to the socket and then reads it
# back.  It returns 1 on success, 0 on failure.
sub tcp_echo
{
  my $self = shift;
  my $timeout = shift;
  my $pingstring = shift;

  my $ret = undef;
  my $time = &time();
  my $wrstr = $pingstring;
  my $rdstr = "";

  eval <<'EOM';
    do {
      my $rin = "";
      vec($rin, $self->{"fh"}->fileno(), 1) = 1;

      my $rout = undef;
      if($wrstr) {
        $rout = "";
        vec($rout, $self->{"fh"}->fileno(), 1) = 1;
      }

      if(mselect($rin, $rout, undef, ($time + $timeout) - &time())) {

        if($rout && vec($rout,$self->{"fh"}->fileno(),1)) {
          my $num = syswrite($self->{"fh"}, $wrstr, length $wrstr);
          if($num) {
            # If it was a partial write, update and try again.
            $wrstr = substr($wrstr,$num);
          } else {
            # There was an error.
            $ret = 0;
          }
        }

        if(vec($rin,$self->{"fh"}->fileno(),1)) {
          my $reply;
          if(sysread($self->{"fh"},$reply,length($pingstring)-length($rdstr))) {
            $rdstr .= $reply;
            $ret = 1 if $rdstr eq $pingstring;
          } else {
            # There was an error.
            $ret = 0;
          }
        }

      }
    } until &time() > ($time + $timeout) || defined($ret);
EOM

  return $ret;
}




# Description: Perform a stream ping.  If the tcp connection isn't
# already open, it opens it.  It then sends some data and waits for
# a reply.  It leaves the stream open on exit.

sub ping_stream
{
  my ($self,
      $ip,                # Packed IP number of the host
      $timeout            # Seconds after which ping times out
      ) = @_;

  # Open the stream if it's not already open
  if(!defined $self->{"fh"}->fileno()) {
    $self->tcp_connect($ip, $timeout) or return 0;
  }

  croak "tried to switch servers while stream pinging"
    if $self->{"ip"} ne $ip;

  return $self->tcp_echo($timeout, $pingstring);
}

# Description: opens the stream.  You would do this if you want to
# separate the overhead of opening the stream from the first ping.

sub open
{
  my ($self,
      $host,              # Host or IP address
      $timeout            # Seconds after which open times out
      ) = @_;

  my ($ip);               # Packed IP number of the host
  $ip = inet_aton($host);
  $timeout = $self->{"timeout"} unless $timeout;

  if($self->{"proto"} eq "stream") {
    if(defined($self->{"fh"}->fileno())) {
      croak("socket is already open");
    } else {
      $self->tcp_connect($ip, $timeout);
    }
  }
}


# Description:  Perform a udp echo ping.  Construct a message of
# at least the one-byte sequence number and any additional data bytes.
# Send the message out and wait for a message to come back.  If we
# get a message, make sure all of its parts match.  If they do, we are
# done.  Otherwise go back and wait for the message until we run out
# of time.  Return the result of our efforts.

use constant UDP_FLAGS => 0; # Nothing special on send or recv
sub ping_udp
{
  my ($self,
      $ip,                # Packed IP number of the host
      $timeout            # Seconds after which ping times out
      ) = @_;

  my ($saddr,             # sockaddr_in with port and ip
      $ret,               # The return value
      $msg,               # Message to be echoed
      $finish_time,       # Time ping should be finished
      $flush,             # Whether socket needs to be disconnected
      $connect,           # Whether socket needs to be connected
      $done,              # Set to 1 when we are done pinging
      $rbits,             # Read bits, filehandles for reading
      $nfound,            # Number of ready filehandles found
      $from_saddr,        # sockaddr_in of sender
      $from_msg,          # Characters echoed by $host
      $from_port,         # Port message was echoed from
      $from_ip            # Packed IP number of sender
      );

  $saddr = sockaddr_in($self->{"port_num"}, $ip);
  $self->{"seq"} = ($self->{"seq"} + 1) % 256;    # Increment sequence
  $msg = chr($self->{"seq"}) . $self->{"data"};   # Add data if any

  if ($self->{"connected"}) {
    if ($self->{"connected"} ne $saddr) {
      # Still connected to wrong destination.
      # Need to flush out the old one.
      $flush = 1;
    }
  } else {
    # Not connected yet.
    # Need to connect() before send()
    $connect = 1;
  }

  # Have to connect() and send() instead of sendto()
  # in order to pick up on the ECONNREFUSED setting
  # from recv() or double send() errno as utilized in
  # the concept by rdw @ perlmonks.  See:
  # http://perlmonks.thepen.com/42898.html
  if ($flush) {
    # Need to socket() again to flush the descriptor
    # This will disconnect from the old saddr.
    socket($self->{"fh"}, PF_INET, SOCK_DGRAM,
           $self->{"proto_num"});
  }
  # Connect the socket if it isn't already connected
  # to the right destination.
  if ($flush || $connect) {
    connect($self->{"fh"}, $saddr);               # Tie destination to socket
    $self->{"connected"} = $saddr;
  }
  send($self->{"fh"}, $msg, UDP_FLAGS);           # Send it

  $rbits = "";
  vec($rbits, $self->{"fh"}->fileno(), 1) = 1;
  $ret = 0;                   # Default to unreachable
  $done = 0;
  my $retrans = 0.01;
  my $factor = $self->{"retrans"};
  $finish_time = &time() + $timeout;       # Ping needs to be done by then
  while (!$done && $timeout > 0)
  {
    if ($factor > 1)
    {
      $timeout = $retrans if $timeout > $retrans;
      $retrans*= $factor; # Exponential backoff
    }
    $nfound  = mselect((my $rout=$rbits), undef, undef, $timeout); # Wait for response
    my $why = $!;
    $timeout = $finish_time - &time();   # Get remaining time

    if (!defined($nfound))  # Hmm, a strange error
    {
      $ret = undef;
      $done = 1;
    }
    elsif ($nfound)         # A packet is waiting
    {
      $from_msg = "";
      $from_saddr = recv($self->{"fh"}, $from_msg, 1500, UDP_FLAGS);
      if (!$from_saddr) {
        # For example an unreachable host will make recv() fail.
        if (!$self->{"econnrefused"} &&
            ($! == ECONNREFUSED ||
             $! == ECONNRESET)) {
          # "Connection refused" means reachable
          # Good, continue
          $ret = 1;
        }
        $done = 1;
      } else {
        ($from_port, $from_ip) = sockaddr_in($from_saddr);
        if (!$source_verify ||
            (($from_ip eq $ip) &&        # Does the packet check out?
             ($from_port == $self->{"port_num"}) &&
             ($from_msg eq $msg)))
        {
          $ret = 1;       # It's a winner
          $done = 1;
        }
      }
    }
    elsif ($timeout <= 0)              # Oops, timed out
    {
      $done = 1;
    }
    else
    {
      # Send another in case the last one dropped
      if (send($self->{"fh"}, $msg, UDP_FLAGS)) {
        # Another send worked?  The previous udp packet
        # must have gotten lost or is still in transit.
        # Hopefully this new packet will arrive safely.
      } else {
        if (!$self->{"econnrefused"} &&
            $! == ECONNREFUSED) {
          # "Connection refused" means reachable
          # Good, continue
          $ret = 1;
        }
        $done = 1;
      }
    }
  }
  return $ret;
}

# Description: Send a TCP SYN packet to host specified.
sub ping_syn
{
  my $self = shift;
  my $host = shift;
  my $ip = shift;
  my $start_time = shift;
  my $stop_time = shift;

  if ($syn_forking) {
    return $self->ping_syn_fork($host, $ip, $start_time, $stop_time);
  }

  my $fh = FileHandle->new();
  my $saddr = sockaddr_in($self->{"port_num"}, $ip);

  # Create TCP socket
  if (!socket ($fh, PF_INET, SOCK_STREAM, $self->{"proto_num"})) {
    croak("tcp socket error - $!");
  }

  if (defined $self->{"local_addr"} &&
      !CORE::bind($fh, sockaddr_in(0, $self->{"local_addr"}))) {
    croak("tcp bind error - $!");
  }

  if ($self->{'device'}) {
    setsockopt($fh, SOL_SOCKET, SO_BINDTODEVICE(), pack("Z*", $self->{'device'}))
      or croak("error binding to device $self->{'device'} $!");
  }
  if ($self->{'tos'}) {
    setsockopt($fh, SOL_IP, IP_TOS(), pack("I*", $self->{'tos'}))
      or croak "error configuring tos to $self->{'tos'} $!";
  }
  # Set O_NONBLOCK property on filehandle
  $self->socket_blocking_mode($fh, 0);

  # Attempt the non-blocking connect
  # by just sending the TCP SYN packet
  if (connect($fh, $saddr)) {
    # Non-blocking, yet still connected?
    # Must have connected very quickly,
    # or else it wasn't very non-blocking.
    #warn "WARNING: Nonblocking connect connected anyway? ($^O)";
  } else {
    # Error occurred connecting.
    if ($! == EINPROGRESS || ($^O eq 'MSWin32' && $! == EWOULDBLOCK)) {
      # The connection is just still in progress.
      # This is the expected condition.
    } else {
      # Just save the error and continue on.
      # The ack() can check the status later.
      $self->{"bad"}->{$host} = $!;
    }
  }

  my $entry = [ $host, $ip, $fh, $start_time, $stop_time ];
  $self->{"syn"}->{$fh->fileno} = $entry;
  if ($self->{"stop_time"} < $stop_time) {
    $self->{"stop_time"} = $stop_time;
  }
  vec($self->{"wbits"}, $fh->fileno, 1) = 1;

  return 1;
}

sub ping_syn_fork {
  my ($self, $host, $ip, $start_time, $stop_time) = @_;

  # Buggy Winsock API doesn't allow nonblocking connect.
  # Hence, if our OS is Windows, we need to create a separate
  # process to do the blocking connect attempt.
  my $pid = fork();
  if (defined $pid) {
    if ($pid) {
      # Parent process
      my $entry = [ $host, $ip, $pid, $start_time, $stop_time ];
      $self->{"syn"}->{$pid} = $entry;
      if ($self->{"stop_time"} < $stop_time) {
        $self->{"stop_time"} = $stop_time;
      }
    } else {
      # Child process
      my $saddr = sockaddr_in($self->{"port_num"}, $ip);

      # Create TCP socket
      if (!socket ($self->{"fh"}, PF_INET, SOCK_STREAM, $self->{"proto_num"})) {
        croak("tcp socket error - $!");
      }

      if (defined $self->{"local_addr"} &&
          !CORE::bind($self->{"fh"}, sockaddr_in(0, $self->{"local_addr"}))) {
        croak("tcp bind error - $!");
      }

      if ($self->{'device'}) {
        setsockopt($self->{"fh"}, SOL_SOCKET, SO_BINDTODEVICE(), pack("Z*", $self->{'device'}))
          or croak("error binding to device $self->{'device'} $!");
      }
      if ($self->{'tos'}) {
        setsockopt($self->{"fh"}, SOL_IP, IP_TOS(), pack("I*", $self->{'tos'}))
          or croak "error configuring tos to $self->{'tos'} $!";
      }

      $!=0;
      # Try to connect (could take a long time)
      connect($self->{"fh"}, $saddr);
      # Notify parent of connect error status
      my $err = $!+0;
      my $wrstr = "$$ $err";
      # Force to 16 chars including \n
      $wrstr .= " "x(15 - length $wrstr). "\n";
      syswrite($self->{"fork_wr"}, $wrstr, length $wrstr);
      exit;
    }
  } else {
    # fork() failed?
    die "fork: $!";
  }
  return 1;
}

# Description: Wait for TCP ACK from host specified
# from ping_syn above.  If no host is specified, wait
# for TCP ACK from any of the hosts in the SYN queue.
sub ack
{
  my $self = shift;

  if ($self->{"proto"} eq "syn") {
    if ($syn_forking) {
      my @answer = $self->ack_unfork(shift);
      return wantarray ? @answer : $answer[0];
    }
    my $wbits = "";
    my $stop_time = 0;
    if (my $host = shift) {
      # Host passed as arg
      if (exists $self->{"bad"}->{$host}) {
        if (!$self->{"econnrefused"} &&
            $self->{"bad"}->{ $host } &&
            (($! = ECONNREFUSED)>0) &&
            $self->{"bad"}->{ $host } eq "$!") {
          # "Connection refused" means reachable
          # Good, continue
        } else {
          # ECONNREFUSED means no good
          return ();
        }
      }
      my $host_fd = undef;
      foreach my $fd (keys %{ $self->{"syn"} }) {
        my $entry = $self->{"syn"}->{$fd};
        if ($entry->[0] eq $host) {
          $host_fd = $fd;
          $stop_time = $entry->[4]
            || croak("Corrupted SYN entry for [$host]");
          last;
        }
      }
      croak("ack called on [$host] without calling ping first!")
        unless defined $host_fd;
      vec($wbits, $host_fd, 1) = 1;
    } else {
      # No $host passed so scan all hosts
      # Use the latest stop_time
      $stop_time = $self->{"stop_time"};
      # Use all the bits
      $wbits = $self->{"wbits"};
    }

    while ($wbits !~ /^\0*\z/) {
      my $timeout = $stop_time - &time();
      # Force a minimum of 10 ms timeout.
      $timeout = 0.01 if $timeout <= 0.01;

      my $winner_fd = undef;
      my $wout = $wbits;
      my $fd = 0;
      # Do "bad" fds from $wbits first
      while ($wout !~ /^\0*\z/) {
        if (vec($wout, $fd, 1)) {
          # Wipe it from future scanning.
          vec($wout, $fd, 1) = 0;
          if (my $entry = $self->{"syn"}->{$fd}) {
            if ($self->{"bad"}->{ $entry->[0] }) {
              $winner_fd = $fd;
              last;
            }
          }
        }
        $fd++;
      }

      if (defined($winner_fd) or my $nfound = mselect(undef, ($wout=$wbits), undef, $timeout)) {
        if (defined $winner_fd) {
          $fd = $winner_fd;
        } else {
          # Done waiting for one of the ACKs
          $fd = 0;
          # Determine which one
          while ($wout !~ /^\0*\z/ &&
                 !vec($wout, $fd, 1)) {
            $fd++;
          }
        }
        if (my $entry = $self->{"syn"}->{$fd}) {
          # Wipe it from future scanning.
          delete $self->{"syn"}->{$fd};
          vec($self->{"wbits"}, $fd, 1) = 0;
          vec($wbits, $fd, 1) = 0;
          if (!$self->{"econnrefused"} &&
              $self->{"bad"}->{ $entry->[0] } &&
              (($! = ECONNREFUSED)>0) &&
              $self->{"bad"}->{ $entry->[0] } eq "$!") {
            # "Connection refused" means reachable
            # Good, continue
          } elsif (getpeername($entry->[2])) {
            # Connection established to remote host
            # Good, continue
          } else {
            # TCP ACK will never come from this host
            # because there was an error connecting.

            # This should set $! to the correct error.
            my $char;
            sysread($entry->[2],$char,1);
            # Store the excuse why the connection failed.
            $self->{"bad"}->{$entry->[0]} = $!;
            if (!$self->{"econnrefused"} &&
                (($! == ECONNREFUSED) ||
                 ($! == EAGAIN && $^O =~ /cygwin/i))) {
              # "Connection refused" means reachable
              # Good, continue
            } else {
              # No good, try the next socket...
              next;
            }
          }
          # Everything passed okay, return the answer
          return wantarray ?
            ($entry->[0], &time() - $entry->[3], inet_ntoa($entry->[1]))
            : $entry->[0];
        } else {
          warn "Corrupted SYN entry: unknown fd [$fd] ready!";
          vec($wbits, $fd, 1) = 0;
          vec($self->{"wbits"}, $fd, 1) = 0;
        }
      } elsif (defined $nfound) {
        # Timed out waiting for ACK
        foreach my $fd (keys %{ $self->{"syn"} }) {
          if (vec($wbits, $fd, 1)) {
            my $entry = $self->{"syn"}->{$fd};
            $self->{"bad"}->{$entry->[0]} = "Timed out";
            vec($wbits, $fd, 1) = 0;
            vec($self->{"wbits"}, $fd, 1) = 0;
            delete $self->{"syn"}->{$fd};
          }
        }
      } else {
        # Weird error occurred with select()
        warn("select: $!");
        $self->{"syn"} = {};
        $wbits = "";
      }
    }
  }
  return ();
}

sub ack_unfork {
  my ($self,$host) = @_;
  my $stop_time = $self->{"stop_time"};
  if ($host) {
    # Host passed as arg
    if (my $entry = $self->{"good"}->{$host}) {
      delete $self->{"good"}->{$host};
      return ($entry->[0], &time() - $entry->[3], inet_ntoa($entry->[1]));
    }
  }

  my $rbits = "";
  my $timeout;

  if (keys %{ $self->{"syn"} }) {
    # Scan all hosts that are left
    vec($rbits, fileno($self->{"fork_rd"}), 1) = 1;
    $timeout = $stop_time - &time();
    # Force a minimum of 10 ms timeout.
    $timeout = 0.01 if $timeout < 0.01;
  } else {
    # No hosts left to wait for
    $timeout = 0;
  }

  if ($timeout > 0) {
    my $nfound;
    while ( keys %{ $self->{"syn"} } and
           $nfound = mselect((my $rout=$rbits), undef, undef, $timeout)) {
      # Done waiting for one of the ACKs
      if (!sysread($self->{"fork_rd"}, $_, 16)) {
        # Socket closed, which means all children are done.
        return ();
      }
      my ($pid, $how) = split;
      if ($pid) {
        # Flush the zombie
        waitpid($pid, 0);
        if (my $entry = $self->{"syn"}->{$pid}) {
          # Connection attempt to remote host is done
          delete $self->{"syn"}->{$pid};
          if (!$how || # If there was no error connecting
              (!$self->{"econnrefused"} &&
               $how == ECONNREFUSED)) {  # "Connection refused" means reachable
            if ($host && $entry->[0] ne $host) {
              # A good connection, but not the host we need.
              # Move it from the "syn" hash to the "good" hash.
              $self->{"good"}->{$entry->[0]} = $entry;
              # And wait for the next winner
              next;
            }
            return ($entry->[0], &time() - $entry->[3], inet_ntoa($entry->[1]));
          }
        } else {
          # Should never happen
          die "Unknown ping from pid [$pid]";
        }
      } else {
        die "Empty response from status socket?";
      }
    }
    if (defined $nfound) {
      # Timed out waiting for ACK status
    } else {
      # Weird error occurred with select()
      warn("select: $!");
    }
  }
  if (my @synners = keys %{ $self->{"syn"} }) {
    # Kill all the synners
    kill 9, @synners;
    foreach my $pid (@synners) {
      # Wait for the deaths to finish
      # Then flush off the zombie
      waitpid($pid, 0);
    }
  }
  $self->{"syn"} = {};
  return ();
}

# Description:  Tell why the ack() failed
sub nack {
  my $self = shift;
  my $host = shift || croak('Usage> nack($failed_ack_host)');
  return $self->{"bad"}->{$host} || undef;
}

# Description:  Close the connection.

sub close
{
  my ($self) = @_;

  if ($self->{"proto"} eq "syn") {
    delete $self->{"syn"};
  } elsif ($self->{"proto"} eq "tcp") {
    # The connection will already be closed
  } else {
    $self->{"fh"}->close();
  }
}


1;
__END__

