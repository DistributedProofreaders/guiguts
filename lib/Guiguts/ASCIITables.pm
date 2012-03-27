package Guiguts::ASCIITables;
use strict;
use warnings;

BEGIN {
	use Exporter();
	our ( @ISA, @EXPORT );
	@ISA    = qw(Exporter);
	@EXPORT = qw(&tablefx);
}
## ASCII Table Special Effects
sub tablefx {
	::viewpagenums() if ( $::lglobal{seepagenums} );
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
		::initialize_popup_without_deletebinding('tblfxpop');
		my $f0 =
		  $::lglobal{tblfxpop}->Frame->pack( -side => 'top', -anchor => 'n' );
		my %tb_buttons = (
			'Table Select'   => sub { tblselect() },
			'Table Deselect' => sub {
				$textwindow->tagRemove( 'table',   '1.0', 'end' );
				$textwindow->tagRemove( 'linesel', '1.0', 'end' );
				$textwindow->markUnset( 'tblstart', 'tblend' );
				undef $::lglobal{selectedline};
			},
			'Insert Vertical Line' => sub {
				insertline('i');
			},
			'Add Vertical Line' => sub {
				insertline('a');
			},
			'Space Out Table' => sub {
				tblspace();
			},
			'Auto Columns' => sub {
				tblautoc();
			},
			'Compress Table' => sub {
				tblcompress();
			},
			'Select Prev Line' => sub {
				tlineselect('p');
			},
			'Select Next Line' => sub {
				tlineselect('n');
			},
			'Line Deselect' => sub {
				$textwindow->tagRemove( 'linesel', '1.0', 'end' );
				undef $::lglobal{selectedline};
			},
			'Delete Sel. Line' => sub {
				my @ranges      = $textwindow->tagRanges('linesel');
				my $range_total = @ranges;
				$::operationinterrupt = 0;
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
			},
			'Remove Sel. Line' => sub {
				tlineremove();
			},
		);
		my ( $inc, $row, $col ) = ( 0, 0, 0 );
		for ( keys %tb_buttons ) {
			$row = int( $inc / 4 );
			$col = $inc % 4;
			$f0->Button(
						 -activebackground => $::activecolor,
						 -command          => $tb_buttons{$_},
						 -text             => $_,
						 -width            => 16
			  )->grid(
					   -row    => $row,
					   -column => $col,
					   -padx   => 1,
					   -pady   => 2
			  );
			++$inc;
		}
		my $f1 =
		  $::lglobal{tblfxpop}->Frame->pack( -side => 'top', -anchor => 'n' );
		$f1->Label( -text => 'Justify', )
		  ->grid( -row => 1, -column => 0, -padx => 1, -pady => 2 );
		my $rb1 = $f1->Radiobutton(
									-text        => 'L',
									-variable    => \$::lglobal{tblcoljustify},
									-selectcolor => $::lglobal{checkcolor},
									-value       => 'l',
		)->grid( -row => 1, -column => 1, -padx => 1, -pady => 2 );
		my $rb2 = $f1->Radiobutton(
									-text        => 'C',
									-variable    => \$::lglobal{tblcoljustify},
									-selectcolor => $::lglobal{checkcolor},
									-value       => 'c',
		)->grid( -row => 1, -column => 2, -padx => 1, -pady => 2 );
		my $rb3 = $f1->Radiobutton(
									-text        => 'R',
									-variable    => \$::lglobal{tblcoljustify},
									-selectcolor => $::lglobal{checkcolor},
									-value       => 'r',
		)->grid( -row => 1, -column => 3, -padx => 1, -pady => 2 );
		$f1->Checkbutton(
			-variable    => \$::lglobal{tblrwcol},
			-selectcolor => $::lglobal{checkcolor},
			-text        => 'Rewrap Cols',
			-command     => sub {
				if ( $::lglobal{tblrwcol} ) {
					$rb1->configure( -state => 'active' );
					$rb2->configure( -state => 'active' );
					$rb3->configure( -state => 'active' );
				} else {
					$rb1->configure( -state => 'disabled' );
					$rb2->configure( -state => 'disabled' );
					$rb3->configure( -state => 'disabled' );
				}
			},
		)->grid( -row => 1, -column => 4, -padx => 1, -pady => 2 );
		$::lglobal{colwidthlbl} =
		  $f1->Label(
					  -text  => "Width $::lglobal{columnspaces}",
					  -width => 8,
		  )->grid( -row => 1, -column => 5, -padx => 1, -pady => 2 );
		$f1->Button(
					 -activebackground => $::activecolor,
					 -command          => sub { coladjust(-1) },
					 -text             => 'Move Left',
					 -width            => 10
		)->grid( -row => 1, -column => 6, -padx => 1, -pady => 2 );
		$f1->Button(
					 -activebackground => $::activecolor,
					 -command          => sub { coladjust(1) },
					 -text             => 'Move Right',
					 -width            => 10
		)->grid( -row => 1, -column => 7, -padx => 1, -pady => 2 );
		my $f3 =
		  $::lglobal{tblfxpop}->Frame->pack( -side => 'top', -anchor => 'n' );
		$f3->Label( -text => 'Table Right Column', )
		  ->grid( -row => 1, -column => 0, -padx => 1, -pady => 2 );
		$f3->Entry(
					-width        => 6,
					-background   => $::bkgcolor,
					-textvariable => \$::lglobal{stepmaxwidth},
		)->grid( -row => 1, -column => 1, -padx => 1, -pady => 2 );
		$f3->Button(
					 -activebackground => $::activecolor,
					 -command          => sub { grid2step() },
					 -text             => 'Convert Grid to Step',
					 -width            => 16
		)->grid( -row => 1, -column => 3, -padx => 1, -pady => 2 );
		my $f4 =
		  $::lglobal{tblfxpop}->Frame->pack( -side => 'top', -anchor => 'n' );
		$f4->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				$textwindow->undo;
				$textwindow->tagRemove( 'highlight', '1.0', 'end' );
			},
			-text  => 'Undo',
			-width => 10
		)->grid( -row => 1, -column => 1, -padx => 1, -pady => 2 );
		$f4->Button(
					 -activebackground => $::activecolor,
					 -command          => sub { $textwindow->redo },
					 -text             => 'Redo',
					 -width            => 10
		)->grid( -row => 1, -column => 2, -padx => 1, -pady => 2 );
		$f4->Button(
					 -activebackground => $::activecolor,
					 -command          => sub { step2grid() },
					 -text             => 'Convert Step to Grid',
					 -width            => 16
		)->grid( -row => 1, -column => 3, -padx => 1, -pady => 2 );
		$::lglobal{tblfxpop}->bind( '<Control-Left>',  sub { coladjust(-1) } );
		$::lglobal{tblfxpop}->bind( '<Control-Right>', sub { coladjust(1) } );
		$::lglobal{tblfxpop}->bind( '<Left>',  sub { tlineselect('p') } );
		$::lglobal{tblfxpop}->bind( '<Right>', sub { tlineselect('n') } );
		$::lglobal{tblfxpop}->bind(
			'<Control-z>',
			sub {
				$textwindow->undo;
				$textwindow->tagRemove( 'highlight', '1.0', 'end' );
			}
		);
		$::lglobal{tblfxpop}->bind( '<Delete>', sub { tlineremove() } );
		tblselect();
	}
	$::lglobal{tblfxpop}->protocol(
		'WM_DELETE_WINDOW' => sub {
			$textwindow->tagRemove( 'table',   '1.0', 'end' );
			$textwindow->tagRemove( 'linesel', '1.0', 'end' );
			$textwindow->markUnset( 'tblstart', 'tblend' );
			$::lglobal{tblfxpop}->destroy;
			undef $::lglobal{tblfxpop};
		}
	);
}

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
		$textwindow->markSet( 'tblstart', $start );
		if ( $textwindow->index('tblstart') !~ /\.0/ ) {
			$textwindow->markSet( 'tblstart', $start . ' linestart' );
		}
		$textwindow->markGravity( 'tblstart', 'left' );
		$textwindow->markSet( 'tblend', $end );
		$textwindow->tagAdd( 'table', 'tblstart', 'tblend' );
	}
	$textwindow->tagRemove( 'sel',     '1.0', 'end' );
	$textwindow->tagRemove( 'linesel', '1.0', 'end' );
	undef $::lglobal{selectedline};
}

sub tlineremove {
	my $textwindow  = $::textwindow;
	my @ranges      = $textwindow->tagRanges('linesel');
	my $range_total = @ranges;
	$::operationinterrupt = 0;
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

sub tlineselect {
	my $textwindow = $::textwindow;
	return unless $textwindow->index('tblstart');
	my $op         = shift;
	my @lineranges = $textwindow->tagRanges('linesel');
	$textwindow->tagRemove( 'linesel', '1.0', 'end' );
	my @ranges      = $textwindow->tagRanges('sel');
	my $range_total = @ranges;
	$::operationinterrupt = 0;

	if ( $range_total == 0 ) {
		my $nextcolumn;
		if ( $op and ( $op eq 'p' ) ) {
			$textwindow->markSet( 'insert', $lineranges[0] ) if @lineranges;
			$nextcolumn =
			  $textwindow->search(
								   '-backward', '-exact',
								   '--',        '|',
								   'insert',    'insert linestart'
			  );
		} else {
			$textwindow->markSet( 'insert', $lineranges[1] ) if @lineranges;
			$nextcolumn =
			  $textwindow->search(
								   '-exact', '--',
								   '|',      'insert',
								   'insert lineend'
			  );
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

sub colcalc {
	my $srow       = shift;
	my $textwindow = $::textwindow;
	my $widthline =
	  $textwindow->get( "$srow.0", "$srow.$::lglobal{selectedline}" );
	if ( $widthline =~ /([^|]*)$/ ) {
		$::lglobal{columnspaces} = length($1);
	} else {
		$::lglobal{columnspaces} = 0;
	}
	$::lglobal{colwidthlbl}
	  ->configure( -text => "Width $::lglobal{columnspaces}" );
}

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
		  split( /\./, ( $textwindow->index('tblend') ) );
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

sub insertline {
	my $op         = shift;
	my $textwindow = $::textwindow;
	my $insert     = $textwindow->index('insert');
	my ( $row, $col ) = split( /\./, $insert );
	my @ranges      = $textwindow->tagRanges('table');
	my $range_total = @ranges;
	$::operationinterrupt = 0;
	if ( $range_total == 0 ) {
		$textwindow->bell;
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

sub coladjust {
	my $dir        = shift;
	my $textwindow = $::textwindow;
	return 0 unless defined $::lglobal{selectedline} or tlineselect();
	if ( $::lglobal{tblrwcol} ) {
		$dir--;
		my @tbl;
		my $selection = $textwindow->get( 'tblstart', 'tblend' );
		my $templine =
		  $textwindow->get( 'tblstart linestart', 'tblstart lineend' );
		my @col = ();
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
		my @table = split( /\n/, $selection );
		my $row = 0;
		my $blankline;
		for (@table) {

			#print "Dollar:".$_."\n";
			#print "colindex:".$colindex."\n";
			my $temp = $col[ ($colindex) ];

			#print "colcolindex:"."$temp"."\n";
			$temp = $col[ ( $colindex - 1 ) ];

			#print "colcolindex-1:"."$temp"."\n";
			my $cell = substr(
							   $_,
							   ( $col[ ( $colindex - 1 ) ] ),
							   (
								  $col[$colindex] -
									$col[ ( $colindex - 1 ) ] - 1
							   ),
							   ''
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
		for my $cellcnt (@cells) {
			$templine = '';
			for ( 1 .. $cellcnt ) {
				last unless @tbl;
				$templine .= shift @tbl;
			}
			my $wrapped =
			  ::wrapper( 0, 0,
						 ( $col[$colindex] - $col[ ( $colindex - 1 ) ] + $dir ),
						 $templine, $::rwhyphenspace );
			push @tblwr, $wrapped;
		}
		my $rowcount = 0;
		$cellheight = 0;
		my $width = $col[$colindex] - $col[ ( $colindex - 1 ) ] + $dir;
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
					my $pad  = $width - length($_);
					my $padl = int( $pad / 2 );
					my $padr = int( $pad / 2 + .5 );
					if ( $::lglobal{tblcoljustify} eq 'l' ) {
						$_ = $_ . ' ' x ($pad);
					} elsif ( $::lglobal{tblcoljustify} eq 'c' ) {
						$_ = ' ' x ($padl) . $_ . ' ' x ($padr);
					} elsif ( $::lglobal{tblcoljustify} eq 'r' ) {
						$_ = ' ' x ($pad) . $_;
					}
					my $templine = $blankline;
					substr( $templine, $col[ $colindex - 1 ], 0, $_ );
					push @temptable, "$templine\n";
				}
				my $templine = $blankline;
				substr( $templine, $col[ $colindex - 1 ], 0, ' ' x $width );
				push @temptable, "$templine\n";
			}
			if ( $diff > 0 ) {
				for (@temparray) {
					my $pad  = $width - length($_);
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
		$textwindow->delete( 'tblstart', 'tblend' );
		for ( reverse @table ) {
			$textwindow->insert( 'tblstart', $_ );
		}
		$dir++;
	} else {
		my ( $srow, $scol ) = split( /\./, $textwindow->index('tblstart') );
		my ( $erow, $ecol ) = split( /\./, $textwindow->index('tblend') );
		$textwindow->addGlobStart;
		if ( $dir > 0 ) {
			for ( $srow .. $erow ) {
				$textwindow->insert( "$_.$::lglobal{selectedline}", ' ' );
			}
		} else {
			for ( $srow .. $erow ) {
				return 0
				  if ( $textwindow->get("$_.@{[$::lglobal{selectedline}-1]}") ne
					   ' ' );
			}
			for ( $srow .. $erow ) {
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
	$::lglobal{stepmaxwidth} = 70
	  if (    ( $::lglobal{stepmaxwidth} =~ /\D/ )
		   || ( $::lglobal{stepmaxwidth} < 15 ) );
	my $selection = $textwindow->get( 'tblstart', 'tblend' );
	$selection =~ s/\n +/\n/g;
	@trows = split( /^[ |]+$/ms, $selection );
	for my $trow (@trows) {
		@tlines = split( /\n/, $trow );
		my @temparray;
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
		for ( 0 .. $cols ) {
			my $wrapped;
			$wrapped = ::wrapper(
								  ( $cell * 5 ), ( $cell * 5 ),
								  $::lglobal{stepmaxwidth}, $tbl[$row][$_],
								  $::rwhyphenspace
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
	$textwindow->addGlobStart;
	$textwindow->delete( 'tblstart', 'tblend' );
	for ( reverse @table ) {
		$textwindow->insert( 'tblstart', "$_\n" );
	}
	$textwindow->tagAdd( 'table', 'tblstart', 'tblend' );
	undef $::lglobal{selectedline};
	$textwindow->addGlobEnd;
}

sub step2grid {
	my $textwindow = $::textwindow;
	my ( @table, @tbl, @tcols );
	my $row = 0;
	my $col;
	return 0 unless ( $textwindow->markExists('tblstart') );
	my $selection = $textwindow->get( 'tblstart', 'tblend' );
	@tcols = split( /\n[ |\n]+\n/, $selection );
	for my $tcol (@tcols) {
		$col = 0;
		while ($tcol) {
			if ( $tcol =~ s/^(\S[^\n|]*)// ) {
				$tbl[$row][$col] .= $1 . ' ';
				$tcol =~ s/^[ |]+//;
				$tcol =~ s/^\n//;
			} else {
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
	for ( reverse @table ) {
		$textwindow->insert( 'tblstart', "$_\n" );
	}
	$textwindow->tagAdd( 'table', 'tblstart', 'tblend' );
	$textwindow->addGlobEnd;
}

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
			$cols[$word] = $size unless defined $cols[$word];
			$cols[$word] = $size if ( $size > $cols[$word] );
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
	$textwindow->delete( 'tblstart', 'tblend' );
	for ( reverse @table ) {
		$textwindow->insert( 'tblstart', "$_\n" );
	}
	$textwindow->tagAdd( 'table', 'tblstart', 'tblend' );
	$textwindow->addGlobEnd;
}
1;
