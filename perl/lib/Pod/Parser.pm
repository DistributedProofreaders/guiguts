#############################################################################
# Pod/Parser.pm -- package which defines a base class for parsing POD docs.
#
# Copyright (C) 1996-2000 by Bradford Appleton. All rights reserved.
# This file is part of "PodParser". PodParser is free software;
# you can redistribute it and/or modify it under the same terms
# as Perl itself.
#############################################################################

package Pod::Parser;

use vars qw($VERSION);
$VERSION = 1.14;  ## Current version of this package
require  5.005;    ## requires this Perl version or later

#############################################################################

#############################################################################

use vars qw(@ISA);
use strict;
#use diagnostics;
use Pod::InputObjects;
use Carp;
use Exporter;
BEGIN {
   if ($] < 5.6) {
      require Symbol;
      import Symbol;
   }
}
@ISA = qw(Exporter);

## These "variables" are used as local "glob aliases" for performance
use vars qw(%myData %myOpts @input_stack);

#############################################################################

##---------------------------------------------------------------------------

sub command {
    my ($self, $cmd, $text, $line_num, $pod_para)  = @_;
    ## Just treat this like a textblock
    $self->textblock($pod_para->raw_text(), $line_num, $pod_para);
}

##---------------------------------------------------------------------------

sub verbatim {
    my ($self, $text, $line_num, $pod_para) = @_;
    my $out_fh = $self->{_OUTPUT};
    print $out_fh $text;
}

##---------------------------------------------------------------------------

sub textblock {
    my ($self, $text, $line_num, $pod_para) = @_;
    my $out_fh = $self->{_OUTPUT};
    print $out_fh $self->interpolate($text, $line_num);
}

##---------------------------------------------------------------------------

sub interior_sequence {
    my ($self, $seq_cmd, $seq_arg, $pod_seq) = @_;
    ## Just return the raw text of the interior sequence
    return  $pod_seq->raw_text();
}

#############################################################################

##---------------------------------------------------------------------------

sub new {
    ## Determine if we were called via an object-ref or a classname
    my $this = shift;
    my $class = ref($this) || $this;
    ## Any remaining arguments are treated as initial values for the
    ## hash that is used to represent this object.
    my %params = @_;
    my $self = { %params };
    ## Bless ourselves into the desired class and perform any initialization
    bless $self, $class;
    $self->initialize();
    return $self;
}

##---------------------------------------------------------------------------

sub initialize {
    #my $self = shift;
    #return;
}

##---------------------------------------------------------------------------

sub begin_pod {
    #my $self = shift;
    #return;
}

##---------------------------------------------------------------------------

sub begin_input {
    #my $self = shift;
    #return;
}

##---------------------------------------------------------------------------

sub end_input {
    #my $self = shift;
    #return;
}

##---------------------------------------------------------------------------

sub end_pod {
    #my $self = shift;
    #return;
}

##---------------------------------------------------------------------------

sub preprocess_line {
    my ($self, $text, $line_num) = @_;
    return  $text;
}

##---------------------------------------------------------------------------

sub preprocess_paragraph {
    my ($self, $text, $line_num) = @_;
    return  $text;
}

#############################################################################

##---------------------------------------------------------------------------

sub parse_text {
    my $self = shift;
    local $_ = '';

    ## Get options and set any defaults
    my %opts = (ref $_[0]) ? %{ shift() } : ();
    my $expand_seq   = $opts{'-expand_seq'}   || undef;
    my $expand_text  = $opts{'-expand_text'}  || undef;
    my $expand_ptree = $opts{'-expand_ptree'} || undef;

    my $text = shift;
    my $line = shift;
    my $file = $self->input_file();
    my $cmd  = "";

    ## Convert method calls into closures, for our convenience
    my $xseq_sub   = $expand_seq;
    my $xtext_sub  = $expand_text;
    my $xptree_sub = $expand_ptree;
    if (defined $expand_seq  and  $expand_seq eq 'interior_sequence') {
        ## If 'interior_sequence' is the method to use, we have to pass
        ## more than just the sequence object, we also need to pass the
        ## sequence name and text.
        $xseq_sub = sub {
            my ($self, $iseq) = @_;
            my $args = join("", $iseq->parse_tree->children);
            return  $self->interior_sequence($iseq->name, $args, $iseq);
        };
    }
    ref $xseq_sub    or  $xseq_sub   = sub { shift()->$expand_seq(@_) };
    ref $xtext_sub   or  $xtext_sub  = sub { shift()->$expand_text(@_) };
    ref $xptree_sub  or  $xptree_sub = sub { shift()->$expand_ptree(@_) };

    ## Keep track of the "current" interior sequence, and maintain a stack
    ## of "in progress" sequences.
    ##
    ## NOTE that we push our own "accumulator" at the very beginning of the
    ## stack. It's really a parse-tree, not a sequence; but it implements
    ## the methods we need so we can use it to gather-up all the sequences
    ## and strings we parse. Thus, by the end of our parsing, it should be
    ## the only thing left on our stack and all we have to do is return it!
    ##
    my $seq       = Pod::ParseTree->new();
    my @seq_stack = ($seq);
    my ($ldelim, $rdelim) = ('', '');

    ## Iterate over all sequence starts text (NOTE: split with
    ## capturing parens keeps the delimiters)
    $_ = $text;
    my @tokens = split /([A-Z]<(?:<+\s)?)/;
    while ( @tokens ) {
        $_ = shift @tokens;
        ## Look for the beginning of a sequence
        if ( /^([A-Z])(<(?:<+\s)?)$/ ) {
            ## Push a new sequence onto the stack of those "in-progress"
            my $ldelim_orig;
            ($cmd, $ldelim_orig) = ($1, $2);
            ($ldelim = $ldelim_orig) =~ s/\s+$//;
            ($rdelim = $ldelim) =~ tr/</>/;
            $seq = Pod::InteriorSequence->new(
                       -name   => $cmd,
                       -ldelim => $ldelim_orig,  -rdelim => $rdelim,
                       -file   => $file,    -line   => $line
                   );
            (@seq_stack > 1)  and  $seq->nested($seq_stack[-1]);
            push @seq_stack, $seq;
        }
        ## Look for sequence ending
        elsif ( @seq_stack > 1 ) {
            ## Make sure we match the right kind of closing delimiter
            my ($seq_end, $post_seq) = ("", "");
            if ( ($ldelim eq '<'   and  /\A(.*?)(>)/s)
                 or  /\A(.*?)(\s+$rdelim)/s )
            {
                ## Found end-of-sequence, capture the interior and the
                ## closing the delimiter, and put the rest back on the
                ## token-list
                $post_seq = substr($_, length($1) + length($2));
                ($_, $seq_end) = ($1, $2);
                (length $post_seq)  and  unshift @tokens, $post_seq;
            }
            if (length) {
                ## In the middle of a sequence, append this text to it, and
                ## dont forget to "expand" it if that's what the caller wanted
                $seq->append($expand_text ? &$xtext_sub($self,$_,$seq) : $_);
                $_ .= $seq_end;
            }
            if (length $seq_end) {
                ## End of current sequence, record terminating delimiter
                $seq->rdelim($seq_end);
                ## Pop it off the stack of "in progress" sequences
                pop @seq_stack;
                ## Append result to its parent in current parse tree
                $seq_stack[-1]->append($expand_seq ? &$xseq_sub($self,$seq)
                                                   : $seq);
                ## Remember the current cmd-name and left-delimiter
                if(@seq_stack > 1) {
                    $cmd = $seq_stack[-1]->name;
                    $ldelim = $seq_stack[-1]->ldelim;
                    $rdelim = $seq_stack[-1]->rdelim;
                } else {
                    $cmd = $ldelim = $rdelim = '';
                }
            }
        }
        elsif (length) {
            ## In the middle of a sequence, append this text to it, and
            ## dont forget to "expand" it if that's what the caller wanted
            $seq->append($expand_text ? &$xtext_sub($self,$_,$seq) : $_);
        }
        ## Keep track of line count
        $line += tr/\n//;
        ## Remember the "current" sequence
        $seq = $seq_stack[-1];
    }

    ## Handle unterminated sequences
    my $errorsub = (@seq_stack > 1) ? $self->errorsub() : undef;
    while (@seq_stack > 1) {
       ($cmd, $file, $line) = ($seq->name, $seq->file_line);
       $ldelim  = $seq->ldelim;
       ($rdelim = $ldelim) =~ tr/</>/;
       $rdelim  =~ s/^(\S+)(\s*)$/$2$1/;
       pop @seq_stack;
       my $errmsg = "*** ERROR: unterminated ${cmd}${ldelim}...${rdelim}".
                    " at line $line in file $file\n";
       (ref $errorsub) and &{$errorsub}($errmsg)
           or (defined $errorsub) and $self->$errorsub($errmsg)
               or  warn($errmsg);
       $seq_stack[-1]->append($expand_seq ? &$xseq_sub($self,$seq) : $seq);
       $seq = $seq_stack[-1];
    }

    ## Return the resulting parse-tree
    my $ptree = (pop @seq_stack)->parse_tree;
    return  $expand_ptree ? &$xptree_sub($self, $ptree) : $ptree;
}

##---------------------------------------------------------------------------

sub interpolate {
    my($self, $text, $line_num) = @_;
    my %parse_opts = ( -expand_seq => 'interior_sequence' );
    my $ptree = $self->parse_text( \%parse_opts, $text, $line_num );
    return  join "", $ptree->children();
}

##---------------------------------------------------------------------------

sub parse_paragraph {
    my ($self, $text, $line_num) = @_;
    local *myData = $self;  ## alias to avoid deref-ing overhead
    local *myOpts = ($myData{_PARSEOPTS} ||= {});  ## get parse-options
    local $_;

    ## See if we want to preprocess nonPOD paragraphs as well as POD ones.
    my $wantNonPods = $myOpts{'-want_nonPODs'};

    ## Update cutting status
    $myData{_CUTTING} = 0 if $text =~ /^={1,2}\S/;

    ## Perform any desired preprocessing if we wanted it this early
    $wantNonPods  and  $text = $self->preprocess_paragraph($text, $line_num);

    ## Ignore up until next POD directive if we are cutting
    return if $myData{_CUTTING};

    ## Now we know this is block of text in a POD section!

    ##-----------------------------------------------------------------
    ## This is a hook (hack ;-) for Pod::Select to do its thing without
    ## having to override methods, but also without Pod::Parser assuming
    ## $self is an instance of Pod::Select (if the _SELECTED_SECTIONS
    ## field exists then we assume there is an is_selected() method for
    ## us to invoke (calling $self->can('is_selected') could verify this
    ## but that is more overhead than I want to incur)
    ##-----------------------------------------------------------------

    ## Ignore this block if it isnt in one of the selected sections
    if (exists $myData{_SELECTED_SECTIONS}) {
        $self->is_selected($text)  or  return ($myData{_CUTTING} = 1);
    }

    ## If we havent already, perform any desired preprocessing and
    ## then re-check the "cutting" state
    unless ($wantNonPods) {
       $text = $self->preprocess_paragraph($text, $line_num);
       return 1  unless ((defined $text) and (length $text));
       return 1  if ($myData{_CUTTING});
    }

    ## Look for one of the three types of paragraphs
    my ($pfx, $cmd, $arg, $sep) = ('', '', '', '');
    my $pod_para = undef;
    if ($text =~ /^(={1,2})(?=\S)/) {
        ## Looks like a command paragraph. Capture the command prefix used
        ## ("=" or "=="), as well as the command-name, its paragraph text,
        ## and whatever sequence of characters was used to separate them
        $pfx = $1;
        $_ = substr($text, length $pfx);
        ($cmd, $sep, $text) = split /(\s+)/, $_, 2; 
        ## If this is a "cut" directive then we dont need to do anything
        ## except return to "cutting" mode.
        if ($cmd eq 'cut') {
           $myData{_CUTTING} = 1;
           return  unless $myOpts{'-process_cut_cmd'};
        }
    }
    ## Save the attributes indicating how the command was specified.
    $pod_para = new Pod::Paragraph(
          -name      => $cmd,
          -text      => $text,
          -prefix    => $pfx,
          -separator => $sep,
          -file      => $myData{_INFILE},
          -line      => $line_num
    );
    # ## Invoke appropriate callbacks
    # if (exists $myData{_CALLBACKS}) {
    #    ## Look through the callback list, invoke callbacks,
    #    ## then see if we need to do the default actions
    #    ## (invoke_callbacks will return true if we do).
    #    return  1  unless $self->invoke_callbacks($cmd, $text, $line_num, $pod_para);
    # }
    if (length $cmd) {
        ## A command paragraph
        $self->command($cmd, $text, $line_num, $pod_para);
    }
    elsif ($text =~ /^\s+/) {
        ## Indented text - must be a verbatim paragraph
        $self->verbatim($text, $line_num, $pod_para);
    }
    else {
        ## Looks like an ordinary block of text
        $self->textblock($text, $line_num, $pod_para);
    }
    return  1;
}

##---------------------------------------------------------------------------

sub parse_from_filehandle {
    my $self = shift;
    my %opts = (ref $_[0] eq 'HASH') ? %{ shift() } : ();
    my ($in_fh, $out_fh) = @_;
    $in_fh = \*STDIN  unless ($in_fh);
    local *myData = $self;  ## alias to avoid deref-ing overhead
    local *myOpts = ($myData{_PARSEOPTS} ||= {});  ## get parse-options
    local $_;

    ## Put this stream at the top of the stack and do beginning-of-input
    ## processing. NOTE that $in_fh might be reset during this process.
    my $topstream = $self->_push_input_stream($in_fh, $out_fh);
    (exists $opts{-cutting})  and  $self->cutting( $opts{-cutting} );

    ## Initialize line/paragraph
    my ($textline, $paragraph) = ('', '');
    my ($nlines, $plines) = (0, 0);

    ## Use <$fh> instead of $fh->getline where possible (for speed)
    $_ = ref $in_fh;
    my $tied_fh = (/^(?:GLOB|FileHandle|IO::\w+)$/  or  tied $in_fh);

    ## Read paragraphs line-by-line
    while (defined ($textline = $tied_fh ? <$in_fh> : $in_fh->getline)) {
        $textline = $self->preprocess_line($textline, ++$nlines);
        next  unless ((defined $textline)  &&  (length $textline));
        $_ = $paragraph;  ## save previous contents

        if ((! length $paragraph) && ($textline =~ /^==/)) {
            ## '==' denotes a one-line command paragraph
            $paragraph = $textline;
            $plines    = 1;
            $textline  = '';
        } else {
            ## Append this line to the current paragraph
            $paragraph .= $textline;
            ++$plines;
        }

        ## See if this line is blank and ends the current paragraph.
        ## If it isnt, then keep iterating until it is.
        next unless (($textline =~ /^([^\S\r\n]*)[\r\n]*$/)
                                     && (length $paragraph));

        ## Issue a warning about any non-empty blank lines
        if (length($1) > 0 and $myOpts{'-warnings'} and ! $myData{_CUTTING}) {
            my $errorsub = $self->errorsub();
            my $file = $self->input_file();
            my $errmsg = "*** WARNING: line containing nothing but whitespace".
                         " in paragraph at line $nlines in file $file\n";
            (ref $errorsub) and &{$errorsub}($errmsg)
                or (defined $errorsub) and $self->$errorsub($errmsg)
                    or  warn($errmsg);
        }

        ## Now process the paragraph
        parse_paragraph($self, $paragraph, ($nlines - $plines) + 1);
        $paragraph = '';
        $plines = 0;
    }
    ## Dont forget about the last paragraph in the file
    if (length $paragraph) {
       parse_paragraph($self, $paragraph, ($nlines - $plines) + 1)
    }

    ## Now pop the input stream off the top of the input stack.
    $self->_pop_input_stream();
}

##---------------------------------------------------------------------------

sub parse_from_file {
    my $self = shift;
    my %opts = (ref $_[0] eq 'HASH') ? %{ shift() } : ();
    my ($infile, $outfile) = @_;
    my ($in_fh,  $out_fh) = (gensym, gensym)  if ($] < 5.6);
    my ($close_input, $close_output) = (0, 0);
    local *myData = $self;
    local $_;

    ## Is $infile a filename or a (possibly implied) filehandle
    $infile  = '-'  unless ((defined $infile)  && (length $infile));
    if (($infile  eq '-') || ($infile =~ /^<&(STDIN|0)$/i)) {
        ## Not a filename, just a string implying STDIN
        $myData{_INFILE} = "<standard input>";
        $in_fh = \*STDIN;
    }
    elsif (ref $infile) {
        ## Must be a filehandle-ref (or else assume its a ref to an object
        ## that supports the common IO read operations).
        $myData{_INFILE} = ${$infile};
        $in_fh = $infile;
    }
    else {
        ## We have a filename, open it for reading
        $myData{_INFILE} = $infile;
        open($in_fh, "< $infile")  or
             croak "Can't open $infile for reading: $!\n";
        $close_input = 1;
    }

    ## NOTE: we need to be *very* careful when "defaulting" the output
    ## file. We only want to use a default if this is the beginning of
    ## the entire document (but *not* if this is an included file). We
    ## determine this by seeing if the input stream stack has been set-up
    ## already
    ## 
    unless ((defined $outfile) && (length $outfile)) {
        (defined $myData{_TOP_STREAM}) && ($out_fh  = $myData{_OUTPUT})
                                       || ($outfile = '-');
    }
    ## Is $outfile a filename or a (possibly implied) filehandle
    if ((defined $outfile) && (length $outfile)) {
        if (($outfile  eq '-') || ($outfile =~ /^>&?(?:STDOUT|1)$/i)) {
            ## Not a filename, just a string implying STDOUT
            $myData{_OUTFILE} = "<standard output>";
            $out_fh  = \*STDOUT;
        }
        elsif ($outfile =~ /^>&(STDERR|2)$/i) {
            ## Not a filename, just a string implying STDERR
            $myData{_OUTFILE} = "<standard error>";
            $out_fh  = \*STDERR;
        }
        elsif (ref $outfile) {
            ## Must be a filehandle-ref (or else assume its a ref to an
            ## object that supports the common IO write operations).
            $myData{_OUTFILE} = ${$outfile};
            $out_fh = $outfile;
        }
        else {
            ## We have a filename, open it for writing
            $myData{_OUTFILE} = $outfile;
            (-d $outfile) and croak "$outfile is a directory, not POD input!\n";
            open($out_fh, "> $outfile")  or
                 croak "Can't open $outfile for writing: $!\n";
            $close_output = 1;
        }
    }

    ## Whew! That was a lot of work to set up reasonably/robust behavior
    ## in the case of a non-filename for reading and writing. Now we just
    ## have to parse the input and close the handles when we're finished.
    $self->parse_from_filehandle(\%opts, $in_fh, $out_fh);

    $close_input  and 
        close($in_fh) || croak "Can't close $infile after reading: $!\n";
    $close_output  and
        close($out_fh) || croak "Can't close $outfile after writing: $!\n";
}

#############################################################################

##---------------------------------------------------------------------------

sub errorsub {
   return (@_ > 1) ? ($_[0]->{_ERRORSUB} = $_[1]) : $_[0]->{_ERRORSUB};
}

##---------------------------------------------------------------------------

sub cutting {
   return (@_ > 1) ? ($_[0]->{_CUTTING} = $_[1]) : $_[0]->{_CUTTING};
}

##---------------------------------------------------------------------------

##---------------------------------------------------------------------------

sub parseopts {
   local *myData = shift;
   local *myOpts = ($myData{_PARSEOPTS} ||= {});
   return %myOpts  if (@_ == 0);
   if (@_ == 1) {
      local $_ = shift;
      return  ref($_)  ?  $myData{_PARSEOPTS} = $_  :  $myOpts{$_};
   }
   my @newOpts = (%myOpts, @_);
   $myData{_PARSEOPTS} = { @newOpts };
}

##---------------------------------------------------------------------------

sub output_file {
   return $_[0]->{_OUTFILE};
}

##---------------------------------------------------------------------------

sub output_handle {
   return $_[0]->{_OUTPUT};
}

##---------------------------------------------------------------------------

sub input_file {
   return $_[0]->{_INFILE};
}

##---------------------------------------------------------------------------

sub input_handle {
   return $_[0]->{_INPUT};
}

##---------------------------------------------------------------------------

sub input_streams {
   return $_[0]->{_INPUT_STREAMS};
}

##---------------------------------------------------------------------------

sub top_stream {
   return $_[0]->{_TOP_STREAM} || undef;
}

#############################################################################

##---------------------------------------------------------------------------

sub _push_input_stream {
    my ($self, $in_fh, $out_fh) = @_;
    local *myData = $self;

    ## Initialize stuff for the entire document if this is *not*
    ## an included file.
    ##
    ## NOTE: we need to be *very* careful when "defaulting" the output
    ## filehandle. We only want to use a default value if this is the
    ## beginning of the entire document (but *not* if this is an included
    ## file).
    unless (defined  $myData{_TOP_STREAM}) {
        $out_fh  = \*STDOUT  unless (defined $out_fh);
        $myData{_CUTTING}       = 1;   ## current "cutting" state
        $myData{_INPUT_STREAMS} = [];  ## stack of all input streams
    }

    ## Initialize input indicators
    $myData{_OUTFILE} = '(unknown)'  unless (defined  $myData{_OUTFILE});
    $myData{_OUTPUT}  = $out_fh      if (defined  $out_fh);
    $in_fh            = \*STDIN      unless (defined  $in_fh);
    $myData{_INFILE}  = '(unknown)'  unless (defined  $myData{_INFILE});
    $myData{_INPUT}   = $in_fh;
    my $input_top     = $myData{_TOP_STREAM}
                      = new Pod::InputSource(
                            -name        => $myData{_INFILE},
                            -handle      => $in_fh,
                            -was_cutting => $myData{_CUTTING}
                        );
    local *input_stack = $myData{_INPUT_STREAMS};
    push(@input_stack, $input_top);

    ## Perform beginning-of-document and/or beginning-of-input processing
    $self->begin_pod()  if (@input_stack == 1);
    $self->begin_input();

    return  $input_top;
}

##---------------------------------------------------------------------------

sub _pop_input_stream {
    my ($self) = @_;
    local *myData = $self;
    local *input_stack = $myData{_INPUT_STREAMS};

    ## Perform end-of-input and/or end-of-document processing
    $self->end_input()  if (@input_stack > 0);
    $self->end_pod()    if (@input_stack == 1);

    ## Restore cutting state to whatever it was before we started
    ## parsing this file.
    my $old_top = pop(@input_stack);
    $myData{_CUTTING} = $old_top->was_cutting();

    ## Dont forget to reset the input indicators
    my $input_top = undef;
    if (@input_stack > 0) {
       $input_top = $myData{_TOP_STREAM} = $input_stack[-1];
       $myData{_INFILE}  = $input_top->name();
       $myData{_INPUT}   = $input_top->handle();
    } else {
       delete $myData{_TOP_STREAM};
       delete $myData{_INPUT_STREAMS};
    }

    return  $input_top;
}

#############################################################################

1;
