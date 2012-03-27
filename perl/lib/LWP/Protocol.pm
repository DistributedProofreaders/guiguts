package LWP::Protocol;

# $Id: Protocol.pm,v 1.41 2003/10/23 19:11:32 uid39246 Exp $

require LWP::MemberMixin;
@ISA = qw(LWP::MemberMixin);
$VERSION = sprintf("%d.%02d", q$Revision: 1.41 $ =~ /(\d+)\.(\d+)/);

use strict;
use Carp ();
use HTTP::Status ();
use HTTP::Response;

my %ImplementedBy = (); # scheme => classname



sub new
{
    my($class, $scheme, $ua) = @_;

    my $self = bless {
	scheme => $scheme,
	ua => $ua,

	# historical/redundant
        parse_head => $ua->{parse_head},
        max_size => $ua->{max_size},
    }, $class;

    $self;
}


sub create
{
    my($scheme, $ua) = @_;
    my $impclass = LWP::Protocol::implementor($scheme) or
	Carp::croak("Protocol scheme '$scheme' is not supported");

    # hand-off to scheme specific implementation sub-class
    my $protocol = $impclass->new($scheme, $ua);

    return $protocol;
}


sub implementor
{
    my($scheme, $impclass) = @_;

    if ($impclass) {
	$ImplementedBy{$scheme} = $impclass;
    }
    my $ic = $ImplementedBy{$scheme};
    return $ic if $ic;

    return '' unless $scheme =~ /^([.+\-\w]+)$/;  # check valid URL schemes
    $scheme = $1; # untaint
    $scheme =~ s/[.+\-]/_/g;  # make it a legal module name

    # scheme not yet known, look for a 'use'd implementation
    $ic = "LWP::Protocol::$scheme";  # default location
    $ic = "LWP::Protocol::nntp" if $scheme eq 'news'; #XXX ugly hack
    no strict 'refs';
    # check we actually have one for the scheme:
    unless (@{"${ic}::ISA"}) {
	# try to autoload it
	eval "require $ic";
	if ($@) {
	    if ($@ =~ /Can't locate/) { #' #emacs get confused by '
		$ic = '';
	    }
	    else {
		die "$@\n";
	    }
	}
    }
    $ImplementedBy{$scheme} = $ic if $ic;
    $ic;
}


sub request
{
    my($self, $request, $proxy, $arg, $size, $timeout) = @_;
    Carp::croak('LWP::Protocol::request() needs to be overridden in subclasses');
}


# legacy
sub timeout    { shift->_elem('timeout',    @_); }
sub parse_head { shift->_elem('parse_head', @_); }
sub max_size   { shift->_elem('max_size',   @_); }


sub collect
{
    my ($self, $arg, $response, $collector) = @_;
    my $content;
    my($parse_head, $max_size) = @{$self}{qw(parse_head max_size)};

    my $parser;
    if ($parse_head && $response->content_type eq 'text/html') {
	require HTML::HeadParser;
	$parser = HTML::HeadParser->new($response->{'_headers'});
    }
    my $content_size = 0;

    if (!defined($arg) || !$response->is_success) {
	# scalar
	while ($content = &$collector, length $$content) {
	    if ($parser) {
		$parser->parse($$content) or undef($parser);
	    }
	    LWP::Debug::debug("read " . length($$content) . " bytes");
	    $response->add_content($$content);
	    $content_size += length($$content);
	    if (defined($max_size) && $content_size > $max_size) {
		LWP::Debug::debug("Aborting because size limit exceeded");
		$response->push_header("Client-Aborted", "max_size");
		#my $tot = $response->header("Content-Length") || 0;
		#$response->header("X-Content-Range", "bytes 0-$content_size/$tot");
		last;
	    }
	}
    }
    elsif (!ref($arg)) {
	# filename
	open(OUT, ">$arg") or
	    return HTTP::Response->new(&HTTP::Status::RC_INTERNAL_SERVER_ERROR,
			  "Cannot write to '$arg': $!");
        binmode(OUT);
        local($\) = ""; # ensure standard $OUTPUT_RECORD_SEPARATOR
	while ($content = &$collector, length $$content) {
	    if ($parser) {
		$parser->parse($$content) or undef($parser);
	    }
	    LWP::Debug::debug("read " . length($$content) . " bytes");
	    print OUT $$content;
	    $content_size += length($$content);
	    if (defined($max_size) && $content_size > $max_size) {
		LWP::Debug::debug("Aborting because size limit exceeded");
		$response->push_header("Client-Aborted", "max_size");
		#my $tot = $response->header("Content-Length") || 0;
		#$response->header("X-Content-Range", "bytes 0-$content_size/$tot");
		last;
	    }
	}
	close(OUT);
    }
    elsif (ref($arg) eq 'CODE') {
	# read into callback
	while ($content = &$collector, length $$content) {
	    if ($parser) {
		$parser->parse($$content) or undef($parser);
	    }
	    LWP::Debug::debug("read " . length($$content) . " bytes");
            eval {
		&$arg($$content, $response, $self);
	    };
	    if ($@) {
	        chomp($@);
		$response->push_header('X-Died' => $@);
		$response->push_header("Client-Aborted", "die");
		last;
	    }
	}
    }
    else {
	return HTTP::Response->new(&HTTP::Status::RC_INTERNAL_SERVER_ERROR,
				  "Unexpected collect argument  '$arg'");
    }
    $response;
}


sub collect_once
{
    my($self, $arg, $response) = @_;
    my $content = \ $_[3];
    my $first = 1;
    $self->collect($arg, $response, sub {
	return $content if $first--;
	return \ "";
    });
}

1;


__END__

