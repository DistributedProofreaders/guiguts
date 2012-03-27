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

# this file handles the HTML format

package format;
use strict;

use utf8;
use encoding 'utf8';

# -xml breaks whitespace
my $tidy_params = '-utf8 -indent -wrap 78';
my $csstemplate = 'html/persistent.css';

sub get_css_file {
    local $/;
    open (CSS, "<:utf8", "$transform::config->{'install_dir'}/$csstemplate") 
        or die ("CCS template $csstemplate file not found");
    my $s = <CSS>;
    close (CSS);
    return $s;
};

sub cp_style (\%\%$) {
    my ($h, $styles, $prop) = @_;
    if (my $p = transform::_getprop (%$h, $prop)) {
        $styles->{$prop} = $p;
    }
}

sub fix_length ($\%) {
    my $len = shift;
    my $h   = shift;

    my $f = qr/([-.\d]+)/; # match float

    # 12%
    if ($len =~ m/$f\s*%/) {
        return $len;
    }
    # 12px
    if ($len =~ m/$f\s*px/) {
        return $len;
    }
    # 12pt
    if ($len =~ m/$f\s*pt/) {
        return sprintf ("%.2fpx", $1);
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
        return sprintf ("%.2fem", $1 * $fs);
    }

    warn ("Unsupported length: $len");
    return 0;
}

sub pg_rend {
    my $nl = shift;
    die "Not a nodelist" unless $nl->isa ('XML::LibXML::NodeList');

    my $n = $nl->get_node (1);
    die "Not an Element" unless $n->isa ('XML::LibXML::Element');

    my $id = $n->getAttribute ('x-id');
    my $name = $n->nodeName ();
    my $h = $css::properties->{$id};
    my ($p, $c, @pre, @post, $classes, $styles);

    $classes->{'tei'} = 1;
    $classes->{"tei-$name"} = 1;
    if ($p = transform::_getprop (%$h, 'x-class')) {
        foreach (split /\s+/, $p) {
            $classes->{$_} = 1;
        }
    }
    if ($p = transform::_getprop (%$h, 'display')) {
        $classes->{$p} = 1 if ($p eq 'block' || $p eq 'inline');
    }

    if ($p = transform::_getprop (%$h, 'white-space')) {
        $classes->{'pre'} = 1 if $p eq 'pre';
    }

    cp_style (%$h, %$styles, 'text-align');
    cp_style (%$h, %$styles, 'text-indent');

    if ($p = transform::_getprop (%$h, 'margin-top')) {
        $styles->{'margin-top'} = fix_length ($p, %$h);
    }
    if ($p = transform::_getprop (%$h, 'margin-bottom')) {
        $styles->{'margin-bottom'} = fix_length ($p, %$h);
    }
    if ($p = transform::_getprop (%$h, 'block-align')) {
        if ($p eq 'center') {
            $styles->{'margin-left'}  = "auto";
            $styles->{'margin-right'} = "auto";
        }
    }
    if ($p = transform::_getprop (%$h, 'margin-left')) {
        $styles->{'margin-left'} = fix_length ($p, %$h);
    }
    if ($p = transform::_getprop (%$h, 'margin-right')) {
        $styles->{'margin-right'} = fix_length ($p, %$h);
    }

    if ($p = transform::_getprop (%$h, 'rules')) {
        if ($p eq 'all') {
            $classes->{'rules'} = 1;
        }
    }
    if ($p = transform::_getprop (%$h, 'float')) {
        if ($p eq 'left') {
            $classes->{'floatleft'}   = 1;
        }
        if ($p eq 'right') {
            $classes->{'floatright'}  = 1;
        }
    }
    if ($p = transform::_getprop (%$h, 'width')) {
        $styles->{'width'} = fix_length ($p, %$h);
    }
    if ($p = transform::_getprop (%$h, 'height')) {
        $styles->{'height'} = fix_length ($p, %$h);
    }

    # build result tree

    my $e = XML::LibXML::Element->new ('root');
    my $attr = XML::LibXML::Element->new ('attributes');
    $e->addChild ($attr);
    
    if ($p = transform::_getprop (%$h, 'x-colspan')) {
        $attr->setAttribute ('colspan', $p);
    }
    if ($p = transform::_getprop (%$h, 'x-rowspan')) {
        $attr->setAttribute ('rowspan', $p);
    }

    if (keys (%$classes)) {
        $attr->setAttribute ('class', join (' ', sort keys (%$classes)));
    }

    my @a;
    while (my ($key, $value) = each (%$styles)) {
        push (@a, "$key: $value");
    }
    if (@a) {
        $attr->setAttribute ('style', join ('; ', @a));
    }
    if (@pre) {
        $e->setAttribute ('pre',  join ('', @pre));
    }
    if (@post) {
        $e->setAttribute ('post', join ('', reverse @post));
    }
    return $e;
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

    if ($s =~ m/\S/) {
        $s = transform::pg_pop_stack ('pretext') . $s;
    }
    my $p;
    my $styles = {};
    if ($p = transform::_getprop (%$h, 'x-pre')) {
        $s = css::decode_value_strip_quotes ($p) . $s;
    }
    if ($p = transform::_getprop (%$h, 'x-post')) {
        $s = $s . css::decode_value_strip_quotes ($p);
    }

    if ($p = transform::_getprop (%$h, 'font-family')) {
        my $value = css::decode_value ($p);
        $styles->{'font-family'} = $value;
    }
    if ($p = transform::_getprop (%$h, 'font-size')) {
        $styles->{'font-size'} = (100 * $p) . '%';
    }
    if ($p = transform::_getprop (%$h, 'font-weight')) {
        $p = css::fix_font_weight ($p);
        $styles->{'font-weight'} = $p;
    }

    if ($p = transform::_getprop (%$h, 'letter-spacing')) {
        $styles->{'letter-spacing'} = fix_length ($p, %$h);
    }
    if ($p = transform::_getprop (%$h, 'line-height')) {
        $styles->{'line-height'} = fix_length ($p, %$h);
    }

    cp_style (%$h, %$styles, 'font-style');
    cp_style (%$h, %$styles, 'font-variant');
    cp_style (%$h, %$styles, 'text-decoration');
    cp_style (%$h, %$styles, 'text-transform');
    cp_style (%$h, %$styles, 'vertical-align');
    cp_style (%$h, %$styles, 'color');

    css::fix_default_italic (%$h);

    if ($p = transform::_getprop (%$h, 'x-default-italic')) {
        $styles->{'font-style'} = 'italic';
    }
    if (($s =~ m/\S/) && scalar (keys %$styles)) {
        my @span;
        foreach my $property (sort keys %$styles) {
            my $value = $styles->{$property};
            push (@span, "$property: $value");
        }
        return "\x{f8f1}span style=\"" . join ("; ", @span) . 
            "\"\x{f8f3}$s\x{f8f1}/span\x{f8f3}";
    }
    return $s;
}

# fix html
# TEI and HTML don't necessarily agree on what is 
# an inlined and what is a block element.
# eg. a <tei:table> must occur within a <tei:p>
# a <html:table> may not occur inside a <html:p>
# here we try to fix all those inconsistencies

my $html_block_elements = {};
my $html_inline_elements = {};

sub parse_dtd_entity_node {
    my $dtd = shift;
    my $nodeName = shift;
    my $h = shift;

    my $node = $dtd->firstChild ();
    # nodeType: elem = 15, attr = 16, ent = 17
    while ($node) {
        last if ($node->nodeType () == 17 && $node->nodeName () eq $nodeName);
        $node = $node->nextSibling ();
    }

    return if (!$node);

    my $s = $node->toString;
    $s =~ s/\s+/ /g;
    $s =~ m/\"(.*)\"/;
    foreach my $name (split (/[\s|,;]+/, $1)) {
        if (substr ($name, 0, 1) eq '%') {
            parse_dtd_entity_node ($dtd, substr ($name, 1), $h);
        } else {
            $h->{$name} = 1;
        }
    }
}

sub recurse_nodes_a1 {
    my $me   = shift;
    my $in_p = shift || $me->nodeName () eq 'p';

    my $child = $me->firstChild ();
    while ($child) {
        if ($in_p && exists ($html_block_elements->{$child->nodeName})) {
            my $parent = $me->parentNode ();

            # This child of mine is a block type node 
            # but I am a <p> or I am a child of a <p> 
            # and thus this child of mine needs fixing.
            # We bubble it upwards so it becomes my sibling.

            # first get rid of empty text nodes
            # around the offending child

            my $nc = $child->nextSibling ();
            while ($nc) {
                my $ncsave = $nc;
                $nc = $nc->nextSibling ();
                my $text = $ncsave->textContent ();
                if ($text =~ m/\S/) {
                    last;
                } else {
                    $me->removeChild ($ncsave);
                }
            }
            my $pc = $child->nextSibling ();
            while ($pc) {
                my $pcsave = $pc;
                $pc = $pc->previousSibling ();
                my $text = $pcsave->textContent ();
                if ($text =~ m/\S/) {
                    last;
                } else {
                    $me->removeChild ($pcsave);
                }
            }

            # now check if the offending child is my
            # first or my last child

            $nc = $child->nextSibling ();
            if (!$nc) {
                # The offending child is my last child
                # Turn the bad child into my next sibling
                $parent->insertAfter ($child, $me);
                return;
            }

            $pc = $child->previousSibling ();
            if (!$pc) {
                # The offending child is my first child
                # Turn the bad child into my prevoius sibling
                $parent->insertBefore ($child, $me);
                return;
            }

            # The offending child is not my first nor my last one.
            # I'll have to be split.
            # The nodes after the offending child will 
            # be given to my second self.
            
            # clone me
            my $mytwin = $me->cloneNode (0);
            my @attributes = $me->attributes ();
            foreach (@attributes) {
                $mytwin->addChild ($_->cloneNode (1));
            }
            
            # give all my children after the bad one to mytwin
            while ($nc) {
                my $nextSibling = $nc->nextSibling ();
                $mytwin->addChild ($nc);
                $nc = $nextSibling;
            }
            
            # turn mytwin into my next sibling
            $parent->insertAfter ($mytwin, $me);
            
            # insert the bad child between me and my second self
            $parent->insertAfter ($child, $me);

            return;
        }
        recurse_nodes_a1 ($child, $in_p);

        $child = $child->nextSibling ();
    }
}
 
sub report_encoding {
    return undef;
}

sub s1_post {
    $transform::basename = "${transform::etext_no}-h";
}

sub s2 {
    charmap::WarnWGL4 ();

    transform::debug ("start compiling stylesheet");
    my $xslt2  = $transform::parser->parse_file ("$transform::root_url/xsl/tei2html.xsl");
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

    transform::debug ("fix html oddities");
    eval {
        $transform::doc->validate ();
    };
    # warn $@ if $@;
    if ($@) {
        # not valid !!! try some ad-hoc fixes ...

        # get correct html dtd
        my $dtd;
        my $intsub = $transform::doc->internalSubset ();
        $intsub = $intsub->toString ();
        #print STDERR $intsub;
        if ($intsub =~ m/PUBLIC\s+"(.*?)"\s+"(.*?)"/) {
            $dtd = XML::LibXML::Dtd->new ($1, $2);
        } elsif ($intsub =~ m/SYSTEM\s+"(.*?)"/) {
            $dtd = XML::LibXML::Dtd->new (undef, $1);
        }

        # this is a simpler way than above, 
        # but it always segfaults on exit
        # this is what the docs says:
        # NOTE Dtd nodes are no ordinary nodes in libxml2. The support for
        # these nodes in XML::LibXML is still limited. In particular one may
        # not want use common node function on doctype declaration nodes!
        #
        # $dtd = $transform::doc->externalSubset;

        if ($dtd) {
            # print STDERR $dtd->serialize ();

            # this will get a list of all elements which 
            # the used html dtd considers a `block'
            parse_dtd_entity_node ($dtd, 'block', $html_block_elements);

            # and also a list of `inline' elements
            parse_dtd_entity_node ($dtd, 'inline', $html_inline_elements);

            # split a <p> whenever a block level element occurs within
            # print STDERR $transform::doc->serialize ();
            recurse_nodes_a1 ($transform::doc->documentElement, 0);

        }

        # try again if valid
        eval {
            $transform::doc->validate ();
        };
        #print STDERR $transform::doc->serialize () if ($@);
        warn $@ if $@; # still not valid
        undef $dtd;
    }

    my $output = $trans2->output_string ($transform::doc);
    undef $trans2;

    Encode::_utf8_on ($output);

    # whitespace eater
    # this helpful character eats all whitespace following it
    # use it where XSL inserts unwanted whitespace
    $output =~ s/\x{f8e3}\s*//gm;

    # convert some unicode chars to entities or strings
    $output =~ s/(\p{charmap::InHtml})/charmap::convert_html (ord ($1))/eg;
    
    if (-x $transform::config->{'tidy'}) {
        transform::debug ("start running tidy");
        my $command = $transform::config->{'tidy'}. " ". 
               $tidy_params. " -output ". 
              "$transform::outdir/$transform::basename.html";
        open (HTML, "|-:utf8", $command); ## hkm
        print HTML $output;
        close (HTML);
        transform::debug ("done running tidy");
    } else {
        open (HTML, ">:utf8", "$transform::outdir/$transform::basename.html");
        print HTML $output;
        close (HTML);
    }

    my $member = $transform::zip->addFile ("$transform::outdir/$transform::basename.html", 
                                           "$transform::basename/$transform::basename.html");
    $member->desiredCompressionMethod (transform::COMPRESSION_DEFLATED);
}

sub debug_viewer {
    `mozilla-firefox $transform::outdir/$transform::basename.html &`;
}

sub register_xpath_functions () {
    my $url = "$transform::root_url/xslt";
    XML::LibXSLT->register_function ($url, "rend",        \&pg_rend);
    XML::LibXSLT->register_function ($url, "s2-textnode", \&s2_textnode);

    XML::LibXSLT->register_function ($url, "get-css",     \&get_css_file);
}

return 1;
