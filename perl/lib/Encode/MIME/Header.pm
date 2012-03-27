package Encode::MIME::Header;
use strict;
# use warnings;
our $VERSION = do { my @r = (q$Revision: 1.9 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };
use Encode qw(find_encoding encode_utf8 decode_utf8);
use MIME::Base64;
use Carp;

my %seed = 
    (
     decode_b     => '1', # decodes 'B' encoding ?
     decode_q     => '1', # decodes 'Q' encoding ?
     encode       => 'B', # encode with 'B' or 'Q' ?
     bpl          => 75,  # bytes per line
     );

$Encode::Encoding{'MIME-Header'} =
    bless {
	%seed,
	Name => 'MIME-Header',
    } => __PACKAGE__;

$Encode::Encoding{'MIME-B'} =
    bless {
	%seed,
	decode_q  => 0,
	Name      => 'MIME-B',
    } => __PACKAGE__;

$Encode::Encoding{'MIME-Q'} =
    bless {
	%seed,
	decode_q    => 1,
	encode      => 'Q',
	Name        => 'MIME-Q',
    } => __PACKAGE__;

use base qw(Encode::Encoding);

sub needs_lines { 1 }
sub perlio_ok{ 0 };

sub decode($$;$){
    use utf8;
    my ($obj, $str, $chk) = @_;
    # zap spaces between encoded words
    $str =~ s/\?=\s+=\?/\?==\?/gos;
    # multi-line header to single line
    $str =~ s/(:?\r|\n|\r\n)[ \t]//gos;
    $str =~
	s{
	    =\?                  # begin encoded word
		([0-9A-Za-z\-_]+) # charset (encoding)
		\?([QqBb])\?     # delimiter
		(.*?)            # Base64-encodede contents
		\?=              # end encoded word      
	    }{
		if    (uc($2) eq 'B'){
		    $obj->{decode_b} or croak qq(MIME "B" unsupported);
		    decode_b($1, $3);
		}elsif(uc($2) eq 'Q'){
		    $obj->{decode_q} or croak qq(MIME "Q" unsupported);
		    decode_q($1, $3);
		}else{
		    croak qq(MIME "$2" encoding is nonexistent!);
		}
	    }egox;
    $_[1] = '' if $chk;
    return $str;
}

sub decode_b{
    my $enc = shift;
    my $d = find_encoding($enc)        or croak qq(Unknown encoding "$enc");
    my $db64 = decode_base64(shift);
    return $d->name eq 'utf8' ?
	Encode::decode_utf8($db64) : $d->decode($db64, Encode::FB_PERLQQ);
}

sub decode_q{
    my ($enc, $q) = @_;
    my $d = find_encoding($enc) or croak qq(Unknown encoding "$enc");
    $q =~ s/_/ /go;
    $q =~ s/=([0-9A-Fa-f]{2})/pack("C", hex($1))/ego;
    return $d->name eq 'utf8' ? 
	Encode::decode_utf8($q) : $d->decode($q, Encode::FB_PERLQQ);
}

my $especials = 
    join('|' =>
	 map {quotemeta(chr($_))} 
	 unpack("C*", qq{()<>@,;:\"\'/[]?.=}));

my $re_encoded_word =
    qr{
       (?:
	=\?               # begin encoded word
	(?:[0-9A-Za-z\-_]+) # charset (encoding)
	\?(?:[QqBb])\?      # delimiter
	(?:.*?)             # Base64-encodede contents
	\?=                 # end encoded word
       )
      }xo;

my $re_especials = qr{$re_encoded_word|$especials}xo;

sub encode($$;$){
    my ($obj, $str, $chk) = @_;
    my @line = ();
    for my $line (split /\r|\n|\r\n/o, $str){
	my (@word, @subline);
        for my $word (split /($re_especials)/o, $line){
	    if ($word =~ /[^\x00-\x7f]/o or $word =~ /^$re_encoded_word$/o){
		push @word, $obj->_encode($word);
	    }else{
		push @word, $word;
	    }
	}
	my $subline = '';
	for my $word (@word){
	    use bytes ();
	    if (bytes::length($subline) + bytes::length($word) > $obj->{bpl}){
		push @subline, $subline;
		$subline = '';
	    }
	    $subline .= $word;
	}
	$subline and push @subline, $subline;
	push @line, join("\n " => @subline);
    }
    $_[1] = '' if $chk;
    return join("\n", @line);
}

use constant HEAD  => '=?UTF-8?';
use constant TAIL    => '?=';
use constant SINGLE => { B => \&_encode_b, Q => \&_encode_q, };

sub _encode{
    my ($o, $str) = @_;
    my $enc = $o->{encode};
    my $llen = ($o->{bpl} - length(HEAD) - 2 - length(TAIL));
    # to coerce a floating-point arithmetics, the following contains
    # .0 in numbers -- dankogai
    $llen *= $enc eq 'B' ? 3.0/4.0 : 1.0/3.0;
    my @result = ();
    my $chunk = '';
    while(length(my $chr = substr($str, 0, 1, ''))){
	use bytes ();
	if (bytes::length($chunk) + bytes::length($chr) > $llen){
	    push @result, SINGLE->{$enc}($chunk);
	    $chunk = '';
	}
	$chunk .= $chr;
    }
    $chunk and push @result, SINGLE->{$enc}($chunk);
    return @result;
}

sub _encode_b{
    HEAD . 'B?' . encode_base64(encode_utf8(shift), '') . TAIL;
}

sub _encode_q{
    my $chunk = shift;
    $chunk =~ s{
		([^0-9A-Za-z])
	       }{
		   join("" => map {sprintf "=%02X", $_} unpack("C*", $1))
	       }egox;
    return decode_utf8(HEAD . 'Q?' . $chunk . TAIL);
}

1;
__END__

