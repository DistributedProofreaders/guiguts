# NOTE: Derived from blib\lib\Image\Size.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Image::Size;

#line 965 "blib\lib\Image\Size.pm (autosplit into blib\lib\auto\Image\Size\psdsize.al)"
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

# end of Image::Size::psdsize
1;
