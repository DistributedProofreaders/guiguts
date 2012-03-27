#!/usr/bin/perl -w
#
# The Gnutenberg Press - font installation utility
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

# this reads pgtei-fonts.cfg and
# from the therein mentioned font files it produces .tfm, .enc, .cov files
# and also .map files for font families
#
# pgtei-fonts.inc is to be included in the tex document preamble
# pgtei-fonts.coverage contains information about the characters in each font

use strict;
require 'common.pl';

# input
my $cfgfile = "pgtei-fonts.cfg";

# output
my $incfile = "$common::outdir/pgtei-fonts.inc";
my $covfile = "$common::outdir/pgtei-fonts.coverage";

###

my %declared_encodings;
my %declared_families;
my %declared_substitutions;
my $defaultfontline;
my %defaults;

my @lines;
my ($family, $range, $series, $shape, $fontfile);
my %fonts;

sub pdf_declare_encoding ($) {
    my $enc = shift;
    return "\\DeclareFontEncoding\{$enc}\{}\{}\n";
}

sub pdf_declare_substitution ($$) {
    my ($enc, $family) = @_;
    return "\\DeclareFontSubstitution\{$enc}\{$family}\{m}\{n}\n";
}

sub pdf_declare_family ($$) {
    my ($enc, $family) = @_;
    my $hc = ($enc eq 'U00') ? '`-' : '-1';

    return "\\DeclareFontFamily\{$enc}\{$family}\{\\hyphenchar\\font=$hc\\relax }\n";
}

sub pdf_declare_shape ($$$$$) {
    my ($enc, $family, $series, $shape, $fontfile) = @_;

    return "\\DeclareFontShape\{$enc}\{$family}\{$series}\{$shape}\{<-> $fontfile$enc}\{}\n";
}

sub decode_range ($) {
    my $ranges = shift;
    ### decode page ranges eg. 00-05,20,21
    my $pages = {};
    foreach my $range (split (/,/, $ranges)) {
        my $r = qr/[0-9a-f]{1,2}/i;
        if ($range =~ m/^($r)-($r)$/) {
            for (hex($1) .. hex($2)) {
                $pages->{sprintf ("U%02x", $_)} = 1;
            }
        } elsif ($range =~ m/^($r)$/i) {
            $pages->{"U$1"} = 1;
        }
    }
    return $pages;
}

sub get_coverage ($) {
    my $fontbasename = shift;
    my $covfile = "$common::outdir/$fontbasename.cov";
    open (COV, "<$covfile") or die ("Cannot read font coverage file $covfile");
    local $/;
    my $s = <COV>;
    close (COV);
    return $s;
}

################################################################################
### slurp config file and predigest lines

open (CFG, "<$cfgfile") or die ("Cannot read $cfgfile");
while (<CFG>) {
    s/\#.*$//;
    chomp;
    next unless length ($_);

    if (/^(\w\wdefault)\s+(.+)$/) {
        $defaults{$1} = $2;
        next;
    }        
    push (@lines, $_);
}
close (CFG);

### write tex config and font coverage file

open (INC,   ">$incfile") or die ("Cannot write $incfile");
open (COVER, ">$covfile") or die ("Cannot write $covfile");

print INC "%
% $incfile
% this is a generated file -- do not edit
% edit $cfgfile and run $0
%

";

### get all font files and map them

foreach my $line (@lines) {
    ($family, $range, $series, $shape, $fontfile) = split (/\s+/, $line);

    my $fontbasename = $fontfile;
    $fontbasename =~ s!^.*/(.*?)$!$1!;
    $fontbasename =~ s/\..*$//;

    my $encs = decode_range ($range);

    print "running makefontmap on $fontfile\n";

    system ("perl makefontmap.pl $fontfile");  ##hkm `./makefontmap.pl $fontfile`;

    ### add cov files to pgtei-fonts.coverage

    my @files = common::read_dir ($common::outdir, qr/^$fontbasename(.*?)\.cov$/i);
    my $encodings = {};

    foreach my $enc (@files) {
        next unless exists $encs->{$enc};
        $encodings->{$enc} = 1;
        # U22/gentium/m/n: 01010...
        print COVER "$enc/$family/$series/$shape: " . get_coverage ("$fontbasename$enc") . "\n";
    }

    $fonts{$fontfile} = $encodings;
    print INC "\\pdfmapfile\{+$fontbasename.map}\n";
}

close (COVER);

print INC "\n";

### print all used encodings

foreach my $line (@lines) {
    ($family, $range, $series, $shape, $fontfile) = split (/\s+/, $line);

    my $pages = decode_range ($range);

    foreach my $page (sort keys %$pages) {
        if (exists $fonts{$fontfile}{$page}) {
            $declared_encodings{$page} = 1;
        }
    }
}

foreach my $enc (sort keys %declared_encodings) {
    print INC pdf_declare_encoding ($enc);
}

print INC "\n";

### declare font families

foreach my $line (@lines) {
    ($family, $range, $series, $shape, $fontfile) = split (/\s+/, $line);

    print INC "%\n% $family $range $series $shape $fontfile\n%\n";

    my $fontbasename = $fontfile;
    $fontbasename =~ s!^.*/(.*?)$!$1!;
    $fontbasename =~ s/\..*$//;

    my $pages = decode_range ($range);

    ### remove pages not in font
    foreach my $page (sort keys %$pages) {
        if (!exists $fonts{$fontfile}{$page}) {
            delete ($pages->{$page});
        }
    }

    ### is this a candidate default font ?

    if (!defined ($defaultfontline) && exists $pages->{'U00'}) {
        $defaultfontline = $line;
    }

    ### declare families

    foreach my $page (sort keys %$pages) {
        if (!exists $declared_families{"$page$family"}) {
            print INC pdf_declare_family ($page, $family);
            $declared_families{"$page$family"} = 1;
        }
    }

    print INC "\n";

    ### declare default shapes
    # use the first font that has contains page

    foreach my $page (sort keys %$pages) {
        if (!exists $declared_substitutions{$page}) {
            print INC pdf_declare_substitution ($page, $family);
            $declared_substitutions{$page} = 1;
        }
    }

    print INC "\n";

    ### declare shapes

    foreach my $page (sort keys %$pages) {
        print INC pdf_declare_shape ($page, $family, $series, $shape, $fontbasename);
    }

    print INC "\n";
}

($family, $range, $series, $shape, $fontfile) = split (/\s+/, $defaultfontline);

sub rc ($$) {
    my ($name, $cmd) = @_;
    print INC "\\renewcommand\{\\$name}\{$cmd}\n";
}

rc ('encodingdefault', 'U00');
rc ('familydefault',   $family);
rc ('seriesdefault',   $series);
rc ('shapedefault',    $shape);

foreach (sort keys %defaults) {
    rc ($_, $defaults{$_});
}

print INC "

\\normalfont

%
% end of $incfile
%
";

close (INC);
