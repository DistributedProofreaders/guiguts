package Guiguts::Utilities;
use strict;
use warnings;
use POSIX qw /strftime /;
use File::HomeDir qw /home/;
use Getopt::Long;

BEGIN {
    use Exporter();
    our ( @ISA, @EXPORT );
    @ISA    = qw(Exporter);
    @EXPORT = qw(&openpng &get_image_file &arabic &roman &popscroll
      &cmdinterp &nofileloadedwarning &win32_cmdline &win32_start &dialogboxcommonsetup &textentrydialogpopup
      &win32_is_exe &win32_create_process &dos_path &runner &run &launchurl &escape_regexmetacharacters
      &deaccentsort &deaccentdisplay &readlabels &working &initialize &initialize_popup_with_deletebinding
      &initialize_popup_without_deletebinding &titlecase &os_normal &escape_problems &natural_sort_alpha
      &natural_sort_length &natural_sort_freq &drag &cut &paste &entrypaste &textcopy &colcut &colcopy &colpaste &showversion
      &checkforupdates &checkforupdatesmonthly &gotobookmark &setbookmark &seeindex &ebookmaker
      &sidenotes &poetrynumbers &get_page_number &externalpopup &add_entry_history &entry_history
      &xtops &toolbar_toggle &killpopup &expandselection
      &getprojectid &setprojectid &viewprojectcomments &viewprojectdiscussion &viewprojectpage
      &scrolldismiss &updatedrecently &hidelinenumbers &restorelinenumbers &displaylinenumbers &displaycolnumbers
      &enable_interrupt &disable_interrupt &set_interrupt &query_interrupt &soundbell &busy &unbusy
      &dieerror &warnerror &infoerror &poperror &BindMouseWheel &display_manual
      &path_settings &path_htmlheader &path_defaulthtmlheader &path_labels &path_defaultlabels &path_userdict &path_defaultdict
      &path_userhtmlheader &processcommandline &copysettings &main_lang &list_lang &setwidgetdefaultoptions);

}

#
# Get name of scan file for given page number
sub get_image_file {
    my $pagenum = shift;
    my $imagefile;
    unless ($::pngspath) {
        if ($::OS_WIN) {
            $::pngspath = "${main::globallastpath}pngs\\";
        } else {
            $::pngspath = "${main::globallastpath}pngs/";
        }
        ::setpngspath() unless ( -e "$::pngspath$pagenum.png" );
    }
    if ($::pngspath) {
        $imagefile = "$::pngspath$pagenum.png";
        unless ( -e $imagefile ) {
            $imagefile = "$::pngspath$pagenum.jpg";
        }
        unless ( -e $imagefile ) {
            print "Image file $imagefile doesn't exist.\n";
        }
    }
    return $imagefile;
}

#
# Routine to handle image viewer file requests
sub openpng {
    my ( $textwindow, $pagenum ) = @_;
    if ( $pagenum eq 'Pg' ) {
        return;
    }
    $::lglobal{pageimageviewed} = $pagenum;
    if ( not $::globalviewerpath ) {
        ::locateExecutable( 'image viewer', \$::globalviewerpath );
        return unless $::globalviewerpath;
    }
    my $imagefile = ::get_image_file($pagenum);
    if ( $imagefile && $::globalviewerpath ) {
        my $focuswidget = $textwindow->focusCurrent;    # remember which widget had focus before spawning viewer
        ::runner( $::globalviewerpath, $imagefile );
        my $grabperiod   = 200;                         # try to get focus back for 200 milliseconds
        my $grabinterval = 10;                          # try to get focus back every 10 milliseconds
        for ( 1 .. ( $grabperiod / $grabinterval ) ) {
            $textwindow->after($grabinterval);
            $focuswidget = $textwindow unless Tk::Exists($focuswidget);    # in case focus widget has been destroyed during delay
            $focuswidget->focusForce;
        }
    } else {
        ::setpngspath();
    }
    return;
}

#
# Roman numeral conversion taken directly from the Roman.pm module Copyright
# (c) 1995 OZAWA Sakuro. Done to avoid users having to install downloadable
# modules.
sub roman {
    my %roman_digit = qw(1 IV 10 XL 100 CD 1000 MMMMMM);
    my @figure      = reverse sort keys %roman_digit;
    grep( $roman_digit{$_} = [ split( //, $roman_digit{$_}, 2 ) ], @figure );
    my $arg = shift;
    return unless defined $arg;
    0 < $arg and $arg < 4000 or return;
    my ( $x, $roman );
    foreach (@figure) {
        my ( $digit, $i, $v ) = ( int( $arg / $_ ), @{ $roman_digit{$_} } );
        if ( 1 <= $digit and $digit <= 3 ) {
            $roman .= $i x $digit;
        } elsif ( $digit == 4 ) {
            $roman .= "$i$v";
        } elsif ( $digit == 5 ) {
            $roman .= $v;
        } elsif ( 6 <= $digit
            and $digit <= 8 ) {
            $roman .= $v . $i x ( $digit - 5 );
        } elsif ( $digit == 9 ) {
            $roman .= "$i$x";
        }
        $arg -= $digit * $_;
        $x = $i;
    }

    #return "$roman.";
    return "$roman";    # getting rid of trailing dot
}

#
# Roman to Arabic conversion
sub arabic {
    my $arg = shift;
    return $arg
      unless $arg =~ /^(?: M{0,3})
                (?: D?C{0,3} | C[DM])
                (?: L?X{0,3} | X[LC])
                (?: V?I{0,3} | I[VX])\.?$/ix;
    $arg =~ s/\.$//;
    my %roman2arabic = qw(I 1 V 5 X 10 L 50 C 100 D 500 M 1000);
    my $last_digit   = 1000;
    my $arabic;
    foreach ( split( //, uc $arg ) ) {
        $arabic -= 2 * $last_digit if $last_digit < $roman2arabic{$_};
        $arabic += ( $last_digit = $roman2arabic{$_} );
    }
    return $arabic;
}

#
# Begin (or end) button 2 scrolling of main window
sub popscroll {
    if ( $::lglobal{scroller} ) {
        scrolldismiss();
        return;
    }
    my $x = $::top->pointerx - $::top->rootx;
    my $y = $::top->pointery - $::top->rooty - 8;
    $::lglobal{scroller} = $::top->Label(
        -background         => $::textwindow->cget( -bg ),
        -image              => $::lglobal{scrollgif},
        -cursor             => 'double_arrow',
        -borderwidth        => 0,
        -highlightthickness => 0,
        -relief             => 'flat',
    )->place( -x => $x, -y => $y );
    $::lglobal{scroller}->eventAdd( '<<ScrollDismiss>>', qw/<1> <3>/ );
    $::lglobal{scroller}->bind( 'current', '<<ScrollDismiss>>', sub { &scrolldismiss(); } );
    $::lglobal{scroll_y}  = $y;
    $::lglobal{scroll_x}  = $x;
    $::lglobal{oldcursor} = $::textwindow->cget( -cursor );
    %{ $::lglobal{scroll_cursors} } = (
        '-1-1' => 'top_left_corner',
        '-10'  => 'top_side',
        '-11'  => 'top_right_corner',
        '0-1'  => 'left_side',
        '00'   => 'double_arrow',
        '01'   => 'right_side',
        '1-1'  => 'bottom_left_corner',
        '10'   => 'bottom_side',
        '11'   => 'bottom_right_corner',
    );
    $::lglobal{scroll_id} = $::top->repeat( $::scrollupdatespd, \&b2scroll );
}

#
# Command parsing for External command routine
sub cmdinterp {

    # Allow basic quoting, in case anyone specifies paths with spaces.
    # Don't support paths with quotes.  The standard \" and \\ escapes
    # would not be friendly on Windows-style paths.
    my $textwindow = $::textwindow;
    my @args       = shift =~ m/"[^"]+"|\S+/g;
    my ( $fname, $pagenum, $number, $pname );
    my ( $selection, $ranges );
    foreach my $arg (@args) {

        # not sure why we'd want this, so leaving it in for windows
        # - it breaks e.g. urls with & (which windows can't do anyway)
        $arg =~ s/^"(.*)"$/$1/g if ($::OS_WIN);

        # Replace $t with selected text for instance for a dictionary search
        if ( $arg =~ m/\$t/ ) {
            my @ranges = $textwindow->tagRanges('sel');
            if (@ranges) {
                my $end   = pop(@ranges);
                my $start = pop(@ranges);
                $selection = $textwindow->get( $start, $end );
            } else {
                $selection = '';
            }
            $arg =~ s/\$t/$selection/g;

            # Windows uses systemW in place of system later, so don't encode here
            $arg = ::encode( "utf-8", $arg ) unless $::OS_WIN;
        }

        # Pass file to default file handler, $f $d $e give the fully specified path/filename
        if ( $arg =~ m/\$f|\$d|\$e/ ) {
            return if nofileloadedwarning();
            $fname = $::lglobal{global_filename};
            my ( $f, $d, $e ) = ::fileparse( $fname, qr{\.[^\.]*$} );
            $arg =~ s/\$f/$f/g if $f;
            $arg =~ s/\$d/$d/g if $d;
            $arg =~ s/\$e/$e/g if $e;
        }

        # Pass image file to default file handler
        if ( $arg =~ m/\$p/ ) {
            return unless $::lglobal{img_num_label};
            $number = $::lglobal{img_num_label}->cget( -text );
            $number =~ s/.+?(\d+).*/$1/;
            $pagenum = $number;
            return ' ' unless $pagenum;
            $arg =~ s/\$p/$number/g;
        }
        if ( $arg =~ m/\$i/ ) {
            return ' ' unless $::pngspath;
            $arg =~ s/\$i/$::pngspath/g;
        }
    }
    return @args;
}

#
# Return true (& issue warning) if contents of main window are not associated with a named file,
# e.g. if it has never been saved, or no file has ever been loaded
sub nofileloadedwarning {
    my $top = $::top;
    if ( $::lglobal{global_filename} =~ m/No File Loaded/ ) {
        my $dialog = $top->Dialog(
            -text    => "File has not been saved.",
            -bitmap  => 'warning',
            -title   => "No Filename",
            -buttons => ['OK']
        );
        my $answer = $dialog->Show;
        return 1;
    }
    return 0;
}

#
# Handle quoting of command line arguments for Windows systems
sub win32_cmdline {
    my @args = @_;

    # <http://blogs.msdn.com/b/twistylittlepassagesallalike/archive/2011/04/23/
    #  everyone-quotes-arguments-the-wrong-way.aspx>
    #
    # which includes perl's system(LIST).  So we do our own quoting.
    #
    foreach (@args) {
        s/(\\*)\"/$!$!\\\"/g;
        s/^(.*)(\\*)$/\"$1$2$2\"/ if m/[ "]/;
        s/&/^&/g;    # Windows command line escapes & with ^
    }
    return join " ", @args;
}

#
# Use Windows "start" command to use default program to open a file
sub win32_start {
    my @args = @_;

    # Windows command to open a file (or URL) using the default program
    # start command must be run through CMD.EXE
    # (we don't have Win32:Gui, or we could use ShellExecute())
    #
    # <http://www.autohotkey.net/~deleyd/parameters/parameters.htm>
    #
    # Other external commands can go through win32_create_process(),
    # which doesn't have this limitation.
    #
    foreach (@args) {
        if (m/["<>|()!%^]/) {
            warn 'Refusing to run "start" command with unsafe characters ("<>|()!%^): '
              . join( " ", @args );
            return -1;
        }
    }

    # <http://stackoverflow.com/questions/72671/
    #  how-to-create-batch-file-in-windows-using-start-with-a-path-and-command-with-s
    #
    # Users never need to create a titled DOS window,
    # but they may need to run the 'start' command on files with spaces.
    #
    # If first argument after 'start' has quotes, it is interpreted as a title
    # for the commmand window. So if a command has spaces in it, and so has
    # quotes, the command is interpreted as the window title and doesn't execute.
    # To solve this, add a dummy title argument. Note that it must have spaces
    # because if it isn't quoted it will be interpreted as the command. Windows!
    @args = ( 'start', 'Guiguts Command Window', @args );
    my $cmdline = win32_cmdline(@args);
    require Win32::Unicode::Process;
    Win32::Unicode::Process::systemW $cmdline;    # systemW is like system, but copes with utf8 encoding correctly.
}

#
# Check file is a Windows executable
sub win32_is_exe {
    my ($exe) = @_;
    return -x $exe && !-d $exe;
}

#
# Find Windows executable (searching path if necessary)
sub win32_find_exe {
    my ($exe) = @_;
    return $exe if win32_is_exe($exe);
    foreach my $ext ( split ';', $::ENV{PATHEXT} ) {
        my $p = $exe . $ext;
        return $p if win32_is_exe($p);
    }
    if ( !File::Spec->file_name_is_absolute($exe) ) {
        foreach my $path ( split ';', $::ENV{PATH} ) {
            my $stem = ::catfile( $path, $exe );
            return $stem if win32_is_exe($stem);
            foreach my $ext ( split ';', $::ENV{PATHEXT} ) {
                my $p = $stem . $ext;
                return $p if win32_is_exe($p);
            }
        }
    }

    # No such program; caller will find out :).
    return $exe;
}

#
# Create subprocess to run Windows executable
sub win32_create_process {
    require Win32;
    require Win32::Process;
    my @args    = @_;
    my $exe     = win32_find_exe( $args[0] );
    my $cmdline = win32_cmdline(@args);
    my $proc;
    if ( Win32::Process::Create( $proc, $exe, $cmdline, 1, 0, '.' ) ) {
        return $proc;
    } else {
        warn "Failed to run $args[0]: " . Win32::FormatMessage( Win32::GetLastError() );
        return undef;
    }
    return;
}

#
# This turns long Windows path to DOS path, e.g., C:\Program Files\
# becomes C:\Progra~1\.
# Removed from code in 1.0.6 (why?), reintroduced 1.0.22
# to fix Link Check etc. failing with spaces in names
sub dos_path {
    return Win32::GetShortPathName( $_[0] );
}

#
# Return path to setting.rc
sub path_settings {
    return ::catfile( $::lglobal{homedirectory}, 'setting.rc' );
}

#
# Return path to header.txt
sub path_htmlheader {
    return ::catfile( $::lglobal{homedirectory}, 'header.txt' );
}

#
# Return path to headerdefault.txt
sub path_defaulthtmlheader {
    return 'headerdefault.txt';
}

#
# Return path to header_user.txt
sub path_userhtmlheader {
    return ::catfile( $::lglobal{homedirectory}, 'header_user.txt' );
}

#
# Return path to user-editable file normally in data directory,
# but may be in directory specified by user using --home
sub path_data {
    my $fname            = shift;
    my $homedirectory    = $::lglobal{homedirectory};
    my $guigutsdirectory = $::lglobal{guigutsdirectory};

    # Windows and macOS have case-insensitive filesystems. Lowercase
    # the paths before comparing them
    if ( $::OS_WIN or $::OS_MAC ) {
        $homedirectory    = lc $homedirectory;
        $guigutsdirectory = lc $guigutsdirectory;
    }

    # If we're using --home (a separate data directory), then we store the
    # data file directly there, not in a subdirectory
    if ( $homedirectory ne $guigutsdirectory ) {
        return ::catfile( $::lglobal{homedirectory}, $fname );
    }

    # Otherwise it's stored in a subdirectory data/ from Guiguts' directory
    return ::catfile( $::lglobal{guigutsdirectory}, 'data', $fname );
}

#
# Return path to labels data file
sub path_labels {
    return path_data( "labels_" . ::main_lang() . ".rc" );
}

#
# Return path to default labels data file
sub path_defaultlabels {
    my $f = ::catfile( 'data', "labels_" . ::main_lang() . "_default.rc" );
    return $f if -e $f;

    # Default to English if language has no defaults file
    return ::catfile( 'data', 'labels_en_default.rc' );
}

#
# Return path to spell query user global dictionary for current language
# Optional argument to specify language
sub path_userdict {
    my $lang = shift // ::main_lang();
    return path_data("dict_${lang}_user.txt");
}

#
# Return path to spell query default global dictionary for current language
# Optional argument to specify language
sub path_defaultdict {
    my $lang = shift // ::main_lang();
    return ::catfile( 'data', "dict_${lang}_default.txt" );
}

#
# Return path to default GG homedir location under user's home folder
sub path_defaulthomedir {
    if ( $::OS_WIN or $::OS_MAC ) {
        return ::catdir( File::HomeDir::home(), "Documents", "GGprefs" );
    } else {
        return ::catdir( File::HomeDir::home(), ".GGprefs" );
    }
}

#
# Return the main (first) language in the list of languages for this book
sub main_lang {
    return ( ( ::list_lang() )[0] // "en" );
}

# Return the languages for this book as a list
# Allow space, comma or plus sign as a separator
sub list_lang {
    return split( /[+, ]+/, $::booklang );
}

#
# system(LIST)
# (but slightly more robust, particularly on Windows).
sub run {
    my @args = @_;
    if ( !$::OS_WIN ) {
        if ( File::Which::which( $args[0] ) ) {
            system { $args[0] } @args;
        } else {
            warn "Executable $args[0] not found nor is it on the path";
        }
    } else {
        require Win32;
        require Win32::Process;
        my $proc = win32_create_process(@args);
        return -1 unless defined $proc;
        $proc->Wait( Win32::Process::INFINITE() );
        $proc->GetExitCode( my $exitcode );
        $? = $exitcode << 8;
    }
    return;
}

#
# Launch url in browser
sub launchurl {
    my $url     = shift;
    my $command = $::extops[0]{command};
    eval('$command =~ s/\$d\$f\$e/$url/');
    ::runner( ::cmdinterp($command) );
}

#
# Start an external program
sub runner {
    my @args = @_;
    unless (@args) {
        warn "Tried to run an empty command";
        return -1;
    }
    if ( !$::OS_WIN ) {

        # We can't call perl fork() in the main GUI process, because Tk crashes
        system( "perl $::lglobal{guigutsdirectory}/spawn.pl " . join( ' ', @args ) );
    } else {
        if ( $args[0] eq 'start' ) {
            win32_start( @args[ 1 .. $#args ] );
        } else {
            my $proc = win32_create_process(@args);
            return ( defined $proc ) ? 0 : -1;
        }
    }
    return;
}

#
# Run external program, with stdin, stdout and/or stderr redirected to temporary files
# stdout and stderr can be redirected to the same file
{

    package runner;

    # Specify file to redirect output to, and optionally same/different file for errors
    sub tofile {
        withfiles( undef, @_ );
    }

    # Specify files to redirect input, output and errors to
    # Output and error can be redirected to the same file
    sub withfiles {
        my ( $infile, $outfile, $errfile ) = @_;
        bless {
            infile  => $infile,
            outfile => $outfile,
            errfile => $errfile,
          },
          'runner';
    }

    # Run the given command, redirecting stdin, stdout and/or stderr to files set up
    # using tofile or withfiles
    sub run {
        my ( $self, @args ) = @_;

        # Take copies of existing file descriptors
        my ( $oldstdout, $oldstdin, $oldstderr );
        unless ( open $oldstdin, '<&', \*STDIN ) {
            warn "Failed to save stdin: $!";
            return -1;
        }
        unless ( open $oldstdout, '>&', \*STDOUT ) {
            warn "Failed to save stdout: $!";
            return -1;
        }
        unless ( open $oldstderr, '>&', \*STDERR ) {
            warn "Failed to save stderr: $!";
            return -1;
        }

        # Redirect any that have been set up
        if ( defined $self->{infile} ) {
            unless ( open STDIN, '<', $self->{infile} ) {
                warn "Failed to open '$self->{infile}': $!";
                return -1;
            }
        }
        if ( defined $self->{outfile} ) {
            unless ( open STDOUT, '>', $self->{outfile} ) {
                warn "Failed to open '$self->{outfile}' for writing: $!";
                return -1;    # Don't bother to restore STDIN here.
            }
        }
        if ( defined $self->{errfile} ) {

            # Check if redirecting both output & error to same file
            if ( defined $self->{outfile} and $self->{errfile} eq $self->{outfile} ) {
                unless ( open STDERR, '>&', \*STDOUT ) {
                    warn "Failed to redirect stderr to stdout: $!";
                    return -1;    # Don't bother to restore STDIN here.
                }
            } else {
                unless ( open STDERR, '>', $self->{errfile} ) {
                    warn "Failed to open '$self->{errfile}' for writing: $!";
                    return -1;    # Don't bother to restore STDIN here.
                }
            }
        }

        # Run the command
        ::run(@args);

        #Restore the file descriptors
        close(STDERR);
        unless ( open STDERR, '>&', $oldstderr ) {
            warn "Failed to restore stderr: $!";
        }
        close($oldstderr);
        close(STDOUT);
        unless ( open STDOUT, '>&', $oldstdout ) {
            warn "Failed to restore stdout: $!";
        }
        close($oldstdout);

        # We restore STDIN here, just because perl warns about it otherwise.
        close(STDIN);
        unless ( open STDIN, '<&', $oldstdin ) {
            warn "Failed to restore stdin: $!";
        }
        close($oldstdin);

        # Return any error from the external program
        return $?;
    }
}

#
# Escape metacharacters used in regexps
sub escape_regexmetacharacters {
    my $inputstring = shift;
    $inputstring =~ s/([\{\}\[\]\(\)\^\$\.\|\*\+\?\\])/\\$1/g;
    $inputstring =~ s/\\\\(['-])/\\$1/g;
    return $inputstring;
}

#
# Deaccent string in a suitable manner for alphabetic sorting
# Needs to be as fast as possible, since called a lot when sorting large array
sub deaccentsort {
    my $phrase = shift;
    $phrase =~ s/\p{Mark}//g;                              # First remove any combining marks from phrase
    if ( $phrase =~ /[$::convertcharssinglesearch]/ ) {    # do we need the slow tr?
        eval
          "\$phrase =~ tr/$::convertlatinsinglesearch$::convertcharssinglesearch/$::convertlatinsinglereplace$::convertcharssinglereplace/";
    } elsif ( $phrase =~ /[$::convertlatinsinglesearch]/ ) {    # do we need tr at all?
        eval "\$phrase =~ tr/$::convertlatinsinglesearch/$::convertlatinsinglereplace/";
    } elsif ( $phrase !~ /[$::convertcharsmultisearch]/ ) {     # Contains no chars we need to treat specially
        return $phrase;
    }
    $phrase =~ s/([$::convertcharsmultisearch])/$::convertcharssort{$1}/g;    # Handle user-defined sort character substitutions
    return $phrase;
}

#
# Deaccent string in a suitable manner for things like HTML anchor
sub deaccentdisplay {
    my $phrase = shift;
    return $phrase unless ( $phrase =~ /[$::convertlatinsinglesearch$::convertcharssinglesearch]/ );

    # first convert the characters specified by the language
    $phrase =~ s/([$::convertcharsdisplaysearch])/$::convertcharsdisplay{$1}/g;

    # then convert anything that hasn't been converted already
    eval
      "\$phrase =~ tr/$::convertlatinsinglesearch$::convertcharssinglesearch/$::convertlatinsinglereplace$::convertcharssinglereplace/";
    return $phrase;
}

#
# Read language-specific labels files
# They also contain language specific strings to control sort ordering
# Defaults are set in this routine, then removed if the user has overridden them using labels file
sub readlabels {
    my $labelfile        = path_labels();
    my $defaultlabelfile = path_defaultlabels();
    @::gcviewlang = ();

    # read the default values first, in case some are missing from the user file
    ::dofile($defaultlabelfile);
    if ( -e $labelfile ) {    # if file exists, use it
        unless ( my $return = ::dofile($labelfile) ) {
            print "A problem was encountered when reading $labelfile. Using default values.\n";
        }
    } else {
        ::copy( $defaultlabelfile, $labelfile );
        print "No label file found, creating file $labelfile with default values.\n";
    }

    # Prepare the strings to be used for deaccenting:
    # - Latin1 versions used for speed if more exotic accents not needed in deaccentsort
    # - Single-char-search and single-char-replace to be used in tr/single-char-search/single-char-replace/ in deaccentsort
    # - Multi-char-search to be used together with convertcharssort in s/// in deaccentsort
    # - Display-multi-char-search to be used with convertcharsdisplay in s/// in deaccentdisplay
    $::convertcharsdisplaysearch = join( '', keys %::convertcharsdisplay );
    $::convertcharsmultisearch   = join( '', keys %::convertcharssort );

    # Latin-1 only
    $::convertlatinsinglesearch =
      "ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏ" . "ÐÑÒÓÔÕÖØÙÚÛÜÝÞß" . "àáâãäåæçèéêëìíîï" . "ðñòóôõöøùúûüýþÿ";
    $::convertlatinsinglereplace =
      "AAAAAAACEEEEIIII" . "DNOOOOOOUUUUYTs" . "aaaaaaaceeeeiiii" . "dnoooooouuuuyty";

    # Contains the accented characters from the Latin Unicode blocks (slower to use)
    $::convertcharssinglesearch =

      # Latin Extended A
      "\x{100}\x{101}\x{102}\x{103}\x{104}\x{105}\x{106}\x{107}\x{108}\x{109}\x{10a}\x{10b}\x{10c}\x{10d}\x{10e}\x{10f}"
      . "\x{110}\x{111}\x{112}\x{113}\x{114}\x{115}\x{116}\x{117}\x{118}\x{119}\x{11a}\x{11b}\x{11c}\x{11d}\x{11e}\x{11f}"
      . "\x{120}\x{121}\x{122}\x{123}\x{124}\x{125}\x{126}\x{127}\x{128}\x{129}\x{12a}\x{12b}\x{12c}\x{12d}\x{12e}\x{12f}"
      . "\x{130}\x{131}\x{134}\x{135}\x{136}\x{137}\x{139}\x{13a}\x{13b}\x{13c}\x{13d}\x{13e}\x{13f}"
      . "\x{140}\x{141}\x{142}\x{143}\x{144}\x{145}\x{146}\x{147}\x{148}\x{149}\x{14c}\x{14d}\x{14e}\x{14f}"
      . "\x{150}\x{151}\x{154}\x{155}\x{156}\x{157}\x{158}\x{159}\x{15a}\x{15b}\x{15c}\x{15d}\x{15e}\x{15f}"
      . "\x{160}\x{161}\x{162}\x{163}\x{164}\x{165}\x{166}\x{167}\x{168}\x{169}\x{16a}\x{16b}\x{16c}\x{16d}\x{16e}\x{16f}"
      . "\x{170}\x{171}\x{172}\x{173}\x{174}\x{175}\x{176}\x{177}\x{178}\x{179}\x{17a}\x{17b}\x{17c}\x{17d}\x{17e}"

      # Latin Extended B
      . "\x{180}\x{181}\x{187}\x{188}\x{189}\x{18a}\x{18b}\x{18c}"
      . "\x{191}\x{192}\x{193}\x{197}\x{198}\x{199}\x{19a}\x{19d}\x{19e}\x{19f}"
      . "\x{1a0}\x{1a1}\x{1a4}\x{1a5}\x{1ab}\x{1ac}\x{1ad}\x{1ae}\x{1af}"
      . "\x{1b0}\x{1b2}\x{1b3}\x{1b4}\x{1b5}\x{1b6}"
      . "\x{1cd}\x{1ce}\x{1cf}"
      . "\x{1d0}\x{1d1}\x{1d2}\x{1d3}\x{1d4}\x{1d5}\x{1d6}\x{1d7}\x{1d8}\x{1d9}\x{1da}\x{1db}\x{1dc}\x{1de}\x{1df}"
      . "\x{1e0}\x{1e1}\x{1e2}\x{1e3}\x{1e4}\x{1e5}\x{1e6}\x{1e7}\x{1e8}\x{1e9}\x{1ea}\x{1eb}\x{1ec}\x{1ed}"
      . "\x{1f0}\x{1f4}\x{1f5}\x{1f8}\x{1f9}\x{1fa}\x{1fb}\x{1fc}\x{1fd}\x{1fe}\x{1ff}"
      . "\x{200}\x{201}\x{202}\x{203}\x{204}\x{205}\x{206}\x{207}\x{208}\x{209}\x{20a}\x{20b}\x{20c}\x{20d}\x{20e}\x{20f}"
      . "\x{210}\x{211}\x{212}\x{213}\x{214}\x{215}\x{216}\x{217}\x{218}\x{219}\x{21a}\x{21b}\x{21e}\x{21f}"
      . "\x{224}\x{225}\x{226}\x{227}\x{228}\x{229}\x{22a}\x{22b}\x{22c}\x{22d}\x{22e}\x{22f}"
      . "\x{230}\x{231}\x{232}\x{233}\x{234}\x{235}\x{236}\x{237}\x{23a}\x{23b}\x{23c}\x{23d}\x{23e}\x{23f}"
      . "\x{243}\x{244}\x{246}\x{247}\x{248}\x{249}\x{24a}\x{24b}\x{24c}\x{24d}\x{24e}\x{24f}"

      # Latin Extended Additional
      . "\x{1e00}\x{1e01}\x{1e02}\x{1e03}\x{1e04}\x{1e05}\x{1e06}\x{1e07}\x{1e08}\x{1e09}\x{1e0a}\x{1e0b}\x{1e0c}\x{1e0d}\x{1e0e}\x{1e0f}"
      . "\x{1e10}\x{1e11}\x{1e12}\x{1e13}\x{1e14}\x{1e15}\x{1e16}\x{1e17}\x{1e18}\x{1e19}\x{1e1a}\x{1e1b}\x{1e1c}\x{1e1d}\x{1e1e}\x{1e1f}"
      . "\x{1e20}\x{1e21}\x{1e22}\x{1e23}\x{1e24}\x{1e25}\x{1e26}\x{1e27}\x{1e28}\x{1e29}\x{1e2a}\x{1e2b}\x{1e2c}\x{1e2d}\x{1e2e}\x{1e2f}"
      . "\x{1e30}\x{1e31}\x{1e32}\x{1e33}\x{1e34}\x{1e35}\x{1e36}\x{1e37}\x{1e38}\x{1e39}\x{1e3a}\x{1e3b}\x{1e3c}\x{1e3d}\x{1e3e}\x{1e3f}"
      . "\x{1e40}\x{1e41}\x{1e42}\x{1e43}\x{1e44}\x{1e45}\x{1e46}\x{1e47}\x{1e48}\x{1e49}\x{1e4a}\x{1e4b}\x{1e4c}\x{1e4d}\x{1e4e}\x{1e4f}"
      . "\x{1e50}\x{1e51}\x{1e52}\x{1e53}\x{1e54}\x{1e55}\x{1e56}\x{1e57}\x{1e58}\x{1e59}\x{1e5a}\x{1e5b}\x{1e5c}\x{1e5d}\x{1e5e}\x{1e5f}"
      . "\x{1e60}\x{1e61}\x{1e62}\x{1e63}\x{1e64}\x{1e65}\x{1e66}\x{1e67}\x{1e68}\x{1e69}\x{1e6a}\x{1e6b}\x{1e6c}\x{1e6d}\x{1e6e}\x{1e6f}"
      . "\x{1e70}\x{1e71}\x{1e72}\x{1e73}\x{1e74}\x{1e75}\x{1e76}\x{1e77}\x{1e78}\x{1e79}\x{1e7a}\x{1e7b}\x{1e7c}\x{1e7d}\x{1e7e}\x{1e7f}"
      . "\x{1e80}\x{1e81}\x{1e82}\x{1e83}\x{1e84}\x{1e85}\x{1e86}\x{1e87}\x{1e88}\x{1e89}\x{1e8a}\x{1e8b}\x{1e8c}\x{1e8d}\x{1e8e}\x{1e8f}"
      . "\x{1e90}\x{1e91}\x{1e92}\x{1e93}\x{1e94}\x{1e95}\x{1e96}\x{1e97}\x{1e98}\x{1e99}\x{1e9a}"
      . "\x{1ea0}\x{1ea1}\x{1ea2}\x{1ea3}\x{1ea4}\x{1ea5}\x{1ea6}\x{1ea7}\x{1ea8}\x{1ea9}\x{1eaa}\x{1eab}\x{1eac}\x{1ead}\x{1eae}\x{1eaf}"
      . "\x{1eb0}\x{1eb1}\x{1eb2}\x{1eb3}\x{1eb4}\x{1eb5}\x{1eb6}\x{1eb7}\x{1eb8}\x{1eb9}\x{1eba}\x{1ebb}\x{1ebc}\x{1ebd}\x{1ebe}\x{1ebf}"
      . "\x{1ec0}\x{1ec1}\x{1ec2}\x{1ec3}\x{1ec4}\x{1ec5}\x{1ec6}\x{1ec7}\x{1ec8}\x{1ec9}\x{1eca}\x{1ecb}\x{1ecc}\x{1ecd}\x{1ece}\x{1ecf}"
      . "\x{1ed0}\x{1ed1}\x{1ed2}\x{1ed3}\x{1ed4}\x{1ed5}\x{1ed6}\x{1ed7}\x{1ed8}\x{1ed9}\x{1eda}\x{1edb}\x{1edc}\x{1edd}\x{1ede}\x{1edf}"
      . "\x{1ee0}\x{1ee1}\x{1ee2}\x{1ee3}\x{1ee4}\x{1ee5}\x{1ee6}\x{1ee7}\x{1ee8}\x{1ee9}\x{1eea}\x{1eeb}\x{1eec}\x{1eed}\x{1eee}\x{1eef}"
      . "\x{1ef0}\x{1ef1}\x{1ef2}\x{1ef3}\x{1ef4}\x{1ef5}\x{1ef6}\x{1ef7}\x{1ef8}\x{1ef9}\x{1efe}\x{1eff}";

    # Contains the non-accented forms of the accented characters above
    $::convertcharssinglereplace =

      # Latin Extended A
      "AaAaAaCcCcCcCcDd"
      . "DdEeEeEeEeEeGgGg"
      . "GgGgHhHhIiIiIiIi"
      . "IiJjKkLlLlLlL"
      . "lLlNnNnNnnOoOo"
      . "OoRrRrRrSsSsSs"
      . "SsTtTtTtUuUuUuUu"
      . "UuUuWwYyYZzZzZz"

      # Latin Extended B
      . "bBBbDdDd"
      . "FfGIKklNnO"
      . "OoPptTtTU"
      . "uVYyZz" . "AaI"
      . "iOoUuUuUuUuUuAa"
      . "AaÆæGgGgKkOoOo"
      . "jGgNnAaÆæOo"
      . "AaAaEeEeIiIiOoOo"
      . "RrRrUuUuSsTtHh"
      . "ZzAaEeOoOoOo"
      . "OoYylntjACcLTs"
      . "BUEeJjQqRrYy"

      # Latin Extended Additional
      . "AaBbBbBbCcDdDdDd"
      . "DdDdEeEeEeEeEeFf"
      . "GgHhHhHhHhHhIiIi"
      . "KkKkKkLlLlLlLlMm"
      . "MmMmNnNnNnNnOoOo"
      . "OoOoPpPpRrRrRrRr"
      . "SsSsSsSsSsTtTtTt"
      . "TtUuUuUuUuUuVvVv"
      . "WwWwWwWwWwXxXxYy"
      . "ZzZzZzhtwya"
      . "AaAaAaAaAaAaAaAa"
      . "AaAaAaAaEeEeEeEe"
      . "EeEeEeEeIiIiOoOo"
      . "OoOoOoOoOoOoOoOo"
      . "OoOoUuUuUuUuUuUu"
      . "UuYyYyYyYy";

    # Remove characters from the default sort strings if they exist in the user's language .rc file
    my @chararray = keys %::convertcharssort;
    for ( my $i = 0 ; $i < @chararray ; $i++ ) {
        my $index = index( $::convertlatinsinglesearch, $chararray[$i] );
        if ( $index >= 0 ) {
            substr $::convertlatinsinglesearch,  $index, 1, '';
            substr $::convertlatinsinglereplace, $index, 1, '';
        }
        $index = index( $::convertcharssinglesearch, $chararray[$i] );
        if ( $index >= 0 ) {
            substr $::convertcharssinglesearch,  $index, 1, '';
            substr $::convertcharssinglereplace, $index, 1, '';
        }
    }
}

#
# Display a "working" message, or remove dialog if no message given
sub working {
    my $msg = shift;
    my $top = $::top;
    if ( defined $msg ) {
        if ( defined $::lglobal{workpop} ) {    # dialog already showing, so just change message
            $::lglobal{worklabel}
              ->configure( -text => "\n\n\nWorking....\n$msg\nPlease wait.\n\n\n" );
        } else {                                # create dialog from scratch
            $::lglobal{workpop} = $top->Toplevel;
            $::lglobal{workpop}->transient($top);
            $::lglobal{workpop}->title('Working.....');
            $::lglobal{worklabel} = $::lglobal{workpop}->Label(
                -text       => "\n\n\nWorking....\n$msg\nPlease wait.\n\n\n",
                -font       => '{helvetica} 20 bold',
                -background => $::activecolor,
            )->pack;
            $::lglobal{workpop}->resizable( 'no', 'no' );
            initialize_popup_with_deletebinding('workpop');
        }
        $::lglobal{workpop}->update;
    } else {    # No message given means "no longer working" so kill dialog
        ::killpopup('workpop');
    }
}

#
# Initialize variables at start of program - called only once
sub initialize {

    # Get location of guiguts.pl & make it the current directory
    $::lglobal{guigutsdirectory} = ::dirname( ::rel2abs($0) );
    chdir $::lglobal{guigutsdirectory};

    sethomedir();

    $::top = ::tkinit( -title => $::window_title, );
    my $top = $::top;
    $top->minsize( 440, 90 );

    # Detect geometry changes for tracking
    $top->bind(
        '<Configure>' => sub {
            $::geometry = $top->geometry;
            $::lglobal{geometryupdate} = 1;
        }
    );
    $::icondata = '
    R0lGODdhIAAgAPcAAAAAAAAAQAAAgAAA/wAgAAAgQAAggAAg/wBAAABAQABAgABA/wBgAABgQABg
    gABg/wCAAACAQACAgACA/wCgAACgQACggACg/wDAAADAQADAgADA/wD/AAD/QAD/gAD//yAAACAA
    QCAAgCAA/yAgACAgQCAggCAg/yBAACBAQCBAgCBA/yBgACBgQCBggCBg/yCAACCAQCCAgCCA/yCg
    ACCgQCCggCCg/yDAACDAQCDAgCDA/yD/ACD/QCD/gCD//0AAAEAAQEAAgEAA/0AgAEAgQEAggEAg
    /0BAAEBAQEBAgEBA/0BgAEBgQEBggEBg/0CAAECAQECAgECA/0CgAECgQECggECg/0DAAEDAQEDA
    gEDA/0D/AED/QED/gED//2AAAGAAQGAAgGAA/2AgAGAgQGAggGAg/2BAAGBAQGBAgGBA/2BgAGBg
    QGBggGBg/2CAAGCAQGCAgGCA/2CgAGCgQGCggGCg/2DAAGDAQGDAgGDA/2D/AGD/QGD/gGD//4AA
    AIAAQIAAgIAA/4AgAIAgQIAggIAg/4BAAIBAQIBAgIBA/4BgAIBgQIBggIBg/4CAAICAQICAgICA
    /4CgAICgQICggICg/4DAAIDAQIDAgIDA/4D/AID/QID/gID//6AAAKAAQKAAgKAA/6AgAKAgQKAg
    gKAg/6BAAKBAQKBAgKBA/6BgAKBgQKBggKBg/6CAAKCAQKCAgKCA/6CgAKCgQKCggKCg/6DAAKDA
    QKDAgKDA/6D/AKD/QKD/gKD//8AAAMAAQMAAgMAA/8AgAMAgQMAggMAg/8BAAMBAQMBAgMBA/8Bg
    AMBgQMBggMBg/8CAAMCAQMCAgMCA/8CgAMCgQMCggMCg/8DAAMDAQMDAgMDA/8D/AMD/QMD/gMD/
    //8AAP8AQP8AgP8A//8gAP8gQP8ggP8g//9AAP9AQP9AgP9A//9gAP9gQP9ggP9g//+AAP+AQP+A
    gP+A//+gAP+gQP+ggP+g///AAP/AQP/AgP/A////AP//QP//gP///yH5BAAAAAAALAAAAAAgACAA
    AAj/AP8JHEiwoMGDCBMqXMiwIUNJJCJKnDixDQlJD5PYErito8ePHictMYERYRtb225NWsmypctJ
    b04IaHMwyS2Vb5bo3Mmzp84TMpMUPHkrJ9CjSJMmNSAgAE2OSbZNQrpEqdKqR5sC2Cawzc2YJ56s
    VPnE6ptJl1RW1fqUxDeRJ85q60e3n62kcybNrSvJQAAAJASSkLpE7N66/bIdPYu4bqS/AAQT1ks3
    W5I2tRILOLFkUja6tS5/fgwg8r/BYyuXCGDCgJISmyfZAh1AQOskASBLXvm53+qrk1RvPuq39O5L
    dCOZKPymecw3s/u1We48p+7TUveOtaUtm/danumO19XW3Xsb49jDZ7vVuC77ftqit/+7G3TvynWj
    u2ncuxb99MkpEUkbJbgRXD+1vJeEG5EkUQJ0dOFmGmrJGXCCCXLRVYKCJnTIWGLXUdhPPs2ttNdj
    b1T2Rl7IRRiiSvJ5V1c2sJ1w3339xJIbem0oMckTmTVWS41A4Zhcbn89tU0AT1TVRiy11BLJasMd
    hVmUBNYGGVddmUCcAGBWuVSYFrJVUAlAMWVAh2y26WZrWgVmEGx+IWnnnXgCllAbSJbm55+A+vlU
    QttYFOihgLXBpUOMNuqoQQEBADs=
    ';
    $::icon = $top->Photo(
        -format => 'gif',
        -data   => $::icondata
    );

    # positionhash stores user's window position
    # geometryhash stores user's window position and size
    # Set default value if no value already loaded from setting.rc
    $::geometryhash{aboutpop}         = '+312+136'        unless $::geometryhash{aboutpop};
    $::geometryhash{alignpop}         = '+338+83'         unless $::geometryhash{alignpop};
    $::geometryhash{asciiboxpop}      = '+358+187'        unless $::geometryhash{asciiboxpop};
    $::positionhash{brkpop}           = '+482+131'        unless $::positionhash{brkpop};
    $::geometryhash{charsuitespopup}  = '+50+50'          unless $::geometryhash{charsuitespopup};
    $::positionhash{comcharspop}      = '+10+10'          unless $::positionhash{comcharspop};
    $::positionhash{composekeypop}    = '+200+52'         unless $::positionhash{composekeypop};
    $::geometryhash{composepop}       = '200x70+100+10'   unless $::geometryhash{composepop};
    $::geometryhash{composerefpop}    = '+300+72'         unless $::geometryhash{composerefpop};
    $::positionhash{defurlspop}       = '+150+150'        unless $::positionhash{defurlspop};
    $::geometryhash{elinkpop}         = '330x110+150+120' unless $::geometryhash{elinkpop};
    $::geometryhash{errorcheckpop}    = '+484+72'         unless $::geometryhash{errorcheckpop};
    $::positionhash{extoptpop}        = '+120+38'         unless $::positionhash{extoptpop};
    $::positionhash{filepathspop}     = '+55+7'           unless $::positionhash{filepathspop};
    $::positionhash{fixpop}           = '+34+22'          unless $::positionhash{fixpop};
    $::positionhash{floodpop}         = '+150+150'        unless $::positionhash{floodpop};
    $::positionhash{fontpop}          = '+10+10'          unless $::positionhash{fontpop};
    $::geometryhash{footcheckpop}     = '+22+12'          unless $::geometryhash{footcheckpop};
    $::positionhash{footpop}          = '+255+157'        unless $::positionhash{footpop};
    $::geometryhash{gotolabpop}       = '265x70+400+400'  unless $::geometryhash{gotolabpop};
    $::geometryhash{gotolinepop}      = '265x70+400+400'  unless $::geometryhash{gotolinepop};
    $::geometryhash{gotopagpop}       = '265x70+400+400'  unless $::geometryhash{gotopagpop};
    $::positionhash{gcviewoptspop}    = '+264+72'         unless $::positionhash{gcviewoptspop};
    $::geometryhash{grpop}            = '750x540+100+100' unless $::geometryhash{grpop};
    $::positionhash{guesspgmarkerpop} = '+10+10'          unless $::positionhash{guesspgmarkerpop};
    $::positionhash{hilitepop}        = '+150+150'        unless $::positionhash{hilitepop};
    $::positionhash{hintpop}          = '+150+150'        unless $::positionhash{hintpop};
    $::geometryhash{hpopup}           = '300x400+584+211' unless $::geometryhash{hpopup};
    $::positionhash{htmlgenpop}       = '+145+37'         unless $::positionhash{htmlgenpop};
    $::geometryhash{htmlimpop}        = '+45+37'          unless $::geometryhash{htmlimpop};
    $::positionhash{intervalpop}      = '+300+137'        unless $::positionhash{intervalpop};
    $::geometryhash{linkpop}          = '+224+72'         unless $::geometryhash{linkpop};
    $::positionhash{marginspop}       = '+145+137'        unless $::positionhash{marginspop};
    $::positionhash{markpop}          = '+140+93'         unless $::positionhash{markpop};
    $::positionhash{markuppop}        = '+150+100'        unless $::positionhash{markuppop};
    $::geometryhash{messagespop}      = '400x300+106+72'  unless $::geometryhash{messagespop};
    $::positionhash{multihelppop}     = '+110+50'         unless $::positionhash{multihelppop};
    $::geometryhash{multispellpop}    = '430x410+100+100' unless $::geometryhash{multispellpop};
    $::geometryhash{oppop}            = '600x400+50+50'   unless $::geometryhash{oppop};
    $::geometryhash{pagelabelpop}     = '375x500+20+20'   unless $::geometryhash{pagelabelpop};
    $::positionhash{pagemarkerpop}    = '+302+97'         unless $::positionhash{pagemarkerpop};
    $::geometryhash{pagesephelppop}   = '+191+132'        unless $::geometryhash{pagesephelppop};
    $::positionhash{pageseppop}       = '+334+176'        unless $::positionhash{pageseppop};
    $::positionhash{quicksearchpop}   = '+334+176'        unless $::positionhash{quicksearchpop};
    $::geometryhash{searchpop}        = '+10+10'          unless $::geometryhash{searchpop};
    $::positionhash{selectionpop}     = '+10+10'          unless $::positionhash{selectionpop};
    $::positionhash{spellpopup}       = '+152+97'         unless $::positionhash{spellpopup};
    $::positionhash{srchhistsizepop}  = '+152+97'         unless $::positionhash{srchhistsizepop};
    $::positionhash{stoppop}          = '+10+10'          unless $::positionhash{stoppop};
    $::positionhash{surpop}           = '+150+150'        unless $::positionhash{surpop};
    $::positionhash{tblfxpop}         = '+120+120'        unless $::positionhash{tblfxpop};
    $::positionhash{txtconvpop}       = '+82+131'         unless $::positionhash{txtconvpop};
    $::positionhash{utfentrypop}      = '+191+132'        unless $::positionhash{utfentrypop};
    $::geometryhash{utfpop}           = '420x315+46+46'   unless $::geometryhash{utfpop};
    $::geometryhash{utfsearchpop}     = '550x450+53+87'   unless $::geometryhash{utfsearchpop};
    $::positionhash{versionbox}       = '+80+80'          unless $::positionhash{versionbox};
    $::geometryhash{wfpop}            = '+365+63'         unless $::geometryhash{wfpop};
    $::positionhash{workpop}          = '+30+30'          unless $::positionhash{workpop};

    # manualhash stores subpage of manual for each dialog
    # Where dialog is used in several contexts, use 'dialogname+context' as key
    $::manualhash{'aboutpop'}                = '#Overview';
    $::manualhash{'alignpop'}                = '/Text_Menu#Align_text_on_string';
    $::manualhash{'asciiboxpop'}             = '/Text_Menu#Draw_ASCII_Boxes';
    $::manualhash{'brkpop'}                  = '/Tools_Menu#Check_Orphaned_Brackets';
    $::manualhash{'charsuitespopup'}         = '/File_Menu#Content_Providing';
    $::manualhash{'comcharspop'}             = '/Unicode_Menu#The_Commonly-Used_Characters_Dialog';
    $::manualhash{'comcharsconfigpop'}       = '/Unicode_Menu#The_Commonly-Used_Characters_Dialog';
    $::manualhash{'composekeypop'}           = '/Preferences_Menu#setcomposekey';
    $::manualhash{'composepop'}              = '/Tools_Menu#Compose_Sequence';
    $::manualhash{'composerefpop'}           = '/Help_Menu#composekey';
    $::manualhash{'defurlspop'}              = '/Preferences_Menu#File_Paths';
    $::manualhash{'elinkpop'}                = '/HTML_Menu#The_HTML_Markup_Dialog';
    $::manualhash{'errorcheckpop+Bookloupe'} = '/Tools_Menu#Bookloupe';
    $::manualhash{'errorcheckpop+Jeebies'}   = '/Tools_Menu#Jeebies';
    $::manualhash{'errorcheckpop+Load Checkfile'}   = '/Tools_Menu#Load_Checkfile';
    $::manualhash{'errorcheckpop+pptxt'}            = '/Text_Menu#PPtxt';
    $::manualhash{'errorcheckpop+Nu HTML Check'}    = '/HTML_Menu#HTML_Validator_.28local.29';
    $::manualhash{'errorcheckpop+Nu XHTML Check'}   = '/HTML_Menu#HTML_Validator_.28local.29';
    $::manualhash{'errorcheckpop+W3C Validate CSS'} = '/HTML_Menu#CSS_Validator';
    $::manualhash{'errorcheckpop+Link Check'} =
      '/HTML_Menu#Check_for_link_errors_.28HTML_Link_Checker.29';
    $::manualhash{'errorcheckpop+HTML Tidy'} = '/HTML_Menu#HTML_Tidy';
    $::manualhash{'errorcheckpop+pphtml'}    = '/HTML_Menu#PPhtml';
    $::manualhash{'errorcheckpop+ppvimage'} =
      '/HTML_Menu#Check_for_image-related_errors_.28PPVimage.29';
    $::manualhash{'errorcheckpop+Spell Query'} = '/Tools_Menu#Spell_Query';
    $::manualhash{'errorcheckpop+EPUBCheck'} =
      '/HTML_Menu#Check_.EPUB_Files_for_Possible_Errors_.28EPUBCheck.29';
    $::manualhash{'errorcheckpop+Unmatched HTML Tags'}     = '/HTML_Menu#Unmatched_Tags';
    $::manualhash{'errorcheckpop+Unmatched DP Tags'}       = '/Tools_Menu#Unmatched_Tags';
    $::manualhash{'errorcheckpop+Unmatched Brackets'}      = '/Tools_Menu#Unmatched_Brackets';
    $::manualhash{'errorcheckpop+Unmatched Block Markup'}  = '/Tools_Menu#Unmatched_Block_Markup';
    $::manualhash{'errorcheckpop+Unmatched Double Quotes'} = '/Text_Menu#Unmatched_Double_Quotes';
    $::manualhash{'extoptpop'}                             = '/Custom_Menu';
    $::manualhash{'filepathspop'}                          = '/Preferences_Menu#File_Paths';
    $::manualhash{'fixpop'}                                = '/Tools_Menu#Basic_Fixup';
    $::manualhash{'floodpop'}                              = '/Edit_Menu#Flood_Fill';
    $::manualhash{'fontpop'}                               = '/Preferences_Menu#Appearance';
    $::manualhash{'footcheckpop'}                          = '/Tools_Menu#Footnote_Fixup';
    $::manualhash{'footpop'}                               = '/Tools_Menu#Footnote_Fixup';
    $::manualhash{'gcviewoptspop'}                         = '/Tools_Menu#Bookloupe';
    $::manualhash{'gotolabpop'} =
      '/Navigation#Go_to_the_text_on_a_specific_page_number_of_the_original_Book';
    $::manualhash{'gotolinepop'} = '/Navigation#Go_to_a_specific_Line';
    $::manualhash{'gotopagpop'} =
      '/Navigation#Go_to_the_text_corresponding_to_a_specific_page_Image';
    $::manualhash{'grpop'}             = '/Tools_Menu#Find_and_Convert_Greek';
    $::manualhash{'guesspgmarkerpop'}  = '/File_Menu#Guess_Page_Markers';
    $::manualhash{'hotkeys'}           = '/Help_Menu#Keyboard_Shortcuts';
    $::manualhash{'hilitepop'}         = '/Navigation#Highlighting_Characters';
    $::manualhash{'hintpop'}           = '/Tools_Menu#Scanno_Hints';
    $::manualhash{'hpopup'}            = '/Tools_Menu#Harmonic_Searches';
    $::manualhash{'htmlgenpop'}        = '/HTML_Menu#Convert_the_text_to_HTML_.28HTML_Generator.29';
    $::manualhash{'htmlimpop'}         = '/HTML_Menu#Add_Illustrations';
    $::manualhash{'intervalpop'}       = '/Preferences_Menu#Backup';
    $::manualhash{'linkpop'}           = '/HTML_Menu#The_HTML_Markup_Dialog';
    $::manualhash{'marginspop'}        = '/Preferences_Menu#Processing';
    $::manualhash{'markpop'}           = '/HTML_Menu#The_HTML_Markup_Dialog';
    $::manualhash{'markupconfigpop'}   = '/HTML_Menu#The_HTML_Markup_Dialog';
    $::manualhash{'markuppop'}         = '/Tools_Menu#Word_Frequency';
    $::manualhash{'messagespop'}       = '/Help_Menu#Error_Messages';
    $::manualhash{'multihelppop'}      = '/Tools_Menu#Spell_Check_in_Multiple_Languages';
    $::manualhash{'multispellpop'}     = '/Tools_Menu#Spell_Check_in_Multiple_Languages';
    $::manualhash{'oppop'}             = '/File_Menu#View_Operations_History';
    $::manualhash{'pagelabelpop'}      = '/File_Menu#Configure_Page_Labels';
    $::manualhash{'pagemarkerpop'}     = '/File_Menu#Display.2FAdjust_Page_Markers';
    $::manualhash{'pagesephelppop'}    = '/Tools_Menu#Fixup_Page_Separators';
    $::manualhash{'pageseppop'}        = '/Tools_Menu#Fixup_Page_Separators';
    $::manualhash{'quicksearchpop'}    = '/Searching#Quick_Search';
    $::manualhash{'regexref'}          = '/Help_Menu#Regular_Expression_Quick_Reference';
    $::manualhash{'searchpop+scannos'} = '/Tools_Menu#Stealth_Scannos';
    $::manualhash{'searchpop+search'}  = '/Searching#The_Search_Dialog';
    $::manualhash{'selectionpop'}      = '/Edit_Menu#Selection_Dialog';
    $::manualhash{'spellpopup'}        = '/Tools_Menu#Spell_Check';
    $::manualhash{'srchhistsizepop'}   = '/Preferences_Menu#Processing';
    $::manualhash{'stoppop'}           = '#Overview';
    $::manualhash{'surpop'}            = '/Edit_Menu#Surround_Selection';
    $::manualhash{'tblfxpop'}          = '/Text_Menu#ASCII_Table_Effects';
    $::manualhash{'txtconvpop'}        = '/Text_Menu#The_Txt_Conversion_Dialog';
    $::manualhash{'utfentrypop'}       = '/Unicode_Menu#Unicode_Lookup_by_Ordinal';
    $::manualhash{'utfpop'}            = '/Unicode_Menu#The_Unicode_Menu';
    $::manualhash{'utfsearchpop'}      = '/Unicode_Menu#Unicode_Search_by_Name';
    $::manualhash{'versionbox'}        = '/Help_Menu#Guiguts_HELP_Menu:_Online_and_Built-in_Help';
    $::manualhash{'wfpop'}             = '/Tools_Menu#Word_Frequency';
    $::manualhash{'workpop'}           = '#Overview';

    ::composeinitialize();

    ::readsettings();

    # Necessary to create a dummy Entry widget for two reasons:
    # Firstly, Entry class key bindings do not get set up until the first instance is created,
    # so without this, any bindings would be overwritten when the first real Entry gets created
    # Secondly, to find out what the default system font characteristics are for Entry widgets
    my $de   = $top->Entry();
    my $font = $de->fontCreate( $de->cget( -font ) );
    $::lglobal{txtfontsystemfamily} = $de->fontActual( $font, -family );
    $::lglobal{txtfontsystemsize}   = $de->fontActual( $font, -size );
    $::lglobal{txtfontsystemweight} = $de->fontActual( $font, -weight );
    $de->fontDelete($font);
    $de->destroy();

    # Similarly for the font used for labels, menus, etc.
    my $dl = $top->Label();
    $font                           = $de->fontCreate( $dl->cget( -font ) );
    $::lglobal{gblfontsystemfamily} = $dl->fontActual( $font, -family );
    $::lglobal{gblfontsystemsize}   = $dl->fontActual( $font, -size );
    $::lglobal{gblfontsystemweight} = $dl->fontActual( $font, -weight );
    $dl->fontDelete($font);
    $dl->destroy();

    # Create named fonts
    $::fontweight = 'normal' unless $::fontweight;    # cope with old settings file
    $top->fontCreate(
        'proofing',
        -family => $::fontname,
        -size   => $::fontsize,
        -weight => $::fontweight,
    );
    $::utffontweight = 'normal' unless $::utffontweight;    # cope with old settings file
    $top->fontCreate(
        'unicode',
        -family => $::utffontname,
        -size   => $::utffontsize,
        -weight => $::utffontweight,
    );
    $top->fontCreate(
        'textentry',
        -family => $::txtfontname,
        -size   => $::txtfontsize,
        -weight => $::txtfontweight,
    );
    ::textentryfontconfigure();    # may need to set to system default
    $top->fontCreate(
        'global',
        -family => $::gblfontname,
        -size   => $::gblfontsize,
        -weight => $::gblfontweight,
    );
    ::globalfontconfigure();       # may need to set to system default

    setwidgetdefaultoptions();

    # Set up Main window size
    unless ($::geometry) {

        # $top->screenheight() and $top->screenwidth() do unexpected things on
        # Macs with dual screens, so we simply set a reasonable starting size
        $::geometry = "800x600+0+0";
    }
    $top->geometry($::geometry) if $::geometry;
    $::text_frame = $top->Frame->pack(
        -anchor => 'nw',
        -expand => 'yes',
        -fill   => 'both'
    );

    # Set up Main window layout
    $::counter_frame = $::text_frame->Frame->pack(
        -side   => 'bottom',
        -anchor => 'sw',
        -pady   => 2,
        -expand => 0
    );

    # The actual text widget
    $::textwindow = $::text_frame->LineNumberText(
        -exportselection => 'true',           # 'sel' tag is associated with selections
        -background      => $::bkgcolor,
        -font            => 'proofing',
        -wrap            => 'none',
        -curlinebg       => $::activecolor,
    )->pack(
        -side   => 'bottom',
        -anchor => 'nw',
        -expand => 'yes',
        -fill   => 'both'
    );
    $top->protocol( 'WM_DELETE_WINDOW' => \&::_exit );
    $top->configure( -menu => $::menubar = $top->Menu );

    # routines to call every time the text is edited
    $::textwindow->SetGUICallbacks( [] );

    # Ignore any watchdog timer alarms. Subroutines that take a long time to
    # complete can trip it
    $SIG{ALRM} = 'IGNORE';
    $SIG{INT}  = sub { ::_exit() };

    # Initialize a whole bunch of global values that used to be discrete variables
    # spread willy-nilly through the code. Refactored them into a global
    # hash and gathered them together in a single subroutine.
    $::lglobal{alignstring}      = '.';
    $::lglobal{asciijustify}     = 'center';
    $::lglobal{asciiwidth}       = 64;
    $::lglobal{autofraction}     = 0;          # HTML convert - 1/2, 1/4, 3/4 to named entities
    $::lglobal{codewarn}         = 1;
    $::lglobal{cssblockmarkup}   = 1;          # HTML convert - Use <div>/CSS rather than <blockquote>
    $::lglobal{delay}            = 50;
    $::lglobal{footstyle}        = 'end';
    $::lglobal{ftnoteindexstart} = '1.0';
    $::lglobal{groutp}           = 'u';

    # The 4 default replacements below must match one of the radiobutton values in htmlgenpop
    $::lglobal{html_b}             = '<b>';                       # HTML convert - default replacement for <b>
    $::lglobal{html_f}             = '<span class="antiqua">';    # HTML convert - default replacement for <f>
    $::lglobal{html_g}             = '<em class="gesperrt">';     # HTML convert - default replacement for <g>
    $::lglobal{html_i}             = '<i>';                       # HTML convert - default replacement for <i>
    $::lglobal{htmlimgalignment}   = 'center';                    # HTML image alignment
    $::lglobal{htmlimagesizex}     = 0;                           # HTML pixel width of file loaded in image dialog
    $::lglobal{htmlimagesizey}     = 0;                           # HTML pixel height of file loaded in image dialog
    $::lglobal{isedited}           = 0;
    $::lglobal{wf_ignore_case}     = 0;
    $::lglobal{lastmatchindex}     = '1.0';
    $::lglobal{lastsearchterm}     = '';
    $::lglobal{longordlabel}       = 0;
    $::lglobal{ordmaxlength}       = 1;
    $::lglobal{pageanch}           = 1;                           # HTML convert - add page anchors
    $::lglobal{pagecmt}            = 0;                           # HTML convert - page markers as comments
    $::lglobal{pageskipco}         = 1;                           # HTML convert - skip coincident page markers
    $::lglobal{poetrynumbers}      = 0;                           # HTML convert - find & format poetry line numbers
    $::lglobal{regaa}              = 1;                           # Auto-advance stealth scannos
    $::lglobal{seepagenums}        = 0;
    $::lglobal{selectionsearch}    = 0;
    $::lglobal{selmaxlength}       = 1;
    $::lglobal{shorthtmlfootnotes} = 1;                           # HTML convert - Footnote_3 rather than Footnote_3_3
    $::lglobal{showblocksize}      = 1;
    $::lglobal{spellencoding}      = "iso8859-1";
    $::lglobal{stepmaxwidth}       = 70;
    $::lglobal{suspects_only}      = 0;
    $::lglobal{tblcoljustify}      = 'l';
    $::lglobal{tblrwcol}           = 1;
    $::lglobal{uoutp}              = 'h';
    $::lglobal{utfrangesort}       = 0;
    $::lglobal{visibleline}        = '';
    $::lglobal{wflastsearchterm}   = '';
    $::lglobal{zoneindex}          = 0;
    @{ $::lglobal{ascii} }  = qw/+ - + | | | + - +/;
    @{ $::lglobal{fixopt} } = ( 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1 );

    # Bookloupe error types
    @{ $::lglobal{gcarray} } = (
        'Asterisk',
        'Begins with punctuation',
        'Broken em-dash',
        'Capital "S"',
        'Caret character',
        'CR without LF',
        'Double punctuation',
        'Endquote missing punctuation',
        'Extra period',
        'Forward slash',
        'HTML symbol',
        'HTML Tag',
        'Hyphen at end of line',
        'Long line',
        'Mismatched curly brackets',
        'Mismatched quotes',
        'Mismatched round brackets',
        'Mismatched singlequotes',
        'Mismatched square brackets',
        'Mismatched underscores',
        'Missing space',
        'No CR',
        'No punctuation at para end',
        'Non-ASCII character',
        'Non-ISO-8859 character',
        'Paragraph starts with lower-case',
        'Query angled bracket with From',
        'Query digit in',
        "Query had\/bad error",
        "Query he\/be error",
        "Query hut\/but error",
        'Query I=exclamation mark',
        'Query missing paragraph break',
        'Query possible scanno',
        'Query punctuation after',
        'Query single character line',
        'Query standalone 0',
        'Query standalone 1',
        'Query word',
        'Short line',
        'Spaced dash',
        'Spaced doublequote',
        'Spaced em-dash',
        'Spaced punctuation',
        'Spaced quote',
        'Spaced singlequote',
        'Tab character',
        'Tilde character',
        'Two successive CRs',
        'Unspaced bracket',
        'Unspaced quotes',
        'Wrongspaced quotes',
        'Wrongspaced singlequotes',
    );
    $::gsopt[$_] = $::mygcview[$_] for 0 .. $#::mygcview;    # Use default gc/bl view settings

    # Find tool locations. setdefaultpath handles differences in *nix/Windows
    # executable names and looks on the search path.
    $::scannospath =~ s/[\/\\]$//;    # Remove trailing slash from scannos path
    $::scannospath =
      ::setdefaultpath( $::scannospath, ::catfile( $::lglobal{guigutsdirectory}, 'scannos' ) );
    $::ebookmakercommand = ::setdefaultpath( $::ebookmakercommand,
        ::catfile( $::lglobal{guigutsdirectory}, 'tools', 'ebookmaker', 'ebookmaker.exe' ) );
    $::validatecommand = ::setdefaultpath( $::validatecommand,
        ::catfile( $::lglobal{guigutsdirectory}, 'tools', 'W3C', 'vnu.jar' ) );
    $::validatecsscommand = ::setdefaultpath( $::validatecsscommand,
        ::catfile( $::lglobal{guigutsdirectory}, 'tools', 'W3C', 'css-validator.jar' ) );
    $::epubcheckcommand = ::setdefaultpath( $::epubcheckcommand,
        ::catfile( $::lglobal{guigutsdirectory}, 'tools', 'W3C', 'epubcheck', 'epubcheck.jar' ) );
    $::gutcommand = ::setdefaultpath( $::gutcommand,
        ::catfile( $::lglobal{guigutsdirectory}, 'tools', 'bookloupe', 'bookloupe.exe' ) );
    $::jeebiescommand = ::setdefaultpath( $::jeebiescommand,
        ::catfile( $::lglobal{guigutsdirectory}, 'tools', 'jeebies', 'jeebies.exe' ) );
    $::tidycommand = ::setdefaultpath( $::tidycommand,
        ::catfile( $::lglobal{guigutsdirectory}, 'tools', 'tidy', 'tidy.exe' ) );

    # If XnView or Aspell are installed under "Program Files (x86)",
    # set that as the default, otherwise use "Program Files"
    # Suitable for Windows installation locations
    my $trypath = ::catfile( '\Program Files (x86)', 'XnView', 'xnview.exe' );
    if ( -e $trypath ) {
        $::globalviewerpath = ::setdefaultpath( $::globalviewerpath, $trypath );
    } else {
        $::globalviewerpath = ::setdefaultpath( $::globalviewerpath,
            ::catfile( '\Program Files', 'XnView', 'xnview.exe' ) );
    }
    $trypath = ::catfile( '\Program Files (x86)', 'Aspell', 'bin', 'aspell.exe' );
    if ( -e $trypath ) {
        $::globalspellpath = ::setdefaultpath( $::globalspellpath, $trypath );
    } else {
        $::globalspellpath = ::setdefaultpath( $::globalspellpath,
            ::catfile( '\Program Files', 'Aspell', 'bin', 'aspell.exe' ) );
    }

    # Override to more likely default locations for Mac
    if ($::OS_MAC) {
        $::globalviewerpath = ::setdefaultpath( $::globalviewerpath,
            ::catfile( '/Applications', 'XnViewMP.app', 'Contents', 'MacOS', 'XnViewMP' ) );

        # M1 and Intel-based Macs have some tools installed in different locations
        $trypath = ::catfile( '/opt', 'homebrew', 'bin', 'aspell' );
        if ( -e $trypath ) {
            $::globalspellpath = ::setdefaultpath( $::globalspellpath, $trypath );
        } else {
            $::globalspellpath =
              ::setdefaultpath( $::globalspellpath, ::catfile( '/usr', 'local', 'bin', 'aspell' ) );
        }
        $trypath = ::catfile( '/opt', 'homebrew', 'bin', 'bookloupe' );
        if ( -e $trypath ) {
            $::gutcommand = ::setdefaultpath( $::gutcommand, $trypath );
        } else {
            $::gutcommand =
              ::setdefaultpath( $::gutcommand, ::catfile( '/usr', 'local', 'bin', 'bookloupe' ) );
        }
        $trypath = ::catfile( '/opt', 'homebrew', 'bin', 'tidy' );
        if ( -e $trypath ) {
            $::tidycommand = ::setdefaultpath( $::tidycommand, $trypath );
        } else {
            $::tidycommand =
              ::setdefaultpath( $::tidycommand, ::catfile( '/usr', 'local', 'bin', 'tidy' ) );
        }
    }

    my $textwindow = $::textwindow;
    $textwindow->tagConfigure( 'footnote', -background => 'cyan' );
    $textwindow->tagConfigure( 'scannos',  -background => $::highlightcolor );
    $textwindow->tagConfigure( 'bkmk',     -background => 'green' );
    $textwindow->tagConfigure( 'table',    -background => '#E7B696' );
    $textwindow->tagRaise('sel');
    $textwindow->tagConfigure( 'quotemark', -background => $::highlightcolor );
    $textwindow->tagConfigure( 'highlight', -background => 'orange' );
    $textwindow->tagConfigure( 'linesel',   -background => '#8EFD94' );
    $textwindow->tagConfigure( 'alignment', -background => '#8EFD94' );
    $textwindow->tagConfigure(
        'CURSOR_HIGHLIGHT_DOUBLECURLY',
        -foreground => 'black',
        -background => 'green'
    );    # From TextEdit.pm
    $textwindow->tagConfigure(
        'CURSOR_HIGHLIGHT_SINGLECURLY',
        -foreground => 'black',
        -background => 'grey'
    );    # From TextEdit.pm

    $textwindow->tagConfigure(
        'pagenum',
        -background  => 'yellow',
        -relief      => 'raised',
        -borderwidth => 2
    );
    $textwindow->tagBind( 'pagenum', '<ButtonRelease-1>', \&::pnumadjust );
    ::displaylinenumbers($::vislnnm);
    ::displaycolnumbers($::viscolnm);

    %{ $::lglobal{utfblocks} } = (
        'Alphabetic Presentation Forms' => [ 'FB00', 'FB4F' ],
        'Arabic Presentation Forms-A'   => [ 'FB50', 'FDCF' ],    #Really FDFF but there are illegal characters in fdc0-fdff
        'Arabic Presentation Forms-B'   => [ 'FE70', 'FEFF' ],
        'Arabic'                        => [ '0600', '06FF' ],
        'Armenian'                      => [ '0530', '058F' ],
        'Arrows'                        => [ '2190', '21FF' ],
        'Bengali'                       => [ '0980', '09FF' ],
        'Block Elements'                => [ '2580', '259F' ],

        #'Bopomofo Extended' => ['31A0', '31BF'],
        #'Bopomofo' => ['3100', '312F'],
        'Box Drawing'      => [ '2500', '257F' ],
        'Braille Patterns' => [ '2800', '28FF' ],
        'Buhid'            => [ '1740', '175F' ],
        'Cherokee'         => [ '13A0', '13FF' ],

        #'CJK Compatibility Forms' => ['FE30', 'FE4F'],
        #'CJK Compatibility Ideographs' => ['F900', 'FAFF'],
        #'CJK Compatibility' => ['3300', '33FF'],
        #'CJK Radicals Supplement' => ['2E80', '2EFF'],
        #'CJK Symbols and Punctuation' => ['3000', '303F'],
        #'CJK Unified Ideographs Extension A' => ['3400', '4DBF'],
        #'CJK Unified Ideographs' => ['4E00', '9FFF'],
        'Combining Diacritical Marks for Symbols' => [ '20D0', '20FF' ],
        'Combining Diacritical Marks'             => [ '0300', '036F' ],
        'Combining Half Marks'                    => [ 'FE20', 'FE2F' ],
        'Control Pictures'                        => [ '2400', '243F' ],
        'Currency Symbols'                        => [ '20A0', '20CF' ],
        'Cyrillic Supplementary'                  => [ '0500', '052F' ],
        'Cyrillic'                                => [ '0400', '04FF' ],
        'Devanagari'                              => [ '0900', '097F' ],
        'Dingbats'                                => [ '2700', '27BF' ],
        'Enclosed Alphanumerics'                  => [ '2460', '24FF' ],

        #'Enclosed CJK Letters and Months' => ['3200', '32FF'],
        'Ethiopic'                      => [ '1200', '137F' ],
        'General Punctuation'           => [ '2000', '206F' ],
        'Geometric Shapes'              => [ '25A0', '25FF' ],
        'Georgian'                      => [ '10A0', '10FF' ],
        'Greek and Coptic'              => [ '0370', '03FF' ],
        'Greek Extended'                => [ '1F00', '1FFF' ],
        'Gujarati'                      => [ '0A80', '0AFF' ],
        'Gurmukhi'                      => [ '0A00', '0A7F' ],
        'Halfwidth and Fullwidth Forms' => [ 'FF00', 'FFEF' ],

        #'Hangul Compatibility Jamo' => ['3130', '318F'],
        #'Hangul Jamo' => ['1100', '11FF'],
        #'Hangul Syllables' => ['AC00', 'D7AF'],
        #'Hanunoo' => ['1720', '173F'],
        'Hebrew' => [ '0590', '05FF' ],

        #'High Private Use Surrogates' => ['DB80', 'DBFF'],
        #'High Surrogates' => ['D800', 'DB7F'],
        #'Hiragana' => ['3040', '309F'],
        #'Ideographic Description Characters' => ['2FF0', '2FFF'],
        #'Kanbun' => ['3190', '319F'],
        #'Kangxi Radicals' => ['2F00', '2FDF'],
        'Kannada' => [ '0C80', '0CFF' ],

        #'Katakana Phonetic Extensions' => ['31F0', '31FF'],
        #'Katakana' => ['30A0', '30FF'],
        #'Khmer Symbols' => ['19E0', '19FF'],
        #'Khmer' => ['1780', '17FF'],
        'Lao'                       => [ '0E80', '0EFF' ],
        'Latin Extended Additional' => [ '1E00', '1EFF' ],
        'Latin Extended-A'          => [ '0100', '017F' ],
        'Latin Extended-B'          => [ '0180', '024F' ],
        'Latin IPA Extensions'      => [ '0250', '02AF' ],
        'Latin-1 Supplement'        => [ '00A0', '00FF' ],
        'Letterlike Symbols'        => [ '2100', '214F' ],

        #'Limbu' => ['1900', '194F'],
        #'Low Surrogates' => ['DC00', 'DFFF'],
        'Malayalam'                            => [ '0D00', '0D7F' ],
        'Mathematical Operators'               => [ '2200', '22FF' ],
        'Miscellaneous Mathematical Symbols-A' => [ '27C0', '27EF' ],
        'Miscellaneous Mathematical Symbols-B' => [ '2980', '29FF' ],
        'Miscellaneous Symbols and Arrows'     => [ '2B00', '2BFF' ],
        'Miscellaneous Symbols'                => [ '2600', '26FF' ],
        'Miscellaneous Technical'              => [ '2300', '23FF' ],
        'Mongolian'                            => [ '1800', '18AF' ],
        'Myanmar'                              => [ '1000', '109F' ],
        'Number Forms'                         => [ '2150', '218F' ],
        'Ogham'                                => [ '1680', '169F' ],
        'Optical Character Recognition'        => [ '2440', '245F' ],
        'Oriya'                                => [ '0B00', '0B7F' ],
        'Phonetic Extensions'                  => [ '1D00', '1D7F' ],
        'Runic'                                => [ '16A0', '16FF' ],
        'Sinhala'                              => [ '0D80', '0DFF' ],
        'Small Form Variants'                  => [ 'FE50', 'FE6F' ],
        'Spacing Modifier Letters'             => [ '02B0', '02FF' ],
        'Superscripts and Subscripts'          => [ '2070', '209F' ],
        'Supplemental Arrows-A'                => [ '27F0', '27FF' ],
        'Supplemental Arrows-B'                => [ '2900', '297F' ],
        'Supplemental Mathematical Operators'  => [ '2A00', '2AFF' ],
        'Syriac'                               => [ '0700', '074F' ],
        'Tagalog'                              => [ '1700', '171F' ],

        #'Tagbanwa' => ['1760', '177F'],
        #'Tai Le' => ['1950', '197F'],
        'Tamil'  => [ '0B80', '0BFF' ],
        'Telugu' => [ '0C00', '0C7F' ],
        'Thaana' => [ '0780', '07BF' ],
        'Thai'   => [ '0E00', '0E7F' ],

        #'Tibetan' => ['0F00', '0FFF'],
        'Unified Canadian Aboriginal Syllabics' => [ '1400', '167F' ],

        'Variation Selectors' => [ 'FE00', 'FE0F' ],

        #'Yi Radicals' => ['A490', 'A4CF'],
        #'Yi Syllables' => ['A000', 'A48F'],
        #'Yijing Hexagram Symbols' => ['4DC0', '4DFF'],
    );

    %{ $::lglobal{grkbeta1} } = (    #Singly marked letters
        "\x{1F00}" => 'a)',
        "\x{1F01}" => 'a(',
        "\x{1F08}" => 'A)',
        "\x{1F09}" => 'A(',
        "\x{1F10}" => 'e)',
        "\x{1F11}" => 'e(',
        "\x{1F18}" => 'E)',
        "\x{1F19}" => 'E(',
        "\x{1F20}" => 'ê)',
        "\x{1F21}" => 'ê(',
        "\x{1F28}" => 'Ê)',
        "\x{1F29}" => 'Ê(',
        "\x{1F30}" => 'i)',
        "\x{1F31}" => 'i(',
        "\x{1F38}" => 'I)',
        "\x{1F39}" => 'I(',
        "\x{1F40}" => 'o)',
        "\x{1F41}" => 'o(',
        "\x{1F48}" => 'O)',
        "\x{1F49}" => 'O(',
        "\x{1F50}" => 'y)',
        "\x{1F51}" => 'y(',
        "\x{1F59}" => 'Y(',
        "\x{1F60}" => 'ô)',
        "\x{1F61}" => 'ô(',
        "\x{1F68}" => 'Ô)',
        "\x{1F69}" => 'Ô(',
        "\x{1F70}" => 'a\\\\',
        "\x{1F71}" => 'a/',
        "\x{1F72}" => 'e\\\\',
        "\x{1F73}" => 'e/',
        "\x{1F74}" => 'ê\\\\',
        "\x{1F75}" => 'ê/',
        "\x{1F76}" => 'i\\\\',
        "\x{1F77}" => 'i/',
        "\x{1F78}" => 'o\\\\',
        "\x{1F79}" => 'o/',
        "\x{1F7A}" => 'y\\\\',
        "\x{1F7B}" => 'y/',
        "\x{1F7C}" => 'ô\\\\',
        "\x{1F7D}" => 'ô/',
        "\x{1FB0}" => 'a=',
        "\x{1FB1}" => 'a_',
        "\x{1FB3}" => 'a|',
        "\x{1FB6}" => 'a~',
        "\x{1FB8}" => 'A=',
        "\x{1FB9}" => 'A_',
        "\x{1FBA}" => 'A\\\\',
        "\x{1FBB}" => 'A/',
        "\x{1FBC}" => 'A|',
        "\x{1FC3}" => 'ê|',
        "\x{1FC6}" => 'ê~',
        "\x{1FC8}" => 'E\\\\',
        "\x{1FC9}" => 'E/',
        "\x{1FCA}" => 'Ê\\\\',
        "\x{1FCB}" => 'Ê/',
        "\x{1FCC}" => 'Ê|',
        "\x{1FD0}" => 'i=',
        "\x{1FD1}" => 'i_',
        "\x{1FD6}" => 'i~',
        "\x{1FD8}" => 'I=',
        "\x{1FD9}" => 'I_',
        "\x{1FDA}" => 'I\\\\',
        "\x{1FDB}" => 'I/',
        "\x{1FE0}" => 'y=',
        "\x{1FE1}" => 'y_',
        "\x{1FE4}" => 'r)',
        "\x{1FE5}" => 'r(',
        "\x{1FE6}" => 'y~',
        "\x{1FE8}" => 'Y=',
        "\x{1FE9}" => 'Y_',
        "\x{1FEA}" => 'Y\\\\',
        "\x{1FEB}" => 'Y/',
        "\x{1FEC}" => 'R(',
        "\x{1FF6}" => 'ô~',
        "\x{1FF3}" => 'ô|',
        "\x{1FF8}" => 'O\\\\',
        "\x{1FF9}" => 'O/',
        "\x{1FFA}" => 'Ô\\\\',
        "\x{1FFB}" => 'Ô/',
        "\x{1FFC}" => 'Ô|',
        "\x{03AA}" => 'I+',
        "\x{03AB}" => 'Y+',
        "\x{03CA}" => 'i+',
        "\x{03CB}" => 'y+',
    );
    %{ $::lglobal{grkbeta2} } = (    #Doubly marked letters
        "\x{1F02}" => 'a)\\\\',
        "\x{1F03}" => 'a(\\\\',
        "\x{1F04}" => 'a)/',
        "\x{1F05}" => 'a(/',
        "\x{1F06}" => 'a~)',
        "\x{1F07}" => 'a~(',
        "\x{1F0A}" => 'A)\\\\',
        "\x{1F0B}" => 'A(\\\\',
        "\x{1F0C}" => 'A)/',
        "\x{1F0D}" => 'A(/',
        "\x{1F0E}" => 'A~)',
        "\x{1F0F}" => 'A~(',
        "\x{1F12}" => 'e)\\\\',
        "\x{1F13}" => 'e(\\\\',
        "\x{1F14}" => 'e)/',
        "\x{1F15}" => 'e(/',
        "\x{1F1A}" => 'E)\\\\',
        "\x{1F1B}" => 'E(\\\\',
        "\x{1F1C}" => 'E)/',
        "\x{1F1D}" => 'E(/',
        "\x{1F22}" => 'ê)\\\\',
        "\x{1F23}" => 'ê(\\\\',
        "\x{1F24}" => 'ê)/',
        "\x{1F25}" => 'ê(/',
        "\x{1F26}" => 'ê~)',
        "\x{1F27}" => 'ê~(',
        "\x{1F2A}" => 'Ê)\\\\',
        "\x{1F2B}" => 'Ê(\\\\',
        "\x{1F2C}" => 'Ê)/',
        "\x{1F2D}" => 'Ê(/',
        "\x{1F2E}" => 'Ê~)',
        "\x{1F2F}" => 'Ê~(',
        "\x{1F32}" => 'i)\\\\',
        "\x{1F33}" => 'i(\\\\',
        "\x{1F34}" => 'i)/',
        "\x{1F35}" => 'i(/',
        "\x{1F36}" => 'i~)',
        "\x{1F37}" => 'i~(',
        "\x{1F3A}" => 'I)\\\\',
        "\x{1F3B}" => 'I(\\\\',
        "\x{1F3C}" => 'I)/',
        "\x{1F3D}" => 'I(/',
        "\x{1F3E}" => 'I~)',
        "\x{1F3F}" => 'I~(',
        "\x{1F42}" => 'o)\\\\',
        "\x{1F43}" => 'o(\\\\',
        "\x{1F44}" => 'o)/',
        "\x{1F45}" => 'o(/',
        "\x{1F4A}" => 'O)\\\\',
        "\x{1F4B}" => 'O(\\\\',
        "\x{1F4C}" => 'O)/',
        "\x{1F4D}" => 'O(/',
        "\x{1F52}" => 'y)\\\\',
        "\x{1F53}" => 'y(\\\\',
        "\x{1F54}" => 'y)/',
        "\x{1F55}" => 'y(/',
        "\x{1F56}" => 'y~)',
        "\x{1F57}" => 'y~(',
        "\x{1F5B}" => 'Y(\\\\',
        "\x{1F5D}" => 'Y(/',
        "\x{1F5F}" => 'Y~(',
        "\x{1F62}" => 'ô)\\\\',
        "\x{1F63}" => 'ô(\\\\',
        "\x{1F64}" => 'ô)/',
        "\x{1F65}" => 'ô(/',
        "\x{1F66}" => 'ô~)',
        "\x{1F67}" => 'ô~(',
        "\x{1F6A}" => 'Ô)\\\\',
        "\x{1F6B}" => 'Ô(\\\\',
        "\x{1F6C}" => 'Ô)/',
        "\x{1F6D}" => 'Ô(/',
        "\x{1F6E}" => 'Ô~)',
        "\x{1F6F}" => 'Ô~(',
        "\x{1F80}" => 'a)|',
        "\x{1F81}" => 'a(|',
        "\x{1F88}" => 'A)|',
        "\x{1F89}" => 'A(|',
        "\x{1F90}" => 'ê)|',
        "\x{1F91}" => 'ê(|',
        "\x{1F98}" => 'Ê)|',
        "\x{1F99}" => 'Ê(|',
        "\x{1FA0}" => 'ô)|',
        "\x{1FA1}" => 'ô(|',
        "\x{1FA8}" => 'Ô)|',
        "\x{1FA9}" => 'Ô(|',
        "\x{1FB2}" => 'a\\\|',
        "\x{1FB4}" => 'a/|',
        "\x{1FB7}" => 'a~|',
        "\x{1FC2}" => 'ê\\\|',
        "\x{1FC4}" => 'ê/|',
        "\x{1FC7}" => 'ê~|',
        "\x{1FD2}" => 'i\\\\+',
        "\x{1FD3}" => 'i/+',
        "\x{1FD7}" => 'i~+',
        "\x{1FE2}" => 'y\\\\+',
        "\x{1FE3}" => 'y/+',
        "\x{1FE7}" => 'y~+',
        "\x{1FF2}" => 'ô\\\|',
        "\x{1FF4}" => 'ô/|',
        "\x{1FF7}" => 'ô~|',
    );
    %{ $::lglobal{grkbeta3} } = (    #Triply marked letters
        "\x{1F82}" => 'a)\\\|',
        "\x{1F83}" => 'a(\\\|',
        "\x{1F84}" => 'a)/|',
        "\x{1F85}" => 'a(/|',
        "\x{1F86}" => 'a~)|',
        "\x{1F87}" => 'a~(|',
        "\x{1F8A}" => 'A)\\\|',
        "\x{1F8B}" => 'A(\\\|',
        "\x{1F8C}" => 'A)/|',
        "\x{1F8D}" => 'A(/|',
        "\x{1F8E}" => 'A~)|',
        "\x{1F8F}" => 'A~(|',
        "\x{1F92}" => 'ê)\\\|',
        "\x{1F93}" => 'ê(\\\|',
        "\x{1F94}" => 'ê)/|',
        "\x{1F95}" => 'ê(/|',
        "\x{1F96}" => 'ê~)|',
        "\x{1F97}" => 'ê~(|',
        "\x{1F9A}" => 'Ê)\\\|',
        "\x{1F9B}" => 'Ê(\\\|',
        "\x{1F9C}" => 'Ê)/|',
        "\x{1F9D}" => 'Ê(/|',
        "\x{1F9E}" => 'Ê~)|',
        "\x{1F9F}" => 'Ê~(|',
        "\x{1FA2}" => 'ô)\\\|',
        "\x{1FA3}" => 'ô(\\\|',
        "\x{1FA4}" => 'ô)/|',
        "\x{1FA5}" => 'ô(/|',
        "\x{1FA6}" => 'ô~)|',
        "\x{1FA7}" => 'ô~(|',
        "\x{1FAA}" => 'Ô)\\\|',
        "\x{1FAB}" => 'Ô(\\\|',
        "\x{1FAC}" => 'Ô)/|',
        "\x{1FAD}" => 'Ô(/|',
        "\x{1FAE}" => 'Ô~)|',
        "\x{1FAF}" => 'Ô~(|',
    );

    # DP character suites (easier to copy and edit with regexes from the tables on
    # https://www.pgdp.net/c/tools/charsuites.php than from the DP code)
    # Note that combining characters are used in some of the character suites. They are
    # not included here since tools such as Character Count do not treat the characters
    # in a combined way, so allowing "s + combinining diaresis below" would inadvertently
    # allow "combinining diaresis below" and thus "x + combinining diaresis below"
    # where x is any other permitted letter.
    # Combining characters appear as standalone characters in Character Count, as they always
    # have, and will be flagged as not being in any character suite, thus warning the
    # user to check how they are used in the file.
    %{ $::lglobal{dpcharsuite} } = (
        "Basic Greek" =>
          "\x{0391}\x{0392}\x{0393}\x{0394}\x{0395}\x{0396}\x{0397}\x{0398}\x{0399}\x{039a}"
          . "\x{039b}\x{039c}\x{039d}\x{039e}\x{039f}\x{03a0}\x{03a1}\x{03a3}\x{03a4}\x{03a5}"
          . "\x{03a6}\x{03a7}\x{03a8}\x{03a9}\x{03b1}\x{03b2}\x{03b3}\x{03b4}\x{03b5}\x{03b6}"
          . "\x{03b7}\x{03b8}\x{03b9}\x{03ba}\x{03bb}\x{03bc}\x{03bd}\x{03be}\x{03bf}\x{03c0}"
          . "\x{03c1}\x{03c2}\x{03c3}\x{03c4}\x{03c5}\x{03c6}\x{03c7}\x{03c8}\x{03c9}",

        "Basic Latin" =>
          "\x{0020}\x{0021}\x{0022}\x{0023}\x{0024}\x{0025}\x{0026}\x{0027}\x{0028}\x{0029}"
          . "\x{002a}\x{002b}\x{002c}\x{002d}\x{002e}\x{002f}\x{0030}\x{0031}\x{0032}\x{0033}"
          . "\x{0034}\x{0035}\x{0036}\x{0037}\x{0038}\x{0039}\x{003a}\x{003b}\x{003c}\x{003d}"
          . "\x{003e}\x{003f}\x{0040}\x{0041}\x{0042}\x{0043}\x{0044}\x{0045}\x{0046}\x{0047}"
          . "\x{0048}\x{0049}\x{004a}\x{004b}\x{004c}\x{004d}\x{004e}\x{004f}\x{0050}\x{0051}"
          . "\x{0052}\x{0053}\x{0054}\x{0055}\x{0056}\x{0057}\x{0058}\x{0059}\x{005a}\x{005b}"
          . "\x{005c}\x{005d}\x{005e}\x{005f}\x{0060}\x{0061}\x{0062}\x{0063}\x{0064}\x{0065}"
          . "\x{0066}\x{0067}\x{0068}\x{0069}\x{006a}\x{006b}\x{006c}\x{006d}\x{006e}\x{006f}"
          . "\x{0070}\x{0071}\x{0072}\x{0073}\x{0074}\x{0075}\x{0076}\x{0077}\x{0078}\x{0079}"
          . "\x{007a}\x{007b}\x{007c}\x{007d}\x{007e}\x{00a1}\x{00a2}\x{00a3}\x{00a4}\x{00a5}"
          . "\x{00a6}\x{00a7}\x{00a8}\x{00a9}\x{00aa}\x{00ab}\x{00ac}\x{00ae}\x{00af}\x{00b0}"
          . "\x{00b1}\x{00b2}\x{00b3}\x{00b4}\x{00b5}\x{00b6}\x{00b7}\x{00b8}\x{00b9}\x{00ba}"
          . "\x{00bb}\x{00bc}\x{00bd}\x{00be}\x{00bf}\x{00c0}\x{00c1}\x{00c2}\x{00c3}\x{00c4}"
          . "\x{00c5}\x{00c6}\x{00c7}\x{00c8}\x{00c9}\x{00ca}\x{00cb}\x{00cc}\x{00cd}\x{00ce}"
          . "\x{00cf}\x{00d0}\x{00d1}\x{00d2}\x{00d3}\x{00d4}\x{00d5}\x{00d6}\x{00d7}\x{00d8}"
          . "\x{00d9}\x{00da}\x{00db}\x{00dc}\x{00dd}\x{00de}\x{00df}\x{00e0}\x{00e1}\x{00e2}"
          . "\x{00e3}\x{00e4}\x{00e5}\x{00e6}\x{00e7}\x{00e8}\x{00e9}\x{00ea}\x{00eb}\x{00ec}"
          . "\x{00ed}\x{00ee}\x{00ef}\x{00f0}\x{00f1}\x{00f2}\x{00f3}\x{00f4}\x{00f5}\x{00f6}"
          . "\x{00f7}\x{00f8}\x{00f9}\x{00fa}\x{00fb}\x{00fc}\x{00fd}\x{00fe}\x{00ff}\x{0152}"
          . "\x{0153}\x{0160}\x{0161}\x{017d}\x{017e}\x{0178}\x{0192}\x{2039}\x{203a}",

        "Extended European Latin A" =>
          "\x{0102}\x{0103}\x{0108}\x{0109}\x{011c}\x{011d}\x{014a}\x{014b}\x{015c}\x{015d}"
          . "\x{016c}\x{016d}\x{0124}\x{0125}\x{0134}\x{0135}\x{0150}\x{0151}\x{0166}\x{0167}"
          . "\x{0170}\x{0171}\x{0174}\x{0175}\x{0176}\x{0177}\x{0218}\x{0219}\x{021a}\x{021b}",

        "Extended European Latin B" =>
          "\x{0100}\x{0101}\x{010c}\x{010d}\x{010e}\x{010f}\x{0112}\x{0113}\x{011a}\x{011b}"
          . "\x{0122}\x{0123}\x{012a}\x{012b}\x{0136}\x{0137}\x{0139}\x{013a}\x{013b}\x{013c}"
          . "\x{013d}\x{013e}\x{0145}\x{0146}\x{0147}\x{0148}\x{014c}\x{014d}\x{0154}\x{0155}"
          . "\x{0156}\x{0157}\x{0158}\x{0159}\x{0160}\x{0161}\x{0164}\x{0165}\x{016a}\x{016b}"
          . "\x{016e}\x{016f}\x{017d}\x{017e}",

        "Extended European Latin C" =>
          "\x{0104}\x{0105}\x{0106}\x{0107}\x{010a}\x{010b}\x{010c}\x{010d}\x{0110}\x{0111}"
          . "\x{0116}\x{0117}\x{0118}\x{0119}\x{0120}\x{0121}\x{0126}\x{0127}\x{012e}\x{012f}"
          . "\x{0141}\x{0142}\x{0143}\x{0144}\x{015a}\x{015b}\x{0160}\x{0161}\x{016a}\x{016b}"
          . "\x{0172}\x{0173}\x{0179}\x{017a}\x{017b}\x{017c}\x{017d}\x{017e}",

        "Medievalist supplement" =>
          "\x{0100}\x{0101}\x{0102}\x{0103}\x{0111}\x{0112}\x{0113}\x{0114}\x{0115}\x{0118}"
          . "\x{0119}\x{0127}\x{012a}\x{012b}\x{012c}\x{012d}\x{014c}\x{014d}\x{014e}\x{014f}"
          . "\x{016a}\x{016b}\x{016c}\x{016d}\x{017f}\x{0180}\x{01bf}\x{01e2}\x{01e3}\x{01ea}"
          . "\x{01eb}\x{01f7}\x{01fc}\x{01fd}\x{021c}\x{021d}\x{0232}\x{0233}\x{204a}\x{a734}"
          . "\x{a735}\x{a751}\x{a753}\x{a755}\x{a75d}\x{a765}\x{a76b}\x{a76d}\x{a770}",

        "Polytonic Greek" =>
          "\x{02b9}\x{0375}\x{0391}\x{0392}\x{0393}\x{0394}\x{0395}\x{0396}\x{0397}\x{0398}"
          . "\x{0399}\x{039a}\x{039b}\x{039c}\x{039d}\x{039e}\x{039f}\x{03a0}\x{03a1}\x{03a3}"
          . "\x{03a4}\x{03a5}\x{03a6}\x{03a7}\x{03a8}\x{03a9}\x{03aa}\x{03ab}\x{03b1}\x{03b2}"
          . "\x{03b3}\x{03b4}\x{03b5}\x{03b6}\x{03b7}\x{03b8}\x{03b9}\x{03ba}\x{03bb}\x{03bc}"
          . "\x{03bd}\x{03be}\x{03bf}\x{03c0}\x{03c1}\x{03c2}\x{03c3}\x{03c4}\x{03c5}\x{03c6}"
          . "\x{03c7}\x{03c8}\x{03c9}\x{03ca}\x{03cb}\x{03db}\x{03dc}\x{03dd}\x{03f2}\x{03f9}"
          . "\x{0386}\x{0388}\x{0389}\x{038a}\x{038c}\x{038e}\x{038f}\x{0390}\x{03ac}\x{03ad}"
          . "\x{03ae}\x{03af}\x{03b0}\x{03cc}\x{03cd}\x{03ce}\x{1f00}\x{1f01}\x{1f02}\x{1f03}"
          . "\x{1f04}\x{1f05}\x{1f06}\x{1f07}\x{1f08}\x{1f09}\x{1f0a}\x{1f0b}\x{1f0c}\x{1f0d}"
          . "\x{1f0e}\x{1f0f}\x{1f10}\x{1f11}\x{1f12}\x{1f13}\x{1f14}\x{1f15}\x{1f18}\x{1f19}"
          . "\x{1f1a}\x{1f1b}\x{1f1c}\x{1f1d}\x{1f20}\x{1f21}\x{1f22}\x{1f23}\x{1f24}\x{1f25}"
          . "\x{1f26}\x{1f27}\x{1f28}\x{1f29}\x{1f2a}\x{1f2b}\x{1f2c}\x{1f2d}\x{1f2e}\x{1f2f}"
          . "\x{1f30}\x{1f31}\x{1f32}\x{1f33}\x{1f34}\x{1f35}\x{1f36}\x{1f37}\x{1f38}\x{1f39}"
          . "\x{1f3a}\x{1f3b}\x{1f3c}\x{1f3d}\x{1f3e}\x{1f3f}\x{1f40}\x{1f41}\x{1f42}\x{1f43}"
          . "\x{1f44}\x{1f45}\x{1f48}\x{1f49}\x{1f4a}\x{1f4b}\x{1f4c}\x{1f4d}\x{1f50}\x{1f51}"
          . "\x{1f52}\x{1f53}\x{1f54}\x{1f55}\x{1f56}\x{1f57}\x{1f59}\x{1f5b}\x{1f5d}\x{1f5f}"
          . "\x{1f60}\x{1f61}\x{1f62}\x{1f63}\x{1f64}\x{1f65}\x{1f66}\x{1f67}\x{1f68}\x{1f69}"
          . "\x{1f6a}\x{1f6b}\x{1f6c}\x{1f6d}\x{1f6e}\x{1f6f}\x{1f70}\x{1f72}\x{1f74}\x{1f76}"
          . "\x{1f78}\x{1f7a}\x{1f7c}\x{1f80}\x{1f81}\x{1f82}\x{1f83}\x{1f84}\x{1f85}\x{1f86}"
          . "\x{1f87}\x{1f88}\x{1f89}\x{1f8a}\x{1f8b}\x{1f8c}\x{1f8d}\x{1f8e}\x{1f8f}\x{1f90}"
          . "\x{1f91}\x{1f92}\x{1f93}\x{1f94}\x{1f95}\x{1f96}\x{1f97}\x{1f98}\x{1f99}\x{1f9a}"
          . "\x{1f9b}\x{1f9c}\x{1f9d}\x{1f9e}\x{1f9f}\x{1fa0}\x{1fa1}\x{1fa2}\x{1fa3}\x{1fa4}"
          . "\x{1fa5}\x{1fa6}\x{1fa7}\x{1fa8}\x{1fa9}\x{1faa}\x{1fab}\x{1fac}\x{1fad}\x{1fae}"
          . "\x{1faf}\x{1fb0}\x{1fb1}\x{1fb2}\x{1fb3}\x{1fb4}\x{1fb6}\x{1fb7}\x{1fb8}\x{1fb9}"
          . "\x{1fba}\x{1fbc}\x{1fc2}\x{1fc3}\x{1fc4}\x{1fc6}\x{1fc7}\x{1fc8}\x{1fca}\x{1fcc}"
          . "\x{1fd0}\x{1fd1}\x{1fd2}\x{1fd6}\x{1fd7}\x{1fd8}\x{1fd9}\x{1fda}\x{1fe0}\x{1fe1}"
          . "\x{1fe2}\x{1fe4}\x{1fe5}\x{1fe6}\x{1fe7}\x{1fe8}\x{1fe9}\x{1fea}\x{1fec}\x{1ff2}"
          . "\x{1ff3}\x{1ff4}\x{1ff6}\x{1ff7}\x{1ff8}\x{1ffa}\x{1ffc}",

        "Semitic and Indic transcriptions" =>
          "\x{0100}\x{0101}\x{0112}\x{0113}\x{012a}\x{012b}\x{014c}\x{014d}\x{015a}\x{015b}"
          . "\x{0160}\x{0161}\x{016a}\x{016b}\x{02be}\x{02bf}\x{1e0c}\x{1e0d}\x{1e24}\x{1e25}"
          . "\x{1e2a}\x{1e2b}\x{1e32}\x{1e33}\x{1e37}\x{1e39}\x{1e40}\x{1e41}\x{1e42}\x{1e43}"
          . "\x{1e44}\x{1e45}\x{1e46}\x{1e47}\x{1e5a}\x{1e5b}\x{1e5c}\x{1e5d}\x{1e62}\x{1e63}"
          . "\x{1e6c}\x{1e6d}\x{1e92}\x{1e93}\x{1e94}\x{1e95}\x{1e96}",

        # Characters s, t & z with combining diaresis below are in the Semitic/Indic charsuite
        # They are not included for the reason explained in the comment above
        #\x{0053}\x{0324}\x{0054}\x{0324}\x{005a}\x{0324}\x{0073}\x{0324}\x{0074}\x{0324}\x{007a}\x{0324}

        "Symbols collection" =>
          "\x{0292}\x{2108}\x{2114}\x{211e}\x{2125}\x{2609}\x{260a}\x{260b}\x{260c}\x{260d}"
          . "\x{263d}\x{263e}\x{263f}\x{2640}\x{2641}\x{2642}\x{2643}\x{2644}\x{2645}\x{2646}"

          # In the symbols charsuite, these 12 astrological signs are followed by \x{fe0e},
          # a variation selector, to force them to be displayed in text rather than image form
          # The variation selectors are omitted for the reason explained in the comment above
          . "\x{2648}\x{2649}\x{264a}\x{264b}\x{264c}\x{264d}\x{264e}\x{264f}\x{2650}\x{2651}\x{2652}\x{2653}"

          . "\x{2669}\x{266a}\x{266d}\x{266e}\x{266f}",
    );

    my $scroll_gif =
      'R0lGODlhCAAQAIAAAAAAAP///yH5BAEAAAEALAAAAAAIABAAAAIUjAGmiMutopz0pPgwk7B6/3SZphQAOw==';
    $::lglobal{scrollgif} = $top->Photo(
        -data   => $scroll_gif,
        -format => 'gif',
    );
}

#
# Use option database to set widget defaults
sub setwidgetdefaultoptions {
    my $top = $::top;

    # 'widgetDefault' priority means user can override, e.g. using .Xdefaults file
    my $priority = 'widgetDefault';

    # Set font for all widgets, then override for Entry fields
    $top->optionAdd( '*font'       => 'global',    $priority );
    $top->optionAdd( '*Entry*font' => 'textentry', $priority );

    # Various colors
    $top->optionAdd( '*Button*activeBackground' => $::activecolor, $priority );

    $top->optionAdd( '*Entry*background'   => $::bkgcolor, $priority );
    $top->optionAdd( '*Spinbox*background' => $::bkgcolor, $priority );
    $top->optionAdd( '*ROText*background'  => $::bkgcolor, $priority );

    my $selectcolor = $::OS_WIN ? 'white' : $::activecolor;
    $top->optionAdd( '*Checkbutton*selectColor' => $selectcolor, $priority );
    $top->optionAdd( '*Radiobutton*selectColor' => $selectcolor, $priority );
}

#
# Cancel button 2 window scrolling
sub scrolldismiss {
    my $textwindow = $::textwindow;
    return unless $::lglobal{scroller};
    $textwindow->configure( -cursor => $::lglobal{oldcursor} );
    ::killpopup('scroller');
    $::lglobal{scroll_id}->cancel if $::lglobal{scroll_id};
    $::lglobal{scroll_id} = '';
}

#
# Display correct cursor and adjust view in main window during button 2 scrolling
sub b2scroll {
    my $top        = $::top;
    my $textwindow = $::textwindow;
    my $scrolly    = $top->pointery - $top->rooty - $::lglobal{scroll_y} - 8;
    my $scrollx    = $top->pointerx - $top->rootx - $::lglobal{scroll_x} - 8;
    my $signy      = ( abs $scrolly > 5 ) ? ( $scrolly < 0 ? -1 : 1 ) : 0;
    my $signx      = ( abs $scrollx > 5 ) ? ( $scrollx < 0 ? -1 : 1 ) : 0;
    $textwindow->configure( -cursor => $::lglobal{scroll_cursors}{"$signy$signx"} );
    $scrolly = ( $scrolly**2 - 25 ) / 800;
    $scrollx = ( $scrollx**2 - 25 ) / 2000;
    $::lglobal{scrolltriggery} += $scrolly;

    if ( $::lglobal{scrolltriggery} > 1 ) {
        $textwindow->yview( 'scroll', ( $signy * $::lglobal{scrolltriggery} ), 'units' );
        $::lglobal{scrolltriggery} = 0;
    }
    $::lglobal{scrolltriggerx} += $scrollx;
    if ( $::lglobal{scrolltriggerx} > 1 ) {
        $textwindow->xview( 'scroll', ( $signx * $::lglobal{scrolltriggerx} ), 'units' );
        $::lglobal{scrolltriggerx} = 0;
    }
}

#
# Create a dialog with common behavior defined and default behavior when window is dismissed
sub initialize_popup_with_deletebinding {
    my $popupname = shift;
    my $context   = shift;    # Additional context for multi-use dialogs
    initialize_popup_without_deletebinding( $popupname, $context );
    $::lglobal{$popupname}->protocol(
        'WM_DELETE_WINDOW' => sub {
            ::killpopup($popupname);
        }
    );
}

#
# Destroy a dialog and undefine the global variable so program knows it's been destroyed
sub killpopup {
    my $popupname = shift;
    return unless $::lglobal{$popupname};
    $::lglobal{$popupname}->destroy;
    undef $::lglobal{$popupname};
}

#
# Create a dialog with common behavior defined but without handling when dialog is dismissed
sub initialize_popup_without_deletebinding {
    my $top       = $::top;
    my $popupname = shift;
    my $context   = shift;    # Additional context for multi-use dialogs
    if ( $::geometryhash{$popupname} ) {
        $::lglobal{$popupname}->geometry( $::geometryhash{$popupname} );
        $::lglobal{$popupname}->bind(
            '<Configure>' => sub {
                $::geometryhash{$popupname} = $::lglobal{$popupname}->geometry;
                $::lglobal{geometryupdate} = 1;
            }
        );
    } elsif ( $::positionhash{$popupname} ) {
        $::lglobal{$popupname}->geometry( $::positionhash{$popupname} );
        $::lglobal{$popupname}->bind(
            '<Configure>' => sub {
                my $pos = $::lglobal{$popupname}->geometry;

                # Extract position coordinates - note negative coords are of form +-nnn
                $pos =~ s/^[0-9x]*(\+-*\d+\+-*\d+)$/$1/;
                $::positionhash{$popupname} = $pos;    # don't try using ->x and ->y, ->y has a wrong value (at least on mac)
                $::lglobal{geometryupdate} = 1;
            }
        );
    }
    $::lglobal{$popupname}->Icon( -image => $::icon );

    # sfpop and searchpop dialogs have their own "stay on top" flag
    my $ontop = $::stayontop;
    $ontop = $::wfstayontop if $popupname eq "wfpop";
    $ontop = $::srstayontop if $popupname eq "searchpop";
    $::lglobal{$popupname}->transient($top) if $ontop;

    $::lglobal{$popupname}->Tk::bind( '<F1>' => sub { display_manual( $popupname, $context ); } );

}

#
# Display the manual page corresponding to the given dialog name and optional context string
sub display_manual {
    my $helplookup = shift;
    my $context    = shift;
    $helplookup .= '+' . $context if $context;
    my $manualpage = $::manualhash{$helplookup};
    if ($manualpage) {
        ::launchurl( 'https://www.pgdp.net/wiki/PPTools/Guiguts/Guiguts_Manual' . $manualpage );
    } else {
        my $top = $::top;
        $top->messageBox(
            -icon    => 'error',
            -message => 'No manual page stored for ' . $helplookup,
            -title   => 'No Manual Page',
            -type    => 'Ok',
        );

    }
}

#
# Convert given text to title case
sub titlecase {
    my $text = shift;
    $text = lc($text);
    $text =~ s/(^\W*\w)/\U$1\E/;
    $text =~ s/([\s\n]+\W*\w)/\U$1\E/g;
    $text =~ s/ (A|An|And|At|By|From|In|Of|On|The|To)\b/ \L$1\E/g if ( ::main_lang() eq 'en' );
    return $text;
}

#
# Convert forward slash to backslash for Windows paths
sub os_normal {
    my $tmp = $_[0];
    $tmp =~ s|/|\\|g if $::OS_WIN && $tmp;
    return $tmp;
}

#
# Handle backslashes and single quotes so string is suitable for writing
# to setting.rc or similar format file
# Note - assumes string variables will be written out enclosed in single quotes
sub escape_problems {
    my $var = shift;
    if ($var) {
        $var =~ s/\\+$/\\\\/g;
        $var =~ s/(?!<\\)'/\\'/g;
    }
    return $var;
}

#
# Set up resizing of widget with scrollbars by creating a
# "corner" widget that can be clicked and dragged
sub drag {
    my $scrolledwidget = shift;
    my $corner         = $scrolledwidget->Subwidget('corner');
    my $corner_label =
      $corner->Label( -image => $::lglobal{drag_img} )->pack( -side => 'bottom', -anchor => 'se' );
    $corner_label->bind(
        '<Enter>',
        sub {
            if ($::OS_WIN) {
                $corner->configure( -cursor => 'size_nw_se' );
            } else {
                $corner->configure( -cursor => 'sizing' );
            }
        }
    );
    $corner_label->bind( '<Leave>', sub { $corner->configure( -cursor => 'arrow' ) } );
    $corner_label->bind(
        '<1>',
        sub {
            ( $::lglobal{x}, $::lglobal{y} ) =
              ( $scrolledwidget->toplevel->pointerx, $scrolledwidget->toplevel->pointery );
        }
    );
    $corner_label->bind(
        '<B1-Motion>',
        sub {
            my $x =
              $scrolledwidget->toplevel->width -
              $::lglobal{x} +
              $scrolledwidget->toplevel->pointerx;
            my $y =
              $scrolledwidget->toplevel->height -
              $::lglobal{y} +
              $scrolledwidget->toplevel->pointery;
            ( $::lglobal{x}, $::lglobal{y} ) =
              ( $scrolledwidget->toplevel->pointerx, $scrolledwidget->toplevel->pointery );
            $scrolledwidget->toplevel->geometry( $x . 'x' . $y );
        }
    );
}

#
# Sorts an array of strings, handling case and accents intelligently
# Sorting is case-insensitive and ignores accents, except for "identical" words
# which are sorted according to normal sort order, e.g. Ab, ab, ABc, Abc, AxY, Axy, etc.
sub natural_sort_alpha {
    sort { lc( ::deaccentsort($a) ) cmp lc( ::deaccentsort($b) ) or $a cmp $b; } @_;
}

#
# Sorts an array of strings by length then string, handling case and accents intelligently
# Sorting is first by length (reversed), then string sorting is case-insensitive and ignores accents,
# except for "identical" words which are sorted according to normal sort order.
# Also note trailing asterisks (used to flag suspects) are stripped from length calculation.
# e.g. ABc, Abc, AxY, Axy, Ab ****, ab ****, Y, y, Z, z, etc.
sub natural_sort_length {
    sort {
             length( noast($b) ) <=> length( noast($a) )
          or lc( ::deaccentsort($a) ) cmp lc( ::deaccentsort($b) )
          or $a cmp $b;
    } @_;
}

#
# Given a ref to a hash containing a number (e.g. word frequency), sorts the keys,
# first by number (reversed), then string sorting is case-insensitive and ignores accents,
# except for "identical" words which are sorted according to normal sort order,
# e.g. 19 ABc, 19 Abc, 19 AxY, 19 Axy, 18 Ab, 18 ab,  etc.
sub natural_sort_freq {
    sort {
             $_[0]->{$b} <=> $_[0]->{$a}
          or lc( ::deaccentsort($a) ) cmp lc( ::deaccentsort($b) )
          or $a cmp $b;
    } keys %{ $_[0] };
}

#
# Remove the 4 asterisk WF "suspects" suffix
sub noast {
    local $/ = ' ****';
    my $phrase = shift;
    chomp $phrase;
    return $phrase;
}

#
# Cut text operation
sub cut {
    my $textwindow  = $::textwindow;
    my @ranges      = $textwindow->tagRanges('sel');
    my $range_total = @ranges;
    return unless $range_total;
    if ( $range_total == 2 ) {
        $textwindow->clipboardCut;
    } else {
        $textwindow->addGlobStart;    # NOTE: Add to undo ring.
        $textwindow->clipboardColumnCut;
        $textwindow->addGlobEnd;      # NOTE: Add to undo ring.
    }
}

#
# Copy text operation
sub textcopy {
    my $textwindow  = $::textwindow;
    my @ranges      = $textwindow->tagRanges('sel');
    my $range_total = @ranges;
    return unless $range_total;
    $textwindow->clipboardClear;
    if ( $range_total == 2 ) {
        $textwindow->clipboardCopy;
    } else {
        $textwindow->clipboardColumnCopy;
    }
}

#
# Special paste routine that will respond differently
# for overstrike/insert modes
sub paste {
    my $textwindow        = $::textwindow;
    my $alternative_paste = shift;
    if ( $textwindow->OverstrikeMode ) {
        my @ranges = $textwindow->tagRanges('sel');
        if (@ranges) {
            my $end   = pop @ranges;
            my $start = pop @ranges;
            $textwindow->delete( $start, $end );
        }

        # Basic eval exception handling to avoid error if nothing in clipboard
        my $text;
        eval { $text = $textwindow->clipboardGet; };
        $text = '' unless $text;

        my $lineend = $textwindow->get( 'insert', 'insert lineend' );
        my $length  = length $text;
        $length = length $lineend if ( length $lineend < length $text );
        $textwindow->delete( 'insert', 'insert +' . ($length) . 'c' );
        $textwindow->insert( 'insert', $text );
    } else {

        # Text::clipboardPaste fails to handle all unicode strings correctly, sometimes
        # pasting them as garbage Latin-1 characters. Text::clipboardPaste calls
        # clipboardGet from Clipboard.pm, but the clipboardGet below calls a different
        # version(?), which crashes with large quantities of text.
        # Default paste will go wrong less frequently and less seriously, but alternative
        # is provided so user can try it if standard paste gives garbage.
        if ($alternative_paste) {
            Tk::catch { $textwindow->Insert( $textwindow->clipboardGet() ) };
        } else {
            $textwindow->clipboardPaste;
        }
    }
}

#
# Special paste routine to insert into Entry widgets
# Try to cope with Perl/Tk failing to handle utf8 correctly on some platforms
# Similarly to paste routine above, alternative paste uses slightly different method
sub entrypaste {
    my $w = shift;
    $w->deleteSelected;

    my $alternative_paste = shift;
    if ($alternative_paste) {
        eval { $w->insert( "insert", $::textwindow->clipboardGet ); };
        $w->SeeInsert if $w->can('SeeInsert');
    } else {
        $w->clipboardPaste;
    }
}

#
# Column cut operation
sub colcut {
    my $textwindow = shift;
    columnizeselection($textwindow);
    $textwindow->addGlobStart;
    ::cut();
    $textwindow->addGlobEnd;
}

#
# Column copy operation
sub colcopy {
    my $textwindow = shift;
    columnizeselection($textwindow);
    $textwindow->addGlobStart;
    ::textcopy();
    $textwindow->addGlobEnd;
}

#
# Column paste operation
sub colpaste {
    my $textwindow = shift;
    $textwindow->addGlobStart;
    $textwindow->clipboardColumnPaste;
    $textwindow->addGlobEnd;
}

#
# Pop dialog showing version numbers of OS and tools
sub showversion {
    my $top = $::top;
    my $os  = $^O;
    $os =~ s/^([^\[]+)\[.+/$1/;
    my $perl   = sprintf( "Perl v%vd", $^V );
    my $aspell = 'Aspell ' . ::get_spellchecker_version();
    my $winver = '';                                         # stops "uninitialised value" message on non windows systems
    if ($::OS_WIN) {
        $winver = qx{ver};
        $winver =~ s{\n}{}smg;
        $winver = "\n$winver";
    }
    my $message = <<"END";
Currently Running:
$::APP_NAME, Version: $::VERSION
Platform: $os$winver
$perl
$aspell
perl/Tk Version: $Tk::VERSION
Tk patchLevel: $Tk::patchLevel
Tk libraries: $Tk::library
END
    my $dialog = $top->DialogBox( -title => 'Versions', -popover => $top );
    my $text   = $dialog->add( 'ROText', -height => 10, -width => 40 )->pack;
    $text->insert( 'end', $message );
    $dialog->Show;
}

#
# Check what is the most recent version of GG online
sub checkonlineversion {

    my $ua = LWP::UserAgent->new(
        env_proxy  => 1,
        keep_alive => 1,
        timeout    => 20,
        ssl_opts   => {
            verify_hostname => 0,
        },
    );
    my $response = $ua->get('https://github.com/DistributedProofreaders/guiguts/releases');

    unless ( $response->content ) {
        return;
    }
    if ( $response->content =~ /(\d+)\.(\d+)\.(\d+)\.zip/i ) {
        return "$1.$2.$3";
    }
}

#
# Check to see if this is the most recent version of GG
sub checkforupdates {
    my $top          = $::top;
    my $monthlycheck = shift;

    # Monthly checks exit silently if user ignoring major (i.e. all) versions
    return if $monthlycheck eq "monthly" and $::ignoreversions eq "major";

    # In case dialog already popped, don't leave up out-of-date info
    ::killpopup('versionbox');

    # Find the latest version available
    ::working('Checking For Updates');
    my $onlineversion = checkonlineversion();
    ::working();
    unless ($onlineversion) {
        $top->messageBox(
            -icon    => 'error',
            -message => 'Could not determine latest version online.',
            -title   => 'Checking for Updates',
            -type    => 'Ok',
        );
        return;
    }
    $::lastversioncheck = time();    # Reset time ready for next monthly check

    # Monthly checks exit silently if user has ignored this version
    # or if the new version isn't a significant enough update
    if ( $monthlycheck eq "monthly" ) {
        return if $onlineversion eq $::ignoreversionnumber;
        my ( $onlinemajorversion, $onlineminorversion, $onlinerevision ) =
          split( /\./, $onlineversion );
        my ( $currentmajorversion, $currentminorversion, $currentrevision ) =
          split( /\./, $::VERSION );
        return
          if $onlinemajorversion == $currentmajorversion
          and $::ignoreversions eq "minor";
        return
              if $onlinemajorversion == $currentmajorversion
          and $onlineminorversion == $currentminorversion
          and $::ignoreversions eq "revisions";
    }

    # Create dialog
    $::lglobal{versionbox} = $top->Toplevel;
    $::lglobal{versionbox}->title('Check for Updates');
    $::lglobal{versionbox}->resizable( 'no', 'no' );
    ::initialize_popup_with_deletebinding('versionbox');

    # Status frame has version information
    my $status_frame =
      $::lglobal{versionbox}->LabFrame( -label => 'Status' )->pack( -side => "top" );
    my $version_frame = $status_frame->Frame()->pack( -side => "top" );
    $version_frame->Label( -text => "Your current version is $::VERSION" )
      ->pack( -side => "top", -anchor => "e" );
    $version_frame->Label( -text => "Latest version online is $onlineversion" )
      ->pack( -side => "top", -anchor => "e" );

    # If current version is up to date, no need for the update buttons, just a message
    if ( $onlineversion eq $::VERSION ) {
        $status_frame->Label( -text => "Your version is up to date!" )
          ->pack( -side => "top", -pady => 5 );
    } else {
        my $button_frame = $::lglobal{versionbox}->Frame()->pack( -side => "top" );

        # Update - take the user to the releases page
        $button_frame->Button(
            -text    => 'Update Now',
            -command => sub {
                ::launchurl("https://github.com/DistributedProofreaders/guiguts/releases");
                ::killpopup('versionbox');
            }
        )->pack( -side => 'left', -pady => 5, -padx => 5 );

        # Ignore - remember this version number and ignore in monthly update checks
        $button_frame->Button(
            -text    => 'Ignore This Version',
            -command => sub {
                $::ignoreversionnumber = $onlineversion;
                ::savesettings();
                ::killpopup('versionbox');
            }
        )->pack( -side => 'left', -pady => 5, -padx => 5 );

        # Remind - do nothing now - next monthly update check will happen as usual
        $button_frame->Button(
            -text    => 'Remind Me Later',
            -command => sub {
                ::killpopup('versionbox');
            }
        )->pack( -side => 'left', -pady => 5, -padx => 5 );
    }

    # Options for monthly update checks
    my $radio_frame =
      $::lglobal{versionbox}->LabFrame( -label => 'Monthly Update Checks' )
      ->pack( -side => "top", -padx => 5 );
    $radio_frame->Radiobutton(
        -text     => "Do Not Check Monthly",
        -value    => "major",
        -variable => \$::ignoreversions
    )->pack( -side => "top", -anchor => "w" );
    $radio_frame->Radiobutton(
        -text     => "Ignore Minor Versions, e.g. 1.2.0 --> 1.3.0",
        -value    => "minor",
        -variable => \$::ignoreversions
    )->pack( -side => "top", -anchor => "w" );
    $radio_frame->Radiobutton(
        -text     => "Ignore Revisions, e.g. 1.2.3 --> 1.2.4",
        -value    => "revisions",
        -variable => \$::ignoreversions
    )->pack( -side => "top", -anchor => "w" );
    $radio_frame->Radiobutton(
        -text     => "Include All Updates",
        -value    => "none",
        -variable => \$::ignoreversions
    )->pack( -side => "top", -anchor => "w" );

    # OK- just dismisses dialog
    $::lglobal{versionbox}->Button(
        -text    => 'OK',
        -command => sub {
            ::killpopup('versionbox');
        }
    )->pack( -side => 'top', -pady => 2 );
}

#
# On a monthly basis, check to see if this is the most recent version of Guiguts
sub checkforupdatesmonthly {
    my $top = $::top;

    return if $::ignoreversions eq "major";    # Ignoring major revisions means never check

    # Is it 30 days since last check?
    return if time() - $::lastversioncheck < 30 * 24 * 60 * 60;
    $::lastversioncheck = time();

    my $updateanswer = $top->Dialog(
        -title          => 'Check for Updates',
        -text           => 'Would you like to check for updates?',
        -buttons        => [ 'OK', 'Later', 'Don\'t Ask' ],
        -default_button => 'OK'
    )->Show();

    checkforupdates("monthly") if $updateanswer eq 'OK';

    $::ignoreversions = "major" if $updateanswer eq 'Don\'t Ask';

    ::savesettings();
}

#
# Set bookmark at cursor location
sub setbookmark {
    my $bookmark   = shift;
    my $textwindow = $::textwindow;
    my $index      = '';
    my $indexb     = '';
    if ( $::bookmarks[$bookmark] ) {
        $indexb = $textwindow->index("bkmk$bookmark");
    }
    $index = $textwindow->index('insert');
    if ( $::bookmarks[$bookmark] ) {
        $textwindow->tagRemove( 'bkmk', $indexb, "$indexb+1c" );
    }
    if ( $index ne $indexb ) {
        $textwindow->markSet( "bkmk$bookmark", $index );
    }
    $::bookmarks[$bookmark] = $index;
    $textwindow->tagAdd( 'bkmk', $index, "$index+1c" );
    ::setedited(1);
}

#
# Go to numbered bookmark
sub gotobookmark {
    my $bookmark   = shift;
    my $textwindow = $::textwindow;
    if ( $::bookmarks[$bookmark] ) {
        $textwindow->see("bkmk$bookmark");
        $textwindow->markSet( 'insert', "bkmk$bookmark" );
        $textwindow->tagAdd( 'bkmk', "bkmk$bookmark", "bkmk$bookmark+1c" );
    } else {
        ::soundbell();
    }
}

#
# Scroll main window to make the given index position visible
sub seeindex {
    my ( $mark, $displayattop ) = @_;
    my $textwindow = $::textwindow;
    my $index      = $textwindow->index($mark);
    if ($displayattop) {
        $textwindow->yview($index);
    } else {
        $textwindow->see('end');    # Mark will be centered
        $textwindow->see($index);
    }
}

#
# Run ebookmaker tool on current HTML file to create epub and mobi or HTML version.
# Note ebookmaker creates a subfolder "out" when output folder is the same as input
# folder only when producing HTML version.
sub ebookmaker {
    my $makehtml   = shift =~ m/html/i;
    my $textwindow = $::textwindow;
    unless ($::ebookmakercommand) {
        ::locateExecutable( 'EBookMaker', \$::ebookmakercommand );
        return unless $::ebookmakercommand;
    }

    my ( $fname, $d, $ext ) = ::fileparse( $::lglobal{global_filename}, qr{\.[^\.]*$} );
    if ( $ext !~ /^(\.htm|\.html)$/ ) {
        $::top->Dialog(
            -text    => "Not an HTML file",
            -bitmap  => 'error',
            -title   => 'Ebookmaker error',
            -buttons => ['Ok']
        )->Show;
        return;
    }

    ::busy();    # Change cursor to show user something is happening

    # Get title information
    my $ttitle = $fname;    # Title defaults to base filename
    my $tbeg   = $textwindow->search( '-exact', '--', '<title>',  '1.0', '20.0' );
    my $tend   = $textwindow->search( '-exact', '--', '</title>', '1.0', '20.0' );
    if ( $tbeg and $tend ) {
        $ttitle = $textwindow->get( $tbeg . '+7c', $tend );       # Get whole title string
        $ttitle =~ s/\s+/ /g;                                     # Join into one line, single spaced
        $ttitle =~ s/The Project Gutenberg EBook of//i;           # Strip PG part - 3 formats
        $ttitle =~ s/(--|\x{2014})A Project Gutenberg eBook//i;
        $ttitle =~ s/\| Project Gutenberg//i;
        HTML::Entities::decode_entities($ttitle);                 # HTML entities need converting to characters
        $ttitle = deaccentdisplay($ttitle);                       # Remove accents since passing as argument in shell
        $ttitle =~ s/[^[:ascii:]]/_/g;                            # Substitute "_" for any remaining non-ASCII characters
        $ttitle =~ s/^\s+|\s+$//g;
    }

    my $filepath  = $::lglobal{global_filename};
    my $outputdir = $::globallastpath;

    infoerror("Beginning ebookmaker");
    infoerror(
        "Files will appear in the directory $::globallastpath" . ( $makehtml ? "out" : "" ) );

    # Set up options for which files ebookmaker will generate
    my $htmloption   = "";
    my $epub2option  = "";
    my $epub3option  = "";
    my $kindleoption = "";
    my $kf8option    = "";

    if ($makehtml) {
        $htmloption = "--make=html.images";
    } else {
        $epub2option = "--make=epub.images";
        $epub3option = "--make=epub3.images";

        # Only use Calibre to create mobi if it's on the path
        if ( $ENV{PATH} =~ /calibre/i ) {
            $kindleoption = "--make=kindle.images";
            $kf8option    = "--make=kf8.images";
        } else {
            infoerror("For Kindle files, install Calibre and ensure it is on your PATH");
        }
    }

    # Run ebookmaker, redirecting stdout and stderr to a file to analyse afterwards
    my $tmpfile = 'ebookmaker.tmp';
    my $runner  = ::runner::withfiles( undef, $tmpfile, $tmpfile );
    $outputdir =~ s/[\/\\]$//;                          # Remove trailing slash from output dir to avoid confusing ebookmaker
    my $configdir = ::dirname($::ebookmakercommand);    # Ebookmaker dir contains tidy.conf file
    $runner->run(
        $::ebookmakercommand,      "--verbose",
        "--max-depth=3",           $htmloption,
        $epub2option,              $epub3option,
        $kindleoption,             $kf8option,
        "--output-dir=$outputdir", "--output-file=$fname",
        "--config-dir=$configdir", "--title=$ttitle",
        "--author=$::bookauthor",  "$filepath"
    );

    # Check for errors or warnings in ebookmaker output
    open my $ebmout, '<', $tmpfile;
    my $err  = 0;
    my $warn = 0;
    while ( my $line = <$ebmout> ) {
        $err++ if $line =~ "^ERROR:" or $line =~ "^CRITICAL:";
        $warn++
          if $line  =~ "^WARNING:"
          and $line !~ "No gnu dbm support found"                                # ignore some warnings
          and $line !~ "No pg-(header|footer) found, inserted a generated one"
          and $line !~ "no boilerplate found in file"
          and $line !~ '<table> lacks "summary" attribute'
          and $line !~ 'Empty alt text for'
          and $line !~ "elements having class .* have been rewritten.";
        adderror($line);                                                         # Send all ebookmaker output to message log
    }
    close $ebmout;
    unlink $tmpfile;

    # Restore cursor, but only pop message log if there are errors or warnings
    ::unbusy();
    if ($err) {
        infoerror(
            "Ebookmaker finished with $err " . ( $err > 1 ? "errors" : "error" ) . " to check" );
        poperror();
    } elsif ($warn) {
        infoerror( "Ebookmaker finished with $warn "
              . ( $warn > 1 ? "warnings" : "warning" )
              . " to check" );
        poperror();
    } else {
        infoerror("Ebookmaker finished succesfully");
    }
}

#
# Concatenate given directories using OS-specific path separator
sub pathcatdir {
    return $_[0] . $Config::Config{path_sep} . $_[1];
}

#
# Run Sidenote Fixup
sub sidenotes {
    my $textwindow = $::textwindow;
    ::operationadd('Sidenote Fixup');
    ::hidepagenums();
    $textwindow->markSet( 'sidenote', '1.0' );
    my ( $bracketndx, $nextbracketndx, $bracketstartndx, $bracketendndx,
        $paragraphp, $paragraphn, $sidenote, $sdnoteindexstart );
    while (1) {
        $sdnoteindexstart = $textwindow->index('sidenote');
        $bracketstartndx =
          $textwindow->search( '-regexp', '--', '\[sidenote', $sdnoteindexstart, 'end' );
        if ($bracketstartndx) {
            $textwindow->replacewith( "$bracketstartndx+1c", "$bracketstartndx+2c", 'S' );
            $textwindow->markSet( 'sidenote', "$bracketstartndx+1c" );
            next;
        }
        $textwindow->markSet( 'sidenote', '1.0' );
        last;
    }
    while (1) {
        $sdnoteindexstart = $textwindow->index('sidenote');
        $bracketstartndx =
          $textwindow->search( '-regexp', '--', '\[Sidenote', $sdnoteindexstart, 'end' );
        last unless $bracketstartndx;
        $bracketndx = "$bracketstartndx+1c";
        while (1) {
            $bracketendndx = $textwindow->search( '--', ']', $bracketndx, 'end' );
            $bracketendndx = $textwindow->index("$bracketstartndx+9c")
              unless $bracketendndx;
            $bracketendndx = $textwindow->index("$bracketendndx+1c")
              if $bracketendndx;
            $nextbracketndx = $textwindow->search( '--', '[', $bracketndx, 'end' );
            if (   ($nextbracketndx)
                && ( $textwindow->compare( $nextbracketndx, '<', $bracketendndx ) ) ) {
                $bracketndx = $bracketendndx;
                next;
            }
            last;
        }
        $textwindow->markSet( 'sidenote', $bracketendndx );
        $paragraphp =
          $textwindow->search( '-backwards', '-regexp', '--', '^$', $bracketstartndx, '1.0' );
        $paragraphp = $bracketstartndx if not $paragraphp;
        $paragraphn = $textwindow->search( '-regexp', '--', '^$', $bracketstartndx, 'end' );
        $sidenote   = $textwindow->get( $bracketstartndx, $bracketendndx );
        if ( $textwindow->get( "$bracketstartndx-2c", $bracketstartndx ) ne "\n\n" ) {
            if (   ( $textwindow->get( $bracketendndx, "$bracketendndx+1c" ) eq ' ' )
                || ( $textwindow->get( $bracketendndx, "$bracketendndx+1c" ) eq "\n" ) ) {
                $textwindow->delete( $bracketendndx, "$bracketendndx+1c" );
            }
            $textwindow->delete( $bracketstartndx, $bracketendndx );
            $textwindow->see($bracketstartndx);
            $textwindow->insert( "$paragraphp+1l", $sidenote . "\n\n" );
        } elsif ( $textwindow->compare( "$bracketendndx+1c", '<', $paragraphn ) ) {
            if (   ( $textwindow->get( $bracketendndx, "$bracketendndx+1c" ) eq ' ' )
                || ( $textwindow->get( $bracketendndx, "$bracketendndx+1c" ) eq "\n" ) ) {
                $textwindow->delete( $bracketendndx, "$bracketendndx+1c" );
            }
            $textwindow->see($bracketstartndx);
            $textwindow->insert( $bracketendndx, "\n\n" );
        }
        $sdnoteindexstart = "$bracketstartndx+10c";
    }
    my $error = $textwindow->search( '-regexp', '--', '(?<=[^\[])[Ss]idenote[: ]', '1.0', 'end' );
    if ($error) {
        ::soundbell();
        $textwindow->see($error);
        $textwindow->markSet( 'insert', $error );
    }
}

#
# Find and format poetry line numbers. They need to be to the right, at
# least 2 spaces from the text.
sub poetrynumbers {
    my $textwindow = $::textwindow;
    $::searchstartindex = '1.0';
    ::hidepagenums();
    ::operationadd('Reformat poetry line numbers');
    my ( $linenum, $line, $spacer, $row, $col );
    while (1) {
        $::searchstartindex =
          $textwindow->search( '-regexp', '--', '(?<=\S)\s\s+\d+$', $::searchstartindex, 'end' );
        last unless $::searchstartindex;
        $textwindow->see($::searchstartindex);
        $textwindow->update;
        ( $row, $col ) = split /\./, $::searchstartindex;
        $line = $textwindow->get( "$row.0", "$row.end" );
        $line =~ s/(?<=\S)\s\s+(\d+)$//;
        $linenum = $1;
        $spacer  = $::rmargin - length($line) - length($linenum);
        $spacer -= 2;
        $line = '  ' . ( ' ' x $spacer ) . $linenum;
        $textwindow->delete( $::searchstartindex, "$::searchstartindex lineend" );
        $textwindow->insert( $::searchstartindex, $line );
        $::searchstartindex = ++$row . '.0';
    }
}

#
# Accepts an optional index to find the page number at that index
# Otherwise returns page number at index of the current insert position
sub get_page_number {
    my $textwindow = $::textwindow;
    my $pnum;
    my $markindex = shift // $textwindow->index('insert');
    my $mark      = $textwindow->markPrevious($markindex);
    while ($mark) {
        if ( $mark =~ /Pg(\S+)/ ) {
            $pnum = $1;
            last;
        } else {
            $mark = $textwindow->markPrevious($mark) if $mark;
        }
    }
    unless ($pnum) {
        $mark = $textwindow->markNext($markindex);
        while ($mark) {
            if ( $mark =~ /Pg(\S+)/ ) {
                $pnum = $1;
                last;
            } else {
                if (   ( not defined $textwindow->markNext($mark) )
                    || ( $mark eq $textwindow->markNext($mark) ) ) {
                    last;
                }
                $mark = $textwindow->markNext($mark);
                last unless $mark;
            }
        }
    }
    $pnum = '' unless $pnum;
    return $pnum;
}

#
# Pop the Set External Programs dialog
sub externalpopup {
    my $textwindow = $::textwindow;
    my $top        = $::top;
    my $menutempvar;
    if ( $::lglobal{extoptpop} ) {
        $::lglobal{extoptpop}->deiconify;
        $::lglobal{extoptpop}->raise;
        $::lglobal{extoptpop}->focus;
    } else {
        $::lglobal{extoptpop} = $top->Toplevel( -title => 'External Programs', );
        my $f0 = $::lglobal{extoptpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        $f0->Label( -text =>
              "You can set up external programs to be called from within guiguts here. Each line of entry boxes represent\n"
              . "a menu entry. The left box is the label that will show up under the menu. The right box is the calling parameters.\n"
              . "Format the calling parameters as they would be when entered into the \"Run\" entry under the Start button\n"
              . "(for Windows). You can call a file directly: (\"C:\\Program Files\\Accessories\\wordpad.exe\") or indirectly for\n"
              . "registered apps (start or rundll). If you call a program that has a space in the path, you must enclose the program\n"
              . "name in double quotes.\n\n"
              . "There are a few exposed internal variables you can use to build commands with.\nUse one of these variables to "
              . "substitute in the corresponding value.\n\n"
              . "\$d = the directory path of the currently open file.\n"
              . "\$f = the current open file name, without a path or extension.\n"
              . "\$e = the extension of the currently open file.\n"
              . '(So, to pass the currently open file, use $d$f$e.)' . "\n\n"
              . "\$i = the directory with full path that the png files are in.\n"
              . "\$p = the number of the page that the cursor is currently in.\n"
              . "\$t = the currently highlighted text.\n" )->pack;
        my $f1 = $::lglobal{extoptpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        for my $menutempvar ( 0 .. ( $#::extops < 10 ? 10 : $#::extops ) + 1 ) {
            $f1->Entry(
                -width        => 50,
                -textvariable => \$::extops[$menutempvar]{label},
                -state        => ( $menutempvar ? 'normal' : 'readonly' ),
            )->grid(
                -row    => "$menutempvar" + 1,
                -column => 1,
                -padx   => 2,
                -pady   => 2
            );
            $f1->Entry(
                -width        => 80,
                -textvariable => \$::extops[$menutempvar]{command},
            )->grid(
                -row    => "$menutempvar" + 1,
                -column => 2,
                -padx   => 2,
                -pady   => 2
            );
        }
        my $f2    = $::lglobal{extoptpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        my $gobut = $f2->Button(
            -command => sub {

                # save the settings and rebuild the menu
                externalpopuptidy();
                ::savesettings();
                ::menurebuild();
                ::killpopup('extoptpop');
            },
            -text  => 'OK',
            -width => 8
        )->pack( -side => 'top', -padx => 2, -anchor => 'n' );
        ::initialize_popup_without_deletebinding('extoptpop');
        $::lglobal{extoptpop}->protocol( 'WM_DELETE_WINDOW' => sub { externalpopupdestroy(); } );
    }
}

#
# Tidy and destroy the custom external commands dialog
sub externalpopupdestroy {
    externalpopuptidy();
    ::killpopup('extoptpop');
}

#
# Remove any empty items in the custom external commands list by building a fresh one
sub externalpopuptidy {
    my @new_extops = qw();
    for my $index ( 0 .. $#::extops ) {
        if ( $::extops[$index]{label} || $::extops[$index]{command} ) {
            push( @new_extops, $::extops[$index] );
        }
    }
    @::extops = @new_extops;
}

#
# Run an external program through the external commands menu
sub xtops {
    my $index = shift;
    return unless $::extops[$index]{command};
    ::runner( ::cmdinterp( $::extops[$index]{command} ) );
}

#
# Remove / set up the tool bar
sub toolbar_toggle {
    my $textwindow = $::textwindow;
    my $top        = $::top;

    # Destroy existing toolbar
    ::killpopup('toptool');
    undef $::lglobal{savetool};

    # Create toolbar unless not wanted
    unless ($::notoolbar) {
        $::lglobal{toptool}  = $top->ToolBar( -side => $::toolside, -close => '30' );
        $::lglobal{toolfont} = $top->Font(
            -family => 'Times',
            -weight => 'bold',
            -size   => 10
        );
        $::lglobal{toptool}->separator;
        $::lglobal{toptool}->ToolButton(
            -image   => 'fileopen16',
            -command => sub { ::file_open($textwindow); },
            -tip     => 'Open'
        );
        $::lglobal{savetool} = $::lglobal{toptool}->ToolButton(
            -image   => 'filesave16',
            -command => [ \&::savefile ],
            -tip     => 'Save',
        );
        ::reset_autosave();    # Ensure save icon color is correct for autosave setting

        # Mouse-3 just resets the autosave timers
        $::lglobal{savetool}->bind( '<3>', sub { ::reset_autosave() } );

        # Shift-Mouse-3 toggles the autosave setting
        $::lglobal{savetool}->bind(
            '<Shift-3>',
            sub {
                $::autosave = !$::autosave;
                ::reset_autosave();
            }
        );
        $::lglobal{toptool}->ToolButton(
            -image   => 'edittrash16',
            -command => sub {
                return if ( ::confirmempty() =~ /cancel/i );
                ::clearvars($textwindow);
            },
            -tip => 'Discard Edits'
        );
        $::lglobal{toptool}->separator;
        $::lglobal{toptool}->ToolButton(
            -image   => 'actundo16',
            -command => sub { $textwindow->undo; $textwindow->see('insert'); },
            -tip     => 'Undo'
        );
        $::lglobal{toptool}->ToolButton(
            -image   => 'actredo16',
            -command => sub { $textwindow->redo; $textwindow->see('insert'); },
            -tip     => 'Redo'
        );
        $::lglobal{toptool}->separator;
        $::lglobal{toptool}->ToolButton(
            -image   => 'filefind16',
            -command => [ \&::searchpopup ],
            -tip     => 'Search & Replace'
        );
        $::lglobal{toptool}->separator;
        $::lglobal{toptool}->ToolButton(
            -text    => 'WF²',
            -font    => $::lglobal{toolfont},
            -command => [ \&::wordfrequency ],
            -tip     => 'Word Frequency'
        );
        $::lglobal{toptool}->ToolButton(
            -text    => 'BL',
            -font    => $::lglobal{toolfont},
            -command => [ sub { ::errorcheckpop_up( $textwindow, $top, 'Bookloupe' ); } ],
            -tip     => 'Bookloupe'
        );
        $::lglobal{toptool}->ToolButton(
            -image   => 'actcheck16',
            -command => [ \&::spellchecker ],
            -tip     => 'Spell Check'
        );
        $::lglobal{toptool}->ToolButton(
            -text    => '"arid"',
            -command => [ \&::stealthscanno ],
            -tip     => 'Scannos'
        );
        $::lglobal{toptool}->separator;
        $::lglobal{toptool}->ToolButton(
            -text    => 'Common',
            -font    => $::lglobal{toolfont},
            -command => [ \&::commoncharspopup ],
            -tip     => 'Commonly-Used Characters Chart'
        );
        $::lglobal{toptool}->ToolButton(
            -text    => 'Grk',
            -font    => $::lglobal{toolfont},
            -command => [ \&::greekpopup ],
            -tip     => 'Greek Transliteration Popup'
        );
        $::lglobal{toptool}->ToolButton(
            -text    => 'UCS',
            -font    => $::lglobal{toolfont},
            -command => [ \&::utfcharsearchpopup ],
            -tip     => 'Unicode Character Search'
        );
        $::lglobal{toptool}->separator;
        $::lglobal{toptool}->ToolButton(
            -text    => 'HTML',
            -font    => $::lglobal{toolfont},
            -command => sub { ::htmlmarkpopup( $textwindow, $top ) },
            -tip     => 'HTML Markup'
        );
        $::lglobal{toptool}->separator;
        $::lglobal{toptool}->ToolButton(
            -text    => 'Tfx',
            -font    => $::lglobal{toolfont},
            -command => [ \&::tablefx ],
            -tip     => 'ASCII Table Formatting'
        );
        $::lglobal{toptool}->separator;
        $::lglobal{toptool}->ToolButton(
            -text    => 'Eol',
            -font    => $::lglobal{toolfont},
            -command => [ \&::endofline ],
            -tip     => 'Remove trailing spaces in selection'
        );
        $::lglobal{toptool}->ToolButton(
            -text    => 'FN',
            -font    => $::lglobal{toolfont},
            -command => [ \&::footnotepop ],
            -tip     => 'Footnote Fixup'
        );
    }
    ::savesettings();
}

#
# Expand current selection to span entire lines
# If multiple selections, span from first to last
sub expandselection {
    my ( $textwindow, $top ) = ( $::textwindow, $::top );
    my @ranges = $textwindow->tagRanges('sel');
    unless (@ranges) {
        push @ranges, $textwindow->index('insert');
        push @ranges, $textwindow->index('insert');
    }
    my $range_total = @ranges;
    return if $range_total == 0;
    my $thisblockend   = pop(@ranges);
    my $thisblockstart = $ranges[0];
    my ( $lsr, $lsc ) = split( /\./, $thisblockstart );
    my ( $ler, $lec ) = split( /\./, $thisblockend );
    $ler++ if $lec;
    $textwindow->tagAdd( 'sel', "$lsr.0", "$ler.0" );
    return ( $lsr, $ler );
}

#
# Adjust current selection to column mode, spanning a block defined by the two given corners
sub columnizeselection {
    my $textwindow  = shift;
    my @ranges      = $textwindow->tagRanges('sel');
    my $range_total = @ranges;
    return unless $range_total == 2;
    my $end   = pop(@ranges);
    my $start = pop(@ranges);
    $textwindow->unselectAll;
    my ( $lsr, $lsc ) = split( /\./, $start );
    my ( $ler, $lec ) = split( /\./, $end );
    if ( $lsc > $lec ) { my $tmp = $lsc; $lsc = $lec; $lec = $tmp; }

    for ( my $i = $lsr ; $i <= $ler ; $i++ ) {
        $textwindow->tagAdd( 'sel', "$i.$lsc", "$i.$lec" );
    }
}

#
# Get the id of the current project by searching for the project comments file
# in the current folder
sub getprojectid {
    my $fname = $::lglobal{global_filename};
    my ( $f, $d, $e ) = ::fileparse( $fname, qr{\.[^\.]*$} );
    opendir( DIR, "$d$::projectfileslocation" );
    for ( readdir(DIR) ) {
        if ( $_ =~ m/(projectID[0-9a-f]*)_comments\.html/ ) {
            $::projectid = $1;
            last;
        }
    }
    closedir(DIR);
    return;
}

#
# Manually set the current project id
sub setprojectid {
    my ( $textwindow, $top ) = ( $::textwindow, $::top );
    my $projectidpop = $top->DialogBox(
        -buttons => ['OK'],
        -title   => 'DP Project ID',
    );
    $projectidpop->resizable( 'no', 'no' );
    my $frame = $projectidpop->Frame->pack( -fill => 'x' );
    $frame->Label( -text => 'Project ID: ' )->pack( -side => 'left' );
    my $entry = $frame->Entry(
        -width        => 30,
        -textvariable => \$::projectid,
    )->pack( -side => 'left', -fill => 'x' );
    ::setedited(1);
    $projectidpop->Show;
}

#
# Open a project comments file that has been saved locally
sub viewprojectcomments {
    ::operationadd('View project comments locally');
    return if ::nofileloadedwarning();
    ::setprojectid() unless $::projectid;
    my $defaulthandler = $::extops[0]{command};
    my $commentsfile   = $::projectfileslocation . $::projectid . '_comments.html';
    $defaulthandler =~ s/\$f\$e/$commentsfile/;
    ::runner( ::cmdinterp($defaulthandler) ) if $::projectid;
}

#
# View the project discussion online
sub viewprojectdiscussion {
    ::operationadd('View project discussion online');
    return if ::nofileloadedwarning();
    ::setprojectid() unless $::projectid;
    ::launchurl( $::urlprojectdiscussion . $::projectid ) if $::projectid;
}

#
# View the project page online
sub viewprojectpage {
    ::operationadd('View project page online');
    return if ::nofileloadedwarning();
    ::setprojectid() unless $::projectid;
    ::launchurl( $::urlprojectpage . $::projectid ) if $::projectid;
}

# Allow for infrequent window updates to display during long operations
# Timings are only accurate to seconds, not milliseconds
# Routine keeps returning true until UPDATE_FREQUENCY seconds have passed.
# It then resets the base time and returns false.
# It is the user's responsibility to do the update when false is returned.
#
# Usage:
#   while ( lots_of_repeats ) {
#       my_processing_sub();
#       my_update_sub() unless ::updatedrecently();
#   }
#

{    # Block to make variables local & persistent
    my $UPDATE_FREQUENCY = 1;        # in seconds
    my $lastcalled       = time();

    sub updatedrecently {

        # Return true if not long since last time save
        return 1 if time() - $lastcalled < $UPDATE_FREQUENCY;

        # Too long since last time save, so save new time and return false
        $lastcalled = time();
        return 0;
    }
}    # end of variable-enclosing block

#
# Show/hide line numbers based on input argument
sub displaylinenumbers {
    $::vislnnm = shift;
    $::vislnnm ? $::textwindow->showlinenum : $::textwindow->hidelinenum;
    ::savesettings();
}

#
# Show/hide column numbers based on input argument
sub displaycolnumbers {
    $::viscolnm = shift;
    $::viscolnm ? $::textwindow->showcolnum : $::textwindow->hidecolnum;
    ::savesettings();
}

#
# Temporarily hide line & column numbers to speed up some operations
# Note that the global flags are not changed
sub hidelinenumbers {
    $::textwindow->hidelinenum if $::vislnnm;
    $::textwindow->hidecolnum  if $::viscolnm;
}

#
# Restore the line & column numbers after they have been temporarily hidden
sub restorelinenumbers {
    $::textwindow->showlinenum if $::vislnnm;
    $::textwindow->showcolnum  if $::viscolnm;
}

# Allow for long operations to be interrupted by the user
#
# Usage:
#   ::enable_interrupt();               # Pop interrupt dialog
#   while ( lots_of_repeats ) {
#       my_processing_sub();
#       last if ::query_interrupt();    # User has interrupted
#   }
#   ::disable_interrupt();
#
# Note that query_interrupt calls disable_interrupt when returning true,
# so it's OK to use return instead of last in above example.

{    # Block to make variable local & persistent
    my $operationinterrupt = 0;

    #
    # Popup the interrupt dialog so user can interrupt operation
    sub enable_interrupt {
        disable_interrupt();    # Reset mechanism
        $::lglobal{stoppop} = $::top->Toplevel;
        $::lglobal{stoppop}->title('Interrupt');
        ::initialize_popup_with_deletebinding('stoppop');
        my $frame      = $::lglobal{stoppop}->Frame->pack;
        my $stopbutton = $frame->Button(
            -command => sub { set_interrupt(); },
            -text    => 'Interrupt Operation',
            -width   => 16
        )->grid( -row => 1, -column => 1, -padx => 10, -pady => 10 );
    }

    #
    # Destroy the dialog and ensure flag is cleared
    sub disable_interrupt {
        killpopup('stoppop');
        $operationinterrupt = 0;
    }

    #
    # Set the interrupt flag, so next time query_interrupt is called, it will return true
    sub set_interrupt {
        $operationinterrupt = 1;
    }

    #
    # Return whether user has interrupted the operation.
    sub query_interrupt {
        return 0 unless $operationinterrupt;
        disable_interrupt();    # If interrupted destroy dialog
        return 1;
    }

}    # end of variable-enclosing block

#
# Sound bell unless global nobell flag is set
# Also flash first label on status bar unless noflash argument is given
sub soundbell {
    my $noflash = shift;
    $::textwindow->bell if $::textwindow and not $::nobell;
    return              if $noflash;
    return unless $::lglobal{current_line_label};
    $::lglobal{current_line_label}->configure( -background => $::activecolor );
    $::lglobal{current_line_label}->update;
    $::lglobal{current_line_label}->after( $::lglobal{delay} );
    $::lglobal{current_line_label}->configure( -background => 'gray' );
}

#
# Add given term to the given history array
sub add_entry_history {
    my ( $term, $history_array_ref ) = @_;

    return if $term eq '';

    my @temparray = @$history_array_ref;

    # new term goes at the top of a fresh list
    @$history_array_ref = ();
    push @$history_array_ref, $term;

    # add the other terms from the list in order
    for (@temparray) {
        next if $_ eq $term;                               # omit current term if previously in list
        push @$history_array_ref, $_;
        last if @$history_array_ref >= $::history_size;    # don't exceed maximum history size
    }
}

#
# Construct and post the history menu for the given widget
sub entry_history {
    my ( $widget, $history_array_ref ) = @_;

    my $menu = $widget->Menu( -title => 'History' );
    $menu->command(
        -label   => 'Clear History',
        -command => sub { @$history_array_ref = (); ::savesettings(); },
    );
    $menu->separator;
    for my $item (@$history_array_ref) {
        $menu->command(
            -label   => $item,
            -command => sub { $widget->delete( '0', 'end' ); $widget->insert( 'end', $item ); },
        );
    }
    my $x = $widget->rootx;
    my $y = $widget->rooty + $widget->height;
    $menu->post( $x, $y );
}

#
# Create a dialog that is similar to a DialogBox, with a label, text entry field,
# OK and Cancel buttons, but with control over its position
#
# Accepts the following named argument pairs:
# -key          => key to dialog in $::lglobal hash
# -title        => title for dialog
# -label        => label for entry field
# -textvariable => reference to variable paired with entry field
# -command      => reference to routine to be executed on OK/Enter
# -defaulttext  => optional default text in entry field that user will append to rather than typeover
#    e.g. given "Pg " for "Pg 25" on gotopage, just "25" will be selected and user will typeover
sub textentrydialogpopup {
    my %args        = (@_);                   # argument pair list stored in hash
    my $key         = $args{-key};
    my $title       = $args{-title};
    my $label       = $args{-label};
    my $varref      = $args{-textvariable};
    my $commandref  = $args{-command};
    my $defaulttext = $args{-defaulttext};

    $label .= ': ' unless $label =~ /: $/;
    $defaulttext = '' unless $defaulttext;
    my $len = length $defaulttext;

    my $textwindow = $::textwindow;
    my $top        = $::top;

    ::killpopup($key) if $::lglobal{$key};

    $::lglobal{$key} = $top->Toplevel;
    $::lglobal{$key}->title($title);

    my $frame1 =
      $::lglobal{$key}->Frame->pack( -expand => 1, -fill => 'x', -padx => 5, -pady => 5 );
    $$varref = $defaulttext unless $$varref;
    my $entryw = $frame1->Entry(
        -width        => 12,
        -textvariable => $varref,
    )->pack( -expand => 1, -fill => 'x', -side => 'right' );
    $frame1->Label( -text => $label )->pack( -side => 'right' );

    my $frame2 = $::lglobal{$key}->Frame->pack( -fill => 'x', -padx => 5, -pady => 5 );
    my $okbtn  = $frame2->Button(
        -text    => 'OK',
        -width   => 8,
        -command => sub { &$commandref(); ::killpopup($key); },
    )->grid( -row => 1, -column => 1, -padx => 5 );
    my $cancelbtn = $frame2->Button(
        -text    => 'Cancel',
        -width   => 8,
        -command => sub { ::killpopup($key); },
    )->grid( -row => 1, -column => 2, -padx => 5, );
    $::lglobal{$key}->Tk::bind( '<Return>', sub { $okbtn->invoke(); } );
    $::lglobal{$key}->Tk::bind( '<Escape>', sub { $cancelbtn->invoke(); } );

    $::lglobal{$key}->resizable( 'yes', 'yes' );
    ::initialize_popup_with_deletebinding($key);
    $entryw->focus;
    $entryw->selectionRange( $len, 'end' );
    $entryw->icursor($len);    # place cursor at end of default text
}

#
# Perform common tasks to set up a dialog box with an Entry field
# including setting Escape key and window manager close button to invoke cancel.
sub dialogboxcommonsetup {
    my $dlg    = shift;    # dialog key in lglobal
    my $var    = shift;    # global variable ref to link to entry field
    my $prompt = shift;    # prompt for label in dialog
    ::initialize_popup_without_deletebinding($dlg);
    $::lglobal{$dlg}->resizable( 'no', 'no' );
    $::lglobal{$dlg}
      ->Tk::bind( '<Key-KP_Enter>' => sub { $::lglobal{$dlg}->Subwidget('B_OK')->invoke; } );
    $::lglobal{$dlg}
      ->Tk::bind( '<Escape>' => sub { $::lglobal{$dlg}->Subwidget('B_Cancel')->invoke; } );
    $::lglobal{$dlg}
      ->protocol( 'WM_DELETE_WINDOW' => sub { $::lglobal{$dlg}->Subwidget('B_Cancel')->invoke; } );
    my $frame = $::lglobal{$dlg}->Frame->pack( -fill => 'x' );
    $frame->Label( -text => $prompt )->pack( -side => 'left' );
    my $entry = $frame->Entry(
        -width        => 25,
        -textvariable => $var,
    )->pack( -side => 'left', -fill => 'x' );
    $::lglobal{$dlg}->Popup;
    $entry->focus;
    $entry->selectionRange( 0, 'end' );
    $::lglobal{$dlg}->Wait;
}

#
# Set cursor to "busy" so user knows something is happening
# Also ignore key and button presses
sub busy {
    $::top->Busy( -recurse => 1 );    # Top level widget and all descendants are "busy"
}

#
# Restore cursor and make key/button press bindings active again
sub unbusy {
    $::top->Unbusy;
}

#
# Handle fatal error (e.g. via die).
# Timestamp, bell, print to stderr, then display in message log dialog before
# giving user a chance to copy any messages before exiting.
# Note that where die is used as a result of a Tk action such as a button
# or key press, it will abort the action rather than the whole program
# and will use warnerror below not dierror.
sub dieerror {
    CORE::die(@_) if $^S;    # Use default die if occurs within eval

    my $message = stamperror(shift);
    soundbell();
    printerror($message);
    adderror($message);

    # Since about to die, give user a change to copy messages before exiting.
    adderror("When you close this message log the program will exit.");
    adderror("Copy/paste any useful messages before clicking Close.");
    poperror();
    if ( $::lglobal{messagespop} ) {
        $::lglobal{messagespop}->grab;          # stop user doing anything else
        $::lglobal{messagespop}->waitWindow;    # wait until they dismiss the dialog
    }
    exit 1;
}

#
# Handle warning (e.g. via warn)
# Timestamp, bell, print to stderr, then display in message log dialog
sub warnerror {
    my $message = stamperror(shift);
    soundbell();
    printerror($message);
    adderror($message);
    poperror();
}

#
# Output an info error
# No bell or message log dialog, but do print to stderr and store in errors list)
sub infoerror {
    my $message = stamperror(shift);
    printerror($message);
    adderror($message);
    refresherror();    # in case dialog is already popped
}

#
# Add a timestamp and strip trailing newlines from error
sub stamperror {
    my $message = shift;
    chomp $message;
    return strftime( "%H:%M:%S", localtime ) . ": " . $message;
}

#
# Print the given error to stderr
sub printerror {
    my $message = shift;
    print STDERR "$message\n";
}

{    # Start of block to localise error message array
    my @errormessages;

    #
    # Add the given error, stripped of newlines, to the error message list
    sub adderror {
        my $message = shift;
        chomp $message;
        push @errormessages, $message;
    }

    #
    # Pop the error messages box with all errors issued so far
    sub poperror {
        my $top = $::top;
        return unless $top;

        if ( defined( $::lglobal{messagespop} ) ) {
            $::lglobal{messagespop}->deiconify;
            $::lglobal{messagespop}->raise;
            $::lglobal{messagespop}->focus;
        } else {
            $::lglobal{messagespop} = $top->Toplevel;
            $::lglobal{messagespop}->title('Message Log');
            my $button_ok = $::lglobal{messagespop}->Button(
                -text    => 'Close',
                -command => sub { ::killpopup('messagespop'); }
            )->pack( -side => 'bottom', -pady => 5 );
            my $frame = $::lglobal{messagespop}->Frame->pack(
                -side   => 'top',
                -expand => 'yes',
                -fill   => 'both'
            );
            $::lglobal{msgbox} = $frame->Scrolled(
                'ROText',
                -scrollbars => 'se',
                -background => $::bkgcolor,
                -font       => 'proofing',
                -width      => 80,
                -height     => 25,
                -wrap       => 'none',
            )->pack( -anchor => 'nw', -expand => 'yes', -fill => 'both' );
            ::initialize_popup_with_deletebinding('messagespop');
            ::drag( $::lglobal{msgbox} );
            $::lglobal{msgbox}->focus;
        }
        refresherror();
    }

    #
    # Refresh message box with all messages issued so far if it is popped
    sub refresherror {
        return unless defined $::lglobal{messagespop};
        $::lglobal{msgbox}->delete( '1.0', 'end' );
        $::lglobal{msgbox}->insert( 'end', join( "\n", @errormessages ) . "\n" );
        $::lglobal{msgbox}->see('end');
    }

}    # End of block to localise error message array

#
# Subroutine to bind mouse wheel to scrolling behaviour so that the wheel scrolls
# a list widget whenever focus is in the containing dialog.
# Requires a widget to bind to (typically the dialog) and a Scrolled widget.
# Adapted from https://docstore.mik.ua/orelly/perl3/tk/ch15_02.htm
sub BindMouseWheel {
    my $bindwidget = shift;
    my $listwidget = shift;

    if ( $^O eq 'MSWin32' ) {
        $bindwidget->bind(
            '<MouseWheel>' => [
                sub {
                    $listwidget->yview( 'scroll', -( $_[1] / 120 ) * 3, 'units' )
                      unless $listwidget->focusCurrent == $listwidget->Subwidget('scrolled');
                },
                Tk::Ev('D')
            ]
        );
    } else {

        # Support for mousewheels on Linux commonly comes through
        # mapping the wheel to buttons 4 and 5.  If you have a
        # mousewheel ensure that the mouse protocol is set to
        # "IMPS/2" in your /etc/X11/XF86Config (or XF86Config-4)
        # file:
        #
        # Section "InputDevice"
        #     Identifier  "Mouse0"
        #     Driver      "mouse"
        #     Option      "Device" "/dev/mouse"
        #     Option      "Protocol" "IMPS/2"
        #     Option      "Emulate3Buttons" "off"
        #     Option      "ZAxisMapping" "4 5"
        # EndSection
        $bindwidget->bind( '<4>' => sub { $listwidget->yview( 'scroll', -3, 'units' ); } );
        $bindwidget->bind( '<5>' => sub { $listwidget->yview( 'scroll', +3, 'units' ); } );
    }
}

#
# Process command line, which has to be done before call to initialize() in guiguts.pl
#
# runtests must be set before initialize(), otherwise it will load
# setting.rc which could influence the test results.
#
# homedirectory must be handled before initialize(), so that
# homedirectory and guigutsdirectory are both set correctly.
sub processcommandline {

    # Default values if not specified on command line
    $::lglobal{runtests}      = 0;
    $::lglobal{homedirectory} = '';
    $::lglobal{nohome}        = 0;

    GetOptions(
        'home=s'   => \$::lglobal{homedirectory},
        'nohome'   => \$::lglobal{nohome},
        'runtests' => \$::lglobal{runtests}
    ) or die("Error in command line arguments\n");

    $::lglobal{nohome} = 1 if $::lglobal{runtests};    # Don't want GGprefs folder for test suite - it will affect the results
}

#
# Handle setting of homedir to store prefs, language data files, personal dictionary files, etc
# Priority as follows:
# 1. If nohome is set, ignore home option and default homedir - use historical location under release
# 2. If homedir set via command line, use if it is suitable
# 3. If default homedir location exists, use it
# 4. Use historical location under release
sub sethomedir {

    # If nohome set, force the use of historical location under release dir
    if ( $::lglobal{nohome} ) {
        $::lglobal{homedirectory} = $::lglobal{guigutsdirectory};
        return;
    }

    # If homedir already specified via command line, ensure it is suitable
    if ( $::lglobal{homedirectory} ) {
        $::lglobal{homedirectory} = ::rel2abs( $::lglobal{homedirectory} );
        ::infoerror( "Using home directory: " . $::lglobal{homedirectory} );
        if ( -e $::lglobal{homedirectory} ) {
            die "ERROR: --home directory must be a directory\n" unless -d $::lglobal{homedirectory};
        } else {
            die "ERROR: --home directory could not be created\n"
              unless mkdir $::lglobal{homedirectory};
        }
        die "ERROR: --home directory is not writeable\n" unless -w $::lglobal{homedirectory};
    } else {    # Otherwise if user's global GG prefs dir exists, use that
        my $defaulthomedirectory = path_defaulthomedir();
        $::lglobal{homedirectory} = $defaulthomedirectory if -d $defaulthomedirectory;
    }

    # If still not set, use historical locations under the release directory
    $::lglobal{homedirectory} = $::lglobal{guigutsdirectory}
      unless $::lglobal{homedirectory};
}

#
# Copy various settings files from another release into the default home directory location
sub copysettings {
    my $top = $::top;

    # User chooses release to copy from
    my $source = $top->chooseDirectory(
        -title =>
          "Choose top-level Guiguts release folder with settings you want to copy. Cancel now if you have unsaved changes!",
        -initialdir => "$::lglobal{guigutsdirectory}",
    );
    return unless $source and -d $source;

    # Check user hasn't chosen global homedir by mistake
    if ( $source eq path_defaulthomedir() ) {
        $top->messageBox(
            -icon    => 'error',
            -type    => 'Ok',
            -title   => 'Bad Folder',
            -message => "You must choose a Guiguts release folder"
        );
        return;
    }

    # Check that user has selected a suitable directory, i.e. contains appropriate files/folders
    my $settings = 'setting.rc';
    my $header   = 'header.txt';
    my $huser    = 'header_user.txt';
    for my $file ( $settings, $header ) {    # header_user.txt is not required to exist
        unless ( -f ::catfile( $source, $file ) ) {
            $top->messageBox(
                -icon    => 'error',
                -type    => 'Ok',
                -title   => 'Bad Folder',
                -message => "$source does not contain a '$file' file"
            );
            return;
        }
    }
    my $datadir = 'data';
    unless ( -d ::catdir( $source, $datadir ) ) {
        $top->messageBox(
            -icon    => 'error',
            -type    => 'Ok',
            -title   => 'Bad Folder',
            -message => "$source does not contain a '$datadir' folder"
        );
        return;
    }

    # Ensure we have a folder to copy into
    my $dest = path_defaulthomedir();
    if ( -d $dest ) {    # If homedir already exists, is it OK to overwrite files in it?
        my $ans = $top->messageBox(
            -icon    => 'warning',
            -type    => 'YesNo',
            -default => 'yes',
            -title   => 'Overwrite Warning',
            -message =>
              "You already have a global settings folder: $dest - are you sure you want to overwrite the settings there with the ones stored under $source?"
        );
        return if $ans =~ /no/i;
    } else {             # If it doesn't exist, create it
        die "ERROR: settings directory could not be created\n" unless mkdir $dest;
    }
    die "ERROR: settings directory is not writeable\n" unless -w $dest;

    # Copy any top level files first
    for my $file ( $settings, $header, $huser ) {
        ::copy( ::catfile( $source, $file ), ::catfile( $dest, $file ) )
          if -f ::catfile( $source, $file );
    }

    # Now copy user's labels files and dictionary files
    my $datasource = ::catdir( $source, $datadir );
    opendir( my $dh, $datasource ) || die "Can't opendir $datasource: $!";
    my @files = sort grep { -f "$datasource/$_" } readdir($dh);
    closedir $dh;
    for my $file (@files) {
        next if $file =~ /labels.*default\.rc/;    # Don't copy default labels files
        ::copy( ::catfile( $datasource, $file ), ::catfile( $dest, $file ) )
          if $file =~ /labels_.*\.rc/ or $file =~ /dict_.*_user\.txt/;
    }

    # Need to exit immediately to stop newly copied setting.rc file being overwritten.
    # This could happen if the global settings folder already existed, so this
    # execution of the program was already using the setting.rc from there.
    # Now the user has overwritten that setting.rc by copying from a different release,
    # we must not re-overwrite it from within this program.
    $top->messageBox(
        -icon    => 'info',
        -type    => 'Ok',
        -title   => 'Restart Necessary',
        -message =>
          "Guiguts will now exit. When you restart, it will use the settings that have just been copied to $dest"
    );
    exit;
}

1;
