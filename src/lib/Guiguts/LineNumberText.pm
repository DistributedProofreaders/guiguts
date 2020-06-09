#$Id: LineNumberText.pm 1120 2012-02-20 06:30:00Z hmonroe $
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
	my $widget;
	if ( $widget = delete $args->{-widget} ) {
		$widget = 'TextUnicode';
	} else {
		$widget = 'Text';
	}
	my $ltext = $self->ROText(
							   -takefocus => 0,
							   -cursor    => 'X_cursor',
							   -bd        => 2,
							   -relief    => 'flat',
							   -width     => $self->{'minwidth'},
							   -wrap      => 'none',
	);
	$ltext->{_MENU_} = ();
	$self->{'ltext'} = $ltext;
	$ltext->tagConfigure( 'CURLINE', -data    => 1 );
	$ltext->tagConfigure( 'RIGHT',   -justify => 'right' );
	my $ftext =
	  $self->Scrolled($widget)
	  ->grid( -row => 0, -column => 1, -sticky => 'nsew' );
	$self->{'rtext'} = my $rtext = $ftext->Subwidget('scrolled');
	$self->gridColumnconfigure( 1, -weight => 1 );
	$self->gridRowconfigure( 0, -weight => 1 );
	$self->Advertise( 'yscrollbar', $ftext->Subwidget('yscrollbar') );
	$self->Advertise( 'xscrollbar', $ftext->Subwidget('xscrollbar') );
	$self->Advertise( 'corner',     $ftext->Subwidget('corner') );
	$self->Advertise( 'frame',      $ftext );
	$self->Advertise( 'scrolled',   $rtext );
	$self->Advertise( 'text',       $rtext );
	$self->Advertise( 'linenum',    $ltext );

	# Set scrolling command to run the lineupdate..
	my $yscroll       = $self->Subwidget('yscrollbar');
	my $scrollcommand = $yscroll->cget( -command );
	$yscroll->configure(
		-command => sub {
			$scrollcommand->Call(@_);
			$self->_lineupdate;
		}
	);
	$self->ConfigSpecs(
		-linenumside      => [ 'METHOD',  undef,       undef,       'left' ],
		-linenumbg        => [ 'METHOD',  'numlinebg', 'numLinebg', '#eaeaea' ],
		-linenumfg        => [ 'METHOD',  'numlinefg', 'numLinefg', '#000000' ],
		-curlinehighlight => [ 'PASSIVE', undef,       undef,       1 ],
		-curlinebg        => [ 'METHOD',  undef,       undef,       '#00ffff' ],
		-curlinefg        => [ 'METHOD',  undef,       undef,       '#000000' ],
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

	#Bindings
	$ltext->bind( '<FocusIn>',   sub { $rtext->focus } );
	$ltext->bind( '<Map>',       sub { $self->_lineupdate } );
	$rtext->bind( '<Configure>', sub { $self->_lineupdate } );
	$rtext->bind( '<KeyPress>',  sub { $self->_lineupdate } );
	$rtext->bind(
		'<ButtonPress>',
		sub {
			$self->{'rtext'}->{'origx'} = undef;
			$self->_lineupdate;
		}
	);
	$rtext->bind( '<Return>',          sub { $self->_lineupdate } );
	$rtext->bind( '<ButtonRelease-2>', sub { $self->_lineupdate } );
	$rtext->bind( '<B2-Motion>',       sub { $self->_lineupdate } );
	$rtext->bind( '<B1-Motion>',       sub { $self->_lineupdate } );
	$rtext->bind( '<<autoscroll>>',    sub { $self->_lineupdate } );
	$rtext->bind( '<MouseWheel>',      sub { $self->_lineupdate } );
	if ( $Tk::platform eq 'unix' ) {
		$rtext->bind( '<4>', sub { $self->_lineupdate } );
		$rtext->bind( '<5>', sub { $self->_lineupdate } );
	}
	my @textMethods =
	  qw/insert delete Delete deleteBefore Contents deleteSelected
	  deleteTextTaggedwith deleteToEndofLine FindAndReplaceAll GotoLineNumber
	  Insert InsertKeypress InsertSelection insertTab openLine yview ReplaceSelectionsWith
	  Transpose see/;
	if ( ref($rtext) eq 'TextUnicode' ) {
		push( @textMethods,
			  'Load',     'SaveUTF',  'IncludeFile',
			  'ntinsert', 'ntdelete', 'replacewith' );
	}
	for my $method (@textMethods) {
		no strict 'refs';
		*{$method} = sub {
			my $cw  = shift;
			my @arr = $cw->{'rtext'}->$method(@_);
			$cw->_lineupdate;
			@arr;
		};
	}
	return;
}    # end Populate

# Configure methods
# ------------------------------------------
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

# Public Methods
# ------------------------------------------
sub showlinenum {
	my ($w) = @_;
	return if ( $w->{'linenumshowing'} );
	my $col;
	( $w->{'side'} eq 'right' ) ? ( $col = 2 ) : ( $col = 0 );
	$w->{'ltext'}->grid( -row => 0, -column => $col, -sticky => 'ns' );
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

#Private Methods
# ------------------------------------------
sub _lineupdate {
	my ($w) = @_;
	return
	  unless ( $w->{'ltext'}->ismapped )
	  ;    # Don't bother continuing if line numbers cannot be displayed
	my @xsave = $w->{'rtext'}->xview;
	my $idx1 = $w->{'rtext'}->index('@0,0'); # First visible line in text widget
	$w->{'rtext'}->see($idx1);
	my ( $dummy, $ypix ) = $w->{'rtext'}->dlineinfo($idx1);
	my $theight = $w->{'rtext'}->height;
	my $oldy = my $lastline = -99;    #ensure at least one number gets shown
	$w->{'ltext'}->delete( '1.0', 'end' );
	my @LineNum;
	my $insertidx = $w->{'rtext'}->index('insert');
	my ($insertLine) = split( /\./, $insertidx );
	my $font         = $w->{'ltext'}->cget( -font );
	my $ltextline    = 0;

	while (1) {
		my $idx = $w->{'rtext'}->index( '@0,' . "$ypix" );
		( my $realline ) = split( /\./, $idx );
		my ( $x, $y, $wi, $he ) = $w->{'rtext'}->dlineinfo($idx);
		last unless defined $he;
		last if ( $oldy == $y );    #line is the same as the last one
		$oldy = $y;
		$ypix += $he;
		last
		  if $ypix >= ( $theight - 1 );  #we have reached the end of the display
		last if ( $y == $ypix );
		$ltextline++;

		if ( $realline == $lastline ) {
			push( @LineNum, "\n" );
		} else {
			push( @LineNum, "$realline\n" );
		}
		$lastline = $realline;
	}

	#ensure proper width for large line numbers (over 5 digits)
	my $neededwidth = length($lastline) + 1;
	my $ltextwidth  = $w->{'ltext'}->cget( -width );
	if ( $neededwidth > $ltextwidth ) {
		$w->{'ltext'}->configure( -width => $neededwidth );
	} elsif (    $ltextwidth > $w->{'minwidth'}
			  && $neededwidth <= $w->{'minwidth'} )
	{
		$w->{'ltext'}->configure( -width => $w->{'minwidth'} );
	} elsif (     $neededwidth < $ltextwidth
			  and $neededwidth > $w->{'minwidth'} )
	{
		$w->{'ltext'}->configure( -width => $neededwidth );
	}

	#Finally insert the linenumbers..
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
		$w->{'ltext'}
		  ->tagAdd( 'CURLINE', "$highlightline\.0", "$highlightline\.end" );
	}
	$w->{'ltext'}->tagAdd( 'RIGHT', '1.0', 'end' );
	$w->{'rtext'}->xviewMoveto( $xsave[0] );
	return;
}
1;
