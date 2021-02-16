package Guiguts::ErrorCheck;
use strict;
use warnings;

BEGIN {
    use Exporter();
    our ( @ISA, @EXPORT );
    @ISA    = qw(Exporter);
    @EXPORT = qw(&errorcheckpop_up);
}

my @errorchecklines;

# General error check window
# Handles Bookloupe, Jeebies, HTML & CSS Validate, Tidy, Link Check
# pphtml, pptxt and Load External Checkfile,
sub errorcheckpop_up {
    my ( $textwindow, $top, $errorchecktype ) = @_;
    my ( $line, $lincol );
    ::hidepagenums();

    # Destroy and start afresh if already popped
    ::killpopup('errorcheckpop');
    $::lglobal{errorcheckpop} = $top->Toplevel;
    $::lglobal{errorcheckpop}->title($errorchecktype);

    # All types have a button to re-run the check
    my $ptopframe   = $::lglobal{errorcheckpop}->Frame->pack;
    my $buttonlabel = 'Run Checks';
    $buttonlabel = 'Load Checkfile' if $errorchecktype eq 'Load Checkfile';
    my $opsbutton = $ptopframe->Button(
        -activebackground => $::activecolor,
        -command          => sub {
            errorcheckpop_up( $textwindow, $top, $errorchecktype );
        },
        -text  => $buttonlabel,
        -width => 16
    )->pack(
        -side   => 'left',
        -pady   => 10,
        -padx   => 20,
        -anchor => 'n'
    );

    # Add verbose checkbox only for certain error check types
    if (   $errorchecktype eq 'Link Check'
        or $errorchecktype eq 'W3C Validate CSS'
        or $errorchecktype eq 'ppvimage'
        or $errorchecktype eq 'pphtml' ) {
        $ptopframe->Checkbutton(
            -variable    => \$::verboseerrorchecks,
            -selectcolor => $::lglobal{checkcolor},
            -text        => 'Verbose'
        )->pack(
            -side   => 'left',
            -pady   => 10,
            -padx   => 2,
            -anchor => 'n'
        );

        # Bookloupe has button to change View Options
    } elsif ( $errorchecktype eq 'Bookloupe' ) {
        $ptopframe->Button(
            -activebackground => $::activecolor,
            -command          => sub { gcviewopts(); },
            -text             => 'View Options',
            -width            => 16
        )->pack(
            -side   => 'left',
            -pady   => 10,
            -padx   => 2,
            -anchor => 'n'
        );

        # Jeebies has paranoia level radio buttons
    } elsif ( $errorchecktype eq 'Jeebies' ) {
        $ptopframe->Label( -text => 'Search mode:', )->pack( -side => 'left', -padx => 2 );
        my @rbutton = ( [ 'Paranoid', 'p' ], [ 'Normal', '' ], [ 'Tolerant', 't' ], );
        for (@rbutton) {
            $ptopframe->Radiobutton(
                -text     => $_->[0],
                -variable => \$::jeebiesmode,
                -value    => $_->[1],
                -command  => \&::savesettings,
            )->pack( -side => 'left', -padx => 2 );
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
            $textwindow->markUnset($_) for values %::errors;
        }
    );
    ::drag( $::lglobal{errorchecklistbox} );

    # button 1 views the error
    $::lglobal{errorchecklistbox}->eventAdd( '<<view>>' => '<ButtonRelease-1>', '<Return>' );
    $::lglobal{errorchecklistbox}->bind( '<<view>>', sub { errorcheckview(); } );

    # buttons 2 & 3 remove the clicked error and view the next error
    $::lglobal{errorchecklistbox}->eventAdd(
        '<<remove>>' => '<ButtonRelease-2>',
        '<ButtonRelease-3>'
    );
    $::lglobal{errorchecklistbox}->bind(
        '<<remove>>',
        sub {
            ::busy();
            my $xx = $::lglobal{errorchecklistbox}->pointerx - $::lglobal{errorchecklistbox}->rootx;
            my $yy = $::lglobal{errorchecklistbox}->pointery - $::lglobal{errorchecklistbox}->rooty;
            my $idx = $::lglobal{errorchecklistbox}->index("\@$xx,$yy");
            $::lglobal{errorchecklistbox}->activate($idx);
            $textwindow->markUnset( $::errors{ $::lglobal{errorchecklistbox}->get('active') } );
            undef $::errors{ $::lglobal{errorchecklistbox}->get('active') };
            $::lglobal{errorchecklistbox}->selectionClear( 0, 'end' );
            $::lglobal{errorchecklistbox}->delete('active');
            $::lglobal{errorchecklistbox}->selectionSet('active');
            errorcheckview();
            ::unbusy();
        }
    );
    $::lglobal{errorcheckpop}->update;

    # End presentation; begin logic
    @errorchecklines = ();
    my $mark  = 0;
    my @marks = $textwindow->markNames;
    for (@marks) {
        if ( $_ =~ /^t\d+$/ ) {
            $textwindow->markUnset($_);
        }
    }
    my $unicode = ::currentfileisunicode();
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
        push @errorchecklines, "Beginning check: " . $errorchecktype;

        # Temporary file in same folder as current file - needs .html extension for some tools
        # Error output in same folder, named errors.err
        my ( $f, $d, $e ) = ::fileparse( $::lglobal{global_filename}, qr{\.[^\.]*$} );
        my $tmpfname = $d . 'tmpcheck' . ( $errorchecktype =~ 'W3C Validate' ? '.html' : '.tmp' );
        $errname = $d . 'errors.err';

        if ( errorcheckrun( $errorchecktype, $tmpfname, $errname ) ) {    # exit if error check failed to run
            ::killpopup('errorcheckpop');
            ::working();
            return;
        }
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

    my $countblank = 0;             # number of blank lines

    # Read and process one line at a time
    while ( $line = <$fh> ) {
        utf8::decode($line) if $unicode;

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
        $::errors{$line} = '';
        if ( $errorchecktype eq 'HTML Tidy' ) {
            last
              if $line =~ /^No warnings or errors were found/
              or $line =~ /^Tidy found/;
            $line =~ s/^\s*line (\d+) column (\d+)\s*/$1:$2 /;

        } elsif ( ( $errorchecktype eq "W3C Validate" )
            or ( $errorchecktype eq "W3C Validate Remote" )
            or ( $errorchecktype eq "pphtml" )
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
            $line =~ s/^\s*(\d+)\s*/$1:0 /;

        } elsif ( $errorchecktype eq "Bookloupe" ) {
            next if $line =~ /^File: /;
            if ( $line =~ /^\s*Line (\d+) column (\d+)\s*/ ) {

                # Adjust column number to start from 0 for most bookloupe errors
                $columnadjust = -1 if $line !~ /Long|Short|digit|space|bracket\?/;
                $line =~ s/^\s*Line (\d+) column (\d+)\s*/$1:$2 /;
            }
            $line =~ s/^\s*Line (\d+)\s*/$1:0 /;

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
        }

        # All line/column formats now converted to "line:col" - mark the locations in the main window
        if ( $line =~ /^(\d+):(\d+)/ ) {

            # Some tools count lines/columns differently
            my $linnum = $1 + $lineadjust;
            my $colnum = $2 + $columnadjust;
            $line =~ s/^\d+:\d+/${linnum}:${colnum}/;

            my $markname = "t" . ++$mark;
            $textwindow->markSet( $markname, "${linnum}.${colnum}" );    # add mark in main text
            $::errors{$line} = $markname;                                # cross-ref error with mark
        }

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
    push @errorchecklines, "Check is complete: " . $errorchecktype
      unless $errorchecktype eq 'Load Checkfile';
    if ( $errorchecktype eq "W3C Validate" ) {
        push @errorchecklines,
          "Don't forget to do the final validation at https://validator.w3.org";
    }
    if ( $errorchecktype eq "W3C Validate CSS" ) {
        push @errorchecklines,
          "Don't forget to do the final validation at https://jigsaw.w3.org/css-validator";
    }

    ::working();
    if ( $errorchecktype eq 'Bookloupe' ) {
        gcwindowpopulate();
    } else {
        $::lglobal{errorchecklistbox}->insert( 'end', @errorchecklines );
    }
    $::lglobal{errorchecklistbox}->insert( 2, "  --> $mark queries" )
      if $errorchecktype eq 'Jeebies';

    $::lglobal{errorchecklistbox}->update;
    $::lglobal{errorchecklistbox}->focus;
    $::lglobal{errorcheckpop}->raise;
}

sub errorcheckrun {    # Runs error checks
    my ( $errorchecktype, $tmpfname, $errname ) = @_;
    my $textwindow = $::textwindow;
    my $top        = $::top;
    ::operationadd("$errorchecktype");
    ::hidepagenums();
    if ( $::lglobal{errorcheckpop} ) {
        $::lglobal{errorchecklistbox}->delete( '0', 'end' );
    }
    $textwindow->focus;
    ::update_indicators();
    return 1 if ::nofileloadedwarning();

    if ( $errorchecktype eq 'HTML Tidy' ) {
        unless ($::tidycommand) {
            ::locateExecutable( 'HTML Tidy', \$::tidycommand );
            return 1 unless $::tidycommand;
        }
    } elsif ( ( $errorchecktype eq "W3C Validate" )
        and ( $::w3cremote == 0 ) ) {
        unless ($::validatecommand) {
            ::locateExecutable( 'W3C HTML Validator (onsgmls)', \$::validatecommand );
            return 1 unless $::validatecommand;
        }
    } elsif ( $errorchecktype eq 'W3C Validate CSS' ) {
        unless ($::validatecsscommand) {
            my $types = [ [ 'JAR file', [ '.jar', ] ], [ 'All Files', ['*'] ], ];
            ::locateExecutable( 'W3C CSS Validator (css-validate.jar)',
                \$::validatecsscommand, $types );
            return 1 unless $::validatecsscommand;
        }
    }
    ::savesettings();
    $top->Busy( -recurse => 1 );

    my $unicode = ::currentfileisunicode();
    savetoerrortmpfile($tmpfname);
    if ( $errorchecktype eq 'HTML Tidy' ) {
        if ($unicode) {
            ::run( $::tidycommand, "-f", $errname, "-e", "-utf8", $tmpfname );
        } else {
            ::run( $::tidycommand, "-f", $errname, "-e", $tmpfname );
        }
    } elsif ( $errorchecktype eq 'W3C Validate' ) {
        if ( $::w3cremote == 0 ) {
            my $validatepath = ::dirname($::validatecommand);
            $ENV{SP_BCTF} = 'UTF-8' if $unicode;
            ::run(
                $::validatecommand,
                "--directory=$validatepath",
                "--catalog=" . ( $::OS_WIN ? "xhtml.soc" : "tools/W3C/xhtml.soc" ),
                "--no-output",
                "--open-entities",
                "--error-file=$errname",
                $tmpfname
            );
        }
    } elsif ( $errorchecktype eq 'W3C Validate Remote' ) {
        my $validator = WebService::Validator::HTML::W3C->new( detailed => 1 );
        if ( $validator->validate_file($tmpfname) ) {
            if ( open my $td, '>', $errname ) {
                if ( $validator->is_valid ) {
                } else {
                    my $errors   = $validator->errors();
                    my $warnings = $validator->warnings();
                    my $warnidx  = 0;

                    # print all the errors and warnings in correct line order
                    foreach my $error (@$errors) {

                        # print any warnings that should come before the next error
                        while ( $warnidx < @$warnings ) {
                            my $warn = $warnings->[$warnidx];
                            last
                              if $warn->line > $error->line
                              or $warn->line == $error->line and $warn->col > $error->line;
                            printf $td ( "%s:%s:W: %s\n", $warn->line, $warn->col, $warn->msg );
                            ++$warnidx;
                        }

                        # print next error
                        printf $td ( "%s:%s:E: %s\n", $error->line, $error->col, $error->msg );
                    }

                    # print any remaining warnings beyond the last error
                    while ( $warnidx < @$warnings ) {
                        my $warn = $warnings->[$warnidx];
                        printf $td ( "%s:%s:W: %s\n", $warn->line, $warn->col, $warn->msg );
                        ++$warnidx;
                    }
                    print $td "Remote response complete";
                }
                close $td;
            }
        } else {
            if ( open my $td, '>', $errname ) {
                print $td $validator->validator_error() . "\n";
                print $td "Try using local validator onsgmls\n";
                close $td;
            }
        }
    } elsif ( $errorchecktype eq 'W3C Validate CSS' ) {
        my $runner = ::runner::tofile( $errname, $errname );    # stdout & stderr
        $runner->run( "java", "-jar", $::validatecsscommand, "--profile=$::cssvalidationlevel",
            "file:$tmpfname" );
    } elsif ( $errorchecktype eq 'pphtml' ) {
        ::run( "perl", "lib/ppvchecks/pphtml.pl", "-i", $tmpfname, "-o", $errname );
    } elsif ( $errorchecktype eq 'Link Check' ) {
        linkcheckrun( $tmpfname, $errname );
    } elsif ( $errorchecktype eq 'ppvimage' ) {
        if ($::verboseerrorchecks) {
            ::run( 'perl', 'tools/ppvimage/ppvimage.pl', '-gg', '-o', $errname, $tmpfname );
        } else {
            ::run( 'perl', 'tools/ppvimage/ppvimage.pl',
                '-gg', '-terse', '-o', $errname, $tmpfname );
        }
    } elsif ( $errorchecktype eq 'pptxt' ) {
        ::run( "perl", "lib/ppvchecks/pptxt.pl", "-i", $tmpfname, "-o", $errname );
    } elsif ( $errorchecktype eq 'Bookloupe' ) {
        booklouperun( $tmpfname, $errname );
    } elsif ( $errorchecktype eq 'Jeebies' ) {
        jeebiesrun( $tmpfname, $errname );
    }
    $top->Unbusy;
    unlink $tmpfname;
    return 0;
}

# Save current file to a temporary file in order to run a check on it
sub savetoerrortmpfile {
    my $tmpfname   = shift;
    my $textwindow = $::textwindow;
    my $top        = $::top;

    my $unicode = ::currentfileisunicode();
    open my $td, '>', $tmpfname or die "Could not open $tmpfname for writing. $!";
    my $count   = 0;
    my $index   = '1.0';
    my ($lines) = $textwindow->index('end - 1c') =~ /^(\d+)\./;
    while ( $textwindow->compare( $index, '<', 'end' ) ) {
        my $end     = $textwindow->index("$index  lineend +1c");
        my $gettext = $textwindow->get( $index, $end );
        utf8::encode($gettext) if ($unicode);
        print $td $gettext;
        $index = $end;
    }
    close $td;
}

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

# When user clicks on an error, show and highlight the correct place in the main text window
sub errorcheckview {
    my $textwindow = $::textwindow;
    $textwindow->tagRemove( 'highlight', '1.0', 'end' );
    my $line = $::lglobal{errorchecklistbox}->get('active');
    return if not defined $line;
    if ( $line =~ /^\d+:\d+/ ) {    # normally line and column number of error is shown
        $textwindow->see( $::errors{$line} );
        $textwindow->markSet( 'insert', $::errors{$line} );

        # Highlight from error to end of line
        my $start = $::errors{$line};
        my $end   = $::errors{$line} . " lineend";

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
        ::update_indicators();
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

sub gcwindowpopulate {
    return unless defined $::lglobal{errorcheckpop};
    my $headr = 0;
    my $error = 0;
    $::lglobal{errorchecklistbox}->delete( '0', 'end' );
    foreach my $line (@errorchecklines) {
        next if $line =~ /^\s*$/;    # Skip blank lines
        next unless defined $::errors{$line};

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

    # Tell user how many queries and how many error types are hidden
    my $hidden = 0;
    $hidden += ( $::gsopt[$_] ? 1 : 0 ) for ( 0 .. $#{ $::lglobal{gcarray} } );
    my $hidtxt = "";
    $hidtxt .= " ($hidden error " . ( $hidden > 1 ? "types" : "type" ) . " hidden)" if $hidden > 0;
    $::lglobal{errorchecklistbox}->insert( $headr, '', "  --> $error queries$hidtxt.", '' );

    # Add start/end messages
    $::lglobal{errorchecklistbox}->insert( 0,     "Beginning check: Bookloupe" );
    $::lglobal{errorchecklistbox}->insert( "end", "Check is complete: Bookloupe" );
    $::lglobal{errorchecklistbox}->update;
}

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
                -variable    => \$::gsopt[$_],
                -command     => sub { gcwindowpopulate(); },
                -selectcolor => $::lglobal{checkcolor},
                -text        => $::lglobal{gcarray}->[$_],
            )->grid( -row => $gcrow, -column => $gccol, -sticky => 'nw' );
        }
        my $pframe2 = $::lglobal{gcviewoptspop}->Frame->pack;
        $pframe2->Button(
            -activebackground => $::activecolor,
            -command          => sub {
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
            -activebackground => $::activecolor,
            -command          => sub {
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
        if ( $::booklang !~ /^en/ && @::gcviewlang ) {
            $pframe2->Button(
                -activebackground => $::activecolor,
                -command          => sub {
                    for ( 0 .. $#::gcviewlang ) {
                        if ( $::gcviewlang[$_] ) {
                            $gsoptions[$_]->select;
                        } else {
                            $gsoptions[$_]->deselect;
                        }
                    }
                    gcwindowpopulate();
                },
                -text  => "Load View: '$::booklang'",
                -width => 14
            )->pack(
                -side   => 'left',
                -pady   => 10,
                -padx   => 2,
                -anchor => 'n'
            );
        } else {
            $pframe2->Button(
                -activebackground => $::activecolor,
                -command          => sub {
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
            -activebackground => $::activecolor,
            -command          => sub {
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
            -activebackground => $::activecolor,
            -command          => sub {
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

sub jeebiesrun {
    my ( $tempfname, $errname ) = @_;
    my $top        = $::top;
    my $textwindow = $::textwindow;

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
    my $textwindow = $::textwindow;
    my $top        = $::top;
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

1;
