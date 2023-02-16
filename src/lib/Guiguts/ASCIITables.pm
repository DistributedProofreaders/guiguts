package Guiguts::ASCIITables;
use strict;
use warnings;

BEGIN {
    use Exporter();
    our ( @ISA, @EXPORT );
    @ISA    = qw(Exporter);
    @EXPORT = qw(&tablefx);
}

my $TEMPPAGEMARK = "\x7f";

#
# Pop the ASCII Table Special Effects dialog
sub tablefx {
    ::hidepagenums();
    my $textwindow = $::textwindow;
    my $top        = $::top;
    if ( defined( $::lglobal{tblfxpop} ) ) {
        $::lglobal{tblfxpop}->deiconify;
        $::lglobal{tblfxpop}->raise;
        $::lglobal{tblfxpop}->focus;
    } else {
        $::lglobal{columnspaces} = '';
        $::lglobal{tblfxpop}     = $top->Toplevel;
        $::lglobal{tblfxpop}->title('ASCII Table Special Effects');
        my $f0         = $::lglobal{tblfxpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        my @tb_buttons = (
            [ 'Table Select', sub { tblselect() } ],
            [
                'Table Deselect',
                sub {
                    $textwindow->tagRemove( 'table',   '1.0', 'end' );
                    $textwindow->tagRemove( 'linesel', '1.0', 'end' );
                    $textwindow->markUnset( 'tblstart', 'tblend' );
                    undef $::lglobal{selectedline};
                }
            ],
            [ 'Insert Vertical Line', sub { insertline('i'); } ],
            [ 'Add Vertical Line',    sub { insertline('a'); } ],
            [ 'Space Out Table',      sub { tblspace(); } ],
            [ 'Compress Table',       sub { tblcompress(); } ],
            [
                'Delete Sel. Line',
                sub {
                    my @ranges      = $textwindow->tagRanges('linesel');
                    my $range_total = @ranges;
                    $textwindow->addGlobStart;
                    if ( $range_total == 0 ) {
                        $textwindow->addGlobEnd;
                        return;
                    } else {
                        while (@ranges) {
                            my $end   = pop(@ranges);
                            my $start = pop(@ranges);
                            $textwindow->delete( $start, $end )
                              if ( $textwindow->get($start) eq '|' );
                        }
                    }
                    $textwindow->tagAdd( 'table', 'tblstart', 'tblend' );
                    $textwindow->tagRemove( 'linesel', '1.0', 'end' );
                    $textwindow->addGlobEnd;
                }
            ],
            [ 'Remove Sel. Line', sub { tlineremove(); } ],
            [ 'Select Prev Line', sub { tlineselect('p'); } ],
            [ 'Select Next Line', sub { tlineselect('n'); } ],
            [
                'Line Deselect',
                sub {
                    $textwindow->tagRemove( 'linesel', '1.0', 'end' );
                    undef $::lglobal{selectedline};
                }
            ],
            [ 'Auto Columns', sub { tblautoc(); } ],
        );
        my ( $inc, $row, $col ) = ( 0, 0, 0 );
        for (@tb_buttons) {
            $row = int( $inc / 4 );
            $col = $inc % 4;
            $f0->Button(
                -command => $tb_buttons[$inc][1],
                -text    => $tb_buttons[$inc][0],
                -width   => 16
            )->grid(
                -row    => $row,
                -column => $col,
                -padx   => 1,
                -pady   => 2
            );
            ++$inc;
        }
        my $f1 = $::lglobal{tblfxpop}->LabFrame( -label => 'Adjust Column' )
          ->pack( -side => 'top', -anchor => 'n', -expand => 'yes', -fill => 'x' );
        my $f1a  = $f1->Frame->pack( -side => 'top', -anchor => 'n' );
        my $f1aj = $f1a->Frame->pack( -side => 'left', -anchor => 'w', -padx => 20 );
        $f1aj->Label( -text => 'Justify', )->pack( -side => 'left', -anchor => 'w' );
        my $rb1 = $f1aj->Radiobutton(
            -text        => 'L',
            -variable    => \$::lglobal{tblcoljustify},
            -selectcolor => $::lglobal{checkcolor},
            -value       => 'l',
        )->pack( -side => 'left', -anchor => 'w' );
        my $rb2 = $f1aj->Radiobutton(
            -text        => 'C',
            -variable    => \$::lglobal{tblcoljustify},
            -selectcolor => $::lglobal{checkcolor},
            -value       => 'c',
        )->pack( -side => 'left', -anchor => 'w' );
        my $rb3 = $f1aj->Radiobutton(
            -text        => 'R',
            -variable    => \$::lglobal{tblcoljustify},
            -selectcolor => $::lglobal{checkcolor},
            -value       => 'r',
        )->pack( -side => 'left', -anchor => 'w' );
        my $f1ah = $f1a->Frame->pack( -side => 'left', -anchor => 'w', -padx => 20 );
        $f1ah->Label( -text => 'Indent', )->pack( -side => 'left', -anchor => 'w' );
        $::lglobal{tblindent} = 0 unless $::lglobal{tblindent};
        my $ientry = $f1ah->Entry(
            -width        => 4,
            -background   => $::bkgcolor,
            -textvariable => \$::lglobal{tblindent},
            -validate     => 'all',
            -vcmd         => sub { return $_[0] =~ /^\d*$/; }
        )->pack( -side => 'left', -anchor => 'w', -pady => 2 );
        my $hitog = $f1ah->Checkbutton(
            -variable    => \$::lglobal{tblhanging},
            -selectcolor => $::lglobal{checkcolor},
            -text        => 'Hanging',
        )->pack( -side => 'left', -anchor => 'w', -pady => 5 );
        my $f1b = $f1->Frame->pack( -side => 'top', -anchor => 'n' );
        $f1b->Checkbutton(
            -variable    => \$::lglobal{tblrwcol},
            -selectcolor => $::lglobal{checkcolor},
            -text        => 'Rewrap Cols',
            -command     => sub {
                if ( $::lglobal{tblrwcol} ) {
                    $rb1->configure( -state => 'active' );
                    $rb2->configure( -state => 'active' );
                    $rb3->configure( -state => 'active' );
                    $ientry->configure( -state => 'normal' );
                    $hitog->configure( -state => 'active' );
                } else {
                    $rb1->configure( -state => 'disabled' );
                    $rb2->configure( -state => 'disabled' );
                    $rb3->configure( -state => 'disabled' );
                    $ientry->configure( -state => 'disabled' );
                    $hitog->configure( -state => 'disabled' );
                }
            },
        )->pack( -side => 'left', -anchor => 'n', -padx => 1 );
        $f1b->Button(
            -command => sub { coladjust(-1) },
            -text    => 'Move Left',
            -width   => 10
        )->pack( -side => 'left', -anchor => 'n', -padx => 1 );
        $f1b->Button(
            -command => sub { coladjust(1) },
            -text    => 'Move Right',
            -width   => 10
        )->pack( -side => 'left', -anchor => 'n', -padx => 1 );
        $::lglobal{colwidthlbl} = $f1b->Label(
            -text  => "Width $::lglobal{columnspaces}",
            -width => 12,
        )->pack( -side => 'left', -anchor => 'n', -padx => 5 );
        my $f2f = $::lglobal{tblfxpop}->LabFrame( -label => 'Leading/Trailing Spaces' )
          ->pack( -side => 'top', -anchor => 'n', -expand => 'yes', -fill => 'x' );
        $f2f->Label( -text => 'Character', )
          ->grid( -row => 1, -column => 0, -padx => 1, -pady => 2 );
        $::lglobal{tablefillchar} = '@'
          unless defined $::lglobal{tablefillchar} and length( $::lglobal{tablefillchar} ) == 1;
        $f2f->Entry(
            -width        => 2,
            -background   => $::bkgcolor,
            -textvariable => \$::lglobal{tablefillchar},
            -validate     => 'all',
            -vcmd         => sub { return length( $_[0] ) <= 1; }
        )->grid( -row => 1, -column => 1, -padx => 1, -pady => 2 );
        $f2f->Button(
            -command => sub { leadtrailspaces('fill'); },
            -text    => 'Fill',
            -width   => 10
        )->grid( -row => 1, -column => 3, -padx => 5, -pady => 2 );
        $f2f->Button(
            -command => sub { leadtrailspaces('restore'); },
            -text    => 'Restore',
            -width   => 10
        )->grid( -row => 1, -column => 4, -padx => 5, -pady => 2 );
        my $f3 = $::lglobal{tblfxpop}->LabFrame( -label => 'Grid <=> Step' )
          ->pack( -side => 'top', -anchor => 'n', -expand => 'yes', -fill => 'x' );
        $f3->Label( -text => 'Table Right Column', )
          ->grid( -row => 1, -column => 0, -padx => 1, -pady => 2 );
        $f3->Entry(
            -width        => 4,
            -background   => $::bkgcolor,
            -textvariable => \$::lglobal{stepmaxwidth},
            -validate     => 'all',
            -vcmd         => sub { return $_[0] =~ /^\d*$/; }
        )->grid( -row => 1, -column => 1, -padx => 1, -pady => 2 );
        $f3->Button(
            -command => sub { grid2step() },
            -text    => 'Convert Grid to Step',
            -width   => 16
        )->grid( -row => 1, -column => 3, -padx => 5, -pady => 2 );
        $f3->Button(
            -command => sub { step2grid() },
            -text    => 'Convert Step to Grid',
            -width   => 16
        )->grid( -row => 1, -column => 4, -padx => 5, -pady => 2 );
        my $f3a = $::lglobal{tblfxpop}->LabFrame( -label => 'Restructure' )
          ->pack( -side => 'top', -anchor => 'n', -expand => 'yes', -fill => 'x' );
        $f3a->Button(
            -command => sub { rejoinrows() },
            -text    => 'Rejoin Rows',
            -width   => 16
        )->grid( -row => 1, -column => 0, -padx => 5, -pady => 2 );
        my $f4   = $::lglobal{tblfxpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        my $ubtn = $f4->Button(
            -command => sub { undoredo('undo'); },
            -text    => 'Undo',
            -width   => 10
        )->grid( -row => 1, -column => 1, -padx => 1, -pady => 2 );
        my $rbtn = $f4->Button(
            -command => sub { undoredo('redo'); },
            -text    => 'Redo',
            -width   => 10
        )->grid( -row => 1, -column => 2, -padx => 1, -pady => 2 );
        ::initialize_popup_without_deletebinding('tblfxpop');

        $::lglobal{tblfxpop}->bind( '<l>',         sub { coladjust(-1) } );
        $::lglobal{tblfxpop}->bind( '<r>',         sub { coladjust(1) } );
        $::lglobal{tblfxpop}->bind( '<p>',         sub { tlineselect('p') } );
        $::lglobal{tblfxpop}->bind( '<n>',         sub { tlineselect('n') } );
        $::lglobal{tblfxpop}->bind( '<Control-z>', sub { $ubtn->invoke; } );
        $::lglobal{tblfxpop}->bind( '<Control-y>', sub { $rbtn->invoke; } );
        $::lglobal{tblfxpop}->protocol(
            'WM_DELETE_WINDOW' => sub {
                $textwindow->tagRemove( 'table',   '1.0', 'end' );
                $textwindow->tagRemove( 'linesel', '1.0', 'end' );
                $textwindow->markUnset( 'tblstart', 'tblend' );
                ::killpopup('tblfxpop');
            }
        );
        tblselect();
    }
}

#
# Mark the selected region as a table to be worked on
sub tblselect {
    my $textwindow = $::textwindow;
    $textwindow->tagRemove( 'table', '1.0', 'end' );
    my @ranges      = $textwindow->tagRanges('sel');
    my $range_total = @ranges;
    if ( $range_total == 0 ) {
        return;
    } else {
        my $end   = pop(@ranges);
        my $start = pop(@ranges);
        $start .= ' linestart';                            # Always start at beginning of line
        $end   .= '+1l linestart' unless $end =~ /\.0/;    # Always end at start of next line (unless already there)
        $textwindow->markSet( 'tblstart', $start );
        $textwindow->markGravity( 'tblstart', 'left' );
        $textwindow->markSet( 'tblend', $end );
        $textwindow->tagAdd( 'table', 'tblstart', 'tblend' );
    }
    $textwindow->tagRemove( 'sel',     '1.0', 'end' );
    $textwindow->tagRemove( 'linesel', '1.0', 'end' );
    undef $::lglobal{selectedline};
}

#
# Remove selected column dividing line
sub tlineremove {
    my $textwindow  = $::textwindow;
    my @ranges      = $textwindow->tagRanges('linesel');
    my $range_total = @ranges;
    $textwindow->addGlobStart;
    if ( $range_total == 0 ) {
        $textwindow->addGlobEnd;
        return;
    } else {
        while (@ranges) {
            my $end   = pop(@ranges);
            my $start = pop(@ranges);
            $textwindow->replacewith( $start, $end, ' ' )
              if ( $textwindow->get($start) eq '|' );
        }
    }
    $textwindow->tagAdd( 'table', 'tblstart', 'tblend' );
    $textwindow->tagRemove( 'linesel', '1.0', 'end' );
    $textwindow->addGlobEnd;
}

#
# Select a column dividing line as being the active one
sub tlineselect {
    my $textwindow = $::textwindow;
    return 0 unless ( $textwindow->markExists('tblstart') );
    my $op         = shift;
    my @lineranges = $textwindow->tagRanges('linesel');
    $textwindow->tagRemove( 'linesel', '1.0', 'end' );
    my @ranges      = $textwindow->tagRanges('sel');
    my $range_total = @ranges;

    if ( $range_total == 0 ) {
        my $nextcolumn;
        if ( $op and ( $op eq 'p' ) ) {
            $textwindow->markSet( 'insert', $lineranges[0] ) if @lineranges;

            # If insert position is before start of table, set it to end of first row
            $textwindow->markSet( 'insert', 'tblstart lineend' )
              if $textwindow->compare( 'insert', '<', 'tblstart' );

            # Find previous '|' column divider
            $nextcolumn =
              $textwindow->search( '-backward', '-exact', '--', '|', 'insert', 'insert linestart' );

            # if no previous '|' on this row, wrap by looking again from the end of the row
            $nextcolumn = $textwindow->search(
                '-backward', '-exact', '--', '|',
                'insert lineend',
                'insert linestart'
            ) unless $nextcolumn;
        } else {
            $textwindow->markSet( 'insert', $lineranges[1] ) if @lineranges;

            # If insert position is after end of table, set it to start of last row
            $textwindow->markSet( 'insert', 'tblend -1l linestart' )
              if $textwindow->compare( 'insert', '>', 'tblend' );

            # Find next '|' column divider
            $nextcolumn = $textwindow->search( '-exact', '--', '|', 'insert', 'insert lineend' );

            # if no next '|' on this row, wrap by looking again from the beginning of the row
            $nextcolumn =
              $textwindow->search( '-exact', '--', '|', 'insert linestart', 'insert lineend' )
              unless $nextcolumn;
        }
        return 0 unless $nextcolumn;
        push @ranges, $nextcolumn;
        push @ranges, $textwindow->index("$nextcolumn +1c");
    }
    my $end   = pop(@ranges);
    my $start = pop(@ranges);
    my ( $row, $col ) = split /\./, $start;
    my $marker = $textwindow->get( $start, $end );
    if ( $marker ne '|' ) {
        $textwindow->tagRemove( 'sel', '1.0', 'end' );
        $textwindow->markSet( 'insert', $start );
        tlineselect($op);
        return;
    }
    $::lglobal{selectedline} = $col;
    $textwindow->addGlobStart;
    $textwindow->markSet( 'insert', "$row.$col" );
    my ( $srow, $scol ) = split( /\./, $textwindow->index('tblstart') );
    my ( $erow, $ecol ) = split( /\./, $textwindow->index('tblend') );
    $erow -= 1 unless $ecol;
    for ( $srow .. $erow ) {
        $textwindow->tagAdd( 'linesel', "$_.$col" );
    }
    colcalc($srow);
    $textwindow->tagAdd( 'table', 'tblstart', 'tblend' );
    $textwindow->addGlobEnd;
    return 1;
}

#
# Calculate the width of a column to show in the dialog
sub colcalc {
    my $srow       = shift;
    my $textwindow = $::textwindow;
    my $widthline  = $textwindow->get( "$srow.0", "$srow.$::lglobal{selectedline}" );
    if ( $widthline =~ /([^|]*)$/ ) {
        $::lglobal{columnspaces} = length($1);
    } else {
        $::lglobal{columnspaces} = 0;
    }
    $::lglobal{colwidthlbl}->configure( -text => "Width $::lglobal{columnspaces}" );
}

#
# Add empty lines between table rows
sub tblspace {
    my $textwindow  = $::textwindow;
    my @ranges      = $textwindow->tagRanges('table');
    my $range_total = @ranges;
    if ( $range_total == 0 ) {
        return;
    } else {
        $textwindow->addGlobStart;
        my $cursor = $textwindow->index('insert');
        my ( $erow, $ecol ) =
          split( /\./, ( $textwindow->index('tblend - 1l lineend') ) );    # tblend is immediately after the table
        my ( $srow, $scol ) =
          split( /\./, ( $textwindow->index('tblstart') ) );
        my $tline = $textwindow->get( "$srow.0", "$srow.end" );
        $tline =~ y/|/ /c;
        while ( $erow >= $srow ) {
            $textwindow->insert( "$erow.end", "\n$tline" )
              if length( $textwindow->get( "$erow.0", "$erow.end" ) );
            $erow--;
        }
        $textwindow->tagAdd( 'table', 'tblstart', 'tblend' );
        $textwindow->tagRemove( 'linesel', '1.0', 'end' );
        undef $::lglobal{selectedline};
        $textwindow->markSet( 'insert', $cursor );
        $textwindow->addGlobEnd;
    }
}

#
# Remove the empty lines between table rows
sub tblcompress {
    my $textwindow  = $::textwindow;
    my @ranges      = $textwindow->tagRanges('table');
    my $range_total = @ranges;
    if ( $range_total == 0 ) {
        return;
    } else {
        $textwindow->addGlobStart;
        my $cursor = $textwindow->index('insert');
        my ( $erow, $ecol ) =
          split( /\./, ( $textwindow->index('tblend') ) );
        my ( $srow, $scol ) =
          split( /\./, ( $textwindow->index('tblstart') ) );
        while ( $erow >= $srow ) {
            if ( $textwindow->get( "$erow.0", "$erow.end" ) =~ /^[ |]*$/ ) {
                $textwindow->delete( "$erow.0 -1c", "$erow.end" );
            }
            $erow--;
        }
        $textwindow->tagAdd( 'table', 'tblstart', 'tblend' );
        $textwindow->markSet( 'insert', $cursor );
        $textwindow->addGlobEnd;
    }
}

#
# Add a column dividing line
sub insertline {
    my $op         = shift;
    my $textwindow = $::textwindow;
    my $insert     = $textwindow->index('insert');
    my ( $row, $col ) = split( /\./, $insert );
    my @ranges      = $textwindow->tagRanges('table');
    my $range_total = @ranges;
    if ( $range_total == 0 ) {
        ::soundbell();
        return;
    } else {
        $textwindow->addGlobStart;
        my $end   = pop(@ranges);
        my $start = pop(@ranges);
        my ( $srow, $scol ) = split( /\./, $start );
        my ( $erow, $ecol ) = split( /\./, $end );
        $erow -= 1 unless $ecol;
        for ( $srow .. $erow ) {
            my $rowlen = $textwindow->index("$_.end");
            my ( $lrow, $lcol ) = split( /\./, $rowlen );
            if ( $lcol < $col ) {
                $textwindow->ntinsert( "$_.end", ( ' ' x ( $col - $lcol ) ) );
            }
            if ( $op eq 'a' ) {
                $textwindow->delete("$_.$col")
                  if ( $textwindow->get("$_.$col") =~ /[ |]/ );
            }
            $textwindow->insert( "$_.$col", '|' );
        }
    }
    $textwindow->tagAdd( 'table', 'tblstart', 'tblend' );
    $textwindow->markSet( 'insert', $insert );
    tlineselect('n');
    $textwindow->addGlobEnd;
}

#
# Move a column dividing line left or right
sub coladjust {
    my $dir        = shift;
    my $textwindow = $::textwindow;
    return 0 unless defined $::lglobal{selectedline} or tlineselect();
    if ( $::lglobal{tblrwcol} ) {
        $dir--;
        my @tbl;
        my $selection = $textwindow->get( 'tblstart',           'tblend' );
        my $templine  = $textwindow->get( 'tblstart linestart', 'tblstart lineend' );
        my @col       = ();
        push @col, 0;
        while ( length($templine) ) {
            my $index = index( $templine, '|' );
            if ( $index > -1 ) {
                push @col, ( $index + 1 + $col[-1] );
                substr( $templine, 0, $index + 1, '' );
                next;
            }
            $templine = '';
        }
        my $colindex;
        for ( 0 .. $#col ) {
            if ( $::lglobal{selectedline} == $col[$_] - 1 ) {
                $colindex = $_;
                last;
            }
        }
        unless ($colindex) {
            $textwindow->tagRemove( 'linesel', '1.0', 'end' );
            $textwindow->tagAdd( 'table', 'tblstart', 'tblend' );
            undef $::lglobal{selectedline};
            return 0;
        }
        $selection =~ s/\n +$/\n/g;
        my @table     = split( /\n/, $selection );
        my $row       = 0;
        my $blankline = '';
        for (@table) {
            my $temp = $col[ ($colindex) ];
            $temp = $col[ ( $colindex - 1 ) ];
            my $cell = substr(
                $_,
                ( $col[ ( $colindex - 1 ) ] ),
                ( $col[$colindex] - $col[ ( $colindex - 1 ) ] - 1 ), ''
            );
            unless ($blankline) {
                $blankline = $_
                  if ( ( $_ =~ /^[ |]+$/ ) && ( $_ =~ /\|/ ) );
            }
            $cell .= ' ';
            $cell =~ s/^\s+$//;
            $tbl[$row] .= $cell;
            $row++;
        }

        # If no blank lines found in table, make one up from the first line that contains '|'.
        unless ($blankline) {
            for my $line (@table) {
                if ( $line =~ /\|/ ) {
                    $blankline = $line;
                    $blankline =~ s/[^\|]/ /g;
                    last;
                }
            }
        }
        my @cells      = ();
        my $cellheight = 1;
        my $cellflag   = 0;
        $row = 0;
        for (@tbl) {
            if ( ( length $_ ) && !$cellflag && !@cells ) {
                push @cells, 0;
                $cellflag = 1;
                next;
            } elsif ( ( length $_ ) && !$cellflag ) {
                push @cells, $cellheight;
                $cellheight = 1;
                $cellflag   = 1;
                next;
            } elsif ( !( length $_ ) && !$cellflag ) {
                $cellheight++;
                next;
            } elsif ( !( length $_ ) && $cellflag ) {
                $cellflag = 0;
                $cellheight++;
                next;
            } elsif ( ( length $_ ) && $cellflag ) {
                $cellheight++;
                next;
            }
        }
        push @cells, $cellheight;
        shift @cells unless $cells[0];
        my @tblwr;
        $::lglobal{tblindent} = 0 unless $::lglobal{tblindent};
        for my $cellcnt (@cells) {
            $templine = '';
            for ( 1 .. $cellcnt ) {
                last unless @tbl;
                $templine .= shift @tbl;
            }

            my ( $lm, $fm ) = ( 0, 0 );
            ( $::lglobal{tblhanging} ? $lm : $fm ) = $::lglobal{tblindent};
            my $wrapped =
              ::wrapper( $lm, $fm, ( $col[$colindex] - $col[ ( $colindex - 1 ) ] + $dir ),
                $templine, $::rwhyphenspace );
            push @tblwr, $wrapped;
        }
        my $rowcount = 0;
        $cellheight = 0;
        my $width = $col[$colindex] - $col[ ( $colindex - 1 ) ] + $dir;
        return 0 if $width < 0;
        my @temptable = ();
        for (@tblwr) {
            my @temparray  = split( /\n/, $_ );
            my $tempheight = @temparray;
            my $diff       = $cells[$cellheight] - $tempheight;
            if ( $diff < 1 ) {
                for ( 1 .. $cells[$cellheight] ) {
                    my $wline = shift @temparray;
                    return 0 if ( length($wline) > $width );
                    my $pad  = $width - length($wline);
                    my $padl = int( $pad / 2 );
                    my $padr = int( $pad / 2 + .5 );
                    if ( $::lglobal{tblcoljustify} eq 'l' ) {
                        $wline = $wline . ' ' x ($pad);
                    } elsif ( $::lglobal{tblcoljustify} eq 'c' ) {
                        $wline = ' ' x ($padl) . $wline . ' ' x ($padr);
                    } elsif ( $::lglobal{tblcoljustify} eq 'r' ) {
                        $wline = ' ' x ($pad) . $wline;
                    }
                    my $templine = shift @table;
                    substr( $templine, $col[ $colindex - 1 ], 0, $wline );
                    push @temptable, "$templine\n";
                }
                for (@temparray) {
                    my $pad = $width - length($_);
                    return 0 if $pad < 0;
                    my $padl = int( $pad / 2 );
                    my $padr = int( $pad / 2 + .5 );
                    if ( $::lglobal{tblcoljustify} eq 'l' ) {
                        $_ = $_ . ' ' x ($pad);
                    } elsif ( $::lglobal{tblcoljustify} eq 'c' ) {
                        $_ = ' ' x ($padl) . $_ . ' ' x ($padr);
                    } elsif ( $::lglobal{tblcoljustify} eq 'r' ) {
                        $_ = ' ' x ($pad) . $_;
                    }
                    return 0 unless $blankline;    # No blank line after row to wrap down into
                    my $templine = $blankline;
                    substr( $templine, $col[ $colindex - 1 ], 0, $_ );
                    push @temptable, "$templine\n";
                }
                return 0 unless $blankline;        # No blank line after row to wrap down into
                my $templine = $blankline;
                substr( $templine, $col[ $colindex - 1 ], 0, ' ' x $width );
                push @temptable, "$templine\n";
            }
            if ( $diff > 0 ) {
                for (@temparray) {
                    my $pad = $width - length($_);
                    return 0 if $pad < 0;
                    my $padl = int( $pad / 2 );
                    my $padr = int( $pad / 2 + .5 );
                    if ( $::lglobal{tblcoljustify} eq 'l' ) {
                        $_ = $_ . ' ' x ($pad);
                    } elsif ( $::lglobal{tblcoljustify} eq 'c' ) {
                        $_ = ' ' x ($padl) . $_ . ' ' x ($padr);
                    } elsif ( $::lglobal{tblcoljustify} eq 'r' ) {
                        $_ = ' ' x ($pad) . $_;
                    }
                    return 0 if ( length($_) > $width );
                    my $templine = shift @table;
                    substr( $templine, $col[ $colindex - 1 ], 0, $_ );
                    push @temptable, "$templine\n";
                }
                for ( 1 .. $diff ) {
                    last unless @table;
                    my $templine = shift @table;
                    substr( $templine, $col[ $colindex - 1 ], 0, ' ' x $width );
                    push @temptable, "$templine\n";
                }
            }
            $cellheight++;
        }
        @table    = ();
        $cellflag = 0;
        for (@temptable) {
            if ( (/^[ |]+$/) && !$cellflag ) {
                $cellflag = 1;
                push @table, $_;
            } else {
                next if (/^[ |]+$/);
                push @table, $_;
                $cellflag = 0;
            }
        }
        $textwindow->addGlobStart;
        my %pgindex = tblgetpg();    # Save page markers to restore them later
        $textwindow->delete( 'tblstart', 'tblend' );
        for ( reverse @table ) {
            $textwindow->insert( 'tblstart', $_ );
        }
        tblsetpg(%pgindex);          # Restore page markers
        $dir++;
    } else {
        my ( $srow, $scol ) = split( /\./, $textwindow->index('tblstart') );
        my ( $erow, $ecol ) = split( /\./, $textwindow->index('tblend') );
        $textwindow->addGlobStart;
        if ( $dir > 0 ) {
            for ( $srow .. $erow - 1 ) {
                $textwindow->insert( "$_.$::lglobal{selectedline}", ' ' );
            }
        } else {
            for ( $srow .. $erow - 1 ) {
                return 0
                  if ( $textwindow->get("$_.@{[$::lglobal{selectedline}-1]}") ne ' ' );
            }
            for ( $srow .. $erow - 1 ) {
                $textwindow->delete("$_.@{[$::lglobal{selectedline}-1]}");
            }
        }
    }
    $::lglobal{selectedline} += $dir;
    $textwindow->addGlobEnd;
    $textwindow->tagAdd( 'table', 'tblstart', 'tblend' );
    my ( $srow, $scol ) = split( /\./, $textwindow->index('tblstart') );
    my ( $erow, $ecol ) = split( /\./, $textwindow->index('tblend') );
    $erow -= 1 unless $ecol;
    for ( $srow .. $erow ) {
        $textwindow->tagAdd( 'linesel', "$_.$::lglobal{selectedline}" );
    }
    colcalc($srow);
    return 1;
}

#
# Convert table from grid format to step format
sub grid2step {
    my $textwindow = $::textwindow;
    my ( @table, @tbl, @trows, @tlines, @twords );
    my $row = 0;
    my $cols;
    return 0 unless ( $textwindow->markExists('tblstart') );
    unless ( $textwindow->get('tblstart') eq '|' ) {
        $textwindow->markSet( 'insert', 'tblstart' );
        insertline('i');
    }

    # Get page markers within table and convert to actual table rows (1st row is row 0)
    my %pgindex = tblgetpg();
    for my $mark ( keys %pgindex ) {
        my $tmpmark = 'tblstart';
        my $row     = 0;
        while ( $tmpmark = $textwindow->search( '-regex', '--', '^[ |]+$', $tmpmark, 'tblend' ) ) {
            if ( $textwindow->compare( $tmpmark, '>', $textwindow->index($mark) ) ) {
                $pgindex{$mark} = $row;
                last;
            }
            $tmpmark .= '+1l';
            $row++;
        }
        $pgindex{$mark} = $row + 1 if not $tmpmark;
    }

    $::lglobal{stepmaxwidth} = 70
      if ( ( $::lglobal{stepmaxwidth} !~ /^\d+$/ )
        || ( $::lglobal{stepmaxwidth} < 15 ) );
    my $selection = $textwindow->get( 'tblstart', 'tblend' );
    $selection =~ s/\n +/\n/g;
    @trows = split( /^[ |]+$/ms, $selection );
    for my $trow (@trows) {
        @tlines = split( /\n/, $trow );
        for my $tline (@tlines) {
            $tline =~ s/^\|//;
            if ( $selection =~ /.\|/ ) {
                @twords = split( /\|/, $tline );
            } else {
                return;
            }
            my $word = 0;
            $cols = $#twords unless $cols;
            for (@twords) {
                $tbl[$row][$word] .= "$_ ";
                $word++;
            }
        }
        $row++;
    }
    $selection = '';
    my $cell = 0;
    for my $row ( 0 .. $#tbl ) {

        # Check if a page marker needs inserting here and add a temporary marker
        for my $mark ( keys %pgindex ) {
            push @table, $TEMPPAGEMARK if $row == $pgindex{$mark};
        }
        for ( 0 .. $cols ) {
            my $wrapped;
            $wrapped = ::wrapper(
                ( $cell * 5 ),
                ( $cell * 5 ),
                $::lglobal{stepmaxwidth},
                $tbl[$row][$_], $::rwhyphenspace
            ) if $tbl[$row][$_];
            $wrapped = " \n" unless $wrapped;
            my @temparray = split( /\n/, $wrapped );
            if ($cell) {
                for (@temparray) {
                    substr( $_, 0, ( $cell * 5 - 1 ), '    |' x $cell );
                }
            }
            push @table, @temparray;
            @temparray = ();
            $cell++;
        }
        push @table, '    |' x ($cols);
        $cell = 0;
    }

    # Handle any page markers at end of table
    for my $mark ( sort keys %pgindex ) {
        push @table, $TEMPPAGEMARK if $pgindex{$mark} > $#tbl;
    }
    $textwindow->addGlobStart;
    $textwindow->delete( 'tblstart', 'tblend' );
    for ( reverse @table ) {
        $textwindow->insert( 'tblstart', "$_\n" );
    }

    # Set new page marker positions and delete temporary page marker characters
    for my $mark ( sort keys %pgindex ) {
        my $tmpmark = $textwindow->search( '-exact', '--', $TEMPPAGEMARK, 'tblstart', 'tblend' );
        last unless $tmpmark;
        $textwindow->markSet( $mark, $tmpmark );
        $textwindow->delete( $tmpmark, "$tmpmark+1l linestart" );
    }
    $textwindow->tagAdd( 'table', 'tblstart', 'tblend' );
    undef $::lglobal{selectedline};
    $textwindow->addGlobEnd;
}

#
# Convert table from step format to grid format
sub step2grid {
    my $textwindow = $::textwindow;
    my ( @table, @tbl, @tcols );
    my $row = 0;
    my $col;
    return 0 unless ( $textwindow->markExists('tblstart') );

    # Work out which row each page marker is on
    my %pgindex = tblgetpg();
    for my $mark ( keys %pgindex ) {
        my $tmpmark = 'tblstart';
        my $row     = 0;

        # Count table rows (lines starting with non-space) & store row number when arrive at page marker
        while ( $tmpmark = $textwindow->search( '-regex', '--', '^[^ ]', $tmpmark, 'tblend' ) ) {
            if ( $textwindow->compare( $tmpmark, '>=', $pgindex{$mark} ) ) {
                $pgindex{$mark} = $row;
                last;
            }
            $row++;
            $tmpmark .= '+1c';
        }
        $pgindex{$mark} = $row + 1 if not $tmpmark;    # Page marker is beyond last row
    }

    my $selection = $textwindow->get( 'tblstart', 'tblend' );
    @tcols = split( /\n[ |\n]+\n/, $selection );
    for my $tcol (@tcols) {
        $col = 0;
        while ($tcol) {
            if ( $tcol =~ s/^ *([^ |][^\n|]*)// ) {    # table text (possibly preceded by space)
                $tbl[$row][$col] .= $1 . ' ';
                $tcol =~ s/^[ |]+//;
                $tcol =~ s/^\n//;
            } else {                                   #   indentation with | character
                $tcol =~ s/^ +\|//smg;
                $col++;
            }
        }
        $row++;
    }
    $selection = '';
    $row       = 0;
    $col       = 0;
    for my $row (@tbl) {
        for (@$row) {
            $_ = ::wrapper( 0, 0, 20, $_, $::rwhyphenspace );
        }
    }
    for my $row (@tbl) {
        my $line;
        while (1) {
            my $num;
            for (@$row) {
                if ( $_ =~ s/^([^\n]*)\n// ) {
                    $num = @$row;
                    $line .= $1;
                    my $pad = 20 - length($1);
                    $line .= ' ' x $pad . '|';
                } else {
                    $line .= ' ' x 20 . '|';
                    $num--;
                }
            }
            last if ( $num < 0 );
            $line .= "\n";
        }
        $table[$col] = $line;
        $col++;
    }
    $textwindow->addGlobStart;
    $textwindow->delete( 'tblstart', 'tblend' );

    # Insert table a row at a time, setting page markers at appropriate points
    $row = 0;
    for my $line (@table) {
        if ( $line =~ /^\S/ ) {
            for my $mark ( sort keys %pgindex ) {    # sorted to ensure correct order of coincident markers
                $textwindow->markSet( $mark, $textwindow->index('tblend') )
                  if $pgindex{$mark} == $row;        # Found position for page marker
            }
            $row++;
        }
        $textwindow->insert( 'tblend', "$line\n" );
    }

    # Handle any page markers at end of table
    for my $mark ( sort keys %pgindex ) {
        $textwindow->markSet( $mark, $textwindow->index('tblend') ) if $pgindex{$mark} >= $row;
    }
    $textwindow->tagAdd( 'table', 'tblstart', 'tblend' );
    $textwindow->addGlobEnd;
}

#
# Automatically split text into table columns at multiple-space points
sub tblautoc {
    my $textwindow = $::textwindow;
    my ( @table, @tbl, @trows, @tlines, @twords );
    my $row = 0;
    my @cols;
    return 0 unless ( $textwindow->markExists('tblstart') );
    my $selection = $textwindow->get( 'tblstart', 'tblend' );
    @trows = split( /\n/, $selection );
    for my $tline (@trows) {
        $tline =~ s/^\|//;
        $tline =~ s/\s+$//;
        if ( $selection =~ /.\|/ ) {
            @twords = split( /\|/, $tline );
        } else {
            @twords = split( /  +/, $tline );
        }
        my $word = 0;
        for (@twords) {
            $_ =~ s/(^\s+)|(\s+$)//g;
            $_ = ' ' unless $_;
            my $size = ( length $_ );
            $cols[$word]      = $size unless defined $cols[$word];
            $cols[$word]      = $size if ( $size > $cols[$word] );
            $tbl[$row][$word] = $_;
            $word++;
        }
        $row++;
    }
    for my $row ( 0 .. $#tbl ) {
        for my $word ( 0 .. $#cols ) {
            $tbl[$row][$word] = '' unless defined $tbl[$row][$word];
            my $pad = ' ' x ( $cols[$word] - ( length $tbl[$row][$word] ) );
            $table[$row] .= $tbl[$row][$word] . $pad . ' |';
        }
    }
    $textwindow->addGlobStart;
    my %pgindex = tblgetpg();    # Save page markers to restore them later
    $textwindow->delete( 'tblstart', 'tblend' );
    for ( reverse @table ) {
        $textwindow->insert( 'tblstart', "$_\n" );
    }
    tblsetpg(%pgindex);          # Restore page markers
    $textwindow->tagAdd( 'table', 'tblstart', 'tblend' );
    $textwindow->addGlobEnd;
}

#
# Where cells have been OCRed one per line, with a blank line marking the end
# of the row, join cells so each row is on one line
sub rejoinrows {
    my $textwindow = $::textwindow;
    my @ranges     = $textwindow->tagRanges('table');
    if (@ranges) {
        $textwindow->addGlobStart;
        my $tbl = $textwindow->get( 'tblstart', 'tblend' );
        $tbl =~ s/(?<!\n)\n(?!\n)/  /g;    # Replace single newlines with double space to delimit cells
        $textwindow->delete( 'tblstart', 'tblend' );
        $textwindow->insert( 'tblend', $tbl . "\n" );
        $textwindow->tagAdd( 'table', 'tblstart', 'tblend' );
        $textwindow->addGlobEnd;
    }
}

#
# Get any page markers within the table, store and return their indexes.
sub tblgetpg {
    my $textwindow = $::textwindow;
    my %pgindex    = ();
    return %pgindex unless $textwindow->markExists('tblstart');

    my $mark = 'tblstart';
    while ( ( $mark = $textwindow->markNext($mark) ) and $mark ne 'tblend' ) {
        next unless $mark =~ m{Pg(\S+)};    # Only look at page markers
        $pgindex{$mark} = $textwindow->index($mark);

        # If any are at end of line, store lineend rather than specific column
        $pgindex{$mark} .= ' lineend'
          if $mark !~ /\.0/
          and $textwindow->compare( $pgindex{$mark}, '>=', "$pgindex{$mark} lineend" );
    }
    return %pgindex;
}

#
# Set any page markers that should be within the table from the given hash
sub tblsetpg {
    my $textwindow = $::textwindow;
    my %pgindex    = @_;
    return unless $textwindow->markExists('tblstart');

    for my $mark ( keys %pgindex ) {
        $textwindow->markSet( $mark, $pgindex{$mark} );
    }
}

#
# fill column's leading/trailing spaces with the table fill character or restore the spaces
sub leadtrailspaces {
    my $operation  = shift;           # fill or restore
    my $textwindow = $::textwindow;
    return unless $::lglobal{tablefillchar};

    # Get indexes of selected column divider
    my @ranges      = $textwindow->tagRanges('linesel');
    my $range_total = @ranges;
    return if $range_total == 0;

    $textwindow->addGlobStart;

    # On each line, fill/restore between the selected column divider and the previous one
    while (@ranges) {
        my $ignore    = pop(@ranges);
        my $colend    = pop(@ranges);
        my $linestart = "$colend linestart";
        my $colstart  = $textwindow->search( '-backwards', '|', $colend, $linestart ) || $linestart;
        my $string    = $textwindow->get( $colstart, $colend );
        next if $string =~ /^[ |]+$/;    # ignore blank cells
        if ( $operation eq 'fill' ) {    # Replace leading/trailing spaces with same number of fill characters
            $string =~ s/\|( +)/"|" . $::lglobal{tablefillchar} x length($1)/e;
            $string =~ s/( +)$/$::lglobal{tablefillchar} x length($1)/e;
        } else {                         # Replace all fill characters with spaces
            $string =~ s/$::lglobal{tablefillchar}/ /g;
        }
        $textwindow->delete( $colstart, $colend );
        $textwindow->insert( $colstart, $string );
    }

    $textwindow->tagRemove( 'table', '1.0', 'end' );
    $textwindow->tagAdd( 'table', 'tblstart', 'tblend' );
    $textwindow->addGlobEnd;
}

#
# Perform undo/redo and attempt to preserve table highlighting and selected column
sub undoredo {
    my $op         = shift;
    my $textwindow = $::textwindow;

    if ( $op eq 'undo' ) {
        $textwindow->undo;
    } else {
        $textwindow->redo;
    }
    $textwindow->tagRemove( 'highlight', '1.0', 'end' );
    $textwindow->tagRemove( 'table',     '1.0', 'end' );
    $textwindow->tagAdd( 'table', 'tblstart', 'tblend' );
    $textwindow->see('insert');

    # Find selected column dividers and use to store column in global variable
    my @ranges = $textwindow->tagRanges('linesel');
    if ( @ranges == 0 ) {
        tlineselect();    # No selected dividers, so select column based on cursor location
    } else {
        my $end = pop(@ranges);
        $end =~ s/.*\.//;
        $::lglobal{selectedline} = $end - 1;
    }
}
1;
