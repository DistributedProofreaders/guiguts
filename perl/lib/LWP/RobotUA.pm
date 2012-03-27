package LWP::RobotUA;

# $Id: RobotUA.pm,v 1.23 2003/10/24 11:13:03 gisle Exp $

require LWP::UserAgent;
@ISA = qw(LWP::UserAgent);
$VERSION = sprintf("%d.%02d", q$Revision: 1.23 $ =~ /(\d+)\.(\d+)/);

require WWW::RobotRules;
require HTTP::Request;
require HTTP::Response;

use Carp ();
use LWP::Debug ();
use HTTP::Status ();
use HTTP::Date qw(time2str);
use strict;


#
# Additional attributes in addition to those found in LWP::UserAgent:
#
# $self->{'delay'}    Required delay between request to the same
#                     server in minutes.
#
# $self->{'rules'}     A WWW::RobotRules object
#

sub new
{
    my($class,$name,$from,$rules) = @_;

    Carp::croak('LWP::RobotUA name required') unless $name;
    Carp::croak('LWP::RobotUA from address required') unless $from
     and $from =~ m/\@/;

    my $self = new LWP::UserAgent;
    $self = bless $self, $class;

    $self->{'delay'} = 1;   # minutes
    $self->{'agent'} = $name;
    $self->{'from'}  = $from;
    $self->{'use_sleep'} = 1;

    if ($rules) {
	$rules->agent($name);
	$self->{'rules'} = $rules;
    }
    else {
	$self->{'rules'} = new WWW::RobotRules $name;
    }

    $self;
}


sub delay     { shift->_elem('delay',     @_); }
sub use_sleep { shift->_elem('use_sleep', @_); }


sub agent
{
    my $self = shift;
    my $old = $self->SUPER::agent(@_);
    if (@_) {
	# Changing our name means to start fresh
	$self->{'rules'}->agent($self->{'agent'}); 
    }
    $old;
}


sub rules {
    my $self = shift;
    my $old = $self->_elem('rules', @_);
    $self->{'rules'}->agent($self->{'agent'}) if @_;
    $old;
}


sub no_visits
{
    my($self, $netloc) = @_;
    $self->{'rules'}->no_visits($netloc) || 0;
}

*host_count = \&no_visits;  # backwards compatibility with LWP-5.02


sub host_wait
{
    my($self, $netloc) = @_;
    return undef unless defined $netloc;
    my $last = $self->{'rules'}->last_visit($netloc);
    if ($last) {
	my $wait = int($self->{'delay'} * 60 - (time - $last));
	$wait = 0 if $wait < 0;
	return $wait;
    }
    return 0;
}


sub simple_request
{
    my($self, $request, $arg, $size) = @_;

    LWP::Debug::trace('()');

    # Do we try to access a new server?
    my $allowed = $self->{'rules'}->allowed($request->url);

    if ($allowed < 0) {
	LWP::Debug::debug("Host is not visited before, or robots.txt expired.");
	# fetch "robots.txt"
	my $robot_url = $request->url->clone;
	$robot_url->path("robots.txt");
	$robot_url->query(undef);
	LWP::Debug::debug("Requesting $robot_url");

	# make access to robot.txt legal since this will be a recursive call
	$self->{'rules'}->parse($robot_url, ""); 

	my $robot_req = new HTTP::Request 'GET', $robot_url;
	my $robot_res = $self->request($robot_req);
	my $fresh_until = $robot_res->fresh_until;
	if ($robot_res->is_success) {
	    my $c = $robot_res->content;
	    if ($robot_res->content_type =~ m,^text/, && $c =~ /Disallow/) {
		LWP::Debug::debug("Parsing robot rules");
		$self->{'rules'}->parse($robot_url, $c, $fresh_until);
	    }
	    else {
		LWP::Debug::debug("Ignoring robots.txt");
		$self->{'rules'}->parse($robot_url, "", $fresh_until);
	    }

	}
	else {
	    LWP::Debug::debug("No robots.txt file found");
	    $self->{'rules'}->parse($robot_url, "", $fresh_until);
	}

	# recalculate allowed...
	$allowed = $self->{'rules'}->allowed($request->url);
    }

    # Check rules
    unless ($allowed) {
	my $res = new HTTP::Response
	  &HTTP::Status::RC_FORBIDDEN, 'Forbidden by robots.txt';
	$res->request( $request ); # bind it to that request
	return $res;
    }

    my $netloc = eval { local $SIG{__DIE__}; $request->url->host_port; };
    my $wait = $self->host_wait($netloc);

    if ($wait) {
	LWP::Debug::debug("Must wait $wait seconds");
	if ($self->{'use_sleep'}) {
	    sleep($wait)
	}
	else {
	    my $res = new HTTP::Response
	      &HTTP::Status::RC_SERVICE_UNAVAILABLE, 'Please, slow down';
	    $res->header('Retry-After', time2str(time + $wait));
	    $res->request( $request ); # bind it to that request
	    return $res;
	}
    }

    # Perform the request
    my $res = $self->SUPER::simple_request($request, $arg, $size);

    $self->{'rules'}->visit($netloc);

    $res;
}


sub as_string
{
    my $self = shift;
    my @s;
    push(@s, "Robot: $self->{'agent'} operated by $self->{'from'}  [$self]");
    push(@s, "    Minimum delay: " . int($self->{'delay'}*60) . "s");
    push(@s, "    Will sleep if too early") if $self->{'use_sleep'};
    push(@s, "    Rules = $self->{'rules'}");
    join("\n", @s, '');
}

1;


__END__

