package HTTP::Daemon;

# $Id: Daemon.pm,v 1.33 2003/10/24 09:07:44 gisle Exp $

use strict;
use vars qw($VERSION @ISA $PROTO $DEBUG);

$VERSION = sprintf("%d.%02d", q$Revision: 1.33 $ =~ /(\d+)\.(\d+)/);

use IO::Socket qw(AF_INET INADDR_ANY inet_ntoa);
@ISA=qw(IO::Socket::INET);

$PROTO = "HTTP/1.1";


sub new
{
    my($class, %args) = @_;
    $args{Listen} ||= 5;
    $args{Proto}  ||= 'tcp';
    return $class->SUPER::new(%args);
}


sub accept
{
    my $self = shift;
    my $pkg = shift || "HTTP::Daemon::ClientConn";
    my ($sock, $peer) = $self->SUPER::accept($pkg);
    if ($sock) {
        ${*$sock}{'httpd_daemon'} = $self;
        return wantarray ? ($sock, $peer) : $sock;
    }
    else {
        return;
    }
}


sub url
{
    my $self = shift;
    my $url = "http://";
    my $addr = $self->sockaddr;
    if (!$addr || $addr eq INADDR_ANY) {
 	require Sys::Hostname;
 	$url .= lc Sys::Hostname::hostname();
    }
    else {
	$url .= gethostbyaddr($addr, AF_INET) || inet_ntoa($addr);
    }
    my $port = $self->sockport;
    $url .= ":$port" if $port != 80;
    $url .= "/";
    $url;
}


sub product_tokens
{
    "libwww-perl-daemon/$HTTP::Daemon::VERSION";
}



package HTTP::Daemon::ClientConn;

use vars qw(@ISA $DEBUG);
use IO::Socket ();
@ISA=qw(IO::Socket::INET);
*DEBUG = \$HTTP::Daemon::DEBUG;

use HTTP::Request  ();
use HTTP::Response ();
use HTTP::Status;
use HTTP::Date qw(time2str);
use LWP::MediaTypes qw(guess_media_type);
use Carp ();

my $CRLF = "\015\012";   # "\r\n" is not portable
my $HTTP_1_0 = _http_version("HTTP/1.0");
my $HTTP_1_1 = _http_version("HTTP/1.1");


sub get_request
{
    my($self, $only_headers) = @_;
    if (${*$self}{'httpd_nomore'}) {
        $self->reason("No more requests from this connection");
	return;
    }

    $self->reason("");
    my $buf = ${*$self}{'httpd_rbuf'};
    $buf = "" unless defined $buf;

    my $timeout = $ {*$self}{'io_socket_timeout'};
    my $fdset = "";
    vec($fdset, $self->fileno, 1) = 1;
    local($_);

  READ_HEADER:
    while (1) {
	# loop until we have the whole header in $buf
	$buf =~ s/^(?:\015?\012)+//;  # ignore leading blank lines
	if ($buf =~ /\012/) {  # potential, has at least one line
	    if ($buf =~ /^\w+[^\012]+HTTP\/\d+\.\d+\015?\012/) {
		if ($buf =~ /\015?\012\015?\012/) {
		    last READ_HEADER;  # we have it
		}
		elsif (length($buf) > 16*1024) {
		    $self->send_error(413); # REQUEST_ENTITY_TOO_LARGE
		    $self->reason("Very long header");
		    return;
		}
	    }
	    else {
		last READ_HEADER;  # HTTP/0.9 client
	    }
	}
	elsif (length($buf) > 16*1024) {
	    $self->send_error(414); # REQUEST_URI_TOO_LARGE
	    $self->reason("Very long first line");
	    return;
	}
	print STDERR "Need more data for complete header\n" if $DEBUG;
	return unless $self->_need_more($buf, $timeout, $fdset);
    }
    if ($buf !~ s/^(\S+)[ \t]+(\S+)(?:[ \t]+(HTTP\/\d+\.\d+))?[^\012]*\012//) {
	${*$self}{'httpd_client_proto'} = _http_version("HTTP/1.0");
	$self->send_error(400);  # BAD_REQUEST
	$self->reason("Bad request line: $buf");
	return;
    }
    my $method = $1;
    my $uri = $2;
    my $proto = $3 || "HTTP/0.9";
    $uri = "http://$uri" if $method eq "CONNECT";
    $uri = $HTTP::URI_CLASS->new($uri, $self->daemon->url);
    my $r = HTTP::Request->new($method, $uri);
    $r->protocol($proto);
    ${*$self}{'httpd_client_proto'} = $proto = _http_version($proto);

    if ($proto >= $HTTP_1_0) {
	# we expect to find some headers
	my($key, $val);
      HEADER:
	while ($buf =~ s/^([^\012]*)\012//) {
	    $_ = $1;
	    s/\015$//;
	    if (/^([^:\s]+)\s*:\s*(.*)/) {
		$r->push_header($key, $val) if $key;
		($key, $val) = ($1, $2);
	    }
	    elsif (/^\s+(.*)/) {
		$val .= " $1";
	    }
	    else {
		last HEADER;
	    }
	}
	$r->push_header($key, $val) if $key;
    }

    my $conn = $r->header('Connection');
    if ($proto >= $HTTP_1_1) {
	${*$self}{'httpd_nomore'}++ if $conn && lc($conn) =~ /\bclose\b/;
    }
    else {
	${*$self}{'httpd_nomore'}++ unless $conn &&
                                           lc($conn) =~ /\bkeep-alive\b/;
    }

    if ($only_headers) {
	${*$self}{'httpd_rbuf'} = $buf;
        return $r;
    }

    # Find out how much content to read
    my $te  = $r->header('Transfer-Encoding');
    my $ct  = $r->header('Content-Type');
    my $len = $r->header('Content-Length');

    if ($te && lc($te) eq 'chunked') {
	# Handle chunked transfer encoding
	my $body = "";
      CHUNK:
	while (1) {
	    print STDERR "Chunked\n" if $DEBUG;
	    if ($buf =~ s/^([^\012]*)\012//) {
		my $chunk_head = $1;
		unless ($chunk_head =~ /^([0-9A-Fa-f]+)/) {
		    $self->send_error(400);
		    $self->reason("Bad chunk header $chunk_head");
		    return;
		}
		my $size = hex($1);
		last CHUNK if $size == 0;

		my $missing = $size - length($buf) + 2; # 2=CRLF at chunk end
		# must read until we have a complete chunk
		while ($missing > 0) {
		    print STDERR "Need $missing more bytes\n" if $DEBUG;
		    my $n = $self->_need_more($buf, $timeout, $fdset);
		    return unless $n;
		    $missing -= $n;
		}
		$body .= substr($buf, 0, $size);
		substr($buf, 0, $size+2) = '';

	    }
	    else {
		# need more data in order to have a complete chunk header
		return unless $self->_need_more($buf, $timeout, $fdset);
	    }
	}
	$r->content($body);

	# pretend it was a normal entity body
	$r->remove_header('Transfer-Encoding');
	$r->header('Content-Length', length($body));

	my($key, $val);
      FOOTER:
	while (1) {
	    if ($buf !~ /\012/) {
		# need at least one line to look at
		return unless $self->_need_more($buf, $timeout, $fdset);
	    }
	    else {
		$buf =~ s/^([^\012]*)\012//;
		$_ = $1;
		s/\015$//;
		if (/^([\w\-]+)\s*:\s*(.*)/) {
		    $r->push_header($key, $val) if $key;
		    ($key, $val) = ($1, $2);
		}
		elsif (/^\s+(.*)/) {
		    $val .= " $1";
		}
		elsif (!length) {
		    last FOOTER;
		}
		else {
		    $self->reason("Bad footer syntax");
		    return;
		}
	    }
	}
	$r->push_header($key, $val) if $key;

    }
    elsif ($te) {
	$self->send_error(501); 	# Unknown transfer encoding
	$self->reason("Unknown transfer encoding '$te'");
	return;

    }
    elsif ($ct && lc($ct) =~ m/^multipart\/\w+\s*;.*boundary\s*=\s*(\w+)/) {
	# Handle multipart content type
	my $boundary = "$CRLF--$1--$CRLF";
	my $index;
	while (1) {
	    $index = index($buf, $boundary);
	    last if $index >= 0;
	    # end marker not yet found
	    return unless $self->_need_more($buf, $timeout, $fdset);
	}
	$index += length($boundary);
	$r->content(substr($buf, 0, $index));
	substr($buf, 0, $index) = '';

    }
    elsif ($len) {
	# Plain body specified by "Content-Length"
	my $missing = $len - length($buf);
	while ($missing > 0) {
	    print "Need $missing more bytes of content\n" if $DEBUG;
	    my $n = $self->_need_more($buf, $timeout, $fdset);
	    return unless $n;
	    $missing -= $n;
	}
	if (length($buf) > $len) {
	    $r->content(substr($buf,0,$len));
	    substr($buf, 0, $len) = '';
	}
	else {
	    $r->content($buf);
	    $buf='';
	}
    }
    ${*$self}{'httpd_rbuf'} = $buf;

    $r;
}


sub _need_more
{
    my $self = shift;
    #my($buf,$timeout,$fdset) = @_;
    if ($_[1]) {
	my($timeout, $fdset) = @_[1,2];
	print STDERR "select(,,,$timeout)\n" if $DEBUG;
	my $n = select($fdset,undef,undef,$timeout);
	unless ($n) {
	    $self->reason(defined($n) ? "Timeout" : "select: $!");
	    return;
	}
    }
    print STDERR "sysread()\n" if $DEBUG;
    my $n = sysread($self, $_[0], 2048, length($_[0]));
    $self->reason(defined($n) ? "Client closed" : "sysread: $!") unless $n;
    $n;
}


sub read_buffer
{
    my $self = shift;
    my $old = ${*$self}{'httpd_rbuf'};
    if (@_) {
	${*$self}{'httpd_rbuf'} = shift;
    }
    $old;
}


sub reason
{
    my $self = shift;
    my $old = ${*$self}{'httpd_reason'};
    if (@_) {
        ${*$self}{'httpd_reason'} = shift;
    }
    $old;
}


sub proto_ge
{
    my $self = shift;
    ${*$self}{'httpd_client_proto'} >= _http_version(shift);
}


sub _http_version
{
    local($_) = shift;
    return 0 unless m,^(?:HTTP/)?(\d+)\.(\d+)$,i;
    $1 * 1000 + $2;
}


sub antique_client
{
    my $self = shift;
    ${*$self}{'httpd_client_proto'} < $HTTP_1_0;
}


sub force_last_request
{
    my $self = shift;
    ${*$self}{'httpd_nomore'}++;
}


sub send_status_line
{
    my($self, $status, $message, $proto) = @_;
    return if $self->antique_client;
    $status  ||= RC_OK;
    $message ||= status_message($status) || "";
    $proto   ||= $HTTP::Daemon::PROTO || "HTTP/1.1";
    print $self "$proto $status $message$CRLF";
}


sub send_crlf
{
    my $self = shift;
    print $self $CRLF;
}


sub send_basic_header
{
    my $self = shift;
    return if $self->antique_client;
    $self->send_status_line(@_);
    print $self "Date: ", time2str(time), $CRLF;
    my $product = $self->daemon->product_tokens;
    print $self "Server: $product$CRLF" if $product;
}


sub send_response
{
    my $self = shift;
    my $res = shift;
    if (!ref $res) {
	$res ||= RC_OK;
	$res = HTTP::Response->new($res, @_);
    }
    my $content = $res->content;
    my $chunked;
    unless ($self->antique_client) {
	my $code = $res->code;
	$self->send_basic_header($code, $res->message, $res->protocol);
	if ($code =~ /^(1\d\d|[23]04)$/) {
	    # make sure content is empty
	    $res->remove_header("Content-Length");
	    $content = "";
	}
	elsif ($res->request && $res->request->method eq "HEAD") {
	    # probably OK
	}
	elsif (ref($content) eq "CODE") {
	    if ($self->proto_ge("HTTP/1.1")) {
		$res->push_header("Transfer-Encoding" => "chunked");
		$chunked++;
	    }
	    else {
		$self->force_last_request;
	    }
	}
	elsif (length($content)) {
	    $res->header("Content-Length" => length($content));
	}
	else {
	    $self->force_last_request;
	}
	print $self $res->headers_as_string($CRLF);
	print $self $CRLF;  # separates headers and content
    }
    if (ref($content) eq "CODE") {
	while (1) {
	    my $chunk = &$content();
	    last unless defined($chunk) && length($chunk);
	    if ($chunked) {
		printf $self "%x%s%s%s", length($chunk), $CRLF, $chunk, $CRLF;
	    }
	    else {
		print $self $chunk;
	    }
	}
	print $self "0$CRLF$CRLF" if $chunked;  # no trailers either
    }
    elsif (length $content) {
	print $self $content;
    }
}


sub send_redirect
{
    my($self, $loc, $status, $content) = @_;
    $status ||= RC_MOVED_PERMANENTLY;
    Carp::croak("Status '$status' is not redirect") unless is_redirect($status);
    $self->send_basic_header($status);
    my $base = $self->daemon->url;
    $loc = $HTTP::URI_CLASS->new($loc, $base) unless ref($loc);
    $loc = $loc->abs($base);
    print $self "Location: $loc$CRLF";
    if ($content) {
	my $ct = $content =~ /^\s*</ ? "text/html" : "text/plain";
	print $self "Content-Type: $ct$CRLF";
    }
    print $self $CRLF;
    print $self $content if $content;
    $self->force_last_request;  # no use keeping the connection open
}


sub send_error
{
    my($self, $status, $error) = @_;
    $status ||= RC_BAD_REQUEST;
    Carp::croak("Status '$status' is not an error") unless is_error($status);
    my $mess = status_message($status);
    $error  ||= "";
    $mess = <<EOT;
<title>$status $mess</title>
<h1>$status $mess</h1>
$error
EOT
    unless ($self->antique_client) {
        $self->send_basic_header($status);
        print $self "Content-Type: text/html$CRLF";
	print $self "Content-Length: " . length($mess) . $CRLF;
        print $self $CRLF;
    }
    print $self $mess;
    $status;
}


sub send_file_response
{
    my($self, $file) = @_;
    if (-d $file) {
	$self->send_dir($file);
    }
    elsif (-f _) {
	# plain file
	local(*F);
	sysopen(F, $file, 0) or 
	  return $self->send_error(RC_FORBIDDEN);
	binmode(F);
	my($ct,$ce) = guess_media_type($file);
	my($size,$mtime) = (stat _)[7,9];
	unless ($self->antique_client) {
	    $self->send_basic_header;
	    print $self "Content-Type: $ct$CRLF";
	    print $self "Content-Encoding: $ce$CRLF" if $ce;
	    print $self "Content-Length: $size$CRLF" if $size;
	    print $self "Last-Modified: ", time2str($mtime), "$CRLF" if $mtime;
	    print $self $CRLF;
	}
	$self->send_file(\*F);
	return RC_OK;
    }
    else {
	$self->send_error(RC_NOT_FOUND);
    }
}


sub send_dir
{
    my($self, $dir) = @_;
    $self->send_error(RC_NOT_FOUND) unless -d $dir;
    $self->send_error(RC_NOT_IMPLEMENTED);
}


sub send_file
{
    my($self, $file) = @_;
    my $opened = 0;
    local(*FILE);
    if (!ref($file)) {
	open(FILE, $file) || return undef;
	binmode(FILE);
	$file = \*FILE;
	$opened++;
    }
    my $cnt = 0;
    my $buf = "";
    my $n;
    while ($n = sysread($file, $buf, 8*1024)) {
	last if !$n;
	$cnt += $n;
	print $self $buf;
    }
    close($file) if $opened;
    $cnt;
}


sub daemon
{
    my $self = shift;
    ${*$self}{'httpd_daemon'};
}


1;

__END__

