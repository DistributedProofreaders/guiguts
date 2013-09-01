package Guiguts::Preferences;
use strict;
use warnings;

BEGIN {
	use Exporter();
	our ( @ISA, @EXPORT );
	@ISA = qw(Exporter);
	@EXPORT =
	  qw(&setdefaultpath &setmargins &fontsize &setpngspath &set_autosave 
	  &autosaveinterval &saveinterval &setcolor &locateExecutable &filePathsPopup &setDPurls );
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
	if ( defined( $::lglobal{marginspop} ) ) {
		$::lglobal{marginspop}->deiconify;
		$::lglobal{marginspop}->raise;
		$::lglobal{marginspop}->focus;
	} else {
		$::lglobal{marginspop} = $top->Toplevel;
		$::lglobal{marginspop}->title('Set Margins for Rewrap');
		$::lglobal{marginspop}->resizable('no', 'no');
		
	my $lmframe =
	  $::lglobal{marginspop}->Frame->pack( -side => 'top', -padx => 5, -pady => 3 );
	my $lmlabel = $lmframe->Label(
								   -width => 25,
								   -text  => 'Left Margin',
	)->pack( -side => 'left' );
	my $lmentry = $lmframe->Spinbox(
								   -width        => 6,
								   -background   => $::bkgcolor,
								   -relief       => 'sunken',
								   -textvariable => \$::lmargin,
								   -increment    => 1,
								   -from         => 0,
								   -to           => 120,
	)->pack( -side => 'left' );
	my $rmframe =
	  $::lglobal{marginspop}->Frame->pack( -side => 'top', -padx => 5, -pady => 3 );
	my $rmlabel = $rmframe->Label(
								   -width => 25,
								   -text  => 'Max. Right Margin',
	)->pack( -side => 'left' );
	my $rmentry = $rmframe->Spinbox(
								   -width        => 6,
								   -background   => $::bkgcolor,
								   -relief       => 'sunken',
								   -textvariable => \$::rmargin,
								   -increment    => 1,
								   -from         => 0,
								   -to           => 120,
	)->pack( -side => 'left' );
	my $blmframe =
	  $::lglobal{marginspop}->Frame->pack( -side => 'top', -padx => 5, -pady => 3 );
	my $blmlabel = $blmframe->Label(
									 -width => 25,
									 -text  => 'Block Left Margin',
	)->pack( -side => 'left' );
	my $blmentry = $blmframe->Spinbox(
									 -width        => 6,
									 -background   => $::bkgcolor,
									 -relief       => 'sunken',
									 -textvariable => \$::blocklmargin,
									 -increment    => 1,
									 -from         => 0,
									 -to           => 120,
	)->pack( -side => 'left' );
	my $brmframe =
	  $::lglobal{marginspop}->Frame->pack( -side => 'top', -padx => 5, -pady => 3 );
	my $brmlabel = $brmframe->Label(
									 -width => 25,
									 -text  => 'Block Max. Right Margin',
	)->pack( -side => 'left' );
	my $brmentry = $brmframe->Spinbox(
									 -width        => 6,
									 -background   => $::bkgcolor,
									 -relief       => 'sunken',
									 -textvariable => \$::blockrmargin,
									 -increment    => 1,
									 -from         => 0,
									 -to           => 120,
	)->pack( -side => 'left' );
	my $plmframe =
	  $::lglobal{marginspop}->Frame->pack( -side => 'top', -padx => 5, -pady => 3 );
	my $plmlabel = $plmframe->Label(
									 -width => 25,
									 -text  => 'Poetry Left Margin',
	)->pack( -side => 'left' );
	my $plmentry = $plmframe->Spinbox(
									 -width        => 6,
									 -background   => $::bkgcolor,
									 -relief       => 'sunken',
									 -textvariable => \$::poetrylmargin,
									 -increment    => 1,
									 -from         => 0,
									 -to           => 20,
	)->pack( -side => 'left' );
	my $didntframe =
	  $::lglobal{marginspop}->Frame->pack( -side => 'top', -padx => 5, -pady => 3 );
	my $didntlabel = $didntframe->Label(
						  -width => 25,
						  -text  => 'Default Indent for /*  */ Blocks',
	  )->pack( -side => 'left' );
	my $didntmentry = $didntframe->Spinbox(
						  -width        => 6,
						  -background   => $::bkgcolor,
						  -relief       => 'sunken',
						  -textvariable => \$::defaultindent,
						  -increment    => 1,
						  -from         => 0,
						  -to           => 120,
	  )->pack( -side => 'left' );
	if ( $::rewrapalgo == 2 ) {
		my $rmdiffframe =
		  $::lglobal{marginspop}->Frame->pack( -side => 'top', -padx => 5, -pady => 3 );
		my $rmdifflabel = $rmdiffframe->Label(
							  -width => 25,
							  -text  => 'Right Margin Max.-Opt. Diff.',
		  )->pack( -side => 'left' );
		my $rmdiffentry = $rmdiffframe->Spinbox(
							  -width        => 6,
							  -background   => $::bkgcolor,
							  -relief       => 'sunken',
							  -textvariable => \$::rmargindiff,
							  -increment    => 1,
							  -from         => 0,
							  -to           => 10,
		  )->pack( -side => 'left' );
	}
		::initialize_popup_without_deletebinding('marginspop');
		$::lglobal{marginspop}->protocol(
			'WM_DELETE_WINDOW' => sub {
				$::lglobal{marginspop}->destroy;
				undef $::lglobal{marginspop};
				if ( ( $::blockrmargin < $::blocklmargin ) || ( $::rmargin < $::lmargin ) )
				{
					$top->messageBox(
						  -icon    => 'error',
						  -title   => 'Incorrect margins',
						  -message => 'The left margin must be smaller than the right margin.',
						  -type    => 'OK',
					);
					setmargins();
				} else {
					::savesettings();
				}
			}
		);
	}
	$::lglobal{marginspop}->raise;
	$::lglobal{marginspop}->focus;
}

# FIXME: Adapt to work with fontCreate thingy
sub fontsize {
	my $textwindow = $::textwindow;
	my $top        = $::top;
	my $sizelabel;
	if ( defined( $::lglobal{fontpop} ) ) {
		$::lglobal{fontpop}->deiconify;
		$::lglobal{fontpop}->raise;
		$::lglobal{fontpop}->focus;
	} else {
		$::lglobal{fontpop} = $top->Toplevel;
		$::lglobal{fontpop}->title('Font');
		my $tframe = $::lglobal{fontpop}->Frame->pack;
		my $fontlist = $tframe->BrowseEntry(
			-label     => 'Font',
			-browsecmd => sub {
				::fontinit();
				$textwindow->configure( -font => $::lglobal{font} );
			},
			-variable => \$::fontname
		)->grid( -row => 1, -column => 1, -pady => 5 );
		$fontlist->insert( 'end', sort( $textwindow->fontFamilies ) );
		my $mframe = $::lglobal{fontpop}->Frame->pack;
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
				$::lglobal{fontpop}->destroy;
				undef $::lglobal{fontpop};
				::savesettings();
			}
		)->grid( -row => 3, -column => 2, -pady => 5 );
		$::lglobal{fontpop}->resizable( 'no', 'no' );
		::initialize_popup_with_deletebinding('fontpop');
		$::lglobal{fontpop}->raise;
		$::lglobal{fontpop}->focus;
	}
}

sub setpngspath {
	my $textwindow = $::textwindow;
	my $top        = $::top;
	my $pagenum    = shift;

	#print $pagenum.'';
	my $path =
	  $textwindow->chooseDirectory( -title => 'Choose the PNGs file directory',
									-initialdir => "$::globallastpath" . "pngs",
	  );
	return unless defined $path and -e $path;
	$path .= '/';
	$path       = ::os_normal($path);
	$::pngspath = $path;
	::setedited(1);
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
            -background   => $::bkgcolor,
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
                undef $::lglobal{intervalpop};
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
			  if ::isedited()
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
	#$::autosaveinterval = time;
}

sub setcolor {    # Color picking routine
	my $top     = $::top;
	my $initial = shift;
	return (
			 $top->chooseColor(
								-initialcolor => $initial,
								-title        => 'Choose color (may require restart to take effect)'
			 )
	);
}

sub locateExecutable {
	my ( $exename, $exepathref, $filetypes ) = @_;
	my $textwindow = $::textwindow;
	my $types;
	if ( $filetypes ) {
		$types = $filetypes;
	} else {
		if ($::OS_WIN) {
			$types = [ [ 'Executable', [ '.exe', '.bat' ] ], [ 'All Files', ['*'] ], ];
		} else {
			$types = [ [ 'All Files', ['*'] ] ];
		}
	}
	$::lglobal{pathtemp} = $textwindow->getOpenFile(
		-filetypes  => $types,
		-title      => "Where is your $exename executable?",
		-initialdir => ::dirname(${$exepathref}),
	);
	${$exepathref} = $::lglobal{pathtemp}
	  if $::lglobal{pathtemp};
	return unless ${$exepathref};
	${$exepathref} = ::os_normal(${$exepathref});
	::savesettings();
}

sub filePathsPopup {
	my ( $textwindow, $top ) = ( $::textwindow, $::top );
	if ( defined( $::lglobal{filepathspop} ) ) {
		$::lglobal{filepathspop}->deiconify;
		$::lglobal{filepathspop}->raise;
		$::lglobal{filepathspop}->focus;
	} else {
		$::lglobal{filepathspop} = $top->Toplevel;
		$::lglobal{filepathspop}->title('Set File Paths');
		my $f1 = $::lglobal{filepathspop}->Frame->pack(
			-side   => 'top',
			-anchor => 'n',
			-fill   => 'x'
		);
		$f1->Label( -text => "Image Viewer:", -width => 22, -anchor => 'w',
		    )->pack( -side => 'left' );
		$f1->Button(
			-text    => 'Locate Image Viewer...',
			-command => sub { ::locateExecutable('image viewer', \$::globalviewerpath); },
			-width   => 24,
		    )->pack( -side => 'right' );
		$f1->Entry(
			-textvariable => \$::globalviewerpath,
			-width        => 60,
			-relief       => 'sunken',
			-background   => $::bkgcolor,
		    )->pack( -expand => 'y', -fill   => 'x' );
		my $f2 = $::lglobal{filepathspop}->Frame->pack(
			-side   => 'top',
			-anchor => 'n',
			-fill   => 'x'
		);
		$f2->Label( -text => "Aspell:", -width => 22, -anchor => 'w',
		    )->pack( -side => 'left' );
		$f2->Button(
			-text    => 'Locate Aspell...',
			-command => sub { ::locateExecutable('Aspell', \$::globalspellpath); },
			-width   => 24,
		    )->pack( -side => 'right' );
		$f2->Entry(
			-textvariable => \$::globalspellpath,
			-relief       => 'sunken',
			-background   => $::bkgcolor,
		    )->pack( -expand => 'y', -fill   => 'x' );
		my $f3 = $::lglobal{filepathspop}->Frame->pack(
			-side   => 'top',
			-anchor => 'n',
			-fill   => 'x'
		);
		$f3->Label( -text => "Gutcheck:", -width => 22, -anchor => 'w',
		    )->pack( -side => 'left' );
		$f3->Button(
			-text    => 'Locate Gutcheck...',
			-command => sub { ::locateExecutable('Gutcheck', \$::gutcommand); },
			-width   => 24,
		    )->pack( -side => 'right' );
		$f3->Entry(
			-textvariable => \$::gutcommand,
			-relief       => 'sunken',
			-background   => $::bkgcolor,
		    )->pack( -expand => 'y', -fill   => 'x' );
		my $f4 = $::lglobal{filepathspop}->Frame->pack(
			-side   => 'top',
			-anchor => 'n',
			-fill   => 'x'
		);
		$f4->Label( -text => "Jeebies:", -width => 22, -anchor => 'w',
		    )->pack( -side => 'left' );
		$f4->Button(
			-text    => 'Locate Jeebies...',
			-command => sub { ::locateExecutable('Jeebies', \$::jeebiescommand); },
			-width   => 24,
		    )->pack( -side => 'right' );
		$f4->Entry(
			-textvariable => \$::jeebiescommand,
			-relief       => 'sunken',
			-background   => $::bkgcolor,
		    )->pack( -expand => 'y', -fill   => 'x' );
		my $f5 = $::lglobal{filepathspop}->Frame->pack(
			-side   => 'top',
			-anchor => 'n',
			-fill   => 'x'
		);
		$f5->Label( -text => "HTML Tidy:", -width => 22, -anchor => 'w',
		    )->pack( -side => 'left' );
		$f5->Button(
			-text    => 'Locate Tidy...',
			-command => sub { ::locateExecutable('Tidy', \$::tidycommand); },
			-width   => 24,
		    )->pack( -side => 'right' );
		$f5->Entry(
			-textvariable => \$::tidycommand,
			-relief       => 'sunken',
			-background   => $::bkgcolor,
		    )->pack( -expand => 'y', -fill   => 'x' );
		my $f6 = $::lglobal{filepathspop}->Frame->pack(
			-side   => 'top',
			-anchor => 'n',
			-fill   => 'x'
		);
		$f6->Label( -text => "W3C Validator (onsgmls):", -width => 22, -anchor => 'w',
		    )->pack( -side => 'left' );
		$f6->Button(
			-text    => 'Locate onsgmls...',
			-command => sub { ::locateExecutable('onsgmls', \$::validatecommand); },
			-width   => 24,
		    )->pack( -side => 'right' );
		$f6->Entry(
			-textvariable => \$::validatecommand,
			-relief       => 'sunken',
			-background   => $::bkgcolor,
		    )->pack( -expand => 'y', -fill   => 'x' );
		my $f7 = $::lglobal{filepathspop}->Frame->pack(
			-side   => 'top',
			-anchor => 'n',
			-fill   => 'x'
		);
		$f7->Label( -text => "W3C CSS Validator:", -width => 22, -anchor => 'w',
		    )->pack( -side => 'left' );
		$f7->Button(
			-text    => 'Locate CSS Validator...',
			-command => sub { ::locateExecutable('css-validator.js', \$::validatecsscommand); },
			-width   => 24,
		    )->pack( -side => 'right' );
		$f7->Entry(
			-textvariable => \$::validatecsscommand,
			-relief       => 'sunken',
			-background   => $::bkgcolor,
		    )->pack( -expand => 'y', -fill   => 'x' );
		my $f0 = $::lglobal{filepathspop}->Frame->pack(
			-side   => 'top',
			-anchor => 'n',
			-fill   => 'x'
		);
		$f0->Label( -text => "Browser command:", -width => 22, -anchor => 'w',
		    )->pack( -side => 'left' );
		$f0->Entry(
			-textvariable => \$::extops[0]{command},
			-relief       => 'sunken',
			-background   => $::bkgcolor,
		    )->pack( -expand => 'y', -fill   => 'x' );
		$::lglobal{filepathspop}->Button(
			-activebackground => $::activecolor,
			-text             => 'Close',
			-command          => sub {
				$::lglobal{filepathspop}->destroy;
				undef $::lglobal{filepathspop};
				::savesettings();
			}
		)->pack;
		$::lglobal{filepathspop}->Tk::bind(
			'<Return>' => sub { ::killpopup('filepathspop'); }
		);
		::initialize_popup_with_deletebinding('filepathspop');
	}
}

sub setDPurls {
	my ( $textwindow, $top ) = ( $::textwindow, $::top );
	if ( defined( $::lglobal{defurlspop} ) ) {
		$::lglobal{defurlspop}->deiconify;
		$::lglobal{defurlspop}->raise;
		$::lglobal{defurlspop}->focus;
	} else {
		$::lglobal{defurlspop} = $top->Toplevel;
		$::lglobal{defurlspop}->title('URLs');
		my $f0 =
		  $::lglobal{defurlspop}->Frame->pack( -side => 'top', -anchor => 'n' );
		$f0->Label( -text => "Contact proofer with username:")
		   ->grid( -row => 1, -column => 0, -sticky => 'w' );
		$f0->Entry(
			-width        => 70,
			-textvariable => \$::url_yes_proofer,
			-relief       => 'sunken',
			-background   => $::bkgcolor,
		    )->grid( -row => 1, -column => 1, -pady => 2 );
		$f0->Label( -text => "Contact proofer without username:")
		   ->grid( -row => 2, -column => 0, -sticky => 'w' );
		$f0->Entry(
			-width        => 70,
			-textvariable => \$::url_no_proofer,
			-relief       => 'sunken',
			-background   => $::bkgcolor,
		    )->grid( -row => 2, -column => 1, -pady => 2 );
		$f0->Label( -text => "View project page of projectid:")
		   ->grid( -row => 3, -column => 0, -sticky => 'w' );
		$f0->Entry(
			-width        => 70,
			-textvariable => \$::urlprojectpage,
			-relief       => 'sunken',
			-background   => $::bkgcolor,
		    )->grid( -row => 3, -column => 1, -pady => 2 );
		$f0->Label( -text => "View project discussion of projectid:")
		   ->grid( -row => 4, -column => 0, -sticky => 'w' );
		$f0->Entry(
			-width        => 70,
			-textvariable => \$::urlprojectdiscussion,
			-relief       => 'sunken',
			-background   => $::bkgcolor,
		    )->grid( -row => 4, -column => 1, -pady => 2 );
		$f0->Button(
			-activebackground => $::activecolor,
			-text             => 'Close',
			-command          => sub {
				$::lglobal{defurlspop}->destroy;
				undef $::lglobal{defurlspop};
				::savesettings();
			}
		)->grid( -row => 5, -column => 0, -columnspan => 2, -pady => 5 );
		::initialize_popup_with_deletebinding('defurlspop');
	}
}

1;
