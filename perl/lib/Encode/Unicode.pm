package Encode::Unicode;

use strict;
use warnings;
no warnings 'redefine';

our $VERSION = do { my @r = (q$Revision: 1.40 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

use XSLoader;
XSLoader::load(__PACKAGE__,$VERSION);

#
# Object Generator 8 transcoders all at once!
#

require Encode;

our %BOM_Unknown = map {$_ => 1} qw(UTF-16 UTF-32);

for my $name (qw(UTF-16 UTF-16BE UTF-16LE
                 UTF-32 UTF-32BE UTF-32LE
                        UCS-2BE  UCS-2LE))
{
    my ($size, $endian, $ucs2, $mask);
    $name =~ /^(\w+)-(\d+)(\w*)$/o;
    if ($ucs2 = ($1 eq 'UCS')){
	$size = 2;
    }else{
	$size = $2/8;
    }
    $endian = ($3 eq 'BE') ? 'n' : ($3 eq 'LE') ? 'v' : '' ;
    $size == 4 and $endian = uc($endian);

    $Encode::Encoding{$name} = 	
	bless {
	       Name   =>   $name,
	       size   =>   $size,
	       endian => $endian,
	       ucs2   =>   $ucs2,
	      } => __PACKAGE__;
}

use base qw(Encode::Encoding);

sub renew { 
    my $self = shift;
    $BOM_Unknown{$self->name} or return $self;
    my $clone = bless { %$self } => ref($self);
    $clone->{clone} = 1; # so the caller knows it is renewed.
    return $clone;
}

# There used to be a perl implemntation of (en|de)code but with
# XS version is ripe, perl version is zapped for optimal speed

*decode = \&decode_xs;
*encode = \&encode_xs;

1;
__END__

