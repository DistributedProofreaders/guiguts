package PerlIO::via::QuotedPrint;

# Set the version info
# Make sure we do things by the book from now on

$VERSION = '0.06';
use strict;

# Make sure the encoding/decoding stuff is available

use MIME::QuotedPrint (); # no need to pollute this namespace

# Satisfy -require-

1;

#-----------------------------------------------------------------------
#  IN: 1 class to bless with
#      2 mode string (ignored)
#      3 file handle of PerlIO layer below (ignored)
# OUT: 1 blessed object

sub PUSHED { bless \*PUSHED,$_[0] } #PUSHED

#-----------------------------------------------------------------------
#  IN: 1 instantiated object (ignored)
#      2 handle to read from
# OUT: 1 decoded string

sub FILL {

# Read the line from the handle
# Decode if there is something decode and return result or signal eof

    my $line = readline( $_[1] );
    (defined $line) ? MIME::QuotedPrint::decode_qp( $line ) : undef;
} #FILL

#-----------------------------------------------------------------------
#  IN: 1 instantiated object (ignored)
#      2 buffer to be written
#      3 handle to write to
# OUT: 1 number of bytes written

sub WRITE {

# Encode whatever needs to be encoded and write to handle: indicate result

    (print {$_[2]} MIME::QuotedPrint::encode_qp($_[1])) ? length($_[1]) : -1;
} #WRITE

__END__

