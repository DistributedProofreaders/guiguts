#############################################################################
# Pod/Checker.pm -- check pod documents for syntax errors
#
# Copyright (C) 1994-2000 by Bradford Appleton. All rights reserved.
# This file is part of "PodParser". PodParser is free software;
# you can redistribute it and/or modify it under the same terms
# as Perl itself.
#############################################################################

package Pod::Checker;

use vars qw($VERSION);
$VERSION = 1.41;  ## Current version of this package
require  5.005;    ## requires this Perl version or later

use Pod::ParseUtils; ## for hyperlinks and lists

#############################################################################

use strict;
#use diagnostics;
use Carp;
use Exporter;
use Pod::Parser;

use vars qw(@ISA @EXPORT);
@ISA = qw(Pod::Parser);
@EXPORT = qw(&podchecker);

use vars qw(%VALID_COMMANDS %VALID_SEQUENCES);

my %VALID_COMMANDS = (
    'pod'    =>  1,
    'cut'    =>  1,
    'head1'  =>  1,
    'head2'  =>  1,
    'head3'  =>  1,
    'head4'  =>  1,
    'over'   =>  1,
    'back'   =>  1,
    'item'   =>  1,
    'for'    =>  1,
    'begin'  =>  1,
    'end'    =>  1,
);

my %VALID_SEQUENCES = (
    'I'  =>  1,
    'B'  =>  1,
    'S'  =>  1,
    'C'  =>  1,
    'L'  =>  1,
    'F'  =>  1,
    'X'  =>  1,
    'Z'  =>  1,
    'E'  =>  1,
);

# stolen from HTML::Entities
my %ENTITIES = (
 # Some normal chars that have special meaning in SGML context
 amp    => '&',  # ampersand 
'gt'    => '>',  # greater than
'lt'    => '<',  # less than
 quot   => '"',  # double quote

 # PUBLIC ISO 8879-1986//ENTITIES Added Latin 1//EN//HTML
 AElig	=> 'Æ',  # capital AE diphthong (ligature)
 Aacute	=> 'Á',  # capital A, acute accent
 Acirc	=> 'Â',  # capital A, circumflex accent
 Agrave	=> 'À',  # capital A, grave accent
 Aring	=> 'Å',  # capital A, ring
 Atilde	=> 'Ã',  # capital A, tilde
 Auml	=> 'Ä',  # capital A, dieresis or umlaut mark
 Ccedil	=> 'Ç',  # capital C, cedilla
 ETH	=> 'Ð',  # capital Eth, Icelandic
 Eacute	=> 'É',  # capital E, acute accent
 Ecirc	=> 'Ê',  # capital E, circumflex accent
 Egrave	=> 'È',  # capital E, grave accent
 Euml	=> 'Ë',  # capital E, dieresis or umlaut mark
 Iacute	=> 'Í',  # capital I, acute accent
 Icirc	=> 'Î',  # capital I, circumflex accent
 Igrave	=> 'Ì',  # capital I, grave accent
 Iuml	=> 'Ï',  # capital I, dieresis or umlaut mark
 Ntilde	=> 'Ñ',  # capital N, tilde
 Oacute	=> 'Ó',  # capital O, acute accent
 Ocirc	=> 'Ô',  # capital O, circumflex accent
 Ograve	=> 'Ò',  # capital O, grave accent
 Oslash	=> 'Ø',  # capital O, slash
 Otilde	=> 'Õ',  # capital O, tilde
 Ouml	=> 'Ö',  # capital O, dieresis or umlaut mark
 THORN	=> 'Þ',  # capital THORN, Icelandic
 Uacute	=> 'Ú',  # capital U, acute accent
 Ucirc	=> 'Û',  # capital U, circumflex accent
 Ugrave	=> 'Ù',  # capital U, grave accent
 Uuml	=> 'Ü',  # capital U, dieresis or umlaut mark
 Yacute	=> 'Ý',  # capital Y, acute accent
 aacute	=> 'á',  # small a, acute accent
 acirc	=> 'â',  # small a, circumflex accent
 aelig	=> 'æ',  # small ae diphthong (ligature)
 agrave	=> 'à',  # small a, grave accent
 aring	=> 'å',  # small a, ring
 atilde	=> 'ã',  # small a, tilde
 auml	=> 'ä',  # small a, dieresis or umlaut mark
 ccedil	=> 'ç',  # small c, cedilla
 eacute	=> 'é',  # small e, acute accent
 ecirc	=> 'ê',  # small e, circumflex accent
 egrave	=> 'è',  # small e, grave accent
 eth	=> 'ð',  # small eth, Icelandic
 euml	=> 'ë',  # small e, dieresis or umlaut mark
 iacute	=> 'í',  # small i, acute accent
 icirc	=> 'î',  # small i, circumflex accent
 igrave	=> 'ì',  # small i, grave accent
 iuml	=> 'ï',  # small i, dieresis or umlaut mark
 ntilde	=> 'ñ',  # small n, tilde
 oacute	=> 'ó',  # small o, acute accent
 ocirc	=> 'ô',  # small o, circumflex accent
 ograve	=> 'ò',  # small o, grave accent
 oslash	=> 'ø',  # small o, slash
 otilde	=> 'õ',  # small o, tilde
 ouml	=> 'ö',  # small o, dieresis or umlaut mark
 szlig	=> 'ß',  # small sharp s, German (sz ligature)
 thorn	=> 'þ',  # small thorn, Icelandic
 uacute	=> 'ú',  # small u, acute accent
 ucirc	=> 'û',  # small u, circumflex accent
 ugrave	=> 'ù',  # small u, grave accent
 uuml	=> 'ü',  # small u, dieresis or umlaut mark
 yacute	=> 'ý',  # small y, acute accent
 yuml	=> 'ÿ',  # small y, dieresis or umlaut mark

 # Some extra Latin 1 chars that are listed in the HTML3.2 draft (21-May-96)
 copy   => '©',  # copyright sign
 reg    => '®',  # registered sign
 nbsp   => "\240", # non breaking space

 # Additional ISO-8859/1 entities listed in rfc1866 (section 14)
 iexcl  => '¡',
 cent   => '¢',
 pound  => '£',
 curren => '¤',
 yen    => '¥',
 brvbar => '¦',
 sect   => '§',
 uml    => '¨',
 ordf   => 'ª',
 laquo  => '«',
'not'   => '¬',    # not is a keyword in perl
 shy    => '­',
 macr   => '¯',
 deg    => '°',
 plusmn => '±',
 sup1   => '¹',
 sup2   => '²',
 sup3   => '³',
 acute  => '´',
 micro  => 'µ',
 para   => '¶',
 middot => '·',
 cedil  => '¸',
 ordm   => 'º',
 raquo  => '»',
 frac14 => '¼',
 frac12 => '½',
 frac34 => '¾',
 iquest => '¿',
'times' => '×',    # times is a keyword in perl
 divide => '÷',

# some POD special entities
 verbar => '|',
 sol => '/'
);

##---------------------------------------------------------------------------

##---------------------------------
## Function definitions begin here
##---------------------------------

sub podchecker( $ ; $ % ) {
    my ($infile, $outfile, %options) = @_;
    local $_;

    ## Set defaults
    $infile  ||= \*STDIN;
    $outfile ||= \*STDERR;

    ## Now create a pod checker
    my $checker = new Pod::Checker(%options);

    ## Now check the pod document for errors
    $checker->parse_from_file($infile, $outfile);

    ## Return the number of errors found
    return $checker->num_errors();
}

##---------------------------------------------------------------------------

##-------------------------------
## Method definitions begin here
##-------------------------------

##################################

## sub new {
##     my $this = shift;
##     my $class = ref($this) || $this;
##     my %params = @_;
##     my $self = {%params};
##     bless $self, $class;
##     $self->initialize();
##     return $self;
## }

sub initialize {
    my $self = shift;
    ## Initialize number of errors, and setup an error function to
    ## increment this number and then print to the designated output.
    $self->{_NUM_ERRORS} = 0;
    $self->{_NUM_WARNINGS} = 0;
    $self->{-quiet} ||= 0;
    # set the error handling subroutine
    $self->errorsub($self->{-quiet} ? sub { 1; } : 'poderror');
    $self->{_commands} = 0; # total number of POD commands encountered
    $self->{_list_stack} = []; # stack for nested lists
    $self->{_have_begin} = ''; # stores =begin
    $self->{_links} = []; # stack for internal hyperlinks
    $self->{_nodes} = []; # stack for =head/=item nodes
    $self->{_index} = []; # text in X<>
    # print warnings?
    $self->{-warnings} = 1 unless(defined $self->{-warnings});
    $self->{_current_head1} = ''; # the current =head1 block
    $self->parseopts(-process_cut_cmd => 1, -warnings => $self->{-warnings});
}

##################################

# Invoked as $self->poderror( @args ), or $self->poderror( {%opts}, @args )
sub poderror {
    my $self = shift;
    my %opts = (ref $_[0]) ? %{shift()} : ();

    ## Retrieve options
    chomp( my $msg  = ($opts{-msg} || "")."@_" );
    my $line = (exists $opts{-line}) ? " at line $opts{-line}" : "";
    my $file = (exists $opts{-file}) ? " in file $opts{-file}" : "";
    unless (exists $opts{-severity}) {
       ## See if can find severity in message prefix
       $opts{-severity} = $1  if ( $msg =~ s/^\**\s*([A-Z]{3,}):\s+// );
    }
    my $severity = (exists $opts{-severity}) ? "*** $opts{-severity}: " : "";

    ## Increment error count and print message "
    ++($self->{_NUM_ERRORS}) 
        if(!%opts || ($opts{-severity} && $opts{-severity} eq 'ERROR'));
    ++($self->{_NUM_WARNINGS})
        if(!%opts || ($opts{-severity} && $opts{-severity} eq 'WARNING'));
    my $out_fh = $self->output_handle() || \*STDERR;
    print $out_fh ($severity, $msg, $line, $file, "\n")
      if($self->{-warnings} || !%opts || $opts{-severity} ne 'WARNING');
}

##################################

sub num_errors {
   return (@_ > 1) ? ($_[0]->{_NUM_ERRORS} = $_[1]) : $_[0]->{_NUM_ERRORS};
}

##################################

sub num_warnings {
   return (@_ > 1) ? ($_[0]->{_NUM_WARNINGS} = $_[1]) : $_[0]->{_NUM_WARNINGS};
}

##################################

sub name {
    return (@_ > 1 && $_[1]) ?
        ($_[0]->{-name} = $_[1]) : $_[0]->{-name};  
}

##################################

sub node {
    my ($self,$text) = @_;
    if(defined $text) {
        $text =~ s/\s+$//s; # strip trailing whitespace
        $text =~ s/\s+/ /gs; # collapse whitespace
        # add node, order important!
        push(@{$self->{_nodes}}, $text);
        # keep also a uniqueness counter
        $self->{_unique_nodes}->{$text}++ if($text !~ /^\s*$/s);
        return $text;
    }
    @{$self->{_nodes}};
}

##################################

# set/return index entries of current POD
sub idx {
    my ($self,$text) = @_;
    if(defined $text) {
        $text =~ s/\s+$//s; # strip trailing whitespace
        $text =~ s/\s+/ /gs; # collapse whitespace
        # add node, order important!
        push(@{$self->{_index}}, $text);
        # keep also a uniqueness counter
        $self->{_unique_nodes}->{$text}++ if($text !~ /^\s*$/s);
        return $text;
    }
    @{$self->{_index}};
}

##################################

# set/return hyperlinks of the current POD
sub hyperlink {
    my $self = shift;
    if($_[0]) {
        push(@{$self->{_links}}, $_[0]);
        return $_[0];
    }
    @{$self->{_links}};
}

## overrides for Pod::Parser

sub end_pod {
    ## Do some final checks and
    ## print the number of errors found
    my $self   = shift;
    my $infile = $self->input_file();
    my $out_fh = $self->output_handle();

    if(@{$self->{_list_stack}}) {
        my $list;
        while(($list = $self->_close_list('EOF',$infile)) &&
          $list->indent() ne 'auto') {
            $self->poderror({ -line => 'EOF', -file => $infile,
                -severity => 'ERROR', -msg => "=over on line " .
                $list->start() . " without closing =back" }); #"
        }
    }

    # check validity of document internal hyperlinks
    # first build the node names from the paragraph text
    my %nodes;
    foreach($self->node()) {
        $nodes{$_} = 1;
        if(/^(\S+)\s+\S/) {
            # we have more than one word. Use the first as a node, too.
            # This is used heavily in perlfunc.pod
            $nodes{$1} ||= 2; # derived node
        }
    }
    foreach($self->idx()) {
        $nodes{$_} = 3; # index node
    }
    foreach($self->hyperlink()) {
        my ($line,$link) = @$_;
        # _TODO_ what if there is a link to the page itself by the name,
        # e.g. in Tk::Pod : L<Tk::Pod/"DESCRIPTION">
        if($link->node() && !$link->page() && $link->type() ne 'hyperlink') {
            my $node = $self->_check_ptree($self->parse_text($link->node(),
                $line), $line, $infile, 'L');
            if($node && !$nodes{$node}) {
                $self->poderror({ -line => $line || '', -file => $infile,
                    -severity => 'ERROR',
                    -msg => "unresolved internal link '$node'"});
            }
        }
    }

    # check the internal nodes for uniqueness. This pertains to
    # =headX, =item and X<...>
    foreach(grep($self->{_unique_nodes}->{$_} > 1,
      keys %{$self->{_unique_nodes}})) {
        $self->poderror({ -line => '-', -file => $infile,
            -severity => 'WARNING',
            -msg => "multiple occurrence of link target '$_'"});
    }

    # no POD found here
    $self->num_errors(-1) if($self->{_commands} == 0);
}

# check a POD command directive
sub command { 
    my ($self, $cmd, $paragraph, $line_num, $pod_para) = @_;
    my ($file, $line) = $pod_para->file_line;
    ## Check the command syntax
    my $arg; # this will hold the command argument
    if (! $VALID_COMMANDS{$cmd}) {
       $self->poderror({ -line => $line, -file => $file, -severity => 'ERROR',
                         -msg => "Unknown command '$cmd'" });
    }
    else { # found a valid command
        $self->{_commands}++; # delete this line if below is enabled again

        ##### following check disabled due to strong request
        #if(!$self->{_commands}++ && $cmd !~ /^head/) {
        #    $self->poderror({ -line => $line, -file => $file,
        #         -severity => 'WARNING', 
        #         -msg => "file does not start with =head" });
        #}

        # check syntax of particular command
        if($cmd eq 'over') {
            # check for argument
            $arg = $self->interpolate_and_check($paragraph, $line,$file);
            my $indent = 4; # default
            if($arg && $arg =~ /^\s*(\d+)\s*$/) {
                $indent = $1;
            }
            # start a new list
            $self->_open_list($indent,$line,$file);
        }
        elsif($cmd eq 'item') {
            # are we in a list?
            unless(@{$self->{_list_stack}}) {
                $self->poderror({ -line => $line, -file => $file,
                     -severity => 'ERROR', 
                     -msg => "=item without previous =over" });
                # auto-open in case we encounter many more
                $self->_open_list('auto',$line,$file);
            }
            my $list = $self->{_list_stack}->[0];
            # check whether the previous item had some contents
            if(defined $self->{_list_item_contents} &&
              $self->{_list_item_contents} == 0) {
                $self->poderror({ -line => $line, -file => $file,
                     -severity => 'WARNING', 
                     -msg => "previous =item has no contents" });
            }
            if($list->{_has_par}) {
                $self->poderror({ -line => $line, -file => $file,
                     -severity => 'WARNING', 
                     -msg => "preceding non-item paragraph(s)" });
                delete $list->{_has_par};
            }
            # check for argument
            $arg = $self->interpolate_and_check($paragraph, $line, $file);
            if($arg && $arg =~ /(\S+)/) {
                $arg =~ s/[\s\n]+$//;
                my $type;
                if($arg =~ /^[*]\s*(\S*.*)/) {
                  $type = 'bullet';
                  $self->{_list_item_contents} = $1 ? 1 : 0;
                  $arg = $1;
                }
                elsif($arg =~ /^\d+\.?\s*(\S*)/) {
                  $type = 'number';
                  $self->{_list_item_contents} = $1 ? 1 : 0;
                  $arg = $1;
                }
                else {
                  $type = 'definition';
                  $self->{_list_item_contents} = 1;
                }
                my $first = $list->type();
                if($first && $first ne $type) {
                    $self->poderror({ -line => $line, -file => $file,
                       -severity => 'WARNING', 
                       -msg => "=item type mismatch ('$first' vs. '$type')"});
                }
                else { # first item
                    $list->type($type);
                }
            }
            else {
                $self->poderror({ -line => $line, -file => $file,
                     -severity => 'WARNING', 
                     -msg => "No argument for =item" });
		$arg = ' '; # empty
                $self->{_list_item_contents} = 0;
            }
            # add this item
            $list->item($arg);
            # remember this node
            $self->node($arg);
        }
        elsif($cmd eq 'back') {
            # check if we have an open list
            unless(@{$self->{_list_stack}}) {
                $self->poderror({ -line => $line, -file => $file,
                         -severity => 'ERROR', 
                         -msg => "=back without previous =over" });
            }
            else {
                # check for spurious characters
                $arg = $self->interpolate_and_check($paragraph, $line,$file);
                if($arg && $arg =~ /\S/) {
                    $self->poderror({ -line => $line, -file => $file,
                         -severity => 'ERROR', 
                         -msg => "Spurious character(s) after =back" });
                }
                # close list
                my $list = $self->_close_list($line,$file);
                # check for empty lists
                if(!$list->item() && $self->{-warnings}) {
                    $self->poderror({ -line => $line, -file => $file,
                         -severity => 'WARNING', 
                         -msg => "No items in =over (at line " .
                         $list->start() . ") / =back list"}); #"
                }
            }
        }
        elsif($cmd =~ /^head(\d+)/) {
            my $hnum = $1;
            $self->{"_have_head_$hnum"}++; # count head types
            if($hnum > 1 && !$self->{"_have_head_".($hnum -1)}) {
              $self->poderror({ -line => $line, -file => $file,
                   -severity => 'WARNING', 
                   -msg => "=head$hnum without preceding higher level"});
            }
            # check whether the previous =head section had some contents
            if(defined $self->{_commands_in_head} &&
              $self->{_commands_in_head} == 0 &&
              defined $self->{_last_head} &&
              $self->{_last_head} >= $hnum) {
                $self->poderror({ -line => $line, -file => $file,
                     -severity => 'WARNING', 
                     -msg => "empty section in previous paragraph"});
            }
            $self->{_commands_in_head} = -1;
            $self->{_last_head} = $hnum;
            # check if there is an open list
            if(@{$self->{_list_stack}}) {
                my $list;
                while(($list = $self->_close_list($line,$file)) &&
                  $list->indent() ne 'auto') {
                    $self->poderror({ -line => $line, -file => $file,
                         -severity => 'ERROR', 
                         -msg => "=over on line ". $list->start() .
                         " without closing =back (at $cmd)" });
                }
            }
            # remember this node
            $arg = $self->interpolate_and_check($paragraph, $line,$file);
            $arg =~ s/[\s\n]+$//s;
            $self->node($arg);
            unless(length($arg)) {
                $self->poderror({ -line => $line, -file => $file,
                     -severity => 'ERROR', 
                     -msg => "empty =$cmd"});
            }
            if($cmd eq 'head1') {
                $self->{_current_head1} = $arg;
            } else {
                $self->{_current_head1} = '';
            }
        }
        elsif($cmd eq 'begin') {
            if($self->{_have_begin}) {
                # already have a begin
                $self->poderror({ -line => $line, -file => $file,
                     -severity => 'ERROR', 
                     -msg => "Nested =begin's (first at line " .
                     $self->{_have_begin} . ")"});
            }
            else {
                # check for argument
                $arg = $self->interpolate_and_check($paragraph, $line,$file);
                unless($arg && $arg =~ /(\S+)/) {
                    $self->poderror({ -line => $line, -file => $file,
                         -severity => 'ERROR', 
                         -msg => "No argument for =begin"});
                }
                # remember the =begin
                $self->{_have_begin} = "$line:$1";
            }
        }
        elsif($cmd eq 'end') {
            if($self->{_have_begin}) {
                # close the existing =begin
                $self->{_have_begin} = '';
                # check for spurious characters
                $arg = $self->interpolate_and_check($paragraph, $line,$file);
                # the closing argument is optional
                #if($arg && $arg =~ /\S/) {
                #    $self->poderror({ -line => $line, -file => $file,
                #         -severity => 'WARNING', 
                #         -msg => "Spurious character(s) after =end" });
                #}
            }
            else {
                # don't have a matching =begin
                $self->poderror({ -line => $line, -file => $file,
                     -severity => 'ERROR', 
                     -msg => "=end without =begin" });
            }
        }
        elsif($cmd eq 'for') {
            unless($paragraph =~ /\s*(\S+)\s*/) {
                $self->poderror({ -line => $line, -file => $file,
                     -severity => 'ERROR', 
                     -msg => "=for without formatter specification" });
            }
            $arg = ''; # do not expand paragraph below
        }
        elsif($cmd =~ /^(pod|cut)$/) {
            # check for argument
            $arg = $self->interpolate_and_check($paragraph, $line,$file);
            if($arg && $arg =~ /(\S+)/) {
                $self->poderror({ -line => $line, -file => $file,
                      -severity => 'ERROR', 
                      -msg => "Spurious text after =$cmd"});
            }
        }
    $self->{_commands_in_head}++;
    ## Check the interior sequences in the command-text
    $self->interpolate_and_check($paragraph, $line,$file)
        unless(defined $arg);
    }
}

sub _open_list
{
    my ($self,$indent,$line,$file) = @_;
    my $list = Pod::List->new(
           -indent => $indent,
           -start => $line,
           -file => $file);
    unshift(@{$self->{_list_stack}}, $list);
    undef $self->{_list_item_contents};
    $list;
}

sub _close_list
{
    my ($self,$line,$file) = @_;
    my $list = shift(@{$self->{_list_stack}});
    if(defined $self->{_list_item_contents} &&
      $self->{_list_item_contents} == 0) {
        $self->poderror({ -line => $line, -file => $file,
            -severity => 'WARNING', 
            -msg => "previous =item has no contents" });
    }
    undef $self->{_list_item_contents};
    $list;
}

# process a block of some text
sub interpolate_and_check {
    my ($self, $paragraph, $line, $file) = @_;
    ## Check the interior sequences in the command-text
    # and return the text
    $self->_check_ptree(
        $self->parse_text($paragraph,$line), $line, $file, '');
}

sub _check_ptree {
    my ($self,$ptree,$line,$file,$nestlist) = @_;
    local($_);
    my $text = '';
    # process each node in the parse tree
    foreach(@$ptree) {
        # regular text chunk
        unless(ref) {
            # count the unescaped angle brackets
            # complain only when warning level is greater than 1
            if($self->{-warnings} && $self->{-warnings}>1) {
              my $count;
              if($count = tr/<>/<>/) {
                $self->poderror({ -line => $line, -file => $file,
                     -severity => 'WARNING', 
                     -msg => "$count unescaped <> in paragraph" });
                }
            }
            $text .= $_;
            next;
        }
        # have an interior sequence
        my $cmd = $_->cmd_name();
        my $contents = $_->parse_tree();
        ($file,$line) = $_->file_line();
        # check for valid tag
        if (! $VALID_SEQUENCES{$cmd}) {
            $self->poderror({ -line => $line, -file => $file,
                 -severity => 'ERROR', 
                 -msg => qq(Unknown interior-sequence '$cmd')});
            # expand it anyway
            $text .= $self->_check_ptree($contents, $line, $file, "$nestlist$cmd");
            next;
        }
        if($nestlist =~ /$cmd/) {
            $self->poderror({ -line => $line, -file => $file,
                 -severity => 'ERROR', 
                 -msg => "nested commands $cmd<...$cmd<...>...>"});
            # _TODO_ should we add the contents anyway?
            # expand it anyway, see below
        }
        if($cmd eq 'E') {
            # preserve entities
            if(@$contents > 1 || ref $$contents[0] || $$contents[0] !~ /^\w+$/) {
                $self->poderror({ -line => $line, -file => $file,
                    -severity => 'ERROR', 
                    -msg => "garbled entity " . $_->raw_text()});
                next;
            }
            my $ent = $$contents[0];
            my $val;
            if($ent =~ /^0x[0-9a-f]+$/i) {
                # hexadec entity
                $val = hex($ent);
            }
            elsif($ent =~ /^0\d+$/) {
                # octal
                $val = oct($ent);
            }
            elsif($ent =~ /^\d+$/) {
                # numeric entity
                $val = $ent;
            }
            if(defined $val) {
                if($val>0 && $val<256) {
                    $text .= chr($val);
                }
                else {
                    $self->poderror({ -line => $line, -file => $file,
                        -severity => 'ERROR', 
                        -msg => "Entity number out of range " . $_->raw_text()});
                }
            }
            elsif($ENTITIES{$ent}) {
                # known ISO entity
                $text .= $ENTITIES{$ent};
            }
            else {
                $self->poderror({ -line => $line, -file => $file,
                    -severity => 'WARNING', 
                    -msg => "Unknown entity " . $_->raw_text()});
                $text .= "E<$ent>";
            }
        }
        elsif($cmd eq 'L') {
            # try to parse the hyperlink
            my $link = Pod::Hyperlink->new($contents->raw_text());
            unless(defined $link) {
                $self->poderror({ -line => $line, -file => $file,
                    -severity => 'ERROR', 
                    -msg => "malformed link " . $_->raw_text() ." : $@"});
                next;
            }
            $link->line($line); # remember line
            if($self->{-warnings}) {
                foreach my $w ($link->warning()) {
                    $self->poderror({ -line => $line, -file => $file,
                        -severity => 'WARNING', 
                        -msg => $w });
                }
            }
            # check the link text
            $text .= $self->_check_ptree($self->parse_text($link->text(),
                $line), $line, $file, "$nestlist$cmd");
            # remember link
            $self->hyperlink([$line,$link]);
        }
        elsif($cmd =~ /[BCFIS]/) {
            # add the guts
            $text .= $self->_check_ptree($contents, $line, $file, "$nestlist$cmd");
        }
        elsif($cmd eq 'Z') {
            if(length($contents->raw_text())) {
                $self->poderror({ -line => $line, -file => $file,
                    -severity => 'ERROR', 
                    -msg => "Nonempty Z<>"});
            }
        }
        elsif($cmd eq 'X') {
            my $idx = $self->_check_ptree($contents, $line, $file, "$nestlist$cmd");
            if($idx =~ /^\s*$/s) {
                $self->poderror({ -line => $line, -file => $file,
                    -severity => 'ERROR', 
                    -msg => "Empty X<>"});
            }
            else {
                # remember this node
                $self->idx($idx);
            }
        }
        else {
            # not reached
            die "internal error";
        }
    }
    $text;
}

# process a block of verbatim text
sub verbatim { 
    ## Nothing particular to check
    my ($self, $paragraph, $line_num, $pod_para) = @_;

    $self->_preproc_par($paragraph);

    if($self->{_current_head1} eq 'NAME') {
        my ($file, $line) = $pod_para->file_line;
        $self->poderror({ -line => $line, -file => $file,
            -severity => 'WARNING',
            -msg => 'Verbatim paragraph in NAME section' });
    }
}

# process a block of regular text
sub textblock { 
    my ($self, $paragraph, $line_num, $pod_para) = @_;
    my ($file, $line) = $pod_para->file_line;

    $self->_preproc_par($paragraph);

    # skip this paragraph if in a =begin block
    unless($self->{_have_begin}) {
        my $block = $self->interpolate_and_check($paragraph, $line,$file);
        if($self->{_current_head1} eq 'NAME') {
            if($block =~ /^\s*(\S+?)\s*[,-]/) {
                # this is the canonical name
                $self->{-name} = $1 unless(defined $self->{-name});
            }
        }
    }
}

sub _preproc_par
{
    my $self = shift;
    $_[0] =~ s/[\s\n]+$//;
    if($_[0]) {
        $self->{_commands_in_head}++;
        $self->{_list_item_contents}++ if(defined $self->{_list_item_contents});
        if(@{$self->{_list_stack}} && !$self->{_list_stack}->[0]->item()) {
            $self->{_list_stack}->[0]->{_has_par} = 1;
        }
    }
}

1;

__END__

