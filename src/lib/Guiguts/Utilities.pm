package Guiguts::Utilities;
use strict;
use warnings;

BEGIN {
    use Exporter();
    our ( @ISA, @EXPORT );
    @ISA    = qw(Exporter);
    @EXPORT = qw(&openpng &get_image_file &arabic &roman &popscroll
      &cmdinterp &nofileloadedwarning &win32_cmdline &win32_start
      &win32_is_exe &win32_create_process &dos_path &runner &debug_dump &run &launchurl &escape_regexmetacharacters
      &deaccentsort &deaccentdisplay &readlabels &BindMouseWheel &working &initialize &fontinit &initialize_popup_with_deletebinding
      &initialize_popup_without_deletebinding &titlecase &os_normal &escape_problems &natural_sort_alpha
      &natural_sort_length &natural_sort_freq &drag &cut &paste &textcopy &colcut &colcopy &colpaste &showversion
      &checkforupdates &checkforupdatesmonthly &gotobookmark &setbookmark &seeindex &ebookmaker
      &sidenotes &poetrynumbers &get_page_number &externalpopup
      &xtops &toolbar_toggle &killpopup &expandselection &currentfileisunicode &currentfileislatin1
      &getprojectid &setprojectid &viewprojectcomments &viewprojectdiscussion &viewprojectpage
      &scrolldismiss &updatedrecently &hidelinenumbers &restorelinenumbers &displaylinenumbers
      &enable_interrupt &disable_interrupt &set_interrupt &query_interrupt &soundbell);

}

sub get_image_file {
    my $pagenum = shift;
    my $number;
    my $imagefile;
    unless ($::pngspath) {
        if ($::OS_WIN) {
            $::pngspath = "${main::globallastpath}pngs\\";
        } else {
            $::pngspath = "${main::globallastpath}pngs/";
        }
        ::setpngspath($pagenum) unless ( -e "$::pngspath$pagenum.png" );
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
        ::runner( $::globalviewerpath, $imagefile );
    } else {
        ::setpngspath($pagenum);
    }
    return;
}

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
            $arg = ::encode( "utf-8", $arg );
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
}

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
    }
    return join " ", @args;
}

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
        if (m/["<>|&()!%^]/) {    # would be very nice to have & for urls...""
            warn 'Refusing to run "start" command with unsafe characters ("<>|&()!%^): '
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
    system $cmdline;
}

sub win32_is_exe {
    my ($exe) = @_;
    return -x $exe && !-d $exe;
}

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
        print STDERR "Failed to run $args[0]: ";
        print STDERR Win32::FormatMessage( Win32::GetLastError() );
        return undef;
    }
    return;
}

# This turns long Windows path to DOS path, e.g., C:\Program Files\
# becomes C:\Progra~1\.
# Removed from code in 1.0.6 (why?), reintroduced 1.0.22
# to fix Link Check etc. failing with spaces in names
sub dos_path {
    return Win32::GetShortPathName( $_[0] );
}

# system(LIST)
# (but slightly more robust, particularly on Windows).
sub run {
    my @args = @_;
    if ( !$::OS_WIN ) {
        system { $args[0] } @args;
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

# Launch url in browser
sub launchurl {
    my $url     = shift;
    my $command = $::extops[0]{command};
    eval('$command =~ s/\$d\$f\$e/$url/');
    ::runner( ::cmdinterp($command) );
}

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

# just working out how to do things
# prints everything I can think of to debug.txt
# prints seenwords to words.txt
sub debug_dump {
    open my $save, '>', 'debug.txt';
    print $save "\%lglobal values:\n";
    for my $key ( keys %::lglobal ) {
        if   ( $::lglobal{$key} ) { print $save "$key => $::lglobal{$key}\n"; }
        else                      { print $save "$key x=>\n"; }
    }
    print $save "\n\@ARGV command line arguments:\n";
    for my $element (@ARGV) {
        print $save "$element\n";
    }
    print $save "\n\%SIG variables:\n";
    for my $key ( keys %SIG ) {
        if ( $SIG{$key} ) {
            print $save "$key => $SIG{$key}\n";
        } else {
            print $save "$key x=>\n";
        }
    }
    print $save "\n\%ENV environment variables:\n";
    for my $key ( keys %ENV ) {
        print $save "$key => $ENV{$key}\n";
    }
    print $save "\n\@INC include path:\n";
    for my $element (@INC) {
        print $save "$element\n";
    }
    print $save "\n\%INC included filenames:\n";
    for my $key ( keys %INC ) {
        print $save "$key => $INC{$key}\n";
    }
    close $save;
    my $section = "\%lglobal{seenwords}\n";
    open $save, '>:bytes', 'words.txt';
    for my $key ( keys %{ $::lglobal{seenwords} } ) {
        $section .= "$key => $::lglobal{seenwords}{$key}\n";
    }
    utf8::encode($section);
    print $save $section;
    close $save;
    $section = "\%lglobal{seenwordslang}\n";
    open $save, '>:bytes', 'words2.txt';
    for my $key ( keys %{ $::lglobal{seenwords} } ) {
        if ( $::lglobal{seenwordslang}{$key} ) {
            $section .= "$key => $::lglobal{seenwordslang}{$key}\n";
        } else {
            $section .= "$key x=>\n";
        }
    }
    utf8::encode($section);
    print $save $section;
    close $save;
    open $save, '>', 'project.txt';
    print $save "\%projectdict\n";
    for my $key ( keys %::projectdict ) {
        print $save "$key => $::projectdict{$key}\n";
    }
    close $save;
}

sub escape_regexmetacharacters {
    my $inputstring = shift;
    $inputstring =~ s/([\{\}\[\]\(\)\^\$\.\|\*\+\?\\])/\\$1/g;
    $inputstring =~ s/\\\\(['-])/\\$1/g;
    return $inputstring;
}

sub deaccentsort {
    my $phrase = shift;
    return $phrase unless ( $phrase =~ y/\xC0-\xFF// );
    eval "\$phrase =~ tr/$::convertcharssinglesearch/$::convertcharssinglereplace/";
    $phrase =~ s/([$::convertcharsmultisearch])/$::convertcharssort{$1}/g;
    return $phrase;
}

sub deaccentdisplay {
    my $phrase = shift;
    return $phrase unless ( $phrase =~ y/\xC0-\xFF// );

    # first convert the characters specified by the language
    $phrase =~ s/([$::convertcharsdisplaysearch])/$::convertcharsdisplay{$1}/g;

    # then convert anything that hasn't been converted already, using the default one character substitute
    $phrase =~
      tr/¿¡¬√ƒ≈‡·‚„‰Â«Á–»… ÀËÈÍÎÃÕŒœÏÌÓÔ“”‘’÷ÿÚÛÙıˆ¯—Òﬂﬁ˛Ÿ⁄€‹˘˙˚¸›ˇ˝/AAAAAAaaaaaaCcDdEEEEeeeeIIIIiiiiOOOOOOooooooNnsTtUUUUuuuuYyy/;
    return $phrase;
}

sub readlabels {
    my $labelfile        = ::catfile( 'data', "labels_$::booklang.rc" );
    my $defaultlabelfile = ::catfile( 'data', "labels_$::booklang" . "_default.rc" );
    $defaultlabelfile = ::catfile( 'data', 'labels_en_default.rc' ) unless ( -e $defaultlabelfile );
    @::gcviewlang     = ();

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
    # - Single-char-search and single-char-replace to be used in tr/single-char-search/single-char-replace/ in deaccentsort
    # - Multi-char-search to be used together with convertcharssort in s/// in deaccentsort
    # - Display-multi-char-search to be used with convertcharsdisplay in s/// in deaccentdisplay
    $::convertcharsdisplaysearch = join( '', keys %::convertcharsdisplay );
    $::convertcharsmultisearch   = join( '', keys %::convertcharssort );

    $::convertcharssinglesearch  = "¿¡¬√ƒ≈∆‡·‚„‰ÂÊ«Á–»… ÀËÈÍÎÃÕŒœÏÌÓÔ“”‘’÷ÿÚÛÙıˆ¯—Òﬂﬁ˛Ÿ⁄€‹˘˙˚¸›ˇ˝";
    $::convertcharssinglereplace = "AAAAAAAaaaaaaaCcDdEEEEeeeeIIIIiiiiOOOOOOooooooNnsTtUUUUuuuuYyy";
    my @chararray = keys %::convertcharssort;
    for ( my $i = 0 ; $i < @chararray ; $i++ ) {
        my $index = index( $::convertcharssinglesearch, $chararray[$i] );
        substr $::convertcharssinglesearch,  $index, 1, '';
        substr $::convertcharssinglereplace, $index, 1, '';
    }
}

sub BindMouseWheel {
    my ($w) = @_;
    if ($::OS_WIN) {
        $w->bind(
            '<MouseWheel>' => [
                sub {
                    $_[0]->yview( 'scroll', -( $_[1] / 120 ) * 3, 'units' );
                },
                ::Ev('D')
            ]
        );
    } else {
        $w->bind(
            '<4>' => sub {
                $_[0]->yview( 'scroll', -3, 'units' )
                  unless $Tk::strictMotif;
            }
        );
        $w->bind(
            '<5>' => sub {
                $_[0]->yview( 'scroll', +3, 'units' )
                  unless $Tk::strictMotif;
            }
        );
    }
}

sub working {
    my $msg = shift;
    my $top = $::top;
    if ( defined( $::lglobal{workpop} ) && ( defined $msg ) ) {
        $::lglobal{worklabel}->configure( -text => "\n\n\nWorking....\n$msg\nPlease wait.\n\n\n" );
        $::lglobal{workpop}->update;
    } elsif ( defined $::lglobal{workpop} ) {
        $::lglobal{workpop}->destroy;
        undef $::lglobal{workpop};
    } else {
        $::lglobal{workpop} = $top->Toplevel;
        $::lglobal{workpop}->transient($top);
        $::lglobal{workpop}->title('Working.....');
        $::lglobal{worklabel} = $::lglobal{workpop}->Label(
            -text       => "\n\n\nWorking....\n$msg\nPlease wait.\n\n\n",
            -font       => '{helvetica} 20 bold',
            -background => $::activecolor,
        )->pack;
        $::lglobal{workpop}->resizable( 'no', 'no' );
        $::lglobal{workpop}->protocol(
            'WM_DELETE_WINDOW' => sub {
                $::lglobal{workpop}->destroy;
                undef $::lglobal{workpop};
            }
        );
        $::lglobal{workpop}->Icon( -image => $::icon );
        $::lglobal{workpop}->update;
    }
}

sub initialize {
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
    if ( $0 =~ m/\/|\\/ ) {
        my $dir = $0;
        $dir =~ s/(\/|\\)[^\/\\]+$/$1/;
        chdir $dir if length $dir;
    }

    # positionhash stores user's window position
    # geometryhash stores user's window position and size
    # Set default value if no value already loaded from setting.rc
    $::geometryhash{aboutpop}         = '+312+136'        unless $::geometryhash{aboutpop};
    $::geometryhash{alignpop}         = '+338+83'         unless $::geometryhash{alignpop};
    $::geometryhash{asciiboxpop}      = '+358+187'        unless $::geometryhash{asciiboxpop};
    $::positionhash{brkpop}           = '+482+131'        unless $::positionhash{brkpop};
    $::positionhash{defurlspop}       = '+150+150'        unless $::positionhash{defurlspop};
    $::geometryhash{errorcheckpop}    = '+484+72'         unless $::geometryhash{errorcheckpop};
    $::positionhash{extoptpop}        = '+120+38'         unless $::positionhash{extoptpop};
    $::positionhash{filepathspop}     = '+55+7'           unless $::positionhash{filepathspop};
    $::positionhash{fixpop}           = '+34+22'          unless $::positionhash{fixpop};
    $::positionhash{floodpop}         = '+150+150'        unless $::positionhash{floodpop};
    $::positionhash{fontpop}          = '+10+10'          unless $::positionhash{fontpop};
    $::geometryhash{footcheckpop}     = '+22+12'          unless $::geometryhash{footcheckpop};
    $::positionhash{footpop}          = '+255+157'        unless $::positionhash{footpop};
    $::geometryhash{gcviewoptspop}    = '+264+72'         unless $::geometryhash{gcviewoptspop};
    $::positionhash{grpop}            = '+144+153'        unless $::positionhash{grpop};
    $::positionhash{guesspgmarkerpop} = '+10+10'          unless $::positionhash{guesspgmarkerpop};
    $::geometryhash{hotkeyspop}       = '+144+119'        unless $::geometryhash{hotkeyspop};
    $::positionhash{hilitepop}        = '+150+150'        unless $::positionhash{hilitepop};
    $::positionhash{hintpop}          = '+150+150'        unless $::positionhash{hintpop};
    $::geometryhash{hpopup}           = '300x400+584+211' unless $::geometryhash{hpopup};
    $::positionhash{htmlgenpop}       = '+145+37'         unless $::positionhash{htmlgenpop};
    $::positionhash{htmlimpop}        = '+45+37'          unless $::positionhash{htmlimpop};
    $::positionhash{latinpop}         = '+10+10'          unless $::positionhash{latinpop};
    $::geometryhash{linkpop}          = '+224+72'         unless $::geometryhash{linkpop};
    $::positionhash{marginspop}       = '+145+137'        unless $::positionhash{marginspop};
    $::positionhash{markpop}          = '+140+93'         unless $::positionhash{markpop};
    $::geometryhash{oppop}            = '600x400+50+50'   unless $::geometryhash{oppop};
    $::geometryhash{pagelabelpop}     = '375x500+20+20'   unless $::geometryhash{pagelabelpop};
    $::positionhash{pagemarkerpop}    = '+302+97'         unless $::positionhash{pagemarkerpop};
    $::geometryhash{pagesephelppop}   = '+191+132'        unless $::geometryhash{pagesephelppop};
    $::positionhash{pageseppop}       = '+334+176'        unless $::positionhash{pageseppop};
    $::geometryhash{regexrefpop}      = '+106+72'         unless $::geometryhash{regexrefpop};
    $::positionhash{searchpop}        = '+10+10'          unless $::positionhash{searchpop};
    $::positionhash{selectionpop}     = '+10+10'          unless $::positionhash{selectionpop};
    $::positionhash{spellpopup}       = '+152+97'         unless $::positionhash{spellpopup};
    $::positionhash{srchhistsizepop}  = '+152+97'         unless $::positionhash{srchhistsizepop};
    $::positionhash{stoppop}          = '+10+10'          unless $::positionhash{stoppop};
    $::positionhash{surpop}           = '+150+150'        unless $::positionhash{surpop};
    $::positionhash{tblfxpop}         = '+120+120'        unless $::positionhash{tblfxpop};
    $::positionhash{txtconvpop}       = '+82+131'         unless $::positionhash{txtconvpop};
    $::positionhash{utfentrypop}      = '+191+132'        unless $::positionhash{utfentrypop};
    $::geometryhash{utfpop}           = '+46+46'          unless $::geometryhash{utfpop};
    $::geometryhash{utfsearchpop}     = '550x450+53+87'   unless $::geometryhash{utfsearchpop};
    $::geometryhash{versionbox}       = '300x250+80+80'   unless $::geometryhash{versionbox};
    $::geometryhash{wfpop}            = '+365+63'         unless $::geometryhash{wfpop};

    # manualhash stores subpage of manual for each dialog
    # Where dialog is used in several contexts, use 'dialogname+context' as key
    $::manualhash{'aboutpop'}                = '#Overview';
    $::manualhash{'alignpop'}                = '/Guiguts_1.1_Text_Menu#Align_text_on_string';
    $::manualhash{'asciiboxpop'}             = '/Guiguts_1.1_Text_Menu#Draw_ASCII_Boxes';
    $::manualhash{'brkpop'}                  = '/Guiguts_1.1_Tools_Menu#Check_Orphaned_Brackets';
    $::manualhash{'defurlspop'}              = '/Guiguts_1.1_Preferences_Menu#File_Paths';
    $::manualhash{'errorcheckpop+Bookloupe'} = '/Guiguts_1.1_Tools_Menu#Bookloupe';
    $::manualhash{'errorcheckpop+Jeebies'}   = '/Guiguts_1.1_Tools_Menu#Jeebies';
    $::manualhash{'errorcheckpop+Load Checkfile'} = '/Guiguts_1.1_Tools_Menu#Load_Checkfile';
    $::manualhash{'errorcheckpop+pptxt'}          = '/Guiguts_1.1_Text_Menu#PPtxt';
    $::manualhash{'errorcheckpop+W3C Validate Remote'} =
      '/Guiguts_1.1_HTML#HTML_Validator_.28local.29';
    $::manualhash{'errorcheckpop+W3C Validate'} = '/Guiguts_1.1_HTML#HTML_Validator_.28local.29';
    $::manualhash{'errorcheckpop+W3C Validate CSS'} = '/Guiguts_1.1_HTML#CSS_Validator';
    $::manualhash{'errorcheckpop+Link Check'} =
      '/Guiguts_1.1_HTML#Check_for_link_errors_.28HTML_Link_Checker.29';
    $::manualhash{'errorcheckpop+HTML Tidy'} = '/Guiguts_1.1_HTML#HTML_Tidy';
    $::manualhash{'errorcheckpop+pphtml'}    = '/Guiguts_1.1_HTML#PPhtml';
    $::manualhash{'errorcheckpop+ppvimage'} =
      '/Guiguts_1.1_HTML#Check_for_image-related_errors_.28PPVimage.29';
    $::manualhash{'extoptpop'}        = '/Guiguts_1.1_Custom_Menu';
    $::manualhash{'filepathspop'}     = '/Guiguts_1.1_Preferences_Menu#File_Paths';
    $::manualhash{'fixpop'}           = '/Guiguts_1.1_Tools_Menu#Basic_Fixup';
    $::manualhash{'floodpop'}         = '/Guiguts_1.1_Edit_Menu#Flood_Fill';
    $::manualhash{'fontpop'}          = '/Guiguts_1.1_Preferences_Menu#Appearance';
    $::manualhash{'footcheckpop'}     = '/Guiguts_1.1_Tools_Menu#Footnote_Fixup';
    $::manualhash{'footpop'}          = '/Guiguts_1.1_Tools_Menu#Footnote_Fixup';
    $::manualhash{'gcviewoptspop'}    = '/Guiguts_1.1_Tools_Menu#Bookloupe';
    $::manualhash{'grpop'}            = '/Guiguts_1.1_Tools_Menu#Find_and_Convert_Greek';
    $::manualhash{'guesspgmarkerpop'} = '/Guiguts_1.1_File_Menu#Guess_Page_Markers';
    $::manualhash{'hotkeyspop'}       = '/Guiguts_1.1_Help_Menu#Keyboard_Shortcuts';
    $::manualhash{'hilitepop'}        = '/Guiguts_1.1_Navigating#Highlighting_Characters';
    $::manualhash{'hintpop'}          = '/Guiguts_1.1_Tools_Menu#Scanno_Hints';
    $::manualhash{'hpopup'}           = '/Guiguts_1.1_Tools_Menu#Harmonic_Searches';
    $::manualhash{'htmlgenpop'} = '/Guiguts_1.1_HTML#Convert_the_text_to_HTML_.28HTML_Generator.29';
    $::manualhash{'htmlimpop'}  = '/Guiguts_1.1_HTML#Add_Illustrations';
    $::manualhash{'latinpop'}   = '/Guiguts_1.1_Unicode_Menu#The_Latin-1_Dialog';
    $::manualhash{'linkpop'}    = '/Guiguts_1.1_HTML#The_HTML_Markup_Dialog';
    $::manualhash{'marginspop'} = '/Guiguts_1.1_Preferences_Menu#Processing';
    $::manualhash{'markpop'}    = '/Guiguts_1.1_HTML#The_HTML_Markup_Dialog';
    $::manualhash{'oppop'}      = '/Guiguts_1.1_File_Menu#View_Operations_History';
    $::manualhash{'pagelabelpop'}      = '/Guiguts_1.1_File_Menu#Configure_Page_Labels';
    $::manualhash{'pagemarkerpop'}     = '/Guiguts_1.1_File_Menu#Display.2FAdjust_Page_Markers';
    $::manualhash{'pagesephelppop'}    = '/Guiguts_1.1_Tools_Menu#Fixup_Page_Separators';
    $::manualhash{'pageseppop'}        = '/Guiguts_1.1_Tools_Menu#Fixup_Page_Separators';
    $::manualhash{'regexrefpop'}       = '/Guiguts_1.1_Searching#Regular_Expressions';
    $::manualhash{'searchpop+scannos'} = '/Guiguts_1.1_Tools_Menu#Stealth_Scannos';
    $::manualhash{'searchpop+search'}  = '/Guiguts_1.1_Searching#The_Search_Dialog';
    $::manualhash{'selectionpop'}      = '/Guiguts_1.1_Edit_Menu#Selection_Dialog';
    $::manualhash{'spellpopup'}        = '/Guiguts_1.1_Tools_Menu#Spell_Check';
    $::manualhash{'srchhistsizepop'}   = '/Guiguts_1.1_Preferences_Menu#Processing';
    $::manualhash{'stoppop'}           = '#Overview';
    $::manualhash{'surpop'}            = '/Guiguts_1.1_Edit_Menu#Surround_Selection';
    $::manualhash{'tblfxpop'}          = '/Guiguts_1.1_Text_Menu#ASCII_Table_Effects';
    $::manualhash{'txtconvpop'}        = '/Guiguts_1.1_Text_Menu#The_Txt_Conversion_Dialog';
    $::manualhash{'utfentrypop'}       = '/Guiguts_1.1_Unicode_Menu#Unicode_Lookup_by_Ordinal';
    $::manualhash{'utfpop'}            = '/Guiguts_1.1_Unicode_Menu#The_Unicode_Menu';
    $::manualhash{'utfsearchpop'}      = '/Guiguts_1.1_Unicode_Menu#Unicode_Search_by_Name';
    $::manualhash{'versionbox'} =
      '/Guiguts_1.1_Help_Menu#Guiguts_HELP_Menu:_Online_and_Built-in_Help';
    $::manualhash{'wfpop'} = '/Guiguts_1.1_Tools_Menu#Word_Frequency';

    ::readsettings();
    ::fontinit();    # Initialize the fonts for the two windows
    ::utffontinit();

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
    $::text_font = $top->fontCreate(
        'courier',
        -family => "Courier New",
        -size   => 12,
        -weight => 'normal',
    );

    # The actual text widget
    $::textwindow = $::text_frame->LineNumberText(
        -widget          => 'TextUnicode',
        -exportselection => 'true',             # 'sel' tag is associated with selections
        -background      => $::bkgcolor,
        -relief          => 'sunken',
        -font            => $::lglobal{font},
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
    $::textwindow->SetGUICallbacks(
        [
            \&::update_indicators,
            sub {
                return unless $::nohighlights;
                $::textwindow->HighlightAllPairsBracketingCursor;
            },
        ]
    );

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
    $::lglobal{groutp}           = 'l';

    # The 4 default replacements below must match one of the radiobutton values in htmlgenpop
    $::lglobal{html_b}             = '<b>';                       # HTML convert - default replacement for <b>
    $::lglobal{html_f}             = '<span class="antiqua">';    # HTML convert - default replacement for <f>
    $::lglobal{html_g}             = '<em class="gesperrt">';     # HTML convert - default replacement for <g>
    $::lglobal{html_i}             = '<i>';                       # HTML convert - default replacement for <i>
    $::lglobal{htmlimgwidthtype}   = '%';                         # HTML image width in % or em
    $::lglobal{htmlimgalignment}   = 'center';                    # HTML image alignment
    $::lglobal{htmlimagesizex}     = 0;                           # HTML pixel width of file loaded in image dialog
    $::lglobal{htmlimagesizey}     = 0;                           # HTML pixel height of file loaded in image dialog
    $::lglobal{isedited}           = 0;
    $::lglobal{wf_ignore_case}     = 0;
    $::lglobal{keep_latin1}        = 1;                           # HTML convert - retain Latin1 characters
    $::lglobal{lastmatchindex}     = '1.0';
    $::lglobal{lastsearchterm}     = '';
    $::lglobal{leave_utf}          = 1;                           # HTML convert - retain utf8 characters
    $::lglobal{longordlabel}       = 0;
    $::lglobal{ordmaxlength}       = 1;
    $::lglobal{pageanch}           = 1;                           # HTML convert - add page anchors
    $::lglobal{pagecmt}            = 0;                           # HTML convert - page markers as comments
    $::lglobal{poetrynumbers}      = 0;                           # HTML convert - find & format poetry line numbers
    $::lglobal{regaa}              = 0;
    $::lglobal{seepagenums}        = 0;
    $::lglobal{selectionsearch}    = 0;
    $::lglobal{selmaxlength}       = 1;
    $::lglobal{shorthtmlfootnotes} = 1;                           # HTML convert - Footnote_3 rather than Footnote_3_3
    $::lglobal{showblocksize}      = 1;
    $::lglobal{showthispageimage}  = 0;
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
    @{ $::lglobal{fixopt} } = ( 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1 );

    # Bookloupe error types
    @{ $::lglobal{gcarray} } = (
        'Asterisk',
        'Begins with punctuation',
        'Broken em-dash',
        'Capital "S"',
        'Carat character',
        'CR without LF',
        'Double punctuation',
        'endquote missing punctuation',
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

    $::lglobal{guigutsdirectory} = ::dirname( ::rel2abs($0) )
      unless defined $::lglobal{guigutsdirectory};
    $::scannospath = ::catfile( $::lglobal{guigutsdirectory}, 'scannos' )
      unless $::scannospath;

    # Find tool locations. setdefaultpath handles differences in *nix/Windows
    # executable names and looks on the search path.
    $::ebookmakercommand = ::setdefaultpath( $::ebookmakercommand,
        ::catfile( $::lglobal{guigutsdirectory}, 'tools', 'ebookmaker', 'ebookmaker.exe' ) );
    $::validatecsscommand = ::setdefaultpath( $::validatecsscommand,
        ::catfile( $::lglobal{guigutsdirectory}, 'tools', 'W3C', 'css-validator.jar' ) );
    $::gutcommand = ::setdefaultpath( $::gutcommand,
        ::catfile( $::lglobal{guigutsdirectory}, 'tools', 'bookloupe', 'bookloupe.exe' ) );
    $::jeebiescommand = ::setdefaultpath( $::jeebiescommand,
        ::catfile( $::lglobal{guigutsdirectory}, 'tools', 'jeebies', 'jeebies.exe' ) );
    $::tidycommand = ::setdefaultpath( $::tidycommand,
        ::catfile( $::lglobal{guigutsdirectory}, 'tools', 'tidy', 'tidy.exe' ) );
    $::globalviewerpath = ::setdefaultpath( $::globalviewerpath,
        ::catfile( '\Program Files', 'XnView', 'xnview.exe' ) );
    $::globalspellpath = ::setdefaultpath( $::globalspellpath,
        ::catfile( '\Program Files', 'Aspell', 'bin', 'aspell.exe' ) );
    $::validatecommand = ::setdefaultpath( $::validatecommand,
        ::catfile( $::lglobal{guigutsdirectory}, 'tools', 'W3C', 'onsgmls.exe' ) );

    my $textwindow = $::textwindow;
    $textwindow->tagConfigure( 'footnote', -background => 'cyan' );
    $textwindow->tagConfigure( 'scannos',  -background => $::highlightcolor );
    $textwindow->tagConfigure( 'bkmk',     -background => 'green' );
    $textwindow->tagConfigure( 'table',    -background => '#E7B696' );
    $textwindow->tagRaise('sel');
    $textwindow->tagConfigure( 'quotemark', -background => '#CCCCFF' );
    $textwindow->tagConfigure( 'highlight', -background => 'orange' );
    $textwindow->tagConfigure( 'linesel',   -background => '#8EFD94' );
    $textwindow->tagConfigure(
        'pagenum',
        -background  => 'yellow',
        -relief      => 'raised',
        -borderwidth => 2
    );
    $textwindow->tagBind( 'pagenum', '<ButtonRelease-1>', \&::pnumadjust );
    ::displaylinenumbers($::vislnnm);

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
        "\x{1F20}" => 'Í)',
        "\x{1F21}" => 'Í(',
        "\x{1F28}" => ' )',
        "\x{1F29}" => ' (',
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
        "\x{1F60}" => 'Ù)',
        "\x{1F61}" => 'Ù(',
        "\x{1F68}" => '‘)',
        "\x{1F69}" => '‘(',
        "\x{1F70}" => 'a\\\\',
        "\x{1F71}" => 'a/',
        "\x{1F72}" => 'e\\\\',
        "\x{1F73}" => 'e/',
        "\x{1F74}" => 'Í\\\\',
        "\x{1F75}" => 'Í/',
        "\x{1F76}" => 'i\\\\',
        "\x{1F77}" => 'i/',
        "\x{1F78}" => 'o\\\\',
        "\x{1F79}" => 'o/',
        "\x{1F7A}" => 'y\\\\',
        "\x{1F7B}" => 'y/',
        "\x{1F7C}" => 'Ù\\\\',
        "\x{1F7D}" => 'Ù/',
        "\x{1FB0}" => 'a=',
        "\x{1FB1}" => 'a_',
        "\x{1FB3}" => 'a|',
        "\x{1FB6}" => 'a~',
        "\x{1FB8}" => 'A=',
        "\x{1FB9}" => 'A_',
        "\x{1FBA}" => 'A\\\\',
        "\x{1FBB}" => 'A/',
        "\x{1FBC}" => 'A|',
        "\x{1FC3}" => 'Í|',
        "\x{1FC6}" => 'Í~',
        "\x{1FC8}" => 'E\\\\',
        "\x{1FC9}" => 'E/',
        "\x{1FCA}" => ' \\\\',
        "\x{1FCB}" => ' /',
        "\x{1FCC}" => ' |',
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
        "\x{1FF6}" => 'Ù~',
        "\x{1FF3}" => 'Ù|',
        "\x{1FF8}" => 'O\\\\',
        "\x{1FF9}" => 'O/',
        "\x{1FFA}" => '‘\\\\',
        "\x{1FFB}" => '‘/',
        "\x{1FFC}" => '‘|',
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
        "\x{1F22}" => 'Í)\\\\',
        "\x{1F23}" => 'Í(\\\\',
        "\x{1F24}" => 'Í)/',
        "\x{1F25}" => 'Í(/',
        "\x{1F26}" => 'Í~)',
        "\x{1F27}" => 'Í~(',
        "\x{1F2A}" => ' )\\\\',
        "\x{1F2B}" => ' (\\\\',
        "\x{1F2C}" => ' )/',
        "\x{1F2D}" => ' (/',
        "\x{1F2E}" => ' ~)',
        "\x{1F2F}" => ' ~(',
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
        "\x{1F62}" => 'Ù)\\\\',
        "\x{1F63}" => 'Ù(\\\\',
        "\x{1F64}" => 'Ù)/',
        "\x{1F65}" => 'Ù(/',
        "\x{1F66}" => 'Ù~)',
        "\x{1F67}" => 'Ù~(',
        "\x{1F6A}" => '‘)\\\\',
        "\x{1F6B}" => '‘(\\\\',
        "\x{1F6C}" => '‘)/',
        "\x{1F6D}" => '‘(/',
        "\x{1F6E}" => '‘~)',
        "\x{1F6F}" => '‘~(',
        "\x{1F80}" => 'a)|',
        "\x{1F81}" => 'a(|',
        "\x{1F88}" => 'A)|',
        "\x{1F89}" => 'A(|',
        "\x{1F90}" => 'Í)|',
        "\x{1F91}" => 'Í(|',
        "\x{1F98}" => ' )|',
        "\x{1F99}" => ' (|',
        "\x{1FA0}" => 'Ù)|',
        "\x{1FA1}" => 'Ù(|',
        "\x{1FA8}" => '‘)|',
        "\x{1FA9}" => '‘(|',
        "\x{1FB2}" => 'a\\\|',
        "\x{1FB4}" => 'a/|',
        "\x{1FB7}" => 'a~|',
        "\x{1FC2}" => 'Í\\\|',
        "\x{1FC4}" => 'Í/|',
        "\x{1FC7}" => 'Í~|',
        "\x{1FD2}" => 'i\\\\+',
        "\x{1FD3}" => 'i/+',
        "\x{1FD7}" => 'i~+',
        "\x{1FE2}" => 'y\\\\+',
        "\x{1FE3}" => 'y/+',
        "\x{1FE7}" => 'y~+',
        "\x{1FF2}" => 'Ù\\\|',
        "\x{1FF4}" => 'Ù/|',
        "\x{1FF7}" => 'Ù~|',
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
        "\x{1F92}" => 'Í)\\\|',
        "\x{1F93}" => 'Í(\\\|',
        "\x{1F94}" => 'Í)/|',
        "\x{1F95}" => 'Í(/|',
        "\x{1F96}" => 'Í~)|',
        "\x{1F97}" => 'Í~(|',
        "\x{1F9A}" => ' )\\\|',
        "\x{1F9B}" => ' (\\\|',
        "\x{1F9C}" => ' )/|',
        "\x{1F9D}" => ' (/|',
        "\x{1F9E}" => ' ~)|',
        "\x{1F9F}" => ' ~(|',
        "\x{1FA2}" => 'Ù)\\\|',
        "\x{1FA3}" => 'Ù(\\\|',
        "\x{1FA4}" => 'Ù)/|',
        "\x{1FA5}" => 'Ù(/|',
        "\x{1FA6}" => 'Ù~)|',
        "\x{1FA7}" => 'Ù~(|',
        "\x{1FAA}" => '‘)\\\|',
        "\x{1FAB}" => '‘(\\\|',
        "\x{1FAC}" => '‘)/|',
        "\x{1FAD}" => '‘(/|',
        "\x{1FAE}" => '‘~)|',
        "\x{1FAF}" => '‘~(|',
    );

    $::lglobal{checkcolor} = ($::OS_WIN) ? 'white' : $::activecolor;
    my $scroll_gif =
      'R0lGODlhCAAQAIAAAAAAAP///yH5BAEAAAEALAAAAAAIABAAAAIUjAGmiMutopz0pPgwk7B6/3SZphQAOw==';
    $::lglobal{scrollgif} = $top->Photo(
        -data   => $scroll_gif,
        -format => 'gif',
    );
}

sub scrolldismiss {
    my $textwindow = $::textwindow;
    return unless $::lglobal{scroller};
    $textwindow->configure( -cursor => $::lglobal{oldcursor} );
    $::lglobal{scroller}->destroy;
    $::lglobal{scroller} = '';
    $::lglobal{scroll_id}->cancel if $::lglobal{scroll_id};
    $::lglobal{scroll_id} = '';
}

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

sub fontinit {
    $::lglobal{font} = "{$::fontname} $::fontsize $::fontweight";
}

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

sub killpopup {
    my $popupname = shift;
    return unless $::lglobal{$popupname};
    $::lglobal{$popupname}->destroy;
    undef $::lglobal{$popupname};
}

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
    if ( ($::stayontop) and ( not $popupname eq "wfpop" ) ) {
        $::lglobal{$popupname}->transient($top);
    }
    if ( ($::wfstayontop) and ( $popupname eq "wfpop" ) ) {
        $::lglobal{$popupname}->transient($top);
    }

    $::lglobal{$popupname}->Tk::bind( '<F1>' => sub { display_manual( $popupname, $context ); } );

}

# Display the manual page corresponding to the given dialog name and optional context string
sub display_manual {
    my $helplookup = shift;
    my $context    = shift;
    $helplookup .= '+' . $context if $context;
    my $manualpage = $::manualhash{$helplookup};
    if ($manualpage) {
        ::launchurl( 'https://www.pgdp.net/wiki/PPTools/Guiguts/Guiguts_1.1_Manual' . $manualpage );
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

sub titlecase {
    my $text = shift;
    $text = lc($text);
    $text =~ s/(^\W*\w)/\U$1\E/;
    $text =~ s/([\s\n]+\W*\w)/\U$1\E/g;
    $text =~ s/ (A|An|And|At|By|From|In|Of|On|The|To)\b/ \L$1\E/g if ( $::booklang eq 'en' );
    return $text;
}

sub os_normal {
    my $tmp = $_[0];
    $tmp =~ s|/|\\|g if $::OS_WIN && $tmp;
    return $tmp;
}

sub escape_problems {
    my $var = shift;
    if ($var) {
        $var =~ s/\\+$/\\\\/g;
        $var =~ s/(?!<\\)'/\\'/g;
    }
    return $var;
}

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

## Ultra fast natural sort - wants an array
sub natural_sort_alpha {
    my $i;
    s/(\d+(,\d+)*)/pack 'aNa*', 0, length $1, $1/eg, $_ .= ' ' . $i++
      for ( my @x = map { lc deaccentsort $_} @_ );
    @_[ map { (split)[-1] } sort @x ];
}

## Fast length sort with secondary natural sort - wants an array
sub natural_sort_length {
    $_->[2] =~ s/(\d+(,\d+)*)/pack 'aNa*', 0, length $1, $1/eg
      for ( my @x = map { [ length noast($_), $_, lc deaccentsort $_ ] } @_ );
    map { $_->[1] } sort { $b->[0] <=> $a->[0] or $a->[2] cmp $b->[2] } @x;
}

## Fast freqency sort with secondary natural sort - wants a hash reference
sub natural_sort_freq {
    $_->[2] =~ s/(\d+(,\d+)*)/pack 'aNa*', 0, length $1, $1/eg
      for (
        my @x =
        map { [ $_[0]->{$_}, $_, lc deaccentsort $_ ] } keys %{ $_[0] }
      );
    map { $_->[1] } sort { $b->[0] <=> $a->[0] or $a->[2] cmp $b->[2] } @x;
}

## No Asterisks
sub noast {
    local $/ = ' ****';
    my $phrase = shift;
    chomp $phrase;
    return $phrase;
}

### Edit Menu
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

# Special paste routine that will respond differently
# for overstrike/insert modes
sub paste {
    my $textwindow = $::textwindow;
    if ( $textwindow->OverstrikeMode ) {
        my @ranges = $textwindow->tagRanges('sel');
        if (@ranges) {
            my $end   = pop @ranges;
            my $start = pop @ranges;
            $textwindow->delete( $start, $end );
        }
        my $text    = $textwindow->clipboardGet;
        my $lineend = $textwindow->get( 'insert', 'insert lineend' );
        my $length  = length $text;
        $length = length $lineend if ( length $lineend < length $text );
        $textwindow->delete( 'insert', 'insert +' . ($length) . 'c' );
        $textwindow->insert( 'insert', $text );
    } else {
        $textwindow->clipboardPaste;
    }
}

sub colcut {
    my $textwindow = shift;
    columnizeselection($textwindow);
    $textwindow->addGlobStart;
    ::cut();
    $textwindow->addGlobEnd;
}

sub colcopy {
    my $textwindow = shift;
    columnizeselection($textwindow);
    $textwindow->addGlobStart;
    ::textcopy();
    $textwindow->addGlobEnd;
}

sub colpaste {
    my $textwindow = shift;
    $textwindow->addGlobStart;
    $textwindow->clipboardColumnPaste;
    $textwindow->addGlobEnd;
}

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
    my $dialog = $top->Dialog(
        -title   => 'Versions',
        -popover => $top,
        -justify => 'center',
        -text    => $message,
    );
    $dialog->Show;
}

# Check what is the most recent version online
sub checkonlineversion {

    #working("Checking for update online (timeout 20 seconds)");
    my $ua = LWP::UserAgent->new(
        env_proxy  => 1,
        keep_alive => 1,
        timeout    => 20,
        ssl_opts   => {
            verify_hostname => 0,
        },
    );
    my $response = $ua->get('https://github.com/DistributedProofreaders/guiguts/releases');

    #working();
    unless ( $response->content ) {
        return;
    }
    if ( $response->content =~ /(\d+)\.(\d+)\.(\d+)\.zip/i ) {
        return "$1.$2.$3";
    }
}

# Check to see if this is the most recent version
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

# On a monthly basis, check to see if this is the most recent version
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

### Bookmarks
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
    ::update_indicators();
}

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

# Run EBookMaker tool on current HTML file to create epub and mobi versions
sub ebookmaker {

    unless ($::ebookmakercommand) {
        ::locateExecutable( 'EBookMaker', \$::ebookmakercommand );
        return unless $::ebookmakercommand;
    }

    my ( $fname, $d, $ext ) = ::fileparse( $::lglobal{global_filename}, qr{\.[^\.]*$} );
    if ( $ext !~ /^(\.htm|\.html)$/ ) {
        print "Not an HTML file\n";
        return;
    }
    my $filepath  = $::lglobal{global_filename};
    my $outputdir = $::globallastpath;

    print "\nBeginning ebookmaker\n";
    print "Files will appear in the directory $::globallastpath.\n";

    # EBookMaker needs to use Tidy and Kindlegen, so temporarily append to the path
    my $tidypath      = ::catdir( $::lglobal{guigutsdirectory}, 'tools', 'tidy' );
    my $kindlegenpath = ::catdir( $::lglobal{guigutsdirectory}, 'tools', 'kindlegen' );

    # local variable means global value will be restored at end of sub
    local $ENV{PATH} = pathcatdir( pathcatdir( $ENV{PATH}, $tidypath ), $kindlegenpath );

    ::runner( $::ebookmakercommand, "--verbose", "--max-depth=3", "--make=epub.images",
        "--make=kindle.images", "--output-dir=$outputdir.", "--title=$fname", "$filepath" );
}

# Concatenate given directories using OS-specific path separator
sub pathcatdir {
    return $_[0] . $Config::Config{path_sep} . $_[1];
}

## Sidenote Fixup
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
        $paragraphn = $textwindow->search( '-regexp', '--', '^$', $bracketstartndx, 'end' );
        $sidenote   = $textwindow->get( $bracketstartndx, $bracketendndx );
        if ( $textwindow->get( "$bracketstartndx-2c", $bracketstartndx ) ne "\n\n" ) {
            if (   ( $textwindow->get( $bracketendndx, "$bracketendndx+1c" ) eq ' ' )
                || ( $textwindow->get( $bracketendndx, "$bracketendndx+1c" ) eq "\n" ) ) {
                $textwindow->delete( $bracketendndx, "" );
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

# Find and format poetry line numbers. They need to be to the right, at
# least 2 space from the text.
## Reformat Poetry ~LINE Numbers
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
        ::update_indicators();
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

sub get_page_number {
    my $textwindow = $::textwindow;
    my $pnum;
    my $markindex = $textwindow->index('insert');
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

sub externalpopup {    # Set up the external commands menu
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
              . "There are a few exposed internal variables you can use to build commands with.\nUse one of these variable to "
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
                -background   => $::bkgcolor,
                -relief       => 'sunken',
                -textvariable => \$::extops[$menutempvar]{label},
                -state        => ( $menutempvar ? 'normal' : 'readonly' ),
            )->grid(
                -row    => "$menutempvar" + 1,
                -column => 1,
                -padx   => 2,
                -pady   => 4
            );
            $f1->Entry(
                -width        => 80,
                -background   => $::bkgcolor,
                -relief       => 'sunken',
                -textvariable => \$::extops[$menutempvar]{command},
            )->grid(
                -row    => "$menutempvar" + 1,
                -column => 2,
                -padx   => 2,
                -pady   => 4
            );
        }
        my $f2    = $::lglobal{extoptpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        my $gobut = $f2->Button(
            -activebackground => $::activecolor,
            -command          => sub {

                # remove any empty items in the list by building a fresh one
                my @new_extops = qw();
                for my $index ( 0 .. $#::extops ) {
                    if ( $::extops[$index]{label} || $::extops[$index]{command} ) {
                        push( @new_extops, $::extops[$index] );
                    }
                }
                @::extops = @new_extops;

                # save the settings and rebuild the menu
                ::savesettings();
                ::menurebuild();
                $::lglobal{extoptpop}->destroy;
                undef $::lglobal{extoptpop};
            },
            -text  => 'OK',
            -width => 8
        )->pack( -side => 'top', -padx => 2, -anchor => 'n' );
        ::initialize_popup_with_deletebinding('extoptpop');
    }
}

sub xtops {    # run an external program through the external commands menu
    my $index = shift;
    return unless $::extops[$index]{command};
    ::runner( ::cmdinterp( $::extops[$index]{command} ) );
}

sub toolbar_toggle {    # Set up / remove the tool bar
    my $textwindow = $::textwindow;
    my $top        = $::top;
    if ( $::notoolbar && $::lglobal{toptool} ) {
        $::lglobal{toptool}->destroy;
        undef $::lglobal{toptool};
        undef $::lglobal{savetool};
    } elsif ( !$::notoolbar && !$::lglobal{toptool} ) {
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
                ::update_indicators();
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
            -text    => 'WF≤',
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
            -text    => 'Ltn-1',
            -font    => $::lglobal{toolfont},
            -command => [ \&::latinpopup ],
            -tip     => 'Latin-1 Popup'
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

# expand current selection to span entire lines
# if multiple selections, span from first to last
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

# adjust current selection to column mode, spanning a block defined by the two given corners
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

sub currentfileisunicode {
    return 1 if $::utf8save;    # treat as unicode regardless of contents
    my $textwindow = $::textwindow;
    return $textwindow->search( '-regexp', '--', '[\x{100}-\x{FFFE}]', '1.0', 'end' );
}

sub currentfileislatin1 {
    my $textwindow = $::textwindow;
    return $textwindow->search( '-regexp', '--',
        '[\xC0-\xCF\xD1-\xD6\xD9-\xDD\xE0-\xEF\xF1-\xF6\xF9-\xFD]',
        '1.0', 'end' );
}

#FIXME: doesnt work quite right if multiple volumes held in same directory
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
        -background   => $::bkgcolor,
        -width        => 30,
        -textvariable => \$::projectid,
    )->pack( -side => 'left', -fill => 'x' );
    ::setedited(1);
    $projectidpop->Show;
}

sub viewprojectcomments {
    ::operationadd('View project comments locally');
    return if ::nofileloadedwarning();
    ::setprojectid() unless $::projectid;
    my $defaulthandler = $::extops[0]{command};
    my $commentsfile   = $::projectfileslocation . $::projectid . '_comments.html';
    $defaulthandler =~ s/\$f\$e/$commentsfile/;
    ::runner( ::cmdinterp($defaulthandler) ) if $::projectid;
}

sub viewprojectdiscussion {
    ::operationadd('View project discussion online');
    return if ::nofileloadedwarning();
    ::setprojectid() unless $::projectid;
    ::launchurl( $::urlprojectdiscussion . $::projectid ) if $::projectid;
}

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

# Show/hide line numbers based on input argument
sub displaylinenumbers {
    $::vislnnm = shift;
    $::vislnnm ? $::textwindow->showlinenum : $::textwindow->hidelinenum;
    ::savesettings();
}

# Temporarily hide line numbers to speed up some operations
# Note that the global flag is not changed
sub hidelinenumbers {
    $::textwindow->hidelinenum if $::vislnnm;
}

# Restore the line numbers after they have been temporarily hidden
sub restorelinenumbers {
    $::textwindow->showlinenum if $::vislnnm;
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

    # Popup the interrupt dialog so user can interrupt operation
    sub enable_interrupt {
        disable_interrupt();    # Reset mechanism
        $::lglobal{stoppop} = $::top->Toplevel;
        $::lglobal{stoppop}->title('Interrupt');
        ::initialize_popup_with_deletebinding('stoppop');
        my $frame      = $::lglobal{stoppop}->Frame->pack;
        my $stopbutton = $frame->Button(
            -activebackground => $::activecolor,
            -command          => sub { set_interrupt(); },
            -text             => 'Interrupt Operation',
            -width            => 16
        )->grid( -row => 1, -column => 1, -padx => 10, -pady => 10 );
    }

    # Destroy the dialog and ensure flag is cleared
    sub disable_interrupt {
        killpopup('stoppop');
        $operationinterrupt = 0;
    }

    # Set the interrupt flag, so next time query_interrupt is called, it will return true
    sub set_interrupt {
        $operationinterrupt = 1;
    }

    # Return whether user has interrupted the operation.
    sub query_interrupt {
        return 0 unless $operationinterrupt;
        disable_interrupt();    # If interrupted destroy dialog
        return 1;
    }

}    # end of variable-enclosing block

# Sound bell unless global nobell flag is set
# Also flash first label on status bar
sub soundbell {
    $::textwindow->bell unless $::nobell;
    return              unless $::lglobal{current_line_label};
    for ( 1 .. 5 ) {
        $::lglobal{current_line_label}->after( $::lglobal{delay} );
        $::lglobal{current_line_label}->configure( -background => $::activecolor );
        $::lglobal{current_line_label}->update;
        $::lglobal{current_line_label}->after( $::lglobal{delay} );
        $::lglobal{current_line_label}->configure( -background => 'gray' );
        $::lglobal{current_line_label}->update;
    }
}

1;
