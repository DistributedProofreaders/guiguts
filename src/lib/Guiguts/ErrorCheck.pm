package Guiguts::ErrorCheck;
use strict;
use warnings;

BEGIN {
    use Exporter();
    our ( @ISA, @EXPORT );
    @ISA    = qw(Exporter);
    @EXPORT = qw(&errorcheckpop_up);
}

# General error check window
# Handles Gutcheck, Jeebies, HTML & CSS Validate, Tidy, Link Check
# pphtml, pptxt and Load External Checkfile,
sub errorcheckpop_up {
    my ( $textwindow, $top, $errorchecktype ) = @_;
    my ( %errors,     @errorchecklines );
    my ( $line,       $lincol );
    ::hidepagenums();

    # Destroy and start afresh if already popped
    if ( $::lglobal{errorcheckpop} ) {
        $::lglobal{errorcheckpop}->destroy;
        undef $::lglobal{errorcheckpop};
    }
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
    # Note Bookloupe/Gutcheck have their own (always on) verbose flag
    if (   ( $errorchecktype eq 'Check All' )
        or ( $errorchecktype eq 'Link Check' )
        or ( $errorchecktype eq 'W3C Validate CSS' )
        or ( $errorchecktype eq 'ppvimage' )
        or ( $errorchecktype eq 'pphtml' ) ) {
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

        # Bookloupe/Gutcheck have buttons to change Run Options and View Options
    } elsif ( $errorchecktype eq 'Bookloupe/Gutcheck' ) {
        my $opsbutton2 = $ptopframe->Button(
            -activebackground => $::activecolor,
            -command          => sub { gcrunopts() },
            -text             => 'Run Options',
            -width            => 16
        )->pack(
            -side   => 'left',
            -pady   => 10,
            -padx   => 2,
            -anchor => 'n'
        );
        my $opsbutton3 = $ptopframe->Button(
            -activebackground => $::activecolor,
            -command          => sub { gcviewopts( \@errorchecklines ) },
            -text             => 'View Options',
            -width            => 16
        )->pack(
            -side   => 'left',
            -pady   => 10,
            -padx   => 2,
            -anchor => 'n'
        );
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

    # Create the dialog - it has a customised delete binding which clears the error marks
    # and destroys the run/view options dialogs as well
    ::initialize_popup_without_deletebinding('errorcheckpop');
    $::lglobal{errorcheckpop}->protocol(
        'WM_DELETE_WINDOW' => sub {
            ::killpopup('errorcheckpop');
            $textwindow->markUnset($_) for values %::errors;
            if ( $errorchecktype eq 'Bookloupe/Gutcheck' ) {
                ::killpopup('gcviewoptspop');
                ::killpopup('gcrunoptspop');
            }
        }
    );

    ::drag( $::lglobal{errorchecklistbox} );
    ::BindMouseWheel( $::lglobal{errorchecklistbox} );

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
            my $xx = $::lglobal{errorchecklistbox}->pointerx - $::lglobal{errorchecklistbox}->rootx;
            my $yy = $::lglobal{errorchecklistbox}->pointery - $::lglobal{errorchecklistbox}->rooty;
            my $idx = $::lglobal{errorchecklistbox}->index("\@$xx,$yy");
            $::lglobal{errorchecklistbox}->activate($idx);
            $::lglobal{errorchecklistbox}->selectionClear( 0, 'end' );
            $::lglobal{errorchecklistbox}->delete('active');
            $::lglobal{errorchecklistbox}->selectionSet('active');
            errorcheckview();
            $::lglobal{errorchecklistbox}->after( $::lglobal{delay} );
        }
    );
    $::lglobal{errorcheckpop}->update;

    # End presentation; begin logic
    my (@errorchecktypes);                     # Multiple errorchecktypes in one popup
    if ( $errorchecktype eq 'Check All' ) {    # Means all HTML checks
        @errorchecktypes =
          ( 'W3C Validate', 'HTML Tidy', 'ppvimage', 'Link Check', 'W3C Validate CSS', 'pphtml' );
    } else {
        @errorchecktypes = ($errorchecktype);
    }
    %errors          = ();
    @errorchecklines = ();
    my $mark  = 0;
    my @marks = $textwindow->markNames;
    for (@marks) {
        if ( $_ =~ /^t\d+$/ ) {
            $textwindow->markUnset($_);
        }
    }
    my $unicode = ::currentfileisunicode();
    foreach my $thiserrorchecktype (@errorchecktypes) {
        my $fname = '';
        ::working($thiserrorchecktype);
        if ( $thiserrorchecktype eq 'Load Checkfile' ) {
            $fname = $::lglobal{errorcheckpop}->getOpenFile( -title => 'File Name?' );
            last if ( not $fname );
        } else {
            push @errorchecklines, "Beginning check: " . $thiserrorchecktype;
            if ( errorcheckrun($thiserrorchecktype) ) {
                push @errorchecklines, "Failed to run: " . $thiserrorchecktype;
            }
            $fname = "errors.err";
        }
        my $fh = FileHandle->new("< $fname");
        if ( not defined($fh) ) {
            my $dialog = $top->Dialog(
                -text    => 'Could not find ' . $thiserrorchecktype . ' error file.',
                -bitmap  => 'question',
                -title   => 'File not found',
                -buttons => [qw/OK/],
            );
            $dialog->Show;
            next;
        }

        # CSS validator reports line numbers from start of style block, so need to adjust
        my $lineadjust = 0;
        if (    $thiserrorchecktype eq 'W3C Validate CSS'
            and $lineadjust = $textwindow->search( '--', '<style', '1.0', 'end' ) ) {
            $lineadjust =~ s/\..*//;    # strip column from 'row.column'
        }

        my $countblank = 0;             # number of blank lines
        while ( $line = <$fh> ) {
            utf8::decode($line) if $unicode;
            $line =~ s/^\s//g;
            chomp $line;

            # distinguish blank lines by setting them to varying numbers
            # of spaces, otherwise if user deletes one, it deletes them all
            $line = ' ' x ++$countblank if ( $line eq '' );

            # Skip rest of CSS
            last
              if $thiserrorchecktype eq 'W3C Validate CSS'
              and not $::verboseerrorchecks
              and (( $line =~ /^To show your readers/i )
                or ( $line =~ /^Valid CSS Information/i ) );

            # skip blank lines
            next if $line =~ /^\s*$/i;

            # skip some unnecessary lines from W3C Validate CSS
            next
              if $line =~ /^{output/i and not $::verboseerrorchecks
              or $line =~ /^W3C/i
              or $line =~ /^URI/i;

            if ( !$::OS_WIN && $thiserrorchecktype eq 'W3C Validate CSS' ) {
                $line =~ s/(\x0d)$//;
            }

            # Skip verbose informational warnings in Link Check
            if (    ( not $::verboseerrorchecks )
                and ( $thiserrorchecktype eq 'Link Check' )
                and ( $line =~ /^Link statistics/i ) ) {
                last;
            }
            if ( $thiserrorchecktype eq 'pphtml' ) {
                if ( $line =~ /^-/i ) {    # skip lines beginning with '-'
                    next;
                }
                if ( ( not $::verboseerrorchecks )
                    and $line =~ /^Verbose checks/i ) {    # stop with verbose specials check
                    last;
                }
            }
            no warnings 'uninitialized';
            if ( $thiserrorchecktype eq 'HTML Tidy' ) {
                if (    ( $line =~ /^[lI\d]/ )
                    and ( $line ne $errorchecklines[-1] ) ) {
                    push @errorchecklines, $line;
                    $::errors{$line} = '';
                    $lincol = '';
                    if ( $line =~ /^line (\d+) column (\d+)/i ) {
                        $lincol = "$1.$2";
                        $mark++;
                        $textwindow->markSet( "t$mark", $lincol );
                        $::errors{$line} = "t$mark";
                    }
                }
            } elsif ( ( $thiserrorchecktype eq "W3C Validate" )
                or ( $thiserrorchecktype eq "W3C Validate Remote" )
                or ( $thiserrorchecktype eq "pphtml" )
                or ( $thiserrorchecktype eq "ppvimage" ) ) {
                $line =~ s/^.*:(\d+:\d+)/line $1/;
                $line =~ s/^(\d+:\d+)/line $1/;
                $line =~ s/^(line \d+) /$1:1/;
                $::errors{$line} = '';
                $lincol = '';
                if ( $line =~ /line (\d+):(\d+)/ ) {
                    $lincol = "$1.$2";
                    $lincol =~ s/\.0/\.1/;    # change column zero to column 1
                    $mark++;
                    $textwindow->markSet( "t$mark", $lincol );
                    $::errors{$line} = "t$mark";
                }
                push @errorchecklines, $line unless $line eq '';
            } elsif ( ( $thiserrorchecktype eq "W3C Validate CSS" )
                or ( $thiserrorchecktype eq "Link Check" )
                or ( $thiserrorchecktype eq "pptxt" ) ) {

                # Format line number, adjusting for tool's idea of start line
                if ( $line =~ /Line : (\d+)/ ) {
                    my $lineno = $1 + $lineadjust;
                    $line =~ s/Line : (\d+)/line ${lineno}:1/;
                }
                push @errorchecklines, $line;
                $::errors{$line} = '';
                $lincol = '';
                if ( $line =~ /line (\d+):(\d+)/ ) {
                    $lincol = "$1.$2";
                    $mark++;
                    $textwindow->markSet( "t$mark", $lincol );
                    $::errors{$line} = "t$mark";
                }

                # Load a checkfile from an external tool, e.g. online ppcomp, pptxt, pphtml
                # File may be in HTML format or a text file
            } elsif ( $thiserrorchecktype eq "Load Checkfile" ) {

                # if HTML file, ignore the header & footer
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
                $::errors{$line} = '';
                $lincol = '';
                if ( $line =~ /^\s*\d+/ ) {
                    $line =~ s/^\s*(\d+)/line $1/;
                    $lincol = "$1.0";
                    $mark++;

                    # add a new mark in the main text at the correct point
                    $textwindow->markSet( "t$mark", $lincol );

                    # remember which line goes with which mark
                    $::errors{$line} = "t$mark";
                }

                # display all lines, even those without line numbers
                push @errorchecklines, $line;
            } elsif ( $thiserrorchecktype eq "Bookloupe/Gutcheck" ) {
                next if $line =~ /^File: /;
                $::errors{$line} = '';
                $lincol = '';
                if ( $line =~ /Line (\d+) column (\d+)/ ) {
                    my $linnum = $1;
                    my $colnum = $2;

                    # Adjust column number to start from 0
                    $colnum-- unless ( $line =~ /Long|Short|digit|space|bracket\?/ );
                    $lincol = "$linnum.$colnum";
                    $line =~ s/ *Line \d+ column \d+/line $linnum:$colnum/;
                } elsif ( $line =~ /Line (\d+)/ ) {
                    $lincol = "$1.0";
                    $line =~ s/ *Line (\d+)/line $1:0/;
                }
                if ( $lincol ne '' ) {
                    $mark++;
                    $textwindow->markSet( "t$mark", $lincol );
                    $::errors{$line} = "t$mark";
                }

                push @errorchecklines, $line;
            } elsif ( $thiserrorchecktype eq "Jeebies" ) {
                $::errors{$line} = '';
                $lincol = '';
                if ( $line =~ /Line (\d+) column (\d+)/ ) {
                    my $linnum = $1;
                    my $colnum = $2;
                    $lincol = "$linnum.$colnum";
                    if ( $line =~ /Query phrase "([^"]+)"/ ) {
                        my $len = length($1) + 1;
                        $lincol = $textwindow->index( $lincol . " -${len}c" );
                    }
                    $line =~ s/ *Line \d+ column \d+/line $linnum:$colnum/;
                } elsif ( $line =~ /Line (\d+)/ ) {
                    $lincol = "$1.0";
                    $line =~ s/ *Line (\d+)/line $1:0/;
                }
                if ( $lincol ne '' ) {
                    $mark++;
                    $textwindow->markSet( "t$mark", $lincol );
                    $::errors{$line} = "t$mark";
                }
                push @errorchecklines, $line;
            }
        }
        $fh->close if $fh;
        unlink 'errors.err' unless $thiserrorchecktype eq 'Load Checkfile';
        my $size = @errorchecklines;
        if ( ( $thiserrorchecktype eq "W3C Validate CSS" ) and ( $size <= 1 ) ) {    # handle errors.err file with zero lines
            push @errorchecklines,
              "Could not perform validation: install java or use W3C CSS Validation web site.";
            next;
        }
        push @errorchecklines, "Check is complete: " . $thiserrorchecktype
          unless $thiserrorchecktype eq 'Load Checkfile';
        if ( $thiserrorchecktype eq "W3C Validate" ) {
            push @errorchecklines,
              "Don't forget to do the final validation at http://validator.w3.org";
        }
        if ( $thiserrorchecktype eq "W3C Validate CSS" ) {
            push @errorchecklines,
              "Don't forget to do the final validation at http://jigsaw.w3.org/css-validator/";
        }
        push @errorchecklines, "";
    }
    ::working();
    if ( $errorchecktype eq 'Bookloupe/Gutcheck' ) {
        gcwindowpopulate( \@errorchecklines );
    } else {
        $::lglobal{errorchecklistbox}->insert( 'end', @errorchecklines );
    }
    $::lglobal{errorchecklistbox}->yview( 'scroll', 1, 'units' );
    $::lglobal{errorchecklistbox}->update;
    $::lglobal{errorchecklistbox}->yview( 'scroll', -1, 'units' );
    $::lglobal{errorchecklistbox}->focus;
    $::lglobal{errorcheckpop}->raise;
}

sub errorcheckrun {    # Runs error checks
    my $errorchecktype = shift;
    my $textwindow     = $::textwindow;
    my $top            = $::top;
    if ( $errorchecktype eq 'W3C Validate Remote' ) {
        unless ( eval { require WebService::Validator::HTML::W3C } ) {
            print
              "Install the module WebService::Validator::HTML::W3C to do W3C Validation remotely. Defaulting to local validation.\n";
            $errorchecktype = 'W3C Validate';
        }
    }
    ::operationadd("$errorchecktype");
    ::hidepagenums();
    if ( $::lglobal{errorcheckpop} ) {
        $::lglobal{errorchecklistbox}->delete( '0', 'end' );
    }
    my ( $name, $fname, $path, $extension, @path );
    $textwindow->focus;
    ::update_indicators();
    my $title = $top->cget('title');
    if ( $title =~ /No File Loaded/ ) { ::savefile( $textwindow, $top ) }
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
    if (   ( $errorchecktype eq 'W3C Validate Remote' )
        or ( $errorchecktype eq 'W3C Validate CSS' ) ) {
        $name = 'validate.html';
    } elsif ( $errorchecktype eq 'ppvimage' ) {
        my ( $f, $d, $e ) =
          ::fileparse( $::lglobal{global_filename}, qr{\.[^\.]*$} );
        $name = $d . 'errors.tmp';    # ppvimage requires tmp file to be in the right dir, so the paths match
    } else {
        $name = 'errors.tmp';
    }
    my $unicode = ::currentfileisunicode();
    if ( open my $td, '>', $name ) {
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
    } else {
        warn "Could not open temp file for writing. $!";
        my $dialog = $top->Dialog(
            -text => 'Could not write to the '
              . cwd()
              . ' directory. Check for write permission or space problems.',
            -bitmap  => 'question',
            -title   => "$errorchecktype problem",
            -buttons => [qw/OK/],
        );
        $dialog->Show;
        return;
    }
    if ( $errorchecktype eq 'HTML Tidy' ) {
        if ($unicode) {
            ::run( $::tidycommand, "-f", "errors.err", "-e", "-utf8", $name );
        } else {
            ::run( $::tidycommand, "-f", "errors.err", "-e", $name );
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
                "--error-file=errors.err",
                $name
            );
        }
    } elsif ( $errorchecktype eq 'W3C Validate Remote' ) {
        my $validator = WebService::Validator::HTML::W3C->new( detailed => 1 );
        if ( $validator->validate_file('./validate.html') ) {
            if ( open my $td, '>', "errors.err" ) {
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
            if ( open my $td, '>', "errors.err" ) {
                print $td $validator->validator_error() . "\n";
                print $td "Try using local validator onsgmls\n";
                close $td;
            }
        }
    } elsif ( $errorchecktype eq 'W3C Validate CSS' ) {
        my $runner = ::runner::tofile( "errors.err", "errors.err" );    # stdout & stderr
        $runner->run( "java", "-jar", $::validatecsscommand, "--profile=$::cssvalidationlevel",
            "file:$name" );
    } elsif ( $errorchecktype eq 'pphtml' ) {
        ::run( "perl", "lib/ppvchecks/pphtml.pl", "-i", $name, "-o", "errors.err" );
    } elsif ( $errorchecktype eq 'Link Check' ) {
        linkcheckrun();
    } elsif ( $errorchecktype eq 'ppvimage' ) {
        if ($::verboseerrorchecks) {
            ::run( 'perl', 'tools/ppvimage/ppvimage.pl', '-gg', '-o', 'errors.err', $name );
        } else {
            ::run( 'perl', 'tools/ppvimage/ppvimage.pl',
                '-gg', '-terse', '-o', 'errors.err', $name );
        }
    } elsif ( $errorchecktype eq 'pptxt' ) {
        ::run( "perl", "lib/ppvchecks/pptxt.pl", "-i", $name, "-o", "errors.err" );
    } elsif ( $errorchecktype eq 'Bookloupe/Gutcheck' ) {
        gutcheckrun();
    } elsif ( $errorchecktype eq 'Jeebies' ) {
        jeebiesrun();
    }
    $top->Unbusy;
    unlink $name;
    return;
}

sub linkcheckrun {
    my $textwindow = $::textwindow;
    my $top        = $::top;
    open my $logfile, ">", "errors.err" || die "output file error\n";
    my ( %anchor, %id, %link, %image, %badlink, $length, $upper );
    my ( $anchors, $ids, $ilinks, $elinks, $images, $count, $css ) = ( 0, 0, 0, 0, 0, 0, 0 );
    my @warning = ();
    my $fname   = $::lglobal{global_filename};
    if ( $fname =~ /(No File Loaded)/ ) {
        print $logfile "You need to save your file first.";
        return;
    }
    my ( $f, $d, $e ) = ::fileparse( $fname, qr{\.[^\.]*$} );
    my %imagefiles;
    my @ifiles   = ();
    my $imagedir = '';
    push @warning, '';
    my ( $fh, $filename );
    my @temp         = split( /[\\\/]/, $textwindow->FileName );
    my $tempfilename = $temp[-1];

    if ( $tempfilename =~ /projectid/i ) {
        print $logfile "Choose a human readable filename: $tempfilename\n";
    }
    if ( $tempfilename =~ /[A-Z]/ ) {
        print $logfile "Use only lower case in filename: $tempfilename\n";
    }
    if ( $textwindow->numberChanges ) {
        $filename = 'tempfile.tmp';
        open( my $fh, ">", "$filename" );
        my ($lines) = $textwindow->index('end - 1 chars') =~ /^(\d+)\./;
        my $index = '1.0';
        while ( $textwindow->compare( $index, '<', 'end' ) ) {
            my $end  = $textwindow->index("$index lineend +1c");
            my $line = $textwindow->get( $index, $end );
            print $fh $line;
            $index = $end;
        }
        $fname = $filename;
        close $fh;
    }
    my $parser = HTML::TokeParser->new($fname);
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
        $badlink{$_} = $_ if ( $_ =~ m/\\|\%5C|\s|\%20/ );
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
    unlink $filename if $filename;
    close $logfile;
}

# When user clicks on an error, show and highlight the correct place in the main text window
sub errorcheckview {
    my $textwindow = $::textwindow;
    $textwindow->tagRemove( 'highlight', '1.0', 'end' );
    my $line = $::lglobal{errorchecklistbox}->get('active');
    return if not defined $line;
    if ( $line =~ /^line/ ) {    # normally line number of error is shown
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
    my $linesref = shift;
    return unless defined $::lglobal{errorcheckpop};
    my $start = 0;
    my $count = 0;
    $::lglobal{errorchecklistbox}->delete( '0', 'end' );
    foreach my $line ( @{$linesref} ) {
        my $flag = 0;
        next unless defined $::errors{$line};
        for ( 0 .. $#{ $::lglobal{gcarray} } ) {
            next unless ( index( $line, $::lglobal{gcarray}->[$_] ) > 0 );
            $::gsopt[$_] = 0 unless defined $::gsopt[$_];
            $flag = 1 if $::gsopt[$_];
            last;
        }
        next if $flag;
        unless ( $count == 0 and $line =~ /^\s*$/ ) {    # Don't add blank line at top
            $start++ unless ( index( $line, 'line', 0 ) == 0 );
            $count++;
            $::lglobal{errorchecklistbox}->insert( 'end', $line );
        }
    }
    $count -= $start;
    $::lglobal{errorchecklistbox}->insert( $start, "  --> $count queries.", '' );
    $::lglobal{errorchecklistbox}->insert( $start, '' );

    # Add start/end messages
    my $command =
      ( $::gutcommand and ::basename($::gutcommand) =~ /gutcheck/ ) ? "Gutcheck" : "Bookloupe";
    $::lglobal{errorchecklistbox}->insert( 0,     "Beginning check: $command" );
    $::lglobal{errorchecklistbox}->insert( "end", "Check is complete: $command" );
    $::lglobal{errorchecklistbox}->update;
}

sub gcviewopts {
    my $linesref = shift;
    my $top      = $::top;
    my @gsoptions;
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
    my $gcrows = int( ( @{ $::lglobal{gcarray} } / 3 ) + .9 );
    if ( defined( $::lglobal{gcviewoptspop} ) ) {
        $::lglobal{gcviewoptspop}->deiconify;
        $::lglobal{gcviewoptspop}->raise;
        $::lglobal{gcviewoptspop}->focus;
    } else {
        $::lglobal{gcviewoptspop} = $top->Toplevel;
        $::lglobal{gcviewoptspop}->title('Bookloupe/Gutcheck View Options');
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
                -command     => sub { gcwindowpopulate($linesref) },
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
                gcwindowpopulate($linesref);
            },
            -text  => 'Hide All',
            -width => 12
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
                gcwindowpopulate($linesref);
            },
            -text  => 'See All',
            -width => 12
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
                    gcwindowpopulate($linesref);
                },
                -text  => "Load View: '$::booklang'",
                -width => 12
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
                    gcwindowpopulate($linesref);
                },
                -text  => 'Toggle View',
                -width => 12
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
                gcwindowpopulate($linesref);
            },
            -text  => 'Load My View',
            -width => 12
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
            -text  => 'Save My View',
            -width => 12
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
                $::lglobal{gcviewoptspop}->destroy;
                @{ $::lglobal{gcarray} } = ();
                undef $::lglobal{gcviewoptspop};
                unlink 'gutreslts.tmp';    #cat('gutreslts.tmp')
            }
        );
    }
}

sub jeebiesrun {
    my $top        = $::top;
    my $textwindow = $::textwindow;
    ::savefile() if ( $textwindow->numberChanges );
    my $title = ::os_normal( $::lglobal{global_filename} );
    unless ($::jeebiescommand) {
        ::locateExecutable( 'Jeebies', \$::jeebiescommand );
        return unless $::jeebiescommand;
    }
    my $jeebiesoptions = "-$::jeebiesmode" . 'e';
    $::jeebiescommand = ::os_normal($::jeebiescommand);
    my $mark = 0;
    $top->Busy( -recurse => 1 );
    my $runner = runner::tofile('errors.err');
    $runner->run( $::jeebiescommand, $jeebiesoptions, $title );

    $top->Unbusy( -recurse => 1 );
}

## Run bookloupe/gutcheck
sub gutcheckrun {
    my $textwindow = $::textwindow;
    my $top        = $::top;
    no warnings;
    ::operationadd('Bookloupe/Gutcheck');
    ::hidepagenums();
    $textwindow->focus;
    ::update_indicators();
    my $title = $top->cget('title');

    if ( $title =~ /No File Loaded/ ) {
        ::nofileloadedwarning();
        return;
    }

    # Bookloupe is utf-8 friendly, but if still using gutcheck, revert to "bytes" encoding
    my $encoding = ">:encoding(UTF-8)";
    if ( $::gutcommand and ::basename($::gutcommand) =~ /gutcheck/ ) {
        $encoding = ">:bytes";
    }
    if ( open my $gc, $encoding, 'gutchk.tmp' ) {
        my $count = 0;
        my $index = '1.0';
        while ( $textwindow->compare( $index, '<', 'end' ) ) {
            my $end = $textwindow->index("$index  lineend +1c");
            print $gc $textwindow->get( $index, $end );
            $index = $end;
        }
        close $gc;
    } else {
        warn "Could not open temp file for writing. $!";
        my $dialog = $top->Dialog(
            -text => 'Could not write to the '
              . cwd()
              . ' directory. Check for write permission or space problems.',
            -bitmap  => 'question',
            -title   => 'Bookloupe/Gutcheck problem',
            -buttons => [qw/OK/],
        );
        $dialog->Show;
        return;
    }
    unless ($::gutcommand) {
        ::locateExecutable( 'Bookloupe/Gutcheck', \$::gutcommand );
        return unless $::gutcommand;
    }
    my $gutcheckoptions = '-ey';    # e - echo queried line. y - puts errors to stdout instead of stderr.
    $gutcheckoptions .= 't' if $::gcopt[0];    # Check common typos
    $gutcheckoptions .= 'x' if $::gcopt[1];    # "Trust no one" Paranoid mode. Queries everything
    $gutcheckoptions .= 'p' if $::gcopt[2];    # Require closure of quotes on every paragraph
    $gutcheckoptions .= 's' if $::gcopt[3];    # Force checking for matched pairs of single quotes
    $gutcheckoptions .= 'm' if $::gcopt[4];    # Ignore markup in < >
    $gutcheckoptions .= 'l' if $::gcopt[5];    # Line end checking - defaults on
    $gutcheckoptions .= 'v' if $::gcopt[6];    # Verbose - list EVERYTHING!
    $gutcheckoptions .= 'u' if $::gcopt[7];    # Use file of User-defined Typos
    $gutcheckoptions .= 'd' if $::gcopt[8];    # Ignore DP style page separators
    $::gutcommand = ::os_normal($::gutcommand);
    ::savesettings();

    my $runner = ::runner::tofile('errors.err');
    $runner->run( $::gutcommand, $gutcheckoptions, 'gutchk.tmp' );
    unlink 'gutchk.tmp';
}

sub gcrunopts {
    my $textwindow = $::textwindow;
    my $top        = $::top;
    $::lglobal{gcrunoptspop} =
      $top->DialogBox( -title => 'Bookloupe/Gutcheck Run Options', -buttons => ['OK'] );
    my $gcopt6 = $::lglobal{gcrunoptspop}->add(
        'Checkbutton',
        -variable    => \$::gcopt[6],
        -selectcolor => $::lglobal{checkcolor},
        -text        => '-v Enable verbose mode (Recommended).',
    )->pack( -side => 'top', -anchor => 'nw', -padx => 5 );
    my $gcopt0 = $::lglobal{gcrunoptspop}->add(
        'Checkbutton',
        -variable    => \$::gcopt[0],
        -selectcolor => $::lglobal{checkcolor},
        -text        => '-t Disable check for common typos.',
    )->pack( -side => 'top', -anchor => 'nw', -padx => 5 );
    my $gcopt1 = $::lglobal{gcrunoptspop}->add(
        'Checkbutton',
        -variable    => \$::gcopt[1],
        -selectcolor => $::lglobal{checkcolor},
        -text        => '-x Disable paranoid mode.',
    )->pack( -side => 'top', -anchor => 'nw', -padx => 5 );
    my $gcopt2 = $::lglobal{gcrunoptspop}->add(
        'Checkbutton',
        -variable    => \$::gcopt[2],
        -selectcolor => $::lglobal{checkcolor},
        -text        => '-p Report ALL unbalanced double quotes.',
    )->pack( -side => 'top', -anchor => 'nw', -padx => 5 );
    my $gcopt3 = $::lglobal{gcrunoptspop}->add(
        'Checkbutton',
        -variable    => \$::gcopt[3],
        -selectcolor => $::lglobal{checkcolor},
        -text        => '-s Report ALL unbalanced single quotes.',
    )->pack( -side => 'top', -anchor => 'nw', -padx => 5 );
    my $gcopt4 = $::lglobal{gcrunoptspop}->add(
        'Checkbutton',
        -variable    => \$::gcopt[4],
        -selectcolor => $::lglobal{checkcolor},
        -text        => '-m Interpret HTML markup.',
    )->pack( -side => 'top', -anchor => 'nw', -padx => 5 );
    my $gcopt5 = $::lglobal{gcrunoptspop}->add(
        'Checkbutton',
        -variable    => \$::gcopt[5],
        -selectcolor => $::lglobal{checkcolor},
        -text        => '-l Do not report non DOS newlines.',
    )->pack( -side => 'top', -anchor => 'nw', -padx => 5 );
    my $gcopt7 = $::lglobal{gcrunoptspop}->add(
        'Checkbutton',
        -variable    => \$::gcopt[7],
        -selectcolor => $::lglobal{checkcolor},
        -text        => '-u Flag words from the .typ file.',
    )->pack( -side => 'top', -anchor => 'nw', -padx => 5 );
    my $gcopt8 = $::lglobal{gcrunoptspop}->add(
        'Checkbutton',
        -variable    => \$::gcopt[8],
        -selectcolor => $::lglobal{checkcolor},
        -text        => '-d Ignore DP style page separators.',
    )->pack( -side => 'top', -anchor => 'nw', -padx => 5 );
    ::initialize_popup_without_deletebinding('gcrunoptspop');
    $::lglobal{gcrunoptspop}->Show;
    ::savesettings();
}

1;
