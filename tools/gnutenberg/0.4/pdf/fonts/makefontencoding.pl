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

# called by makefontmap.pl, don't run directly

# this takes the official adobe glyph list and generates 256 encoding files
# need this to encode the Acrobat Reader resident fonts

use strict;
require 'common.pl';

my $pages = {};

### read glyph names from adobe glyph list

open (AGL, "<:crlf", $common::aglfile) or die ("Cannot read file $common::aglfile. Need $common::aglfile in current dir.");

while (<AGL>) {
    s/\#.*$//;
    chomp;

    next unless length ($_);
    
    my ($name, $pos) = split (/;/, $_);

    next unless $pos =~ m/^[0-9a-f]+$/i;

    $pos = hex ($pos);
    my $page = $pos >> 8;
    $pos -= $page << 8;
    
    $pages->{$page}{$pos} = $name;
}

close (AGL);

### generate encoding files

foreach my $page (sort keys %$pages) {
    open (ENC, sprintf (">%s/U%02x.enc", $common::outdir, $page));
    printf ENC ("/U%02xEncoding [", $page);

    foreach my $pos (0 .. 255) {
        printf ENC ("\n\n%% %02x%02x", $page, $pos) if ($pos % 16 == 0);
        print  ENC "\n" if ($pos % 4 == 0);
        my $h = $pages->{$page};
        if (exists ($h->{$pos})) {
            # print /name
            print ENC "/$h->{$pos} ";
        } else {
            # print /uni1234
            printf ENC ("/uni%02x%02x ", $page, $pos);
        }
    }
    print ENC "\n] def\n";

    close (ENC);
}


