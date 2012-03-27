#!/usr/bin/perl
#$Id: update_unicore.pl 235 2009-12-07 18:37:05Z vlsimpson $

use strict;
use warnings;
use Config;
use LWP::UserAgent;
$|++;

my $url = 'http://www.unicode.org/Public/UNIDATA/';

my $libpath = $Config{installprivlib};

$libpath .= '/unicore/';

die "$libpath does not exist; exiting." unless -e $libpath;

my @files = qw/
    ArabicShaping.txt
    BidiMirroring.txt
    Blocks.txt
    CaseFolding.txt
    CompositionExclusions.txt
    EastAsianWidth.txt
    HangulSyllableType.txt
    Index.txt
    Jamo.txt
    LineBreak.txt
    NamesList.txt
    NormalizationCorrections.txt
    PropertyAliases.txt
    PropList.txt
    Scripts.txt
    SpecialCasing.txt
    StandardizedVariants.txt
    UnicodeData.txt
    PropertyValueAliases.txt
    /;

my $ua = LWP::UserAgent->new(
    env_proxy  => 1,
    keep_alive => 1,
    timeout    => 60,
);

print "Downloading Unicode data files from $url\n\n";

get_files( $url, @files );

print "\nRenaming PropertyValueAliases.txt to PropValueAliases.txt.\n";
rename 'PropertyValueAliases.txt', 'PropValueAliases.txt';

$files[-1] = 'PropValueAliases.txt';

my $libmode = get_mode($libpath);

unless ( substr( $libmode, 1, 1 ) eq '7' ) {
    chmod 0777, $libpath or die "Can not modify permissions. $!.\n";
}

print "Copying files to $libpath.\n";

for ( @files, 'mktables.pl' ) {
    force_unlink( $libpath . $_ );
    print "Moving $_ to $libpath.\n";
    rename $_, $libpath . $_;
}

chmod 0755, $libpath . 'mktables.pl';

chdir $libpath;

system 'perl mktables.pl -v -w';

chmod $libmode, $libpath;

print "\n\nFinished; unicore is up to date.";

sub get_files {
    my ( $url, @files ) = @_;
    for my $file (@files) {
        print "Getting $file. ";
        if ( -e $file ) {
            print " Already downloaded, skipping...\n";
            next;
        }
        my $time     = time;
        my $response = $ua->get( $url . $file );
        if ( $response->is_success ) {
            print ' Downloaded - ';
        }
        else {
            if ( time - $time > 20 ) {
                warn "Timed out, restarting.\n";
                exec "perl $0";
            }
            die $response->status_line
                . " Are you connected to the internet?\n";
        }
        open my $fh, '>', $file
            or die "\n\nCould not write file $file. $!.\n";
        my $thisfile = $response->content;
        $thisfile =~ s/\cM\cJ|\cM|\cJ/\n/g;
        print $fh $thisfile;
        close $fh;
        my $size = sprintf( "%.1f", ( ( stat($file) )[7] / 1024 ) );
        print $size, "KB written.\n";
    }
}

sub get_mode {
    my $file = shift;
    return sprintf "%04o", ( stat($file) )[2] & 07777;
}

sub force_unlink {
    my $filename = shift;
    return unless -e $filename;
    return if CORE::unlink($filename);

    # We might need write permission
    chmod 0777, $filename;
    CORE::unlink($filename) or die "Couldn't unlink $filename: $!.\n";
}

