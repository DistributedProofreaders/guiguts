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

# TODO: 
#
# solve units question
# move css @media into formats 
# fix footnotes section in pdf bug
# fix example files 
#
# ? move milestone to preprocessor ? 
# ??? fix lists in html using style="content: " ???

########################################################################
# This script drives the whole conversion process.
# It calls libxslt at the appropriate stages and does a lot of 
# dirty perling in between.
# It also contains XPath extension functions called by the stylesheets.
########################################################################

package transform;

require 5.008;   # needs unicode support
use strict;

no warnings qw(once);

#########################################################################################
# per-installation config

# find libraries in the program directory
my $progdir = $0;
$progdir =~ s!/[^/]*$!!;
push @INC, $progdir;

our $config = {};
require 'config.pl';

use utf8;
use encoding 'utf8';

use Getopt::Long;
use IO::File;
use XML::LibXML;
use XML::LibXSLT;
use Archive::Zip qw (:ERROR_CODES :CONSTANTS);
use Text::Wrap;
use POSIX;
use File::Copy;

#########################################################################################
# don't change these

my $version      = '0.4';
our $root_url    = "http://www.gutenberg.org/tei/marcello/$version";

#########################################################################################
# default options

our $outdir      = '';
our $infile      = '';
our $format      = 'html';
our $subformat   = 'html';
our $pdffontsize = 11.0;

my @mapfiles;
our $verbose     = 0;
our $debug       = 0;

my $copyrighted  = 0;
my $do_usage     = 0;

require 'charmap.pl';
require 'css.pl';
require 'Hyphen.pm';

#########################################################################################
# parameters for external programs

# tei2pdf
our $latex_params          = '--interaction=nonstopmode';

# convert <formula notation="tex"> to image
my $dvips_params           = '';
my $convert_params         = '-units PixelsPerInch -density 96x96 -type TrueColor ' . 
                             '+matte -depth 8 -trim';

#########################################################################################
# global vars

our $doc;         # the XML document at its current transformation stage

our $srcdir                 = '';
our $curdir;
our $basename;    # 12345-pdf

our $zip;
my $cnt_formulas = 0;
my $cnt_svgs = 0;

our $etext_no;
my $pubdate;
my $langid;
my $nroffdev;

my $vars   = {};
my $stacks = {};
my @nodes;

#########################################################################################

sub usage ($) {
    my $errmsg = shift;
    print "error: $errmsg\n\n" if $errmsg;

print <<EOF;
usage: transform.pl [-f html|txt|pdf] [-c] [-d] [-m <charmapfile>] 
       <inputfile> <outputdir>

  inputfile        tei input file
  outputdir        existing directory where to store output files
                   NOTE: existing files will be overwritten!
  -f|--format      specify one output format out of: html txt pdf. default: html
  -m|--map         specify one or more external character maps
  -c|--copyrighted specify that the ebook is copyrighted
  -d|--debug       print debug information while converting
  -h|--help        print this info

EOF
exit ();
}

GetOptions (  "format|f=s"     => \$format,
	      "map|m=s"        => \@mapfiles,
	      "verbose|v+"     => \$verbose,
	      "debug|d!"       => \$debug,
	      "copyrighted|c!" => \$copyrighted,
	      "help|h|?!"      => \$do_usage,
	   );

usage ("") if $do_usage;

# sanity checks

usage ("No input file specified!")       if (@ARGV < 1);
usage ("No output directory specified!") if (@ARGV < 2);

$infile = $ARGV[0];
$outdir = $ARGV[1];
$outdir =~ s!/$!!;
$infile =~ m!^(.*)[\\/]!;
$srcdir = $1;
if (not defined $srcdir) {$srcdir='';}

usage ("Cannot read input file $infile!")      if (!-r $infile);
usage ("Output directory $outdir must exist!") if (!-d $outdir);

$subformat = $format;
if ($format =~ m/(\w+)\.(\w+)/) {
    $format    = $1;
    $subformat = "$1.$2";
}

my $formatfile = "$config->{'install_dir'}/$format/mod-$format.pl";
usage ("Unknown format $format!") unless -r $formatfile;

require $formatfile;

my $do_svg2image = (-x $config->{'convert'});
my $do_tex2image = (-x $config->{'latex'} && -x $config->{'dvips'} && -x $config->{'convert'});
my $zip_images   = ($format eq 'html');

binmode (STDERR, ':utf8');

sub debug {
    my $msg = shift;
    print STDERR "*** $msg\n" if $debug;
}

sub debug2 {
    my $level = shift;
    my $msg   = shift;
    print STDERR "*** $msg\n" if $debug >= $level;
}

########################################################################
# XPath extension functions
########################################################################

sub wrap_tex_formula {
    my $tex_formula = shift;
    return <<EOF;
\\documentclass[$pdffontsize pt]{article}
\\usepackage\{ucs}
\\usepackage[utf8]\{inputenc} \% needs debian latex-ucs package

\\usepackage[T1]\{fontenc}

\\usepackage{amsmath}
\\usepackage{amsfonts}
\\usepackage{amssymb}
%\\usepackage[pdftex]{graphicx,color}
\\pagestyle{empty}
\\begin{document}
$tex_formula
\\end{document}
EOF
}

sub pg_render_tex_formula {
    my $formula = shift;
    Encode::_utf8_on ($formula);
    $formula =~ s/(.)/charmap::inband ($1)/eg;

    my $e = XML::LibXML::Element->new ('root');

    if ($do_tex2image) {
        my $doc = wrap_tex_formula ($formula);

        ++$cnt_formulas;
        my $fname = "$cnt_formulas";
        my $filename = "formulas/$cnt_formulas.png";

        chdir ($outdir);
        mkdir ("formulas");
        chdir ("formulas");

        # create temporary latex file
        my $hd;
        open ($hd, ">:utf8", "$fname.tex") 
            || die ("Cannot write to file $outdir/formulas/$fname.tex.\n");
        print $hd ($doc);
        close ($hd);

        debug ("latex: " . `$config->{'latex'} $latex_params "$fname.tex"`);
        die if $?;

        debug ("dvips: " . `$config->{'dvips'} $dvips_params -o "$fname.ps" "$fname.dvi"`); # > /dev/null 2>&1
        die if $?;

        debug ("convert: " . `$config->{'convert'} $convert_params "$fname.ps" "$fname.png"`);
        die if $?;

        chdir ($curdir);

        if ($zip_images) {
            # this just records the file name, does not read the file in yet
            my $member = $zip->addFile ("$outdir/$filename", "$basename/$filename");
            $member->desiredCompressionMethod (COMPRESSION_STORED);
        }

        $e->setAttribute ("url", $filename);

        _get_image_size ($e, "$outdir/$filename");
    } else {
        print STDERR ("Could not make image out of formula.\n");
    }
    return $e;
}

sub pg_render_svg {
    my $svg = shift;
    Encode::_utf8_on ($svg);
    $svg =~ s/(.)/charmap::inband ($1)/eg;

    my $e = XML::LibXML::Element->new ('root');

    if ($do_svg2image) {
        chomp ($svg);
        $svg =~ s/^\s+//;
        ++$cnt_svgs;
        my $fname = "svgs/$cnt_svgs";

        mkdir ("$outdir/svgs");

        # create temporary svg file
        my $hd;
        open ($hd, ">:utf8", "$outdir/$fname.svg") 
            || die ("Cannot write to file $outdir/$fname.svg.\n");
        print $hd ($svg);
        close ($hd);
        
        debug ("convert");
        `$config->{'convert'} $convert_params "$outdir/$fname.svg" "$outdir/$fname.png"`;
        die if $?;

        if ($zip_images) {
            # this just records the file name, does not read the file in yet
            my $member = $zip->addFile ("$outdir/$fname.png", "$basename/$fname.png");
            $member->desiredCompressionMethod (COMPRESSION_STORED);
            $member = $zip->addFile ("$outdir/$fname.svg", "$basename/$fname.svg");
            $member->desiredCompressionMethod (COMPRESSION_DEFLATED);
        }
        # this must not return an extension
        # html needs urls ending in .svg and .png
        $e->setAttribute ("url", $fname);

        _get_image_size ($e, "$outdir/$fname.png");
    } else {
        print STDERR ("Could not make image out of formula.\n");
    }
    return $e;
}

sub pg_copy_image {
    my $url = shift;

    my $filename = $url;
    $filename =~ s!.*/!!; # just filename, no dirs

    my $e = XML::LibXML::Element->new ('root');
    $e->setAttribute ("url", "images/$filename");

    if (-f "$srcdir/$url") {
        if ($zip_images) {
            my $member = $zip->addFile ("$srcdir/$url", "$basename/images/$filename");
            $member->desiredCompressionMethod (COMPRESSION_STORED);
        }

        mkdir ("$outdir/images");
        copy("$srcdir/$url", "$outdir/images/$filename"); ##hkm

        _get_image_size ($e, "$srcdir/$url");
    }
    return $e;
}

sub _get_image_size {
    my $e = shift;
    my $path = shift;

    if (-x $config->{'identify'}) {
        my $id = `$config->{'identify'} "$path"`;
        if ($id =~ m/\s+(\d+)x(\d+)\s+/) {
            $e->setAttribute ("width", $1);
            $e->setAttribute ("height", $2);
        }
        debug ("identify: $id");
    }
    return $e;
}

sub pg_set_var ($$) {
    my $name  = shift;
    my $value = shift;
    $vars->{$name} = $value;
    return '';
}

sub pg_get_var ($) {
    my $name  = shift;
    my $value = $vars->{$name};
    return '' unless defined ($value);
    return $value;
}

sub pg_inc_var ($) {
    my $name  = shift;
    
    if (!exists ($vars->{$name})) {
        $vars->{$name} = 0;
    }
    
    return ++$vars->{$name};
}

sub pg_push_stack ($$) {
    my $name  = shift;
    my $value = shift;
    push (@{$stacks->{$name}}, $value);
    return '';
}

sub pg_pop_stack ($) {
    my $name  = shift;
    my $value = pop (@{$stacks->{$name}});
    return '' unless defined ($value);
    return $value;
}

sub pg_get_filedir {
    my $etext_no = shift;
    my $prefix = $etext_no;
    $prefix =~ s/.$//; # cut last digit
    $prefix =~ s!(.)!$1/!g;

    return "/dirs/$prefix$etext_no/";
}

sub pg_get_format {
    return $format;
}

sub pg_get_copyrighted {
    return $copyrighted;
}

my $colors = {
    # from HTML 4.01 spec
    black   => "000000",	
    silver  => "c0c0c0",	
    gray    => "808080",	
    white   => "ffffff",	
    maroon  => "800000",	
    red     => "ff0000",	
    purple  => "800080",	
    fuchsia => "ff00ff",
    green   => "008000",
    lime    => "00ff00",
    olive   => "808000",
    yellow  => "ffff00",
    navy    => "000080",
    blue    => "0000ff",
    teal    => "008080",
    aqua    => "00ffff",
};

sub fixcolor {
    my $color = lc (shift);
    if (defined $colors->{$color}) {
        $color = $colors->{$color};
    }
    $color =~ s/^\#//;
    if ($color =~ m/^[0-9a-f]{3}$/) {
        # f80 => ff8800
        $color =~ s/([0-9a-f])/$1$1/g;
    }
    if ($color =~ m/[0-9a-f]{6}/) {
        return $color;
    }
    return "000000";  # return black on error
}

sub pg_id2lang {
    return charmap::id2lang (shift);
}

sub pg_uc {
    return uc (shift);
}

sub pg_lc {
    return lc (shift);
}

sub pg_str_replicate {
    my $s = shift;
    my $n = shift;
    return $s x int ($n);
}

sub pg_get_etext_no {
    return $etext_no;
}

sub pg_get_basename {
    return $basename;
}

sub pg_get_fileext {
#    return '.htm' if $format eq 'html';
    return ".$format";
}

sub pg_get_formatted_title {
    my $s = "The Project Gutenberg EBook of ";
    
    my @titles = $doc->findnodes ("/TEI.2/teiHeader/fileDesc/titleStmt/title");
    $s .= $titles[0]->textContent;

    my @authors = $doc->findnodes ("/TEI.2/teiHeader/fileDesc/titleStmt/author");
    if (scalar @authors) {
        $s .= " by ";
        my $cauthors = @authors;
        my $i = 1;
        foreach my $author (@authors) {
            $s .= $author->textContent;
            if ($i < $cauthors - 1) {
                $s .= ", ";
            }
            if ($i < $cauthors) {
                $s .= " and ";
            }
            $i++;
        }
    }    
    return $s;
}

sub _format_header {
    my $key = shift;
    my $value = shift;
    my $indent = $key;
    $indent =~ s/./ /g;

    return wrap ("$key: ", "$indent  ", $value) . "\n\n";
}

sub pg_get_formatted_header {
    my $s = '';

    my @titles  = $doc->findnodes ("/TEI.2/teiHeader/fileDesc/titleStmt/title");
    my $title = $titles[0]->textContent;

    my $authors = $doc->findnodes ("/TEI.2/teiHeader/fileDesc/titleStmt/author");
    my $encoding = format::report_encoding ();
    
    $s .= _format_header ('Title', $title);
    $s .= _format_header ('Author', pg_get_author ($authors));
    $s .= _format_header ('Release Date', "$pubdate [Ebook \#$etext_no]"); # \xf8fc
    $s .= _format_header ('Language', pg_id2lang ($langid));
    $s .= _format_header ('Character set encoding', uc ($encoding)) if $encoding;
    $s .= "\n***START OF THE PROJECT GUTENBERG EBOOK " . uc ($title) . "***\n";

    return $s;
}

sub pg_get_formatted_footer {
    my @titles  = $doc->findnodes ("/TEI.2/teiHeader/fileDesc/titleStmt/title");
    my $title = uc ($titles[0]->textContent);
    return "***END OF THE PROJECT GUTENBERG EBOOK $title***\n";
}

sub pg_get_author {
    my $nl = shift;
    die "Not a nodelist" unless $nl->isa ('XML::LibXML::NodeList');

    my @authors;
    my @nodes = $nl->get_nodelist ();
    foreach my $node (@nodes) {
        push @authors, $node->textContent ();
    }
    if (@authors >= 2) {
        my $last = pop (@authors);
        my $prev = pop (@authors);
        push (@authors, "$prev and $last");
    }

    return join (', ', @authors);
}    
   
sub roman ($) {
    my $arabic = shift;

    my %r = qw (1 I 4 IV 5 V 9 IX 10 X 40 XL 50 L 90 XC 100 C 400 CD 500 D 900 CM 1000 M);
    my $roman = '';

    foreach my $sb (sort { $b <=> $a } keys %r) {
        while ($arabic >= int ($sb)) {
            $arabic -= $sb;
            $roman .= $r{$sb};
        }
    }    
    return $roman;
}

sub _style_counter ($$) {
    my $value = shift;
    my $style = shift;

    return ''         if ($style eq 'none');
    return "\x{2022}" if ($style eq 'disc');
    return "\x{25e6}" if ($style eq 'circle');
    return "\x{25a0}" if ($style eq 'square');
    return "\x{25a1}" if ($style eq 'box');
    return "\x{2713}" if ($style eq 'check');
    return "\x{25c6}" if ($style eq 'diamond');
    return "\x{2013}" if ($style eq 'hyphen');

    if ($style eq 'decimal') {
        return $value . '.';
    }
    if ($style eq 'decimal-leading-zero') {
        return "0$value." if ($value < 10);
        return $value . '.';
    }
    if ($style eq 'lower-latin' or $style eq 'lower-alpha') {
        return chr ($value + 0x60) . '.';
    }
    if ($style eq 'upper-latin' or $style eq 'upper-alpha') {
        return chr ($value + 0x40) . '.';
    }
    if ($style eq 'lower-greek') {
        return chr ($value + 0x3b0) . '.';
    }
    if ($style eq 'upper-greek') {
        return chr ($value + 0x390 . '.');
    }
    if ($style eq 'lower-roman') {
        return lc (roman ($value)) . '.';
    }
    if ($style eq 'upper-roman') {
        return roman ($value) . '.';
    }
    return $value;
}

sub parse_content ($$) {
    my $n       = shift;
    my $content = shift;

    die "Not an Element" unless $n->isa ('XML::LibXML::Element');

    my $output = '';

    while (1) {
        $content =~ m/\G\s*/gc;
        if ($content =~ m/\G\"(.*?)\"\s*/gc) {
            $output .= css::decode ($1);
            next;
        }
        if ($content =~ m/\G\'(.*?)\'\s*/gc) {
            $output .= css::decode ($1);
            next;
        }
        if ($content =~ m/\Gcounter\s*\((.*?)\)\s*/gc) {
            my ($countername, $counterstyle) = split (/[,\s]+/, $1);
            my $value = pg_counter_get ($n, $countername);
            if ($counterstyle) {
                $value = _style_counter ($value, $counterstyle);
            }
            $output .= $value;
            next;
        }
        last;
    }
    # debug ("parse_content: $content => $output");
    return $output;
}

sub _getprop (\%$) {
    my $h = shift;
    my $propname = shift;

    # debug ("_getprop $propname");

    return css::prop_from_hash ($h, $propname);
}

sub _isblock (\%) {
    my $h = shift;

    # this is what the user said
    my $display  = _getprop (%$h, 'display');
    if (defined $display) {
        return $display eq 'block';
    }

    # this is the css default 
    my $xdisplay = _getprop (%$h, 'x-display');
    return ($xdisplay && ($xdisplay eq 'block'));
}

sub _counter_mk_attribute ($$) {
    # node countername
    my $me = shift;
    my $countername = shift;

    die "Not an Element" unless $me->isa ('XML::LibXML::Element');
    my $name = $me->nodeName;

    # get nesting (see: section 12.4.1 of the CSS 2.1 spec)
    my $nesting = $me->find ("count(ancestor-or-self::*[\@x-counter-reset='$countername'])");

    return "x-counter-$countername-$nesting";
}

sub pg_counter_reset ($$@) {
    # node countername [value]
    my $me = shift;
    my $countername = shift;
    my $value = shift;

    die "Not an Element" unless $me->isa ('XML::LibXML::Element');
    $value = 0 if (!defined $value);
    $me->setAttribute ("x-counter-reset", $countername);

    my $attr = _counter_mk_attribute ($me, $countername);
    $me->setAttribute ($attr, $value);
}

sub pg_counter_increment ($$@) {
    # node countername [value]
    my $me = shift;
    my $countername = shift;
    my $value = shift;

    die "Not an Element" unless $me->isa ('XML::LibXML::Element');
    $value = 1 if (!defined $value);

    my $attr = _counter_mk_attribute ($me, $countername);

    # this works only because the following nodes 
    # do not have an attribute x-counter-* yet
    my $crit = "//*[\@$attr]";

    my @nodes = $me->findnodes ($crit);
    if (scalar @nodes) {
        my $preceding = pop (@nodes);
        $value += $preceding->getAttribute ($attr);
        $me->setAttribute ($attr, $value);
        return;
    } 
    pg_counter_reset ($me, $countername, 0);
}

sub pg_counter_get ($$) {
    # node countername
    my $me = shift;
    my $countername = shift;

    die "Not an Element" unless $me->isa ('XML::LibXML::Element');

    my $attr = _counter_mk_attribute ($me, $countername);

    my $value = $me->getAttribute ($attr);
    $value = 0 if (!defined $value);

    # debug ("counter-get: $attr = $value");
    return $value;
}

### get/set properties 

sub assert_element ($) {
    my $n = shift;
    if ($n->isa ('XML::LibXML::NodeList')) {
        $n = $n->get_node (1);
    }
    die "Not an Element" unless $n->isa ('XML::LibXML::Element');
    return $n;
}

sub pg_set_prop ($$$) {
    my $me = assert_element (shift ());
    my $propname = shift;
    my $value = shift;

    css::set_prop ($me, $propname, $value);
    return '';
}

sub pg_set_class ($$) {
    my $me = assert_element (shift ());
    my $classname = shift;

    css::set_class ($me, $classname);
    return '';
}

sub pg_get_prop ($$@) {
    my $me = assert_element (shift ());
    my $propname = shift;

    my $p = css::get_prop ($me, $propname);
    return $p if defined $p;

    return shift;
}

sub pg_default_prop ($$$) {
    my $me = assert_element (shift ());
    my $propname = shift;
    my $value = shift;

    my $h = css::hash_from_node ($me);
    $h->{$propname} = $value if (!exists $h->{$propname});
    return '';
}

sub pg_get_props ($) {
    my $me = assert_element (shift ());

    my $h = css::hash_from_node ($me);

    my $e = XML::LibXML::Element->new ('root');
    my $propsnode = XML::LibXML::Element->new ('properties');
    $e->addChild ($propsnode);
    
    while (my ($key, $value) = each (%{$h})) {
        # debug ("rend: $key, $value");
        # eval { $propsnode->setAttribute ($key, $value); }
        $value = 'null' unless defined ($value);
        if ($key =~ m/^[\w][-\w\d]*$/) {
            $value = css::decode_value_strip_quotes ($value);
            $propsnode->setAttribute ($key, $value);
        } else {
            debug ("setAttribute bogus key: '$key' => '$value'");
        }
    }
    return $e;
}

sub pg_disinherit ($) {
    my $me = assert_element (shift ());

    css::disinherit ($me);
    return;
}

sub mk_props_node (\@\@) {
    my $pre  = shift;
    my $post = shift;

    my $e = XML::LibXML::Element->new ('root');
    my $propsnode = XML::LibXML::Element->new ('properties');
    $e->addChild ($propsnode);
    
    if (@$pre) {
        $e->setAttribute ('pre',  join ('', @$pre));
    }
    if (@$post) {
        $e->setAttribute ('post', join ('', reverse @$post));
    }
    return $e;
}

sub pg_outband {
    my $s = shift;
    Encode::_utf8_on ($s);
        
    # apply the char mapping included with the TEI file
    $s =~ s/(.)/charmap::apply_charmap ($1)/eg; # may substitute multiple chars

    # put `active' chars out of band
    # (`active' chars are those who have a special meaning
    # in html, tex or nroff)
    $s =~ s/(.)/charmap::outband ($1)/eg;

    return $s;
}

sub pg_inband {
    my $s = shift;
    Encode::_utf8_on ($s);

    $s =~ s/(.)/charmap::inband ($1)/eg;
    return $s;
};

my $quote_signs = {};
$quote_signs->{'en-gb'}{'pre'} {0} = "\x{2018}";
$quote_signs->{'en-gb'}{'pre'} {1} = "\x{201c}";
$quote_signs->{'en-gb'}{'post'}{0} = "\x{2019}";
$quote_signs->{'en-gb'}{'post'}{1} = "\x{201d}";
$quote_signs->{'en-gb'}{'sep'}     = "\x{2009}";

$quote_signs->{'en-us'}{'pre'} {0} = "\x{201c}";
$quote_signs->{'en-us'}{'pre'} {1} = "\x{2018}";
$quote_signs->{'en-us'}{'post'}{0} = "\x{201d}";
$quote_signs->{'en-us'}{'post'}{1} = "\x{2019}";
$quote_signs->{'en-us'}{'sep'}     = "\x{2009}";

$quote_signs->{'de'}   {'pre'} {0} = "\x{201e}";
$quote_signs->{'de'}   {'pre'} {1} = "\x{201a}";
$quote_signs->{'de'}   {'post'}{0} = "\x{201c}";
$quote_signs->{'de'}   {'post'}{1} = "\x{2018}";
$quote_signs->{'de'}   {'sep'}     = "\x{2009}";

$quote_signs->{'fr'}   {'pre'} {0} = "«\x{2009}";
$quote_signs->{'fr'}   {'pre'} {1} = "\x{2039}\x{2009}";
$quote_signs->{'fr'}   {'post'}{0} = "\x{2009}»";
$quote_signs->{'fr'}   {'post'}{1} = "\x{2009}\x{203a}";
$quote_signs->{'fr'}   {'sep'}     = "";

sub pg_fix_quotes {
    my $me = shift;
    die "Not an Element" unless $me->isa ('XML::LibXML::Element');

    my $h = shift;

    my $level = 0;
    my $lang  = "en-us";

    my $pre  = defined ($h->{'pre'})  ? $h->{'pre'}  : 'default';
    my $post = defined ($h->{'post'}) ? $h->{'post'} : 'default';

    # debug ("quotes: pre($pre), post($post)");

    if ($pre eq 'default' || $post eq 'default') {
        # find the language of this quote
        $lang = $me->findvalue ("ancestor::*[\@lang][1]/\@lang");
        debug ("No language defined for node!") if !$lang;
        $lang = "en-us" if (!$lang || $lang eq "en");

        # find the level of this quote
        my $ancestor = $me;
        while ($ancestor = $ancestor->parentNode ()) {
            # get the quote nesting for this quote
            # count <q> ancestors but stop at the first <note>
            my $name = $ancestor->nodeName ();
            last if ($name eq "p" || $name eq "div" || $name eq "note");
            if ($name eq "q" || $name eq "quote") {
                my $isblockquote = $ancestor->hasAttribute ("x-is-block");
                last if $isblockquote;
                $level++;
            }
        }
        $level = $level % 2;
    }
    if ($pre eq 'default') {
        $pre = $quote_signs->{$lang}{'pre'}{$level};
        if ($me->firstChild ()->nodeName () =~ m/^q|quote$/) {
            $pre .= $quote_signs->{$lang}{'sep'};
        }
    } elsif ($pre ne 'none') {
        $pre = "&$pre;";
    }
    if ($post eq 'default') {
        $post = $quote_signs->{$lang}{'post'}{$level};
        if ($me->lastChild ()->nodeName () =~ m/^q|quote$/) {
            $post = $quote_signs->{$lang}{'sep'} . $post;
        }
    } elsif ($post ne 'none') {
        $post = "&$post;";
    }

    # debug ("quotes: pre($pre), post($post), level ($level)");

    my $child;
    if ($pre ne 'none') {
        $pre =~ s/(.)/charmap::apply_charmap ($1)/eg; # may substitute multiple chars
        $child = $doc->createTextNode ($pre);
        $me->insertBefore ($child, $me->firstChild);
    }
    if ($post ne 'none') {
        $post =~ s/(.)/charmap::apply_charmap ($1)/eg; # may substitute multiple chars
        $child = $doc->createTextNode ($post);
        $me->insertAfter ($child, $me->lastChild);
    }
};

sub pg_s1_list {
    # copy @type to rend class
    my $me = shift;
    die "Not an Element" unless $me->isa ('XML::LibXML::Element');

    my $h = shift;
    
    my $type = $me->getAttribute ('type');
    $type = 'simple' if !defined $type;

    $type = "x-list-$type";

    # add a class x-list-$type to all labels and items in this list
    # that class is used by the embedded stylesheet 
    # we have to set this on all children until we
    # implement selector hierarchy in css

    my @nodes = $me->findnodes (".|labelitem|labelitem/label|labelitem/item|labelitem/headLabel|labelitem/headItem");

    foreach my $n (@nodes) {
        my $rend = $n->getAttribute ('rend');
        if (defined $rend) {
            $n->setAttribute ('rend', "$type; $rend");
        } else {
            $n->setAttribute ('rend', $type);
        }            
    }
}

sub pg_s1_table ($) {
    # get a reliable count of columns
    my $me = shift;
    die "Not an Element" unless $me->isa ('XML::LibXML::Element');

    my $rows  = 0;
    my $cells = 0;

    my @rows = $me->findnodes ('row');
    $rows = scalar (@rows);

    foreach my $row (@rows) {
        my @cells = $row->findnodes ('cell');
        my $cnt = 0;
        foreach my $cell (@cells) {
            my $colspan = $cell->getAttribute ('cols');
            defined ($colspan) ? $cnt += $colspan : $cnt++;
        }
        $cells = $cnt if ($cells < $cnt);
    }
    
    $me->setAttribute ('rows', "$rows");
    $me->setAttribute ('cols', "$cells");
}

sub pg_pgIf {
    my $me = shift;
    die "Not an Element" unless $me->isa ('XML::LibXML::Element');
    my $remove = 'then'; # this is the branch to remove

    if ($me->hasAttribute ('output')) {
        my $output = $me->getAttribute ('output');
        $remove = 'else' if ($output eq $format);
    }
    if ($me->hasAttribute ('has')) {
        if ($me->getAttribute ('has') eq 'footnotes') {
            my $crit = "/TEI.2/text//notes[\@type='foot']";
            $crit = "/TEI.2/text//note[\@place='end']" if ($format eq 'pdf');
            my @footnotes = $doc->findnodes ($crit);
            $remove = 'else' if (scalar (@footnotes));
        }
    }
    if ($me->hasAttribute ('test')) {
        if ($me->getAttribute ('test') eq 'copyrighted') {
            $remove = 'else' if (pg_get_copyrighted ());
        }
    }

    # delete `$remove' branch
    foreach my $node ($me->getChildrenByTagName ($remove)) {
        # debug ("removing <$remove> node");
        $me->removeChild ($node);
    }
}

sub pg_pgVar {
    my $name = shift;

    return pg_get_etext_no ()                  if ($name eq 'etextno');
    return pg_get_formatted_title ()           if ($name eq 'formatted-title');
    return pg_get_formatted_header ()          if ($name eq 'formatted-header');
    return pg_get_formatted_footer ()          if ($name eq 'formatted-footer');
    return pg_get_filedir (pg_get_etext_no ()) if ($name eq 'filedir');
    return pg_get_basename ()                  if ($name eq 'filename');
    return pg_get_fileext ()                   if ($name eq 'fileext');
    return '.zip'                              if ($name eq 'zipext');

    if ($name eq 'title') {
        return $doc->find ('/TEI.2/teiHeader/fileDesc/titleStmt/title[1]');
    }
    if ($name eq 'author') {
        my $nl = $doc->findnodes ('/TEI.2/teiHeader/fileDesc/titleStmt/author');
        return pg_get_author ($nl);
    }
    if ($name eq 'releasedate') {
        return $doc->find ('/TEI.2/teiHeader/fileDesc/publicationStmt/date');
    }
    if ($name eq 'langid') {
        return $doc->find ('/TEI.2/@lang');
    }
    if ($name eq 'language') {
        return pg_id2lang ($doc->find ('/TEI.2/@lang'));
    }

    die ("Invalid <pgVar name=\"$name\">");
}

# stacks and variables
XML::LibXSLT->register_function ("$root_url/xslt", 
                                 "get-var", \&pg_get_var);
XML::LibXSLT->register_function ("$root_url/xslt", 
                                 "set-var", \&pg_set_var);
XML::LibXSLT->register_function ("$root_url/xslt", 
                                 "inc-var", \&pg_inc_var);
XML::LibXSLT->register_function ("$root_url/xslt", 
                                 "push-stack", \&pg_push_stack);
XML::LibXSLT->register_function ("$root_url/xslt", 
                                 "pop-stack", \&pg_pop_stack);

# css properties 
XML::LibXSLT->register_function ("$root_url/xslt", 
                                 "set-prop", \&pg_set_prop);
XML::LibXSLT->register_function ("$root_url/xslt", 
                                 "default-prop", \&pg_default_prop);
XML::LibXSLT->register_function ("$root_url/xslt", 
                                 "set-class", \&pg_set_class);
XML::LibXSLT->register_function ("$root_url/xslt", 
                                 "get-prop", \&pg_get_prop);
XML::LibXSLT->register_function ("$root_url/xslt", 
                                 "get-props", \&pg_get_props);
XML::LibXSLT->register_function ("$root_url/xslt", 
                                 "disinherit", \&pg_disinherit);

# css counters
XML::LibXSLT->register_function ("$root_url/xslt", 
                                 "counter-reset", \&pg_counter_reset);
XML::LibXSLT->register_function ("$root_url/xslt", 
                                 "counter-increment", \&pg_counter_increment);
XML::LibXSLT->register_function ("$root_url/xslt", 
                                 "counter-get", \&pg_counter_get);

# string functions
XML::LibXSLT->register_function ("$root_url/xslt", 
                                 "uc", \&pg_uc);
XML::LibXSLT->register_function ("$root_url/xslt", 
                                 "lc", \&pg_lc);
XML::LibXSLT->register_function ("$root_url/xslt", 
                                 "str-replicate", \&pg_str_replicate);

# information
XML::LibXSLT->register_function ("$root_url/xslt", 
                                 "get-formatted-title", \&pg_get_formatted_title);
XML::LibXSLT->register_function ("$root_url/xslt", 
                                 "get-formatted-header", \&pg_get_formatted_header);
XML::LibXSLT->register_function ("$root_url/xslt", 
                                 "get-formatted-footer", \&pg_get_formatted_footer);
XML::LibXSLT->register_function ("$root_url/xslt", 
                                 "get-author",  \&pg_get_author);
XML::LibXSLT->register_function ("$root_url/xslt", 
                                 "get-etext-no", \&pg_get_etext_no);
XML::LibXSLT->register_function ("$root_url/xslt", 
                                 "get-basename", \&pg_get_basename);
XML::LibXSLT->register_function ("$root_url/xslt", 
                                 "get-fileext", \&pg_get_fileext);
XML::LibXSLT->register_function ("$root_url/xslt", 
                                 "get-output-format", \&pg_get_format);
XML::LibXSLT->register_function ("$root_url/xslt", 
                                 "get-copyrighted", \&pg_get_copyrighted);
XML::LibXSLT->register_function ("$root_url/xslt", 
                                 "get-filedir", \&pg_get_filedir);
XML::LibXSLT->register_function ("$root_url/xslt", 
                                 "id2lang", \&pg_id2lang);
# misc
XML::LibXSLT->register_function ("$root_url/xslt", 
                                 "outband", \&pg_outband);
XML::LibXSLT->register_function ("$root_url/xslt", 
                                 "inband", \&pg_inband);
XML::LibXSLT->register_function ("$root_url/xslt", 
                                 "copy-image", \&pg_copy_image);
XML::LibXSLT->register_function ("$root_url/xslt", 
                                 "render-svg", \&pg_render_svg);
XML::LibXSLT->register_function ("$root_url/xslt", 
                                 "render-tex-formula", \&pg_render_tex_formula);

format::register_xpath_functions ();

########################################################################
# parse tei and xsl
########################################################################
    
our $parser = new XML::LibXML;

$parser->load_catalog ($config->{'catalog_file'});
$parser->load_ext_dtd (1);
$parser->complete_attributes (0);
$parser->expand_xinclude (1);
$parser->expand_entities (1);
$parser->line_numbers (1);

# $parser->clean_namespaces (1);

# load tei file

debug ("start parsing $infile");

eval {
    $parser->validation (1);
    $doc = $parser->parse_file ($infile);
};
die $@ if $@;

my $intsub = $doc->internalSubset ();
$intsub = $intsub->toString ();

die ("$infile is not a PGTEI 0.4 file") unless $intsub =~ m/$root_url/;

charmap::read_charmaps ($doc, \@mapfiles);

css::parse_builtin_stylesheet ();
css::parse_embedded_stylesheets ($doc);
# stylesheet::css_print_stylesheet () if $debug;

debug ("done parsing $infile");

# load xsl stylesheets

debug ("start parsing stylesheets");

$parser->validation (0); # don't validate XSL

my $xslt0 = $parser->parse_file ("$root_url/xsl/tei1include.xsl");
my $xslt1 = $parser->parse_file ("$root_url/xsl/teipreprocessor.xsl");

debug ("done parsing stylesheets");

debug ("start compiling stylesheets");

our $xslt  = XML::LibXSLT->new();
my $trans0 = $xslt->parse_stylesheet ($xslt0);
my $trans1 = $xslt->parse_stylesheet ($xslt1);

undef $xslt0;
undef $xslt1;

debug ("done compiling stylesheets");

########################################################################
# do transforms
########################################################################

$zip = Archive::Zip->new ();

chomp ($curdir = getcwd()); ## hkm chomp ($curdir = (`pwd`));

$etext_no = $doc->findvalue ('/TEI.2/teiHeader//idno[@type="etext-no"]');
$pubdate  = $doc->findvalue ('/TEI.2/teiHeader/fileDesc/publicationStmt/date');
$langid   = $doc->findvalue ('/TEI.2/@lang');

if ($etext_no =~ /C$/i) {
    $copyrighted = 1;
}
$etext_no = POSIX::strtod ($etext_no);
if (!$etext_no) {
    $etext_no = 999999;
}

debug ("etext-no: $etext_no");
debug ("Copyrighted etext!") if $copyrighted;
debug ("outdir: $outdir");

debug ("do transform pass 0 (include pg license)");
$doc = $trans0->transform ($doc);
undef $trans0;

### hyphenation (experimental)

my $hyphenations = {};

# collect langs from document

my %doclangs;

@nodes = $doc->findnodes ('//*[@lang]');
foreach my $n (@nodes) {
    my $lang = $n->getAttribute ('lang');
    $doclangs{$lang} = 1;
}

foreach my $lang (sort keys %doclangs) {
    my $patternfile = "$config->{'install_dir'}/hyphenation/patterns.$lang";
    if (! -r $patternfile) {
        debug ("No hyphenation patterns found for language = $lang");
        next;
    }
    my $hyp = new Hyphen (
                          file       => $patternfile,
                          hyphenchar => "\x{c2}\x{ad}", # U+00AD
                          leftmin    => 2,
                          rightmin   => 2,
                         );
    if (defined $hyp) {
        $hyphenations->{$lang} = $hyp;
        debug ("Hyphenation patterns for language = $lang loaded from $patternfile");
    } else {
        debug ("Error while parsing $patternfile");
    }
}

# copy line number into attribute
if ($debug) {
    @nodes = $doc->findnodes ("//*");
    foreach my $n (@nodes) {
        $n->setAttribute ('x-lineno', $n->line_number ());
    }
}

# substitute pgVar and pgIf

# we substitute pgVar twice, once now, 
# to get a (nearly) correct codepoint count
# and once later when we know the chosen encoding 
# (the encoding may depend on what characters pgVar inserts)
@nodes = $doc->findnodes ('//pgVar');
foreach my $n (@nodes) {
	my $pgattribute = pg_pgVar ($n->getAttribute ('name')); #hkm
    if (defined $pgattribute) {
    	$n->appendTextNode ($pgattribute); #hkm
    }
}
@nodes = $doc->findnodes ('//pgIf');
foreach my $n (@nodes) {
    pg_pgIf ($n);
}
@nodes = $doc->findnodes ('//divGen[@type="encodingDesc"]');
foreach my $n (@nodes) {
    my $parent = $n->parentNode;
    foreach my $note ($charmap::notes->get_nodelist ()) {
        $parent->insertBefore ($note, $n);
    }
    $parent->removeChild ($n);
}

########################################################################
# 1. xslt pass

debug ("do transform pass 1 (general)");
$doc = $trans1->transform ($doc);
undef $trans1;

# fix list classes
@nodes = $doc->findnodes ("//list");
foreach my $n (@nodes) {
    pg_s1_list ($n);
}

# give an id to all nodes
my $id = 0;
@nodes = $doc->findnodes ("//*");
foreach my $n (@nodes) {
    $n->setAttribute ('x-id', $id++);
}

my $open_block = 0;

sub recurse_nodes_s1 {
    my $n          = shift; # $
    my $inherited  = shift; # \%
    my $ref_open_block = shift;
    my $p;
    my $h = {};

    if ($n->isa ('XML::LibXML::Element')) {
        my $name = $n->nodeName;
        my $id   = $n->getAttribute ('x-id');

        ### get CCS properties 

        my $rend = '';
        if ($n->hasAttribute ('rend')) {
            $rend = $n->getAttribute ('rend');
            Encode::_utf8_on ($rend);
        }
        $h = css::parse_rend ($name, $rend);

        $h->{'x-parent'}   = $inherited;
        $h->{'x-id'}       = $id;
        $h->{'x-noderef'}  = $n;
        $h->{'x-nodename'} = $name;
        $h->{'x-lang'}     = $n->getAttribute ('lang') if ($n->hasAttribute ('lang'));

        ### do things 

        # always turn off hyphenation in formulas
        $h->{'hyphenate'} = 'none' if ($name eq 'formula');

        if (_isblock (%$h)) {
            # set an easy-to-test attribute
            $n->setAttribute ('x-is-block', 1);
            $h->{'x-display'} = 'block';
            if (_getprop (%$h, 'x-element') eq 'span') {
                $h->{'x-element'} = 'div';
            }
            # set if a block element interrupts an unfinished parent block
            if ($$ref_open_block) {
                $h->{'x-open-block'} = 1;
            }
            $$ref_open_block = 0;
        }
        # last para ?
        if ($name eq 'p') {
            my $s = $n->findvalue ("following-sibling::*");
            if ($s =~ m/\S/) {
                $h->{'x-content-follows'} = 1;
            }                
        }
        # fix quotes
        if ($name eq 'q' || $name eq 'quote') {
            pg_fix_quotes ($n, $h);
        }
        # fix lists
        if ($name eq 'label' || $name eq 'headLabel') {
            $p = _getprop (%$h, 'list-style-type');
            if (defined $p) {
                $h->{'content'} = "counter(x-list $p)";
            }
        }
        # fix tables
        if ($name eq 'table') {
            pg_s1_table ($n);
        }
        # counters
        if ($p = _getprop (%$h, 'counter-reset')) {
            my ($countername, $value) = split (/\s+/, $p);
            pg_counter_reset ($n, $countername, $value);
        }
        if ($p = _getprop (%$h, 'counter-increment')) {
            my ($countername, $value) = split (/\s+/, $p);
            pg_counter_increment ($n, $countername, $value);
        }

        # generated content
        if ($p = _getprop (%$h, 'content')) {
            my $content = parse_content ($n, $p);
            # debug ("Content: $content");
            $n->appendTextNode ($content) if (length ($content));
        }

        # debug ("undefined id") if !defined $id;

        # store properties away for later re-use
        $css::properties->{$id} = $h if defined $id;

        # turn type attribute into class
        if ($n->hasAttribute ('type')) {
            my $type = $n->getAttribute ('type');
            Encode::_utf8_on ($type);
            css::set_class ($n, "x-type-$type");
        }
        # nesting
        if ($name eq 'div') {
            my $level = $n->findvalue ('count(ancestor-or-self::div)');
            $n->setAttribute ('x-div-nesting', $level);
            css::set_class ($n, "x-div$level");
        }
    }

    if ($n->isa ('XML::LibXML::Text')) {
        $h = $inherited; # text node has no attributes of its own

        my $s = $n->data;
        Encode::_utf8_on ($s);
        my $lang;
        my $changed = 0;

        if (($p = _getprop (%$h, 'hyphenate')) && ($lang = _getprop (%$h, 'x-lang'))) {
            if ($p eq 'auto') {
                if (defined $hyphenations->{$lang}) {
                    my $hyp = $hyphenations->{$lang};
                    $s =~ s/(\w+)/$hyp->hyphenate($1)/eg;
                    $changed = 1;
                }
            }
        }

        $$ref_open_block = 1 if ($s =~ m/\S/);

        if ($changed) {
            $n->setData ($s);
        }

        return;
    }

    ### only elements have children
    # ... but document is not an element :-(

    my $child = $n->firstChild ();
    my $open_block = 0;
    while ($child) {
        recurse_nodes_s1 ($child, $h, \$open_block);
        $child = $child->nextSibling;
    }
    return;
}

recurse_nodes_s1 ($doc, { 'x-lang' => 'en', 'hyphenate' => 'none' });

# apply char mappings
# see which unicode characters the text contains
# (pgVar answers may depend on the encoding)

debug ("analyzing codepoints ...");

@nodes = $doc->findnodes ("/TEI.2/teiHeader//text()|/TEI.2/text//text()");
foreach my $n (@nodes) {
    my $s = $n->data;
    Encode::_utf8_on ($s);
        
    # apply the char mapping included with the TEI file
    $s =~ s/(.)/charmap::apply_charmap ($1)/eg; # may substitute multiple chars

    # count codepoints
    $s =~ s/(.)/charmap::count_codepoints ($1)/eg;

    # put `active' chars out of band
    # (`active' chars are those who have a special meaning
    # in html, tex or nroff)
    $s =~ s/(.)/charmap::outband ($1)/eg;

    $n->setData ($s);
}

# hook for format files
# set $basename here
format::s1_post ();

if ($debug) {
    # this is not an accurate count of codepoints
    # just a hint why it does not generate the encoding you want
    debug ("Codepoints:\n" . 
           charmap::print_codepoints (charmap::get_codepoints ()));
}

# do pgVar the second time (encoding is known here)
@nodes = $doc->findnodes ('//pgVar');
foreach my $n (@nodes) {
    my $name = $n->getAttribute ('name');
    if ($name eq 'filename' || $name eq 'formatted-header') {
        $n->removeChildNodes (); # from first pgVar substitution
        $n->appendTextNode (pg_pgVar ($name));
    }
}

if ($debug) {
    open (TMP, ">:utf8", "$outdir/$basename.s1.xml");
    print TMP $doc->toString ();
    close (TMP);
}

########################################################################
# 2. xslt pass
# done in format-specific backends
########################################################################

debug ("passing to back-end");

format::s2 ();

debug ("done back-end");

########################################################################
# zip it up and deliver
########################################################################

debug ("start zipping files");

$zip->writeToFileNamed ("$outdir/$basename.zip");

debug ("done zipping files");

debug ("outdir: $outdir/");

if ($debug) {
    format::debug_viewer ();
}

debug ("done all");

# Local Variables:
# mode:perl
# coding:utf-8-unix
# End:
