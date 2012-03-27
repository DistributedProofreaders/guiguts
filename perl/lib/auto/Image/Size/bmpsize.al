# NOTE: Derived from blib\lib\Image\Size.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Image::Size;

#line 948 "blib\lib\Image\Size.pm (autosplit into blib\lib\auto\Image\Size\bmpsize.al)"
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

# end of Image::Size::bmpsize
1;
