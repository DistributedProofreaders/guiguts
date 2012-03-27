package HTTP::Headers;

# $Id: Headers.pm,v 1.47 2003/10/23 19:11:32 uid39246 Exp $

use strict;
use Carp ();

use vars qw($VERSION $TRANSLATE_UNDERSCORE);
$VERSION = sprintf("%d.%02d", q$Revision: 1.47 $ =~ /(\d+)\.(\d+)/);

# The $TRANSLATE_UNDERSCORE variable controls whether '_' can be used
# as a replacement for '-' in header field names.
$TRANSLATE_UNDERSCORE = 1 unless defined $TRANSLATE_UNDERSCORE;

# "Good Practice" order of HTTP message headers:
#    - General-Headers
#    - Request-Headers
#    - Response-Headers
#    - Entity-Headers

my @header_order = qw(
   Cache-Control Connection Date Pragma Trailer Transfer-Encoding Upgrade
   Via Warning

   Accept Accept-Charset Accept-Encoding Accept-Language
   Authorization Expect From Host
   If-Match If-Modified-Since If-None-Match If-Range If-Unmodified-Since
   Max-Forwards Proxy-Authorization Range Referer TE User-Agent

   Accept-Ranges Age ETag Location Proxy-Authenticate Retry-After Server
   Vary WWW-Authenticate

   Allow Content-Encoding Content-Language Content-Length Content-Location
   Content-MD5 Content-Range Content-Type Expires Last-Modified
);

# Make alternative representations of @header_order.  This is used
# for sorting and case matching.
my %header_order;
my %standard_case;

{
    my $i = 0;
    for (@header_order) {
	my $lc = lc $_;
	$header_order{$lc} = ++$i;
	$standard_case{$lc} = $_;
    }
}



sub new
{
    my($class) = shift;
    my $self = bless {}, $class;
    $self->header(@_); # set up initial headers
    $self;
}


sub header
{
    my $self = shift;
    my(@old);
    while (my($field, $val) = splice(@_, 0, 2)) {
	@old = $self->_header($field, $val);
    }
    return @old if wantarray;
    return $old[0] if @old <= 1;
    join(", ", @old);
}


sub push_header
{
    Carp::croak('Usage: $h->push_header($field, $val)') if @_ != 3;
    shift->_header(@_, 'PUSH');
}


sub init_header
{
    Carp::croak('Usage: $h->init_header($field, $val)') if @_ != 3;
    shift->_header(@_, 'INIT');
}


sub remove_header
{
    my($self, @fields) = @_;
    my $field;
    my @values;
    foreach $field (@fields) {
	$field =~ tr/_/-/ if $TRANSLATE_UNDERSCORE;
	my $v = delete $self->{lc $field};
	push(@values, ref($v) eq 'ARRAY' ? @$v : $v) if defined $v;
    }
    return @values;
}


sub _header
{
    my($self, $field, $val, $op) = @_;
    $field =~ tr/_/-/ if $TRANSLATE_UNDERSCORE;

    # $push is only used interally sub push_header
    Carp::croak('Need a field name') unless length($field);

    my $lc_field = lc $field;
    unless(defined $standard_case{$lc_field}) {
	# generate a %standard_case entry for this field
	$field =~ s/\b(\w)/\u$1/g;
	$standard_case{$lc_field} = $field;
    }

    my $h = $self->{$lc_field};
    my @old = ref($h) eq 'ARRAY' ? @$h : (defined($h) ? ($h) : ());

    $op ||= "";
    $val = undef if $op eq 'INIT' && @old;
    if (defined($val)) {
	my @new = ($op eq 'PUSH') ? @old : ();
	if (ref($val) ne 'ARRAY') {
	    push(@new, $val);
	}
	else {
	    push(@new, @$val);
	}
	$self->{$lc_field} = @new > 1 ? \@new : $new[0];
    }
    @old;
}


# Compare function which makes it easy to sort headers in the
# recommended "Good Practice" order.
sub _header_cmp
{
    ($header_order{$a} || 999) <=> ($header_order{$b} || 999) || $a cmp $b;
}


sub scan
{
    my($self, $sub) = @_;
    my $key;
    foreach $key (sort _header_cmp keys %$self) {
        next if $key =~ /^_/;
	my $vals = $self->{$key};
	if (ref($vals) eq 'ARRAY') {
	    my $val;
	    for $val (@$vals) {
		&$sub($standard_case{$key} || $key, $val);
	    }
	}
	else {
	    &$sub($standard_case{$key} || $key, $vals);
	}
    }
}


sub as_string
{
    my($self, $endl) = @_;
    $endl = "\n" unless defined $endl;

    my @result = ();
    $self->scan(sub {
	my($field, $val) = @_;
	if ($val =~ /\n/) {
	    # must handle header values with embedded newlines with care
	    $val =~ s/\s+$//;          # trailing newlines and space must go
	    $val =~ s/\n\n+/\n/g;      # no empty lines
	    $val =~ s/\n([^\040\t])/\n $1/g;  # intial space for continuation
	    $val =~ s/\n/$endl/g;      # substitute with requested line ending
	}
	push(@result, "$field: $val");
    });

    join($endl, @result, '');
}


sub clone
{
    my $self = shift;
    my $clone = new HTTP::Headers;
    $self->scan(sub { $clone->push_header(@_);} );
    $clone;
}


sub _date_header
{
    require HTTP::Date;
    my($self, $header, $time) = @_;
    my($old) = $self->_header($header);
    if (defined $time) {
	$self->_header($header, HTTP::Date::time2str($time));
    }
    HTTP::Date::str2time($old);
}


sub date                { shift->_date_header('Date',                @_); }
sub expires             { shift->_date_header('Expires',             @_); }
sub if_modified_since   { shift->_date_header('If-Modified-Since',   @_); }
sub if_unmodified_since { shift->_date_header('If-Unmodified-Since', @_); }
sub last_modified       { shift->_date_header('Last-Modified',       @_); }

# This is used as a private LWP extention.  The Client-Date header is
# added as a timestamp to a response when it has been received.
sub client_date         { shift->_date_header('Client-Date',         @_); }

# The retry_after field is dual format (can also be a expressed as
# number of seconds from now), so we don't provide an easy way to
# access it until we have know how both these interfaces can be
# addressed.  One possibility is to return a negative value for
# relative seconds and a positive value for epoch based time values.
#sub retry_after       { shift->_date_header('Retry-After',       @_); }

sub content_type      {
  my $ct = (shift->_header('Content-Type', @_))[0];
  return '' unless defined($ct) && length($ct);
  my @ct = split(/\s*;\s*/, lc($ct));
  wantarray ? @ct : $ct[0];
}

sub title             { (shift->_header('Title',            @_))[0] }
sub content_encoding  { (shift->_header('Content-Encoding', @_))[0] }
sub content_language  { (shift->_header('Content-Language', @_))[0] }
sub content_length    { (shift->_header('Content-Length',   @_))[0] }

sub user_agent        { (shift->_header('User-Agent',       @_))[0] }
sub server            { (shift->_header('Server',           @_))[0] }

sub from              { (shift->_header('From',             @_))[0] }
sub referer           { (shift->_header('Referer',          @_))[0] }
*referrer = \&referer;  # on tchrist's request
sub warning           { (shift->_header('Warning',          @_))[0] }

sub www_authenticate  { (shift->_header('WWW-Authenticate', @_))[0] }
sub authorization     { (shift->_header('Authorization',    @_))[0] }

sub proxy_authenticate  { (shift->_header('Proxy-Authenticate',  @_))[0] }
sub proxy_authorization { (shift->_header('Proxy-Authorization', @_))[0] }

sub authorization_basic       { shift->_basic_auth("Authorization",       @_) }
sub proxy_authorization_basic { shift->_basic_auth("Proxy-Authorization", @_) }

sub _basic_auth {
    require MIME::Base64;
    my($self, $h, $user, $passwd) = @_;
    my($old) = $self->_header($h);
    if (defined $user) {
	Carp::croak("Basic authorization user name can't contain ':'")
	  if $user =~ /:/;
	$passwd = '' unless defined $passwd;
	$self->_header($h => 'Basic ' .
                             MIME::Base64::encode("$user:$passwd", ''));
    }
    if (defined $old && $old =~ s/^\s*Basic\s+//) {
	my $val = MIME::Base64::decode($old);
	return $val unless wantarray;
	return split(/:/, $val, 2);
    }
    return;
}


1;

__END__

