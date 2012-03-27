# File	  : Zlib.pm
# Author  : Paul Marquess
# Created : 29 April 2003
# Version : 1.22
#
#     Copyright (c) 1995-2003 Paul Marquess. All rights reserved.
#     This program is free software; you can redistribute it and/or
#     modify it under the same terms as Perl itself.
#

package Compress::Zlib;

require 5.004 ;
require Exporter;
require DynaLoader;
use AutoLoader;
use Carp ;
use IO::Handle ;

use strict ;
use warnings ;
our ($VERSION, @ISA, @EXPORT, $AUTOLOAD);
our ($deflateDefault, $deflateParamsDefault, $inflateDefault);

$VERSION = "1.22" ;

@ISA = qw(Exporter DynaLoader);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw(
	deflateInit 
	inflateInit

	compress 
	uncompress

	gzip gunzip

	gzopen 
	$gzerrno

	adler32 
	crc32

	ZLIB_VERSION

	DEF_WBITS
	OS_CODE

        MAX_MEM_LEVEL
	MAX_WBITS

	Z_ASCII
	Z_BEST_COMPRESSION
	Z_BEST_SPEED
	Z_BINARY
	Z_BUF_ERROR
	Z_DATA_ERROR
	Z_DEFAULT_COMPRESSION
	Z_DEFAULT_STRATEGY
        Z_DEFLATED
	Z_ERRNO
	Z_FILTERED
	Z_FINISH
	Z_FULL_FLUSH
	Z_HUFFMAN_ONLY
	Z_MEM_ERROR
	Z_NEED_DICT
	Z_NO_COMPRESSION
	Z_NO_FLUSH
	Z_NULL
	Z_OK
	Z_PARTIAL_FLUSH
	Z_STREAM_END
	Z_STREAM_ERROR
	Z_SYNC_FLUSH
	Z_UNKNOWN
	Z_VERSION_ERROR
);



sub AUTOLOAD {
    my($constname);
    ($constname = $AUTOLOAD) =~ s/.*:://;
    my ($error, $val) = constant($constname);
    Carp::croak $error if $error;
    no strict 'refs';
    *{$AUTOLOAD} = sub { $val };
    goto &{$AUTOLOAD};
}

bootstrap Compress::Zlib $VERSION ;

# Preloaded methods go here.

sub isaFilehandle
{
    my $fh = shift ;

    return ((UNIVERSAL::isa($fh,'GLOB') or UNIVERSAL::isa(\$fh,'GLOB')) 
		and defined fileno($fh)  )

}

sub isaFilename
{
    my $name = shift ;

    return (! ref $name and UNIVERSAL::isa(\$name, 'SCALAR')) ;
}

sub gzopen
{
    my ($file, $mode) = @_ ;
 
    if (isaFilehandle $file) {
	IO::Handle::flush($file) ;
	my $offset = -f $file ? tell($file) : -1 ;
        gzdopen_(fileno($file), $mode, $offset) ;
    }
    elsif (isaFilename $file) {
	gzopen_($file, $mode) 
    }
    else {
	croak "gzopen: file parameter is not a filehandle or filename"
    }
}

sub ParseParameters($@)
{
    my ($default, @rest) = @_ ;
    my (%got) = %$default ;
    my (@Bad) ;
    my ($key, $value) ;
    my $sub = (caller(1))[3] ;
    my %options = () ;

    # allow the options to be passed as a hash reference or
    # as the complete hash.
    if (@rest == 1) {

        croak "$sub: parameter is not a reference to a hash"
            if ref $rest[0] ne "HASH" ;

        %options = %{ $rest[0] } ;
    }
    elsif (@rest >= 2) {
        my $count = @rest;
        croak "$sub: Expected even number of parameters, got $count"
            if @rest % 2 != 0 ;
        %options = @rest ;
    }

    while (($key, $value) = each %options)
    {
	$key =~ s/^-// ;

        if (exists $default->{$key})
          { $got{$key} = $value }
        else
	  { push (@Bad, $key) }
    }
    
    if (@Bad) {
        my ($bad) = join(", ", @Bad) ;
        croak "unknown key value(s) @Bad" ;
    }

    return \%got ;
}

$deflateDefault = {
	'Level'	     =>	Z_DEFAULT_COMPRESSION(),
	'Method'     =>	Z_DEFLATED(),
	'WindowBits' =>	MAX_WBITS(),
	'MemLevel'   =>	MAX_MEM_LEVEL(),
	'Strategy'   =>	Z_DEFAULT_STRATEGY(),
	'Bufsize'    =>	4096,
	'Dictionary' =>	"",
	} ;

$deflateParamsDefault = {
	'Level'	     =>	undef,
	'Strategy'   =>	undef,
	'Bufsize'    =>	undef,
	} ;

$inflateDefault = {
	'WindowBits' =>	MAX_WBITS(),
	'Bufsize'    =>	4096,
	'Dictionary' =>	"",
	} ;


sub deflateInit
{
    my ($got) = ParseParameters($deflateDefault, @_) ;
    no warnings;
    croak "deflateInit: Bufsize must be >= 1, you specified $got->{Bufsize}"
        unless $got->{Bufsize} >= 1;
    _deflateInit($got->{Level}, $got->{Method}, $got->{WindowBits}, 
		$got->{MemLevel}, $got->{Strategy}, $got->{Bufsize},
		$got->{Dictionary}) ;
		
}

sub inflateInit
{
    my ($got) = ParseParameters($inflateDefault, @_) ;
    no warnings;
    croak "inflateInit: Bufsize must be >= 1, you specified $got->{Bufsize}"
        unless $got->{Bufsize} >= 1;
    _inflateInit($got->{WindowBits}, $got->{Bufsize}, $got->{Dictionary});
 
}

sub Compress::Zlib::deflateStream::deflateParams
{
    my $self = shift ;
    my ($got) = ParseParameters($deflateParamsDefault, @_) ;
    croak "deflateParams needs Level and/or Strategy"
        unless defined $got->{Level} || defined $got->{Strategy};
    no warnings;
    croak "deflateParams: Bufsize must be >= 1, you specified $got->{Bufsize}"
        unless  !defined $got->{Bufsize} || $got->{Bufsize} >= 1;

    my $flags = 0;
    if (defined $got->{Level}) 
      { $flags |= 1 }
    else 
      { $got->{Level} = 0 }

    if (defined $got->{Strategy}) 
      { $flags |= 2 }
    else 
      { $got->{Strategy} = 0 }

    $got->{Bufsize} = 0 
        if !defined $got->{Bufsize};

    $self->_deflateParams($flags, $got->{Level}, $got->{Strategy}, 
                          $got->{Bufsize});
		
}

sub compress($;$)
{
    my ($x, $output, $out, $err, $in) ;

    if (ref $_[0] ) {
        $in = $_[0] ;
	croak "not a scalar reference" unless ref $in eq 'SCALAR' ;
    }
    else {
        $in = \$_[0] ;
    }

    my $level = (@_ == 2 ? $_[1] : Z_DEFAULT_COMPRESSION() );


    if ( (($x, $err) = deflateInit(Level => $level))[1] == Z_OK()) {

        ($output, $err) = $x->deflate($in) ;
	return undef unless $err == Z_OK() ;

	($out, $err) = $x->flush() ;
	return undef unless $err == Z_OK() ;
    
        return ($output . $out) ;

    }

    return undef ;
}


sub uncompress($)
{
    my ($x, $output, $err, $in) ;

    if (ref $_[0] ) {
        $in = $_[0] ;
	croak "not a scalar reference" unless ref $in eq 'SCALAR' ;
    }
    else {
        $in = \$_[0] ;
    }

    if ( (($x, $err) = inflateInit())[1] == Z_OK())  {
 
        ($output, $err) = $x->__unc_inflate($in) ;
        return undef unless $err == Z_STREAM_END() ;
 
	return $output ;
    }
 
    return undef ;
}


# Constants
use constant MAGIC1	=> 0x1f ;
use constant MAGIC2	=> 0x8b ;
use constant OSCODE	=> 3 ;

use constant FTEXT	=> 1 ;
use constant FHCRC	=> 2 ;
use constant FEXTRA	=> 4 ;
use constant FNAME	=> 8 ;
use constant FCOMMENT	=> 16 ;
use constant NULL	=> pack("C", 0) ;
use constant RESERVED	=> 0xE0 ;

use constant MIN_HDR_SIZE => 10 ; # minimum gzip header size
 
sub memGzip
{
  my $x = deflateInit(
                      -Level         => Z_BEST_COMPRESSION(),
                      -WindowBits     =>  - MAX_WBITS(),
                     )
      or return undef ;
 
  # write a minimal gzip header
  my(@m);
  push @m, pack("C" . MIN_HDR_SIZE, 
                MAGIC1, MAGIC2, Z_DEFLATED(), 0,0,0,0,0,0, OSCODE) ;
 
  # if the deflation buffer isn't a reference, make it one
  my $string = (ref $_[0] ? $_[0] : \$_[0]) ;

  my ($output, $status) = $x->deflate($string) ;
  push @m, $output ;
  $status == Z_OK()
      or return undef ;
 
  ($output, $status) = $x->flush() ;
  push @m, $output ;
  $status == Z_OK()
      or return undef ;
 
  push @m, pack("V V", crc32($string), $x->total_in());
 
  return join "", @m;
}

sub _removeGzipHeader
{
    my $string = shift ;

    return Z_DATA_ERROR() 
        if length($$string) < MIN_HDR_SIZE ;

    my ($magic1, $magic2, $method, $flags, $time, $xflags, $oscode) = 
        unpack ('CCCCVCC', $$string);

    return Z_DATA_ERROR()
        unless $magic1 == MAGIC1 and $magic2 == MAGIC2 and
           $method == Z_DEFLATED() and !($flags & RESERVED()) ;
    substr($$string, 0, MIN_HDR_SIZE) = '' ;

    # skip extra field
    if ($flags & FEXTRA)
    {
        return Z_DATA_ERROR()
            if length($$string) < 2 ;

        my ($extra_len) = unpack ('v', $$string);
        $extra_len += 2;
        return Z_DATA_ERROR()
            if length($$string) < $extra_len ;

        substr($$string, 0, $extra_len) = '';
    }

    # skip orig name
    if ($flags & FNAME)
    {
        my $name_end = index ($$string, NULL);
        return Z_DATA_ERROR()
           if $name_end == -1 ;
        substr($$string, 0, $name_end + 1) =  '';
    }

    # skip comment
    if ($flags & FCOMMENT)
    {
        my $comment_end = index ($$string, NULL);
        return Z_DATA_ERROR()
            if $comment_end == -1 ;
        substr($$string, 0, $comment_end + 1) = '';
    }

    # skip header crc
    if ($flags & FHCRC)
    {
        return Z_DATA_ERROR()
            if length ($$string) < 2 ;
        substr($$string, 0, 2) = '';
    }
    
    return Z_OK();
}


sub memGunzip
{
    # if the buffer isn't a reference, make it one
    my $string = (ref $_[0] ? $_[0] : \$_[0]);
 
    _removeGzipHeader($string) == Z_OK() 
        or return undef;
     
    my $x = inflateInit( -WindowBits => - MAX_WBITS()) 
              or return undef;
    my ($output, $status) = $x->inflate($string);
    return undef 
        unless $status == Z_STREAM_END();

    if (length $$string >= 8)
    {
        my ($crc, $len) = unpack ("VV", substr($$string, 0, 8));
        substr($$string, 0, 8) = '';
        return undef 
            unless $len == length($output) and
                   $crc == crc32($output);
    }
    else
    {
        $$string = '';
    }

    return $output;   
}

# Autoload methods go after __END__, and are processed by the autosplit program.

1;
__END__

