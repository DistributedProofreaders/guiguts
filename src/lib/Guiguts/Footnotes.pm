package Guiguts::Footnotes;
use strict;
use warnings;

BEGIN {
    use Exporter();
    our ( @ISA, @EXPORT );
    @ISA    = qw(Exporter);
    @EXPORT = qw(&footnotepop &footnotefixup &getlz);
}

## Pop up a window where footnotes can be found, fixed and formatted. (heh)
sub footnotepop {
    my $textwindow = $::textwindow;
    my $top        = $::top;
    ::operationadd('Footnote Fixup');
    ::hidepagenums();
    if ( defined( $::lglobal{footpop} ) ) {
        $::lglobal{footpop}->deiconify;
        $::lglobal{footpop}->raise;
        $::lglobal{footpop}->focus;
    } else {
        $::lglobal{fncount} = '1' unless $::lglobal{fncount};
        $::lglobal{fnalpha} = '1' unless $::lglobal{fnalpha};
        $::lglobal{fnroman} = '1' unless $::lglobal{fnroman};
        $::lglobal{fnindex} = '0' unless $::lglobal{fnindex};
        $::lglobal{fntotal} = '0' unless $::lglobal{fntotal};
        $::lglobal{footpop} = $top->Toplevel;
        my ( $checkn, $checka, $checkr );
        $::lglobal{footpop}->title('Footnote Fixup');
        my $frame1 = $::lglobal{footpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        $frame1->Button(
            -activebackground => $::activecolor,
            -command          => sub { fnfirstpass() },
            -text             => 'First Pass',
            -underline        => 0,
            -width            => 14
        )->grid( -row => 1, -column => 1, -padx => 2, -pady => 4 );
        $frame1->Button(
            -activebackground => $::activecolor,
            -command          => sub { footnoteadjust() },
            -text             => 'Rescan this FN',
            -width            => 14
        )->grid( -row => 1, -column => 2, -padx => 2, -pady => 2 );
        $frame1->Button(
            -activebackground => $::activecolor,
            -command          => sub { fnview() },
            -text             => 'Check Footnotes',
            -width            => 14
        )->grid( -row => 1, -column => 3, -padx => 6, -pady => 2 );
        $frame1->Button(
            -activebackground => $::activecolor,
            -command          => sub { fnjoin() },
            -text             => 'Join With Previous',
            -width            => 14
        )->grid( -row => 2, -column => 2, -padx => 2, -pady => 2 );
        $frame1->Button(
            -activebackground => $::activecolor,
            -command          => sub { setanchor() },
            -text             => 'Set Anchor',
            -width            => 14
        )->grid( -row => 2, -column => 3, -padx => 2, -pady => 2 );
        my $frame1b = $::lglobal{footpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        $::lglobal{unlimitedsearchbutton} = $frame1b->Checkbutton(
            -variable => \$::lglobal{fnsearchlimit},
            -text     => 'Unlimited Anchor Search'
        )->grid( -row => 1, -column => 1, -padx => 3, -pady => 4 );
        $frame1b->Checkbutton(
            -variable => \$::lglobal{fncenter},
            -text     => 'Center on Search'
        )->grid( -row => 1, -column => 2, -padx => 3, -pady => 4 );
        my $frame2 = $::lglobal{footpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        $frame2->Button(
            -activebackground => $::activecolor,
            -command          => sub {
                $textwindow->yview('end');
                $textwindow->see( $::lglobal{fnarray}->[ $::lglobal{fnindex} ][2] )
                  if $::lglobal{fnarray}->[ $::lglobal{fnindex} ][2];
            },
            -text  => 'See Anchor',
            -width => 14
        )->grid( -row => 1, -column => 1, -padx => 2, -pady => 4 );
        $::lglobal{footnotetotal} = $frame2->Label->grid( -row => 1, -column => 2 );
        $frame2->Button(
            -activebackground => $::activecolor,
            -command          => sub {
                footnoteshow();
            },
            -text  => 'See Footnote',
            -width => 14
        )->grid( -row => 1, -column => 3, -padx => 2, -pady => 4 );
        $frame2->Button(
            -activebackground => $::activecolor,
            -command          => sub {
                $::lglobal{fnindex}--;
                footnoteshow();
            },
            -text  => '<--- Prev. FN',
            -width => 14
        )->grid( -row => 2, -column => 1 );
        $::lglobal{fnindexbrowse} = $frame2->BrowseEntry(
            -label     => 'Go to - #',
            -variable  => \$::lglobal{fnindex},
            -state     => 'readonly',
            -width     => 8,
            -listwidth => 22,
            -browsecmd => sub {
                footnoteshow();
            }
        )->grid( -row => 2, -column => 2 );
        $frame2->Button(
            -activebackground => $::activecolor,
            -command          => sub {
                $::lglobal{fnindex}++;
                footnoteshow();
            },
            -text  => 'Next FN --->',
            -width => 14
        )->grid( -row => 2, -column => 3 );
        my $frame3 = $::lglobal{footpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        $::lglobal{footnotenumber} = $frame3->Label(
            -background => $::bkgcolor,
            -relief     => 'sunken',
            -justify    => 'center',
            -font       => '{Times} 10',
            -width      => 10,
        )->grid( -row => 3, -column => 1, -padx => 2, -pady => 4 );
        $::lglobal{footnoteletter} = $frame3->Label(
            -background => $::bkgcolor,
            -relief     => 'sunken',
            -justify    => 'center',
            -font       => '{Times} 10',
            -width      => 10,
        )->grid( -row => 3, -column => 2, -padx => 2, -pady => 4 );
        $::lglobal{footnoteroman} = $frame3->Label(
            -background => $::bkgcolor,
            -relief     => 'sunken',
            -justify    => 'center',
            -font       => '{Times} 10',
            -width      => 10,
        )->grid( -row => 3, -column => 3, -padx => 2, -pady => 4 );
        $checkn = $frame3->Checkbutton(
            -variable => \$::lglobal{fntypen},
            -command  => sub {
                return if ( $::lglobal{footstyle} eq 'inline' );
                $checka->deselect;
                $checkr->deselect;
            },
            -text  => 'All to Number',
            -width => 14
        )->grid( -row => 5, -column => 1, -padx => 2, -pady => 4 );
        $checka = $frame3->Checkbutton(
            -variable => \$::lglobal{fntypea},
            -command  => sub {
                return if ( $::lglobal{footstyle} eq 'inline' );
                $checkn->deselect;
                $checkr->deselect;
            },
            -text  => 'All to Letter',
            -width => 14
        )->grid( -row => 5, -column => 2, -padx => 2, -pady => 4 );
        $checkr = $frame3->Checkbutton(
            -variable => \$::lglobal{fntyper},
            -command  => sub {
                return if ( $::lglobal{footstyle} eq 'inline' );
                $checka->deselect;
                $checkn->deselect;
            },
            -text  => 'All to Roman',
            -width => 14
        )->grid( -row => 5, -column => 3, -padx => 2, -pady => 4 );
        $frame3->Button(
            -activebackground => $::activecolor,
            -command          => sub {
                return if ( $::lglobal{footstyle} eq 'inline' );
                fninsertmarkers('n');
                footnoteshow();
            },
            -text  => 'Number',
            -width => 14
        )->grid( -row => 4, -column => 1, -padx => 2, -pady => 4 );
        $frame3->Button(
            -activebackground => $::activecolor,
            -command          => sub {
                return if ( $::lglobal{footstyle} eq 'inline' );
                fninsertmarkers('a');
                footnoteshow();
            },
            -text  => 'Letter',
            -width => 14
        )->grid( -row => 4, -column => 2, -padx => 2, -pady => 4 );
        $frame3->Button(
            -activebackground => $::activecolor,
            -command          => sub {
                return if ( $::lglobal{footstyle} eq 'inline' );
                fninsertmarkers('r');
                footnoteshow();
            },
            -text  => 'Roman',
            -width => 14
        )->grid( -row => 4, -column => 3, -padx => 2, -pady => 4 );
        my $frame4 = $::lglobal{footpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        my $fnrb1  = $frame4->Radiobutton(
            -text        => 'Inline',
            -variable    => \$::lglobal{footstyle},
            -selectcolor => $::lglobal{checkcolor},
            -value       => 'inline',
            -command     => sub {
                $::lglobal{fnindex} = 1;
                footnoteshow();
                $::lglobal{fnmvbutton}->configure( -state => 'disabled' );
            },
        )->grid( -row => 8, -column => 1 );
        $::lglobal{fnfpbutton} = $frame4->Button(
            -activebackground => $::activecolor,
            -command          => sub { &footnotefixup() },
            -text             => 'Reindex',
            -state            => 'disabled',
            -width            => 14
        )->grid( -row => 8, -column => 3, -padx => 2, -pady => 4 );
        my $fnrb2 = $frame4->Radiobutton(
            -text        => 'Out-of-Line',
            -variable    => \$::lglobal{footstyle},
            -selectcolor => $::lglobal{checkcolor},
            -value       => 'end',
            -command     => sub {
                $::lglobal{fnindex} = 1;
                footnoteshow();
                $::lglobal{fnmvbutton}->configure( -state => 'normal' )
                  if ( $::lglobal{fnsecondpass}
                    && ( defined $::lglobal{fnlzs} and @{ $::lglobal{fnlzs} } ) );
            },
        )->grid( -row => 8, -column => 2 );
        my $frame6 = $::lglobal{footpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        $frame6->Button(
            -activebackground => $::activecolor,
            -command          => sub { setlz() },
            -text             => 'Set LZ @ cursor',
            -width            => 14
        )->grid( -row => 1, -column => 1, -padx => 2, -pady => 4 );
        $frame6->Button(
            -activebackground => $::activecolor,
            -command          => sub { autochaptlz() },
            -text             => 'Autoset Chap. LZ',
            -width            => 14
        )->grid( -row => 1, -column => 2, -padx => 2, -pady => 4 );
        $frame6->Button(
            -activebackground => $::activecolor,
            -command          => sub { autoendlz() },
            -text             => 'Autoset End LZ',
            -width            => 14
        )->grid( -row => 1, -column => 3, -padx => 2, -pady => 4 );
        $frame6->Button(
            -activebackground => $::activecolor,
            -command          => sub {
                getlz();
                return                  unless $::lglobal{fnlzs} and @{ $::lglobal{fnlzs} };
                $::lglobal{zoneindex}-- unless $::lglobal{zoneindex} < 1;
                if ( $::lglobal{fnlzs}[ $::lglobal{zoneindex} ] ) {
                    $textwindow->see( 'LZ' . $::lglobal{zoneindex} );
                    $textwindow->tagRemove( 'highlight', '1.0', 'end' );
                    $textwindow->tagAdd(
                        'highlight',
                        'LZ' . $::lglobal{zoneindex},
                        'LZ' . $::lglobal{zoneindex} . '+10c'
                    );
                }
            },
            -text  => '<--- Prev. LZ',
            -width => 12
        )->grid( -row => 2, -column => 1, -padx => 2, -pady => 4 );
        $frame6->Button(
            -activebackground => $::activecolor,
            -command          => sub {
                getlz();
                return unless $::lglobal{fnlzs} and @{ $::lglobal{fnlzs} };
                $::lglobal{zoneindex}++
                  unless $::lglobal{zoneindex} > ( ( scalar( @{ $::lglobal{fnlzs} } ) ) - 2 );
                if ( $::lglobal{fnlzs}[ $::lglobal{zoneindex} ] ) {
                    $textwindow->see( 'LZ' . $::lglobal{zoneindex} );
                    $textwindow->tagRemove( 'highlight', '1.0', 'end' );
                    $textwindow->tagAdd(
                        'highlight',
                        'LZ' . $::lglobal{zoneindex},
                        'LZ' . $::lglobal{zoneindex} . '+10c'
                    );
                }
            },
            -text  => 'Next LZ --->',
            -width => 12
        )->grid( -row => 2, -column => 3, -padx => 6, -pady => 4 );
        my $frame7 = $::lglobal{footpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        $::lglobal{fnmvbutton} = $frame7->Button(
            -activebackground => $::activecolor,
            -command          => sub { footnotemove() },
            -text             => 'Move FNs to Landing Zone(s)',
            -state            => 'disabled',
            -width            => 30
        )->grid( -row => 1, -column => 2, -padx => 3, -pady => 4 );
        $::lglobal{fnmvinlinebutton} = $frame7->Button(
            -activebackground => $::activecolor,
            -command          => sub { footnotemoveinline() },
            -text             => 'Move FNs to Para',
            -state            => 'disabled',
            -width            => 30
        )->grid( -row => 2, -column => 2, -padx => 3, -pady => 4 );
        my $frame8 = $::lglobal{footpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        $frame8->Button(
            -activebackground => $::activecolor,
            -command          => sub { footnotetidy() },
            -text             => 'Tidy Up Footnotes',
            -width            => 18
        )->grid( -row => 1, -column => 1, -padx => 6, -pady => 4 );
        ::initialize_popup_without_deletebinding('footpop');
        $::lglobal{footpop}->protocol(
            'WM_DELETE_WINDOW' => sub {
                ::killpopup('footcheckpop');
                ::killpopup('footpop');
                $textwindow->tagRemove( 'footnote', '1.0', 'end' );
            }
        );
        $fnrb2->select;
        $::lglobal{footpop}->Tk::bind( '<f>' => sub { fnfirstpass(); } );
        my ( $start, $end );
        $start = '1.0';
        while (1) {
            $start = $textwindow->markNext($start);
            last unless $start;
            next unless ( $start =~ /^fns/ );
            $end = $start;
            $end =~ s/^fns/fne/;
            $textwindow->tagAdd( 'footnote', $start, $end );
        }
        $::lglobal{footnotenumber}->configure( -text => $::lglobal{fncount} );
        $::lglobal{footnoteletter}->configure( -text => alpha( $::lglobal{fnalpha} ) );
        $::lglobal{footnoteroman}->configure( -text => ::roman( $::lglobal{fnroman} ) . '.' );
        $::lglobal{footnotetotal}
          ->configure( -text => "# $::lglobal{fnindex}" . "/" . "$::lglobal{fntotal}" );
        $::lglobal{fnsecondpass} = 0;
    }
}

sub fnfirstpass {
    $::lglobal{fnsecondpass} = 0;
    footnotefixup();
    fnview();
}

sub footnoteshow {
    my $textwindow = $::textwindow;
    if ( $::lglobal{fnindex} < 1 ) {
        $::lglobal{fnindex} = 1;
        return;
    }
    if ( $::lglobal{fnindex} > $::lglobal{fntotal} ) {
        $::lglobal{fnindex} = $::lglobal{fntotal};
        return;
    }
    $textwindow->tagRemove( 'footnote',  '1.0', 'end' );
    $textwindow->tagRemove( 'highlight', '1.0', 'end' );
    footnoteadjust();
    my $start     = $textwindow->index("fns$::lglobal{fnindex}");
    my $end       = $textwindow->index("fne$::lglobal{fnindex}");
    my $anchor    = $textwindow->index("fna$::lglobal{fnindex}");
    my $anchorend = $textwindow->index("fnb$::lglobal{fnindex}");
    my $line      = $textwindow->index('end -1l');
    $textwindow->yview('end');

    if ( $::lglobal{fncenter} ) {
        $textwindow->see($start) if $start;
    } else {
        my $widget = $textwindow->{rtext};
        my ( $lx, $ly, $lw, $lh ) = $widget->dlineinfo($line);
        my $bottom = int(
            (
                $widget->height -
                  2 * $widget->cget( -bd ) -
                  2 * $widget->cget( -highlightthickness )
            ) / $lh / 2
        ) - 1;
        $textwindow->see("$end-${bottom}l") if $start;
    }
    $textwindow->tagAdd( 'footnote', $start, $end ) if $start;
    $textwindow->markSet( 'insert', $start )        if $start;
    $textwindow->tagAdd( 'highlight', $anchor, $anchorend )
      if ( ( $anchor ne $start ) && $anchorend );
    $::lglobal{footnotetotal}->configure( -text => "# $::lglobal{fnindex}/$::lglobal{fntotal}" )
      if $::lglobal{footpop};
    ::update_indicators();
}

sub fninsertmarkers {
    my $style      = shift;
    my $textwindow = $::textwindow;
    my $offset     = $textwindow->search(
        '--', ':',
        $::lglobal{fnarray}->[ $::lglobal{fnindex} ][0],
        $::lglobal{fnarray}->[ $::lglobal{fnindex} ][1]
    );
    if ( $::lglobal{footstyle} eq 'end' ) {
        $textwindow->addGlobStart;
        $textwindow->delete( $::lglobal{fnarray}->[ $::lglobal{fnindex} ][0] . '+9c', $offset )
          if $offset;
        if ( $::lglobal{fnarray}->[ $::lglobal{fnindex} ][3] ne
            $::lglobal{fnarray}->[ $::lglobal{fnindex} ][2] ) {
            $textwindow->delete(
                $::lglobal{fnarray}->[ $::lglobal{fnindex} ][2],
                $::lglobal{fnarray}->[ $::lglobal{fnindex} ][3]
            );
        }
        $::lglobal{fnarray}->[ $::lglobal{fnindex} ][6] = $::lglobal{fncount}
          if $style eq 'n';
        $::lglobal{fnarray}->[ $::lglobal{fnindex} ][6] = $::lglobal{fnalpha}
          if $style eq 'a';
        $::lglobal{fnarray}->[ $::lglobal{fnindex} ][6] = $::lglobal{fnroman}
          if $style eq 'r';
        $::lglobal{fnarray}->[ $::lglobal{fnindex} ][5] = $style;
        $::lglobal{fnarray}->[ $::lglobal{fnindex} ][4] = $::lglobal{fncount}
          if $style eq 'n';
        $::lglobal{fnarray}->[ $::lglobal{fnindex} ][4] = alpha( $::lglobal{fnalpha} )
          if $style eq 'a';
        $::lglobal{fnarray}->[ $::lglobal{fnindex} ][4] = ::roman( $::lglobal{fnroman} ) . '.'
          if $style eq 'r';
        $::lglobal{fncount}++ if $style eq 'n';
        $::lglobal{fnalpha}++ if $style eq 'a';
        $::lglobal{fnroman}++ if $style eq 'r';
        footnoteadjust();
        $textwindow->insert(
            $::lglobal{fnarray}->[ $::lglobal{fnindex} ][0] . '+9c',
            ' ' . $::lglobal{fnarray}->[ $::lglobal{fnindex} ][4]
        );
        $textwindow->insert(
            $::lglobal{fnarray}->[ $::lglobal{fnindex} ][2],
            '[' . $::lglobal{fnarray}->[ $::lglobal{fnindex} ][4] . ']'
        );
        $::lglobal{fnarray}->[ $::lglobal{fnindex} ][3] =
          $textwindow->index( $::lglobal{fnarray}->[ $::lglobal{fnindex} ][2] . ' +'
              . ( length( $::lglobal{fnarray}->[ $::lglobal{fnindex} ][4] ) + 2 )
              . 'c' );
        $textwindow->markSet( "fna$::lglobal{fnindex}",
            $::lglobal{fnarray}->[ $::lglobal{fnindex} ][2] );
        $textwindow->markSet( "fnb$::lglobal{fnindex}",
            $::lglobal{fnarray}->[ $::lglobal{fnindex} ][3] );
        footnoteadjust();
        $::lglobal{footnotenumber}->configure( -text => $::lglobal{fncount} );
        $textwindow->addGlobEnd;
    }
}

# Join the footnote fnindex '*[Footnote:' with the previous.
sub fnjoin {
    my $textwindow = $::textwindow;
    $textwindow->addGlobStart;
    $textwindow->tagRemove( 'footnote',  '1.0', 'end' );
    $textwindow->tagRemove( 'highlight', '1.0', 'end' );

    # Find the colon in this footnote
    my $start = $textwindow->search(
        '--', ':',
        $::lglobal{fnarray}->[ $::lglobal{fnindex} ][0],
        $::lglobal{fnarray}->[ $::lglobal{fnindex} ][1]
    );

    # $end is the ending index of this footnote -1 character
    my $end = $::lglobal{fnarray}->[ $::lglobal{fnindex} ][1] . '-1c';

    # delete '*' at end of previous footnote
    $textwindow->delete( $::lglobal{fnarray}->[ $::lglobal{fnindex} - 1 ][1] )
      if ( $textwindow->get( $::lglobal{fnarray}->[ $::lglobal{fnindex} - 1 ][1] ) eq '*' );

    # Insert the text of this footnote at the end of the previous one
    $textwindow->insert( $::lglobal{fnarray}->[ $::lglobal{fnindex} - 1 ][1] . '-1c',
        "\n" . $textwindow->get( "$start+2c", $end ) );

    # delete markup
    my $markupl = $textwindow->get(
        $::lglobal{fnarray}->[ $::lglobal{fnindex} - 1 ][1] . '-4c',
        $::lglobal{fnarray}->[ $::lglobal{fnindex} - 1 ][1]
    );
    my $markupn = $textwindow->get(
        $::lglobal{fnarray}->[ $::lglobal{fnindex} - 1 ][1] . '+1c',
        $::lglobal{fnarray}->[ $::lglobal{fnindex} - 1 ][1] . '+4c'
    );
    if ( ( $markupl =~ /<\/([ibgf])>/i ) && ( $markupn =~ /<$1>/i ) ) {
        $textwindow->delete(
            $::lglobal{fnarray}->[ $::lglobal{fnindex} - 1 ][1] . '-4c',
            $::lglobal{fnarray}->[ $::lglobal{fnindex} - 1 ][1]
        );
        $textwindow->delete(
            $::lglobal{fnarray}->[ $::lglobal{fnindex} - 1 ][1] . '+1c',
            $::lglobal{fnarray}->[ $::lglobal{fnindex} - 1 ][1] . '+4c'
        );
    }
    footnoteadjust();

    # Delete this footnote
    $textwindow->delete( "fns$::lglobal{fnindex}-2c", "fne$::lglobal{fnindex}+1c" );
    $textwindow->delete( "fna$::lglobal{fnindex}",    "fnb$::lglobal{fnindex}" );
    $textwindow->delete( "fns$::lglobal{fnindex}-1c", "fns$::lglobal{fnindex}" )
      if ( $textwindow->get("fns$::lglobal{fnindex}-1c") eq '*' );
    $::lglobal{fnarray}->[ $::lglobal{fnindex} ][0] = '';
    $::lglobal{fnarray}->[ $::lglobal{fnindex} ][1] = '';
    footnoteadjust();
    $::lglobal{fncount}--
      if $::lglobal{fnarray}->[ $::lglobal{fnindex} ][5] eq 'n';
    $::lglobal{fnalpha}--
      if $::lglobal{fnarray}->[ $::lglobal{fnindex} ][5] eq 'a';
    $::lglobal{fnroman}--
      if $::lglobal{fnarray}->[ $::lglobal{fnindex} ][5] eq 'r';
    $::lglobal{fnindex}--;

    # reload the Check Footnotes window to update the list
    if ( defined( $::lglobal{footcheckpop} ) ) {
        ::killpopup('footcheckpop');
        fnview( $::lglobal{fnindex} );
    }
    footnoteshow();
    $textwindow->addGlobEnd;
}

# Pop up a window showing all the footnote addresses with potential
# problems highlighted
sub fnview {
    my $top        = $::top;
    my $textwindow = $::textwindow;
    my $fnindex    = shift;
    $fnindex = 0 unless $fnindex;
    my ( %fnotes, %anchors, $ftext );
    my $allcheckspassed = 1;    # flag if all checks passed
    ::hidepagenums();
    if ( defined( $::lglobal{footcheckpop} ) ) {
        $::lglobal{footcheckpop}->deiconify;
        $::lglobal{footcheckpop}->raise;
        $::lglobal{footcheckpop}->focus;
    } else {
        $::lglobal{footcheckpop} = $top->Toplevel;
        ::initialize_popup_with_deletebinding('footcheckpop');
        $::lglobal{footcheckpop}->title('Footnote Check');
        my $frame1 = $::lglobal{footcheckpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        $frame1->Label(
            -text => "Warning: You shouldn't attempt to reindex or auto-move footnotes\n"
              . "until you've addressed all warnings displayed here." )
          ->grid( -row => 0, -column => 1, -columnspan => 4 );
        $frame1->Label(
            -text       => "Duplicate anchors.\nmore than one fn\npointing to same anchor",
            -background => 'yellow',
        )->grid( -row => 1, -column => 1 );
        $frame1->Label(
            -text       => "No anchor found.\npossibly missing anchor,\nmissing colon, incorrect #",
            -background => 'pink',
        )->grid( -row => 1, -column => 2 );
        $frame1->Label(
            -text       => "Out of sequence.\nfn's not in same\norder as anchors",
            -background => 'cyan',
        )->grid( -row => 1, -column => 3 );
        $frame1->Label(
            -text       => "Very long.\nfn missing its end bracket?\n(may just be a long fn.)",
            -background => 'tan',
        )->grid( -row => 1, -column => 4 );
        my $duplbl = $frame1->Label( -background => 'yellow' )
          ->grid( -row => 2, -column => 1, -sticky => 'ew' );
        my $noanchlbl =
          $frame1->Label( -background => 'pink' )->grid( -row => 2, -column => 2, -sticky => 'ew' );
        my $seqlbl =
          $frame1->Label( -background => 'cyan' )->grid( -row => 2, -column => 3, -sticky => 'ew' );
        my $longlbl =
          $frame1->Label( -background => 'tan' )->grid( -row => 2, -column => 4, -sticky => 'ew' );
        my $frame2 = $::lglobal{footcheckpop}->Frame->pack(
            -side   => 'top',
            -anchor => 'n',
            -fill   => 'both',
            -expand => 'both'
        );
        $ftext = $frame2->Scrolled(
            'ROText',
            -scrollbars => 'se',
            -background => $::bkgcolor,
            -font       => 'proofing',
        )->pack(
            -anchor => 'nw',
            -fill   => 'both',
            -expand => 'both',
            -padx   => 2,
            -pady   => 2
        );
        ::drag($ftext);
        $ftext->tagConfigure( 'seq',    background => 'cyan' );
        $ftext->tagConfigure( 'dup',    background => 'yellow' );
        $ftext->tagConfigure( 'noanch', background => 'pink' );
        $ftext->tagConfigure( 'long',   background => 'tan' );

        $::lglobal{footcheckpop}->eventAdd( '<<find>>' => '<Double-Button-1>', '<Return>' );
        $::lglobal{footcheckpop}->bind(
            '<<find>>',
            sub {
                my ( $row, $col ) = split( /\./, $ftext->index('insert') );
                $::lglobal{fnindex} = $row;
                footnoteshow();
            }
        );
        my ( $noanchcount, $seqcount, $dupcount, $longcount ) = ( 0, 0, 0, 0 );
        for my $findex ( 1 .. $::lglobal{fntotal} ) {
            $ftext->insert( 'end',
                    'footnote #'
                  . $findex
                  . '  line.column - '
                  . $::lglobal{fnarray}->[$findex][0]
                  . ",\tanchor line.column - "
                  . $::lglobal{fnarray}->[$findex][2]
                  . "\n" );
            if ( $::lglobal{fnarray}->[$findex][0] eq $::lglobal{fnarray}->[$findex][2] ) {
                $ftext->tagAdd( 'noanch', 'end -2l', 'end -1l' );
                $ftext->update;
                $noanchcount++;
                $allcheckspassed = 0;
            }
            if (
                ( $findex > 1 )
                && (
                    $textwindow->compare(
                        $::lglobal{fnarray}->[$findex][0], '<',
                        $::lglobal{fnarray}->[ $findex - 1 ][0]
                    )
                    || $textwindow->compare(
                        $::lglobal{fnarray}->[$findex][2], '<',
                        $::lglobal{fnarray}->[ $findex - 1 ][2]
                    )
                )
            ) {
                $ftext->tagAdd( 'seq', 'end -2l', 'end -1l' );
                $ftext->update;
                $seqcount++;
                $allcheckspassed = 0;
            }
            if ( exists $fnotes{ $::lglobal{fnarray}->[$findex][2] } ) {
                $ftext->tagAdd( 'dup', 'end -2l', 'end -1l' );
                $ftext->update;
                $dupcount++;
                $allcheckspassed = 0;
            }

            # Long footnote, or if suitable closing bracket is not found, footnotefind sets the end
            # to 10 chars after start, i.e. impossibly short.
            # Either way, mark as a potentially long, potentially missing bracket footnote
            if (
                $::lglobal{fnarray}->[$findex][1] - $::lglobal{fnarray}->[$findex][0] > 40
                or $textwindow->compare(
                    "$::lglobal{fnarray}->[$findex][0] + 11c", '>',
                    $::lglobal{fnarray}->[$findex][1]
                )
            ) {
                $ftext->tagAdd( 'long', 'end -2l', 'end -1l' );
                $ftext->update;
                $longcount++;

                # do not change $allcheckspassed=0;
            }
            $fnotes{ $::lglobal{fnarray}->[$findex][2] } = $findex;
        }
        $noanchlbl->configure( -text => "Found $noanchcount" );
        $seqlbl->configure( -text => "Found $seqcount" );
        $duplbl->configure( -text => "Found $dupcount" );
        $longlbl->configure( -text => "Found $longcount" );
        if ($allcheckspassed) {
            ::operationadd('Footnote check passed');
        }
        $ftext->see("1.0 + $fnindex l") if $fnindex;
    }
}

# @{$::lglobal{fnarray}} is an array of arrays
#
# $::lglobal{fnarray}->[$::lglobal{fnindex}][0] = starting index of footnote.
# $::lglobal{fnarray}->[$::lglobal{fnindex}][1] = ending index of footnote.
# $::lglobal{fnarray}->[$::lglobal{fnindex}][2] = index of footnote anchor.
# $::lglobal{fnarray}->[$::lglobal{fnindex}][3] = index of footnote anchor end.
# $::lglobal{fnarray}->[$::lglobal{fnindex}][4] = anchor label.
# $::lglobal{fnarray}->[$::lglobal{fnindex}][5] = anchor type n a r (numeric, alphabet, roman)
# $::lglobal{fnarray}->[$::lglobal{fnindex}][6] = type index
sub footnotefixup {
    my $top        = $::top;
    my $textwindow = $::textwindow;
    ::hidelinenumbers();    # To speed updating of text window
    ::hidepagenums();
    ::operationadd('Reindex footnotes') if $::lglobal{fnsecondpass} == 1;
    my ( $start, $end, $anchor, $pointer );
    $textwindow->markSet( 'lastfnindex', '1.0' );

    $start              = 1;
    $::lglobal{fncount} = '1';
    $::lglobal{fnalpha} = '1';
    $::lglobal{fnroman} = '1';
    if ( defined( $::lglobal{footcheckpop} ) ) {
        ::killpopup('footcheckpop');
    }

    $::lglobal{fnindexbrowse}->delete( '0', 'end' ) if $::lglobal{footpop};
    $::lglobal{footnotenumber}->configure( -text => $::lglobal{fncount} )
      if $::lglobal{footpop};
    $::lglobal{footnoteletter}->configure( -text => alpha( $::lglobal{fnalpha} ) )
      if $::lglobal{footpop};
    $::lglobal{footnoteroman}->configure( -text => ::roman( $::lglobal{fnroman} ) . '.' )
      if $::lglobal{footpop};
    $::lglobal{ftnoteindexstart} = '1.0';
    $textwindow->markSet( 'fnindex', $::lglobal{ftnoteindexstart} );
    $::lglobal{fntotal} = 0;
    $textwindow->tagRemove( 'footnote',  '1.0', 'end' );
    $textwindow->tagRemove( 'highlight', '1.0', 'end' );

    $textwindow->addGlobStart;
    while (1) {
        $::lglobal{ftnoteindexstart} =
          $textwindow->search( '-exact', '--', '[ Footnote', '1.0', 'end' );
        last unless $::lglobal{ftnoteindexstart};
        $textwindow->delete( "$::lglobal{ftnoteindexstart}+1c", "$::lglobal{ftnoteindexstart}+2c" );
    }
    while (1) {
        $::lglobal{ftnoteindexstart} =
          $textwindow->search( '-exact', '--', '{Footnote', '1.0', 'end' );
        last unless $::lglobal{ftnoteindexstart};
        $textwindow->delete( $::lglobal{ftnoteindexstart}, "$::lglobal{ftnoteindexstart}+1c" );
        $textwindow->insert( $::lglobal{ftnoteindexstart}, '[' );
    }

    # Misspelled Fotonote
    while (1) {
        $::lglobal{ftnoteindexstart} =
          $textwindow->search( '-exact', '--', '[Fotonote', '1.0', 'end' );
        last unless $::lglobal{ftnoteindexstart};
        $textwindow->delete( "$::lglobal{ftnoteindexstart}+1c", "$::lglobal{ftnoteindexstart}+9c" );
        $textwindow->insert( "$::lglobal{ftnoteindexstart}+1c", 'Footnote' );
    }

    # Misspelled Fotonoto
    while (1) {
        $::lglobal{ftnoteindexstart} =
          $textwindow->search( '-exact', '--', '[Footnoto', '1.0', 'end' );
        last unless $::lglobal{ftnoteindexstart};
        $textwindow->delete( "$::lglobal{ftnoteindexstart}+1c", "$::lglobal{ftnoteindexstart}+9c" );
        $textwindow->insert( "$::lglobal{ftnoteindexstart}+1c", 'Footnote' );
    }

    # Misspelled footnote
    while (1) {
        $::lglobal{ftnoteindexstart} =
          $textwindow->search( '-exact', '--', '[footnote', '1.0', 'end' );
        last unless $::lglobal{ftnoteindexstart};
        $textwindow->delete( "$::lglobal{ftnoteindexstart}+1c", "$::lglobal{ftnoteindexstart}+2c" );
        $textwindow->insert( "$::lglobal{ftnoteindexstart}+1c", 'F' );
    }
    $::lglobal{ftnoteindexstart} = '1.0';
    while (1) {
        ( $start, $end ) = footnotefind();
        last unless $start;
        $::lglobal{fntotal}++;
        $::lglobal{fnindex} = $::lglobal{fntotal};
        ( $start, $end ) = (
            $textwindow->index("fns$::lglobal{fnindex}"),
            $textwindow->index("fne$::lglobal{fnindex}")
        ) if $::lglobal{fnsecondpass};
        $pointer = '';
        $anchor  = '';
        $textwindow->see($start) if $start and not ::updatedrecently();
        $textwindow->tagAdd( 'footnote', $start, $end );
        $textwindow->markSet( 'insert', $start );
        $::lglobal{fnindexbrowse}->insert( 'end', $::lglobal{fnindex} )
          if $::lglobal{footpop};
        $::lglobal{footnotetotal}->configure( -text => "# $::lglobal{fnindex}/$::lglobal{fntotal}" )
          if $::lglobal{footpop};
        $pointer =
          $textwindow->get( $start,
            ( $textwindow->search( '--', ':', $start, "$start lineend" ) ) );
        $pointer =~ s/\[Footnote\s*//i;
        $pointer =~ s/\s*:$//;

        if ( length($pointer) > 20 ) {
            $pointer = '';
            $textwindow->insert( "$start+9c", ':' );
        }
        if ( $::lglobal{fnsearchlimit} ) {
            $anchor = $textwindow->search( '-backwards', '--', "[$pointer]", $start, '1.0' )
              if $pointer;
        } else {
            $anchor = $textwindow->search( '-backwards', '--', "[$pointer]", $start, "$start-80l" )
              if $pointer;
        }
        $textwindow->tagAdd( 'highlight', $anchor, $anchor . '+' . ( length($pointer) + 2 ) . 'c' )
          if $anchor;
        $::lglobal{fnarray}->[ $::lglobal{fnindex} ][0] = $start if $start;
        $::lglobal{fnarray}->[ $::lglobal{fnindex} ][1] = $end   if $end;
        $::lglobal{fnarray}->[ $::lglobal{fnindex} ][2] = $start
          unless ( $pointer && $anchor );
        $::lglobal{fnarray}->[ $::lglobal{fnindex} ][2] = $anchor if $anchor;
        $::lglobal{fnarray}->[ $::lglobal{fnindex} ][3] = $start
          unless ( $pointer && $anchor );
        $::lglobal{fnarray}->[ $::lglobal{fnindex} ][3] =
          $textwindow->index(
            $::lglobal{fnarray}->[ $::lglobal{fnindex} ][2] . '+' . ( length($pointer) + 2 ) . 'c' )
          if $anchor;
        $::lglobal{fnarray}->[ $::lglobal{fnindex} ][4] = $pointer if $pointer;

        if ($pointer) {
            $::lglobal{fnarray}->[ $::lglobal{fnindex} ][5] = 'n';
            if ( $pointer =~ /\p{IsAlpha}+/ ) {
                $::lglobal{fnarray}->[ $::lglobal{fnindex} ][5] = 'a';
                $::lglobal{fnarray}->[ $::lglobal{fnindex} ][4] = uc($pointer);
            }
            if ( $pointer =~ /[ivxlcdm]+\./i ) {
                $::lglobal{fnarray}->[ $::lglobal{fnindex} ][5] = 'r';
                $::lglobal{fnarray}->[ $::lglobal{fnindex} ][4] = uc($pointer);
            }
        } else {
            $::lglobal{fnarray}->[ $::lglobal{fnindex} ][5] = '';
        }
        $textwindow->markSet( "fns$::lglobal{fnindex}", $start );
        $textwindow->markSet( "fne$::lglobal{fnindex}", $end );
        $textwindow->markSet( "fna$::lglobal{fnindex}",
            $::lglobal{fnarray}->[ $::lglobal{fnindex} ][2] );
        $textwindow->markSet( "fnb$::lglobal{fnindex}",
            $::lglobal{fnarray}->[ $::lglobal{fnindex} ][3] );
        ::update_indicators();
        $textwindow->focus;
        $::lglobal{footpop}->raise if $::lglobal{footpop};

        if ( $::lglobal{fnsecondpass} ) {
            if ( $::lglobal{footstyle} eq 'end' ) {
                $::lglobal{fnsearchlimit} = 1;
                &fninsertmarkers('n')
                  if ( ( $::lglobal{fnarray}->[ $::lglobal{fnindex} ][5] eq 'n' )
                    || ( $::lglobal{fnarray}->[ $::lglobal{fnindex} ][5] eq '' )
                    || ( $::lglobal{fntypen} ) );
                &fninsertmarkers('a')
                  if ( ( $::lglobal{fnarray}->[ $::lglobal{fnindex} ][5] eq 'a' )
                    || ( $::lglobal{fntypea} ) );
                &fninsertmarkers('r')
                  if ( ( $::lglobal{fnarray}->[ $::lglobal{fnindex} ][5] eq 'r' )
                    || ( $::lglobal{fntyper} ) );
                $::lglobal{fnmvbutton}->configure( '-state' => 'normal' )
                  if ( defined $::lglobal{fnlzs} and @{ $::lglobal{fnlzs} } );
            } else {
                $textwindow->markSet( 'insert', 'fna' . $::lglobal{fnindex} );
                $::lglobal{fnarray}->[ $::lglobal{fnindex} ][4] = '';
                &setanchor();
            }
        }
    }
    $textwindow->addGlobEnd;
    $::lglobal{fnindex}      = 1;
    $::lglobal{fnsecondpass} = 1;
    if ( $::lglobal{footpop} ) {
        $::lglobal{fnfpbutton}->configure( '-state' => 'normal' );
        $::lglobal{fnmvinlinebutton}->configure( '-state' => 'normal' );
    }
    footnoteshow();
    ::restorelinenumbers();
}

sub getlz {
    my $textwindow = $::textwindow;
    my $index      = '1.0';
    my $zone       = 0;
    $::lglobal{fnlzs} = ();
    my @marks = grep( /^LZ/, $textwindow->markNames );
    for my $mark (@marks) {
        $textwindow->markUnset($mark);
    }
    while (1) {
        $index = $textwindow->search( '-regex', '--', '^FOOTNOTES:$', $index, 'end' );
        last unless $index;
        push @{ $::lglobal{fnlzs} }, $index;
        $textwindow->markSet( "LZ$zone", $index );
        $index = $textwindow->index("$index +10c");
        $zone++;
    }
}

sub autochaptlz {
    my $textwindow = $::textwindow;
    $::lglobal{zoneindex} = 0;
    $::lglobal{fnlzs}     = ();
    my $char;
    $textwindow->addGlobStart;
    while (1) {
        $char = $textwindow->get('end-2c');
        last if ( $char =~ /\S/ );
        $textwindow->delete('end-2c');
        $textwindow->update;
    }
    $textwindow->insert( 'end', "\n\n" );
    my $index = '200.0';
    while (1) {
        $index = $textwindow->search( '-regex', '--', '^$', $index, 'end' );
        last unless ($index);
        last if ( $index < '100.0' );
        if (   ( $textwindow->index("$index+1l") ) eq ( $textwindow->index("$index+1c") )
            && ( $textwindow->index("$index+2l") ) eq ( $textwindow->index("$index+2c") )
            && ( $textwindow->index("$index+3l") ) eq ( $textwindow->index("$index+3c") ) ) {
            $textwindow->markSet( 'insert', "$index+1l" );
            setlz();
            $index .= '+4l';
        } else {
            $index .= '+1l';
            next;
        }
    }
    $textwindow->addGlobEnd;
}

sub autoendlz {
    my $textwindow = $::textwindow;
    $textwindow->markSet( 'insert', 'end -1c' );

    #$textwindow->insert( 'insert', "FOOTNOTES:\n\n" );
    setlz();
}

sub setlz {
    my $textwindow = $::textwindow;

    # Put footnotes at the end of the previous page before a chapter <-- not working
    my $markindex = $textwindow->markPrevious('insert');
    if ( $textwindow->compare( $markindex, '<', 'insert-2l' ) ) {
        $textwindow->insert( 'insert', "FOOTNOTES:\n\n" );
    } else {

        #$textwindow->insert( $markindex.'-1c', "\n\nFOOTNOTES:" );
        $textwindow->insert( $markindex, "\n\nFOOTNOTES:" );
    }
    $::lglobal{fnmvbutton}->configure( '-state' => 'normal' )
      if ( ( $::lglobal{fnsecondpass} ) && ( $::lglobal{footstyle} eq 'end' ) );
    $textwindow->see('insert');
}

sub footnotemove {
    my $textwindow = $::textwindow;
    my ( $lz, %footnotes, $zone, $index, $r, $c, $marker );
    ::operationadd('Moved footnotes to landing zone');
    $::lglobal{fnsecondpass} = 0;
    footnotefixup();
    autoendlz();
    getlz();
    $::lglobal{fnindex} = 1;
    $textwindow->addGlobStart;

    foreach my $lz ( @{ $::lglobal{fnlzs} } ) {
        if ( $::lglobal{fnarray}->[ $::lglobal{fnindex} ][0] ) {
            while (
                $textwindow->compare( $::lglobal{fnarray}->[ $::lglobal{fnindex} ][0], '<=', $lz ) )
            {
                $footnotes{$lz} .=
                  "\n\n" . $textwindow->get( "fns$::lglobal{fnindex}", "fne$::lglobal{fnindex}" );
                $::lglobal{fnindex}++;
                last if $::lglobal{fnindex} > $::lglobal{fntotal};
            }
        }
    }
    $::lglobal{fnindex} = $::lglobal{fntotal};
    while ( $::lglobal{fnindex} ) {
        $textwindow->delete("fne$::lglobal{fnindex} +1c")
          if ( $textwindow->get("fne$::lglobal{fnindex} +1c") eq "\n" );
        $textwindow->delete("fns$::lglobal{fnindex} -1c")
          if ( $textwindow->get("fns$::lglobal{fnindex} -1c") eq "\n" );

        # Try to remove extra line before moved footnote
        #$textwindow->delete("fns$::lglobal{fnindex} -1c")
        # if ( $textwindow->get("fns$::lglobal{fnindex} -1c") eq "\n" );
        $textwindow->delete( "fns$::lglobal{fnindex}", "fne$::lglobal{fnindex}" );
        $::lglobal{fnindex}--;
    }
    $zone = 0;
    foreach my $lz ( @{ $::lglobal{fnlzs} } ) {
        $textwindow->insert( $textwindow->index("LZ$zone +10c"), $footnotes{$lz} )
          if $footnotes{$lz};
        $footnotes{$lz} = '';
        $zone++;
    }
    $zone = 1;
    while ( $::lglobal{fnarray}->[$zone][4] ) {
        my $fna = $textwindow->index("fna$zone");
        my $fnb = $textwindow->index("fnb$zone");
        if ( $textwindow->get( "$fna -1c", $fna ) eq ' ' ) {
            $textwindow->delete( "$fna -1c", $fna );
            $fna = $textwindow->index("fna$zone -1c");
            $fnb = $textwindow->index("fnb$zone -1c");
            $textwindow->markSet( "fna$zone", $fna );
            $textwindow->markSet( "fnb$zone", $fnb );
        }
        ( $r, $c ) = split /\./, $fna;
        while ( $c eq '0' ) {
            $marker = $textwindow->get( $fna, $fnb );
            $textwindow->delete( $fna, $fnb );
            $r--;
            $textwindow->insert( "$r.end", $marker );
            ( $r, $c ) = split /\./, ( $textwindow->index("$r.end") );
        }
        $zone++;
    }
    @{ $::lglobal{fnlzs} }   = ();
    @{ $::lglobal{fnarray} } = ();
    $index              = '1.0';
    $::lglobal{fnindex} = 0;
    $::lglobal{fntotal} = 0;
    while (1) {
        $index = $textwindow->search( '-regex', '--', 'FOOTNOTES:', $index, 'end' );
        last unless ($index);
        unless ( $textwindow->get("$index +2l") =~ /^\[/ ) {
            $textwindow->delete( $index, "$index+12c" );
        }
        $index .= '+4l';
    }
    ::delblanklines();
    $textwindow->addGlobEnd;
    $::lglobal{fnmvbutton}->configure( '-state' => 'disabled' );
    $::lglobal{fnmvinlinebutton}->configure( '-state' => 'disabled' );
    $::lglobal{unlimitedsearchbutton}->select;
    $textwindow->markSet( 'insert', '1.0' );
    $textwindow->see('1.0');
}

sub footnotemoveinline {
    my $textwindow = $::textwindow;
    ::operationadd('Moved footnotes to end-of-paragraph');
    $::lglobal{fnindex} = $::lglobal{fntotal};
    $textwindow->addGlobStart;
    while ( $::lglobal{fnindex} ) {
        my $start     = $textwindow->index("fns$::lglobal{fnindex}");
        my $end       = $textwindow->index("fne$::lglobal{fnindex}");
        my $anchor    = $textwindow->index("fna$::lglobal{fnindex}");
        my $anchorend = $textwindow->index("fnb$::lglobal{fnindex}");

        # FIND NEXT PARA BREAK (next blank line, unless there's a page sep getting in the way)
        my $nextbreak = $textwindow->search( '-regex', '--', '^$', "$anchor", 'end' );
        if ( $textwindow->get( "$nextbreak -1l", "$nextbreak" ) =~ m/^-----/ ) {    # make sure we don't end at the top of the next page
            $nextbreak = "$nextbreak -1l";
            while ( $textwindow->get( "$nextbreak -1l", "$nextbreak" ) =~ m/(^-----|^\[)/ ) {

                # possibly skip over several pages, possibly [Blanks
                $nextbreak = "$nextbreak -1l";
            }
        }
        my $footnotetext = $textwindow->get( "$start", "$end" );
        $textwindow->delete("$end +1c")
          if ( $textwindow->get("$end +1c") eq "\n" );
        $textwindow->delete("$start -1c")
          if ( $textwindow->get("$start -1c") eq "\n" );
        $textwindow->delete( "fns$::lglobal{fnindex}", "fne$::lglobal{fnindex}" );

        # INSERT THE FOOTNOTE AT ITS NEW LOCATION
        # -1c ensures that we get on the right side of page break markers
        $textwindow->insert( "$nextbreak -1c", "\n\n$footnotetext" );
        $::lglobal{fnindex}--;
    }
    ::delblanklines();
    $textwindow->addGlobEnd;
    $::lglobal{fnmvbutton}->configure( '-state' => 'disabled' );
    $::lglobal{fnmvinlinebutton}->configure( '-state' => 'disabled' );
}

sub footnoteadjust {
    my $textwindow = $::textwindow;
    my $end        = $::lglobal{fnarray}->[ $::lglobal{fnindex} ][1];
    my $start      = $::lglobal{fnarray}->[ $::lglobal{fnindex} ][0];
    my $tempsave   = $::lglobal{ftnoteindexstart};
    my $label;
    unless ( $start and $::lglobal{fnindex} ) {
        $tempsave = $::lglobal{fnindex};
        $::lglobal{fnarray}->[ $::lglobal{fnindex} ] = ();
        my $type = $::lglobal{fnarray}->[ $::lglobal{fnindex} ][5];
        $::lglobal{fncount}-- if $type and $type eq 'n';
        $::lglobal{fnalpha}-- if $type and $type eq 'a';
        $::lglobal{fnroman}-- if $type and $type eq 'r';
        while ( $::lglobal{fnarray}->[ $::lglobal{fnindex} + 1 ][0] ) {
            $::lglobal{fnarray}->[ $::lglobal{fnindex} ][0] =
              $textwindow->index( 'fns' . ( $::lglobal{fnindex} + 1 ) );
            $textwindow->markSet( "fns$::lglobal{fnindex}",
                $::lglobal{fnarray}->[ $::lglobal{fnindex} ][0] );
            $::lglobal{fnarray}->[ $::lglobal{fnindex} ][1] =
              $textwindow->index( 'fne' . ( $::lglobal{fnindex} + 1 ) );
            $textwindow->markSet( "fne$::lglobal{fnindex}",
                $::lglobal{fnarray}->[ $::lglobal{fnindex} ][1] );
            $::lglobal{fnarray}->[ $::lglobal{fnindex} ][2] =
              $textwindow->index( 'fna' . ( $::lglobal{fnindex} + 1 ) );
            $textwindow->markSet( "fna$::lglobal{fnindex}",
                $::lglobal{fnarray}->[ $::lglobal{fnindex} ][2] );
            $::lglobal{fnarray}->[ $::lglobal{fnindex} ][3] = '';
            $::lglobal{fnarray}->[ $::lglobal{fnindex} ][3] =
              $textwindow->index( 'fnb' . ( $::lglobal{fnindex} + 1 ) )
              if $::lglobal{fnarray}->[ $::lglobal{fnindex} + 1 ][3];
            $textwindow->markSet( "fnb$::lglobal{fnindex}",
                $::lglobal{fnarray}->[ $::lglobal{fnindex} ][3] )
              if $::lglobal{fnarray}->[ $::lglobal{fnindex} + 1 ][3];
            $::lglobal{fnarray}->[ $::lglobal{fnindex} ][4] =
              $::lglobal{fnarray}->[ $::lglobal{fnindex} + 1 ][4];
            $::lglobal{fnarray}->[ $::lglobal{fnindex} ][5] =
              $::lglobal{fnarray}->[ $::lglobal{fnindex} + 1 ][5];
            $::lglobal{fnarray}->[ $::lglobal{fnindex} ][6] =
              $::lglobal{fnarray}->[ $::lglobal{fnindex} + 1 ][6];
            $::lglobal{fnindex}++;
        }
        $::lglobal{footnotenumber}->configure( -text => $::lglobal{fncount} );
        $::lglobal{footnoteletter}->configure( -text => alpha( $::lglobal{fnalpha} ) );
        $::lglobal{footnoteroman}->configure( -text => ::roman( $::lglobal{fnroman} ) . '.' );
        $::lglobal{fnarray}->[ $::lglobal{fnindex} ] = ();
        $::lglobal{fnindex} = $tempsave;
        $::lglobal{fntotal}--;
        $::lglobal{footnotetotal}
          ->configure( -text => "# $::lglobal{fnindex}/$::lglobal{fntotal}" );
        return;
    }
    $textwindow->tagRemove( 'footnote', $start, $end );
    if ( $::lglobal{fnindex} > 1 ) {
        $::lglobal{ftnoteindexstart} =
          $::lglobal{fnarray}->[ $::lglobal{fnindex} - 1 ][1];
        $textwindow->markSet( 'fnindex', $::lglobal{ftnoteindexstart} );
    } else {
        $::lglobal{ftnoteindexstart} = '1.0';
        $textwindow->markSet( 'fnindex', $::lglobal{ftnoteindexstart} );
    }

    #print "\n$start|$end|$::lglobal{fnindex}, $::lglobal{ftnoteindexstart}\n";
    ( $start, $end ) = footnotefind();
    $textwindow->markSet( "fns$::lglobal{fnindex}", $start );
    $textwindow->markSet( "fne$::lglobal{fnindex}", $end );
    $::lglobal{ftnoteindexstart} = $tempsave;
    $textwindow->markSet( 'fnindex', $::lglobal{ftnoteindexstart} );
    $textwindow->tagAdd( 'footnote', $start, $end );
    $textwindow->markSet( 'insert', $start );
    $::lglobal{footnotenumber}->configure( -text => $::lglobal{fncount} )
      if $::lglobal{footpop};
    $::lglobal{footnoteletter}->configure( -text => alpha( $::lglobal{fnalpha} ) )
      if $::lglobal{footpop};
    $::lglobal{footnoteroman}->configure( -text => ::roman( $::lglobal{fnroman} ) . '.' )
      if $::lglobal{footpop};

    if ( $end eq "$start+10c" ) {
        ::soundbell();
        return;
    }
    $::lglobal{fnarray}->[ $::lglobal{fnindex} ][0] = $start if $start;
    $::lglobal{fnarray}->[ $::lglobal{fnindex} ][1] = $end   if $end;
    $textwindow->focus;
    $::lglobal{footpop}->raise if $::lglobal{footpop};
    return ( $start, $end );
}

# Clean up footnotes in txt version. Note: destructive. Use only
# at end of editing.
sub footnotetidy {
    my $textwindow = $::textwindow;
    my ( $begin, $end, $colon );
    $::lglobal{fnsecondpass} = 0;
    footnotefixup();
    return unless $::lglobal{fntotal} > 0;
    $::lglobal{fnindex} = 1;
    ::hidelinenumbers();    # To speed updating of text window
    $textwindow->addGlobStart;

    while (1) {
        $begin = $textwindow->index( 'fns' . $::lglobal{fnindex} );
        $textwindow->delete( "$begin+1c", "$begin+10c" );
        $colon =
          $textwindow->search( '--', ':', $begin,
            $textwindow->index( 'fne' . $::lglobal{fnindex} ) );
        $textwindow->delete($colon)        if $colon;
        $textwindow->insert( $colon, ']' ) if $colon;
        $end = $textwindow->index( 'fne' . $::lglobal{fnindex} );
        $textwindow->delete("$end-1c");
        $textwindow->tagAdd( 'sel', 'fns' . $::lglobal{fnindex}, "$end+1c" );
        ::selectrewrap('silentmode');    # slow to rewrap if screen updated for every note
        $::lglobal{fnindex}++;
        last if $::lglobal{fnindex} > $::lglobal{fntotal};
        $textwindow->update unless ::updatedrecently();    # do occasional updates
    }
    $textwindow->addGlobEnd;
    ::restorelinenumbers();
}

sub setanchor {
    my $textwindow = $::textwindow;
    my ( $index, $insert );
    $insert = $textwindow->index('insert');
    if ( $::lglobal{fnarray}->[ $::lglobal{fnindex} ][0] ne
        $::lglobal{fnarray}->[ $::lglobal{fnindex} ][2] ) {
        $textwindow->delete(
            $::lglobal{fnarray}->[ $::lglobal{fnindex} ][2],
            $::lglobal{fnarray}->[ $::lglobal{fnindex} ][3]
        ) if $::lglobal{fnarray}->[ $::lglobal{fnindex} ][3];
    } else {
        $::lglobal{fnarray}->[ $::lglobal{fnindex} ][2] = $insert;
    }
    footnoteadjust();
    if ( $::lglobal{footstyle} eq 'inline' ) {
        $index = $textwindow->search( ':', "fns$::lglobal{fnindex}", "fne$::lglobal{fnindex}" );
        $textwindow->delete( "fns$::lglobal{fnindex}+9c", $index ) if $index;
        footnoteadjust();
        my $fn = $textwindow->get(
            $textwindow->index( 'fns' . $::lglobal{fnindex} ),
            $textwindow->index( 'fne' . $::lglobal{fnindex} )
        );
        $textwindow->insert( $textwindow->index("fna$::lglobal{fnindex}"), $fn )
          if $textwindow->compare( $textwindow->index("fna$::lglobal{fnindex}"),
            '>', $textwindow->index("fns$::lglobal{fnindex}") );
        $textwindow->delete(
            $textwindow->index("fns$::lglobal{fnindex}"),
            $textwindow->index("fne$::lglobal{fnindex}")
        );
        $textwindow->insert( $textwindow->index("fna$::lglobal{fnindex}"), $fn )
          if $textwindow->compare( $textwindow->index("fna$::lglobal{fnindex}"),
            '<=', $textwindow->index("fns$::lglobal{fnindex}") );
        $::lglobal{fnarray}->[ $::lglobal{fnindex} ][0] =
          $textwindow->index( 'fns' . $::lglobal{fnindex} );
        $::lglobal{fnarray}->[ $::lglobal{fnindex} ][4] = '';
        $::lglobal{fnarray}->[ $::lglobal{fnindex} ][3] = '';
        $::lglobal{fnarray}->[ $::lglobal{fnindex} ][6] = '';
        footnoteadjust();
    } else {
        $::lglobal{fnarray}->[ $::lglobal{fnindex} ][2] = $insert;
        if (
            $textwindow->compare(
                $::lglobal{fnarray}->[ $::lglobal{fnindex} ][2],
                '>',
                $::lglobal{fnarray}->[ $::lglobal{fnindex} ][0]
            )
        ) {
            $::lglobal{fnarray}->[ $::lglobal{fnindex} ][2] =
              $::lglobal{fnarray}->[ $::lglobal{fnindex} ][0];
        }
        $textwindow->insert(
            $::lglobal{fnarray}->[ $::lglobal{fnindex} ][2],
            '[' . $::lglobal{fnarray}->[ $::lglobal{fnindex} ][4] . ']'
        );
        $textwindow->update;
        $::lglobal{fnarray}->[ $::lglobal{fnindex} ][3] =
          $textwindow->index( $::lglobal{fnarray}->[ $::lglobal{fnindex} ][2] . '+'
              . ( length( $::lglobal{fnarray}->[ $::lglobal{fnindex} ][4] ) + 2 )
              . 'c' );
        $textwindow->markSet( "fna$::lglobal{fnindex}",
            $::lglobal{fnarray}->[ $::lglobal{fnindex} ][2] );
        $textwindow->markSet( "fnb$::lglobal{fnindex}",
            $::lglobal{fnarray}->[ $::lglobal{fnindex} ][3] );
        footnoteadjust();
        footnoteshow();
    }
}

sub footnotefind {
    my $textwindow = $::textwindow;
    my ( $bracketndx, $nextbracketndx, $bracketstartndx, $bracketendndx );
    $::lglobal{ftnoteindexstart} = $textwindow->index('fnindex');
    $bracketstartndx =
      $textwindow->search( '-nocase', '--', '[Footnote', $::lglobal{ftnoteindexstart}, 'end' );
    return ( 0, 0 ) unless $bracketstartndx;
    $bracketndx = "$bracketstartndx+1c";
    while (1) {
        $bracketendndx = $textwindow->search( '--', ']', $bracketndx, 'end' );
        $bracketendndx = $textwindow->index("$bracketstartndx+9c")
          unless $bracketendndx;
        $bracketendndx = $textwindow->index("$bracketendndx+1c")
          if $bracketendndx;
        $nextbracketndx = $textwindow->search( '--', '[', $bracketndx, 'end' );
        if (   ($nextbracketndx)
            && ( $textwindow->compare( $nextbracketndx, '<', $bracketendndx ) ) ) {
            $bracketndx = $bracketendndx;
            next;
        }
        last;
    }
    $::lglobal{ftnoteindexstart} = "$bracketstartndx+1c";
    $textwindow->markSet( 'fnindex', $::lglobal{ftnoteindexstart} );
    my $lastfnindex = $textwindow->index('lastfnindex');
    if ( $textwindow->compare( $lastfnindex, '<', $bracketendndx ) ) {
        $textwindow->markSet( 'lastfnindex', $bracketendndx );
    }
    return ( $bracketstartndx, $bracketendndx );
}

sub alpha {
    my $label = shift;
    $label--;
    my ( $single, $double, $triple );
    $single = $label % 26;
    $double = ( int( $label / 26 ) % 26 );
    $triple = ( $label - $single - ( $double * 26 ) % 26 );
    $single = chr( 65 + $single );
    $double = chr( 65 + $double - 1 );
    $triple = chr( 65 + $triple - 1 );
    $double = '' if ( $label < 26 );
    $triple = '' if ( $label < 676 );
    return ( $triple . $double . $single );
}
1;
