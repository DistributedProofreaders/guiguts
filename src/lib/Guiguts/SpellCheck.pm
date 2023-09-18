package Guiguts::SpellCheck;
use strict;
use warnings;

BEGIN {
    use Exporter();
    our ( @ISA, @EXPORT );
    @ISA    = qw(Exporter);
    @EXPORT = qw(&aspellstart &aspellstop &spellchecker &spellloadprojectdict &getmisspelledwords
      &spelloptions &get_spellchecker_version &spellmyaddword &spelladdgoodwords &spellsaveprojdict);
}

#
# Initialize spellchecker
sub spellcheckfirst {
    my $textwindow = $::textwindow;
    my $top        = $::top;
    @{ $::lglobal{misspelledlist} } = ();
    ::hidepagenums();
    $::globalspelldictopt = ::main_lang();
    spellloadprojectdict();

    # get list of misspelled words in selection (or file if nothing selected)
    spellget_misspellings();

    # collect hyphenated words for faster, more accurate spell-check later
    $::lglobal{hyphen_words} = ();
    if ( scalar( $::lglobal{seenwords} ) ) {
        foreach my $word ( keys %{ $::lglobal{seenwords} } ) {
            if ( $::lglobal{seenwords}->{$word} >= 1 && $word =~ /-/ ) {
                $::lglobal{hyphen_words}->{$word} =
                  $::lglobal{seenwords}->{$word};
            }
        }
    }

    # initialise variables for first call to spellchecknext
    $textwindow->markSet( 'spellindex', $::lglobal{spellindexstart} );
    $::lglobal{matchlength} = '0';
    $::lglobal{nextmiss}    = 0;
    aspellstart();
    spellchecknext();
}

#
# Load the project dictionary
sub spellloadprojectdict {
    getprojectdic();
    if (    ( defined $::lglobal{projectdictname} )
        and ( -e $::lglobal{projectdictname} ) ) {
        open( my $fh, "<:encoding(utf8)", $::lglobal{projectdictname} );
        my $hashref = \%::projectdict;
        while ( my $line = <$fh> ) {
            $line =~ s/[\n\r]+//;
            if ( $line eq "%projectdict = (" ) {    # following words are good
                $hashref = \%::projectdict;
                next;
            }
            if ( $line eq "%projectbadwords = (" ) {    # following words are bad
                $hashref = \%::projectbadwords;
                next;
            }
            $line =~ s/' => '',$//g;                    # remove ending
            $line =~ s/^'//g;                           # remove start
            $line =~ s/\\'/'/g;                         # unescape single quote
            next if $line eq ");" or $line eq "";
            $hashref->{$line} = '';
        }
    }
}

#
# Find the next misspelled word
sub spellchecknext {
    my $textwindow = $::textwindow;
    my $top        = $::top;
    ::hidepagenums();
    $textwindow->tagRemove( 'highlight', '1.0', 'end' );    # unhighlight any higlighted text
    spellclearvars();
    $::lglobal{misspelledlabel}->configure( -text => 'Not in Dictionary:' );
    ::soundbell() if $::lglobal{nextmiss} >= ( scalar( @{ $::lglobal{misspelledlist} } ) );
    $::lglobal{suggestionlabel}->configure( -text => 'Suggestions:' );
    return
      if $::lglobal{nextmiss} >= ( scalar( @{ $::lglobal{misspelledlist} } ) );    # no more misspelled words, bail
    $::lglobal{lastmatchindex} = $textwindow->index('spellindex');

    if (   ( $::lglobal{misspelledlist}[ $::lglobal{nextmiss} ] =~ /^[\xC0-\xFF]/ )
        || ( $::lglobal{misspelledlist}[ $::lglobal{nextmiss} ] =~ /[\xC0-\xFF]$/ ) ) {    # crappy workaround for accented character bug
        $::lglobal{matchindex} = (
            $textwindow->search(
                -forwards,
                -count => \$::lglobal{matchlength},
                $::lglobal{misspelledlist}[ $::lglobal{nextmiss} ],
                $::lglobal{lastmatchindex}, 'end'
            )
        );
    } else {
        $::lglobal{matchindex} = (
            $textwindow->search(
                -forwards, -regexp,
                -count => \$::lglobal{matchlength},
                '(?<![\p{Alnum}\p{Mark}])'
                  . $::lglobal{misspelledlist}[ $::lglobal{nextmiss} ]
                  . '(?![\p{Alnum}\p{Mark}])', $::lglobal{lastmatchindex}, 'end'
            )
        );
    }
    unless ( $::lglobal{matchindex} ) {
        $::lglobal{matchindex} = (
            $textwindow->search(
                -forwards, -exact,
                -count => \$::lglobal{matchlength},
                $::lglobal{misspelledlist}[ $::lglobal{nextmiss} ],
                $::lglobal{lastmatchindex}, 'end'
            )
        );
    }
    $::lglobal{spreplaceentry}->delete( '0', 'end' );    # remove last replacement word
    $::lglobal{misspelledentry}
      ->insert( 'end', $::lglobal{misspelledlist}[ $::lglobal{nextmiss} ] );    #put the misspelled word in the spellcheck text box
    spelladdtexttags()
      if $::lglobal{matchindex};                                                # highlight the word in the text
    $::lglobal{lastmatchindex} =
      spelladjust_index( $::lglobal{matchindex},
        $::lglobal{misspelledlist}[ $::lglobal{nextmiss} ] )
      if $::lglobal{matchindex};                                                #get the index of the end of the match
    spellguesses( $::lglobal{misspelledlist}[ $::lglobal{nextmiss} ] );         # get a list of guesses for the misspelling
    spellshow_guesses();                                                        # and put them in the guess list
    $::lglobal{spellpopup}->configure( -title => 'Current Dictionary - '
          . ( $::globalspelldictopt || 'No dictionary!' )
          . " | $#{$::lglobal{misspelledlist}} words to check." );

    if ( scalar( $::lglobal{seenwords} ) ) {
        my $spell_count_case = 0;
        my $hyphen_count     = 0;
        my $cur_word         = $::lglobal{misspelledlist}[ $::lglobal{nextmiss} ];
        my $proper_case      = lc($cur_word);
        $proper_case =~ s/(^\w)/\U$1\E/;
        $spell_count_case += ( $::lglobal{seenwords}->{ uc($cur_word) } || 0 )
          if $cur_word ne uc($cur_word);    # Add the full-uppercase version to the count
        $spell_count_case += ( $::lglobal{seenwords}->{ lc($cur_word) } || 0 )
          if $cur_word ne lc($cur_word);    # Add the full-lowercase version to the count
        $spell_count_case += ( $::lglobal{seenwords}->{$proper_case} || 0 )
          if $cur_word ne $proper_case;     # Add the propercase version to the count

        foreach my $hyword ( keys %{ $::lglobal{hyphen_words} } ) {
            next if $hyword !~ /$cur_word/;
            if (   $hyword =~ /^$cur_word-/
                || $hyword =~ /-$cur_word$/
                || $hyword =~ /-$cur_word-/ ) {
                $hyphen_count += $::lglobal{hyphen_words}->{$hyword};
            }
        }
        my $spell_count_non_poss = 0;
        $spell_count_non_poss = ( $::lglobal{seenwords}->{$1} || 0 )
          if $cur_word =~ /^(.*)'s$/i;
        $spell_count_non_poss = ( $::lglobal{seenwords}->{ $cur_word . '\'s' } || 0 )
          if $cur_word !~ /^(.*)'s$/i;
        $spell_count_non_poss += ( $::lglobal{seenwords}->{ $cur_word . '\'S' } || 0 )
          if $cur_word !~ /^(.*)'s$/i;
        $::lglobal{misspelledlabel}->configure(
            -text => 'Not in Dictionary:  -  '
              . (
                $::lglobal{seenwords}->{ $::lglobal{misspelledlist}[ $::lglobal{nextmiss} ] }
                  || '0'
              )
              . ' exact'
              . (
                $spell_count_case + $spell_count_non_poss > 0
                ? ", $spell_count_case case, $spell_count_non_poss possessive"
                : ''
              )
              . ( $hyphen_count > 0 ? ", $hyphen_count hyphen" : '' )
              . ' in text.'
        );
    }
    return 1;
}

#
# get the misspelled word as it appears in the text (may be checking case insensitive)
sub spellgettextselection {
    my $textwindow = $::textwindow;
    return $textwindow->get( $::lglobal{matchindex},
        "$::lglobal{matchindex}+$::lglobal{matchlength}c" );
}

#
# Replace the bad spelling with the correction
sub spellreplace {
    my $textwindow = $::textwindow;
    ::hidepagenums();
    my $replacement = $::lglobal{spreplaceentry}->get;    # get the word for the replacement box
    ::soundbell() unless $replacement;
    my $misspelled = $::lglobal{misspelledentry}->get;
    return unless $replacement;
    $textwindow->replacewith( $::lglobal{matchindex},
        "$::lglobal{matchindex}+$::lglobal{matchlength}c", $replacement );
    $::lglobal{lastmatchindex} =
      spelladjust_index( ( $textwindow->index( $::lglobal{matchindex} ) ), $replacement );    #adjust the index to the end of the replaced word
    print OUT '$$ra ' . "$misspelled, $replacement\n";
    shift @{ $::lglobal{misspelledlist} };
    spellchecknext();                                                                         # and check the next word
}

#
# Replace the replacement word with one from the guess list
sub spellmisspelled_replace {
    ::hidepagenums();
    $::lglobal{spreplaceentry}->delete( 0, 'end' );
    my $term = $::lglobal{replacementlist}->get('active');
    $::lglobal{spreplaceentry}->insert( 'end', $term );
}

#
# Tell aspell to add a word to the personal dictionary
sub spelladdword {
    my $textwindow = $::textwindow;
    my $term       = $::lglobal{misspelledentry}->get;
    unless ($term) {
        ::soundbell();
        return;
    }
    print OUT "*$term\n";
    print OUT "#\n";
}

#
# Add a word to the project dictionary
# Optional second argument if it's a bad word
sub spellmyaddword {
    my $textwindow = $::textwindow;
    my $term       = shift;
    my $bad        = shift;
    unless ($term) {
        ::soundbell();
        return;
    }
    return if $term =~ /^\s*$/;
    ( $bad ? $::projectbadwords{$term} : $::projectdict{$term} ) = '';
    spellsaveprojdict();
}

#
# Save project dictionary
sub spellsaveprojdict {
    getprojectdic();    # Get dict name into global
    if ( not defined $::lglobal{projectdictname} ) {
        my $dialog = $::top->Dialog(
            -text    => "File must be saved before words can be added to project dictionary.",
            -bitmap  => 'warning',
            -title   => 'No Project Dictionary',
            -buttons => [qw/OK/],
        );
        $dialog->Show;
        return;
    }
    my $section = "\%projectdict = (\n";
    for my $term ( sort keys %::projectdict ) {
        $term =~ s/'/\\'/g;
        $section .= "'$term' => '',\n";
    }
    $section .= ");\n\n";

    $section .= "\%projectbadwords = (\n";
    for my $term ( sort keys %::projectbadwords ) {
        $term =~ s/'/\\'/g;
        $section .= "'$term' => '',\n";
    }
    $section .= ");\n\n";

    open( my $dic, '>:encoding(utf8)', "$::lglobal{projectdictname}" );
    print $dic $section;
    close $dic;
}

#
# Clear the fields in the spellcheck dialog
sub spellclearvars {
    my $textwindow = $::textwindow;
    $::lglobal{misspelledentry}->delete( '0', 'end' );
    $::lglobal{replacementlist}->delete( 0,   'end' );
    $::lglobal{spreplaceentry}->delete( '0', 'end' );
    $textwindow->tagRemove( 'highlight', '1.0', 'end' );
}

#
# Start aspell in interactive mode, repipe stdin and stdout to file handles
sub aspellstart {
    aspellstop();
    my @cmd =
      ( $::globalspellpath, '-a', '-S', '--sug-mode', $::globalaspellmode, '--rem-filter',
        'nroff' );
    @cmd = ( $::globalspellpath, '-a' ) if $::spellcheckwithenchant;
    push @cmd, '-d', $::globalspelldictopt if $::globalspelldictopt;
    $::lglobal{spellpid} = ::open2( \*IN, \*OUT, @cmd );
    my $line = <IN>;
}

#
# Get the version of Aspell being used (if any)
sub get_spellchecker_version {
    return $::lglobal{spellversion} if $::lglobal{spellversion};
    return "Not available" unless $::globalspellpath and -e $::globalspellpath;
    my $aspell_version;
    my $runner = runner::tofile('aspell.tmp');
    $runner->run( $::globalspellpath, 'help' );
    open my $aspell, '<', 'aspell.tmp';
    while (<$aspell>) {
        $aspell_version = $1 if m/^Aspell ([\d\.]+)/;
    }
    close $aspell;
    unlink 'aspell.tmp';
    $::lglobal{spellversion} = $aspell_version;
    $aspell_version = "Unknown" unless $aspell_version;
    return $aspell_version;
}

#
# Stop the Aspell process
sub aspellstop {
    if ( $::lglobal{spellpid} ) {
        close IN;
        close OUT;
        kill 9, $::lglobal{spellpid} if $::OS_WIN;    # Brute force kill the aspell process... seems to be necessary under windows
        waitpid( $::lglobal{spellpid}, 0 );
        $::lglobal{spellpid} = 0;
    }
}

#
# Feed Aspell a word to get a list of guesses
sub spellguesses {
    my $word = shift;                   # word to get guesses for
    @{ $::lglobal{guesslist} } = ();    # clear the guesslist
    utf8::encode($word);
    print OUT $word, "\n";              # send the word to the stdout file handle
    my $list = <IN>;                    # and read the results
    $list =~ s/.*\: //;                 # remove incidental stuff (word, index, number of guesses)
    $list =~ s/\#.*0/\*none\*/;         # oops, no guesses, put a notice in.
    chomp $list;                        # remove newline
    chop $list
      if substr( $list, length($list) - 1, 1 ) eq "\r";    # if chomp didn't take care of both \r and \n in Windows...
    @{ $::lglobal{guesslist} } =
      ( split /, /, $list );                               # split the words into an array
    map ( utf8::decode($_), @{ $::lglobal{guesslist} } )
      if ( ::get_spellchecker_version() =~ m/^0.6/ );
    do { $list = <IN> } while ( $list ne "\n" && $list ne "\r\n" );    # throw away extra lines until newline (especially for non-ascii)
}

#
# Load the guesses into the guess list box
sub spellshow_guesses {
    $::lglobal{replacementlist}->delete( 0, 'end' );
    $::lglobal{replacementlist}->insert( 0, @{ $::lglobal{guesslist} } );
    $::lglobal{replacementlist}->activate(0);
    $::lglobal{spreplaceentry}->delete( '0', 'end' );
    $::lglobal{spreplaceentry}->insert( 'end', $::lglobal{guesslist}[0] );
    $::lglobal{replacementlist}->update;
    $::lglobal{suggestionlabel}->configure( -text => @{ $::lglobal{guesslist} } . ' Suggestions:' );
}

#
# Set the start and end points for spell checking:
# either selected text or whole file if nothing selected
sub spellcheckrange {
    ::hidepagenums();
    my $textwindow = $::textwindow;
    my @ranges     = $textwindow->tagRanges('sel');
    if (@ranges) {
        $::lglobal{spellindexstart} = $ranges[0];
        $::lglobal{spellindexend}   = $ranges[-1];
    } else {
        $::lglobal{spellindexstart} = '1.0';
        $::lglobal{spellindexend}   = $textwindow->index('end');
    }
}

#
# Get list of misspelled words
sub spellget_misspellings {
    my $textwindow = $::textwindow;
    spellcheckrange();                                                                           # get chunk of text to process
    return if ( $::lglobal{spellindexstart} eq $::lglobal{spellindexend} );
    my $section = $textwindow->get( $::lglobal{spellindexstart}, $::lglobal{spellindexend} );    # get selection
    $section =~ s/^-----File:.*//g;
    getmisspelledwords($section);
    ::wordfrequencybuildwordlist($textwindow);

    if ( $#{ $::lglobal{misspelledlist} } > 0 ) {
        $::lglobal{spellpopup}->configure( -title => 'Current Dictionary - '
              . ( $::globalspelldictopt || '<default>' )
              . " | $#{$::lglobal{misspelledlist}} words to check." );
    } else {
        $::lglobal{spellpopup}->configure( -title => 'Current Dictionary - '
              . ( $::globalspelldictopt || 'No dictionary!' )
              . ' | No Misspelled Words Found.' );
    }
    unlink 'checkfil.txt';
}

#
# Use Aspell to get list of misspelled words
sub getmisspelledwords {
    $::lglobal{misspelledlist} = ();
    my $section = shift;
    my ( $word, @templist );
    open my $save, '>:bytes', 'checkfil.txt';
    utf8::encode($section);
    print $save $section;
    close $save;
    my @spellopt = ( "list", "--encoding=utf-8" );
    @spellopt = ("-l") if $::spellcheckwithenchant;
    push @spellopt, "-d", $::globalspelldictopt if $::globalspelldictopt;
    my $runner = ::runner::withfiles( 'checkfil.txt', 'temp.txt' );
    $runner->run( $::globalspellpath, @spellopt );

    unlink 'checkfil.txt';
    open my $infile, '<', 'temp.txt';
    my ( $ln, $tmp );
    while ( $ln = <$infile> ) {
        $ln =~ s/\r\n/\n/;
        chomp $ln;
        utf8::decode($ln);
        push( @templist, $ln );
    }
    close $infile;
    unlink 'temp.txt';
    foreach my $word (@templist) {
        next if ( exists( $::projectdict{$word} ) );
        push @{ $::lglobal{misspelledlist} }, $word;    # filter out project dictionary word list.
    }
}

#
# Remove ignored words from checklist
sub spellignoreall {
    my $textwindow = $::textwindow;
    my $next;
    my $word = $::lglobal{misspelledentry}->get;    # get word you want to ignore
    unless ($word) {
        ::soundbell();
        return;
    }
    my @ignorelist = @{ $::lglobal{misspelledlist} };    # copy the misspellings array
    @{ $::lglobal{misspelledlist} } = ();                # then clear it
    foreach my $next (@ignorelist) {                     # then put all of the words you are NOT ignoring back into the
                                                         # misspellings list
        push @{ $::lglobal{misspelledlist} }, $next
          if ( $next ne $word );                         # inefficient but easy, and the overhead isn't THAT bad...
    }
    spellmyaddword($word);
}

#
# Given an index of the match start return next index to use
# Maybe previously advanced by length of word, but now just advances by 1 character
sub spelladjust_index {
    my $textwindow = $::textwindow;
    my ( $idx, $match ) = @_;
    my ( $mr, $mc ) = split /\./, $idx;
    $mc += 1;
    $textwindow->markSet( 'spellindex', "$mr.$mc" );
    return "$mr.$mc";    # and return the index of 1 character later
}

#
# Add highlighting to selected word
sub spelladdtexttags {
    my $textwindow = $::textwindow;
    $textwindow->markSet( 'insert', $::lglobal{matchindex} );
    $textwindow->tagAdd( 'highlight', $::lglobal{matchindex},
        "$::lglobal{matchindex}+$::lglobal{matchlength} chars" );
    $textwindow->yview('end');
    $textwindow->see( $::lglobal{matchindex} );
}

#
# Add spellings from good_words.txt & bad_words.txt to the project dictionary
sub spelladdgoodwords {
    my $textwindow = $::textwindow;
    my $top        = $::top;
    my $ans        = $top->messageBox(
        -icon    => 'warning',
        -type    => 'YesNo',
        -default => 'yes',
        -title   => 'Warning',
        -message =>
          'Warning: Before adding good_words.txt to project dictionary, first check it does not contain misspellings, multiple spellings, etc. Continue?'
    );
    if ( $ans =~ /no/i ) {
        return;
    }
    my $pwd = ::getcwd();
    chdir $::globallastpath;

    my $fh;

    # Load good words first
    if ( open( $fh, "<:encoding(utf8)", "good_words.txt" ) ) {
        ::busy();
        while ( my $line = <$fh> ) {
            $line =~ s/\s+$//;
            next if $line eq '';
            spellmyaddword($line);
        }
        close($fh);

        # The bad_words.txt file often doesn't exist, so don't error if that's the case
        if ( open( $fh, "<:encoding(utf8)", "bad_words.txt" ) ) {
            while ( my $line = <$fh> ) {
                $line =~ s/\s+$//;
                next if $line eq '';
                spellmyaddword( $line, "bad" );
            }
            close($fh);
        }
        ::unbusy();
    } else {
        ::warnerror("Could not open good_words.txt");
    }
    chdir $pwd;
}

#
# Pop the spell check window
sub spellchecker {
    my $textwindow = $::textwindow;
    my $top        = $::top;
    ::operationadd('Spellcheck');
    ::hidepagenums();
    if ( defined( $::lglobal{spellpopup} ) ) {    # If window already exists
        $::lglobal{spellpopup}->deiconify;                        # pop it up off the task bar
        $::lglobal{spellpopup}->raise;                            # put it on top
        $::lglobal{spellpopup}->focus;                            # and give it focus
        spelloptions()
          unless $::globalspellpath and -e $::globalspellpath;    # Whoops, don't know where to find Aspell
        return unless $::globalspellpath and -e $::globalspellpath;    # Still no Aspell, so quit spell check
        spellclearvars();
        spellcheckfirst();                                             # Start checking the spelling
    } else {    # window doesn't exist so set it up
        $::lglobal{spellpopup} = $top->Toplevel;
        $::lglobal{spellpopup}
          ->title( 'Current Dictionary - ' . $::globalspelldictopt || 'No dictionary!' );
        my $spf1 =
          $::lglobal{spellpopup}->Frame->pack( -side => 'top', -anchor => 'n', -padx => 5 );
        $::lglobal{misspelledlabel} =
          $spf1->Label( -text => 'Not in Dictionary:', )
          ->pack( -side => 'top', -anchor => 'n', -pady => 5 );
        $::lglobal{misspelledentry} = $spf1->Entry(
            -width => 42,
            -font  => 'proofing',
        )->pack( -side => 'top', -anchor => 'n', -pady => 1 );
        my $replacelabel =
          $spf1->Label( -text => 'Replacement Text:', )
          ->pack( -side => 'top', -anchor => 'n', -padx => 6 );
        $::lglobal{spreplaceentry} = $spf1->Entry(
            -width => 42,
            -font  => 'proofing',
        )->pack( -side => 'top', -anchor => 'n', -padx => 1 );
        $::lglobal{suggestionlabel} =
          $spf1->Label( -text => 'Suggestions:', )
          ->pack( -side => 'top', -anchor => 'n', -pady => 5 );
        $::lglobal{replacementlist} = $spf1->ScrlListbox(
            -background => $::bkgcolor,
            -scrollbars => 'se',
            -font       => 'proofing',
            -width      => 40,
            -height     => 4,
        )->pack( -side => 'top', -anchor => 'n', -padx => 6, -pady => 6 );
        my $spf2 =
          $::lglobal{spellpopup}->Frame->pack( -side => 'top', -anchor => 'n', -padx => 5 );
        my $spf3 =
          $::lglobal{spellpopup}->Frame->pack( -side => 'top', -anchor => 'n', -padx => 5 );
        my $spf4 =
          $::lglobal{spellpopup}->Frame->pack( -side => 'top', -anchor => 'n', -padx => 5 );
        my $spf5 =
          $::lglobal{spellpopup}->Frame->pack( -side => 'top', -anchor => 'n', -padx => 5 );

        my $changebutton = $spf2->Button(
            -command => sub {
                ::busy();
                spellreplace();
                ::unbusy();
            },
            -text  => 'Change',
            -width => 22,
        )->pack(
            -side   => 'left',
            -pady   => 2,
            -padx   => 3,
            -anchor => 'nw'
        );
        my $ignorebutton = $spf2->Button(
            -command => sub {
                ::busy();
                shift @{ $::lglobal{misspelledlist} };
                spellchecknext();
                ::unbusy();
            },
            -text  => 'Skip <Ctrl+s>',
            -width => 14,
        )->pack(
            -side   => 'left',
            -pady   => 2,
            -padx   => 3,
            -anchor => 'nw'
        );
        my $dictmyaddbutton = $spf2->Button(
            -command => sub {
                ::busy();
                spellmyaddword( $::lglobal{misspelledentry}->get );
                spellignoreall();
                spellchecknext();
                ::unbusy();
            },
            -text  => 'Add To Project Dic. <Ctrl+p>',
            -width => 22,
        )->pack(
            -side   => 'left',
            -pady   => 2,
            -padx   => 3,
            -anchor => 'nw'
        );
        my $dictmybutton = $spf3->Button(
            -command => sub {
                spelladdgoodwords();
            },
            -text  => 'Add Goodwords To Proj. Dic.',
            -width => 22,
        )->pack(
            -side   => 'left',
            -pady   => 2,
            -padx   => 3,
            -anchor => 'nw'
        );
        my $ignoreallbutton = $spf3->Button(
            -command => sub {
                ::busy();
                spellignoreall();
                spellchecknext();
                ::unbusy();
            },
            -text  => 'Skip All <Ctrl+i>',
            -width => 14,
        )->pack(
            -side   => 'left',
            -pady   => 2,
            -padx   => 3,
            -anchor => 'nw'
        );
        my $dictaddbutton = $spf3->Button(
            -command => sub {
                ::busy();
                spelladdword();
                spellignoreall();
                spellchecknext();
                ::unbusy();
            },
            -text  => 'Add To Aspell Dic. <Ctrl+a>',
            -width => 22,
        )->pack(
            -side   => 'left',
            -pady   => 2,
            -padx   => 3,
            -anchor => 'nw'
        );
        $spf4->Button(
            -command => sub {
                $::spellindexbkmrk = $textwindow->index( $::lglobal{lastmatchindex} . '-1c' )
                  || '1.0';
                $textwindow->markSet( 'spellbkmk', $::spellindexbkmrk );
                ::savesettings();
            },
            -text  => 'Set Bookmark',
            -width => 14,
        )->pack(
            -side   => 'left',
            -pady   => 2,
            -padx   => 3,
            -anchor => 'nw'
        );
        $spf4->Button(
            -command => sub {
                return unless $::spellindexbkmrk;
                $textwindow->tagRemove( 'sel',       '1.0', 'end' );
                $textwindow->tagRemove( 'highlight', '1.0', 'end' );
                $textwindow->tagAdd( 'sel', 'spellbkmk', 'end' );
                spellcheckfirst();
            },
            -text  => 'Resume @ Bkmrk',
            -width => 14,
        )->pack(
            -side   => 'left',
            -pady   => 2,
            -padx   => 3,
            -anchor => 'nw'
        );
        my $spelloptionsbutton = $spf5->Button(
            -command => sub { spelloptions() },
            -text    => 'Options',
            -width   => 12,
        )->pack(
            -side   => 'left',
            -pady   => 2,
            -padx   => 3,
            -anchor => 'nw'
        );
        my $closebutton = $spf5->Button(
            -command => \&endaspell,
            -text    => 'Close',
            -width   => 12,
        )->pack(
            -side   => 'left',
            -pady   => 2,
            -padx   => 3,
            -anchor => 'nw'
        );

        ::initialize_popup_without_deletebinding('spellpopup');
        $::lglobal{spellpopup}->protocol( 'WM_DELETE_WINDOW' => \&endaspell );
        $::lglobal{spellpopup}->bind( '<Control-a>', sub { $dictaddbutton->invoke; } );
        $::lglobal{spellpopup}->bind( '<Control-p>', sub { $dictmyaddbutton->invoke; } );
        $::lglobal{spellpopup}->bind( '<Control-s>', sub { $ignorebutton->invoke; } );
        $::lglobal{spellpopup}->bind( '<Control-i>', sub { $ignoreallbutton->invoke; } );
        $::lglobal{spellpopup}->bind( '<Return>',    sub { $changebutton->invoke; } );
        $::lglobal{replacementlist}->bind( '<Double-Button-1>', \&spellmisspelled_replace );
        $::lglobal{replacementlist}->bind( '<Triple-Button-1>',
            sub { ::busy(); spellmisspelled_replace(); spellreplace(); ::unbusy(); } );
        spelloptions()
          unless $::globalspellpath and -e $::globalspellpath;    # Check to see if we know where Aspell is
        spellcheckfirst() if $::globalspellpath and -e $::globalspellpath;    # Start spellcheck if we now know where Aspell is
    }
}

#
# End the Aspell process
sub endaspell {
    my $textwindow = $::textwindow;
    @{ $::lglobal{misspelledlist} } = ();
    ::killpopup('spellpopup');                    # completely remove spellcheck window
    print OUT "\cC\n" if $::lglobal{spellpid};    # send quit signal to aspell
    aspellstop();                                 # and remove the process
    $textwindow->tagRemove( 'highlight', '1.0', 'end' );
}

#
# Get project dictionary name into global variable (base filename + ".dic")
sub getprojectdic {
    return unless $::lglobal{global_filename};
    my $fname = $::lglobal{global_filename};
    $fname = Win32::GetLongPathName($fname) if $::OS_WIN;
    return unless $fname;
    $::lglobal{projectdictname} = $fname;
    $::lglobal{projectdictname} =~ s/\.[^\.]*?$/\.dic/;

    # Adjustment for multiple volumes/versions, assuming names like mybook1, mybook2, etc.
    # Allows up to 3 digits for the volume/version number
    # For backward compatibility, first check for dictionary name obtained by removing one digit
    $::lglobal{projectdictname} =~ s/\d\.dic$/\.dic/;
    $::lglobal{projectdictname} .= '.dic' if $::lglobal{projectdictname} eq $fname;

    # If old-named dictionary doesn't exist, use new name (removing up to 2 more digits)
    unless ( -e $::lglobal{projectdictname} ) {
        $::lglobal{projectdictname} =~ s/\d{1,2}\.dic$/\.dic/;
        $::lglobal{projectdictname} .= '.dic' if $::lglobal{projectdictname} eq $fname;
    }
}

#
# Pop the Spell Check options dialog
sub spelloptions {
    my $textwindow = $::textwindow;
    my $top        = $::top;
    if ( $::globalspellpath and -e $::globalspellpath ) {
        aspellstart() unless $::lglobal{spellpid};
    }
    my $dicts;
    my $dictlist;
    my $spellop = $top->DialogBox(
        -title   => 'Spell Check Options',
        -buttons => ['OK']
    );
    my $spellpathlabel  = $spellop->add( 'Label', -text  => 'Aspell executable file:' )->pack;
    my $spellpathentry  = $spellop->add( 'Entry', -width => 60, -background => $::bkgcolor )->pack;
    my $spellpathbrowse = $spellop->add(
        'Button',
        -text    => 'Locate Aspell Executable',
        -width   => 24,
        -command => sub {
            ::locateExecutable( 'Aspell', \$::globalspellpath );
            if ( $::globalspellpath and -e $::globalspellpath ) {
                $spellpathentry->delete( 0, 'end' );
                $spellpathentry->insert( 'end', $::globalspellpath );
                ::savesettings();
                my $runner = ::runner::tofile('aspell.tmp');
                $runner->run( $::globalspellpath, 'dump', 'dicts' );
                warn "Unable to access dictionaries.\n" if $?;
                open my $infile, '<', 'aspell.tmp';

                while ( $dicts = <$infile> ) {
                    chomp $dicts;
                    next if ( $dicts =~ m/-/ );
                    $dictlist->insert( 'end', $dicts );
                }
                close $infile;
                unlink 'aspell.tmp';
            }
        }
    )->pack( -pady => 4 );
    $spellpathentry->insert( 'end', $::globalspellpath );
    my $spellencodinglabel =
      $spellop->add( 'Label', -text => 'Set encoding: default = iso8859-1' )->pack;
    my $spellencodingentry = $spellop->add(
        'Entry',
        -width        => 30,
        -textvariable => \$::lglobal{spellencoding},
    )->pack;
    my $dictlabel =
      $spellop->add( 'Label', -text => 'Dictionary files (double-click to select):' )->pack;
    $dictlist = $spellop->add(
        'ScrlListbox',
        -scrollbars => 'e',
        -selectmode => 'browse',
        -background => $::bkgcolor,
        -height     => 10,
        -width      => 40,
    )->pack( -pady => 4 );
    my $spelldiclabel = $spellop->add( 'Label', -text => 'Current Dictionary (ies)' )->pack;
    my $spelldictxt   = $spellop->add(
        'ROText',
        -width      => 40,
        -height     => 1,
        -background => $::bkgcolor
    )->pack;
    $spelldictxt->delete( '1.0', 'end' );
    $spelldictxt->insert( '1.0', $::globalspelldictopt );

    if ( $::globalspellpath and -e $::globalspellpath ) {
        my $runner = runner::tofile('aspell.tmp');
        $runner->run( $::globalspellpath, 'dump', 'dicts' );
        warn "Unable to access dictionaries.\n" if $?;
        open my $infile, '<', 'aspell.tmp';
        while ( $dicts = <$infile> ) {
            chomp $dicts;
            next if ( $dicts =~ m/-/ );
            $dictlist->insert( 'end', $dicts );
        }
        close $infile;
        unlink 'aspell.tmp';
    }
    $dictlist->eventAdd( '<<dictsel>>' => '<Double-Button-1>' );
    $dictlist->bind(
        '<<dictsel>>',
        sub {
            ::busy();
            my $selection = $dictlist->get('active');
            $spelldictxt->delete( '1.0', 'end' );
            $spelldictxt->insert( '1.0', $selection );
            $selection            = '' if $selection eq "No dictionary!";
            $::globalspelldictopt = $selection;
            ::savesettings();
            aspellstart();

            if ( defined( $::lglobal{spellpopup} ) ) {
                spellclearvars();
                spellcheckfirst();
            }
            ::unbusy();
        }
    );
    my $spopframe = $spellop->Frame->pack;
    $spopframe->Radiobutton(
        -text     => 'Ultra Fast',
        -variable => \$::globalaspellmode,
        -value    => 'ultra'
    )->grid( -row => 0, -sticky => 'w' );
    $spopframe->Radiobutton(
        -text     => 'Fast',
        -variable => \$::globalaspellmode,
        -value    => 'fast'
    )->grid( -row => 1, -sticky => 'w' );
    $spopframe->Radiobutton(
        -text     => 'Normal',
        -variable => \$::globalaspellmode,
        -value    => 'normal'
    )->grid( -row => 2, -sticky => 'w' );
    $spopframe->Radiobutton(
        -text     => 'Bad Spellers',
        -variable => \$::globalaspellmode,
        -value    => 'bad-spellers'
    )->grid( -row => 3, -sticky => 'w' );
    $spellop->Show;
    $spellop->focus;
    $spellop->raise;
}

1;
