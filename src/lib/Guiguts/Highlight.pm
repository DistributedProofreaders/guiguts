package Guiguts::Highlight;
use strict;
use warnings;

BEGIN {
	use Exporter();
	our ( @ISA, @EXPORT );
	@ISA    = qw(Exporter);
	@EXPORT = qw(&scannosfile &hilite &hiliteremove &hilitesinglequotes &hilitedoublequotes &hilitepopup &highlight_scannos);
}

# Routine to find highlight word list
sub scannosfile {
	my $top = $::top;
	if ($::debug) { print "sub scannosfile\n"; }
	if ($::debug) { print "scannoslistpath=$::scannoslistpath\n"; }
	$::scannoslistpath = ::os_normal($::scannoslistpath);
	if ($::debug) { print "sub scannosfile1\n"; }
	my $types = [ [ 'Text file', [ '.txt', ] ], [ 'All Files', ['*'] ], ];
	my $scannosfile = $top->getOpenFile(
		-title      => 'List of words to highlight?',
		-filetypes  => $types,
		-initialdir => $::scannoslistpath
	);
	if ($scannosfile) {
		$::scannoslist = $scannosfile;
		my ( $name, $path, $extension ) =
		  ::fileparse( $::scannoslist, '\.[^\.]*$' );
		$::scannoslistpath = $path;
		if ($::debug) {
			print "sub scannosfile1.5:" . $::scannoslistpath . "\n";
		}
		::highlight_scannos() if ($::scannos_highlighted);
		%{ $::lglobal{wordlist} } = ();
		::highlight_scannos();
		read_word_list();
	}
	if ($::debug) { print "sub scannosfile2:" . $::scannoslist . "\n"; }
	return;
}
##routine to automatically highlight words in the text
sub highlightscannos {
	my $textwindow = $::textwindow;
	my $top        = $::top;
	if ($::debug) { print "sub highlightscannos\n"; }
	return 0 unless $::scannos_highlighted;
	if ($::debug) {
		print $::scannoslist . ":wdlist\n";
		if ( -e $::scannoslist ) {
			print $::scannoslist . ":exists\n";
		} else {
			print $::scannoslist . ":does not exist\n";
		}
		print $::lglobal{wordlist} . ":lglob wordlist\n";
	}
	unless ($::lglobal{wordlist}) {read_word_list();}
	my ( $fileend, undef ) = split /\./, $textwindow->index('end');
	if ( $::lglobal{hl_index} < $fileend ) {
		for ( 0 .. 99 ) {
			my $textline = $textwindow->get( "$::lglobal{hl_index}.0",
				"$::lglobal{hl_index}.end" );
			while ( $textline =~
				s/ [^\p{Alnum} ]|[^\p{Alnum} ] |[^\p{Alnum} ][^\p{Alnum} ]/  / )
			{
			}
			$textline =~ s/^'|[,']+$/"/;
			$textline =~ s/--/  /g;
			my @words = split( /[^'\p{Alnum},-]+/, $textline );
			for my $word (@words) {
				if ( defined $::lglobal{wordlist}->{$word} ) {
					my $indx = 0;
					my $index;
					while (1) {
						$index = index( $textline, $word, $indx );
						last if ( $index < 0 );
						$indx = $index + length($word);
						if ( $index > 0 ) {
							next
							  if (
								$textwindow->get(
									"$::lglobal{hl_index}.@{[$index-1]}") =~
								m{\p{Alnum}}
							  );
						}
						next
						  if (
							$textwindow->get(
"$::lglobal{hl_index}.@{[$index + length $word]}"
							) =~ m{\p{Alnum}}
						  );
						$textwindow->tagAdd(
							'scannos',
							"$::lglobal{hl_index}.$index",
							"$::lglobal{hl_index}.$index +@{[length $word]}c"
						);
					}
				}
			}
			$::lglobal{hl_index}++;
			last if ( $::lglobal{hl_index} > $fileend );
		}
	}
	my $idx1 = $textwindow->index('@0,0');   # First visible line in text widget
	$::lglobal{visibleline} = $idx1;
	$textwindow->tagRemove(
		'scannos',
		$idx1,
		$textwindow->index(
			'@' . $textwindow->width . ',' . $textwindow->height
		)
	);
	my ( $dummy, $ypix ) = $textwindow->dlineinfo($idx1);
	my $theight = $textwindow->height;
	my $oldy = my $lastline = -99;
	while (1) {
		my $idx = $textwindow->index( '@0,' . "$ypix" );
		( my $realline ) = split( /\./, $idx );
		my ( $x, $y, $wi, $he ) = $textwindow->dlineinfo($idx);
		my $textline = $textwindow->get( "$realline.0", "$realline.end" );
		while ( $textline =~
			s/ [^\p{Alnum} ]|[^\p{Alnum} ] |[^\p{Alnum} ][^\p{Alnum} ]/  / )
		{
		}
		$textline =~ s/^'|[,']+$/"/;
		$textline =~ s/--/  /g;
		my @words = split( /[^'\p{Alnum},-]/, $textline );

		for my $word (@words) {
			if ( defined $::lglobal{wordlist}->{$word} ) {
				my $indx = 0;
				my $index;
				while (1) {
					$index = index( $textline, $word, $indx );
					last if ( $index < 0 );
					$indx = $index + length($word);
					if ( $index > 0 ) {
						next
						  if ( $textwindow->get("$realline.@{[$index - 1]}") =~
							m{\p{Alnum}} );
					}
					next
					  if (
						$textwindow->get(
							"$realline.@{[$index + length $word]}") =~
						m{\p{Alnum}}
					  );
					$textwindow->tagAdd(
						'scannos',
						"$realline.$index",
						"$realline.$index +@{[length $word]}c"
					);
				}
			}
		}
		last unless defined $he;
		last if ( $oldy == $y );    #line is the same as the last one
		$oldy = $y;
		$ypix += $he;
		last
		  if $ypix >= ( $theight - 1 );  #we have reached the end of the display
		last if ( $y == $ypix );
	}
	return;
}

sub read_word_list {
	my $top = $::top;
	::scannosfile() unless ( defined $::scannoslist && -e $::scannoslist );
	return 0 unless $::scannoslist;
	if ($::debug) { print "opening scannos list\n"; }
	if ( open my $fh, '<', $::scannoslist ) {
		if ($::debug) { print "opened scannos list\n"; }
		while (<$fh>) {
			utf8::decode($_);
			if ($::debug) { print "$_ :scanno read "; }
			if ( $_ =~ 'scannoslist' ) {
				my $dialog = $top->Dialog(
					-text => 'Warning: File must contain only a list of words.',
					-bitmap  => 'warning',
					-title   => 'Warning!',
					-buttons => ['OK'],
				);
				my $answer = $dialog->Show;
				$::scannos_highlighted = 0;
				undef $::scannoslist;
				return;
			}
			$_ =~ s/^\x{FFEF}?// if ( $. < 2 );
			s/\cM\cJ|\cM|\cJ//g;
			next unless length $_;
			my @words = split /[\s \xA0]+/, $_;
			for my $word (@words) {
				next unless length $word;
				$word =~ s/^\p{Punct}*|\p{Punct}*$//g;
				$::lglobal{wordlist}->{$word} = '';
			}
		}
	} else {
		warn "Cannot open $::scannoslist: $!";
		return 0;
	}
}

sub hilite {
	my $textwindow = $::textwindow;
	my $top        = $::top;
	my $mark       = shift;
	my $matchtype  = shift;

	$mark = quotemeta($mark) if $matchtype eq 'exact';
	my @ranges      = $textwindow->tagRanges('sel');
	my $range_total = @ranges;
	my ( $index, $lastindex );

	if ( $range_total == 0 ) {
		return;
	} else {
		my $end            = pop(@ranges);
		my $start          = pop(@ranges);
		my $thisblockstart = $start;
		$lastindex = $start;
		my $thisblockend = $end;
		hiliteremove();
		my $length;
		while ($lastindex) {
			$index = $textwindow->search(
				'-regexp',
				-count => \$length,
				'--', $mark, $lastindex, $thisblockend
			);
			$textwindow->tagAdd( 'quotemark', $index,
				$index . ' +' . $length . 'c' )
			  if $index;
			if   ($index) { $lastindex = "$index+1c" }
			else          { $lastindex = '' }
		}
	}
}

# Remove all highlights from file
sub hiliteremove {
	my $textwindow = $::textwindow;
	$textwindow->tagRemove( 'highlight', '1.0', 'end' );
	$textwindow->tagRemove( 'quotemark', '1.0', 'end' ); 
}

# Highlight straight and curly single quotes in selection
sub hilitesinglequotes {
	hilite( '[\'\x{2018}\x{2019}]', 'regex' );
}

# Highlight straight and curly double quotes in selection
sub hilitedoublequotes {
	hilite( '["\x{201c}\x{201d}]', 'regex' );
}

# Popup for highlighting arbitrary characters in selection
sub hilitepopup {
	my $textwindow = $::textwindow;
	my $top        = $::top;
	::hidepagenums();
	if ( defined( $::lglobal{hilitepop} ) ) {
		$::lglobal{hilitepop}->deiconify;
		$::lglobal{hilitepop}->raise;
		$::lglobal{hilitepop}->focus;
	} else {
		$::lglobal{hilitepop} = $top->Toplevel;
		$::lglobal{hilitepop}->title('Character Highlight');
		::initialize_popup_with_deletebinding('hilitepop');
		my $hilitemode = 'exact';
		my $f =
		  $::lglobal{hilitepop}->Frame->pack( -side => 'top', -anchor => 'n' );
		$f->Label( -text => 'Highlight Character(s) or Regex', )
		  ->pack( -side => 'top', -pady => 2, -padx => 2, -anchor => 'n' );
		my $entry = $f->Entry(
			-width      => 40,
			-background => $::bkgcolor,
			-font       => $::lglobal{font},
			-relief     => 'sunken',
		  )->pack(
			-expand => 1,
			-fill   => 'x',
			-padx   => 3,
			-pady   => 3,
			-anchor => 'n'
		  );
		my $f2 =
		  $::lglobal{hilitepop}->Frame->pack( -side => 'top', -anchor => 'n' );
		$f2->Radiobutton(
			-variable    => \$hilitemode,
			-selectcolor => $::lglobal{checkcolor},
			-value       => 'exact',
			-text        => 'Exact',
		)->grid( -row => 0, -column => 1 );
		$f2->Radiobutton(
			-variable    => \$hilitemode,
			-selectcolor => $::lglobal{checkcolor},
			-value       => 'regex',
			-text        => 'Regex',
		)->grid( -row => 0, -column => 2 );
		my $f3 =
		  $::lglobal{hilitepop}->Frame->pack( -side => 'top', -anchor => 'n' );
		$f3->Button(
			-activebackground => $::activecolor,
			-command          => sub {

				if ( $textwindow->markExists('selstart') ) {
					$textwindow->tagAdd( 'sel', 'selstart', 'selend' );
				}
			},
			-text  => 'Previous Selection',
			-width => 16,
		)->grid( -row => 1, -column => 1, -padx => 2, -pady => 2 );
		$f3->Button(
			-activebackground => $::activecolor,
			-command => sub { $textwindow->tagAdd( 'sel', '1.0', 'end' ) },
			-text    => 'Select Whole File',
			-width   => 16,
		)->grid( -row => 1, -column => 2, -padx => 2, -pady => 2 );
		$f3->Button(
			-activebackground => $::activecolor,
			-command          => sub { hilite( $entry->get, $hilitemode ) },
			-text             => 'Apply Highlights',
			-width            => 16,
		)->grid( -row => 2, -column => 1, -padx => 2, -pady => 2 );
		$f3->Button(
			-activebackground => $::activecolor,
			-command          => \&::hiliteremove,
			-text  => 'Remove Highlight',
			-width => 16,
		)->grid( -row => 2, -column => 2, -padx => 2, -pady => 2 );
	}
}

sub highlight_scannos {    # Enable / disable word highlighting in the text
	my $textwindow = $::textwindow;
	my $top        = $::top;
	if ($::scannos_highlighted) {
		$::lglobal{hl_index} = 1;
		highlightscannos();
		$::lglobal{scannos_highlightedid} =
		  $top->repeat( 400, \&highlightscannos );
	} else {
		$::lglobal{scannos_highlightedid}->cancel
		  if $::lglobal{scannos_highlightedid};
		undef $::lglobal{scannos_highlightedid};
		$textwindow->tagRemove( 'scannos', '1.0', 'end' );
	}
	::update_indicators();
	::savesettings();
}
1;
