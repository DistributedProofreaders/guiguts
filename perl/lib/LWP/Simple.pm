package LWP::Simple;

# $Id: Simple.pm,v 1.38 2003/10/23 19:11:32 uid39246 Exp $

use strict;
use vars qw($ua %loop_check $FULL_LWP @EXPORT @EXPORT_OK $VERSION);

require Exporter;

@EXPORT = qw(get head getprint getstore mirror);
@EXPORT_OK = qw($ua);

# I really hate this.  I was a bad idea to do it in the first place.
# Wonder how to get rid of it???  (It even makes LWP::Simple 7% slower
# for trivial tests)
use HTTP::Status;
push(@EXPORT, @HTTP::Status::EXPORT);

$VERSION = sprintf("%d.%02d", q$Revision: 1.38 $ =~ /(\d+)\.(\d+)/);
$FULL_LWP++ if grep {lc($_) eq "http_proxy"} keys %ENV;


sub import
{
    my $pkg = shift;
    my $callpkg = caller;
    if (grep $_ eq '$ua', @_) {
	$FULL_LWP++;
	_init_ua();
    }
    Exporter::export($pkg, $callpkg, @_);
}


sub _init_ua
{
    require LWP;
    require LWP::UserAgent;
    require HTTP::Status;
    require HTTP::Date;
    $ua = new LWP::UserAgent;  # we create a global UserAgent object
    my $ver = $LWP::VERSION = $LWP::VERSION;  # avoid warning
    $ua->agent("LWP::Simple/$LWP::VERSION");
    $ua->env_proxy;
}


sub get ($)
{
    %loop_check = ();
    goto \&_get;
}


sub get_old ($)
{
    my($url) = @_;
    _init_ua() unless $ua;

    my $request = HTTP::Request->new(GET => $url);
    my $response = $ua->request($request);

    return $response->content if $response->is_success;
    return undef;
}


sub head ($)
{
    my($url) = @_;
    _init_ua() unless $ua;

    my $request = HTTP::Request->new(HEAD => $url);
    my $response = $ua->request($request);

    if ($response->is_success) {
	return $response unless wantarray;
	return (scalar $response->header('Content-Type'),
		scalar $response->header('Content-Length'),
		HTTP::Date::str2time($response->header('Last-Modified')),
		HTTP::Date::str2time($response->header('Expires')),
		scalar $response->header('Server'),
	       );
    }
    return;
}


sub getprint ($)
{
    my($url) = @_;
    _init_ua() unless $ua;

    my $request = HTTP::Request->new(GET => $url);
    local($\) = ""; # ensure standard $OUTPUT_RECORD_SEPARATOR
    my $callback = sub { print $_[0] };
    if ($^O eq "MacOS") {
	$callback = sub { $_[0] =~ s/\015?\012/\n/g; print $_[0] }
    }
    my $response = $ua->request($request, $callback);
    unless ($response->is_success) {
	print STDERR $response->status_line, " <URL:$url>\n";
    }
    $response->code;
}


sub getstore ($$)
{
    my($url, $file) = @_;
    _init_ua() unless $ua;

    my $request = HTTP::Request->new(GET => $url);
    my $response = $ua->request($request, $file);

    $response->code;
}


sub mirror ($$)
{
    my($url, $file) = @_;
    _init_ua() unless $ua;
    my $response = $ua->mirror($url, $file);
    $response->code;
}


sub _get
{
    my $url = shift;
    my $ret;
    if (!$FULL_LWP && $url =~ m,^http://([^/:\@]+)(?::(\d+))?(/\S*)?$,) {
	my $host = $1;
	my $port = $2 || 80;
	my $path = $3;
	$path = "/" unless defined($path);
	return _trivial_http_get($host, $port, $path);
    }
    else {
        _init_ua() unless $ua;
	if (@_ && $url !~ /^\w+:/) {
	    # non-absolute redirect from &_trivial_http_get
	    my($host, $port, $path) = @_;
	    require URI;
	    $url = URI->new_abs($url, "http://$host:$port$path");
	}
	my $request = HTTP::Request->new(GET => $url);
	my $response = $ua->request($request);
	return $response->is_success ? $response->content : undef;
    }
}


sub _trivial_http_get
{
   my($host, $port, $path) = @_;
   #print "HOST=$host, PORT=$port, PATH=$path\n";

   require IO::Socket;
   local($^W) = 0;
   my $sock = IO::Socket::INET->new(PeerAddr => $host,
                                    PeerPort => $port,
                                    Proto    => 'tcp',
                                    Timeout  => 60) || return undef;
   $sock->autoflush;
   my $netloc = $host;
   $netloc .= ":$port" if $port != 80;
   print $sock join("\015\012" =>
                    "GET $path HTTP/1.0",
                    "Host: $netloc",
                    "User-Agent: lwp-trivial/$VERSION",
                    "", "");

   my $buf = "";
   my $n;
   1 while $n = sysread($sock, $buf, 8*1024, length($buf));
   return undef unless defined($n);

   if ($buf =~ m,^HTTP/\d+\.\d+\s+(\d+)[^\012]*\012,) {
       my $code = $1;
       #print "CODE=$code\n$buf\n";
       if ($code =~ /^30[1237]/ && $buf =~ /\012Location:\s*(\S+)/) {
           # redirect
           my $url = $1;
           return undef if $loop_check{$url}++;
           return _get($url, $host, $port, $path);
       }
       return undef unless $code =~ /^2/;
       $buf =~ s/.+?\015?\012\015?\012//s;  # zap header
   }

   return $buf;
}


1;

__END__

