package HTML::PullParser;

# $Id: PullParser.pm,v 2.7 2003/10/10 09:56:18 gisle Exp $

require HTML::Parser;
@ISA=qw(HTML::Parser);
$VERSION = sprintf("%d.%02d", q$Revision: 2.7 $ =~ /(\d+)\.(\d+)/);

use strict;
use Carp ();

sub new
{
    my($class, %cnf) = @_;

    # Construct argspecs for the various events
    my %argspec;
    for (qw(start end text declaration comment process default)) {
	my $tmp = delete $cnf{$_};
	next unless defined $tmp;
	$argspec{$_} = $tmp;
    }
    Carp::croak("Info not collected for any events")
	  unless %argspec;

    my $file = delete $cnf{file};
    my $doc  = delete $cnf{doc};
    Carp::croak("Can't parse from both 'doc' and 'file' at the same time")
	  if defined($file) && defined($doc);
    Carp::croak("No 'doc' or 'file' given to parse from")
	  unless defined($file) || defined($doc);

    # Create object
    $cnf{api_version} = 3;
    my $self = $class->SUPER::new(%cnf);

    my $accum = $self->{pullparser_accum} = [];
    while (my($event, $argspec) = each %argspec) {
	$self->SUPER::handler($event => $accum, $argspec);
    }

    if (defined $doc) {
	$self->{pullparser_str_ref} = ref($doc) ? $doc : \$doc;
	$self->{pullparser_str_pos} = 0;
    }
    else {
	if (!ref($file) && ref(\$file) ne "GLOB") {
	    require IO::File;
	    $file = IO::File->new($file, "r") || return;
	}

	$self->{pullparser_file} = $file;
    }
    $self;
}


sub handler
{
    Carp::croak("Can't set handlers for HTML::PullParser");
}


sub get_token
{
    my $self = shift;
    while (!@{$self->{pullparser_accum}} && !$self->{pullparser_eof}) {
	if (my $f = $self->{pullparser_file}) {
	    # must try to parse more from the file
	    my $buf;
	    if (read($f, $buf, 512)) {
		$self->parse($buf);
	    } else {
		$self->eof;
		$self->{pullparser_eof}++;
		delete $self->{pullparser_file};
	    }
	}
	elsif (my $sref = $self->{pullparser_str_ref}) {
	    # must try to parse more from the scalar
	    my $pos = $self->{pullparser_str_pos};
	    my $chunk = substr($$sref, $pos, 512);
	    $self->parse($chunk);
	    $pos += length($chunk);
	    if ($pos < length($$sref)) {
		$self->{pullparser_str_pos} = $pos;
	    }
	    else {
		$self->eof;
		$self->{pullparser_eof}++;
		delete $self->{pullparser_str_ref};
		delete $self->{pullparser_str_pos};
	    }
	}
	else {
	    die;
	}
    }
    shift @{$self->{pullparser_accum}};
}


sub unget_token
{
    my $self = shift;
    unshift @{$self->{pullparser_accum}}, @_;
    $self;
}

1;


__END__

