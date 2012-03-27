#
# $Id: UTF7.pm,v 0.2 2003/05/19 04:56:03 dankogai Exp $
#
package Encode::Unicode::UTF7;
use strict;
no warnings 'redefine';
use base qw(Encode::Encoding);
__PACKAGE__->Define('UTF-7');
our $VERSION = do { my @r = (q$Revision: 0.2 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };
use MIME::Base64;
use Encode;

#
# Algorithms taken from Unicode::String by Gisle Aas
#

our $OPTIONAL_DIRECT_CHARS = 1;
my $specials =   quotemeta "\'(),-./:?";
$OPTIONAL_DIRECT_CHARS and
    $specials .= quotemeta "!\"#$%&*;<=>@[]^_`{|}";
# \s will not work because it matches U+3000 DEOGRAPHIC SPACE
# We use qr/[\n\r\t\ ] instead 
my $re_asis =     qr/(?:[\n\r\t\ A-Za-z0-9$specials])/;
my $re_encoded = qr/(?:[^\n\r\t\ A-Za-z0-9$specials])/;
my $e_utf16 = find_encoding("UTF-16BE");

sub needs_lines { 1 };

sub encode($$;$){
    my ($obj, $str, $chk) = @_;
    my $len = length($str);
    pos($str) = 0;
    my $bytes = '';
    while (pos($str) < $len){
	if    ($str =~ /\G($re_asis+)/ogc){
	    $bytes .= $1;
	}elsif($str =~ /\G($re_encoded+)/ogsc){
	    if ($1 eq "+"){
		$bytes .= "+-";
	    }else{
		my $base64 = encode_base64($e_utf16->encode($1), '');
		$base64 =~ s/=+$//;
		$bytes .= "+$base64-";
	    }
	}else{
	    die "This should not happen! (pos=" . pos($str) . ")";
	}
    }
    $_[1] = '' if $chk;
    return $bytes;
}
	   
sub decode{
    my ($obj, $bytes, $chk) = @_;
    my $len = length($bytes);
    my $str = "";
    while (pos($bytes) < $len) {
	if    ($bytes =~ /\G([^+]+)/ogc) {
	    $str .= $1;
	}elsif($bytes =~ /\G\+-/ogc) {
	    $str .= "+";
	}elsif($bytes =~ /\G\+([A-Za-z0-9+\/]+)-?/ogsc) {
	    my $base64 = $1;
	    my $pad = length($base64) % 4;
	    $base64 .= "=" x (4 - $pad) if $pad;
	    $str .= $e_utf16->decode(decode_base64($base64));
	}elsif($bytes =~ /\G\+/ogc) {
	    $^W and warn "Bad UTF7 data escape";
	    $str .= "+";
	}else{
	    die "This should not happen " . pos($bytes);
	}
    }
    $_[1] = '' if $chk;
    return $str;
}
1;
__END__

