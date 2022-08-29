package Guiguts::Preferences;
use strict;
use warnings;
use File::Basename;

BEGIN {
    use Exporter();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT =
      qw(&setdefaultpath &setmargins &setfonts &setfontrow &textentryfontconfigure &globalfontconfigure
      &fontgeometryupdate &setpngspath &storedefaultcolor_autosave
      &saveinterval &reset_autosave &setcolor &locateExecutable &filePathsPopup &setDPurls &composekeypopup);
}

#
# Find path to tool, either from suggested default path, or on the system path.
# If user already has a path set up for this tool, then we may not want to override it,
# since perhaps it is a modified or updated version they keep on their system.
# However, a frequent reason for the user having a path already in their setting.rc
# is if they copied the setting.rc from another installed release, for example when they
# upgraded. In that case, the tail end of the saved path will match the tail end of
# the default path for the tool, e.g. "...tools\jeebies\jeebies.exe". In this case,
# we just keep the tail end (relative) path which will work wherever this release
# is installed.
sub setdefaultpath {
    my ( $oldpath, $defaultpath ) = @_;
    my $newpath = '';
    if ( -e $defaultpath )    # If default path exists, consider it for new path
    {
        $newpath = $defaultpath;
    } else {                  # Otherwise check for no-extension version or elsewhere on path
        my ( $basename, $filepath, $suffix ) =
          fileparse( $defaultpath, ( ".exe", ".com", ".bat" ) );
        my $filename = "$basename$suffix";

        # Does the file exist in the same location without the extension (ala *nix)?
        if ( -e ::catfile( $filepath, $basename ) ) {
            $newpath = ::catfile( $filepath, $basename );
        } else {    # Is it on the path somewhere - check both with and without extension
            $newpath = File::Which::which($filename) or File::Which::which($basename);
        }
    }
    $newpath = $oldpath unless $newpath;    # Use oldpath if new path not found

    if ( $newpath && -e $newpath ) {
        my $index = index( $newpath, 'tools' );
        $index = index( $newpath, 'scannos' ) if $index < 0;
        if ( $index >= 0 ) {                # New path is in tools or scannos under the release
            my $newtail = substr( $newpath, $index );    # Get the relative tail-end of the path
            if ( $oldpath && -e $oldpath ) {
                my $oldtail = '';
                $index = index( $oldpath, 'tools' );

                # Extra basename condition for scannos permits user to name their custom folder anything but "scannos",
                # Without that, names ending in "scannos", like "myscannos" would match the default name and get reset
                $index = index( $oldpath, 'scannos' )
                  if $index < 0 and basename($oldpath) eq "scannos";
                if ( $index >= 0 ) {    # Old path was in tools or scannos under the release
                    my $oldtail = substr( $oldpath, $index );
                    return $oldpath unless $newtail eq $oldtail;    # Old path was different so keep it
                } else {
                    return $oldpath;                                # Old path was not under release, so keep it
                }
            }

            # Either new and old have matching tails, or no suitable old - return relative path tail
            return $newtail;
        } else {    # Not under tools subfolder - use old if it exists, otherwise use new default
            return $oldpath if $oldpath && -e $oldpath;
            return $newpath;
        }
    } else {
        return ( $oldpath ? $oldpath : $defaultpath );    # If all else fails return old path, or if empty, the default path
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
        $::lglobal{marginspop}->title('Rewrap Margins');
        $::lglobal{marginspop}->resizable( 'no', 'no' );

        my $lmframe = $::lglobal{marginspop}->Frame->pack( -side => 'top', -padx => 5, -pady => 3 );
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
        my $rmframe = $::lglobal{marginspop}->Frame->pack( -side => 'top', -padx => 5, -pady => 3 );
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
        my $button_frame =
          $::lglobal{marginspop}->Frame->pack( -side => 'top', -padx => 5, -pady => 3 );
        my $button_ok = $button_frame->Button(
            -activebackground => $::activecolor,
            -text             => 'OK',
            -command          => sub {
                ::killpopup('marginspop');
                if ( ( $::blockrmargin < $::blocklmargin ) || ( $::rmargin < $::lmargin ) ) {
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
        )->grid( -row => 3, -column => 2, -pady => 5 );

        ::initialize_popup_with_deletebinding('marginspop');
    }
    $::lglobal{marginspop}->raise;
    $::lglobal{marginspop}->focus;
}

#
# Pop dialog for user to set fonts used for interface and text window
sub setfonts {
    my $textwindow = $::textwindow;
    my $top        = $::top;
    if ( defined( $::lglobal{fontpop} ) ) {
        $::lglobal{fontpop}->deiconify;
        $::lglobal{fontpop}->raise;
        $::lglobal{fontpop}->focus;
    } else {
        $::lglobal{fontpop} = $top->Toplevel;
        $::lglobal{fontpop}->title('Font Preferences');

        my $tframe = $::lglobal{fontpop}->Frame->pack;

        setfontrow( 'proofing', \$::fontname, \$::fontsize, \$::fontweight,
            'Main and Error Windows',
            $tframe, 1 );
        setfontrow( 'unicode', \$::utffontname, \$::utffontsize, \$::utffontweight,
            'Unicode and Greek',
            $tframe, 2 );
        my ( $txtnamew, $txtsizew, $txtweightw ) =
          setfontrow( 'textentry', \$::txtfontname, \$::txtfontsize, \$::txtfontweight,
            'Text Entry Fields',
            $tframe, 3, \$::txtfontsystemuse );
        fontfieldsstate( $::txtfontsystemuse, $txtnamew, $txtsizew, $txtweightw );
        $tframe->Checkbutton(
            -variable => \$::txtfontsystemuse,
            -text     => 'Use System Default For Text Entry Fields',
            -command  => sub {
                textentryfontconfigure();
                fontfieldsstate( $::txtfontsystemuse, $txtnamew, $txtsizew, $txtweightw );
            },
        )->grid( -row => 4, -column => 1, -columnspan => 3, -padx => 5, -pady => 5 );
        my ( $gblnamew, $gblsizew, $gblweightw ) =
          setfontrow( 'global', \$::gblfontname, \$::gblfontsize, \$::gblfontweight,
            'Menus, Labels, Buttons, etc.',
            $tframe, 5, \$::gblfontsystemuse );
        fontfieldsstate( $::gblfontsystemuse, $gblnamew, $gblsizew, $gblweightw );
        $tframe->Checkbutton(
            -variable => \$::gblfontsystemuse,
            -text     => 'Use System Default For Menus, Labels, Buttons, etc.',
            -command  => sub {
                globalfontconfigure();
                fontfieldsstate( $::gblfontsystemuse, $gblnamew, $gblsizew, $gblweightw );
                ::menurebuild();
            },
        )->grid( -row => 6, -column => 1, -columnspan => 3, -padx => 5, -pady => 5 );

        my $button_ok = $::lglobal{fontpop}->Button(
            -activebackground => $::activecolor,
            -text             => 'OK',
            -command          => sub {
                $::top->fontConfigure(
                    'proofing',
                    -family => $::fontname,
                    -size   => $::fontsize,
                    -weight => $::fontweight,
                );
                $::top->fontConfigure(
                    'unicode',
                    -family => $::utffontname,
                    -size   => $::utffontsize,
                    -weight => $::utffontweight,
                );
                textentryfontconfigure();

                ::killpopup('fontpop');
                ::savesettings();
            }
        )->pack( -pady => 5 );

        $::lglobal{fontpop}->resizable( 'no', 'no' );
        ::initialize_popup_without_deletebinding('fontpop');

        # Even if dialog closed via window manager, ensure fonts used match dialog settings
        $::lglobal{fontpop}->protocol( 'WM_DELETE_WINDOW' => sub { $button_ok->invoke; } );
    }
}

#
# Create row of widgets to configure given font using refs to relevant global variables
# Return list of created widgets
sub setfontrow {
    my $name    = shift;
    my $rfamily = shift;
    my $rsize   = shift;
    my $rweight = shift;
    my $label   = shift;
    my $tframe  = shift;
    my $row     = shift;
    my $rsystem = shift;

    my $top = $::top;

    # Font family
    my $fontlist = $tframe->BrowseEntry(
        -label     => $label . ": ",
        -browsecmd => sub {
            $top->fontConfigure( $name, -family => $$rfamily );
            fontgeometryupdate();
        },
        -variable => $rfamily,
    )->grid( -row => $row, -column => 1, -padx => 5, -pady => 5, -sticky => 'e' );
    $fontlist->insert( 'end', sort( $top->fontFamilies ) );

    # Font size
    my $sizeentry = $tframe->Spinbox(
        -textvariable => $rsize,
        -width        => 4,
        -increment    => 1,
        -from         => 1,
        -to           => 1000,
        -validate     => 'all',
        -vcmd         => sub { fontsizevalidate( $name, $$rsystem, @_ ); },
    )->grid( -row => $row, -column => 2, -pady => 5 );

    # User can hit Return/Enter to apply the font size they have typed
    for (qw/Return KP_Enter/) {
        $sizeentry->bind(
            "<$_>" => sub {
                $::top->fontConfigure( $name, -size => $$rsize );
                fontgeometryupdate();
            }
        );
    }

    # Font weight
    my $chkbtn = $tframe->Checkbutton(
        -variable => $rweight,
        -onvalue  => 'bold',
        -offvalue => 'normal',
        -command  => sub {
            $::top->fontConfigure( $name, -weight => $$rweight );
            fontgeometryupdate();
        },
        -text => 'Bold'
    )->grid( -row => $row, -column => 3, -pady => 5 );

    return ( $fontlist, $sizeentry, $chkbtn );
}

#
# Validation routine for font size SpinBoxes - must be numeric and >= 1.
# If user is not in the process of editing, e.g. routine called due to loss of focus
# or because linked textvariable changes, then reconfigure the font.
# Note: accepts empty string because user might be in the process of editing.
sub fontsizevalidate {
    my $font     = shift;
    my $system   = shift;
    my $val      = shift;
    my $useredit = defined shift;
    my $top      = $::top;

    return 1 if $system;                     # No need to validate if using system font
    return 1 if $val eq '';                  # OK - user might delete then type new number
    return 0 if $val =~ /\D/ or $val < 1;    # invalid font size
                                             # don't update if user is just editing; use $val as $::fontsize isn't set yet
    unless ($useredit) {
        $::top->fontConfigure( $font, -size => $val );
        fontgeometryupdate();
    }
    return 1;
}

#
# Configure the Text Entry widgets' font
# Either set to the system default stored previously or to the user's choice
sub textentryfontconfigure {
    $::top->fontConfigure(
        'textentry',
        -family => ( $::txtfontsystemuse ? $::lglobal{txtfontsystemfamily} : $::txtfontname ),
        -size   => ( $::txtfontsystemuse ? $::lglobal{txtfontsystemsize}   : $::txtfontsize ),
        -weight => ( $::txtfontsystemuse ? $::lglobal{txtfontsystemweight} : $::txtfontweight ),
    );
    fontgeometryupdate();
}

#
# Set state of given widgets to disabled/normal depending on if system font is being used
sub fontfieldsstate {
    my $sysuse = shift;
    while ( my $w = shift ) {
        $w->configure( -state => ( $sysuse ? 'disabled' : 'normal' ) );
    }
}

#
# Configure the global font - used for all widgets except those specifically overridden,
# i.e. text entry fields, the main window, and a few others that use the proofing font or the unicode font
# Either set to the system default stored previously or to the user's choice
sub globalfontconfigure {
    $::top->fontConfigure(
        'global',
        -family => ( $::gblfontsystemuse ? $::lglobal{gblfontsystemfamily} : $::gblfontname ),
        -size   => ( $::gblfontsystemuse ? $::lglobal{gblfontsystemsize}   : $::gblfontsize ),
        -weight => ( $::gblfontsystemuse ? $::lglobal{gblfontsystemweight} : $::gblfontweight ),
    );
    fontgeometryupdate();
}

#
# Update widgets that need to be alerted to font size change
sub fontgeometryupdate {
    ::menurebuild();
    ::setsearchpopgeometry();
}

sub setpngspath {
    my $textwindow = $::textwindow;
    my $top        = $::top;

    #print $pagenum.'';
    my $path = $textwindow->chooseDirectory(
        -title      => 'Choose the PNGs file directory',
        -initialdir => "$::globallastpath" . "pngs",
    );
    return unless defined $path and -e $path;
    $path .= '/';
    $path       = ::os_normal($path);
    $::pngspath = $path;
    ::setedited(1);
}

# Pop up a window where you can adjust the auto save interval
sub saveinterval {
    my $top = $::top;
    if ( $::lglobal{intervalpop} ) {
        $::lglobal{intervalpop}->deiconify;
        $::lglobal{intervalpop}->raise;
    } else {
        $::lglobal{intervalpop} = $top->Toplevel;
        $::lglobal{intervalpop}->title('Auto Save Interval');
        $::lglobal{intervalpop}->resizable( 'no', 'no' );
        ::initialize_popup_with_deletebinding('intervalpop');
        my $frame = $::lglobal{intervalpop}->Frame->pack( -fill => 'x', -padx => 5, -pady => 5 );
        $frame->Label( -text => 'Minutes between auto save' )->pack( -side => 'left' );
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
        my $frame1 = $::lglobal{intervalpop}->Frame->pack( -fill => 'x', -padx => 5, -pady => 5 );
        $frame->Label( -text => '(1-999)' )->pack( -side => 'left' );
        my $button = $frame1->Button(
            -text    => 'OK',
            -command => sub {
                $::autosaveinterval = 5 unless $::autosaveinterval;
                ::killpopup('intervalpop');
            },
        )->pack;
        $entry->selectionRange( 0, 'end' );
    }
}

# If autosave is on, then reset the timers
# If autosave is off, then ensure timers are cancelled
sub reset_autosave {

    # Start by cancelling the timers if they are running
    $::lglobal{autosaveid}->cancel if $::lglobal{autosaveid};
    undef $::lglobal{autosaveid};
    $::lglobal{saveflashid}->cancel if $::lglobal{saveflashid};
    undef $::lglobal{saveflashid};
    $::lglobal{saveflashingid}->cancel if $::lglobal{saveflashingid};
    undef $::lglobal{saveflashingid};

    # If autosave is on, then (re-)start the timers
    if ($::autosave) {
        my $top = $::top;

        # Timer to do an autosave
        $::lglobal{autosaveid} = $top->repeat(
            $::autosaveinterval * 60000,
            sub {
                ::savefile()
                  if ::isedited()
                  and $::lglobal{global_filename} !~ /No File Loaded/;
            }
        );

        # Timer for when to start flash warning 10 seconds before autosave
        $::lglobal{saveflashid} = $top->after(
            $::autosaveinterval * 60000 - 10000,
            sub {
                my $textwindow = $::textwindow;
                flash_autosave($textwindow)
                  if $::lglobal{global_filename} !~ /No File Loaded/;
            }
        );
    }

    storedefaultcolor_autosave();

    # Ensure the icon is the right color
    $::lglobal{savetool}->configure(
        -background       => $::autosave ? 'green' : $::lglobal{savetoolcolor},
        -activebackground => $::autosave ? 'green' : $::lglobal{savetoolcolor}
    ) if $::lglobal{savetool};

    ::savesettings();
}

# Set a timer to flash the save icon green/yellow to warn autosave is imminent
sub flash_autosave {
    $::lglobal{saveflashingid} = $::top->repeat(
        500,
        sub {
            return unless $::lglobal{savetool};
            my $textwindow = $::textwindow;
            storedefaultcolor_autosave();
            if ( $::lglobal{savetool}->cget('-background') eq 'yellow' ) {
                $::lglobal{savetool}->configure(
                    -background       => 'green',
                    -activebackground => 'green'
                ) unless $::notoolbar;
            } else {
                $::lglobal{savetool}->configure(
                    -background       => 'yellow',
                    -activebackground => 'yellow'
                ) if ( $textwindow->numberChanges and ( !$::notoolbar ) );
            }
        }
    );
}

# Store save icon's default background color so it can be restored when turning off autosave
sub storedefaultcolor_autosave {
    return if $::lglobal{savetoolcolor};    # once stored, don't overwrite the color later
    return unless $::lglobal{savetool};     # can't get color if icon not shown
    $::lglobal{savetoolcolor} = $::lglobal{savetool}->cget('-background');
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
    if ($filetypes) {
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
        -initialdir => ::dirname( ${$exepathref} ),
    );
    ${$exepathref} = $::lglobal{pathtemp}
      if $::lglobal{pathtemp};
    return unless ${$exepathref};
    ${$exepathref} = ::os_normal( ${$exepathref} );
    ::savesettings();
}

#
# Allow user to choose a new directory containing scannos, tools, etc.
# Accepts current setting and displays the directory that contains it
sub locateDirectory {
    my ( $dirname, $dirpathref ) = @_;
    my $textwindow = $::textwindow;
    $::lglobal{pathtemp} = $textwindow->chooseDirectory(
        -title      => "Where is your $dirname folder?",
        -initialdir => ::dirname( ${$dirpathref} ),
        -mustexist  => 1,
    );
    ${$dirpathref} = $::lglobal{pathtemp} if $::lglobal{pathtemp};
    return unless ${$dirpathref};
    ${$dirpathref} = ::os_normal( ${$dirpathref} );

    # If possible, convert to relative path by trimming release root directory and slash from start
    if ( index( ${$dirpathref}, $::lglobal{guigutsdirectory} ) == 0
        and length( ${$dirpathref} ) > length( $::lglobal{guigutsdirectory} ) ) {
        ${$dirpathref} = substr( ${$dirpathref}, length( $::lglobal{guigutsdirectory} ) + 1 );
    }
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
        $::lglobal{filepathspop}->title('File Paths');
        my $f1 = $::lglobal{filepathspop}->Frame->pack(
            -side   => 'top',
            -anchor => 'n',
            -fill   => 'x'
        );
        $f1->Label(
            -text   => "Image Viewer:",
            -width  => 22,
            -anchor => 'w',
        )->pack( -side => 'left' );
        $f1->Button(
            -text    => 'Locate Image Viewer...',
            -command => sub { ::locateExecutable( 'image viewer', \$::globalviewerpath ); },
            -width   => 24,
        )->pack( -side => 'right' );
        $f1->Entry(
            -textvariable => \$::globalviewerpath,
            -width        => 60,
            -relief       => 'sunken',
            -background   => $::bkgcolor,
        )->pack( -expand => 'y', -fill => 'x' );
        my $f2 = $::lglobal{filepathspop}->Frame->pack(
            -side   => 'top',
            -anchor => 'n',
            -fill   => 'x'
        );
        $f2->Label(
            -text   => "Aspell:",
            -width  => 22,
            -anchor => 'w',
        )->pack( -side => 'left' );
        $f2->Button(
            -text    => 'Locate Aspell...',
            -command => sub { ::locateExecutable( 'Aspell', \$::globalspellpath ); },
            -width   => 24,
        )->pack( -side => 'right' );
        $f2->Entry(
            -textvariable => \$::globalspellpath,
            -relief       => 'sunken',
            -background   => $::bkgcolor,
        )->pack( -expand => 'y', -fill => 'x' );
        my $f3 = $::lglobal{filepathspop}->Frame->pack(
            -side   => 'top',
            -anchor => 'n',
            -fill   => 'x'
        );
        $f3->Label(
            -text   => "Bookloupe:",
            -width  => 22,
            -anchor => 'w',
        )->pack( -side => 'left' );
        $f3->Button(
            -text    => 'Locate Bookloupe...',
            -command => sub { ::locateExecutable( 'Bookloupe', \$::gutcommand ); },
            -width   => 24,
        )->pack( -side => 'right' );
        $f3->Entry(
            -textvariable => \$::gutcommand,
            -relief       => 'sunken',
            -background   => $::bkgcolor,
        )->pack( -expand => 'y', -fill => 'x' );
        my $f4 = $::lglobal{filepathspop}->Frame->pack(
            -side   => 'top',
            -anchor => 'n',
            -fill   => 'x'
        );
        $f4->Label(
            -text   => "Jeebies:",
            -width  => 22,
            -anchor => 'w',
        )->pack( -side => 'left' );
        $f4->Button(
            -text    => 'Locate Jeebies...',
            -command => sub { ::locateExecutable( 'Jeebies', \$::jeebiescommand ); },
            -width   => 24,
        )->pack( -side => 'right' );
        $f4->Entry(
            -textvariable => \$::jeebiescommand,
            -relief       => 'sunken',
            -background   => $::bkgcolor,
        )->pack( -expand => 'y', -fill => 'x' );
        my $f5 = $::lglobal{filepathspop}->Frame->pack(
            -side   => 'top',
            -anchor => 'n',
            -fill   => 'x'
        );
        $f5->Label(
            -text   => "HTML Tidy:",
            -width  => 22,
            -anchor => 'w',
        )->pack( -side => 'left' );
        $f5->Button(
            -text    => 'Locate Tidy...',
            -command => sub { ::locateExecutable( 'HTML Tidy', \$::tidycommand ); },
            -width   => 24,
        )->pack( -side => 'right' );
        $f5->Entry(
            -textvariable => \$::tidycommand,
            -relief       => 'sunken',
            -background   => $::bkgcolor,
        )->pack( -expand => 'y', -fill => 'x' );
        my $f6 = $::lglobal{filepathspop}->Frame->pack(
            -side   => 'top',
            -anchor => 'n',
            -fill   => 'x'
        );
        $f6->Label(
            -text   => "Nu HTML Checker:",
            -width  => 22,
            -anchor => 'w',
        )->pack( -side => 'left' );
        my $jartypes = [ [ 'JAR file', [ '.jar', ] ], [ 'All Files', ['*'] ], ];
        $f6->Button(
            -text    => 'Locate Nu HTML Checker...',
            -command => sub {
                ::locateExecutable( 'Nu HTML Checker (vnu.jar)', \$::validatecommand, $jartypes );
            },
            -width => 24,
        )->pack( -side => 'right' );
        $f6->Entry(
            -textvariable => \$::validatecommand,
            -relief       => 'sunken',
            -background   => $::bkgcolor,
        )->pack( -expand => 'y', -fill => 'x' );
        my $f7 = $::lglobal{filepathspop}->Frame->pack(
            -side   => 'top',
            -anchor => 'n',
            -fill   => 'x'
        );
        $f7->Label(
            -text   => "W3C CSS Validator:",
            -width  => 22,
            -anchor => 'w',
        )->pack( -side => 'left' );
        $f7->Button(
            -text    => 'Locate CSS Validator...',
            -command => sub {
                ::locateExecutable( 'W3C CSS Validator (css-validate.jar)',
                    \$::validatecsscommand, $jartypes );
            },
            -width => 24,
        )->pack( -side => 'right' );
        $f7->Entry(
            -textvariable => \$::validatecsscommand,
            -relief       => 'sunken',
            -background   => $::bkgcolor,
        )->pack( -expand => 'y', -fill => 'x' );
        my $f8 = $::lglobal{filepathspop}->Frame->pack(
            -side   => 'top',
            -anchor => 'n',
            -fill   => 'x'
        );
        $f8->Label(
            -text   => "EBookMaker:",
            -width  => 22,
            -anchor => 'w',
        )->pack( -side => 'left' );
        $f8->Button(
            -text    => 'Locate EBookMaker...',
            -command => sub { ::locateExecutable( 'ebookmaker.exe', \$::ebookmakercommand ); },
            -width   => 24,
        )->pack( -side => 'right' );
        $f8->Entry(
            -textvariable => \$::ebookmakercommand,
            -relief       => 'sunken',
            -background   => $::bkgcolor,
        )->pack( -expand => 'y', -fill => 'x' );
        my $f8b = $::lglobal{filepathspop}->Frame->pack(
            -side   => 'top',
            -anchor => 'n',
            -fill   => 'x'
        );
        my $f9 = $::lglobal{filepathspop}->Frame->pack(
            -side   => 'top',
            -anchor => 'n',
            -fill   => 'x'
        );
        $f9->Label(
            -text   => "Scannos folder:",
            -width  => 22,
            -anchor => 'w',
        )->pack( -side => 'left' );
        $f9->Button(
            -text    => 'Locate Scannos...',
            -command => sub { locateDirectory( 'scannos', \$::scannospath ); },
            -width   => 24,
        )->pack( -side => 'right' );
        $f9->Entry(
            -textvariable => \$::scannospath,
            -relief       => 'sunken',
            -background   => $::bkgcolor,
        )->pack( -expand => 'y', -fill => 'x' );
        my $f0 = $::lglobal{filepathspop}->Frame->pack(
            -side   => 'top',
            -anchor => 'n',
            -fill   => 'x'
        );
        $f0->Label(
            -text   => "Browser command:",
            -width  => 22,
            -anchor => 'w',
        )->pack( -side => 'left' );
        $f0->Entry(
            -textvariable => \$::extops[0]{command},
            -relief       => 'sunken',
            -background   => $::bkgcolor,
        )->pack( -expand => 'y', -fill => 'x' );
        $::lglobal{filepathspop}->Button(
            -activebackground => $::activecolor,
            -text             => 'OK',
            -command          => sub {
                ::killpopup('filepathspop');
                ::savesettings();
            }
        )->pack;
        $::lglobal{filepathspop}->Tk::bind( '<Return>' => sub { ::killpopup('filepathspop'); } );
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
        $::lglobal{defurlspop}->title('DP URLs');
        my $f0 = $::lglobal{defurlspop}->Frame->pack( -side => 'top', -anchor => 'n' );
        $f0->Label( -text => "View project page of projectid:" )
          ->grid( -row => 3, -column => 0, -sticky => 'w' );
        $f0->Entry(
            -width        => 70,
            -textvariable => \$::urlprojectpage,
            -relief       => 'sunken',
            -background   => $::bkgcolor,
        )->grid( -row => 3, -column => 1, -pady => 2 );
        $f0->Label( -text => "View project discussion of projectid:" )
          ->grid( -row => 4, -column => 0, -sticky => 'w' );
        $f0->Entry(
            -width        => 70,
            -textvariable => \$::urlprojectdiscussion,
            -relief       => 'sunken',
            -background   => $::bkgcolor,
        )->grid( -row => 4, -column => 1, -pady => 2 );
        $f0->Button(
            -activebackground => $::activecolor,
            -text             => 'OK',
            -command          => sub {
                ::killpopup('defurlspop');
                ::savesettings();
            }
        )->grid( -row => 5, -column => 0, -columnspan => 2, -pady => 5 );
        ::initialize_popup_with_deletebinding('defurlspop');
    }
}

#
# Pop dialog for user to choose which key/combination will initialize Composing
sub composekeypopup {
    my $top = $::top;

    $::lglobal{composekeycombination} = $::composepopbinding;
    $::lglobal{composekeyshift}       = ( $::lglobal{composekeycombination} =~ /Shift-/ );
    $::lglobal{composekeycontrol}     = ( $::lglobal{composekeycombination} =~ /Control-/ );
    $::lglobal{composekeyalt}         = ( $::lglobal{composekeycombination} =~ /Alt-/ );
    $::lglobal{composekeybase}        = $::lglobal{composekeycombination};
    $::lglobal{composekeybase} =~ s/.+-//;    # remove modifiers to find base key

    if ( defined( $::lglobal{composekeypop} ) ) {
        $::lglobal{composekeypop}->deiconify;
        $::lglobal{composekeypop}->raise;
        $::lglobal{composekeypop}->focus;
    } else {
        $::lglobal{composekeypop} = $top->Toplevel;
        $::lglobal{composekeypop}->title('Set Compose Key');
        $::lglobal{composekeypop}->Label( -text =>
              "Press the key to use for starting Compose Sequences\nAlso select Shift, Control and/or Alt modifiers if required",
        )->pack;
        my $f0 = $::lglobal{composekeypop}->Frame->pack( -side => 'top', -anchor => 'n' );
        $f0->Checkbutton(
            -text     => 'Shift',
            -variable => \$::lglobal{composekeyshift},
            -command  => \&composekeypopupbind,
        )->grid( -row => 1, -column => 1 );
        $f0->Checkbutton(
            -text     => 'Control',
            -variable => \$::lglobal{composekeycontrol},
            -command  => \&composekeypopupbind,
        )->grid( -row => 1, -column => 2 );
        $f0->Checkbutton(
            -text     => 'Alt',
            -variable => \$::lglobal{composekeyalt},
            -command  => \&composekeypopupbind,
        )->grid( -row => 1, -column => 3 );
        my $f1       = $::lglobal{composekeypop}->Frame->pack( -side => 'top', -anchor => 'n' );
        my $entrybox = $f1->Entry(
            -width        => 25,
            -textvariable => \$::lglobal{composekeycombination},
            -state        => 'readonly',
        )->pack;
        $f1->Button(
            -command => sub { ::killpopup('composekeypop'); },
            -text    => 'OK',
        )->pack( -pady => 5 );
        $::lglobal{composekeypop}->Tk::bind( '<Key>', \&composekeypopupcallback );
        ::initialize_popup_with_deletebinding('composekeypop');
    }
}

#
# Given base key, set the combination to be used for Composing
sub composekeypopupcallback {
    my $widget = shift;
    $::lglobal{composekeybase} = $widget->XEvent->K;
    composekeypopupbind();
}

#
# Bind the Compose dialog to the chosen combination of modifiers and base
sub composekeypopupbind {

    ::keybind( "<$::composepopbinding>", undef );    # Unbind previous key

    # Combine the modifiers with the base key
    $::composepopbinding = '';
    $::composepopbinding .= 'Shift-'   if $::lglobal{composekeyshift};
    $::composepopbinding .= 'Control-' if $::lglobal{composekeycontrol};
    $::composepopbinding .= 'Alt-'     if $::lglobal{composekeyalt};
    $::lglobal{composekeybase} = 'Alt_R' unless $::lglobal{composekeybase};    # sensible default
    $::composepopbinding .= $::lglobal{composekeybase};

    ::keybind( "<$::composepopbinding>", sub { ::composepopup(); } );          # Rebind new combination

    $::lglobal{composekeycombination} = $::composepopbinding;                  # Update dialog entry box
}

1;
