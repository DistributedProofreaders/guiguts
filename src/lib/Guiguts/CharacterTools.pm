package Guiguts::CharacterTools;
use strict;
use warnings;

BEGIN {
    use Exporter();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT =
      qw(&latinpopup &utfpopup &utffontinit &utfcharentrypopup &utfcharsearchpopup &cp1252toUni);
}

sub pututf {
    $::lglobal{utfpop} = shift;
    my @xy     = $::lglobal{utfpop}->pointerxy;
    my $widget = $::lglobal{utfpop}->containing(@xy);
    my $letter = $widget->cget( -text );
    return unless $letter;
    my $ord = ord($letter);
    $letter = "&#$ord;" if ( $::lglobal{uoutp} eq 'h' );
    insertit($letter);
}

sub latinpopup {
    my $top = $::top;
    if ( defined( $::lglobal{latinpop} ) ) {
        $::lglobal{latinpop}->deiconify;
        $::lglobal{latinpop}->raise;
        $::lglobal{latinpop}->focus;
    } else {
        my @lbuttons;
        $::lglobal{latinpop} = $top->Toplevel;
        $::lglobal{latinpop}->title('Latin-1 ISO 8859-1');
        ::initialize_popup_with_deletebinding('latinpop');
        my $b       = $::lglobal{latinpop}->Balloon( -initwait => 750 );
        my $tframe  = $::lglobal{latinpop}->Frame->pack;
        my $default = $tframe->Radiobutton(
            -variable    => \$::lglobal{latoutp},
            -selectcolor => $::lglobal{checkcolor},
            -value       => 'l',
            -text        => 'Latin-1 Character',
        )->grid( -row => 1, -column => 1 );
        $tframe->Radiobutton(
            -variable    => \$::lglobal{latoutp},
            -selectcolor => $::lglobal{checkcolor},
            -value       => 'h',
            -text        => 'HTML Named Entity',
        )->grid( -row => 1, -column => 2 );
        $tframe->Label( -text => 'Click to insert', )
          ->grid( -row => 2, -column => 1, -columnspan => 2 );
        my $frame      = $::lglobal{latinpop}->Frame( -background => $::bkgcolor )->pack;
        my @latinchars = (
            [ 'À', 'Á', 'Â', 'Ã', 'Ä', 'Å', 'Æ',      'Ç' ],
            [ 'à', 'á', 'â', 'ã', 'ä', 'å', 'æ',      'ç' ],
            [ 'È', 'É', 'Ê', 'Ë', 'Ì', 'Í', 'Î',      'Ï' ],
            [ 'è', 'é', 'ê', 'ë', 'ì', 'í', 'î',      'ï' ],
            [ 'Ò', 'Ó', 'Ô', 'Õ', 'Ö', 'Ø', 'Ñ',      'Þ' ],
            [ 'ò', 'ó', 'ô', 'õ', 'ö', 'ø', 'ñ',      'þ' ],
            [ 'Ù', 'Ú', 'Û', 'Ü', 'Ð', 'ß', 'Ý',      '×' ],
            [ 'ù', 'ú', 'û', 'ü', 'ð', 'ÿ', 'ý',      '÷' ],
            [ '¡', '¿', '«', '»', '¼', '½', '¾',      '¬' ],
            [ '°', 'µ', '©', '®', '¹', '²', '³',      '±' ],
            [ '£', '¢', '¦', '§', '¶', 'º', 'ª',      '·' ],
            [ '¤', '¥', '¯', '¸', '¨', '´', "\x{A0}", '' ],
        );

        for my $y ( 0 .. 11 ) {
            for my $x ( 0 .. 7 ) {
                $lbuttons[ ( $y * 16 ) + $x ] = $frame->Button(
                    -activebackground   => $::activecolor,
                    -text               => $latinchars[$y][$x],
                    -font               => '{Times} 18',
                    -relief             => 'flat',
                    -borderwidth        => 0,
                    -background         => $::bkgcolor,
                    -command            => \&putlatin,
                    -highlightthickness => 0,
                )->grid( -row => $y, -column => $x, -padx => 2 );
                my $name  = ord( $latinchars[$y][$x] );
                my $hex   = uc sprintf( "%04x", $name );
                my $msg   = "Dec. $name, Hex. $hex";
                my $cname = charnames::viacode($name);
                $msg .= ", $cname" if $cname;
                $b->attach( $lbuttons[ ( $y * 16 ) + $x ], -balloonmsg => $msg, );
            }
        }
        $default->select;

        sub putlatin {
            my @xy     = $::lglobal{latinpop}->pointerxy;
            my $widget = $::lglobal{latinpop}->containing(@xy);
            my $letter = $widget->cget( -text );
            return unless $letter;
            my $hex = sprintf( "%x", ord($letter) );
            $letter = ::entity( '\x' . $hex ) if ( $::lglobal{latoutp} eq 'h' );
            insertit($letter);
        }
        $::lglobal{latinpop}->resizable( 'no', 'no' );
        $::lglobal{latinpop}->raise;
        $::lglobal{latinpop}->focus;
    }
}

sub insertit {
    my $letter  = shift;
    my $isatext = 0;
    my $spot;

    # Tk::Text matches searchentry and replaceentries
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
    my $textwindow = $::textwindow;
    my $rows       = ( ( hex $end ) - ( hex $start ) + 1 ) / 16 - 1;
    my ( @buttons, $blln );
    $blln = $::lglobal{utfpop}->Balloon( -initwait => 750 );
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
            my $name  = hex($start) + ( $y * 16 ) + $x;
            my $hex   = sprintf "%04X", $name;
            my $msg   = "Dec. $name, Hex. $hex";
            my $cname = charnames::viacode($name);
            $msg .= ", $cname" if $cname;
            $name = 0 unless $cname;

            # FIXME: See Todo
            $buttons[ ( $y * 16 ) + $x ] = $::lglobal{utfframe}->Button(

                #    $buttons( ( $y * 16 ) + $x ) = $frame->Button(
                -activebackground   => $::activecolor,
                -text               => chr($name),
                -font               => $::lglobal{utffont},
                -relief             => 'flat',
                -borderwidth        => 0,
                -background         => $::bkgcolor,
                -command            => [ \&pututf, $::lglobal{utfpop} ],
                -highlightthickness => 0,
            )->grid( -row => $y, -column => $x );
            $buttons[ ( $y * 16 ) + $x ]->bind(
                '<ButtonPress-3>',
                sub {
                    $textwindow->clipboardClear;
                    $textwindow->clipboardAppend( $buttons[ ( $y * 16 ) + $x ]->cget('-text') );
                }
            );
            $blln->attach( $buttons[ ( $y * 16 ) + $x ], -balloonmsg => $msg, );
            $::lglobal{utfpop}->update;
        }
    }
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
    my $cframe   = $::lglobal{utfpop}->Frame->pack;
    my $fontlist = $cframe->BrowseEntry(
        -label     => 'Font',
        -browsecmd => sub {
            ::utffontinit();
            for (@buttons) {
                $_->configure( -font => $::lglobal{utffont} );
            }
        },
        -variable => \$::utffontname,
    )->grid( -row => 1, -column => 1, -padx => 8, -pady => 2 );
    $fontlist->insert( 'end', sort( $textwindow->fontFamilies ) );
    my $bigger = $cframe->Button(
        -activebackground => $::activecolor,
        -text             => 'Smaller',
        -command          => sub {
            $::utffontsize--;
            ::utffontinit();
            for (@buttons) {
                $_->configure( -font => $::lglobal{utffont} );
            }
            $sizelabel->configure( -text => $::utffontsize );
        },
    )->grid( -row => 1, -column => 2, -padx => 2, -pady => 2 );
    $sizelabel =
      $cframe->Label( -text => $::utffontsize )
      ->grid( -row => 1, -column => 3, -padx => 2, -pady => 2 );
    my $smaller = $cframe->Button(
        -activebackground => $::activecolor,
        -text             => 'Bigger',
        -command          => sub {
            $::utffontsize++;
            ::utffontinit();
            for (@buttons) {
                $_->configure( -font => $::lglobal{utffont} );
            }
            $sizelabel->configure( -text => $::utffontsize );
        },
    )->grid( -row => 1, -column => 4, -padx => 2, -pady => 2 );
    my $usel = $cframe->Radiobutton(
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
        -label     => 'UTF Block',
        -width     => 30,
        -browsecmd => sub {
            doutfbuttons( $::lglobal{utfblocks}{$block}[0], $::lglobal{utfblocks}{$block}[1] );
        },
        -variable => \$block,
    )->grid( -row => 1, -column => 7, -padx => 8, -pady => 2 );
    $unicodelist->insert( 'end', sort( keys %{ $::lglobal{utfblocks} } ) );
    $usel->select;
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

sub utffontinit {
    $::lglobal{utffont} = "{$::utffontname} $::utffontsize";
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

        # Add Basic Latin and Latin-1 Supplement blocks
        $blocks{'Basic Latin'}        = [ '0000', '007F' ];
        $blocks{'Latin-1 Supplement'} = [ '0080', '00FF' ];

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
        my $fontlist = $cframe->BrowseEntry(
            -label     => 'Font',
            -browsecmd => sub {
                utffontinit();
                for (@textchars) {
                    $_->configure( -font => $::lglobal{utffont} );
                }
            },
            -variable => \$::utffontname,
        )->grid( -row => 1, -column => 1, -padx => 8, -pady => 2 );
        $fontlist->insert( 'end', sort( $textwindow->fontFamilies ) );
        my $bigger = $cframe->Button(
            -activebackground => $::activecolor,
            -text             => 'Bigger',
            -command          => sub {
                $::utffontsize++;
                utffontinit();
                for (@textchars) {
                    $_->configure( -font => $::lglobal{utffont} );
                }
                $sizelabel->configure( -text => $::utffontsize );
            },
        )->grid( -row => 1, -column => 2, -padx => 2, -pady => 2 );
        $sizelabel =
          $cframe->Label( -text => $::utffontsize )
          ->grid( -row => 1, -column => 3, -padx => 2, -pady => 2 );
        my $smaller = $cframe->Button(
            -activebackground => $::activecolor,
            -text             => 'Smaller',
            -command          => sub {
                $::utffontsize--;
                utffontinit();
                for (@textchars) {
                    $_->configure( -font => $::lglobal{utffont} );
                }
                $sizelabel->configure( -text => $::utffontsize );
            },
        )->grid( -row => 1, -column => 4, -padx => 2, -pady => 2 );
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
                                -font       => $::lglobal{utffont},
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
        $::lglobal{utfentrypop}->title('Ordinal to Char');
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
        )->grid( -row => 1, -column => 2 );
        $outentry = $frame->ROText(
            -background => $::bkgcolor,
            -relief     => 'sunken',
            -font       => "{sanserif} $::utffontsize",
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
