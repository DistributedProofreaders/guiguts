# LineNumberText
# Implements a TextUnicode widget with scrollbars, line numbers and column numbers
#
# Advertises "scrolled" (the TextUnicode widget) and "corner" (the resizing corner)
#
# May originally have worked with Text widget instead of TextUnicode, but the rest
# of Guiguts relies on the TextUnicode widget too much for a Text widget to work now
#
package Guiguts::LineNumberText;
use strict;
use warnings;
use Tk;
use Tk::widgets qw(ROText);
use base qw(Tk::Frame);
use Carp;
Construct Tk::Widget 'LineNumberText';

sub Populate {
    my ( $self, $args ) = @_;
    $self->SUPER::Populate($args);
    $self->{'minwidth'}       = 5;
    $self->{'linenumshowing'} = 0;
    $self->{'colnumshowing'}  = 0;

    # Create read-only text widget to display line numbers
    $self->{'ltext'} = my $ltext = $self->ROText(
        -takefocus => 0,
        -cursor    => 'X_cursor',
        -bd        => 2,                     # border doesn't show, but keeps it aligned with main text window which has border
        -relief    => 'flat',
        -width     => $self->{'minwidth'},
        -wrap      => 'none',
    );
    $ltext->{_MENU_} = ();
    $ltext->tagConfigure( 'RIGHT', -justify => 'right' );

    # Create scrolled TextUnicode widget - the main text window
    # ftext is the container widget, and rtext is the actual text window
    # Placed in grid at (1,1) to give space for row/col number widgets at (0,0) for left/above or (2,2) for right/below
    $self->{'ftext'} = my $ftext =
      $self->Scrolled('TextUnicode')->grid( -row => 1, -column => 1, -sticky => 'nsew' );
    $self->{'rtext'} = my $rtext = $ftext->Subwidget('scrolled');

    # Grid weights ensure text window resizes with main window, but row/col number widgets remain fixed size
    $self->gridColumnconfigure( 1, -weight => 1 );
    $self->gridRowconfigure( 1, -weight => 1 );

    # Create read-only text widget to display column numbers
    $self->{'ctext'} = my $ctext = $self->ROText(
        -takefocus => 0,
        -cursor    => 'X_cursor',
        -bd        => 2,            # border doesn't show, but keeps it aligned with main text window which has border
        -relief    => 'flat',
        -height    => 1,
        -wrap      => 'none',
    );
    $ctext->{_MENU_} = ();

    $self->Advertise( 'corner',   $ftext->Subwidget('corner') );
    $self->Advertise( 'scrolled', $rtext );

    # Set scrolling commands to update the line/col numbers
    for my $sub ( 'xscrollbar', 'yscrollbar' ) {
        my $swgt          = $ftext->Subwidget($sub);
        my $scrollcommand = $swgt->cget( -command );
        $swgt->configure(
            -command => sub {
                $scrollcommand->Call(@_);
                $self->_lincolupdate;
            }
        );
    }

    # What to do with configure/cget requests - also contains default values
    $self->ConfigSpecs(
        -linenumside      => [ 'METHOD',  undef,       undef,       'left' ],       # Change to 'right' to have line numbers on right
        -linenumbg        => [ 'METHOD',  'numlinebg', 'numLinebg', '#eaeaea' ],
        -linenumfg        => [ 'METHOD',  'numlinefg', 'numLinefg', '#000000' ],
        -curlinehighlight => [ 'PASSIVE', undef,       undef,       1 ],
        -curlinebg        => [ 'METHOD',  undef,       undef,       '#00ffff' ],
        -curlinefg        => [ 'METHOD',  undef,       undef,       '#000000' ],
        -colnumpos        => [ 'METHOD',  undef,       undef,       'top' ],        # Change to 'bottom' to have column numbers at bottom
        -colnumbg         => [ 'METHOD',  'numcolbg',  'numColbg',  '#eaeaea' ],
        -colnumfg         => [ 'METHOD',  'numcolfg',  'numColfg',  '#000000' ],
        -curcolbg         => [ 'METHOD',  undef,       undef,       '#eaeaea' ],    # Change for a different current column colour like current line
        -curcolfg         => [ 'METHOD',  undef,       undef,       '#000000' ],
        -background       => [ $ftext,    undef,       undef,       undef ],
        -foreground       => [ $ftext,    undef,       undef,       undef ],
        -scrollbars       => [ $ftext,    undef,       undef,       'se' ],
        -font             => ['CHILDREN'],
        -spacing1         => ['CHILDREN'],
        -spacing2         => ['CHILDREN'],
        -spacing3         => ['CHILDREN'],
        'DEFAULT'         => [$rtext],
    );
    $self->Delegates( 'DEFAULT' => 'scrolled' );

    # Bindings - Redirect attempts to focus on line/col numbers to main text window
    $ctext->bind( '<FocusIn>', sub { $rtext->focus } );
    $ltext->bind( '<FocusIn>', sub { $rtext->focus } );

    # Almost any kind of change needs line/col number update
    $ltext->bind( '<Map>',       sub { $self->_lincolupdate } );
    $rtext->bind( '<Configure>', sub { $self->_lincolupdate } );
    $rtext->bind( '<KeyPress>',  sub { $self->_lincolupdate } );
    $rtext->bind(
        '<ButtonPress>',
        sub {
            $self->{'rtext'}->{'origx'} = undef;
            $self->_lincolupdate;
        }
    );
    $rtext->bind( '<Return>',          sub { $self->_lincolupdate } );
    $rtext->bind( '<ButtonRelease-2>', sub { $self->_lincolupdate } );
    $rtext->bind( '<B2-Motion>',       sub { $self->_lincolupdate } );
    $rtext->bind( '<B1-Motion>',       sub { $self->_lincolupdate } );
    $rtext->bind( '<<autoscroll>>',    sub { $self->_lincolupdate } );
    $rtext->bind( '<MouseWheel>',      sub { $self->_lincolupdate } );
    if ( $Tk::platform eq 'unix' ) {
        $rtext->bind( '<4>', sub { $self->_lincolupdate } );
        $rtext->bind( '<5>', sub { $self->_lincolupdate } );
    }

    # These methods (either from Text base widget or TextUnicode) also need line/col updates
    my @textMethods = qw/insert delete Delete deleteBefore Contents deleteSelected
      deleteTextTaggedwith deleteToEndofLine FindAndReplaceAll GotoLineNumber
      Insert InsertKeypress InsertSelection insertTab openLine yview ReplaceSelectionsWith
      Transpose see Load SaveUTF IncludeFile ntinsert ntdelete replacewith/;
    for my $method (@textMethods) {
        no strict 'refs';
        *{$method} = sub {
            my $cw  = shift;
            my @arr = $cw->{'rtext'}->$method(@_);
            $cw->_lincolupdate;
            @arr;
        };
    }
    return;
}    # end Populate

# Configure methods
# ------------------------------------------

# For line numbers
sub linenumside {
    my ( $w, $side ) = @_;
    return unless defined $side;
    $side = lc($side);
    return unless ( $side eq 'left' or $side eq 'right' );
    $w->{'side'} = $side;
    $w->hidelinenum;
    $w->showlinenum;
    return;
}

sub linenumbg {
    return shift->{'ltext'}->configure( -bg => @_ );
}

sub linenumfg {
    return shift->{'ltext'}->configure( -fg => @_ );
}

sub curlinebg {
    return shift->{'ltext'}->tagConfigure( 'CURLINE', -background => @_ );
}

sub curlinefg {
    return shift->{'ltext'}->tagConfigure( 'CURLINE', -foreground => @_ );
}

# For column numbers
sub colnumpos {
    my ( $w, $pos ) = @_;
    return unless defined $pos;
    $pos = lc($pos);
    return unless ( $pos eq 'top' or $pos eq 'bottom' );
    $w->{'colpos'} = $pos;
    $w->hidecolnum;
    $w->showcolnum;
    return;
}

sub colnumbg {
    return shift->{'ctext'}->configure( -bg => @_ );
}

sub colnumfg {
    return shift->{'ctext'}->configure( -fg => @_ );
}

# Raise current column number - the dark border to right (and below) looks a bit like an insert cursor at the current column
sub curcolbg {
    return
      shift->{'ctext'}
      ->tagConfigure( 'CURCOL', -background => @_, -relief => 'raised', -borderwidth => 2 );
}

sub curcolfg {
    return shift->{'ctext'}->tagConfigure( 'CURCOL', -foreground => @_ );
}

# Public Methods
# ------------------------------------------
sub showlinenum {
    my ($w) = @_;
    return if ( $w->{'linenumshowing'} );
    my $col = ( $w->{'side'} eq 'right' ) ? 2 : 0;
    $w->{'ltext'}->grid( -row => 1, -column => $col, -sticky => 'ns' );
    $w->{'linenumshowing'} = 1;
    return;
}

sub hidelinenum {
    my ($w) = @_;
    return unless ( $w->{'linenumshowing'} );
    $w->{'ltext'}->gridForget;
    $w->{'linenumshowing'} = 0;
    return;
}

sub showcolnum {
    my ($w) = @_;
    return if ( $w->{'colnumshowing'} );
    my $row = ( $w->{'colpos'} eq 'top' ) ? 0 : 2;
    $w->{'ctext'}->grid( -row => $row, -column => 1, -sticky => 'ew' );
    $w->{'colnumshowing'} = 1;
    return;
}

sub hidecolnum {
    my ($w) = @_;
    return unless ( $w->{'colnumshowing'} );
    $w->{'ctext'}->gridForget;
    $w->{'colnumshowing'} = 0;
    return;
}

#Private Methods
# ------------------------------------------
sub _lincolupdate {
    my ($w) = @_;
    return
      unless ( $w->{'ltext'}->ismapped or $w->{'ctext'}->ismapped );    # Don't bother continuing if line/col numbers cannot be displayed
    my @xsave = $w->{'rtext'}->xview;
    my $idx1  = $w->{'rtext'}->index('@0,0');                           # First visible line in text widget
    my ( $dummy, $ypix ) = $w->{'rtext'}->dlineinfo($idx1);
    my $theight = $w->{'rtext'}->height;
    my $oldy    = my $lastline = -99;                                   # Ensure at least one number gets shown
    my @LineNum;
    my $insertidx = $w->{'rtext'}->index('insert');
    my ( $insertLine, $insertCol ) = split( /\./, $insertidx );
    my $ltextline = 0;
    my $leftcol   = 0;                                                  # Max value of leftmost column number

    # Find row,column index of leftmost visible column character for each row
    # Use y coordinate to get line number of visible rows
    while (1) {
        my $idx = $w->{'rtext'}->index( '@0,' . "$ypix" );
        my ( $realline, $realcol ) = split( /\./, $idx );
        my ( $x, $y, $wi, $he ) = $w->{'rtext'}->dlineinfo($idx);
        last unless defined $he;
        last if ( $oldy == $y );    #line is the same as the last one
        $oldy = $y;
        $ypix += $he;
        last
          if $ypix >= ( $theight - 1 );    #we have reached the end of the display

        # if last line of file is onscreen, we tried above to get index of first character of
        # line beyond end, which index returns as row/col of last character of last line of file
        last if ( $y == $ypix );
        $ltextline++;

        if ( $realline == $lastline ) {
            push( @LineNum, "\n" );
        } else {
            push( @LineNum, "$realline\n" );
        }
        $lastline = $realline;

        # If line too short and scrolled off left side of screen, index returns column number
        # of last character of line, so need to get maximum column number, not just the first.
        # That will give us the column number of the first visible column of the screen
        $leftcol = $realcol if $realcol > $leftcol;
    }

    if ( $w->{'ltext'}->ismapped ) {

        # Ensure proper width for large line numbers (over 5 digits)
        my $neededwidth = length($lastline) + 1;
        my $ltextwidth  = $w->{'ltext'}->cget( -width );
        if ( $neededwidth > $ltextwidth ) {
            $w->{'ltext'}->configure( -width => $neededwidth );
        } elsif ( $ltextwidth > $w->{'minwidth'}
            && $neededwidth <= $w->{'minwidth'} ) {
            $w->{'ltext'}->configure( -width => $w->{'minwidth'} );
        } elsif ( $neededwidth < $ltextwidth
            and $neededwidth > $w->{'minwidth'} ) {
            $w->{'ltext'}->configure( -width => $neededwidth );
        }

        # Finally insert the linenumbers..
        $w->{'ltext'}->delete( '1.0', 'end' );
        my $i = 1;
        my $highlightline;
        foreach my $ln (@LineNum) {
            $w->{'ltext'}->insert( 'end', $ln );
            if ( $ln =~ /\d+/ and $ln == $insertLine ) {
                $highlightline = $i;
            }
            $i++;
        }
        if ( $highlightline and $w->cget( -curlinehighlight ) ) {
            $w->{'ltext'}->tagAdd( 'CURLINE', "$highlightline\.0", "$highlightline\.end" );
        }
        $w->{'ltext'}->tagAdd( 'RIGHT', '1.0', 'end' );
    }

    # Now insert the column numbers
    if ( $w->{'ctext'}->ismapped ) {

        # Note that on Mac, ROText widget appears to have a width limit of 192.
        # If the string below is more than that, its first characters don't get displayed
        my $ruler = substr(
            "....,....1....,....2....,....3....,....4....,....5....,....6....,....7....,....8....,....9....,...10"
              . "....,....1....,....2....,....3....,....4....,....5....,....6....,....7....,....8....,....9",
            $leftcol
        );
        $w->{'ctext'}->delete( '1.0', 'end' );
        $w->{'ctext'}->insert( 'end', $ruler );

        # Use tag to highlight in the ruler to the left of where the insert cursor is, i.e. current column
        if ( $insertCol >= $leftcol ) {
            my $highlightcol = $insertCol - $leftcol - 1;
            $w->{'ctext'}->tagAdd( 'CURCOL', "1.$highlightcol" ) if $highlightcol >= 0;
        }
    }
    $w->{'rtext'}->xviewMoveto( $xsave[0] );
    return;
}

1;
