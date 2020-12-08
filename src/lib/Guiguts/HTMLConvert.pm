package Guiguts::HTMLConvert;
use strict;
use warnings;

my $EMPX = 16.0;    # 1em in px assumed to be 16
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

# Return true if asterisks or <tb> converted on this line
sub html_convert_tb {
    my ( $textwindow, $selection, $step ) = @_;
    if (   $selection =~ s/\s{7}(\*\s{7}){4}\*/<hr class="tb" \/>/
        or $selection =~ s/<tb>/<hr class="tb" \/>/ ) {
        $textwindow->ntdelete( "$step.0", "$step.end" );
        $textwindow->ntinsert( "$step.0", $selection );
        return 1;
    }
    return 0;
}

sub html_convert_subscripts {
    my ( $textwindow, $selection, $step ) = @_;
    if ( $selection =~ s/_\{([^}]+?)\}/<sub>$1<\/sub>/g ) {
        $textwindow->ntdelete( "$step.0", "$step.end" );
        $textwindow->ntinsert( "$step.0", $selection );
    }
    return;
}

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
    return;
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
    ::named( '&(?![\w#])', '&amp;' );
    ::named( '&$',         '&amp;' );
    ::named( '& ',         '&amp; ' );
    ::named( '&c\.',       '&amp;c.' );
    ::named( '&c,',        '&amp;c.,' );
    ::named( '&c ',        '&amp;c. ' );
    $textwindow->FindAndReplaceAll( '-regexp', '-nocase', "(?<![a-zA-Z0-9/\\-\"])>", "&gt;" );
    $textwindow->FindAndReplaceAll( '-regexp', '-nocase',
        "(?![\\n0-9])<(?![a-zA-Z0-9/\\-\\n])", '&lt;' );
    return;
}

# double hyphens go to character entity ref. FIXME: Add option for real emdash.
sub html_convert_emdashes {
    ::working("Converting Emdashes");

    # Avoid converting double hyphens in HTML comments <!--  -->
    # Probably not strictly necessary, since no HTML comments in the file at this time
    # Use negative lookbehind for "<!" and negative lookahead for ">"
    ::named( '(?<!<!)--(?!>)', '&mdash;' );

    ::named( "\x{A0}", '&nbsp;' );
    return;
}

# convert latin1 and utf charactes to HTML Character Entity Reference's.
sub html_convert_latin1 {
    ::working("Converting Latin-1 Characters...");
    for ( 128 .. 255 ) {
        ::named( chr($_), ::entity($_) );
    }
    return;
}

sub html_convert_codepage {
    ::working("Converting Windows Codepage 1252\ncharacters to Unicode");
    ::cp1252toUni();
    return;
}

sub html_convert_utf {
    my ( $textwindow, $leave_utf, $keep_latin1 ) = @_;
    my $blockstart;
    unless ($leave_utf) {
        ::working("Converting UTF-8...");
        while ( $blockstart =
            $textwindow->search( '-regexp', '--', '[\x{100}-\x{65535}]', '1.0', 'end' ) ) {
            my $xchar = ord( $textwindow->get($blockstart) );
            $textwindow->ntdelete($blockstart);
            $textwindow->ntinsert( $blockstart, "&#$xchar;" );
        }
    }
    ::working("Converting Named\n and Numeric Characters");
    ::named( ' >', ' &gt;' );    # see html_convert_ampersands -- probably no effect
    ::named( '< ', '&lt; ' );
    if ( !$keep_latin1 ) { html_convert_latin1(); }
    return;
}

sub html_string_convert_utf {
    my ( $string, $leave_utf, $keep_latin1 ) = @_;
    return                                                         unless $string;
    $string =~ s/([\x{100}-\x{65535}])/sprintf("&x%x;",ord($1))/eg unless $leave_utf;
    $string = html_string_convert_latin1($string) unless $keep_latin1;
    return $string;
}

sub html_string_convert_latin1 {
    my $string     = shift;
    my %markuphash = (
        "\x80" => "&#8364;",
        "\x81" => "&#129;",
        "\x82" => "&#8218;",
        "\x83" => "&#402;",
        "\x84" => "&#8222;",
        "\x85" => "&#8230;",
        "\x86" => "&#8224;",
        "\x87" => "&#8225;",
        "\x88" => "&#710;",
        "\x89" => "&#8240;",
        "\x8a" => "&#352;",
        "\x8b" => "&#8249;",
        "\x8c" => "&#338;",
        "\x8d" => "&#141;",
        "\x8e" => "&#381;",
        "\x8f" => "&#143;",
        "\x90" => "&#144;",
        "\x91" => "&#8216;",
        "\x92" => "&#8217;",
        "\x93" => "&#8220;",
        "\x94" => "&#8221;",
        "\x95" => "&#8226;",
        "\x96" => "&#8211;",
        "\x97" => "&#8212;",
        "\x98" => "&#732;",
        "\x99" => "&#8482;",
        "\x9a" => "&#353;",
        "\x9b" => "&#8250;",
        "\x9c" => "&#339;",
        "\x9d" => "&#157;",
        "\x9e" => "&#382;",
        "\x9f" => "&#376;",
        "\xa0" => "&nbsp;",
        "\xa1" => "&iexcl;",
        "\xa2" => "&cent;",
        "\xa3" => "&pound;",
        "\xa4" => "&curren;",
        "\xa5" => "&yen;",
        "\xa6" => "&brvbar;",
        "\xa7" => "&sect;",
        "\xa8" => "&uml;",
        "\xa9" => "&textcopy;",
        "\xaa" => "&ordf;",
        "\xab" => "&laquo;",
        "\xac" => "&not;",
        "\xad" => "&shy;",
        "\xae" => "&reg;",
        "\xaf" => "&macr;",
        "\xb0" => "&deg;",
        "\xb1" => "&plusmn;",
        "\xb2" => "&sup2;",
        "\xb3" => "&sup3;",
        "\xb4" => "&acute;",
        "\xb5" => "&micro;",
        "\xb6" => "&para;",
        "\xb7" => "&middot;",
        "\xb8" => "&cedil;",
        "\xb9" => "&sup1;",
        "\xba" => "&ordm;",
        "\xbb" => "&raquo;",
        "\xbc" => "&frac14;",
        "\xbd" => "&frac12;",
        "\xbe" => "&frac34;",
        "\xbf" => "&iquest;",
        "\xc0" => "&Agrave;",
        "\xc1" => "&Aacute;",
        "\xc2" => "&Acirc;",
        "\xc3" => "&Atilde;",
        "\xc4" => "&Auml;",
        "\xc5" => "&Aring;",
        "\xc6" => "&AElig;",
        "\xc7" => "&Ccedil;",
        "\xc8" => "&Egrave;",
        "\xc9" => "&Eacute;",
        "\xca" => "&Ecirc;",
        "\xcb" => "&Euml;",
        "\xcc" => "&Igrave;",
        "\xcd" => "&Iacute;",
        "\xce" => "&Icirc;",
        "\xcf" => "&Iuml;",
        "\xd0" => "&ETH;",
        "\xd1" => "&Ntilde;",
        "\xd2" => "&Ograve;",
        "\xd3" => "&Oacute;",
        "\xd4" => "&Ocirc;",
        "\xd5" => "&Otilde;",
        "\xd6" => "&Ouml;",
        "\xd7" => "&times;",
        "\xd8" => "&Oslash;",
        "\xd9" => "&Ugrave;",
        "\xda" => "&Uacute;",
        "\xdb" => "&Ucirc;",
        "\xdc" => "&Uuml;",
        "\xdd" => "&Yacute;",
        "\xde" => "&THORN;",
        "\xdf" => "&szlig;",
        "\xe0" => "&agrave;",
        "\xe1" => "&aacute;",
        "\xe2" => "&acirc;",
        "\xe3" => "&atilde;",
        "\xe4" => "&auml;",
        "\xe5" => "&aring;",
        "\xe6" => "&aelig;",
        "\xe7" => "&ccedil;",
        "\xe8" => "&egrave;",
        "\xe9" => "&eacute;",
        "\xea" => "&ecirc;",
        "\xeb" => "&euml;",
        "\xec" => "&igrave;",
        "\xed" => "&iacute;",
        "\xee" => "&icirc;",
        "\xef" => "&iuml;",
        "\xf0" => "&eth;",
        "\xf1" => "&ntilde;",
        "\xf2" => "&ograve;",
        "\xf3" => "&oacute;",
        "\xf4" => "&ocirc;",
        "\xf5" => "&otilde;",
        "\xf6" => "&ouml;",
        "\xf7" => "&divide;",
        "\xf8" => "&oslash;",
        "\xf9" => "&ugrave;",
        "\xfa" => "&uacute;",
        "\xfb" => "&ucirc;",
        "\xfc" => "&uuml;",
        "\xfd" => "&yacute;",
        "\xfe" => "&thorn;",
        "\xff" => "&yuml;",
    );
    $string =~ s/([\x80-\xff])/$markuphash{$1}/g;
    return $string;
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
    while ( $::blockstart = $textwindow->search( '-regexp', '--', '<\/h\d><br />', '1.0', 'end' ) )
    {
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
        next unless $fnarray->[$step][3];
        $textwindow->ntdelete( 'fne' . "$step" . '-1c', 'fne' . "$step" );

        $textwindow->ntinsert( 'fne' . "$step", "\n\n</div>" );
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
    my ( $textwindow, $headertext, $cssblockmarkup, $poetrynumbers ) = @_;

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
    # in a block, insert <br />
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
    my $inblock    = 0;
    my $incontents = '1.0';
    my $indent     = 0;
    my $intitle    = 0;
    my $inheader   = 0;
    my $indexline  = 0;
    my $ital       = 0;
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
    my ( $blkopen, $blkclose );

    if ($cssblockmarkup) {
        $blkopen  = '<div class="blockquot"><p>';
        $blkclose = '</p></div>';
    } else {
        $blkopen  = '<blockquote><p>';
        $blkclose = '</p></blockquote>';
    }

    ::hidelinenumbers();    # To speed updating of text window

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
        html_convert_subscripts( $textwindow, $selection, $step );
        html_convert_superscripts( $textwindow, $selection, $step );
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

                # delete "p/" characters and
                # newline so a page number doesn't fall inside the closing tag
                $textwindow->ntdelete( "$step.0", "$step.0 +3c" );

                # add back the deleted newline, and 3 </div>s with 2 more newlines
                $textwindow->ntinsert( "$step.0 -1c", "\n$selection" );

                # allow for the two additional newlines
                $step += 2;
                $ler  += 2;
                push @last5, $selection;
                shift @last5 while ( scalar(@last5) > 4 );
                $ital = 0;
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
            $indent = length($1) if $selection =~ s/^(\s+)//;
            $textwindow->ntdelete( "$step.0", "$step.$indent" ) if $indent;
            unless ($unindentedpoetry) {
                $indent -= 4;
            }    # rewrapped poetry automatically has indent of 4
            $indent = 0 if ( $indent < 0 );

            # italic markup cannot span lines, so may need to close & re-open per line
            $ital = doitalicperline( sub { $textwindow->ntinsert(@_) },
                $textwindow, $step, $selection, $ital );

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
            $ital      = 0;

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
            my $blkopencopy = $blkopen;
            if ( $selection =~ m|^/[\*\$]| ) {
                $selection = "\n$selection";    # catch /* immediately following /#
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
        if ( $selection =~ /^\/[Ll]/ ) {
            $listmark = 1;
            $ital     = 0;
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
            my $blkclosecopy = $blkclose;
            $blkclosecopy =~ s|</p>||
              unless is_paragraph_open( $textwindow, ( $step - 1 ) . '.end' );
            $textwindow->ntinsert( ( $step - 1 ) . '.end', $blkclosecopy );
            push @last5, $selection;
            shift @last5 while ( scalar(@last5) > 4 );
            $step++;
            next;
        }

        #close list
        if ( $selection =~ /^[Ll]\// ) {
            $listmark = 0;
            $ital     = 0;

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

            # italic markup cannot span lines, so may need to close & re-open per line
            $ital = doitalicperline( sub { $textwindow->ntinsert(@_) },
                $textwindow, $step, $selection, $ital );

            $textwindow->ntinsert( "$step.0",   '<li>' );
            $textwindow->ntinsert( "$step.end", '</li>' );
            push @last5, $selection;
            shift @last5 while ( scalar(@last5) > 4 );
            $step++;
            next;
        }

        # delete spaces
        if ($blkquot) {
            if ( $selection =~ s/^(\s+)// ) {
                my $space = length $1;
                $textwindow->ntdelete( "$step.0", "$step.0 +${space}c" );
            }
        }

        # close para at $/ or */
        if ( $selection =~ /^[\$\*]\// ) {
            $inblock = 0;
            $ital    = 0;
            $textwindow->replacewith( "$step.0", "$step.end", '</p>' );
            $step++;
            next;
        }

        #insert close para, open para at /$ or /*
        if ( $selection =~ /^\/[\$\*]/ ) {
            $inblock = 1;
            $ital    = 0;
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
            $step++;
            next;
        }

        # Start of index (/I)
        if ( $selection =~ /^\/[Ii]/ ) {
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
        if ( $selection =~ /^[Ii]\// ) {
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

        # in block or just an indented line, add margin-left span and <br />
        if ( $inblock || ( $selection =~ /^\s/ ) ) {
            if ( $selection =~ /^(\s+)/ ) {
                $indent = ( length($1) / 2 );    # left margin of 1em for every 2 spaces
                $selection =~ s/^\s+//;
                $selection =~ s/  /&nbsp; /g;    # attempt to maintain multiple spaces
                $textwindow->ntdelete( "$step.0", "$step.end" );
                $textwindow->ntinsert( "$step.0", $selection );

                # italic markup cannot span lines, so may need to close & re-open per line
                $ital = doitalicperline( sub { $textwindow->ntinsert(@_) },
                    $textwindow, $step, $selection, $ital );

                $textwindow->ntinsert( "$step.0",
                    '<span style="margin-left: ' . $indent . 'em;">' );
                $textwindow->ntinsert( "$step.end", '</span>' );
            }
            $textwindow->ntinsert( "$step.end", '<br />' );

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
                push @contents, "<a href=\"#" . $aname . "\">" . $completeheader . "</a><br />\n";
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

# Put <div class="chapter"> before, and </div> after h2 elements, including pagenum
# within the div if it comes up to 5 lines before the h2 and there's no intervening text.
sub html_convert_chapterdivs {
    my ($textwindow) = @_;
    my $searchstart = '1.0';
    my $h2blockend;

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
                "\n<hr class=\"chap\" />\n\n<div class=\"chapter\">\n" );
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
    while ( $thisblockstart =
        $textwindow->search( '-exact', '--', '<p>FOOTNOTES:', $thisblockstart, 'end' ) ) {
        $textwindow->ntdelete( $thisblockstart, "$thisblockstart+17c" );
        $textwindow->insert( $thisblockstart, '<div class="footnotes"><h3>FOOTNOTES:</h3>' );

        # Improved logic for finding end of footnote block: find
        # the next footnote block
        my $nextfootnoteblock =
          $textwindow->search( '-exact', '--', 'FOOTNOTES:', $thisblockstart . '+1l', 'end' );
        unless ($nextfootnoteblock) {
            $nextfootnoteblock = 'end';
        }
        unless ($nextfootnoteblock) {
            $nextfootnoteblock = 'end';
        }

        # find the start of last footnote
        my $lastfootnoteinblock =
          $textwindow->search( '-exact', '-backwards', '--', '<div class="footnote">',
            $nextfootnoteblock );

        # find the end of the last footnote
        my $endoflastfootnoteinblock =
          $textwindow->search( '-exact', '--', '</p></div>', $lastfootnoteinblock );
        $textwindow->insert( $endoflastfootnoteinblock . '+10c', '</div>' );
        if ($endoflastfootnoteinblock) {
            $thisblockstart = $endoflastfootnoteinblock;
        } else {
            $thisblockstart = 'end';
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
        while ( $textwindow->get( "$thisblockstart+1c", $thisnoteend ) =~ /\[/ ) {
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

    # Work through all the text markers
    while ( $mark = $textwindow->markNext($mark) ) {
        next unless $mark =~ m{Pg(\S+)};    # Only look at page markers
        my $markindex = $textwindow->index($mark);    # Get page marker's index

        # This is the custom page label
        my $num = $::pagenumbers{$mark}{label};
        $num =~ s/Pg // if defined $num;

        # Use the marker unless there is a custom page label
        $num = $1 unless $::pagenumbers{$mark}{action};
        next unless length $num;

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

        # If no more marks (reached end of file) or next mark page marker at least a line
        # beyond the current one, then convert batch of accumulated page markers to a string
        my $pagereference = '';
        if (
            not $marknext    # no next marker - end of file
            or $textwindow->compare( $textwindow->index($marknext), '>=', "$markindex+1l" )
        ) {
            my $br      = "";                 # No br before first marker in batch
            my $numrefs = scalar @pagerefs;
            my $count   = 0;
            for (
                sort {                        # Sort Roman numerals correctly too
                    ( looks_like_number($a) ? $a : ::arabic($a) )
                      <=> ( looks_like_number($b) ? $b : ::arabic($b) )
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
                    $br = "<br />";    # Insert br before any subsequent markers
                }
            }
            @pagerefs = ();
        }

        # comment only
        $textwindow->ntinsert( $markindex, "<!-- Page $num -->" )
          if ( $::pagecmt and $num );
        if ($pagereference) {

            # If exporting with page markers, insert where found
            $textwindow->ntinsert( $markindex, $pagereference )
              if ( $::lglobal{exportwithmarkup} and $num );

            # If skipping coincident pagenums, we know there is just one id to insert in the span
            my $idtxt = $::lglobal{pageskipco} ? " id=\"$::htmllabels{pglabel}$num\"" : "";

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
    ::working();
    return;
}

sub html_parse_header {
    my ( $textwindow, $headertext, $title, $author ) = @_;
    my $selection;
    my $step;
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
        unless ( -e 'header.txt' ) {
            ::copy( 'headerdefault.txt', 'header.txt' );
        }
        open my $infile, '<', 'header.txt'
          or warn "Could not open header file. $!\n";
        while (<$infile>) {
            $_ =~ s/\cM\cJ|\cM|\cJ/\n/g;

            # FIXME: $_ = eol_convert($_);
            $headertext .= $_;
        }
        close $infile;
    }

    $author =~ s/&/&amp;/g if $author;
    unless ( $::lglobal{leave_utf} ) {
        $title = html_string_convert_utf( $title, $::lglobal{leave_utf}, $::lglobal{keep_latin1} );
        $author =
          html_string_convert_utf( $author, $::lglobal{leave_utf}, $::lglobal{keep_latin1} );
    }
    $headertext =~ s/TITLE/$title/   if $title;
    $headertext =~ s/AUTHOR/$author/ if $author;
    $headertext =~ s/BOOKLANG/$::booklang/g;
    if ( $::lglobal{leave_utf} && ::currentfileisunicode() ) {
        $headertext =~ s/BOOKCHARSET/utf-8/;
    } elsif ( $::lglobal{keep_latin1} && ::currentfileislatin1() ) {
        $headertext =~ s/BOOKCHARSET/iso-8859-1/;
    } else {
        $headertext =~ s/BOOKCHARSET/ascii/;
    }
    eval( '$headertext =~ s#\{LANG=' . uc($::booklang) . '\}(.*?)\{/LANG\}#$1#gs' );    # code duplicated near footertext

    # locate and markup title
    $step = 0;
    my $intitle = 0;
    while (1) {
        $step++;
        last if ( $textwindow->compare( "$step.0", '>', 'end' ) );
        $selection = $textwindow->get( "$step.0", "$step.end" );
        next if ( $selection =~ /^\[Illustr/i );                                        # Skip Illustrations
        next if ( $selection =~ /^\/[\$fx]/i );                                         # Skip /$|/F tags
        if (    ($intitle)
            and ( ( not length($selection) or ( $selection =~ /^f\//i ) ) ) ) {
            $step--;
            $textwindow->ntinsert( "$step.end", '</h1>' );
            last;
        }                                                                               #done finding title
        next if ( $selection =~ /^\/[\$fx]/i );                                         # Skip /$|/F tags
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
            last if ( $selection =~ /[\/[Ff]/ );
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
    my ( $textwindow, $headertext, $leave_utf, $autofraction ) = @_;
    my $thisblockstart;
    ::fracconv( $textwindow, '1.0', 'end' ) if $autofraction;
    $textwindow->ntinsert( '1.0', $headertext );
    insert_paragraph_close( $textwindow, 'end' );
    if ( -e 'footer.txt' ) {
        my $footertext;
        open my $infile, '<', 'footer.txt';
        while (<$infile>) {
            $_ =~ s/\cM\cJ|\cM|\cJ/\n/g;

            # FIXME: $_ = eol_convert($_);
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
    my ( $textwindow, $top, $thisblockstart, $thisblockend ) = @_;
    $thisblockstart = 'insert'        unless $thisblockstart;
    $thisblockend   = $thisblockstart unless $thisblockend;
    $textwindow->markSet( 'thisblockstart', $thisblockstart );
    $textwindow->markSet( 'thisblockend',   $thisblockend );
    my $selection;
    $selection            = $textwindow->get( $thisblockstart, $thisblockend ) if @_;
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
          ->pack( -side => 'top', -anchor => 'n', -padx => 2 );
        $::lglobal{imgname} =
          $f1->Entry( -width => 45, )->pack( -side => 'left' );
        my $f3 =
          $::lglobal{htmlimpop}->LabFrame( -label => 'Alt text' )
          ->pack( -side => 'top', -anchor => 'n' );
        $::lglobal{alttext} =
          $f3->Entry( -width => 45, )->pack( -side => 'left' );
        my $f4a =
          $::lglobal{htmlimpop}->LabFrame( -label => 'Caption text' )
          ->pack( -side => 'top', -anchor => 'n' );
        $::lglobal{captiontext} =
          $f4a->Entry( -width => 45, )->pack( -side => 'left' );
        my $f4 =
          $::lglobal{htmlimpop}->LabFrame( -label => 'Title text' )
          ->pack( -side => 'top', -anchor => 'n' );
        $::lglobal{titltext} =
          $f4->Entry( -width => 45, )->pack( -side => 'left' );
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
                htmlimageupdateheight($newval) if $ok;    # Update the height field
                return $ok;
            },
        )->pack( -side => 'left' );
        $f51->Label( -text => 'Height' )->pack( -side => 'left' );
        $::lglobal{heightent} = $f51->Entry(
            -width        => 8,
            -state        => 'readonly',
            -textvariable => \$::lglobal{htmlimgheight},
        )->pack( -side => 'left' );
        my $percentsel = $f51->Radiobutton(
            -variable    => \$::lglobal{htmlimgwidthtype},
            -text        => '%',
            -selectcolor => $::lglobal{checkcolor},
            -value       => '%',
            -command     => sub { htmlimagewidthsetdefault(); }
        )->pack( -side => 'left' );
        my $emsel = $f51->Radiobutton(
            -variable    => \$::lglobal{htmlimgwidthtype},
            -text        => 'em',
            -selectcolor => $::lglobal{checkcolor},
            -value       => 'em',
            -command     => sub { htmlimagewidthsetdefault(); }
        )->pack( -side => 'left' );
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
            -text    => 'OK',
            -width   => 10,
            -command => sub { htmlimageok($textwindow); }
        )->pack;
        my $f = $::lglobal{htmlimpop}->Frame->pack;
        $::lglobal{imagelbl} = $f->Label(
            -text       => 'Thumbnail',
            -justify    => 'center',
            -background => $::bkgcolor,
        )->grid( -row => 1, -column => 1 );
        $::lglobal{imagelbl}->bind( $::lglobal{imagelbl}, '<1>', \&thumbnailbrowse );
        $::lglobal{htmlimpop}->protocol( 'WM_DELETE_WINDOW' => sub { htmlimagedestroy(); } );
        $::lglobal{htmlimpop}->transient($top);
    }
    $::lglobal{alttext}->delete( 0, 'end' )                       if $::lglobal{alttext};
    $::lglobal{titltext}->delete( 0, 'end' )                      if $::lglobal{titltext};
    $::lglobal{captiontext}->insert( 'end', "<p>$selection</p>" ) if $selection;
    &thumbnailbrowse();
}

sub htmlimageok {
    my $textwindow = shift;
    my $name       = $::lglobal{imgname}->get;
    return unless $name;
    my $widthcn = my $width = $::lglobal{widthent}->get;
    $widthcn =~ s/\./_/;    # Convert decimal point to underscore for classname
    my ( $fname, $extension );
    ( $fname, $::globalimagepath, $extension ) = ::fileparse($name);
    $::globalimagepath = ::os_normal($::globalimagepath);
    $name =~ s/[\/\\]/\;/g;
    my $tempname = $::globallastpath;
    $tempname =~ s/[\/\\]/\;/g;
    $name     =~ s/$tempname//;
    $name     =~ s/;/\//g;
    my $selection = $::lglobal{captiontext}->get;
    $selection ||= '';
    my $alt = $::lglobal{alttext}->get;
    $alt =~ s/"/&quot;/g;
    $alt       = " alt=\"$alt\"";
    $selection = "  <div class=\"caption\">$selection</div>\n"
      if $selection;
    $::lglobal{preservep} = '' unless $selection;
    my $title = $::lglobal{titltext}->get || '';
    $title =~ s/"/&quot;/g;
    $title = " title=\"$title\"" if $title;

    # Use filename as basis for an id - remove file extension first
    $fname =~ s/\.[^\.]*$//;
    my $idname    = makeanchor( ::deaccentdisplay($fname) );
    my $classname = 'illow' . ( $::lglobal{htmlimgwidthtype} eq '%' ? 'p' : 'e' ) . $widthcn;
    my $classreg  = '\.illow[pe][0-9\.]+';                                                      # Match any automatically added illow classes

    # Replace [Illustration] with div, img and caption
    $textwindow->addGlobStart;
    $textwindow->delete( 'thisblockstart', 'thisblockend' );

    # Never want image size to exceed its natural size
    my $maxwidth = $::lglobal{htmlimagesizex} / $EMPX;
    $textwindow->insert(
        'thisblockstart',
        "<div class=\"fig$::lglobal{htmlimgalignment} $classname\" id=\"$idname\""
          . (
            $::lglobal{htmlimgwidthtype} eq '%' ? " style=\"max-width: ${maxwidth}em;\">\n" : ">\n"
          )
          . "  <img class=\"w100\" src=\"$name\" $alt$title />\n"
          . "$selection</div>"
          . $::lglobal{preservep}
    );

    # Write class into CSS block (sorted) - first find end of CSS
    my $insertpoint = $textwindow->search( '--', '</style', '1.0', 'end' );
    if ($insertpoint) {
        my $cssdef = ".$classname {width: " . $width . "$::lglobal{htmlimgwidthtype};}";

        # If % width and override flag set, then also add CSS to override width to 100% for epub
        my $cssovr =
          ( $::lglobal{htmlimgwidthtype} eq '%' and $::epubpercentoverride )
          ? "    \@media handheld { .$classname {width: 100%;} }"
          : "";

        # If this class has been added already, write it again (override may have changed)
        if ( my $samepoint =
            $textwindow->search( '-backwards', '--', $cssdef, $insertpoint, '10.0' ) ) {
            $textwindow->ntdelete( $samepoint . ' linestart', $samepoint . ' lineend' );
            $textwindow->ntinsert( $samepoint . ' linestart', $cssdef . $cssovr );

            # Otherwise, find correct place to insert line
        } else {

            # Find end of last class definition in CSS
            $insertpoint = $textwindow->search( '-backwards', '--', '}', $insertpoint, '10.0' );
            if ($insertpoint) {
                $insertpoint = $insertpoint . ' +1l';    # default position for first ever illow class
                my $length     = 0;
                my $classpoint = $insertpoint;

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
                $textwindow->ntinsert( $insertpoint . ' linestart', $cssdef . $cssovr . "\n" );

                # Unless it already exists, add heading before first illow class
                my $heading = '/* Illustration classes */';
                unless ( $textwindow->search( '--', $heading, '10.0', $insertpoint ) ) {
                    $insertpoint =
                      $textwindow->search( '-regexp', '--', $classreg, '10.0', $insertpoint );
                    $textwindow->ntinsert( $insertpoint . ' linestart', "\n$heading\n" )
                      if ($insertpoint);
                }
            }
        }
    }
    $textwindow->addGlobEnd;
    htmlimagedestroy();
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
    if ( $::lglobal{htmlimgwidthtype} eq '%' ) {
        $sizex = htmlimagewidthmaxpercent();
    } else {
        $sizex = $::lglobal{htmlimagesizex} / $EMPX;
    }
    $::lglobal{widthent}->delete( 0, 'end' );
    $::lglobal{widthent}->insert( 'end', $sizex );
    htmlimageupdateheight($sizex);

    # Tell user maximum % width such that both dimensions will fit a 4:3 screen
    $::lglobal{htmlimgmaxwidth}->configure(
        -text => ( $::lglobal{htmlimgwidthtype} eq '%' )
        ? "Max width to fit $LANDX:$LANDY screen is " . $sizex . "%"
        : ""
    );
}

# Return the maximum percentage width for the current image
# such that both its width and height will fit a landscape screen
sub htmlimagewidthmaxpercent {
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
        if ( $::lglobal{htmlimgwidthtype} eq '%' ) {
            $heightlabel = ' --';
        } else {
            $heightlabel = $widthlabel * $::lglobal{htmlimagesizey} / $::lglobal{htmlimagesizex}
              if $::lglobal{htmlimagesizex} and $::lglobal{htmlimagesizey};
            $heightlabel = sprintf( "%.3f", $heightlabel );
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
    htmlimage( $textwindow, $top, $start, $end );
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
    html_convert_codepage();
    html_convert_ampersands($textwindow);
    $headertext = html_parse_header( $textwindow, $headertext, $title, $author );
    html_convert_emdashes();
    $::lglobal{fnsecondpass}  = 0;
    $::lglobal{fnsearchlimit} = 1;
    html_convert_footnotes( $textwindow, $::lglobal{fnarray} );
    html_convert_body(
        $textwindow, $headertext,
        $::lglobal{cssblockmarkup},
        $::lglobal{poetrynumbers}
    );
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
    html_convert_utf( $textwindow, $::lglobal{leave_utf}, $::lglobal{keep_latin1} );
    html_wrapup( $textwindow, $headertext, $::lglobal{leave_utf}, $::lglobal{autofraction} );
    $textwindow->ResetUndo;
    ::setedited(1);
}

sub thumbnailbrowse {
    my $types = [ [ 'Image Files', [ '.gif', '.jpg', '.png' ] ], [ 'All Files', ['*'] ], ];
    my $name  = $::lglobal{htmlimpop}->getOpenFile(
        -filetypes  => $types,
        -title      => 'File Load',
        -initialdir => $::globalimagepath
    );
    return unless ($name);
    my $xythumb = 200;
    if ( $::lglobal{ImageSize} ) {
        ( $::lglobal{htmlimagesizex}, $::lglobal{htmlimagesizey} ) = Image::Size::imgsize($name);
        $::lglobal{htmlimggeom}->configure( -text => "File size: "
              . $::lglobal{htmlimagesizex} / $EMPX . " x "
              . $::lglobal{htmlimagesizey} / $EMPX . " em "
              . "($::lglobal{htmlimagesizex} x $::lglobal{htmlimagesizey} px)" );
    } else {
        $::lglobal{htmlimagesizex} = $xythumb;
        $::lglobal{htmlimagesizey} = $xythumb;
        $::lglobal{htmlimggeom}->configure( -text => "File size: unknown" );
        $::lglobal{htmlimgmaxwidth}->configure( -text => "" );
    }
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
    my $sw = int( ( $::lglobal{htmlorig}->width ) / $xythumb );
    my $sh = int( ( $::lglobal{htmlorig}->height ) / $xythumb );
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

        # Leave utf8 characters rather than convert to numeric entities
        $f0->Checkbutton(
            -variable    => \$::lglobal{leave_utf},
            -selectcolor => $::lglobal{checkcolor},
            -text        => 'Keep UTF-8 Chars',
            -anchor      => 'w',
        )->grid(
            -row    => 2,
            -column => 1,
            -padx   => 1,
            -pady   => 2,
            -sticky => 'w'
        );

        # Leave Latin-1 characters rather than convert to HTML entities
        $f0->Checkbutton(
            -variable    => \$::lglobal{keep_latin1},
            -selectcolor => $::lglobal{checkcolor},
            -text        => 'Keep Latin-1 Chars',
            -anchor      => 'w',
        )->grid(
            -row    => 2,
            -column => 2,
            -padx   => 1,
            -pady   => 2,
            -sticky => 'w'
        );

        # Automatically convert 1/2, 1/4, 3/4 to named entities
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

        # Use <div> with CSS class rather than HTML <blockquote> element
        $f0->Checkbutton(
            -variable    => \$::lglobal{cssblockmarkup},
            -selectcolor => $::lglobal{checkcolor},
            -text        => 'CSS blockquote',
            -anchor      => 'w',
        )->grid(
            -row    => 3,
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
            -row    => 3,
            -column => 2,
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
        $f2->Button(
            -activebackground => $::activecolor,
            -command          => sub {
                ::runner( ::cmdinterp( $::extops[0]{command} ) );
            },
            -text  => 'View in Browser',
            -width => 16,
        )->grid( -row => 1, -column => 2, -padx => 5, -pady => 1 );

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
    ::dialogboxcommonsetup(
        'markupconfigpop',
        \$::htmlentryattribhash{$typ},
        'Class name or attributes: '
    );

    markupconfiglabel( $w, $typ );                  # Adjust label to show presence of class/attributes

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
        $label =~ s/$/+/;
    } else {
        $label =~ s/\+$//;
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

    $mark = "blockquote" if $mark eq "blkq";    # shortened form for button label

    if ( $mark eq 'br' ) {
        my ( $lsr, $lsc, $ler, $lec, $step );
        ( $lsr, $lsc ) = split /\./, $thisblockstart;
        ( $ler, $lec ) = split /\./, $thisblockend;
        if ( $lsr eq $ler ) {
            $textwindow->insert( 'insert', "<br$attr />" );
        } else {
            $step = $lsr;
            while ( $step <= $ler ) {
                $selection = $textwindow->get( "$step.0", "$step.end" );
                $selection =~ s/<br.*?>//g;
                $textwindow->insert( "$step.end", "<br$attr />" );
                $step++;
            }
        }
    } elsif ( $mark eq 'hr' ) {
        $textwindow->insert( 'insert', "<hr$attr />" );
    } elsif ( $mark eq 'nbsp' ) {
        my ( $lsr, $lsc, $ler, $lec, $step );
        ( $lsr, $lsc ) = split /\./, $thisblockstart;
        ( $ler, $lec ) = split /\./, $thisblockend;
        if ( $lsr eq $ler ) {
            $textwindow->insert( 'insert', '&nbsp;' );
        } else {
            $step = $lsr;
            while ( $step <= $ler ) {
                $selection = $textwindow->get( "$step.0", "$step.end" );
                if ( $selection =~ /\s\s/ ) {
                    $selection =~ s/^\s/&nbsp;/;
                    $selection =~ s/  /&nbsp; /g;
                    $selection =~ s/&nbsp; /&nbsp;&nbsp;/g;
                    $textwindow->delete( "$step.0", "$step.end" );
                    $textwindow->insert( "$step.0", $selection );
                }
                $step++;
            }
        }
    } elsif ( $mark eq 'img' ) {
        htmlimage( $textwindow, $top, $thisblockstart, $thisblockend );
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
            $lsc     = 0    if ( $step > $lsr );
            $stepend = $lec if ( $step == $ler );
            $selection = $textwindow->get( "$step.$lsc", "$step.$stepend" );
            $edited++ if ( $selection =~ s/<\/td>/  /g );
            $edited++ if ( $selection =~ s/<\/?body>//g );
            $edited++ if ( $selection =~ s/<br.*?>//g );
            $edited++ if ( $selection =~ s/<\/?div[^>]*?>//g );
            $edited++
              if ( $selection =~ s/<span.*?margin-left: (\d+\.?\d?)em.*?>/' ' x ($1 *2)/e );
            $edited++ if ( $selection =~ s/<\/?span[^>]*?>//g );
            $edited++ if ( $selection =~ s/<\/?[hscalupt].*?>//g );
            $edited++ if ( $selection =~ s/&nbsp;/ /g );
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
    $linkname =~ s/-/\x00/g;
    $linkname =~ s/&amp;|&mdash;/\xFF/;
    $linkname =~ s/<sup>.*?<\/sup>//g;
    $linkname =~ s/<\/?[^>]+>//g;
    $linkname =~ s/\p{Punct}//g;
    $linkname =~ s/\x00/-/g;
    $linkname =~ s/\s+/_/g;

    while ( $linkname =~ m/([\x{100}-\x{ffef}])/ ) {
        my $char     = "$1";
        my $ord      = ord($char);
        my $phrase   = charnames::viacode($ord);
        my $case     = 'lc';
        my $notlatin = 1;
        $phrase   = '-X-' unless ( $phrase =~ /(LETTER|DIGIT|LIGATURE)/ );
        $case     = 'uc' if $phrase =~ /CAPITAL|^-X-$/;
        $notlatin = 0 if $phrase =~ /LATIN/;
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
        # <p>...</p> counts as one entry, but <br /> forces a new entry
    } else {
        my $paragraph = 0;
        my $brflag    = 0;
        my $step      = $lsr;
        while ( $step <= $ler ) {
            if ( my $selection = $textwindow->get( "$step.0", "$step.end" ) ) {

                # If <br /> at end of previous line, need to restart list entry markup
                if ( $brflag and $selection !~ /<p>/ ) {    # not if about to start paragraph anyway
                    $selection = '<li>' . $selection;
                }
                $brflag = 0;

                # If <br />, end current list entry and restart another on next line, even if in paragraph
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

    $selection = '<table class="autotable" summary="">' . "\n";

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
    $textwindow->delete( "$lsr.0", "$ler.end" );
    $textwindow->insert( "$lsr.0", $selection );
    $textwindow->addGlobEnd;
}

sub poetryhtml {
    my $textwindow = $::textwindow;
    ::hidepagenums();
    my @ranges      = $textwindow->tagRanges('sel');
    my $range_total = @ranges;
    return if ( $range_total == 0 );

    my $end   = pop(@ranges);
    my $start = pop(@ranges);
    my ( $lsr, $lsc, $ler, $lec, $step, $ital );
    ( $lsr, $lsc ) = split /\./, $start;
    ( $ler, $lec ) = split /\./, $end;
    $ital = 0;    # Not in italics at start of poem

    my $unindentedpoetry = ispoetryunindented( $textwindow, "$lsr.0", "$ler.end" );

    # Find end of existing CSS in case need to insert new classes
    my $cssend = $textwindow->search( '--', '</style', '1.0', 'end' );
    $cssend = $textwindow->search( '-backwards', '--', '}', $cssend, '10.0' ) if $cssend;
    $cssend = '75.0' unless $cssend;
    my ( $cssendr, $cssendc ) = split /\./, $cssend;
    $cssendr++;

    $step = $lsr;
    while ( $step <= $ler ) {
        my $selection = $textwindow->get( "$step.0", "$step.end" );

        # end of stanza
        if ( $selection =~ /^$/ ) {
            $textwindow->insert( "$step.0", "  </div>\n  <div class=\"stanza\">" );

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
        }
        $selection =~ s/&nbsp;/ /g;
        $selection =~ s/^(\s+)//;
        my $indent = 0;
        $indent = length($1) if $1;
        $textwindow->delete( "$step.0", "$step.$indent" ) if $indent;
        unless ($unindentedpoetry) {
            $indent -= 4;
        }    # rewrapped poetry automatically has indent of 4
        $indent = 0 if ( $indent < 0 );

        # italic markup cannot span lines, so may need to close & re-open per line
        $ital =
          doitalicperline( sub { $textwindow->insert(@_) }, $textwindow, $step, $selection, $ital );

        $textwindow->insert( "$step.0",   "    <div class=\"verse indent$indent\">" );
        $textwindow->insert( "$step.end", '</div>' );

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
}

# determine if poetry is not already indented by four spaces
sub ispoetryunindented {
    my ( $textwindow, $poetrystart, $poetryend ) = @_;

    # look for a line beginning with four characters, but not all spaces
    return (  $poetrystart
          and $poetryend
          and $textwindow->search( '-regexp', '--', '^(?!\\s{4}).{4}', $poetrystart, $poetryend ) );
}

# If italic markup spans across end of line, we have to close
# at end of line and re-open at start of next.
# First argument is temporary sub that calls textwindow->insert/ntinsert
sub doitalicperline {
    my ( $insertfunc, $textwindow, $step, $selection, $ital ) = @_;

    # Find the last open & close italic markups in the line
    my ( $op, $cl ) = ( -1, -1 );    # Default to not found
    $op = $-[$#-] if ( $selection =~ /(<i>)/g );
    $cl = $-[$#-] if ( $selection =~ /(<\/i>)/g );

    # Add open to start of this line if currently in italic
    $insertfunc->( "$step.0", '<i>' ) if $ital;

    # Italic left open by this line if open comes last
    $ital = 1 if ( $op > $cl );

    # Italic left closed by this line if close comes last
    $ital = 0 if ( $cl > $op );

    # Add close to end of this line if now in italic
    $insertfunc->( "$step.end", '</i>' ) if $ital;

    return $ital;    # So calling routine can remember for next line
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
# Convert ordinal to a named or number HTML entity
sub entity {
    my $ord      = shift;
    my @entities = (
        '&#8364;',  '&#129;',   '&#8218;',  '&#402;',   '&#8222;',  '&#8230;',
        '&#8224;',  '&#8225;',  '&#710;',   '&#8240;',  '&#352;',   '&#8249;',
        '&#338;',   '&#141;',   '&#381;',   '&#143;',   '&#144;',   '&#8216;',
        '&#8217;',  '&#8220;',  '&#8221;',  '&#8226;',  '&#8211;',  '&#8212;',
        '&#732;',   '&#8482;',  '&#353;',   '&#8250;',  '&#339;',   '&#157;',
        '&#382;',   '&#376;',   '&nbsp;',   '&iexcl;',  '&cent;',   '&pound;',
        '&curren;', '&yen;',    '&brvbar;', '&sect;',   '&uml;',    '&textcopy;',
        '&ordf;',   '&laquo;',  '&not;',    '&shy;',    '&reg;',    '&macr;',
        '&deg;',    '&plusmn;', '&sup2;',   '&sup3;',   '&acute;',  '&micro;',
        '&para;',   '&middot;', '&cedil;',  '&sup1;',   '&ordm;',   '&raquo;',
        '&frac14;', '&frac12;', '&frac34;', '&iquest;', '&Agrave;', '&Aacute;',
        '&Acirc;',  '&Atilde;', '&Auml;',   '&Aring;',  '&AElig;',  '&Ccedil;',
        '&Egrave;', '&Eacute;', '&Ecirc;',  '&Euml;',   '&Igrave;', '&Iacute;',
        '&Icirc;',  '&Iuml;',   '&ETH;',    '&Ntilde;', '&Ograve;', '&Oacute;',
        '&Ocirc;',  '&Otilde;', '&Ouml;',   '&times;',  '&Oslash;', '&Ugrave;',
        '&Uacute;', '&Ucirc;',  '&Uuml;',   '&Yacute;', '&THORN;',  '&szlig;',
        '&agrave;', '&aacute;', '&acirc;',  '&atilde;', '&auml;',   '&aring;',
        '&aelig;',  '&ccedil;', '&egrave;', '&eacute;', '&ecirc;',  '&euml;',
        '&igrave;', '&iacute;', '&icirc;',  '&iuml;',   '&eth;',    '&ntilde;',
        '&ograve;', '&oacute;', '&ocirc;',  '&otilde;', '&ouml;',   '&divide;',
        '&oslash;', '&ugrave;', '&uacute;', '&ucirc;',  '&uuml;',   '&yacute;',
        '&thorn;',  '&yuml;',
    );
    return $entities[ $ord - 128 ] if $ord >= 128 and $ord <= 255;

    # If we don't have an HTML name, return the number form
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
        ::named( '&amp;',   '&',  $start, 'srchend' );
        ::named( '&quot;',  '"',  $start, 'srchend' );
        ::named( '&mdash;', '--', $start, 'srchend' );
        ::named( ' &gt;',   ' >', $start, 'srchend' );
        ::named( '&lt; ',   '< ', $start, 'srchend' );

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
        ::named( '(?<=[^-!])--(?=[^>])', '&mdash;', $start, 'srchend' );
        ::named( '(?<=[^-])--$',         '&mdash;', $start, 'srchend' );
        ::named( '^--(?=[^-])',          '&mdash;', $start, 'srchend' );
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
        '\b1\/2\b' => '&frac12;',
        '\b1\/4\b' => '&frac14;',
        '\b3\/4\b' => '&frac34;',
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

sub pageadjust {
    my $textwindow = $::textwindow;
    my $top        = $::top;
    if ( defined $::lglobal{pagelabelpop} ) {
        $::lglobal{pagelabelpop}->deiconify;
        $::lglobal{pagelabelpop}->raise;
    } else {
        my @marks = $textwindow->markNames;
        my @pages = sort grep ( /^Pg\S+$/, @marks );
        my %pagetrack;
        $::lglobal{pagelabelpop} = $top->Toplevel;
        $::lglobal{pagelabelpop}->title('Configure Page Labels');
        ::initialize_popup_with_deletebinding('pagelabelpop');
        my $frame0 =
          $::lglobal{pagelabelpop}->Frame->pack( -side => 'top', -anchor => 'n', -pady => 4 );

        unless (@pages) {
            $frame0->Label(
                -text       => 'No Page Markers Found',
                -background => $::bkgcolor,
            )->pack;
            return;
        }
        my $recalc = $frame0->Button(
            -text    => 'Recalculate',
            -width   => 15,
            -command => sub {
                my $index = 1;
                my $style = 'Arabic';
                for my $page (@pages) {
                    my ($num) = $page =~ /Pg(\S+)/;
                    if ( $pagetrack{$num}[4]->cget( -text ) eq 'Start @' ) {
                        my $start = $pagetrack{$num}[5]->get;
                        $index = $start unless $start eq '';
                    }
                    if ( $pagetrack{$num}[3]->cget( -text ) eq 'Arabic' ) {
                        $style = 'Arabic';
                    } elsif ( $pagetrack{$num}[3]->cget( -text ) eq 'Roman' ) {
                        $style = 'Roman';
                    }
                    if ( $pagetrack{$num}[4]->cget( -text ) eq 'No Count' ) {
                        $pagetrack{$num}[2]->configure( -text => '' );
                    } else {
                        my $label;
                        if ( $style eq 'Roman' ) {
                            $label = lc( ::roman($index) or '' );    # blank if roman can't convert
                        } else {
                            $label = $index;
                            $label =~ s/^0+// if $label and length $label;
                        }
                        $pagetrack{$num}[2]->configure( -text => "Pg $label" );
                        $index++;
                    }
                }
            },
        )->grid( -row => 1, -column => 1, -padx => 5, -pady => 4 );
        $frame0->Button(
            -text    => 'Use These Values',
            -width   => 15,
            -command => sub {
                %::pagenumbers = ();
                for my $page (@pages) {
                    my ($num) = $page =~ /Pg(\S+)/;
                    $::pagenumbers{$page}{label} =
                      $pagetrack{$num}[2]->cget( -text );
                    $::pagenumbers{$page}{style} =
                      $pagetrack{$num}[3]->cget( -text );
                    $::pagenumbers{$page}{action} =
                      $pagetrack{$num}[4]->cget( -text );
                    $::pagenumbers{$page}{base} = $pagetrack{$num}[5]->get;
                }
                $recalc->invoke;
                ::setedited(1);
                ::killpopup('pagelabelpop');
            }
        )->grid( -row => 1, -column => 2, -padx => 5 );
        my $frame1 = $::lglobal{pagelabelpop}->Scrolled(
            'Pane',
            -scrollbars => 'se',
            -background => $::bkgcolor,
        )->pack(
            -expand => 1,
            -fill   => 'both',
            -side   => 'top',
            -anchor => 'n'
        );
        ::drag($frame1);
        $top->update;
        my $updatetemp;
        $top->Busy( -recurse => 1 );
        my $row = 0;
        for my $page (@pages) {
            my ($num) = $page =~ /Pg(\S+)/;
            $updatetemp++;
            $::lglobal{pagelabelpop}->update if ( $updatetemp == 20 );
            $pagetrack{$num}[0] = $frame1->Button(
                -text    => "Image# $num",
                -width   => 12,
                -command => [
                    sub {
                        ::openpng( $textwindow, $num );
                    },
                ],
            )->grid( -row => $row, -column => 0, -padx => 2 );
            $pagetrack{$num}[1] = $frame1->Label(
                -text       => "Label -->",
                -background => $::bkgcolor,
            )->grid( -row => $row, -column => 1 );
            my $temp = $num;
            $temp =~ s/^0+//;
            $pagetrack{$num}[2] = $frame1->Label(
                -text       => "Pg $temp",
                -background => 'yellow',
            )->grid( -row => $row, -column => 2 );
            $pagetrack{$num}[3] = $frame1->Button(
                -text    => ( $page eq $pages[0] ) ? 'Arabic' : '"',
                -width   => 8,
                -command => [
                    sub {
                        if ( $pagetrack{ $_[0] }[3]->cget( -text ) eq 'Arabic' ) {
                            $pagetrack{ $_[0] }[3]->configure( -text => 'Roman' );
                        } elsif ( $pagetrack{ $_[0] }[3]->cget( -text ) eq 'Roman' ) {
                            $pagetrack{ $_[0] }[3]->configure( -text => '"' );
                        } elsif ( $pagetrack{ $_[0] }[3]->cget( -text ) eq '"' ) {
                            $pagetrack{ $_[0] }[3]->configure( -text => 'Arabic' );
                        } else {
                            $pagetrack{ $_[0] }[3]->configure( -text => '"' );
                        }
                    },
                    $num
                ],
            )->grid( -row => $row, -column => 3, -padx => 2 );
            $pagetrack{$num}[4] = $frame1->Button(
                -text    => ( $page eq $pages[0] ) ? 'Start @' : '+1',
                -width   => 8,
                -command => [
                    sub {
                        if ( $pagetrack{ $_[0] }[4]->cget( -text ) eq 'Start @' ) {
                            $pagetrack{ $_[0] }[4]->configure( -text => '+1' );
                        } elsif ( $pagetrack{ $_[0] }[4]->cget( -text ) eq '+1' ) {
                            $pagetrack{ $_[0] }[4]->configure( -text => 'No Count' );
                        } elsif ( $pagetrack{ $_[0] }[4]->cget( -text ) eq 'No Count' ) {
                            $pagetrack{ $_[0] }[4]->configure( -text => 'Start @' );
                        } else {
                            $pagetrack{ $_[0] }[4]->configure( -text => '+1' );
                        }
                    },
                    $num
                ],
            )->grid( -row => $row, -column => 4, -padx => 2 );
            $pagetrack{$num}[5] = $frame1->Entry(
                -width    => 8,
                -validate => 'all',
                -vcmd     => sub {
                    return 0 if ( $_[0] =~ /\D/ );
                    return 1;
                }
            )->grid( -row => $row, -column => 5, -padx => 2 );
            if ( $page eq $pages[0] ) {
                $pagetrack{$num}[5]->insert( 'end', $num );
            }
            $row++;
        }
        $top->Unbusy( -recurse => 1 );
        if ( defined $::pagenumbers{ $pages[0] }{action}
            and length $::pagenumbers{ $pages[0] }{action} ) {
            for my $page (@pages) {
                my ($num) = $page =~ /Pg(\S+)/;
                $pagetrack{$num}[2]->configure( -text => $::pagenumbers{$page}{label} );
                $pagetrack{$num}[3]
                  ->configure( -text => ( $::pagenumbers{$page}{style} or 'Arabic' ) );
                $pagetrack{$num}[4]
                  ->configure( -text => ( $::pagenumbers{$page}{action} or '+1' ) );
                $pagetrack{$num}[5]->delete( '0', 'end' );
                $pagetrack{$num}[5]->insert( 'end', $::pagenumbers{$page}{base} );
            }
        }
        $top->update;
    }
}

sub addpagelinks {
    my $selection = shift;
    $selection =~ s/(\d{1,3})-(\d{1,3})/<a href="#$::htmllabels{pglabel}$1">$1-$2<\/a>/g;
    $selection =~ s/(\d{1,3})([,;\.])/<a href="#$::htmllabels{pglabel}$1">$1<\/a>$2/g;
    $selection =~ s/\s(\d{1,3})\s/ <a href="#$::htmllabels{pglabel}$1">$1<\/a> /g;
    $selection =~ s/(\d{1,3})$/<a href="#$::htmllabels{pglabel}$1">$1<\/a>/;
    return $selection;
}
1;
