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

package common;

our $outdir  = 'generated';
our $aglfile = 'adobeglyphlist.txt';

sub read_dir ($$) {
    my $dir = shift;
    my $re = shift;

    opendir (DIR, $dir);
    my @files = grep { s/$re/$1/ } readdir (DIR);
    closedir (DIR);

    # print ("read_dir: $dir $re " . scalar @files . "\n";

    return @files;
}

1;

