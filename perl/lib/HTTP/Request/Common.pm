# $Id: Common.pm,v 1.22 2003/10/23 19:11:32 uid39246 Exp $
#
package HTTP::Request::Common;

use strict;
use vars qw(@EXPORT @EXPORT_OK $VERSION $DYNAMIC_FILE_UPLOAD);

$DYNAMIC_FILE_UPLOAD ||= 0;  # make it defined (don't know why)

require Exporter;
*import = \&Exporter::import;
@EXPORT =qw(GET HEAD PUT POST);
@EXPORT_OK = qw($DYNAMIC_FILE_UPLOAD);

require HTTP::Request;
use Carp();

$VERSION = sprintf("%d.%02d", q$Revision: 1.22 $ =~ /(\d+)\.(\d+)/);

my $CRLF = "\015\012";   # "\r\n" is not portable

sub GET  { _simple_req('GET',  @_); }
sub HEAD { _simple_req('HEAD', @_); }
sub PUT  { _simple_req('PUT' , @_); }

sub POST
{
    my $url = shift;
    my $req = HTTP::Request->new(POST => $url);
    my $content;
    $content = shift if @_ and ref $_[0];
    my($k, $v);
    while (($k,$v) = splice(@_, 0, 2)) {
	if (lc($k) eq 'content') {
	    $content = $v;
	}
	else {
	    $req->push_header($k, $v);
	}
    }
    my $ct = $req->header('Content-Type');
    unless ($ct) {
	$ct = 'application/x-www-form-urlencoded';
    }
    elsif ($ct eq 'form-data') {
	$ct = 'multipart/form-data';
    }

    if (ref $content) {
	if ($ct =~ m,^multipart/form-data\s*(;|$),i) {
	    require HTTP::Headers::Util;
	    my @v = HTTP::Headers::Util::split_header_words($ct);
	    Carp::carp("Multiple Content-Type headers") if @v > 1;
	    @v = @{$v[0]};

	    my $boundary;
	    my $boundary_index;
	    for (my @tmp = @v; @tmp;) {
		my($k, $v) = splice(@tmp, 0, 2);
		if (lc($k) eq "boundary") {
		    $boundary = $v;
		    $boundary_index = @v - @tmp - 1;
		    last;
		}
	    }

	    ($content, $boundary) = form_data($content, $boundary, $req);

	    if ($boundary_index) {
		$v[$boundary_index] = $boundary;
	    }
	    else {
		push(@v, boundary => $boundary);
	    }

	    $ct = HTTP::Headers::Util::join_header_words(@v);
	}
	else {
	    # We use a temporary URI object to format
	    # the application/x-www-form-urlencoded content.
	    require URI;
	    my $url = URI->new('http:');
	    $url->query_form(ref($content) eq "HASH" ? %$content : @$content);
	    $content = $url->query;
	}
    }

    $req->header('Content-Type' => $ct);  # might be redundant
    if (defined($content)) {
	$req->header('Content-Length' =>
		     length($content)) unless ref($content);
	$req->content($content);
    }
    else {
        $req->header('Content-Length' => 0);
    }
    $req;
}


sub _simple_req
{
    my($method, $url) = splice(@_, 0, 2);
    my $req = HTTP::Request->new($method => $url);
    my($k, $v);
    while (($k,$v) = splice(@_, 0, 2)) {
	if (lc($k) eq 'content') {
	    $req->add_content($v);
	}
	else {
	    $req->push_header($k, $v);
	}
    }
    $req;
}


sub form_data   # RFC1867
{
    my($data, $boundary, $req) = @_;
    my @data = ref($data) eq "HASH" ? %$data : @$data;  # copy
    my $fhparts;
    my @parts;
    my($k,$v);
    while (($k,$v) = splice(@data, 0, 2)) {
	if (!ref($v)) {
	    $k =~ s/([\\\"])/\\$1/g;  # escape quotes and backslashes
	    push(@parts,
		 qq(Content-Disposition: form-data; name="$k"$CRLF$CRLF$v));
	}
	else {
	    my($file, $usename, @headers) = @$v;
	    unless (defined $usename) {
		$usename = $file;
		$usename =~ s,.*/,, if defined($usename);
	    }
	    my $disp = qq(form-data; name="$k");
	    $disp .= qq(; filename="$usename") if $usename;
	    my $content = "";
	    my $h = HTTP::Headers->new(@headers);
	    my $ct = $h->header("Content-Type");
	    if ($file) {
		require Symbol;
		my $fh = Symbol::gensym();
		open($fh, $file) or Carp::croak("Can't open file $file: $!");
		binmode($fh);
		if ($DYNAMIC_FILE_UPLOAD) {
		    # will read file later
		    $content = $fh;
		}
		else {
		    local($/) = undef; # slurp files
		    $content = <$fh>;
		    close($fh);
		    $h->header("Content-Length" => length($content));
		}
		unless ($ct) {
		    require LWP::MediaTypes;
		    $ct = LWP::MediaTypes::guess_media_type($file, $h);
		}
	    }
	    if ($h->header("Content-Disposition")) {
		# just to get it sorted first
		$disp = $h->header("Content-Disposition");
		$h->remove_header("Content-Disposition");
	    }
	    if ($h->header("Content")) {
		$content = $h->header("Content");
		$h->remove_header("Content");
	    }
	    my $head = join($CRLF, "Content-Disposition: $disp",
			           $h->as_string($CRLF),
			           "");
	    if (ref $content) {
		push(@parts, [$head, $content]);
		$fhparts++;
	    }
	    else {
		push(@parts, $head . $content);
	    }
	}
    }
    return "" unless @parts;

    my $content;
    if ($fhparts) {
	$boundary = boundary(10) # hopefully enough randomness
	    unless $boundary;

	# add the boundaries to the @parts array
	for (1..@parts-1) {
	    splice(@parts, $_*2-1, 0, "$CRLF--$boundary$CRLF");
	}
	unshift(@parts, "--$boundary$CRLF");
	push(@parts, "$CRLF--$boundary--$CRLF");

	# See if we can generate Content-Length header
	my $length = 0;
	for (@parts) {
	    if (ref $_) {
	 	my ($head, $f) = @$_;
		my $file_size;
		unless ( -f $f && ($file_size = -s _) ) {
		    # The file is either a dynamic file like /dev/audio
		    # or perhaps a file in the /proc file system where
		    # stat may return a 0 size even though reading it
		    # will produce data.  So we cannot make
		    # a Content-Length header.  
		    undef $length;
		    last;
		}
	    	$length += $file_size + length $head;
	    }
	    else {
		$length += length;
	    }
        }
        $length && $req->header('Content-Length' => $length);

	# set up a closure that will return content piecemeal
	$content = sub {
	    for (;;) {
		unless (@parts) {
		    defined $length && $length != 0 &&
		    	Carp::croak "length of data sent did not match calculated Content-Length header.  Probably because uploaded file changed in size during transfer.";
		    return;
		}
		my $p = shift @parts;
		unless (ref $p) {
		    $p .= shift @parts while @parts && !ref($parts[0]);
		    defined $length && ($length -= length $p);
		    return $p;
		}
		my($buf, $fh) = @$p;
		my $buflength = length $buf;
		my $n = read($fh, $buf, 2048, $buflength);
		if ($n) {
		    $buflength += $n;
		    unshift(@parts, ["", $fh]);
		}
		else {
		    close($fh);
		}
		if ($buflength) {
		    defined $length && ($length -= $buflength);
		    return $buf 
	    	}
	    }
	};

    }
    else {
	$boundary = boundary() unless $boundary;

	my $bno = 0;
      CHECK_BOUNDARY:
	{
	    for (@parts) {
		if (index($_, $boundary) >= 0) {
		    # must have a better boundary
		    $boundary = boundary(++$bno);
		    redo CHECK_BOUNDARY;
		}
	    }
	    last;
	}
	$content = "--$boundary$CRLF" .
	           join("$CRLF--$boundary$CRLF", @parts) .
		   "$CRLF--$boundary--$CRLF";
    }

    wantarray ? ($content, $boundary) : $content;
}


sub boundary
{
    my $size = shift || return "xYzZY";
    require MIME::Base64;
    my $b = MIME::Base64::encode(join("", map chr(rand(256)), 1..$size*3), "");
    $b =~ s/[\W]/X/g;  # ensure alnum only
    $b;
}

1;

__END__

