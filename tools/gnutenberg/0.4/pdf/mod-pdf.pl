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

# this file handles the PDF format

package format;
use strict;

use utf8;
use encoding 'utf8';
use charnames ':full';

my $parindent = '12pt';

my $supdir = "$transform::config->{'install_dir'}/pdf/fonts";
my $gendir = "$supdir/generated";

my $texfontaliases = {
    'times roman'            => 'times',
    'times new roman'        => 'times',
    'monospace'              => 'courier',
};

my $current_family = 'times';
my $current_series = 'm';
my $current_shape  = 'n';

my $char2fonts = {};
my $fonts = {};

sub fix_length ($\%@) {
    my $len = shift;
    my $h   = shift;
    my $unit = shift;

    my $f = qr/([-.\d]+)/; # match float

    # 12%
    if ($len =~ m/$f\s*%/) {
        return sprintf ("%.2f%s", $1 * 0.01, $unit);
    }
    # 12px
    if ($len =~ m/$f\s*px/) {
        return sprintf ("%.2fcm", $1 * 0.21);
    }
    # 12pt
    if ($len =~ m/$f\s*pt/) {
        return sprintf ("%.2fpt", $1);
    }
    # !
    if ($len eq '!') {
        return $len; # latex special meaning
    }

    my $fs = transform::_getprop (%$h, 'font-size');
    $fs = 1.0 if !defined ($fs);

    # 12em
    if ($len =~ m/$f\s*em/) {
        return sprintf ("%.2fem", $1 * $fs);
    }
    # 12en
    if ($len =~ m/$f\s*en/) {
        return sprintf ("%.2fem", $1 * 0.5 * $fs);
    }
    # 12ex
    if ($len =~ m/$f\s*ex/) {
        return sprintf ("%.2fem", $1 * 0.5 * $fs);
    }
    # 12
    if ($len =~ m/$f/) {
        return sprintf ("%.2fem", $1 * 0.5 * $fs);
    }

    warn ("Unsupported length: $len");
    return 0;
}

sub fix_vlength ($\%@) {
    # insert some slop to ease pagination
    my $len  = shift;
    my $h    = shift;
    my $unit = shift;
    return fix_length ($len, %$h, $unit) . ' plus12pt minus3pt\relax';
}

sub pg_fix_length {
    my $len  = shift;
    my $h    = {};
    my $unit = shift;
    return fix_length ($len, %$h, $unit);
}

sub fontdiff ($) {
    # returns the "demerits" of this font in relation to 
    # the currently selected font
    
    my ($encoding, $family, $series, $shape) = split (/\//, shift ());
    my $diff = 0;
    
    $diff += 1 if ($family ne $current_family);
    $diff += 2 if ($shape  ne $current_shape);
    $diff += 4 if ($series ne $current_series);

    return $diff;
}

sub get_most_similar_font ($) {
    # from all fonts containing this character
    # return the one most "similar" to the selected one
    # similarity is defined in fontdemerits ()
    my $cp   = shift;
    my $page = $cp >> 8;
    my $i    = $cp & 0xFF;

    return undef unless exists $char2fonts->{$page};
    return undef unless exists $char2fonts->{$page}[$i];

    my $fonts = $char2fonts->{$page}[$i]; # array ref
    my @afonts = sort { fontdiff ($a) <=> fontdiff ($b) } @$fonts;
    return $afonts[0];
}

sub has_char ($) {
    # has the current font this char?
    my $cp = shift;
    my $page = $cp >> 8;
    my $i    = $cp & 0xFF;

    my $encoding = sprintf ("U%02x", $page);

    my $font = "$encoding/$current_family/$current_series/$current_shape";
    return 0 unless exists $fonts->{$font};

    return substr ($fonts->{$font}, $i, 1) eq '1';
}

sub font_hack ($) {
    my $c = shift;
    my $cp = ord ($c);

    return $c if ($cp < 0x80);

    my $page = $cp >> 8;
    my $i    = $cp & 0xFF;

    return sprintf ("\\u\{%02x}\{%d}", $page, $i) if (has_char ($cp));

    my $font = get_most_similar_font ($cp);
    if (!defined ($font)) {
        transform::debug (sprintf ("Missing: U+%02x", $cp));
        return "\\vrule width1em height1em depth0pt\\relax";
    }

    transform::debug (sprintf ("Substituting $current_family/$current_series/$current_shape => $font for U+%02x", $cp));

    my ($encoding, $family, $series, $shape) = split (/\//, $font);

    return sprintf ("\{\\usefont\{%s}\{%s}\{%s}\{%s}\\selectfont\\u\{%02x}\{%d}}", 
                    $encoding, $family, $series, $shape, $page, $i);
}

sub tex_header {
# about 60 chars per line
# about 40 lines per page
    my $pdflineskip = $transform::pdffontsize * 1.3;

    my $papername   = 'a5paper';

    my $paperwidth  = 29.7 / 2;
    my $outermargin = $paperwidth * 2 / 9;
    my $innermargin = $paperwidth     / 9;
    my $textwidth   = $paperwidth - $outermargin - $innermargin;

    my $paperheight = 21;
    my $topmargin   = $paperheight     / 9;
    my $textheight  = $paperheight * 7 / 9;

    my $marginparwidth = $outermargin * 6 / 9;
    my $marginparsep   = $outermargin * 1 / 9;

    my $header = "\\NeedsTeXFormat\{LaTeX2e}[1994/06/01]
\\documentclass[$papername,${transform::pdffontsize}pt,openright]\{book}

\% \\usepackage\{ucs}
\% \\usepackage[utf8]\{inputenc} \% utf8x needs debian latex-ucs package
\% \\DeclareUnicodeCharacter{8213}{\\textemdash\\nobreak\\textemdash}

";

    ### declare ttf fonts and encodings

    $header .= declare_truetype_fonts ();

    ### preload unicode pages and characters

#     my $unicodepages = charmap::get_unicode_pages ();
#     foreach my $unicodepage (sort keys %$unicodepages) {
#         $header .= "\\PreloadUnicodePage\{$unicodepage}\n";
#     }
#     $header .= "\\PreloadUnicodePage\{3}\n";
#     $header .= "\\PrerenderUnicode\{";

#     my $codepoints = charmap::get_codepoints ();
#     foreach my $codepoint (grep {$_ > 127} sort keys %$codepoints) {
#         my $c = chr ($codepoint);
#         if ($c =~ m/\P{charmap::InTex}/) {
#             $header .= chr ($codepoint);
#         }
#     }
#     $header .= "}\n";

    my @titles = $transform::doc->findnodes ('/TEI.2/teiHeader/fileDesc/titleStmt/title');
    my $title  = $titles[0]->textContent;

    my $authors = $transform::doc->findnodes ('/TEI.2/teiHeader/fileDesc/titleStmt/author');
    my $author  = transform::pg_get_author ($authors);

    my @tables = $transform::doc->findnodes ('//table');
    my $longtable = (scalar @tables) ? '\usepackage{longtable}' : '';

    my @formulas = $transform::doc->findnodes ('//formula[@notation="tex"]');
    my $amstex = (scalar @formulas) ? '\\usepackage{amsmath}
\\usepackage{amsfonts}
\\usepackage{amssymb}
' : '';

    # breaks diacritics
    $header .= '\makeatletter

\def\u#1#2{{\fontencoding{U#1}\selectfont\symbol{#2}}}

\def\shy{\discretionary{\u{00}{45}}{}{}}

% underline

\def\uldimens{\dimen2=1.5\dp0\dimen1=\dimen2\advance\dimen1 -.5pt%
\dimen0=\wd0\advance\dimen0 .5pt\relax}

\def\ul#1{\setbox0=\hbox{\vphantom{y}#1}\copy0\hbox to 0pt%
{\hss\uldimens\leaders\hrule height-\dimen1 depth\dimen2\hskip\dimen0}}

\def\ulglue{\setbox0=\hbox{\vphantom{y}}%
\uldimens\leaders\hrule height-\dimen1 depth\dimen2\hskip.33em plus.1em minus.1em}

% line-through

\def\stdimens{\dimen2=-.5ex\dimen1=\dimen2\advance\dimen1 -.5pt%
\dimen0=\wd0\advance\dimen0 .5pt\relax}

\def\st#1{\setbox0=\hbox{\vphantom{y}#1}\copy0\hbox to 0pt%
{\hss\stdimens\leaders\hrule height-\dimen1 depth\dimen2\hskip\dimen0}}

\def\stglue{\setbox0=\hbox{\vphantom{y}}%
\stdimens\leaders\hrule height-\dimen1 depth\dimen2\hskip.33em plus.1em minus.1em}

% superscript and subscript without math mode

\def\textsuperscript#1{{\raise 1ex\hbox{\footnotesize #1}}}
\def\textsubscript#1{{\raise -.8ex\hbox{\footnotesize #1}}}

';

    $header .= "
\% \\usepackage\{textcomp}

\\usepackage\[pdftex]\{color}
\\usepackage\[pdftex]\{graphics}
$longtable
$amstex

\\pdfinfo \{
  /Author      ($author)
  /Title       ($title)
}

\\def\\teititle\{$title}

\% do not compress PDF
\% a zipped compressed PDF is 25% bigger than a zipped uncompressed PDF
\% if your deliverables are not zipped set this to 9
\\pdfcompresslevel=0

\\listfiles

\\setlength\\hoffset          {-1in}
\\setlength\\voffset          {-1in}

\\setlength\\paperwidth       \{$paperwidth cm}
\\setlength\\paperheight      \{$paperheight cm}

\\setlength\\textwidth        \{$textwidth cm}
\\setlength\\textheight       \{$textheight cm}

\\setlength\\evensidemargin   \{$outermargin cm}
\\setlength\\oddsidemargin    \{$innermargin cm}
\\setlength\\topmargin        \{$topmargin cm}

\\addtolength\\topmargin      {-\\headheight}
\\addtolength\\topmargin      {-\\headsep}

\\setlength\\marginparwidth   \{$marginparwidth cm}
\\setlength\\marginparsep     \{$marginparsep cm}

\\setlength\\parindent        {0pt}
\\newlength\\dispindent
\\setlength\\dispindent       {6pt}

\\parskip=0pt \% we insert parskip when needed

\\newlength\\basefontsize
\\setlength\\basefontsize     \{${transform::pdffontsize}pt}

\\newlength\\basebaselineskip
\\setlength\\basebaselineskip     \{${pdflineskip}pt}

";

$header .= '

% \skip\footins=12pt plus1fil minus4pt

% define better looking footnote style

\renewcommand\@makefntext[1]{%
    \noindent\hb@xt@' . $parindent . '{\hss\@makefnmark\ }#1}

% we need the strut inserted inside the last \par
% or an empty line will appear at the bottom of the footnote

\long\def\@footnotetext#1{\insert\footins{%
    \reset@font\footnotesize
    \interlinepenalty\interfootnotelinepenalty
    \splittopskip\footnotesep
    \splitmaxdepth \dp\strutbox \floatingpenalty \@MM
    \hsize\columnwidth \@parboxrestore
    \parindent=0pt\parskip=0pt
    \protected@edef\@currentlabel{%
       \csname p@footnote\endcsname\@thefnmark
    }%
    \color@begingroup
      \@makefntext{%
        \rule\z@\footnotesep\ignorespaces#1}%
    \color@endgroup}}%

\def\fns{\nobreak\vrule\@width\z@\@height\z@\@depth\dp\strutbox}

';

    return $header;
};

sub pg_rend {
    my $nl = shift;
    die "Not a nodelist" unless $nl->isa ('XML::LibXML::NodeList');

    my $n = $nl->get_node (1);
    die "Not an Element" unless $n->isa ('XML::LibXML::Element');

    my $id = $n->getAttribute ('x-id');
    my $h = $css::properties->{$id};
    my ($p, $value, @pre, @post);
    $value = '';

    # blocky attributes 
    if (transform::_isblock (%$h)) {

        if ($p = transform::_getprop (%$h, 'x-open-block')) {
            push (@pre, "\\teipar % open_block hack\n");
        }

        # outside the block

        if ($p = transform::_getprop (%$h, 'page-break-before')) {
            $value = "\n\\clearpage % page-break-before\n\\thispagestyle\{plain}\n\n" 
                if ($p eq 'always');
            $value = "\n\\cleardoublepage % page-break-before\n\\thispagestyle\{plain}\n\n"
                if ($p eq 'right');
            $value = "\n\\penalty10000\n"
                if ($p eq 'avoid');
            $value = "\n\\vfil\\penalty-500\\vfilneg\n"
                if ($p eq 'auto');
            push (@pre, $value);
        }
        if ($p = transform::_getprop (%$h, 'page-break-after')) {
            $value = "\n\\clearpage % page-break-before\n\\thispagestyle\{plain}\n\n" 
                if ($p eq 'always');
            $value = "\n\\cleardoublepage % page-break-before\n\\thispagestyle\{plain}\n\n"
                if ($p eq 'right');
            $value = "\n\\penalty10000\n"
                if ($p eq 'avoid');
            $value = "\n\\vfil\\penalty-500\\vfilneg\n"
                if ($p eq 'auto');
            push (@post, $value);
        }
        if ($p = transform::_getprop (%$h, 'x-pdf-penalty-after')) {
            push (@post, "\\penalty $p\{}");
        }

        if ($p = transform::_getprop (%$h, 'page-float')) {
            $value = css::decode ($p);
            $value =~ s/[^htbp]//g;
            push (@pre,  "\n\\begin{figure}[$value]\n");
            push (@post, "\n\\end{figure}\n\\penalty-200\n");
        }

        if ($p = transform::_getprop (%$h, 'margin-top')) {
            $p = fix_vlength ($p, %$h);
            push (@pre,  "\n\\teivmargin{$p} % margin-top\n");
        }
        if ($p = transform::_getprop (%$h, 'margin-bottom')) {
            $p = fix_vlength ($p, %$h);
            push (@post, "\n\\teivmargin{$p} % margin-bottom\n");
        }

        # start of block 

        push (@pre,  "\{% <$h->{'x-nodename'}>\n");
        push (@post, "\\teipar}% </$h->{'x-nodename'}>\n\x{f8e3}"); # eat whitespace after

        if ($p = transform::_getprop (%$h, 'page-break-inside')) {
            push (@pre, '\interlinepenalty=10000{}') if ($p eq 'avoid');
        }
        if ($p = transform::_getprop (%$h, 'x-pdf-parskip')) {
            $p = fix_length ($p, %$h);
            push (@pre, "\\parskip=$p\{}");
        }

        if ($p = transform::_getprop (%$h, 'margin-left')) {
            $p = fix_length ($p, %$h);
            push (@pre,  "\\leftindent{$p}");
        }
        if ($p = transform::_getprop (%$h, 'margin-right')) {
            $p = fix_length ($p, %$h);
            push (@pre,  "\\rightindent{$p}");
        }
        if ($p = transform::_getprop (%$h, 'text-align')) {
            push (@pre, '\teileftalign{}')   if $p eq 'left';
            push (@pre, '\teicenteralign{}') if $p eq 'center';
            push (@pre, '\teirightalign{}')  if $p eq 'right';
        }
        if ($p = transform::_getprop (%$h, 'hyphenate')) {
            push (@pre, '\hyphenpenalty10000{}')   if $p eq 'none';
        }

        if ($p = transform::_getprop (%$h, 'text-indent')) {
            my $hanging = ($p =~ s/\s+hanging$//);
            $p = fix_length ($p, %$h);
            if ($hanging) {
                push (@pre, "\\hangafter=1\\hangindent=$p\n");
            } else {
                push (@pre, "\\hskip $p\\relax\n");
            }
        }
        # non-inherited text-indent
#         if ($p = transform::_getprop (%$h, 'x-text-indent')) {
#             my $hanging = ($p =~ s/\s+hanging$//);
#             $p = fix_length ($p, %$h);
#             if ($hanging) {
#                 push (@pre, "\\hangafter=1\\hangindent=$p\n");
#             } else {
#                 push (@pre, "\\hskip $p\\relax\n");
#             }
#         }
        if ($p = transform::_getprop (%$h, 'font-size')) {
            # this is font-size on a block element
            # we need baselineskip to be in scope when \par is called
            push (@pre, "\\fontsize\{$p\\basefontsize}\{$p\\basebaselineskip}\\selectfont\{}");
        }
    }
    return transform::mk_props_node (@pre, @post);
};

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
    my $parens = 0; # set this if your code needs a local scope

    $current_family = 'times';
    $current_series = 'm';
    $current_shape  = 'n';

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
    if ($p = transform::_getprop (%$h, 'x-pdf-footnote')) {
        # put a strut into every text inside footnote
        # see also: redefinition of \@footnotetext in preamble
        if ($s =~ m/\S/) {
            $s .= '{\fns}',
        }
    }

    ### order of these transformations is important !

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

    if ($p = transform::_getprop (%$h, 'text-decoration')) {
        if ($p eq 'underline') {
            $s =~ s/([^\s\x{ad}]+)/\\ul\{$1\}/g; 
            $s =~ s/\s+/\{\\ulglue\}/g;
            # alternative: insert U+0332 combining low line
        }
        if ($p eq 'line-through') {
            $s =~ s/([^\s\x{ad}]+)/\\st\{$1\}/g; 
            $s =~ s/\s+/\{\\stglue\}/g;
            # alternative: insert U+0336 combining long stroke overlay
        }
    }
    if ($p = transform::_getprop (%$h, 'letter-spacing')) {
        $p = fix_length ($p, %$h);
        $s =~ s/([^\s\x{ad}]+)/pdf_kern_word($1,$p)/eg; # insert kerns
        $s =~ s/\s+/\{\\space\\space\\space\}/g;
        $s =~ s/[\x{ad}]/\\discretionary\{\\kern$p\\u\{00\}\{45\}\}\{\}\{\\kern$p\}/g;
    }
    if ($p = transform::_getprop (%$h, 'font-variant')) {
        if ($p eq 'small-caps') {
            $s =~ s/([[:lower:]]+)/"\{\\scriptsize " . uc($1) . '}'/eg;
        }
    }

    ### color

    if ($p = transform::_getprop (%$h, 'color')) {
        my $color = texcolor ($p);
        $s = "\\textcolor$color\{$s}";
    }

    ### italic 

    if ($p = transform::_getprop (%$h, 'font-style')) {
        if ($p eq 'normal') {
            $s = "\\upshape\{}$s";
            $current_shape = 'n';
        }
        if ($p eq 'italic') {
            $s = "\\itshape\{}$s";
            $current_shape = 'it';
        }
        if ($p eq 'oblique') {
            $s = "\\slshape\{}$s";
            $current_shape = 'sl';
        }
        $parens = 1;
    }
    css::fix_default_italic (%$h);
    if ($p = transform::_getprop (%$h, 'x-default-italic')) {
        $s = "\\itshape\{}$s";
        $current_shape = 'it';
        $parens = 1;
    }

    ###

    if ($p = transform::_getprop (%$h, 'vertical-align')) {
        if ($p eq 'super') {
            $s = "\\textsuperscript\{$s}";
        }
        if ($p eq 'sub') {
            $s = "\\textsubscript\{$s}";
        }
    }

    if ($p = transform::_getprop (%$h, 'font-weight')) {
        if (css::fix_font_weight ($p) > 550) {
            $s = "\\bfseries\{}$s";
            $current_series = 'b';
        } else {
            $s = "\\mdseries\{}$s";
            $current_series = 'm';
        }
        $parens = 1;
    }

    ### font stuff

    if ($p = transform::_getprop (%$h, 'font-size')) {
        # this is font-size on an inlined element
        # we rely on lineskiplimit here
        $s = "\\fontsize\{$p\\basefontsize}\{$p\\basebaselineskip}\\selectfont\{}$s";
        $parens = 1;
    }
    if ($p = transform::_getprop (%$h, 'font-variant')) {
        # $s = "\\scshape\{}$s" if ($p eq 'small-caps');
        $s = "\\upshape\{}$s" if ($p eq 'normal');
        $parens = 1;
    }
    if ($p = transform::_getprop (%$h, 'font-family')) {
        my $ff = lc (css::decode_value_strip_quotes ($p));
        if (exists $texfontaliases->{$ff}) {
            $ff = $texfontaliases->{$ff};
        }
        $ff =~ s/\s+//g; # tex doesnt like spaces in font names
        $current_family = $ff;
        $s = "\\fontfamily\{$ff}\\selectfont\{}$s";
        $parens = 1;
    }
    
    ### font hacks

    $s =~ s/\x{c2}\x{ad}/\{\\shy}/g;
    $s =~ s/(\P{charmap::InTex})/font_hack($1)/eg;
    
    # $s = "\\normalfont{}$s";

    if ($parens) {
        return "\{$s}";
    }
    return $s;
}

sub report_encoding {
    return undef;
}

sub s1_post {
    $transform::basename = "${transform::etext_no}-pdf";
}

sub s2 {
    read_coverage_file ();
    print_font_coverage ();

    transform::debug ("start compiling stylesheet");
    my $xslt2  = $transform::parser->parse_file ("$transform::root_url/xsl/tei2tex.xsl");
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

    # newline or end-of-row in tables
    $output =~ s/^\\\\/ \\\\/g;

    # convert unicode chars to tex escapes
    $output =~ s/(\p{charmap::InTex})/charmap::convert_tex (ord ($1))/eg;

    unlink "$transform::outdir/$transform::basename*"; ## hkm was "rm -f"

    my $hd;
    open ($hd, ">:utf8", "$transform::outdir/$transform::basename.tex") or 
        die ("Cannot write to file $transform::outdir/$transform::basename.tex.\n");
    print $hd ($output);
    close ($hd);

    chdir ($transform::outdir);

    my $runs = 1;
    my $msg;
    ##hkm changed the following lines
    $ENV{ENCFONTS}= $gendir; ##HKM
    $ENV{TEXFONTS}= $gendir;
    $ENV{TEXFONTMAPS}= $gendir;
    $ENV{TFMFONTS}= $gendir;
    $ENV{TTFONTS}= $gendir;
    $ENV{TEXPSHEADERS}= $gendir;
    my $cmdline = "$transform::config->{'pdflatex'} $transform::latex_params $transform::basename.tex"; ##hkm
    transform::debug ($cmdline);
    
    while ($runs <= 4) {
    	print $cmdline.":cmdline\n";
        $msg = `$cmdline`;
        # at least 2 runs for toc
        last if ($runs >= 2 && !($msg =~ /Warning:.*?Rerun/s) && !($msg =~ /No file $transform::basename\.toc/s));
        $runs++;
    }

    transform::debug ($msg);
    transform::debug ("Needed $runs latex runs.");

    my @msg = split (/$/m, $msg);
    @msg = grep { /(?:^[!])|(?:Warning)|(?:Error)/ } @msg;
    transform::debug (join ("\n", @msg));

    chdir ($transform::curdir);

    my $member = $transform::zip->addFile ("$transform::outdir/$transform::basename.pdf", "$transform::basename.pdf");
    $member->desiredCompressionMethod (transform::COMPRESSION_DEFLATED);
}


### helper functions

sub declare_truetype_fonts {
    my $s;
    if (open (INC, "<$gendir/pgtei-fonts.inc")) {
        local $/;
        $s = <INC>;
        close (INC);
    }
    return $s;
}

sub texcolor {
    # input "0080ff" output "[rgb]{0.00, 0.50, 1.00}"
    my $color = transform::fixcolor (shift);
    $color =~ s/(..)/0x$1 /g;

    my @rgb = map { sprintf ("%.2f", (hex ($_) / 255.0)) } split (/ /, $color);
    return '[rgb]{' . join (",", @rgb) . '}'; # no spaces !
}

sub pdf_kern_word ($$) {
    my $word = shift;
    my $k = shift;
    return join ("\{\\kern$k\}", split (//, $word));
}

sub fix_outline ($) {
    my $s = shift;
    my $err = 0;
    Encode::_utf8_on ($s);
    $s =~ s/(.)/charmap::convert_pdfoutline($1, $err)/egs;
    if ($err) {
        die ("Unsupported characters in heading: '$s'");
    }
    return $s;
}

sub print_font_coverage {
    my @missing;
    my $msg = "Font Coverage of Used Characters:\n";
    foreach my $cp (sort { $a <=> $b } keys %$charmap::codepoints) {
        my $page = $cp >> 8;
        my $i    = $cp & 0xFF;
        $msg .= sprintf ("  U+%04x: ", $cp);
        if (exists $char2fonts->{$page}[$i]) {
            $msg .= join (', ', @{$char2fonts->{$page}[$i]});
        } else {
            push (@missing, $cp) unless chr ($cp) =~ m/\p{charmap::InNoWarn}/;
        }
        $msg .= "\n";
    }
    transform::debug2 (2, $msg);

    if (scalar @missing) {
        print ("Error: Missing Characters!\nNo installed font contains these characters. They will not display in the pdf.\n");
        foreach my $cp (@missing) {
            my $name = charnames::viacode ($cp);
            $name = 'n.n.' if (!defined $name);
            printf ("  U+%04x: (%dx) %s\n", $cp, $charmap::codepoints->{$cp}, $name);
        }
        print "\n";
    }
}

sub read_coverage_file {
    my $covfile = "$gendir/pgtei-fonts.coverage";

    # format of coverage file
    # U00/gentium/m/n: 0000000000000000000... 256 chars

    open (COVER, "<$covfile") or die ("Cannot read font coverage file: $covfile");
    while (<COVER>) {
        chomp;
        my ($f, $coverage) =  split (/:\s+/, $_);
        die ("Bogus font coverage file: $covfile") if length ($coverage) != 0x100;

        my ($encoding, $family, $series, $shape) = split (/\//, $f);

        $fonts->{$f} = $coverage;

        my $page = hex (substr ($encoding, 1));
        if (!exists $char2fonts->{$page}) {
            $char2fonts->{$page} = [];
            $#{$char2fonts->{$page}} = 0x100;
        }

        my $i = 0;
        my $pg = $page << 8;
        foreach my $bit (split (//, $coverage)) {
            if ((exists $charmap::codepoints->{$i + $pg}) && ($bit eq "1")) {
                if (!exists $char2fonts->{$page}[$i]) {
                    $char2fonts->{$page}[$i] = [];
                }
                push (@{$char2fonts->{$page}[$i]}, $f);
            }
            $i++;
        }            
    }
    close (COVER);
}

sub debug_viewer {
    system ("gpdf $transform::outdir/$transform::basename.pdf &");
}

sub register_xpath_functions () {
    my $u = "$transform::root_url/xslt";
    XML::LibXSLT->register_function ($u, "rend",            \&pg_rend);
    XML::LibXSLT->register_function ($u, "s2-textnode",     \&s2_textnode);

    XML::LibXSLT->register_function ($u, "pdf-header",      \&tex_header);
    XML::LibXSLT->register_function ($u, "pdf-fix-outline", \&fix_outline);
    XML::LibXSLT->register_function ($u, "fix-length",      \&pg_fix_length);
}

return 1;

