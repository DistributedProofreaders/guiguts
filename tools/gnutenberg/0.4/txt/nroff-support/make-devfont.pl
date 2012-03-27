#! /usr/bin/perl -w
#

my %codes;
my $printed = 0;

sub print_missing_chars {
    return if $printed;
    for my $i (0x100 .. 0xFFFF) {
        unless (defined $codes{$i}) {
            printf ("---\t24\t0\t0x%04X\n", $i);
        }
    }
    $printed = 1;
}

while (<>) {
    my $in_charset = /^charset$/ .. /^kernpairs$/;

    if ($in_charset) {
        my ($name, $metrics, $type, $code) = split /\s+/;
        $codes{oct ($code)} = 1 if $code;
    }

    if (/^kernpairs$/) {
        print_missing_chars ();
    }
    print;
}

print_missing_chars ();
