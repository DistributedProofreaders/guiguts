package Guiguts::ErrorCheck;
use strict;
use warnings;

BEGIN {
    use Exporter();
    our ( @ISA, @EXPORT );
    @ISA    = qw(Exporter);
    @EXPORT = qw(&errorcheckpop_up &spellquerycleardict &spellqueryinitialize &spellquerywfwordok
      &errorcheckillosnupdateneeded &savetoerrortmpfile);
}

my @errorchecklines;
my %errors;
my $APOS   = "\x{2019}";             # Curly apostrophe/right single quote
my $BEGMSG = "Beginning check:";
my $ENDMSG = "Check is complete:";

#
# General error check window
# Handles Bookloupe, Jeebies, HTML & CSS Validate, Tidy, Link Check,
# Unmatched Tag/Brackets/Double Quotes/Block Checks
# pphtml, pptxt, ppvimage, Spell Query, EPUBCheck,
# Illustration Fixup, Sidenote Fixup and Load External Checkfile.
sub errorcheckpop_up {
    my ( $textwindow, $top, $errorchecktype ) = @_;
    my ( $line, $lincol );

    errorchecksettype($errorchecktype);
    ::hidepagenums();
    $textwindow->tagRemove( 'highlight', '1.0', 'end' );    # Remove any previous highlighting

    # Destroy and start afresh if already popped
    ::killpopup('errorcheckpop');
    $::lglobal{errorcheckpop} = $top->Toplevel;
    $::lglobal{errorcheckpop}->title($errorchecktype);

    my $ptopframeb = $::lglobal{errorcheckpop}->Frame->pack( -fill => 'x' );

    my $gcol = 0;

    # Label to count number of queries (not shown for EPUBCheck)
    $::lglobal{eccountlabel} =
      $errorchecktype eq 'EPUBCheck'
      ? 0
      : $ptopframeb->Label( -justify => 'left', )
      ->grid( -padx => 10, -row => 0, -column => $gcol++ );

    # Spell Query threshold setting sits under the query count label
    if ( $errorchecktype eq 'Spell Query' ) {
        $gcol = 0;
        $ptopframeb->Label( -text => 'Threshold <=' )
          ->grid( -padx => 0, -row => 1, -column => $gcol++ );
        $ptopframeb->Spinbox(
            -textvariable => \$::spellquerythreshold,
            -width        => 4,
            -increment    => 1,
            -from         => 1,
            -to           => 1000,
        )->grid( -padx => 0, -row => 1, -column => $gcol++ );
    }

    # All types have a button to re-run the check
    my $buttonlabel = 'Run Checks';
    $buttonlabel = 'Load Checkfile' if $errorchecktype eq 'Load Checkfile';
    my $opsbutton = $ptopframeb->Button(
        -command => sub {
            errorcheckpop_up( $textwindow, $top, $errorchecktype );
        },
        -text  => $buttonlabel,
        -width => 16
    )->grid( -padx => 10, -row => 0, -column => $gcol++ );

    # Spell Query bad word count sits under the Run Checks button
    if ( $errorchecktype eq 'Spell Query' ) {
        $gcol--;
        $::lglobal{sqbadwordcountlbl} =
          $ptopframeb->Label()->grid( -padx => 0, -row => 1, -column => $gcol++ );
    }

    $ptopframeb->Button(
        -command => sub {
            errorcheckcopy();
        },
        -text  => "Copy errors",
        -width => 16
    )->grid( -padx => 10, -row => 0, -column => $gcol++ );

    # Add verbose checkbox only for certain error check types
    if (   $errorchecktype eq 'Link Check'
        or $errorchecktype eq 'W3C Validate CSS'
        or $errorchecktype eq 'ppvimage'
        or $errorchecktype eq 'pphtml' ) {
        $ptopframeb->Checkbutton(
            -variable => \$::verboseerrorchecks,
            -text     => 'Verbose'
        )->grid( -padx => 10, -row => 0, -column => $gcol++ );

        # Bookloupe has button to change View Options
    } elsif ( $errorchecktype eq 'Bookloupe' ) {
        $ptopframeb->Button(
            -command => sub { gcviewopts(); },
            -text    => 'View Options',
            -width   => 16
        )->grid( -padx => 10, -row => 0, -column => $gcol++ );

        # Jeebies has paranoia level radio buttons
    } elsif ( $errorchecktype eq 'Jeebies' ) {
        $ptopframeb->Label( -text => 'Search mode:', )->grid( -row => 0, -column => $gcol++ );
        my @rbutton = ( [ 'Paranoid', 'p' ], [ 'Normal', '' ], [ 'Tolerant', 't' ], );
        for (@rbutton) {
            $ptopframeb->Radiobutton(
                -text     => $_->[0],
                -variable => \$::jeebiesmode,
                -value    => $_->[1],
                -command  => \&::savesettings,
            )->grid( -row => 0, -column => $gcol++ );
        }

        # Spell Query has Skip, Skip All, Add to Project Dict, Add to Global Dict
        # and languages field
    } elsif ( $errorchecktype eq 'Spell Query' ) {
        $::lglobal{spellqueryballoon} = $top->Balloon() unless $::lglobal{spellqueryballoon};
        $ptopframeb->Button(
            -command => sub {
                ::spelladdgoodwords();                                     # Add good words to project dictionary
                spellquerycleardict();                                     # Clear cache, so project dictionary will be reloaded below
                errorcheckpop_up( $textwindow, $top, $errorchecktype );    # Rerun Spell Query
            },
            -text  => 'Add good/bad words',
            -width => 16
        )->grid( -row => 1, -column => $gcol - 1 );
        my $btnskip = $ptopframeb->Button(
            -command => sub {
                errorcheckremove($errorchecktype);
                errorcheckview($errorchecktype);
            },
            -text  => 'Skip',
            -width => 16
        )->grid( -row => 0, -column => $gcol );
        $::lglobal{spellqueryballoon}
          ->attach( $btnskip, -msg => "Right-click\non queried spelling to Skip" );
        my $btnskipall = $ptopframeb->Button(
            -command => sub {
                errorcheckremovesimilar($errorchecktype);
                errorcheckview($errorchecktype);
            },
            -text  => 'Skip All',
            -width => 16
        )->grid( -row => 1, -column => $gcol++ );
        $::lglobal{spellqueryballoon}->attach( $btnskipall,
            -msg => "Ctrl+Shift+Right-click\non queried spelling to Skip All" );
        my $btnproj = $ptopframeb->Button(
            -command => sub {
                errorcheckprocessspell('project');
                errorcheckremovesimilar($errorchecktype);
                errorcheckview($errorchecktype);
            },
            -text  => 'Add to Project Dict',
            -width => 16
        )->grid( -row => 0, -column => $gcol );
        $::lglobal{spellqueryballoon}->attach( $btnproj,
            -msg => "Ctrl+Left-click\non queried spelling to\nAdd to Project Dictionary" );
        my $btnglob = $ptopframeb->Button(
            -command => sub {
                errorcheckprocessspell('global');
                errorcheckremovesimilar($errorchecktype);
                errorcheckview($errorchecktype);
            },
            -text  => 'Add to Global Dict',
            -width => 16
        )->grid( -row => 1, -column => $gcol++ );
        $::lglobal{spellqueryballoon}->attach( $btnglob,
            -msg => "Ctrl+Shift+Left-click\non queried spelling to\nAdd to Global Dictionary" );

        # Sorting options
        my $rcol = 1;
        $ptopframeb->Label( -text => 'Sort:', )->grid( -row => 2, -column => $rcol++ );
        my @rbutton =
          ( [ 'Line Number', 'l' ], [ 'Alphabetical', 'a' ], [ 'Case Insensitive', 'i' ], );
        $::lglobal{errsortmode} = 'l' unless $::lglobal{errsortmode};
        for (@rbutton) {
            $ptopframeb->Radiobutton(
                -text     => $_->[0],
                -variable => \$::lglobal{errsortmode},
                -value    => $_->[1],
                -command  => sub { errsortrefresh($errorchecktype); }
            )->grid( -row => 2, -column => $rcol++ );
        }
    }

    # Scrolled listbox to display the errors
    my $pframe = $::lglobal{errorcheckpop}->Frame->pack( -fill => 'both', -expand => 'both', );
    $::lglobal{errorchecklistbox} = $pframe->Scrolled(
        'Listbox',
        -scrollbars  => 'se',
        -background  => $::bkgcolor,
        -font        => 'proofing',
        -selectmode  => 'single',
        -activestyle => 'none',
    )->pack(
        -anchor => 'nw',
        -fill   => 'both',
        -expand => 'both',
        -padx   => 2,
        -pady   => 2
    );

    # Create the dialog - it has a customised delete binding which clears the error marks
    # and destroys the run/view options dialogs as well
    ::initialize_popup_without_deletebinding( 'errorcheckpop', "$errorchecktype" );
    $::lglobal{errorcheckpop}->protocol(
        'WM_DELETE_WINDOW' => sub {
            ::killpopup('errorcheckpop');
            ::killpopup('gcviewoptspop') if $errorchecktype eq 'Bookloupe';
            $textwindow->markUnset($_) for values %errors;
            errorcheckillosnclearbookmarks();
        }
    );
    ::drag( $::lglobal{errorchecklistbox} );

    # button 1 views the error
    $::lglobal{errorchecklistbox}->eventAdd( '<<view>>' => '<ButtonRelease-1>', '<Return>' );
    $::lglobal{errorchecklistbox}->bind( '<<view>>', sub { errorcheckview($errorchecktype); } );

    # buttons 2 & 3 remove the clicked error and view the next error
    $::lglobal{errorchecklistbox}->eventAdd(
        '<<remove>>' => '<ButtonRelease-2>',
        '<ButtonRelease-3>'
    );
    $::lglobal{errorchecklistbox}->bind(
        '<<remove>>',
        sub {
            errorchecksetactive();
            errorcheckremove($errorchecktype);
            errorcheckview($errorchecktype);
        }
    );

    # Ctrl + button 1 attempts to view and process the clicked error
    # For Spell Query, it adds the word to the project dictionary
    # For Illustration/Sidenote Fixup, moves illo/sidenote forward through file to a suitable spot
    $::lglobal{errorchecklistbox}->eventAdd( '<<process>>' => '<Control-ButtonRelease-1>' );
    $::lglobal{errorchecklistbox}->bind(
        '<<process>>',
        sub {
            errorchecksetactive();
            if ( $errorchecktype eq 'Spell Query' ) {
                errorcheckprocessspell('project');
                errorcheckremovesimilar($errorchecktype);
            } elsif ( $errorchecktype eq 'Illustration Fixup'
                or $errorchecktype eq 'Sidenote Fixup' ) {
                errorcheckprocessillosn('forward');
            } else {
                errorcheckprocess($errorchecktype);
            }
            errorcheckview($errorchecktype);
        }
    );

    # Ctrl + buttons 2 & 3 attempt to process the clicked error, then remove it and view the next error
    # if processing is set up for the current error type. Otherwise, just removes the error.
    $::lglobal{errorchecklistbox}->eventAdd(
        '<<processremove>>' => '<Control-ButtonRelease-2>',
        '<Control-ButtonRelease-3>'
    );
    $::lglobal{errorchecklistbox}->bind(
        '<<processremove>>',
        sub {
            errorchecksetactive();
            errorcheckprocess($errorchecktype);
            errorcheckremove($errorchecktype);
            errorcheckview($errorchecktype);
        }
    );

    # Ctrl + Shift + button 1 attempts to view and alternatively process the clicked error
    # For Spell Query, adds the word to the global dictionary
    # For Illustration/Sidenote Fixup, moves illo/sidenote backward through file to a suitable spot
    $::lglobal{errorchecklistbox}
      ->eventAdd( '<<processalternative>>' => '<Control-Shift-ButtonRelease-1>' );
    $::lglobal{errorchecklistbox}->bind(
        '<<processalternative>>',
        sub {
            errorchecksetactive();
            if ( $errorchecktype eq 'Spell Query' ) {
                errorcheckprocessspell('global');
                errorcheckremovesimilar($errorchecktype);
            } elsif ( $errorchecktype eq 'Illustration Fixup'
                or $errorchecktype eq 'Sidenote Fixup' ) {
                errorcheckprocessillosn('backward');
            }
            errorcheckview($errorchecktype);
        }
    );

    # Ctrl + Shift + buttons 2 & 3 remove all similar errors (e.g. suggesting same spelling correction)
    # and view the next error
    $::lglobal{errorchecklistbox}->eventAdd(
        '<<processremovesimilar>>' => '<Control-Shift-ButtonRelease-2>',
        '<Control-Shift-ButtonRelease-3>'
    );
    $::lglobal{errorchecklistbox}->bind(
        '<<processremovesimilar>>',
        sub {
            errorchecksetactive();
            errorcheckremovesimilar($errorchecktype);
            errorcheckview($errorchecktype);
        }
    );

    # Alt/command + button 1 pops the Search dialog prepopulated with the queried word
    $::lglobal{errorchecklistbox}->eventAdd( '<<errsearch>>' => "<$::altkey-ButtonRelease-1>" );
    $::lglobal{errorchecklistbox}->bind(
        '<<errsearch>>',
        sub {
            errorchecksetactive();
            my $line = $::lglobal{errorchecklistbox}->get('active');
            return
                  unless defined $line
              and defined $errors{$line}
              and $line =~ s/^\d+:\d+ +- ([\w'$APOS]+) .*/$1/;

            ::searchpopup();
            ::searchoptset(qw/1 x x 0/);    # Whole-word non-regex search
            $::lglobal{searchentry}->delete( 0, 'end' );
            $::lglobal{searchentry}->insert( 'end', $line );
            ::updatesearchlabels();         # Updates count in S&R dialog if word frequency has been run previously
            $::lglobal{searchpop}->deiconify;
            $::lglobal{searchpop}->raise;
            $::lglobal{searchpop}->focus;
        }
    );

    $::lglobal{errorcheckpop}->update;

    # End presentation; begin logic
    @errorchecklines = ();
    %errors          = ();
    my $mark  = 0;
    my @marks = $textwindow->markNames;
    for (@marks) {
        if ( $_ =~ /^t\d+$/ ) {
            $textwindow->markUnset($_);
        }
    }
    ::working($errorchecktype);

    my $errname;
    if ( $errorchecktype eq 'Load Checkfile' ) {
        $errname = $::lglobal{errorcheckpop}->getOpenFile( -title => 'File Name?' );
        if ( not $errname ) {    # if cancelled, close dialog and exit
            ::killpopup('errorcheckpop');
            ::working();
            return;
        }
    } else {
        push @errorchecklines, "$BEGMSG $errorchecktype";

        # Temporary file in same folder as current file - needs .html extension for some tools
        # Error output in same folder, named errors.err
        my ( $f, $d, $e ) = ::fileparse( $::lglobal{global_filename}, qr{\.[^\.]*$} );
        my $tmpfname = $d . 'tmpcheck.tmp';
        $tmpfname =~ s/tmp$/html/  if $errorchecktype eq 'W3C Validate CSS';
        $tmpfname =~ s/tmp$/html/  if $errorchecktype eq 'Nu HTML Check';
        $tmpfname =~ s/tmp$/xhtml/ if $errorchecktype eq 'Nu XHTML Check';
        $errname = $d . 'errors.err';

        if ( errorcheckrun( $errorchecktype, $tmpfname, $errname ) ) {    # exit if error check failed to run
            ::killpopup('errorcheckpop');
            ::working();
            return;
        }
    }

    # Zero-size error file means some tools failed badly (e.g. blocked by anti-virus software)
    if (    -z $errname
        and $errorchecktype ne "Spell Query"
        and $errorchecktype ne "Illustration Fixup"
        and $errorchecktype ne "Sidenote Fixup"
        and $errorchecktype ne "Load Checkfile"
        and $errorchecktype ne "Nu HTML Check"
        and $errorchecktype ne "Nu XHTML Check"
        and $errorchecktype ne "Unmatched DP Tags"
        and $errorchecktype ne "Unmatched HTML Tags"
        and $errorchecktype ne "Unmatched Brackets"
        and $errorchecktype ne "Unmatched Double Quotes"
        and $errorchecktype ne "Unmatched Block Markup" ) {
        unlink $errname;
        my $dialog = $top->Dialog(
            -text    => 'Error file was empty - maybe blocked by anti-virus software?',
            -bitmap  => 'question',
            -title   => "Empty $errorchecktype error file",
            -buttons => [qw/OK/],
        );
        $dialog->Show;
        ::killpopup('errorcheckpop');
        ::working();
        return;
    }

    # Open error file
    my $fh = FileHandle->new("< $errname");
    if ( not defined($fh) ) {
        my $dialog = $top->Dialog(
            -text    => 'Could not find ' . $errorchecktype . ' error file.',
            -bitmap  => 'question',
            -title   => 'File not found',
            -buttons => [qw/OK/],
        );
        $dialog->Show;
        ::killpopup('errorcheckpop');
        ::working();
        return;
    }

    # CSS validator reports line numbers from start of style block, so need to adjust
    my $lineadjust = 0;
    if (    $errorchecktype eq 'W3C Validate CSS'
        and $lineadjust = $textwindow->search( '--', '<style', '1.0', 'end' ) ) {
        $lineadjust =~ s/\..*//;    # strip column from 'row.column'
    }

    my $countblank   = 0;           # number of blank lines
    my $countqueries = 0;           # number of queries to be reported

    # Read and process one line at a time
    while ( $line = <$fh> ) {
        utf8::decode($line);

        # Remove leading space and end-of-line characters
        $line =~ s/^\s//g;
        $line =~ s/(\x0d)$//;
        chomp $line;

        # distinguish blank lines by setting them to varying numbers
        # of spaces, otherwise if user deletes one, it deletes them all
        $line = ' ' x ++$countblank if ( $line eq '' );

        # Skip rest of CSS
        last
          if $errorchecktype eq 'W3C Validate CSS'
          and not $::verboseerrorchecks
          and (( $line =~ /^To show your readers/i )
            or ( $line =~ /^Valid CSS Information/i ) );

        # skip blank lines
        next if $line =~ /^\s*$/;

        # skip some unnecessary lines from W3C Validate CSS
        next
          if $line =~ /^{output/i and not $::verboseerrorchecks
          or $line =~ /^W3C/i
          or $line =~ /^URI/i;

        # Skip verbose informational warnings in Link Check
        if (    ( not $::verboseerrorchecks )
            and ( $errorchecktype eq 'Link Check' )
            and ( $line =~ /^Link statistics/i ) ) {
            last;
        }
        if ( $errorchecktype eq 'pphtml' ) {
            if ( $line =~ /^-/i ) {    # skip lines beginning with '-'
                next;
            }
            if ( ( not $::verboseerrorchecks )
                and $line =~ /^Verbose checks/i ) {    # stop with verbose specials check
                last;
            }
        }

        my $columnadjust = 0;
        if ( $errorchecktype eq 'HTML Tidy' ) {
            last
              if $line =~ /^No warnings or errors were found/
              or $line =~ /^Tidy found/;
            $line =~ s/^\s*line (\d+) column (\d+)\s*/$1:$2 /;

        } elsif ( $errorchecktype eq "Nu HTML Check" or $errorchecktype eq "Nu XHTML Check" ) {
            if ( $line =~ "StackOverflowError" ) {
                push @errorchecklines, $line;
                my $dialog = $top->Dialog(
                    -text => "Could not check file locally - use W3C Validation web site.\n"
                      . "Please report this 'Java Stack Overflow' error.",
                    -bitmap  => 'warning',
                    -title   => 'Java Stack Overflow',
                    -buttons => [qw/OK/],
                );
                $dialog->Show;
                last;
            }
            $line =~ s/^.*?"://;                 # remove filename
            $line =~ s/-[0-9\.]+:/:/;            # remove end of line.col range
            $line =~ s/^(\d+):/$1.1:/;           # flag first column if no column given
            $line =~ s/^(\d+)\.(\d+):/$1:$2/;    # replace period with colon in line.col
            $columnadjust = -1;                  # GG columns start from zero, Nu starts from 1 (except for CSS errors)

        } elsif ( ( $errorchecktype eq "pphtml" )
            or ( $errorchecktype eq "ppvimage" ) ) {
            $line =~ s/^.*:(\d+):(\d+)\s*/$1:$2 /;
            $line =~ s/^\s*line (\d+)\s*/$1:0 /;

        } elsif ( ( $errorchecktype eq "W3C Validate CSS" )
            or ( $errorchecktype eq "Link Check" )
            or ( $errorchecktype eq "pptxt" ) ) {
            $line =~ s/^\s*line (\d+)\s*/$1:0 /;
            $line =~ s/^\s*Line : (\d+)\s*/$1:0 /;

        } elsif ( $errorchecktype eq "Load Checkfile" ) {

            # Load a checkfile from an external tool, e.g. online ppcomp, pptxt, pphtml
            # File may be in HTML format or a text file

            # Ignore HTML header & footer
            if ( $line =~ /<body>/ ) {
                @errorchecklines = ();
                next;
            }
            last if ( $line =~ /<\/body>/ );

            # Mark *red text* (used by pptxt)
            $line =~ s/<span class='red'>([^<]*)<\/span>/*$1*/g;

            # Mark >>>inserted<<< and ###deleted### text (used by ppcomp)
            $line =~ s/<ins>([^<]*)<\/ins>/>>>$1<<</g;
            $line =~ s/<del>([^<]*)<\/del>/###$1###/g;

            # Remove some unwanted HTML
            $line =~ s/<\/?span[^>]*>//g;
            $line =~ s/<\/?a[^>]*>//g;
            $line =~ s/<\/?pre>//g;
            $line =~ s/<\/?p[^>]*>//g;
            $line =~ s/<\/?div[^>]*>//g;
            $line =~ s/<br[^>]*>/ /g;             # Line break becomes space - can't insert \n
            $line =~ s/<\/?h[1-6][^>]*>/***/g;    # Put asterisks round headers
            $line =~ s/<hr[^>]*>/====/g;          # Replace horizontal rules with ====
            $line =~ s/\&lt;/</g;                 # Restore < & > characters
            $line =~ s/\&gt;/>/g;

            # if line has a number at the start, assume it is the error line number
            # unless it already has a column number, set the column number to zero
            $line =~ s/^\s*(\d+)[:\s]*/$1:0 / unless $line =~ /^\s*(\d+):(\d+)/;

        } elsif ( $errorchecktype eq "Bookloupe" ) {
            next if $line =~ /^File: /;
            next if $line =~ /^\s*-->.+ Not reporting/;
            if ( $line =~ /^\s*Line (\d+) column (\d+)\s*/ ) {

                # Adjust column number to start from 0 for most bookloupe errors
                $columnadjust = -1 if $line !~ /Long|Short|digit|space|bracket\?/;
                $line =~ s/^\s*Line (\d+) column (\d+)\s*/$1:$2 /;
            }
            $line =~ s/^\s*Line (\d+)\s*/$1:0 /;
            $line =~ s/ - Carat character\?/ - Caret character?/;                              # Correct bookloupe misspelling
            $line =~ s/ - endquote missing punctuation\?/ - Endquote missing punctuation?/;    # Correct capital letter inconsistency

        } elsif ( $errorchecktype eq "Jeebies" ) {
            next if $line =~ /^File: /;
            if ( $line =~ /^\s*Line (\d+) column (\d+)/ ) {
                my ( $row, $col ) = ( $1, $2 );

                # Jeebies reports end of phrase, so adjust to the beginning
                if ( $line =~ /Query phrase "([^"]+)"/ ) {
                    my $len      = length($1) + 1;
                    my $location = $textwindow->index( "$row.$col" . " -${len}c" );
                    ( $row, $col ) = split /\./, $location;
                }
                $line =~ s/^\s*Line \d+ column \d+\s*/$row:$col /;
            }

        } elsif ( $errorchecktype eq "Spell Query" ) {    # Spell query also has a frequency count to append
            my $freq = spellqueryfrequency($line);
            next if $freq > $::spellquerythreshold;       # If it's spelled the same way several times, it's probably not an error
            if ( $line =~ s/\*\*\*$// ) {                 # Spelling flagged as bad word
                $line .= " *$freq*";
            } else {
                $line .= " ($freq)";                      # Ordinary misspelling
            }

        } elsif ( $errorchecktype eq "EPUBCheck" ) {

            # EPUBCheck's error messages each contain the full path of the epub file, maybe plus the path
            # to the relevant HTML file within it, so abbreviate that part of the message.
            # First replace epub filename with "..."
            # Then cut out the unnecessary part of the internal path if it is given
            $line =~ s/^(.+\): ).+\.epub(.+)/$1...$2/;
            $line =~ s/^(.+\): \.\.\.).+(-\d+\.html.+)/$1$2/;
        }

        # All line/column formats now converted to "line:col" - mark the locations in the main window
        if ( $line =~ /^(\d+):(\d+)/ ) {

            # Some tools count lines/columns differently
            my $linnum = $1 + $lineadjust;
            my $colnum = $2 + $columnadjust;
            $colnum = 0 if $colnum < 0;    # Nu CSS errors could end up as column -1
            $line =~ s/^\d+:\d+/${linnum}:${colnum}/;

            # Skip if already have identical error at same location already, since firstly it is not necessary,
            # and secondly it would break logic using errors hash to store references to marks in file.
            next if $errors{$line};

            my $markname = "t" . ++$mark;
            $textwindow->markSet( $markname, "${linnum}.${colnum}" );    # add mark in main text
            $errors{$line} = $markname;                                  # cross-ref error with mark
        } else {
            $errors{$line} = '';
        }
        $countqueries++ unless ignorequery( $errorchecktype, $line );

        # Add all lines to the output, even those without line/column numbers
        push @errorchecklines, $line;
    }
    $fh->close if $fh;
    unlink $errname unless $errorchecktype eq 'Load Checkfile';
    my $size = @errorchecklines;
    if ( ( $errorchecktype eq "W3C Validate CSS" ) and ( $size <= 1 ) ) {    # handle errors file with zero lines
        my $dialog = $top->Dialog(
            -text    => 'Could not validate: install java or use W3C CSS Validation web site.',
            -bitmap  => 'warning',
            -title   => 'Validation failed',
            -buttons => [qw/OK/],
        );
        $dialog->Show;
        ::killpopup('errorcheckpop');
        ::working();
        return;
    }
    push @errorchecklines, "$ENDMSG $errorchecktype" unless $errorchecktype eq 'Load Checkfile';
    if ( $errorchecktype eq "Nu HTML Check" or $errorchecktype eq "Nu XHTML Check" ) {
        push @errorchecklines,
          "Don't forget to do the final validation at https://validator.w3.org";
    }
    if ( $errorchecktype eq "W3C Validate CSS" ) {
        push @errorchecklines,
          "Don't forget to do the final validation at https://jigsaw.w3.org/css-validator";
    }

    ::working();
    if ( $errorchecktype eq 'Bookloupe' ) {
        gcwindowpopulate();    # Also handles query count display since it depends on shown/hidden error types

    } elsif ( $errorchecktype eq "EPUBCheck" ) {

        # EPUBCheck gives very long error lines, so wrap them using the width of the listbox
        # and the width of a character to determine how many characters wide to wrap
        my @splitlines;
        my $INDENT    = 3;
        my $charwidth = $::lglobal{errorchecklistbox}->fontMeasure( 'proofing', 'X' );    # width of a character
        my $wrapwidth = int( $::lglobal{errorchecklistbox}->width / $charwidth );
        for my $line (@errorchecklines) {
            $line = ::wrapper( $INDENT, 0, $wrapwidth, $line, $::rwhyphenspace );
            push @splitlines, split( /\n/, $line );
        }
        $::lglobal{errorchecklistbox}->insert( 'end', @splitlines );
    } else {
        errsortrefresh($errorchecktype);
        eccountupdate($countqueries);
        if ( $errorchecktype eq "Spell Query" ) {
            my $numbadwords    = sqgetnumbadwords();
            my $numbadwordslbl = $numbadwords > 0 ? "*$numbadwords* bad word" : "";
            $numbadwordslbl .= "s" if $numbadwords > 1;
            $::lglobal{sqbadwordcountlbl}->configure( -text => $numbadwordslbl );
        }
    }

    $::lglobal{errorchecklistbox}->update;
    $::lglobal{errorchecklistbox}->focus;
    $::lglobal{errorcheckpop}->raise;
}

#
# Error sort comparison function
sub errsortfunc {

    # Keep first line first, and last line last
    return -1 if $a =~ /^$BEGMSG/ or $b =~ /^$ENDMSG/;
    return 1  if $b =~ /^$BEGMSG/ or $a =~ /^$ENDMSG/;

    # Extract row:col numbers from message
    my $ta = $a;
    $ta =~ s/^(\d+):(\d+) +- //;
    my $alin = $1 // 0;
    my $acol = $2 // 0;
    my $tb   = $b;
    $tb =~ s/^(\d+):(\d+) +- //;
    my $blin = $1 // 0;
    my $bcol = $2 // 0;

    # Compare text of message
    my $cmpstr = 0;                                                     # text ignored if sorting by row:col
    $cmpstr = $ta cmp $tb         if $::lglobal{errsortmode} eq 'a';    # alphabetical
    $cmpstr = lc($ta) cmp lc($tb) if $::lglobal{errsortmode} eq 'i';    # case-insensitive

    return $cmpstr || $alin <=> $blin || $acol <=> $bcol;
}

#
# Refresh the display of errors, sorting it first for Spell Query only
sub errsortrefresh {
    my $errorchecktype = shift;

    # Note: This code assumes that, apart from the beginning and end messages,
    # all messages originally had an entry in the $errors array linking them to the text.
    # If a spelling is "skipped" this is currently flagged by undefining that link,
    # so that spelling is not inserted into the sorted list, which is correct behavior.
    # However, if sorting is implemented for another check type, this assumption may not hold,
    # e.g. if it contains messages that do not begin with "row:col".
    # The code below would omit such messages from the sorted list
    if ( $errorchecktype eq 'Spell Query' ) {
        my @errorchecktemp;
        for my $line (@errorchecklines) {
            push @errorchecktemp, $line if defined $errors{$line} or $line =~ /^($BEGMSG|$ENDMSG)/;
        }
        @errorchecklines = sort errsortfunc @errorchecktemp;
    }

    # Get currently active error, so we can reselect it after refreshing the list
    my $actidx = -1;
    my $active = $::lglobal{errorchecklistbox}->get('active');    # Get text of active error
    if ($active) {
        for my $idx ( 0 .. $#errorchecklines ) {
            if ( $errorchecklines[$idx] eq $active ) {            # Found the error in the resorted list
                $actidx = $idx;
                last;
            }
        }
    }

    $::lglobal{errorchecklistbox}->delete( '0', 'end' );
    for my $line (@errorchecklines) {
        $::lglobal{errorchecklistbox}->insert( 'end', $line );
    }

    # Reactivate/select the previously active error and make it visible in the view
    if ( $actidx >= 0 ) {
        $::lglobal{errorchecklistbox}->activate($actidx);
        $::lglobal{errorchecklistbox}->selectionSet($actidx);
        $::lglobal{errorchecklistbox}->see($actidx);
    }
}

#
# Return if this query message should be ignored
sub ignorequery {
    my $errorchecktype = shift;
    my $query          = shift;

    # All +string: messages indicate query to be resolved by search
    return 0 if $query =~ /^\+.+:/;

    # Don't ignore ppvimage warnings/errors
    return 0 if $errorchecktype eq "ppvimage" and $query =~ /(WARNING|ERROR):/;

    # Ignore any other queries without line:column numbers
    return 1 if $query !~ /^\d+:\d+/;

    # Only some ppvimage queries are ignored at the moment
    return 0 unless $errorchecktype eq "ppvimage";

    # Certain specific ppvimage queries need to be ignored - they are just for information
    if ( $errorchecktype eq "ppvimage" ) {
        return (
                 $query =~ /^\d+:\d+ Image: /
              or $query =~ /^\d+:\d+ natural width=/
              or $query =~ /^\d+:\d+ coded width=/
              or $query =~ /^\d+:\d+ Filesize: +\d+ KB$/
              or $query =~ /^\d+:\d+ Linked image: /
              or $query =~ /^\d+:\d+ NOTE: /
        );
    }
    return 0;    # All other tools' line:column queries need counting
}

#
# Run error checks for given errorcheck type.
# For most checks, the currently loaded file has been saved into a
# temporary file, and any errors will be written to an error file
# to be processed later
sub errorcheckrun {
    my ( $errorchecktype, $tmpfname, $errname ) = @_;
    my $textwindow = $::textwindow;
    my $top        = $::top;
    ::operationadd("$errorchecktype");
    ::hidepagenums();
    if ( $::lglobal{errorcheckpop} ) {
        $::lglobal{errorchecklistbox}->delete( '0', 'end' );
    }
    $textwindow->focus;
    unless ( $errorchecktype eq 'EPUBCheck' ) {    # Checks an epub, not the currently loaded file
        return 1 if ::nofileloadedwarning();
    }

    my $jartypes = [ [ 'JAR file', [ '.jar', ] ], [ 'All Files', ['*'] ], ];
    if ( $errorchecktype eq 'HTML Tidy' ) {
        unless ($::tidycommand) {
            ::locateExecutable( 'HTML Tidy', \$::tidycommand );
            return 1 unless $::tidycommand;
        }
    } elsif ( $errorchecktype eq "Nu HTML Check" or $errorchecktype eq "Nu XHTML Check" ) {
        unless ($::validatecommand) {
            ::locateExecutable( 'Nu HTML Checker (vnu.jar)', \$::validatecommand, $jartypes );
            return 1 unless $::validatecommand;
        }
    } elsif ( $errorchecktype eq 'W3C Validate CSS' ) {
        unless ($::validatecsscommand) {
            ::locateExecutable( 'W3C CSS Validator (css-validate.jar)',
                \$::validatecsscommand, $jartypes );
            return 1 unless $::validatecsscommand;
        }
    } elsif ( $errorchecktype eq 'EPUBCheck' ) {
        unless ($::epubcheckcommand) {
            ::locateExecutable( 'W3C EPUBCheck (epubcheck.jar)', \$::epubcheckcommand, $jartypes );
            return 1 unless $::epubcheckcommand;
        }
    }
    ::savesettings();
    $top->Busy( -recurse => 1 );

    # Bookloupe strips /*, /$ and /#, but doesn't know about newer rewrap types,
    # so strip them all here if they are the only text on the line,
    # or if the open rewrap marker is optionally followed by margins in square brackets
    my $striptext =
      $errorchecktype eq 'Bookloupe'
      ? "^(/[$::allblocktypes](?=[\[\n]))|([$::allblocktypes]/(?=[\n]))"
      : "";

    # For EPUBCheck, instead of saving current file as a temporary file,
    # user chooses an epub file to check
    if ( $errorchecktype eq 'EPUBCheck' ) {
        my $types = [ [ 'Epub Files', ['.epub'] ], [ 'All Files', ['*'] ], ];
        $tmpfname = $::lglobal{errorcheckpop}->getOpenFile(
            -title      => 'File Name?',
            -filetypes  => $types,
            -initialdir => ::getsafelastpath()
        );
        unless ($tmpfname) {
            $top->Unbusy;
            return 1;
        }
    } elsif ( $errorchecktype ne 'Spell Query'
        and $errorchecktype ne 'Unmatched DP Tags'
        and $errorchecktype ne 'Unmatched HTML Tags'
        and $errorchecktype ne 'Unmatched Brackets'
        and $errorchecktype ne 'Unmatched Double Quotes'
        and $errorchecktype ne 'Unmatched Block Markup'
        and $errorchecktype ne 'Illustration Fixup'
        and $errorchecktype ne 'Sidenote Fixup' ) {    # No external tool, so no temp file needed
        savetoerrortmpfile( $tmpfname, $striptext );
    }

    if ( $errorchecktype eq 'HTML Tidy' ) {
        ::run( $::tidycommand, "-f", $errname, "-e", "-utf8", $tmpfname );
    } elsif ( $errorchecktype eq 'Nu HTML Check' or $errorchecktype eq "Nu XHTML Check" ) {
        my $runner = ::runner::tofile( $errname, $errname );    # stdout & stderr
        $runner->run( "java", "-Xss2048k", "-jar", $::validatecommand, "$tmpfname" );
    } elsif ( $errorchecktype eq 'W3C Validate CSS' ) {
        my $runner = ::runner::tofile( $errname, $errname );    # stdout & stderr
        $runner->run( "java", "-jar", $::validatecsscommand, "--profile=$::cssvalidationlevel",
            "file:$tmpfname" );
    } elsif ( $errorchecktype eq 'EPUBCheck' ) {
        my $runner = ::runner::tofile( $errname, $errname );    # stdout & stderr
        $runner->run( "java", "-Xss2048k", "-jar", $::epubcheckcommand, $tmpfname );
    } elsif ( $errorchecktype eq 'pphtml' ) {
        ::run( "perl", "lib/ppvchecks/pphtml.pl", "-i", $tmpfname, "-o", $errname );
    } elsif ( $errorchecktype eq 'Link Check' ) {
        linkcheckrun( $tmpfname, $errname );
    } elsif ( $errorchecktype eq 'ppvimage' ) {
        if ($::verboseerrorchecks) {
            ::run( 'perl', 'tools/ppvimage/ppvimage.pl', '-o', $errname, $tmpfname );
        } else {
            ::run( 'perl', 'tools/ppvimage/ppvimage.pl', '-terse', '-o', $errname, $tmpfname );
        }
    } elsif ( $errorchecktype eq 'pptxt' ) {
        ::run( "perl", "lib/ppvchecks/pptxt.pl", "-i", $tmpfname, "-o", $errname );
    } elsif ( $errorchecktype eq 'Bookloupe' ) {
        booklouperun( $tmpfname, $errname );
    } elsif ( $errorchecktype eq 'Jeebies' ) {
        jeebiesrun( $tmpfname, $errname );
    } elsif ( $errorchecktype eq 'Spell Query' ) {
        spellqueryrun($errname);
    } elsif ( $errorchecktype eq 'Illustration Fixup' or $errorchecktype eq 'Sidenote Fixup' ) {
        illosncheckrun($errname);
    } elsif ( $errorchecktype eq 'Unmatched DP Tags' ) {
        unmatcheddptagsrun($errname);
    } elsif ( $errorchecktype eq 'Unmatched HTML Tags' ) {
        unmatchedhtmltagsrun($errname);
    } elsif ( $errorchecktype eq 'Unmatched Brackets' ) {
        unmatchedbracketsrun($errname);
    } elsif ( $errorchecktype eq 'Unmatched Double Quotes' ) {
        unmatcheddoublequotesrun($errname);
    } elsif ( $errorchecktype eq 'Unmatched Block Markup' ) {
        unmatchedblockrun($errname);
    }
    $top->Unbusy;
    unlink $tmpfname unless $errorchecktype eq 'EPUBCheck';    # Don't delete the epub file
    return 0;
}

#
# Save current file to a temporary file in order to run a check on it
# Second optional argument is regex to match text to be stripped before saving, e.g. rewrap markup
sub savetoerrortmpfile {
    my $tmpfname   = shift;
    my $striptext  = shift;
    my $textwindow = $::textwindow;
    my $top        = $::top;

    open my $td, '>', $tmpfname or die "Could not open $tmpfname for writing. $!";
    my $count   = 0;
    my $index   = '1.0';
    my ($lines) = $textwindow->index('end - 1c') =~ /^(\d+)\./;
    while ( $textwindow->compare( $index, '<', 'end' ) ) {
        my $end     = $textwindow->index("$index  lineend +1c");
        my $gettext = $textwindow->get( $index, $end );
        $gettext =~ s/$striptext//g if $striptext;
        utf8::encode($gettext);
        print $td $gettext;
        $index = $end;
    }
    close $td;
}

#
# Run the link check on an HTML file - parses the HTML file rather than running an external tool
sub linkcheckrun {
    my ( $tempfname, $errname ) = @_;
    my $textwindow = $::textwindow;
    my $top        = $::top;
    open my $logfile, ">", $errname or die "Error opening link check output file: $errname";
    my ( %anchor, %id, %link, %image, %badlink, $length, $upper );
    my ( $anchors, $ids, $ilinks, $elinks, $images, $count, $css ) = ( 0, 0, 0, 0, 0, 0, 0 );
    my @warning = ();

    my $fname = $::lglobal{global_filename};
    if ( $fname =~ /(No File Loaded)/ ) {
        print $logfile "You need to save your file first.";
        return;
    }
    my ( $f, $d, $e ) = ::fileparse( $fname, qr{\.[^\.]*$} );
    my %imagefiles;
    my @ifiles   = ();
    my $imagedir = '';
    push @warning, '';
    my @temp         = split( /[\\\/]/, $textwindow->FileName );
    my $tempfilename = $temp[-1];

    if ( $tempfilename =~ /projectid/i ) {
        print $logfile "Choose a human readable filename: $tempfilename\n";
    }
    if ( $tempfilename =~ /[A-Z]/ ) {
        print $logfile "Use only lower case in filename: $tempfilename\n";
    }
    my $parser = HTML::TokeParser->new($tempfname);
    while ( my $token = $parser->get_token ) {
        if ( $token->[0] eq 'S' and $token->[1] eq 'style' ) {
            $token = $parser->get_token;
            if ( $token->[0] eq 'T' and $token->[2] ) {
                my @urls = $token->[1] =~ m/\burl\(['"](.+?)['"]\)/gs;
                for my $img (@urls) {
                    if ($img) {
                        if ( !$imagedir ) {
                            $imagedir = $img;
                            $imagedir =~ s/\/.*?$/\//;
                            @ifiles = glob( ::dos_path( $d . $imagedir ) . '*.*' );
                            for (@ifiles) { $_ =~ s/\Q$d\E// }
                            for (@ifiles) { $imagefiles{$_} = '' }
                        }
                        $image{$img}++;
                        $upper++ if ( $img ne lc($img) );
                        delete $imagefiles{$img}
                          if ( ( defined $imagefiles{$img} )
                            || ( defined $link{$img} ) );
                        push @warning, "+$img: contains uppercase characters!\n"
                          if ( $img ne lc($img) );
                        push @warning, "+$img: not found!\n"
                          unless ( -e $d . $img );
                        $css++;
                    }
                }
            }
        }
        next unless $token->[0] eq 'S';
        my $url    = $token->[2]{href} || '';
        my $anchor = $token->[2]{name} || '';
        my $img    = $token->[2]{src}  || '';
        my $id     = $token->[2]{id}   || '';
        if ($anchor) {
            $anchor{ '#' . $anchor } = $anchor;
            $anchors++;
        } elsif ($id) {
            $id{ '#' . $id } = $id;
            $ids++;
        }
        if ( $url =~ m/^(#?)(.+)$/ ) {
            $link{ $1 . $2 } = $2;
            $ilinks++ if $1;
            $elinks++ unless $1;
        }
        if ($img) {
            if ( !$imagedir ) {
                $imagedir = $img;
                $imagedir =~ s/\/.*?$/\//;
                @ifiles = glob( $d . $imagedir . '*.*' );
                for (@ifiles) { $_ =~ s/\Q$d\E// }
                for (@ifiles) { $imagefiles{$_} = '' }
            }
            $image{$img}++;
            $upper++ if ( $img ne lc($img) );
            delete $imagefiles{$img}
              if ( ( defined $imagefiles{$img} )
                || ( defined $link{$img} ) );
            push @warning, "+$img: contains uppercase characters!\n"
              if ( $img ne lc($img) );
            push @warning, "+$img: not found!\n"
              unless ( -e $d . $img );
            $images++;
        }
    }
    for ( keys %link ) {
        $badlink{$_} = $_      if ( $_ =~ m/\\|\%5C|\s|\%20/ );
        delete $imagefiles{$_} if ( defined $imagefiles{$_} );
    }
    for ( ::natural_sort_alpha( keys %link ) ) {
        unless ( ( defined $anchor{$_} )
            || ( defined $id{$_} )
            || ( $link{$_} eq $_ ) ) {
            print $logfile "+#$link{$_}: Internal link without anchor\n";
            $count++;
        }
    }
    my $externflag;
    for ( ::natural_sort_alpha( keys %link ) ) {
        if ( $link{$_} eq $_ ) {
            if ( $_ =~ /:\/\// ) {
                print $logfile "+$link{$_}: External link\n";
            } else {
                my $temp = $_;
                $temp =~ s/^([^#]+).*/$1/;
                unless ( -e $d . $temp ) {
                    print $logfile "local file(s) not found!\n"
                      unless $externflag;
                    print $logfile "+$link{$_}:\n";
                    $externflag++;
                }
            }
        }
    }
    for ( ::natural_sort_alpha( keys %badlink ) ) {
        print $logfile "+$badlink{$_}: Link with bad characters\n";
    }
    print $logfile @warning if @warning;
    print $logfile "";
    if ( keys %imagefiles ) {
        for ( ::natural_sort_alpha( keys %imagefiles ) ) {
            print $logfile "+" . $_ . ": File not used!\n"
              if ( $_ =~ /\.(png|jpg|gif|bmp)/ );
        }
        print $logfile "";
    }
    print $logfile "Link statistics:\n";
    print $logfile "$anchors named anchors\n";
    print $logfile "$ids unnamed anchors (tag with id attribute)\n";
    print $logfile "$ilinks internal links\n";
    print $logfile "$images image links\n";
    print $logfile "$css CSS style image links\n";
    print $logfile "$elinks external links\n";
    print $logfile "ANCHORS WITHOUT LINKS. - (INFORMATIONAL)\n";

    for ( ::natural_sort_alpha( keys %anchor ) ) {
        unless ( exists $link{$_} ) {
            print $logfile "$anchor{$_}\n";
            $count++;
        }
    }
    print $logfile "$count  anchors without links\n";
    close $logfile;
}

#
# When user clicks on an error, show and highlight the correct place in the main text window
sub errorcheckview {
    my $errorchecktype = shift;
    my $textwindow     = $::textwindow;
    $textwindow->tagRemove( 'highlight', '1.0', 'end' );
    my $line = $::lglobal{errorchecklistbox}->get('active');
    return if not defined $line;
    if ( $line =~ /^\d+:\d+/ ) {    # normally line and column number of error is shown
        $textwindow->see( $errors{$line} );
        $textwindow->markSet( 'insert', $errors{$line} );

        # Highlight from error to end of line
        my $start = $errors{$line};
        my $end   = $errors{$line} . " lineend";

        # If line:column range is given, highlight the whole thing
        $end = "$1.$2" if $line =~ /^\d+:\d+-(\d+):(\d+)/;

        # Just highlight queried word for Spell Query
        $end = $errors{$line} . "+" . length($1) . "c"
          if $errorchecktype eq "Spell Query" and $line =~ /^\d+:\d+ +- (\S+)/;

        # Ensure at least 1 character is highlighted
        if ( $textwindow->index($start) == $textwindow->index($end) ) {

            # if empty line, select whole line
            if ( $textwindow->index($start) == $textwindow->index( $start . " linestart" ) ) {
                $end = $start . " +1l";
            } else {    # error is at end of non-empty line
                $start .= "- 1c";
            }
        }
        $textwindow->tagAdd( 'highlight', $start, $end );
    } else {    # some tools output error without line number
        if ( $line =~ /^\+(.*):/ ) {    # search on text between + and :
            my @savesets = @::sopt;
            ::searchoptset(qw/0 x x 0/);
            ::searchfromstartifnew($1);
            ::searchtext($1);
            ::searchoptset(@savesets);
            $::top->raise;
        }
    }
    $textwindow->focus;
    $::lglobal{errorcheckpop}->raise;
}

#
# Activate the item under the mouse cursor
sub errorchecksetactive {
    my $xx  = $::lglobal{errorchecklistbox}->pointerx - $::lglobal{errorchecklistbox}->rootx;
    my $yy  = $::lglobal{errorchecklistbox}->pointery - $::lglobal{errorchecklistbox}->rooty;
    my $idx = $::lglobal{errorchecklistbox}->index("\@$xx,$yy");
    $::lglobal{errorchecklistbox}->activate($idx);
}

#
# Remove the active item
sub errorcheckremove {
    my $errorchecktype = shift;

    my $rmvmsg = $::lglobal{errorchecklistbox}->get('active');
    return unless defined $rmvmsg;

    $::textwindow->markUnset( $errors{$rmvmsg} );
    undef $errors{$rmvmsg};
    $::lglobal{errorchecklistbox}->selectionClear( 0, 'end' );
    $::lglobal{errorchecklistbox}->delete('active');
    $::lglobal{errorchecklistbox}->selectionSet('active');

    eccountupdate(-1) unless ignorequery( $errorchecktype, $rmvmsg );    # If deleted line is a query, update the query count
}

#
# Process the active item if possible, making the suggested change to the text
sub errorcheckprocess {
    my $textwindow     = $::textwindow;
    my $errorchecktype = shift;

    my $line = $::lglobal{errorchecklistbox}->get('active');
    return if not defined $errors{$line};

    my ( $begmatch, $endmatch, $match, $replacement );

    # Process the line appropriately for the type
    if ( $errorchecktype eq 'Load Checkfile' ) {
        ( $begmatch, $endmatch, $match, $replacement ) = errorcheckprocesssuggest($line);
    } elsif ( $errorchecktype eq 'Jeebies' ) {
        ( $begmatch, $endmatch, $match, $replacement ) = errorcheckprocessjeebies($line);
    } else {
        return;
    }

    return unless $begmatch;

    # Check match string is still in text before replacing it (might have already been corrected)
    my $matchstr = $textwindow->get( $begmatch, $endmatch );
    if ( $matchstr ne $match ) {
        ::soundbell();
        return;
    }

    $textwindow->addGlobStart;
    $textwindow->insert( $endmatch, $replacement );    # Append so new text ends up after mark
    $textwindow->delete( $begmatch, $endmatch );       # Then delete old text
    $textwindow->addGlobEnd;
}

#
# Process "Suggest 'X' for 'Y'" by replacing string 'Y' with string 'X'
# Originally added for OCRfixr tool which was trialled but not continued.
# Would work for any future tool that outputs a file with the correct
# format for suggested edits, e.g. "123:27 Suggest 'dog' for 'cat'"
# File would then be loaded using Load Checkfile
sub errorcheckprocesssuggest {
    my $line = shift;
    my ( $begmatch, $endmatch, $match, $replacement );
    if ( $line =~ /^\d+:\d+ +Suggest '(.+)' for '(.+)'/ ) {
        $replacement = $1;
        $match       = $2;

        $begmatch = $errors{$line};
        $endmatch = $errors{$line} . "+" . length($match) . "c";
    }
    return ( $begmatch, $endmatch, $match, $replacement );
}

#
# Process Jeebies output 'Query phrase "xxx he/be xxx' by swapping  he/be
sub errorcheckprocessjeebies {
    my $line = shift;
    my ( $begmatch, $endmatch, $match, $replacement );
    if ( $line =~ /^\d+:\d+ +- Query phrase ".*\b([HhBb]e)\b.*"/ ) {
        $match       = $1;
        $replacement = "be" if $match eq "he";
        $replacement = "he" if $match eq "be";
        $replacement = "Be" if $match eq "He";
        $replacement = "He" if $match eq "Be";

        # find first he/be as a whole word from the marked location
        $begmatch = $::textwindow->search( '-regexp', '--', '\b' . $match . '\b',
            $errors{$line}, $errors{$line} . "+1l" );
        $endmatch = $begmatch . "+" . length($match) . "c" if $begmatch;
    }
    return ( $begmatch, $endmatch, $match, $replacement );
}

#
# Process Spell Query output by adding queried word to either the
# project or global dictionary based on argument
sub errorcheckprocessspell {
    my $dictionary = shift;
    my $line       = $::lglobal{errorchecklistbox}->get('active');
    return                               if not defined $errors{$line};
    spellqueryadddict( $1, $dictionary ) if $line =~ /^\d+:\d+ +- ([^ ]+)/;
}

#
# Remove the active item and similar items
sub errorcheckremovesimilar {
    my $textwindow     = $::textwindow;
    my $errorchecktype = shift;
    my $line           = $::lglobal{errorchecklistbox}->get('active');
    return unless defined $line;
    return unless defined $errors{$line} and $line =~ s/^\d+:\d+ +(.+)/$1/;

    # Reverse through list deleting lines that are identical to the chosen one apart from line:column
    my $index = $::lglobal{errorchecklistbox}->size();
    while ( $index > 0 ) {
        $index--;
        my $rmvmsg = $::lglobal{errorchecklistbox}->get($index);
        next unless $rmvmsg =~ /^\d+:\d+ +\Q$line\E$/;    # Quote $line in case it contains regex special characters

        $::textwindow->markUnset( $errors{$rmvmsg} );
        undef $errors{$rmvmsg};
        $::lglobal{errorchecklistbox}->delete($index);

        eccountupdate(-1) unless ignorequery( $errorchecktype, $rmvmsg );    # If deleted line is a query, update the query count
    }
    $::lglobal{errorchecklistbox}->selectionClear( 0, 'end' );
    $::lglobal{errorchecklistbox}->selectionSet('active');
}

#
# Copy list of errors to the copy/paste buffer
sub errorcheckcopy {
    my $textwindow = $::textwindow;
    my @elements   = $::lglobal{errorchecklistbox}->get( 0, 'end' );
    $textwindow->clipboardClear;
    for my $line (@elements) {
        $textwindow->clipboardAppend( $line . "\n" );
    }
}

#
# Special population of errorcheck window is needed for bookloupe
# because it has its own options for which types of error to show/hide
sub gcwindowpopulate {
    return unless defined $::lglobal{errorcheckpop};
    my $headr = 0;
    my $error = 0;
    $::lglobal{errorchecklistbox}->delete( '0', 'end' );
    foreach my $line (@errorchecklines) {
        next if $line =~ /^\s*$/;    # Skip blank lines
        next unless defined $errors{$line};

        # Check if error type has been hidden
        my $flag = 0;
        for ( 0 .. $#{ $::lglobal{gcarray} } ) {
            next unless ( index( $line, $::lglobal{gcarray}->[$_] ) > 0 );
            $::gsopt[$_] = 0 unless defined $::gsopt[$_];
            $flag = 1 if $::gsopt[$_];
            last;
        }
        next if $flag;

        # Increment count of either header lines or non-hidden error lines
        ( $line =~ /^\s*-->/ or $line =~ /^\s*\*\*\*/ ) ? $headr++ : $error++;
        $::lglobal{errorchecklistbox}->insert( 'end', $line );
    }
    eccountupdate($error);

    # Tell user how many error types are hidden
    my $hidden = 0;
    $hidden += ( $::gsopt[$_] ? 1 : 0 ) for ( 0 .. $#{ $::lglobal{gcarray} } );
    if ( $hidden > 0 ) {
        my $hidtxt = "  --> $hidden error " . ( $hidden > 1 ? "types" : "type" ) . " hidden.";
        $::lglobal{errorchecklistbox}->insert( $headr, '', $hidtxt, '' );
    }

    # Add start/end messages
    $::lglobal{errorchecklistbox}->insert( 0,     "$BEGMSG Bookloupe" );
    $::lglobal{errorchecklistbox}->insert( "end", "$ENDMSG Bookloupe" );
    $::lglobal{errorchecklistbox}->update;
}

#
# Pop the bookloupe view options window, allowing user to show/hide error types
sub gcviewopts {
    my $top = $::top;
    my @gsoptions;
    my $gcrows = int( ( @{ $::lglobal{gcarray} } / 3 ) + .9 );
    if ( defined( $::lglobal{gcviewoptspop} ) ) {
        $::lglobal{gcviewoptspop}->deiconify;
        $::lglobal{gcviewoptspop}->raise;
        $::lglobal{gcviewoptspop}->focus;
    } else {
        $::lglobal{gcviewoptspop} = $top->Toplevel;
        $::lglobal{gcviewoptspop}->title('Bookloupe View Options');
        my $pframe = $::lglobal{gcviewoptspop}->Frame->pack;
        $pframe->Label( -text => 'Select option to hide that error.', )->pack;
        my $pframe1 = $::lglobal{gcviewoptspop}->Frame->pack;
        my ( $gcrow, $gccol );
        for ( 0 .. $#{ $::lglobal{gcarray} } ) {
            $gccol         = int( $_ / $gcrows );
            $gcrow         = $_ % $gcrows;
            $::gsopt[$_]   = 0 unless defined $::gsopt[$_];
            $gsoptions[$_] = $pframe1->Checkbutton(
                -variable => \$::gsopt[$_],
                -command  => sub { gcwindowpopulate(); },
                -text     => $::lglobal{gcarray}->[$_],
            )->grid( -row => $gcrow, -column => $gccol, -sticky => 'nw' );
        }
        my $pframe2 = $::lglobal{gcviewoptspop}->Frame->pack;
        $pframe2->Button(
            -command => sub {
                for ( 0 .. $#gsoptions ) {
                    $gsoptions[$_]->select;
                }
                gcwindowpopulate();
            },
            -text  => 'Hide All',
            -width => 14
        )->pack(
            -side   => 'left',
            -pady   => 10,
            -padx   => 2,
            -anchor => 'n'
        );
        $pframe2->Button(
            -command => sub {
                for ( 0 .. $#gsoptions ) {
                    $gsoptions[$_]->deselect;
                }
                gcwindowpopulate();
            },
            -text  => 'See All',
            -width => 14
        )->pack(
            -side   => 'left',
            -pady   => 10,
            -padx   => 2,
            -anchor => 'n'
        );
        my $mainlang = ::main_lang();
        if ( $mainlang !~ /^en/ && @::gcviewlang ) {
            $pframe2->Button(
                -command => sub {
                    for ( 0 .. $#::gcviewlang ) {
                        if ( $::gcviewlang[$_] ) {
                            $gsoptions[$_]->select;
                        } else {
                            $gsoptions[$_]->deselect;
                        }
                    }
                    gcwindowpopulate();
                },
                -text  => "Load View: '$mainlang'",
                -width => 14
            )->pack(
                -side   => 'left',
                -pady   => 10,
                -padx   => 2,
                -anchor => 'n'
            );
        } else {
            $pframe2->Button(
                -command => sub {
                    for ( 0 .. $#gsoptions ) {
                        $gsoptions[$_]->toggle;
                    }
                    gcwindowpopulate();
                },
                -text  => 'Toggle View',
                -width => 14
            )->pack(
                -side   => 'left',
                -pady   => 10,
                -padx   => 2,
                -anchor => 'n'
            );
        }
        $pframe2->Button(
            -command => sub {
                for ( 0 .. $#::mygcview ) {
                    if ( $::mygcview[$_] ) {
                        $gsoptions[$_]->select;
                    } else {
                        $gsoptions[$_]->deselect;
                    }
                }
                gcwindowpopulate();
            },
            -text  => 'Load Defaults',
            -width => 14
        )->pack(
            -side   => 'left',
            -pady   => 10,
            -padx   => 2,
            -anchor => 'n'
        );
        $pframe2->Button(
            -command => sub {
                for ( 0 .. $#::gsopt ) {
                    $::mygcview[$_] = $::gsopt[$_];
                }
                ::savesettings();
            },
            -text  => 'Save As Defaults',
            -width => 14
        )->pack(
            -side   => 'left',
            -pady   => 10,
            -padx   => 2,
            -anchor => 'n'
        );
        $::lglobal{gcviewoptspop}->resizable( 'no', 'no' );
        ::initialize_popup_without_deletebinding('gcviewoptspop');
        $::lglobal{gcviewoptspop}->protocol(
            'WM_DELETE_WINDOW' => sub {
                ::killpopup('gcviewoptspop');
                unlink 'gutreslts.tmp';
            }
        );
    }
}

#
# Run the jeebies tool
sub jeebiesrun {
    my ( $tempfname, $errname ) = @_;

    unless ($::jeebiescommand) {
        ::locateExecutable( 'Jeebies', \$::jeebiescommand );
        return unless $::jeebiescommand;
    }
    $::jeebiescommand = ::os_normal($::jeebiescommand);

    # Pass paranoia level as an option to jeebies
    my $jeebiesoptions = "-$::jeebiesmode" . 'e';
    my $runner         = runner::tofile($errname);
    $runner->run( $::jeebiescommand, $jeebiesoptions, $tempfname );

}

## Run bookloupe
sub booklouperun {
    my ( $tempfname, $errname ) = @_;
    ::operationadd('Bookloupe');

    unless ($::gutcommand) {
        ::locateExecutable( 'Bookloupe', \$::gutcommand );
        return unless $::gutcommand;
    }
    $::gutcommand = ::os_normal($::gutcommand);

    # Run bookloupe with standard options
    # e - echo queried line. y - puts errors to stdout instead of stderr.
    # v - list EVERYTHING!.  d -  ignore DP style page separators.
    my $runner = ::runner::tofile($errname);
    $runner->run( $::gutcommand, '-eyvd', $tempfname );
}

#
# Block to make Spell Query dictionary hash local & persistent
{
    my %sqglobaldict      = ();
    my %sqbadspellingfreq = ();
    my %sqbadwordcount    = ();

    # Codes returned by spellquerywordok()
    my $SQWORDOKYES = 0;    # Word in dictionary, or meets other criteria for being OK
    my $SQWORDOKNO  = 1;    # Typically a spelling error
    my $SQWORDOKBAD = 2;    # Actual "bad word" - maybe an OK word, but bad in this project - needs marking specially

    #
    # Run Spell Query on whole file
    sub spellqueryrun {
        my $errname    = shift;
        my $textwindow = $::textwindow;

        return unless spellqueryinitialize();
        spellqueryclearcounts();

        open my $logfile, ">", $errname or die "Error opening Spell Query output file: $errname";

        my ( $lastline, $lastcol ) = split( /\./, $textwindow->index('end') );

        my $step = 1;
        while ( $step <= $lastline ) {
            my $line    = $textwindow->get( "$step.0", "$step.end" );
            my $col     = 0;
            my $nextcol = 0;

            # Replace all non-alphanumeric (but not apostrophes) with space
            $line =~ s/[^\p{Alnum}\p{Mark}'$APOS]/ /g;

            # Check each word individually
            my @words = split( /\s/, $line );    # Split on single spaces to aid column counting
            for my $wd (@words) {

                # Get column of word start (at top of loop otherwise "next" skips over it)
                $col     = $nextcol;
                $nextcol = $col + length($wd) + 1;    # Step forward word length plus single space

                next unless $wd;                      # Empty word if two consecutive separators, e.g. period & space
                my $wordok = spellquerywordok($wd);
                next if $wordok == $SQWORDOKYES;

                # If word has leading straight apostrophe, it might be open single quote; trim it and check again
                if ( $wd =~ s/^'// ) {
                    ++$col;                           # Allow for having removed apostrophe from start of word
                    $wordok = spellquerywordok($wd);
                    next if $wordok == $SQWORDOKYES;
                }

                # if trailing straight/curly apostrophe, it might be close single quote; trim it and check again
                if ( $wd =~ s/['$APOS]$//g ) {
                    $wordok = spellquerywordok($wd);
                    next if $wordok == $SQWORDOKYES;
                }
                next if $wd =~ /^['$APOS]*$/;    # OK if nothing left in string but zero or more quotes

                # Format message - increment word frequency; final total gets appended later when populating dialog
                $sqbadspellingfreq{$wd}++;
                my $badwd = $wordok == $SQWORDOKBAD ? "***" : "";    # Flag bad word to higher routine with asterisks
                $sqbadwordcount{$wd}++ if $badwd;
                my $error = sprintf( "%d:%-2d - %s%s", $step, $col, $wd, $badwd );
                utf8::encode($error);
                print $logfile "$error\n";
            }
            $step++;
        }
        close $logfile;
    }

    #
    # Return true if word from Word Frequency list is OK
    # Word may contain non-word characters (e.g. hyphen ) - OK if all the parts are OK
    sub spellquerywfwordok {
        my $wfword = shift;

        for my $wd ( split( /\W/, $wfword ) ) {
            return 0 unless spellquerywordok($wd) == $SQWORDOKYES;    # part not found
        }
        return 1;                                                     # all parts ok
    }

    #
    # Return true if word is OK, e.g. in dictionary or meets some other criterion
    sub spellquerywordok {
        my $wd = shift;

        # Return status code if whole thing is a bad word or in the dictionary
        my $wordok = spellqueryindictapos($wd);
        return $wordok
          if $wordok == $SQWORDOKBAD
          or $wordok == $SQWORDOKYES;

        # Some languages use l', quest', etc., before word - accept if the "prefix" and the main word are both good
        # Prefix can be with or without apostrophe ("with" is safer to avoid prefix being accepted if standalone word)
        return $SQWORDOKYES
          if $wd =~ /^(\w+)['$APOS](\w+)/
          and (spellqueryindictapos($1) == $SQWORDOKYES
            or spellqueryindictapos( $1 . "'" ) == $SQWORDOKYES )
          and spellqueryindictapos($2) == $SQWORDOKYES;

        # Now check numbers
        return $SQWORDOKYES if $wd =~ /^\d+$/;                  # word is all digits
        return $SQWORDOKYES if $wd =~ /^(\d*[02-9])?1st$/i;     # ...1st, ...21st, ...31st, etc
        return $SQWORDOKYES if $wd =~ /^(\d*[02-9])?2n?d$/i;    # ...2nd, ...22nd, ...32nd, etc (also 2d, 22d, etc)
        return $SQWORDOKYES if $wd =~ /^(\d*[02-9])?3r?d$/i;    # ...3rd, ...23rd, ...33rd, etc (also 3d, 33d, etc)
        return $SQWORDOKYES if $wd =~ /^\d*[04-9]th$/i;         # ...0th, ...4th, ...5th, etc
        return $SQWORDOKYES if $wd =~ /^\d*1[123]th$/i;         # ...11th, ...12th, ...13th

        # Allow decades/years
        return $SQWORDOKYES if $wd =~ /^['$APOS]?\d\ds$/;       # e.g. '20s or 20s (abbreviation for 1820s)
        return $SQWORDOKYES if $wd =~ /^['$APOS]\d\d$/;         # e.g. '62 (abbreviation for 1862)
        return $SQWORDOKYES if $wd =~ /^1\d{3}s$/;              # e.g. 1820s

        # Allow abbreviations for shillings and pence (not pounds because 20l is common scanno for the number 201)
        return $SQWORDOKYES if $wd =~ /^\d{1,2}[sd]$/;          # e.g. 15s or 6d (up to 2 digits of old English shillings and pence)

        return $SQWORDOKYES if $wd =~ /^sc$/i;                  # <sc> DP markup

        return $SQWORDOKNO;
    }

    #
    # Return true if a word is in the dictionary, allowing swap of straight/curly apostrophes
    sub spellqueryindictapos {
        my $wd = shift;

        my $wordok = spellqueryindict($wd);

        # Return status code if it's a bad word, in the dictionary or doesn't contain apostrophes
        return $wordok
          if $wordok == $SQWORDOKBAD
          or $wordok == $SQWORDOKYES
          or $wd !~ /['$APOS]/;

        # Contains apostrophes - try swapping straight/curly and recheck
        if ( $wd =~ /$APOS/ ) {
            $wd =~ s/$APOS/'/g;
        } elsif ( $wd =~ /'/ ) {
            $wd =~ s/'/$APOS/g;
        }
        return spellqueryindict($wd);
    }

    #
    # Return whether word is in the bad_words list, dictionary, or neither (wrong spelling)
    # Check same case, lower case, or title case (e.g. LONDON matches London)
    # Can't just do case-insensitive check because we don't want "london" to be OK.
    sub spellqueryindict {
        my $wd   = shift;
        my $lcwd = lc $wd;
        my $tcwd = length($wd) > 1 ? substr( $wd, 0, 1 ) . substr( $lcwd, 1 ) : '';
        $tcwd = '' if $tcwd eq $lcwd;    # No point in checking same word twice

        # First ensure bad words are always reported
        return $SQWORDOKBAD if exists( $::projectbadwords{$wd} );
        return $SQWORDOKBAD if exists( $::projectbadwords{$lcwd} );
        return $SQWORDOKBAD if $tcwd and exists( $::projectbadwords{$tcwd} );

        # Now check dictionary for good words
        return $SQWORDOKYES if $sqglobaldict{$wd};
        return $SQWORDOKYES if $sqglobaldict{$lcwd};
        return $SQWORDOKYES if $tcwd and $sqglobaldict{$tcwd};

        return $SQWORDOKNO;
    }

    #
    # Load the Spell Query default global dictionary and optional user global and project dictionaries
    # Dictionary hash will have been cleared if new project loaded or language changed
    # Return true on success
    sub spellqueryinitialize {

        return 1 if %sqglobaldict;    # Don't reload dictionaries if already loaded

        # Load dictionaries for current languages
        for my $lang ( ::list_lang() ) {

            # Load default and user global dictionaries for this language
            my $dictloaded = 0;
            for my $dictname ( ::path_defaultdict($lang), ::path_userdict($lang) ) {
                if ( -f $dictname ) {
                    return 0 unless spellqueryloadglobaldict($dictname);
                    $dictloaded = 1;
                }
            }

            # Either the default or user dictionary must exist for each language
            unless ($dictloaded) {
                ::warnerror("No Spell Query dictionary found for language '$lang'");
                return 0;
            }
        }

        # Now add project dictionary words
        delete $::projectdict{$_}     for keys %::projectdict;       # Old spellcheck code doesn't clear hash in spellloadprojectdict()
        delete $::projectbadwords{$_} for keys %::projectbadwords;
        ::spellloadprojectdict();
        $sqglobaldict{$_} = 1 for keys %::projectdict;

        return 1;
    }

    #
    # Add global dictionary into spell query dict hash
    # File format is one word per line
    # Return true on success
    sub spellqueryloadglobaldict {
        my $dictname = shift;
        my $fh;
        unless ( open $fh, "<", $dictname ) {
            ::warnerror("Error opening Spell Query dictionary: $dictname");
            return 0;
        }

        while ( my $line = <$fh> ) {
            utf8::decode($line);
            $line =~ s/^\s+|\s+$//g;    # Trim leading/trailing space
            $sqglobaldict{$line} = 1;
        }
        close $fh;
    }

    #
    # Add word to project/global dictionary depending on second argument
    sub spellqueryadddict {
        my $word       = shift;
        my $dictionary = shift;

        $sqglobaldict{$word} = 1;    # Mark as OK in dictionary hash

        if ( $dictionary eq 'project' ) {
            ::spellmyaddword($word);
        } else {
            my $dictname = ::path_userdict();
            my $fh;
            unless ( open $fh, ">>:encoding(utf8)", $dictname ) {
                ::warnerror("Error opening Spell Query dictionary to add word: $dictname");
                return 0;
            }
            print $fh "$word\n";
            close $fh;
        }
    }

    #
    # Return how many times bad word referred to in error message was found during the check
    sub spellqueryfrequency {
        my $line = shift;
        return $sqbadspellingfreq{$1} if $line =~ /^\d+:\d+ +- ([^*]+)/;    # Ignore asterisks marking bad words
        return 0;
    }

    #
    # Clear the spell query dictionary
    sub spellquerycleardict {
        delete $sqglobaldict{$_} for keys %sqglobaldict;
    }

    #
    # Clear the spell query frequency counts
    sub spellqueryclearcounts {
        delete $sqbadspellingfreq{$_} for keys %sqbadspellingfreq;
        delete $sqbadwordcount{$_}    for keys %sqbadwordcount;
    }

    #
    # Get number of bad words used in file
    sub sqgetnumbadwords {
        my $numbadwords = 0;
        for my $key ( keys %sqbadwordcount ) {
            $numbadwords += $sqbadwordcount{$key};
        }
        return $numbadwords;
    }
}    # end of variable-enclosing block

#
# Check that all relevant opening items have a matching close item
# and vice versa
# Input arguments are error output filename, regex to match open/close items,
# and subroutine references to get match string, and whether to skip item.
sub unmatcheditemsrun {
    my $errname    = shift;           # output filename
    my $regexp     = shift;           # regex that matches open or close item, enclosed in grouping parentheses
    my $rsubmatch  = shift;           # subroutine that will convert open to close & vice versa
    my $nestreg    = shift;           # regex to match tags that can nest - undef matches nothing
    my $rsubskip   = shift;           # optional subroutine that will return whether to skip item
    my $textwindow = $::textwindow;

    open my $logfile, ">", $errname or die "Error opening Unmatched Items output file: $errname";

    # Find each start/end tag in order from beginning to end
    my $start = '1.0';
    my $len;
    while ( my $index =
        $textwindow->search( '-regexp', '-count', \$len, '--', $regexp, $start, 'end' ) ) {
        my $endidx = "$index + $len c";
        my $item   = $textwindow->get( $index, $endidx );

        unless ( $rsubskip and &$rsubskip($item) ) {    # May skip certain elements
            my ( $matchstr, $reverse ) = &$rsubmatch($item);
            if ($matchstr) {                            # Should always be true, since we're only passing valid items to matching subroutine
                my $nest = ( defined $nestreg and $item =~ $nestreg );
                my $matchidx =
                  ::hilitematchfind( $index, $endidx, $item, $matchstr, $reverse, $nest );
                unless ($matchidx) {                    # Failed to find a match
                    my ( $row, $col ) = split( /\./, $index );
                    my $error = sprintf( "%d:%d - %s not matched", $row, $col, $item );
                    utf8::encode($error);
                    print $logfile "$error\n";
                }
            }
        }
        $start = $endidx;
    }
    close $logfile;
}

#
# Check that all relevant DP tags have a matching pair
# Skips thought breaks and does not allow nesting
sub unmatcheddptagsrun {
    my $errname = shift;
    my $TAGCH   = "[a-z]";    # Permissible characters in tag name
    unmatcheditemsrun( $errname, "<$TAGCH+|</$TAGCH+", \&::hilitematchtag, undef,
        \&::hilitematchtb );
}

#
# Check that all relevant HTML tags have a matching pair
# Skips void elements
# Allows all tags to be nested - don't use empty regex to match all, since special meaning in Perl
sub unmatchedhtmltagsrun {
    my $errname = shift;
    my $TAGCH   = "[a-z0-9]";    # Permissible characters in tag name
    unmatcheditemsrun( $errname, "<$TAGCH+|</$TAGCH+", \&::hilitematchtag, ".",
        \&::hilitematchvoid );
}

#
# Check that all brackets have matching pair (no nesting)
sub unmatchedbracketsrun {
    my $errname = shift;
    unmatcheditemsrun( $errname, "[][)(}{]", \&::hilitematchpair );
}

#
# Check that all curly double quotes have matching pair (no nesting)
sub unmatcheddoublequotesrun {
    my $errname = shift;
    unmatcheditemsrun( $errname, "[\x{201c}\x{201d}]", \&::hilitematchpair );
}

#
# Check that all block markups have matching pair (/# may be nested)
sub unmatchedblockrun {
    my $errname = shift;
    unmatcheditemsrun( $errname, "^(/[$::allblocktypes]|[$::allblocktypes]/)\$",
        \&::hilitematchblock, "^(/#|#/)\$" );
}

#
# Block to make Illustration/Sidenote Fixup globals local & persistent
{
    my $ILLOSNSTARTREG        = "^\\*?\\[";
    my $ILLOSNENDREG          = "]\$";
    my $ILLOSNSTARTGENERIC    = "[";
    my $ILLOSNSTARTMARKPREFIX = "illosnstart";
    my $ILLOSNENDMARKPREFIX   = "illosnend";
    my $ILLOSNERROROK         = 0;
    my $ILLOSNERRORUNCLOSED   = 1;
    my $ILLOSNERRORMIDPARA    = 2;
    my $PAGEBREAKREGEX        = "^-----File";
    my %illosnerrortypes      = (
        $ILLOSNERROROK       => "",
        $ILLOSNERRORUNCLOSED => "(UNCLOSED)",
        $ILLOSNERRORMIDPARA  => "(MIDPARAGRAPH)"
    );

    # Global array of hashes storing markup information. Each element stores
    #    start => name of mark at start of illo/sn markup
    #    end => name of mark at end of illo/sn markup
    #    error => markup error
    my @illosnlist;

    # Find and mark all illos/sidenotes and write summary to logfile
    sub illosncheckrun {
        my $errname    = shift;
        my $textwindow = $::textwindow;

        @illosnlist = ();    # Clear global array of illo/sidenote markup information

        my $checktype = errorcheckgettype();
        my $startreg  = illosnstartreg();

        # Find and mark start of each illo/sidenote markup
        my $start     = '1.0';
        my $illosnnum = 0;
        while ( my $illosnstart = $textwindow->search( '-regexp', '--', $startreg, $start, 'end' ) )
        {
            push @illosnlist,
              { start => "$ILLOSNSTARTMARKPREFIX$illosnnum", error => $ILLOSNERROROK };
            $textwindow->markSet( $illosnlist[$illosnnum]{start}, $illosnstart );
            $start = $illosnstart . '+1c';
            $illosnnum++;
        }

        # Find and mark end of each illo/sidenote markup, and begin to check for validity
        # "Unclosed" if no end markup, or end is not before next start, or end is not before next page break
        for $illosnnum ( 0 .. $#illosnlist ) {
            my $illosn = $illosnlist[$illosnnum];
            my $nextstart =
              $illosnnum < $#illosnlist ? $illosnlist[ $illosnnum + 1 ]{start} : 'end';
            my $illosnend = $textwindow->search( '-regexp', '--', $ILLOSNENDREG,
                $illosn->{start} . '+1c', $nextstart );
            $illosnend .= ' lineend' if $illosnend;    # End is after closing bracket
            my $nextpage = $textwindow->search( '-regexp', '--', $PAGEBREAKREGEX,
                $illosn->{start} . '+1c', $nextstart );
            $nextpage = 'end' unless $nextpage;
            $illosn->{error} = $ILLOSNERRORUNCLOSED
              unless $illosnend and $textwindow->compare( $illosnend, '<', $nextpage );
            $illosn->{end} = "$ILLOSNENDMARKPREFIX$illosnnum";
            $textwindow->markSet( $illosn->{end}, $illosnend // $nextstart );

            # If "[Illustration/Sidenote" is preceded by an asterisk it's a mid-paragraph illo/sidenote
            $illosn->{error} = $ILLOSNERRORMIDPARA
              if $textwindow->get( $illosn->{start}, "$illosn->{start} + 1c" ) eq "*";

            # If illo/sidenote is closed OK, check if it is mid-paragraph
            $illosn->{error} = $ILLOSNERRORMIDPARA
              if $illosn->{error} == $ILLOSNERROROK
              and isillosnmidpara($illosn);
        }

        open my $logfile, ">", $errname
          or die "Error opening $checktype output file: $errname";
        for my $illosn (@illosnlist) {
            my $startindex = $textwindow->index( $illosn->{start} );
            my $endindex   = $textwindow->index( $illosn->{end} );
            my $caption    = $textwindow->get( $startindex, "$startindex lineend" );
            $caption    =~ s/$startreg:? *//;
            $caption    =~ s/$ILLOSNENDREG//;
            $startindex =~ s/\./:/;
            $endindex   =~ s/\./:/;
            my $error = "$startindex-$endindex$illosnerrortypes{$illosn->{error}} $caption";
            utf8::encode($error);
            print $logfile "$error\n";
        }
        close $logfile;
    }

    #
    # Process the active illo/sidenote by moving it forward or backward to a suitable location
    sub errorcheckprocessillosn {
        my $direction  = shift;
        my $textwindow = $::textwindow;

        my $line = $::lglobal{errorchecklistbox}->get('active');
        return if not defined $line or not defined $errors{$line};

        my $activeline = $::lglobal{errorchecklistbox}->index('active');
        my $illosnnum  = $activeline - 1;                                  # Allow for header line
        return unless $illosnnum >= 0 and $illosnnum <= $#illosnlist;
        my $illosn = $illosnlist[$illosnnum];

        # If illo/sidenote is unclosed, we can't fix it automatically
        if ( $illosn->{error} == $ILLOSNERRORUNCLOSED ) {
            ::soundbell();
            return;
        }

        # Find suitable place forward or backward to move illo/sidenote to
        my $startingpoint = $direction eq 'forward' ? $illosn->{end} : $illosn->{start};
        my $insertpoint   = findparabreak( $startingpoint, $direction );
        $textwindow->markSet( 'insertpointmark', $insertpoint );
        $textwindow->markGravity( 'insertpointmark', 'left' );    # So illo/sidenote gets inserted after mark

        # If new position doesn't move the illo/sidenote, then nothing left to do
        my $comparepoint =
          ( $direction eq 'forward' ? "$illosn->{end} +1l" : "$illosn->{start} -1l" );
        if ( $textwindow->compare( $insertpoint, '==', $comparepoint ) ) {
            ::soundbell();
            return;
        }

        $textwindow->addGlobStart;
        my $end        = $illosn->{end} . '+1l linestart';
        my $illosntext = $textwindow->get( $illosn->{start}, $end );

        # If illo/sidenote is mid-paragraph and it has a blank line after it, that should be deleted
        if (    $illosn->{error} == $ILLOSNERRORMIDPARA
            and $textwindow->get( $end, "$end lineend" ) eq "" ) {
            $end .= '+1l';
        }
        $textwindow->delete( $illosn->{start}, $end );

        # Use system bookmarks to aid user jumping between old & new locations
        # illosnold - original position of illo/sidenote currently worked on
        # illosnnew - new position of illo/sidenote after latest move
        if ( not $::lglobal{illosncachestartmark}
            or $::lglobal{illosncachestartmark} ne $illosn->{start} ) {
            $::lglobal{illosncachestartmark} = $illosn->{start};
            ::setbookmarksystem( 'illosnold', $::lglobal{illosncachestartmark} );
        }

        # If illo/sidenote has a blank line before it, we also want to delete the blank line
        my $prevline = "$illosn->{start} -1l";
        $textwindow->delete( "$prevline linestart", )
          unless $textwindow->get( "$prevline linestart", "$prevline lineend" );

        $illosntext =~ s/^\*//;    # Remove any leading asterisk
        $textwindow->insert( 'insertpointmark', "\n$illosntext" );
        $textwindow->addGlobEnd;

        errorcheckillosnupdateneeded();
    }

    #
    # Given an index and direction, finds closest blank line suitable for
    # illo/sidenote to be moved to
    # Skips over page markers & Blank Page markup
    # Stops if it reaches illo/sidenote markup
    sub findparabreak {
        my $textwindow     = $::textwindow;
        my $step           = $textwindow->index(shift);
        my $direction      = shift;
        my $incr           = 1;
        my $comparison     = '<';
        my $endpoint       = 'end';
        my $startillosnreg = illosnstartreg();
        my $endillosnreg   = $ILLOSNENDREG;
        my $startblockreg  = quotemeta('/*');
        my $endblockreg    = quotemeta('*/');

        if ( $direction eq 'backward' ) {
            $incr           = -1;
            $comparison     = '>';
            $endpoint       = '1.0';
            $startillosnreg = $ILLOSNENDREG;
            $endillosnreg   = illosnstartreg();
            $startblockreg  = quotemeta('*/');
            $endblockreg    = quotemeta('/*');
        }
        $step =~ s/\..+//;

        $step += $incr;    # Skip potential blank line that precedes/follows the illo/sidenote
        while ( $textwindow->compare( "$step.0", $comparison, $endpoint ) ) {
            $step += $incr;
            my $line = $textwindow->get( "$step.0", "$step.0 lineend" );
            next if $line =~ /$PAGEBREAKREGEX/;
            next if $line =~ /^\[Blank Page\]/i;

            # If we hit another illo/sidenote, stop - we don't want to swap order
            if ( $line =~ /$startillosnreg/ ) {

                # If moving backward, supposed end of illo/sidenote could be end of footnote, etc.
                # so make sure it's really an illo/sidenote
                my $isillosn = 1;
                if ( $direction eq 'backward' ) {
                    my $startindex = $textwindow->search( '-backwards', '--', $ILLOSNSTARTGENERIC,
                        "$step.0 lineend", '1.0' );
                    $startindex = '1.0' unless $startindex;
                    $isillosn   = 0
                      if $textwindow->get( $startindex, "$startindex lineend" ) !~ /$endillosnreg/;
                }

                if ($isillosn) {
                    $step -= $incr;
                    return "$step.0";
                }
            }

            # If we hit /*...*/ markup, step over it
            if ( $line =~ /$startblockreg/ ) {
                while ( $textwindow->compare( "$step.0", $comparison, $endpoint )
                    and $textwindow->get( "$step.0", "$step.0 lineend" ) !~ /$endblockreg/ ) {
                    $step += $incr;
                }
            }

            # Found blank line - skip past any multiple blank lines
            if ( length($line) == 0 ) {
                $step += $incr;
                while ( $textwindow->compare( "$step.0", $comparison, $endpoint )
                    and length( $textwindow->get( "$step.0", "$step.0 lineend" ) ) == 0 ) {
                    $step += $incr;
                }
                $step -= $incr;    # stepped past blank lines to non-blank, so back-up one line
                return "$step.0";
            }
        }
        return $endpoint;
    }

    #
    # Returns whether illo/sidenote is mid-paragraph by checking whether it is followed
    # by a non-blank line, apart from page markers, blank page markup or another illo
    sub isillosnmidpara {
        my $illosn     = shift;
        my $textwindow = $::textwindow;
        my $startreg   = illosnstartreg();
        my $midpara    = 0;
        my $step       = $textwindow->index( $illosn->{end} );
        $step =~ s/\..+//;
        while ( $textwindow->compare( "$step.0", '<', 'end' ) ) {
            $step++;
            my $line = $textwindow->get( "$step.0", "$step.0 lineend" );
            next if $line =~ /$PAGEBREAKREGEX/;     # Skip page marker lines
            next if $line =~ /^\[Blank Page\]/i;    # Skip blank page markup

            # If we hit another illo/sidenote, step over it to keep checking what happens after it
            if ( $line =~ /$startreg/ ) {
                while ( $textwindow->compare( "$step.0", '<', 'end' )
                    and $textwindow->get( "$step.0", "$step.0 lineend" ) !~ /$ILLOSNENDREG/ ) {
                    $step++;
                }
                next;    # At end of illo/sidenote, go to check next line
            }

            # If we find a blank line, but next line is an illo/sidenote, it doesn't count as a paragraph break.
            # This happens where an illo/sidenote is at the top of page and has had a blank line inserted before it,
            # despite it really being mid-paragraph
            if ( length($line) == 0 ) {
                my $line2 = $textwindow->get( "$step.0 +1l", "$step.0 +1l lineend" );
                next if $line2 =~ /$startreg/;
                last;    # Valid blank line
            }
            $midpara = 1;    # if we get here, we found a non-blank line
        }
        return $midpara;
    }

    # Update the Illustration/Sidenote Fixup window if it is visible
    sub errorcheckillosnupdateneeded {
        my $checktype = errorcheckgettype();
        return unless $checktype eq 'Illustration Fixup' or $checktype eq 'Sidenote Fixup';
        my $activeline = $::lglobal{errorchecklistbox}->index('active');
        errorcheckpop_up( $::textwindow, $::top, $checktype );
        if ( defined $activeline ) {
            $::lglobal{errorchecklistbox}->activate($activeline);
            $::lglobal{errorchecklistbox}->selectionSet($activeline);
            $::lglobal{errorchecklistbox}->see($activeline);

            # Set "illosnnew" system bookmark at current illo/sidenote position
            # Needed particularly after undo/redo
            my $illosnnum = $activeline - 1;    # Allow for header line
            if ( $illosnnum >= 0 and $illosnnum <= $#illosnlist ) {
                my $illosn = $illosnlist[$illosnnum];
                if ( $::lglobal{illosncachestartmark} eq $illosn->{start} ) {    # Only use if cache is not stale
                    ::setbookmarksystem( 'illosnnew', $illosn->{start} );
                } else {
                    errorcheckillosnclearbookmarks();
                }
            }
        }
        errorcheckview($checktype);
    }

    # Clear the system bookmarks related to illo fixup
    sub errorcheckillosnclearbookmarks {
        ::unsetbookmarksystem($_) for ( 'illosnold', 'illosnnew' );
        $::lglobal{illosncachestartmark} = "";
    }

    sub illosnstartreg {
        return $ILLOSNSTARTREG . 'Illustration' if errorcheckgettype() eq 'Illustration Fixup';
        return $ILLOSNSTARTREG . 'Sidenote'     if errorcheckgettype() eq 'Sidenote Fixup';
        return $ILLOSNSTARTREG . 'ERROR';
    }
}    # end of variable-enclosing block

#
# Update query count in dialog
# Positive value sets the count, negative value is subtracted (e.g. when error removed)
sub eccountupdate {
    return unless $::lglobal{eccountlabel};
    my $num = shift;
    $::lglobal{eccountvalue} = $num if $num >= 0;
    $::lglobal{eccountvalue} += $num if $num < 0;
    $::lglobal{eccountvalue} = 0     if $::lglobal{eccountvalue} < 0;
    $::lglobal{eccountlabel}->configure( -text => $::lglobal{eccountvalue}
          . ( $::lglobal{eccountvalue} == 1 ? " query" : " queries" ) );
}

{    # variable-enclosing block for set/query current check type
    my $errorchecktypecurrent;

    # Set the current type of error check being done
    sub errorchecksettype {
        $errorchecktypecurrent = shift;
    }

    # Get the current type of error check being done
    # Returns empty string if no error check being done
    sub errorcheckgettype {
        return "" unless $::lglobal{errorcheckpop};    # Dialog not popped
        return $errorchecktypecurrent;
    }
}    # end of variable-enclosing block
1;
