package Guiguts::SelectionMenu;
use strict;
use warnings;

BEGIN {
    use Exporter();
    our ( @ISA, @EXPORT );
    @ISA    = qw(Exporter);
    @EXPORT = qw(&case &surround &surroundit &flood &floodfill &indent
      &selectrewrap &wrapper &alignpopup &asciibox_popup &blockrewrap &rcaligntext &tocalignselection);
}

my $blockwraptypes = quotemeta '#iI';    # Blockquotes & index allow user to specify left/first/right margins

# "Delete" character is inserted to flag mark positions during wrapping
my $TEMPPAGEMARK = "\x7f";

sub wrapper {
    my ( $leftmargin, $firstmargin, $rightmargin, $paragraph, $rwhyphenspace ) = @_;
    return $paragraph
      if ( $paragraph =~
        m|^$TEMPPAGEMARK*[$::allblocktypes]$TEMPPAGEMARK*/$TEMPPAGEMARK*\n$TEMPPAGEMARK*$|
        || $paragraph =~
        m|^$TEMPPAGEMARK*/$TEMPPAGEMARK*[$::allblocktypes]$TEMPPAGEMARK*\n$TEMPPAGEMARK*$|
        || $paragraph =~ m|^$TEMPPAGEMARK*$| );
    return knuth_wrapper( $leftmargin, $firstmargin, $rightmargin, $paragraph, $rwhyphenspace );
}

sub knuth_wrapper {
    my ( $leftmargin, $firstmargin, $rightmargin, $paragraph, $rwhyphenspace ) = @_;
    my ( $pre, $post ) = ( '', '' );
    my $NBSP     = "\x{a0}";      # Non-breaking space
    my $TEMPNBSP = "\x{E123}";    # Private Use Area character won't appear in our books

    # if open rewrap markup, remove, then prepend once rewrapped
    if ( $paragraph =~
        s|^($TEMPPAGEMARK*/$TEMPPAGEMARK*[$blockwraptypes]$TEMPPAGEMARK*\[$TEMPPAGEMARK*[0-9.,$TEMPPAGEMARK*]+$TEMPPAGEMARK*\]$TEMPPAGEMARK*)||
    ) {
        $pre = "$1\n";
    } elsif ( $paragraph =~ s|^($TEMPPAGEMARK*/$TEMPPAGEMARK*[$blockwraptypes]$TEMPPAGEMARK*)|| ) {
        $pre = "$1\n";
    }

    # if close rewrap markup, remove (including any newline), then append once rewrapped
    # (note that look-behind group is not captured, so $1 refers to large capturing group)
    if ( $paragraph =~
        s|(?<=\n)($TEMPPAGEMARK*[$blockwraptypes]$TEMPPAGEMARK*/$TEMPPAGEMARK*)(\n?)$|| ) {
        $post = "$1$2";
    }
    my $maxwidth = $rightmargin;
    my $optwidth = $rightmargin - $::rmargindiff;
    $paragraph =~ s/-\n/-/g unless $rwhyphenspace;
    $paragraph =~ s/\n/ /g;
    $paragraph =~ s/$NBSP/$TEMPNBSP/g;               # use temp character for non-breaking space so reflow doesn't break there
    my $reflowed = ::reflow_string(
        $paragraph,
        maximum       => $maxwidth,
        optimum       => $optwidth,
        indent1       => ' ' x $firstmargin,
        indent2       => ' ' x $leftmargin,
        frenchspacing => 'y',
        semantic      => 0,
        namebreak     => 0,
        sentence      => 0,
        independent   => 0,
        dependent     => 0,
        shortlast     => 0,
        connpenalty   => 0,
    );
    $reflowed =~ s/ *$//;
    $reflowed =~ s/$TEMPNBSP/$NBSP/g;    # restore non-breaking spaces
    return $pre . $reflowed . $post;
}

#
# Rewraps an index, assuming DP formatting, i.e.
# |
# |/i[8.2.72] (optional wrap margins similar to block margins)
# |A main entry, 12, 23, ... all on one line
# |  subentry indented by 2, 45, 56, ...
# |
# |Next main entry after blank line, 78, 89 ...
# etc.
#
# First line of each entry or subentry will be indented by $firstmargin plus amount already
# indented by user to signify sublevel
# Continuation lines will all be indented to $leftmargin - user's responsibility to ensure this
# is big enough to avoid confusion on index with deep sublevels
#
sub indexwrapper {
    my ( $leftmargin, $firstmargin, $rightmargin, $paragraph, $rwhyphenspace ) = @_;

    # Split paragraph (entry plus subentries) into lines (single entry or subentry)
    my @lines = split( /\n/, $paragraph );

    # Rewrap each line (entry) independently and append to a single string to return.
    my $rewrapped = '';
    for my $line (@lines) {
        my $notpmline = removetpms($line);

        # if start and end of markup - just preserve - don't indent
        if ( $notpmline =~ /^([Ii]\/|\/[Ii])$/ ) {
            $rewrapped .= $line . "\n";
            next;
        }

        # see how far user has indented line to signify depth of sublevel
        $line =~ /^( *)/;
        my $firstindent = $firstmargin + length($1);

        # Wrap entry and append to string
        $line = wrapper( $leftmargin, $firstindent, $rightmargin, $line, $rwhyphenspace );
        $rewrapped .= $line;
    }
    return $rewrapped;
}

# Wrap a center block marked with /c...c/
# Center align each line between the left and right margins
# Copes with /c nested inside /#
sub centerblockwrapper {
    my ( $leftmargin, $rightmargin, $paragraph ) = @_;

    my @lines = split( /\n/, $paragraph );    # Split paragraph into lines

    # Center each line independently and append to a single string to return.
    my $rewrapped = '';
    my $done      = 0;                        # Used to stop indenting when closing c/ is spotted
    for my $line (@lines) {
        my $notpmline = removetpms($line);
        $done = 1 if $notpmline =~ /^[Cc]\/$/;

        # if done, or start and end of markup - just preserve - don't indent
        if ( $done or $notpmline =~ /^(\/[#Cc]|[#Cc]\/)$/ ) {
            $rewrapped .= $line;
            $rewrapped .= "\n" unless $notpmline =~ /^#\/$/;    # No extra newline for closing blockquote markup
        } else {
            $line      =~ s/^\s*//;                                            # Remove any existing indentation
            $notpmline =~ s/^\s*//;
            my $len = length($notpmline);                                      # Don't count temp page markers in line length
            $len = ( $rightmargin - $leftmargin - $len ) / 2 + $leftmargin;    # Indentation required for centering
            $len = 0 if $len < 0;
            $rewrapped .= ' ' x $len . $line;
            $rewrapped .= "\n" unless $notpmline =~ /^$/;
        }
    }
    return $rewrapped;
}

# Wrap a right block marked with /r...r/
# Right align the block, retaining relative indentation, i.e. longest line will touch right margin
# Copes with /r nested inside /#
sub rightblockwrapper {
    my ( $rightmargin, $paragraph ) = @_;

    my @lines = split( /\n/, $paragraph );    # Split paragraph into lines

    # Find number of spaces needed to move longest line to right margin
    my $minspc = 1000;
    for my $line (@lines) {
        my $notpmline = removetpms($line);
        my $spc       = $rightmargin - length($notpmline);    # Don't count temp page markers in line length
        $spc    = 0    if $spc < 0;
        $minspc = $spc if $spc < $minspc;
    }

    # Indent all lines by this amount, and append to a single string to return.
    my $rewrapped = '';
    my $done      = 0;    # Used to stop indenting when closing r/ is spotted
    for my $line (@lines) {
        my $notpmline = removetpms($line);
        $done = 1 if $notpmline =~ /^[Rr]\/$/;

        # if done, or start and end of markup - just preserve - don't indent
        if ( $done or $notpmline =~ /^(\/[#Rr]|[#Rr]\/)$/ ) {
            $rewrapped .= $line;
            $rewrapped .= "\n" unless $notpmline =~ /^#\/$/;    # No extra newline for closing blockquote markup
        } else {
            $rewrapped .= ' ' x $minspc . $line;
            $rewrapped .= "\n" unless $notpmline =~ /^$/;
        }
    }
    return $rewrapped;
}

#
# Rewrap selected text
# Global variable $::blockwrap is zero for normal text, -1 within Index markup,
# or a positive number indicating the depth of nested blockquotes
sub selectrewrap {
    my $silentmode = shift;
    my $textwindow = $::textwindow;
    my @ranges     = $textwindow->tagRanges('sel');
    return if @ranges == 0;    # Nothing selected

    my $thisblockstart;
    my $start;
    my $scannosave = $::scannos_highlighted;
    $::scannos_highlighted = 0;

    unless ($silentmode) {
        ::hidelinenumbers();    # To speed updating of text window
        ::hidepagenums();
        ::savesettings();
    }
    $textwindow->addGlobStart;
    my $end = pop(@ranges);                                     #get the end index of the selection
    $start = pop(@ranges);                                      #get the start index of the selection
    my @marklist = $textwindow->dump( -mark, $start, $end );    #see if there any page markers set
    my ( $markname, @savelist, $markindex );
    while (@marklist) {                                         #save the pagemarkers if they have been set
        shift @marklist;
        $markname  = shift @marklist;
        $markindex = shift @marklist;
        if ( $markname =~ /Pg\S+/ ) {
            $textwindow->insert( $markindex, $TEMPPAGEMARK );    #mark the page breaks for rewrapping
            push @savelist, $markname;
        }
    }

    # If the selection starts on a blank(ish) line, advance the selection start until it isn't.
    while ( $textwindow->get( $start, "$start lineend" ) =~ /^[\s\n$TEMPPAGEMARK]*$/ ) {
        $start = $textwindow->index("$start+1l linestart");
    }

    # If the selection ends at the end of a line but not over it advance the selection end until it does.
    # Traps odd spaces at paragraph end bug
    while ( $textwindow->get( "$end+1c", "$end+1c lineend" ) =~ /^[\s\n$TEMPPAGEMARK]*$/ ) {
        $end = $textwindow->index("$end+1c");
        last if $textwindow->compare( $end, '>=', 'end' );
    }
    $thisblockstart = $start;
    my $thisblockend   = $end;
    my $indentblockend = $end;
    my $inblock        = 0;
    my $blockcenter    = 0;
    my $blockright     = 0;
    my $infront        = 0;
    my $enableindent;
    my $fblock      = 0;
    my $leftmargin  = $::blocklmargin;
    my $rightmargin = $::blockrmargin;
    my $firstmargin = $::blocklmargin;
    my ( $rewrapped, $initial_tab, $subsequent_tab, $spaces );
    my $indent = 0;
    my $offset = 0;
    my $poem   = 0;
    my $textline;
    my $lastend = $start;
    my ( $sr, $sc, $er, $ec, $line );
    my $textend      = $textwindow->index('end');
    my $toplineblank = 0;
    my $selection;

    if ( $textend eq $end ) {
        $textwindow->tagAdd( 'blockend', "$end-1c" )    #set a marker at the end of the selection, or one charecter less
    } else {    #if the selection ends at the text end
        $textwindow->tagAdd( 'blockend', $end );
    }
    if ( $textwindow->get( '1.0', '1.end' ) eq '' ) {    #trap top line delete bug
        $toplineblank = 1;
    }
    ::enable_interrupt() unless $silentmode;
    $spaces      = 0;
    $::blockwrap = 0 unless $::blockwrap;

    # main while loop
    while (1) {
        $indent = $::defaultindent;
        $thisblockend =
          $textwindow->search( '-regex', '--',
            "(^$TEMPPAGEMARK*\$|^$TEMPPAGEMARK*[$blockwraptypes]$TEMPPAGEMARK*/$TEMPPAGEMARK*\$)",
            $thisblockstart, $end );    # find end of paragraph or end of markup
                                        # if two start rewrap block markers aren't separated by a blank line, just let it become added
        $thisblockend = $thisblockstart
          if ( $textwindow->get( "$thisblockstart +1l", "$thisblockstart +1l+2c" ) =~
            /^\/[$::allblocktypes]$/ );

        if ($thisblockend) {
            $thisblockend = $textwindow->index( $thisblockend . ' lineend' );
        } else {
            $thisblockend = $end;
        }
        ;                               #or end of text if end of selection
        $selection = $textwindow->get( $thisblockstart, $thisblockend )
          if $thisblockend;             #get the paragraph of text
        unless ($selection) {
            $thisblockstart = $thisblockend;
            $thisblockstart = $textwindow->index("$thisblockstart+1c");
            last if $textwindow->compare( $thisblockstart, '>=', $end );
            last if ::query_interrupt();
            next;
        }
        last
          if ( ( $thisblockend eq $lastend )
            || ( $textwindow->compare( $thisblockend, '<', $lastend ) ) );    # finish if the search isn't advancing

        # To simplify all the comparisons for various blocktypes below, make a copy of the selection
        # but with the temporary page markers removed.
        # Only use this for the comparions; use the original for the actual rewrapping process.
        my $notpmselection = removetpms($selection);

        # Check for block types that support blockwrap
        if ( $notpmselection =~ /^\/[$blockwraptypes]/ ) {
            if ( $notpmselection =~ /^\/\#/ ) {    # blockquote
                $::blockwrap++;                    # increment blockquote level
                ( $leftmargin, $firstmargin, $rightmargin ) = setblockmargins($::blockwrap);
            } elsif ( $notpmselection =~ /^\/[iI]/ ) {    # index
                $leftmargin  = 8;                         # All continuation lines aligned here
                $firstmargin = 2;                         # All first lines indented by existing indent, plus this figure
                $rightmargin = 72;                        # Right hand limit
                $::blockwrap = -1;
            }

            # Check if there are any parameters following blockwrap markup [n...
            if ( $notpmselection =~ /^\/[$blockwraptypes]\[(\d+)/ ) {    #check for block rewrapping with parameter markup
                $leftmargin  = $1;
                $firstmargin = $leftmargin;
            }

            # [n.n...
            if ( $notpmselection =~ /^\/[$blockwraptypes]\[(\d+)?(\.)(\d+)/ ) {
                $firstmargin = $3;
            }

            # [n.n,n...
            if ( $notpmselection =~ /^\/[$blockwraptypes]\[(\d+)?(\.)?(\d+)?,(\d+)/ ) {
                $rightmargin = $4;
            }
        }

        # if selection is /*, /L, or /l
        if ( $notpmselection =~ /^\/[\*Ll]/ ) {
            $inblock      = 1;
            $enableindent = 1;
        }    #check for no rewrap markup
             # if there are any parameters /*[n
        if ( $notpmselection =~ /^\/\*\[(\d+)/ ) { $indent = $1 }

        # if selection begins /p or /P
        if ( $notpmselection =~ /^\/[pP]/ ) {
            $inblock      = 1;
            $enableindent = 1;
            $poem         = 1;
            $indent       = $::poetrylmargin;
        }

        # starting a block if selection begins /x /f /$ /c or /r
        $inblock     = 1 if $notpmselection =~ /^\/[XxFf\$CcRr]/;
        $blockcenter = 1 if $notpmselection =~ /^\/[cC]/;
        $blockright  = 1 if $notpmselection =~ /^\/[rR]/;

        $textwindow->markSet( 'rewrapend', $thisblockend );    # Set a mark at the end of the text so it can be found after rewrap
        unless ( $notpmselection =~ /^\s*?(\*\s*){4}\*/ ) {    # skip rewrap if paragraph is a thought break
            if ( $inblock and not( $blockcenter or $blockright ) ) {
                if ($enableindent) {

                    # In order to support poetry, etc., within blockquotes,
                    # special handling for [pP\*Ll] types here means that if immediately followed
                    # by closing of blockquote markup, the close blockquote will be handled next time round
                    # the loop. See comment "Special handling for [pP\*Ll] types" below.
                    $indentblockend =
                      $textwindow->search( '-regex', '--',
                        "^$TEMPPAGEMARK*[pP\*Ll]$TEMPPAGEMARK*\/",
                        $thisblockstart, $end );
                    $indentblockend = $indentblockend || $end;
                    $textwindow->markSet( 'rewrapend', $indentblockend );
                    unless ($offset) { $offset = 0 }
                    ( $sr, $sc ) = split /\./, $thisblockstart;
                    ( $er, $ec ) = split /\./, $indentblockend;
                    unless ($offset) {
                        $offset = 100;
                        for my $line ( $sr + 1 .. $er - 1 ) {
                            $textline = $textwindow->get( "$line.0", "$line.end" );
                            if ($textline) {
                                $textwindow->search(
                                    '-regexp',
                                    '-count' => \$spaces,
                                    '--', '^\s+', "$line.0", "$line.end"
                                );
                                unless ($spaces) { $spaces = 0 }
                                if     ( $spaces < $offset ) {
                                    $offset = $spaces;
                                }
                                $spaces = 0;
                            }
                        }
                        $indent = $indent - $offset;
                    }
                    for my $line ( $sr .. $er - 1 ) {
                        $textline = $textwindow->get( "$line.0", "$line.end" );
                        my $notpmtextline = removetpms($textline);
                        next
                          if ( ( $textline =~ /^\/[pP\*Ll]/ )
                            || ( $textline =~ /^[pP\*LlFf]\// ) );
                        if ( $enableindent and $fblock == 0 ) {
                            $textwindow->insert( "$line.0", ( ' ' x $indent ) )
                              if ( $indent > 0 );
                            if ( $indent < 0 ) {
                                if ( $textwindow->get( "$line.0", "$line.@{[abs $indent]}" ) =~
                                    /\S/ ) {
                                    while ( $textwindow->get("$line.0") eq ' ' ) {
                                        $textwindow->delete("$line.0");
                                    }
                                } else {
                                    $textwindow->delete( "$line.0", "$line.@{[abs $indent]}" );
                                }
                            }
                        }
                    }
                    $indent       = 0;
                    $offset       = 0;
                    $enableindent = 0;
                    $poem         = 0;
                    $inblock      = 0;
                }
            } else {
                my $skipit = ( $selection =~ /^(\/#|#\/)$/ );    # Happens when /c or /r directly follows /# or blank line before #/
                if ( $::blockwrap > 0 ) {                        # block wrap
                    if ($blockcenter) {
                        $rewrapped = centerblockwrapper( $leftmargin, $rightmargin, $selection );
                    } elsif ($blockright) {
                        $rewrapped = rightblockwrapper( $rightmargin, $selection );
                    } else {
                        $rewrapped = wrapper(
                            $leftmargin, $firstmargin, $rightmargin,
                            $selection,  $::rwhyphenspace
                        );
                    }
                } elsif ( $::blockwrap == -1 ) {                 # index wrap
                    $rewrapped = indexwrapper( $leftmargin, $firstmargin, $rightmargin,
                        $selection, $::rwhyphenspace );
                } else {                                         #rewrap the paragraph
                    if ($blockcenter) {
                        $rewrapped = centerblockwrapper( $::lmargin, $::rmargin, $selection );
                    } elsif ($blockright) {
                        $rewrapped = rightblockwrapper( $::rmargin, $selection );
                    } else {
                        $rewrapped =
                          wrapper( $::lmargin, $::lmargin, $::rmargin, $selection,
                            $::rwhyphenspace );
                    }
                }
                unless ($skipit) {
                    $textwindow->delete( $thisblockstart, $thisblockend );    #delete the original paragraph
                    $textwindow->insert( $thisblockstart, $rewrapped );       #insert the rewrapped paragraph
                }
                my @endtemp = $textwindow->tagRanges('blockend');             #find the end of the rewrapped text
                $end = shift @endtemp;
            }
        }
        if ( $notpmselection =~ /^[XxFf\$CcRr]\//m ) {
            $inblock      = 0;
            $indent       = 0;
            $offset       = 0;
            $enableindent = 0;
            $poem         = 0;
            $blockcenter  = 0;
            $blockright   = 0;
        }
        if ( $notpmselection =~ /^[$blockwraptypes]\/$/m ) {

            # blockquote
            if ( $notpmselection =~ /^\#\/$/m ) {

                # In order to support poetry, etc., within blockquotes,
                # if [pP\*Ll] markup is closed immediately preceding close of blockquote,
                # special treatment earlier means the close blockquote will be selected next time round loop
                # so don't decrement the level now, or it will be done twice.
                # See comment "Special handling for [pP\*Ll] types" above.
                unless ( $notpmselection =~ /[pP\*Ll]\/\n\#\// ) {
                    if ( $::blockwrap > 0 ) {
                        $::blockwrap--;    # decrement blockquote level
                        ( $leftmargin, $firstmargin, $rightmargin ) = setblockmargins($::blockwrap);
                    } else {
                        ::warnerror("Close blockquote (#/) found with no matching open markup");
                    }
                }
            } else {
                $::blockwrap = 0;
            }
        }
        last unless $end;
        $thisblockstart = $textwindow->index('rewrapend');             #advance to the next paragraph
        $lastend        = $textwindow->index("$thisblockstart+1c");    #track where the end of the last paragraph was

        # if there are blank lines before the next paragraph, advance past them
        while (1) {
            $thisblockstart = $textwindow->index("$thisblockstart+1l linestart");
            last if $textwindow->compare( $thisblockstart, '>=', 'end' );
            next if $textwindow->get( $thisblockstart, "$thisblockstart lineend" ) eq '';
            last;
        }

        # reset blockwrap and quit if interrupted
        if ( ::query_interrupt() ) {
            $::blockwrap = 0;
            last;
        }
        last if $thisblockstart eq $end;    # finish if next paragraph starts at end of selection

        $textwindow->update unless $silentmode or ::updatedrecently();    # Too slow if update window after every paragraph
    }
    unless ($silentmode) {
        ::disable_interrupt();
        $textwindow->Busy( -recurse => 1 );
    }

    #if there are saved page markers, remove the temporary markers and reinsert the saved ones
    while (@savelist) {
        $markname  = shift @savelist;
        $markindex = $textwindow->search( '-regex', '--', $TEMPPAGEMARK, '1.0', 'end' );
        $textwindow->delete($markindex);
        $textwindow->markSet( $markname, $markindex );
        $textwindow->markGravity( $markname, 'left' );
    }

    # reinsert deleted top line if it was removed
    $textwindow->insert( '1.0', "\n" ) if $start eq '1.0' and $toplineblank == 1;

    $textwindow->tagRemove( 'blockend', '1.0', 'end' );

    # If any line consists solely of whitespace, empty it
    $textwindow->delete( $thisblockstart, "$thisblockstart lineend" )
      while $thisblockstart = $textwindow->search( '-regexp', '--', '^\s+$', '1.0', 'end' );

    $textwindow->addGlobEnd;
    unless ($silentmode) {
        $textwindow->focus;
        $textwindow->update;
        $textwindow->see($start);
        $textwindow->Unbusy;
        ::restorelinenumbers();
    }
    $::blockwrap = 0;    # In case of markup error, don't want to leave blockwrap variable set
}

#
# Create a copy of a paragraph without temporary pagemarker characters for ease of
# regex comparisons. Page markers can otherwise optionally appear anywhere in
# "/#[4.8,24]" which means the regex to match gets very long and unreadable.
# Note: do not use this copy for wrapping, just comparing
sub removetpms {
    my $notpm = shift;
    $notpm =~ s/$TEMPPAGEMARK//g;
    return $notpm;
}

#
# Set the margins for block wrapping based on depth of nested blocks
# For each level, indent left margin by difference between standard and block margin
# Don't indent right margin extra or text width becomes too narrow
sub setblockmargins {
    my $blockdepth  = shift;
    my $leftmargin  = $::lmargin + $blockdepth * ( $::blocklmargin - $::lmargin );
    my $firstmargin = $leftmargin;
    my $rightmargin = $::rmargin - $blockdepth * ( $::rmargin - $::blockrmargin );
    return ( $leftmargin, $firstmargin, $rightmargin );
}

sub aligntext {
    my ( $textwindow, $alignstring ) = @_;
    my @ranges      = $textwindow->tagRanges('sel');
    my $range_total = @ranges;
    if ( $range_total == 0 ) {
        return;
    } else {
        my $textindex = 0;
        my ( $linenum, $line, $sr, $sc, $er, $ec, $r, $c, @indexpos );
        my $end   = pop(@ranges);
        my $start = pop(@ranges);
        $textwindow->addGlobStart;
        ( $sr, $sc ) = split /\./, $start;
        ( $er, $ec ) = split /\./, $end;
        for my $linenum ( $sr .. $er - 1 ) {
            $indexpos[$linenum] =
              $textwindow->search( '--', $alignstring, "$linenum.0 -1c", "$linenum.end" );
            if ( $indexpos[$linenum] ) {
                ( $r, $c ) = split /\./, $indexpos[$linenum];
            } else {
                $c = -1;
            }
            if ( $c > $textindex ) { $textindex = $c }
            $indexpos[$linenum] = $c;
        }
        for my $linenum ( $sr .. $er ) {
            $indexpos[$linenum] = 0 unless defined $indexpos[$linenum];
            if ( $indexpos[$linenum] > (-1) ) {
                $textwindow->insert( "$linenum.0", ( ' ' x ( $textindex - $indexpos[$linenum] ) ) );
            }
        }
        $textwindow->addGlobEnd;
    }
}

# Draws an ascii box around selected lines of text, with at least one space between
# box and text (unless lines are too long, when no space is added)
# Text is wrapped before boxing unless $asciinowrap is true
# $asciiwidth is width of box, including box lines
# $ascii array contains box characters to use for tl,top,tr,l,unused,r,bl,bot,br
# Text can be left, right or center justified based on $asciijustify
sub asciibox {
    my ( $textwindow, $asciinowrap, $asciiwidth, $ascii, $asciijustify ) = @_;

    my @ranges      = $textwindow->tagRanges('sel');
    my $range_total = @ranges;
    return if $range_total == 0 or $asciiwidth < 5;

    $textwindow->addGlobStart;
    my $end   = pop(@ranges);
    my $start = pop(@ranges);

    # If wrapping, temporarily set global margins to width of text in box
    # Also need to mark and re-find end of text because it will move
    unless ($asciinowrap) {
        local $::lmargin = 0;
        local $::rmargin = ( $asciiwidth - 4 );
        $textwindow->markSet( 'asciiend', $end );
        ::selectrewrap();
        $end = $textwindow->index('asciiend-1l lineend');
    }

    # Insert bottom line, then top line
    $textwindow->insert( $end,
        "\n" . ${$ascii}[6] . ( ${$ascii}[7] x ( $asciiwidth - 2 ) ) . ${$ascii}[8] );
    $textwindow->insert( $start,
        ${$ascii}[0] . ( ${$ascii}[1] x ( $asciiwidth - 2 ) ) . ${$ascii}[2] . "\n" );

    # For each line of text, justify and add the left/right box lines
    my ( $sr, $sc ) = split /\./, $start;
    my ( $er, $ec ) = split /\./, $end;
    for my $linenum ( $sr + 1 .. $er + 1 ) {

        # Trim any existing leading/trailing spaces from current line
        my $line = $textwindow->get( "$linenum.0", "$linenum.end" );
        $line =~ s/^\s+|\s+$//g;

        # Calculate number of spaces needed on left/right
        my $nspaces = $asciiwidth - 2 - length($line);
        my $lspaces;
        if ( $asciijustify eq 'left' ) {
            $lspaces = 1;    # one space on left
        } elsif ( $asciijustify eq 'right' ) {
            $lspaces = $nspaces - 1;    # one space on right
        } else {
            $lspaces = int( $nspaces / 2 );    # share spaces left/right
        }
        $lspaces = 0 if $lspaces < 0;
        my $rspaces = $nspaces - $lspaces;
        $rspaces = 0 if $rspaces < 0;

        # Replace the line with the new boxed and padded version
        $line = ${$ascii}[3] . ( ' ' x $lspaces ) . $line . ( ' ' x $rspaces ) . ${$ascii}[5];
        $textwindow->delete( "$linenum.0", "$linenum.end" );
        $textwindow->insert( "$linenum.0", $line );
    }
    $textwindow->addGlobEnd;
}

sub case {
    ::savesettings();
    my ( $textwindow, $marker ) = @_;
    my @ranges      = $textwindow->tagRanges('sel');
    my $range_total = @ranges;
    my $done        = '';
    if ( $range_total == 0 ) {
        return;
    } else {
        $textwindow->addGlobStart;
        while (@ranges) {
            my $end            = pop(@ranges);
            my $start          = pop(@ranges);
            my $thisblockstart = $start;
            my $thisblockend   = $end;
            my $selection      = $textwindow->get( $thisblockstart, $thisblockend );
            my @words          = ();
            if ( $marker eq 'uc' ) {
                $done = uc($selection);
            } elsif ( $marker eq 'lc' ) {
                $done = lc($selection);
            } elsif ( $marker eq 'sc' ) {
                $done = lc($selection);
                $done =~ s/(^\W*\w)/\U$1\E/;
            } elsif ( $marker eq 'tc' ) {
                $done = ::titlecase($selection);
            }
            $textwindow->replacewith( $start, $end, $done );
        }
        $textwindow->addGlobEnd;
    }
}

sub surround {
    my ( $textwindow, $top ) = ( $::textwindow, $::top );
    if ( defined( $::lglobal{surpop} ) ) {
        $::lglobal{surpop}->deiconify;
        $::lglobal{surpop}->raise;
        $::lglobal{surpop}->focus;
    } else {
        $::lglobal{surpop} = $top->Toplevel;
        $::lglobal{surpop}->title('Surround With');
        my $f = $::lglobal{surpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        $f->Label( -text => "Surround the selection with:\n\\n will be replaced with a newline.", )
          ->pack(
            -side   => 'top',
            -pady   => 5,
            -padx   => 2,
            -anchor => 'n'
          );
        my $f1      = $::lglobal{surpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        my $surstrt = $f1->Entry(
            -textvariable => \$::lglobal{surstrt},
            -width        => 12,
        )->pack(
            -side   => 'left',
            -pady   => 5,
            -padx   => 2,
            -anchor => 'n'
        );
        $surstrt->bind(
            '<FocusIn>',
            sub {
                $::lglobal{hasfocus} = $surstrt;
            }
        );
        my $surend = $f1->Entry(
            -textvariable => \$::lglobal{surend},
            -width        => 12,
        )->pack(
            -side   => 'left',
            -pady   => 5,
            -padx   => 2,
            -anchor => 'n'
        );
        $surend->bind(
            '<FocusIn>',
            sub {
                $::lglobal{hasfocus} = $surend;
            }
        );
        my $f2    = $::lglobal{surpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        my $gobut = $f2->Button(
            -command => sub {
                ::surroundit( $::lglobal{surstrt}, $::lglobal{surend}, $textwindow );
            },
            -text  => 'Surround',
            -width => 16
        )->pack(
            -side   => 'top',
            -pady   => 5,
            -padx   => 2,
            -anchor => 'n'
        );
        ::initialize_popup_with_deletebinding('surpop');
        $surstrt->insert( 'end', '_' ) unless ( $surstrt->get );
        $surend->insert( 'end', '_' )  unless ( $surend->get );
    }
}

sub surroundit {
    my ( $pre, $post, $textwindow ) = @_;
    $pre  =~ s/\\n/\n/;
    $post =~ s/\\n/\n/;
    my @ranges = $textwindow->tagRanges('sel');
    unless (@ranges) {
        push @ranges, $textwindow->index('insert');
        push @ranges, $textwindow->index('insert');
    }
    $textwindow->addGlobStart;
    while (@ranges) {
        my $end   = pop(@ranges);
        my $start = pop(@ranges);
        $textwindow->replacewith( $start, $end, $pre . $textwindow->get( $start, $end ) . $post );
    }
    $textwindow->addGlobEnd;
}

sub flood {

    #my ( $textwindow, $top, $floodpop, $font, $activecolor, $icon ) = @_;
    my $top        = $::top;
    my $textwindow = $::textwindow;
    if ( defined( $::lglobal{floodpop} ) ) {
        $::lglobal{floodpop}->deiconify;
        $::lglobal{floodpop}->raise;
        $::lglobal{floodpop}->focus;
    } else {
        $::lglobal{floodpop} = $top->Toplevel;
        $::lglobal{floodpop}->title('Flood Fill');
        my $f = $::lglobal{floodpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        $f->Label( -text => "Flood fill selection with string:\n(Blank will default to spaces.)", )
          ->pack( -side => 'top', -pady => 5, -padx => 2, -anchor => 'n' );
        my $f1 = $::lglobal{floodpop}->Frame->pack(
            -side   => 'top',
            -anchor => 'n',
            -expand => 'y',
            -fill   => 'x'
        );
        my $floodch = $f1->Entry(
            -textvariable => \$::lglobal{ffchar},
            -width        => 24,
        )->pack(
            -side   => 'left',
            -pady   => 5,
            -padx   => 2,
            -anchor => 'w',
            -expand => 'y',
            -fill   => 'x'
        );
        $floodch->bind(
            '<FocusIn>',
            sub {
                $::lglobal{hasfocus} = $floodch;
            }
        );
        my $f2    = $::lglobal{floodpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        my $gobut = $f2->Button(
            -command => sub { floodfill( $textwindow, $::lglobal{ffchar} ) },
            -text    => 'Flood Fill',
            -width   => 16
        )->pack( -side => 'top', -pady => 5, -padx => 2, -anchor => 'n' );
        ::initialize_popup_with_deletebinding('floodpop');
    }
}

sub floodfill {
    my ( $textwindow, $ffchar ) = @_;
    my @ranges = $textwindow->tagRanges('sel');
    return        unless @ranges;
    $ffchar = ' ' unless length $ffchar;
    $textwindow->addGlobStart;
    while (@ranges) {
        my $end       = pop(@ranges);
        my $start     = pop(@ranges);
        my $selection = $textwindow->get( $start, $end );
        my $temp      = substr( $ffchar x ( ( ( length $selection ) / ( length $ffchar ) ) + 1 ),
            0, ( length $selection ) );
        chomp $selection;
        my @temparray = split( /\n/, $selection );
        my $replacement;
        for (@temparray) {
            $replacement .= substr( $temp, 0, ( length $_ ), '' );
            $replacement .= "\n";
        }
        chomp $replacement;
        $textwindow->replacewith( $start, $end, $replacement );
    }
    $textwindow->addGlobEnd;
}

sub indent {
    my ( $textwindow, $indent ) = @_;
    my @ranges      = $textwindow->tagRanges('sel');
    my $range_total = @ranges;
    if ( $range_total == 0 ) {
        return;
    } else {
        my @selarray;
        $textwindow->addGlobStart;
        while (@ranges) {
            my $end            = pop(@ranges);
            my $start          = pop(@ranges);
            my $thisblockstart = int($start) . '.0';
            my $thisblockend   = int($end) . '.0';
            my $index          = $thisblockstart;
            if ( $thisblockstart == $thisblockend ) {
                my $char;
                if ( $indent eq 'in' ) {
                    if ( $textwindow->compare( $end, '==', "$end lineend" ) ) {
                        $char = ' ';
                    } else {
                        $char = $textwindow->get($end);
                        $textwindow->delete($end);
                    }
                    $textwindow->insert( $start, $char )
                      unless ( $textwindow->get( $start, "$start lineend" ) =~ /^$/ );
                    $end = "$end+1c"
                      unless ( $textwindow->get( $end, "$end lineend" ) =~ /^$/ );
                    push @selarray, ( "$start+1c", $end );
                } elsif ( $indent eq 'out' ) {
                    if ( $textwindow->compare( $start, '==', "$start linestart" ) ) {
                        push @selarray, ( $start, $end );
                        next;
                    } else {
                        $char = $textwindow->get("$start-1c");
                        $textwindow->insert( $end, $char );
                        $textwindow->delete("$start-1c");
                        push @selarray, ( "$start-1c", "$end-1c" );
                    }
                }
            } else {
                while ( $index <= $thisblockend ) {
                    if ( $indent eq 'in' ) {
                        $textwindow->insert( $index, ' ' )
                          unless ( $textwindow->get( $index, "$index lineend" ) =~ /^$/ );
                    } elsif ( $indent eq 'out' ) {
                        if ( $textwindow->get( $index, "$index+1c" ) eq ' ' ) {
                            $textwindow->delete( $index, "$index+1c" );
                        }
                    }
                    $index++;
                    $index .= '.0';
                }
                push @selarray, ( $thisblockstart, "$thisblockend lineend" );
            }
            $textwindow->focus;
            $textwindow->tagRemove( 'sel', '1.0', 'end' );
        }
        while (@selarray) {
            my $end   = pop(@selarray);
            my $start = pop(@selarray);
            $textwindow->tagAdd( 'sel', $start, $end );
        }
        $textwindow->addGlobEnd;
    }
}

sub alignpopup {
    my $textwindow = $::textwindow;
    my $top        = $::top;
    if ( defined( $::lglobal{alignpop} ) ) {
        $::lglobal{alignpop}->deiconify;
        $::lglobal{alignpop}->raise;
        $::lglobal{alignpop}->focus;
    } else {
        $::lglobal{alignpop} = $top->Toplevel;
        $::lglobal{alignpop}->title('Align text');
        my $f = $::lglobal{alignpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        $f->Label( -text => 'String to align on (first occurence)', )
          ->pack( -side => 'top', -pady => 5, -padx => 2, -anchor => 'n' );
        my $f1 = $::lglobal{alignpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        $f1->Entry(
            -width        => 8,
            -textvariable => \$::lglobal{alignstring},
        )->pack( -side => 'top', -pady => 5, -padx => 2, -anchor => 'n' );
        my $gobut = $f1->Button(
            -command => [
                sub {
                    aligntext( $textwindow, $::lglobal{alignstring} );
                }
            ],
            -text  => 'Align selected text',
            -width => 16
        )->pack( -side => 'top', -pady => 5, -padx => 2, -anchor => 'n' );
        ::initialize_popup_with_deletebinding('alignpop');
    }
}

sub blockrewrap {
    my $textwindow = $::textwindow;
    $::blockwrap = 1;
    selectrewrap();
    $::blockwrap = 0;
}

sub asciibox_popup {
    my $textwindow = $::textwindow;
    my $top        = $::top;
    ::hidepagenums();
    if ( defined( $::lglobal{asciiboxpop} ) ) {
        $::lglobal{asciiboxpop}->deiconify;
        $::lglobal{asciiboxpop}->raise;
        $::lglobal{asciiboxpop}->focus;
    } else {
        $::lglobal{asciiboxpop} = $top->Toplevel;
        $::lglobal{asciiboxpop}->title('ASCII Boxes');
        my $f = $::lglobal{asciiboxpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        $f->Label( -text => 'ASCII Drawing Characters', )
          ->pack( -side => 'top', -pady => 2, -padx => 2, -anchor => 'n' );
        my $f5 = $::lglobal{asciiboxpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        my ( $row, $col );
        for ( 0 .. 8 ) {
            next if $_ == 4;
            $row = int $_ / 3;
            $col = $_ % 3;
            $f5->Entry(
                -width        => 1,
                -font         => 'proofing',
                -textvariable => \${ $::lglobal{ascii} }[$_],
            )->grid(
                -row    => $row,
                -column => $col,
                -padx   => 3,
                -pady   => 3
            );
        }
        my $f0     = $::lglobal{asciiboxpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        my $wlabel = $f0->Label(
            -width => 16,
            -text  => 'ASCII Box Width',
        )->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'n' );
        my $wmentry = $f0->Entry(
            -width        => 6,
            -textvariable => \$::lglobal{asciiwidth},
        )->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'n' );
        my $f1       = $::lglobal{asciiboxpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        my $leftjust = $f1->Radiobutton(
            -text     => 'left justified',
            -variable => \$::lglobal{asciijustify},
            -value    => 'left',
        )->grid( -row => 2, -column => 1, -padx => 1, -pady => 2 );
        my $centerjust = $f1->Radiobutton(
            -text     => 'centered',
            -variable => \$::lglobal{asciijustify},
            -value    => 'center',
        )->grid( -row => 2, -column => 2, -padx => 1, -pady => 2 );
        my $rightjust = $f1->Radiobutton(
            -text     => 'right justified',
            -variable => \$::lglobal{asciijustify},
            -value    => 'right',
        )->grid( -row => 2, -column => 3, -padx => 1, -pady => 2 );
        my $asciiw = $f1->Checkbutton(
            -variable => \$::lglobal{asciinowrap},
            -text     => 'Don\'t Rewrap'
        )->grid( -row => 3, -column => 2, -padx => 1, -pady => 2 );
        my $gobut = $f1->Button(
            -command => sub {
                asciibox( $textwindow, $::lglobal{asciinowrap}, $::lglobal{asciiwidth},
                    $::lglobal{ascii}, $::lglobal{asciijustify} );
            },
            -text  => 'Draw Box',
            -width => 16
        )->grid( -row => 4, -column => 2, -padx => 1, -pady => 2 );
        $::lglobal{asciiboxpop}->resizable( 'no', 'no' );
        ::initialize_popup_with_deletebinding('asciiboxpop');
        $::lglobal{asciiboxpop}->raise;
        $::lglobal{asciiboxpop}->focus;
    }
}

sub rcaligntext {
    my ( $align, $indentval ) = @_;
    my $textwindow  = $::textwindow;
    my @ranges      = $textwindow->tagRanges('sel');
    my $range_total = @ranges;
    my $optrmargin  = $::rmargin - $::rmargindiff;
    return if ( $range_total == 0 );
    my ( $start, $end ) = ::expandselection();
    my $thisblockstart = "$start.0";
    my $thisblockend   = "$end.0";
    my $index          = $thisblockstart;
    $textwindow->addGlobStart;

    while ( $index < $thisblockend ) {
        while ( $textwindow->get( $index, "$index+1c" ) eq ' ' ) {
            $textwindow->delete( $index, "$index+1c" );
        }
        my $line = $textwindow->get( $index, "$index lineend" );
        if ( length($line) < $optrmargin ) {
            my $paddval = $optrmargin - length($line) + $indentval;
            if ( $align eq 'c' ) { $paddval = $paddval / 2; }
            $textwindow->insert( $index, ' ' x $paddval ) unless $line eq '';
        }
        $index++;
        $index .= '.0';
    }
    $textwindow->addGlobEnd;
    $textwindow->focus;
}

sub tocalignselection {
    my ($indentval) = @_;
    $indentval = 0 unless $indentval;
    my $textwindow  = $::textwindow;
    my @ranges      = $textwindow->tagRanges('sel');
    my $range_total = @ranges;
    return if ( $range_total == 0 );
    my ( $start, $end ) = ::expandselection();
    my $thisblockstart = "$start.0";
    my $thisblockend   = "$end.0";
    my $index          = $thisblockstart;
    $textwindow->addGlobStart;

    while ( $index < $thisblockend ) {
        my $line = $textwindow->get( $index, "$index lineend" );
        if ( $line =~ /^(.*?)  +(\d+([,-\x{2013}] *\d+)*\.?)$/ ) {
            my $len1     = length($1);
            my $len2     = length($2);
            my $spacelen = length($line) - $len1 - $len2;
            if ( $len1 + $len2 + 2 <= $::rmargin ) {
                my $paddval = $::rmargin - $len1 - $len2 - $spacelen + $indentval;
                if ( $paddval >= 0 ) {
                    $textwindow->insert( $index . "+$len1 c", ' ' x $paddval );
                } else {
                    $textwindow->delete( $index . "+$len1 c", $index . "+$len1 c" . "-$paddval c" );
                }
            }
        }
        $index++;
        $index .= '.0';
    }
    $textwindow->addGlobEnd;
    $textwindow->focus;
}

1;
