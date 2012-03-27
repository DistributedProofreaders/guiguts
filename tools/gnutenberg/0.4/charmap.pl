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

# FIXME needs a thorough rewrite

package charmap;
use strict;

use utf8;
use encoding 'utf8';
use charnames ':full';

########################################################################
# This section deals mostly with character sets and entities,
# which are most difficult to do in XSLT.
#
# There are some characters that would cause trouble in TeX and nroff
# if left unescaped. We get those characters out of the way by
# encoding them into Unicode private chars (code point range U+F8E0..U+F8FF).
# When the pipe splits into backend-specific pipes we put those
# characters back with the appropriate escapes for that backend.
#
########################################################################

# map of unicode code point =>
#  [substitute on input, html representation, nroff representation,
# tex representation, pdf bookmark representation]

# on input: if we find the character we substitute it with
# the unicode private codepoint

# on output: if we find the code point we substitute it with the
# appropriate backend-specific representation

my $entities = {

0x27   => [undef, undef,   undef,        undef,               undef],       # apos
0xa0   => [undef, undef,   '\ ',         '{\penalty\@M \ }',  ' '],         # nbsp
0xad   => [undef, undef,   '\%',         undef,               ''],          # shy

# ISO Latin Extended-A

0x152  => [undef, undef,   undef,        undef,        'OE'],        # OElig
0x153  => [undef, undef,   undef,        undef,        'oe'],        # oelig

# Unicode General Punctuation

0x2002 => [undef, undef,   '\ ',         '{\kern.5em}',    ' '],     # ensp
0x2003 => [undef, undef,   '\ \ ',       '{\kern1em}',     ' '],     # emsp
0x2009 => [undef, undef,   '\ ',         '{\kern.1667em}', ' '],     # thinsp
0x200d => [undef, '',      '\&',         '{\kern0pt}',     ''],      # zwj, not present in all fonts

0x2013 => [undef, undef,   undef,        undef,        '-'],         # ndash
0x2014 => [undef, undef,   undef,        undef,        '--'],        # mdash

0x2015 => [undef, '&mdash;&mdash;',
                           '\(em\(em',   '\u{20}{20}\u{20}{20}',
                                                       '----'],      # qdash, not present in all fonts

0x2018 => [undef, undef,   undef,        undef,        "`"],         # lsquo
0x2019 => [undef, undef,   undef,        undef,        "'"],         # rsquo
0x201a => [undef, undef,   undef,        undef,        ","],         # sbquo

0x201c => [undef, undef,   undef,        undef,        '"'],         # ldquo
0x201d => [undef, undef,   undef,        undef,        '"'],         # rdquo
0x201e => [undef, undef,   undef,        undef,        '"'],         # bdquo

0x2020 => [undef, undef,   undef,        undef,        '+'],         # dagger
0x2021 => [undef, undef,   undef,        undef,        '++'],        # Dagger
0x2022 => [undef, undef,   undef,        undef,        '*'],         # bull
0x2026 => [undef, undef,   undef,        undef,        '...'],       # hellip
0x2030 => [undef, undef,   undef,        undef,        '\%.'],       # permil
0x2032 => [undef, undef,   undef,        undef,        "'"],         # prime
0x2033 => [undef, undef,   undef,        undef,        "''"],        # Prime

0x2039 => [undef, undef,   undef,        undef,        '<'],         # lsaquo
0x203a => [undef, undef,   undef,        undef,        '>'],         # rsaquo

0x20ac => [undef, undef,   undef,        undef,        'EUR'],       # euro
0x2122 => [undef, undef,   undef,        undef,        '(tm)'],      # trade

# private stuff
# if you renumber these, always check the xsl and transform.pl

0xf8ff => ["\\",  "\\",    '\(rs',       '\u{00}{92}',  undef],
0xf8fe => ['{',   '{',     '{',          '\u{00}{123}', undef],
0xf8fd => ['}',   '}',     '}',          '\u{00}{125}', undef],
0xf8fc => ['#',   '#',     "\\N'35'",    '\u{00}{35}',  '#'],
0xf8fb => ['%',   '%',     "\\N'37'",    '\u{00}{37}',  '%'],
0xf8fa => ['$',   '$',     "\\N'36'",    '\u{00}{36}',  '$'],
0xf8f9 => ['^',   '^',     "\\N'94'",    '\u{00}{94}',  '^'],
0xf8f8 => ['_',   '_',     "\\N'95'",    '\u{00}{95}',  '_'],
0xf8f7 => ['~',   '~',     "\\N'126'",   '\u{00}{126}', '~'],
0xf8f6 => ["'",   "'",     "'",          '\u{00}{39}',  "'"],
0xf8f5 => ['`',   '`',     '`',          '\u{00}{96}',  "`"],
0xf8f4 => ['-',   '-',     '\-',         '\u{00}{45}',  '-'],
0xf8f3 => [undef, '>',     '>',          '>',           '>'],
0xf8f2 => ['.',   '.',     "\\N'46'",    '.',           '.'],
0xf8f1 => [undef, '<',     '<',          '<',           '<'],
0xf8f0 => ['&',   '&amp;', '&',          '\u{00}{38}',  '&'],


0xf8e5 => [undef, undef,   '\ ',         '{\enskip}',                 ' '],   # verbatim space
0xf8e4 => [undef, undef,   "\\ \n.br\n", "\\ \\teipar\n\\noindent{}", ' '],   # verbatim newline

# this little critter eats all trailing whitespace
0xf8e3 => [undef, undef,   undef,        undef,                       undef],

};

# see: man perlunicode "User-Defined Character Properties"

sub InOutbandedChars {
    # these are the private codepoints we use to outband TeX and nroff
    # special chars
    return <<END;
+f8e0 f8ff
END
}

sub InHtml {
    # characters that need replacement in internal => html
    # zwj qdash
    return <<END;
+200d
+2015
+charmap::InOutbandedChars
END
}

sub InTex {
    # characters that need replacement in internal => tex
    # nbsp shy ensp emsp thinsp zwj qdash
    return <<END;
+00a0
+00ad
+2002
+2003
+2009
+200d
+2015
+charmap::InOutbandedChars
END
}

sub InNroff {
    return <<END;
+0000 007f
END
}

sub InWGL4 {
# Windows Glyph List 4.0
# see: http://www.microsoft.com/typography/otspec/WGL4.htm
    return <<END;
+0020 007e
+00a0 00ff
+0100 017f
+0192
+01fa 01ff
+02c6
+02c7
+02c9
+02d8 02dd
+0384 038a
+038c
+038e 03a1
+03a3 03ce
+0401 040c
+040e 044f
+0451 045c
+045e
+045f
+0490
+0491
+1e80 1e85
+1ef2
+1ef3
+2013 2015
+2017 201e
+2020 2022
+2026
+2030
+2032
+2033
+2039
+203a
+203c
+203e
+2044
+207f
+20a3
+20a4
+20a7
+20ac
+2105
+2113
+2116
+2122
+2126
+212e
+215b 215e
+2190 2195
+21a8
+2202
+2206
+220f
+2211
+2212
+2215
+2219
+221a
+221e
+221f
+2229
+222b
+2248
+2260
+2261
+2264
+2265
+2302
+2310
+2320
+2321
+2500
+2502
+250c
+2510
+2514
+2518
+251c
+2524
+252c
+2534
+253c
+2550 256c
+2580
+2584
+2588
+258c
+2590 2593
+25a0
+25a1
+25aa 25ac
+25b2
+25ba
+25bc
+25c4
+25ca
+25cb
+25cf
+25d8
+25d9
+25e6
+263a 263c
+2640
+2642
+2660
+2663
+2665
+2666
+266a
+266b
+f001
+f002
+fb01
+fb02
END
}

sub InNoWarn {
# don't warn for these chars
    return <<END;
+0020
+00a0
+00ad
+2002
+2003
+2009
+200d
END
};

sub NotInWGL4 {
# Warn if we find these characters in text
    return <<END;
+0000 ffff
-charmap::InWGL4
-charmap::InNoWarn
END
};

my $read_charmap_files = {}; # avoid inclusion loops
my %charmap;           # document-local character mapping
our $codepoints = {};  # a count of codepoints for charset detection

# nodelist of collected charmap notes to display to the user
our $notes = new XML::LibXML::NodeList ();

# language name to ISO 639a code
my $id2language = {
    'ab' => 'Abkhazian',
    'om' => 'Afan',
    'aa' => 'Afar',
    'af' => 'Afrikaans',
    'sq' => 'Albanian',
    'am' => 'Amharic',
    'ar' => 'Arabic',
    'hy' => 'Armenian',
    'as' => 'Assamese',
    'ay' => 'Aymara',
    'az' => 'Azerbaijani',
    'bn' => 'Bangla',
    'ba' => 'Bashkir',
    'eu' => 'Basque',
    'bn' => 'Bengali',
    'dz' => 'Bhutani',
    'bh' => 'Bihari',
    'bi' => 'Bislama',
    'br' => 'Breton',
    'bg' => 'Bulgarian',
    'my' => 'Burmese',
    'be' => 'Byelorussian',
    'km' => 'Cambodian',
    'ca' => 'Catalan',
    'zh' => 'Chinese',
    'co' => 'Corsican',
    'hr' => 'Croatian',
    'cs' => 'Czech',
    'da' => 'Danish',
    'nl' => 'Dutch',
    'en' => 'English',
    'en-gb' => 'British',
    'en-us' => 'American',
    'eo' => 'Esperanto',
    'et' => 'Estonian',
    'fo' => 'Faroese',
    'fa' => 'Farsi',
    'fj' => 'Fiji',
    'fi' => 'Finnish',
    'fr' => 'French',
    'fy' => 'Frisian',
    'gl' => 'Galician',
    'ka' => 'Georgian',
    'de' => 'German',
    'el' => 'Greek',
    'kl' => 'Greenlandic',
    'gn' => 'Guarani',
    'gu' => 'Gujarati',
    'ha' => 'Hausa',
    'he' => 'Hebrew',
    'hi' => 'Hindi',
    'hu' => 'Hungarian',
    'is' => 'Icelandic',
    'id' => 'Indonesian',
    'ia' => 'Interlingua',
    'ie' => 'Interlingue',
    'iu' => 'Inuktitut',
    'ik' => 'Inupiak',
    'ga' => 'Irish',
    'it' => 'Italian',
    'ja' => 'Japanese',
    'jv' => 'Javanese',
    'kn' => 'Kannada',
    'ks' => 'Kashmiri',
    'kk' => 'Kazakh',
    'rw' => 'Kinyarwanda',
    'ky' => 'Kirghiz',
    'ko' => 'Korean',
    'ku' => 'Kurdish',
    'rn' => 'Kurundi',
    'lo' => 'Laothian',
    'la' => 'Latin',
    'lv' => 'Latvian',
    'lv' => 'Lettish',
    'ln' => 'Lingala',
    'lt' => 'Lithuanian',
    'mk' => 'Macedonian',
    'mg' => 'Malagasy',
    'ms' => 'Malay',
    'ml' => 'Malayalam',
    'mt' => 'Maltese',
    'mi' => 'Maori',
    'mr' => 'Marathi',
    'mo' => 'Moldavian',
    'mn' => 'Mongolian',
    'na' => 'Nauru',
    'ne' => 'Nepali',
    'no' => 'Norwegian',
    'oc' => 'Occitan',
    'or' => 'Oriya',
    'om' => 'Oromo',
    'ps' => 'Pashto',
    'fa' => 'Persian',
    'pl' => 'Polish',
    'pt' => 'Portuguese',
    'pa' => 'Punjabi',
    'ps' => 'Pushto',
    'qu' => 'Quechua',
    'rm' => 'Rhaeto-Romance',
    'ro' => 'Romanian',
    'ru' => 'Russian',
    'sm' => 'Samoan',
    'sg' => 'Sangho',
    'sa' => 'Sanskrit',
    'gd' => 'Scots Gaelic',
    'sr' => 'Serbian',
    'sh' => 'Serbo-Croatian',
    'st' => 'Sesotho',
    'tn' => 'Setswana',
    'sn' => 'Shona',
    'sd' => 'Sindhi',
    'si' => 'Singhalese',
    'ss' => 'Siswati',
    'sk' => 'Slovak',
    'sl' => 'Slovenian',
    'so' => 'Somali',
    'es' => 'Spanish',
    'su' => 'Sundanese',
    'sw' => 'Swahili',
    'sv' => 'Swedish',
    'tl' => 'Tagalog',
    'tg' => 'Tajik',
    'ta' => 'Tamil',
    'tt' => 'Tatar',
    'te' => 'Telugu',
    'th' => 'Thai',
    'bo' => 'Tibetan',
    'ti' => 'Tigrinya',
    'to' => 'Tonga',
    'ts' => 'Tsonga',
    'tr' => 'Turkish',
    'tk' => 'Turkmen',
    'tw' => 'Twi',
    'ug' => 'Uigur',
    'uk' => 'Ukrainian',
    'ur' => 'Urdu',
    'uz' => 'Uzbek',
    'vi' => 'Vietnamese',
    'vo' => 'Volapuk',
    'cy' => 'Welsh',
    'wo' => 'Wolof',
    'xh' => 'Xhosa',
    'yi' => 'Yiddish',
    'yo' => 'Yoruba',
    'za' => 'Zhuang',
    'zu' => 'Zulu',
};

sub id2lang {
    my $id = shift;
    return $id2language->{$id};
}

sub get_min_encoding {
    my @cps = sort {$a <=> $b} keys %$codepoints;

    my $max = $cps[$#cps];
    return  7 if $max < 128;
    return  8 if $max < 256;
    return 16;
}

sub print_codepoints (\%) {
    my $codepoints = shift;
    my $cplist = '';
    foreach my $cp (sort {$a <=> $b} keys %$codepoints) {
        my $name = charnames::viacode ($cp);
        $name = 'n.n.' if (!defined $name);
        $cplist .= sprintf ("  U+0x%04x: %6d (%s)\n",
                            $cp, $codepoints->{$cp}, $name);
    }
    return $cplist;
}

sub get_unicode_pages {
    my $unicodepages = {};
    foreach my $codepoint (keys %$codepoints) {
        my $c = chr ($codepoint);
        if ($c =~ m/\P{InOutbandedChars}/) {
            $unicodepages->{$codepoint >> 8} = 1;
        }
    }
    return $unicodepages;
}

sub get_codepoints_filter ($) {
    # filter codepoints thru regular expression
    my $re = shift;

    my $h = {};
    foreach (keys %$codepoints) {
        my $c = chr ($_);
        if ($c =~ m/$re/) {
            $h->{$_} = $codepoints->{$_};
        }
    }
    return $h;
}

sub get_codepoints {
    return $codepoints;
}

# Put some code points out of band (into unicode private use area).
# Most of these characters are command and escape characters
# in TeX or nroff and just get in the way if we leave them there.

sub apply_charmap {
    my $c = shift;
    $c = $charmap{$c} if defined $charmap{$c};
    return $c;
}

sub count_codepoints {
    my $c = shift;
    $codepoints->{ord($c)}++ if (length ($c));
    return $c;
}

sub read_charmap ($) {
    # param: pgCharMap node
    my $map = shift;
    die "Not an Element"  unless $map->isa ('XML::LibXML::Element');
    die "Not a pgCharMap" unless $map->nodeName eq 'pgCharMap';

    my $href = $map->getAttribute ('href');
    if (defined $href) {
        read_charmap_file ($href);
        return;
    }

    my $name = $map->getAttribute ('n');

    my $doit = 1;
    if ($map->hasAttribute ("formats")) {
        $doit = 0;
        foreach my $fmt (split (/\s+/, $map->getAttribute ("formats"))) {
            $doit = 1 if $fmt eq $transform::subformat;
        }
    }
    return unless $doit;

    transform::debug ("Reading charmap: $name");

    $notes->push ($map->getChildrenByTagName ('note'));

    foreach my $char ($map->getChildrenByTagName ('char')) {
        my $id       = $char->getAttribute ("id");
        my $desc     = $char->getChildrenByTagName ("desc");
        my $mapping  = $char->getChildrenByTagName ("mapping");
        if ($id && $mapping) {
            if ($id =~ m/^U([0-9a-fx]+)$/i) {
                $id = $1;
                $id = ($id =~ m/^0/) ? oct ($id) : int ($id);
                my $s = $mapping->shift()->textContent;
                $charmap{chr($id)} = $s;
                transform::debug (sprintf ("mapping: U+0x%04x to '%s' (%s)", $id, $s, $desc));
            }
        }
    }
}

sub read_charmap_file ($) {
    my $href= shift;

    return if (exists $read_charmap_files->{$href});
    $read_charmap_files->{$href} = 1;

    my $parser = XML::LibXML->new ();
    my $doc;
    eval {
        $doc = $parser->parse_file ($href);
    };
    die $@ if $@;

    my @maps = $doc->findnodes ("/pgExtensions/pgCharMap");

    foreach my $map (@maps) {
        read_charmap ($map);
    }
}

sub read_charmaps ($\@) {
    my $doc = shift;
    my $mapfiles = shift;

    # read TEI-embedded map first
    my @maps = $doc->findnodes ("/TEI.2/pgExtensions/pgCharMap");
    foreach my $map (@maps) {
        read_charmap ($map);
    }

    # read mapfiles given on command line
    foreach my $mapfile (@$mapfiles) {
        read_charmap_file ($mapfile);
    }
}

sub WarnWGL4 {
#    my $cpw;# = get_codepoints_filter ('\p{NotInWGL4}');
#    if (%$cpw) {
#        warn ("Warning: These characters are not in WGL-4.
#Most users won't have fonts containing these characters.
#" . print_codepoints (%$cpw));
#    }
}

sub convert_utf {
    my $c = ord (shift);
    my $ord = shift;

    return $entities->{$c}[$ord] if (defined $entities->{$c}[$ord]);
    return "&#$c;";
}

sub ent2char {
    my $ent = shift;

    my $c = int ($ent);
    if ($ent =~ /x([0-9a-f]+)/i) {
        $c = hex ($1);
    }
    return $c;
}

sub convert_html {
    my $c = shift;
    #print "$c\n";
    return $entities->{$c}[1] if (defined $entities->{$c}[1]);

    return "&#$c;";
}

sub convert_nroff {
    my $c = shift;
    return $entities->{$c}[2] if (defined $entities->{$c}[2]);

    return "\\N'$c'";
}

sub convert_tex {
    my $c = shift;
    return $entities->{$c}[3] if (defined $entities->{$c}[3]);

    return chr ($c);
}

sub convert_pdfoutline ($\$) {
    my $c = shift;
    my $err = shift;
    my $n = ord ($c);
    return $entities->{$n}[4] if (defined $entities->{$n}[4]);
    return $c if $n < 256;
    $$err = 1;
    return '_';
}


my $outbandhash = {};
my $inbandhash = {};

while (my ($key, $value) = each (%$entities)) {
    if (defined $value->[0]) {
        my $v = $value->[0];
        # print "$v:$key\n";
        $outbandhash->{$v} = chr ($key);
    }
}

while (my ($key, $value) = each (%$entities)) {
    if (defined $value->[0]) {
        my $v = $value->[0];
        # print "$v:$key\n";
        $inbandhash->{chr($key)} = $v;
    }
}

sub outband {
    my $c = shift;
    return $outbandhash->{$c} if defined $outbandhash->{$c};
    return $c;
}

sub inband {
    my $c = shift;
    return $inbandhash->{$c} if defined $inbandhash->{$c};
    return $c;
}

1;

# Local Variables:
# mode:perl
# coding:utf-8-unix
# End:
