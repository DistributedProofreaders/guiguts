#!/usr/bin/perl -w
#
# The Gnutenberg Press - TeX hyphenation pattern preparation utility
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

# use this to prepare TeX hyphenation patterns for the Gnutenberg Press
# (we need those patterns in unicode, free from all those silly 
# tex macros)
#
# usage: 
# ./makehyphenpatterns hyphen.tex > patterns.en
# ./makehyphenpatterns dehypht.tex > patterns.de
# etc.

use utf8;
use encoding 'utf8';

binmode (STDOUT, ':utf8');

my $patterns = '';
my $hyphenation = '';

local $/ = undef;
$_ = <>;

my $lang = 'en';

if (m/(\w\w)hyph\w?\.tex/) {
    $lang = $1;
}

s/%.*?$//gsm;	              # drop comments

s/^.*\\patterns\s*\{\s*//s;   # drop everything up to patterns
$patterns = $_;
$patterns =~ s/\n}.*$//s;

if (/\\hyphenation/) {
    s/^.*\\hyphenation\s*\{\s*//s;
    $hyphenation = $_;
    $hyphenation =~ s/\n}.*$//s;
}

if ($lang eq 'de') {
    # fixes for dehyph?
    $patterns =~ s!\S*\\c\S+!!g;
    $patterns =~ s!\\3!ß!g;
    $patterns =~ s!\"a!ä!g;
    $patterns =~ s!\"o!ö!g;
    $patterns =~ s!\"u!ü!g;
    $patterns =~ s!\"A!Ä!g;
    $patterns =~ s!\"O!Ö!g;
    $patterns =~ s!\"U!Ü!g;
}

if ($lang eq 'fr') {
    # fixes for frhyph

    $patterns =~ s!\\\`a!à!g;
    $patterns =~ s!\\\^a!â!g;

    $patterns =~ s!\\c\{c\}!ç!g;

    $patterns =~ s!\\\`e!è!g;
    $patterns =~ s!\\\'e!é!g;
    $patterns =~ s!\\\^e!ê!g;
    $patterns =~ s!\\\"e!ë!g;

    $patterns =~ s!\\\^i!î!g;
    $patterns =~ s!\\\"i!ï!g;

    $patterns =~ s!\\\^o!ô!g;

    $patterns =~ s!\\oeOT!\x{153}!g;
    $patterns =~ s!\\oe!\x{153}!g;

    $patterns =~ s!\\\`u!ù!g;
    $patterns =~ s!\\\^u!û!g;
    $patterns =~ s!\\\"u!ü!g;

    $patterns =~ s!\\\"y!ÿ!g;
}

$patterns =~ s!\\n\{(.*?)\}!$1!g;

print "% encoding: utf-8\n% patterns\n";

for (split (/\s+/, $patterns)) {
    last if $_ eq '}';

    s!\\x\{([0-9a-f]+)\}!chr(hex($1))!eg; # convert \x{abcd}
    s!\^\^([0-9a-f]{2})!chr(hex($1))!eg;  # convert ^^ab

    s/(\D)(?!\d)/${1}0/g;                 # insert zeroes
    s/^(?!\d)/0/g;		          # 
    
    my $pat = lc ($_);

    print "$pat\n";
}

print "% hyphenation\n";

for (split (/\s+/, $hyphenation)) {
    last if $_ eq '}';

    $_ = ".$_.";

    s!-!9!g;

    s/(\D)(?!\d)/${1}8/g;		  # insert no-breaks
    s!^(\D)!8$1!;		          # 

    my $pat = lc ($_);

    print "$pat\n";
}

# Local Variables:
# mode:perl
# coding:utf-8-unix
# End:
