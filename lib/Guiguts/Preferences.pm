package Guiguts::Preferences;
use strict;
use warnings;

BEGIN {
	use Exporter();
	our ( @ISA, @EXPORT );
	@ISA = qw(Exporter);
	@EXPORT =
	  qw(&setviewerpath &setdefaultpath &setmargins &fontsize &setbrowser &setpngspath &set_autosave 
	  &autosaveinterval &saveinterval &setcolor &locateAspellExe);
}

sub setviewerpath {    #Find your image viewer
	my $textwindow = shift;
	my $types;
	if ($::OS_WIN) {
		$types = [ [ 'Executable', [ '.exe', ] ], [ 'All Files', ['*'] ], ];
	} else {
		$types = [ [ 'All Files', ['*'] ] ];
	}

	#print $::globalviewerpath."aa\n";
	#	print ::dirname($::globalviewerpath)."aa\n";
	$::lglobal{pathtemp} =
	  $textwindow->getOpenFile(
								-filetypes  => $types,
								-title      => 'Where is your image viewer?',
								-initialdir => ::dirname($::globalviewerpath)
	  );
	$::globalviewerpath = $::lglobal{pathtemp} if $::lglobal{pathtemp};
	$::globalviewerpath = ::os_normal($::globalviewerpath);
	::savesettings();
}

sub setdefaultpath {
	my ( $pathname, $path ) = @_;
	if ($pathname) { return $pathname }
	if ( ( !$pathname ) && ( -e $path ) ) { return $path; }
	else {
		return '';
	}
}

sub setmargins {
	my $top = $::top;
	my $getmargins = $top->DialogBox( -title   => 'Set Margins for Rewrap',
									  -buttons => ['Close'], );
	my $lmframe =
	  $getmargins->add('Frame')->pack( -side => 'top', -padx => 5, -pady => 3 );
	my $lmlabel = $lmframe->Label(
								   -width => 25,
								   -text  => 'Rewrap Left Margin',
	)->pack( -side => 'left' );
	my $lmentry = $lmframe->Entry(
								   -width        => 6,
								   -background   => $::bkgcolor,
								   -relief       => 'sunken',
								   -textvariable => \$::lmargin,
	)->pack( -side => 'left' );
	my $rmframe =
	  $getmargins->add('Frame')->pack( -side => 'top', -padx => 5, -pady => 3 );
	my $rmlabel = $rmframe->Label(
								   -width => 25,
								   -text  => 'Rewrap Right Margin',
	)->pack( -side => 'left' );
	my $rmentry = $rmframe->Entry(
								   -width        => 6,
								   -background   => $::bkgcolor,
								   -relief       => 'sunken',
								   -textvariable => \$::rmargin,
	)->pack( -side => 'left' );
	my $blmframe =
	  $getmargins->add('Frame')->pack( -side => 'top', -padx => 5, -pady => 3 );
	my $blmlabel = $blmframe->Label(
									 -width => 25,
									 -text  => 'Block Rewrap Left Margin',
	)->pack( -side => 'left' );
	my $blmentry = $blmframe->Entry(
									 -width        => 6,
									 -background   => $::bkgcolor,
									 -relief       => 'sunken',
									 -textvariable => \$::blocklmargin,
	)->pack( -side => 'left' );
	my $brmframe =
	  $getmargins->add('Frame')->pack( -side => 'top', -padx => 5, -pady => 3 );
	my $brmlabel = $brmframe->Label(
									 -width => 25,
									 -text  => 'Block Rewrap Right Margin',
	)->pack( -side => 'left' );
	my $brmentry = $brmframe->Entry(
									 -width        => 6,
									 -background   => $::bkgcolor,
									 -relief       => 'sunken',
									 -textvariable => \$::blockrmargin,
	)->pack( -side => 'left' );

	#
	my $plmframe =
	  $getmargins->add('Frame')->pack( -side => 'top', -padx => 5, -pady => 3 );
	my $plmlabel = $plmframe->Label(
									 -width => 25,
									 -text  => 'Poetry Rewrap Left Margin',
	)->pack( -side => 'left' );
	my $plmentry = $plmframe->Entry(
									 -width        => 6,
									 -background   => $::bkgcolor,
									 -relief       => 'sunken',
									 -textvariable => \$::poetrylmargin,
	)->pack( -side => 'left' );

	#
	my $didntframe =
	  $getmargins->add('Frame')->pack( -side => 'top', -padx => 5, -pady => 3 );
	my $didntlabel =
	  $didntframe->Label(
						  -width => 25,
						  -text  => 'Default Indent for /*  */ Blocks',
	  )->pack( -side => 'left' );
	my $didntmentry =
	  $didntframe->Entry(
						  -width        => 6,
						  -background   => $::bkgcolor,
						  -relief       => 'sunken',
						  -textvariable => \$::defaultindent,
	  )->pack( -side => 'left' );
	$getmargins->Icon( -image => $::icon );
	$getmargins->Show;
	if (    ( $::blockrmargin eq '' )
		 || ( $::blocklmargin eq '' )
		 || ( $::rmargin      eq '' )
		 || ( $::lmargin      eq '' ) )
	{
		$top->messageBox(
						  -icon    => 'error',
						  -message => 'The margins must be a positive integer.',
						  -title   => 'Incorrect margin ',
						  -type    => 'OK',
		);
		setmargins();
	}
	if (    ( $::blockrmargin =~ /[\D\.]/ )
		 || ( $::blocklmargin =~ /[\D\.]/ )
		 || ( $::rmargin      =~ /[\D\.]/ )
		 || ( $::lmargin      =~ /[\D\.]/ ) )
	{
		$top->messageBox(
						  -icon    => 'error',
						  -message => 'The margins must be a positive integer.',
						  -title   => 'Incorrect margin ',
						  -type    => 'OK',
		);
		setmargins();
	}
	if ( ( $::blockrmargin < $::blocklmargin ) || ( $::rmargin < $::lmargin ) )
	{
		$top->messageBox(
			  -icon    => 'error',
			  -message => 'The left margins must come before the right margin.',
			  -title   => 'Incorrect margin ',
			  -type    => 'OK',
		);
		setmargins();
	}
	::savesettings();
}

# FIXME: Adapt to work with fontCreate thingy
sub fontsize {
	my $textwindow = $::textwindow;
	my $top        = $::top;
	my $sizelabel;
	if ( defined( $::lglobal{fspop} ) ) {
		$::lglobal{fspop}->deiconify;
		$::lglobal{fspop}->raise;
		$::lglobal{fspop}->focus;
	} else {
		$::lglobal{fspop} = $top->Toplevel;
		$::lglobal{fspop}->title('Font');
		$::lglobal{fspop}->resizable( 'no', 'no' );
		::initialize_popup_with_deletebinding('fspop');
		my $tframe = $::lglobal{fspop}->Frame->pack;
		my $fontlist = $tframe->BrowseEntry(
			-label     => 'Font',
			-browsecmd => sub {
				::fontinit();
				$textwindow->configure( -font => $::lglobal{font} );
			},
			-variable => \$::fontname
		)->grid( -row => 1, -column => 1, -pady => 5 );
		$fontlist->insert( 'end', sort( $textwindow->fontFamilies ) );
		my $mframe = $::lglobal{fspop}->Frame->pack;
		my $smallerbutton = $mframe->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				$::fontsize--;
				::fontinit();
				$textwindow->configure( -font => $::lglobal{font} );
				$sizelabel->configure( -text => $::fontsize );
			},
			-text  => 'Smaller',
			-width => 10
		)->grid( -row => 1, -column => 1, -pady => 5 );
		$sizelabel =
		  $mframe->Label( -text => $::fontsize )
		  ->grid( -row => 1, -column => 2, -pady => 5 );
		my $biggerbutton = $mframe->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				$::fontsize++;
				::fontinit();
				$textwindow->configure( -font => $::lglobal{font} );
				$sizelabel->configure( -text => $::fontsize );
			},
			-text  => 'Bigger',
			-width => 10
		)->grid( -row => 1, -column => 3, -pady => 5 );
		my $weightbox = $mframe->Checkbutton(
			-variable    => \$::fontweight,
			-onvalue     => 'bold',
			-offvalue    => '',
			-selectcolor => $::activecolor,
			-command     => sub {
				::fontinit();
				$textwindow->configure( -font => $::lglobal{font} );
			},
			-text => 'Bold'
		)->grid( -row => 2, -column => 2, -pady => 5 );
		my $button_ok = $mframe->Button(
			-activebackground => $::activecolor,
			-text             => 'Close',
			-command          => sub {
				$::lglobal{fspop}->destroy;
				undef $::lglobal{fspop};
				::savesettings();
			}
		)->grid( -row => 3, -column => 2, -pady => 5 );
		$::lglobal{fspop}->raise;
		$::lglobal{fspop}->focus;
	}
}
## Set up command to start a browser, varies by OS and browser
sub setbrowser {
	my $top       = $::top;
	my $browsepop = $top->Toplevel;
	$browsepop->title('Browser Start Command?');
	$browsepop->Label( -text =>
"Enter the complete path to the executable.\n(Under Windows, you can use 'start' to use the default handler.\n"
		. "Under OSX, 'open' will start the default browser.)" )
	  ->grid( -row => 0, -column => 1, -columnspan => 2 );
	my $browserentry =
	  $browsepop->Entry(
						 -width        => 60,
						 -background   => $::bkgcolor,
						 -textvariable => $::globalbrowserstart,
	  )->grid( -row => 1, -column => 1, -columnspan => 2, -pady => 3 );
	my $button_ok = $browsepop->Button(
		-activebackground => $::activecolor,
		-text             => 'OK',
		-width            => 6,
		-command          => sub {
			$::globalbrowserstart = $browserentry->get;
			::savesettings();
			$browsepop->destroy;
			undef $browsepop;
		}
	)->grid( -row => 2, -column => 1, -pady => 8 );
	my $button_cancel = $browsepop->Button(
		-activebackground => $::activecolor,
		-text             => 'Cancel',
		-width            => 6,
		-command          => sub {
			$browsepop->destroy;
			undef $browsepop;
		}
	)->grid( -row => 2, -column => 2, -pady => 8 );
	$browsepop->protocol(
		 'WM_DELETE_WINDOW' => sub { $browsepop->destroy; undef $browsepop; } );
	$browsepop->Icon( -image => $::icon );
}

sub setpngspath {
	my $textwindow = $::textwindow;
	my $top        = $::top;
	my $pagenum    = shift;

	#print $pagenum.'';
	my $path =
	  $textwindow->chooseDirectory( -title => 'Choose the PNGs file directory.',
									-initialdir => "$::globallastpath" . "pngs",
	  );
	return unless defined $path and -e $path;
	$path .= '/';
	$path       = ::os_normal($path);
	$::pngspath = $path;
	::_bin_save();
	::openpng( $textwindow, $pagenum ) if defined $pagenum;
}

# Pop up a window where you can adjust the auto save interval
sub saveinterval {
	my $top = $::top;
    if ( $::lglobal{intervalpop} ) {
        $::lglobal{intervalpop}->deiconify;
        $::lglobal{intervalpop}->raise;
    }
    else {
        $::lglobal{intervalpop} = $top->Toplevel;
        $::lglobal{intervalpop}->title('Autosave Interval');
        $::lglobal{intervalpop}->resizable( 'no', 'no' );
        my $frame = $::lglobal{intervalpop}
            ->Frame->pack( -fill => 'x', -padx => 5, -pady => 5 );
        $frame->Label( -text => 'Minutes between autosave' )
            ->pack( -side => 'left' );
        my $entry = $frame->Entry(
            -background   => 'white',
            -width        => 5,
            -textvariable => \$::autosaveinterval,
            -validate     => 'key',
            -vcmd         => sub {
                return 1 unless $_[0];
                return 0 if ( $_[0] =~ /\D/ );
                return 0 if ( $_[0] < 1 );
                return 0 if ( $_[0] > 999 );
                return 1;
            },
        )->pack( -side => 'left', -fill => 'x' );
        my $frame1 = $::lglobal{intervalpop}
            ->Frame->pack( -fill => 'x', -padx => 5, -pady => 5 );
        $frame->Label( -text => '(1-999)' )->pack( -side => 'left' );
        my $button = $frame1->Button(
            -text    => 'OK',
            -command => sub {
                $::autosaveinterval = 5 unless $::autosaveinterval;
                $::lglobal{intervalpop}->destroy;
                undef $::lglobal{scrlspdpop};
            },
        )->pack;
        $::lglobal{intervalpop}->protocol(
            'WM_DELETE_WINDOW' => sub {
                $::autosaveinterval = 5 unless $::autosaveinterval;
                $::lglobal{intervalpop}->destroy;
                undef $::lglobal{intervalpop};
            }
        );
        $::lglobal{intervalpop}->Icon( -image => $::icon );
        $entry->selectionRange( 0, 'end' );
    }
}

sub set_autosave {
	my $textwindow = $::textwindow;
	my $top        = $::top;
	$::lglobal{autosaveid}->cancel     if $::lglobal{autosaveid};
	$::lglobal{saveflashid}->cancel    if $::lglobal{saveflashid};
	$::lglobal{saveflashingid}->cancel if $::lglobal{saveflashingid};
	$::lglobal{autosaveid} = $top->repeat(
		( $::autosaveinterval * 60000 ),
		sub {
			::savefile()
			  if $textwindow->numberChanges
				  and $::lglobal{global_filename} !~ /No File Loaded/;
		}
	);
	$::lglobal{saveflashid} = $top->after(
		( $::autosaveinterval * 60000 - 10000 ),
		sub {
			::_flash_save($textwindow)
			  if $::lglobal{global_filename} !~ /No File Loaded/;
		}
	);
	$::lglobal{savetool}
	  ->configure( -background => 'green', -activebackground => 'green' )
	  unless $::notoolbar;
	#$::lglobal{autosaveinterval} = time;
}

sub setcolor {    # Color picking routine
	my $top     = $::top;
	my $initial = shift;
	return (
			 $top->chooseColor(
								-initialcolor => $initial,
								-title        => 'Choose color'
			 )
	);
}

sub locateAspellExe {
	my $textwindow = shift;
	my $types;
	if ($::OS_WIN) {
		$types = [ [ 'Executable', [ '.exe', ] ], [ 'All Files', ['*'] ], ];
	} else {
		$types = [ [ 'All Files', ['*'] ] ];
	}
	$::lglobal{pathtemp} = $textwindow->getOpenFile(
		-filetypes  => $types,
		-title      => 'Where is the Aspell executable?',
		-initialdir => ::dirname($::globalspellpath)
	);
	$::globalspellpath = $::lglobal{pathtemp}
	  if $::lglobal{pathtemp};
	return unless $::globalspellpath;
	$::globalspellpath = ::os_normal($::globalspellpath);
	::savesettings();
}

1;
