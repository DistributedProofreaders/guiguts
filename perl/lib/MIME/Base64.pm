#
# $Id: Base64.pm,v 2.34 2003/10/09 19:15:42 gisle Exp $

package MIME::Base64;

use strict;
use vars qw(@ISA @EXPORT $VERSION $OLD_CODE);

require Exporter;
require DynaLoader;
@ISA = qw(Exporter DynaLoader);
@EXPORT = qw(encode_base64 decode_base64);

$VERSION = '2.21';

eval { bootstrap MIME::Base64 $VERSION; };
if ($@) {
    # can't bootstrap XS implementation, use perl implementation
    *encode_base64 = \&old_encode_base64;
    *decode_base64 = \&old_decode_base64;

    $OLD_CODE = $@;
    #warn $@ if $^W;
}

# Historically this module has been implemented as pure perl code.
# The XS implementation runs about 20 times faster, but the Perl
# code might be more portable, so it is still here.

sub old_encode_base64 ($;$)
{
    if ($] >= 5.006) {
	require bytes;
	if (bytes::length($_[0]) > length($_[0]) ||
	    ($] >= 5.008 && $_[0] =~ /[^\0-\xFF]/))
	{
	    require Carp;
	    Carp::croak("The Base64 encoding is only defined for bytes");
	}
    }

    use integer;

    my $eol = $_[1];
    $eol = "\n" unless defined $eol;

    my $res = pack("u", $_[0]);
    # Remove first character of each line, remove newlines
    $res =~ s/^.//mg;
    $res =~ s/\n//g;

    $res =~ tr|` -_|AA-Za-z0-9+/|;               # `# help emacs
    # fix padding at the end
    my $padding = (3 - length($_[0]) % 3) % 3;
    $res =~ s/.{$padding}$/'=' x $padding/e if $padding;
    # break encoded string into lines of no more than 76 characters each
    if (length $eol) {
	$res =~ s/(.{1,76})/$1$eol/g;
    }
    return $res;
}


sub old_decode_base64 ($)
{
    local($^W) = 0; # unpack("u",...) gives bogus warning in 5.00[123]
    use integer;

    my $str = shift;
    $str =~ tr|A-Za-z0-9+=/||cd;            # remove non-base64 chars
    if (length($str) % 4) {
	require Carp;
	Carp::carp("Length of base64 data not a multiple of 4")
    }
    $str =~ s/=+$//;                        # remove padding
    $str =~ tr|A-Za-z0-9+/| -_|;            # convert to uuencoded format
    return "" unless length $str;

    ## I guess this could be written as
    #return unpack("u", join('', map( chr(32 + length($_)*3/4) . $_,
    #			$str =~ /(.{1,60})/gs) ) );
    ## but I do not like that...
    my $uustr = '';
    my ($i, $l);
    $l = length($str) - 60;
    for ($i = 0; $i <= $l; $i += 60) {
	$uustr .= "M" . substr($str, $i, 60);
    }
    $str = substr($str, $i);
    # and any leftover chars
    if ($str ne "") {
	$uustr .= chr(32 + length($str)*3/4) . $str;
    }
    return unpack ("u", $uustr);
}

# Set up aliases so that these functions also can be called as
#
#    MIME::Base64::encode();
#    MIME::Base64::decode();

*encode = \&encode_base64;
*decode = \&decode_base64;

1;
