package Guiguts::StatusBar;
use strict;
use warnings;

BEGIN {
    use Exporter();
    our ( @ISA, @EXPORT );
    @ISA    = qw(Exporter);
    @EXPORT = qw(&update_indicators &_updatesel &buildstatusbar &togglelongordlabel &seecurrentimage
      &setlang &selection &gotoline &gotopage &gotolabel);
}

# Routine to update the status bar when something has changed.
#
sub update_indicators {
    my $textwindow = $::textwindow;
    my $top        = $::top;
    my ( $last_line, $last_col ) = split( /\./, $textwindow->index('end') );
    my ( $line,      $column )   = split( /\./, $textwindow->index('insert') );
    $::lglobal{current_line_label}
      ->configure( -text => "L:$line/" . ( $last_line - 1 ) . " C:$column" )
      if ( $::lglobal{current_line_label} );
    my $mode             = $textwindow->OverstrikeMode;
    my $overstrke_insert = ' I ';
    if ($mode) {
        $overstrke_insert = ' O ';
    }
    $::lglobal{insert_overstrike_mode_label}->configure( -text => " $overstrke_insert " )
      if ( $::lglobal{insert_overstrike_mode_label} );
    my $filename = $textwindow->FileName;
    $filename = 'No File Loaded' unless ( defined($filename) );
    $::lglobal{highlightlabel}->configure( -background => $::highlightcolor )
      if ($::scannos_highlighted);
    if ( $::lglobal{highlightlabel} ) {
        $::lglobal{highlightlabel}->configure( -background => 'gray' )
          unless ($::scannos_highlighted);
    }
    $filename = ::os_normal($filename);
    $::lglobal{global_filename} = $filename;
    my $edit_flag = '';
    if ( ::isedited() ) {
        $edit_flag = 'edited';
    }

    # window label format: GG-version - [edited] - [file name]
    if ($edit_flag) {
        $top->configure( -title => $::window_title . " - " . $edit_flag . " - " . $filename );
    } else {
        $top->configure( -title => $::window_title . " - " . $filename );
    }
    update_ordinal_button();

    #FIXME: need some logic behind this
    $textwindow->idletasks;
    my ( $mark, $pnum );
    $pnum = ::get_page_number();
    my $markindex = $textwindow->index('insert');
    if ( $filename ne 'No File Loaded' or defined $::lglobal{prepfile} ) {
        $::lglobal{img_num_label}->configure( -text => 'Img:001' )
          if defined $::lglobal{img_num_label};
        $::lglobal{page_label}->configure( -text => ("Lbl: None ") )
          if defined $::lglobal{page_label};
        if (   $::auto_show_images
            && $pnum ) {
            if (   ( not defined $::lglobal{pageimageviewed} )
                or ( $pnum ne "$::lglobal{pageimageviewed}" ) ) {
                $::lglobal{pageimageviewed} = $pnum;
                ::openpng( $textwindow, $pnum );
            }
        }
        update_img_button($pnum);
        update_prev_img_button();
        update_see_img_button();
        update_next_img_button();
        update_auto_img_button();
        update_label_button();
        update_lang_button();
        update_img_lbl_values($pnum);
    }
    $textwindow->tagRemove( 'bkmk', '1.0', 'end' ) unless $::bkmkhl;
    if ( $::lglobal{geometryupdate} ) {
        ::savesettings();
        $::lglobal{geometryupdate} = 0;
    }
}
## Bindings to make label in status bar act like buttons
sub _butbind {
    my $widget = shift;
    $widget->bind(
        '<Enter>',
        sub {
            $widget->configure( -background => $::activecolor );
            $widget->configure( -relief     => 'raised' );
        }
    );
    $widget->bind(
        '<Leave>',
        sub {
            $widget->configure( -background => 'gray' );
            $widget->configure( -relief     => 'ridge' );
        }
    );
    $widget->bind( '<ButtonRelease-1>', sub { $widget->configure( -relief => 'raised' ) } );
}

## Update Last Selection readout in status bar
sub _updatesel {
    my $textwindow = shift;
    my @ranges     = $textwindow->tagRanges('sel');
    my $msg;
    if (@ranges) {
        if ( $::lglobal{showblocksize} && ( @ranges > 2 ) ) {
            my ( $srow, $scol ) = split /\./, $ranges[0];
            my ( $erow, $ecol ) = split /\./, $ranges[-1];
            $msg = ' R:' . abs( $erow - $srow + 1 ) . ' C:' . abs( $ecol - $scol ) . ' ';
        } else {
            $msg = " $ranges[0]--$ranges[-1] ";
            if ( $::lglobal{selectionpop} ) {
                $::lglobal{selsentry}->delete( '0', 'end' );
                $::lglobal{selsentry}->insert( 'end', $ranges[0] );
                $::lglobal{seleentry}->delete( '0', 'end' );
                $::lglobal{seleentry}->insert( 'end', $ranges[-1] );
            }
        }
    } else {
        $msg = ' No Selection ';
    }
    my $msgln = length($msg);

    $::lglobal{selmaxlength} = $msgln if ( $msgln > $::lglobal{selmaxlength} );
    $::lglobal{selectionlabel}->configure( -text => $msg, -width => $::lglobal{selmaxlength} );
    ::update_indicators();
    $textwindow->_lineupdate;
}

## Status Bar
sub buildstatusbar {
    my $textwindow = $::textwindow;
    my $top        = $::top;
    $::lglobal{drag_img} = $top->Photo(
        -format => 'gif',
        -data   => '
R0lGODlhDAAMALMAAISChNTSzPz+/AAAAOAAyukAwRIA4wAAd8oA0MEAe+MTYHcAANAGgnsAAGAA
AAAAACH5BAAAAAAALAAAAAAMAAwAAwQfMMg5BaDYXiw178AlcJ6VhYFXoSoosm7KvrR8zfXHRQA7
'
    );
    $::lglobal{hist_img} = $top->Photo(
        -format => 'gif',
        -data   => 'R0lGODlhBwAEAIAAAAAAAP///yH5BAEAAAEALAAAAAAHAAQAAAIIhA+BGWoNWSgAOw=='
    );
    ::drag($textwindow);
    $::lglobal{current_line_label} = $::counter_frame->Label(
        -text       => 'L:1/1 C:0',
        -width      => 18,
        -relief     => 'ridge',
        -background => 'gray',
    )->grid( -row => 1, -column => 0, -sticky => 'nw' );
    $::lglobal{current_line_label}->bind(
        '<1>',
        sub {
            $::lglobal{current_line_label}->configure( -relief => 'sunken' );
            gotoline();
            ::update_indicators();
        }
    );
    $::lglobal{current_line_label}->bind(
        '<3>',
        sub {
            if   ($::vislnnm) { $::vislnnm = 0 }
            else              { $::vislnnm = 1 }
            $textwindow->showlinenum if $::vislnnm;
            $textwindow->hidelinenum unless $::vislnnm;
            ::savesettings();
        }
    );
    $::lglobal{selectionlabel} = $::counter_frame->Label(
        -text       => ' No Selection ',
        -relief     => 'ridge',
        -background => 'gray',
    )->grid( -row => 1, -column => 9, -sticky => 'nw' );
    $::lglobal{selectionlabel}->bind(
        '<1>',
        sub {
            if ( $::lglobal{showblocksize} ) {
                $::lglobal{showblocksize} = 0;
            } else {
                $::lglobal{showblocksize} = 1;
            }
        }
    );
    $::lglobal{selectionlabel}->bind( '<Double-1>', sub { ::selection() } );
    $::lglobal{selectionlabel}->bind(
        '<3>',
        sub {
            if ( $textwindow->markExists('selstart') ) {
                $textwindow->tagAdd( 'sel', 'selstart', 'selend' );
            }
        }
    );
    $::lglobal{selectionlabel}->bind(
        '<Shift-3>',
        sub {
            $textwindow->tagRemove( 'sel', '1.0', 'end' );
            if ( $textwindow->markExists('selstart') ) {
                my ( $srow, $scol ) = split /\./, $textwindow->index('selstart');
                my ( $erow, $ecol ) = split /\./, $textwindow->index('selend');
                for ( $srow .. $erow ) {
                    $textwindow->tagAdd( 'sel', "$_.$scol", "$_.$ecol" );
                }
            }
        }
    );
    $::lglobal{highlightlabel} = $::counter_frame->Label(
        -text       => 'H',
        -width      => 2,
        -relief     => 'ridge',
        -background => 'gray',
    )->grid( -row => 1, -column => 1 );
    $::lglobal{highlightlabel}->bind(
        '<1>',
        sub {
            if ($::scannos_highlighted) {
                $::scannos_highlighted = 0;
                $::lglobal{highlighttempcolor} = 'gray';
            } else {
                ::scannosfile() unless $::scannoslist;
                return          unless $::scannoslist;
                $::scannos_highlighted = 1;
                $::lglobal{highlighttempcolor} = $::highlightcolor;
            }
            ::highlight_scannos();
        }
    );
    $::lglobal{highlightlabel}->bind( '<3>', sub { ::scannosfile() } );
    $::lglobal{highlightlabel}->bind(
        '<Enter>',
        sub {
            $::lglobal{highlighttempcolor} =
              $::lglobal{highlightlabel}->cget( -background );
            $::lglobal{highlightlabel}->configure( -background => $::activecolor );
            $::lglobal{highlightlabel}->configure( -relief     => 'raised' );
        }
    );
    $::lglobal{highlightlabel}->bind(
        '<Leave>',
        sub {
            $::lglobal{highlightlabel}->configure( -background => $::lglobal{highlighttempcolor} );
            $::lglobal{highlightlabel}->configure( -relief     => 'ridge' );
        }
    );
    $::lglobal{highlightlabel}->bind(
        '<ButtonRelease-1>',
        sub {
            $::lglobal{highlightlabel}->configure( -relief => 'raised' );
        }
    );
    $::lglobal{insert_overstrike_mode_label} = $::counter_frame->Label(
        -text       => '',
        -relief     => 'ridge',
        -background => 'gray',
        -width      => 2,
    )->grid( -row => 1, -column => 8, -sticky => 'nw' );
    $::lglobal{insert_overstrike_mode_label}->bind(
        '<1>',
        sub {
            $::lglobal{insert_overstrike_mode_label}->configure( -relief => 'sunken' );
            if ( $textwindow->OverstrikeMode ) {
                $textwindow->OverstrikeMode(0);
            } else {
                $textwindow->OverstrikeMode(1);
            }
        }
    );
    $::lglobal{ordinallabel} = $::counter_frame->Label(
        -text       => '',
        -relief     => 'ridge',
        -background => 'gray',
        -anchor     => 'w',
    )->grid( -row => 1, -column => 10 );
    $::lglobal{ordinallabel}->bind(
        '<1>',
        sub {
            $::lglobal{ordinallabel}->configure( -relief => 'sunken' );
            ::togglelongordlabel();
        }
    );
    _butbind($_)
      for (
        $::lglobal{insert_overstrike_mode_label}, $::lglobal{current_line_label},
        $::lglobal{selectionlabel},               $::lglobal{ordinallabel}
      );
    $::lglobal{statushelp} = $top->Balloon( -initwait => 1000 );
    $::lglobal{statushelp}->attach( $::lglobal{current_line_label},
        -balloonmsg => "Line number out of total lines\nand column number of cursor." );
    $::lglobal{statushelp}->attach(
        $::lglobal{insert_overstrike_mode_label},
        -balloonmsg => 'Typeover Mode. (Insert/Overstrike)'
    );
    $::lglobal{statushelp}->attach( $::lglobal{ordinallabel},
        -balloonmsg =>
          "Decimal & Hexadecimal ordinal of the\ncharacter to the right of the cursor." );
    $::lglobal{statushelp}->attach( $::lglobal{highlightlabel},
        -balloonmsg => "Highlight words from list. Right click to select list" );
    $::lglobal{statushelp}->attach( $::lglobal{selectionlabel},
        -balloonmsg =>
          "Start and end points of selection -- Or, total lines.columns of selection" );
}

sub update_img_button {
    my $pnum       = shift;
    my $textwindow = $::textwindow;
    unless ( defined( $::lglobal{img_num_label} ) ) {
        $::lglobal{img_num_label} = $::counter_frame->Label(
            -text       => "Img:$pnum",
            -width      => 7,
            -background => 'gray',
            -relief     => 'ridge',
        )->grid( -row => 1, -column => 2, -sticky => 'nw' );
        $::lglobal{img_num_label}->bind(
            '<1>',
            sub {
                $::lglobal{img_num_label}->configure( -relief => 'sunken' );
                gotopage();
                ::update_indicators();
            }
        );
        $::lglobal{img_num_label}->bind(
            '<3>',
            sub {
                $::lglobal{img_num_label}->configure( -relief => 'sunken' );
                ::togglepagenums();
                ::update_indicators();
            }
        );
        _butbind( $::lglobal{img_num_label} );
        $::lglobal{statushelp}
          ->attach( $::lglobal{img_num_label}, -balloonmsg => "Image/Page name for current page." );
    }
    return ();
}

sub update_label_button {
    my $textwindow = $::textwindow;
    unless ( $::lglobal{page_label} ) {
        $::lglobal{page_label} = $::counter_frame->Label(
            -text       => 'Lbl: None ',
            -background => 'gray',
            -relief     => 'ridge',
        )->grid( -row => 1, -column => 7 );
        _butbind( $::lglobal{page_label} );
        $::lglobal{page_label}->bind(
            '<1>',
            sub {
                $::lglobal{page_label}->configure( -relief => 'sunken' );
                ::gotolabel();
            }
        );
        $::lglobal{page_label}->bind(
            '<3>',
            sub {
                $::lglobal{page_label}->configure( -relief => 'sunken' );
                ::pageadjust();
            }
        );
        $::lglobal{statushelp}
          ->attach( $::lglobal{page_label}, -balloonmsg => "Page label assigned to current page." );
    }
    return ();
}

# New subroutine "update_ordinal_button" extracted - Mon Mar 21 22:53:33 2011.
#
sub update_ordinal_button {
    my $textwindow = $::textwindow;
    my $ordinal    = ord( $textwindow->get('insert') );
    my $hexi       = uc sprintf( "%04x", $ordinal );
    if ( $::lglobal{longordlabel} ) {
        my $msg   = charnames::viacode($ordinal) || '';
        my $msgln = length(" Dec $ordinal : Hex $hexi : $msg ");
        $::lglobal{ordmaxlength} = $msgln
          if ( $msgln > $::lglobal{ordmaxlength} );
        $::lglobal{ordinallabel}->configure(
            -text    => " Dec $ordinal : Hex $hexi : $msg ",
            -width   => $::lglobal{ordmaxlength},
            -justify => 'left'
        );
    } else {
        $::lglobal{ordinallabel}->configure(
            -text  => " Dec $ordinal : Hex $hexi ",
            -width => 18
        ) if ( $::lglobal{ordinallabel} );
    }
}

sub togglelongordlabel {
    $::lglobal{longordlabel} = 1 - $::lglobal{longordlabel};
    ::update_indicators();
}

sub update_prev_img_button {
    my $textwindow = $::textwindow;
    unless ( defined( $::lglobal{previmagebutton} ) ) {
        $::lglobal{previmagebutton} = $::counter_frame->Label(
            -text       => '<',
            -width      => 2,
            -relief     => 'ridge',
            -background => 'gray',
        )->grid( -row => 1, -column => 3 );
        $::lglobal{previmagebutton}->bind(
            '<1>',
            sub {
                $::lglobal{previmagebutton}->configure( -relief => 'sunken' );
                $::lglobal{showthispageimage} = 1;
                ::displaypagenums();
                $textwindow->focus;
                ::pgprevious();
            }
        );
        _butbind( $::lglobal{previmagebutton} );
        $::lglobal{statushelp}->attach( $::lglobal{previmagebutton},
            -balloonmsg =>
              "Move to previous page in text and open image corresponding to previous current page in an external viewer."
        );
    }
}

# New subroutine "update_see_img_button" extracted - Mon Mar 21 23:23:36 2011.
#
sub update_see_img_button {
    my $textwindow = $::textwindow;
    unless ( defined( $::lglobal{pagebutton} ) ) {
        $::lglobal{pagebutton} = $::counter_frame->Label(
            -text       => 'See Img',
            -width      => 7,
            -relief     => 'ridge',
            -background => 'gray',
        )->grid( -row => 1, -column => 4 );
        $::lglobal{pagebutton}->bind( '<1>', \&seecurrentimage );
        $::lglobal{pagebutton}->bind( '<3>', sub { ::setpngspath() } );
        _butbind( $::lglobal{pagebutton} );
        $::lglobal{statushelp}->attach( $::lglobal{pagebutton},
            -balloonmsg => "Open Image corresponding to current page in an external viewer." );
    }
}

sub seecurrentimage {
    my $textwindow = $::textwindow;
    $::lglobal{pagebutton}->configure( -relief => 'sunken' );
    my $pagenum = ::get_page_number();
    if ( defined $::lglobal{pagemarkerpop} ) {
        $::lglobal{pagenumentry}->delete( '0', 'end' );
        $::lglobal{pagenumentry}->insert( 'end', "Pg" . $pagenum );
    }
    ::openpng( $textwindow, $pagenum );
}

sub update_next_img_button {
    my $textwindow = $::textwindow;
    unless ( defined( $::lglobal{nextimagebutton} ) ) {
        $::lglobal{nextimagebutton} = $::counter_frame->Label(
            -text       => '>',
            -width      => 2,
            -relief     => 'ridge',
            -background => 'gray',
        )->grid( -row => 1, -column => 5 );
        $::lglobal{nextimagebutton}->bind(
            '<1>',
            sub {
                $::lglobal{nextimagebutton}->configure( -relief => 'sunken' );
                $::lglobal{showthispageimage} = 1;
                ::displaypagenums();
                $textwindow->focus;
                ::pgnext();
            }
        );
        _butbind( $::lglobal{nextimagebutton} );
        $::lglobal{statushelp}->attach( $::lglobal{nextimagebutton},
            -balloonmsg =>
              "Move to next page in text and open image corresponding to next current page in an external viewer."
        );
    }
}

sub update_auto_img_button {
    my $textwindow = $::textwindow;
    unless ( defined( $::lglobal{autoimagebutton} ) ) {
        $::lglobal{autoimagebutton} = $::counter_frame->Label(
            -text       => 'Auto Img',
            -width      => 9,
            -relief     => 'ridge',
            -background => 'gray',
        )->grid( -row => 1, -column => 6 );
        if ($::auto_show_images) {
            $::lglobal{autoimagebutton}->configure( -background => $::highlightcolor );
        }
        $::lglobal{autoimagebutton}->bind(
            '<1>',
            sub {
                $::auto_show_images = 1 - $::auto_show_images;
                if ($::auto_show_images) {
                    $::lglobal{autoimagebutton}->configure( -relief     => 'sunken' );
                    $::lglobal{autoimagebutton}->configure( -background => $::highlightcolor );
                    $::lglobal{statushelp}->attach( $::lglobal{autoimagebutton},
                        -balloonmsg =>
                          "Stop automatically showing the image for the current page." );
                } else {
                    $::lglobal{autoimagebutton}->configure( -relief     => 'sunken' );
                    $::lglobal{autoimagebutton}->configure( -background => 'gray' );
                    $::lglobal{statushelp}->attach( $::lglobal{autoimagebutton},
                        -balloonmsg =>
                          "Automatically show the image for the current page (focus shifts to image window)."
                    );
                }
            }
        );
        _butbind( $::lglobal{autoimagebutton} );
        $::lglobal{statushelp}->attach( $::lglobal{autoimagebutton},
            -balloonmsg =>
              "Automatically show the image for the current page (focus shifts to image window)." );
        $::lglobal{autoimagebutton}->bind(
            '<Leave>',
            sub {
                $::lglobal{autoimagebutton}
                  ->configure( -background => $::auto_show_images ? $::highlightcolor : 'gray' );
                $::lglobal{autoimagebutton}->configure( -relief => 'ridge' );
            }
        );
    }
}

# New subroutine "update_img_lbl_values" extracted - Tue Mar 22 00:08:26 2011.
#
sub update_img_lbl_values {
    my $pnum       = shift;
    my $textwindow = $::textwindow;
    if ( defined $::lglobal{img_num_label} ) {
        $::lglobal{img_num_label}->configure( -text  => "Img:$pnum" );
        $::lglobal{img_num_label}->configure( -width => ( length($pnum) + 5 ) );
    }
    my $label = $::pagenumbers{"Pg$pnum"}{label};
    if ( defined $label && length $label ) {
        $::lglobal{page_label}->configure( -text => ("Lbl: $label ") );
    } else {
        $::lglobal{page_label}->configure( -text => ("Lbl: None ") );
    }
}

sub update_lang_button {
    my $textwindow = $::textwindow;
    unless ( $::lglobal{langbutton} ) {
        $::lglobal{langbutton} = $::counter_frame->Label(
            -width      => 11,
            -relief     => 'ridge',
            -background => 'gray',
        )->grid( -row => 1, -column => 11 );
        _butbind( $::lglobal{langbutton} );
        $::lglobal{langbutton}->bind(
            '<1>',
            sub {
                $::lglobal{langbutton}->configure( -relief => 'sunken' );
                setlang();
            }
        );
        $::lglobal{statushelp}
          ->attach( $::lglobal{langbutton}, -balloonmsg => "Set language of current project." );
    }
    $::lglobal{langbutton}->configure( -text => "Lang:$::booklang" );
}

sub setlang {
    my $textwindow = $::textwindow;
    my $top        = $::top;
    unless ( defined( $::lglobal{setlangpop} ) ) {
        $::lglobal{setlangpop} = $top->DialogBox(
            -buttons => [qw[OK Cancel]],
            -title   => 'Set language',
            -popover => $top,
            -command => sub {
                if ( defined $_[0] and $_[0] eq 'OK' ) {
                    ::setedited(1);
                    $::booklang = $::lglobal{booklang};
                    update_lang_button();
                    ::readlabels();
                }
                $::lglobal{setlangpop}->destroy;
                undef $::lglobal{setlangpop};
            }
        );
        $::lglobal{setlangpop}->resizable( 'no', 'no' );
        my $frame = $::lglobal{setlangpop}->Frame->pack( -fill => 'x' );
        $frame->Label( -text => 'Language: ' )->pack( -side => 'left' );
        $::lglobal{booklang} = $::booklang;
        my $entry = $frame->Entry(
            -background   => $::bkgcolor,
            -width        => 20,
            -textvariable => \$::lglobal{booklang},
        )->pack( -side => 'left', -fill => 'x' );
        $::lglobal{setlangpop}->Advertise( entry => $entry );
        $::lglobal{setlangpop}->Popup;
        $::lglobal{setlangpop}->Subwidget('entry')->focus;
        $::lglobal{setlangpop}->Subwidget('entry')->selectionRange( 0, 'end' );
        $::lglobal{setlangpop}->Subwidget('entry')->icursor('end');
        $::lglobal{setlangpop}->Wait;
    }
}

# Pop up window allowing tracking and auto reselection of last selection
sub selection {
    my $top        = $::top;
    my $textwindow = $::textwindow;
    my ( $start, $end );
    if ( $::lglobal{selectionpop} ) {
        $::lglobal{selectionpop}->deiconify;
        $::lglobal{selectionpop}->raise;
    } else {
        $::lglobal{selectionpop} = $top->Toplevel;
        $::lglobal{selectionpop}->title('Select Line.Col');
        my $frame = $::lglobal{selectionpop}->Frame->pack( -fill => 'x', -padx => 5, -pady => 5 );
        $frame->Label( -text => 'Start Line.Col' )->grid( -row => 1, -column => 1 );
        $::lglobal{selsentry} = $frame->Entry(
            -background   => $::bkgcolor,
            -width        => 15,
            -textvariable => \$start,
            -validate     => 'focusout',
            -vcmd         => sub {
                return 0 unless ( $_[0] =~ m{^\d+\.\d+$} );
                return 1;
            },
        )->grid( -row => 1, -column => 2 );
        $frame->Label( -text => 'End Line.Col' )->grid( -row => 2, -column => 1 );
        $::lglobal{seleentry} = $frame->Entry(
            -background   => $::bkgcolor,
            -width        => 15,
            -textvariable => \$end,
            -validate     => 'focusout',
            -vcmd         => sub {
                return 0 unless ( $_[0] =~ m{^\d+\.\d+$} );
                return 1;
            },
        )->grid( -row => 2, -column => 2 );
        my $frame1 = $::lglobal{selectionpop}->Frame->pack( -fill => 'x', -padx => 5, -pady => 5 );
        my $button = $frame1->Button(
            -text    => 'OK',
            -width   => 8,
            -command => sub {
                return
                  unless ( ( $start =~ m{^\d+\.\d+$} )
                    && ( $end =~ m{^\d+\.\d+$} ) );
                $textwindow->tagRemove( 'sel', '1.0', 'end' );
                $textwindow->tagAdd( 'sel', $start, $end );
                $textwindow->markSet( 'selstart', $start );
                $textwindow->markSet( 'selend',   $end );
                $textwindow->focus;
            },
        )->grid( -row => 1, -column => 1 );
        $frame1->Button(
            -text    => 'Close',
            -width   => 8,
            -command => sub {
                $::lglobal{selectionpop}->destroy;
                undef $::lglobal{selectionpop};
                undef $::lglobal{selsentry};
                undef $::lglobal{seleentry};
            },
        )->grid( -row => 1, -column => 2 );
        $::lglobal{selectionpop}->resizable( 'no', 'no' );
        ::initialize_popup_without_deletebinding('selectionpop');
        $::lglobal{selectionpop}->protocol(
            'WM_DELETE_WINDOW' => sub {
                $::lglobal{selectionpop}->destroy;
                undef $::lglobal{selectionpop};
                undef $::lglobal{selsentry};
                undef $::lglobal{seleentry};
            }
        );
    }
    my @ranges = $textwindow->tagRanges('sel');
    if (@ranges) {
        $::lglobal{selsentry}->delete( '0', 'end' );
        $::lglobal{selsentry}->insert( 'end', $ranges[0] );
        $::lglobal{seleentry}->delete( '0', 'end' );
        $::lglobal{seleentry}->insert( 'end', $ranges[-1] );
    } elsif ( $textwindow->markExists('selstart') ) {
        $::lglobal{selsentry}->delete( '0', 'end' );
        $::lglobal{selsentry}->insert( 'end', $textwindow->index('selstart') );
        $::lglobal{seleentry}->delete( '0', 'end' );
        $::lglobal{seleentry}->insert( 'end', $textwindow->index('selend') );
    }
    $::lglobal{selsentry}->selectionRange( 0, 'end' );
    return;
}

# Pop up a window which will allow jumping directly to a specified line
sub gotoline {
    my $textwindow = $::textwindow;
    my $top        = $::top;
    unless ( defined( $::lglobal{gotolinepop} ) ) {
        $::lglobal{gotolinepop} = $top->DialogBox(
            -buttons => [qw[OK Cancel]],
            -title   => 'Go To Line Number',
            -popover => $top,
            -command => sub {
                if ( defined $_[0] and $_[0] eq 'OK' ) {
                    $::lglobal{line_number} =~ s/[\D.]//g;
                    my ( $last_line, $junk ) =
                      split( /\./, $textwindow->index('end') );
                    ( $::lglobal{line_number}, $junk ) =
                      split( /\./, $textwindow->index('insert') )
                      unless $::lglobal{line_number};
                    $::lglobal{line_number} =~ s/^\s+|\s+$//g;
                    if ( $::lglobal{line_number} > $last_line ) {
                        $::lglobal{line_number} = $last_line;
                    }
                    $textwindow->markSet( 'insert', "$::lglobal{line_number}.0" );
                    $textwindow->see('insert');
                    update_indicators();
                    $::lglobal{gotolinepop}->destroy;
                    undef $::lglobal{gotolinepop};
                } else {
                    $::lglobal{gotolinepop}->destroy;
                    undef $::lglobal{gotolinepop};
                }
            }
        );
        gotocommonsetup( 'gotolinepop', 'line_number', 'Enter line number: ', '' );
    }
}

# Pop up a window which will allow jumping directly to a specified page
sub gotopage {
    my $textwindow = $::textwindow;
    my $top        = $::top;
    unless ( defined( $::lglobal{gotopagpop} ) ) {
        return unless %::pagenumbers;
        for ( keys(%::pagenumbers) ) {
            $::lglobal{pagedigits} = ( length($_) - 2 );
            last;
        }
        $::lglobal{gotopagpop} = $top->DialogBox(
            -buttons => [qw[OK Cancel]],
            -title   => 'Goto Page Number',
            -popover => $top,
            -command => sub {
                if ( ( defined $_[0] ) and ( $_[0] eq 'OK' ) ) {
                    unless ( $::lglobal{lastpage} ) {
                        $::lglobal{gotopagpop}->bell;
                        $::lglobal{gotopagpop}->destroy;
                        undef $::lglobal{gotopagpop};
                        return;
                    }
                    if ( $::lglobal{pagedigits} == 3 ) {
                        $::lglobal{lastpage} =
                          sprintf( "%03s", $::lglobal{lastpage} );
                    } elsif ( $::lglobal{pagedigits} == 4 ) {
                        $::lglobal{lastpage} =
                          sprintf( "%04s", $::lglobal{lastpage} );
                    }
                    unless ( exists $::pagenumbers{ 'Pg' . $::lglobal{lastpage} }
                        && defined $::pagenumbers{ 'Pg' . $::lglobal{lastpage} } ) {
                        delete $::pagenumbers{ 'Pg' . $::lglobal{lastpage} };
                        $::lglobal{gotopagpop}->bell;
                        $::lglobal{gotopagpop}->destroy;
                        undef $::lglobal{gotopagpop};
                        return;
                    }
                    my $index = $textwindow->index( 'Pg' . $::lglobal{lastpage} );
                    $textwindow->markSet( 'insert', "$index +1l linestart" );
                    ::seeindex( 'insert -2l', 1 );
                    $textwindow->focus;
                    update_indicators();
                    $::lglobal{gotopagpop}->destroy;
                    undef $::lglobal{gotopagpop};
                } else {
                    $::lglobal{gotopagpop}->destroy;
                    undef $::lglobal{gotopagpop};
                }
            }
        );
        gotocommonsetup( 'gotopagpop', 'lastpage', 'Enter image number: ', '' );
    }
}

## Pop up a window which will allow jumping directly to a specified page label
sub gotolabel {
    my $textwindow = $::textwindow;
    my $top        = $::top;
    unless ( defined( $::lglobal{gotolabpop} ) ) {
        return unless %::pagenumbers;
        for ( keys(%::pagenumbers) ) {
            $::lglobal{pagedigits} = ( length($_) - 2 );
            last;
        }
        $::lglobal{gotolabpop} = $top->DialogBox(
            -buttons => [qw[Ok Cancel]],
            -title   => 'Goto Page Label',
            -popover => $top,
            -command => sub {
                if ( $_[0] && $_[0] eq 'Ok' ) {
                    my $mark;
                    for ( keys %::pagenumbers ) {
                        if (   $::pagenumbers{$_}{label}
                            && $::pagenumbers{$_}{label} eq $::lglobal{lastlabel} ) {
                            $mark = $_;
                            last;
                        }
                    }
                    unless ($mark) {
                        $::lglobal{gotolabpop}->bell;
                        $::lglobal{gotolabpop}->destroy;
                        undef $::lglobal{gotolabpop};
                        return;
                    }
                    my $index = $textwindow->index($mark);
                    $textwindow->markSet( 'insert', "$index +1l linestart" );
                    ::seeindex( 'insert -2l', 1 );
                    $textwindow->focus;
                    ::update_indicators();
                    $::lglobal{gotolabpop}->destroy;
                    undef $::lglobal{gotolabpop};
                } else {
                    $::lglobal{gotolabpop}->destroy;
                    undef $::lglobal{gotolabpop};
                }
            }
        );
        gotocommonsetup( 'gotolabpop', 'lastlabel', 'Enter label: ', 'Pg ' );
    }
}

# Perform operations common to the "goto" dialogs,
# including setting Escape key and window manager close button to invoke cancel
sub gotocommonsetup {
    my $dlg     = shift;             # dialog key in lglobal
    my $var     = shift;             # variable key in lglobal
    my $prompt  = shift;             # prompt for label in dialog
    my $default = shift;             # default value for label (e.g. "Pg " in gotopage)
    my $len     = length $default;
    $::lglobal{$dlg}->Icon( -image => $::icon );
    $::lglobal{$dlg}->resizable( 'no', 'no' );
    $::lglobal{$dlg}
      ->Tk::bind( '<Key-KP_Enter>' => sub { $::lglobal{$dlg}->Subwidget('B_OK')->invoke; } );
    $::lglobal{$dlg}
      ->Tk::bind( '<Escape>' => sub { $::lglobal{$dlg}->Subwidget('B_Cancel')->invoke; } );
    $::lglobal{$dlg}
      ->protocol( 'WM_DELETE_WINDOW' => sub { $::lglobal{$dlg}->Subwidget('B_Cancel')->invoke; } );
    my $frame = $::lglobal{$dlg}->Frame->pack( -fill => 'x' );
    $frame->Label( -text => $prompt )->pack( -side => 'left' );
    $::lglobal{$var} = $default unless $::lglobal{$var};
    my $entry = $frame->Entry(
        -background   => $::bkgcolor,
        -width        => 25,
        -textvariable => \$::lglobal{$var}
    )->pack( -side => 'left', -fill => 'x' );
    $::lglobal{$dlg}->Advertise( entry => $entry );
    $::lglobal{$dlg}->Popup;
    $::lglobal{$dlg}->Subwidget('entry')->focus;
    $::lglobal{$dlg}->Subwidget('entry')->selectionRange( $len, 'end' );
    $::lglobal{$dlg}->Subwidget('entry')->icursor($len);    # place cursor at end of default text
    $::lglobal{$dlg}->Wait;
}

1;
