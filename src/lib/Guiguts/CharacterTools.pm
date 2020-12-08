package Guiguts::CharacterTools;
use strict;
use warnings;

BEGIN {
    use Exporter();
    our ( @ISA, @EXPORT );
    @ISA    = qw(Exporter);
    @EXPORT = qw(&commoncharspopup &utfpopup &utfcharentrypopup &utfcharsearchpopup &cp1252toUni);
}

#
# Create popup containing commonly used characters
# Buttons inserting a space can be defined by user, configured by Ctrl-click, stored in $::userchars
# This allows as many as possible of user's definitions to be preserved if in a future upgrade,
# more buttons are defined, preferably keeping at least as many user-defined buttons
sub commoncharspopup {
    my $top = $::top;
    if ( defined( $::lglobal{comchars} ) ) {
        $::lglobal{comchars}->deiconify;
        $::lglobal{comchars}->raise;
        $::lglobal{comchars}->focus;
    } else {
        my @lbuttons;
        $::lglobal{comchars} = $top->Toplevel;
        $::lglobal{comchars}->title('Commonly Used Characters');
        ::initialize_popup_with_deletebinding('comchars');
        my $blln      = $::lglobal{comchars}->Balloon( -initwait => 750 );
        my $tframe    = $::lglobal{comchars}->Frame->pack;
        my $charradio = $tframe->Radiobutton(
            -variable    => \$::lglobal{comcharoutp},
            -selectcolor => $::lglobal{checkcolor},
            -value       => 'c',
            -text        => 'Character',
        )->grid( -row => 1, -column => 1 );
        $tframe->Radiobutton(
            -variable    => \$::lglobal{comcharoutp},
            -selectcolor => $::lglobal{checkcolor},
            -value       => 'h',
            -text        => 'HTML Entity',
        )->grid( -row => 1, -column => 2 );
        $charradio->select;
        my $frame       = $::lglobal{comchars}->Frame( -background => $::bkgcolor )->pack;
        my @commonchars = (
            [ 'À', 'Á', 'Â', 'Ã', 'Ä', 'Å', 'Æ', 'Ç', 'È', 'É', 'Ê', 'Ë', 'Ì', 'Í', 'Î', 'Ï', ],
            [    # Capital Y with diaresis isn't in allowed range for Perl source code
                'Ò', 'Ó', 'Ô', 'Õ', 'Ö', 'Ø', 'Ñ',       'ß',
                'Ù', 'Ú', 'Û', 'Ü', 'Ð', 'þ', "\x{178}", 'Ý',
            ],
            [ 'à', 'á', 'â', 'ã', 'ä', 'å', 'æ', 'ç', 'è', 'é', 'ê', 'ë', 'ì', 'í', 'î', 'ï', ],
            [ 'ò', 'ó', 'ô', 'õ', 'ö', 'ø', 'ñ', '',  'ù', 'ú', 'û', 'ü', 'ð', 'Þ', 'ÿ', 'ý', ],
            [    # Invert ! ?, angle quotes, curly single/double, low/high single/double, pointers
                "\x{A1}",   "\x{BF}",   "\x{AB}",   "\x{BB}",   "\x{2018}", "\x{2019}",
                "\x{201C}", "\x{201D}", "\x{201A}", "\x{201B}", "\x{201E}", "\x{201F}",
                "\x{261E}", "\x{261B}", "\x{261C}", "\x{261A}",
            ],
            [    # +-, mid-dot, mult & div, deg, 1,2,3 prime, per mille, super 1,2,3, pound, cent, (C), nbsp
                "\x{B1}",   "\x{B7}",   "\x{D7}",   "\x{F7}", "\x{B0}", "\x{2032}",
                "\x{2033}", "\x{2034}", "\x{2030}", "\x{B9}", "\x{B2}", "\x{B3}",
                "\x{A3}",   "\x{A2}",   "\x{A9}",   "\x{A0}",
            ],
            [    # fractions, ordered by denominator then numerator
                "\x{BD}",   "\x{2153}", "\x{BC}",   "\x{BE}",   "\x{2155}", "\x{2156}",
                "\x{2157}", "\x{2158}", "\x{2159}", "\x{215A}", "\x{2150}", "\x{215B}",
                "\x{215C}", "\x{215D}", "\x{215E}", "\x{2151}",
            ],
            [    # emdash, endash, footnote markers, asterism, o&a ordinals, 5 x user-defined buttons
                "\x{2014}", "\x{2013}", "\x{2020}", "\x{2021}", "\x{A7}", "\x{2016}",
                "\x{B6}",   "\x{A6}",   "\x{2042}", "\x{BA}",   "\x{AA}", " ",
                " ",        " ",        " ",        " ",
            ],
        );

        my $ucidx = 0;    # Index into user-defined characters
        for my $y ( 0 .. $#commonchars ) {
            for my $x ( 0 .. $#{ $commonchars[$y] } ) {
                my $text = $commonchars[$y][$x];
                next if $text eq '';    # No text, don't even create a button

                # User can override 'space' buttons - simply fill them in order, not via row/column
                my $userbutton = ( $text eq ' ' );
                if ( $userbutton and $ucidx <= $#::userchars and $::userchars[$ucidx] ) {
                    $text = $::userchars[$ucidx];
                }

                my $ord = ord($text);

                # Define simple flat button to save space
                my $w = $frame->Button(
                    -activebackground => $::activecolor,
                    -text             => $text,
                    -font             => 'unicode',
                    -relief           => 'flat',
                    -borderwidth      => 0,
                    -background       => $::bkgcolor,
                    -command =>
                      sub { insertit( $::lglobal{comcharoutp} eq 'h' ? ::entity($ord) : $text ); },
                    -highlightthickness => 0,
                    -width              => 1,
                )->grid( -row => $y, -column => $x );

                charbind3( $w, $text );    # Bind Mouse-3 to copy character to clipboard

                # For user buttons, bind Ctrl/Meta Mouse-1 to pop a dialog to set character
                if ($userbutton) {
                    $w->eventAdd( '<<config>>' => '<Control-ButtonRelease-1>' );
                    $w->eventAdd( '<<config>>' => '<Meta-ButtonRelease-1>' ) if $::OS_MAC;
                    $w->bind( '<<config>>' => [ \&usercharconfig, $ucidx, $blln ] );
                    ++$ucidx;              # Keep count of number of user buttons defined
                }

                # re-order bindings so that widget's binding precedes class binding
                # meaning we can break out of callbacks later before class callback is called
                my @tags = $w->bindtags;
                $w->bindtags( [ @tags[ 1, 0, 2, 3 ] ] );

                charbuttonballoon( $w, $blln, $ord );    # Balloon message if user hovers over button
            }
        }
        $::lglobal{comchars}->resizable( 'no', 'no' );
        $::lglobal{comchars}->raise;
        $::lglobal{comchars}->focus;
    }
}

#
# Pop a config dialog to set character for given button
# Accepts a single character, e.g. '#'.
# If more than 1 character entered, convert to a decimal ordinal if valid
# If not valid decimal, try converting to a hex ordinal, optionally preceded by \x, 0x or x
# Final fallback, just take first character from string entered
sub usercharconfig {
    my $w    = shift;
    my $idx  = shift;
    my $blln = shift;

    $::lglobal{comcharsconfigpop} = $w->DialogBox(
        -buttons => [qw[OK Cancel]],
        -title   => "Define button",
        -popover => 'cursor',
    );
    ::dialogboxcommonsetup(
        'comcharsconfigpop',
        \$::lglobal{comcharconfigval},
        'Enter character, decimal or hex ordinal: '
    );

    # Replace empty string with space character
    my $text = $::lglobal{comcharconfigval} ? $::lglobal{comcharconfigval} : ' ';

    # If more than one character, interpret as decimal ordinal, hex ordinal or just take first char
    if ( length($text) > 1 ) {
        if ( $text =~ /^\d+$/ ) {    # decimal integer
            $text = chr($text);
        } elsif ( $text =~ s/([\\0]?[x])?([0-9a-f]+)/$2/i ) {    # hex (with x, \x, 0x or no prefix)
            $text = chr( hex($text) );
        } else {
            $text = substr( $text, 0, 1 );                       # Just take first character of string
        }
    }

    my $ord = ord($text);
    $::userchars[$idx] = $text;                                  # Save user's new definition
    $w->configure( -text => $text );                             # Update the label on the button
    $w->configure(                                               # Button needs to insert the new character
        -command => sub { insertit( $::lglobal{comcharoutp} eq 'h' ? ::entity($ord) : $text ); }
    );
    charbind3( $w, $text );                                      # Right-click button copies text to clipboard
    charbuttonballoon( $w, $blln, $ord );                        # Balloon message if user hovers over button

    # stop class callback being called - possible due to binding reordering during button creation above
    $w->break;
}

#
# Bind Mouse-3 to copy given text to clipboard
sub charbind3 {
    my $w    = shift;
    my $text = shift;
    $w->bind(
        '<ButtonPress-3>',
        sub {
            my $textwindow = $::textwindow;
            $textwindow->clipboardClear;
            $textwindow->clipboardAppend($text);
        }
    );
}

#
# Attach balloon to widget with message about character it will insert
sub charbuttonballoon {
    my $w     = shift;
    my $blln  = shift;
    my $ord   = shift;
    my $cname = charnames::viacode($ord);
    my $msg   = "Dec. $ord, Hex. " . sprintf( "%04X", $ord );
    $msg .= ", $cname" if $cname;
    $blln->attach( $w, -balloonmsg => $msg, );
}

sub insertit {
    my $letter  = shift;
    my $isatext = 0;
    my $spot;

    # Tk::Text/Tk::Entry match various text entry boxes
    $isatext = $::lglobal{hasfocus}->isa('Tk::Text') || $::lglobal{hasfocus} == $::textwindow;
    if ($isatext) {
        $spot = $::lglobal{hasfocus}->index('insert');
        my @ranges = $::lglobal{hasfocus}->tagRanges('sel');
        $::lglobal{hasfocus}->delete(@ranges) if @ranges;
    } elsif ( $::lglobal{hasfocus}->isa('Tk::Entry') ) {
        $::lglobal{hasfocus}->delete( 'sel.first', 'sel.last' )
          if $::lglobal{hasfocus}->selectionPresent();
    }
    $::lglobal{hasfocus}->insert( 'insert', $letter );
    $::lglobal{hasfocus}->markSet( 'insert', $spot . '+' . length($letter) . 'c' )
      if $isatext;
}

sub doutfbuttons {
    my ( $start, $end ) = @_;
    my $rows = ( ( hex $end ) - ( hex $start ) + 1 ) / 16 - 1;
    my $blln = $::lglobal{utfpop}->Balloon( -initwait => 750 );
    ::killpopup('pframe');
    $::lglobal{pframe} =
      $::lglobal{utfpop}->Frame( -background => $::bkgcolor )
      ->pack( -expand => 'y', -fill => 'both' );
    $::lglobal{utfframe} = $::lglobal{pframe}->Scrolled(
        'Pane',
        -background => $::bkgcolor,
        -scrollbars => 'se',
        -sticky     => 'nswe'
    )->pack( -expand => 'y', -fill => 'both' );
    ::drag( $::lglobal{utfframe} );

    for my $y ( 0 .. $rows ) {
        for my $x ( 0 .. 15 ) {
            my $ord  = hex($start) + ( $y * 16 ) + $x;
            my $text = chr($ord);

            my $w = $::lglobal{utfframe}->Button(
                -activebackground => $::activecolor,
                -text             => $text,
                -font             => 'unicode',
                -relief           => 'flat',
                -borderwidth      => 0,
                -background       => $::bkgcolor,
                -command => sub { insertit( $::lglobal{uoutp} eq 'h' ? "&#$ord;" : $text ); },
                -highlightthickness => 0,
                -width              => 1,
            )->grid( -row => $y, -column => $x );

            charbind3( $w, $text );                  # Right-click button copies text to clipboard
            charbuttonballoon( $w, $blln, $ord );    # Balloon message if user hovers over button
        }
    }
    $::lglobal{utfpop}->update;
}

### Unicode
sub utfpopup {
    my ( $block, $start, $end ) = @_;
    my $top        = $::top;
    my $textwindow = $::textwindow;
    $top->Busy( -recurse => 1 );
    my $blln;
    my ( $frame, $sizelabel, @buttons );
    my $rows = ( ( hex $end ) - ( hex $start ) + 1 ) / 16 - 1;
    ::killpopup('utfpop');
    $::lglobal{utfpop} = $top->Toplevel;
    ::initialize_popup_without_deletebinding('utfpop');
    $blln = $::lglobal{utfpop}->Balloon( -initwait => 750 );
    $::lglobal{utfpop}->title( $block . ': ' . $start . ' - ' . $end );

    # Choose Unicode/HTML code and select block
    my $cframe = $::lglobal{utfpop}->Frame->pack;
    my $usel   = $cframe->Radiobutton(
        -variable    => \$::lglobal{uoutp},
        -selectcolor => $::lglobal{checkcolor},
        -value       => 'u',
        -text        => 'Unicode',
    )->grid( -row => 1, -column => 5, -padx => 5 );
    $cframe->Radiobutton(
        -variable    => \$::lglobal{uoutp},
        -selectcolor => $::lglobal{checkcolor},
        -value       => 'h',
        -text        => 'HTML code',
    )->grid( -row => 1, -column => 6 );
    my $unicodelist = $cframe->BrowseEntry(
        -label     => 'Block',
        -width     => 30,
        -browsecmd => sub {
            doutfbuttons( $::lglobal{utfblocks}{$block}[0], $::lglobal{utfblocks}{$block}[1] );
        },
        -variable => \$block,
    )->grid( -row => 1, -column => 7, -padx => 8, -pady => 2 );
    $unicodelist->insert( 'end', sort( keys %{ $::lglobal{utfblocks} } ) );
    $usel->select;

    # Allow user to change font
    my $fframe = $::lglobal{utfpop}->Frame->pack;
    ::setfontrow( 'unicode', \$::utffontname, \$::utffontsize, \$::utffontweight, 'Font', $fframe,
        1 );

    $::lglobal{pframe} =
      $::lglobal{utfpop}->Frame( -background => $::bkgcolor )
      ->pack( -expand => 'y', -fill => 'both' );
    $::lglobal{utfframe} = $::lglobal{pframe}->Scrolled(
        'Pane',
        -background => $::bkgcolor,
        -scrollbars => 'se',
        -sticky     => 'nswe'
    )->pack( -expand => 'y', -fill => 'both' );
    ::drag( $::lglobal{utfframe} );
    doutfbuttons( $start, $end );
    $::lglobal{utfpop}->protocol(
        'WM_DELETE_WINDOW' => sub {
            $blln->destroy;
            undef $blln;
            ::killpopup('utfpop');
        }
    );
    $top->Unbusy( -recurse => 1 );
}

sub utfcharsearchpopup {
    my $textwindow = $::textwindow;
    my $top        = $::top;
    if ( defined $::lglobal{utfsearchpop} ) {
        $::lglobal{utfsearchpop}->deiconify;
        $::lglobal{utfsearchpop}->raise;
    } else {
        require q(unicore/Name.pl);
        my $stopit = 0;

        # get lists of supported blocks and unicode characters at start
        my %blocks = %{ $::lglobal{utfblocks} };

        # Add Basic Latin block - not in list of unicode blocks displayed
        $blocks{'Basic Latin'} = [ '0000', '007F' ];

        my @lines = split /\n/, do 'unicore/Name.pl';
        $::lglobal{utfsearchpop} = $top->Toplevel;
        $::lglobal{utfsearchpop}->title('Unicode Character Search');
        ::initialize_popup_with_deletebinding('utfsearchpop');
        my $cframe = $::lglobal{utfsearchpop}->Frame->pack;
        my $frame0 =
          $::lglobal{utfsearchpop}->Frame->pack( -side => 'top', -anchor => 'n', -pady => 4 );
        my $sizelabel;
        my ( @textchars, @textlabels );
        my $pane = $::lglobal{utfsearchpop}->Scrolled(
            'Pane',
            -background => $::bkgcolor,
            -scrollbars => 'se',
            -sticky     => 'wne',
        )->pack( -expand => 'y', -fill => 'both', -anchor => 'nw' );
        ::drag($pane);

        ::setfontrow( 'unicode', \$::utffontname, \$::utffontsize, \$::utffontweight, 'Font',
            $cframe, 1 );

        $frame0->Label( -text => 'Search Characteristics ', )->grid( -row => 1, -column => 1 );
        my $characteristics = $frame0->Entry(
            -width      => 40,
            -background => $::bkgcolor
        )->grid( -row => 1, -column => 2 );
        my $doit = $frame0->Button(
            -text    => 'Search',
            -command => sub {
                for ( @textchars, @textlabels ) {
                    $_->destroy;
                }
                $stopit = 0;
                my $row = 0;
                @textlabels = @textchars = ();

                # split user entry into individual characteristics
                my @chars = split /\s+/, uc( $characteristics->get );

                # check all the character names
                for (@lines) {
                    my @items = split /\t+/, $_;
                    my ( $ord, $name ) = ( $items[0], $items[-1] );
                    last if ( hex $ord > 65535 );
                    if ($stopit) { $stopit = 0; last; }

                    # find character names that match all the user's characteristics
                    my $count = 0;
                    for my $char (@chars) {
                        $count++;
                        last if $name !~ /\b$char\b/;

                        # if all characteristics have matched then add to list
                        if ( @chars == $count ) {

                            # find which block the character is in
                            my $block = '';
                            for ( keys %blocks ) {
                                next if not $_;
                                if (   hex( $blocks{$_}[0] ) <= hex($ord)
                                    && hex( $blocks{$_}[1] ) >= hex($ord) ) {
                                    $block = $_;
                                    last;
                                }
                            }
                            next if not $block;    # character is not in a known block
                            $textchars[$row] = $pane->Label(
                                -text       => chr( hex $ord ),
                                -font       => 'unicode',
                                -background => $::bkgcolor,
                            )->grid(
                                -row    => $row,
                                -column => 0,
                                -sticky => 'w'
                            );
                            utfchar_bind( $textchars[$row] );
                            $textlabels[$row] = $pane->Label(
                                -text       => "$name  -  Ordinal $ord  -  $block",
                                -background => $::bkgcolor,
                            )->grid(
                                -row    => $row,
                                -column => 1,
                                -sticky => 'w'
                            );
                            utflabel_bind(
                                $textlabels[$row],  $block,
                                $blocks{$block}[0], $blocks{$block}[1]
                            );
                            $row++;
                        }
                    }
                }
            },
        )->grid( -row => 1, -column => 3 );
        $frame0->Button(
            -text    => 'Stop',
            -command => sub { $stopit = 1; },
        )->grid( -row => 1, -column => 4 );
        $characteristics->bind( '<Return>' => sub { $doit->invoke } );
    }
}

sub utflabel_bind {
    my ( $widget, $block, $start, $end ) = @_;
    $widget->bind(
        '<Enter>',
        sub {
            $widget->configure( -background => $::activecolor );
        }
    );
    $widget->bind( '<Leave>', sub { $widget->configure( -background => $::bkgcolor ); } );
    $widget->bind(
        '<ButtonPress-1>',
        sub {
            utfpopup( $block, $start, $end );
        }
    );
}

sub utfchar_bind {
    my $textwindow = $::textwindow;
    my $widget     = shift;
    $widget->bind(
        '<Enter>',
        sub {
            $widget->configure( -background => $::activecolor );
        }
    );
    $widget->bind( '<Leave>', sub { $widget->configure( -background => $::bkgcolor ) } );
    $widget->bind(
        '<ButtonPress-3>',
        sub {
            $widget->clipboardClear;
            $widget->clipboardAppend( $widget->cget('-text') );
            $widget->configure( -relief => 'sunken' );
        }
    );
    $widget->bind(
        '<ButtonRelease-3>',
        sub {
            $widget->configure( -relief => 'flat' );
        }
    );
    $widget->bind(
        '<ButtonPress-1>',
        sub {
            $widget->configure( -relief => 'sunken' );
            $::lglobal{hasfocus}->insert( 'insert', $widget->cget('-text') );
        }
    );
    $widget->bind(
        '<ButtonRelease-1>',
        sub {
            $widget->configure( -relief => 'flat' );
        }
    );
}

# Pop up window to allow entering Unicode characters by ordinal number
sub utfcharentrypopup {
    my $textwindow = $::textwindow;
    my $top        = $::top;
    my $ord;
    my $base = 'dec';
    if ( $::lglobal{utfentrypop} ) {
        $::lglobal{utfentrypop}->deiconify;
        $::lglobal{utfentrypop}->raise;
    } else {
        $::lglobal{utfentrypop} = $top->Toplevel;
        $::lglobal{utfentrypop}->title('Unicode Character Entry');
        my $frame  = $::lglobal{utfentrypop}->Frame->pack( -fill => 'x', -padx => 5, -pady => 5 );
        my $frame2 = $::lglobal{utfentrypop}->Frame->pack( -fill => 'x', -padx => 5, -pady => 5 );
        $frame->Label( -text => 'Ordinal of char.' )->grid( -row => 1, -column => 1 );
        my $charlbl = $frame2->Label( -text => '', -width => 50 )->pack;
        my ( $inentry, $outentry );
        $frame->Radiobutton(
            -variable => \$base,
            -value    => 'hex',
            -text     => 'Hex',
            -command  => sub { $inentry->validate }
        )->grid( -row => 0, -column => 1 );
        $frame->Radiobutton(
            -variable => \$base,
            -value    => 'dec',
            -text     => 'Decimal',
            -command  => sub { $inentry->validate }
        )->grid( -row => 0, -column => 2 );
        $inentry = $frame->Entry(
            -background   => $::bkgcolor,
            -width        => 6,
            -textvariable => \$ord,
            -validate     => 'key',
            -vcmd         => sub {

                if ( $_[0] eq '' ) {
                    $outentry->delete( '1.0', 'end' );
                    return 1;
                }
                my ( $name, $char );
                if ( $base eq 'hex' ) {
                    return 0 unless ( $_[0] =~ /^[a-fA-F\d]{0,4}$/ );
                    $char = chr( hex( $_[0] ) );
                    $name = charnames::viacode( hex( $_[0] ) );
                } elsif ( $base eq 'dec' ) {
                    return 0
                      unless ( ( $_[0] =~ /^\d{0,5}$/ )
                        && ( $_[0] < 65519 ) );
                    $char = chr( $_[0] );
                    $name = charnames::viacode( $_[0] );
                }
                $outentry->delete( '1.0', 'end' );
                $outentry->insert( 'end', $char );
                $charlbl->configure( -text => $name );
                return 1;
            },
        )->grid( -row => 1, -column => 2, -pady => 5 );
        $outentry = $frame->ROText(
            -background => $::bkgcolor,
            -relief     => 'sunken',
            -font       => 'unicode',
            -width      => 6,
            -height     => 1,
        )->grid( -row => 2, -column => 2 );
        my $outcopy = $frame->Button(
            -text    => 'Copy',
            -width   => 8,
            -command => sub {
                $outentry->tagAdd( 'sel', '1.0', '1.0 lineend' );
                $outentry->clipboardCopy;
            },
        )->grid( -row => 2, -column => 3 );
        my $frame1 = $::lglobal{utfentrypop}->Frame->pack( -fill => 'x', -padx => 5, -pady => 5 );
        my $button = $frame1->Button(
            -text    => 'Insert',
            -width   => 8,
            -command => sub {
                $::lglobal{hasfocus}->insert( 'insert', $outentry->get( '1.0', 'end -1c' ) );
            },
        )->grid( -row => 1, -column => 1 );
        $frame1->Button(
            -text    => 'Close',
            -width   => 8,
            -command => sub { ::killpopup('utfentrypop'); },
        )->grid( -row => 1, -column => 2 );
        $inentry->Tk::bind(
            '<Return>',
            sub {
                $::lglobal{hasfocus}->insert( 'insert', $outentry->get( '1.0', 'end -1c' ) );
            }
        );
        $::lglobal{utfentrypop}->resizable( 'yes', 'no' );
        ::initialize_popup_with_deletebinding('utfentrypop');
    }
}

## Convert Windows CP 1252
sub cp1252toUni {
    my $textwindow = $::textwindow;
    my %cp         = (
        "\x{80}" => "\x{20AC}",
        "\x{82}" => "\x{201A}",
        "\x{83}" => "\x{0192}",
        "\x{84}" => "\x{201E}",
        "\x{85}" => "\x{2026}",
        "\x{86}" => "\x{2020}",
        "\x{87}" => "\x{2021}",
        "\x{88}" => "\x{02C6}",
        "\x{89}" => "\x{2030}",
        "\x{8A}" => "\x{0160}",
        "\x{8B}" => "\x{2039}",
        "\x{8C}" => "\x{0152}",
        "\x{8E}" => "\x{017D}",
        "\x{91}" => "\x{2018}",
        "\x{92}" => "\x{2019}",
        "\x{93}" => "\x{201C}",
        "\x{94}" => "\x{201D}",
        "\x{95}" => "\x{2022}",
        "\x{96}" => "\x{2013}",
        "\x{97}" => "\x{2014}",
        "\x{98}" => "\x{02DC}",
        "\x{99}" => "\x{2122}",
        "\x{9A}" => "\x{0161}",
        "\x{9B}" => "\x{203A}",
        "\x{9C}" => "\x{0153}",
        "\x{9E}" => "\x{017E}",
        "\x{9F}" => "\x{0178}"
    );
    for my $term ( keys %cp ) {
        my $thisblockstart;
        while ( $thisblockstart = $textwindow->search( '-exact', '--', $term, '1.0', 'end' ) ) {

            # Use replacewith() to ensure change is tracked and saved
            $textwindow->replacewith( $thisblockstart, "$thisblockstart+1c", $cp{$term} );
        }
    }
    ::update_indicators();
}
1;
