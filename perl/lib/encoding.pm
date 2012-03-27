# $Id: encoding.pm,v 1.48 2003/12/29 02:47:16 dankogai Exp dankogai $
package encoding;
our $VERSION = do { my @r = (q$Revision: 1.48 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

use Encode;
use strict;
sub DEBUG () { 0 }

BEGIN {
    if (ord("A") == 193) {
	require Carp;
	Carp::croak("encoding pragma does not support EBCDIC platforms");
    }
}

our $HAS_PERLIO = 0;
eval { require PerlIO::encoding };
unless ($@){
    $HAS_PERLIO = (PerlIO::encoding->VERSION >= 0.02);
}

sub _exception{
    my $name = shift;
    $] > 5.008 and return 0;               # 5.8.1 or higher then no
    my %utfs = map {$_=>1}
	qw(utf8 UCS-2BE UCS-2LE UTF-16 UTF-16BE UTF-16LE
	   UTF-32 UTF-32BE UTF-32LE);
    $utfs{$name} or return 0;               # UTFs or no
    require Config; Config->import(); our %Config;
    return $Config{perl_patchlevel} ? 0 : 1 # maintperl then no
}

sub import {
    my $class = shift;
    my $name  = shift;
    my %arg = @_;
    $name ||= $ENV{PERL_ENCODING};
    my $enc = find_encoding($name);
    unless (defined $enc) {
	require Carp;
	Carp::croak("Unknown encoding '$name'");
    }
    $name = $enc->name; # canonize
    unless ($arg{Filter}) {
	DEBUG and warn "_exception($name) = ", _exception($name);
	_exception($name) or ${^ENCODING} = $enc;
	$HAS_PERLIO or return 1;
    }else{
	defined(${^ENCODING}) and undef ${^ENCODING};
	# implicitly 'use utf8'
	require utf8; # to fetch $utf8::hint_bits;
	$^H |= $utf8::hint_bits;
	eval {
	    require Filter::Util::Call ;
	    Filter::Util::Call->import ;
	    filter_add(sub{
			   my $status = filter_read();
                           if ($status > 0){
			       $_ = $enc->decode($_, 1);
			       DEBUG and warn $_;
			   }
			   $status ;
		       });
	};
    }	DEBUG and warn "Filter installed";
    defined ${^UNICODE} and ${^UNICODE} != 0 and return 1;
    for my $h (qw(STDIN STDOUT)){
	if ($arg{$h}){
	    unless (defined find_encoding($arg{$h})) {
		require Carp;
		Carp::croak("Unknown encoding for $h, '$arg{$h}'");
	    }
	    eval { binmode($h, ":raw :encoding($arg{$h})") };
	}else{
	    unless (exists $arg{$h}){
		eval { 
		    no warnings 'uninitialized';
		    binmode($h, ":raw :encoding($name)");
		};
	    }
	}
	if ($@){
	    require Carp;
	    Carp::croak($@);
	}
    }
    return 1; # I doubt if we need it, though
}

sub unimport{
    no warnings;
    undef ${^ENCODING};
    if ($HAS_PERLIO){
	binmode(STDIN,  ":raw");
	binmode(STDOUT, ":raw");
    }else{
	binmode(STDIN);
	binmode(STDOUT);
    }
    if ($INC{"Filter/Util/Call.pm"}){
	eval { filter_del() };
    }
}

1;
__END__

