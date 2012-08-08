package Guiguts::WordFrequency;
use strict;
use warnings;

BEGIN {
	use Exporter();
	our ( @ISA, @EXPORT );
	@ISA    = qw(Exporter);
	@EXPORT = qw(&wordfrequencybuildwordlist &wordfrequency);
}

# build lists of words, word pairs, and double hyphenated words
sub wordfrequencybuildwordlist {
	my $textwindow = shift;
	my ( @words, $match, @savesets );
	my $index = '1.0';
	my $wc    = 0;
	my $end   = $textwindow->index('end');
	$::lglobal{seenwordsdoublehyphen} = ();
	$::lglobal{seenwords}             = ();
	$::lglobal{seenwordpairs}         = ();
	my $filename = $textwindow->FileName;

	unless ($filename) {
		$filename = 'tempfile.tmp';
		open( my $file, ">", "$filename" );
		my ($lines) = $textwindow->index('end - 1 chars') =~ /^(\d+)\./;
		while ( $textwindow->compare( $index, '<', 'end' ) ) {
			my $end = $textwindow->index("$index  lineend +1c");
			my $line = $textwindow->get( $index, $end );
			print $file $line;
			$index = $end;
		}
	}
	::savefile()
	  if ( ( $textwindow->FileName )
		&& ( $textwindow->numberChanges != 0 ) );
	open my $fh, '<', $filename;
	my $lastwordseen = '';
	while ( my $line = <$fh> ) {
		utf8::decode($line);
		next if $line =~ m/^-----*\s?File:\s?\S+\.(png|jpg)---/;
		$line =~ s/_/ /g;
		$line =~ s/<!--//g;
		$line =~ s/-->//g;
		$line =~ s/<\/?[a-z]*>/ /g;    # throw away tags
		if ( $::lglobal{ignore_case} ) { $line = lc($line) }
		@words = split( /\s+/, $line );

		# build a list of "word--word""
		for my $word (@words) {
			next unless ( $word =~ /--/ );
			next if ( $word =~ /---/ );
			$word =~ s/[\.,']$//;
			$word =~ s/^[\.'-]+//;
			next if ( $word eq '' );
			$match = ( $::lglobal{ignore_case} ) ? lc($word) : $word;
			$::lglobal{seenwordsdoublehyphen}->{$match}++;
		}
		$line =~ s/[^'\.,\p{Alnum}\*-]/ /g;    # get rid of nonalphanumeric
		$line =~ s/--/ /g;                     # get rid of --
		$line =~
		  s/—/ /g;    # trying to catch words with real em-dashes, from dp2rst
		$line =~ s/(\D),/$1 /g;    # throw away comma after non-digit
		$line =~ s/,(\D)/ $1/g;    # and before
		@words = split( /\s+/, $line );
		for my $word (@words) {
			$word =~ s/ //g;
			if ( length($word) == 0 ) { next; }
			if ( $lastwordseen && not( "$lastwordseen $word" =~ m/\d/ ) ) {
				$::lglobal{seenwordpairs}->{"$lastwordseen $word"}++;
			}
			$lastwordseen = $word;
			$word =~ s/(?<!\-)\*//g;
			$word =~ s/^\*$//;
			$word =~ s/[\.	',-]+$//;    # throw away punctuation at end
			$word =~ s/^[\.,'-]+//;     #and at the beginning
			next if ( $word eq '' );
			$wc++;
			$match = ( $::lglobal{ignore_case} ) ? lc($word) : $word;
			$::lglobal{seenwords}->{$match}++;
		}
		$index++;
		$index .= '.0';
		$textwindow->update;
	}
	close $fh;
	unlink 'tempfile.tmp' if ( -e 'tempfile.tmp' );
	return $wc;
}
## Word Frequency
sub wordfrequency {
	my $top        = $::top;
	my $textwindow = $::textwindow;
	::operationadd('Word Frequency');
	::viewpagenums() if ( $::lglobal{seepagenums} );
	::oppopupdate()  if $::lglobal{oppop};
	my ( @words, $match, @savesets );
	my $index = '1.0';
	my $wc    = 0;
	my $end   = $textwindow->index('end');
	::searchoptset(qw/1 0 x 0/);    # Default is whole word search

	if ( $::lglobal{wfpop} ) {
		$::lglobal{wfpop}->deiconify;
		$::lglobal{wfpop}->raise;
		$::lglobal{wclistbox}->delete( '0', 'end' );
	} else {
		$::lglobal{wfpop} = $top->Toplevel;
		$::lglobal{wfpop}
		  ->title('Word frequency - Ctrl+s to save, Ctrl+x to export');
		my $wordfreqseframe =
		  $::lglobal{wfpop}->Frame->pack( -side => 'top', -anchor => 'n' );
		my $wcopt3 = $wordfreqseframe->Checkbutton(
			-variable    => \$::lglobal{suspects_only},
			-selectcolor => $::lglobal{checkcolor},
			-text        => 'Suspects only'
		)->pack( -side => 'left', -anchor => 'nw', -pady => 1 );
		my $wcopt1 = $wordfreqseframe->Checkbutton(
			-variable    => \$::lglobal{ignore_case},
			-selectcolor => $::lglobal{checkcolor},
			-text        => 'No case',
		)->pack( -side => 'left', -anchor => 'nw', -pady => 1 );
		$wordfreqseframe->Radiobutton(
			-variable    => \$::alpha_sort,
			-selectcolor => $::lglobal{checkcolor},
			-value       => 'a',
			-text        => 'Alph',
		)->pack( -side => 'left', -anchor => 'nw', -pady => 1 );
		$wordfreqseframe->Radiobutton(
			-variable    => \$::alpha_sort,
			-selectcolor => $::lglobal{checkcolor},
			-value       => 'f',
			-text        => 'Frq',
		)->pack( -side => 'left', -anchor => 'nw', -pady => 1 );
		$wordfreqseframe->Radiobutton(
			-variable    => \$::alpha_sort,
			-selectcolor => $::lglobal{checkcolor},
			-value       => 'l',
			-text        => 'Len',
		)->pack( -side => 'left', -anchor => 'nw', -pady => 1 );
		$wordfreqseframe->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				return unless ( $::lglobal{wclistbox}->curselection );
				$::lglobal{harmonics} = 1;
				harmonicspop($top);
			},
			-text => '1st Harm',
		  )->pack(
			-side   => 'left',
			-padx   => 1,
			-pady   => 1,
			-anchor => 'nw'
		  );
		$wordfreqseframe->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				return unless ( $::lglobal{wclistbox}->curselection );
				$::lglobal{harmonics} = 2;
				harmonicspop($top);
			},
			-text => '2nd Harm',
		  )->pack(
			-side   => 'left',
			-padx   => 1,
			-pady   => 1,
			-anchor => 'nw'
		  );
		$wordfreqseframe->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				#return if $::lglobal{global_filename} =~ /No File Loaded/;
				#savefile() unless ( $textwindow->numberChanges == 0 );
				wordfrequency();
			},
			-text => 'Rerun '
		  )->pack(
			-side   => 'left',
			-padx   => 2,
			-pady   => 1,
			-anchor => 'nw'
		  );
		my $wordfreqseframe1 =
		  $::lglobal{wfpop}->Frame->pack( -side => 'top', -anchor => 'n' );
		my @wfbuttons = (
			[ 'Emdashes'  => sub { dashcheck() } ],
			[ 'Hyphens'   => sub { hyphencheck() } ],
			[ 'Alpha/num' => sub { alphanumcheck() } ],
			[
				'All Words' => sub {
					$::lglobal{saveheader} =
					  "$wc total words. " .
					  keys( %{ $::lglobal{seenwords} } )
					  . " distinct words in file.";
					sortwords( $::lglobal{seenwords} );
					::searchoptset(qw/1 0 x 0/);   #default is whole word search
				  }
			],
			[ 'Check Spelling', sub { wordfrequencyspellcheck() } ],
			[ 'Ital/Bold/SC',   sub { itwords(); ital_adjust() } ],
			[ 'ALL CAPS',       sub { capscheck() } ],
			[ 'MiXeD CasE',     sub { mixedcasecheck() } ],
			[
				'Initial Caps',
				sub {
					anythingwfcheck( 'words with initial caps',
						'^\p{Upper}\P{Upper}+$', $top );
				  }
			],
			[ 'Character Cnts', sub { charsortcheck() } ],
			[ 'Check , Upper',  sub { commark() } ],
			[ 'Check . lower',  sub { bangmark() } ],
			[ 'Check Accents',  sub { accentcheck() } ],
			[
				'Unicode > FF',
				[
					\&anythingwfcheck, 'words with unicode chars > FF',
					'[\x{100}-\x{FFEF}]'
				]
			],
			[ 'Stealtho Check', sub { stealthcheck() } ],
			[
				'Ligatures',
				[
					\&anythingwfcheck,
					'words with possible ligatures',
					'(oe|ae|æ|Æ|\x{0153}|\x{0152})'
				]
			],
			[ 'RegExpEntry', [ \&anythingwfcheck, 'dummy entry', 'dummy' ] ],
			[
				'<--RegExp',
				[
					sub {
						anythingwfcheck( 'words matching regular expression',
							$::regexpentry );
					  }
				]
			],
		);
		my ( $row, $col, $inc ) = ( 0, 0, 0 );
		for (@wfbuttons) {
			$row = int( $inc / 5 );
			$col = $inc % 5;
			++$inc;
			if ( not( $_->[0] eq 'RegExpEntry' ) ) {
				my $button = $wordfreqseframe1->Button(
					-activebackground => $::activecolor,
					-command          => $_->[1],
					-text             => $_->[0],
					-width            => 13
				  )->grid(
					-row    => $row,
					-column => $col,
					-padx   => 1,
					-pady   => 1
				  );
				$button->bind( '<3>' => $_->[2] ) if $_->[2];
			} else {
				$::lglobal{regexpentry} = $wordfreqseframe1->Entry(
					-background   => $::bkgcolor,
					-textvariable => \$::regexpentry,
					-width        => 13,
				)->grid( -row => $row, -column => $col );
			}
		}
		my $wcframe =
		  $::lglobal{wfpop}->Frame->pack( -fill => 'both', -expand => 'both', );
		$::lglobal{wclistbox} = $wcframe->Scrolled(
			'Listbox',
			-scrollbars  => 'se',
			-background  => $::bkgcolor,
			-font        => $::lglobal{font},
			-selectmode  => 'single',
			-activestyle => 'none',
		  )->pack(
			-anchor => 'nw',
			-fill   => 'both',
			-expand => 'both',
			-padx   => 2,
			-pady   => 2
		  );
		::initialize_popup_without_deletebinding('wfpop');
		::drag( $::lglobal{wclistbox} );
		$::lglobal{wfpop}->protocol(
			'WM_DELETE_WINDOW' => sub {
				$::lglobal{wfpop}->destroy;
				undef $::lglobal{wfpop};
				undef $::lglobal{wclistbox};
				$::lglobal{markuppop}->destroy if $::lglobal{markuppop};
				undef $::lglobal{markuppop};
			}
		);
		::BindMouseWheel( $::lglobal{wclistbox} );
		$::lglobal{wclistbox}->eventAdd( '<<search>>' => '<ButtonRelease-3>' );
		$::lglobal{wclistbox}->bind(
			'<<search>>',
			sub {
				$::lglobal{wclistbox}->selectionClear( 0, 'end' );
				$::lglobal{wclistbox}->selectionSet(
					$::lglobal{wclistbox}->index(
						'@'
						  . (
							$::lglobal{wclistbox}->pointerx -
							  $::lglobal{wclistbox}->rootx
						  )
						  . ','
						  . (
							$::lglobal{wclistbox}->pointery -
							  $::lglobal{wclistbox}->rooty
						  )
					)
				);

				# right click means popup a search box
				my ($sword) =
				  $::lglobal{wclistbox}
				  ->get( $::lglobal{wclistbox}->curselection );
				::searchpopup();
				$sword =~ s/\d+\s+(\S)/$1/;
				$sword =~ s/\s+\*\*\*\*$//;
				if ( $sword =~ /\*space\*/ ) {
					$sword = ' ';
					::searchoptset(qw/0 x x 1/);
				} elsif ( $sword =~ /\*tab\*/ ) {
					$sword = '\t';
					::searchoptset(qw/0 x x 1/);
				} elsif ( $sword =~ /\*newline\*/ ) {
					$sword = '\n';
					::searchoptset(qw/0 x x 1/);
				} elsif ( $sword =~ /\*nbsp\*/ ) {
					$sword = '\x{A0}';
					::searchoptset(qw/0 x x 1/);
				} elsif ( $sword =~ /\W/ ) {
					$sword =~ s/([^\w\s\\])/\\$1/g;
					::searchoptset(qw/0 x x 1/);
				}
				$::lglobal{searchentry}->delete( '1.0', 'end' );
				$::lglobal{searchentry}->insert( 'end', $sword );
				::updatesearchlabels();
				$::lglobal{searchentry}->after( $::lglobal{delay} );
			}
		);
		$::lglobal{wclistbox}
		  ->eventAdd( '<<find>>' => '<Double-Button-1>', '<Return>' );
		$::lglobal{wclistbox}->bind(    # FIXME: This needs to go in GC code.
			'<<find>>',
			sub {
				my ($sword) =
				  $::lglobal{wclistbox}
				  ->get( $::lglobal{wclistbox}->curselection );
				return unless length $sword;
				@savesets = @::sopt;
				$sword =~ s/(\d+)\s+(\S)/$2/;
				my $snum = $1;
				$sword =~ s/\s+\*\*\*\*$//;
				if ( $sword =~ /\W/ ) {
					$sword =~ s/\*nbsp\*/\x{A0}/;
					$sword =~ s/\*tab\*/\t/;
					$sword =~ s/\*newline\*/\n/;
					$sword =~ s/\*space\*/ /;
					$sword =~ s/([^\w\s\\])/\\$1/g;

					#$sword = ::escape_regexmetacharacters($sword);
					$sword .= '\b'
					  if ( ( length $sword gt 1 ) && ( $sword =~ /\w$/ ) );
					::searchoptset(qw/0 0 x 1/);    # Case sensitive
				}

				# not whole word search from character cnts popup
				if (    ( length($sword) == 1 )
					and ( $::lglobal{saveheader} =~ /characters in the file./ )
				  )
				{
					::searchoptset(qw/0 0 x 0/);
				}
				if ( $::intelligentWF && $sword =~ /^\\,(\s|\\n)/ ) {

		# during comma-Upper ck, ignore if name followed by period, !, or ?
		# NOTE: sword will be used as a regular expression filter during display
					$sword .= '([^\.\?\!]|$)';
				}
				if    ( $sword =~ /\*space\*/ )   { $sword = ' ' }
				elsif ( $sword =~ /\*tab\*/ )     { $sword = "\t" }
				elsif ( $sword =~ /\*newline\*/ ) { $sword = "\n" }
				elsif ( $sword =~ /\*nbsp\*/ )    { $sword = "\xA0" }
				unless ($snum) {
					::searchoptset(qw/0 x x 1/);
					unless ( $sword =~ m/--/ ) {
						$sword = "(?<=-)$sword|$sword(?=-)";
					}
				}

		#print $sword.":sword\n";
		#print $::sopt[0],$::sopt[1],$::sopt[2],$::sopt[3],$::sopt[4].":sopt\n";
				::searchfromstartifnew($sword);
				::searchtext($sword);
				::searchoptset(@savesets);
				$top->raise;
			}
		);
		$::lglobal{wclistbox}->eventAdd( '<<harm>>' => '<Control-Button-1>' );
		$::lglobal{wclistbox}->bind(
			'<<harm>>',
			sub {
				return unless ( $::lglobal{wclistbox}->curselection );
				harmonics( $::lglobal{wclistbox}->get('active') );
				harmonicspop();
			}
		);
		$::lglobal{wclistbox}->eventAdd(
			'<<adddict>>' => '<Control-Button-2>',
			'<Control-Button-3>'
		);
		$::lglobal{wclistbox}->bind(
			'<<adddict>>',
			sub {
				return unless ( $::lglobal{wclistbox}->curselection );
				return unless $::lglobal{wclistbox}->index('active');
				my $sword = $::lglobal{wclistbox}->get('active');
				$sword =~ s/\d+\s+([\w'-]*)/$1/;
				$sword =~ s/\*\*\*\*$//;
				$sword =~ s/\s//g;
				return if ( $sword =~ /[^\p{Alnum}']/ );
				::spellmyaddword($sword);
				delete( $::lglobal{spellsort}->{$sword} );
				$::lglobal{saveheader} =
				  scalar( keys %{ $::lglobal{spellsort} } )
				  . ' words not recognised by the spellchecker.';
				sortwords( \%{ $::lglobal{spellsort} } );
			}
		);
		add_navigation_events( $::lglobal{wclistbox} );
		$::lglobal{wfpop}->bind(
			'<Control-s>' => sub {
				my ($name);
				$name = $textwindow->getSaveFile(
					-title       => 'Save Word Frequency List As',
					-initialdir  => $::globallastpath,
					-initialfile => 'wordfreq.txt'
				);

				#FIXME not UTF-8 compatible
				if ( defined($name) and length($name) ) {
					open( my $save, ">", "$name" );
					print $save join "\n",
					  $::lglobal{wclistbox}->get( '0', 'end' );
				}
			}
		);
		$::lglobal{wfpop}->bind(
			'<Control-x>' => sub {
				my ($name);
				$name = $textwindow->getSaveFile(
					-title       => 'Export Word Frequency List As',
					-initialdir  => $::globallastpath,
					-initialfile => 'wordlist.txt'
				);

				#FIXME not UTF-8 compatible
				if ( defined($name) and length($name) ) {
					my $count = $::lglobal{wclistbox}->index('end');
					open( my $save, ">", "$name" );
					for ( 1 .. $count ) {
						my $word = $::lglobal{wclistbox}->get($_);
						if ( ( defined $word ) && ( length $word ) ) {
							$word =~ s/^\d+\s+//;
							$word =~ s/\s+\*{4}\s*$//;
							print $save $word, "\n";
						}
					}
				}
			}
		);
	}
	$top->Busy( -recurse => 1 );
	$::lglobal{wclistbox}->focus;
	$::lglobal{wclistbox}
	  ->insert( 'end', 'Please wait, building word list....' );
	$wc = wordfrequencybuildwordlist($textwindow);

	#print "$index  ";
	$::lglobal{saveheader} = "$wc total words. " .
	  keys( %{ $::lglobal{seenwords} } ) . " distinct words in file.";
	$::lglobal{wclistbox}->delete( '0', 'end' );
	$::lglobal{last_sort} = $::lglobal{ignore_case};

	#print $::lglobal{ignore_case}.":ignore\n";
	if ( $::lglobal{ignore_case} ) {
		::searchoptset("x 1 x x");
	} else {
		::searchoptset("x 0 x x");
	}
	$top->Unbusy( -recurse => 1 );
	sortwords( \%{ $::lglobal{seenwords} } );
	::update_indicators();
}

sub bangmark {
	my $top = $::top;
	::operationadd('Check . lower');
	$top->Busy( -recurse => 1 );
	$::lglobal{wclistbox}->delete( '0', 'end' );
	my %display = ();
	my $wordw   = 0;
	my $ssindex = '1.0';
	my $length  = 0;
	return if ( nofileloaded($top) );
	$::lglobal{wclistbox}->insert( 'end', 'Please wait, building list....' );
	$::lglobal{wclistbox}->update;
	my $wholefile = slurpfile();

	while (
		$wholefile =~ m/(\p{Alnum}+\.['"]?\n*\s*['"]?\p{Lower}\p{Alnum}*)/g )
	{
		my $word = $1;
		$wordw++;
		if ( $wordw == 0 ) {

			# FIXME: think this code DOESN'T WORK. skipping
			$word =~ s/<\/?[bidhscalup].*?>//g;
			$word =~ s/(\p{Alnum})'(\p{Alnum})/$1PQzJ$2/g;
			$word =~ s/"/pQzJ/g;
			$word =~ s/(\p{Alnum})\.(\s*\S)/$1PqzJ$2/g;
			$word =~ s/(\p{Alnum})-(\p{Alnum})/$1PLXj$2/g;
			$word =~ s/[^\s\p{Alnum}]//g;
			$word =~ s/PQzJ/'/g;
			$word =~ s/PqzJ/./g;
			$word =~ s/PLXj/-/g;
			$word =~ s/pQzJ/"/g;
			$word =~ s/\P{Alnum}+$//g;
			$word =~ s/\x{d}//g;
		}
		$word =~ s/\n/\\n/g;
		$display{$word}++;
	}
	$::lglobal{saveheader} =
	  "$wordw words with lower case after period. " . '(\n means newline)';
	sortwords( \%display );
	$top->Unbusy;
	::searchoptset(qw/0 x x 1/);
}

sub dashcheck {
	my $top = $::top;
	::operationadd('Check emdashes');
	$top->Busy( -recurse => 1 );
	$::lglobal{wclistbox}->delete( '0', 'end' );
	$::lglobal{wclistbox}->insert( 'end', 'Please wait, building list....' );
	$::lglobal{wclistbox}->update;
	$::lglobal{wclistbox}->delete( '0', 'end' );
	my $wordw   = 0;
	my $wordwo  = 0;
	my %display = ();

	foreach my $word ( keys %{ $::lglobal{seenwordsdoublehyphen} } ) {
		next if ( $::lglobal{seenwordsdoublehyphen}->{$word} < 1 );
		if ( $word =~ /-/ ) {
			$wordw++;
			my $wordtemp = $word;
			$display{$word} = $::lglobal{seenwordsdoublehyphen}->{$word}
			  unless $::lglobal{suspects_only};
			$word =~ s/--/-/g;

			#$word =~ s/—/-/g; # dp2rst creates real em-dashes
			if ( $::lglobal{seenwords}->{$word} ) {
				my $aword = $word . ' ****';
				$display{$wordtemp} =
				  $::lglobal{seenwordsdoublehyphen}->{$wordtemp}
				  if $::lglobal{suspects_only};
				$display{$aword} = $::lglobal{seenwords}->{$word};
				$wordwo++;
			}
		}
	}
	$::lglobal{saveheader} =
	  "$wordw emdash phrases, $wordwo suspects (marked with ****).";
	sortwords( \%display );
	::searchoptset(qw /0 x x 0/);
	$top->Unbusy;
}

sub alphanumcheck {
	my $top = $::top;
	::operationadd('Check alpha/num');
	$top->Busy( -recurse => 1 );
	my %display = ();
	$::lglobal{wclistbox}->delete( '0', 'end' );
	$::lglobal{wclistbox}
	  ->insert( 'end', 'Please wait, building word list....' );
	$::lglobal{wclistbox}->update;
	$::lglobal{wclistbox}->delete( '0', 'end' );
	my $wordw = 0;

	foreach ( keys %{ $::lglobal{seenwords} } ) {
		next unless ( $_ =~ /\d/ );
		next unless ( $_ =~ /\p{Alpha}/ );
		$wordw++;
		$display{$_} = $::lglobal{seenwords}->{$_};
	}
	$::lglobal{saveheader} = "$wordw mixed alphanumeric words.";
	sortwords( \%display );
	$::lglobal{wclistbox}->yview( 'scroll', 1, 'units' );
	$::lglobal{wclistbox}->update;
	$::lglobal{wclistbox}->yview( 'scroll', -1, 'units' );
	::searchoptset(qw/0 x x 0/);
	$top->Unbusy;
}

sub capscheck {
	my $top = $::top;
	::operationadd('Check ALL CAPS');
	$top->Busy( -recurse => 1 );
	$::lglobal{wclistbox}->delete( '0', 'end' );
	$::lglobal{wclistbox}
	  ->insert( 'end', 'Please wait, building word list....' );
	$::lglobal{wclistbox}->update;
	my %display = ();
	my $wordw   = 0;

	foreach ( keys %{ $::lglobal{seenwords} } ) {
		next if ( $_ =~ /\p{IsLower}/ );
		if ( $_ =~ /\p{IsUpper}+(?!\p{IsLower})/ ) {
			$wordw++;
			$display{$_} = $::lglobal{seenwords}->{$_};
		}
	}
	$::lglobal{saveheader} = "$wordw distinct capitalized words.";
	sortwords( \%display );
	::searchoptset(qw/1 x x 0/);
	$top->Unbusy;
}

sub mixedcasecheck {
	my $top = $::top;
	::operationadd('Check MiXeD CasE');
	$top->Busy( -recurse => 1 );
	$::lglobal{wclistbox}->delete( '0', 'end' );
	$::lglobal{wclistbox}
	  ->insert( 'end', 'Please wait, building word list....' );
	$::lglobal{wclistbox}->update;
	my %display = ();
	my $wordw   = 0;

	foreach ( sort ( keys %{ $::lglobal{seenwords} } ) ) {
		next unless ( $_ =~ /\p{IsUpper}/ );
		next unless ( $_ =~ /\p{IsLower}/ );
		next if ( $_ =~ /^\p{Upper}[\p{IsLower}\d'-]+$/ );
		$wordw++;
		$display{$_} = $::lglobal{seenwords}->{$_};
	}
	$::lglobal{saveheader} = "$wordw distinct mixed case words.";
	sortwords( \%display );
	::searchoptset(qw/1 x x 0/);
	$top->Unbusy;
}

# Refactor various word frequency checks into one
sub anythingwfcheck {
	my ( $checktype, $checkregexp ) = @_;
	my $top = $::top;
	::operationadd( 'Check ' . $checktype );
	$::lglobal{wclistbox}->delete( '0', 'end' );
	if ( not ::isvalid($checkregexp) ) {
		$::lglobal{wclistbox}
		  ->insert( 'end', "Invalid regular expression: $checkregexp" );
		$::lglobal{wclistbox}->update;
		return;
	}
	$::lglobal{wclistbox}
	  ->insert( 'end', 'Please wait, building word list....' );
	$::lglobal{wclistbox}->update;
	$top->Busy( -recurse => 1 );
	my %display = ();
	my $wordw   = 0;
	foreach ( sort ( keys %{ $::lglobal{seenwords} } ) ) {
		next unless ( $_ =~ /$checkregexp/ );
		$wordw++;
		$display{$_} = $::lglobal{seenwords}->{$_};
	}
	$::lglobal{saveheader} = "$wordw distinct $checktype.";
	sortwords( \%display );
	::searchoptset(qw/1 x x 0/);
	$top->Unbusy;
}

sub accentcheck {
	my $top = $::top;
	::operationadd('Check Accents');
	$top->Busy( -recurse => 1 );
	$::lglobal{wclistbox}->delete( '0', 'end' );
	$::lglobal{wclistbox}
	  ->insert( 'end', 'Please wait, building word list....' );
	my %display = ();
	my %accent  = ();
	$::lglobal{wclistbox}->update;
	my $wordw  = 0;
	my $wordwo = 0;

	foreach my $word ( keys %{ $::lglobal{seenwords} } ) {
		if ( $word =~
			/[\xC0-\xCF\xD1-\xD6\xD9-\xDD\xE0-\xEF\xF1-\xF6\xF9-\xFD]/ )
		{
			$wordw++;
			my $wordtemp = $word;
			$display{$word} = $::lglobal{seenwords}->{$word}
			  unless $::lglobal{suspects_only};
			my @dwords = ( ::deaccentsort($word) );
			if ( $word =~ s/\xC6/Ae/ ) {
				push @dwords, ( ::deaccentsort($word) );
			}
			for my $wordd (@dwords) {
				my $line;
				$line =
				  sprintf( "%-8d %s", $::lglobal{seenwords}->{$wordd}, $wordd )
				  if $::lglobal{seenwords}->{$wordd};
				if ( $::lglobal{seenwords}->{$wordd} ) {
					$display{$wordtemp} = $::lglobal{seenwords}->{$wordtemp}
					  if $::lglobal{suspects_only};
					$display{ $wordd . ' ****' } =
					  $::lglobal{seenwords}->{$wordd};
					$wordwo++;
				}
			}
			$accent{$word}++;
		}
	}
	$::lglobal{saveheader} =
	  "$wordw accented words, $wordwo suspects (marked with ****).";
	sortwords( \%display );
	::searchoptset(qw/0 x x 0/);
	$top->Unbusy;
}

sub commark {
	my $top = $::top;
	::operationadd('Check , Upper');
	$top->Busy( -recurse => 1 );
	$::lglobal{wclistbox}->delete( '0', 'end' );
	my %display = ();
	my $wordw   = 0;
	my $ssindex = '1.0';
	my $length;
	return if ( nofileloaded($top) );
	$::lglobal{wclistbox}->insert( 'end', 'Please wait, building list....' );
	$::lglobal{wclistbox}->update;
	my $wholefile = slurpfile();

	if ($::intelligentWF) {

		# Skip if pattern is: . Hello, John
		$wholefile =~
s/([\.\?\!]['"]*[\n\s]['"]*\p{Upper}\p{Alnum}*),([\n\s]['"]*\p{Upper})/$1 $2/g;

		# Skip if pattern is: \n\nHello, John
		$wholefile =~
		  s/(\n\n *['"]*\p{Upper}\p{Alnum}*),( ['"]*\p{Upper})/$1 $2/g;
	}
	while (
		$wholefile =~ m/,(['"]*\n*\s*['"]*\p{Upper}\p{Alnum}*)([\.\?\!]?)/g )
	{
		my $word = $1;
		next
		  if $::intelligentWF
			  && $2
			  && $2 ne '';    # ignore if word followed by period, !, or ?
		$wordw++;
		if ( $wordw == 0 ) {

			# FIXME: think this code DOESN'T WORK. skipping
			$word =~ s/<\/?[bidhscalup].*?>//g;
			$word =~ s/(\p{Alnum})'(\p{Alnum})/$1PQzJ$2/g;
			$word =~ s/"/pQzJ/g;
			$word =~ s/(\p{Alnum})\.(\p{Alnum})/$1PqzJ$2/g;
			$word =~ s/(\p{Alnum})-(\p{Alnum})/$1PLXJ$2/g;
			$word =~ s/[^\s\p{Alnum}]//g;
			$word =~ s/PQzJ/'/g;
			$word =~ s/PqzJ/./g;
			$word =~ s/PLXJ/-/g;
			$word =~ s/pQzJ/"/g;
			$word =~ s/\P{Alnum}+$//g;
			$word =~ s/\x{d}//g;
		}
		$word =~ s/\n/\\n/g;
		$display{ ',' . $word }++;
	}
	$::lglobal{saveheader} =
	  "$wordw words with uppercase following commas. " . '(\n means newline)';
	sortwords( \%display );
	$top->Unbusy;
	::searchoptset(qw/0 0 x 1/);
}

sub itwords {
	my $top = $::top;
	::operationadd('Check Ital/Bold/SC');
	$top->Busy( -recurse => 1 );
	$::lglobal{wclistbox}->delete( '0', 'end' );
	my %display  = ();
	my $wordw    = 0;
	my $suspects = '0';
	my %words;
	my $ssindex = '1.0';
	my $length;
	return if ( nofileloaded($top) );
	$::lglobal{wclistbox}->insert( 'end', 'Please wait, building list....' );
	$::lglobal{wclistbox}->update;
	my $wholefile = slurpfile();
	$::markupthreshold = 0 unless $::markupthreshold;

	while ( $wholefile =~ m/(<(i|I|b|B|sc)>)(.*?)(<\/(i|I|b|B|sc)>)/sg ) {
		my $word   = $1 . $3 . $4;
		my $wordwo = $3;
		my $num    = 0;
		$num++ while ( $word =~ /(\S\s)/g );
		next if ( $num >= $::markupthreshold );
		$word =~ s/\n/\\n/g;
		$display{$word}++;
		$wordwo =~ s/\n/\\n/g;
		$words{$wordwo} = $display{$word};
	}
	$wordw = scalar keys %display;
	for my $wordwo ( keys %words ) {
		my $wordwo2 = $wordwo;
		$wordwo2 =~ s/\\n/\n/g;
		while ( $wholefile =~ m/(?<=\W)\Q$wordwo2\E(?=\W)/sg ) {
			$display{$wordwo}++;
		}
		$display{$wordwo} = $display{$wordwo} - $words{$wordwo}
		  if ( ( $words{$wordwo} ) || ( $display{$wordwo} =~ /\\n/ ) );
		delete $display{$wordwo} unless $display{$wordwo};
	}
	$suspects = ( scalar keys %display ) - $wordw;
	$::lglobal{saveheader} =
"$wordw words/phrases with markup, $suspects similar without. (\\n means newline)";
	$wholefile = ();
	sortwords( \%display );
	$top->Unbusy;
	::searchoptset(qw/1 x x 0/);
}

sub ital_adjust {
	my $top = $::top;
	return if $::lglobal{markuppop};
	$::lglobal{markuppop} = $top->Toplevel( -title => 'Word count threshold', );
	my $f0 =
	  $::lglobal{markuppop}->Frame->pack( -side => 'top', -anchor => 'n' );
	$f0->Label( -text =>
"Threshold word count for marked up phrase.\nPhrases with more words will be skipped.\nDefault is 4."
	)->pack;
	my $f1 =
	  $::lglobal{markuppop}->Frame->pack( -side => 'top', -anchor => 'n' );
	$f1->Entry(
		-width        => 10,
		-background   => $::bkgcolor,
		-relief       => 'sunken',
		-textvariable => \$::markupthreshold,
		-validate     => 'key',
		-vcmd         => sub {
			return 1 unless $_[1];
			return 1 unless ( $_[1] =~ /\D/ );
			return 0;
		},
	)->grid( -row => 1, -column => 1, -padx => 2, -pady => 4 );
	$f1->Button(
		-activebackground => $::activecolor,
		-command          => sub {
			$::lglobal{markuppop}->destroy;
			undef $::lglobal{markuppop};
		},
		-text  => 'OK',
		-width => 8
	)->grid( -row => 2, -column => 1, -padx => 2, -pady => 4 );
}

sub hyphencheck {
	my $top = $::top;
	::operationadd('Check hyphens');
	$top->Busy( -recurse => 1 );
	$::lglobal{wclistbox}->delete( '0', 'end' );
	$::lglobal{wclistbox}
	  ->insert( 'end', 'Please wait, building word list....' );
	$::lglobal{wclistbox}->update;
	my $wordw   = 0;
	my $wordwo  = 0;
	my %display = ();

	foreach my $word ( keys %{ $::lglobal{seenwords} } ) {
		next if ( $::lglobal{seenwords}->{$word} < 1 );

		# For words with hyphens
		if ( $word =~ /-/ ) {
			$wordw++;
			my $wordtemp = $word;

			# display all words with hyphens unless suspects only is chosen
			$display{$word} = $::lglobal{seenwords}->{$word}
			  unless $::lglobal{suspects_only};

			# Check if the same word also appears with a double hyphen
			$word =~ s/-/--/g;
			if ( $::lglobal{seenwordsdoublehyphen}->{$word} ) {

				# display with single and with double hyphen
				$display{ $wordtemp . ' ****' } =
				  $::lglobal{seenwords}->{$wordtemp}
				  if $::lglobal{suspects_only};
				my $aword = $word . ' ****';
				$display{ $word . ' ****' } =
				  $::lglobal{seenwordsdoublehyphen}->{$word};
				$wordwo++;
			}

			# Check if the same word also appears with space
			$word =~ s/-/ /g;
			$word =~ s/  / /g;
			if (   $::twowordsinhyphencheck
				&& $::lglobal{seenwordpairs}->{$word} )
			{
				my $aword = $word . ' ****';
				$display{$aword} = $::lglobal{seenwordpairs}->{$word};
				$display{ $wordtemp . ' ****' } =
				  $::lglobal{seenwords}->{$wordtemp}
				  if $::lglobal{suspects_only};
				$wordwo++;
			}

			# Check if the same word also appears without a space or hyphen
			$word =~ s/ //g;
			if ( $::lglobal{seenwords}->{$word} ) {
				$display{ $wordtemp . ' ****' } =
				  $::lglobal{seenwords}->{$wordtemp}
				  if $::lglobal{suspects_only};
				my $aword = $word . ' ****';
				$display{$aword} = $::lglobal{seenwords}->{$word};
				$wordwo++;
			}
		}
	}
	if ($::twowordsinhyphencheck)
	{
		foreach my $word ( keys %{ $::lglobal{seenwordpairs} } ) {
			next if ( $::lglobal{seenwordpairs}->{$word} < 1 );    # never true
			     # For each pair of consecutive words
			if ( $word =~ / / ) {    #always true
				my $wordtemp = $word;

				# Check if the same word also appears without a space
				$word =~ s/ //g;
				if ( $::lglobal{seenwords}->{$word} ) {
					$display{ $word . ' ****' } =
					  $::lglobal{seenwords}->{$word};
					my $aword = $wordtemp . ' ****';
					$display{$aword} = $::lglobal{seenwordpairs}->{$wordtemp}
					  unless $display{$aword};
					$wordwo++;
				}
				$word =~ s/-//g;
				if ( $::lglobal{seenwords}->{$word} ) {
					$display{ $word . ' ****' } =
					  $::lglobal{seenwords}->{$word};
					my $aword = $wordtemp . ' ****';
					$display{$aword} = $::lglobal{seenwordpairs}->{$wordtemp}
					  unless $display{$aword};
					$wordwo++;
				}
			}
		}
	}
	$::lglobal{saveheader} =
	  "$wordw words with hyphens, $wordwo suspects (marked ****).";
	sortwords( \%display );
	$top->Unbusy;
}

sub wordfrequencygetmisspelled {
	$::lglobal{misspelledlist} = ();
	my ( $words, $uwords );
	my $wordw = 0;
	foreach ( sort ( keys %{ $::lglobal{seenwords} } ) ) {
		$words .= "$_\n";
	}
	if ($words) {
		::getmisspelledwords($words);
	}
	if ( $::lglobal{misspelledlist} ) {
		foreach ( sort @{ $::lglobal{misspelledlist} } ) {
			$::lglobal{spellsort}->{$_} = $::lglobal{seenwords}->{$_} || '0';
			$wordw++;
		}
	}
	return $wordw;
}

sub wordfrequencyspellcheck {
	my $top = $::top;
	::operationadd('Check spelling wordfrequency');
	::spelloptions() unless $::globalspellpath;
	return unless $::globalspellpath;
	$top->Busy( -recurse => 1 );
	$::lglobal{wclistbox}->delete( '0', 'end' );
	$::lglobal{wclistbox}
	  ->insert( 'end', 'Please wait, building word list....' );
	$::lglobal{wclistbox}->update;
	my $wordw = wordfrequencygetmisspelled();
	$::lglobal{saveheader} = "$wordw words not recognised by the spellchecker.";
	sortwords( \%{ $::lglobal{spellsort} } );
	$top->Unbusy;
}

sub charsortcheck {
	my $textwindow = $::textwindow;
	my $top        = $::top;
	::operationadd('Check Character Cnts');
	$top->Busy( -recurse => 1 );
	$::lglobal{wclistbox}->delete( '0', 'end' );
	my %display = ();
	my %chars;
	my $index    = '1.0';
	my $end      = $textwindow->index('end');
	my $wordw    = 0;
	my $filename = $textwindow->FileName;
	return if ( nofileloaded($top) );
	$::lglobal{wclistbox}->insert( 'end', 'Please wait, building list....' );
	$::lglobal{wclistbox}->update;
	::savefile() unless ( $textwindow->numberChanges == 0 );
	open my $fh, '<', $filename;

	while ( my $line = <$fh> ) {
		utf8::decode($line);
		$line =~ s/^\x{FEFF}?// if ( $. < 2 );    # Drop the BOM!
		if ( $::lglobal{ignore_case} ) { $line = lc($line) }
		my @words = split( //, $line );
		foreach (@words) {
			$chars{$_}++;
			$wordw++;
		}
		$index++;
		$index .= '.0';
	}
	close $fh;
	my ( $last_line, $last_col ) = split( /\./, $textwindow->index('end') );
	$wordw += ( $last_line - 2 );
	foreach ( keys %chars ) {
		next if ( $chars{$_} < 1 );
		next if ( $_ =~ / / );
		if ( $_ =~ /\t/ ) { $display{'*tab*'} = $chars{$_}; next }
		$display{$_} = $chars{$_};
	}
	$display{'*newline*'} = $last_line - 2;
	$display{'*space*'}   = $chars{' '};
	$display{'*nbsp*'}    = $chars{"\xA0"} if $chars{"\xA0"};
	delete $display{"\xA0"}  if $chars{"\xA0"};
	delete $display{"\x{d}"} if $chars{"\x{d}"};
	delete $display{"\n"}    if $chars{"\n"};
	$::lglobal{saveheader} = "$wordw characters in the file.";
	sortwords( \%display );
	::searchoptset(qw/0 x x 0/);
	$top->Unbusy;
}

sub stealthcheck {
	my $top        = $::top;
	my $textwindow = $::textwindow;
	::operationadd('Check Stealthos Word Frequency');
	::loadscannos();
	$top->Busy( -recurse => 1 );
	$::lglobal{wclistbox}->delete( '0', 'end' );
	$::lglobal{wclistbox}->insert( 'end', 'Please wait, building list....' );
	$::lglobal{wclistbox}->update;
	my %display = ();
	my ( $line, $word, %list, @words, $scanno );
	my $index = '1.0';
	my $end   = $textwindow->index('end');
	my $wordw = 0;

	while ( ( $scanno, $word ) = each(%::scannoslist) ) {
		$list{$word}   = '';
		$list{$scanno} = '';
	}
	foreach my $word ( keys %{ $::lglobal{seenwords} } ) {
		next unless exists( $list{$word} );
		$wordw++;
		$display{$word} = $::lglobal{seenwords}->{$word};
	}
	$::lglobal{saveheader} = "$wordw suspect words found in file.";
	sortwords( \%display );
	::searchoptset(qw/1 x x 0/);
	$top->Unbusy;
}

sub harmonicspop {
	my $top = shift;
	my ( $line, $word, $sword, $snum, @savesets, $wc );
	if ( $::lglobal{hpopup} ) {
		$::lglobal{hpopup}->deiconify;
		$::lglobal{hpopup}->raise;
		$::lglobal{hlistbox}->delete( '0', 'end' );
	} else {
		$::lglobal{hpopup} = $top->Toplevel;
		$::lglobal{hpopup}->title('Word harmonics');
		::initialize_popup_with_deletebinding('hpopup');
		my $frame =
		  $::lglobal{hpopup}
		  ->Frame->pack( -fill => 'both', -expand => 'both', );
		$::lglobal{hlistbox} = $frame->Scrolled(
			'Listbox',
			-scrollbars  => 'se',
			-background  => $::bkgcolor,
			-font        => $::lglobal{font},
			-selectmode  => 'single',
			-activestyle => 'none',
		  )->pack(
			-anchor => 'nw',
			-fill   => 'both',
			-expand => 'both',
			-padx   => 2,
			-pady   => 2
		  );
		::drag( $::lglobal{hlistbox} );
		$::lglobal{hpopup}->protocol(
			'WM_DELETE_WINDOW' => sub {
				$::lglobal{hpopup}->destroy;
				undef $::lglobal{hpopup};
				undef $::lglobal{hlistbox};
			}
		);
		::BindMouseWheel( $::lglobal{hlistbox} );
		$::lglobal{hlistbox}->eventAdd( '<<search>>' => '<ButtonRelease-3>' );
		$::lglobal{hlistbox}->bind(
			'<<search>>',
			sub {
				$::lglobal{hlistbox}->selectionClear( 0, 'end' );
				$::lglobal{hlistbox}->selectionSet(
					$::lglobal{hlistbox}->index(
						'@'
						  . (
							$::lglobal{hlistbox}->pointerx -
							  $::lglobal{hlistbox}->rootx
						  )
						  . ','
						  . (
							$::lglobal{hlistbox}->pointery -
							  $::lglobal{hlistbox}->rooty
						  )
					)
				);
				my ($sword) =
				  $::lglobal{hlistbox}
				  ->get( $::lglobal{hlistbox}->curselection );
				::searchpopup();
				$sword =~ s/\d+\s+([\w'-]*)/$1/;
				$sword =~ s/\s+\*\*\*\*$//;
				$::lglobal{searchentry}->delete( '1.0', 'end' );
				$::lglobal{searchentry}->insert( 'end', $sword );
				::updatesearchlabels();
				$::lglobal{searchentry}->after( $::lglobal{delay} );
			}
		);
		$::lglobal{hlistbox}->eventAdd( '<<find>>' => '<Double-Button-1>' );
		$::lglobal{hlistbox}->bind(
			'<<find>>',
			sub {
				return unless $::lglobal{hlistbox}->index('active');
				$top->Busy( -recurse => 1 );
				$sword = $::lglobal{hlistbox}->get('active');
				return unless ( $::lglobal{hlistbox}->curselection );
				$sword =~ s/(\d+)\s+([\w'-]*)/$2/;
				$snum = $1;
				$sword =~ s/\s+\*\*\*\*$//;
				@savesets = @::sopt;

				unless ($snum) {
					::searchoptset(qw/0 x x 1/);
					$sword = "(?<=-)$sword|$sword(?=-)";
				}
				::searchfromstartifnew($sword);
				::searchtext($sword);
				::searchoptset(@savesets);
				$top->Unbusy( -recurse => 1 );
			}
		);
		$::lglobal{hlistbox}->bind(
			'<Down>',
			sub {
				return unless defined $::lglobal{wclistbox};
				my $index = $::lglobal{wclistbox}->index('active');
				$::lglobal{wclistbox}->selectionClear( '0', 'end' );
				$::lglobal{wclistbox}->activate( $index + 1 );
				$::lglobal{wclistbox}->selectionSet( $index + 1 );
				$::lglobal{wclistbox}->see('active');
				harmonics( $::lglobal{wclistbox}->get('active') );
				harmonicspop();
				$::lglobal{hpopup}->break;
			}
		);
		$::lglobal{hlistbox}->bind(
			'<Up>',
			sub {
				return unless defined $::lglobal{wclistbox};
				my $index = $::lglobal{wclistbox}->index('active');
				$::lglobal{wclistbox}->selectionClear( '0', 'end' );
				$::lglobal{wclistbox}->activate( $index - 1 );
				$::lglobal{wclistbox}->selectionSet( $index - 1 );
				$::lglobal{wclistbox}->see('active');
				harmonics( $::lglobal{wclistbox}->get('active') );
				harmonicspop();
				$::lglobal{hpopup}->break;
			}
		);
		$::lglobal{hlistbox}->eventAdd( '<<harm>>' => '<Control-Button-1>' );
		$::lglobal{hlistbox}->bind(
			'<<harm>>',
			sub {
				return unless ( $::lglobal{hlistbox}->curselection );
				harmonics( $::lglobal{hlistbox}->get('active') );
				harmonicspop();
			}
		);
	}
	my $active = $::lglobal{wclistbox}->get('active');
	$active =~ s/\d+\s+([\w'-]*)/$1/;
	$active =~ s/\*\*\*\*$//;
	$active =~ s/\s//g;
	$::lglobal{hlistbox}->insert( 'end', 'Please wait... searching...' );
	$::lglobal{hlistbox}->update;
	if ( defined $::lglobal{harmonics} && $::lglobal{harmonics} == 2 ) {
		harmonics2($active);
		$wc = scalar( keys( %{ $::lglobal{harmonic} } ) );
		$::lglobal{hlistbox}->delete( '0', 'end' );
		$::lglobal{hlistbox}
		  ->insert( 'end', "$wc 2nd order harmonics for $active." );
	} else {
		harmonics($active);
		$wc = scalar( keys( %{ $::lglobal{harmonic} } ) );
		$::lglobal{hlistbox}->delete( '0', 'end' );
		$::lglobal{hlistbox}
		  ->insert( 'end', "$wc 1st order harmonics for $active." );
	}
	foreach my $word ( sort { ::deaccentsort( lc $a ) cmp ::deaccentsort( lc $b ) }
		( keys %{ $::lglobal{harmonic} } ) )
	{
		$line =
		  sprintf( "%-8d %s", $::lglobal{seenwords}->{$word}, $word )
		  ;    # Print to the file
		$::lglobal{hlistbox}->insert( 'end', $line );
	}
	%{ $::lglobal{harmonic} } = ();
	$::lglobal{hlistbox}->focus;
}

sub harmonics {
	my $word = shift;
	$word =~ s/\d+\s+([\w'-]*)/$1/;
	$word =~ s/\*\*\*\*$//;
	$word =~ s/\s//g;
	my $length = length $word;
	for my $test ( keys %{ $::lglobal{seenwords} } ) {
		next if ( abs( $length - length $test ) > 1 );
		$::lglobal{harmonic}{$test} = 1 if ( distance( $word, $test ) <= 1 );
	}
}

sub harmonics2 {
	my $word = shift;
	$word =~ s/\d+\s+([\w'-]*)/$1/;
	$word =~ s/\*\*\*\*$//;
	$word =~ s/\s//g;
	my $length = length $word;
	for my $test ( keys %{ $::lglobal{seenwords} } ) {
		next if ( abs( $length - length $test ) > 2 );
		$::lglobal{harmonic}{$test} = 1 if ( distance( $word, $test ) <= 2 );
	}
}
#### Levenshtein edit distance calculations #################
#### taken from the Text::Levenshtein Module ################
#### If available, uses Text::LevenshteinXS #################
#### which is orders of magnitude faster. ###################
sub distance {
	if ( $::lglobal{LevenshteinXS} ) {
		return Text::LevenshteinXS::distance(@_);
	}
	no warnings;
	my $word1 = shift;
	my $word2 = shift;
	return 0 if $word1 eq $word2;
	my @d;
	my $len1 = length $word1;
	my $len2 = length $word2;
	$d[0][0] = 0;

	for ( 1 .. $len1 ) {
		$d[$_][0] = $_;
		return $_
		  if $_ != $len1 && substr( $word1, $_ ) eq substr( $word2, $_ );
	}
	for ( 1 .. $len2 ) {
		$d[0][$_] = $_;
		return $_
		  if $_ != $len2 && substr( $word1, $_ ) eq substr( $word2, $_ );
	}
	for my $i ( 1 .. $len1 ) {
		my $w1 = substr( $word1, $i - 1, 1 );
		for ( 1 .. $len2 ) {
			$d[$i][$_] = _min(
				$d[ $i - 1 ][$_] + 1,
				$d[$i][ $_ - 1 ] + 1,
				$d[ $i - 1 ][ $_ - 1 ] +
				  ( $w1 eq substr( $word2, $_ - 1, 1 ) ? 0 : 1 )
			);
		}
	}
	return $d[$len1][$len2];
}

sub _min {
	return
	    $_[0] < $_[1]
	  ? $_[0] < $_[2]
		  ? $_[0]
		  : $_[2]
	  : $_[1] < $_[2] ? $_[1]
	  :                 $_[2];
}

sub sortwords {
	my $href = shift;
	$::lglobal{wclistbox}->delete( '0', 'end' );
	$::lglobal{wclistbox}->insert( 'end', 'Please wait, sorting list....' );
	$::lglobal{wclistbox}->update;
	if ( $::alpha_sort eq 'f' ) {    # Sorted by word frequency
		for ( ::natural_sort_freq($href) ) {
			my $line = sprintf( "%-8d %s", $$href{$_}, $_ ); # Print to the file
			$::lglobal{wclistbox}->insert( 'end', $line );
		}
	} elsif ( $::alpha_sort eq 'a' ) {    # Sorted alphabetically
		for ( ::natural_sort_alpha( keys %$href ) ) {
			my $line = sprintf( "%-8d %s", $$href{$_}, $_ ); # Print to the file
			$::lglobal{wclistbox}->insert( 'end', $line );
		}
	} elsif ( $::alpha_sort eq 'l' ) {    # Sorted by word length
		for ( ::natural_sort_length( keys %$href ) ) {
			my $line = sprintf( "%-8d %s", $$href{$_}, $_ ); # Print to the file
			$::lglobal{wclistbox}->insert( 'end', $line );
		}
	}
	$::lglobal{wclistbox}->delete('0');
	$::lglobal{wclistbox}->insert( '0', $::lglobal{saveheader} );
	$::lglobal{wclistbox}->update;
	$::lglobal{wclistbox}->yview( 'scroll', 1, 'units' );
	$::lglobal{wclistbox}->update;
	$::lglobal{wclistbox}->yview( 'scroll', -1, 'units' );
}

sub nofileloaded {
	my $top = shift;
	if ( $::lglobal{global_filename} =~ m/No File Loaded/ ) {
		$::lglobal{wclistbox}->insert( 'end', 'Please save the file first.' );
		$::lglobal{wclistbox}->update;
		$top->Unbusy;
		return 1;
	}
}

sub add_navigation_events {
	my ($dialog_box) = @_;
	$dialog_box->eventAdd(
		'<<pnext>>' => '<Next>',
		'<Prior>', '<Up>', '<Down>'
	);
	$dialog_box->bind(
		'<<pnext>>',
		sub {
			$dialog_box->selectionClear( 0, 'end' );
			$dialog_box->selectionSet( $dialog_box->index('active') );
		}
	);
	$dialog_box->bind(
		'<Home>',
		sub {
			$dialog_box->selectionClear( 0, 'end' );
			$dialog_box->see(0);
			$dialog_box->selectionSet(1);
			$dialog_box->activate(1);
		}
	);
	$dialog_box->bind(
		'<End>',
		sub {
			$dialog_box->selectionClear( 0, 'end' );
			$dialog_box->see( $dialog_box->index('end') );
			$dialog_box->selectionSet( $dialog_box->index('end') - 1 );
			$dialog_box->activate( $dialog_box->index('end') - 1 );
		}
	);
}

sub slurpfile {
	my $textwindow = $::textwindow;
	my $filename   = $textwindow->FileName;
	my $wholefile;
	::savefile() unless ( $textwindow->numberChanges == 0 );
	{
		local $/;    # slurp in the file
		open my $fh, '<', $filename;
		$wholefile = <$fh>;
		close $fh;
		utf8::decode($wholefile);
	}
	$wholefile =~ s/-----*\s?File:\s?\S+\.(png|jpg)---.*\r?\n?//g;
	return $wholefile;
}
1;
