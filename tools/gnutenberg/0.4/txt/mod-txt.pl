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

# this file handles the TXT format

package format;
use strict;

use utf8;
use encoding 'utf8';

my $linelength = 74;
my $nroff_params           = "-t -S -Wall -P-f";
my $bits;
my $txt_encoding = 'unknown';

sub fix_length ($) {
    my $len = shift;
    my $unit = shift;
    my $f = qr/([-.\d]+)/; # match float

    # 12% 
    if ($len =~ m/$f\s*%/) {
        return int ($1 * $linelength / 100);
    }
    # 12em
    if ($len =~ m/$f\s*em/) {
        return int ($1 * 2);
    }
    # 12en
    if ($len =~ m/$f\s*en/) {
        return int ($1);
    }
    # 12ex
    if ($len =~ m/$f\s*ex/) {
        return int ($1);
    }
    # 12px
    if ($len =~ m/$f\s*px/) {
        return int ($1 * 8);
    }
    # 12
    if ($len =~ m/$f/) {
        return int ($1);
    }
    warn ("Unsupported length: '$len'");
    return 0;
}

sub nroff_header {
    my $header = ".de nop
..
.blm nop     \\\" empty line in input does nothing
.c2 \$        \\\" no-break control char is \$
.pl 100000   \\\" make one long page
.po 0        \\\" the left margin
.ll $linelength       \\\" the line length
.hy 0        \\\" disable hyphenation
.nr t 0 0    \\\" paragraph indent
.nr i 2 0    \\\" indent
.nr y 6 0    \\\" display indent
.nr s 1 0    \\\" paragraph spacing
.nr z 2 0    \\\" division spacing
.nr pll 0 0  \\\" previous line length (for verse)
";

return $header;

}

sub fill_nbsp ($$) {
    # format label for lists and footnotes
    my $s    = shift;
    Encode::_utf8_on ($s);
    my $len  = shift;
    my $slen = length ($s);

    my $text = '\ ' x ($len - $slen - 1);
    $text .= $s;
    $text .= "\n\x{f8e3}";
    return $text;
}

sub report_encoding {
    return $txt_encoding;
}

sub pg_rend {
    my $nl = shift;
    die "Not a nodelist" unless $nl->isa ('XML::LibXML::NodeList');

    my $n = $nl->get_node (1);
    die "Not an Element" unless $n->isa ('XML::LibXML::Element');

    my $id = $n->getAttribute ('x-id');
    my $h = $css::properties->{$id};
    my (@pre, @post);

    # blocky attributes 
    if (transform::_isblock (%$h)) {
        my $p;

        if ($p = transform::_getprop (%$h, 'x-open-block')) {
            push (@pre, "\n.br \\\" open_block hack\n");
        }

        # outside the block
        if ($p = transform::_getprop (%$h, 'margin-top')) {
            $p = fix_length ($p);
            push (@pre,  "\n.csp $p \\\" margin-top\n");
        }
        if ($p = transform::_getprop (%$h, 'margin-bottom')) {
            $p = fix_length ($p);
            push (@post, "\n.csp $p \\\" margin-bottom\n");
        }

        # blocky 
        if ($p = transform::_getprop (%$h, 'margin-left')) {
            $p = fix_length ($p);
            push (@pre,  "\n.indent +$p \\\" margin-left\n");
            push (@post, "\n.indent -$p \\\" reset margin-left\n");
        }
        if ($p = transform::_getprop (%$h, 'margin-right')) {
            $p = fix_length ($p);
            push (@pre,  "\n.ll -$p \\\" margin-right\n");
            push (@post, "\n.ll +$p \\\" reset margin-right\n");
        }
        if ($p = transform::_getprop (%$h, 'text-align')) {
            my $align = 'b';
            $align = 'l' if ($p eq 'left');
            $align = 'c' if ($p eq 'center');
            $align = 'r' if ($p eq 'right');
            $align = 'b' if ($p eq 'justify');
            
            push (@pre,  "\n.ad $align\n");
            push (@post, "\n.ad l\n");
        }
        if ($p = transform::_getprop (%$h, 'text-indent')) {
            my $hanging = ($p =~ s/\s+hanging$//);
            $p = fix_length ($p);
            if ($hanging) {
                push (@pre,  "\n.in +$p\n.ti -$p \\\" text-indent hanging\n");
                push (@post, "\n.in -$p \\\" text-indent hanging\n");
            } else {
                push (@pre,  "\n.ti $p \\\" text-indent\n");
            }
        }
        # non-inherited text-indent
#         if ($p = transform::_getprop (%$h, 'x-text-indent')) {
#             my $hanging = ($p =~ s/\s+hanging$//);
#             $p = fix_length ($p);
#             if ($hanging) {
#                 push (@pre,  "\n.in +$p\n.ti -$p \\\" x-text-indent hanging\n");
#                 push (@post, "\n.in -$p \\\" x-text-indent hanging\n");
#             } else {
#                 push (@pre,  "\n.ti $p \\\" x-text-indent\n");
#             }
#         }
        push (@post, "\n.br\n");
    }

    return transform::mk_props_node (@pre, @post);
}

sub s2_textnode {
    my $nl = shift;
    die "Not a nodelist" unless $nl->isa ('XML::LibXML::NodeList');

    my $n = $nl->get_node (1);
    die "Not an text node" unless $n->isa ('XML::LibXML::Text');

    my $id = shift;
    my $h = $css::properties->{$id};

    my $s = $n->data;
    Encode::_utf8_on ($s);

    my $p;

    # inliny attributes
    if ($s =~ m/\S/) {
        $s = transform::pg_pop_stack ('pretext') . $s;
    }

    if ($p = transform::_getprop (%$h, 'x-pre')) {
        $s = css::decode_value_strip_quotes ($p) . $s;
    }
    if ($p = transform::_getprop (%$h, 'x-post')) {
        $s = $s . css::decode_value_strip_quotes ($p);
    }

    # small-caps are rendered as uppercase
    if ($p = transform::_getprop (%$h, 'font-variant')) {
        $s = uc ($s)      if ($p eq 'small-caps');
    }
    if ($p = transform::_getprop (%$h, 'text-transform')) {
        $s = uc ($s)      if ($p eq 'uppercase');
        $s = ucfirst ($s) if ($p eq 'capitalize');
        $s = lc ($s)      if ($p eq 'lowercase');
    }
    if ($p = transform::_getprop (%$h, 'white-space')) {
        if ($p eq 'pre') {
            # replace all spaces and newlines in verbatim block
            # with non-collapsing ones
            $s =~ s/ /\x{f8e5}/g;       # non-collapsing space
            $s =~ s/\r*\n/\x{f8e4}/g;   # non-collapsing newline
        }
    }

    my $c = '';

    if ($p = transform::_getprop (%$h, 'font-weight')) {
        $c = '*' if (css::fix_font_weight ($p) > 550);
    }
    if ($p = transform::_getprop (%$h, 'font-style')) {
        $c = '_' if ($p eq 'italic');
        $c = '_' if ($p eq 'oblique');
        $c = '_' if ($p eq 'normal');
    }
    css::fix_default_italic (%$h);
    if ($p = transform::_getprop (%$h, 'x-default-italic')) {
        $c = '_';
    }
    if ($p = transform::_getprop (%$h, 'text-decoration')) {
        $c = '_' if ($p eq 'none');
        $c = '_' if ($p eq 'underline');
        $c = '-' if ($p eq 'line-through');
    }
    if ($p = transform::_getprop (%$h, 'color')) {
        $c = '_';
    }
    if ($p = transform::_getprop (%$h, 'letter-spacing')) {
        $c = '_';
    }
    return "$c$s$c";
}

sub s1_post {
    $bits = charmap::get_min_encoding ();

    $txt_encoding = 'us-ascii';
    $txt_encoding = 'iso-8859-1' if $bits == 8;
    $txt_encoding = 'utf-8'      if $bits == 16;
    transform::debug ("txt format minimal encoding: $txt_encoding");

    $transform::basename = "$transform::etext_no";
    $transform::basename .= '-8' if $bits ==  8;
    $transform::basename .= '-0' if $bits == 16;
}

sub s2 {
    charmap::WarnWGL4 ();

    transform::debug ("start compiling stylesheet");
    my $xslt2 = $transform::parser->parse_file ("$transform::root_url/xsl/tei2nroff.xsl");
    my $trans2 = $transform::xslt->parse_stylesheet ($xslt2);
    undef $xslt2;
    transform::debug ("done compiling stylesheet");

    transform::debug ("start xslt transform");
    $transform::doc = $trans2->transform ($transform::doc);
    transform::debug ("done xslt transform");

    if ($transform::debug) {
        open (TMP, ">:utf8", "$transform::outdir/$transform::basename.s2.xml");
        print TMP $transform::doc->toString ();
        close (TMP);
    }

    my $output = $trans2->output_string ($transform::doc);
    undef $trans2;

    Encode::_utf8_on ($output);

    # whitespace eater
    # this helpful character eats all whitespace following it
    # use it where XSL inserts unwanted whitespace
    $output =~ s/\x{f8e3}\s*//gm;

    # convert % to newline
    $output =~ s/\%/\n/gm;

    # convert unicode chars to nroff escapes
    $output =~ s/(\P{charmap::InNroff})/charmap::convert_nroff (ord ($1))/eg;

    # remove empty lines
    $output =~ s/\n\s+/\n/g;

    open (NROFF, ">", "$transform::outdir/$transform::basename.nroff");
    print NROFF $output;
    close (NROFF);

    {
        my $nroffdev = "-Tascii";
        $nroffdev    = "-Tlatin1" if $bits == 8;
        $nroffdev    = "-Tutf8 -F$transform::config->{'install_dir'}/txt/nroff-support"
            if $bits == 16;

        my $mode = ($bits == 16) ? ':utf8' : ':encoding(iso-8859-1)';

        my $nroffcmdline = "$transform::config->{'nroff'} $nroff_params $nroffdev";
        transform::debug ($nroffcmdline);
        open (TXT, "-|$mode", $nroffcmdline. " $transform::outdir/$transform::basename.nroff"); ##hkm
        local $/;
        my $txt = <TXT>;
        close (TXT);

        if ($bits == 16) {
           Encode::_utf8_on ($txt);
        } else {
           Encode::_utf8_off ($txt);
        }

        # remove empty space at the top
        $txt =~ s/^\s*//s;

        open (TXT, ">:crlf$mode", "$transform::outdir/$transform::basename.txt") or 
            die ("Cannot write to $transform::outdir/$transform::basename.txt");
        print TXT ($txt);
        close (TXT);
    }

    transform::debug ("written: $transform::outdir/$transform::basename.txt");
    my $member = $transform::zip->addFile ("$transform::outdir/$transform::basename.txt", "$transform::basename.txt");
    $member->desiredCompressionMethod (transform::COMPRESSION_DEFLATED);
}

sub debug_viewer {
    system ("less -r $transform::outdir/$transform::basename.txt");
}

sub register_xpath_functions () {
    my $url = "$transform::root_url/xslt";
    XML::LibXSLT->register_function ($url, "rend",         \&pg_rend);
    XML::LibXSLT->register_function ($url, "s2-textnode",  \&s2_textnode);

    XML::LibXSLT->register_function ($url, "nroff-header", \&nroff_header);
    XML::LibXSLT->register_function ($url, "fix-length",   \&fix_length);
    XML::LibXSLT->register_function ($url, "fill-nbsp",    \&fill_nbsp);
    XML::LibXSLT->register_function ($url, "get-encoding", \&pg_get_encoding);
}

return 1;
