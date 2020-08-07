package Guiguts::PageNumbers;
use strict;
use warnings;

BEGIN {
    use Exporter();
    our ( @ISA, @EXPORT );
    @ISA    = qw(Exporter);
    @EXPORT = qw( &hidepagenums &displaypagenums &togglepagenums
      &pnumadjust &pgnext &pgprevious &pgrenum &pmovedown
      &pmoveup &pmoveleft &pmoveright &pageadd &pageremove	);
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
        if ( $::lglobal{pagemarkerpop} ) {
            $::geometryhash{pagemarkerpop} = $::lglobal{pagemarkerpop}->geometry;
            $::lglobal{pagemarkerpop}->destroy;
            undef $::lglobal{pagemarkerpop};
        }
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
            -activebackground => $::activecolor,
            -command          => \&::pmoveup,
            -text             => 'Move Up',
            -width            => 10
        )->grid( -row => 1, -column => 2 );
        my $leftbutton = $frame2->Button(
            -activebackground => $::activecolor,
            -command          => \&::pmoveleft,
            -text             => 'Move Left',
            -width            => 10
        )->grid( -row => 2, -column => 1 );
        $::lglobal{pagenumentry} = $frame2->Entry(
            -background => 'yellow',
            -relief     => 'sunken',
            -text       => $mark,
            -width      => 10,
            -justify    => 'center',
        )->grid( -row => 2, -column => 2 );
        my $rightbutton = $frame2->Button(
            -activebackground => $::activecolor,
            -command          => \&::pmoveright,
            -text             => 'Move Right',
            -width            => 10
        )->grid( -row => 2, -column => 3 );
        my $downbutton = $frame2->Button(
            -activebackground => $::activecolor,
            -command          => \&::pmovedown,
            -text             => 'Move Down',
            -width            => 10
        )->grid( -row => 3, -column => 2 );
        my $frame3     = $::lglobal{pagemarkerpop}->Frame->pack( -pady => 4 );
        my $prevbutton = $frame3->Button(
            -activebackground => $::activecolor,
            -command          => \&::pgprevious,
            -text             => 'Previous Marker',
            -width            => 14
        )->grid( -row => 1, -column => 1 );
        my $nextbutton = $frame3->Button(
            -activebackground => $::activecolor,
            -command          => \&::pgnext,
            -text             => 'Next Marker',
            -width            => 14
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
            -activebackground => $::activecolor,
            -command          => \&::pgrenum,
            -text             => 'Renumber',
            -width            => 12
        )->grid( -row => 3, -column => 1, -pady => 3 );
        my $frame5 = $::lglobal{pagemarkerpop}->Frame->pack( -pady => 5 );
        $frame5->Button(
            -activebackground => $::activecolor,
            -command          => sub { $textwindow->bell unless ::pageadd() },
            -text             => 'Add',
            -width            => 8
        )->grid( -row => 1, -column => 1 );
        $frame5->Button(
            -activebackground => $::activecolor,
            -command          => sub {
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
        $frame5->Button(
            -activebackground => $::activecolor,
            -command          => \&::pageremove,
            -text             => 'Remove',
            -width            => 8
        )->grid( -row => 1, -column => 3 );
        my $frame6 = $::lglobal{pagemarkerpop}->Frame->pack( -pady => 5 );
        $frame6->Button(
            -activebackground => $::activecolor,
            -command          => sub {
                ::togglepagenums();
                $textwindow->addGlobStart;
                my @marks = $textwindow->markNames;
                for ( sort @marks ) {
                    if ( $_ =~ /Pg(\S+)/ ) {
                        my $pagenum = '[Pg ' . $1 . ']';
                        $textwindow->insert( $_, $pagenum );
                    }
                }
                $textwindow->addGlobEnd;
            },
            -text  => 'Insert Page Markers',
            -width => 20,
        )->grid( -row => 1, -column => 1 );
        $::lglobal{pagemarkerpop}->bind( $::lglobal{pagemarkerpop}, '<Up>'     => \&::pmoveup );
        $::lglobal{pagemarkerpop}->bind( $::lglobal{pagemarkerpop}, '<Left>'   => \&::pmoveleft );
        $::lglobal{pagemarkerpop}->bind( $::lglobal{pagemarkerpop}, '<Right>'  => \&::pmoveright );
        $::lglobal{pagemarkerpop}->bind( $::lglobal{pagemarkerpop}, '<Down>'   => \&::pmovedown );
        $::lglobal{pagemarkerpop}->bind( $::lglobal{pagemarkerpop}, '<Prior>'  => \&::pgprevious );
        $::lglobal{pagemarkerpop}->bind( $::lglobal{pagemarkerpop}, '<Next>'   => \&::pgnext );
        $::lglobal{pagemarkerpop}->bind( $::lglobal{pagemarkerpop}, '<Delete>' => \&::pageremove );
        $::lglobal{pagemarkerpop}->protocol(
            'WM_DELETE_WINDOW' => sub {
                $::lglobal{pagemarkerpop}->destroy;
                undef $::lglobal{pagemarkerpop};
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
    $textwindow->bell unless $offset;
    return            unless $offset;
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

sub pgprevious {    #move focus to previous page marker
    my $textwindow = $::textwindow;
    $::auto_show_images = 0;    # turn off so no interference
    my $mark;
    my $num = $::lglobal{pagenumentry}->get;
    $num  = $textwindow->index('insert') unless $num;
    $mark = $num;
    while ( $num = $textwindow->markPrevious($num) ) {
        if ( $num =~ /Pg\S+/ ) { $mark = $num; last; }
    }
    $::lglobal{pagenumentry}->delete( '0', 'end' );
    $::lglobal{pagenumentry}->insert( 'end', $mark );
    if ( $::lglobal{showthispageimage} and ( $mark =~ /Pg(\S+)/ ) ) {
        $textwindow->focus;
        ::openpng( $textwindow, $1 );
        $::lglobal{showthispageimage} = 0;
    }
    $textwindow->markSet( 'insert', $mark );
    ::seeindex( $mark, $::donotcenterpagemarkers );
    ::update_indicators();
}

sub pgnext {    #move focus to next page marker
    my $textwindow = $::textwindow;
    my $mark;
    my $num = $::lglobal{pagenumentry}->get;
    $::auto_show_images = 0;                                          # turn off so no interference
    $num                = $textwindow->index('insert') unless $num;
    $mark               = $num;
    while ( $num = $textwindow->markNext($num) ) {
        if ( $num =~ /Pg\S+/ ) { $mark = $num; last; }
    }
    $::lglobal{pagenumentry}->delete( '0', 'end' );
    $::lglobal{pagenumentry}->insert( 'end', $mark );
    if ( $::lglobal{showthispageimage} and ( $mark =~ /Pg(\S+)/ ) ) {
        $textwindow->focus;
        ::openpng( $textwindow, $1 );
        $::lglobal{showthispageimage} = 0;
    }
    $textwindow->markSet( 'insert', $mark );
    ::seeindex( $mark, $::donotcenterpagemarkers );
    ::update_indicators();
}

sub pmoveup {    # move the page marker up a line
    my $textwindow = $::textwindow;
    my $mark;
    my $num = $::lglobal{pagenumentry}->get;
    $num  = $textwindow->index('insert') unless $num;
    $mark = $num;
    if ( not $num =~ /Pg\S+/ ) {
        while ( $num = $textwindow->markPrevious($num) ) {
            last
              if $num =~ /Pg\S+/;
        }
    }
    $num = '1.0' unless $num;
    my $pagenum   = " $mark ";
    my $markindex = $textwindow->index("$mark");
    my $index     = $textwindow->index("$markindex-1 lines");
    if ( $num eq '1.0' ) {
        return if $textwindow->compare( $index, '<', '1.0' );
    } else {

        #		return
        #		  if $textwindow->compare(
        #								   $index, '<',
        #								   (
        #									  $textwindow->index(
        #											 $num . '+' . length($pagenum) . 'c'
        #									  )
        #								   )
        #		  );
    }
    $textwindow->ntdelete( $mark, $mark . ' +' . length($pagenum) . 'chars' );
    $textwindow->markSet( $mark, $index );
    $textwindow->markGravity( $mark, 'left' );
    $textwindow->ntinsert( $mark, $pagenum );
    $textwindow->tagAdd( 'pagenum', $mark, $mark . ' +' . length($pagenum) . ' chars' );
    ::setedited(1);
    $textwindow->see($mark);
}

sub pmoveleft {    # move the page marker left a character
    my $textwindow = $::textwindow;
    my $mark;
    my $num = $::lglobal{pagenumentry}->get;
    $num  = $textwindow->index('insert') unless $num;
    $mark = $num;
    while ( $num = $textwindow->markPrevious($num) ) {
        last
          if $num =~ /Pg\S+/;
    }
    $num = '1.0' unless $num;
    my $pagenum = " $mark ";
    my $index   = $textwindow->index("$mark-1c");
    if ( $num eq '1.0' ) {
        return if $textwindow->compare( $index, '<', '1.0' );
    } else {
        return
          if $textwindow->compare( $index, '<',
            ( $textwindow->index( $num . '+' . length($pagenum) . 'c' ) ) );
    }
    $textwindow->ntdelete( $mark, $mark . ' +' . length($pagenum) . 'c' );
    $textwindow->markSet( $mark, $index );
    $textwindow->markGravity( $mark, 'left' );
    $textwindow->ntinsert( $mark, $pagenum );
    $textwindow->tagAdd( 'pagenum', $mark, $mark . ' +' . length($pagenum) . 'c' );
    ::setedited(1);
    $textwindow->see($mark);
}

sub pmoveright {    # move the page marker right a character
    my $textwindow = $::textwindow;
    my $mark;
    my $num = $::lglobal{pagenumentry}->get;
    $num  = $textwindow->index('insert') unless $num;
    $mark = $num;
    while ( $num = $textwindow->markNext($num) ) { last if $num =~ /Pg\S+/ }
    $num = $textwindow->index('end') unless $num;
    my $pagenum = " $mark ";
    my $index   = $textwindow->index("$mark+1c");

    if (
        $textwindow->compare(
            $index, '>=', $textwindow->index($mark) . 'lineend -' . length($pagenum) . 'c'
        )
    ) {
        $index = $textwindow->index( $textwindow->index($mark) . ' +1l linestart' );
    }
    if ( $textwindow->compare( $num, '==', 'end' ) ) {
        return if $textwindow->compare( $index, '>=', 'end' );
    } else {
        return
          if $textwindow->compare( $index . '+' . length($pagenum) . 'c', '>=', $num );
    }
    $textwindow->ntdelete( $mark, $mark . ' +' . length($pagenum) . 'c' );
    $textwindow->markSet( $mark, $index );
    $textwindow->markGravity( $mark, 'left' );
    $textwindow->ntinsert( $mark, $pagenum );
    $textwindow->tagAdd( 'pagenum', $mark, $mark . ' +' . length($pagenum) . 'c' );
    ::setedited(1);
    $textwindow->see($mark);
}

sub pmovedown {    # move the page marker down a line
    my $textwindow = $::textwindow;
    my $mark;
    my $num = $::lglobal{pagenumentry}->get;
    $num  = $textwindow->index('insert') unless $num;
    $mark = $num;
    while ( $num = $textwindow->markNext($num) ) { last if $num =~ /Pg\S+/ }
    $num = $textwindow->index('end') unless $num;
    my $pagenum = " $mark ";
    my $index   = $textwindow->index("$mark+1l");

    if ( $textwindow->compare( $num, '==', 'end' ) ) {
        return if $textwindow->compare( $index, '>=', 'end' );
    } else {
        return if $textwindow->compare( $index, '>', $num );
    }
    $textwindow->ntdelete( $mark, $mark . ' +' . length($pagenum) . 'c' );
    $textwindow->markSet( $mark, $index );
    $textwindow->markGravity( $mark, 'left' );
    $textwindow->ntinsert( $mark, $pagenum );
    $textwindow->tagAdd( 'pagenum', $mark, $mark . ' +' . length($pagenum) . 'c' );
    ::setedited(1);
    $textwindow->see($mark);
}
## End Page Number Adjust

1;
