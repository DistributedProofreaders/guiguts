###############################################################################
#
# This file copyright (c) 2000 by Randy J. Ray, all rights reserved
#
# Copying and distribution are permitted under the terms of the Artistic
# License as distributed with Perl versions 5.005 and later.
#
###############################################################################
#
# Once upon a time, this code was lifted almost verbatim from wwwis by Alex
# Knowles, alex@ed.ac.uk. Since then, even I barely recognize it. It has
# contributions, fixes, additions and enhancements from all over the world.
#
# See the file README for change history.
#
###############################################################################

package Image::Size;

require 5.002;

use strict;
use Cwd ();
use File::Spec ();
use Symbol ();
use AutoLoader 'AUTOLOAD';
require Exporter;
use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $revision $VERSION $NO_CACHE
            %PCD_MAP $PCD_SCALE $read_in $last_pos *imagemagick_size);

BEGIN
{

    @ISA         = qw(Exporter);
    @EXPORT      = qw(imgsize);
    @EXPORT_OK   = qw(imgsize html_imgsize attr_imgsize $NO_CACHE $PCD_SCALE);
    %EXPORT_TAGS = ('all' => [ @EXPORT_OK ]);

    $revision = q$Id: Size.pm,v 1.35 2003/07/21 06:48:47 rjray Exp $;
    $VERSION = "2.992";

    # Check if we have Image::Magick available
    eval {
        local $SIG{__DIE__}; # protect against user installed die handlers
        require Image::Magick;
    };
    if ($@) {
        *imagemagick_size =
            sub
            {
                (undef, undef, "Data stream is not a known image file format");
            };
    } else {
        *imagemagick_size =
            sub
            {
                my ($file_name) = @_;
                my $img = Image::Magick->new();
                my $x = $img->Read($file_name);
                # Image::Magick error handling is a bit weird, see
                # <http://www.simplesystems.org/ImageMagick/www/perl.html#erro>
                if("$x") {
                    return (undef, undef, "$x");
                } else {
                    return ($img->Get('width', 'height', 'format'));
                }
            };
    }

}

# This allows people to specifically request that the cache not be used
$NO_CACHE = 0;

# Package lexicals - invisible to outside world, used only in imgsize
#
# Cache of files seen, and mapping of patterns to the sizing routine
my %cache = ();
my %type_map = ( '^GIF8[7,9]a'              => \&gifsize,
                 "^\xFF\xD8"                => \&jpegsize,
                 "^\x89PNG\x0d\x0a\x1a\x0a" => \&pngsize,
                 "^P[1-7]"                  => \&ppmsize, # also XVpics
                 '\#define\s+\S+\s+\d+'     => \&xbmsize,
                 '\/\* XPM \*\/'            => \&xpmsize,
                 '^MM\x00\x2a'              => \&tiffsize,
                 '^II\x2a\x00'              => \&tiffsize,
                 '^BM'                      => \&bmpsize,
                 '^8BPS'                    => \&psdsize,
                 '^PCD_OPA'                 => \&pcdsize,
                 '^FWS'                     => \&swfsize,
                 '^CWS'                     => \&swfmxsize,
                 "^\x8aMNG\x0d\x0a\x1a\x0a" => \&mngsize);
# Kodak photo-CDs are weird. Don't ask me why, you really don't want details.
%PCD_MAP = ( 'base/16' => [ 192,  128  ],
             'base/4'  => [ 384,  256  ],
             'base'    => [ 768,  512  ],
             'base4'   => [ 1536, 1024 ],
             'base16'  => [ 3072, 2048 ],
             'base64'  => [ 6144, 4096 ] );
# Default scale for PCD images
$PCD_SCALE = 'base';

#
# These are lexically-scoped anonymous subroutines for reading the three
# types of input streams. When the input to imgsize() is typed, then the
# lexical "read_in" is assigned one of these, thus allowing the individual
# routines to operate on these streams abstractly.
#

my $read_io = sub {
    my $handle = shift;
    my ($length, $offset) = @_;

    if (defined($offset) && ($offset != $last_pos))
    {
        $last_pos = $offset;
        return '' if (! seek($handle, $offset, 0));
    }

    my ($data, $rtn) = ('', 0);
    $rtn = read $handle, $data, $length;
    $data = '' unless ($rtn);
    $last_pos = tell $handle;

    $data;
};

my $read_buf = sub {
    my $buf = shift;
    my ($length, $offset) = @_;

    if (defined($offset) && ($offset != $last_pos))
    {
        $last_pos = $offset;
        return '' if ($last_pos > length($$buf));
    }

    my $data = substr($$buf, $last_pos, $length);
    $last_pos += length($data);

    $data;
};

sub imgsize
{
    my $stream = shift;

    my ($handle, $header);
    my ($x, $y, $id, $mtime, @list);
    # These only used if $stream is an existant open FH
    my ($save_pos, $need_restore) = (0, 0);
    # This is for when $stream is a locally-opened file
    my $need_close = 0;
    # This will contain the file name, if we got one
    my $file_name = undef;

    $header = '';

    if (ref($stream) eq "SCALAR")
    {
        $handle = $stream;
        $read_in = $read_buf;
        $header = substr(($$handle || ''), 0, 256);
    }
    elsif (ref $stream)
    {
        #
        # I no longer require $stream to be in the IO::* space. So I'm assuming
        # you don't hose yourself by passing a ref that can't do fileops. If
        # you do, you fix it.
        #
        $handle = $stream;
        $read_in = $read_io;
        $save_pos = tell $handle;
        $need_restore = 1;

        #
        # First alteration (didn't wait long, did I?) to the existant handle:
        #
        # assist dain-bramaged operating systems -- SWD
        # SWD: I'm a bit uncomfortable with changing the mode on a file
        # that something else "owns" ... the change is global, and there
        # is no way to reverse it.
        # But image files ought to be handled as binary anyway.
        #
        binmode($handle);
        seek($handle, 0, 0);
        read $handle, $header, 256;
        seek($handle, 0, 0);
    }
    else
    {
        unless ($NO_CACHE)
        {
            $stream = File::Spec->catfile(Cwd::cwd(),$stream)
                unless File::Spec->file_name_is_absolute($stream);
            $mtime = (stat $stream)[9];
            if (-e "$stream" and exists $cache{$stream})
            {
                @list = split(/,/, $cache{$stream}, 4);

                # Don't return the cache if the file is newer.
                return @list[1 .. 3] unless ($list[0] < $mtime);
                # In fact, clear it
                delete $cache{$stream};
            }
        }

        #first try to open the stream
        $handle = Symbol::gensym();
        open($handle, "< $stream") or
            return (undef, undef, "Can't open image file $stream: $!");

        $need_close = 1;
        # assist dain-bramaged operating systems -- SWD
        binmode($handle);
        read $handle, $header, 256;
        seek($handle, 0, 0);
        $read_in = $read_io;
        $file_name = $stream;
    }
    $last_pos = 0;

    #
    # Oh pessimism... set the values of $x and $y to the error condition. If
    # the grep() below matches the data to one of the known types, then the
    # called subroutine will override these...
    #
    $id = "Data stream is not a known image file format";
    $x  = undef;
    $y  = undef;

    grep($header =~ /$_/ && (($x, $y, $id) = &{$type_map{$_}}($handle)),
         keys %type_map);

    #
    # Added as an afterthought: I'm probably not the only one who uses the
    # same shaded-sphere image for several items on a bulleted list:
    #
    $cache{$stream} = join(',', $mtime, $x, $y, $id)
        unless ($NO_CACHE or (ref $stream) or (! defined $x));

    #
    # If we were passed an existant file handle, we need to restore the
    # old filepos:
    #
    seek($handle, $save_pos, 0) if $need_restore;
    # ...and if we opened the file ourselves, we need to close it
    close($handle) if $need_close;

    #
    # Image::Magick operates on file names.
    #
    if ($file_name && ! defined($x) && ! defined($y)) {
        ($x, $y, $id) = imagemagick_size($file_name);
    }


    # results:
    return (wantarray) ? ($x, $y, $id) : ();
}

sub html_imgsize
{
    my @args = imgsize(@_);

    # Use lowercase and quotes so that it works with xhtml.
    return ((defined $args[0]) ?
            sprintf('width="%d" height="%d"', @args) :
            undef);
}

sub attr_imgsize
{
    my @args = imgsize(@_);

    return ((defined $args[0]) ?
            (('-width', '-height', @args)[0, 2, 1, 3]) :
            undef);
}

# This used only in gifsize:
sub img_eof
{
    my $stream = shift;

    return ($last_pos >= length($$stream)) if (ref($stream) eq "SCALAR");

    eof $stream;
}


1;

__END__

###########################################################################
# Subroutine gets the size of the specified GIF
###########################################################################
sub gifsize
{
    my $stream = shift;

    my ($cmapsize, $buf, $h, $w, $x, $y, $type);

    my $gif_blockskip = sub {
        my ($skip, $type) = @_;
        my ($lbuf);

        &$read_in($stream, $skip);        # Skip header (if any)
        while (1)
        {
            if (&img_eof($stream))
            {
                return (undef, undef,
                        "Invalid/Corrupted GIF (at EOF in GIF $type)");
            }
            $lbuf = &$read_in($stream, 1);        # Block size
            last if ord($lbuf) == 0;     # Block terminator
            &$read_in($stream, ord($lbuf));  # Skip data
        }
    };

    $type = &$read_in($stream, 6);
    if (length($buf = &$read_in($stream, 7)) != 7 )
    {
        return (undef, undef, "Invalid/Corrupted GIF (bad header)");
    }
    ($x) = unpack("x4 C", $buf);
    if ($x & 0x80)
    {
        $cmapsize = 3 * (2**(($x & 0x07) + 1));
        if (! &$read_in($stream, $cmapsize))
        {
            return (undef, undef,
                    "Invalid/Corrupted GIF (global color map too small?)");
        }
    }

  FINDIMAGE:
    while (1)
    {
        if (&img_eof($stream))
        {
            return (undef, undef,
                    "Invalid/Corrupted GIF (at EOF w/o Image Descriptors)");
        }
        $buf = &$read_in($stream, 1);
        ($x) = unpack("C", $buf);
        if ($x == 0x2c)
        {
            # Image Descriptor (GIF87a, GIF89a 20.c.i)
            if (length($buf = &$read_in($stream, 8)) != 8)
            {
                return (undef, undef,
                        "Invalid/Corrupted GIF (missing image header?)");
            }
            ($x, $w, $y, $h) = unpack("x4 C4", $buf);
            $x += $w * 256;
            $y += $h * 256;
            return ($x, $y, 'GIF');
        }
        if ($x == 0x21)
        {
            # Extension Introducer (GIF89a 23.c.i, could also be in GIF87a)
            $buf = &$read_in($stream, 1);
            ($x) = unpack("C", $buf);
            if ($x == 0xF9)
            {
                # Graphic Control Extension (GIF89a 23.c.ii)
                &$read_in($stream, 6);    # Skip it
                next FINDIMAGE;       # Look again for Image Descriptor
            }
            elsif ($x == 0xFE)
            {
                # Comment Extension (GIF89a 24.c.ii)
                &$gif_blockskip(0, "Comment");
                next FINDIMAGE;       # Look again for Image Descriptor
            }
            elsif ($x == 0x01)
            {
                # Plain Text Label (GIF89a 25.c.ii)
                &$gif_blockskip(13, "text data");
                next FINDIMAGE;       # Look again for Image Descriptor
            }
            elsif ($x == 0xFF)
            {
                # Application Extension Label (GIF89a 26.c.ii)
                &$gif_blockskip(12, "application data");
                next FINDIMAGE;       # Look again for Image Descriptor
            }
            else
            {
                return (undef, undef,
                        sprintf("Invalid/Corrupted GIF (Unknown " .
                                "extension %#x)", $x));
            }
        }
        else
        {
            return (undef, undef,
                    sprintf("Invalid/Corrupted GIF (Unknown code %#x)",
                            $x));
        }
    }
}

sub xbmsize
{
    my $stream = shift;

    my $input;
    my ($x, $y, $id) = (undef, undef, "Could not determine XBM size");

    $input = &$read_in($stream, 1024);
    if ($input =~ /^\#define\s*\S*\s*(\d+)\s*\n\#define\s*\S*\s*(\d+)/si)
    {
        ($x, $y) = ($1, $2);
        $id = 'XBM';
    }

    ($x, $y, $id);
}

# Added by Randy J. Ray, 30 Jul 1996
# Size an XPM file by looking for the "X Y N W" line, where X and Y are
# dimensions, N is the total number of colors defined, and W is the width of
# a color in the ASCII representation, in characters. We only care about X & Y.
sub xpmsize
{
    my $stream = shift;

    my $line;
    my ($x, $y, $id) = (undef, undef, "Could not determine XPM size");

    while ($line = &$read_in($stream, 1024))
    {
        next unless ($line =~ /"\s*(\d+)\s+(\d+)(\s+\d+\s+\d+){1,2}\s*"/s);
        ($x, $y) = ($1, $2);
        $id = 'XPM';
        last;
    }

    ($x, $y, $id);
}


# pngsize : gets the width & height (in pixels) of a png file
# cor this program is on the cutting edge of technology! (pity it's blunt!)
#
# Re-written and tested by tmetro@vl.com
sub pngsize
{
    my $stream = shift;

    my ($x, $y, $id) = (undef, undef, "could not determine PNG size");
    my ($offset, $length);

    # Offset to first Chunk Type code = 8-byte ident + 4-byte chunk length + 1
    $offset = 12; $length = 4;
    if (&$read_in($stream, $length, $offset) eq 'IHDR')
    {
        # IHDR = Image Header
        $length = 8;
        ($x, $y) = unpack("NN", &$read_in($stream, $length));
        $id = 'PNG';
    }

    ($x, $y, $id);
}

# mngsize: gets the width and height (in pixels) of an MNG file.
# See <URL:http://www.libpng.org/pub/mng/spec/> for the specification.
#
# Basically a copy of pngsize.
sub mngsize
{
    my $stream = shift;

    my ($x, $y, $id) = (undef, undef, "could not determine MNG size");
    my ($offset, $length);

    # Offset to first Chunk Type code = 8-byte ident + 4-byte chunk length + 1
    $offset = 12; $length = 4;
    if (&$read_in($stream, $length, $offset) eq 'MHDR')
    {
        # MHDR = Image Header
        $length = 8;
        ($x, $y) = unpack("NN", &$read_in($stream, $length));
        $id = 'MNG';
    }

    ($x, $y, $id);
}

# jpegsize: gets the width and height (in pixels) of a jpeg file
# Andrew Tong, werdna@ugcs.caltech.edu           February 14, 1995
# modified slightly by alex@ed.ac.uk
# and further still by rjray@blackperl.com
# optimization and general re-write from tmetro@vl.com
sub jpegsize
{
    my $stream = shift;

    my $MARKER      = "\xFF";       # Section marker.

    my $SIZE_FIRST  = 0xC0;         # Range of segment identifier codes
    my $SIZE_LAST   = 0xC3;         #  that hold size info.

    my ($x, $y, $id) = (undef, undef, "could not determine JPEG size");

    my ($marker, $code, $length);
    my $segheader;

    # Dummy read to skip header ID
    &$read_in($stream, 2);
    while (1)
    {
        $length = 4;
        $segheader = &$read_in($stream, $length);

        # Extract the segment header.
        ($marker, $code, $length) = unpack("a a n", $segheader);

        # Verify that it's a valid segment.
        if ($marker ne $MARKER)
        {
            # Was it there?
            $id = "JPEG marker not found";
            last;
        }
        elsif ((ord($code) >= $SIZE_FIRST) && (ord($code) <= $SIZE_LAST))
        {
            # Segments that contain size info
            $length = 5;
            ($y, $x) = unpack("xnn", &$read_in($stream, $length));
            $id = 'JPG';
            last;
        }
        else
        {
            # Dummy read to skip over data
            &$read_in($stream, ($length - 2));
        }
    }

    ($x, $y, $id);
}

# ppmsize: gets data on the PPM/PGM/PBM family.
#
# Contributed by Carsten Dominik <dominik@strw.LeidenUniv.nl>
sub ppmsize
{
    my $stream = shift;

    my ($x, $y, $id) = (undef, undef,
                        "Unable to determine size of PPM/PGM/PBM data");
    my $n;

    my $header = &$read_in($stream, 1024);

    # PPM file of some sort
    $header =~ s/^\#.*//mg;
    ($n, $x, $y) = ($header =~ /^(P[1-6])\s+(\d+)\s+(\d+)/s);
    $id = "PBM" if $n eq "P1" || $n eq "P4";
    $id = "PGM" if $n eq "P2" || $n eq "P5";
    $id = "PPM" if $n eq "P3" || $n eq "P6";
    if ($n eq 'P7')
    {
        # John Bradley's XV thumbnail pics (thanks to inwap@jomis.Tymnet.COM)
        $id = 'XV';
        ($x, $y) = ($header =~ /IMGINFO:(\d+)x(\d+)/s);
    }

    ($x, $y, $id);
}

# tiffsize: size a TIFF image
#
# Contributed by Cloyce Spradling <cloyce@headgear.org>
sub tiffsize {
    my $stream = shift;

    my ($x, $y, $id) = (undef, undef, "Unable to determine size of TIFF data");

    my $endian = 'n';           # Default to big-endian; I like it better
    my $header = &$read_in($stream, 4);
    $endian = 'v' if ($header =~ /II\x2a\x00/o); # little-endian

    # Set up an association between data types and their corresponding
    # pack/unpack specification.  Don't take any special pains to deal with
    # signed numbers; treat them as unsigned because none of the image
    # dimensions should ever be negative.  (I hope.)
    my @packspec = ( undef,     # nothing (shouldn't happen)
                     'C',       # BYTE (8-bit unsigned integer)
                     undef,     # ASCII
                     $endian,   # SHORT (16-bit unsigned integer)
                     uc($endian), # LONG (32-bit unsigned integer)
                     undef,     # RATIONAL
                     'c',       # SBYTE (8-bit signed integer)
                     undef,     # UNDEFINED
                     $endian,   # SSHORT (16-bit unsigned integer)
                     uc($endian), # SLONG (32-bit unsigned integer)
                     );

    my $offset = &$read_in($stream, 4, 4); # Get offset to IFD
    $offset = unpack(uc($endian), $offset); # Fix it so we can use it

    my $ifd = &$read_in($stream, 2, $offset); # Get number of directory entries
    my $num_dirent = unpack($endian, $ifd); # Make it useful
    $offset += 2;
    $num_dirent = $offset + ($num_dirent * 12); # Calc. maximum offset of IFD

    # Do all the work
    $ifd = '';
    my $tag = 0;
    my $type = 0;
    while (!defined($x) || !defined($y)) {
        $ifd = &$read_in($stream, 12, $offset); # Get first directory entry
        last if (($ifd eq '') || ($offset > $num_dirent));
        $offset += 12;
        $tag = unpack($endian, $ifd); # ...and decode its tag
        $type = unpack($endian, substr($ifd, 2, 2)); # ...and the data type
        # Check the type for sanity.
        next if (($type > @packspec+0) || (!defined($packspec[$type])));
        if ($tag == 0x0100) {   # ImageWidth (x)
            # Decode the value
            $x = unpack($packspec[$type], substr($ifd, 8, 4));
        } elsif ($tag == 0x0101) {      # ImageLength (y)
            # Decode the value
            $y = unpack($packspec[$type], substr($ifd, 8, 4));
        }
    }

    # Decide if we were successful or not
    if (defined($x) && defined($y)) {
        $id = 'TIF';
    } else {
        $id = '';
        $id = 'ImageWidth ' if (!defined($x));
        if (!defined ($y)) {
            $id .= 'and ' if ($id ne '');
            $id .= 'ImageLength ';
        }
        $id .= 'tag(s) could not be found';
    }

    ($x, $y, $id);
}

# bmpsize: size a Windows-ish BitMaP image
#
# Adapted from code contributed by Aldo Calpini <a.calpini@romagiubileo.it>
sub bmpsize
{
    my $stream = shift;

    my ($x, $y, $id) = (undef, undef, "Unable to determine size of BMP data");
    my ($buffer);

    $buffer = &$read_in($stream, 26);
    ($x, $y) = unpack("x18VV", $buffer);
    $id = 'BMP' if (defined $x and defined $y);

    ($x, $y, $id);
}

# psdsize: determine the size of a PhotoShop save-file (*.PSD)
sub psdsize
{
    my $stream = shift;

    my ($x, $y, $id) = (undef, undef, "Unable to determine size of PSD data");
    my ($buffer);

    $buffer = &$read_in($stream, 26);
    ($y, $x) = unpack("x14NN", $buffer);
    $id = 'PSD' if (defined $x and defined $y);

    ($x, $y, $id);
}

# swfsize: determine size of ShockWave/Flash files. Adapted from code sent by
# Dmitry Dorofeev <dima@yasp.com>
sub swfsize
{
    my $image  = shift;
    my $header = &$read_in($image, 33);

    sub _bin2int { unpack("N", pack("B32", substr("0" x 32 . shift, -32))); }

    my $ver = _bin2int(unpack 'B8', substr($header, 3, 1));
    my $bs = unpack 'B133', substr($header, 8, 17);
    my $bits = _bin2int(substr($bs, 0, 5));
    my $x = int(_bin2int(substr($bs, 5+$bits, $bits))/20);
    my $y = int(_bin2int(substr($bs, 5+$bits*3, $bits))/20);

    return ($x, $y, 'SWF');
}

# Suggested by Matt Mueller <mueller@wetafx.co.nz>, and based on a piece of
# sample Perl code by a currently-unknown author. Credit will be placed here
# once the name is determined.
sub pcdsize
{
    my $stream = shift;

    my ($x, $y, $id) = (undef, undef, "Unable to determine size of PCD data");
    my $buffer = &$read_in($stream, 0xf00);

    # Second-tier sanity check
    return ($x, $y, $id) unless (substr($buffer, 0x800, 3) eq 'PCD');

    my $orient = ord(substr($buffer, 0x0e02, 1)) & 1; # Clear down to one bit
    ($x, $y) = @{$Image::Size::PCD_MAP{lc $Image::Size::PCD_SCALE}}
        [($orient ? (0, 1) : (1, 0))];

    return ($x, $y, 'PCD');
}

# swfmxsize: determine size of compressed ShockWave/Flash MX files. Adapted
# from code sent by Victor Kuriashkin <victor@yasp.com>
sub swfmxsize
{
    require Compress::Zlib;

    my ($image) = @_;
    my $header = &$read_in($image, 1058);
    sub _bin2int { unpack("N", pack("B32", substr("0" x 32 . shift, -32))); }
    my $ver = _bin2int(unpack 'B8', substr($header, 3, 1));

    $header = substr($header, 8, 1024);
    $header = Compress::Zlib::uncompress($header);
    my $bs = unpack 'B133', substr($header, 0, 9);
    my $bits = _bin2int(substr($bs, 0, 5));
    my $x = int(_bin2int(substr($bs, 5+$bits, $bits))/20);
    my $y = int(_bin2int(substr($bs, 5+$bits*3, $bits))/20);

    return ($x, $y, 'SWC');
}
