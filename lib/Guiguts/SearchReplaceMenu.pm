package Guiguts::SearchReplaceMenu;
use strict;
use warnings;

BEGIN {
	use Exporter();
	our ( @ISA, @EXPORT );
	@ISA = qw(Exporter);
	@EXPORT =
	  qw(&add_search_history &searchtext &search_history &reg_check &getnextscanno &updatesearchlabels
	  &isvalid &swapterms &findascanno &reghint &replaceeval &replace &opstop &replaceall &killstoppop
	  &searchfromstartifnew &searchoptset &searchpopup &stealthscanno &find_proofer_comment
	  &find_asterisks &find_transliterations &nextblock &orphanedbrackets &orphanedmarkup &searchsize
	  &loadscannos &replace_incr_counter);
}

sub add_search_history {
	if ($::scannosearch) {
		return;    # do not add to search history during a scannos check
	}
	my ( $term, $history_array_ref) = @_;
	my @temparray = @$history_array_ref;
	@$history_array_ref = ();
	push @$history_array_ref, $term;
	for (@temparray) {
		next if $_ eq $term;
		push @$history_array_ref, $_;
		last if @$history_array_ref >= $::history_size;
	}
}

sub searchtext {
	my ($searchterm) = @_;
	my $textwindow   = $::textwindow;
	my $top          = $::top;
	::viewpagenums() if ( $::lglobal{seepagenums} );

#print $::sopt[0],$::sopt[1],$::sopt[2],$::sopt[3],$::sopt[4].":sopt\n";
# $::sopt[0] --> 0 = pattern search                       1 = whole word search
# $::sopt[1] --> 0 = case sensitive                     1 = case insensitive search
# $::sopt[2] --> 0 = search forwards    \                  1 = search backwards
# $::sopt[3] --> 0 = normal search term           1 = regex search term - 3 and 0 are mutually exclusive
# $::sopt[4] --> 0 = search from last index       1 = Start from beginning
#	$::searchstartindex--where the last search for this $searchterm ended
#   replaced with the insertion point if the user has clicked someplace else
#print $::sopt[4]."from beginning\n";
	$searchterm = '' unless defined $searchterm;
	if ( length($searchterm) ) {    #and not ($searchterm =~ /\W/)
		::add_search_history( $searchterm, \@::search_history);
	}
	$::lglobal{lastsearchterm} = 'stupid variable needs to be initialized'
	  unless length( $::lglobal{lastsearchterm} );
	$textwindow->tagRemove( 'highlight', '1.0', 'end' ) if $::searchstartindex;
	my ( $start, $end );
	my $foundone    = 1;
	my @ranges      = $textwindow->tagRanges('sel');
	my $range_total = @ranges;
	$::searchstartindex = $textwindow->index('insert')
	  unless $::searchstartindex;
	my $searchstartingpoint = $textwindow->index('insert');

	# this is a search within a selection
	if ( $range_total == 0 && $::lglobal{selectionsearch} ) {
		$start = $textwindow->index('insert');
		$end   = $::lglobal{selectionsearch};

		# this is a search through the end of the document
	} elsif ( $range_total == 0 && !$::lglobal{selectionsearch} ) {
		$start = $textwindow->index('insert');
		$end   = 'end';
		$end   = '1.0' if ( $::sopt[2] );
	} else {
		$end                        = pop(@ranges);
		$start                      = pop(@ranges);
		$::lglobal{selectionsearch} = $end;
	}
	if ( $::sopt[4] ) {
		if ( $::sopt[2] ) {

			# search backwards and Start From Beginning so start from the end
			$start = 'end';
			$end   = '1.0';
		} else {

			# search forwards and Start From Beginning so start from the end
			$start = '1.0';
			$end   = 'end';
		}
		$::lglobal{searchop4}->deselect if ( defined $::lglobal{searchpop} );
		$::lglobal{lastsearchterm} = "resetresetreset";
	}

	#print "start:$start\n";
	if ($start) {    # but start is always defined?
		if ( $::sopt[2] ) {    # if backwards
			$::searchstartindex = $start;
		} else {
			$::searchendindex =
			  "$start+1c";     #forwards. #unless ( $start eq '1.0' )
			    #print $::searchstartindex.":".$::searchendindex."4\n";
		}

		# forward search begin +1c or the next search would find the same match
	}
	{    # Turn off warnings temporarily since $searchterm is undefined on first
		    # search
		no warnings;
		unless ( length($searchterm) ) {
			$searchterm = $::lglobal{searchentry}->get( '1.0', '1.end' );
			::add_search_history( $searchterm, \@::search_history);
		}
	}    # warnings back on; keep this bracket
	return ('') unless length($searchterm);
	#::operationadd( "Search for " . $searchterm );
	if ( $::sopt[3] ) {
		unless ( ::isvalid($searchterm) ) {
			badreg();
			return;
		}
	}

	# if this is a new searchterm
	unless ( $searchterm eq $::lglobal{lastsearchterm} ) {
		if ( $::sopt[2] ) {
			( $range_total == 0 )
			  ? ( $::searchstartindex = 'end' )
			  : ( $::searchstartindex = $end );
		}
		$::lglobal{lastsearchterm} = $searchterm
		  unless ( ( $searchterm =~ m/\\n/ ) && ( $::sopt[3] ) );
		clearmarks() if ( ( $searchterm =~ m/\\n/ ) && ( $::sopt[3] ) );
	}
	$textwindow->tagRemove( 'sel', '1.0', 'end' );
	my $length = '0';
	my ($tempindex);

	# Search across line boundaries with regexp "this\nand"
	if ( ( $searchterm =~ m/\\n/ ) && ( $::sopt[3] ) ) {
		unless ( $searchterm eq $::lglobal{lastsearchterm} ) {
			{
				$top->Busy;

				# have to search on the whole file
				my $wholefile = $textwindow->get( '1.0', $end );

				# search is case sensitive if $::sopt[1] is set
				if ( $::sopt[1] ) {
					while ( $wholefile =~ m/$searchterm/smgi ) {
						push @{ $::lglobal{nlmatches} },
						  [ $-[0], ( $+[0] - $-[0] ) ];
					}
				} else {
					while ( $wholefile =~ m/$searchterm/smg ) {
						push @{ $::lglobal{nlmatches} },
						  [ $-[0], ( $+[0] - $-[0] ) ];
					}
				}
				$top->Unbusy;
			}
			my $matchidx = 0;
			my $lineidx  = 1;
			my $matchacc = 0;
			foreach my $match ( @{ $::lglobal{nlmatches} } ) {
				while (1) {
					my $linelen =
					  length( $textwindow->get( "$lineidx.0", "$lineidx.end" ) )
					  + 1;
					last if ( ( $matchacc + $linelen ) > $match->[0] );
					$matchacc += $linelen;
					$lineidx++;
				}
				$matchidx++;
				my $offset = $match->[0] - $matchacc;
				$textwindow->markSet( "nls${matchidx}q" . $match->[1],
					"$lineidx.$offset" );
			}
			$::lglobal{lastsearchterm} = $searchterm;
		}
		my $mark;
		if ( $::sopt[2] ) {
			$mark = getmark($::searchstartindex);
		} else {
			$mark = getmark($::searchendindex);
		}
		while ($mark) {
			if ( $mark =~ /nls\d+q(\d+)/ ) {
				$length = $1;

				#print $length."1\n";
				$::searchstartindex = $textwindow->index($mark);
				last;
			} else {
				$mark = getmark($mark) if $mark;
				next;
			}
		}
		$::searchstartindex = 0 unless $mark;
		$::lglobal{lastsearchterm} = 'reset' unless $mark;
	} else {    # not a search across line boundaries
		my $exactsearch = $searchterm;
		$exactsearch = ::escape_regexmetacharacters($exactsearch);
		$searchterm  = '(?<!\p{Alnum})' . $exactsearch . '(?!\p{Alnum})'
		  if $::sopt[0];
		my ( $direction, $searchstart, $mode );
		if   ( $::sopt[2] ) { $searchstart = $::searchstartindex }
		else                { $searchstart = $::searchendindex }
		if   ( $::sopt[2] ) { $direction = '-backwards' }
		else                { $direction = '-forwards' }
		if   ( $::sopt[0] or $::sopt[3] ) { $mode = '-regexp' }
		else                              { $mode = '-exact' }

		if ($::debug) {
			print "$mode:$direction:$length:$searchterm:$searchstart:$end\n";
		}

		#print $length."2\n";
		#finally we actually do some searching
		if ( $::sopt[1] ) {
			$::searchstartindex = $textwindow->search(
				$mode, $direction, '-nocase',
				'-count' => \$length,
				'--', $searchterm, $searchstart, $end
			);

			#print $length."3\n";
		} else {
			$::searchstartindex = $textwindow->search(
				$mode, $direction,
				'-count' => \$length,
				'--', $searchterm, $searchstart, $end
			);

			#print $length."4\n";
		}
	}
	if ($::searchstartindex) {
		$tempindex = $::searchstartindex;

		#print $::searchstartindex.":".$::searchendindex."7\n";
		my ( $row, $col ) = split /\./, $tempindex;

		#print "$row:$col:$length 5\n";
		$col += $length;
		$::searchendindex = "$row.$col" if $length;

		#print $::searchstartindex.":".$::searchendindex."3\n";
		$::searchendindex =
		  $textwindow->index("$::searchstartindex +${length}c")
		  if ( $searchterm =~ m/\\n/ );

		#print $::searchstartindex.":".$::searchendindex."2\n";
		$::searchendindex = $textwindow->index("$::searchstartindex +1c")
		  unless $length;

		#print $::searchstartindex.":".$::searchendindex."1\n";
		$textwindow->markSet( 'insert', $::searchstartindex )
		  if $::searchstartindex;    # position the cursor at the index
		    #print $::searchstartindex.":".$::searchendindex."\n";
		$textwindow->tagAdd( 'highlight', $::searchstartindex,
			$::searchendindex )
		  if $::searchstartindex;    # highlight the text
		$textwindow->yviewMoveto(1);
		$textwindow->see($::searchstartindex)
		  if ( $::searchendindex && $::sopt[2] )
		  ;    # scroll text box, if necessary, to make found text visible
		$textwindow->see($::searchendindex)
		  if ( $::searchendindex && !$::sopt[2] );
		$::searchendindex = $::searchstartindex unless $length;

		#print $::searchstartindex.":".$::searchendindex.":10\n";
	}
	unless ($::searchstartindex) {

		#print $::searchstartindex.":".$::searchendindex.":11\n";
		$foundone = 0;
		unless ( $::lglobal{selectionsearch} ) { $start = '1.0'; $end = 'end' }
		if ( $::sopt[2] ) {
			$::searchstartindex = $end;

			#print $::searchstartindex.":".$::searchendindex.":12\n";
			$textwindow->markSet( 'insert', $::searchstartindex );
			$textwindow->see($::searchendindex);
		} else {
			$::searchendindex = $start;

			#print $::searchstartindex.":".$::searchendindex.":13\n";
			$textwindow->markSet( 'insert', $start );
			$textwindow->see($start);
		}
		$::lglobal{selectionsearch} = 0;
		unless ( $::lglobal{regaa} ) {
			$textwindow->bell unless $::nobell;
			$::lglobal{searchbutton}->flash if defined $::lglobal{searchpop};
			$::lglobal{searchbutton}->flash if defined $::lglobal{searchpop};

			# If nothing found, return cursor to starting point
			if ($::failedsearch) {
				$::searchendindex = $searchstartingpoint;
				$textwindow->markSet( 'insert', $searchstartingpoint );
				$textwindow->see($searchstartingpoint);
			}
		}
	}
	::updatesearchlabels();
	::update_indicators();
	return $foundone;    # return index of where found text started
}

sub search_history {
	my ( $widget, $history_array_ref ) = @_;
	my $menu = $widget->Menu( -title => 'History', -tearoff => 0 );
	$menu->command(
		-label   => 'Clear History',
		-command => sub { @$history_array_ref = (); ::savesettings(); },
	);
	$menu->separator;
	for my $item (@$history_array_ref) {
		$menu->command(
			-label   => $item,
			-command => [ sub { load_hist_term( $widget, $_[0] ) }, $item ],
		);
	}
	my $x = $widget->rootx;
	my $y = $widget->rooty + $widget->height;
	$menu->post( $x, $y );
}

sub load_hist_term {
	my ( $widget, $term ) = @_;
	$widget->delete( '1.0', 'end' );
	$widget->insert( 'end', $term );
}

sub reg_check {
	$::lglobal{searchentry}->tagConfigure( 'reg', -foreground => 'black' );
	$::lglobal{searchentry}->tagRemove( 'reg', '1.0', 'end' );
	return unless $::sopt[3];
	$::lglobal{searchentry}->tagAdd( 'reg', '1.0', 'end' );
	my $term = $::lglobal{searchentry}->get( '1.0', 'end' );
	return if ( $term eq '^' or $term eq '$' );
	return if ::isvalid($term);
	$::lglobal{searchentry}->tagConfigure( 'reg', -foreground => 'red' );
	return;
}

sub regedit {
	my $top    = $::top;
	my $editor = $top->DialogBox(
		-title   => 'Regex editor',
		-buttons => [ 'Save', 'Cancel' ]
	);
	my $regsearchlabel = $editor->add( 'Label', -text => 'Search Term' )->pack;
	$::lglobal{regsearch} = $editor->add(
		'Text',
		-background => $::bkgcolor,
		-width      => 40,
		-height     => 1,
	)->pack;
	my $regreplacelabel =
	  $editor->add( 'Label', -text => 'Replacement Term' )->pack;
	$::lglobal{regreplace} = $editor->add(
		'Text',
		-background => $::bkgcolor,
		-width      => 40,
		-height     => 1,
	)->pack;
	my $reghintlabel = $editor->add( 'Label', -text => 'Hint Text' )->pack;
	$::lglobal{reghinted} = $editor->add(
		'Text',
		-background => $::bkgcolor,
		-width      => 40,
		-height     => 8,
		-wrap       => 'word',
	)->pack;
	my $buttonframe = $editor->add('Frame')->pack;
	$buttonframe->Button(
		-activebackground => $::activecolor,
		-text             => '<--',
		-command          => sub {
			$::lglobal{scannosindex}-- if $::lglobal{scannosindex};
			regload();
		},
	)->pack( -side => 'left', -pady => 5, -padx => 2, -anchor => 'w' );
	$buttonframe->Button(
		-activebackground => $::activecolor,
		-text             => '-->',
		-command          => sub {
			$::lglobal{scannosindex}++
			  if $::lglobal{scannosarray}[ $::lglobal{scannosindex} ];
			regload();
		},
	)->pack( -side => 'left', -pady => 5, -padx => 2, -anchor => 'w' );
	$buttonframe->Button(
		-activebackground => $::activecolor,
		-text             => 'Add',
		-command          => \&regadd,
	)->pack( -side => 'left', -pady => 5, -padx => 2, -anchor => 'w' );
	$buttonframe->Button(
		-activebackground => $::activecolor,
		-text             => 'Del',
		-command          => \&regdel,
	)->pack( -side => 'left', -pady => 5, -padx => 2, -anchor => 'w' );
	$::lglobal{regsearch}
	  ->insert( 'end', ( $::lglobal{searchentry}->get( '1.0', '1.end' ) ) )
	  if $::lglobal{searchentry}->get( '1.0', '1.end' );
	$::lglobal{regreplace}
	  ->insert( 'end', ( $::lglobal{replaceentry}->get( '1.0', '1.end' ) ) )
	  if $::lglobal{replaceentry}->get( '1.0', '1.end' );
	$::lglobal{reghinted}->insert( 'end',
		( $::reghints{ $::lglobal{searchentry}->get( '1.0', '1.end' ) } ) )
	  if $::reghints{ $::lglobal{searchentry}->get( '1.0', '1.end' ) };
	my $button = $editor->Show;
	if ( $button =~ /save/i ) {
		open my $reg, ">", "$::lglobal{scannosfilename}";
		print $reg "\%::scannoslist = (\n";
		foreach my $word ( sort ( keys %::scannoslist ) ) {
			my $srch = $word;
			$srch =~ s/'/\\'/;
			my $repl = $::scannoslist{$word};
			$repl =~ s/'/\\'/;
			print $reg "'$srch' => '$repl',\n";
		}
		print $reg ");\n\n";
		print $reg <<'EOF';
# For a hint, use the regex expression EXACTLY as it appears in the %::scannoslist hash
# but replace the replacement term (heh) with the hint text. Note: if a single quote
# appears anywhere in the hint text, you'll need to escape it with a backslash. I.E. isn't
# I could have made this more compact by converting the scannoslist hash into a two dimensional
# hash, but would have sacrificed backward compatibility.

EOF
		print $reg '%::reghints = (' . "\n";
		foreach my $word ( sort ( keys %::reghints ) ) {
			my $srch = $word;
			$srch =~ s/'/\\'/;
			my $repl = $::reghints{$word};
			$repl =~ s/([\\'])/\\$1/;
			print $reg "'$srch' => '$repl'\n";
		}
		print $reg ");\n\n";
		close $reg;
	}
}

sub regload {
	my $word = '';
	$word = $::lglobal{scannosarray}[ $::lglobal{scannosindex} ];
	$::lglobal{regsearch}->delete( '1.0', 'end' );
	$::lglobal{regreplace}->delete( '1.0', 'end' );
	$::lglobal{reghinted}->delete( '1.0', 'end' );
	$::lglobal{regsearch}->insert( 'end', $word ) if defined $word;
	$::lglobal{regreplace}->insert( 'end', $::scannoslist{$word} )
	  if defined $word;
	$::lglobal{reghinted}->insert( 'end', $::reghints{$word} ) if defined $word;
}

sub regadd {
	my $st = $::lglobal{regsearch}->get( '1.0', '1.end' );
	unless ( isvalid($st) ) {
		badreg();
		return;
	}
	my $rt = $::lglobal{regsearch}->get( '1.0', '1.end' );
	my $rh = $::lglobal{reghinted}->get( '1.0', 'end' );
	$rh =~ s/(?!<\\)'/\\'/;
	$rh =~ s/\n/ /;
	$rh =~ s/  / /;
	$rh =~ s/\s+$//;
	$::reghints{$st} = $rh;

	unless ( defined $::scannoslist{$st} ) {
		$::scannoslist{$st} = $rt;
		$::lglobal{scannosindex} = 0;
		@{ $::lglobal{scannosarray} } = ();
		foreach ( sort ( keys %::scannoslist ) ) {
			push @{ $::lglobal{scannosarray} }, $_;
		}
		foreach ( @{ $::lglobal{scannosarray} } ) {
			$::lglobal{scannosindex}++ unless ( $_ eq $st );
			next unless ( $_ eq $st );
			last;
		}
	} else {
		$::scannoslist{$st} = $rt;
	}
	regload();
}

sub regdel {
	my $word = '';
	my $st = $::lglobal{regsearch}->get( '1.0', '1.end' );
	delete $::reghints{$st};
	delete $::scannoslist{$st};
	$::lglobal{scannosindex}--;
	@{ $::lglobal{scannosarray} } = ();
	foreach my $word ( sort ( keys %::scannoslist ) ) {
		push @{ $::lglobal{scannosarray} }, $word;
	}
	regload();
}

sub reghint {
	my $message = 'No hints for this entry.';
	my $reg = $::lglobal{searchentry}->get( '1.0', '1.end' );
	if ( $::reghints{$reg} ) { $message = $::reghints{$reg} }
	if ( defined( $::lglobal{hintpop} ) ) {
		$::lglobal{hintpop}->deiconify;
		$::lglobal{hintpop}->raise;
		$::lglobal{hintpop}->focus;
		$::lglobal{hintmessage}->delete( '1.0', 'end' );
		$::lglobal{hintmessage}->insert( 'end', $message );
	} else {
		$::lglobal{hintpop} = $::lglobal{searchpop}->Toplevel;
		::initialize_popup_with_deletebinding('hintpop');
		$::lglobal{hintpop}->title('Search Term Hint');
		my $frame = $::lglobal{hintpop}->Frame->pack(
			-anchor => 'nw',
			-expand => 'yes',
			-fill   => 'both'
		);
		$::lglobal{hintmessage} = $frame->ROText(
			-width      => 40,
			-height     => 6,
			-background => $::bkgcolor,
			-wrap       => 'word',
		  )->pack(
			-anchor => 'nw',
			-expand => 'yes',
			-fill   => 'both',
			-padx   => 4,
			-pady   => 4
		  );
		$::lglobal{hintmessage}->insert( 'end', $message );
	}
}

sub getnextscanno {
	$::scannosearch = 1;
	::findascanno();
	unless ( searchtext() ) {
		if ( $::lglobal{regaa} ) {
			while (1) {
				last
				  if ( $::lglobal{scannosindex}++ >=
					$#{ $::lglobal{scannosarray} } );
				::findascanno();
				last if searchtext();
			}
		}
	}
}

sub swapterms {
	my $tempholder = $::lglobal{replaceentry}->get( '1.0', '1.end' );
	$::lglobal{replaceentry}->delete( '1.0', 'end' );
	$::lglobal{replaceentry}
	  ->insert( 'end', $::lglobal{searchentry}->get( '1.0', '1.end' ) );
	$::lglobal{searchentry}->delete( '1.0', 'end' );
	$::lglobal{searchentry}->insert( 'end', $tempholder );
	searchtext();
}

sub isvalid {
	my $term = shift;
	return eval { '' =~ m/$term/; 1 } || 0;
}

sub badreg {
	my $warning = $::top->Dialog(
		-text =>
"Invalid Regex search term.\nDo you have mismatched\nbrackets or parenthesis?",
		-title   => 'Invalid Regex',
		-bitmap  => 'warning',
		-buttons => ['Ok'],
	);
	$warning->Icon( -image => $::icon );
	$warning->Show;
}

sub clearmarks {
	@{ $::lglobal{nlmatches} } = ();
	my ( $mark, $mindex );
	$mark = $::textwindow->markNext($::searchendindex);
	while ($mark) {
		if ( $mark =~ /nls\d+q(\d+)/ ) {
			$mindex = $::textwindow->index($mark);
			$::textwindow->markUnset($mark);
			$mark = $mindex;
		}
		$mark = $::textwindow->markNext($mark) if $mark;
	}
}

sub getmark {
	my $start = shift;
	if ( $::sopt[2] ) {    # search reverse
		return $::textwindow->markPrevious($start);
	} else {               # search forward
		return $::textwindow->markNext($start);
	}
}

sub updatesearchlabels {
	if ( $::lglobal{seenwords} && $::lglobal{searchpop} ) {
		my $replaceterm = $::lglobal{replaceentry}->get( '1.0', '1.end' );
		my $searchterm1 = $::lglobal{searchentry}->get( '1.0', '1.end' );
		if ( ( $::lglobal{seenwords}->{$searchterm1} ) && ( $::sopt[0] ) ) {
			$::lglobal{searchnumlabel}->configure(
				-text => "Found $::lglobal{seenwords}->{$searchterm1} times." );
		} elsif ( ( $searchterm1 eq '' ) || ( !$::sopt[0] ) ) {
			$::lglobal{searchnumlabel}->configure( -text => '' );
		} else {
			$::lglobal{searchnumlabel}->configure( -text => 'Not Found.' );
		}
	}
}

# calls the replacewith command after calling replaceeval
# to allow arbitrary perl code to be included in the replace entry
sub replace {
	::viewpagenums() if ( $::lglobal{seepagenums} );
	my $replaceterm = shift;
	$replaceterm = '' unless length $replaceterm;
	return unless $::searchstartindex;
	my $searchterm = $::lglobal{searchentry}->get( '1.0', '1.end' );
	$replaceterm = replaceeval( $searchterm, $replaceterm ) if ( $::sopt[3] );
	if ($::searchstartindex) {
		$::textwindow->replacewith( $::searchstartindex, $::searchendindex,
			$replaceterm );
	}
	return 1;
}

sub findascanno {
	my $textwindow = $::textwindow;
	$::searchendindex = '1.0';
	my $word = '';
	$word = $::lglobal{scannosarray}[ $::lglobal{scannosindex} ];
	$::lglobal{searchentry}->delete( '1.0', 'end' );
	$::lglobal{replaceentry}->delete( '1.0', 'end' );
	$textwindow->bell unless ( $word || $::nobell || $::lglobal{regaa} );
	$::lglobal{searchbutton}->flash unless ( $word || $::lglobal{regaa} );
	$::lglobal{regtracker}
	  ->configure( -text => ( $::lglobal{scannosindex} + 1 ) . '/'
		  . scalar( @{ $::lglobal{scannosarray} } ) );
	$::lglobal{hintmessage}->delete( '1.0', 'end' )
	  if ( defined( $::lglobal{hintpop} ) );
	return 0 unless $word;
	$::lglobal{searchentry}->insert( 'end', $word );
	$::lglobal{replaceentry}->insert( 'end', ( $::scannoslist{$word} ) );
	$::sopt[2]
	  ? $textwindow->markSet( 'insert', 'end' )
	  : $textwindow->markSet( 'insert', '1.0' );
	reghint() if ( defined( $::lglobal{hintpop} ) );
	$textwindow->update;
	return 1;
}

# allow the replacment term to contain arbitrary perl code
# called only from replace()
sub replaceeval {
	my $textwindow = $::textwindow;
	my $top        = $::top;
	my ( $searchterm, $replaceterm ) = @_;
	my @replarray = ();
	my ( $replaceseg, $seg1, $seg2, $replbuild );
	my ( $m1, $m2, $m3, $m4, $m5, $m6, $m7, $m8 );
	my (
		$cfound,  $lfound,  $ufound, $tfound,
		$gafound, $gbfound, $gfound, $afound
	);

	#check for control codes before the $1 codes for text found are inserted
	if ( $replaceterm =~ /\\C/ )  { $cfound  = 1; }
	if ( $replaceterm =~ /\\L/ )  { $lfound  = 1; }
	if ( $replaceterm =~ /\\U/ )  { $ufound  = 1; }
	if ( $replaceterm =~ /\\T/ )  { $tfound  = 1; }
	if ( $replaceterm =~ /\\GA/ ) { $gafound = 1; }
	if ( $replaceterm =~ /\\GB/ ) { $gbfound = 1; }
	if ( $replaceterm =~ /\\G/ )  { $gfound  = 1; }
	if ( $replaceterm =~ /\\A/ )  { $afound  = 1; }
	my $found = $textwindow->get( $::searchstartindex, $::searchendindex );
	$searchterm =~ s/\Q(?<=\E.*?\)//;
	$searchterm =~ s/\Q(?=\E.*?\)//;
	$found      =~ m/$searchterm/m;
	$m1 = $1;
	$m2 = $2;
	$m3 = $3;
	$m4 = $4;
	$m5 = $5;
	$m6 = $6;
	$m7 = $7;
	$m8 = $8;
	$replaceterm =~ s/(?<!\\)\$1/$m1/g if defined $m1;
	$replaceterm =~ s/(?<!\\)\$2/$m2/g if defined $m2;
	$replaceterm =~ s/(?<!\\)\$3/$m3/g if defined $m3;
	$replaceterm =~ s/(?<!\\)\$4/$m4/g if defined $m4;
	$replaceterm =~ s/(?<!\\)\$5/$m5/g if defined $m5;
	$replaceterm =~ s/(?<!\\)\$6/$m6/g if defined $m6;
	$replaceterm =~ s/(?<!\\)\$7/$m7/g if defined $m7;
	$replaceterm =~ s/(?<!\\)\$8/$m8/g if defined $m8;
	$replaceterm =~ s/\\\$/\$/g;

# For an explanation see
# http://www.pgdp.net/wiki/PPTools/Guiguts/Searching#Replacing_by_Modifying_Quoted_Text
# \C indicates perl code to be run
	if ($cfound) {
		if ( $::lglobal{codewarn} ) {
			my $message = <<'END';
WARNING!! The replacement term will execute arbitrary perl code.
If you do not want to, or are not sure of what you are doing, cancel the operation.
It is unlikely that there is a problem. However, it is possible (and not terribly difficult)
to construct an expression that would delete files, execute arbitrary malicious code,
reformat hard drives, etc.
Do you want to proceed?
END
			my $dialog = $top->Dialog(
				-text    => $message,
				-bitmap  => 'warning',
				-title   => 'WARNING! Code in term.',
				-buttons => [ 'OK', 'Warnings Off', 'Cancel' ],
			);
			my $answer = $dialog->Show;
			$::lglobal{codewarn} = 0 if ( $answer eq 'Warnings Off' );
			return $replaceterm
			  unless ( ( $answer eq 'OK' )
				|| ( $answer eq 'Warnings Off' ) );
		}
		$replbuild = '';
		if ( $replaceterm =~ s/^\\C// ) {
			if ( $replaceterm =~ s/\\C// ) {
				@replarray = split /\\C/, $replaceterm;
			} else {
				push @replarray, $replaceterm;
			}
		} else {
			@replarray = split /\\C/, $replaceterm;
			$replbuild = shift @replarray;
		}
		while ( $replaceseg = shift @replarray ) {
			$seg1 = $seg2 = '';
			( $seg1, $seg2 ) = split /\\E/, $replaceseg, 2;
			$replbuild .= eval $seg1;
			$replbuild .= $seg2 if $seg2;
		}
		$replaceterm = $replbuild;
		$replbuild   = '';
	}

	# \Ltest\L is converted to lower case
	if ($lfound) {
		if ( $replaceterm =~ s/^\\L// ) {
			if ( $replaceterm =~ s/\\L// ) {
				@replarray = split /\\L/, $replaceterm;
			} else {
				push @replarray, $replaceterm;
			}
		} else {
			@replarray = split /\\L/, $replaceterm;
			$replbuild = shift @replarray;
		}
		while ( $replaceseg = shift @replarray ) {
			$seg1 = $seg2 = '';
			( $seg1, $seg2 ) = split /\\E/, $replaceseg, 2;
			$replbuild .= lc($seg1);
			$replbuild .= $seg2 if $seg2;
		}
		$replaceterm = $replbuild;
		$replbuild   = '';
	}

	# \Utest\U is converted to lower case
	if ($ufound) {
		if ( $replaceterm =~ s/^\\U// ) {
			if ( $replaceterm =~ s/\\U// ) {
				@replarray = split /\\U/, $replaceterm;
			} else {
				push @replarray, $replaceterm;
			}
		} else {
			@replarray = split /\\U/, $replaceterm;
			$replbuild = shift @replarray;
		}
		while ( $replaceseg = shift @replarray ) {
			$seg1 = $seg2 = '';
			( $seg1, $seg2 ) = split /\\E/, $replaceseg, 2;
			$replbuild .= uc($seg1);
			$replbuild .= $seg2 if $seg2;
		}
		$replaceterm = $replbuild;
		$replbuild   = '';
	}

	# \Ttest\T is converted to title case
	if ($tfound) {
		if ( $replaceterm =~ s/^\\T// ) {
			if ( $replaceterm =~ s/\\T// ) {
				@replarray = split /\\T/, $replaceterm;
			} else {
				push @replarray, $replaceterm;
			}
		} else {
			@replarray = split /\\T/, $replaceterm;
			$replbuild = shift @replarray;
		}
		while ( $replaceseg = shift @replarray ) {
			$seg1 = $seg2 = '';
			( $seg1, $seg2 ) = split /\\E/, $replaceseg, 2;
			$seg1 = lc($seg1);
			$seg1 =~ s/(^\W*\w)/\U$1\E/;
			$seg1 =~ s/([\s\n]+\W*\w)/\U$1\E/g;
			$replbuild .= $seg1;
			$replbuild .= $seg2 if $seg2;
		}
		$replaceterm = $replbuild;
		$replbuild   = '';
	}
	$replaceterm =~ s/\\n/\n/g;
	$replaceterm =~ s/\\t/\t/g;

	# \GA runs betaascii
	if ($gafound) {
		if ( $replaceterm =~ s/^\\GA// ) {
			if ( $replaceterm =~ s/\\GA// ) {
				@replarray = split /\\GA/, $replaceterm;
			} else {
				push @replarray, $replaceterm;
			}
		} else {
			@replarray = split /\\GA/, $replaceterm;
			$replbuild = shift @replarray;
		}
		while ( $replaceseg = shift @replarray ) {
			$seg1 = $seg2 = '';
			( $seg1, $seg2 ) = split /\\E/, $replaceseg, 2;
			$replbuild .= betaascii($seg1);
			$replbuild .= $seg2 if $seg2;
		}
		$replaceterm = $replbuild;
		$replbuild   = '';
	}

	# \GB runs betagreek
	if ($gbfound) {
		if ( $replaceterm =~ s/^\\GB// ) {
			if ( $replaceterm =~ s/\\GB// ) {
				@replarray = split /\\GB/, $replaceterm;
			} else {
				push @replarray, $replaceterm;
			}
		} else {
			@replarray = split /\\GB/, $replaceterm;
			$replbuild = shift @replarray;
		}
		while ( $replaceseg = shift @replarray ) {
			$seg1 = $seg2 = '';
			( $seg1, $seg2 ) = split /\\E/, $replaceseg, 2;
			$replbuild .= betagreek( 'beta', $seg1 );
			$replbuild .= $seg2 if $seg2;
		}
		$replaceterm = $replbuild;
		$replbuild   = '';
	}

	# \G runs betagreek unicode
	if ($gfound) {
		if ( $replaceterm =~ s/^\\G// ) {
			if ( $replaceterm =~ s/\\G// ) {
				@replarray = split /\\G/, $replaceterm;
			} else {
				push @replarray, $replaceterm;
			}
		} else {
			@replarray = split /\\G/, $replaceterm;
			$replbuild = shift @replarray;
		}
		while ( $replaceseg = shift @replarray ) {
			$seg1 = $seg2 = '';
			( $seg1, $seg2 ) = split /\\E/, $replaceseg, 2;
			$replbuild .= betagreek( 'unicode', $seg1 );
			$replbuild .= $seg2 if $seg2;
		}
		$replaceterm = $replbuild;
		$replbuild   = '';
	}

	# \A converts to anchor
	if ($afound) {
		if ( $replaceterm =~ s/^\\A// ) {
			if ( $replaceterm =~ s/\\A// ) {
				@replarray = split /\\A/, $replaceterm;
			} else {
				push @replarray, $replaceterm;
			}
		} else {
			@replarray = split /\\A/, $replaceterm;
			$replbuild = shift @replarray;
		}
		while ( $replaceseg = shift @replarray ) {
			$seg1 = $seg2 = '';
			( $seg1, $seg2 ) = split /\\E/, $replaceseg, 2;
			my $linkname;
			$linkname = ::makeanchor( ::deaccentdisplay($seg1) );
			$seg1     = "<a id=\"$linkname\"></a>";
			$replbuild .= $seg1;
			$replbuild .= $seg2 if $seg2;
		}
		$replaceterm = $replbuild;
	}
	return $replaceterm;
}

sub opstop {
	if ( defined( $::lglobal{stoppop} ) ) {
		$::lglobal{stoppop}->deiconify;
		$::lglobal{stoppop}->raise;
		$::lglobal{stoppop}->focus;
	} else {
		$::lglobal{stoppop} = $::top->Toplevel;
		$::lglobal{stoppop}->title('Interrupt');
		::initialize_popup_with_deletebinding('stoppop');
		my $frame      = $::lglobal{stoppop}->Frame->pack;
		my $stopbutton = $frame->Button(
			-activebackground => $::activecolor,
			-command          => sub { $::operationinterrupt = 1 },
			-text             => 'Interrupt Operation',
			-width            => 16
		)->grid( -row => 1, -column => 1, -padx => 10, -pady => 10 );
	}
}

sub killstoppop {
	if ( $::lglobal{stoppop} ) {
		$::lglobal{stoppop}->destroy;
		undef $::lglobal{stoppop};
	}
	;    #destroy interrupt popup
}

sub replaceall {
	my $replacement = shift;
	$replacement = '' unless $replacement;
	my $textwindow = $::textwindow;
	my $top        = $::top;

	# Check if replaceall applies only to a selection
	my @ranges = $textwindow->tagRanges('sel');
	if (@ranges) {
		$::lglobal{lastsearchterm} =
		  $::lglobal{replaceentry}->get( '1.0', '1.end' );
		$::searchstartindex = pop @ranges;
		$::searchendindex   = pop @ranges;
	} else {
		my $searchterm = $::lglobal{searchentry}->get( '1.0', '1.end' );
		$::lglobal{lastsearchterm} = '';

		# if not a search across line boundary
		# and not a search within a selection do a speedy FindAndReplaceAll
		unless ( ( $::sopt[3] ) or ((isvalid($searchterm)) && ( $replacement =~ $searchterm) ) )
		{    #( $searchterm =~ m/\\n/ ) &&
			my $exactsearch = $searchterm;

			# escape metacharacters for whole word matching
			$exactsearch = ::escape_regexmetacharacters($exactsearch)
			  ;    # this is a whole word search
			$searchterm = '(?<!\p{Alnum})' . $exactsearch . '(?!\p{Alnum})'
			  if $::sopt[0];
			my ( $searchstart, $mode );
			if   ( $::sopt[0] or $::sopt[3] ) { $mode = '-regexp' }
			else                              { $mode = '-exact' }
			::working("Replace All");
			if ( $::sopt[1] ) {
				$textwindow->FindAndReplaceAll( $mode, '-nocase', $searchterm,
					$replacement );
			} else {
				$textwindow->FindAndReplaceAll( $mode, '-case', $searchterm,
					$replacement );
			}
			::working();
			return;
		}
	}

	#print "repl:$replacement:ranges:@ranges:\n";
	$textwindow->focus;
	::opstop();
	while ( searchtext() )
	{    # keep calling search() and replace() until you return undef
		last unless replace($replacement);
		last if $::operationinterrupt;
		$textwindow->update;
	}
	$::operationinterrupt = 0;
	$::lglobal{stoppop}->destroy;
	undef $::lglobal{stoppop};
}

# Reset search from start of doc if new search term
sub searchfromstartifnew {
	my $new_term = shift;
	if ( $new_term ne $::lglobal{lastsearchterm} ) {
		searchoptset(qw/x x x x 1/);
	}
}

sub searchoptset {
	my @opt       = @_;
	my $opt_count = @opt;

# $::sopt[0] --> 0 = pattern search               1 = whole word search
# $::sopt[1] --> 0 = case sensitive             1 = case insensitive search
# $::sopt[2] --> 0 = search forwards              1 = search backwards
# $::sopt[3] --> 0 = normal search term   1 = regex search term - 3 and 0 are mutually exclusive
# $::sopt[4] --> 1 = start search at beginning
	for ( 0 .. $opt_count - 1 ) {
		if ( defined( $::lglobal{searchpop} ) ) {
			if ( $opt[$_] !~ /[a-zA-Z]/ ) {
				$opt[$_]
				  ? $::lglobal{"searchop$_"}->select
				  : $::lglobal{"searchop$_"}->deselect;
			}
		} else {
			if ( $opt[$_] !~ /[a-zA-Z]/ ) { $::sopt[$_] = $opt[$_] }
		}
	}

	#print $::sopt[0],$::sopt[1],$::sopt[2],$::sopt[3],$::sopt[4].":sopt set\n";
}
### Search
sub searchpopup {
	my $textwindow = $::textwindow;
	my $top        = $::top;
	::viewpagenums() if ( $::lglobal{seepagenums} );
	::operationadd('Stealth Scannos') if $::lglobal{doscannos};
	my $aacheck;
	my $searchterm = '';
	my @ranges     = $textwindow->tagRanges('sel');
	$searchterm = $textwindow->get( $ranges[0], $ranges[1] ) if @ranges;

	if ( defined( $::lglobal{searchpop} ) ) {
		$::lglobal{searchpop}->deiconify;
		$::lglobal{searchpop}->raise;
		$::lglobal{searchpop}->focus;
		$::lglobal{searchentry}->focus;
	} else {
		$::lglobal{searchpop} = $top->Toplevel;
		$::lglobal{searchpop}->title('Search & Replace');
		$::lglobal{searchpop}->minsize( 460, 127 );
		my $sf1 =
		  $::lglobal{searchpop}->Frame->pack( -side => 'top', -anchor => 'n' );
		my $searchlabel =
		  $sf1->Label( -text => 'Search Text', )
		  ->pack( -side => 'left', -anchor => 'n', -padx => 80 );
		$::lglobal{searchnumlabel} = $sf1->Label(
			-text  => '',
			-width => 20,
		)->pack( -side => 'right', -anchor => 'e', -padx => 1 );
		my $sf11 = $::lglobal{searchpop}->Frame->pack(
			-side   => 'top',
			-anchor => 'w',
			-padx   => 3,
			-expand => 'y',
			-fill   => 'x'
		);
		$sf11->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				$textwindow->undo;
				$textwindow->tagRemove( 'highlight', '1.0', 'end' );
			},
			-text  => 'Undo',
			-width => 6
		)->pack( -side => 'right', -anchor => 'w' );
		$::lglobal{searchbutton} = $sf11->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				add_search_history(
					$::lglobal{searchentry}->get( '1.0', '1.end' ),
					\@::search_history);
				searchtext('');
			},
			-text  => 'Search',
			-width => 6
		  )->pack(
			-side   => 'right',
			-pady   => 1,
			-padx   => 2,
			-anchor => 'w'
		  );
		$::lglobal{searchentry} = $sf11->Text(
			-background => $::bkgcolor,
			-width      => 60,
			-height     => 1,
		  )->pack(
			-side   => 'right',
			-anchor => 'w',
			-expand => 'y',
			-fill   => 'x'
		  );
		$sf11->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				search_history( $::lglobal{searchentry}, \@::search_history );
			},
			-image  => $::lglobal{hist_img},
			-width  => 9,
			-height => 15,
		)->pack( -side => 'right', -anchor => 'w' );
		$::lglobal{regrepeat} =
		  $::lglobal{searchentry}->repeat( 500, \&reg_check );
		my $sf2 =
		  $::lglobal{searchpop}->Frame->pack( -side => 'top', -anchor => 'w' );
		$::lglobal{searchop1} = $sf2->Checkbutton(
			-variable    => \$::sopt[1],
			-selectcolor => $::lglobal{checkcolor},
			-text        => 'Case Insensitive'
		)->pack( -side => 'left', -anchor => 'n', -pady => 1 );
		$::lglobal{searchop0} = $sf2->Checkbutton(
			-variable    => \$::sopt[0],
			-command     => [ \&searchoptset, 'x', 'x', 'x', 0 ],
			-selectcolor => $::lglobal{checkcolor},
			-text        => 'Whole Word'
		)->pack( -side => 'left', -anchor => 'n', -pady => 1 );
		$::lglobal{searchop3} = $sf2->Checkbutton(
			-variable    => \$::sopt[3],
			-command     => [ \&searchoptset, 0, 'x', 'x', 'x' ],
			-selectcolor => $::lglobal{checkcolor},
			-text        => 'Regex'
		)->pack( -side => 'left', -anchor => 'n', -pady => 1 );
		$::lglobal{searchop2} = $sf2->Checkbutton(
			-variable    => \$::sopt[2],
			-selectcolor => $::lglobal{checkcolor},
			-text        => 'Reverse'
		)->pack( -side => 'left', -anchor => 'n', -pady => 1 );
		$::lglobal{searchop4} = $sf2->Checkbutton(
			-variable    => \$::sopt[4],
			-selectcolor => $::lglobal{checkcolor},
			-text        => 'Start at Beginning'
		)->pack( -side => 'left', -anchor => 'n', -pady => 1 );
		$::lglobal{searchop5} = $sf2->Checkbutton(
			-variable    => \$::auto_show_images,
			-selectcolor => $::lglobal{checkcolor},
			-text        => 'Show Images'
		)->pack( -side => 'left', -anchor => 'n', -pady => 1 );
		my $sf5;
		my @multisearch;
		my $sf10 = $::lglobal{searchpop}->Frame->pack(
			-side   => 'top',
			-anchor => 'n',
			-expand => '1',
			-fill   => 'x'
		);
		my $replacelabel =
		  $sf10->Label( -text => "Replacement Text\t\t", )
		  ->grid( -row => 1, -column => 1 );
		$sf10->Label( -text => 'Terms - ' )->grid( -row => 1, -column => 2 );
		$sf10->Radiobutton(
			-text     => 'single',
			-variable => \$::multiterm,
			-value    => 0,
			-command  => sub {
				for ( @multisearch ) {
					$_->packForget;
				}
			},
		)->grid( -row => 1, -column => 3 );
		$sf10->Radiobutton(
			-text     => 'multi',
			-variable => \$::multiterm,
			-value    => 1,
			-command  => sub {
				for ( @multisearch ) {
					#print "$::multiterm:single\n";
					if ( defined $sf5 ) {
						$_->pack(
							-before => $sf5,
							-side   => 'top',
							-anchor => 'w',
							-padx   => 3,
							-expand => 'y',
							-fill   => 'x'
						);
					} else {
						$_->pack(
							-side   => 'top',
							-anchor => 'w',
							-padx   => 3,
							-expand => 'y',
							-fill   => 'x'
						);
					}
				}
			},
		)->grid( -row => 1, -column => 4 );
		my $sf12 = $::lglobal{searchpop}->Frame->pack(
			-side   => 'top',
			-anchor => 'w',
			-padx   => 3,
			-expand => 'y',
			-fill   => 'x'
		);
		$sf12->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				my $temp = $::lglobal{replaceentry}->get( '1.0', '1.end' );
				replaceall( $::lglobal{replaceentry}->get( '1.0', '1.end' ) );
			},
			-text  => 'Rpl All',
			-width => 5
		  )->pack(
			-side   => 'right',
			-pady   => 1,
			-padx   => 2,
			-anchor => 'nw'
		  );
		$sf12->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				replace( $::lglobal{replaceentry}->get( '1.0', '1.end' ) );
				add_search_history(
					$::lglobal{searchentry}->get( '1.0', '1.end' ),
					\@::search_history);
				searchtext('');
			},
			-text  => 'R & S',
			-width => 5
		  )->pack(
			-side   => 'right',
			-pady   => 1,
			-padx   => 2,
			-anchor => 'nw'
		  );
		$sf12->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				replace( $::lglobal{replaceentry}->get( '1.0', '1.end' ) );
				add_search_history(
					$::lglobal{replaceentry}->get( '1.0', '1.end' ),
					\@::replace_history);
			},
			-text  => 'Replace',
			-width => 6
		  )->pack(
			-side   => 'right',
			-pady   => 1,
			-padx   => 2,
			-anchor => 'nw'
		  );
		$::lglobal{replaceentry} = $sf12->Text(
			-background => $::bkgcolor,
			-width      => 60,
			-height     => 1,
		  )->pack(
			-side   => 'right',
			-anchor => 'w',
			-padx   => 1,
			-expand => 'y',
			-fill   => 'x'
		  );
		$sf12->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				search_history( $::lglobal{replaceentry}, \@::replace_history );
			},
			-image  => $::lglobal{hist_img},
			-width  => 9,
			-height => 15,
		)->pack( -side => 'right', -anchor => 'w' );
		for ( 1 .. $::multisearchsize ) {
			push @multisearch, $::lglobal{searchpop}->Frame;
			my $replaceentry = "replaceentry$_";
		$multisearch[$_-1]->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				replaceall( $::lglobal{$replaceentry}->get( '1.0', '1.end' ) );
			},
			-text  => 'Rpl All',
			-width => 5
		  )->pack(
			-side   => 'right',
			-pady   => 1,
			-padx   => 2,
			-anchor => 'nw'
		  );
		$multisearch[$_-1]->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				replace( $::lglobal{$replaceentry}->get( '1.0', '1.end' ) );
				searchtext('');
			},
			-text  => 'R & S',
			-width => 5
		  )->pack(
			-side   => 'right',
			-pady   => 1,
			-padx   => 2,
			-anchor => 'nw'
		  );
		$multisearch[$_-1]->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				replace( $::lglobal{$replaceentry}->get( '1.0', '1.end' ) );
				add_search_history(
					$::lglobal{$replaceentry}->get( '1.0', '1.end' ),
					\@::replace_history );
			},
			-text  => 'Replace',
			-width => 6
		  )->pack(
			-side   => 'right',
			-pady   => 1,
			-padx   => 2,
			-anchor => 'nw'
		  );
		$::lglobal{$replaceentry} = $multisearch[$_-1]->Text(
			-background => $::bkgcolor,
			-width      => 60,
			-height     => 1,
		  )->pack(
			-side   => 'right',
			-anchor => 'w',
			-padx   => 1,
			-expand => 'y',
			-fill   => 'x'
		  );
		$multisearch[$_-1]->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				search_history( $::lglobal{$replaceentry},
					\@::replace_history );
			},
			-image  => $::lglobal{hist_img},
			-width  => 9,
			-height => 15,
		)->pack( -side => 'right', -anchor => 'w' );
		}
		if ($::multiterm) {
			for ( @multisearch ) {
				$_->pack(
					-side   => 'top',
					-anchor => 'w',
					-padx   => 3,
					-expand => 'y',
					-fill   => 'x'
				);
			}
		}
		if ( $::lglobal{doscannos} ) {
			$sf5 =
			  $::lglobal{searchpop}
			  ->Frame->pack( -side => 'top', -anchor => 'n' );
			my $nextbutton = $sf5->Button(
				-activebackground => $::activecolor,
				-command          => sub {
					$::lglobal{scannosindex}++
					  unless ( $::lglobal{scannosindex} >=
						scalar( @{ $::lglobal{scannosarray} } ) );
					getnextscanno();
				},
				-text  => 'Next Stealtho',
				-width => 15
			  )->pack(
				-side   => 'left',
				-pady   => 5,
				-padx   => 2,
				-anchor => 'w'
			  );
			my $nextoccurrencebutton = $sf5->Button(
				-activebackground => $::activecolor,
				-command          => sub {
					searchtext('');
				},
				-text  => 'Next Occurrence',
				-width => 15
			  )->pack(
				-side   => 'left',
				-pady   => 5,
				-padx   => 2,
				-anchor => 'w'
			  );
			my $lastbutton = $sf5->Button(
				-activebackground => $::activecolor,
				-command          => sub {
					$aacheck->deselect;
					$::lglobal{scannosindex}--
					  unless ( $::lglobal{scannosindex} == 0 );
					getnextscanno();
				},
				-text  => 'Prev Stealtho',
				-width => 15
			  )->pack(
				-side   => 'left',
				-pady   => 5,
				-padx   => 2,
				-anchor => 'w'
			  );
			my $switchbutton = $sf5->Button(
				-activebackground => $::activecolor,
				-command          => sub { swapterms() },
				-text             => 'Swap Terms',
				-width            => 15
			  )->pack(
				-side   => 'left',
				-pady   => 5,
				-padx   => 2,
				-anchor => 'w'
			  );
			my $hintbutton = $sf5->Button(
				-activebackground => $::activecolor,
				-command          => sub { reghint() },
				-text             => 'Hint',
				-width            => 5
			  )->pack(
				-side   => 'left',
				-pady   => 5,
				-padx   => 2,
				-anchor => 'w'
			  );
			my $editbutton = $sf5->Button(
				-activebackground => $::activecolor,
				-command          => sub { regedit() },
				-text             => 'Edit',
				-width            => 5
			  )->pack(
				-side   => 'left',
				-pady   => 5,
				-padx   => 2,
				-anchor => 'w'
			  );
			my $sf6 =
			  $::lglobal{searchpop}
			  ->Frame->pack( -side => 'top', -anchor => 'n' );
			$::lglobal{regtracker} = $sf6->Label( -width => 15 )->pack(
				-side   => 'left',
				-pady   => 5,
				-padx   => 2,
				-anchor => 'w'
			);
			$aacheck = $sf6->Checkbutton(
				-text     => 'Auto Advance',
				-variable => \$::lglobal{regaa},
			  )->pack(
				-side   => 'left',
				-pady   => 5,
				-padx   => 2,
				-anchor => 'w'
			  );
		}
		$::lglobal{searchpop}->protocol(
			'WM_DELETE_WINDOW' => sub {
				$::lglobal{regrepeat}->cancel;
				undef $::lglobal{regrepeat};
				$::lglobal{searchpop}->destroy;
				undef $::lglobal{searchpop};
				$textwindow->tagRemove( 'highlight', '1.0', 'end' );
				undef $::lglobal{hintpop} if $::lglobal{hintpop};
				$::scannosearch = 0;    #no longer in a scanno search
			}
		);
		$::lglobal{searchpop}->Icon( -image => $::icon );
		$::lglobal{searchentry}->focus;
		$::lglobal{searchpop}->resizable( 'yes', 'no' );
		$::lglobal{searchpop}->transient($top) if $::stayontop;
		$::lglobal{searchpop}->Tk::bind(
			'<Return>' => sub {
				$::lglobal{searchentry}->see('1.0');
				$::lglobal{searchentry}->delete('1.end');
				$::lglobal{searchentry}->delete( '2.0', 'end' );
				$::lglobal{replaceentry}->see('1.0');
				$::lglobal{replaceentry}->delete('1.end');
				$::lglobal{replaceentry}->delete( '2.0', 'end' );
				searchtext();
				$top->raise;
			}
		);
		$::lglobal{searchpop}->Tk::bind(
			'<Control-f>' => sub {
				$::lglobal{searchentry}->see('1.0');
				$::lglobal{searchentry}->delete( '2.0', 'end' );
				$::lglobal{replaceentry}->see('1.0');
				$::lglobal{replaceentry}->delete( '2.0', 'end' );
				searchtext();
				$top->raise;
			}
		);
		$::lglobal{searchpop}->Tk::bind(
			'<Control-F>' => sub {
				$::lglobal{searchentry}->see('1.0');
				$::lglobal{searchentry}->delete( '2.0', 'end' );
				$::lglobal{replaceentry}->see('1.0');
				$::lglobal{replaceentry}->delete( '2.0', 'end' );
				searchtext();
				$top->raise;
			}
		);
		$::lglobal{searchpop}->eventAdd(
			'<<FindNexte>>' => '<Control-Key-G>',
			'<Control-Key-g>'
		);
		$::lglobal{searchentry}->bind(
			'<<FindNexte>>',
			sub {
				$::lglobal{searchentry}->delete('insert -1c')
				  if ( $::lglobal{searchentry}->get('insert -1c') eq "\cG" );
				searchtext( $::lglobal{searchentry}->get( '1.0', '1.end' ) );
				$textwindow->focus;
			}
		);
		$::lglobal{searchentry}->{_MENU_}   = ();
		$::lglobal{replaceentry}->{_MENU_}  = ();
		$::lglobal{searchentry}->bind(
			'<FocusIn>',
			sub {
				$::lglobal{hasfocus} = $::lglobal{searchentry};
			}
		);
		$::lglobal{replaceentry}->bind(
			'<FocusIn>',
			sub {
				$::lglobal{hasfocus} = $::lglobal{replaceentry};
			}
		);
		for ( 1 .. $::multisearchsize ) {
			$::lglobal{"replaceentry$_"}->{_MENU_} = ();
			$::lglobal{"replaceentry$_"}->bind(
				'<FocusIn>',
				eval " sub { \$::lglobal{hasfocus} = \$::lglobal{replaceentry$_}; } "
			);
		}
		$::lglobal{searchpop}->Tk::bind(
			'<Control-Return>' => sub {
				$::lglobal{searchentry}->see('1.0');
				$::lglobal{searchentry}->delete('1.end');
				$::lglobal{searchentry}->delete( '2.0', 'end' );
				$::lglobal{replaceentry}->see('1.0');
				$::lglobal{replaceentry}->delete('1.end');
				$::lglobal{replaceentry}->delete( '2.0', 'end' );
				replace( $::lglobal{replaceentry}->get( '1.0', '1.end' ) );
				searchtext();
				$top->raise;
			}
		);
		$::lglobal{searchpop}->Tk::bind(
			'<Shift-Return>' => sub {
				$::lglobal{searchentry}->see('1.0');
				$::lglobal{searchentry}->delete('1.end');
				$::lglobal{searchentry}->delete( '2.0', 'end' );
				$::lglobal{replaceentry}->see('1.0');
				$::lglobal{replaceentry}->delete('1.end');
				$::lglobal{replaceentry}->delete( '2.0', 'end' );
				replace( $::lglobal{replaceentry}->get( '1.0', '1.end' ) );
				$top->raise;
			}
		);
		$::lglobal{searchpop}->Tk::bind(
			'<Control-Shift-Return>' => sub {
				$::lglobal{searchentry}->see('1.0');
				$::lglobal{searchentry}->delete('1.end');
				$::lglobal{searchentry}->delete( '2.0', 'end' );
				$::lglobal{replaceentry}->see('1.0');
				$::lglobal{replaceentry}->delete('1.end');
				$::lglobal{replaceentry}->delete( '2.0', 'end' );
				replaceall( $::lglobal{replaceentry}->get( '1.0', '1.end' ) );
				$top->raise;
			}
		);
	}
	if ( length $searchterm ) {
		$::lglobal{searchentry}->delete( '1.0', 'end' );
		$::lglobal{searchentry}->insert( 'end', $searchterm );
		$::lglobal{searchentry}->tagAdd( 'sel', '1.0', 'end -1c' );
		searchtext('');
	}
}

sub stealthscanno {
	my $textwindow = $::textwindow;
	my $top        = $::top;
	$::lglobal{doscannos} = 1;
	if ( defined $::lglobal{searchpop} ) {
		$::lglobal{regrepeat}->cancel;
		undef $::lglobal{regrepeat};
		$::lglobal{searchpop}->destroy;
	}
	undef $::lglobal{searchpop};
	searchoptset(qw/1 x x 0 1/)
	  ;    # force search to begin at start of doc, whole word
	if ( ::loadscannos() ) {
		::savesettings();
		searchpopup();
		getnextscanno();
		searchtext();
	}
	$::lglobal{doscannos} = 0;
}

sub find_proofer_comment {

	#	::searchtext('[**');
	my $textwindow = $::textwindow;
	my $pattern    = '[**';
	my $comment    = $textwindow->search( $pattern, "insert" );
	if ($comment) {
		my $index = $textwindow->index("$comment +1c");
		$textwindow->SetCursor($index);
	} else {
		::operationadd('Found no more proofer comments');
	}
}

sub find_asterisks {
	my $textwindow = $::textwindow;
	my $pattern    = "(?<!/)\\*(?!/)" ;
	my $comment    = $textwindow->search( '-regexp', '--',$pattern, "insert" );

	if ($comment) {
		my $index = $textwindow->index("$comment +1c");
		$textwindow->SetCursor($index);
	} else {
		::operationadd('Found no more asterisks without slash');
	}
}

sub find_transliterations {
	my $textwindow = $::textwindow;
	my $pattern    = "\\[[^FIS\\d]" ;
	my $comment    = $textwindow->search( '-regexp', '--',$pattern, "insert" );

	if ($comment) {
		my $index = $textwindow->index("$comment +1c");
		$textwindow->SetCursor($index);
	} else {
		::operationadd('Found no more transliterations (\\[[^FIS\\d])');
	}
}

sub nextblock {
	my ( $mark, $direction ) = @_;
	my $textwindow = $::textwindow;
	my $top = $::top;
	unless ($::searchstartindex) { $::searchstartindex = '1.0' }

#use Text::Balanced qw (			extract_delimited			extract_bracketed			extract_quotelike			extract_codeblock			extract_variable			extract_tagged			extract_multiple			gen_delimited_pat			gen_extract_tagged		       );
#print extract_bracketed( "((I)(like(pie))!)", '()' );
#return;
	if ( $mark eq 'default' ) {
		if ( $direction eq 'forward' ) {
			$::searchstartindex =
			  $textwindow->search( '-exact', '--', '/*', $::searchstartindex,
				'end' )
			  if $::searchstartindex;
			::operationadd('Found no more /*..*/ blocks')
			  unless $::searchstartindex;
		} elsif ( $direction eq 'reverse' ) {
			$::searchstartindex =
			  $textwindow->search( '-backwards', '-exact', '--', '/*',
				$::searchstartindex, '1.0' )
			  if $::searchstartindex;
		}
	} elsif ( $mark eq 'indent' ) {
		if ( $direction eq 'forward' ) {
			$::searchstartindex =
			  $textwindow->search( '-regexp', '--', '^\S', $::searchstartindex,
				'end' )
			  if $::searchstartindex;
			$::searchstartindex =
			  $textwindow->search( '-regexp', '--', '^\s', $::searchstartindex,
				'end' )
			  if $::searchstartindex;
			::operationadd('Found no more indented blocks')
			  unless $::searchstartindex;
		} elsif ( $direction eq 'reverse' ) {
			$::searchstartindex =
			  $textwindow->search( '-backwards', '-regexp', '--', '^\S',
				$::searchstartindex, '1.0' )
			  if $::searchstartindex;
			$::searchstartindex =
			  $textwindow->search( '-backwards', '-regexp', '--', '^\s',
				$::searchstartindex, '1.0' )
			  if $::searchstartindex;
		}
	} elsif ( $mark eq 'stet' ) {
		if ( $direction eq 'forward' ) {
			$::searchstartindex =
			  $textwindow->search( '-exact', '--', '/$', $::searchstartindex,
				'end' )
			  if $::searchstartindex;
			::operationadd('Found no more /$..$/ blocks')
			  unless $::searchstartindex;
		} elsif ( $direction eq 'reverse' ) {
			$::searchstartindex =
			  $textwindow->search( '-backwards', '-exact', '--', '/$',
				$::searchstartindex, '1.0' )
			  if $::searchstartindex;
		}
	} elsif ( $mark eq 'block' ) {
		if ( $direction eq 'forward' ) {
			$::searchstartindex =
			  $textwindow->search( '-exact', '--', '/#', $::searchstartindex,
				'end' )
			  if $::searchstartindex;
			::operationadd('Found no more /#..#/ blocks')
			  unless $::searchstartindex;
		} elsif ( $direction eq 'reverse' ) {
			$::searchstartindex =
			  $textwindow->search( '-backwards', '-exact', '--', '/#',
				$::searchstartindex, '1.0' )
			  if $::searchstartindex;
		}
	} elsif ( $mark eq 'poetry' ) {
		if ( $direction eq 'forward' ) {
			$::searchstartindex =
			  $textwindow->search( '-regexp', '--', '\/[pP]',
				$::searchstartindex, 'end' )
			  if $::searchstartindex;
			::operationadd('Found no more /p..p/ blocks')
			  unless $::searchstartindex;
		} elsif ( $direction eq 'reverse' ) {
			$::searchstartindex =
			  $textwindow->search( '-backwards', '-regexp', '--', '\/[pP]',
				$::searchstartindex, '1.0' )
			  if $::searchstartindex;
		}
	}
	$textwindow->markSet( 'insert', $::searchstartindex )
	  if $::searchstartindex;
	if ($::searchstartindex) {
		$textwindow->see('end');
		$textwindow->see($::searchstartindex);
	} 
	$textwindow->update;
	$textwindow->focus;
	if ( $direction eq 'forward' ) {
		$::searchstartindex += 1;
	} elsif ( $direction eq 'reverse' ) {
		$::searchstartindex -= 1;
	}
	if ( $::searchstartindex = int($::searchstartindex) ) {
		$::searchstartindex .= '.0';
	}
	::update_indicators();
}

sub orphanedbrackets {
	my $textwindow = $::textwindow;
	my $top        = $::top;
	my $psel;
	if ( defined( $::lglobal{brkpop} ) ) {
		$::lglobal{brkpop}->deiconify;
		$::lglobal{brkpop}->raise;
		$::lglobal{brkpop}->focus;
	} else {
		$::lglobal{brkpop} = $top->Toplevel;
		$::lglobal{brkpop}->title('Find orphan brackets');
		::initialize_popup_without_deletebinding('brkpop');
		$::lglobal{brkpop}->Label( -text => 'Bracket or Markup Style' )->pack;
		my $frame = $::lglobal{brkpop}->Frame->pack;
		$psel = $frame->Radiobutton(
			-variable    => \$::lglobal{brsel},
			-selectcolor => $::lglobal{checkcolor},
			-value       => '[\(\)]',
			-text        => '(  )',
		)->grid( -row => 1, -column => 1 );
		my $ssel = $frame->Radiobutton(
			-variable    => \$::lglobal{brsel},
			-selectcolor => $::lglobal{checkcolor},
			-value       => '[\[\]]',
			-text        => '[  ]',
		)->grid( -row => 1, -column => 2 );
		my $csel = $frame->Radiobutton(
			-variable    => \$::lglobal{brsel},
			-selectcolor => $::lglobal{checkcolor},
			-value       => '[\{\}]',
			-text        => '{  }',
		)->grid( -row => 1, -column => 3, -pady => 5 );
		my $asel = $frame->Radiobutton(
			-variable    => \$::lglobal{brsel},
			-selectcolor => $::lglobal{checkcolor},
			-value       => '[<>]',
			-text        => '<  >',
		)->grid( -row => 1, -column => 4, -pady => 5 );
		my $frame1 = $::lglobal{brkpop}->Frame->pack;
		my $dsel   = $frame1->Radiobutton(
			-variable    => \$::lglobal{brsel},
			-selectcolor => $::lglobal{checkcolor},
			-value       => '\/\*|\*\/',
			-text        => '/* */',
		)->grid( -row => 1, -column => 1, -pady => 5 );
		my $nsel = $frame1->Radiobutton(
			-variable    => \$::lglobal{brsel},
			-selectcolor => $::lglobal{checkcolor},
			-value       => '\/#|#\/',
			-text        => '/# #/',
		)->grid( -row => 1, -column => 2, -pady => 5 );
		my $stsel = $frame1->Radiobutton(
			-variable    => \$::lglobal{brsel},
			-selectcolor => $::lglobal{checkcolor},
			-value       => '\/\$|\$\/',
			-text        => '/$ $/',
		)->grid( -row => 1, -column => 3, -pady => 5 );
		my $frame3  = $::lglobal{brkpop}->Frame->pack;
		my $parasel = $frame3->Radiobutton(
			-variable    => \$::lglobal{brsel},
			-selectcolor => $::lglobal{checkcolor},
			-value       => '^\/[Pp]|[Pp]\/',
			-text        => '/p p/',
		)->grid( -row => 2, -column => 1, -pady => 5 );
		my $qusel = $frame3->Radiobutton(
			-variable    => \$::lglobal{brsel},
			-selectcolor => $::lglobal{checkcolor},
			-value       => "\«|\»",
			-text        => 'Angle quotes « »',
		)->grid( -row => 2, -column => 2, -pady => 5 );
		my $gqusel = $frame3->Radiobutton(
			-variable    => \$::lglobal{brsel},
			-selectcolor => $::lglobal{checkcolor},
			-value       => '»|«',
			-text        => 'German Angle quotes » «',
		)->grid( -row => 3, -column => 2 );

		#		my $allqsel =
		#		  $frame3->Radiobutton(
		#								-variable    => \$::lglobal{brsel},
		#								-selectcolor => $::lglobal{checkcolor},
		#								-value       => 'all',
		#								-text        => 'All brackets ( )',
		#		  )->grid( -row => 3, -column => 2 );
		my $frame2     = $::lglobal{brkpop}->Frame->pack;
		my $brsearchbt = $frame2->Button(
			-activebackground => $::activecolor,
			-text             => 'Search',
			-command          => \&brsearch,
			-width            => 10,
		)->grid( -row => 1, -column => 2, -pady => 5 );
		my $brnextbt = $frame2->Button(
			-activebackground => $::activecolor,
			-text             => 'Next',
			-command          => sub {
				shift @{ $::lglobal{brbrackets} }
				  if @{ $::lglobal{brbrackets} };
				shift @{ $::lglobal{brindices} }
				  if @{ $::lglobal{brindices} };
				$textwindow->bell
				  unless ( $::lglobal{brbrackets}[1] || $::nobell );
				return unless $::lglobal{brbrackets}[1];
				brnext();
			},
			-width => 10,
		)->grid( -row => 2, -column => 2, -pady => 5 );
	}
	$::lglobal{brkpop}->protocol(
		'WM_DELETE_WINDOW' => sub {
			$::lglobal{brkpop}->destroy;
			undef $::lglobal{brkpop};
			$textwindow->tagRemove( 'highlight', '1.0', 'end' );
		}
	);
	$::lglobal{brkpop}->transient($top) if $::stayontop;
	if ($psel) { $psel->select; }

	sub brsearch {
		my $textwindow = $::textwindow;
		::viewpagenums() if ( $::lglobal{seepagenums} );
		@{ $::lglobal{brbrackets} } = ();
		@{ $::lglobal{brindices} }  = ();
		$::lglobal{brindex} = '1.0';
		my $brcount = 0;
		my $brlength;
		while ( $::lglobal{brindex} ) {
			$::lglobal{brindex} = $textwindow->search(
				'-regexp',
				'-count' => \$brlength,
				'--', "$::lglobal{brsel}", $::lglobal{brindex}, 'end'
			);
			my $brackets = $::lglobal{brsel};
			if ( $brackets =~ /^\[(.*)\]$/ ) {
				$brackets = $1;
				$brackets =~ s/\\//g;
				::operationadd( 'Found no more orphaned ' . $brackets )
				  unless $::lglobal{brindex};
			}
			last unless $::lglobal{brindex};
			$::lglobal{brbrackets}[$brcount] =
			  $textwindow->get( $::lglobal{brindex},
				$::lglobal{brindex} . '+' . $brlength . 'c' );
			$::lglobal{brindices}[$brcount] = $::lglobal{brindex};
			$brcount++;
			$::lglobal{brindex} .= '+1c';
		}
		brnext() if @{ $::lglobal{brbrackets} };
	}

	sub brnext {
		my $textwindow = $::textwindow;
		::viewpagenums() if ( $::lglobal{seepagenums} );
		$textwindow->tagRemove( 'highlight', '1.0', 'end' );
		while (1) {
			last
			  unless (
				(
					   ( $::lglobal{brbrackets}[0] =~ m{[\[\(\{<«]} )
					&& ( $::lglobal{brbrackets}[1] =~ m{[\]\)\}>»]} )
				)
				|| (   ( $::lglobal{brbrackets}[0] =~ m{[\[\(\{<»]} )
					&& ( $::lglobal{brbrackets}[1] =~ m{[\]\)\}>«]} ) )
				|| (   ( $::lglobal{brbrackets}[0] =~ m{^\x7f*/\*} )
					&& ( $::lglobal{brbrackets}[1] =~ m{^\x7f*\*/} ) )
				|| (   ( $::lglobal{brbrackets}[0] =~ m{^\x7f*/\$} )
					&& ( $::lglobal{brbrackets}[1] =~ m{^\x7f*\$/} ) )
				|| (   ( $::lglobal{brbrackets}[0] =~ m{^\x7f*/[p]}i )
					&& ( $::lglobal{brbrackets}[1] =~ m{^\x7f*[p]/}i ) )
				|| (   ( $::lglobal{brbrackets}[0] =~ m{^\x7f*/#} )
					&& ( $::lglobal{brbrackets}[1] =~ m{^\x7f*#/} ) )
			  );
			shift @{ $::lglobal{brbrackets} };
			shift @{ $::lglobal{brbrackets} };
			shift @{ $::lglobal{brindices} };
			shift @{ $::lglobal{brindices} };
			$::lglobal{brbrackets}[0] = $::lglobal{brbrackets}[0] || '';
			$::lglobal{brbrackets}[1] = $::lglobal{brbrackets}[1] || '';
			last unless @{ $::lglobal{brbrackets} };
		}
		if ( ( $::lglobal{brbrackets}[2] ) && ( $::lglobal{brbrackets}[3] ) ) {
			if (   ( $::lglobal{brbrackets}[0] eq $::lglobal{brbrackets}[1] )
				&& ( $::lglobal{brbrackets}[2] eq $::lglobal{brbrackets}[3] ) )
			{
				shift @{ $::lglobal{brbrackets} };
				shift @{ $::lglobal{brbrackets} };
				shift @{ $::lglobal{brindices} };
				shift @{ $::lglobal{brindices} };
				shift @{ $::lglobal{brbrackets} };
				shift @{ $::lglobal{brbrackets} };
				shift @{ $::lglobal{brindices} };
				shift @{ $::lglobal{brindices} };
				brnext();
			}
		}
		if ( @{ $::lglobal{brbrackets} } ) {
			$textwindow->markSet( 'insert', $::lglobal{brindices}[0] )
			  if $::lglobal{brindices}[0];
			$textwindow->see( $::lglobal{brindices}[0] )
			  if $::lglobal{brindices}[0];
			$textwindow->tagAdd( 'highlight', $::lglobal{brindices}[0],
				    $::lglobal{brindices}[0] . '+'
				  . ( length( $::lglobal{brbrackets}[0] ) )
				  . 'c' )
			  if $::lglobal{brindices}[0];
			$textwindow->tagAdd( 'highlight', $::lglobal{brindices}[1],
				    $::lglobal{brindices}[1] . '+'
				  . ( length( $::lglobal{brbrackets}[1] ) )
				  . 'c' )
			  if $::lglobal{brindices}[1];
			$textwindow->focus;
		}
	}
}

sub orphanedmarkup {
	searchpopup();
	searchoptset(qw/0 x x 1/);
	$::lglobal{searchentry}->delete( '1.0', 'end' );

	#	$::lglobal{searchentry}->insert( 'end', "\\<(\\w+)>\\n?[^<]+<(?!/\\1>)" );
	$::lglobal{searchentry}->insert( 'end',
		"<(?!tb)(\\w+)>(\\n|[^<])+<(?!/\\1>)|<(?!/?(tb|sc|[bfgi])>)" );
}

sub searchsize {  # Pop up a window where you can adjust the search history size
	my $top = $::top;
	if ( $::lglobal{hssizepop} ) {
		$::lglobal{hssizepop}->deiconify;
		$::lglobal{hssizepop}->raise;
	} else {
		$::lglobal{hssizepop} = $top->Toplevel;
		$::lglobal{hssizepop}->title('History Size');
		::initialize_popup_with_deletebinding('hssizepop');
		$::lglobal{hssizepop}->resizable( 'no', 'no' );
		my $frame =
		  $::lglobal{hssizepop}
		  ->Frame->pack( -fill => 'x', -padx => 5, -pady => 5 );
		$frame->Label( -text => 'History Size: # of terms to save - ' )
		  ->pack( -side => 'left' );
		my $entry = $frame->Entry(
			-background   => $::bkgcolor,
			-width        => 5,
			-textvariable => \$::history_size,
			-validate     => 'key',
			-vcmd         => sub {
				return 1 unless $_[0];
				return 0 if ( $_[0] =~ /\D/ );
				return 0 if ( $_[0] < 1 );
				return 0 if ( $_[0] > 200 );
				return 1;
			},
		)->pack( -side => 'left', -fill => 'x' );
		my $frame2 =
		  $::lglobal{hssizepop}
		  ->Frame->pack( -fill => 'x', -padx => 5, -pady => 5 );
		$frame2->Button(
			-text    => 'Ok',
			-width   => 10,
			-command => sub {
				::savesettings();
				$::lglobal{hssizepop}->destroy;
				undef $::lglobal{hssizepop};
			}
		)->pack;
		$::lglobal{hssizepop}->raise;
		$::lglobal{hssizepop}->focus;
	}
}

# Do not move from guiguts.pl; do command must be run in main
sub loadscannos {
	my $top = $::top;
	$::lglobal{scannosfilename} = '';
	%::scannoslist = ();
	@{ $::lglobal{scannosarray} } = ();
	$::lglobal{scannosindex} = 0;
	my $types = [ [ 'Scannos', ['.rc'] ], [ 'All Files', ['*'] ], ];
	$::scannospath = ::os_normal($::scannospath);
	$::lglobal{scannosfilename} = $top->getOpenFile(
		-filetypes  => $types,
		-title      => 'Scannos list?',
		-initialdir => $::scannospath
	);

	if ( $::lglobal{scannosfilename} ) {
		my ( $name, $path, $extension ) =
		  ::fileparse( $::lglobal{scannosfilename}, '\.[^\.]*$' );
		$::scannospath = $path;
		unless ( my $return = ::dofile( $::lglobal{scannosfilename} ) )
		{    # load scannos list
			unless ( defined $return ) {
				if ($@) {
					$top->messageBox(
						-icon => 'error',
						-message =>
'Could not parse scannos file, file may be corrupted.',
						-title => 'Problem with file',
						-type  => 'Ok',
					);
				} else {
					$top->messageBox(
						-icon    => 'error',
						-message => 'Could not find scannos file.',
						-title   => 'Problem with file',
						-type    => 'Ok',
					);
				}
				$::lglobal{doscannos} = 0;
				return 0;
			}
		}
		foreach ( sort ( keys %::scannoslist ) ) {
			push @{ $::lglobal{scannosarray} }, $_;
		}
		if ( $::lglobal{scannosfilename} =~ /reg/i ) {
			searchoptset(qw/0 x x 1/);
		} else {
			searchoptset(qw/x x x 0/);
		}
		return 1;
	}
}


sub replace_incr_counter {
    my $counter = 1;
    my $textwindow = $::textwindow;
    my $pos = '1.0';
    while (1) {
	my $newpos = $textwindow->search( '-exact', '--', '[::]', "$pos", 'end' );
	last unless $newpos;
	$textwindow->delete( "$newpos", "$newpos+4c" );
	$textwindow->insert( "$newpos", $counter );
	$pos = $newpos;
	$counter++;
    }
}

1;
