#!/usr/bin/perl -w
#
# The Gnutenberg Press - Conversion Process Driver
# Copyright (C) 2004-2005  Marcello Perathoner
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

# test the hyphenation module
# usage : ./hyphentest englishwordtohyphenate

use strict;
use utf8;
use encoding 'utf8';

require '../Hyphen.pm';

my $hyp = new Hyphen (
                      file       => 'patterns.en',
                      hyphenchar => '-',
                      leftmin    => 2,
                      rightmin   => 2,
                      debug      => 1,
                      );

my $word = $ARGV[0];
$word = $hyp->hyphenate ($word);

# show debug info

my ($s, $chars, $values);
$s = $hyp->{'lastpattern'};
($chars  = $s) =~ s/\d/ /g;
($values = $s) =~ s/\D/ /g;
print "$chars\n$values\n";

# show hyphenated word

print "$word\n";
