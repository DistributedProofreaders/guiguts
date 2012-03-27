package URI::Heuristic;

# $Id: Heuristic.pm,v 4.16 2003/07/23 23:47:52 gisle Exp $

use strict;

use vars qw(@EXPORT_OK $VERSION $MY_COUNTRY %LOCAL_GUESSING $DEBUG);

require Exporter;
*import = \&Exporter::import;
@EXPORT_OK = qw(uf_uri uf_uristr uf_url uf_urlstr);
$VERSION = sprintf("%d.%02d", q$Revision: 4.16 $ =~ /(\d+)\.(\d+)/);

sub MY_COUNTRY() {
    for ($MY_COUNTRY) {
	return $_ if defined;

	# First try the environment.
	$_ = $ENV{COUNTRY};
	return $_ if defined;

	# Could use LANG, LC_ALL, etc at this point, but probably too
	# much of a wild guess.  (Catalan != Canada, etc.)
	#

	# Last bit of domain name.  This may access the network.
	require Net::Domain;
	my $fqdn = Net::Domain::hostfqdn();
	$_ = lc($1) if $fqdn =~ /\.([a-zA-Z]{2})$/;
	return $_ if defined;

	# Give up.  Defined but false.
	return ($_ = 0);
    }
}

%LOCAL_GUESSING =
(
 'us' => [qw(www.ACME.gov www.ACME.mil)],
 'uk' => [qw(www.ACME.co.uk www.ACME.org.uk www.ACME.ac.uk)],
 'au' => [qw(www.ACME.com.au www.ACME.org.au www.ACME.edu.au)],
 'il' => [qw(www.ACME.co.il www.ACME.org.il www.ACME.net.il)],
 # send corrections and new entries to <gisle@aas.no>
);


sub uf_uristr ($)
{
    local($_) = @_;
    print STDERR "uf_uristr: resolving $_\n" if $DEBUG;
    return unless defined;

    s/^\s+//;
    s/\s+$//;

    if (/^(www|web|home)\./) {
	$_ = "http://$_";

    } elsif (/^(ftp|gopher|news|wais|http|https)\./) {
	$_ = "$1://$_";

    } elsif ($^O ne "MacOS" && 
	    (m,^/,      ||          # absolute file name
	     m,^\.\.?/, ||          # relative file name
	     m,^[a-zA-Z]:[/\\],)    # dosish file name
	    )
    {
	$_ = "file:$_";

    } elsif ($^O eq "MacOS" && m/:/) {
        # potential MacOS file name
	unless (m/^(ftp|gopher|news|wais|http|https|mailto):/) {
	    require URI::file;
	    my $a = URI::file->new($_)->as_string;
	    $_ = ($a =~ m/^file:/) ? $a : "file:$a";
	}
    } elsif (/^\w+([\.\-]\w+)*\@(\w+\.)+\w{2,3}$/) {
	$_ = "mailto:$_";

    } elsif (!/^[a-zA-Z][a-zA-Z0-9.+\-]*:/) {      # no scheme specified
	if (s/^([-\w]+(?:\.[-\w]+)*)([\/:\?\#]|$)/$2/) {
	    my $host = $1;

	    if ($host !~ /\./ && $host ne "localhost") {
		my @guess;
		if (exists $ENV{URL_GUESS_PATTERN}) {
		    @guess = map { s/\bACME\b/$host/; $_ }
		             split(' ', $ENV{URL_GUESS_PATTERN});
		} else {
		    if (MY_COUNTRY()) {
			my $special = $LOCAL_GUESSING{MY_COUNTRY()};
			if ($special) {
			    my @special = @$special;
			    push(@guess, map { s/\bACME\b/$host/; $_ }
                                               @special);
			} else {
			    push(@guess, 'www.$host.' . MY_COUNTRY());
			}
		    }
		    push(@guess, map "www.$host.$_",
			             "com", "org", "net", "edu", "int");
		}


		my $guess;
		for $guess (@guess) {
		    print STDERR "uf_uristr: gethostbyname('$guess.')..."
		      if $DEBUG;
		    if (gethostbyname("$guess.")) {
			print STDERR "yes\n" if $DEBUG;
			$host = $guess;
			last;
		    }
		    print STDERR "no\n" if $DEBUG;
		}
	    }
	    $_ = "http://$host$_";

	} else {
	    # pure junk, just return it unchanged...

	}
    }
    print STDERR "uf_uristr: ==> $_\n" if $DEBUG;

    $_;
}

sub uf_uri ($)
{
    require URI;
    URI->new(uf_uristr($_[0]));
}

# legacy
*uf_urlstr = \*uf_uristr;

sub uf_url ($)
{
    require URI::URL;
    URI::URL->new(uf_uristr($_[0]));
}

1;
