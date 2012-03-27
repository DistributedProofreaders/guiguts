package Unicode::String;

# Copyright 1997-1999, Gisle Aas.

use strict;
use vars qw($VERSION @ISA @EXPORT_OK $UTF7_OPTIONAL_DIRECT_CHARS);
use Carp;

require Exporter;
require DynaLoader;
@ISA = qw(Exporter DynaLoader);

@EXPORT_OK = qw(utf16 utf8 utf7 ucs2 ucs4 latin1 uchr uhex byteswap2 byteswap4);

$VERSION = '2.07'; # $Id: String.pm,v 1.27 2000/05/19 12:00:45 gisle Exp $

$UTF7_OPTIONAL_DIRECT_CHARS ||= 1;

bootstrap Unicode::String $VERSION;

use overload '""'   => \&as_string,
	     'bool' => \&as_bool,
	     '0+'   => \&as_num,
	     '.='   => \&append,
             '.'    => \&concat,
             'x'    => \&repeat,
	     '='    => \&copy,
             'fallback' => 1;

my %stringify = (
   unicode => \&utf16,
   utf16   => \&utf16,
   ucs2    => \&utf16,
   utf8    => \&utf8,
   utf7    => \&utf7,
   ucs4    => \&ucs4,
   latin1  => \&latin1,
  'hex'    => \&hex,
);

my $stringify_as = \&utf8;

# some aliases
*ucs2 = \&utf16;
*uhex = \&hex;
*uchr = \&chr;

sub new
{
    #_dump_arg("new", @_);
    my $class = shift;
    my $str;
    my $self = bless \$str, $class;
    &$stringify_as($self, shift) if @_;
    $self;
}


sub repeat
{
    my($self, $count) = @_;
    my $class = ref($self);
    my $str = $$self x $count;
    bless \$str, $class;
}


sub _dump_arg
{
    my $func = shift;
    print "$func(";
    print join(",", map { if (defined $_) {
                             my $x = overload::StrVal($_);
			     $x =~ s/\n/\\n/g;
			     $x = '""' unless length $x;
			     $x;
			 } else {
			     "undef"
			 }
                        } @_);
    print ")\n";
}


sub concat
{
    #_dump_arg("concat", @_);
    my($self, $other, $reversed) = @_;
    my $class = ref($self);
    unless (UNIVERSAL::isa($other, 'Unicode::String')) {
	$other = Unicode::String->new($other);
    }
    my $str = $reversed ? $$other . $$self : $$self . $$other;
    bless \$str, $class;
}


sub append
{
    #_dump_arg("append", @_);
    my($self, $other) = @_;
    unless (UNIVERSAL::isa($other, 'Unicode::String')) {
	$other = Unicode::String->new($other);
    }
    $$self .= $$other;
    $self;
}


sub copy
{
    my($self) = @_;
    my $class = ref($self);
    my $copy = $$self;
    bless \$copy, $class;
}


sub as_string
{
    #_dump_arg("as_string", @_);
    &$stringify_as($_[0]);
}


sub as_bool
{
    # This is different from perl's normal behaviour by not letting
    # a U+0030  ("0") be false.
    my $self = shift;
    $$self ? 1 : "";
}


sub as_num
{
    # Should be able to use the numeric property from Unidata
    # in order to parse a large number of numbers.  Currently we
    # only convert it to a plain string and let perl's normal
    # num-converter do the job.
    my $self = shift;
    my $str = $self->utf8;
    $str + 0;
}


sub stringify_as
{
    my $class;
    if (@_ > 1) {
	$class = shift;
	$class = ref($class) if ref($class);
    } else {
	$class = "Unicode::String";
    }
    my $old = $stringify_as;
    if (@_) {
	my $as = shift;
	croak("Don't know how to stringify as '$as'")
	    unless exists $stringify{$as};
	$stringify_as = $stringify{$as};
    }
    $old;
}


sub utf16
{
    my $self = shift;
    unless (ref $self) {
	my $u = new Unicode::String;
	$u->utf16($self);
	return $u;
    }
    my $old = $$self;
    if (@_) {
	$$self = shift;
	if ((length($$self) % 2) != 0) {
	    warn "Uneven UTF16 data" if $^W;
	    $$self .= "\0";
	}
	if ($$self =~ /^\xFF\xFE/) {
	    # the string needs byte swapping
	    $$self = pack("n*", unpack("v*", $$self));
	}
    }
    $old;
}



sub utf7   # rfc1642
{
    my $self = shift;
    unless (ref $self) {
	# act as ctor
	my $u = new Unicode::String;
	$u->utf7($self);
	return $u;
    }
    my $old;
    if (defined wantarray) {
	# encode into $old
	$old = "";
	pos($$self) = 0;
	my $len = length($$self);
	while (pos($$self) < $len) {
            if (($UTF7_OPTIONAL_DIRECT_CHARS &&
		 $$self =~ /\G((?:\0[A-Za-z0-9\'\(\)\,\-\.\/\:\?\!\"\#\$\%\&\*\;\<\=\>\@\[\]\^\_\`\{\|\}\s])+)/gc)
	        || $$self =~ /\G((?:\0[A-Za-z0-9\'\(\)\,\-\.\/\:\?\s])+)/gc)
            {
		#print "Plain ", utf16($1)->latin1, "\n";
		$old .= utf16($1)->latin1;
	    }
            elsif (($UTF7_OPTIONAL_DIRECT_CHARS &&
                    $$self =~ /\G((?:[^\0].|\0[^A-Za-z0-9\'\(\)\,\-\.\/\:\?\!\"\#\$\%\&\*\;\<\=\>\@\[\]\^\_\`\{\|\}\s])+)/gsc)
                   || $$self =~ /\G((?:[^\0].|\0[^A-Za-z0-9\'\(\)\,\-\.\/\:\?\s])+)/gsc)
            {
		#print "Unplain ", utf16($1)->hex, "\n";
		if ($1 eq "\0+") {
		    $old .= "+-";
		} else {
		    require MIME::Base64;
		    my $base64 = MIME::Base64::encode($1, '');
		    $base64 =~ s/=+$//;
		    $old .= "+$base64-";
		    # XXX should we determine when the final "-" is
		    # unnecessary? depends on next char not being part
		    # of the base64 char set.
		}
	    } else {
		die "This should not happen, pos=" . pos($$self) .
                                            ":  "  . $self->hex . "\n";
	    }
	}
    }
    
    if (@_) {
	# decode
	my $len = length($_[0]);
	$$self = "";
	while (pos($_[0]) < $len) {
	    if ($_[0] =~ /\G([^+]+)/gc) {
		$self->append(latin1($1));
	    } elsif ($_[0] =~ /\G\+-/gc) {
		$$self .= "\0+";
	    } elsif ($_[0] =~ /\G\+([A-Za-z0-9+\/]+)-?/gc) {
		my $base64 = $1;
		my $pad = length($base64) % 4;
		$base64 .= "=" x (4 - $pad) if $pad;
		require MIME::Base64;
		$$self .= MIME::Base64::decode($base64);
		if ((length($$self) % 2) != 0) {
		    warn "Uneven UTF7 base64-data" if $^W;
		    chop($$self); # correct it
		}
            } elsif ($_[0] =~ /\G\+/gc) {
		warn "Bad UTF7 data escape" if $^W;
		$$self .= "\0+";
	    } else {
		die "This should not happen " . pos($_[0]);
	    }
	}
    }
    $old;
}


sub hex
{
    my $self = shift;
    unless (ref $self) {
	my $u = new Unicode::String;
	$u->hex($self);
	return $u;
    }
    my $old;
    if (defined($$self) && defined wantarray) {
	$old = unpack("H*", $$self);
	$old =~ s/(....)/U+$1 /g;
	$old =~ s/\s+$//;
    }
    if (@_) {
	my $new = shift;
	$new =~ tr/0-9A-Fa-f//cd;  # leave only hex chars
	croak("Hex string length must be multiple of four")
	    unless (length($new) % 4) == 0;
	$$self = pack("H*", $new);
    }
    $old;
}


sub length
{
    my $self = shift;
    int(length($$self) / 2);
}

sub byteswap
{
   my $self = shift;
   byteswap2($$self);
   $self;
}

sub unpack
{
    my $self = shift;
    unpack("n*", $$self)
}


sub pack
{
    my $self = shift;
    $$self = pack("n*", @_);
    $self;
}


sub ord
{
    my $self = shift;
    return () unless defined $$self;

    my $array = wantarray;
    my @ret;
    my @chars;
    if ($array) {
        @chars = CORE::unpack("n*", $$self);
    } else {
	@chars = CORE::unpack("n2", $$self);
    }

    while (@chars) {
	my $first = shift(@chars);
	if ($first >= 0xD800 && $first <= 0xDFFF) { 	# surrogate
	    my $second = shift(@chars);
	    #print "F=$first S=$second\n";
	    if ($first >= 0xDC00 || $second < 0xDC00 || $second > 0xDFFF) {
		carp(sprintf("Bad surrogate pair (U+%04x U+%04x)",
			     $first, $second));
		unshift(@chars, $second);
		next;
	    }
	    push(@ret, ($first-0xD800)*0x400 + ($second-0xDC00) + 0x10000);
	} else {
	    push(@ret, $first);
	}
	last unless $array;
    }
    $array ? @ret : $ret[0];
}


sub name
{
    my $self = shift;
    require Unicode::CharName;
    if (wantarray) {
	return map { Unicode::CharName::uname($_) } $self->ord;
    } else {
        return Unicode::CharName::uname(scalar($self->ord));
    }
}


sub chr
{
    my($self,$val) = @_;
    unless (ref $self) {
	# act as ctor
	my $u = new Unicode::String;
	return $u->uchr($self);
    }
    if ($val > 0xFFFF) {
	# must be represented by a surrogate pair
	return undef if $val > 0x10FFFF;  # Unicode limit
	$val -= 0x10000;
	my $h = int($val / 0x400) + 0xD800;
	my $l = ($val % 0x400) + 0xDC00;
	$$self = CORE::pack("n2", $h, $l);
    } else {
	$$self = CORE::pack("n", $val);
    }
    $self;
}


sub substr
{
    my($self, $offset, $length, $substitute) = @_;
    $offset ||= 0;
    $offset *= 2;
    my $substr;
    if (defined $substitute) {
	unless (UNIVERSAL::isa($substitute, 'Unicode::String')) {
	    $substitute = Unicode::String->new($substitute);
	}
	if (defined $length) {
	    $substr = substr($$self, $offset, $length*2) = $$substitute;
	} else {
	    $substr = substr($$self, $offset) = $$substitute;
	}
    } else {
	if (defined $length) {
	    $substr = substr($$self, $offset, $length*2);
	} else {
	    $substr = substr($$self, $offset);
	}
    }
    bless \$substr, ref($self);
}


sub index
{
    my($self, $other, $pos) = @_;
    $pos ||= 0;
    $pos *= 2;
    $other = Unicode::String->new($other) unless ref($other);
    $pos++ while ($pos = index($$self, $$other, $pos)) > 0 && ($pos%2) != 0;
    $pos /= 2 if $pos > 0;
    $pos;
}


sub rindex
{
    my($self, $other, $pos) = @_;
    $pos ||= 0;
    die "NYI";
}


sub chop
{
    my $self = shift;
    if (CORE::length $$self) {
	my $chop = chop($$self);
	$chop = chop($$self) . $chop;
	return bless \$chop, ref($self);
    }
    undef;
}


# XXX: Ideas to be implemented
sub scan;
sub reverse;

sub lc;
sub lcfirst;
sub uc;
sub ucfirst;

sub split;
sub sprintf;
sub study;
sub tr;


1;

__END__


#
# Some old code that is not used any more (because the methods are
# now implemented as XS) and which I did not want to throw away yet.
#

sub ucs4_inperl
{
    my $self = shift;
    unless (ref $self) {
	my $u = new Unicode::String;
	$u->ucs4($self);
	return $u;
    }
    my $old = pack("N*", $self->ord);
    if (@_) {
	$$self = "";
	for (unpack("N*", shift)) {
	    $self->append(uchr($_));
	}
    }
    $old;
}


sub utf8_inperl
{
    my $self = shift;
    unless (ref $self) {
	# act as ctor
	my $u = new Unicode::String;
	$u->utf8($self);
	return $u;
    }

    my $old;
    if (defined($$self) && defined wantarray) {
	# encode UTF-8
	my $uc;
	for $uc (unpack("n*", $$self)) {
	    if ($uc < 0x80) {
		# 1 byte representation
		$old .= chr($uc);
	    } elsif ($uc < 0x800) {
		# 2 byte representation
		$old .= chr(0xC0 | ($uc >> 6)) .
                        chr(0x80 | ($uc & 0x3F));
	    } else {
		# 3 byte representation
		$old .= chr(0xE0 | ($uc >> 12)) .
		        chr(0x80 | (($uc >> 6) & 0x3F)) .
			chr(0x80 | ($uc & 0x3F));
	    }
	}
    }

    if (@_) {
	if (defined $_[0]) {
	    $$self = "";
	    my $bytes = shift;
	    $bytes =~ s/^[\200-\277]+//;  # can't start with 10xxxxxx
	    while (length $bytes) {
		if ($bytes =~ s/^([\000-\177]+)//) {
		    $$self .= pack("n*", unpack("C*", $1));
		} elsif ($bytes =~ s/^([\300-\337])([\200-\277])//) {
		    my($b1,$b2) = (ord($1), ord($2));
		    $$self .= pack("n", (($b1 & 0x1F) << 6) | ($b2 & 0x3F));
		} elsif ($bytes =~ s/^([\340-\357])([\200-\277])([\200-\277])//) {
		    my($b1,$b2,$b3) = (ord($1), ord($2), ord($3));
		    $$self .= pack("n", (($b1 & 0x0F) << 12) |
                                        (($b2 & 0x3F) <<  6) |
				         ($b3 & 0x3F));
		} else {
		    croak "Bad UTF-8 data";
		}
	    }
	} else {
	    $$self = undef;
	}
    }

    $old;
}




sub latin1_inperl
{
    my $self = shift;
    unless (ref $self) {
	# act as ctor
	my $u = new Unicode::String;
	$u->latin1($self);
	return $u;
    }

    my $old;
    # XXX: should really check that none of the chars > 256
    $old = pack("C*", unpack("n*", $$self)) if defined $$self;

    if (@_) {
	# set the value
	if (defined $_[0]) {
	    $$self = pack("n*", unpack("C*", $_[0]));
	} else {
	    $$self = undef;
	}
    }
    $old;
}
