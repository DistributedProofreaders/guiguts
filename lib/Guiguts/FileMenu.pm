package Guiguts::FileMenu;
use strict;
use warnings;

BEGIN {
	use Exporter();
	our ( @ISA, @EXPORT );
	@ISA = qw(Exporter);
	@EXPORT =
	  qw(&file_open &file_saveas &file_savecopyas &file_include &file_export_preptext &file_import_preptext &_bin_save &file_close
	  &_flash_save &clearvars &savefile &_exit &file_mark_pages &_recentupdate &file_guess_page_marks
	  &oppopupdate &opspop_up &confirmempty &openfile &readsettings &savesettings &file_export_pagemarkup
	  &file_import_markup &operationadd &isedited &setedited);
}

sub file_open {    # Find a text file to open
	my $textwindow = shift;
	my ($name);
	return if ( ::confirmempty() =~ /cancel/i );
	my $types = [
		[
			'Text Files',
			[qw/.txt .text .ggp .htm .html .rst .bk1 .bk2 .xml .tei/]
		],
		[ 'All Files', ['*'] ],
	];
	$name = $textwindow->getOpenFile(
		-filetypes  => $types,
		-title      => 'Open File',
		-initialdir => $::globallastpath
	);
	if ( defined($name) and length($name) ) {
		::openfile($name);
	}
}

sub file_include {    # FIXME: Should include even if no file loaded.
	my $textwindow = shift;
	my ($name);
	my $types = [
		[
			'Text Files',
			[
				'.txt', '.text', '.ggp', '.htm', '.html', '.rst', '.tei', '.xml'
			]
		],
		[ 'All Files', ['*'] ],
	];
	return if $::lglobal{global_filename} =~ m{No File Loaded};
	$name = $textwindow->getOpenFile(
		-filetypes  => $types,
		-title      => 'File Include',
		-initialdir => $::globallastpath
	);
	$textwindow->IncludeFile($name)
	  if defined($name)
		  and length($name);
	::update_indicators();
	return;
}

sub file_saveas {
	my $textwindow = shift;
	::hidepagenums();
	my $name = $textwindow->getSaveFile(
		-title      => 'Save As',
		-initialdir => $::globallastpath
	);
	if ( defined($name) and length($name) ) {
		my $binname = $name;
		$binname =~ s/\.[^\.]*?$/\.bin/;
		if ( $binname eq $name ) { $binname .= '.bin' }
		if ( -e $binname ) {
			my $warning = $::top->Dialog(    # FIXME: heredoc
				-text =>
"WARNING! A file already exists that will use the same .bin filename.\n"
				  . "It is highly recommended that a different file name is chosen to avoid\n"
				  . "corrupting the .bin files.\n\n Are you sure you want to continue?",
				-title          => 'Bin File Collision!',
				-bitmap         => 'warning',
				-buttons        => [qw/Continue Cancel/],
				-default_button => qw/Cancel/,
			);
			my $answer = $warning->Show;
			return unless ( $answer eq 'Continue' );
		}
		$textwindow->SaveUTF($name);
		my ( $fname, $extension, $filevar );
		( $fname, $::globallastpath, $extension ) = ::fileparse($name);
		$::globallastpath = ::os_normal($::globallastpath);
		$name             = ::os_normal($name);
		$textwindow->FileName($name);
		$::lglobal{global_filename} = $name;
		_bin_save();
		::_recentupdate($name);
	} else {
		return;
	}
	$textwindow->ResetUndo;    #necessary to reset edited flag
	::setedited(0);
	::update_indicators();
	return;
}

sub file_savecopyas {
	my $textwindow = shift;
	::hidepagenums();
	my $name = $textwindow->getSaveFile(
		-title       => 'Save As',
		-initialdir  => $::globallastpath,
		-initialfile => $::lglobal{global_filename},
	);
	if ( defined($name) and length($name) ) {
		my $binname = $name;
		$binname =~ s/\.[^\.]*?$/\.bin/;
		if ( $binname eq $name ) { $binname .= '.bin' }
		if ( -e $binname ) {
			my $warning = $::top->Dialog(    # FIXME: heredoc
				-text =>
				    "WARNING! A file already exists that will use the same .bin filename.\n"
				  . "It is highly recommended that a different file name is chosen to avoid\n"
				  . "corrupting the .bin files.\n\n Are you sure you want to continue?",
				-title          => 'Bin File Collision!',
				-bitmap         => 'warning',
				-buttons        => [qw/Continue Cancel/],
				-default_button => qw/Cancel/,
			);
			my $answer = $warning->Show;
			return unless ( $answer eq 'Continue' );
		}
		$textwindow->SaveUTF($name);
		$name             = ::os_normal($name);
		my $oldfilename = $::lglobal{global_filename};
		$::lglobal{global_filename} = $name; # first do a bin_save, then restore the file name
		_bin_save();
		$::lglobal{global_filename} = $oldfilename;
		$textwindow->FileName($oldfilename);
		::_recentupdate($name);
	} else {
		return;
	}
	return;
}

sub file_close {
	my $textwindow = shift;
	return if ( ::confirmempty() =~ m{cancel}i );
	::hidepagenums();
	clearvars($textwindow);
	::update_indicators();
	return;
}

sub file_import_preptext {
	my ( $textwindow, $top ) = @_;
	return if ( ::confirmempty() =~ /cancel/i );
	my $directory = $top->chooseDirectory( -title =>
		  'Choose the directory containing the text files to be imported.', );
	return 0
	  unless ( defined $directory and -d $directory and $directory ne '' );
	$top->Busy( -recurse => 1 );
	my $pwd = ::getcwd();
	chdir $directory;
	my @files = glob "*.txt";
	chdir $pwd;
	$directory .= '/';
	$directory        = ::os_normal($directory);
	$::globallastpath = $directory;

	for my $file ( sort @files ) {
		if ( $file =~ /^(\w+)\.txt/ ) {
			$textwindow->ntinsert( 'end', ( "\n" . '-' x 5 ) );
			$textwindow->ntinsert( 'end', "File: $1.png" );
			$textwindow->ntinsert( 'end', ( '-' x 45 ) . "\n" );
			if ( open my $fh, '<', "$directory$file" ) {
				local $/ = undef;
				my $line = <$fh>;
				utf8::decode($line);
				$line =~ s/^\x{FEFF}?//;
				$line =~ s/\cM\cJ|\cM|\cJ/\n/g;
				#$line = eol_convert($line);
				$line =~ s/[\t \xA0]+$//smg;
				$textwindow->ntinsert( 'end', $line );
				close $file;
			}
			$top->update;
		}
	}
	$textwindow->markSet( 'insert', '1.0' );
	$::lglobal{prepfile} = 1;
	::file_mark_pages() if ( $::auto_page_marks );
	my $tmppath = $::globallastpath;
	$tmppath =~ s|[^/\\]*[/\\]$||; # go one dir level up
	$tmppath = ::catfile( $tmppath, $::defaultpngspath, '');
	$::pngspath = $tmppath if ( -e $tmppath );
	$top->Unbusy( -recurse => 1 );
	return;
}

sub file_export_preptext {
	my $exporttype       = shift;
	my $top              = $::top;
	my $textwindow       = $::textwindow;
	my $midwordpagebreak = 0;
	my $directory        = $top->chooseDirectory(
		-title => 'Choose the directory to export the text files to.', );
	return 0 unless ( defined $directory and $directory ne '' );
	unless ( -e $directory ) {
		mkdir $directory or warn "Could not make directory $!\n" and return;
	}
	$top->Busy( -recurse => 1 );
	my @marks = $textwindow->markNames;
	my @pages = sort grep ( /^Pg\S+$/, @marks );
	my $unicode = ::currentfileisunicode();
	my ( $f, $globalfilename, $e ) =
	  ::fileparse( $::lglobal{global_filename}, qr{\.[^\.]*$} );
	if ( $exporttype eq 'onefile' ) {
		# delete the existing file
		open my $fh, '>', "$directory/prep.txt";
		close $fh;
	}
	while (@pages) {
		my $page = shift @pages;
		my ($filename) = $page =~ /Pg(\S+)/;
		$filename .= '.txt';
		my $next;
		if (@pages) {
			$next = $pages[0];
		} else {
			$next = 'end';
		}
		my $file = $textwindow->get( $page, $next );
		if ( $midwordpagebreak and ( $exporttype eq 'onefile' ) ) {

			# put the rest of the word after the separator with a *
			$file = '*' . $file;

			# ... with the rest of the word with the following line
			$file =~ s/\n/ /;
			$midwordpagebreak = 0;
		}
		if ( $file =~ '[A-Za-z]$' and ( $exporttype eq 'onefile' ) ) {
			my $nextchar = $textwindow->get( $pages[0], $pages[0] . '+1c' );
			if ( $nextchar =~ '^[A-Za-z]' ) {
				$file .= '-*';
				$midwordpagebreak = 1;
			}
		}
		$file =~ s/-*\s?File:\s?(\S+)\.(png|jpg)---[^\n]*\n//;
		$file =~ s/\n+$//;
		if ($unicode) {
			#$file = "\x{FEFF}" . $file;    # Add the BOM to beginning of file.
			utf8::encode($file);
		}
		if ( $exporttype eq 'onefile' ) {
			open my $fh, '>>', "$directory/prep.txt";
			print $fh $file;
			print $fh ( "\n" . '-' x 5 )
			  . "File: $page.png"
			  . ( '-' x 45 ) . "\n";
			close $fh;
		} else {
			open my $fh, '>', "$directory/$filename";
			print $fh $file;
			close $fh;
		}
	}
	$top->Unbusy( -recurse => 1 );
	return;
}

sub _flash_save {
	$::lglobal{saveflashingid} = $::top->repeat(
		500,
		sub {
			if ( $::lglobal{savetool}->cget('-background') eq 'yellow' ) {
				$::lglobal{savetool}->configure(
					-background       => 'green',
					-activebackground => 'green'
				) unless $::notoolbar;
			} else {
				$::lglobal{savetool}->configure(
					-background       => 'yellow',
					-activebackground => 'yellow'
				) if ( $::textwindow->numberChanges and ( !$::notoolbar ) );
			}
		}
	);
	return;
}

## save the .bin file associated with the text file
sub _bin_save {
	my ( $textwindow, $top ) = ( $::textwindow, $::top );
	my $mark = '1.0';
	while ( $textwindow->markPrevious($mark) ) {
		$mark = $textwindow->markPrevious($mark);
	}
	my $markindex;
	while ($mark) {
		if ( $mark =~ m{Pg(\S+)} ) {
			$markindex                    = $textwindow->index($mark);
			$::pagenumbers{$mark}{offset} = $markindex;
			$mark                         = $textwindow->markNext($mark);
		} else {
			$mark = $textwindow->markNext($mark) if $mark;
			next;
		}
	}
	return if ( $::lglobal{global_filename} =~ m{No File Loaded} );
	my $binname = "$::lglobal{global_filename}.bin";
	if ( $textwindow->markExists('spellbkmk') ) {
		$::spellindexbkmrk = $textwindow->index('spellbkmk');
	}
	my $bak = "$binname.bak";
	if ( -e $bak ) {
		my $perms = ( stat($bak) )[2] & 7777;
		unless ( $perms & 300 ) {
			$perms = $perms | 300;
			chmod $perms, $bak or warn "Can not back up .bin file: $!\n";
		}
		unlink $bak;
	}
	if ( -e $binname ) {
		my $perms = ( stat($binname) )[2] & 7777;
		unless ( $perms & 300 ) {
			$perms = $perms | 300;
			chmod $perms, $binname
			  or warn "Can not save .bin file: $!\n" and return;
		}
		rename $binname, $bak or warn "Can not back up .bin file: $!\n";
	}
	my $fh = FileHandle->new("> $binname");
	if ( defined $fh ) {
		print $fh "\%::pagenumbers = (\n";
		for my $page ( sort { $a cmp $b } keys %::pagenumbers ) {
			no warnings 'uninitialized';
			if ( $page eq "Pg" ) {
				next;
			}
			print $fh " '$page' => {";
			print $fh "'offset' => '$::pagenumbers{$page}{offset}', ";
			print $fh "'label' => '$::pagenumbers{$page}{label}', ";
			print $fh "'style' => '$::pagenumbers{$page}{style}', ";
			print $fh "'action' => '$::pagenumbers{$page}{action}', ";
			print $fh "'base' => '$::pagenumbers{$page}{base}'},\n";
		}
		print $fh ");\n\n";
		delete $::proofers{''};
		foreach my $page ( sort keys %::proofers ) {
			no warnings 'uninitialized';
			for my $round ( 1 .. $::lglobal{numrounds} ) {
				if ( defined $::proofers{$page}->[$round] ) {
					print $fh '$::proofers{\'' 
					  . $page . '\'}[' 
					  . $round
					  . '] = \''
					  . $::proofers{$page}->[$round] . '\';' . "\n";
				}
			}
		}
		print $fh "\n";
		foreach ( keys %::operationshash ) {
			my $mark = ::escape_problems($_);
			print $fh "\$::operationshash{'$mark'}='"
			  . $::operationshash{$mark} . "';\n";
		}
		print $fh "\n";
		print $fh '$::bookmarks[0] = \''
		  . $textwindow->index('insert') . "';\n";
		for ( 1 .. 5 ) {
			print $fh '$::bookmarks[' 
			  . $_ 
			  . '] = \''
			  . $textwindow->index( 'bkmk' . $_ ) . "';\n"
			  if $::bookmarks[$_];
		}
		if ($::pngspath) {
			print $fh
			  "\n\$::pngspath = '@{[::escape_problems($::pngspath)]}';\n\n";
		}
		print $fh "\$::spellindexbkmrk = '$::spellindexbkmrk';\n\n";
		print $fh "\$::projectid = '$::projectid';\n\n";
		print $fh "\$::booklang = '$::booklang';\n\n";
		print $fh
"\$scannoslistpath = '@{[::escape_problems(::os_normal($::scannoslistpath))]}';\n\n";
		print $fh '1;';
		$fh->close;
	} else {
		$top->BackTrace("Cannot open $binname:$!");
	}
	return;
}

## Clear persistent variables before loading another file
sub clearvars {
	my $textwindow = shift;
	my @marks      = $textwindow->markNames;
	for (@marks) {
		unless ( $_ =~ m{insert|current} ) {
			$textwindow->markUnset($_);
		}
	}
	%::reghints = ();
	%{ $::lglobal{seenwordsdoublehyphen} } = ();
	$::lglobal{seenwords}     = ();
	$::lglobal{seenwordpairs} = ();
	$::lglobal{fnarray}       = ();
	%::proofers               = ();
	%::pagenumbers            = ();
	%::operationshash         = ();
	@::operations             = ();
	@::bookmarks              = ();
	$::pngspath               = q{};
	::setedited(0);
	::hidepagenums();
	@{ $::lglobal{fnarray} } = ();
	::tglprfbar() if $::lglobal{proofbarvisible};
	undef $::lglobal{prepfile};
	return;
}

sub savefile {    # Determine which save routine to use and then use it
	my ( $textwindow, $top ) = ( $::textwindow, $::top );
	::hidepagenums();
	if ( $::lglobal{global_filename} =~ /No File Loaded/ ) {
		unless ( ::isedited() ) {
			return;
		}
		my ($name);
		$name = $textwindow->getSaveFile(
			-title      => 'Save As',
			-initialdir => $::globallastpath
		);
		if ( defined($name) and length($name) ) {
			$textwindow->SaveUTF($name);
			$name = ::os_normal($name);
			::_recentupdate($name);
		} else {
			return;
		}
	} else {
		if ($::autobackup) {
			if ( -e $::lglobal{global_filename} ) {
				if ( -e "$::lglobal{global_filename}.bk2" ) {
					unlink "$::lglobal{global_filename}.bk2";
				}
				if ( -e "$::lglobal{global_filename}.bk1" ) {
					rename(
						"$::lglobal{global_filename}.bk1",
						"$::lglobal{global_filename}.bk2"
					);
				}
				rename(
					$::lglobal{global_filename},
					"$::lglobal{global_filename}.bk1"
				);
			}
		}
		$textwindow->SaveUTF;
	}
	$textwindow->ResetUndo;    #necessary to reset edited flag
	::_bin_save();
	::setedited(0);
	::set_autosave() if $::autosave;
	::update_indicators();
}

sub file_mark_pages {
	my $top        = $::top;
	my $textwindow = $::textwindow;
	$top->Busy( -recurse => 1 );
	::hidepagenums();
	my ( $line, $index, $page, $rnd1, $rnd2, $pagemark );
	$::searchstartindex = '1.0';
	$::searchendindex   = '1.0';
	while ($::searchstartindex) {

		#$::searchstartindex =
		#  $textwindow->search( '-exact', '--',
		#					   '--- File:',
		#					   $::searchendindex, 'end' );
		$::searchstartindex =
		  $textwindow->search( '-nocase', '-regexp', '--',
			'-*\s?File:\s?(\S+)\.(png|jpg)---.*$',
			$::searchendindex, 'end' );
		last unless $::searchstartindex;
		my ( $row, $col ) = split /\./, $::searchstartindex;
		$line = $textwindow->get( "$row.0", "$row.end" );
		$::searchendindex = $textwindow->index("$::searchstartindex lineend");

		#$line = $textwindow->get( $::searchstartindex, $::searchendindex );
		# get the page name - we do this separate from pulling the
		# proofer names in case we did an Import Test Prep Files
		# which does not include proofer names
		#  look for one or more dashes followed by File: followed
		#  by zero or more spaces, then non-greedily capture everything
		#  up to the first period
		if ( $line =~ /-+File:\s*(.*?)\./ ) {
			$page = $1;
		}

		# get list of proofers:
		#  look for one or more dashes followed by File:, then
		#  non-greedily ignore everything up to the
		#  string of dashes, ignore the dashes, then capture
		#  everything until the dashes begin again (proofer string)
		#		if ( $line =~ /-+File:.*?-+([^-]+)-+/ ) {
		if ( $line =~ /^-----*\s?File:\s?\S+\.(png|jpg)---(.*)$/ ) {
			my $prftrim = $2;
			$prftrim =~ s/-*$//g;

			# split the proofer string into parts
			@{ $::proofers{$page} } = split( "\Q\\\E", $prftrim );
		}
		$pagemark = 'Pg' . $page;
		$::pagenumbers{$pagemark}{offset} = 1;
		$textwindow->markSet( $pagemark, $::searchstartindex );
		$textwindow->markGravity( $pagemark, 'left' );
	}
	delete $::proofers{''};
	$top->Unbusy( -recurse => 1 );
	return;
}

## Track recently open files for the menu
sub _recentupdate {    # FIXME: Seems to be choking.
	my $name = shift;

	# remove $name or any *empty* values from the list
	@::recentfile = grep( !/(?: \Q$name\E | \Q*empty*\E )/x, @::recentfile );

	# place $name at the top
	unshift @::recentfile, $name;

	# limit the list to the desired number of entries
	pop @::recentfile while ( $#::recentfile >= $::recentfile_size );
	::menurebuild();
	return;
}

## Global Exit
sub _exit {
	if ( confirmdiscard() =~ m{no}i ) {
		::aspellstop() if $::lglobal{spellpid};
		exit;
	}
}

sub file_guess_page_marks {
	my $top        = $::top;
	my $textwindow = $::textwindow;
	my ( $totpages, $line25, $linex );
	if ( $::lglobal{pgpop} ) {
		$::lglobal{pgpop}->deiconify;
	} else {
		$::lglobal{pgpop} = $top->Toplevel;
		$::lglobal{pgpop}->title('Guess Page Numbers');
		::initialize_popup_with_deletebinding('pgpop');
		my $f0 = $::lglobal{pgpop}->Frame->pack;
		$f0->Label( -text =>
'This function should only be used if you have the page images but no page markers in the text.',
		)->grid( -row => 1, -column => 1, -padx => 1, -pady => 2 );
		my $f1 = $::lglobal{pgpop}->Frame->pack;
		$f1->Label( -text => 'How many pages are there total?', )
		  ->grid( -row => 1, -column => 1, -padx => 1, -pady => 2 );
		my $tpages = $f1->Entry(
			-background => $::bkgcolor,
			-width      => 8,
		)->grid( -row => 1, -column => 2, -padx => 1, -pady => 2 );
		$f1->Label( -text => 'What line # does page 25 start with?', )
		  ->grid( -row => 2, -column => 1, -padx => 1, -pady => 2 );
		my $page25 = $f1->Entry(
			-background => $::bkgcolor,
			-width      => 8,
		)->grid( -row => 2, -column => 2, -padx => 1, -pady => 2 );
		my $f3 = $::lglobal{pgpop}->Frame->pack;
		$f3->Label(
			-text => 'Select a page near the back, before the index starts.', )
		  ->grid( -row => 2, -column => 1, -padx => 1, -pady => 2 );
		my $f4 = $::lglobal{pgpop}->Frame->pack;
		$f4->Label( -text => 'Page #?.', )
		  ->grid( -row => 1, -column => 1, -padx => 1, -pady => 2 );
		$f4->Label( -text => 'Line #?.', )
		  ->grid( -row => 1, -column => 2, -padx => 1, -pady => 2 );
		my $pagexe = $f4->Entry(
			-background => $::bkgcolor,
			-width      => 8,
		)->grid( -row => 2, -column => 1, -padx => 1, -pady => 2 );
		my $linexe = $f4->Entry(
			-background => $::bkgcolor,
			-width      => 8,
		)->grid( -row => 2, -column => 2, -padx => 1, -pady => 2 );
		my $f2         = $::lglobal{pgpop}->Frame->pack;
		my $calcbutton = $f2->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				my ( $pnum, $lnum, $pagex, $linex, $number );
				$totpages = $tpages->get;
				$line25   = $page25->get;
				$pagex    = $pagexe->get;
				$linex    = $linexe->get;
				unless ( $totpages && $line25 && $line25 && $linex ) {
					$top->messageBox(
						-icon    => 'error',
						-message => 'Need all values filled in.',
						-title   => 'Missing values',
						-type    => 'Ok',
					);
					return;
				}
				if ( $totpages <= $pagex ) {
					$top->messageBox(
						-icon => 'error',
						-message =>
						  'Selected page must be lower than total pages',
						-title => 'Bad value',
						-type  => 'Ok',
					);
					return;
				}
				if ( $linex <= $line25 ) {
					$top->messageBox(
						-icon    => 'error',
						-message => "Line number for selected page must be \n"
						  . "higher than that of page 25",
						-title => 'Bad value',
						-type  => 'Ok',
					);
					return;
				}
				my $end = $textwindow->index('end');
				$end = int( $end + .5 );
				my $average = ( int( $line25 + .5 ) / 25 );
				for my $pnum ( 1 .. 24 ) {
					$lnum = int( ( $pnum - 1 ) * $average ) + 1;
					if ( $totpages > 999 ) {
						$number = sprintf '%04s', $pnum;
					} else {
						$number = sprintf '%03s', $pnum;
					}
					$textwindow->markSet( 'Pg' . $number, "$lnum.0" );
					$textwindow->markGravity( "Pg$number", 'left' );
				}
				$average =
				  ( ( int( $linex + .5 ) ) - ( int( $line25 + .5 ) ) ) /
				  ( $pagex - 25 );
				for my $pnum ( 1 .. $pagex - 26 ) {
					$lnum = int( ( $pnum - 1 ) * $average ) + 1 + $line25;
					if ( $totpages > 999 ) {
						$number = sprintf '%04s', $pnum + 25;
					} else {
						$number = sprintf '%03s', $pnum + 25;
					}
					$textwindow->markSet( "Pg$number", "$lnum.0" );
					$textwindow->markGravity( "Pg$number", 'left' );
				}
				$average =
				  ( $end - int( $linex + .5 ) ) / ( $totpages - $pagex );
				for my $pnum ( 1 .. ( $totpages - $pagex ) ) {
					$lnum = int( ( $pnum - 1 ) * $average ) + 1 + $linex;
					if ( $totpages > 999 ) {
						$number = sprintf '%04s', $pnum + $pagex;
					} else {
						$number = sprintf '%03s', $pnum + $pagex;
					}
					$textwindow->markSet( "Pg$number", "$lnum.0" );
					$textwindow->markGravity( "Pg$number", 'left' );
				}
				$::lglobal{pgpop}->destroy;
				undef $::lglobal{pgpop};
			},
			-text  => 'Guess Page #s',
			-width => 18
		)->grid( -row => 1, -column => 1, -padx => 1, -pady => 2 );
	}
	return;
}

sub oppopupdate {
	my $href = shift;
	$::lglobal{oplistbox}->delete( '0', 'end' );
	# Sort operations by date/time completed
	foreach my $value (
		sort { $::operationshash{$a} cmp $::operationshash{$b} }
		keys %::operationshash
	  )
	{
		$::lglobal{oplistbox}
		  ->insert( 'end', "$value $::operationshash{$value}" );
	}
	$::lglobal{oplistbox}->update;
	$::lglobal{oplistbox}->yview( 'scroll', 1, 'units' );
	$::lglobal{oplistbox}->update;
	$::lglobal{oplistbox}->yview( 'scroll', -1, 'units' );
}

sub operationadd {
	my $operation = shift;
	my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime(time);
	$year += 1900;
	my $timestamp = sprintf('%4d-%02d-%02d %02d:%02d:%02d',
				 $year,$mon,$mday,$hour,$min,$sec);
	$::operationshash{$operation} = $timestamp;
	$operation = ::escape_problems($operation);
	::oppopupdate() if $::lglobal{oppop};
	::setedited(1);
}

# Pop up an "Operation" history. Track which functions have already been
# run.
sub opspop_up {
	my $top = $::top;
	if ( $::lglobal{oppop} ) {
		$::lglobal{oppop}->deiconify;
		$::lglobal{oppop}->raise;
	} else {
		$::lglobal{oppop} = $top->Toplevel;
		$::lglobal{oppop}->title('Operations history');
		::initialize_popup_with_deletebinding('oppop');
		my $frame = $::lglobal{oppop}->Frame->pack(
			-anchor => 'nw',
			-fill   => 'both',
			-expand => 'both',
			-padx   => 2,
			-pady   => 2
		);
		$::lglobal{oplistbox} = $frame->Scrolled(
			'Listbox',
			-scrollbars  => 'se',
			-background  => $::bkgcolor,
			-selectmode  => 'single',
			-activestyle => 'none',
		  )->pack(
			-anchor => 'nw',
			-fill   => 'both',
			-expand => 'both',
			-padx   => 2,
			-pady   => 2
		  );
		::drag( $::lglobal{oplistbox} );
	}
	::oppopupdate();
}

sub confirmdiscard {
	my $textwindow = $::textwindow;
	my $top        = $::top;
	if ( ::isedited() ) {
		my $ans = $top->messageBox(
			-icon    => 'warning',
			-type    => 'YesNoCancel',
			-default => 'yes',
			-message =>
			  'The file has been modified without being saved. Save edits?'
		);
		if ( $ans =~ /yes/i ) {
			savefile();
		} else {
			return $ans;
		}
	}
	return 'no';
}

sub confirmempty {
	my $textwindow = $::textwindow;
	my $answer     = confirmdiscard();
	if ( $answer =~ /no/i ) {
		if ( $::lglobal{img_num_label} ) {
			$::lglobal{img_num_label}->destroy;
			undef $::lglobal{img_num_label};
		}
		if ( $::lglobal{pagebutton} ) {
			$::lglobal{pagebutton}->destroy;
			undef $::lglobal{pagebutton};
		}
		if ( $::lglobal{previmagebutton} ) {
			$::lglobal{previmagebutton}->destroy;
			undef $::lglobal{previmagebutton};
		}
		if ( $::lglobal{proofbutton} ) {
			$::lglobal{proofbutton}->destroy;
			undef $::lglobal{proofbutton};
		}
		$textwindow->EmptyDocument;
	}
	return $answer;
}

sub openfile {    # and open it
	my $name       = shift;
	my $top        = $::top;
	my $textwindow = $::textwindow;
	return if ( $name eq '*empty*' );
	return if ( confirmempty() =~ /cancel/i );
	unless ( -e $name ) {
		my $dbox = $top->Dialog(
			-text    => 'Could not find file. Has it been moved or deleted?',
			-bitmap  => 'error',
			-title   => 'Could not find File.',
			-buttons => ['Ok']
		);
		$dbox->Show;
		return;
	}
	clearvars($textwindow);
	if ( $::lglobal{img_num_label} ) {
		$::lglobal{img_num_label}->destroy;
		undef $::lglobal{img_num_label};
	}
	if ( $::lglobal{page_label} ) {
		$::lglobal{page_label}->destroy;
		undef $::lglobal{page_label};
	}
	if ( $::lglobal{pagebutton} ) {
		$::lglobal{pagebutton}->destroy;
		undef $::lglobal{pagebutton};
	}
	if ( $::lglobal{previmagebutton} ) {
		$::lglobal{previmagebutton}->destroy;
		undef $::lglobal{previmagebutton};
	}
	if ( $::lglobal{proofbutton} ) {
		$::lglobal{proofbutton}->destroy;
		undef $::lglobal{proofbutton};
	}
	if ( $::lglobal{footpop} ) {
		$::lglobal{footpop}->destroy;
		undef $::lglobal{footpop};
	}
	if ( $::lglobal{footviewpop} ) {
		$::lglobal{footviewpop}->destroy;
		undef $::lglobal{footviewpop};
	}
	my ( $fname, $extension, $filevar );
	$textwindow->Load($name);
	( $fname, $::globallastpath, $extension ) = ::fileparse($name);
	$textwindow->markSet( 'insert', '1.0' );
	$::globallastpath           = ::os_normal($::globallastpath);
	$name                       = ::os_normal($name);
	$::lglobal{global_filename} = $name;
	my $binname = getbinname();

	unless ( -e $binname ) {    #for backward compatibility
		$binname = $::lglobal{global_filename};
		$binname =~ s/\.[^\.]*$/\.bin/;
		if ( $binname eq $::lglobal{global_filename} ) { $binname .= '.bin' }
	}
	if ( -e $binname ) {
		::dofile($binname);     #do $binname;
		interpretbinfile();
	}
	::getprojectid() unless $::projectid;
	_recentupdate($name);
	unless ( -e $::pngspath ) {
		$::pngspath = $::globallastpath . $::defaultpngspath;
		unless ( -e $::pngspath ) {
			$::pngspath = $::globallastpath . ::os_normal( $::projectid.'_images/') if $::projectid;
		}
		unless ( -e $::pngspath ) {
			$::pngspath = '';
		}
	}
	::update_indicators();
	file_mark_pages() if $::auto_page_marks;
	::readlabels();

   #push @::operations, ( localtime() . " - Open $::lglobal{global_filename}" );
   #oppopupdate() if $::lglobal{oppop};
	::savesettings();
	::set_autosave() if $::autosave;
}

sub readsettings {
	if ( -e 'setting.rc' ) {
		unless ( my $return = ::dofile('setting.rc') ) {
			open my $file, "<", "setting.rc"
			  or warn "Could not open setting file\n";
			my @file = <$file>;
			close $file;
			my $settings = '';
			for (@file) {
				$settings .= $_;
			}
			unless ( my $return = eval($settings) ) {
				if ( -e 'setting.rc' ) {
					open my $file, "<", "setting.rc"
					  or warn "Could not open setting file\n";
					my @file = <$file>;
					close $file;
					open $file, ">", "setting.err";
					print $file @file;
					close $file;
					print length($file);
				}
			}
		}
	}
	# If someone just upgraded, reset the update counter
	unless ($::lastversionrun eq $::VERSION) {
		$::lastversioncheck = time();
		$::lastversionrun=$::VERSION;

		$::lmargin = 0 if ( $::lmargin == 1 );

		# get rid of geometry values that are out of use, but keep the position
		for ( keys %::geometryhash ) {
			if ( $::positionhash{$_} ) {
				if ( $::geometryhash{$_} =~ m/^\d+x\d+(\+\d+\+\d+)$/) {
					$::positionhash{$_} = $1;
				}
				delete $::geometryhash{$_};
			}
		}

		# force the first element of extops to be "view in browser"
		if ( $::extops[0]{label} eq 'Open current file in its default program'
		     || $::extops[0]{label} eq 'Pass open file to default handler') {
			$::extops[0]{label} = 'View in browser';
		}
		if ( $::extops[0]{label} =~ m/browser/ ) {
			$::extops[0]{label} = 'View in browser';
		}
		else {
			if ( $::extops[$::extops_size-1]{label} || $::extops[$::extops_size-1]{command} ) {
				$::extops_size++;
			}
			for ( my $i = $::extops_size-1; $i > 0; --$i ) {
				$::extops[$i]{label}   = $::extops[$i-1]{label};
				$::extops[$i]{command} = $::extops[$i-1]{command};
			}
			$::extops[0]{label}   = 'View in browser';
			$::extops[0]{command} = $::globalbrowserstart . ' "$d$f$e"';
		}
	}
}

## Save setting.rc file
sub savesettings {
	my $top = $::top;

	#print time()."savesettings\n";
	my $message = <<EOM;
# This file contains your saved settings for guiguts.
# It is automatically generated when you save your settings.
# If you delete it, all the settings will revert to defaults.
# You shouldn't ever have to edit this file manually.\n\n
EOM
	my ( $index, $savethis );
	#my $thispath = $0;
	#$thispath =~ s/[^\\]*$//;
	my $savefile = ::catfile($::lglobal{guigutsdirectory} , 'setting.rc');
	$::geometry = $top->geometry unless $::geometry;
	if ( open my $save_handle, '>', $savefile ) {
		print $save_handle $message;
		print $save_handle '@gcopt = (';
		print $save_handle "$_," || '0,' for @::gcopt;
		print $save_handle ");\n\n";

		# a variable's value is also saved if it is zero
		# otherwise we can't have a default value of 1 without overwriting the user's setting
		for (
			qw/alpha_sort activecolor auto_page_marks auto_show_images autobackup autosave autosaveinterval bkgcolor
			blocklmargin blockrmargin bold_char defaultindent donotcenterpagemarkers extops_size failedsearch
			font_char fontname fontsize fontweight geometry
			geometry2 geometry3 gesperrt_char globalaspellmode highlightcolor history_size 
			htmldiventry htmlspanentry ignoreversionnumber
			intelligentWF ignoreversions italic_char jeebiesmode lastversioncheck lastversionrun lmargin	
			multisearchsize multiterm nobell nohighlights projectfileslocation notoolbar poetrylmargin projectfileslocation
			recentfile_size rewrapalgo rmargin rmargindiff rwhyphenspace sc_char scannos_highlighted stayontop toolside 
			txt_conv_bold txt_conv_font txt_conv_gesperrt txt_conv_italic txt_conv_sc txt_conv_tb
			twowordsinhyphencheck unicodemenusplit utffontname utffontsize
			url_no_proofer url_yes_proofer urlprojectpage urlprojectdiscussion
			menulayout verboseerrorchecks vislnnm w3cremote wfstayontop/
		  )
		{
			print $save_handle "\$$_", ' ' x ( 25 - length $_ ), "= '",
			  eval '$::' . $_, "';\n";
		}
		print $save_handle "\n";
		for (
			qw/globallastpath globalspellpath globalspelldictopt globalviewerpath globalbrowserstart
			gutcommand jeebiescommand scannospath tidycommand validatecommand validatecsscommand gnutenbergdirectory/
		  )
		{
			if ( eval '$::' . $_ ) {
				print $save_handle "\$$_", ' ' x ( 20 - length $_ ), "= '",
				  ::escape_problems( ::os_normal( eval '$::' . $_ ) ), "';\n";
			}
		}
		print $save_handle ("\n\@recentfile = (\n");
		for (@::recentfile) {
			print $save_handle "\t'", ::escape_problems($_), "',\n";
		}
		print $save_handle (");\n\n");
		print $save_handle ("\@extops = (\n");
		for my $index ( 0 .. $#::extops ) {
			my $label   = ::escape_problems( $::extops[$index]{label} );
			my $command = ::escape_problems( $::extops[$index]{command} );
			print $save_handle
			  "\t{'label' => '$label', 'command' => '$command'},\n";
		}
		print $save_handle ");\n\n";

		for ( keys %::geometryhash ) {
			print $save_handle "\$geometryhash{$_}", ' ' x ( 18 - length $_ ),
				"= '$::geometryhash{$_}';\n";
		}
		print $save_handle "\n";
		for ( keys %::positionhash ) {
			print $save_handle "\$positionhash{$_}", ' ' x ( 18 - length $_ ),
				"= '$::positionhash{$_}';\n";
		}
		print $save_handle "\n";

		print $save_handle '@mygcview = (';
		for (@::mygcview) { print $save_handle "$_," }
		print $save_handle (");\n\n");
		print $save_handle ("\@search_history = (\n");
		my @array = @::search_history;
		for my $index (@array) {
			$index =~ s/([^A-Za-z0-9 ])/'\x{'.(sprintf "%x", ord $1).'}'/eg;
			print $save_handle qq/\t"$index",\n/;
		}
		print $save_handle ");\n\n";
		print $save_handle ("\@replace_history = (\n");
		@array = @::replace_history;
		for my $index (@array) {
			$index =~ s/([^A-Za-z0-9 ])/'\x{'.(sprintf "%x", ord $1).'}'/eg;
			print $save_handle qq/\t"$index",\n/;
		}
		print $save_handle ");\n\n";
		print $save_handle ("\@multidicts = (\n");
		for my $index (@::multidicts) {
			print $save_handle qq/\t"$index",\n/;
		}
		print $save_handle ");\n\n1;\n";
	}
}

sub getbinname {
	my $binname = "$::lglobal{global_filename}.bin";
	unless ( -e $binname ) {    #for backward compatibility
		$binname = $::lglobal{global_filename};
		$binname =~ s/\.[^\.]*$/\.bin/;
		if ( $binname eq $::lglobal{global_filename} ) { $binname .= '.bin' }
	}
	return $binname;
}

sub file_export_pagemarkup {
	my $textwindow = $::textwindow;
	my ($name);
	::savefile() if ( $textwindow->numberChanges );
	$name = $textwindow->getSaveFile(
		-title      => 'Export with Page Markers',
		-initialdir => $::globallastpath
	);
	return unless $name;
	$::lglobal{exportwithmarkup} = 1;
	::html_convert_pageanchors();
	$::lglobal{exportwithmarkup} = 0;

	if ( defined($name) and length($name) ) {
		$name .= '.gut';
		my $bincontents = '';
		open my $fh, '<', getbinname() or die "Could not read $name";
		my $inpagenumbers   = 0;
		my $pastpagenumbers = 0;
		while ( my $line = <$fh> ) {
			$bincontents .= $line;
		}
		close $fh;

		# write the file with page markup
		open my $fh2, '>', "$name" or die "Could not read $name";
		my $unicode = ::currentfileisunicode();
		my $filecontents = $textwindow->get( '1.0', 'end -1c' );
		utf8::encode($filecontents) if $unicode;
		print $fh2
		  "##### Do not edit this line. File exported from guiguts #####\n";
		print $fh2 $filecontents;

		# write the bin contents
		print $fh2 "\n";
		print $fh2 "##### Do not edit below. #####\n";
		print $fh2 $bincontents;
		close $fh2;
	}
	openfile( $::lglobal{global_filename} );

	#$textwindow->undo;
	# OR reload the original file
}

sub file_import_markup {
	my $textwindow = $::textwindow;
	return if ( ::confirmempty() =~ /cancel/i );
	my ($name);
	my $types = [ [ '.gut Files', [qw/.gut/] ], [ 'All Files', ['*'] ], ];
	$name = $textwindow->getOpenFile(
		-filetypes  => $types,
		-title      => 'Open File',
		-initialdir => $::globallastpath
	);
	if ( defined($name) and length($name) ) {
		::openfile($name);
	}
	$::lglobal{global_filename} = 'No File Loaded';
	$textwindow->FileName( $::lglobal{global_filename} );
	my $firstline = $textwindow->get( '1.0', '1.end' );
	if ( $firstline =~ '##### Do not edit this line.' ) {
		$textwindow->delete( '1.0', '2.0' );
	}
	my $binstart =
	  $textwindow->search( '-exact', '--', '##### Do not edit below.',
		'1.0', 'end' );
	my ( $row, $col ) = split( /\./, $binstart );
	$textwindow->delete( "$row.0", "$row.end" );
	my $binfile = $textwindow->get( "$row.0", "end" );
	$textwindow->delete( "$row.0", "end" );
	::evalstring($binfile);
	my ( $pagenumberstartindex, $pagenumberendindex, $pagemarkup );
	::working('Converting Page Number Markup');

	while ( $pagenumberstartindex =
		$textwindow->search( '-regexp', '--', '<Pg', '1.0', 'end' ) )
	{
		$pagenumberendindex =
		  $textwindow->search( '-regexp', '--', '>', $pagenumberstartindex,
			'end' );
		$pagemarkup =
		  $textwindow->get( $pagenumberstartindex . '+1c',
			$pagenumberendindex );
		$textwindow->delete( $pagenumberstartindex,
			$pagenumberendindex . '+1c' );
		$::pagenumbers{$pagemarkup}{offset} = $pagenumberstartindex;
	}
	::working();
	interpretbinfile();    # place page markers with the above offsets
}

sub interpretbinfile {
	my $textwindow = $::textwindow;
	my $markindex;
	foreach my $mark ( sort keys %::pagenumbers ) {
		$markindex = $::pagenumbers{$mark}{offset};
		if ( $markindex eq '' ) {
			delete $::pagenumbers{$mark};
			next;
		}
		$textwindow->markSet( $mark, $markindex );
		$textwindow->markGravity( $mark, 'left' );
	}
	for ( 1 .. 5 ) {
		if ( $::bookmarks[$_] ) {
			$textwindow->markSet( 'insert', $::bookmarks[$_] );
			$textwindow->markSet( "bkmk$_", $::bookmarks[$_] );
			::setbookmark($_);
		}
	}
	$::bookmarks[0] ||= '1.0';
	$textwindow->markSet( 'insert',    $::bookmarks[0] );
	$textwindow->markSet( 'spellbkmk', $::spellindexbkmrk )
	  if $::spellindexbkmrk;
	$textwindow->see( $::bookmarks[0] );
	$textwindow->focus;
	return ();
}

sub isedited {
	my $textwindow = $::textwindow;
	return $textwindow->numberChanges || $::lglobal{isedited};
}

sub setedited {
	my $val = shift;
	my $textwindow = $::textwindow;
	$::lglobal{isedited} = $val;
	$textwindow->ResetUndo unless $val;
}

1;
