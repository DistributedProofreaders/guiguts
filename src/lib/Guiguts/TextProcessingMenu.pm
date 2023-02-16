package Guiguts::TextProcessingMenu;
use strict;
use warnings;

BEGIN {
    use Exporter();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT =
      qw(&text_convert_italic &text_convert_bold &txt_convert_simple_markup &text_thought_break &text_convert_tb
      &text_convert_options &txt_convert_palette &fixpopup &text_uppercase_smallcaps &text_remove_smallcaps_markup
      &txt_manual_sc_conversion &endofline &cleanup &text_quotes_convert &text_quotes_select &text_quotes_flipdouble
      &text_quotes_usespaces &text_quotes_removeat &text_straight_quote_select &text_straight_quote_convert
      &text_quotes_insert);
}

my $LDQ  = "\x{201c}";
my $RDQ  = "\x{201d}";
my $LSQ  = "\x{2018}";
my $RSQ  = "\x{2019}";
my $FLAG = "@";

sub text_convert_italic {
    my ( $textwindow, $italic_char ) = @_;
    my $italic  = qr/<\/?i>/;
    my $replace = $italic_char;
    $textwindow->FindAndReplaceAll( '-regexp', '-nocase', $italic, $replace );
}

sub text_convert_bold {
    my ( $textwindow, $bold_char ) = @_;
    my $bold    = qr{</?b>};
    my $replace = "$bold_char";
    $textwindow->FindAndReplaceAll( '-regexp', '-nocase', $bold, $replace );
}

sub txt_convert_simple_markup {
    my ( $textwindow, $markup, $replace ) = @_;
    my $search = eval( 'qr{' . $markup . '}' );
    $textwindow->FindAndReplaceAll( '-regexp', '-nocase', $search, $replace );
}

## Insert a "Thought break" (duh)
sub text_thought_break {
    my ($textwindow) = @_;
    $textwindow->insert( ( $textwindow->index('insert') ) . ' lineend', '       *' x 5 );
}

sub text_convert_tb {
    my ($textwindow) = @_;
    my $tb = '       *       *       *       *       *';
    $textwindow->FindAndReplaceAll( '-exact', '-nocase', '<tb>', $tb );
}

sub text_convert_options {
    my $top     = shift;
    my $options = $top->DialogBox(
        -title   => "Auto-Convert Options",
        -buttons => ["OK"],
    );
    my $italic_frame = $options->add('Frame')->pack( -side => 'top', -padx => 5, -pady => 3 );
    my $italic_label = $italic_frame->Label(
        -width => 25,
        -text  => "Italic Replace Character"
    )->pack( -side => 'left' );
    my $italic_entry = $italic_frame->Entry(
        -width        => 6,
        -background   => $::bkgcolor,
        -relief       => 'sunken',
        -textvariable => \$::italic_char,
    )->pack( -side => 'left' );
    my $bold_frame = $options->add('Frame')->pack( -side => 'top', -padx => 5, -pady => 3 );
    my $bold_label = $bold_frame->Label(
        -width => 25,
        -text  => "Bold Replace Character"
    )->pack( -side => 'left' );
    my $bold_entry = $bold_frame->Entry(
        -width        => 6,
        -background   => $::bkgcolor,
        -relief       => 'sunken',
        -textvariable => \$::bold_char,
    )->pack( -side => 'left' );
    $options->Show;
    ::savesettings();
}

sub txt_convert_palette {
    my ( $textwindow, $top ) = ( $::textwindow, $::top );
    if ( defined( $::lglobal{txtconvpop} ) ) {
        $::lglobal{txtconvpop}->deiconify;
        $::lglobal{txtconvpop}->raise;
        $::lglobal{txtconvpop}->focus;
    } else {
        $::lglobal{txtconvpop} = $top->Toplevel;
        $::lglobal{txtconvpop}->title('Txt Markup');

        my $italic_frame =
          $::lglobal{txtconvpop}->Frame->pack( -side => 'top', -padx => 5, -pady => 3 );
        $italic_frame->Label(
            -text  => '<i></i>',
            -width => 8,
        )->pack( -side => 'left' );
        my $italic_check = $italic_frame->Checkbutton(
            -variable => \$::txt_conv_italic,
            -width    => 10,
            -text     => 'convert to:'
        )->pack( -side => 'left' );
        my $italic_entry = $italic_frame->Entry(
            -width        => 6,
            -background   => $::bkgcolor,
            -relief       => 'sunken',
            -textvariable => \$::italic_char,
        )->pack( -side => 'left' );
        my $italic_button = $italic_frame->Button(
            -width   => 16,
            -text    => 'Convert <i></i> now',
            -command => sub { txt_convert_simple_markup( $textwindow, "</?i>", $::italic_char ); }
        )->pack( -side => 'left' );
        my $bold_frame =
          $::lglobal{txtconvpop}->Frame->pack( -side => 'top', -padx => 5, -pady => 3 );
        $bold_frame->Label(
            -text  => '<b></b>',
            -width => 8,
        )->pack( -side => 'left' );
        my $bold_check = $bold_frame->Checkbutton(
            -variable => \$::txt_conv_bold,
            -width    => 10,
            -text     => 'convert to:'
        )->pack( -side => 'left' );
        my $bold_entry = $bold_frame->Entry(
            -width        => 6,
            -background   => $::bkgcolor,
            -relief       => 'sunken',
            -textvariable => \$::bold_char,
        )->pack( -side => 'left' );
        my $bold_button = $bold_frame->Button(
            -width   => 16,
            -text    => 'Convert <b></b> now',
            -command => sub { txt_convert_simple_markup( $textwindow, "</?b>", $::bold_char ); }
        )->pack( -side => 'left' );
        my $g_frame = $::lglobal{txtconvpop}->Frame->pack( -side => 'top', -padx => 5, -pady => 3 );
        $g_frame->Label(
            -text  => '<g></g>',
            -width => 8,
        )->pack( -side => 'left' );
        my $g_check = $g_frame->Checkbutton(
            -variable => \$::txt_conv_gesperrt,
            -text     => 'convert to:',
            -width    => 10,
        )->pack( -side => 'left' );
        my $g_entry = $g_frame->Entry(
            -width        => 6,
            -background   => $::bkgcolor,
            -relief       => 'sunken',
            -textvariable => \$::gesperrt_char,
        )->pack( -side => 'left' );
        my $g_button = $g_frame->Button(
            -width   => 16,
            -text    => 'Convert <g></g> now',
            -command => sub { txt_convert_simple_markup( $textwindow, "</?g>", $::gesperrt_char ); }
        )->pack( -side => 'left' );
        my $f_frame = $::lglobal{txtconvpop}->Frame->pack( -side => 'top', -padx => 5, -pady => 3 );
        $f_frame->Label(
            -text  => '<f></f>',
            -width => 8,
        )->pack( -side => 'left' );
        my $f_check = $f_frame->Checkbutton(
            -variable => \$::txt_conv_font,
            -text     => 'convert to:',
            -width    => 10,
        )->pack( -side => 'left' );
        my $f_entry = $f_frame->Entry(
            -width        => 6,
            -background   => $::bkgcolor,
            -relief       => 'sunken',
            -textvariable => \$::font_char,
        )->pack( -side => 'left' );
        my $f_button = $f_frame->Button(
            -width   => 16,
            -text    => 'Convert <f></f> now',
            -command => sub { txt_convert_simple_markup( $textwindow, "</?f>", $::font_char ); }
        )->pack( -side => 'left' );
        my $sc_frame =
          $::lglobal{txtconvpop}->Frame->pack( -side => 'top', -padx => 5, -pady => 3 );
        my $sc_label = $sc_frame->Label(
            -text  => "<sc></sc>",
            -width => 9,
        )->pack( -side => 'left' );
        my $sc_none = $sc_frame->Radiobutton(
            -variable => \$::txt_conv_sc,
            -value    => 0,
            -text     => "ignore",
            -width    => 7,
        )->pack( -side => 'left' );
        my $sc_uc = $sc_frame->Radiobutton(
            -variable => \$::txt_conv_sc,
            -value    => 2,
            -text     => "UPPERCASE",
            -width    => 10,
        )->pack( -side => 'left' );
        my $sc_char = $sc_frame->Radiobutton(
            -variable => \$::txt_conv_sc,
            -value    => 1,
            -text     => "convert to:",
            -width    => 8,
        )->pack( -side => 'left' );
        my $sc_entry = $sc_frame->Entry(
            -width        => 6,
            -background   => $::bkgcolor,
            -relief       => 'sunken',
            -textvariable => \$::sc_char,
        )->pack( -side => 'left' );
        my $tb_frame =
          $::lglobal{txtconvpop}->Frame->pack( -side => 'top', -padx => 5, -pady => 3 );
        $tb_frame->Label(
            -text  => "<tb>",
            -width => 8,
        )->pack( -side => 'left' );
        my $tb_check = $tb_frame->Checkbutton(
            -variable => \$::txt_conv_tb,
            -text     => 'convert to stars',
            -width    => 15,
        )->pack( -side => 'left' );
        my $tb_button = $tb_frame->Button(
            -width   => 16,
            -text    => 'Convert <tb> now',
            -command => sub { ::text_convert_tb($textwindow); }
        )->pack( -side => 'left' );
        my $all_frame =
          $::lglobal{txtconvpop}->Frame->pack( -side => 'top', -padx => 5, -pady => 3 );
        my $sc_manual = $all_frame->Button(
            -width   => 20,
            -text    => 'Do <sc> manually...',
            -command => sub { ::txt_manual_sc_conversion() },
        )->pack( -side => 'left', -padx => 10 );
        my $all_button = $all_frame->Button(
            -width   => 20,
            -text    => 'Do All Selected',
            -command => sub {
                $textwindow->addGlobStart;
                txt_convert_simple_markup( $textwindow, "</?i>", $::italic_char )
                  if ($::txt_conv_italic);
                txt_convert_simple_markup( $textwindow, "</?b>", $::bold_char )
                  if ($::txt_conv_bold);
                txt_convert_simple_markup( $textwindow, "</?g>", $::gesperrt_char )
                  if ($::txt_conv_gesperrt);
                txt_convert_simple_markup( $textwindow, "</?f>", $::font_char )
                  if ($::txt_conv_font);
                text_convert_tb($textwindow)
                  if ($::txt_conv_tb);
                if ($::txt_conv_sc) {
                    txt_auto_uppercase_smallcaps() if ( $::txt_conv_sc == 2 );
                    txt_convert_simple_markup( $textwindow, "</?sc>", $::sc_char )
                      if ( $::txt_conv_sc == 1 );
                }
                $textwindow->addGlobEnd;
            }
        )->pack( -side => 'left' );
        ::initialize_popup_with_deletebinding('txtconvpop');
    }
    ::savesettings();
}

sub fixpopup {
    my $top = $::top;
    ::hidepagenums();
    if ( defined( $::lglobal{fixpop} ) ) {
        $::lglobal{fixpop}->deiconify;
        $::lglobal{fixpop}->raise;
        $::lglobal{fixpop}->focus;
    } else {
        $::lglobal{fixpop} = $top->Toplevel;
        $::lglobal{fixpop}->title('Fixup Options');
        my $pframe = $::lglobal{fixpop}->Frame->pack;
        $pframe->Label( -text => 'Select options for the fixup routine:', )->pack;
        my $pframe1 = $::lglobal{fixpop}->Frame->pack;
        ${ $::lglobal{fixopt} }[15] = 1;
        my @rbuttons = (
            'Skip /* */, /$ $/, /X X/, and /F F/ marked blocks.',
            'Fix up spaces around single hyphens.',
            'Convert multiple spaces to single spaces.',
            'Remove spaces before single periods.',
            'Remove spaces before exclamation marks.',
            'Remove spaces before question marks.',
            'Remove spaces before semicolons.',
            'Remove spaces before colons.',
            'Remove spaces before commas.',
            'Remove spaces after beginning and before ending double quote.',
            'Remove spaces after opening and before closing brackets, () [], {}.',
            'Mark up a line with 4 or more * and nothing else as <tb>.',
            'Fix obvious l<->1 problems, lst, llth, etc.',
            'Format ellipses correctly',
            'Remove spaces after beginning and before ending angle quotes « ».',
        );
        my $row = 0;

        for (@rbuttons) {
            $pframe1->Checkbutton(
                -variable => \${ $::lglobal{fixopt} }[$row],
                -text     => $_,
            )->grid( -row => $row, -column => 1, -sticky => 'nw' );
            ++$row;
        }
        $pframe1->Radiobutton(
            -variable => \${ $::lglobal{fixopt} }[15],
            -value    => 1,
            -text     => 'French style angle quotes «guillemets»',
        )->grid( -row => $row, -column => 1 );
        ++$row;
        $pframe1->Radiobutton(
            -variable => \${ $::lglobal{fixopt} }[15],
            -value    => 0,
            -text     => 'German style angle quotes »guillemets«',
        )->grid( -row => $row, -column => 1 );
        my $tframe = $::lglobal{fixpop}->Frame->pack;
        $tframe->Button(
            -command => sub {
                $::lglobal{fixpop}->UnmapWindow;
                fixup();
                ::killpopup('fixpop');
            },
            -text  => 'Go!',
            -width => 14
        )->pack( -pady => 6 );
        ::initialize_popup_with_deletebinding('fixpop');
    }
}

## Fixup Popup
sub fixup {
    my $textwindow = $::textwindow;
    ::hidelinenumbers();    # To speed updating of text window
    ::operationadd('Fixup Routine');
    ::hidepagenums();
    my ($line);
    my $index      = '1.0';
    my $lastindex  = '1.0';
    my $inblock    = 0;
    my $BLOCKTYPES = quotemeta '$*XxFf';
    my $inpoem     = 0;
    my $POEMTYPES  = quotemeta 'Pp';
    my $TEMPPOEMLN = "\x7f";
    my $end        = $textwindow->index('end');
    ::enable_interrupt();

    while ( $lastindex < $end ) {
        my $edited = 0;    # if current line has been edited
        $line    = $textwindow->get( $lastindex, $index );
        $inblock = 1 if $line =~ /\/[$BLOCKTYPES]/;
        $inblock = 0 if $line =~ /[$BLOCKTYPES]\//;
        $inpoem  = 1 if $line =~ /\/[$POEMTYPES]/;
        $inpoem  = 0 if $line =~ /[$POEMTYPES]\//;
        unless ( $inblock && ${ $::lglobal{fixopt} }[0] ) {

            if ( ${ $::lglobal{fixopt} }[2] ) {    # remove multiple spaces
                my $poetrylinenum = '';

                # if poem line number replace with temporary character
                # preserve whitespace after line number (includes newline) - trailing spaces will be dealt with later
                $poetrylinenum = $1 if $inpoem and $line =~ s/(\s\s+\d+)(\s*)$/$TEMPPOEMLN$2/;

                # replace other multiple spaces with a single space
                $edited++ while ( $line =~ s/(?<=\S)\s\s+(?=\S)/ / );

                # restore saved line number with its preceding spaces
                $line =~ s/$TEMPPOEMLN/$poetrylinenum/ if $inpoem;
            }

            # Fix up spaces around single hyphens
            if ( ${ $::lglobal{fixopt} }[1] ) {
                $edited++ if $line =~ s/(\S) +-(?!-)/$1-/g;    # Don't remove spaces before hyphen if start of line, like poetry
                $edited++ if $line =~ s/(?<!-)- +/-/g;
            }

            # Remove space before single periods (only if not first on line and not decimal point before digits)
            if ( ${ $::lglobal{fixopt} }[3] ) {
                $edited++ if $line =~ s/(\S) +\.(?![\d\.])/$1\./g;
            }

            # Get rid of space before exclamation points
            if ( ${ $::lglobal{fixopt} }[4] ) {
                $edited++ if $line =~ s/ +!/!/g;
            }

            # Get rid of space before question marks
            if ( ${ $::lglobal{fixopt} }[5] ) {
                $edited++ if $line =~ s/ +\?/\?/g;
            }

            # Get rid of space before semicolons
            if ( ${ $::lglobal{fixopt} }[6] ) {
                $edited++ if $line =~ s/ +\;/\;/g;
            }

            # Get rid of space before colons
            if ( ${ $::lglobal{fixopt} }[7] ) {
                $edited++ if $line =~ s/ +:/:/g;
            }

            # Get rid of space before commas
            if ( ${ $::lglobal{fixopt} }[8] ) {
                $edited++ if $line =~ s/ +,/,/g;
            }

            # Remove spaces after beginning and before ending double quote
            if ( ${ $::lglobal{fixopt} }[9] ) {
                $edited++ if $line =~ s/^\" +/\"/;
                $edited++ if $line =~ s/ +\"$/\"/;
            }

            # Remove spaces after opening and before closing brackets
            if ( ${ $::lglobal{fixopt} }[10] ) {
                $edited++ if $line =~ s/(?<=(\(|\{|\[)) //g;
                $edited++ if $line =~ s/ (?=(\)|\}|\]))//g;
            }

            # Fix thought breaks: asterisks to <tb>
            if ( ${ $::lglobal{fixopt} }[11] ) {
                $edited++ if $line =~ s/^\s*(\*\s*){4,}$/<tb>\n/;
            }

            # Remove trailing spaces
            $edited++ if ( $line =~ s/ +$// );

            # Fix llth, lst
            if ( ${ $::lglobal{fixopt} }[12] ) {
                $edited++ if $line =~ s/llth/11th/g;
                $edited++ if $line =~ s/(?<=\d)lst/1st/g;
                $edited++ if $line =~ s/(?<=\s)lst/1st/g;
                $edited++ if $line =~ s/^lst/1st/;
            }

            # format ellipses correctly - add space before unless already one,
            # or sentence-ending punctuation is present, or at start of quoted text
            if ( ${ $::lglobal{fixopt} }[13] ) {
                $edited++ if $line =~ s/(?<=[^\.\!\? \"'$LDQ$LSQ])\.{3}(?![\.\!\?])/ \.\.\./g;
            }

            # format french guillemets correctly
            if ( ${ $::lglobal{fixopt} }[14] and ${ $::lglobal{fixopt} }[15] ) {
                $edited++ if $line =~ s/«\s+/«/g;
                $edited++ if $line =~ s/\s+»/»/g;
            }

            # format german guillemets correctly
            if ( ${ $::lglobal{fixopt} }[14] and !${ $::lglobal{fixopt} }[15] ) {
                $edited++ if $line =~ s/\s+«/«/g;
                $edited++ if $line =~ s/»\s+/»/g;
            }
            $textwindow->replacewith( $lastindex, $index, $line ) if $edited;
        }
        unless ( ::updatedrecently() ) {
            $textwindow->see($index);
            $textwindow->markSet( 'insert', $index );
            $textwindow->update;
        }
        $lastindex = $index;
        $index++;
        $index .= '.0';
        if ( $index > $end ) { $index = $end }
        if ( ::query_interrupt() ) {
            ::restorelinenumbers();
            return;
        }
    }
    ::disable_interrupt();
    $textwindow->markSet( 'insert', 'end' );
    $textwindow->see('end');
    ::restorelinenumbers();
}

sub text_uppercase_smallcaps {
    ::searchpopup();
    ::searchoptset(qw/0 x x 1/);
    $::lglobal{searchentry}->delete( 0, 'end' );
    $::lglobal{searchentry}->insert( 'end', "<sc>(\\n?[^<]+)</sc>" );
    $::lglobal{replaceentry}->delete( 0, 'end' );
    $::lglobal{replaceentry}->insert( 'end', "\\U\$1\\E" );
}

sub txt_auto_uppercase_smallcaps {
    my $textwindow = $::textwindow;
    $textwindow->addGlobStart;
    my ( $thisblockstart, $thisblockend, $selection );
    while ( $thisblockstart = $textwindow->search( '-exact', '--', '<sc>', '1.0', 'end' ) ) {
        $thisblockend = $textwindow->search( '-exact', '--', '</sc>', $thisblockstart, 'end' );
        $selection    = $textwindow->get( "$thisblockstart +4c", $thisblockend );
        $textwindow->replacewith( $thisblockstart, "$thisblockend +5c", uc($selection) );
    }
    $textwindow->addGlobEnd;
}

sub text_remove_smallcaps_markup {
    ::searchpopup();
    ::searchoptset(qw/0 x x 1/);
    $::lglobal{searchentry}->delete( 0, 'end' );
    $::lglobal{searchentry}->insert( 'end', "<sc>(\\n?[^<]+)</sc>" );
    $::lglobal{replaceentry}->delete( 0, 'end' );
    $::lglobal{replaceentry}->insert( 'end', "\$1" );
}

sub txt_manual_sc_conversion {
    ::searchpopup();
    ::searchoptset(qw/0 x x 1/);
    $::lglobal{searchmultiadd}->invoke while $::multisearchsize < 3;    # Ensure sufficient replacement fields
    $::lglobal{searchentry}->delete( 0, 'end' );
    $::lglobal{replaceentry}->delete( 0, 'end' );
    $::lglobal{replaceentry1}->delete( 0, 'end' );
    $::lglobal{replaceentry2}->delete( 0, 'end' );
    $::lglobal{searchentry}->insert( 'end', '<sc>(\\n?[^<]+)</sc>' );
    $::lglobal{replaceentry}->insert( 'end', '$1' );
    $::lglobal{replaceentry1}->insert( 'end', '\U$1\E' );
    $::lglobal{replaceentry2}->insert( 'end', "$::sc_char\$1$::sc_char" );
    $::lglobal{searchmulti}->invoke;
}

## End of Line Cleanup
sub endofline {
    my $textwindow = $::textwindow;
    ::operationadd('Remove end-of-line spaces');
    ::hidepagenums();
    my $start  = '1.0';
    my $end    = $textwindow->index('end');
    my @ranges = $textwindow->tagRanges('sel');
    if (@ranges) {
        $start = $ranges[0];
        $end   = $ranges[-1];
    }
    $textwindow->FindAndReplaceAll( '-regex', '-nocase', '\s+$', '' );
}

## Clean Up Rewrap
sub cleanup {
    my $textwindow = $::textwindow;
    my $top        = $::top;
    $top->Busy( -recurse => 1 );
    $::searchstartindex = '1.0';
    ::hidepagenums();
    $textwindow->addGlobStart;
    while (1) {
        $::searchstartindex =
          $textwindow->search( '-regexp', '--', "^\/[$::allblocktypes]|^[$::allblocktypes]\/",
            $::searchstartindex, 'end' );
        last unless $::searchstartindex;

        # if a start rewrap block marker is followed by a start rewrap block marker,
        # also delete the blank line between the two
        if (   $textwindow->get( $::searchstartindex, "$::searchstartindex +1c" ) eq '/'
            && $textwindow->get( "$::searchstartindex +3c", "$::searchstartindex +6c" ) =~
            /\n\/[$::allblocktypes]/ ) {
            $textwindow->delete( "$::searchstartindex -1c", "$::searchstartindex +5c lineend" );
        } else {
            $textwindow->delete( "$::searchstartindex -1c", "$::searchstartindex lineend" );
        }
    }
    $textwindow->addGlobEnd;
    $top->Unbusy( -recurse => 1 );
}

##
## Routines to convert straight quotes to curly quotes
## Algorithm from ppsmq -  https://github.com/DistributedProofreaders/ppwb/blob/master/bin/ppsmq.py
##

#
# Top-level routine for converting straight quotes to curly quotes
sub text_quotes_convert {
    my $textwindow = $::textwindow;
    my $top        = $::top;
    $top->Busy( -recurse => 1 );
    $textwindow->addGlobStart;

    $::lglobal{quotesflagcount} = 0;
    text_quotes_double();
    text_quotes_single();

    $textwindow->addGlobEnd;
    $top->Unbusy( -recurse => 1 );
}

#
# Convert double quotes from straight to curly
# Algorithm is to alternate left and right quotes, but resetting at end of paragraph
# Subsequent checks mark potential errors with "@"
sub text_quotes_double {
    my $textwindow = $::textwindow;
    my $linenum    = 0;
    my $lineend    = $textwindow->index('end');
    $lineend =~ s/\..+//;

    my $dqlevel = 0;
    while ( $linenum < $lineend ) {
        $linenum++;
        my $line   = $textwindow->get( "$linenum.0", "$linenum.end" );
        my $edited = 0;

        # expect dqlevel == 0 on an empty line unless next line starts with open quote
        if ( $line =~ /^$/ ) {
            if (    $dqlevel != 0
                and $linenum + 1 < $lineend
                and $textwindow->get("$linenum.0 +1l") ne '"' ) {
                $textwindow->insert( "$linenum.0 - 1l lineend", $FLAG );
                $::lglobal{quotesflagcount}++;
            }
            $dqlevel = 0;
            next;
        }

        # Catch ditto marks first (double space both sides unless end of line)
        $edited = 1 if $line =~ s/(?<=  )"(?=  )/$RDQ/g;    # look-arounds necessary for multiple matches to work
        $edited = 1 if $line =~ s/  "$/  $RDQ/;

        # if quotes at start of line, must be open quotes
        if ( $line =~ s/^"/$LDQ/ ) {
            $edited = 1;
            if ( $dqlevel != 0 ) {                          # flag previous line if open not expected
                $textwindow->insert( "$linenum.0 - 1l lineend", $FLAG );
                $::lglobal{quotesflagcount}++;
            }
            $dqlevel = 1;
        }

        # replace straight with curly quotes, one at a time
        while (1) {
            if ( $dqlevel == 0 ) {
                if ( $line =~ s/"/$LDQ/ ) {
                    $dqlevel = 1;
                    $edited  = 1;
                } else {
                    last;
                }
            } else {
                if ( $line =~ s/"/$RDQ/ ) {
                    $dqlevel = 0;
                    $edited  = 1;
                } else {
                    last;
                }

            }
        }

        next unless $edited;

        # Check for various errors and flag/correct them
        if ( $line =~ s/$LDQ$/$RDQ/ ) {    # open quote end of line - change to close quote
            $line .= $FLAG;
            $::lglobal{quotesflagcount}++;
            $dqlevel = 0;
        }
        if ( $line =~ /\w$LDQ/ ) {         # open quote preceded by word char
            $line .= $FLAG;
            $::lglobal{quotesflagcount}++;
        }
        if ( $line =~ /$RDQ\w/ ) {         # close quote followed by word char
            $line .= $FLAG;
            $::lglobal{quotesflagcount}++;
        }
        if ( $line =~ /$LDQ / ) {          # floating open quote
            $line .= $FLAG;
            $::lglobal{quotesflagcount}++;
        }
        if ( $line =~ / $RDQ(?!(  |$))/ ) {    # floating close quote
            $line .= $FLAG;
            $::lglobal{quotesflagcount}++;
        }

        $textwindow->replacewith( "$linenum.0", "$linenum.end", $line );
    }
}

#
# Convert single quotes from straight to curly
# First by converting specific words with apostrophes at the start
# Then by applying rules regarding quote placement
sub text_quotes_single {
    my $textwindow = $::textwindow;
    my $linenum    = 0;
    my $lineend    = $textwindow->index('end');
    $lineend =~ s/\..+//;

    # Prepare word list and replacements
    my @words = (
        "'em",        "'Tis",  "'Tisn't", "'Tweren't", "'Twere", "'Twould",
        "'Twouldn't", "'Twas", "'Im",     "'Twixt",    "'Til",   "'Scuse",
        "'Gainst",    "'Twon't"
    );
    my @replc = ();
    for my $word (@words) {
        my $repl = $word;
        $repl =~ s/'/$RSQ/g;
        push( @replc, $repl );
    }

    while ( $linenum < $lineend ) {
        $linenum++;
        my $edited = 0;
        my $line   = $textwindow->get( "$linenum.0", "$linenum.end" );

        # Replace using word list
        for my $ii ( 0 .. $#words ) {
            my $wmix = $words[$ii];
            my $rmix = $replc[$ii];
            $edited = 1 if $line =~ s/$wmix\b/$rmix/g;    # replace mixed case version
            my $wlow = lc $words[$ii];
            my $rlow = lc $replc[$ii];
            $edited = 1 if $line =~ s/$wlow\b/$rlow/g;    # replace lower case version
        }

        # Replace using rules
        $edited = 1 if $line =~ s/(\w)'(\w)/$1$RSQ$2/g;    # letter-'-letter
        $edited = 1 if $line =~ s/([\.,\w])'/$1$RSQ/g;     # period, comma or letter followed by '
        $edited = 1 if $line =~ s/(\w)'\./$1$RSQ\./g;      # letter-apostrophe-period
        $edited = 1 if $line =~ s/'$/$RSQ/;                # at end of line
        $edited = 1 if $line =~ s/' /$RSQ /g;              # followed by a space
        $edited = 1 if $line =~ s/'$RDQ/$RSQ$RDQ/g;        # followed by a right double quote

        $textwindow->replacewith( "$linenum.0", "$linenum.end", $line ) if $edited;
    }

}

#
# Select next line containing @
sub text_quotes_select {
    my $textwindow = $::textwindow;
    $textwindow->tagRemove( 'sel', '1.0', 'end' );

    my $atindex = $textwindow->search( '-exact', '--', '@', 'insert' );
    if ($atindex) {
        $textwindow->tagAdd( 'sel', "$atindex linestart", "$atindex lineend" );
        $textwindow->markSet( 'insert' => "$atindex lineend" );
        $textwindow->see('insert');
        $textwindow->focus;
    } else {
        ::soundbell();
    }
}

#
# Flip the double quote types left<-->right in the current selection
sub text_quotes_flipdouble {
    my $textwindow = $::textwindow;
    my @ranges     = $textwindow->tagRanges('sel');
    return if ( @ranges == 0 );
    my $end   = pop(@ranges);
    my $start = pop(@ranges);

    $textwindow->addGlobStart;
    my $index = $start;
    while ( $index = $textwindow->search( '-regexp', '--', "[$LDQ$RDQ]", $index, $end ) ) {

        # use Win32::Unicode;
        # Win32::Unicode::printW $textwindow->get($index). "\n";
        my $ch = $textwindow->get($index) eq $RDQ ? $LDQ : $RDQ;
        $textwindow->insert( $index, $ch );
        $textwindow->delete( "$index+1c", "$index+2c" );
        $index .= "+1c";
    }
    $textwindow->addGlobEnd;

    $textwindow->tagAdd( 'sel', $start, $end );    # Reselect region
    $textwindow->focus;
}

#
# Use space/non-space to choose correct double quotes in current selection
sub text_quotes_usespaces {
    my $textwindow = $::textwindow;
    my @ranges     = $textwindow->tagRanges('sel');
    return if ( @ranges == 0 );
    my $end   = pop(@ranges);
    my $start = pop(@ranges);

    $textwindow->addGlobStart;

    # Find open quotes that need changing to close quotes
    my $index = $start;
    while ( $index = $textwindow->search( '-exact', '--', $LDQ, $index, $end ) ) {
        my $ch = $textwindow->get( "$index-1c", "$index+2c" );
        if ( $ch =~ /\S$LDQ[\s@]/ ) {    # Allow @ as it might have been appended to line as flag
            $textwindow->insert( $index, $RDQ );
            $textwindow->delete( "$index+1c", "$index+2c" );
        }
        $index .= "+1c";
    }

    # Find close quotes that need changing to open quotes
    $index = $start;
    while ( $index = $textwindow->search( '-exact', '--', $RDQ, $index, $end ) ) {
        my $ch = $textwindow->get( "$index-1c", "$index+2c" );
        if ( $ch =~ /\s$RDQ\S/ ) {
            $textwindow->insert( $index, $LDQ );
            $textwindow->delete( "$index+1c", "$index+2c" );
        }
        $index .= "+1c";
    }
    $textwindow->addGlobEnd;

    $textwindow->tagAdd( 'sel', $start, $end );    # Reselect region
    $textwindow->focus;
}

#
# Remove all @ symbols in current selection
sub text_quotes_removeat {
    my $textwindow = $::textwindow;
    my @ranges     = $textwindow->tagRanges('sel');
    return if ( @ranges == 0 );
    my $end   = pop(@ranges);
    my $start = pop(@ranges);

    $textwindow->addGlobStart;
    my $length;
    my $index = $start;
    while ( $index =
        $textwindow->search( '-regexp', '-count' => \$length, '--', '@+', $index, $end ) ) {
        $textwindow->delete( $index, "$index+${length}c" );
    }
    $textwindow->addGlobEnd;

    $textwindow->tagAdd( 'sel', $start, $end );    # Reselect region
    $textwindow->focus;
}

#
# Select next straight quote
sub text_straight_quote_select {
    my $textwindow = $::textwindow;
    $textwindow->tagRemove( 'sel', '1.0', 'end' );

    my $atindex = $textwindow->search( '-exact', '--', "'", 'insert' );
    if ($atindex) {
        $textwindow->tagAdd( 'sel', "$atindex", "$atindex+1c" );
        $textwindow->markSet( 'insert' => "$atindex+1c" );
        $textwindow->see('insert');
        $textwindow->focus;
    } else {
        ::soundbell();
    }
}

#
# Replace selected text (normally a straight quote) with a left/right curly quote
sub text_straight_quote_convert {
    my $quote      = shift;
    my $textwindow = $::textwindow;
    my @ranges     = $textwindow->tagRanges('sel');
    return if ( @ranges == 0 );
    my $end   = pop(@ranges);
    my $start = pop(@ranges);
    $textwindow->insert( $start, $quote );
    $textwindow->delete( "$start+1c", "$end+1c" );
}

#
# Insert the given type of quote, keeping the focus on the main window
sub text_quotes_insert {
    my $textwindow = $::textwindow;

    $textwindow->addGlobStart;
    $::textwindow->insert( 'insert', shift );
    $textwindow->addGlobEnd;

    $textwindow->focus;
}
1;
