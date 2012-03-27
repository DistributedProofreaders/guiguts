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

# this file handles the embedded CSS stylesheet and rend attribute syntax

package css;

use strict;
use utf8;
use encoding 'utf8';

our $properties = {};

our $ss_builtin = <<EOF;
/* this is the default PGTEI 0.4 stylesheet
   it may be overridden by embedded stylesheets and in rend attributes */

/* properties starting with x- are private. 
   do not touch! you have beeen warned! */

*                { x-display: inline; x-element: span; text-indent: 0 } 

address          { x-element: address }
argument         { x-display: block; x-element: div; 
                   margin-left: 4; margin-right: 4; margin-top: 2; margin-bottom: 2; 
                   text-align: center; font-size: small }
attName          { font-weight: bold; font-family: monospace }
back             { x-display: block; x-element: div }
body             { x-display: block; x-element: div }
byline           { x-display: block; x-element: div }
castGroup        { x-display: block; x-element: li }
castItem         { x-display: block; x-element: li }
castList         { x-display: block; x-element: ul; margin-top: 2; margin-bottom: 2 }
cell             { x-element: td }
cit              { x-display: block; x-element: div }
closer           { x-display: block; x-element: div }
code             { font-family: monospace }
dateline         { x-display: block; x-element: div }
div              { x-display: block; x-element: div; margin-top: 2; margin-bottom: 2 } 
divGen           { x-display: block; x-element: div }
eg               { x-display: block; x-element: pre; white-space: pre; x-class: shaded;
                   text-align: left; margin-top: 2; margin-bottom: 2; 
                   font-family: monospace; text-indent: 0 }
emph             { x-element: em; x-default-italic: 1 }
entName          { font-weight: bold; font-family: monospace }
epigraph         { x-display: block; x-element: div; 
                   margin-left: 10; margin-bottom: 2; text-align: right; font-size: small }
figure           { x-display: block; x-element: img }
front            { x-display: block; x-element: div }
gap              { font-family: monospace }
gi               { font-weight: bold; font-family: monospace }
group            { x-display: block; x-element: div }
hi               { x-default-italic: 1 }
ident            { font-weight: bold; font-family: monospace }
item             { x-display: block; x-element: td }
headItem         { x-display: block; x-element: th; font-weight: bold }
kw               { font-weight: bold; font-family: monospace }
l                { x-display: block; x-element: div; text-align: left }
label            { x-display: block; x-element: th; counter-increment: x-list; }
labelitem        { x-display: block; x-element: tr }
headLabel        { x-display: block; x-element: th }
lb               { x-display: block; x-element: div }
lg               { x-display: block; x-element: div; 
                   margin-top: 1; margin-bottom: 1;
                   page-break-inside: avoid } 
list             { x-display: block; x-element: ul; 
                   margin-top: 1; margin-bottom: 1; counter-reset: x-list }
mentioned        { x-default-italic: 1 }
milestone        { x-display: block; x-element: div; margin-top: 1; margin-bottom: 1 }
opener           { x-display: block; x-element: div }
note             { x-element: div }
notelabel        { x-element: dt }
notetext         { x-display: block; x-element: dd }
noteref          { vertical-align: super; font-size: 60%; }
marginnote       { x-display: block; x-element: div; font-size: 80% }
marginnotetext   { x-display: block; x-element: div; }
p                { x-display: block; x-element: p }
pb               { x-display: block; x-element: div }
ptr              { x-element: a }
q                { pre: default; post: default }
quote            { pre: default; post: default }
ref              { x-element: a }
row              { x-element: tr }
salute           { x-display: block; x-element: div }
set              { x-display: block; x-element: div }
signed           { x-display: block; x-element: div; text-align: right }
sp               { x-display: block; x-element: div; margin-left: 2 }
speaker          { x-display: block; x-element: div; indent: -2; font-weight: bold }
table            { x-display: block; x-element: div; margin-bottom: 1 }
tag              { font-weight: bold; font-family: monospace }
term             { x-default-italic: 1 }
text             { x-display: block; x-element: div }
title            { x-default-italic: 1 }
titlePage        { x-display: block; x-element: div }
trailer          { x-display: block; x-element: p }
val              { font-weight: bold; font-family: monospace }
xptr             { x-element: a }
xref             { x-element: a }

\@media pdf {
    eg           { font-size: x-small }
    head.x-head1 { x-pre: '\\noindent{\\vrule width 0pt height 50pt depth 0pt}' }
}

/* shortcuts and backward compatibility */

.display         { display: block; x-element: div;
                  margin-left: 4; margin-right: 4; margin-top: 2; margin-bottom: 2;
                  font-size: small; }

q.pre            { post: none }
q.post           { pre: none }
q.none           { pre: none; post: none }
q.display        { pre: none; post: none }

quote.pre        { post: none }
quote.post       { pre: none }
quote.none       { pre: none; post: none }
quote.display    { pre: none; post: none }

titlePart.block  { x-element: h1 }

/* table/head list/head figure/head */

head             { x-display: block; x-element: div; 
                   margin-top: 1; margin-bottom: 1; 
                   text-align: left; text-indent: 0; 
                   hyphenate: none;
                   page-break-inside: avoid; 
                   page-break-after:  avoid }

head.x-figure-head { text-align: center }
head.x-list-head   { x-element: th; x-class: tei-list-head;
                     margin-bottom: 1; font-weight: bold }

text             { margin-top: 2; margin-bottom: 2 }
front            { margin-top: 2; margin-bottom: 6 }
body             { margin-top: 6; margin-bottom: 6 }
back             { margin-top: 6; margin-bottom: 2 }

div.x-div1       { margin-top: 5; margin-bottom: 5 }
div.x-div2       { margin-top: 4; margin-bottom: 4 }
div.x-div3       { margin-top: 3; margin-bottom: 3 }
div              { margin-top: 2; margin-bottom: 2 }

p                { margin-top: 1; margin-bottom: 1 }

/* div/head */

head.x-head      { margin-top: 2; margin-bottom: 2 }

head.x-head1     { x-element: h1; font-size: 173% }
head.x-head2     { x-element: h2; font-size: 144% }
head.x-head3     { x-element: h3; font-size: 120% }
head.x-head4     { x-element: h4 }
head.x-head5     { x-element: h5 }
head.x-head6     { x-element: h6 }

head.x-subhead   { margin-top: 2; margin-bottom: 2; 
                   text-align: center;
                   page-break-before: avoid }

head.x-subhead1  { x-element: h1; font-size: 144%; }
head.x-subhead2  { x-element: h2; font-size: 120%; }
head.x-subhead3  { x-element: h3 }
head.x-subhead4  { x-element: h4 }
head.x-subhead5  { x-element: h5 }
head.x-subhead6  { x-element: h6 }

/* lists */

label.x-list-ordered         { content: counter(x-list, decimal) }
label.x-list-bulleted        { content: counter(x-list, disc) }

list.x-list-gloss            { x-class: tei-list-gloss }
label.x-list-gloss           { x-class: tei-label-gloss }
headLabel.x-list-gloss       { x-class: tei-headLabel-gloss; font-weight: bold; }
item.x-list-gloss            { x-class: tei-item-gloss; }
headItem.x-list-gloss        { x-class: tei-headItem-gloss; font-weight: bold; }

/* tables */

head.x-table-head            { x-element: th; x-class: tei-head-table;
                               text-align: center; font-weight: bold }
cell.x-cell-label            { x-element: th; x-class: tei-cell-label; 
                               font-weight: bold; }

\@media html {
    p                        { margin-top: 0 }
    label                    { x-post: "\xc2\xa0\xc2\xa0" }
    label.x-list-simple      { x-post: "" }
}

\@media pdf {
    p                        { hyphenate: auto; 
                               text-indent: 12pt; 
                               margin-top: 0; margin-bottom: 0; }
    l                        { hyphenate: auto; 
                               text-indent: 12en hanging;
                               x-pdf-penalty-after:  500; }
    lg                       { text-indent: 0;
                               x-pdf-parskip: 0pt; 
                               x-pdf-penalty-after: -700 }
    labelitem                { margin-left: 4 }
    labelitem.x-list-gloss   { margin-left: 0 }
    item.x-list-gloss        { margin-left: 4 }
    headItem.x-list-gloss    { margin-left: 4 }
}

\@media txt {
    text                     { text-align: left }

    head.x-head1             { text-transform: uppercase }

    note                     { x-display: block; text-indent: 6 hanging; 
                               margin-top: 1; margin-bottom: 1 }
    marginnote               { x-display: block; text-indent: 6 hanging; }

    l                        { text-indent: 12 hanging; } 
    item                     { text-indent:  6 hanging; }
    headItem                 { text-indent:  6 hanging; }

    item.x-list-gloss        { margin-left: 6; text-indent: 0 }
    headItem.x-list-gloss    { margin-left: 6; text-indent: 0 }

    label.x-list-bulleted    { content: "-" }
}

EOF

my $media = 1;
my $styles = {};

sub _check_token (\$$) {
    # dont eat the token, just check if it is there
    my ($ss, $check) = @_;
    return $$ss =~ m/^\s*$check/s ;
}

sub _get_token (\$$) {
    # eat and return the token
    my ($ss, $check) = @_;
    $$ss =~ s/^\s*//s;

    if ($$ss =~ s/^$check//s) {
        return $1;
    }
    return undef;
}

sub _get_token_or_die (\$$) {
    # die if the requested token is not there
    my ($ss, $check) = @_;
    my $token = _get_token ($$ss, $check);
    if (!defined ($token)) {
        my $found = substr ($$ss, 0, 100);
        die ("CSS parser error: Expected: '$check' found: '$found'");
    }
    return $token;
}

sub _get_identifier (\$) {
    my $ss = shift;
    return _get_token ($$ss, qr/(\w[-\*\w\d]*)/ );
}

sub _get_selector (\$) {
    my $ss = shift;
    my $selector = _get_token ($$ss, qr/(.*?)(?=\s*\{)/ );
    $selector =~ s/\s+/ /g if ($selector);
    return $selector;
}

sub parse_declaration (\$\%) {
    # A declaration is either empty or consists of a property, 
    # followed by a colon (:), followed by a value.

    my ($ss, $sel) = @_;

    # transform::debug ("declaration: >$$ss<");

    my ($property, $value) = split (/:\s*/, $$ss);
    $sel->{$property} = $value;
    # transform::debug ("Declaration >$property:< >$value<");
}

sub parse_declaration_list (\$\%) {
    # A declaration-block starts with a left curly brace ({) and 
    # ends with the matching right curly brace (}).
    # In between there must be a list of zero or more 
    # semicolon-separated (;) declarations.

    my ($ss, $h) = @_;

    my $declaration_list = _get_token ($$ss, qr"(.*?)(?=})");
    # transform::debug ("declaration list: >$declaration_list<");

    if ($media) {
        foreach my $declaration (split (/\s*;\s*/, $declaration_list)) {
            $declaration =~ s/\s+$//;
            parse_declaration ($declaration, %$h);
        }
    }
}

sub parse_declaration_block (\$\%) {
    # A declaration-block starts with a left curly brace ({) and 
    # ends with the matching right curly brace (}).
    # In between there must be a list of zero or more 
    # semicolon-separated (;) declarations.

    my ($ss, $h) = @_;

    _get_token_or_die ($$ss, '({)');
    parse_declaration_list ($$ss, %$h);
    _get_token_or_die ($$ss, '(})');
}

sub parse_rule_set (\$\%) {
    # A rule set (also called "rule") consists of a selector 
    # followed by a declaration block.
    my ($ss, $h) = @_;

    my $selector;
    if ($selector = _get_selector ($$ss)) {
        # transform::debug ("Selector: '$selector'");
        # FIXME: $h->{$selector} = {}; # needed for classes with empty rulesets
        parse_declaration_block ($$ss, %{$h->{$selector}});
    }
}

sub parse_block (\$\%) {
    my ($ss, $h) = @_;
    _get_token_or_die ($$ss, '({)');
    while ($$ss) {
        last if (_check_token ($$ss, '}'));
        parse_rule_set ($$ss, %$h);
    }
    _get_token_or_die ($$ss, '(})');
}

sub parse_at_rule (\$\%) {
    my ($ss, $h) = @_;
    
    my $at_keyword = _get_identifier ($$ss);

    if ($at_keyword eq 'media') {
        my $medias = _get_token ($$ss, qr/([^\{]+)/ );
        $media = ($medias =~ m/\b$transform::format\b/ || $medias =~ m/\ball\b/);
        parse_block ($$ss, %$h);
    } else {
        die ("Unsupported at-rule: $$ss");
    }
}

sub parse_stylesheet ($\%) {
    # A CSS style sheet, for any version of CSS, consists of a 
    # list of statements. 
    # There are two kinds of statements: at-rules and rule sets.

    my $ss = shift;
    my $h = shift;

    # strip comments, css comments are whitespace
    $ss =~ s!/\*.*?\*/! !gs;

    $ss =~ s/"(.*?)"/'"'.encode($1).'"'/egs;
    $ss =~ s/'(.*?)'/"'".encode($1)."'"/egs;

    $ss =~ s/\s+/ /g;

    while ($ss) {
        if (_get_token ($ss, '(@)')) {
            # at-rule
            parse_at_rule ($ss, %$h);
        } else {
            # rule set
            $media = 1;
            parse_rule_set ($ss, %$h);
        }
    }
}

sub parse_builtin_stylesheet () {
    parse_stylesheet ($ss_builtin, %$styles);
}

sub print_stylesheet {
    foreach my $k (sort keys (%$styles)) {
        print ("$k\n");
        my $v = $styles->{$k};
        foreach my $kk (sort keys (%$v)) {
            my $vv = $v->{$kk};
            print ("  $kk: $vv\n");
        }
    }
}

sub merge (\%\%) {
    # merge 2 style hashes
    # the second one overrides the first one
    my $h1 = shift;
    my $h2 = shift;

    foreach (keys %$h2) {
        $h1->{$_} = $h2->{$_};
    }
}

# to be completed 
our $inherited = { 
    'background'            => 0,
    'background-attachment' => 0, 
    'background-color'      => 0,
    'background-image'      => 0,
    'background-position'   => 0,
    'background-repeat'     => 0,
    'color'                 => 1,
    'content'               => 0,
    'counter-increment'     => 0,
    'counter-reset'         => 0,
    'font'                  => 1,
    'font-family'           => 1,
    'font-size'             => 1,
    'font-style'            => 1,
    'font-variant'          => 1,
    'font-weight'           => 1,
    'hyphenate'             => 1,
    'letter-spacing'        => 1,
    'line-height'           => 1,
    'list-style'            => 1,
    'list-style-image'      => 1,
    'list-style-position'   => 1,
    'list-style-type'       => 1,
    'quotes'                => 1,
    'text-align'            => 1, 
    'text-decoration'       => 1,  # only to inline
    'text-indent'           => 1, 
    'text-transform'        => 1,
    'white-space'           => 1,
    'word-spacing'          => 1,

    'x-lang'                => 1,  # not a CCS prop but a practical one to have around
    'x-pdf-footnote'        => 1,  # tex sets this if inside footnote

};

sub fix_properties (\%) {
    # param: hash of property => value
    # return hash ref
    my $h = shift;
    my $p;

    # fix compatibilty and other issues
    if ($p = transform::_getprop (%$h, 'white-space')) {
        if ($p eq 'pre') {
            $h->{'x-element'} = 'pre';
        }
    }
    if ($p = transform::_getprop (%$h, 'indent')) {
        $h->{'margin-left'} = $p;
    }
    if ($p = transform::_getprop (%$h, 'font-size')) {
        $h->{'font-size'} = fix_font_size ($p);
    }
}

sub prop_from_hash (\%$) {
    my $h        = shift;
    my $propname = shift;

    my $inherit  = 0;

    # transform::debug ("Query prop: $propname");

    if (exists ($h->{$propname})) {
        my $p = $h->{$propname};
        $inherit = "$p" eq 'inherit';
        return $p if !$inherit;
    }
    $inherit |= ((exists $inherited->{$propname}) && ($inherited->{$propname} == 1));

    if ($inherit) {
        while ($h = $h->{'x-parent'}) {
            return $h->{$propname} if (exists ($h->{$propname}));
        }
    }
    return undef;
}

sub hash_from_node ($) {
    my $n = shift;

    die ("internal error: no x-id on node") unless $n->hasAttribute ('x-id');

    my $id = $n->getAttribute ('x-id');
    die ("internal error: bogus x-id $id on node") unless exists $properties->{$id};

    return $properties->{$id}; # hash ref
}

sub get_prop ($$) {
    my $n = shift;
    my $propname = shift;

    my $h = hash_from_node ($n);
    return prop_from_hash (%$h, $propname);
}

sub set_prop ($$$) {
    my $n = shift;
    my $propname = shift;
    my $value = shift;

    my $h = hash_from_node ($n);
    # debug ("set rend: $propname to $value");
    $h->{$propname} = $value;

    fix_properties (%$h);
}

sub set_class ($$) {
    my $n = shift;
    my $class = shift;

    my $element = $n->nodeName ();
    my $h = hash_from_node ($n);

    # dont check private "x-" classes 
    my $done = $class =~ m/^x-/; 

    $class = ".$class";

    if (exists $styles->{$class}) {
        merge (%$h, %{$styles->{$class}});
        $done = 1;
    }
    if (exists $styles->{"$element$class"}) {
        merge (%$h, %{$styles->{"$element$class"}});
        $done = 1;
    }
    if (exists $styles->{"$element$class:before"}) {
        merge (%$h, %{$styles->{"$element$class:before"}});
        $done = 1;
    }
    if (!$done) {
        die ("Undefined class '$class' on element <$element>");
    }
    fix_properties (%$h);
}

sub disinherit ($) {
    my $n = shift;
    # we need this for elements that flow out of the parent context 
    # like <note>. otherwise note would inherit the formatting
    # of the parent node.

    my $h = hash_from_node ($n);

    # save this one
    $h->{'x-lang'} = prop_from_hash (%$h, 'x-lang');

    $h->{'x-parent'} = undef;
}

sub parse_rend ($$) {
    # input a rend string like "display; font-style: italic"
    # a rend string may contain css rules and classes separated by ";"
    # a css rule has the form "property: value"
    # a class has the form: "class"
    my $element = shift;
    my $rend = shift;

    # transform::debug ("got rend: $rend");

    $rend =~ s/"(.*?)"/'"'.encode($1).'"'/egs;
    $rend =~ s/'(.*?)'/"'".encode($1)."'"/egs;

    my $h = {};
    merge (%$h, %{$styles->{'*'}});
    merge (%$h, %{$styles->{$element}});
    if (exists $styles->{"$element:before"}) {
        merge (%$h, %{$styles->{"$element:before"}});
    }

    if (length ($rend)) {
        my $rule;
        while ($rule = _get_token ($rend, qr/(.*?)\s*(?:;|$)/ )) {
            $rule =~ s/\s+$//;
            # transform::debug ("got rule: $rule");
            if (index ($rule, ':') == -1) {
                # got a class
                my $class = ".$rule";
                # dont check private "x-" classes 
                my $done = $rule =~ m/^x-/; 
                if (exists $styles->{$class}) {
                    merge (%$h, %{$styles->{$class}});
                    $done = 1;
                }
                if (exists $styles->{"$element$class"}) {
                    merge (%$h, %{$styles->{"$element$class"}});
                    $done = 1;
                }
                if (exists $styles->{"$element$class:before"}) {
                    merge (%$h, %{$styles->{"$element$class:before"}});
                    $done = 1;
                }
                if (!$done) {
                    die ("Undefined class '$class' on element <$element>");
                }
            } else {
                # got a rule
                parse_declaration ($rule, %$h);
            }
        }
    }
    fix_properties (%$h);
    return $h;
}

sub decode_value ($) {
    my $rend = shift;
    $rend =~ s/"(.*?)"/'"'.decode($1).'"'/egs;
    $rend =~ s/'(.*?)'/"'".decode($1)."'"/egs;
    return $rend;
}

sub decode_value_strip_quotes ($) {
    my $rend = shift;
    $rend =~ s/"(.*?)"/decode($1)/egs;
    $rend =~ s/'(.*?)'/decode($1)/egs;
    return $rend;
}

sub parse_embedded_stylesheets ($) {
    my $doc = shift;
    
    my @stylesheets = $doc->findnodes ("/TEI.2/pgExtensions/pgStyleSheet");

    foreach my $ssnode (@stylesheets) {
        transform::debug ("Reading embedded stylesheet");
        my $stylesheet = $ssnode->textContent;
        parse_stylesheet ($stylesheet, %$styles);
    }
}

sub fix_font_weight ($) {
    my $v = shift;
    if ($v eq 'bold')   { $v = '700'; }
    if ($v eq 'normal') { $v = '400'; }
    return $v;
}

sub fix_font_size ($) {
    my $v = shift;

    if ($v =~ m/^\d/) {
        if ($v =~ m/^[.\d]+\s*%$/) {
            return POSIX::strtod ($v) * 0.01;
        }
        if ($v =~ m/^[.\d]+$/) {
            return POSIX::strtod ($v);
        }
    }

    if ($v eq 'xx-small') { return 0.73; }
    if ($v eq 'x-small')  { return 0.81; }
    if ($v eq 'small')    { return 0.90; }
    if ($v eq 'medium')   { return 1.00; }
    if ($v eq 'large')    { return 1.20; }
    if ($v eq 'x-large')  { return 1.44; }
    if ($v eq 'xx-large') { return 1.73; }

    die ("unknown font size $v");
}

sub fix_default_italic (\%) {
    my $h = shift;
    if (defined $h->{'font-weight'} ||
        defined $h->{'font-style'} ||
        defined $h->{'font-size'} ||
        defined $h->{'font-family'} ||
        defined $h->{'font-variant'} ||
        defined $h->{'text-decoration'} ||
        defined $h->{'text-transform'} ||
        defined $h->{'vertical-align'} ||
        defined $h->{'color'} ||
        defined $h->{'letter-spacing'}) {

        delete ($h->{'x-default-italic'});
    }
}

sub encode {
    my $s = shift;
    Encode::_utf8_off ($s);
    $s =~ s/(.)/sprintf ("%02X", unpack ('C', ($1)))/egs;
    Encode::_utf8_on ($s);
    return $s;
}

sub decode {
    my $s = shift;
    Encode::_utf8_off ($s);
    $s =~ s/([A-F0-9]{2})/pack ('C', hex($1))/eg;
    Encode::_utf8_on ($s);
    return $s;
}

