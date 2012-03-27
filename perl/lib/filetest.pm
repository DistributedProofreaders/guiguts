package filetest;

our $VERSION = '1.01';

$filetest::hint_bits = 0x00400000; # HINT_FILETEST_ACCESS

sub import {
    if ( $_[1] eq 'access' ) {
	$^H |= $filetest::hint_bits;
    } else {
	die "filetest: the only implemented subpragma is 'access'.\n";
    }
}

sub unimport {
    if ( $_[1] eq 'access' ) {
	$^H &= ~$filetest::hint_bits;
    } else {
	die "filetest: the only implemented subpragma is 'access'.\n";
    }
}

1;
