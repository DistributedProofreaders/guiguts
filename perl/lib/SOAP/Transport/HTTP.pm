# ======================================================================
#
# Copyright (C) 2000-2001 Paul Kulchenko (paulclinger@yahoo.com)
# SOAP::Lite is free software; you can redistribute it
# and/or modify it under the same terms as Perl itself.
#
# $Id: HTTP.pm,v 1.11 2002/04/15 17:35:11 paulk Exp $
#
# ======================================================================

package SOAP::Transport::HTTP;

use strict;
use vars qw($VERSION);
$VERSION = sprintf("%d.%s", map {s/_//g; $_} q$Name: release-0_55-public $ =~ /-(\d+)_([\d_]+)/);

use SOAP::Lite;

# ======================================================================

package SOAP::Transport::HTTP::Client;

use vars qw(@ISA $COMPRESS);
@ISA = qw(SOAP::Client LWP::UserAgent);

$COMPRESS = 'deflate';

my(%redirect, %mpost, %nocompress);

# hack for HTTP conection that returns Keep-Alive 
# miscommunication (?) between LWP::Protocol and LWP::Protocol::http
# dies after timeout, but seems like we could make it work
sub patch { 
  local $^W; 
  { sub LWP::UserAgent::redirect_ok; *LWP::UserAgent::redirect_ok = sub {1} }
  { package LWP::Protocol; 
    my $collect = \&collect; # store original  
    *collect = sub {          
      if (defined $_[2]->header('Connection') && $_[2]->header('Connection') eq 'Keep-Alive') {
        my $data = $_[3]->(); 
        my $next = SOAP::Utils::bytelength($$data) == $_[2]->header('Content-Length') ? sub { \'' } : $_[3];
        my $done = 0; $_[3] = sub { $done++ ? &$next : $data };
      }
      goto &$collect;
    };
  }
  *patch = sub {};
};

sub DESTROY { SOAP::Trace::objects('()') }

sub new { require LWP::UserAgent; patch;
  my $self = shift;

  unless (ref $self) {
    my $class = ref($self) || $self;
    my(@params, @methods);
    while (@_) { $class->can($_[0]) ? push(@methods, shift() => shift) : push(@params, shift) }
    $self = $class->SUPER::new(@params);
    $self->agent(join '/', 'SOAP::Lite', 'Perl', SOAP::Transport::HTTP->VERSION);
    $self->options({});
    while (@methods) { my($method, $params) = splice(@methods,0,2);
      $self->$method(ref $params eq 'ARRAY' ? @$params : $params) 
    }
    SOAP::Trace::objects('()');
  }
  return $self;
}

sub send_receive {
  my($self, %parameters) = @_;
  my($envelope, $endpoint, $action, $encoding) = 
    @parameters{qw(envelope endpoint action encoding)};

  $endpoint ||= $self->endpoint;

  my $method = 'POST';
  my $resp;

  $self->options->{is_compress} ||= exists $self->options->{compress_threshold} &&
                                    eval { require Compress::Zlib };

  COMPRESS: {

    my $compressed = !exists $nocompress{$endpoint} &&
                     $self->options->{is_compress} && 
                     ($self->options->{compress_threshold} || 0) < SOAP::Utils::bytelength $envelope;
    $envelope = Compress::Zlib::compress($envelope) if $compressed;

    while (1) { 

      # check cache for redirect
      $endpoint = $redirect{$endpoint} if exists $redirect{$endpoint};
      # check cache for M-POST
      $method = 'M-POST' if exists $mpost{$endpoint};
  
      # what's this all about? 
      # unfortunately combination of LWP and Perl 5.6.1 and later has bug
      # in sending multibyte characters. LWP uses length() to calculate
      # content-length header and starting 5.6.1 length() calculates chars
      # instead of bytes. 'use bytes' in THIS file doesn't work, because
      # it's lexically scoped. Unfortunately, content-length we calculate
      # here doesn't work either, because LWP overwrites it with 
      # content-length it calculates (which is wrong) AND uses length()
      # during syswrite/sysread, so we are in a bad shape anyway.

      # what to do? we calculate proper content-length (using 
      # bytelength() function from SOAP::Utils) and then drop utf8 mark
      # from string (doing pack with 'C0A*' modifier) if length and 
      # bytelength are not the same
      my $bytelength = SOAP::Utils::bytelength($envelope);
      $envelope = pack('C0A*', $envelope) 
        if !$SOAP::Constants::DO_NOT_USE_LWP_LENGTH_HACK && length($envelope) != $bytelength;

      my $req = HTTP::Request->new($method => $endpoint, HTTP::Headers->new, $envelope);

      $req->proxy_authorization_basic($ENV{'HTTP_proxy_user'}, $ENV{'HTTP_proxy_pass'})
        if ($ENV{'HTTP_proxy_user'} && $ENV{'HTTP_proxy_pass'}); # by Murray Nesbitt 
  
      if ($method eq 'M-POST') {
        my $prefix = sprintf '%04d', int(rand(1000));
        $req->header(Man => qq!"$SOAP::Constants::NS_ENV"; ns=$prefix!);
        $req->header("$prefix-SOAPAction" => $action) if defined $action;  
      } else {
        $req->header(SOAPAction => $action) if defined $action;
      }
  
      # allow compress if present and let server know we could handle it
      $req->header(Accept => ['text/xml', 'multipart/*']);

      $req->header('Accept-Encoding' => [$COMPRESS]) if $self->options->{is_compress};
      $req->content_encoding($COMPRESS) if $compressed;

      $req->content_type(join '; ', 'text/xml', 
        !$SOAP::Constants::DO_NOT_USE_CHARSET && $encoding ? 'charset=' . lc($encoding) : ());
      $req->content_length($bytelength);
  
      SOAP::Trace::transport($req);
      SOAP::Trace::debug($req->as_string);
      
      $self->SUPER::env_proxy if $ENV{'HTTP_proxy'};
  
      $resp = $self->SUPER::request($req);
  
      SOAP::Trace::transport($resp);
      SOAP::Trace::debug($resp->as_string);
  
      # 100 OK, continue to read?
      if (($resp->code == 510 || $resp->code == 501) && $method ne 'M-POST') { 
        $mpost{$endpoint} = 1;
      } elsif ($resp->code == 415 && $compressed) { # 415 Unsupported Media Type
        $nocompress{$endpoint} = 1;
        $envelope = Compress::Zlib::uncompress($envelope);
        redo COMPRESS; # try again without compression
      } else {
        last;
      }
    }
  }

  $redirect{$endpoint} = $resp->request->url
    if $resp->previous && $resp->previous->is_redirect;

  $self->code($resp->code);
  $self->message($resp->message);
  $self->is_success($resp->is_success);
  $self->status($resp->status_line);

  my $content = ($resp->content_encoding || '') =~ /\b$COMPRESS\b/o && $self->options->{is_compress} 
    ? Compress::Zlib::uncompress($resp->content) 
    : ($resp->content_encoding || '') =~ /\S/ 
      ? die "Unexpected Content-Encoding '@{[$resp->content_encoding]}' returned\n"
      : $resp->content;
  $resp->content_type =~ m!^multipart/! 
    ? join("\n", $resp->headers_as_string, $content) 
    : ($resp->content_type eq 'text/xml' ||          # text/xml
       !$resp->is_success ||                         # failed request
       $SOAP::Constants::DO_NOT_CHECK_CONTENT_TYPE) 
      ? $content
      : die "Unexpected Content-Type '@{[join '; ', $resp->content_type]}' returned\n";
}

# ======================================================================

package SOAP::Transport::HTTP::Server;

use vars qw(@ISA $COMPRESS);
@ISA = qw(SOAP::Server);

use URI;

$COMPRESS = 'deflate';

sub DESTROY { SOAP::Trace::objects('()') }

sub new { require LWP::UserAgent;
  my $self = shift;

  unless (ref $self) {
    my $class = ref($self) || $self;
    $self = $class->SUPER::new(@_);
    $self->on_action(sub {
      (my $action = shift) =~ s/^("?)(.*)\1$/$2/;
      die "SOAPAction shall match 'uri#method' if present (got '$action', expected '@{[join('#', @_)]}'\n"
        if $action && $action ne join('#', @_) 
                   && $action ne join('/', @_)
                   && (substr($_[0], -1, 1) ne '/' || $action ne join('', @_));
    });
    SOAP::Trace::objects('()');
  }
  return $self;
}

sub BEGIN {
  no strict 'refs';
  for my $method (qw(request response)) {
    my $field = '_' . $method;
    *$method = sub {
      my $self = shift->new;
      @_ ? ($self->{$field} = shift, return $self) : return $self->{$field};
    }
  }
}

sub handle {
  my $self = shift->new;

  if ($self->request->method eq 'POST') {
    $self->action($self->request->header('SOAPAction') || undef);
  } elsif ($self->request->method eq 'M-POST') {
    return $self->response(HTTP::Response->new(510, # NOT EXTENDED
           "Expected Mandatory header with $SOAP::Constants::NS_ENV as unique URI")) 
      if $self->request->header('Man') !~ /^"$SOAP::Constants::NS_ENV";\s*ns\s*=\s*(\d+)/;
    $self->action($self->request->header("$1-SOAPAction") || undef);
  } else {
    return $self->response(HTTP::Response->new(405)) # METHOD NOT ALLOWED
  }

  my $compressed = ($self->request->content_encoding || '') =~ /\b$COMPRESS\b/;
  $self->options->{is_compress} ||= $compressed && eval { require Compress::Zlib };

  # signal error if content-encoding is 'deflate', but we don't want it OR
  # something else, so we don't understand it
  return $self->response(HTTP::Response->new(415)) # UNSUPPORTED MEDIA TYPE
    if $compressed && !$self->options->{is_compress} ||
       !$compressed && ($self->request->content_encoding || '') =~ /\S/;

  my $content_type = $self->request->content_type || '';
  # in some environments (PerlEx?) content_type could be empty, so allow it also
  # anyway it'll blow up inside ::Server::handle if something wrong with message
  # TBD: but what to do with MIME encoded messages in THOSE environments?
  return $self->make_fault($SOAP::Constants::FAULT_CLIENT, "Content-Type must be 'text/xml' instead of '$content_type'")
    if $content_type && 
       $content_type ne 'text/xml' && 
       $content_type !~ m!^multipart/!;

  my $content = $compressed ? Compress::Zlib::uncompress($self->request->content) : $self->request->content;
  my $response = $self->SUPER::handle(
    $self->request->content_type =~ m!^multipart/! 
      ? join("\n", $self->request->headers_as_string, $content) : $content
  ) or return;

  $self->make_response($SOAP::Constants::HTTP_ON_SUCCESS_CODE, $response);
}

sub make_fault {
  my $self = shift;
  $self->make_response($SOAP::Constants::HTTP_ON_FAULT_CODE => $self->SUPER::make_fault(@_));
  return;
}

sub make_response {
  my $self = shift;
  my($code, $response) = @_;

  my $encoding = $1 if $response =~ /^<\?xml(?: version="1.0"| encoding="([^"]+)")+\?>/;
  $response =~ s!(\?>)!$1<?xml-stylesheet type="text/css"?>! if $self->request->content_type eq 'multipart/form-data';

  $self->options->{is_compress} ||= 
    exists $self->options->{compress_threshold} && eval { require Compress::Zlib };

  my $compressed = $self->options->{is_compress} && 
                   grep(/\b($COMPRESS|\*)\b/, $self->request->header('Accept-Encoding')) &&
                   ($self->options->{compress_threshold} || 0) < SOAP::Utils::bytelength $response;
  $response = Compress::Zlib::compress($response) if $compressed;

  $self->response(HTTP::Response->new( 
     $code => undef, 
     HTTP::Headers->new(
       'SOAPServer' => $self->product_tokens,
       $compressed ? ('Content-Encoding' => $COMPRESS) : (),
       'Content-Type' => join('; ', 'text/xml', 
         !$SOAP::Constants::DO_NOT_USE_CHARSET && $encoding ? 'charset=' . lc($encoding) : ()),
       'Content-Length' => SOAP::Utils::bytelength $response), 
     $response,
  ));
}

sub product_tokens { join '/', 'SOAP::Lite', 'Perl', SOAP::Transport::HTTP->VERSION }

# ======================================================================

package SOAP::Transport::HTTP::CGI;

use vars qw(@ISA);
@ISA = qw(SOAP::Transport::HTTP::Server);

sub DESTROY { SOAP::Trace::objects('()') }

sub new { 
  my $self = shift;

  unless (ref $self) {
    my $class = ref($self) || $self;
    $self = $class->SUPER::new(@_);
    SOAP::Trace::objects('()');
  }
  return $self;
}

sub handle {
  my $self = shift->new;

  my $length = $ENV{'CONTENT_LENGTH'} || 0;

  if (!$length) {     
    $self->response(HTTP::Response->new(411)) # LENGTH REQUIRED
  } elsif (defined $SOAP::Constants::MAX_CONTENT_SIZE && $length > $SOAP::Constants::MAX_CONTENT_SIZE) {
    $self->response(HTTP::Response->new(413)) # REQUEST ENTITY TOO LARGE
  } else {
    my $content; binmode(STDIN); read(STDIN,$content,$length);
    $self->request(HTTP::Request->new( 
      $ENV{'REQUEST_METHOD'} || '' => $ENV{'SCRIPT_NAME'},
      HTTP::Headers->new(map {(/^HTTP_(.+)/i ? $1 : $_) => $ENV{$_}} keys %ENV),
      $content,
    ));
    $self->SUPER::handle;
  }

  # imitate nph- cgi for IIS (pointed by Murray Nesbitt)
  my $status = defined($ENV{'SERVER_SOFTWARE'}) && $ENV{'SERVER_SOFTWARE'}=~/IIS/
    ? $ENV{SERVER_PROTOCOL} || 'HTTP/1.0' : 'Status:';
  my $code = $self->response->code;
  binmode(STDOUT); print STDOUT 
    "$status $code ", HTTP::Status::status_message($code), 
    "\015\012", $self->response->headers_as_string, 
    "\015\012", $self->response->content;
}

# ======================================================================

package SOAP::Transport::HTTP::Daemon;

use Carp ();
use vars qw($AUTOLOAD @ISA);
@ISA = qw(SOAP::Transport::HTTP::Server);

sub DESTROY { SOAP::Trace::objects('()') }

sub new { require HTTP::Daemon; 
  my $self = shift;

  unless (ref $self) {
    my $class = ref($self) || $self;

    my(@params, @methods);
    while (@_) { $class->can($_[0]) ? push(@methods, shift() => shift) : push(@params, shift) }
    $self = $class->SUPER::new;
    $self->{_daemon} = HTTP::Daemon->new(@params) or Carp::croak "Can't create daemon: $!";
    $self->myuri(URI->new($self->url)->canonical->as_string);
    while (@methods) { my($method, $params) = splice(@methods,0,2);
      $self->$method(ref $params eq 'ARRAY' ? @$params : $params) 
    }
    SOAP::Trace::objects('()');
  }
  return $self;
}

sub AUTOLOAD {
  my $method = substr($AUTOLOAD, rindex($AUTOLOAD, '::') + 2);
  return if $method eq 'DESTROY';

  no strict 'refs';
  *$AUTOLOAD = sub { shift->{_daemon}->$method(@_) };
  goto &$AUTOLOAD;
}

sub handle {
  my $self = shift->new;
  while (my $c = $self->accept) {
    while (my $r = $c->get_request) {
      $self->request($r);
      $self->SUPER::handle;
      $c->send_response($self->response)
    }
    # replaced ->close, thanks to Sean Meisner <Sean.Meisner@VerizonWireless.com>
    # shutdown() doesn't work on AIX. close() is used in this case. Thanks to Jos Clijmans <jos.clijmans@recyfin.be>
    UNIVERSAL::isa($c, 'shutdown') ? $c->shutdown(2) : $c->close(); 
    undef $c;
  }
}

# ======================================================================

package SOAP::Transport::HTTP::Apache;

use vars qw(@ISA);
@ISA = qw(SOAP::Transport::HTTP::Server);

sub DESTROY { SOAP::Trace::objects('()') }

sub new { require Apache; require Apache::Constants;
  my $self = shift;

  unless (ref $self) {
    my $class = ref($self) || $self;
    $self = $class->SUPER::new(@_);
    SOAP::Trace::objects('()');
  }
  return $self;
}

sub handler { 
  my $self = shift->new; 
  my $r = shift || Apache->request; 

  $self->request(HTTP::Request->new( 
    $r->method => $r->uri,
    HTTP::Headers->new($r->headers_in),
    do { my $buf; $r->read($buf, $r->header_in('Content-length')); $buf; } 
  ));
  $self->SUPER::handle;

  # we will specify status manually for Apache, because
  # if we do it as it has to be done, returning SERVER_ERROR,
  # Apache will modify our content_type to 'text/html; ....'
  # which is not what we want.
  # will emulate normal response, but with custom status code 
  # which could also be 500.
  $r->status($self->response->code);
  $self->response->headers->scan(sub { $r->header_out(@_) });
  $r->send_http_header(join '; ', $self->response->content_type);
  $r->print($self->response->content);
  &Apache::Constants::OK;
}

sub configure {
  my $self = shift->new;
  my $config = shift->dir_config;
  foreach (%$config) {
    $config->{$_} =~ /=>/
      ? $self->$_({split /\s*(?:=>|,)\s*/, $config->{$_}})
      : ref $self->$_() ? () # hm, nothing can be done here
                        : $self->$_(split /\s+|\s*,\s*/, $config->{$_})
      if $self->can($_);
  }
  $self;
}

{ sub handle; *handle = \&handler } # just create alias

# ======================================================================
#
# Copyright (C) 2001 Single Source oy (marko.asplund@kronodoc.fi)
# a FastCGI transport class for SOAP::Lite.
#
# ======================================================================

package SOAP::Transport::HTTP::FCGI;

use vars qw(@ISA);
@ISA = qw(SOAP::Transport::HTTP::CGI);

sub DESTROY { SOAP::Trace::objects('()') }

sub new { require FCGI; Exporter::require_version('FCGI' => 0.47); # requires thread-safe interface
  my $self = shift;

  if (!ref($self)) {
    my $class = ref($self) || $self;
    $self = $class->SUPER::new(@_);
    $self->{_fcgirq} = FCGI::Request(\*STDIN, \*STDOUT, \*STDERR);
    SOAP::Trace::objects('()');
  }
  return $self;
}

sub handle {
  my $self = shift->new;

  my ($r1, $r2);
  my $fcgirq = $self->{_fcgirq};

  while (($r1 = $fcgirq->Accept()) >= 0) {
    $r2 = $self->SUPER::handle;
  }

  return undef;
}

# ======================================================================

1;

__END__

