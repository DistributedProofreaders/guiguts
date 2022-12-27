package Guiguts::HTMLConvert;
use strict;
use warnings;

my $EMPX = 16.0;                     # 1em in px assumed to be 16
my ( $LANDX, $LANDY ) = ( 4, 3 );    # Common aspect ratio of landscape screen

BEGIN {
    use Exporter();
    use List::Util qw[min max];
    use Scalar::Util qw(looks_like_number);
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT =
      qw(&htmlautoconvert &htmlgenpopup &htmlmarkpopup &makeanchor &autoindex &entity &named &tonamed
      &fromnamed &fracconv &pageadjust &html_convert_pageanchors);
}

#
# Return the correct closure for void elements, either ">" or " />" (space included to match older versions of GG)
sub voidclosure {
    return $::xmlserialization ? " />" : ">";
}

# Return true if asterisks or <tb> converted on this line
sub html_convert_tb {
    my ( $textwindow, $selection, $step ) = @_;
    my $closure = voidclosure();
    if (   $selection =~ s/\s{7}(\*\s{7}){4}\*/<hr class="tb"$closure/
        or $selection =~ s/<tb>/<hr class="tb"$closure/ ) {
        $textwindow->ntdelete( "$step.0", "$step.end" );
        $textwindow->ntinsert( "$step.0", $selection );
        return 1;
    }
    return 0;
}

# Convert subscripts in the textwindow at this line
# Also return modified line so remainder of HTML conversion acts on the edited version
sub html_convert_subscripts {
    my ( $textwindow, $selection, $step ) = @_;
    if ( $selection =~ s/_\{([^}]+?)\}/<sub>$1<\/sub>/g ) {
        $textwindow->ntdelete( "$step.0", "$step.end" );
        $textwindow->ntinsert( "$step.0", $selection );
    }
    return $selection;
}

# Convert superscripts in the textwindow at this line
# Also return modified line so remainder of HTML conversion acts on the edited version
# Doesn't convert Gen^rl; workaround Gen^{rl} - correct behaviour, not a bug, cf. the guidelines
sub html_convert_superscripts {
    my ( $textwindow, $selection, $step ) = @_;
    if ( $selection =~ s/\^\{([^}]+?)\}/<sup>$1<\/sup>/g ) {
        $textwindow->ntdelete( "$step.0", "$step.end" );
        $textwindow->ntinsert( "$step.0", $selection );
    }

    # Fixed a bug--did not handle the case without curly brackets, i.e., Philad^a.
    if ( $selection =~ s/\^(.)/<sup>$1<\/sup>/g ) {
        $textwindow->ntdelete( "$step.0", "$step.end" );
        $textwindow->ntinsert( "$step.0", $selection );
    }
    return $selection;
}

sub html_convert_simple_tag {
    my ( $markup, $replace ) = @_;
    if ( "<$markup>" ne $replace ) {
        ::named( "<$markup>", $replace );
        $replace =~ s/^<([a-z0-9]+).*>$/$1/;
        ::named( "</$markup>", "</$replace>" );
    }
    return;
}

sub html_convert_ampersands {
    my $textwindow = shift;
    ::working("Converting Ampersands");
    ::named( '&', '&amp;' );
    $textwindow->FindAndReplaceAll( '-regexp', '-nocase', "(?<![a-zA-Z0-9/\\-\"])>", "&gt;" );
    $textwindow->FindAndReplaceAll( '-regexp', '-nocase',
        "(?![\\n0-9])<(?![a-zA-Z0-9/\\-\\n])", '&lt;' );
    return;
}

# double hyphens go to emdash.
sub html_convert_emdashes {
    ::working("Converting Emdashes");

    # Avoid converting double hyphens in HTML comments <!--  -->
    # Probably not strictly necessary, since no HTML comments in the file at this time
    # Use negative lookbehind for "<!" and negative lookahead for ">"
    ::named( '(?<!<!)--(?!>)', "\x{2014}" );

    # Convert non-breaking space character to numeric entity, since character looks just like a regular space
    ::named( "\x{A0}", '&#160;' );
    return;
}

sub html_cleanup_markers {
    my ($textwindow) = @_;
    my $thisblockend;
    my $thisblockstart = '1.0';
    my $thisend        = q{};
    my ( $ler, $lec );
    ::working("Cleaning up\nblock Markers");
    while ( $::blockstart = $textwindow->search( '-regexp', '--', '^\/[\*\$\#]', '1.0', 'end' ) ) {
        ( $::xler, $::xlec ) = split /\./, $::blockstart;
        $::blockend = "$::xler.end";
        $textwindow->ntdelete( "$::blockstart-1c", $::blockend );
    }
    while ( $::blockstart = $textwindow->search( '-regexp', '--', '^[\*\$\#]\/', '1.0', 'end' ) ) {
        ( $::xler, $::xlec ) = split /\./, $::blockstart;
        $::blockend = "$::xler.end";
        $textwindow->ntdelete( "$::blockstart-1c", $::blockend );
    }
    while ( $::blockstart =
        $textwindow->search( '-regexp', '--', '<\/h\d><br' . voidclosure(), '1.0', 'end' ) ) {
        $textwindow->ntdelete( "$::blockstart+5c", "$::blockstart+9c" );
    }
    return;
}

sub html_convert_footnotes {
    my ( $textwindow, $fnarray ) = @_;
    my $step = 0;
    ::working('Converting Footnotes');
    ::footnotefixup();
    ::getlz();

    # Keep track of last footnote to set closing </div>
    $textwindow->markSet( 'lastfnindex', '1.0' );
    $textwindow->tagRemove( 'footnote',  '1.0', 'end' );
    $textwindow->tagRemove( 'highlight', '1.0', 'end' );
    $textwindow->see('1.0');
    $textwindow->update;
    while (1) {
        $step++;
        last if ( $textwindow->compare( "$step.0", '>', 'end' ) );
        last unless $fnarray->[$step][0];

        # User's responsibility to ensure footnote markup is OK prior to HTML conversion
        # If not, this may skip creating HTML footnote.
        next unless $fnarray->[$step][3] and $fnarray->[$step][4];

        # insert first in case page marker directly follows footnote
        $textwindow->ntinsert( 'fne' . "$step" . '-1c', "\n\n</div>" );
        $textwindow->ntdelete( 'fne' . "$step" . '-1c', 'fne' . "$step" );

        $textwindow->ntinsert(
            ( 'fns' . "$step" . '+' . ( length( $fnarray->[$step][4] ) + 11 ) . "c" ),
            "$::htmllabels{fnanchafter}</a>" );
        $textwindow->ntdelete(
            'fns' . "$step" . '+' . ( length( $fnarray->[$step][4] ) + 10 ) . 'c',
            "fns" . "$step" . '+' . ( length( $fnarray->[$step][4] ) + 11 ) . 'c'
        );
        $textwindow->ntinsert(
            'fns' . "$step" . '+10c',
            "<div class=\"footnote\">\n\n<a id=\"$::htmllabels{fnlabel}"
              . ( $::lglobal{shorthtmlfootnotes} ? '' : $fnarray->[$step][4] . '_' )
              . $step
              . "\" href=\"#$::htmllabels{fnanchor}"
              . ( $::lglobal{shorthtmlfootnotes} ? '' : $fnarray->[$step][4] . '_' )
              . $step
              . "\" class=\"label\">$::htmllabels{fnanchbefore}"
        );
        $textwindow->ntdelete( 'fns' . "$step", 'fns' . "$step" . '+10c' );

        # jump through some hoops to steer clear of page markers
        if ( $fnarray->[$step][3] ) {
            $textwindow->ntinsert( "fnb$step -1c", ']</a>' );
            $textwindow->ntdelete( "fnb$step -1c", "fnb$step" );
        }
        unless ( $::htmllabels{fnanchbefore} eq '[' && $::htmllabels{fnanchafter} eq ']' ) {
            $textwindow->ntinsert( "fna$step +1c", $::htmllabels{fnanchbefore} );    # insert before delete, otherwise it gets excluded from the tag
            $textwindow->ntdelete( "fna$step",     "fna$step +1c" );
            $textwindow->ntdelete( "fnb$step -5c", "fnb$step -4c" );
            $textwindow->ntinsert( "fnb$step -4c", $::htmllabels{fnanchafter} );
        }
        $textwindow->ntinsert(
            'fna' . "$step",
            "<a id=\"$::htmllabels{fnanchor}"
              . ( $::lglobal{shorthtmlfootnotes} ? '' : $fnarray->[$step][4] . '_' )
              . $step
              . "\" href=\"#$::htmllabels{fnlabel}"
              . ( $::lglobal{shorthtmlfootnotes} ? '' : $fnarray->[$step][4] . '_' )
              . $step
              . "\" class=\"fnanchor\">"
        ) if ( $fnarray->[$step][3] );
    }
    return;
}

sub html_convert_body {
    my ( $textwindow, $headertext, $poetrynumbers ) = @_;

    #outline of subroutine: make a single pass through all lines $selection
    # with the last four lines stored in @last5
    # for a given line, convert subscripts, superscriptions and thought breaks for the line
    # /x|/X gets <pre>
    # and end tag gets </pre>
    # in front matter /F enter close para two lines above if needed
    # 	delete close front tag
    # 	Now in the title; skip ahead
    # 	no longer in title
    # 	now in some other header than <h1>
    # 	close para end of the last line before if the previous line does not already close
    # if poetrynumbers, and line ends with two spaces and digits, create line number
    # if end of poetry, delete two characters, insert closing </div></div>
    # end of stanza
    # if line ends spaces plus digits insert line number
    #delete indent based on number of digits
    # open poetry, if beginning x/ /p
    #   close para if needed before open poetry
    # in blockquote
    #   close para if needed before open blockquote
    # deal with block quotes
    # deal with lists
    # if nonblank followed by blank, insert close para after the nonblank  unless
    #   it already has a closing tag (problematic one)
    # at end of block, insert close para
    # in a block, insert <br>
    # four blank lines--start of chapter
    # Sets a mark for the horizontal rule at the page marker rather than just before
    # the header.
    # make an anchor for autogenerate TOC
    # insert chapter heading unless already a para or heading open
    # bold face insertion into autogenerated TOC
    #open subheading with <p>
    #open with para if blank line then nonblank line
    #open with para if blank line then two nonblank lines
    #open with para if blank line then three nonblank lines
    #
    ::working('Converting Body');
    my @contents = ("\n");
    my $aname    = q{};
    my $blkquot  = 0;
    my $cflag    = 0;
    my $front;

    #my $headertext;
    my $chapdiv    = 0;
    my $inblock    = 0;
    my $incontents = '1.0';
    my $indent     = 0;
    my $intitle    = 0;
    my $inheader   = 0;
    my $indexline  = 0;
    my $ital       = 0;
    my $bold       = 0;
    my $smcap      = 0;
    my $listmark   = 0;
    my $pgoffset   = 0;
    my $poetry     = 0;
    my $poetryend  = 0;
    my $selection  = q{};
    my $skip       = 0;
    my $thisblank  = q{};
    my $thisblockend;
    my $thisblockstart   = '1.0';
    my $unindentedpoetry = 0;
    my @last5            = [ '1', '1', '1', '1', '1', '1' ];
    my $step             = 1;
    my ( $ler, $lec );
    $thisblockend = $textwindow->index('end');
    my $blkcenter = 0;
    my $blkright  = 0;
    my $blkrstart = 0;               # Value of $step when a block right starts
    my @blkrlens  = ();
    my $closure   = voidclosure();

    ::hidelinenumbers();             # To speed updating of text window

    #last line and column
    ( $ler, $lec ) = split /\./, $thisblockend;

    #step through all the lines
    while ( $step <= $ler ) {
        unless ( ::updatedrecently() ) {    # slow if updated too frequently
            $textwindow->see("$step.0");
            $textwindow->update;
        }

        #with with one row (line) at a time
        $selection = $textwindow->get( "$step.0", "$step.end" );

        #flag--in table of contents
        $incontents = "$step.end"
          if ( ( $step < 100 )
            && ( $selection =~ /contents/i )
            && ( $incontents eq '1.0' ) );
        $selection = html_convert_subscripts( $textwindow, $selection, $step );
        $selection = html_convert_superscripts( $textwindow, $selection, $step );
        next if html_convert_tb( $textwindow, $selection, $step );

        # /x|/X gets <pre>
        if ( $selection =~ m"^/x"i ) {
            $skip = 1;

            # delete the line
            $textwindow->ntdelete( "$step.0", "$step.end" );

            #insert <pre> instead
            $textwindow->insert( "$step.0", '<pre>' );

            # added this--was not getting close para before <pre>
            insert_paragraph_close( $textwindow, ( $step - 1 ) . '.end' )
              if ( ( $last5[3] )
                && ( $last5[3] !~ /<\/?h\d?|<br.*?>|<\/p>|<\/div>/ ) );
            if ( ( $last5[2] ) && ( !$last5[3] ) ) {
                insert_paragraph_close( $textwindow, ( $step - 2 ) . ".end" )
                  unless (
                    $textwindow->get( ( $step - 2 ) . '.0', ( $step - 2 ) . '.end' ) =~ /<\/p>/ );
            }
            $step++;
            next;    #done with this row
        }

        # and end x/ tag gets </pre>
        if ( $selection =~ m"^x/"i ) {
            $skip = 0;
            $textwindow->ntdelete( "$step.0", "$step.end" );
            $textwindow->ntinsert( "$step.0", '</pre>' );
            $step++;
            $step++;
            next;
        }

        # skip the row after /X
        if ($skip) {
            $step++;
            next;
        }

        # in front matter /F enter close para two lines above if needed
        if ( $selection =~ m"^/f"i ) {
            $front = 1;
            $textwindow->ntdelete( "$step.0", "$step.end +1c" );
            if ( ( $last5[2] ) && ( !$last5[3] ) ) {
                insert_paragraph_close( $textwindow, ( $step - 2 ) . ".end" )
                  unless (
                    $textwindow->get( ( $step - 2 ) . '.0', ( $step - 2 ) . '.end' ) =~ /<\/p>/ );
            }
            next;
        }
        if ($front) {

            # delete close front tag F/, replace with close para if needed
            if ( $selection =~ m"^f/"i ) {
                $front = 0;
                $textwindow->ntdelete( "$step.0", "$step.end" );    #"$step.end +1c"
                insert_paragraph_close( $textwindow, $step . '.end' );
                $step++;
                next;
            }

            # Now in the title; skip ahead
            if ( ( $selection =~ /^<h1/ ) and ( not $selection =~ /<\/h1/ ) ) {
                $intitle = 1;
                push @last5, $selection;
                shift @last5 while ( scalar(@last5) > 4 );
                $step++;
                next;
            }

            # no longer in title
            if ( $selection =~ /<\/h1/ ) {
                $intitle = 0;
                push @last5, $selection;
                shift @last5 while ( scalar(@last5) > 4 );
                $step++;
                next;
            }

            # now in some other header than <h1>
            if ( $selection =~ /^<h/ ) {
                push @last5, $selection;
                shift @last5 while ( scalar(@last5) > 4 );
                $step++;
                next;
            }

            # <p class="center"> if selection does not have /h, /d, <br>, </p>, or </div> (or last line closed markup)
            #   print "int:$intitle:las:$last5[3]:sel:$selection\n";
            if (
                (
                    length($selection)
                    && (   ( !$last5[3] )
                        or ( $last5[3] =~ /<\/?h\d?|<br.*?>|<\/p>|<\/div>/ ) )
                    && ( $selection !~ /<\/?h\d?|<br.*?>|<\/p>|<\/div>/ )
                    && ( not $intitle )
                )
            ) {
                $textwindow->ntinsert( "$step.0", '<p class="center">' );
            }

            # close para end of the last line before if the previous line does not already close
            insert_paragraph_close( $textwindow, ( $step - 1 ) . '.end' )
              if (!( length($selection) )
                && ( $last5[3] )
                && ( $last5[3] !~ /<\/?h\d?|<br.*?>|<\/p>|<\/div>/ ) );
            push @last5, $selection;
            shift @last5 while ( scalar(@last5) > 4 );
            $step++;
            next;
        }    # done with front matter

        #if poetrynumbers, and line ends with two spaces and digits, create line number
        if ( $poetrynumbers && ( $selection =~ s/\s\s(\d+)$// ) ) {
            $selection .= '<span class="linenum">' . $1 . '</span>';
            $textwindow->ntdelete( "$step.0", "$step.end" );
            $textwindow->ntinsert( "$step.0", $selection );
        }

        # if in a poetry block
        if ($poetry) {

            # if end of p/ block, insert closing </div></div></div>
            if ( $selection =~ /^[pP]\/<?/ ) {
                $poetry    = 0;
                $selection = "  </div>\n</div>\n</div>";
                my $extra_nl = 2;
                if ($chapdiv) {    # Close chapter div if opened previously
                    $selection .= "\n</div>";
                    $extra_nl++;
                    $chapdiv = 0;
                }

                # delete "p/" characters and
                # newline so a page number doesn't fall inside the closing tag
                $textwindow->ntdelete( "$step.0", "$step.0 +3c" );

                # add back the deleted newline, and 3 </div>s with 2 more newlines
                $textwindow->ntinsert( "$step.0 -1c", "\n$selection" );

                # allow for the two/three additional newlines
                $step += $extra_nl;
                $ler  += $extra_nl;
                push @last5, $selection;
                shift @last5 while ( scalar(@last5) > 4 );
                $ital = $bold = $smcap = 0;
                $step++;
                next;
            }

            # end of stanza
            if ( $selection =~ /^$/ ) {
                $textwindow->ntinsert( "$step.0", "  </div>\n  <div class=\"stanza\">" );

                # allow for the additional newline
                $step++;
                $ler++;
                while (1) {
                    $step++;
                    $selection = $textwindow->get( "$step.0", "$step.end" );
                    last if ( $step ge $ler );
                    next if ( $selection =~ /^$/ );
                    last;
                }
                next;
            }

            # if line ends spaces plus digits insert line number
            if ( $selection =~ s/\s{2,}(\d+)\s*$/<span class="linenum">$1<\/span>/ ) {
                $textwindow->ntdelete( "$step.0", "$step.end" );
                $textwindow->ntinsert( "$step.0", $selection );
            }
            my $indent = 0;

            # indent based on number of spaces
            $indent = length($1)                                if $selection =~ s/^(\s+)//;
            $textwindow->ntdelete( "$step.0", "$step.$indent" ) if $indent;
            unless ($unindentedpoetry) {
                $indent -= 4;
            }    # rewrapped poetry automatically has indent of 4
            $indent = 0 if ( $indent < 0 );

            # italic/bold/smcap markup cannot span lines, so may need to close & re-open per line
            ( $ital, $bold, $smcap ) = domarkupperline( sub { $textwindow->ntinsert(@_) },
                $textwindow, $step, $selection, $ital, $bold, $smcap );

            # Default verse with no extra spaces has 3em padding, and -3em text-indent to
            # give hanging indent in case of a continuation line.
            # Every two spaces causes +1em indent, but continuation lines need to align at 3em,
            # so, add the half the space indent to -3em to set the em text-indent for each line
            # For example, if 4 space indent, use 4/2 - 3 = -1em text-indent, i.e.
            #    .poetry .indent4 {text-indent: -1em;}

            # Add new CSS to classhash - will be appended later after header
            $::lglobal{classhash}->{$indent} =
              ".poetry .indent$indent {text-indent: " . ( $indent / 2 - 3 ) . "em;}\n";
            $textwindow->ntinsert( "$step.0",   "    <div class=\"verse indent$indent\">" );
            $textwindow->ntinsert( "$step.end", '</div>' );
            push @last5, $selection;
            shift @last5 while ( scalar(@last5) > 4 );
            $step++;
            next;
        }

        # open poetry, if beginning /p
        if ( $selection =~ /^\/[pP]$/ ) {
            $poetry    = 1;
            $poetryend = $textwindow->search( '-regexp', '--', '^[pP]/$', $step . '.end', 'end' );
            $ital      = $bold = $smcap = 0;

            # If 4 blank lines precede start of block, insert hr and chapter div
            if ( !$last5[0] && !$last5[1] && !$last5[2] && !$last5[3] ) {
                insert_chapdiv($step);
                $chapdiv = 1;    # Remember to close div later
            }

            $unindentedpoetry = ispoetryunindented( $textwindow, $step . '.end', $poetryend );
            if ( ( $last5[2] ) && ( !$last5[3] ) ) {

                # close para
                insert_paragraph_close( $textwindow, ( $step - 2 ) . ".end" )
                  unless (
                    $textwindow->get( ( $step - 2 ) . '.0', ( $step - 2 ) . '.end' ) =~ /<\/p>/ );
            }
            $textwindow->ntdelete( $step . '.end -2c', $step . '.end' );
            $selection =
              "<div class=\"poetry-container\">\n<div class=\"poetry\">\n  <div class=\"stanza\">";
            $textwindow->ntinsert( $step . '.end', $selection );

            # allow for the two additional newlines inserted
            $step += 2;
            $ler  += 2;
            push @last5, $selection;
            shift @last5 while ( scalar(@last5) > 4 );
            $step++;
            next;
        }

        # in blockquote /#
        if ( $selection =~ /^\/\#/ ) {
            $blkquot = 1;
            push @last5, $selection;
            shift @last5 while ( scalar(@last5) > 4 );
            $step++;
            $selection = $textwindow->get( "$step.0", "$step.end" );
            $selection =~ s/^\s+//;
            my $blkopencopy = '<blockquote><p>';    # Switched to <div> in wrapup routine if necessary
            if ( $selection =~ m|^/[\*\$rc]|i ) {
                $selection = "\n$selection";        # catch /* /r or /c immediately following /#
                $blkopencopy =~ s/<p>//;
            }
            $textwindow->ntdelete( "$step.0", "$step.end" );
            $textwindow->ntinsert( "$step.0", $blkopencopy . $selection );

            # close para
            if ( ( $last5[1] ) && ( !$last5[2] ) ) {
                insert_paragraph_close( $textwindow, ( $step - 3 ) . ".end" )
                  unless ( $textwindow->get( ( $step - 3 ) . '.0', ( $step - 2 ) . '.end' ) =~
                    /<\/?h\d?|<br.*?>|<\/p>|<\/div>/ );
            }

            # close para
            $textwindow->ntinsert( ($step) . ".end", '</p>' )
              unless ( length $textwindow->get( ( $step + 1 ) . '.0', ( $step + 1 ) . '.end' ) );
            push @last5, $selection;
            shift @last5 while ( scalar(@last5) > 4 );
            $step++;
            next;
        }

        # list
        if ( $selection =~ /^\/[Ll]$/ ) {
            $listmark = 1;
            $ital     = $bold = $smcap = 0;
            if ( ( $last5[2] ) && ( !$last5[3] ) ) {
                insert_paragraph_close( $textwindow, ( $step - 2 ) . ".end" )
                  unless (
                    $textwindow->get( ( $step - 2 ) . '.0', ( $step - 2 ) . '.end' ) =~ /<\/p>/ );
            }
            $textwindow->ntdelete( "$step.0", "$step.end" );
            $step++;
            $selection = $textwindow->get( "$step.0", "$step.end" );
            $selection = '<ul><li>' . $selection . '</li>';
            $textwindow->ntdelete( "$step.0", "$step.end" );
            $textwindow->ntinsert( "$step.0", $selection );
            push @last5, $selection;
            shift @last5 while ( scalar(@last5) > 4 );
            $step++;
            next;
        }

        # close blockquote #/
        if ( $selection =~ /^\#\// ) {
            $blkquot = 0;
            my $blkclosecopy = '</p></blockquote>';    # Switched to </div> in wrapup routine if necessary
            $blkclosecopy =~ s|</p>||
              unless is_paragraph_open( $textwindow, ( $step - 1 ) . '.end' );
            $textwindow->ntinsert( ( $step - 1 ) . '.end', $blkclosecopy );
            push @last5, $selection;
            shift @last5 while ( scalar(@last5) > 4 );
            $step++;
            next;
        }

        #close list
        if ( $selection =~ /^[Ll]\/$/ ) {
            $listmark = 0;
            $ital     = $bold = $smcap = 0;

            # insert first to avoid moving page marker into list
            $textwindow->ntinsert( "$step.0", '</ul>' );
            $textwindow->ntdelete( "$step.5", "$step.end" );
            push @last5, '</ul>';
            shift @last5 while ( scalar(@last5) > 4 );
            $step++;
            next;
        }

        #in list
        if ($listmark) {
            if ( $selection eq '' ) { $step++; next; }

            # italic/bold/smcap markup cannot span lines, so may need to close & re-open per line
            ( $ital, $bold, $smcap ) = domarkupperline( sub { $textwindow->ntinsert(@_) },
                $textwindow, $step, $selection, $ital, $bold, $smcap );

            $textwindow->ntinsert( "$step.0",   '<li>' );
            $textwindow->ntinsert( "$step.end", '</li>' );
            push @last5, $selection;
            shift @last5 while ( scalar(@last5) > 4 );
            $step++;
            next;
        }

        # delete spaces
        if ( $blkquot and not $blkright ) {
            if ( $selection =~ s/^(\s+)// ) {
                my $space = length $1;
                $textwindow->ntdelete( "$step.0", "$step.0 +${space}c" );
            }
        }

        # close para at $/, */, c/ or r/
        if ( $selection =~ /^[\$\*cr]\//i ) {
            $inblock   = 0;
            $ital      = $bold = $smcap = 0;
            $blkcenter = 0 if $selection =~ /^c\//i;

            # If closing a block right, shift whole block across so longest line touches right margin
            if ( $blkright and $selection =~ /^r\//i ) {
                my $blkrmaxlen = max(@blkrlens);
                for my $stepidx ( 0 .. $#blkrlens ) {
                    next if $blkrlens[$stepidx] == 0;    # Skip paragraph breaks
                    my $steptmp    = $blkrstart + $stepidx;
                    my $blkrindent = ( $blkrmaxlen - $blkrlens[$stepidx] ) / 2;
                    next if $blkrindent == 0;
                    $textwindow->ntinsert( "$steptmp.0",
                        '<span style="margin-right: ' . $blkrindent . 'em;">' );

                    # if line ends with a <br> close the span before it (or it would fail on some epub readers)
                    my $spancl = $textwindow->search( '-regexp', '--', '<br ?/?>$', "$steptmp.0",
                        "$steptmp.end" );
                    $spancl = "$steptmp.end" unless $spancl;
                    $textwindow->ntinsert( $spancl, '</span>' );
                }
                $blkright  = 0;
                $blkrstart = 0;
                @blkrlens  = ();
            }

            # Remember to close chapter div if it was opened earlier
            $textwindow->replacewith( "$step.0", "$step.end", $chapdiv ? '</p></div>' : '</p>' );
            $chapdiv = 0;
            $step++;
            next;
        }

        # insert close para, open para at /$, /*, /c or /r
        if ( $selection =~ /^\/[\$\*cr]/i ) {
            if ($inblock) {    # Code structure does not cope with these types being nested
                my $dialog = $::top->Dialog(
                    -text => "Block markup is illegally nested near line $step in the source file",
                    -bitmap  => 'warning',
                    -title   => 'HTML Generation Failed',
                    -buttons => [qw/OK/],
                );
                $dialog->Show;
                ::restorelinenumbers();
                return;
            }
            $inblock   = 1;
            $blkcenter = ( $selection =~ /^\/c/i );
            $blkright  = ( $selection =~ /^\/r/i );
            $ital      = $bold = $smcap = 0;
            if ( ( $last5[2] ) && ( !$last5[3] ) ) {
                insert_paragraph_close( $textwindow, ( $step - 2 ) . '.end' )
                  unless (
                    (
                        $textwindow->get( ( $step - 2 ) . '.0', ( $step - 2 ) . '.end' ) =~
                        /<\/?[hd]\d?|<br.*?>|<\/p>/
                    )
                  );
            }

            #			$textwindow->replacewith( "$step.0", "$step.end", '<p>' );
            $textwindow->delete( "$step.0", "$step.end" );
            insert_paragraph_open( $textwindow, "$step.0" );

            # Immediately inside a blockquote, the <p> has been placed on the end of the <div class="blockquot"> line
            my $inspos = "$step.2";
            if ( $textwindow->get( "$step.0", "$step.end" ) eq "" ) {
                my $stepm = $step - 1;
                my $idx   = index( $textwindow->get( "$stepm.0", "$stepm.end" ), "<p>" );
                if ( $idx >= 0 ) {
                    $idx += 2;
                    $inspos = "$stepm.$idx";
                }
            }

            # If 4 blank lines precede start of block, insert hr and chapter div
            if ( !$last5[0] && !$last5[1] && !$last5[2] && !$last5[3] ) {
                insert_chapdiv($step);
                $chapdiv = 1;    # Remember to close div later
            }
            $textwindow->ntinsert( "$inspos", ' class="center"' ) if $blkcenter;
            $textwindow->ntinsert( "$inspos", ' class="right"' )  if $blkright;
            if ($blkright) {
                $blkrstart = $step + 1;
                @blkrlens  = ();
            }
            $step++;
            next;
        }

        # Start of index (/I) including possible [n.n,n] rewrap margin settings
        if ( $selection =~ /^\/[Ii]$/ or $selection =~ /^\/[Ii]\[[\d\.,]+]/ ) {
            $indexline = 1;
            $textwindow->ntdelete( "$step.0", "$step.end" );
            $textwindow->ntinsert( "$step.0", '<ul class="index">' );

            # if haven't just finished a heading, paragraph or div, need to close previous paragraph
            insert_paragraph_close( $textwindow, ( $step - 1 ) . '.end' )
              if ( $last5[3] and $last5[3] !~ /<\/?h\d?|<br.*?>|<\/p>|<\/div>/ );
            insert_paragraph_close( $textwindow, ( $step - 2 ) . ".end" )
              if ( !$last5[3]
                and $last5[2]
                and $textwindow->get( ( $step - 2 ) . '.0', ( $step - 2 ) . '.end' ) !~ /<\/p>/ );

            $step++;
            next;
        }

        # End of index (I/)
        if ( $selection =~ /^[Ii]\/$/ ) {
            $indexline = 0;

            # Insert first to avoid subsequent page marker moving back inside list
            $textwindow->ntinsert( "$step.0", '</ul>' );
            $textwindow->ntdelete( "$step.5", "$step.end" );
            $step++;
            next;
        }

        # Inside index
        if ($indexline) {
            if ($selection) {
                $selection = addpagelinks($selection);

                # First line or two previous blank lines - new section of index
                if ( $indexline == 1 or ( !$last5[3] and !$last5[2] ) ) {
                    $selection = '<li class="ifrst">' . $selection . '</li>';

                    # One previous blank line - top-level entry
                } elsif ( !$last5[3] ) {
                    $selection = '<li class="indx">' . $selection . '</li>';

                    # Indented line - sub entry
                } elsif ( $selection =~ s/^(\s+)// ) {
                    $indent    = int( ( length($1) + 1 ) / 2 );
                    $selection = '<li class="isub' . $indent . '">' . $selection . '</li>';
                }
                $textwindow->ntdelete( "$step.0", "$step.end" );
                $textwindow->ntinsert( "$step.0", $selection );
                $indexline++;
            }
            push @last5, $selection;
            shift @last5 while ( scalar(@last5) > 4 );
            $step++;
            next;
        }

        # if not in title or in block, close para
        if ( ( $last5[2] ) && ( !$last5[3] ) && ( not $intitle ) ) {
            insert_paragraph_close( $textwindow, ( $step - 2 ) . '.end' )
              unless (
                (
                    $textwindow->get( ( $step - 2 ) . '.0', ( $step - 2 ) . '.end' ) =~
                    /<\/?[hd]\d?|<br.*?>|<\/p>|<\/[uo]l>/
                )
                || ($inblock)
              );
        }

        # in block or just an indented line, add <br> and
        # 1. margin-right span for right aligned  - added later since need to know max line length in block
        # 2. no extra span for center aligned
        # 3. margin-left span for other cases
        if ( $inblock || ( $selection =~ /^\s/ ) ) {
            if ($blkcenter) {
                $selection =~ s/^\s+//;
                $selection =~ s/  /&#160; /g;    # attempt to maintain multiple spaces
                                                 # TODO - remove this commented section if not needed
                                                 # if ($selection =~ /^$/) { # Blank line - replace with a paragraph break unless first/last line in block
                                                 # my $stepm = $step - 1;
                                                 # my $stepp = $step + 1;
                                                 # unless ( $textwindow->get( "$stepm.0", "$stepm.end" ) =~ /^<p class="center">$/ or
                                                 # $textwindow->get( "$stepp.0", "$stepp.end" ) =~ /^[Cc]\/$/ ) {
                                                 # $selection =~ s/^$/<\/p><p class="center">/;
                                                 # $addbr = 0;
                                                 # }
                                                 # }
                $textwindow->ntdelete( "$step.0", "$step.end" );
                $textwindow->ntinsert( "$step.0", $selection );

                # italic/bold/smcap markup cannot span lines, so may need to close & re-open per line
                ( $ital, $bold, $smcap ) = domarkupperline( sub { $textwindow->ntinsert(@_) },
                    $textwindow, $step, $selection, $ital, $bold, $smcap );
            } elsif ($blkright) {

                # store length of line to use for offsetting later
                my $len = length($selection);

                # adjust length for conversions that have been done since the user did their alignment
                # For each conversion, count the occurrences of the converted entity on the line
                # then adjust for the number of characters that the conversion added or removed.
                my $cnt = () = $selection =~ /&#160;/g;     # instead of non-breaking space
                $len -= $cnt * 5;
                $cnt = () = $selection =~ /&amp;/g;         # instead of ampersand
                $len -= $cnt * 4;
                $cnt = () = $selection =~ /&[lg]t;/g;       # instead of < or >
                $len -= $cnt * 3;
                $cnt = () = $selection =~ /<sup>.</g;       # opening sup for a single character, i.e. instead of ^x
                $len -= $cnt * 4;
                $cnt = () = $selection =~ /<sup>.[^<]/g;    # opening sup for multiple characters, i.e. instead of ^{xy}
                $len -= $cnt * 2;
                $cnt = () = $selection =~ /<sub>.[^<]/g;    # opening sub instead of _{xy}
                $len -= $cnt * 2;
                $cnt = () = $selection =~ /<\/su[pb]>/g;    # closing /sup or /sub are all extra characters
                $len -= $cnt * 6;
                push( @blkrlens, $len );
                $selection =~ s/^\s+//;
                $selection =~ s/  /&#160; /g;               # attempt to maintain multiple spaces
                $textwindow->ntdelete( "$step.0", "$step.end" );
                $textwindow->ntinsert( "$step.0", $selection );

                # italic/bold/smcap markup cannot span lines, so may need to close & re-open per line
                ( $ital, $bold, $smcap ) = domarkupperline( sub { $textwindow->ntinsert(@_) },
                    $textwindow, $step, $selection, $ital, $bold, $smcap );
            } elsif ( $selection =~ /^(\s+)/ ) {
                $indent = ( length($1) / 2 );               # left margin of 1em for every 2 spaces
                $selection =~ s/^\s+//;
                $selection =~ s/  /&#160; /g;               # attempt to maintain multiple spaces
                $textwindow->ntdelete( "$step.0", "$step.end" );
                $textwindow->ntinsert( "$step.0", $selection );

                # italic/bold/smcap markup cannot span lines, so may need to close & re-open per line
                ( $ital, $bold, $smcap ) = domarkupperline( sub { $textwindow->ntinsert(@_) },
                    $textwindow, $step, $selection, $ital, $bold, $smcap );

                $textwindow->ntinsert( "$step.0",
                    '<span style="margin-left: ' . $indent . 'em;">' );
                $textwindow->ntinsert( "$step.end", '</span>' );
            }
            $textwindow->ntinsert( "$step.end", "<br$closure" );

            if ( ( $last5[2] ) && ( !$last5[3] ) && ( $selection =~ /\/\*/ ) ) {
                insert_paragraph_close( $textwindow, ( $step - 2 ) . ".end" )
                  unless ( $textwindow->get( ( $step - 2 ) . '.0', ( $step - 2 ) . '.end' ) =~
                    /<\/[hd]\d?/ );
            }
            push @last5, $selection;
            shift @last5 while ( scalar(@last5) > 4 );
            $step++;
            next;
        }

        # four blank lines--start of chapter
        if (   ( !$last5[0] )
            && ( !$last5[1] )
            && ( !$last5[2] )
            && ( !$last5[3] )
            && ($selection) ) {

            # make an anchor for autogenerate TOC
            $aname =~ s/<\/?[hscalup].*?>//g;
            $aname = makeanchor( ::deaccentdisplay($selection) );
            my $completeheader = $selection;

            # insert chapter heading unless already a para or heading open
            if ( not $selection =~ /<[ph]/ ) {
                $textwindow->ntinsert( "$step.0", "<h2 class=\"nobreak\" id=\"" . $aname . "\">" );

                # remove surplus blank lines prior to h2
                $textwindow->ntdelete( "$step.0-3l", "$step.0" );
                $step -= 3;

                my $linesinheader = 1;
                while (1) {
                    $step++;
                    $linesinheader++;
                    $selection = $textwindow->get( "$step.0", "$step.end" );
                    my $restofheader = $selection;
                    $restofheader =~ s/^\s+|\s+$//g;
                    if ( length($restofheader) ) {

                        # accumulate header for TOC
                        $completeheader .= ' ' . $restofheader;
                    } else {

                        # end of header reached
                        $step--;
                        $textwindow->ntinsert( "$step.end", '</h2>' );
                        $linesinheader--;
                        if ( $linesinheader > 3 ) {
                            $textwindow->ntinsert( "$step.end", '<Warning: long header>' );
                        }
                        last;
                    }
                }
            }

            # bold face insertion into autogenerated TOC
            unless ( ( $selection =~ /<p/ ) or ( $selection =~ /<h1/ ) ) {
                $selection =~ s/<sup>.*?<\/sup>//g;
                $selection =~ s/<[^>]+>//g;
                $selection = "<b>$selection</b>";
                push @contents,
                  "<a href=\"#" . $aname . "\">" . $completeheader . "</a><br$closure\n";
            }
            $selection .= '<h2';

            #open subheading with <p>
        } elsif ( $last5[2] && ( $last5[2] =~ /<h2/ ) && ($selection) ) {
            $textwindow->ntinsert( "$step.0", '<p>' )
              unless ( ( $selection =~ /<\/*[phd]/ )
                || ( $selection =~ /<[hb]r/ )
                || ($inblock) );

            #open with para if blank line then nonblank line
        } elsif ( ( $last5[2] ) && ( !$last5[3] ) && ($selection) ) {
            $textwindow->ntinsert( "$step.0", '<p>' )
              unless ( ( $selection =~ /<\/*[phd]/ )
                || ( $selection =~ /<[hb]r/ )
                || ($inblock) );

            #open with para if two blank lines then nonblank line
        } elsif ( ( $last5[1] )
            && ( !$last5[2] )
            && ( !$last5[3] )
            && ($selection) ) {
            $textwindow->ntinsert( "$step.0", '<p>' )
              unless ( ( $selection =~ /<\/*[phd]/ )
                || ( $selection =~ /<[hb]r/ )
                || ($inblock) );

            #open with para if three blank lines then nonblank line
        } elsif ( ( $last5[0] )
            && ( !$last5[1] )
            && ( !$last5[2] )
            && ( !$last5[3] )
            && ($selection) ) {    #start of new paragraph unless line contains <p, <h, <d, <hr, or <br
            $textwindow->ntinsert( "$step.0", '<p>' )
              unless ( ( $selection =~ /<\/*[phd]/ )
                || ( $selection =~ /<[hb]r/ )
                || ($inblock) );
        }
        push @last5, $selection;
        shift @last5 while ( scalar(@last5) > 4 );
        $step++;
    }

    # close the autogenerated TOC and insert at line called contents
    #push @contents, '</p>';
    local $" = '';
    my $contentstext =
      "\n\n<!-- Autogenerated TOC. Modify or delete as required. -->\n@contents\n<!-- End Autogenerated TOC. -->\n\n";
    $contentstext = "<p>" . $contentstext . "</p>"
      unless is_paragraph_open( $textwindow, $incontents );
    $textwindow->insert( $incontents, $contentstext ) if @contents;
    ::restorelinenumbers();
}

#
# Insert an hr and a chapter div before the current line
# Must only be called if 4 blank lines precede the "step" line handed in as argument
sub insert_chapdiv {
    my $step   = shift;
    my $stepm4 = $step - 4;
    $::textwindow->ntinsert( "$stepm4.0", '<hr class="chap x-ebookmaker-drop"' . voidclosure() );
    my $stepm1 = $step - 1;
    $::textwindow->ntinsert( "$stepm1.0", '<div class="chapter">' );
}

# Put <div class="chapter"> before, and </div> after h2 elements, including pagenum
# within the div if it comes up to 5 lines before the h2 and there's no intervening text.
sub html_convert_chapterdivs {
    my ($textwindow) = @_;
    my $searchstart = '1.0';
    my $h2blockend;
    my $closure = voidclosure();

    # find the end of an h2 element
    while ( $h2blockend = $textwindow->search( '-exact', '--', '</h2>', $searchstart, 'end' ) ) {

        # find the corresponding start of h2 by searching backwards
        my $h2blockstart = $textwindow->search( '-exact', '-backwards', '--', '<h2', $h2blockend );
        if ($h2blockstart) {

            # check if there's a pagenum span within the last 5 lines
            my $pagelength;
            my $pagestart = $textwindow->search(
                '-regexp', '-backwards',
                '-count' => \$pagelength,
                '--',
                '<p><span class="pagenum".+</span></p>', $h2blockstart, $h2blockstart . '-5l'
            );
            if ($pagestart) {

                # move the start point to before the pagenum unless
                # there's text between the end of the pagenum and the start of the h2
                $h2blockstart = $pagestart
                  unless (
                    $textwindow->search(
                        '-regexp', '--', '.', $pagestart . '+' . $pagelength . 'c',
                        $h2blockstart
                    )
                  );
            }

            # insert the end and start of the chapter div, with a chapter break <hr> before it
            $textwindow->ntinsert( $h2blockend . '+5c', "\n</div>" );
            $textwindow->ntinsert( $h2blockstart,
                "\n<hr class=\"chap x-ebookmaker-drop\"$closure\n\n<div class=\"chapter\">\n" );
        }
        $searchstart = $h2blockend . '+5l';    # ensure we don't find the same </h2 again
    }
}

sub html_convert_underscoresmallcaps {
    my ($textwindow) = @_;
    my $thisblockstart = '1.0';
    ::working("Converting underline and small caps markup");
    while ( $thisblockstart = $textwindow->search( '-exact', '--', '<u>', '1.0', 'end' ) ) {
        $textwindow->ntdelete( $thisblockstart, "$thisblockstart+3c" );
        $textwindow->ntinsert( $thisblockstart, '<span class="u">' );
    }
    while ( $thisblockstart = $textwindow->search( '-exact', '--', '</u>', '1.0', 'end' ) ) {
        $textwindow->ntdelete( $thisblockstart, "$thisblockstart+4c" );
        $textwindow->ntinsert( $thisblockstart, '</span>' );
    }
    while ( $thisblockstart = $textwindow->search( '-exact', '--', '<sc>', '1.0', 'end' ) ) {
        $textwindow->ntdelete( $thisblockstart, "$thisblockstart+4c" );

        # If text from here to next closing </sc> does not contain
        # any Unicode lowercase letters, use allsmcap class.
        my $thisblockend = '1.0';
        if ( $thisblockend = $textwindow->search( '-exact', '--', '</sc>', $thisblockstart, 'end' )
            and $textwindow->get( "$thisblockstart+1c", $thisblockend ) !~ /\p{Lowercase_Letter}/ )
        {
            $textwindow->ntinsert( $thisblockstart, '<span class="allsmcap">' );
        } else {
            $textwindow->ntinsert( $thisblockstart, '<span class="smcap">' );
        }
    }
    while ( $thisblockstart = $textwindow->search( '-exact', '--', '</sc>', '1.0', 'end' ) ) {
        $textwindow->ntdelete( $thisblockstart, "$thisblockstart+5c" );
        $textwindow->ntinsert( $thisblockstart, '</span>' );
    }
    while ( $thisblockstart = $textwindow->search( '-exact', '--', '</pre></p>', '1.0', 'end' ) ) {
        $textwindow->ntdelete( "$thisblockstart+6c", "$thisblockstart+10c" );
    }
}

# Set opening and closing markup for footnotes
sub html_convert_footnoteblocks {
    my ($textwindow) = @_;
    my $thisblockstart = '1.0';
    ::working("Marking footnote blocks");
    my $fnheadinglen = length("<p>$::htmllabels{fnheading}:</p>");
    while (
        $thisblockstart = $textwindow->search(
            '-exact',        '--', "<p>$::htmllabels{fnheading}:",
            $thisblockstart, 'end'
        )
    ) {
        $textwindow->ntdelete( $thisblockstart, "$thisblockstart+${fnheadinglen}c" );
        $textwindow->insert( $thisblockstart,
            "<div class=\"footnotes\"><h3>$::htmllabels{fnheading}:</h3>" );

        # Improved logic for finding end of footnote block: find
        # the next footnote block
        my $nextfootnoteblock =
          $textwindow->search( '-exact', '--', "$::htmllabels{fnheading}:",
            $thisblockstart . '+1l', 'end' );
        $nextfootnoteblock = 'end' unless $nextfootnoteblock;

        # find the start of last footnote in this block
        my $lastfootnoteinblock =
          $textwindow->search( '-exact', '-backwards', '--', '<div class="footnote">',
            $nextfootnoteblock );

        # if no footnotes in block just insert closing /div immediately after heading
        if ( not $lastfootnoteinblock ) {
            $textwindow->insert( $thisblockstart . '+42c', '</div>' );
            $thisblockstart .= '+1l';
            next;
        }

        # find the end of the last footnote (</p> followed by </div> with only whitespace between)
        my $endoflastfootnoteinblock = $lastfootnoteinblock;
        while (1) {

            # Find the next </div>
            $endoflastfootnoteinblock =
              $textwindow->search( '-exact', '--', '</div>', "$endoflastfootnoteinblock+1c" );
            if ($endoflastfootnoteinblock) {

                # Get 8 characters before </div> in case of blank lines between </p> and </div>
                # Can be two blank lines if footnote ends in block markup
                my $pdiv = $textwindow->get( $endoflastfootnoteinblock . '-8c',
                    $endoflastfootnoteinblock . '+6c' );

                # If find </p> followed by </div> assume it's the end of this last footnote.
                # Insert another closing </div> but put it before the existing </div>
                # to avoid problems if pagemarker comes straight after footnote.
                if ( $pdiv =~ /<\/p>\s*<\/div>/ ) {
                    $textwindow->insert( $endoflastfootnoteinblock, "</div>\n" );
                    $thisblockstart = $endoflastfootnoteinblock;
                    last;
                }
            } else {
                $thisblockstart = 'end';
                last;
            }
        }
    }
    return;
}

sub html_convert_sidenotes {
    my ($textwindow) = @_;
    ::working("Converting\nSidenotes");
    my $thisnoteend;
    my $length;
    my $thisblockstart = '1.0';
    while (
        $thisblockstart = $textwindow->search(
            '-regexp',
            '-count' => \$length,
            '--', '(<p>)?\[Sidenote:\s*', '1.0', 'end'
        )
    ) {
        $textwindow->ntdelete( $thisblockstart, $thisblockstart . '+' . $length . 'c' );
        $textwindow->ntinsert( $thisblockstart, '<div class="sidenote">' );
        $thisnoteend = $textwindow->search( '--', ']', $thisblockstart, 'end' );
        while ( $textwindow->compare( "$thisblockstart+1c", "<", $thisnoteend )
            and $textwindow->get( "$thisblockstart+1c", $thisnoteend ) =~ /\[/ ) {
            $thisblockstart = $thisnoteend;
            $thisnoteend    = $textwindow->search( '--', ']</p>', $thisblockstart, 'end' );
        }
        if ($thisnoteend) {
            my $dtext = $textwindow->get( $thisnoteend, "$thisnoteend+5c" );
            if ( $dtext eq ']</p>' ) {    # normal footnote in its own paragraph
                $textwindow->ntdelete( $thisnoteend, "$thisnoteend+5c" );
            } elsif ( substr( $dtext, 0, 1 ) =~ ']' ) {    # inline footnote
                $textwindow->ntdelete( $thisnoteend, "$thisnoteend+1c" );
            }
        }
        $textwindow->ntinsert( $thisnoteend, '</div>' ) if $thisnoteend;
    }
    while ( $thisblockstart = $textwindow->search( '--', '</div></div></p>', '1.0', 'end' ) ) {
        $textwindow->ntdelete( "$thisblockstart+12c", "$thisblockstart+16c" );
    }
    return;
}

sub html_convert_pageanchors {
    my $textwindow = $::textwindow;
    ::working("Inserting Page Number Markup");
    $|++;
    my @pagerefs;    # keep track of first/last page markers at the same position
    my $tempcounter;
    my $mark = '1.0';
    while ( $textwindow->markPrevious($mark) ) {
        $mark = $textwindow->markPrevious($mark);
    }

    my $closure = voidclosure();

    # Work through all the text markers
    while ( $mark = $textwindow->markNext($mark) ) {
        next unless $mark =~ m{Pg(\S+)};              # Only look at page markers
        my $markindex = $textwindow->index($mark);    # Get page marker's index

        # This is the custom page label
        my $num = $::pagenumbers{$mark}{label};
        $num =~ s/Pg // if defined $num;

        # Use the marker unless there is a custom page label
        $num = $1 unless $::pagenumbers{$mark}{action};
        next      unless length $num;

        # Strip leading zeroes
        $num =~ s/^0+(\d)/$1/;

        # Accumulate markers in pagerefs
        if ( $::lglobal{exportwithmarkup} ) {
            push @pagerefs, $mark;    # do not drop leading zeroes
        } else {
            push @pagerefs, $num;
        }

        # Find next page marker & its index
        my $marknext = $mark;
        while ( $marknext = $textwindow->markNext($marknext) ) {
            last if $marknext =~ m{Pg(\S+)};
        }

        # If no more marks (reached end of file) or there are word characters between the
        # current mark and the next, then convert batch of accumulated page markers to a string
        my $pagereference = '';
        my $lastref       = '';
        if (
            not $marknext    # no next marker - end of file
            or $textwindow->get( $markindex, $marknext ) =~ /\w/
        ) {
            my $br      = "";                 # No br before first marker in batch
            my $numrefs = scalar @pagerefs;
            my $count   = 0;
            for (
                sort {                        # Roman numbered pages come before Arabic numbered
                    ( looks_like_number($a) ? $a : ::arabic($a) - 1000 )
                      <=> ( looks_like_number($b) ? $b : ::arabic($b) - 1000 )
                } @pagerefs
            ) {
                ++$count;
                if ( $::lglobal{exportwithmarkup} ) {
                    $pagereference .= "<$_>";
                } elsif ( not $::lglobal{pageskipco} or $count == $numrefs ) {

                    # If skipping coincident pagenums, just one pagenum per span, so put id on
                    # span later, rather than on individual anchor element per pagenum here
                    my $idtxt =
                      $::lglobal{pageskipco} ? "" : "<a id=\"$::htmllabels{pglabel}$_\"></a>";
                    $pagereference .=
                      "$br" . "$idtxt$::htmllabels{pgnumbefore}$_$::htmllabels{pgnumafter}";
                    $br = "<br$closure";    # Insert br before any subsequent markers
                }
                $lastref = $_;
            }
            @pagerefs = ();
        }

        # if marker is not at whitespace, move it forward so pagenum span doesn't end up mid-word
        $markindex = ::safemark( $markindex, '<' );    # don't advance past '<' (HTML tag), e.g. abc<br>

        # comment only
        $textwindow->ntinsert( $markindex, "<!-- Page $lastref -->" )
          if ( $::pagecmt and $lastref );
        if ($pagereference) {

            # If exporting with page markers, insert where found
            $textwindow->ntinsert( $markindex, $pagereference )
              if ( $::lglobal{exportwithmarkup} and $lastref );

            # If skipping coincident pagenums, we know there is just one id to insert in the span
            my $idtxt = $::lglobal{pageskipco} ? " id=\"$::htmllabels{pglabel}$lastref\"" : "";

            # Otherwise may need to insert elsewhere
            my $insertpoint = $markindex;
            my $inserted    = 0;
            my $inserttext  = "<span class=\"pagenum\"$idtxt>$pagereference</span>";

            # move page ref if inside end of paragraph to outside
            my $nextpend = $textwindow->search( '--', '</p>', $markindex, 'end' ) || 'end';
            if ( $textwindow->compare( $nextpend, '<=', $markindex . '+1c' ) ) {
                $insertpoint = $nextpend . '+4c';
                $inserttext  = '<p>' . $inserttext . '</p>';
            } else {

                # move page ref forward to just inside <li...> markup if up to 2 characters before it,
                # i.e. at start of line, or on previous blank line, or two blank lines back
                my $nextlistart = $textwindow->search( '--', '<li', $markindex, 'end' );
                if (    $nextlistart
                    and $textwindow->compare( $nextlistart, '<=', $markindex . '+2c' ) ) {
                    my $nextliend = $textwindow->search( '--', '>', $markindex, 'end' );
                    $insertpoint = "$nextliend+1c" if $nextliend;
                } else {

                    # if neither previous <p> nor previous <div> is open, then wrap in <p>
                    my $pstart =
                      $textwindow->search( '-backwards', '-exact', '--', '<p', $markindex, '1.0' )
                      || '1.0';
                    my $pend =
                      $textwindow->search( '-backwards', '-exact', '--', '</p>', $markindex, '1.0' )
                      || '1.0';
                    my $sstart =
                      $textwindow->search( '-backwards', '-exact', '--', '<div ', $markindex,
                        '1.0' )
                      || '1.0';
                    my $send =
                      $textwindow->search( '-backwards', '-exact', '--', '</div>', $markindex,
                        '1.0' )
                      || '1.0';
                    if (
                        not( $textwindow->compare( $pend, '<', $pstart )
                            or ( $textwindow->compare( $send, '<', $sstart ) ) )
                    ) {
                        $inserttext = '<p>' . $inserttext . '</p>';
                    }
                }
            }

            # Oops find headers not <hr>
            my $hstart =
              $textwindow->search( '-backwards', '-regexp', '--', '<h\d', $markindex, '1.0' )
              || '1.0';
            my $hend =
              $textwindow->search( '-backwards', '-regexp', '--', '</h\d', $markindex, '1.0' )
              || '1.0';
            $insertpoint = $textwindow->index("$hstart-1l lineend")
              if $textwindow->compare( $hend, '<', $hstart );

            # poetry divs - place page ref at end of line to avoid disturbing code layout
            if ( $textwindow->get( "$markindex linestart", "$markindex lineend" ) =~
                /\s*<div class="(verse)|(stanza)/ ) {
                $insertpoint = "$markindex lineend";
            }

            $textwindow->ntinsert( $insertpoint, $inserttext )
              if $::lglobal{pageanch};
        }
    }
    ::working("");
    return;
}

sub html_parse_header {
    my ( $textwindow, $headertext, $title, $author ) = @_;
    my $selection;
    my $step;
    my $closure = voidclosure();
    ::working('Parsing Header');
    $selection = $textwindow->get( '1.0', '1.end' );
    if ( $selection =~ /DOCTYPE/ ) {
        $step = 1;
        while (1) {
            $selection = $textwindow->get( "$step.0", "$step.end" );
            $headertext .= ( $selection . "\n" );
            $textwindow->ntdelete( "$step.0", "$step.end" );
            last if ( $selection =~ /^\<body/ );
            $step++;
            last if ( $textwindow->compare( "$step.0", '>', 'end' ) );
        }
        $textwindow->ntdelete( '1.0', "$step.0 +1c" );
    } else {
        unless ( -e ::path_htmlheader() ) {
            ::copy( ::path_defaulthtmlheader(), ::path_htmlheader() );
        }

        # Either use header file, or use default header file followed by "user" header if one exists
        my $userheader = -e ::path_userhtmlheader();
        my $headername = $userheader ? ::path_defaulthtmlheader() : ::path_htmlheader();
        open my $infile, '<:encoding(utf8)', $headername
          or warn "Could not open header file. $!\n";
        while ( my $line = <$infile> ) {
            $line =~ s/\cM\cJ|\cM|\cJ/\n/g;

            # Upgrade to HTML5 if old XHTML4 header
            $line = "<!DOCTYPE html>\n"                     if $line =~ /<!DOCTYPE .* XHTML/;
            next                                            if $line =~ /DTD\/xhtml/;             # skip DTD line;
            next                                            if $line =~ /content="text\/css"/;    # skip content line
            $line = "    <meta charset=\"UTF-8\"$closure\n" if $line =~ /charset=BOOKCHARSET/;
            $line =
              "    <link rel=\"icon\" href=\"images/cover.jpg\" type=\"image/x-cover\"$closure\n"
              if $line =~ /rel="coverpage"/;
            $line = "    <style>\n" if $line =~ /<style type="text\/css">/;

            # If "user" header exists, insert it just before end of CSS
            if ( $userheader and $line =~ /<\/style>/ ) {
                open my $inuser, '<:encoding(utf8)', ::path_userhtmlheader()
                  or warn "Could not open header file. $!\n";
                while ( my $uline = <$inuser> ) {
                    $uline =~ s/\cM\cJ|\cM|\cJ/\n/g;
                    $headertext .= $uline;
                }
                close $inuser;
            }
            $headertext .= $line;
        }
        close $infile;
    }

    $author     =~ s/&/&amp;/g       if $author;
    $headertext =~ s/TITLE/$title/   if $title;
    $headertext =~ s/AUTHOR/$author/ if $author;
    my $mainlang = ::main_lang();
    $headertext =~ s/BOOKLANG/$mainlang/g;

    # locate and markup title
    $step = 0;
    my $intitle = 0;
    while (1) {
        $step++;
        last if ( $textwindow->compare( "$step.0", '>', 'end' ) );
        $selection = $textwindow->get( "$step.0", "$step.end" );
        next if ( $selection =~ /^\[Illustr/i );    # Skip Illustrations
        next if ( $selection =~ /^\/[\$fx]/i );     # Skip /$|/F tags
        if (    ($intitle)
            and ( ( not length($selection) or ( $selection =~ /^f\//i ) ) ) ) {
            $step--;
            $textwindow->ntinsert( "$step.end", '</h1>' );
            last;
        }                                           #done finding title
        next if ( $selection =~ /^\/[\$fx]/i );     # Skip /$|/F tags
        next unless length($selection);
        if ( $intitle == 0 ) {
            $textwindow->ntinsert( "$step.0", '<h1>' );
            $intitle = 1;
        } elsif ($title) {
            if ( ( $title =~ /^by/i ) or ( $title =~ /\Wby\s/i ) ) {
                $step--;
                $textwindow->ntinsert( "$step.end", '</h1>' );
                last;
            }
        }
    }
    return $headertext;
}

sub get_title_author {
    my $textwindow = $::textwindow;
    my $step       = 0;
    my ( $selection, $title, $author );
    my $completetitle = '';
    my $intitle       = 0;
    while (1) {    # find title
        $step++;
        last if ( $textwindow->compare( "$step.0", '>', 'end' ) || $step > 500 );
        $selection = $textwindow->get( "$step.0", "$step.end" );
        next if ( $selection =~ /^\[Illustr/i );    # Skip Illustrations
        next if ( $selection =~ /^\/[\$fx]/i );     # Skip /$|/F tags
        if (    ($intitle)
            and ( ( not length($selection) or ( $selection =~ /^f\//i ) ) ) ) {
            $step--;
            last;
        }                                           #done finding title
        next if ( $selection =~ /^\/[\$fx]/i );     # Skip /$|/F tags
        next unless length($selection);
        $title = $selection;
        $title =~ s/[,.]$//;                        #throw away trailing , or .
        $title = ::titlecase($title);
        $title =~ s/^\s+|\s+$//g;
        $title =~ s/<[^>]*>//g;

        if ( $intitle == 0 ) {
            $completetitle = $title;
            $intitle       = 1;
        } else {
            if ( ( $title =~ /^by/i ) or ( $title =~ /\Wby\s/i ) ) {
                $step--;
                last;
            }
            $completetitle .= ' ' . $title;
        }
    }
    while (1) {
        $step++;
        last if ( $textwindow->compare( "$step.0", '>', 'end' ) );
        $selection = $textwindow->get( "$step.0", "$step.end" );
        if ( ( $selection =~ /^by/i ) and ( $step < 100 ) ) {
            if ( $selection =~ /^by$/i ) {
                do {
                    $step++;
                    $selection = $textwindow->get( "$step.0", "$step.end" );
                } until ( $selection ne "" );
                $author = $selection;
                $author =~ s/,$//;
            } else {
                $author = $selection;
                $author =~ s/\s$//i;
            }
        }
        last if $author || ( $step > 100 );
    }
    if ($author) {
        $author =~ s/^by //i;
        $author = ucfirst( lc($author) );
        $author =~ s/(\W)(\w)/$1\U$2\E/g;
    }
    return ( $completetitle, $author );
}

sub html_wrapup {
    my ( $textwindow, $headertext, $autofraction, $cssblockmarkup ) = @_;
    my $thisblockstart;
    ::fracconv( $textwindow, '1.0', 'end' ) if $autofraction;
    $textwindow->ntinsert( '1.0', $headertext );
    insert_paragraph_close( $textwindow, 'end' );
    if ( -e 'footer.txt' ) {
        my $footertext;
        open my $infile, '<', 'footer.txt';
        while (<$infile>) {
            $_ =~ s/\cM\cJ|\cM|\cJ/\n/g;
            $footertext .= $_;
        }
        close $infile;
        $textwindow->ntinsert( 'end', $footertext );
    }
    $textwindow->ntinsert( 'end', "\n<\/body>\n<\/html>" );

    # improve readability of code
    ::named( '><p',               ">\n\n<p" );
    ::named( '><hr',              ">\n\n<hr" );
    ::named( '</p></div>',        "</p>\n</div>" );
    ::named( '</p></blockquote>', "</p>\n</blockquote>" );

    # switch blockquotes to divs with CSS if option selected by user during autogeneration
    ::named( '<blockquote>',  '<div class="blockquot">' ) if $cssblockmarkup;
    ::named( '</blockquote>', '</div>' )                  if $cssblockmarkup;

    # Output poetry indent CSS.
    # Find end of CSS, then search back for end of last class definition
    # Insert classes stored earlier in reverse order, preceded by a comment header
    $thisblockstart = $textwindow->search( '--', '</style', '1.0', 'end' );
    $thisblockstart = '75.0' unless $thisblockstart;
    $thisblockstart = $textwindow->search( '-backwards', '--', '}', $thisblockstart, '10.0' );
    if ( keys %{ $::lglobal{classhash} } ) {
        $textwindow->ntinsert( $thisblockstart . ' +1l linestart', "\n" );
        for ( reverse( sort( values( %{ $::lglobal{classhash} } ) ) ) ) {
            $textwindow->ntinsert( $thisblockstart . ' +1l linestart', $_ );
        }
        $textwindow->ntinsert( $thisblockstart . ' +1l linestart', "\n/* Poetry indents */\n" );
    }
    %{ $::lglobal{classhash} } = ();
    ::working();
    $textwindow->Unbusy;
    $textwindow->see('1.0');
    return;
}

# insert </p> only if there is an open <p> tag
sub insert_paragraph_close {
    my ( $textwindow, $index ) = @_;
    if ( is_paragraph_open( $textwindow, $index ) ) {
        $textwindow->ntinsert( $index, '</p>' );
        return 1;
    }
    return 0;
}

sub is_paragraph_open {
    my ( $textwindow, $index ) = @_;
    my $pstart = $textwindow->search( '-backwards', '-regexp', '--', '<p(>| )', $index, '1.0' )
      || '1.0';
    my $pend = $textwindow->search( '-backwards', '--', '</p>', $index, '1.0' )
      || '1.0';
    if ( $textwindow->compare( $pend, '<', $pstart ) ) {
        return 1;
    }
    return 0;
}

# insert <p> only if there is not an open <p> tag
sub insert_paragraph_open {
    my ( $textwindow, $index ) = @_;
    if ( not is_paragraph_open( $textwindow, $index ) ) {
        $textwindow->ntinsert( $index, '<p>' );
        return 1;
    }
    return 0;
}

sub htmlimage {
    my $filename   = shift;
    my $textwindow = $::textwindow;
    my $top        = $::top;
    $::lglobal{imarkupstart} = 'insert'                 unless $::lglobal{imarkupstart};
    $::lglobal{imarkupend}   = $::lglobal{imarkupstart} unless $::lglobal{imarkupend};
    $textwindow->markSet( 'thisblockstart', $::lglobal{imarkupstart} );
    $textwindow->markSet( 'thisblockend',   $::lglobal{imarkupend} );
    my $selection = $textwindow->get( $::lglobal{imarkupstart}, $::lglobal{imarkupend} );
    $selection            = '' unless $selection;
    $::lglobal{preservep} = '';
    $::lglobal{preservep} = "\n<p>" if $selection !~ /<\/p>$/;
    $selection =~ s/<p>\[Illustration/[Illustration/;
    $selection =~ s/\[Illustration:?\s*(\.*)/$1/;
    $selection =~ s/\]<\/p>$/]/;
    $selection =~ s/(\.*)\]$/$1/;
    my $xpad = 0;
    $::globalimagepath = $::globallastpath
      unless $::globalimagepath;
    $::lglobal{htmlorig}  = $top->Photo;
    $::lglobal{htmlthumb} = $top->Photo;

    if ( defined( $::lglobal{htmlimpop} ) ) {
        $::lglobal{htmlimpop}->deiconify;
        $::lglobal{htmlimpop}->raise;
        $::lglobal{htmlimpop}->focus;
    } else {
        $::lglobal{htmlimpop} = $top->Toplevel;
        $::lglobal{htmlimpop}->title('Image');
        ::initialize_popup_without_deletebinding('htmlimpop');
        my $f1 =
          $::lglobal{htmlimpop}->LabFrame( -label => 'File Name' )
          ->pack( -side => 'top', -anchor => 'n', -expand => 'yes', -fill => 'x' );
        $::lglobal{imgname} =
          $f1->Entry()->pack( -side => 'left', -expand => 'yes', -fill => 'x' );
        $f1->Button(
            -text    => 'Browse...',
            -command => sub { thumbnailbrowse(); }
        )->pack( -side => 'left' );
        my $f3 =
          $::lglobal{htmlimpop}->LabFrame( -label => 'Alt text' )
          ->pack( -side => 'top', -anchor => 'n', -expand => 'yes', -fill => 'x' );
        $::lglobal{alttext} =
          $f3->Entry()->pack( -side => 'left', -expand => 'yes', -fill => 'x' );
        my $f4a =
          $::lglobal{htmlimpop}->LabFrame( -label => 'Caption text' )
          ->pack( -side => 'top', -anchor => 'n', -expand => 'yes', -fill => 'x' );
        $::lglobal{captiontext} =
          $f4a->Entry()->pack( -side => 'left', -expand => 'yes', -fill => 'x' );
        my $f4 =
          $::lglobal{htmlimpop}->LabFrame( -label => 'Title text' )
          ->pack( -side => 'top', -anchor => 'n', -expand => 'yes', -fill => 'x' );
        $::lglobal{titltext} =
          $f4->Entry()->pack( -side => 'left', -expand => 'yes', -fill => 'x' );
        my $f5 =
          $::lglobal{htmlimpop}->LabFrame( -label => 'Geometry' )
          ->pack( -side => 'top', -anchor => 'n' );
        my $f51 = $f5->Frame->pack( -side => 'top', -anchor => 'n' );
        $f51->Label( -text => 'Width' )->pack( -side => 'left' );
        $::lglobal{widthent} = $f51->Entry(
            -width    => 8,
            -validate => 'all',
            -vcmd     => sub {
                my $newval = shift;
                my $change = shift;
                my $ok     = 1;       # Default to OK for unchanged/empty value

                # Need to check it's a number if it has changed and is non-empty,
                $ok = looks_like_number($newval) if ( $change and $newval );
                htmlimageupdateheight($newval)   if $ok;                       # Update the height field
                return $ok;
            },
        )->pack( -side => 'left' );
        $f51->Label( -text => 'Height' )->pack( -side => 'left' );
        $::lglobal{heightent} = $f51->Entry(
            -width        => 8,
            -state        => 'readonly',
            -textvariable => \$::lglobal{htmlimgheight},
        )->pack( -side => 'left' );

        # Ensure saved image width type is not disallowed
        $::htmlimagewidthtype = '%'
          if $::htmlimagewidthtype eq 'px' and not $::htmlimageallowpixels;
        my $percentsel = $f51->Radiobutton(
            -variable    => \$::htmlimagewidthtype,
            -text        => '%',
            -selectcolor => $::lglobal{checkcolor},
            -value       => '%',
            -command     => sub { htmlimagewidthsetdefault(); }
        )->pack( -side => 'left' );
        my $emsel = $f51->Radiobutton(
            -variable    => \$::htmlimagewidthtype,
            -text        => 'em',
            -selectcolor => $::lglobal{checkcolor},
            -value       => 'em',
            -command     => sub { htmlimagewidthsetdefault(); }
        )->pack( -side => 'left' );
        my $pxsel = $f51->Radiobutton(
            -variable    => \$::htmlimagewidthtype,
            -text        => 'px',
            -selectcolor => $::lglobal{checkcolor},
            -value       => 'px',
            -command     => sub { htmlimagewidthsetdefault(); }
        )->pack( -side => 'left' )
          if $::htmlimageallowpixels;
        my $f52 = $f5->Frame->pack( -side => 'top', -anchor => 'n' );
        $::lglobal{htmlimggeom} =
          $f52->Label( -text => '' )->pack();
        $::lglobal{htmlimgmaxwidth} =
          $f52->Label( -text => '' )->pack();
        $f52->Checkbutton(
            -variable    => \$::epubpercentoverride,
            -selectcolor => $::lglobal{checkcolor},
            -text        => 'Override % with 100% in epub',
            -anchor      => 'w',
        )->pack();
        my $f2 =
          $::lglobal{htmlimpop}->LabFrame( -label => 'Alignment' )
          ->pack( -side => 'top', -anchor => 'n' );
        $f2->Radiobutton(
            -variable    => \$::lglobal{htmlimgalignment},
            -text        => 'Left',
            -selectcolor => $::lglobal{checkcolor},
            -value       => 'left',
        )->grid( -row => 1, -column => 1 );
        my $censel = $f2->Radiobutton(
            -variable    => \$::lglobal{htmlimgalignment},
            -text        => 'Center',
            -selectcolor => $::lglobal{checkcolor},
            -value       => 'center',
        )->grid( -row => 1, -column => 2 );
        $f2->Radiobutton(
            -variable    => \$::lglobal{htmlimgalignment},
            -text        => 'Right',
            -selectcolor => $::lglobal{checkcolor},
            -value       => 'right',
        )->grid( -row => 1, -column => 3 );
        $censel->select;
        my $f8 = $::lglobal{htmlimpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        $f8->Button(
            -text    => 'Prev File',
            -width   => 8,
            -command => sub {
                my $nextfile = htmlimagefilenext(-1);
                if ($nextfile) {
                    htmlimage($nextfile);
                } else {
                    ::soundbell();
                }
            }
        )->pack( -side => 'left', -padx => 5 );
        $f8->Button(
            -text    => 'Insert & Load Next',
            -width   => 14,
            -command => sub {
                htmlimageok($textwindow);
                my $nextfile = htmlimagenext();
                if ($nextfile) {
                    htmlimage($nextfile);
                } else {
                    htmlimagedestroy();
                }
            }
        )->pack( -side => 'left', -padx => 5 );
        $f8->Button(
            -text    => 'Next File',
            -width   => 8,
            -command => sub {
                my $nextfile = htmlimagefilenext(+1);
                if ($nextfile) {
                    htmlimage($nextfile);
                } else {
                    ::soundbell();
                }
            }
        )->pack( -side => 'left', -padx => 5 );
        my $f9 = $::lglobal{htmlimpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        $f9->Button(
            -text    => 'Cancel',
            -width   => 8,
            -command => sub { htmlimagedestroy(); }
        )->pack( -side => 'left', -padx => 5 );
        $f9->Button(
            -text    => 'OK',
            -width   => 8,
            -command => sub { htmlimageok($textwindow); htmlimagedestroy(); }
        )->pack( -side => 'left', -padx => 5, -pady => 5 );
        my $f = $::lglobal{htmlimpop}->LabFrame( -label => 'Thumbnail' )->pack;
        $::lglobal{imagelbl} = $f->Label(
            -justify => 'center',
            -height  => 200,
            -width   => 200
        )->grid( -row => 1, -column => 1 );
        $::lglobal{imagelbl}->bind( '<1>', sub { thumbnailbrowse(); } );
        $::lglobal{htmlimpop}->protocol( 'WM_DELETE_WINDOW' => sub { htmlimagedestroy(); } );
        $::lglobal{htmlimpop}->transient($top);
    }
    $::lglobal{alttext}->delete( 0, 'end' )                       if $::lglobal{alttext};
    $::lglobal{titltext}->delete( 0, 'end' )                      if $::lglobal{titltext};
    $::lglobal{captiontext}->delete( 0, 'end' )                   if $::lglobal{captiontext};
    $::lglobal{captiontext}->insert( 'end', "<p>$selection</p>" ) if $selection;

    # Either load given filename or if none given let user browse for one
    thumbnailbrowse($filename);
}

#
# Find the next [Illustration] markup and load the next image after the currently loaded one
# Relies on the image order in the file matching alphabetical order of filenames
sub htmlimagenext {
    my $textwindow = $::textwindow;

    # Find next [Illustration] or exit
    $::lglobal{imarkupstart} =
      $textwindow->search( '-regexp', '--', '(<p>)?\[Illustration', $::lglobal{imarkupend}, 'end' );
    unless ( $::lglobal{imarkupstart} ) {
        ::soundbell();
        return "";
    }
    $textwindow->see( $::lglobal{imarkupstart} );
    my $length;
    $::lglobal{imarkupend} = $textwindow->search(
        '-regexp',
        '-count' => \$length,
        '--', '\](<\/p>)?', $::lglobal{imarkupstart}, 'end'
    );
    $::lglobal{imarkupend} = $textwindow->index( $::lglobal{imarkupend} . ' +' . $length . 'c' );
    unless ( $::lglobal{imarkupend} ) {
        ::soundbell();
        return "";
    }
    $textwindow->tagAdd( 'highlight', $::lglobal{imarkupstart}, $::lglobal{imarkupend} );
    $textwindow->markSet( 'insert', $::lglobal{imarkupstart} );

    return htmlimagefilenext(+1);
}

#
# Get current image name from dialog and find prev/next one alphabetically
sub htmlimagefilenext {
    my $dir      = shift;
    my $thisfile = $::lglobal{imgname}->get;
    unless ($thisfile) {
        ::soundbell();
        return "";
    }

    # Get sorted list of files in the current image file's directory
    my $dirname = ::dirname($thisfile);
    $thisfile = ::basename($thisfile);
    opendir( my $dh, $dirname ) || die "Can't opendir $dirname: $!";
    my @files = sort grep { -f "$dirname/$_" } readdir($dh);
    closedir $dh;

    # Find "previous" by just reversing the list
    @files = reverse @files if $dir < 0;

    # Find current file in the list and return the next one
    my $nextfile = "";
    my $found    = 0;
    for my $file (@files) {
        if ($found) {    # Found current file on last loop so this is the next file
            $nextfile = $file;
            last;
        }
        $found = 1 if $thisfile eq $file;    # Flag when find current file in list
    }
    unless ($nextfile) {                     # Didn't find a next file - reached end of list
        ::soundbell();
        return "";
    }
    return ::catfile( $dirname, $nextfile );
}

sub htmlimageok {
    my $textwindow = shift;
    my $name       = $::lglobal{imgname}->get;
    return unless $name;
    my $widthcn = my $width = $::lglobal{widthent}->get;
    my $height  = $::lglobal{heightent}->get;
    $widthcn =~ s/\./_/;    # Convert decimal point to underscore for classname
    my ( $fname, $extension );
    ( $fname, $::globalimagepath, $extension ) = ::fileparse($name);
    $::globalimagepath = ::os_normal($::globalimagepath);

    # Convert image path to relative path by removing project directory path from start if possible
    $name =~ s/[\/\\]/\;/g;
    my $tempname = $::globallastpath;
    $tempname =~ s/[\/\\]/\;/g;
    $name = substr( $name, length($tempname) ) if index( $name, $tempname ) == 0;
    $name =~ s/;/\//g;
    my $selection = $::lglobal{captiontext}->get;
    $selection ||= '';
    my $alt = $::lglobal{alttext}->get;
    $alt =~ s/"/&quot;/g;
    $alt       = " alt=\"$alt\"";
    $selection = "  <figcaption class=\"caption\">$selection</figcaption>\n"
      if $selection;
    $::lglobal{preservep} = '' unless $selection;
    my $title = $::lglobal{titltext}->get || '';
    $title =~ s/"/&quot;/g;
    $title = " title=\"$title\"" if $title;

    # Use filename as basis for an id - remove file extension first
    $fname =~ s/\.[^\.]*$//;
    my $idname = makeanchor( ::deaccentdisplay($fname) );

    # Ensure id is unique by appending _2, _3, etc if it already exists
    if ( $textwindow->search( '-exact', '--', "id=\"$idname\"", '1.0', 'end' ) ) {
        my $idsuffix = 2;
        $idsuffix++
          while $textwindow->search( '-exact', '--', "id=\"${idname}_$idsuffix\"", '1.0', 'end' );
        $idname .= "_$idsuffix";    # Append the suffix for the first version not found in file
    }

    my $illowsuffix = 'p';
    $illowsuffix = 'e' if $::htmlimagewidthtype eq 'em';
    $illowsuffix = 'x' if $::htmlimagewidthtype eq 'px';
    my $classname = "illow$illowsuffix$widthcn";
    my $figclass  = ( $::htmlimagewidthtype eq 'px' ? "" : " $classname" );

    # Replace [Illustration] with figure, img and figcaption
    $textwindow->addGlobStart;
    $textwindow->delete( 'thisblockstart', 'thisblockend' );

    # Never want image size to exceed its natural size
    my $maxwidth = $::lglobal{htmlimagesizex} / $EMPX;
    my $sizexy   = "";
    $sizexy = " width=\"$width\" height=\"$height\""
      if $::htmlimageallowpixels and $::htmlimagewidthtype eq 'px';
    my $style = "";
    $style = " style=\"max-width: ${maxwidth}em;\"" if $::htmlimagewidthtype eq '%';
    $style = " style=\"width: ${width}px;\""        if $::htmlimagewidthtype eq 'px';
    my $wclass = $::htmlimagewidthtype eq 'px' ? '' : ' class="w100"';
    $textwindow->insert( 'thisblockstart',
            "<figure class=\"fig$::lglobal{htmlimgalignment}$figclass\" id=\"$idname\"$style>\n"
          . "  <img$wclass src=\"$name\"$sizexy$alt$title"
          . voidclosure() . "\n"
          . "$selection</figure>"
          . $::lglobal{preservep} );

    # Write class into CSS block (sorted) - first find end of CSS
    my $insertpoint = $textwindow->search( '--', '</style', '1.0', 'end' );
    if ( $insertpoint and $::htmlimagewidthtype ne 'px' ) {    # px type uses style, not class
        my $cssdef = ".$classname {width: " . $width . "$::htmlimagewidthtype;}";

        # If % width and override flag set (and not already 100%), then also add CSS to override width to 100% for epub
        my $cssovr =
          ( $::htmlimagewidthtype eq '%' and $::epubpercentoverride and $width ne 100 )
          ? "\n.x-ebookmaker .$classname {width: 100%;}"
          : "";

        # Don't write the same override CSS twice
        $cssovr = ""
          if $cssovr and $textwindow->search( '-exact', '--', substr( $cssovr, 1 ), '1.0', 'end' );

        # If this class has been added already, write it again (override may have changed)
        if ( my $samepoint =
            $textwindow->search( '-backwards', '--', $cssdef, $insertpoint, '10.0' ) ) {
            $textwindow->delete( $samepoint . ' linestart', $samepoint . ' lineend' );
            $textwindow->insert( $samepoint . ' linestart', $cssdef . $cssovr );

            # Otherwise, find correct place to insert line
        } else {

            # Find end of last class definition in CSS
            $insertpoint = $textwindow->search( '-backwards', '--', '}', $insertpoint, '10.0' );
            if ($insertpoint) {
                $insertpoint = $insertpoint . ' +1l';       # default position for first ever illow class
                my $length     = 0;
                my $classpoint = $insertpoint;
                my $classreg   = '\.illow[pex][0-9\.]+';    # Match any automatically added illow classes

                # Loop back through illow classes to find correct place to insert
                # If a smaller width is found, insert after it. If not, insert at start of list
                while (
                    $classpoint = $textwindow->search(
                        '-backwards', '-regexp',
                        '-count' => \$length,
                        '--', $classreg, $classpoint, '10.0'
                    )
                ) {
                    $insertpoint = $classpoint;    # Potential insert point
                    my $testcn = $textwindow->get( "$classpoint+1c", "$classpoint+${length}c" );
                    if ( $testcn le $classname ) {
                        $insertpoint = $insertpoint . ' +1l';    # Insert after smaller width
                        last;
                    }
                }
                $textwindow->insert( $insertpoint . ' linestart', $cssdef . $cssovr . "\n" );

                # Unless it already exists, add heading before first illow class
                my $heading = '/* Illustration classes */';
                unless ( $textwindow->search( '--', $heading, '10.0', $insertpoint ) ) {
                    $insertpoint =
                      $textwindow->search( '-regexp', '--', $classreg, '10.0', $insertpoint );
                    $textwindow->insert( $insertpoint . ' linestart', "\n$heading\n" )
                      if ($insertpoint);
                }
            }
        }
    }
    $textwindow->addGlobEnd;
    $textwindow->markSet( 'insert', 'thisblockstart' );
    $textwindow->see('insert');
}

sub htmlimagedestroy {
    $::lglobal{htmlthumb}->delete if $::lglobal{htmlthumb};
    ::killpopup('htmlthumb');
    $::lglobal{htmlorig}->delete if $::lglobal{htmlorig};
    ::killpopup('htmlorig');
    $::textwindow->tagRemove( 'highlight', '1.0', 'end' );
    ::killpopup('htmlimpop');
}

# Reset the width field to the default for the current type
sub htmlimagewidthsetdefault {
    my $sizex;
    if ( $::htmlimagewidthtype eq '%' ) {
        $sizex = htmlimagewidthmaxpercent();
    } elsif ( $::htmlimagewidthtype eq 'em' ) {
        $sizex = $::lglobal{htmlimagesizex} / $EMPX;
    } else {
        $sizex = $::lglobal{htmlimagesizex};
    }
    $::lglobal{widthent}->delete( 0, 'end' );
    $::lglobal{widthent}->insert( 'end', $sizex );
    htmlimageupdateheight($sizex);

    # Tell user maximum % width such that both dimensions will fit a 4:3 screen
    $::lglobal{htmlimgmaxwidth}->configure(
        -text => ( $::htmlimagewidthtype eq '%' )
        ? "Max width to fit $LANDX:$LANDY screen is " . $sizex . "%"
        : ""
    );
}

# Return the maximum percentage width for the current image
# such that both its width and height will fit a landscape screen
sub htmlimagewidthmaxpercent {
    return 100 unless $::lglobal{htmlimagesizex} and $::lglobal{htmlimagesizey};
    return min( 100,
        int( 100.0 * $LANDY / $LANDX * $::lglobal{htmlimagesizex} / $::lglobal{htmlimagesizey} ) );
}

# Update the image height field based on the width field, width type (%/em)
# and aspect ratio of loaded image
# If using percentage width, then height is not known/displayed
sub htmlimageupdateheight {
    my $widthlabel  = shift;
    my $heightlabel = '';
    if ( looks_like_number($widthlabel) ) {
        $heightlabel = ' --';
        if ( $::lglobal{htmlimagesizex} and $::lglobal{htmlimagesizey} ) {
            if ( $::htmlimagewidthtype eq 'em' ) {
                $heightlabel =
                  $widthlabel * $::lglobal{htmlimagesizey} / $::lglobal{htmlimagesizex};
                $heightlabel = sprintf( "%.3f", $heightlabel );
            } elsif ( $::htmlimagewidthtype eq 'px' ) {
                $heightlabel =
                  $widthlabel * $::lglobal{htmlimagesizey} / $::lglobal{htmlimagesizex};
                $heightlabel = sprintf( "%.0f", $heightlabel );
            } else {
                $heightlabel = ' --';
            }
        }
    }
    $::lglobal{htmlimgheight} = $heightlabel;
}

sub htmlimages {
    my ( $textwindow, $top ) = @_;
    my $length;
    my $start = $textwindow->search( '-regexp', '--', '(<p>)?\[Illustration', '1.0', 'end' );
    return unless $start;
    $textwindow->see($start);
    my $end = $textwindow->search(
        '-regexp',
        '-count' => \$length,
        '--', '\](<\/p>)?', $start, 'end'
    );
    $end = $textwindow->index( $end . ' +' . $length . 'c' );
    return unless $end;
    $textwindow->tagAdd( 'highlight', $start, $end );
    $textwindow->markSet( 'insert', $start );
    ::update_indicators();
    $::lglobal{imarkupstart} = $start;
    $::lglobal{imarkupend}   = $end;
    htmlimage();
}

sub htmlautoconvert {
    my ( $textwindow, $top, $title, $author ) = @_;
    ::hidepagenums();
    my $headertext;
    if ( $::lglobal{global_filename} =~ /No File Loaded/ ) {
        $top->messageBox(
            -icon    => 'warning',
            -type    => 'OK',
            -message => 'File must be saved first.'
        );
        return;
    }

    # Backup file
    $textwindow->Busy;
    my $savefn = $::lglobal{global_filename};
    $::lglobal{global_filename} =~ s/\.[^\.]*?$//;
    my $newfn = $::lglobal{global_filename} . '-htmlbak.txt';
    ::working("Saving backup of file\nto $newfn");
    $textwindow->SaveUTF($newfn);
    $::lglobal{global_filename} = $newfn;
    ::_bin_save();
    $::lglobal{global_filename} = $savefn;
    $textwindow->FileName($savefn);
    html_convert_ampersands($textwindow);
    $headertext               = html_parse_header( $textwindow, $headertext, $title, $author );
    $::lglobal{fnsecondpass}  = 0;
    $::lglobal{fnsearchlimit} = 1;
    html_convert_footnotes( $textwindow, $::lglobal{fnarray} );
    html_convert_body( $textwindow, $headertext, $::lglobal{poetrynumbers} );
    html_convert_emdashes();
    html_cleanup_markers($textwindow);
    html_convert_underscoresmallcaps($textwindow);
    html_convert_simple_tag( 'i', $::lglobal{html_i} );
    html_convert_simple_tag( 'b', $::lglobal{html_b} );
    html_convert_simple_tag( 'g', $::lglobal{html_g} );
    html_convert_simple_tag( 'f', $::lglobal{html_f} );
    html_convert_footnoteblocks($textwindow);
    html_convert_sidenotes($textwindow);
    html_convert_pageanchors();
    html_convert_chapterdivs($textwindow);    # after page anchors, so they can be included in div
    html_wrapup( $textwindow, $headertext, $::lglobal{autofraction}, $::lglobal{cssblockmarkup} );
    $textwindow->ResetUndo;
    ::setedited(1);
}

#
# Optionally takes a filename instead of letting user browse for one
sub thumbnailbrowse {
    my $name = shift;
    unless ($name) {
        my $types = [ [ 'Image Files', [ '.gif', '.jpg', '.png' ] ], [ 'All Files', ['*'] ], ];
        $name = $::lglobal{htmlimpop}->getOpenFile(
            -filetypes  => $types,
            -title      => 'File Load',
            -initialdir => $::globalimagepath
        );
        return unless ($name);
    }
    ( $::lglobal{htmlimagesizex}, $::lglobal{htmlimagesizey} ) = Image::Size::imgsize($name);
    unless ( $::lglobal{htmlimagesizex} and $::lglobal{htmlimagesizey} ) {
        $::top->messageBox(
            -icon    => 'error',
            -message => "Unable to get image width and height.",
            -title   => 'Image Error.',
            -type    => 'Ok',
        );
        return;
    }
    $::lglobal{htmlimggeom}->configure( -text => "File size: "
          . $::lglobal{htmlimagesizex} / $EMPX . " x "
          . $::lglobal{htmlimagesizey} / $EMPX . " em "
          . "($::lglobal{htmlimagesizex} x $::lglobal{htmlimagesizey} px)" );
    htmlimagewidthsetdefault();

    $::lglobal{htmlorig}->blank;
    $::lglobal{htmlthumb}->blank;
    $::lglobal{imgname}->delete( '0', 'end' );
    $::lglobal{imgname}->insert( 'end', $name );
    my ( $fn, $ext );
    ( $fn, $::globalimagepath, $ext ) = ::fileparse( $name, '(?<=\.)[^\.]*$' );
    $::globalimagepath = ::os_normal($::globalimagepath);

    if ( lc($ext) eq 'gif' ) {
        $::lglobal{htmlorig}->read( $name, -shrink );
    } else {
        $ext =~ s/jpg/jpeg/;
        $::lglobal{htmlorig}->read( $name, -format => $ext, -shrink );
    }
    my $xythumb = 200;
    my $sw      = int( ( $::lglobal{htmlorig}->width ) / $xythumb );
    my $sh      = int( ( $::lglobal{htmlorig}->height ) / $xythumb );
    if ( $sh > $sw ) {
        $sw = $sh;
    }
    if ( $sw < 2 ) { $sw += 1 }
    $::lglobal{htmlthumb}->copy( $::lglobal{htmlorig}, -subsample => ($sw), -shrink );
    $::lglobal{imagelbl}->configure(
        -image   => $::lglobal{htmlthumb},
        -text    => 'Thumbnail',
        -justify => 'center',
    );
}

# Create the HTML Generator dialog for user to adjust settings then autogenerate HTML
# Note that the default settings for the Checkbuttons and Radiobuttons are defined by
# the initial value of the relevant ::lglobal hash element set in sub initialize.
sub htmlgenpopup {
    my ( $textwindow, $top ) = ( $::textwindow, $::top );
    ::operationadd('Begin HTML Generation');
    ::hidepagenums();
    if ( defined( $::lglobal{htmlgenpop} ) ) {
        $::lglobal{htmlgenpop}->deiconify;
        $::lglobal{htmlgenpop}->raise;
        $::lglobal{htmlgenpop}->focus;
    } else {
        $::lglobal{htmlgenpop} = $top->Toplevel;
        $::lglobal{htmlgenpop}->title('HTML Generator');

        my $f1 = $::lglobal{htmlgenpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        $f1->Button(
            -text    => 'Custom Page Labels',
            -command => sub { ::pageadjust() },
        )->grid( -row => 1, -column => 2, -padx => 1, -pady => 1 );
        $f1->Button(
            -activebackground => $::activecolor,
            -command          => sub { htmlimages( $textwindow, $top ); },
            -text             => 'Auto Illus Search',
            -width            => 16,
        )->grid( -row => 1, -column => 3, -padx => 1, -pady => 1 );

        my $ishtml = $textwindow->search( '-nocase', '--', '<html', '1.0' );
        my ( $htmltitle, $htmlauthor ) = ( '', '' );
        ( $htmltitle, $htmlauthor ) = get_title_author() unless $ishtml;
        my $f0a = $::lglobal{htmlgenpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        $f0a->Label( -text => 'Title:', )
          ->grid( -row => 0, -column => 0, -padx => 2, -pady => 2, -sticky => 'w' );
        $f0a->Entry(
            -textvariable => \$htmltitle,
            -width        => 45,
            -background   => $::bkgcolor,
            -relief       => 'sunken',
        )->grid( -row => 0, -column => 1, -pady => 2, -sticky => 'w' );
        $f0a->Label( -text => 'Author:', )
          ->grid( -row => 1, -column => 0, -padx => 2, -pady => 2, -sticky => 'w' );
        $f0a->Entry(
            -textvariable => \$htmlauthor,
            -width        => 45,
            -background   => $::bkgcolor,
            -relief       => 'sunken',
        )->grid( -row => 1, -column => 1, -pady => 2, -sticky => 'w' );
        $f0a->Label( -text => 'Language:', )
          ->grid( -row => 2, -column => 0, -padx => 2, -pady => 2, -sticky => 'w' );
        $f0a->Entry(
            -textvariable => \$::booklang,
            -width        => 5,
            -background   => $::bkgcolor,
            -relief       => 'sunken',
        )->grid( -row => 2, -column => 1, -pady => 2, -sticky => 'w' );

        my $f0 = $::lglobal{htmlgenpop}->Frame->pack( -side => 'top', -anchor => 'n' );

        # Page numbers retained as comments rather than spans in HTML
        $f0->Checkbutton(
            -variable    => \$::lglobal{pagecmt},
            -selectcolor => $::lglobal{checkcolor},
            -text        => 'Pg #s as Comments',
            -anchor      => 'w',
        )->grid(
            -row    => 1,
            -column => 1,
            -padx   => 1,
            -pady   => 2,
            -sticky => 'w'
        );

        # Add anchor at each page boundary
        $f0->Checkbutton(
            -variable    => \$::lglobal{pageanch},
            -selectcolor => $::lglobal{checkcolor},
            -text        => 'Insert Anchors at Pg #s',
            -anchor      => 'w',
        )->grid(
            -row    => 1,
            -column => 2,
            -padx   => 1,
            -pady   => 2,
            -sticky => 'w'
        );

        # Only output last of coincident page numbers (due to blank pages)
        $f0->Checkbutton(
            -variable    => \$::lglobal{pageskipco},
            -selectcolor => $::lglobal{checkcolor},
            -text        => 'Skip coincident Pg #s',
            -anchor      => 'w',
        )->grid(
            -row    => 1,
            -column => 3,
            -padx   => 1,
            -pady   => 2,
            -sticky => 'w'
        );

        # Use <div> with CSS class rather than HTML <blockquote> element
        $f0->Checkbutton(
            -variable    => \$::lglobal{cssblockmarkup},
            -selectcolor => $::lglobal{checkcolor},
            -text        => 'CSS blockquote',
            -anchor      => 'w',
        )->grid(
            -row    => 2,
            -column => 1,
            -padx   => 1,
            -pady   => 2,
            -sticky => 'w'
        );

        # Anchor will be of the form Footnote_3 rather than Footnote_3_3
        $f0->Checkbutton(
            -variable    => \$::lglobal{shorthtmlfootnotes},
            -selectcolor => $::lglobal{checkcolor},
            -text        => 'Short FN Anchors',
            -anchor      => 'w',
        )->grid(
            -row    => 2,
            -column => 2,
            -padx   => 1,
            -pady   => 2,
            -sticky => 'w'
        );

        # Automatically convert 1/2, 1/4, 3/4 to entities
        $f0->Checkbutton(
            -variable    => \$::lglobal{autofraction},
            -selectcolor => $::lglobal{checkcolor},
            -text        => 'Convert Fractions',
            -anchor      => 'w',
        )->grid(
            -row    => 2,
            -column => 3,
            -padx   => 1,
            -pady   => 2,
            -sticky => 'w'
        );

        my $f7 = $::lglobal{htmlgenpop}->Frame->pack( -side => 'top', -anchor => 'n' );

        # Find & format poetry line numbers consisting of digits spaced beyond end of line
        $f7->Checkbutton(
            -variable    => \$::lglobal{poetrynumbers},
            -selectcolor => $::lglobal{checkcolor},
            -text        => 'Find and Format Poetry Line Numbers'
        )->grid( -row => 1, -column => 1, -pady => 2 );

        my $f4 = $::lglobal{htmlgenpop}->Frame->pack( -side => 'top', -anchor => 'n' );

        # HTML to use when converting <i> markup
        $f4->Label( -text => '<i>:', )->grid( -row => 1, -column => 0, -padx => 2, -pady => 2 );
        $f4->Radiobutton(
            -text        => '<i>',
            -selectcolor => $::lglobal{checkcolor},
            -variable    => \$::lglobal{html_i},
            -value       => '<i>',
        )->grid( -row => 1, -column => 1 );
        $f4->Radiobutton(
            -text        => '<em>',
            -selectcolor => $::lglobal{checkcolor},
            -variable    => \$::lglobal{html_i},
            -value       => '<em>',
        )->grid( -row => 1, -column => 2 );
        $f4->Radiobutton(
            -text        => '<em class>',
            -selectcolor => $::lglobal{checkcolor},
            -variable    => \$::lglobal{html_i},
            -value       => '<em class="italic">',
        )->grid( -row => 1, -column => 3 );
        $f4->Radiobutton(
            -text        => '<span class>',
            -selectcolor => $::lglobal{checkcolor},
            -variable    => \$::lglobal{html_i},
            -value       => '<span class="italic">',
        )->grid( -row => 1, -column => 4 );

        # HTML to use when converting <b> markup
        $f4->Label( -text => '<b>:', )->grid( -row => 2, -column => 0, -padx => 2, -pady => 2 );
        $f4->Radiobutton(
            -text        => '<b>',
            -selectcolor => $::lglobal{checkcolor},
            -variable    => \$::lglobal{html_b},
            -value       => '<b>',
        )->grid( -row => 2, -column => 1 );
        $f4->Radiobutton(
            -text        => '<em>',
            -selectcolor => $::lglobal{checkcolor},
            -variable    => \$::lglobal{html_b},
            -value       => '<em>',
        )->grid( -row => 2, -column => 2 );
        $f4->Radiobutton(
            -text        => '<em class>',
            -selectcolor => $::lglobal{checkcolor},
            -variable    => \$::lglobal{html_b},
            -value       => '<em class="bold">',
        )->grid( -row => 2, -column => 3 );
        $f4->Radiobutton(
            -text        => '<span class>',
            -selectcolor => $::lglobal{checkcolor},
            -variable    => \$::lglobal{html_b},
            -value       => '<span class="bold">',
        )->grid( -row => 2, -column => 4 );

        # HTML to use when converting <g> markup
        $f4->Label( -text => '<g>:', )->grid( -row => 3, -column => 0, -padx => 2, -pady => 2 );
        $f4->Radiobutton(
            -text        => 'ign.',
            -selectcolor => $::lglobal{checkcolor},
            -variable    => \$::lglobal{html_g},
            -value       => '<g>',
        )->grid( -row => 3, -column => 1 );
        $f4->Radiobutton(
            -text        => '<em>',
            -selectcolor => $::lglobal{checkcolor},
            -variable    => \$::lglobal{html_g},
            -value       => '<em>',
        )->grid( -row => 3, -column => 2 );
        $f4->Radiobutton(
            -text        => '<em class>',
            -selectcolor => $::lglobal{checkcolor},
            -variable    => \$::lglobal{html_g},
            -value       => '<em class="gesperrt">',
        )->grid( -row => 3, -column => 3 );
        $f4->Radiobutton(
            -text        => '<span class>',
            -selectcolor => $::lglobal{checkcolor},
            -variable    => \$::lglobal{html_g},
            -value       => '<span class="gesperrt">',
        )->grid( -row => 3, -column => 4 );

        # HTML to use when converting <f> markup
        $f4->Label( -text => '<f>:', )->grid( -row => 4, -column => 0, -padx => 2, -pady => 2 );
        $f4->Radiobutton(
            -text        => 'ign.',
            -selectcolor => $::lglobal{checkcolor},
            -variable    => \$::lglobal{html_f},
            -value       => '<f>',
        )->grid( -row => 4, -column => 1 );
        $f4->Radiobutton(
            -text        => '<em>',
            -selectcolor => $::lglobal{checkcolor},
            -variable    => \$::lglobal{html_f},
            -value       => '<em>',
        )->grid( -row => 4, -column => 2 );
        $f4->Radiobutton(
            -text        => '<em class>',
            -selectcolor => $::lglobal{checkcolor},
            -variable    => \$::lglobal{html_f},
            -value       => '<em class="antiqua">',
        )->grid( -row => 4, -column => 3 );
        $f4->Radiobutton(
            -text        => '<span class>',
            -selectcolor => $::lglobal{checkcolor},
            -variable    => \$::lglobal{html_f},
            -value       => '<span class="antiqua">',
        )->grid( -row => 4, -column => 4 );

        my $f2 = $::lglobal{htmlgenpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        $f2->Button(
            -activebackground => $::activecolor,
            -command => sub { htmlautoconvert( $textwindow, $top, $htmltitle, $htmlauthor ) },
            -text    => 'Autogenerate HTML',
            -width   => 16
        )->grid( -row => 1, -column => 1, -padx => 5, -pady => 1 );

        ::initialize_popup_with_deletebinding('htmlgenpop');
    }
}

#
# Create the HTML markup dialog
sub htmlmarkpopup {
    my ( $textwindow, $top ) = ( $::textwindow, $::top );
    ::operationadd('Begin HTML Markup');
    ::hidepagenums();
    if ( defined( $::lglobal{markpop} ) ) {
        $::lglobal{markpop}->deiconify;
        $::lglobal{markpop}->raise;
        $::lglobal{markpop}->focus;
    } else {
        $::lglobal{markpop} = $top->Toplevel;
        $::lglobal{markpop}->title('HTML Markup');
        my $tableformat;

        # Markup buttons
        my $lf1 = $::lglobal{markpop}->LabFrame( -label => 'Markup' )
          ->pack( -side => 'top', -anchor => 'n', -expand => 'yes', -fill => 'x' );
        my $f1 = $lf1->Frame->pack( -side => 'top', -anchor => 'n' );
        my ( $inc, $row, $col ) = ( 0, 0, 0 );

        for (
            qw/
            em    strong i   b     big small
            h1    h2     h3  h4    h5  h6
            table tr     td  ol    ul  li
            sup   sub    ins del   q   cite
            p     hr     br  blkq  pre nbsp
            /
        ) {
            $col = $inc % 6;
            $row = int $inc / 6;
            my $mbtn = $f1->Button(
                -activebackground => $::activecolor,
                -command          => [
                    sub {
                        markup( $textwindow, $top, $_[0], $::htmlentryattribhash{ $_[0] } );
                    },
                    $_
                ],
                -text  => ( $_ eq "nbsp" ? "&$_;" : "<$_>" ),
                -width => 7
            )->grid(
                -row    => $row,
                -column => $col,
                -padx   => 1,
                -pady   => 1
            );
            markupbindconfig( $mbtn, $_ );
            ++$inc;
        }
        my $f5 = $lf1->Frame->pack( -side => 'top', -anchor => 'n', -pady => 8 );

        # Create rows with entry field and buttons for configurable div, span & i
        for my $row ( 1 .. @::htmlentry ) {
            my $col   = 1;
            my $entry = $f5->Entry(
                -width      => 23,
                -background => $::bkgcolor,
                -relief     => 'sunken',
            )->grid( -row => $row, -column => $col++, -padx => 1, -pady => 2 );
            $f5->Button(
                -activebackground => $::activecolor,
                -command          => sub {
                    ::entry_history( $entry, \@::htmlentryhistory );
                },
                -image  => $::lglobal{hist_img},
                -width  => 9,
                -height => 15,
            )->grid( -row => $row, -column => $col++, -padx => 0, -pady => 2 );
            my $ent = $row - 1;
            $entry->insert( 'end', $::htmlentry[$ent] );
            for (qw / div span i /) {
                $f5->Button(
                    -activebackground => $::activecolor,
                    -command          => [
                        sub {
                            $::htmlentry[$ent] = $entry->get;
                            ::add_entry_history( $::htmlentry[$ent], \@::htmlentryhistory );
                            markup( $textwindow, $top, "$_[0]", $::htmlentry[$ent] );
                        },
                        $_
                    ],
                    -text  => "$_",
                    -width => 7
                )->grid( -row => $row, -column => $col++, -padx => 1, -pady => 2 );
            }
        }

        my $lf2 = $::lglobal{markpop}->LabFrame( -label => 'Links' )
          ->pack( -side => 'top', -anchor => 'n', -expand => 'yes', -fill => 'x' );

        my $f2       = $lf2->Frame->pack( -side => 'top', -anchor => 'n' );
        my @hbuttons = (
            [ 'Internal Link', 'ilink' ],
            [ 'External Link', 'elink' ],
            [ 'Anchor',        'anchor' ],
            [ 'Image',         'img' ],
        );

        ( $row, $col ) = ( 0, 0 );
        for (@hbuttons) {
            my $marktype = $hbuttons[$col][1];
            my $mbtn     = $f2->Button(
                -activebackground => $::activecolor,
                -command          => [
                    sub {
                        markup( $textwindow, $top, $marktype, $::htmlentryattribhash{$marktype} );
                    }
                ],
                -text  => "$hbuttons[$col][0]",
                -width => 11
            )->grid(
                -row    => $row,
                -column => $col,
                -padx   => 1,
                -pady   => 2
            );
            markupbindconfig( $mbtn, $marktype );
            ++$col;
        }

        my $lf3 = $::lglobal{markpop}->LabFrame( -label => 'Lists' )
          ->pack( -side => 'top', -anchor => 'n', -expand => 'yes', -fill => 'x' );
        my $unorderselect = $lf3->Radiobutton(
            -text        => 'unordered',
            -selectcolor => $::lglobal{checkcolor},
            -variable    => \$::lglobal{liststyle},
            -value       => 'ul',
        )->pack( -side => 'left', -anchor => 'w', -padx => 4, -pady => 2 );
        my $orderselect = $lf3->Radiobutton(
            -text        => 'ordered',
            -selectcolor => $::lglobal{checkcolor},
            -variable    => \$::lglobal{liststyle},
            -value       => 'ol',
        )->pack( -side => 'left', -anchor => 'w', -padx => 4, -pady => 2 );
        $unorderselect->select;
        $lf3->Checkbutton(
            -text     => 'ML',
            -variable => \$::lglobal{list_multiline},
            -onvalue  => 1,
            -offvalue => 0
        )->pack( -side => 'right', -anchor => 'e', -padx => 4, -pady => 2 );
        my $autolbutton = $lf3->Button(
            -activebackground => $::activecolor,
            -command          => sub { autolist($textwindow); $textwindow->focus },
            -text             => 'Auto List',
            -width            => 12
        )->pack( -side => 'right', -anchor => 'e', -padx => 4, -pady => 2 );

        my $lf4 = $::lglobal{markpop}->LabFrame( -label => 'Tables' )
          ->pack( -side => 'top', -anchor => 'n', -expand => 'yes', -fill => 'x' );
        my $f4a =
          $lf4->Frame->pack( -side => 'top', -anchor => 'n', -expand => 'yes', -fill => 'x' );
        $f4a->Label( -text => 'Column Format:', )
          ->pack( -side => 'left', -anchor => 'n', -padx => 4, -pady => 2 );
        $tableformat = $f4a->Entry(
            -background => $::bkgcolor,
            -relief     => 'sunken',
        )->pack(
            -side   => 'left',
            -anchor => 'n',
            -padx   => 4,
            -pady   => 2,
            -expand => 'yes',
            -fill   => 'x'
        );
        my $f4b =
          $lf4->Frame->pack( -side => 'top', -anchor => 'n', -expand => 'yes', -fill => 'x' );
        my $leftselect = $f4b->Radiobutton(
            -text        => 'left',
            -selectcolor => $::lglobal{checkcolor},
            -variable    => \$::lglobal{tablecellalign},
            -value       => ' class="tdl"',
        )->pack( -side => 'left', -anchor => 'n', -padx => 4, -pady => 2 );
        my $censelect = $f4b->Radiobutton(
            -text        => 'center',
            -selectcolor => $::lglobal{checkcolor},
            -variable    => \$::lglobal{tablecellalign},
            -value       => ' class="tdc"',
        )->pack( -side => 'left', -anchor => 'n', -padx => 4, -pady => 2 );
        my $rghtselect = $f4b->Radiobutton(
            -text        => 'right',
            -selectcolor => $::lglobal{checkcolor},
            -variable    => \$::lglobal{tablecellalign},
            -value       => ' class="tdr"',
        )->pack( -side => 'left', -anchor => 'n', -padx => 4, -pady => 2 );
        $leftselect->select;
        $f4b->Checkbutton(
            -text     => 'ML',
            -variable => \$::lglobal{tbl_multiline},
            -onvalue  => 1,
            -offvalue => 0
        )->pack( -side => 'right', -anchor => 'n', -padx => 4, -pady => 2 );
        $f4b->Button(
            -activebackground => $::activecolor,
            -command          => sub {
                autotable( $textwindow, $tableformat->get );
                $textwindow->focus;
            },
            -text  => 'Auto Table',
            -width => 12
        )->pack( -side => 'right', -anchor => 'n', -padx => 4, -pady => 2 );

        my $f7 = $::lglobal{markpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        $f7->Button(
            -activebackground => $::activecolor,
            -command          => \&poetryhtml,
            -text             => 'Apply Poetry Markup to Sel.',
            -width            => 24
        )->grid( -row => 1, -column => 1, -padx => 1, -pady => 2 );
        $f7->Button(
            -activebackground => $::activecolor,
            -command          => \&hyperlinkpagenums,
            -text             => 'Hyperlink Page Nums',
            -width            => 24
        )->grid( -row => 1, -column => 2, -padx => 1, -pady => 2 );

        my $f3 = $::lglobal{markpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        $f3->Button(
            -activebackground => $::activecolor,
            -command          => sub { clearmarkupinselection() },
            -text             => 'Remove Markup from Selection',
            -width            => 24
        )->grid( -row => 1, -column => 1, -padx => 1, -pady => 2 );
        $f3->Button(
            -activebackground => $::activecolor,
            -command          => sub {
                for my $orphan (
                    'i',          'b',    'u',      'center', 'sub',   'sup',
                    'h1',         'h2',   'h3',     'h4',     'h5',    'h6',
                    'p',          'em',   'strong', 'big',    'small', 'q',
                    'blockquote', 'cite', 'pre',    'del',    'ins',
                ) {
                    ::working( 'Checking <' . $orphan . '>' );
                    last if orphans($orphan);
                }
                ::working();
            },
            -text  => 'Find Some Orphaned Markup',
            -width => 24
        )->grid( -row => 1, -column => 2, -padx => 1, -pady => 2 );

        ::initialize_popup_with_deletebinding('markpop');
    }
}

#
# Configure Mouse-3 and Ctrl/Meta Mouse-1 to pop a dialog to set class/attributes for given button
# Also, if button has attributes set, append a plus sign to its button label
sub markupbindconfig {
    my $w   = shift;
    my $typ = shift;

    return if $typ eq 'nbsp' or $typ eq 'img';

    $w->eventAdd( '<<config>>' => '<ButtonRelease-3>' );
    $w->eventAdd( '<<config>>' => '<Control-ButtonRelease-1>' );
    $w->eventAdd( '<<config>>' => '<Meta-ButtonRelease-1>' ) if $::OS_MAC;
    $w->bind( '<<config>>' => sub { markupconfig( $w, $typ ); } );

    # re-order bindings so that widget's binding precedes class binding
    # meaning we can break out of callbacks later before class callback is called
    my @tags = $w->bindtags;
    $w->bindtags( [ @tags[ 1, 0, 2, 3 ] ] );

    markupconfiglabel( $w, $typ );    # Adjust label to show presence of class/attributes
}

#
# Pop a config dialog to set class/attributes for given button
sub markupconfig {
    my $w   = shift;
    my $typ = shift;

    $::lglobal{markupconfigpop} = $w->DialogBox(
        -buttons => [qw[OK Cancel]],
        -title   => "Configure Attributes for <$typ>",
        -popover => 'cursor',
        -command => sub {
            my $btn = shift;
            $w->invoke if $btn and $btn eq 'OK';    # invoke the button widget we are configuring
            ::killpopup('markupconfigpop');
        }
    );
    $::htmlentryattribhash{$typ} //= '';            # Avoid settings file being written with this variable undefined
    ::dialogboxcommonsetup(
        'markupconfigpop',
        \$::htmlentryattribhash{$typ},
        'Class name or attributes: '
    );

    markupconfiglabel( $w, $typ );                  # Adjust label to show presence of class/attributes

    ::savesettings();                               # Ensure new definition gets saved in setting file

    # stop class callback being called - possible due to binding reordering in markupbindconfig
    $w->break;
}

#
# Configure given widget's label to have a plus sign appended (or not) if class name/attributes set
sub markupconfiglabel {
    my $w   = shift;
    my $typ = shift;

    my $label = $w->cget( -text );
    if ( $::htmlentryattribhash{$typ} ) {
        $label =~ s/\+*$/+/;    # Ensure button ends in just one plus sign
    } else {
        $label =~ s/\+*$//;     # Remove any plus signs
    }
    $w->configure( -text => $label );
}

#
# Add markup of the given type
sub markup {
    my $textwindow = shift;
    my $top        = shift;
    my $mark       = shift;
    my $attr       = shift;

    # User may have configured additional class/attributes
    if ($attr) {
        $attr = "class=\"$attr\"" if $attr =~ /^[-_\w]+$/;           # expand classname to class="classname"
        $attr = " " . $attr       if substr( $attr, 0, 1 ) ne " ";
    } else {
        $attr = "";
    }

    ::hidepagenums();
    ::savesettings();
    my @ranges = $textwindow->tagRanges('sel');

    unless (@ranges) {
        push @ranges, $textwindow->index('insert');
        push @ranges, $textwindow->index('insert');
    }
    my $range_total = @ranges;
    my $done        = '';
    my @intanchors;
    return unless $range_total;
    my $end            = pop(@ranges);
    my $start          = pop(@ranges);
    my $thisblockstart = $start;
    my $thisblockend   = $end;
    my $selection;
    my $closure = voidclosure();

    $mark = "blockquote" if $mark eq "blkq";    # shortened form for button label

    if ( $mark eq 'br' ) {
        my ( $lsr, $lsc, $ler, $lec, $step );
        ( $lsr, $lsc ) = split /\./, $thisblockstart;
        ( $ler, $lec ) = split /\./, $thisblockend;
        if ( $lsr eq $ler ) {
            $textwindow->insert( 'insert', "<br$attr$closure" );
        } else {
            $step = $lsr;
            while ( $step <= $ler ) {
                $selection = $textwindow->get( "$step.0", "$step.end" );
                $selection =~ s/<br.*?>//g;
                $textwindow->insert( "$step.end", "<br$attr$closure" );
                $step++;
            }
        }
    } elsif ( $mark eq 'hr' ) {
        $textwindow->insert( 'insert', "<hr$attr$closure" );
    } elsif ( $mark eq 'nbsp' ) {
        my ( $lsr, $lsc, $ler, $lec, $step );
        ( $lsr, $lsc ) = split /\./, $thisblockstart;
        ( $ler, $lec ) = split /\./, $thisblockend;
        if ( $lsr eq $ler ) {
            $textwindow->insert( 'insert', '&#160;' );
        } else {
            $step = $lsr;
            while ( $step <= $ler ) {
                $selection = $textwindow->get( "$step.0", "$step.end" );
                if ( $selection =~ /\s\s/ ) {
                    $selection =~ s/^\s/&#160;/;
                    $selection =~ s/  /&#160; /g;
                    $selection =~ s/&#160; /&#160;&#160;/g;
                    $textwindow->delete( "$step.0", "$step.end" );
                    $textwindow->insert( "$step.0", $selection );
                }
                $step++;
            }
        }
    } elsif ( $mark eq 'img' ) {
        $::lglobal{imarkupstart} = $thisblockstart;
        $::lglobal{imarkupend}   = $thisblockend;
        htmlimage();
    } elsif ( $mark eq 'elink' ) {
        my ( $name, $tempname );
        $name = '';
        if ( $::lglobal{elinkpop} ) {
            $::lglobal{elinkpop}->deiconify;
        } else {
            $::lglobal{elinkpop} = $top->Toplevel;
            $::lglobal{elinkpop}->title('External Link');
            ::initialize_popup_with_deletebinding('elinkpop');
            $::lglobal{elinkpop}->resizable( 'yes', 'no' );
            my $linkf1 = $::lglobal{elinkpop}->Frame->pack(
                -side   => 'top',
                -anchor => 'n',
                -expand => 'yes',
                -fill   => 'x',
                -padx   => 10,
                -pady   => 4
            );
            my $linklabel = $linkf1->Label( -text => 'Link name' )->pack;
            $::lglobal{linkentry} =
              $linkf1->Entry( -background => $::bkgcolor )->pack( -expand => 'yes', -fill => 'x' );
            my $linkf2    = $::lglobal{elinkpop}->Frame->pack( -side => 'top', -anchor => 'n' );
            my $extbrowse = $linkf2->Button(
                -activebackground => $::activecolor,
                -text             => 'Browse',
                -width            => 16,
                -command          => sub {
                    $name = $::lglobal{elinkpop}->getOpenFile( -title => 'File Name?' );
                    if ($name) {
                        $::lglobal{linkentry}->delete( 0, 'end' );
                        $::lglobal{linkentry}->insert( 'end', $name );
                    }
                }
            )->pack( -side => 'left', -pady => 4 );
            my $linkf3 = $::lglobal{elinkpop}->Frame->pack( -side => 'top', -anchor => 'n' );
            my $okbut  = $linkf3->Button(
                -activebackground => $::activecolor,
                -text             => 'OK',
                -width            => 16,
                -command          => sub {
                    $name = $::lglobal{linkentry}->get;
                    if ($name) {
                        $name =~ s/[\/\\]/;/g;
                        $tempname = $::globallastpath;
                        $tempname =~ s/[\/\\]/;/g;
                        $name     =~ s/$tempname//;
                        $name     =~ s/;/\//g;
                        $textwindow->insert( $thisblockend,   "</a>" );
                        $textwindow->insert( $thisblockstart, "<a href=\"$name\"$attr>" );
                    }
                    ::killpopup('elinkpop');
                }
            )->pack( -pady => 4 );
            $::lglobal{linkentry}->focus;
        }
        $done = '';
    } elsif ( $mark eq 'ilink' ) {
        my ( $anchorname, $anchorstartindex, $anchorendindex, $length,
            $srow, $scol, $string, $link, $match, $match2 );
        $length     = 0;
        @intanchors = ();
        my %inthash = ();
        $anchorstartindex = $anchorendindex = '1.0';
        while (
            $anchorstartindex = $textwindow->search(
                '-regexp',
                '-count' => \$length,
                '--',
                '(name|id)=[\'"].+?[\'"]',
                $anchorendindex, 'end'
            )
        ) {
            $anchorendindex = $textwindow->index( $anchorstartindex . ' +' . $length . 'c' );
            $string         = $textwindow->get( $anchorstartindex, $anchorendindex );
            $string =~ m/=['"](.+?)['"]/;
            $match = $1;
            push @intanchors, '#' . $match;
            $match2 = $match;

            if ( exists $inthash{ '#' . ( lc($match) ) } ) {
                $textwindow->tagAdd( 'highlight', $anchorstartindex, $anchorendindex );
                $textwindow->see($anchorstartindex);
                ::soundbell();
                $top->messageBox(
                    -icon    => 'error',
                    -message => "More than one instance of the anchor $match2 in text.",
                    -title   => 'Duplicate anchor names.',
                    -type    => 'Ok',
                );
                return;
            } else {
                $inthash{ '#' . ( lc($match) ) } = '#' . $match2;
            }
        }
        my ( $name, $tempname );
        $name = '';
        if ( $::lglobal{linkpop} ) {
            $::lglobal{linkpop}->deiconify;
        } else {
            my $linklistbox;
            $selection = $textwindow->get( $thisblockstart, $thisblockend );
            return unless length($selection);
            $::lglobal{linkpop} = $top->Toplevel;
            $::lglobal{linkpop}->title('Internal Links');
            ::initialize_popup_with_deletebinding('linkpop');
            $::lglobal{fnlinks} = 1;
            my $tframe = $::lglobal{linkpop}->Frame->pack;
            $tframe->Checkbutton(
                -variable    => \$::lglobal{ilinksrt},
                -selectcolor => $::lglobal{checkcolor},
                -text        => 'Sort Alphabetically',
                -command     => sub {
                    $linklistbox->delete( '0', 'end' );
                    linkpopulate( $linklistbox, \@intanchors );
                },
            )->pack(
                -side   => 'left',
                -pady   => 2,
                -padx   => 2,
                -anchor => 'n'
            );
            $tframe->Checkbutton(
                -variable    => \$::lglobal{fnlinks},
                -selectcolor => $::lglobal{checkcolor},
                -text        => 'Hide Footnote Links',
                -command     => sub {
                    $linklistbox->delete( '0', 'end' );
                    linkpopulate( $linklistbox, \@intanchors );
                },
            )->pack(
                -side   => 'left',
                -pady   => 2,
                -padx   => 2,
                -anchor => 'n'
            );
            $tframe->Checkbutton(
                -variable    => \$::lglobal{pglinks},
                -selectcolor => $::lglobal{checkcolor},
                -text        => 'Hide Page Links',
                -command     => sub {
                    $linklistbox->delete( '0', 'end' );
                    linkpopulate( $linklistbox, \@intanchors );
                },
            )->pack(
                -side   => 'left',
                -pady   => 2,
                -padx   => 2,
                -anchor => 'n'
            );
            my $pframe = $::lglobal{linkpop}->Frame->pack( -fill => 'both', -expand => 'both' );
            $linklistbox = $pframe->Scrolled(
                'Listbox',
                -scrollbars  => 'se',
                -background  => $::bkgcolor,
                -selectmode  => 'single',
                -activestyle => 'none',
            )->pack(
                -side   => 'top',
                -anchor => 'nw',
                -fill   => 'both',
                -expand => 'both',
                -padx   => 2,
                -pady   => 2
            );
            ::drag($linklistbox);
            $linklistbox->eventAdd( '<<trans>>' => '<Double-Button-1>' );
            $linklistbox->bind(
                '<<trans>>',
                sub {
                    $name = $linklistbox->get('active');
                    $textwindow->insert( $thisblockend,   "</a>" );
                    $textwindow->insert( $thisblockstart, "<a href=\"$name\"$attr>" );
                    ::killpopup('linkpop');
                }
            );
            my $tempvar   = lc( makeanchor( ::deaccentdisplay($selection) ) );
            my $flag      = 0;
            my @entrarray = split( /_/, $tempvar );
            $entrarray[1] = '@' unless $entrarray[1];
            $entrarray[2] = '@' unless $entrarray[2];
            for ( sort (@intanchors) ) {
                last unless $tempvar;
                next
                  if (
                    ( ( $_ =~ /#$::htmllabels{fnlabel}/ ) || ( $_ =~ /#$::htmllabels{fnanchor}/ ) )
                    && $::lglobal{fnlinks} );
                next
                  if ( ( $_ =~ /#$::htmllabels{pglabel}/ ) && $::lglobal{pglinks} );
                next unless ( lc($_) eq '#' . $tempvar );
                $linklistbox->insert( 'end', $_ );
                $flag++;
            }
            $linklistbox->insert( 'end', '  ' );

            if ( $entrarray[1] && ( $entrarray[1] ne '@' ) ) {
                $entrarray[0] = '@'
                  if ( $entrarray[0] =~ /^to$|^a$|^the$|^and$/ );
                $entrarray[1] = '@'
                  if ( $entrarray[1] =~ /^to$|^a$|^the$|^and$/ );
                $entrarray[2] = '@'
                  if ( $entrarray[2] =~ /^to$|^a$|^the$|^and$/ );
            }
            for ( sort (@intanchors) ) {
                next
                  if (
                    ( ( $_ =~ /#$::htmllabels{fnlabel}/ ) || ( $_ =~ /#$::htmllabels{fnanchor}/ ) )
                    && $::lglobal{fnlinks} );

                next
                  if ( ( $_ =~ /#$::htmllabels{pglabel}/ ) && $::lglobal{pglinks} );
                next
                  unless ( $entrarray[0]
                    and lc($_) =~ /\Q$entrarray[0]\E|\Q$entrarray[1]\E|\Q$entrarray[2]\E/ );
                $linklistbox->insert( 'end', $_ );
                $flag++;
            }
            $linklistbox->insert( 'end', "  " );
            $flag = 0;
            linkpopulate( $linklistbox, \@intanchors );
            $linklistbox->focus;
        }
    } elsif ( $mark eq 'anchor' ) {
        my $linkname;
        $selection = $textwindow->get( $thisblockstart, $thisblockend )
          || '';
        $linkname = makeanchor( ::deaccentdisplay($selection) ) || '';
        $textwindow->insert( $thisblockstart, "<a id=\"$linkname\"$attr></a>" );
    } elsif ( $mark =~ /h\d/ ) {
        $selection = $textwindow->get( $thisblockstart, $thisblockend );
        if ( $selection =~ s/<\/?p>//g ) {
            $textwindow->delete( $thisblockstart, $thisblockend );
            $textwindow->tagRemove( 'sel', '1.0', 'end' );
            $textwindow->markSet( 'blkend', $thisblockstart );
            $textwindow->insert( $thisblockstart, "<$mark$attr>$selection</$mark>" );
            $textwindow->tagAdd( 'sel', $thisblockstart, $textwindow->index('blkend') );
        } else {
            $textwindow->insert( $thisblockend,   "</$mark>" );
            $textwindow->insert( $thisblockstart, "<$mark$attr>" );
        }
    } else {
        $textwindow->insert( $thisblockend,   "</$mark>" );
        $textwindow->insert( $thisblockstart, "<$mark$attr>" );
    }
    $textwindow->focus unless $mark eq 'elink' or $mark eq 'ilink';
}

sub clearmarkupinselection {
    my ( $textwindow, $top ) = ( $::textwindow, $::top );
    ::hidepagenums();
    my @ranges = $textwindow->tagRanges('sel');
    unless (@ranges) {
        push @ranges, $textwindow->index('insert');
        push @ranges, $textwindow->index('insert');
    }
    my $range_total = @ranges;
    return unless $range_total;

    #my $open           = 0;
    #my $close          = 0;
    $textwindow->addGlobStart;
    while (@ranges) {
        my $end            = pop(@ranges);
        my $start          = pop(@ranges);
        my $thisblockstart = $start;
        my $thisblockend   = $end;
        my ( $lsr, $lsc, $ler, $lec, $step, $edited, $selection, $selectionend );
        ( $lsr, $lsc ) = split( /\./, $thisblockstart );
        ( $ler, $lec ) = split( /\./, $thisblockend );
        $step = $lsr;
        my $stepend = 'end';

        while ( $step <= $ler ) {
            $lsc       = 0    if ( $step > $lsr );
            $stepend   = $lec if ( $step == $ler );
            $selection = $textwindow->get( "$step.$lsc", "$step.$stepend" );
            $edited++ if ( $selection =~ s/<\/td>/  /g );
            $edited++ if ( $selection =~ s/<\/?body>//g );
            $edited++ if ( $selection =~ s/<br.*?>//g );
            $edited++ if ( $selection =~ s/<\/?div[^>]*?>//g );
            $edited++
              if ( $selection =~ s/<span.*?margin-left: (\d+\.?\d?)em.*?>/' ' x ($1 *2)/e );
            $edited++ if ( $selection =~ s/<\/?span[^>]*?>//g );
            $edited++ if ( $selection =~ s/<\/?[hscalupt].*?>//g );
            $edited++ if ( $selection =~ s/&#160;/ /g );
            $edited++ if ( $selection =~ s/<\/?blockquote>//g );
            $textwindow->delete( "$step.$lsc", "$step.$stepend" ) if $edited;
            $textwindow->insert( "$step.$lsc", $selection )       if $edited;
            $step++;
            unless ( $step % 25 ) { $textwindow->update }
        }
        if ( $lsr == $ler ) {
            $selectionend = "$ler." . ( $lsc + length($selection) );
        } else {
            $selectionend = "$ler." . length($selection);
        }
        $textwindow->tagAdd( 'sel', $start, $selectionend ) if $range_total == 2;
    }
    $textwindow->addGlobEnd;

    #if ( $open != $close ) { # never implemented?
    #	$top->messageBox(
    #		-icon => 'error',
    #		-message =>
    #	"Mismatching open and close markup removed.\nYou may have orphaned markup.",
    #		-title => 'Mismatching markup.',
    #		-type  => 'Ok',
    #	);
    #}
}

sub hyperlinkpagenums {
    ::searchpopup();
    ::searchoptset(qw/0 x x 1/);
    $::lglobal{searchentry}->insert( 'end', "(?<!\\d)(\\d{1,3})" );
    $::lglobal{replaceentry}->insert( 'end', "<a href=\"#$::htmllabels{pglabel}\$1\">\$1</a>" );
}

sub makeanchor {
    my $linkname = shift;
    return unless $linkname;
    $linkname =~ s/-/\x00/g;             # preserve hyphens
    $linkname =~ s/_/\x01/g;             # preserve underscores
    $linkname =~ s/&amp;/\xFF/;
    $linkname =~ s/<sup>.*?<\/sup>//g;
    $linkname =~ s/<\/?[^>]+>//g;
    $linkname =~ s/\p{Punct}//g;
    $linkname =~ s/\x00/-/g;             # restore hyphens
    $linkname =~ s/\x01/_/g;             # restore underscores
    $linkname =~ s/\s+/_/g;

    while ( $linkname =~ m/([\x{100}-\x{ffef}])/ ) {
        my $char     = "$1";
        my $ord      = ord($char);
        my $phrase   = charnames::viacode($ord);
        my $case     = 'lc';
        my $notlatin = 1;
        $phrase   = '-X-' unless ( $phrase and $phrase =~ /(LETTER|DIGIT|LIGATURE)/ );
        $case     = 'uc' if $phrase =~ /CAPITAL|^-X-$/;
        $notlatin = 0    if $phrase =~ /LATIN/;
        $phrase =~ s/.+(LETTER|DIGIT|LIGATURE) //;
        $phrase =~ s/ WITH.+//;
        $phrase = lc($phrase) if $case eq 'lc';
        $phrase =~ s/ /_/g;
        $phrase = "-$phrase-" if $notlatin;
        $linkname =~ s/$char/$phrase/g;
    }
    $linkname =~ s/--+/-/g;
    $linkname =~ s/[\x90-\xff\x20\x22]/_/g;
    $linkname =~ s/__+/_/g;
    $linkname =~ s/^[_-]+|[_-]+$//g;
    return $linkname;
}

# Return the start and end rows of the selected text
# If end selection is at start of line, return previous row
sub getselrows {
    my $textwindow = shift;

    # get selected range - if none, current insert point is start & end
    my @ranges = $textwindow->tagRanges('sel');
    unless (@ranges) {
        push @ranges, $textwindow->index('insert');
        push @ranges, $textwindow->index('insert');
    }

    # split end & start into row & column
    my ( $ler, $lec ) = split /\./, pop(@ranges);
    my ( $lsr, $lsc ) = split /\./, pop(@ranges);

    # if no text selected on final row, then end at previous row
    --$ler if ( $lec == 0 and $ler > $lsr );
    return ( $lsr, $ler );
}

# Create an index from selected region using <ul> and <li> markup and classes
sub autoindex {
    my $textwindow = shift;
    ::hidepagenums();
    my ( $lsr, $ler ) = getselrows($textwindow);

    $textwindow->addGlobStart;
    my $step   = $lsr;
    my $blanks = 0;
    my $first  = 1;
    my $indent = 0;

    while ( $textwindow->get( "$step.0", "$step.end" ) eq '' ) {
        $step++;
    }
    while ( $step <= $ler ) {
        my $selection = $textwindow->get( "$step.0", "$step.end" );
        unless ($selection) { $step++; $blanks++; next }
        $selection = addpagelinks($selection);
        if ( $first == 1 ) { $blanks = 2; $first = 0 }
        if ( $blanks == 2 ) {
            $selection = '<li class="ifrst">' . $selection . '</li>';
            $first     = 0;
        }
        if ( $blanks == 1 ) {
            $selection = '<li class="indx">' . $selection . '</li>';
        }
        if ( $selection =~ /^(\s+)/ ) {
            $indent = ( int( ( length($1) + 1 ) / 2 ) );
            $selection =~ s/^\s+//;
            $selection = '<li class="isub' . $indent . '">' . $selection . '</li>';
        }
        $textwindow->delete( "$step.0", "$step.end" );
        $selection =~ s/<li<\/li>//;
        $textwindow->insert( "$step.0", $selection );
        $blanks = 0;
        $step++;
    }
    $textwindow->insert( "$ler.end", "\n</ul>\n" );
    $textwindow->insert( "$lsr.0",   "<ul class=\"index\">\n" );
    $textwindow->addGlobEnd;
}

# Create a list from selected region using basic <ul>/<ol> and <li> markup
sub autolist {
    my $textwindow = shift;
    ::hidepagenums();
    my ( $lsr, $ler ) = getselrows($textwindow);

    $textwindow->addGlobStart;

    # Multiline means list entries are separated by double newlines
    if ( $::lglobal{list_multiline} ) {
        my $selection = $textwindow->get( "$lsr.0", "$ler.end" );

        # Split at double newline
        $selection =~ s/\n +/\n/g;
        $selection =~ s/\n\n+/\x{8A}/g;
        my @lrows = split( /\x{8A}/, $selection );

        # Recombine with list markup added
        $selection = "<$::lglobal{liststyle}>";
        for (@lrows) {
            $selection .= "\n<li>$_</li>\n";
        }
        $selection .= "</$::lglobal{liststyle}>\n";

        $textwindow->delete( "$lsr.0", "$ler.end" );
        $textwindow->insert( "$lsr.0", $selection );

        # Not multiline - each line is a list entry, except
        # <p>...</p> counts as one entry, but <br> forces a new entry
    } else {
        my $paragraph = 0;
        my $brflag    = 0;
        my $step      = $lsr;
        while ( $step <= $ler ) {
            if ( my $selection = $textwindow->get( "$step.0", "$step.end" ) ) {

                # If <br> at end of previous line, need to restart list entry markup
                if ( $brflag and $selection !~ /<p>/ ) {    # not if about to start paragraph anyway
                    $selection = '<li>' . $selection;
                }
                $brflag = 0;

                # If <br>, end current list entry and restart another on next line, even if in paragraph
                if ( $selection =~ s/<br.*?>//g ) {
                    $selection = $selection . '</li>' unless ( $selection =~ /<\/li>/ );
                    $brflag    = 1;
                }

                # If a marked paragraph, just one set of list entry markup round whole paragraph
                # Otherwise, add list markup round any line that doesn't already have it
                $paragraph = 1 if ( $selection =~ s/<p>/<li>/g );
                unless ($paragraph) {
                    $selection = '<li>' . $selection  unless ( $selection =~ /<li>/ );
                    $selection = $selection . '</li>' unless ( $selection =~ /<\/li>/ );
                }
                $paragraph = 0 if ( $selection =~ s/<\/p>/<\/li>/g );

                $textwindow->delete( "$step.0", "$step.end" );
                $selection =~ s/<li><\/li>//;
                $textwindow->insert( "$step.0", $selection );
            }
            $step++;
        }
        $textwindow->insert( "$ler.end", "\n</$::lglobal{liststyle}>" );
        $textwindow->insert( "$lsr.0",   "<$::lglobal{liststyle}>\n" );
    }
    $textwindow->addGlobEnd;
}

# Create a table from selected region using <table> markup
sub autotable {
    my ( $textwindow, $format ) = @_;
    ::hidepagenums();
    my ( $lsr, $ler ) = getselrows($textwindow);

    my ( @tbl, @trows, @tlines, @twords );

    my $selection = $textwindow->get( "$lsr.0", "$ler.end" );
    $selection =~ s/<br.*?>//g;
    $selection =~ s/<\/?p>//g;
    $selection =~ s/\n[\s|]+\n/\n\n/g;
    $selection =~ s/^\n+//;

    # Multiline means rows are separated by double newline
    if ( $::lglobal{tbl_multiline} ) {
        $selection =~ s/\n\n+/\x{8A}/g;
        @trows = split( /\x{8A}/, $selection );
    } else {
        $selection =~ s/\n[\s|]*\n/\n/g;
        @trows = split( /\n/, $selection );
    }

    # Default to split cells at multiple spaces, but use | instead if any in table
    my $splitregex = qr/\s\s+/;
    $splitregex = qr/\|/ if ( $selection =~ /\|/ );    #

    # For each row in the table...
    my $row = 0;
    for my $trow (@trows) {
        @tlines = split( /\n/, $trow );

        # For each line in the file... (relevant in multiline case)
        for my $tline (@tlines) {
            @twords = split( $splitregex, $tline );

            # Load into 2D array
            for ( 0 .. $#twords ) {
                $tbl[$row][$_] .= "$twords[$_] ";
            }
        }
        $row++;
    }

    my @cformat = split( //, $format ) if ($format);

    $selection = '<table class="autotable">' . "\n";

    # Each row is a <tr>
    for my $row ( 0 .. $#tbl ) {
        $selection .= "<tr>\n";

        # Each element of row is a <td>
        for ( $tbl[$row] ) {
            my $cellcnt = 0;
            my $cellalign;
            while (@$_) {
                if ( $cformat[$cellcnt] ) {
                    if ( $cformat[$cellcnt] eq '>' ) {
                        $cellalign = ' class="tdr"';
                    } elsif ( $cformat[$cellcnt] eq '|' ) {
                        $cellalign = ' class="tdc"';
                    } else {
                        $cellalign = ' class="tdl"';
                    }
                } else {
                    $cellalign = $::lglobal{tablecellalign};
                }
                ++$cellcnt;
                $selection .= '<td' . $cellalign . '>' . ( shift @$_ ) . "</td>\n";
            }
        }
        $selection .= "</tr>\n";
    }
    $selection .= '</table>';
    $selection =~ s/<td[^>]+><\/td>//g;
    $selection =~ s/ +<\//<\//g;
    $selection =~ s/d> +/d>/g;
    $selection =~ s/ +/ /g;

    $textwindow->addGlobStart;
    $textwindow->replacewith( "$lsr.0", "$ler.end", $selection );
    $textwindow->addGlobEnd;
}

sub orphans {
    my $textwindow = $::textwindow;
    ::hidepagenums();
    my $br = shift;
    $textwindow->tagRemove( 'highlight', '1.0', 'end' );
    my ( $thisindex, $open, $close, $crow, $ccol, $orow, $ocol, @op );
    $open  = '<' . $br . '>|<' . $br . ' [^>]*>';
    $close = '<\/' . $br . '>';
    my $end = $textwindow->index('end');
    $thisindex = '1.0';
    my ( $lengtho, $lengthc );
    my $opindex = $textwindow->search(
        '-regexp',
        '-count' => \$lengtho,
        '--', $open, $thisindex, 'end'
    );
    push @op, $opindex;
    my $clindex = $textwindow->search(
        '-regexp',
        '-count' => \$lengthc,
        '--', $close, $thisindex, 'end'
    );
    return unless ( $clindex || $opindex );
    push @op, ( $clindex || $end );

    while ($opindex) {
        $opindex = $textwindow->search(
            '-regexp',
            '-count' => \$lengtho,
            '--', $open, $op[0] . '+1c', 'end'
        );
        if ($opindex) {
            push @op, $opindex;
        } else {
            push @op, $textwindow->index('end');
        }
        my $begin = $op[1];
        $begin   = 'end' unless $begin;
        $clindex = $textwindow->search(
            '-regexp',
            '-count' => \$lengthc,
            '--', $close, "$begin+1c", 'end'
        );
        if ($clindex) {
            push @op, $clindex;
        } else {
            push @op, $textwindow->index('end');
        }
        if ( $textwindow->compare( $op[1], '==', $op[3] ) ) {
            $textwindow->markSet( 'insert', $op[0] ) if $op[0];
            $textwindow->see( $op[0] )               if $op[0];
            $textwindow->tagAdd( 'highlight', $op[0], $op[0] . '+' . length($open) . 'c' );
            return 1;
        }
        if (   ( $textwindow->compare( $op[0], '<', $op[1] ) )
            && ( $textwindow->compare( $op[1], '<', $op[2] ) )
            && ( $textwindow->compare( $op[2], '<', $op[3] ) )
            && ( $op[2] ne $end )
            && ( $op[3] ne $end ) ) {
            $textwindow->update;
            $textwindow->focus;
            shift @op;
            shift @op;
            next;
        } elsif ( ( $textwindow->compare( $op[0], '<', $op[1] ) )
            && ( $textwindow->compare( $op[1], '>', $op[2] ) ) ) {
            $textwindow->markSet( 'insert', $op[2] ) if $op[2];
            $textwindow->see( $op[2] )               if $op[2];
            $textwindow->tagAdd( 'highlight', $op[2], $op[2] . ' +' . $lengtho . 'c' );
            $textwindow->tagAdd( 'highlight', $op[0], $op[0] . ' +' . $lengtho . 'c' );
            $textwindow->update;
            $textwindow->focus;
            return 1;
        } elsif ( ( $textwindow->compare( $op[0], '<', $op[1] ) )
            && ( $textwindow->compare( $op[2], '>', $op[3] ) ) ) {
            $textwindow->markSet( 'insert', $op[3] ) if $op[3];
            $textwindow->see( $op[3] )               if $op[3];
            $textwindow->tagAdd( 'highlight', $op[3], $op[3] . '+' . $lengthc . 'c' );
            $textwindow->tagAdd( 'highlight', $op[1], $op[1] . '+' . $lengthc . 'c' );
            $textwindow->update;
            $textwindow->focus;
            return 1;
        } elsif ( ( $textwindow->compare( $op[0], '>', $op[1] ) )
            && ( $op[0] ne $end ) ) {
            $textwindow->markSet( 'insert', $op[1] ) if $op[1];
            $textwindow->see( $op[1] )               if $op[1];
            $textwindow->tagAdd( 'highlight', $op[1], $op[1] . '+' . $lengthc . 'c' );
            $textwindow->tagAdd( 'highlight', $op[3], $op[3] . '+' . $lengtho . 'c' );
            $textwindow->update;
            $textwindow->focus;
            return 1;
        } else {
            if (   ( $op[3] eq $end )
                && ( $textwindow->compare( $op[2], '>', $op[0] ) ) ) {
                $textwindow->markSet( 'insert', $op[2] ) if $op[2];
                $textwindow->see( $op[2] )               if $op[2];
                $textwindow->tagAdd( 'highlight', $op[2], $op[2] . '+' . $lengthc . 'c' );
            }
            if (   ( $op[2] eq $end )
                && ( $textwindow->compare( $op[3], '>', $op[1] ) ) ) {
                $textwindow->markSet( 'insert', $op[3] ) if $op[3];
                $textwindow->see( $op[3] )               if $op[3];
                $textwindow->tagAdd( 'highlight', $op[3], $op[3] . '+' . $lengthc . 'c' );
            }
            if ( ( $op[1] eq $end ) && ( $op[2] eq $end ) ) {
                $textwindow->markSet( 'insert', $op[0] ) if $op[0];
                $textwindow->see( $op[0] )               if $op[0];
                $textwindow->tagAdd( 'highlight', $op[0], $op[0] . '+' . $lengthc . 'c' );
            }
            ::update_indicators();
            return 0;
        }
    }
    return 0;
}

#
# Apply poetry markup to selected region
# Copes with unindented poetry or where the whole poem is indented by 4 spaces
# One or more blank lines delimit stanzas
sub poetryhtml {
    my $textwindow = $::textwindow;
    ::hidepagenums();
    my @ranges      = $textwindow->tagRanges('sel');
    my $range_total = @ranges;
    return if ( $range_total == 0 );

    $textwindow->addGlobStart;
    my $end   = pop(@ranges);
    my $start = pop(@ranges);
    my ( $lsr, $lsc, $ler, $lec, $step, $ital, $bold, $smcap );
    ( $lsr, $lsc ) = split /\./, $start;
    ( $ler, $lec ) = split /\./, $end;
    $ital = $bold = $smcap = 0;    # Not in italics/bold/smcap at start of poem

    my $unindentedpoetry = ispoetryunindented( $textwindow, "$lsr.0", "$ler.end" );

    # Find end of existing CSS in case need to insert new classes
    my $cssend = $textwindow->search( '--', '</style', '1.0', 'end' );
    $cssend = $textwindow->search( '-backwards', '--', '}', $cssend, '10.0' ) if $cssend;
    $cssend = '75.0' unless $cssend;
    my ( $cssendr, $cssendc ) = split /\./, $cssend;
    $cssendr++;

    my $linesinstanza = 0;
    $step = $lsr;
    while ( $step <= $ler ) {
        my $selection = $textwindow->get( "$step.0", "$step.end" );

        # blank line - end of stanza if one has been started
        if ( $selection =~ /^$/ ) {
            if ( $linesinstanza > 0 and $step != $ler ) {
                $textwindow->insert( "$step.0", "  </div>\n  <div class=\"stanza\">" );
                $step++;    # allow for the additional newline
                $ler++;
                $linesinstanza = 0;    # starting fresh stanza
            }
            $textwindow->delete( "$step.0", "$step.0 + 1l" );    # Blank text line not needed in HTML code
            $ler--;                                              # So there's one less line to process
            next;
        }
        $selection =~ s/&#160;/ /g;
        my $indent = 0;
        $indent = length($1) if $selection =~ s/^(\s+)//;
        $textwindow->delete( "$step.0", "$step.$indent" ) if $indent;
        unless ($unindentedpoetry) {
            $indent -= 4;
        }    # rewrapped poetry automatically has indent of 4
        $indent = 0 if ( $indent < 0 );

        # italic/bold/smcap markup cannot span lines, so may need to close & re-open per line
        ( $ital, $bold, $smcap ) = domarkupperline( sub { $textwindow->insert(@_) },
            $textwindow, $step, $selection, $ital, $bold, $smcap );

        $textwindow->insert( "$step.0",   "    <div class=\"verse indent$indent\">" );
        $textwindow->insert( "$step.end", '</div>' );
        $linesinstanza++;

        # unless this class already defined, add it to end of CSS block
        my $classdef = ".poetry .indent$indent {text-indent: " . ( $indent / 2 - 3 ) . "em;}";
        unless ( $textwindow->search( '-backwards', '--', $classdef, "$cssendr.0", '0.0' ) ) {
            $textwindow->insert( "$cssendr.0", "$classdef\n" );

            # allow for additional line added to top of file
            $cssendr++;
            $step++;
            $ler++;
            $lsr++;
        }

        $step++;
    }

    $textwindow->insert( "$ler.end", "\n  </div>\n</div>\n</div>" );
    $textwindow->insert( "$lsr.0",
        "<div class=\"poetry-container\">\n<div class=\"poetry\">\n  <div class=\"stanza\">\n" );
    $textwindow->addGlobEnd;
}

# determine if poetry is not already indented by four spaces
sub ispoetryunindented {
    my ( $textwindow, $poetrystart, $poetryend ) = @_;

    # look for a line beginning with four characters, but not all spaces
    return (  $poetrystart
          and $poetryend
          and $textwindow->search( '-regexp', '--', '^(?!\\s{4}).{4}', $poetrystart, $poetryend ) );
}

# If italic/bold/smcap markup spans across end of line, we have to close
# at end of line and re-open at start of next.
# First argument is temporary sub that calls textwindow->insert/ntinsert

sub domarkupperline {
    my ( $insertfunc, $textwindow, $step, $selection, $ital, $bold, $smcap ) = @_;

    my @flags = ( $ital, $bold, $smcap );
    my @mrkps = ( "i", "b", "sc" );

    # Loop through each sort of markup
    for my $typ ( 0 .. 2 ) {

        # Find the last open & close markups of this type in the line
        my ( $op, $cl ) = ( -1, -1 );    # Default to not found
        $op = $-[$#-] if ( $selection =~ /(<$mrkps[$typ]>)/g );
        $cl = $-[$#-] if ( $selection =~ /(<\/$mrkps[$typ]>)/g );

        # Add open to start of this line if currently in markup
        $insertfunc->( "$step.0", "<$mrkps[$typ]>" ) if $flags[$typ];

        # Markup left open by this line if open comes last
        $flags[$typ] = 1 if ( $op > $cl );

        # Markup left closed by this line if close comes last
        $flags[$typ] = 0 if ( $cl > $op );

        # Add close to end of this line if now in markup
        $insertfunc->( "$step.end", "</$mrkps[$typ]>" ) if $flags[$typ];
    }

    return @flags;    # So calling routine can remember for next line
}

sub linkpopulate {
    my $linklistbox = shift;
    my $anchorsref  = shift;
    if ( $::lglobal{ilinksrt} ) {
        for ( ::natural_sort_alpha( @{$anchorsref} ) ) {
            next
              if ( ( ( $_ =~ /#$::htmllabels{fnlabel}/ ) || ( $_ =~ /#$::htmllabels{fnanchor}/ ) )
                && $::lglobal{fnlinks} );
            next if ( ( $_ =~ /#$::htmllabels{pglabel}/ ) && $::lglobal{pglinks} );
            $linklistbox->insert( 'end', $_ );
        }
    } else {
        foreach ( @{$anchorsref} ) {
            next
              if ( ( ( $_ =~ /#$::htmllabels{fnlabel}/ ) || ( $_ =~ /#$::htmllabels{fnanchor}/ ) )
                && $::lglobal{fnlinks} );
            next if ( ( $_ =~ /#$::htmllabels{pglabel}/ ) && $::lglobal{pglinks} );
            $linklistbox->insert( 'end', $_ );
        }
    }
    $linklistbox->yviewScroll( 1, 'units' );
    $linklistbox->update;
    $linklistbox->yviewScroll( -1, 'units' );
}

#
# Convert ordinal to a number HTML entity
sub entity {
    my $ord = shift;
    return '&#' . $ord . ';';
}

sub named {
    my ( $from, $to, $start, $end ) = @_;
    my $length;
    my $textwindow = $::textwindow;

    #print "from:$from:to:$to\n";
    my $searchstartindex = $start;
    $searchstartindex = '1.0' unless $searchstartindex;
    $end              = 'end' unless $end;
    $textwindow->markSet( 'srchend', $end );
    while (
        $searchstartindex = $textwindow->search(
            '-regexp',
            '-count' => \$length,
            '--', $from, $searchstartindex, 'srchend'
        )
    ) {
        $textwindow->ntinsert( $searchstartindex, $to );
        $textwindow->ntdelete( $searchstartindex . '+' . length($to) . 'c',
            $searchstartindex . '+' . ( $length + length($to) ) . 'c' );

        # insert before delete to stay on the right side of page markers
        $searchstartindex = $textwindow->index("$searchstartindex+1c");
    }
}

sub fromnamed {
    my ($textwindow) = @_;
    my @ranges       = $textwindow->tagRanges('sel');
    my $range_total  = @ranges;
    return unless $range_total;
    while (@ranges) {
        my $end   = pop @ranges;
        my $start = pop @ranges;
        $textwindow->addGlobStart;
        $textwindow->markSet( 'srchend', $end );
        my ( $thisblockstart, $length );
        ::named( '&amp;',  '&',  $start, 'srchend' );
        ::named( '&quot;', '"',  $start, 'srchend' );
        ::named( ' &gt;',  ' >', $start, 'srchend' );
        ::named( '&lt; ',  '< ', $start, 'srchend' );

        for ( 160 .. 255 ) {
            ::named( ::entity($_), chr($_), $start, 'srchend' );
        }
        while (
            $thisblockstart = $textwindow->search(
                '-regexp',
                '-count' => \$length,
                '--', '&#\d+;', $start, $end
            )
        ) {
            my $xchar = $textwindow->get( $thisblockstart, $thisblockstart . '+' . $length . 'c' );
            $textwindow->ntdelete( $thisblockstart, $thisblockstart . '+' . $length . 'c' );
            $xchar =~ s/&#(\d+);/$1/;
            $textwindow->ntinsert( $thisblockstart, chr($xchar) );
        }
        $textwindow->markUnset('srchend');
        $textwindow->addGlobEnd;
        $textwindow->markSet( 'insert', $start );
    }
}

# Note that double hyphen is converted to numeric (not named) emdash
sub tonamed {
    my ($textwindow) = @_;
    my @ranges       = $textwindow->tagRanges('sel');
    my $range_total  = @ranges;
    return unless $range_total;
    while (@ranges) {
        my $end   = pop @ranges;
        my $start = pop @ranges;
        $textwindow->addGlobStart;
        $textwindow->markSet( 'srchend', $end );
        my $thisblockstart;
        ::named( '&(?![\w#])',           '&amp;',   $start, 'srchend' );
        ::named( '&$',                   '&amp;',   $start, 'srchend' );
        ::named( '"',                    '&quot;',  $start, 'srchend' );
        ::named( '(?<=[^-!])--(?=[^>])', '&#8212;', $start, 'srchend' );
        ::named( '(?<=[^-])--$',         '&#8212;', $start, 'srchend' );
        ::named( '^--(?=[^-])',          '&#8212;', $start, 'srchend' );
        ::named( '& ',                   '&amp; ',  $start, 'srchend' );
        ::named( '&c\.',                 '&amp;c.', $start, 'srchend' );
        ::named( ' >',                   ' &gt;',   $start, 'srchend' );
        ::named( '< ',                   '&lt; ',   $start, 'srchend' );

        for ( 128 .. 255 ) {
            ::named( chr($_), ::entity($_), $start, 'srchend' );
        }
        while ( $thisblockstart =
            $textwindow->search( '-regexp', '--', '[\x{100}-\x{65535}]', $start, 'srchend' ) ) {
            my $xchar = ord( $textwindow->get($thisblockstart) );
            $textwindow->ntdelete( $thisblockstart, "$thisblockstart+1c" );
            $textwindow->ntinsert( $thisblockstart, "&#$xchar;" );
        }
        $textwindow->markUnset('srchend');
        $textwindow->addGlobEnd;
        $textwindow->markSet( 'insert', $start );
    }
}

sub fracconv {
    my ( $textwindow, $start, $end ) = @_;
    my %frachash = (
        '\b1\/2\b' => '&#189;',
        '\b1\/4\b' => '&#188;',
        '\b3\/4\b' => '&#190;',
    );
    my ( $ascii, $html, $length );
    my $thisblockstart = 1;
    while ( ( $ascii, $html ) = each(%frachash) ) {
        while (
            $thisblockstart = $textwindow->search(
                '-regexp',
                '-count' => \$length,
                '--', "-?$ascii", $start, $end
            )
        ) {
            $textwindow->replacewith( $thisblockstart, $thisblockstart . "+$length c", $html );
        }
    }
}

{    # Start of block to localise page label variables
    my @pages   = ();
    my %numbers = ();
    my %styles  = ();
    my %actions = ();
    my %bases   = ();
    my %labels  = ();

    #
    # Pop the Configure Page Labels dialog
    sub pageadjust {
        if ( defined $::lglobal{pagelabelpop} ) {
            $::lglobal{pagelabelpop}->deiconify;
            $::lglobal{pagelabelpop}->raise;
            return;
        }

        my $textwindow = $::textwindow;
        my $top        = $::top;
        my @marks      = $textwindow->markNames;
        @pages = sort grep ( /^Pg\S+$/, @marks );

        # Initialise balloon help
        $::lglobal{pagelabelballoon}      = $top->Balloon() unless $::lglobal{pagelabelballoon};
        $::lglobal{pagelabelprevselected} = "";

        $::lglobal{pagelabelpop} = $top->Toplevel;
        $::lglobal{pagelabelpop}->title('Configure Page Labels');
        ::initialize_popup_with_deletebinding('pagelabelpop');

        my $frame0 = $::lglobal{pagelabelpop}->Frame->pack(
            -fill   => 'x',
            -side   => 'top',
            -anchor => 'n'
        );

        unless (@pages) {
            $frame0->Label( -text => 'No Page Markers Found' )->pack;
            return;
        }

        # Top section shows details for selected page label
        my $fimg = $frame0->LabFrame( -label => 'Img' )->pack( -side => 'left', -anchor => 'w' );
        $::lglobal{pagelabelballoon}
          ->attach( $fimg, -msg => 'Double-click on page list to show image' );
        $::lglobal{pagelabelautoimgbtn} = $fimg->Checkbutton(
            -variable    => \$::lglobal{pagelabelautoimg},
            -selectcolor => $::lglobal{checkcolor},
            -text        => 'Auto Img',
            -anchor      => 'w',
            -command     => sub {
                $::lglobal{pagelabelimgbtn}->invoke if $::lglobal{pagelabelautoimg};
            },
        )->pack( -side => 'top', -anchor => 'nw' );
        $::lglobal{pagelabelimgbtn} = $fimg->Button(
            -text    => "View\nImg\n",
            -width   => 8,
            -height  => 3,
            -command => sub {
                ::openpng( $textwindow, $numbers{ $::lglobal{pagelabelselected} } )
                  if defined $::lglobal{pagelabelselected}
                  and exists $numbers{ $::lglobal{pagelabelselected} };
            }
        )->pack( -side => 'bottom', -anchor => 'sw', -fill => 'y', -padx => 2, -pady => 5 );

        # Label style - Arabic/Roman
        my $fstyle = $frame0->LabFrame( -label => 'Style' )
          ->pack( -side => 'left', -anchor => 'w', -fill => 'y' );
        $::lglobal{pagelabelballoon}
          ->attach( $fstyle, -msg => 'Shift-click on page list to cycle style' );
        my $fstylea = $fstyle->Radiobutton(
            -text        => 'Arabic',
            -selectcolor => $::lglobal{checkcolor},
            -variable    => \$::lglobal{pagelabelstyle},
            -value       => 'Arabic',
            -command     => sub { pagelabelsetstyle(); },
        )->grid( -row => 1, -column => 1, -sticky => 'w' );
        my $fstyler = $fstyle->Radiobutton(
            -text        => 'Roman',
            -selectcolor => $::lglobal{checkcolor},
            -variable    => \$::lglobal{pagelabelstyle},
            -value       => 'Roman',
            -command     => sub { pagelabelsetstyle(); },
        )->grid( -row => 2, -column => 1, -sticky => 'w' );
        my $fstyled = $fstyle->Radiobutton(
            -text        => '"',
            -selectcolor => $::lglobal{checkcolor},
            -variable    => \$::lglobal{pagelabelstyle},
            -value       => '"',
            -command     => sub { pagelabelsetstyle(); },
        )->grid( -row => 3, -column => 1, -sticky => 'w' );

        # Label action - Start @/+1/No Count
        my $faction = $frame0->LabFrame( -label => 'Action' )
          ->pack( -side => 'left', -anchor => 'w', -fill => 'y' );
        $::lglobal{pagelabelballoon}
          ->attach( $faction, -msg => 'Control-click on page list to cycle action' );
        my $factions = $faction->Radiobutton(
            -text        => 'Start @',
            -selectcolor => $::lglobal{checkcolor},
            -variable    => \$::lglobal{pagelabelaction},
            -value       => 'Start @',
            -command     => sub { pagelabelsetaction(); },
        )->grid( -row => 1, -column => 1, -sticky => 'w' );
        my $factionp = $faction->Radiobutton(
            -text        => '+1',
            -selectcolor => $::lglobal{checkcolor},
            -variable    => \$::lglobal{pagelabelaction},
            -value       => '+1',
            -command     => sub { pagelabelsetaction(); },
        )->grid( -row => 2, -column => 1, -sticky => 'w' );
        my $factionn = $faction->Radiobutton(
            -text        => 'No Count',
            -selectcolor => $::lglobal{checkcolor},
            -variable    => \$::lglobal{pagelabelaction},
            -value       => 'No Count',
            -command     => sub { pagelabelsetaction(); },
        )->grid( -row => 3, -column => 1, -sticky => 'w' );

        # Label base - only used with 'Start @' action
        $::lglobal{pagelabelbaseentry} = $faction->Entry(
            -width        => 6,
            -validate     => 'key',
            -vcmd         => sub { pagelabelsetbase(@_); },
            -textvariable => \$::lglobal{pagelabelbase},
        )->grid( -row => 1, -column => 2, -sticky => 'w' );

        # Scrolled listbox to display the label information
        $::lglobal{pagelabellist} = $::lglobal{pagelabelpop}->Scrolled(
            'Listbox',
            -scrollbars  => 'osoe',
            -background  => $::bkgcolor,
            -font        => 'proofing',
            -selectmode  => 'browse',
            -activestyle => 'none',
        )->pack(
            -anchor => 'n',
            -fill   => 'both',
            -expand => 1,
            -padx   => 2,
            -pady   => 2
        );

        # Recalculate and apply buttons
        my $frame1 = $::lglobal{pagelabelpop}->Frame->pack(
            -fill   => 'x',
            -side   => 'top',
            -anchor => 'n'
        );
        my $recalc = $frame1->Button(
            -text    => 'Recalculate',
            -width   => 15,
            -command => sub { labelrecalculate(); }
        )->grid( -row => 1, -column => 1, -padx => 5, -pady => 4 );
        $frame1->Button(
            -text    => 'Use These Values',
            -width   => 15,
            -command => sub { labeluse(); }
        )->grid( -row => 1, -column => 2, -padx => 5 );

        ::drag( $::lglobal{pagelabellist} );
        ::BindMouseWheel( $::lglobal{pagelabelpop}, $::lglobal{pagelabellist} );

        # Bindings for list box - basic selection first
        $::lglobal{pagelabellist}->bind(
            '<<ListboxSelect>>',
            sub {
                $::lglobal{pagelabellist}->activate( $::lglobal{pagelabellist}->curselection );
                labellistselect();
            }
        );

        # Double click shows image (if auto img is on, first click will have shown it)
        $::lglobal{pagelabellist}->bind(
            '<Double-1>',
            sub {
                $::lglobal{pagelabelimgbtn}->invoke unless $::lglobal{pagelabelautoimg};
            }
        );

        # Ensure binding of Shift/Control mouse clicks catches double clicks or the above
        # double click binding is executed. Also note double clicks do single click binding first.
        # Shift mouse 1 cycles round styles
        $::lglobal{pagelabellist}->eventAdd( '<<CycleStyle>>' => '<Shift-1>', '<Shift-Double-1>' );
        $::lglobal{pagelabellist}->bind(
            '<<CycleStyle>>',
            sub {
                labellistselectxy();
                if    ( $::lglobal{pagelabelstyle} eq 'Arabic' ) { $fstyler->invoke; }
                elsif ( $::lglobal{pagelabelstyle} eq 'Roman' )  { $fstyled->invoke; }
                else                                             { $fstylea->invoke; }
            }
        );

        # Control mouse 1 cycles round actions
        $::lglobal{pagelabellist}
          ->eventAdd( '<<CycleAction>>' => '<Control-1>', '<Control-Double-1>' );
        $::lglobal{pagelabellist}->bind(
            '<<CycleAction>>',
            sub {
                labellistselectxy();
                if    ( $::lglobal{pagelabelaction} eq 'Start @' ) { $factionp->invoke; }
                elsif ( $::lglobal{pagelabelaction} eq '+1' )      { $factionn->invoke; }
                else                                               { $factions->invoke; }
            }
        );

        labellistload();
        labellistupdate();
    }

    #
    # Load the label information into the dialog variables
    sub labellistload {
        %numbers = ();
        %styles  = ();
        %actions = ();
        %bases   = ();
        %labels  = ();

        for my $page (@pages) {
            my $num = $page;
            $num =~ s/Pg//;
            $numbers{$page} = $num;
            $styles{$page} =
              $::pagenumbers{$page}{style} || ( $page eq $pages[0] ? 'Arabic' : '"' );
            $actions{$page} =
              $::pagenumbers{$page}{action} || ( $page eq $pages[0] ? 'Start @' : '+1' );
            my $temp = $num;
            $temp =~ s/^0+//;
            $bases{$page}  = $::pagenumbers{$page}{base}  || ( $page eq $pages[0] ? $temp : '' );
            $labels{$page} = $::pagenumbers{$page}{label} || '';
        }
    }

    #
    # Refresh the whole list of label information
    sub labellistupdate {
        my @labelinfolist = ();
        for my $page (@pages) {
            push @labelinfolist, labelinfo($page);
        }
        $::lglobal{pagelabellist}->delete( '0', 'end' );
        $::lglobal{pagelabellist}->insert( 'end', @labelinfolist );

        # Select first page in list
        if ( $::lglobal{pagelabellist}->size > 0 ) {
            $::lglobal{pagelabellist}->activate(0);
            $::lglobal{pagelabellist}->selectionSet(0);
            labellistselect();
        }
    }

    #
    # For the given page, return a formatted string for the list
    sub labelinfo {
        my $page = shift;
        my $num  = $numbers{$page};
        my $sty  = $styles{$page};
        my $act  = $actions{$page};
        my $bas  = $bases{$page};
        my $lab  = $labels{$page};

        my $string = "$num:  ";

        my $tmp = 'Arabic';
        $tmp = 'Roman ' if $sty eq 'Roman';
        $tmp = '  "   ' if $sty eq '"';
        $string .= $tmp . '  ';

        $tmp = '   +1   ';
        $tmp = 'Start @ ' if $act eq 'Start @';
        $tmp = 'No Count' if $act eq 'No Count';
        $string .= $tmp . ' ';

        $tmp = '   ';
        $tmp = sprintf( "%-3d", $bas ) if looks_like_number($bas);
        $string .= $tmp . ' ';

        $string .= '--> ' . $lab;

        return $string;
    }

    #
    # Select current page and display details
    sub labellistselect {
        my $index = $::lglobal{pagelabellist}->index('active');
        $::lglobal{pagelabelselected} = $pages[$index];
        labellistdetails();

        # Consider auto-show image if changing which page is selected
        if ( $::lglobal{pagelabelprevselected} ne $::lglobal{pagelabelselected} ) {
            $::lglobal{pagelabelimgbtn}->invoke if $::lglobal{pagelabelautoimg};
            $::lglobal{pagelabelprevselected} = $::lglobal{pagelabelselected};
        }
    }

    #
    # Select a page from the list using the current pointer position
    sub labellistselectxy {
        my $xx    = $::lglobal{pagelabellist}->pointerx - $::lglobal{pagelabellist}->rootx;
        my $yy    = $::lglobal{pagelabellist}->pointery - $::lglobal{pagelabellist}->rooty;
        my $index = $::lglobal{pagelabellist}->index("\@$xx,$yy");
        $::lglobal{pagelabellist}->selectionClear( 0, 'end' );
        $::lglobal{pagelabellist}->activate($index);
        $::lglobal{pagelabellist}->selectionSet($index);
        labellistselect();
    }

    #
    # Show the label details of the selected page
    sub labellistdetails {
        if ( defined $::lglobal{pagelabelselected}
            and exists $numbers{ $::lglobal{pagelabelselected} } ) {
            $::lglobal{pagelabelimgbtn}
              ->configure( -text => "View\nImg\n$numbers{$::lglobal{pagelabelselected}}" );
            $::lglobal{pagelabelstyle}  = $styles{ $::lglobal{pagelabelselected} };
            $::lglobal{pagelabelaction} = $actions{ $::lglobal{pagelabelselected} };
            $::lglobal{pagelabelbase}   = $bases{ $::lglobal{pagelabelselected} };
            if ( $::lglobal{pagelabelaction} eq 'Start @' ) {
                $::lglobal{pagelabelbaseentry}->configure( -state => 'normal' );
                $::lglobal{pagelabelbaseentry}->focus;
                $::lglobal{pagelabelbaseentry}->icursor('end');
            } else {
                $::lglobal{pagelabelbaseentry}->configure( -state => 'disabled' );
            }
        } else {
            $::lglobal{pagelabelimgbtn}->configure( -text => "View\nImg\n" );
            $::lglobal{pagelabelstyle}  = '';
            $::lglobal{pagelabelaction} = '';
            $::lglobal{pagelabelbase}   = '';
            $::lglobal{pagelabelbaseentry}->configure( -state => 'disabled' );
        }
    }

    #
    # Update the currently active item in the list
    sub pagelabelupdateactive {
        if ( defined $::lglobal{pagelabelselected}
            and exists $numbers{ $::lglobal{pagelabelselected} } ) {
            my $index = $::lglobal{pagelabellist}->index('active');
            $::lglobal{pagelabellist}->delete($index);
            $::lglobal{pagelabellist}->insert( $index, labelinfo( $::lglobal{pagelabelselected} ) );
            $::lglobal{pagelabellist}->activate($index);
            $::lglobal{pagelabellist}->selectionClear( 0, 'end' );
            $::lglobal{pagelabellist}->selectionSet($index);
        }
    }

    #
    # Set the style for the currently selected page
    sub pagelabelsetstyle {
        if ( defined $::lglobal{pagelabelselected}
            and exists $numbers{ $::lglobal{pagelabelselected} } ) {
            $styles{ $::lglobal{pagelabelselected} } = $::lglobal{pagelabelstyle};
            pagelabelupdateactive();
            labellistdetails();
        }
    }

    #
    # Set the action for the currently selected page
    sub pagelabelsetaction {
        if ( defined $::lglobal{pagelabelselected}
            and exists $numbers{ $::lglobal{pagelabelselected} } ) {
            $actions{ $::lglobal{pagelabelselected} } = $::lglobal{pagelabelaction};
            pagelabelupdateactive();
            labellistdetails();
        }
    }

    #
    # Set the base for the currently selected page
    # This is also the validation routine
    sub pagelabelsetbase {
        return 1 unless defined $_[1];
        my $base = shift;
        if (
            defined $::lglobal{pagelabelselected}
            and exists $numbers{ $::lglobal{pagelabelselected} }    # page number exists
            and $base !~ /\D/
        ) {
            $bases{ $::lglobal{pagelabelselected} } = $base;                       # $::lglobal{pagelabelbase} hasn't been set yet
            pagelabelupdateactive() if Tk::Exists( $::lglobal{pagelabellist} );    # list widget exists (can be called early for validation)
            return 1;
        } else {
            return 0;                                                              # Non-digits not allowed
        }
    }

    #
    # Recalculate all the labels based on current values, and display
    sub labelrecalculate {
        my $index = 1;
        my $style = 'Arabic';
        for my $page (@pages) {
            $index = $bases{$page} if $bases{$page} and $actions{$page} eq 'Start @';
            $style = $styles{$page} unless $styles{$page} eq '"';
            if ( $actions{$page} eq 'No Count' ) {
                $labels{$page} = '';
            } else {
                if ( $style eq 'Roman' ) {
                    $labels{$page} = "Pg " . lc( ::roman($index) or '' );    # blank if roman can't convert
                } else {
                    $labels{$page} = "Pg $index";
                    $labels{$page} =~ s/ 0+/ /;
                }
                $index++;
            }
        }
        my $saveautoimg = $::lglobal{pagelabelautoimg};
        $::lglobal{pagelabelautoimg} = 0;
        my $prevpage = $::lglobal{pagelabellist}->index('active');
        labellistupdate();

        # Re-select page in list
        $::lglobal{pagelabellist}->selectionClear( 0, 'end' );
        $::lglobal{pagelabellist}->activate($prevpage);
        $::lglobal{pagelabellist}->selectionSet($prevpage);
        $::lglobal{pagelabellist}->see($prevpage);
        labellistselect();
        $::lglobal{pagelabelautoimg} = $saveautoimg;
    }

    #
    # Store the temporary values in the global hash and close the dialog
    sub labeluse {
        %::pagenumbers = ();
        for my $page (@pages) {
            $::pagenumbers{$page}{style}  = $styles{$page};
            $::pagenumbers{$page}{action} = $actions{$page};
            $::pagenumbers{$page}{base}   = $bases{$page};
            $::pagenumbers{$page}{label}  = $labels{$page};
        }
        ::setedited(1);
        ::killpopup('pagelabelpop');
    }

}    # End of block to localise page label variables

#
# Convert numbers to page links in given text only where the numbers are less than 1000
# (to help avoid dates) and where the formatting guidelines have been followed.
# Modified text is returned.
# The rules are as follows:
# 1. Number must be preceded by a comma (optionally close quote) then one or more spaces
# 2. Number must be no more than 3 digits (word boundary \b used to avoid partial matches with 4 digit numbers)
# 3. Page range may be specified by hyphen or ndash between two numbers
sub addpagelinks {
    my $selection = shift;
    my $ndash     = "\x{2013}";
    my $rdblq     = "\x{201d}";
    $selection =~
      s/(,["$rdblq]?) +(\d{1,3})([-$ndash])\b(\d{1,3})\b/$1 <a href="#$::htmllabels{pglabel}$2">$2$3$4<\/a>/g;
    $selection =~ s/(,["$rdblq]?) +\b(\d{1,3})\b/$1 <a href="#$::htmllabels{pglabel}$2">$2<\/a>/g;
    return $selection;
}
1;
