package HTTP::Response;

# $Id: Response.pm,v 1.41 2003/10/24 10:25:16 gisle Exp $

require HTTP::Message;
@ISA = qw(HTTP::Message);
$VERSION = sprintf("%d.%02d", q$Revision: 1.41 $ =~ /(\d+)\.(\d+)/);

use strict;
use HTTP::Status ();



sub new
{
    my($class, $rc, $msg, $header, $content) = @_;
    my $self = $class->SUPER::new($header, $content);
    $self->code($rc);
    $self->message($msg);
    $self;
}


sub clone
{
    my $self = shift;
    my $clone = bless $self->SUPER::clone, ref($self);
    $clone->code($self->code);
    $clone->message($self->message);
    $clone->request($self->request->clone) if $self->request;
    # we don't clone previous
    $clone;
}


sub code      { shift->_elem('_rc',      @_); }
sub message   { shift->_elem('_msg',     @_); }
sub previous  { shift->_elem('_previous',@_); }
sub request   { shift->_elem('_request', @_); }


sub status_line
{
    my $self = shift;
    my $code = $self->{'_rc'}  || "000";
    my $mess = $self->{'_msg'} || HTTP::Status::status_message($code) || "?";
    return "$code $mess";
}


sub base
{
    my $self = shift;
    my $base = $self->header('Content-Base')     ||  # used to be HTTP/1.1
               $self->header('Content-Location') ||  # HTTP/1.1
               $self->header('Base');                # HTTP/1.0
    return $HTTP::URI_CLASS->new_abs($base, $self->request->uri);
    # So yes, if $base is undef, the return value is effectively
    # just a copy of $self->request->uri.
}


sub as_string
{
    require HTTP::Status;
    my $self = shift;
    my @result;
    #push(@result, "---- $self ----");
    my $code = $self->code;
    my $status_message = HTTP::Status::status_message($code) || "Unknown code";
    my $message = $self->message || "";

    my $status_line = "$code";
    my $proto = $self->protocol;
    $status_line = "$proto $status_line" if $proto;
    $status_line .= " ($status_message)" if $status_message ne $message;
    $status_line .= " $message";
    push(@result, $status_line);
    push(@result, $self->headers_as_string);
    my $content = $self->content;
    if (defined $content) {
	push(@result, $content);
    }
    #push(@result, ("-" x 40));
    join("\n", @result, "");
}


sub is_info     { HTTP::Status::is_info     (shift->{'_rc'}); }
sub is_success  { HTTP::Status::is_success  (shift->{'_rc'}); }
sub is_redirect { HTTP::Status::is_redirect (shift->{'_rc'}); }
sub is_error    { HTTP::Status::is_error    (shift->{'_rc'}); }


sub error_as_HTML
{
    my $self = shift;
    my $title = 'An Error Occurred';
    my $body  = $self->status_line;
    return <<EOM;
<HTML>
<HEAD><TITLE>$title</TITLE></HEAD>
<BODY>
<H1>$title</H1>
$body
</BODY>
</HTML>
EOM
}


sub current_age
{
    my $self = shift;
    # Implementation of <draft-ietf-http-v11-spec-07> section 13.2.3
    # (age calculations)
    my $response_time = $self->client_date;
    my $date = $self->date;

    my $age = 0;
    if ($response_time && $date) {
	$age = $response_time - $date;  # apparent_age
	$age = 0 if $age < 0;
    }

    my $age_v = $self->header('Age');
    if ($age_v && $age_v > $age) {
	$age = $age_v;   # corrected_received_age
    }

    my $request = $self->request;
    if ($request) {
	my $request_time = $request->date;
	if ($request_time) {
	    # Add response_delay to age to get 'corrected_initial_age'
	    $age += $response_time - $request_time;
	}
    }
    if ($response_time) {
	$age += time - $response_time;
    }
    return $age;
}


sub freshness_lifetime
{
    my $self = shift;

    # First look for the Cache-Control: max-age=n header
    my @cc = $self->header('Cache-Control');
    if (@cc) {
	my $cc;
	for $cc (@cc) {
	    my $cc_dir;
	    for $cc_dir (split(/\s*,\s*/, $cc)) {
		if ($cc_dir =~ /max-age\s*=\s*(\d+)/i) {
		    return $1;
		}
	    }
	}
    }

    # Next possibility is to look at the "Expires" header
    my $date = $self->date || $self->client_date || time;      
    my $expires = $self->expires;
    unless ($expires) {
	# Must apply heuristic expiration
	my $last_modified = $self->last_modified;
	if ($last_modified) {
	    my $h_exp = ($date - $last_modified) * 0.10;  # 10% since last-mod
	    if ($h_exp < 60) {
		return 60;  # minimum
	    }
	    elsif ($h_exp > 24 * 3600) {
		# Should give a warning if more than 24 hours according to
		# <draft-ietf-http-v11-spec-07> section 13.2.4, but I don't
		# know how to do it from this function interface, so I just
		# make this the maximum value.
		return 24 * 3600;
	    }
	    return $h_exp;
	}
	else {
	    return 3600;  # 1 hour is fallback when all else fails
	}
    }
    return $expires - $date;
}


sub is_fresh
{
    my $self = shift;
    $self->freshness_lifetime > $self->current_age;
}


sub fresh_until
{
    my $self = shift;
    return $self->freshness_lifetime - $self->current_age + time;
}

1;


__END__

