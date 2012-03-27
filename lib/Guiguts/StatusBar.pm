package Guiguts::StatusBar;
use strict;
use warnings;

BEGIN {
	use Exporter();
	our ( @ISA, @EXPORT );
	@ISA = qw(Exporter);
	@EXPORT =
	  qw(&update_indicators &_updatesel &buildstatusbar &selection &gotoline &gotopage);
}

# Routine to update the status bar when something has changed.
#
sub update_indicators {
	my $textwindow = $::textwindow;
	my $top        = $::top;
	my ( $last_line, $last_col ) = split( /\./, $textwindow->index('end') );
	my ( $line,      $column )   = split( /\./, $textwindow->index('insert') );
	$::lglobal{current_line_label}
	  ->configure( -text => "Ln:$line/" . ( $last_line - 1 ) . " Col:$column" )
	  if ( $::lglobal{current_line_label} );
	my $mode             = $textwindow->OverstrikeMode;
	my $overstrke_insert = ' I ';
	if ($mode) {
		$overstrke_insert = ' O ';
	}
	$::lglobal{insert_overstrike_mode_label}
	  ->configure( -text => " $overstrke_insert " )
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
	if ( $textwindow->numberChanges ) {
		$edit_flag = 'edited';
	}

	# window label format: GG-version - [edited] - [file name]
	if ($edit_flag) {
		$top->configure(   -title => $::window_title . " - "
						 . $edit_flag . " - "
						 . $filename );
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
		if (    $::auto_show_images
			 && $pnum )
		{
			if (    ( not defined $::lglobal{pageimageviewed} )
				 or ( $pnum ne "$::lglobal{pageimageviewed}" ) )
			{
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
		update_img_lbl_values($pnum);
		update_proofers_button($pnum);
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
	$widget->bind( '<ButtonRelease-1>',
				   sub { $widget->configure( -relief => 'raised' ) } );
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
			$msg = ' R:'
			  . abs( $erow - $srow + 1 ) . ' C:'
			  . abs( $ecol - $scol ) . ' ';
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

	#FIXME
	no warnings 'uninitialized';
	$::lglobal{selmaxlength} = $msgln if ( $msgln > $::lglobal{selmaxlength} );
	$::lglobal{selectionlabel}
	  ->configure( -text => $msg, -width => $::lglobal{selmaxlength} );
	::update_indicators();
	$textwindow->_lineupdate;
}
## Status Bar
sub buildstatusbar {
	my $textwindow = $::textwindow;
	my $top        = $::top;
	$::lglobal{current_line_label} =
	  $::counter_frame->Label(
							   -text       => 'Ln: 1/1 - Col: 0',
							   -width      => 20,
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
	$::lglobal{selectionlabel} =
	  $::counter_frame->Label(
							   -text       => ' No Selection ',
							   -relief     => 'ridge',
							   -background => 'gray',
	  )->grid( -row => 1, -column => 10, -sticky => 'nw' );
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
				my ( $srow, $scol ) = split /\./,
				  $textwindow->index('selstart');
				my ( $erow, $ecol ) = split /\./, $textwindow->index('selend');
				for ( $srow .. $erow ) {
					$textwindow->tagAdd( 'sel', "$_.$scol", "$_.$ecol" );
				}
			}
		}
	);
	$::lglobal{highlightlabel} =
	  $::counter_frame->Label(
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
				return unless $::scannoslist;
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
			$::lglobal{highlightlabel}
			  ->configure( -background => $::activecolor );
			$::lglobal{highlightlabel}->configure( -relief => 'raised' );
		}
	);
	$::lglobal{highlightlabel}->bind(
		'<Leave>',
		sub {
			$::lglobal{highlightlabel}
			  ->configure( -background => $::lglobal{highlighttempcolor} );
			$::lglobal{highlightlabel}->configure( -relief => 'ridge' );
		}
	);
	$::lglobal{highlightlabel}->bind(
		'<ButtonRelease-1>',
		sub {
			$::lglobal{highlightlabel}->configure( -relief => 'raised' );
		}
	);
	$::lglobal{insert_overstrike_mode_label} =
	  $::counter_frame->Label(
							   -text       => '',
							   -relief     => 'ridge',
							   -background => 'gray',
							   -width      => 2,
	  )->grid( -row => 1, -column => 9, -sticky => 'nw' );
	$::lglobal{insert_overstrike_mode_label}->bind(
		'<1>',
		sub {
			$::lglobal{insert_overstrike_mode_label}
			  ->configure( -relief => 'sunken' );
			if ( $textwindow->OverstrikeMode ) {
				$textwindow->OverstrikeMode(0);
			} else {
				$textwindow->OverstrikeMode(1);
			}
		}
	);
	$::lglobal{ordinallabel} =
	  $::counter_frame->Label(
							   -text       => '',
							   -relief     => 'ridge',
							   -background => 'gray',
							   -anchor     => 'w',
	  )->grid( -row => 1, -column => 11 );
	$::lglobal{ordinallabel}->bind(
		'<1>',
		sub {
			$::lglobal{ordinallabel}->configure( -relief => 'sunken' );
			$::lglobal{longordlabel} = $::lglobal{longordlabel} ? 0 : 1;
			::update_indicators();
		}
	);
	_butbind($_)
	  for (
			$::lglobal{insert_overstrike_mode_label},
			$::lglobal{current_line_label},
			$::lglobal{selectionlabel},
			$::lglobal{ordinallabel}
	  );
	$::lglobal{statushelp} = $top->Balloon( -initwait => 1000 );
	$::lglobal{statushelp}->attach( $::lglobal{current_line_label},
			 -balloonmsg =>
			   "Line number out of total lines\nand column number of cursor." );
	$::lglobal{statushelp}->attach( $::lglobal{insert_overstrike_mode_label},
						  -balloonmsg => 'Typeover Mode. (Insert/Overstrike)' );
	$::lglobal{statushelp}->attach( $::lglobal{ordinallabel},
		-balloonmsg =>
"Decimal & Hexadecimal ordinal of the\ncharacter to the right of the cursor."
	);
	$::lglobal{statushelp}->attach( $::lglobal{highlightlabel},
					-balloonmsg =>
					  "Highlight words from list. Right click to select list" );
	$::lglobal{statushelp}->attach( $::lglobal{selectionlabel},
		-balloonmsg =>
"Start and end points of selection -- Or, total lines.columns of selection"
	);
}

sub update_img_button {
	my $pnum       = shift;
	my $textwindow = $::textwindow;
	unless ( defined( $::lglobal{img_num_label} ) ) {
		$::lglobal{img_num_label} =
		  $::counter_frame->Label(
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
				::viewpagenums();
				::update_indicators();
			}
		);
		_butbind( $::lglobal{img_num_label} );
		$::lglobal{statushelp}->attach( $::lglobal{img_num_label},
						   -balloonmsg => "Image/Page name for current page." );
	}
	return ();
}

sub update_label_button {
	my $textwindow = $::textwindow;
	unless ( $::lglobal{page_label} ) {
		$::lglobal{page_label} =
		  $::counter_frame->Label(
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
		$::lglobal{statushelp}->attach( $::lglobal{page_label},
						-balloonmsg => "Page label assigned to current page." );
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
		my $msg = charnames::viacode($ordinal) || '';
		my $msgln = length(" Dec $ordinal : Hex $hexi : $msg ");
		no warnings 'uninitialized';
		$::lglobal{ordmaxlength} = $msgln
		  if ( $msgln > $::lglobal{ordmaxlength} );
		$::lglobal{ordinallabel}->configure(
								   -text => " Dec $ordinal : Hex $hexi : $msg ",
								   -width   => $::lglobal{ordmaxlength},
								   -justify => 'left'
		);
	} else {
		$::lglobal{ordinallabel}->configure(
										  -text => " Dec $ordinal : Hex $hexi ",
										  -width => 18
		) if ( $::lglobal{ordinallabel} );
	}
}

sub update_prev_img_button {
	my $textwindow = $::textwindow;
	unless ( defined( $::lglobal{previmagebutton} ) ) {
		$::lglobal{previmagebutton} =
		  $::counter_frame->Label(
								   -text       => '<',
								   -width      => 1,
								   -relief     => 'ridge',
								   -background => 'gray',
		  )->grid( -row => 1, -column => 3 );
		$::lglobal{previmagebutton}->bind(
			'<1>',
			sub {
				$::lglobal{previmagebutton}->configure( -relief => 'sunken' );
				$::lglobal{showthispageimage} = 1;
				::viewpagenums() unless $::lglobal{pnumpop};
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
		$::lglobal{pagebutton} =
		  $::counter_frame->Label(
								   -text       => 'See Img',
								   -width      => 7,
								   -relief     => 'ridge',
								   -background => 'gray',
		  )->grid( -row => 1, -column => 4 );
		$::lglobal{pagebutton}->bind(
			'<1>',
			sub {
				$::lglobal{pagebutton}->configure( -relief => 'sunken' );
				my $pagenum = ::get_page_number();
				if ( defined $::lglobal{pnumpop} ) {
					$::lglobal{pagenumentry}->delete( '0', 'end' );
					$::lglobal{pagenumentry}->insert( 'end', "Pg" . $pagenum );
				}
				::openpng( $textwindow, $pagenum );
			}
		);
		$::lglobal{pagebutton}->bind( '<3>', sub { ::setpngspath() } );
		_butbind( $::lglobal{pagebutton} );
		$::lglobal{statushelp}->attach( $::lglobal{pagebutton},
			 -balloonmsg =>
			   "Open Image corresponding to current page in an external viewer."
		);
	}
}

sub update_next_img_button {
	my $textwindow = $::textwindow;
	unless ( defined( $::lglobal{nextimagebutton} ) ) {
		$::lglobal{nextimagebutton} =
		  $::counter_frame->Label(
								   -text       => '>',
								   -width      => 1,
								   -relief     => 'ridge',
								   -background => 'gray',
		  )->grid( -row => 1, -column => 5 );
		$::lglobal{nextimagebutton}->bind(
			'<1>',
			sub {
				$::lglobal{nextimagebutton}->configure( -relief => 'sunken' );
				$::lglobal{showthispageimage} = 1;
				::viewpagenums() unless $::lglobal{pnumpop};
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
		$::lglobal{autoimagebutton} =
		  $::counter_frame->Label(
								   -text       => 'Auto Img',
								   -width      => 9,
								   -relief     => 'ridge',
								   -background => 'gray',
		  )->grid( -row => 1, -column => 6 );
		if ($::auto_show_images) {
			$::lglobal{autoimagebutton}->configure( -text => 'No Img' );
		}
		$::lglobal{autoimagebutton}->bind(
			'<1>',
			sub {
				$::auto_show_images = 1 - $::auto_show_images;
				if ($::auto_show_images) {
					$::lglobal{autoimagebutton}
					  ->configure( -relief => 'sunken' );
					$::lglobal{autoimagebutton}->configure( -text => 'No Img' );
					$::lglobal{statushelp}->attach( $::lglobal{autoimagebutton},
						-balloonmsg =>
"Stop automatically showing the image for the current page."
					);
				} else {
					$::lglobal{autoimagebutton}
					  ->configure( -relief => 'sunken' );
					$::lglobal{autoimagebutton}
					  ->configure( -text => 'Auto Img' );
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
"Automatically show the image for the current page (focus shifts to image window)."
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

#
# New subroutine "update_proofers_button" extracted - Tue Mar 22 00:13:24 2011.
#
sub update_proofers_button {
	my $pnum       = shift;
	my $textwindow = $::textwindow;
	if ( ( scalar %::proofers ) && ( defined( $::lglobal{pagebutton} ) ) ) {
		unless ( defined( $::lglobal{proofbutton} ) ) {
			$::lglobal{proofbutton} =
			  $::counter_frame->Label(
									   -text       => 'See Proofers',
									   -width      => 11,
									   -relief     => 'ridge',
									   -background => 'gray',
			  )->grid( -row => 1, -column => 8 );
			$::lglobal{proofbutton}->bind(
				'<1>',
				sub {
					$::lglobal{proofbutton}->configure( -relief => 'sunken' );
					showproofers();
				}
			);
			$::lglobal{proofbutton}->bind(
				'<3>',
				sub {
					$::lglobal{proofbutton}->configure( -relief => 'sunken' );
					::tglprfbar();
				}
			);
			_butbind( $::lglobal{proofbutton} );
			$::lglobal{statushelp}->attach( $::lglobal{proofbutton},
							  -balloonmsg => "Proofers for the current page." );
		}
		{
			no warnings 'uninitialized';
			my ( $pg, undef ) = each %::proofers;
			for my $round ( 1 .. 8 ) {
				last unless defined $::proofers{$pg}->[$round];
				$::lglobal{numrounds} = $round;
				$::lglobal{proofbar}[$round]->configure(
					 -text => "  Round $round  $::proofers{$pnum}->[$round]  " )
				  if $::lglobal{proofbarvisible};
			}
		}
	}
}
## Make toolbar visible if invisible and vice versa
sub tglprfbar {
	my $textwindow = $::textwindow;
	my $top        = $::top;
	if ( $::lglobal{proofbarvisible} ) {
		for ( @{ $::lglobal{proofbar} } ) {
			$_->gridForget if defined $_;
		}
		$::proofer_frame->packForget;
		my @geom = split /[x+]/, $top->geometry;
		$geom[1] -= $::counter_frame->height;
		$top->geometry("$geom[0]x$geom[1]+$geom[2]+$geom[3]");
		$::lglobal{proofbarvisible} = 0;
	} else {
		my $pnum = $::lglobal{img_num_label}->cget( -text );
		$pnum =~ s/\D+//g;
		$::proofer_frame->pack(
								-before => $::counter_frame,
								-side   => 'bottom',
								-anchor => 'sw',
								-expand => 0
		);
		my @geom = split /[x+]/, $top->geometry;
		$geom[1] += $::counter_frame->height;
		$top->geometry("$geom[0]x$geom[1]+$geom[2]+$geom[3]");
		{
			no warnings 'uninitialized';
			my ( $pg, undef ) = each %::proofers;
			for my $round ( 1 .. 8 ) {
				last unless defined $::proofers{$pg}->[$round];
				$::lglobal{numrounds} = $round;
				$::lglobal{proofbar}[$round] =
				  $::proofer_frame->Label(
										   -text       => '',
										   -relief     => 'ridge',
										   -background => 'gray',
				  )->grid( -row => 1, -column => $round, -sticky => 'nw' );
				_butbind( $::lglobal{proofbar}[$round] );
				$::lglobal{proofbar}[$round]->bind(
					'<1>' => sub {
						$::lglobal{proofbar}[$round]
						  ->configure( -relief => 'sunken' );
						my $proofer =
						  $::lglobal{proofbar}[$round]->cget( -text );
						$proofer =~ s/\s+Round \d\s+|\s+$//g;
						$proofer =~ s/\s/%20/g;
						::prfrmessage($proofer);
					}
				);
			}
		}
		$::lglobal{proofbarvisible} = 1;
	}
	return;
}

sub showproofers {
	my $top = $::top;
	if ( defined( $::lglobal{prooferpop} ) ) {
		$::lglobal{prooferpop}->deiconify;
		$::lglobal{prooferpop}->raise;
		$::lglobal{prooferpop}->focus;
	} else {
		$::lglobal{prooferpop} = $top->Toplevel;
		$::lglobal{prooferpop}->title('Proofers For This File');
		::initialize_popup_with_deletebinding('prooferpop');
		my $bframe = $::lglobal{prooferpop}->Frame->pack;
		$bframe->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				my @ranges      = $::lglobal{prfrrotextbox}->tagRanges('sel');
				my $range_total = @ranges;
				my $proofer     = '';
				if ($range_total) {
					$proofer =
					  $::lglobal{prfrrotextbox}->get( $ranges[0], $ranges[1] );
					$proofer =~ s/^\s+//;
					$proofer =~ s/\s\s.*//s;
					$proofer =~ s/\s/%20/g;
				}
				::prfrmessage($proofer);
			},
			-text  => 'Send Message',
			-width => 12
		)->grid( -row => 1, -column => 1, -padx => 3, -pady => 3 );
		$bframe->Button(
						 -activebackground => $::activecolor,
						 -command          => \&prfrbypage,
						 -text             => 'Page',
						 -width            => 12
		)->grid( -row => 2, -column => 1, -padx => 3, -pady => 3 );
		$bframe->Button(
						 -activebackground => $::activecolor,
						 -command          => \&prfrbyname,
						 -text             => 'Name',
						 -width            => 12
		)->grid( -row => 1, -column => 2, -padx => 3, -pady => 3 );
		$bframe->Button(
						 -activebackground => $::activecolor,
						 -command          => sub { prfrby(0) },
						 -text             => 'Total',
						 -width            => 12
		)->grid( -row => 2, -column => 2, -padx => 3, -pady => 3 );
		for my $round ( 1 .. $::lglobal{numrounds} ) {
			$bframe->Button(
							 -activebackground => $::activecolor,
							 -command => [ sub { prfrby( $_[0] ) }, $round ],
							 -text    => "Round $round",
							 -width   => 12
			  )->grid(
					   -row => ( ( $round + 1 ) % 2 ) + 1,
					   -column => int( ( $round + 5 ) / 2 ),
					   -padx   => 3,
					   -pady   => 3
			  );
		}
		my $frame =
		  $::lglobal{prooferpop}->Frame->pack(
											   -anchor => 'nw',
											   -expand => 'yes',
											   -fill   => 'both'
		  );
		$::lglobal{prfrrotextbox} =
		  $frame->Scrolled(
							'ROText',
							-scrollbars => 'se',
							-background => $::bkgcolor,
							-font       => '{Courier} 10',
							-width      => 80,
							-height     => 40,
							-wrap       => 'none',
		  )->pack( -anchor => 'nw', -expand => 'yes', -fill => 'both' );
		delete $::proofers{''};
		::drag( $::lglobal{prfrrotextbox} );
		prfrbypage();
	}
}

sub prfrmessage {
	my $proofer = shift;
	if ( $proofer eq '' ) {
		::runner( $::globalbrowserstart, $::no_proofer_url );
	} else {
		::runner( $::globalbrowserstart, "$::yes_proofer_url$proofer" );
	}
}

sub prfrhdr {
	my ($max) = @_;
	$::lglobal{prfrrotextbox}->insert(
									   'end',
									   sprintf( "%*s     ",
												( -$max ), '   Name' )
	);
	for ( 1 .. $::lglobal{numrounds} ) {
		$::lglobal{prfrrotextbox}
		  ->insert( 'end', sprintf( " %-8s", "Round $_" ) );
	}
	$::lglobal{prfrrotextbox}->insert( 'end', sprintf( " %-8s\n", 'Total' ) );
}

sub prfrbypage {
	my @max = split //, ( '8' x ( $::lglobal{numrounds} + 1 ) );
	for my $page ( keys %::proofers ) {
		for my $round ( 1 .. $::lglobal{numrounds} ) {
			my $name = $::proofers{$page}->[$round];
			next unless defined $name;
			$max[$round] = length $name if length $name > $max[$round];
		}
	}
	$::lglobal{prfrrotextbox}->delete( '1.0', 'end' );
	$::lglobal{prfrrotextbox}->insert( 'end', sprintf( "%-8s", 'Page' ) );
	for my $round ( 1 .. $::lglobal{numrounds} ) {
		$::lglobal{prfrrotextbox}->insert( 'end',
					 sprintf( " %*s", ( -$max[$round] - 2 ), "Round $round" ) );
	}
	$::lglobal{prfrrotextbox}->insert( 'end', "\n" );
	delete $::proofers{''};
	for my $page ( sort keys %::proofers ) {
		$::lglobal{prfrrotextbox}->insert( 'end', sprintf( "%-8s", $page ) );
		for my $round ( 1 .. $::lglobal{numrounds} ) {
			$::lglobal{prfrrotextbox}->insert(
							 'end',
							 sprintf( " %*s",
									  ( -$max[$round] - 2 ),
									  $::proofers{$page}->[$round] || '<none>' )
			);
		}
		$::lglobal{prfrrotextbox}->insert( 'end', "\n" );
	}
}

sub prfrbyname {
	my ( $page, $prfr, %proofersort );
	my $max = 8;
	for my $page ( keys %::proofers ) {
		for ( 1 .. $::lglobal{numrounds} ) {
			$max = length $::proofers{$page}->[$_]
			  if ( $::proofers{$page}->[$_]
				   and length $::proofers{$page}->[$_] > $max );
		}
	}
	$::lglobal{prfrrotextbox}->delete( '1.0', 'end' );
	foreach my $page ( keys %::proofers ) {
		for ( 1 .. $::lglobal{numrounds} ) {
			$proofersort{ $::proofers{$page}->[$_] }[$_]++
			  if $::proofers{$page}->[$_];
			$proofersort{ $::proofers{$page}->[$_] }[0]++
			  if $::proofers{$page}->[$_];
		}
	}
	prfrhdr($max);
	delete $proofersort{''};
	foreach my $prfr ( sort { deaccent( lc($a) ) cmp deaccent( lc($b) ) }
					   ( keys %proofersort ) )
	{
		for ( 1 .. $::lglobal{numrounds} ) {
			$proofersort{$prfr}[$_] = "0" unless $proofersort{$prfr}[$_];
		}
		$::lglobal{prfrrotextbox}
		  ->insert( 'end', sprintf( "%*s", ( -$max - 2 ), $prfr ) );
		for ( 1 .. $::lglobal{numrounds} ) {
			$::lglobal{prfrrotextbox}
			  ->insert( 'end', sprintf( " %8s", $proofersort{$prfr}[$_] ) );
		}
		$::lglobal{prfrrotextbox}
		  ->insert( 'end', sprintf( " %8s\n", $proofersort{$prfr}[0] ) );
	}
}

sub prfrby {
	my $which = shift;
	my ( $page, $prfr, %proofersort, %ptemp );
	my $max = 8;
	for my $page ( keys %::proofers ) {
		for ( 1 .. $::lglobal{numrounds} ) {
			$max = length $::proofers{$page}->[$_]
			  if ( $::proofers{$page}->[$_]
				   and length $::proofers{$page}->[$_] > $max );
		}
	}
	$::lglobal{prfrrotextbox}->delete( '1.0', 'end' );
	foreach my $page ( keys %::proofers ) {
		for ( 1 .. $::lglobal{numrounds} ) {
			$proofersort{ $::proofers{$page}->[$_] }[$_]++
			  if $::proofers{$page}->[$_];
			$proofersort{ $::proofers{$page}->[$_] }[0]++
			  if $::proofers{$page}->[$_];
		}
	}
	foreach my $prfr ( keys(%proofersort) ) {
		$ptemp{$prfr} = ( $proofersort{$prfr}[$which] || '0' );
	}
	delete $ptemp{''};
	prfrhdr($max);
	foreach my $prfr (
		sort {
			$ptemp{$b} <=> $ptemp{$a}
			  || ( ::deaccent( lc($a) ) cmp ::deaccent( lc($b) ) )
		} keys %ptemp
	  )
	{
		$::lglobal{prfrrotextbox}
		  ->insert( 'end', sprintf( "%*s", ( -$max - 2 ), $prfr ) );
		for ( 1 .. $::lglobal{numrounds} ) {
			$::lglobal{prfrrotextbox}->insert( 'end',
							sprintf( " %8s", $proofersort{$prfr}[$_] || '0' ) );
		}
		$::lglobal{prfrrotextbox}
		  ->insert( 'end', sprintf( " %8s\n", $proofersort{$prfr}[0] ) );
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
		::initialize_popup_without_deletebinding('selectionpop');
		$::lglobal{selectionpop}->resizable( 'no', 'no' );
		my $frame =
		  $::lglobal{selectionpop}
		  ->Frame->pack( -fill => 'x', -padx => 5, -pady => 5 );
		$frame->Label( -text => 'Start Line.Col' )
		  ->grid( -row => 1, -column => 1 );
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
		$frame->Label( -text => 'End Line.Col' )
		  ->grid( -row => 2, -column => 1 );
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
		my $frame1 =
		  $::lglobal{selectionpop}
		  ->Frame->pack( -fill => 'x', -padx => 5, -pady => 5 );
		my $button = $frame1->Button(
			-text    => 'OK',
			-width   => 8,
			-command => sub {
				return
				  unless (    ( $start =~ m{^\d+\.\d+$} )
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
			-buttons => [qw[Ok Cancel]],
			-title   => 'Go To Line Number',
			-popover => $top,
			-command => sub {
				no warnings 'uninitialized';
				if ( $_[0] eq 'Ok' ) {
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
					$textwindow->markSet( 'insert',
										  "$::lglobal{line_number}.0" );
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
		$::lglobal{gotolinepop}->Icon( -image => $::icon );
		$::lglobal{gotolinepop}->resizable( 'no', 'no' );
		my $frame = $::lglobal{gotolinepop}->Frame->pack( -fill => 'x' );
		$frame->Label( -text => 'Enter Line number: ' )
		  ->pack( -side => 'left' );
		my $entry = $frame->Entry(
								   -background   => $::bkgcolor,
								   -width        => 25,
								   -textvariable => \$::lglobal{line_number},
		)->pack( -side => 'left', -fill => 'x' );
		$::lglobal{gotolinepop}->Advertise( entry => $entry );
		$::lglobal{gotolinepop}->Popup;
		$::lglobal{gotolinepop}->Subwidget('entry')->focus;
		$::lglobal{gotolinepop}->Subwidget('entry')->selectionRange( 0, 'end' );
		$::lglobal{gotolinepop}->Wait;
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
			-buttons => [qw[Ok Cancel]],
			-title   => 'Goto Page Number',
			-popover => $top,
			-command => sub {
				if ( ( defined $_[0] ) and ( $_[0] eq 'Ok' ) ) {
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
					unless (
							exists $::pagenumbers{ 'Pg' . $::lglobal{lastpage} }
							&& defined $::pagenumbers{ 'Pg'
								  . $::lglobal{lastpage} } )
					{
						delete $::pagenumbers{ 'Pg' . $::lglobal{lastpage} };
						$::lglobal{gotopagpop}->bell;
						$::lglobal{gotopagpop}->destroy;
						undef $::lglobal{gotopagpop};
						return;
					}
					my $index =
					  $textwindow->index( 'Pg' . $::lglobal{lastpage} );
					$textwindow->markSet( 'insert', "$index +1l linestart" );
					$textwindow->see('insert');
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
		$::lglobal{gotopagpop}->resizable( 'no', 'no' );
		$::lglobal{gotopagpop}->Icon( -image => $::icon );
		my $frame = $::lglobal{gotopagpop}->Frame->pack( -fill => 'x' );
		$frame->Label( -text => 'Enter image number: ' )
		  ->pack( -side => 'left' );
		my $entry = $frame->Entry(
								   -background   => $::bkgcolor,
								   -width        => 25,
								   -textvariable => \$::lglobal{lastpage}
		)->pack( -side => 'left', -fill => 'x' );
		$::lglobal{gotopagpop}->Advertise( entry => $entry );
		$::lglobal{gotopagpop}->Popup;
		$::lglobal{gotopagpop}->Subwidget('entry')->focus;
		$::lglobal{gotopagpop}->Subwidget('entry')->selectionRange( 0, 'end' );
		$::lglobal{gotopagpop}->Wait;
	}
}
1;
