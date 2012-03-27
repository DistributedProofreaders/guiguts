#!/usr/bin/perl -w
#
# The Gnutenberg Press - pdftex truetype fontmap utility
# Copyright (C) 2005  Marcello Perathoner
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#

# utility to prepare Type1 and truetype fonts for use in the Gnutenberg Press
# called from installfonts.pl, don't call this directly

# Using Unicode Fonts in TeX

# The main limitation of TeX is that it doesn't handle characters
# greater than 0xff. To handle characters up to 0xffff we define 256
# new encodings named 'U00' to 'Uff'. Each encoding encodes all 256
# characters from one unicode page. Also, we chop up a truetype font
# into up to 256 different TeX fonts, each of which contains up to 256
# characters in a different encoding. Unicode character [U+0x1234]
# would end up as the character at position 0x34 in the font encoded
# with encoding 'U12'. 

# If we want to print this character in TeX, we request a font with
# encoding 'U12' and then output symbol 0x34. This means: if the
# selected font family contains a font with encoding U12 then that
# font will be used, otherwise TeX looks for a different font in
# encoding U12 and uses that one. Thus, you may get characters from
# different fonts mixed up, but you will get the character if any of
# the installed fonts contains it.


# $t1encfile  = 'T1-WGL4.enc';

use strict;
require 'common.pl';

die ("Usage: $0 /path/to/fontfile.ttf") if (scalar @ARGV < 1);

my $fontfile = $ARGV[0];
die ("I see no such file here ($fontfile)") unless -r $fontfile;

my $fontbasename = $fontfile;
$fontbasename =~ s!^.*/(.*?)$!$1!;
$fontbasename =~ s/\.(.*)$//;
my $ext = $1;

my $agl = {};
my $fontname;

sub get_ttf_coverage ($) {
    my $encfile = shift;

    if (open (ENC, "<$encfile")) {
        local $/;
        my $s = <ENC>;
        close (ENC);

        $s =~ s/^.*\[\s*//;
        $s =~ s/\s*\].*$//;

        my @chars = map { ($_ eq '/.notdef') ? 0 : 1 } split (/\s+/, $s);
        die "Bogus file: $encfile" unless (scalar @chars) == 256;

        return join ('', @chars);
    }
    return '';
}

sub get_afm_coverage ($) {
    my $afmfile = shift;

    open (AFM, "<:crlf", $afmfile) or die ("Cannot read $afmfile");
    my $good = 0;
    my $codepoints = {};
    foreach my $s (<AFM>) {
        $fontname = $1 if $s =~ m/^FontName\s+(.*)$/;
        $good = 1      if $s =~ m/^StartCharMetrics/;
        $good = 0      if $s =~ m/^EndCharMetrics/;
        next unless $good;

        if ($s =~ m/; N (\S+) ;/) {
            if (exists $agl->{$1}) {
                my $cp = $agl->{$1};
                $codepoints->{$cp} = 1;
            } else {
                print ("unknown character name $1\n");
            }
        }
    }
    close AFM;

    return $codepoints;
}

########################################################################

open (MAP, ">$common::outdir/$fontbasename.map") 
    or die ("Cannot write fontmap $common::outdir/$fontbasename.map");

if ($ext eq 'ttf') {
    # make Uxx encoded fonts from TrueType font
    system("ttf2tfm $fontfile -w $common::outdir/${fontbasename}U\@Unicode\@"); ##hkm
    
    my @encs = common::read_dir ($common::outdir, qr/^($fontbasename.*)\.enc$/);

    foreach my $enc (sort @encs) {
        open (COV, ">$common::outdir/$enc.cov") or die ("Cannot write coverage file $common::outdir/$enc.cov");;
        print COV get_ttf_coverage ("$common::outdir/$enc.enc");
        close (COV);
    }

    my @tfms = common::read_dir ($common::outdir, qr/^(${fontbasename}U[0-9a-f]{2})\.tfm$/i);

    ### make fontmap file
    # GenR101U00 GenR101U00 " GenR101U00Encoding ReEncodeFont " <GenR101.ttf <GenR101U00.enc

    foreach my $tfm (sort @tfms) {
        print MAP "$tfm $tfm \" ${tfm}Encoding ReEncodeFont \" <$fontfile <$tfm.enc\n";
    }
}

if ($ext eq 'afm') {
    open (AGL, "<:crlf", $common::aglfile) 
        or die ("Cannot read $common::aglfile");

    foreach my $line (<AGL>) {
        next if $line =~ m/^\#/;
        next unless $line =~ m/(\w+);([0-9a-f]+)/i;
        $agl->{$1} = hex ($2);
    }
    close AGL;
    
    system ("perl makefontencoding.pl") unless -r "$common::outdir/U00.enc"; ## hkm

    my $codepoints = get_afm_coverage ($fontfile);

    my %codepages = map { ($_ >> 8) => 1 } keys %$codepoints;

    # from adobe Type1 font metrics
    foreach my $codepage (sort {$a <=> $b} keys %codepages) {
        # outputs correct mapfile entry
        my $enc = sprintf ("U%02x", $codepage);
        `afm2tfm $fontfile -p $common::outdir/$enc.enc $common::outdir/$fontbasename$enc.tfm`;

        print MAP "$fontbasename$enc $fontname \" ${enc}Encoding ReEncodeFont \" <$enc.enc\n";
        
        open (COV, ">$common::outdir/$fontbasename$enc.cov") 
            or die ("Cannot write coverage file $common::outdir/$fontbasename$enc.cov");

        foreach my $i (($codepage << 8) .. ($codepage << 8) + 0xFF) {
            print COV exists $codepoints->{$i} ? '1' : '0';
        }
        close (COV);
    }
}

close (MAP);
