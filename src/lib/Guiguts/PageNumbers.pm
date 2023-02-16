package Guiguts::PageNumbers;
use strict;
use warnings;

BEGIN {
    use Exporter();
    our ( @ISA, @EXPORT );
    @ISA    = qw(Exporter);
    @EXPORT = qw( &hidepagenums &displaypagenums &togglepagenums
      &pnumadjust &pgfocus &pgrenum &pageadd &pageremove &pagetextinsert );
}

sub hidepagenums {
    ::togglepagenums() if $::lglobal{seepagenums};
}

sub displaypagenums {
    ::togglepagenums() unless $::lglobal{seepagenums};
}

## Toggle visible page markers. This is not line numbers but marks for pages.
sub togglepagenums {
    my $showallmarkers = shift;
    my $textwindow     = $::textwindow;
    if ( $::lglobal{seepagenums} ) {
        $::lglobal{seepagenums} = 0;
        my @marks = $textwindow->markNames;
        for ( reverse sort @marks ) {
            if ( $_ =~ m{Pg(\S+)} ) {
                my $pagenum = " Pg$1 ";
                $textwindow->ntdelete( $_, "$_ +@{[length $pagenum]}c" );
            } elsif ($showallmarkers) {
                my $pagenum = " @_";
                $textwindow->ntdelete( $_, "$_ +@{[length $pagenum]}c" );
            }
        }
        $textwindow->tagRemove( 'pagenum', '1.0', 'end' );
        ::killpopup('pagemarkerpop');
    } else {
        $::lglobal{seepagenums} = 1;
        my @marks = $textwindow->markNames;
        for ( reverse sort @marks ) {
            if ( $_ =~ m{Pg(\S+)} ) {
                my $pagenum = " Pg$1 ";
                $textwindow->ntinsert( $_, $pagenum );
                $textwindow->tagAdd( 'pagenum', $_, "$_ +@{[length $pagenum]}c" );
            } elsif ($showallmarkers) {
                my $pagenum = " $1";
                $textwindow->ntinsert( $_, $pagenum );
                $textwindow->tagAdd( 'pagenum', $_, "$_ +@{[length $pagenum]}c" );
            }
        }
        ::pnumadjust();
    }
}

## Page Number Adjust
sub pnumadjust {
    my $textwindow = $::textwindow;
    my $top        = $::top;
    my $mark       = $textwindow->index('current');
    while ( $mark = $textwindow->markPrevious($mark) ) {
        if ( $mark =~ /Pg(\S+)/ ) {
            last;
        }
    }
    if ( not defined $mark ) {
        $mark = $textwindow->index('current');
    }
    if ( not defined $mark ) {
        $mark = "1.0";
    }
    if ( not $mark =~ /Pg(\S+)/ ) {
        while ( $mark = $textwindow->markNext($mark) ) {
            if ( $mark =~ /Pg(\S+)/ ) {
                last;
            }
        }
    }
    $textwindow->markSet( 'insert', $mark || '1.0' );
    if ( $::lglobal{pagemarkerpop} ) {
        $::lglobal{pagemarkerpop}->deiconify;
        $::lglobal{pagemarkerpop}->raise;
        $::lglobal{pagenumentry}->configure( -text => $mark );
    } else {
        $::lglobal{pagemarkerpop} = $top->Toplevel;
        ::initialize_popup_without_deletebinding('pagemarkerpop');
        $::lglobal{pagemarkerpop}->title('Adjust Page Markers');
        my $frame2   = $::lglobal{pagemarkerpop}->Frame->pack( -pady => 5 );
        my $upbutton = $frame2->Button(
            -command => sub { pmove('up'); },
            -text    => 'Move Up',
            -width   => 10
        )->grid( -row => 1, -column => 2 );
        my $leftbutton = $frame2->Button(
            -command => sub { pmove('left'); },
            -text    => 'Move Left',
            -width   => 10
        )->grid( -row => 2, -column => 1 );
        $::lglobal{pagenumentry} = $frame2->Entry(
            -background => 'yellow',
            -relief     => 'sunken',
            -text       => $mark,
            -width      => 10,
            -justify    => 'center',
        )->grid( -row => 2, -column => 2 );
        my $rightbutton = $frame2->Button(
            -command => sub { pmove('right'); },
            -text    => 'Move Right',
            -width   => 10
        )->grid( -row => 2, -column => 3 );
        my $downbutton = $frame2->Button(
            -command => sub { pmove('down'); },
            -text    => 'Move Down',
            -width   => 10
        )->grid( -row => 3, -column => 2 );
        my $frame3     = $::lglobal{pagemarkerpop}->Frame->pack( -pady => 4 );
        my $prevbutton = $frame3->Button(
            -command => sub { pgfocus(-1); },
            -text    => 'Previous Marker',
            -width   => 14
        )->grid( -row => 1, -column => 1 );
        my $nextbutton = $frame3->Button(
            -command => sub { pgfocus(+1); },
            -text    => 'Next Marker',
            -width   => 14
        )->grid( -row => 1, -column => 2 );
        my $frame4 = $::lglobal{pagemarkerpop}->Frame->pack( -pady => 5 );
        $frame4->Label( -text => 'Adjust Page Offset', )->grid( -row => 1, -column => 1 );
        $::lglobal{pagerenumoffset} = $frame4->Spinbox(
            -textvariable => 0,
            -from         => -999,
            -to           => 999,
            -increment    => 1,
            -width        => 6,
        )->grid( -row => 2, -column => 1 );
        $frame4->Button(
            -command => \&::pgrenum,
            -text    => 'Renumber',
            -width   => 12
        )->grid( -row => 3, -column => 1, -pady => 3 );
        my $frame5 = $::lglobal{pagemarkerpop}->Frame->pack( -pady => 5 );
        $frame5->Button(
            -command => sub { ::soundbell() unless ::pageadd() },
            -text    => 'Add',
            -width   => 8
        )->grid( -row => 1, -column => 1 );
        $frame5->Button(
            -command => sub {
                my $insert = $textwindow->index('insert');
                unless ( ::pageadd() ) {
                    $::lglobal{pagerenumoffset}->configure( -textvariable => '1' );
                    $textwindow->markSet( 'insert', $insert );
                    ::pgrenum();
                    $textwindow->markSet( 'insert', $insert );
                    ::pageadd();
                }
                $textwindow->markSet( 'insert', $insert );
            },
            -text  => 'Insert',
            -width => 8
        )->grid( -row => 1, -column => 2 );
        my $removebutton = $frame5->Button(
            -command => \&::pageremove,
            -text    => 'Remove',
            -width   => 8
        )->grid( -row => 1, -column => 3 );
        my $frame6 = $::lglobal{pagemarkerpop}->Frame->pack( -pady => 5 );
        $frame6->Button(
            -command => sub { pagetextinsert('markers'); },
            -text    => 'Insert Page Markers',
            -width   => 16,
        )->grid( -row => 1, -column => 1 );
        $frame6->Button(
            -command => sub { pagetextinsert('labels'); },
            -text    => 'Insert Page Labels',
            -width   => 16,
        )->grid( -row => 1, -column => 2 );
        $::lglobal{pagemarkerpop}->bind( '<Up>'     => sub { $upbutton->invoke; } );
        $::lglobal{pagemarkerpop}->bind( '<Left>'   => sub { $leftbutton->invoke; } );
        $::lglobal{pagemarkerpop}->bind( '<Right>'  => sub { $rightbutton->invoke; } );
        $::lglobal{pagemarkerpop}->bind( '<Down>'   => sub { $downbutton->invoke; } );
        $::lglobal{pagemarkerpop}->bind( '<Prior>'  => sub { $prevbutton->invoke; } );
        $::lglobal{pagemarkerpop}->bind( '<Next>'   => sub { $nextbutton->invoke; } );
        $::lglobal{pagemarkerpop}->bind( '<Delete>' => sub { $removebutton->invoke; } );
        $::lglobal{pagemarkerpop}->protocol(
            'WM_DELETE_WINDOW' => sub {
                ::killpopup('pagemarkerpop');
                ::hidepagenums();
            }
        );
        if ($::OS_WIN) {
            $::lglobal{pagerenumoffset}->bind(
                $::lglobal{pagerenumoffset},
                '<MouseWheel>' => [
                    sub {
                        ( $_[1] > 0 )
                          ? $::lglobal{pagerenumoffset}->invoke('buttonup')
                          : $::lglobal{pagerenumoffset}->invoke('buttondown');
                    },
                    ::Ev('D')
                ]
            );
        }
    }
}

#
# Insert the text of either the page markers or page labels (if configured)
sub pagetextinsert {
    my $type       = shift;           # 'markers' or 'labels'
    my $textwindow = $::textwindow;
    ::hidepagenums();
    $textwindow->addGlobStart;
    my @marks = $textwindow->markNames;
    for my $page ( reverse sort @marks ) {    # Reverse ensures coincident markers end up in correct order
        if ( $page =~ /(Pg)(\S+)/ ) {         # Only use page marks
            my $pagetxt;
            if ( $type eq 'labels' ) {
                next unless $::pagenumbers{$page}{label};    # No label, so skip
                $pagetxt = $::pagenumbers{$page}{label};
            } else {
                $pagetxt = "$1 $2";                          # Insert marker with a space
            }
            $textwindow->insert( $page, '[' . $pagetxt . ']' );
        }
    }
    $textwindow->addGlobEnd;
}

sub pageremove {    # Delete a page marker
    my $textwindow = $::textwindow;
    my $num        = $::lglobal{pagenumentry}->get;
    $num = $textwindow->index('insert') unless $num;
    ::hidepagenums();
    $textwindow->markUnset($num);
    %::pagenumbers = ();
    my @marks = $textwindow->markNames;
    for (@marks) {
        $::pagenumbers{$_}{offset} = $textwindow->index($_) if $_ =~ /Pg\S+/;
    }
    ::setedited(1);
    ::displaypagenums();
}

sub pageadd {    # Add a page marker
    my $textwindow = $::textwindow;
    my ( $prev, $next, $mark, $length );
    my $insert = $textwindow->index('insert');
    $textwindow->markSet( 'insert', '1.0' );
    $prev = $insert;
    while ( $prev = $textwindow->markPrevious($prev) ) {
        if ( $prev =~ /Pg(\S+)/ ) {
            $mark   = $1;
            $length = length($1);
            last;
        }
    }
    unless ($prev) {
        $prev = $insert;
        while ( $prev = $textwindow->markNext($prev) ) {
            if ( $prev =~ /Pg(\S+)/ ) {
                $mark   = 0;
                $length = length($1);
                last;
            }
        }
        $prev = '1.0';
    }
    $mark = sprintf( "%0" . $length . 'd', $mark + 1 );
    $mark = "Pg$mark";
    $textwindow->markSet( 'insert', $insert );
    return 0 if ( $textwindow->markExists($mark) );
    ::hidepagenums();
    $textwindow->markSet( $mark, $insert );
    $textwindow->markGravity( $mark, 'left' );
    %::pagenumbers = ();
    my @marks = $textwindow->markNames;

    for (@marks) {
        $::pagenumbers{$_}{offset} = $textwindow->index($_) if $_ =~ /Pg\S+/;
    }
    ::setedited(1);
    ::displaypagenums();
    return 1;
}

sub pgrenum {    # Re sequence page markers
    my $textwindow = $::textwindow;
    my ( $mark, $length, $num, $start, $end );
    my $offset = $::lglobal{pagerenumoffset}->get;
    return if $offset !~ m/-?\d+/;
    my @marks;
    if ( $offset < 0 ) {
        @marks = ( sort( keys(%::pagenumbers) ) );
        $num   = $start = $::lglobal{pagenumentry}->get;
        $start =~ s/Pg(\S+)/$1/;
        while ( $num = $textwindow->markPrevious($num) ) {
            if ( $num =~ /Pg\d+/ ) {
                $mark = $num;
                $mark =~ s/Pg(\S+)/$1/;
                if ( ( $mark - $start ) le $offset ) {
                    $offset = ( $mark - $start + 1 );
                }
                last;
            }
        }
        while ( !( $textwindow->markExists( $marks[$#marks] ) ) ) {
            pop @marks;
        }
        $end   = $marks[$#marks];
        $start = $::lglobal{pagenumentry}->get;
        while ( $marks[0] ne $start ) { shift @marks }
    } else {
        @marks = reverse( sort( keys(%::pagenumbers) ) );
        while ( !( $textwindow->markExists( $marks[0] ) ) ) { shift @marks }
        $start = $textwindow->index('end');
        $num   = $textwindow->index('insert');
        while ( $num = $textwindow->markNext($num) ) {
            if ( $num =~ /Pg\d+/ ) {
                $end = $num;
                last;
            }
        }
        $end = $::lglobal{pagenumentry}->get unless $end;
        while ( $marks[$#marks] ne $end ) { pop @marks }
    }
    unless ($offset) {
        ::soundbell();
        return;
    }
    ::hidepagenums();
    $textwindow->markSet( 'insert', '1.0' );
    %::pagenumbers = ();
    while (1) {
        $start = shift @marks;
        last unless $start;
        $start =~ /Pg(\S+)/;
        $mark   = $1;
        $length = length($1);
        $mark   = sprintf( "%0" . $length . 'd', $mark + $offset );
        $mark   = "Pg$mark";
        $num    = $start;
        $start  = $textwindow->index($num);
        $textwindow->markUnset($num);
        $textwindow->markSet( $mark, $start );
        $textwindow->markGravity( $mark, 'left' );
        next if @marks;
        last;
    }
    @marks = $textwindow->markNames;
    for (@marks) {
        $::pagenumbers{$_}{offset} = $textwindow->index($_) if $_ =~ /Pg\d+/;
    }
    ::setedited(1);
    ::displaypagenums();
}

#
# Move focus to previous or next marker (pass negative number for previous)
# Optional second argument to show the image for this page
sub pgfocus {
    my $searchmethod = (shift) < 0 ? "markPrevious" : "markNext";
    my $showimage    = shift;
    my $textwindow   = $::textwindow;
    ::set_auto_img(0);    # turn off so no interference
    my $mark;
    my $num = $::lglobal{pagenumentry}->get;
    $num  = $textwindow->index('insert') unless $num;
    $mark = $num;

    while ( $num = $textwindow->$searchmethod($num) ) {
        if ( $num =~ /Pg\S+/ ) {
            $mark = $num;
            last;
        }
    }
    $::lglobal{pagenumentry}->delete( '0', 'end' );
    $::lglobal{pagenumentry}->insert( 'end', $mark );
    if ( $showimage and $mark =~ /Pg(\S+)/ ) {
        $textwindow->focus;
        ::openpng( $textwindow, $1 );
    }
    $textwindow->markSet( 'insert', $mark );
    ::seeindex( $mark, $::donotcenterpagemarkers );
}

#
# Move current page marker based on up/down/left/right argument
sub pmove {
    my $direction = shift;
    my $pm        = ( $direction =~ /(down|right)/ ? "+" : "-" );    # down/right are forwards; up/left backwards
    my $lc        = ( $direction =~ /(up|down)/    ? "l" : "c" );    # up/down move a line; left/right a char

    my $textwindow = $::textwindow;
    my $mark       = $::lglobal{pagenumentry}->get;
    return unless $mark and $mark =~ /Pg\S+/;
    my $pagenum = " $mark ";
    my $markend = "$mark+" . length($pagenum) . "c";
    my $index   = $textwindow->index("$mark${pm}1$lc");              # index of new position

    # Special case: "+1c" does not automatically drop off end of line to next line
    $index = $textwindow->index("$mark +1l linestart")
      if $direction eq 'right' and $textwindow->compare( "$markend+1c", '>', "$markend lineend" );

    # Exit if trying to move beyond beginning or end
    return
      if $textwindow->compare( $index, '<',  '1.0' )
      or $textwindow->compare( $index, '>=', 'end' );

    $textwindow->ntdelete( $mark, $markend );
    $textwindow->markSet( $mark, $index );
    $textwindow->markGravity( $mark, 'left' );
    $textwindow->ntinsert( $mark, $pagenum );
    $textwindow->tagAdd( 'pagenum', $mark, $markend );
    ::setedited(1);
    $textwindow->see($mark);
}

1;
