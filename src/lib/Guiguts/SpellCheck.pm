package Guiguts::SpellCheck;
use strict;
use warnings;

BEGIN {
    use Exporter();
    our ( @ISA, @EXPORT );
    @ISA    = qw(Exporter);
    @EXPORT = qw(&aspellstart &aspellstop &spellchecker &spellloadprojectdict &getmisspelledwords
      &spelloptions &get_spellchecker_version);
}

# Initialize spellchecker
sub spellcheckfirst {
    my $textwindow = $::textwindow;
    my $top        = $::top;
    @{ $::lglobal{misspelledlist} } = ();
    ::hidepagenums();
    $::globalspelldictopt = $::booklang;
    spellloadprojectdict();
    $::lglobal{lastmatchindex} = '1.0';

    # get list of misspelled words in selection (or file if nothing selected)
    spellget_misspellings();
    my $term = $::lglobal{misspelledlist}[0];    # get first misspelled term
    $::lglobal{misspelledentry}->delete( '0', 'end' );
    $::lglobal{misspelledentry}->insert( 'end', $term );    # put it in the appropriate text box
    $::lglobal{suggestionlabel}->configure( -text => 'Suggestions:' );
    return unless $term;                                    # no misspellings found, bail
    $::lglobal{matchlength} = '0';
    $::lglobal{matchindex}  = $textwindow->search(
        -forwards,
        -count => \$::lglobal{matchlength},
        $term, $::lglobal{spellindexstart}, 'end'
    );                                                      # search for the misspelled word in the text
    $::lglobal{lastmatchindex} = spelladjust_index( $::lglobal{matchindex}, $term );    # find the index of the end of the match
    spelladdtexttags();                                                                 # highlight the word in the text
    ::update_indicators();                                                              # update the status bar
    aspellstart();                                                                      # initialize the guess function
    spellguesses($term);                                                                # get the guesses for the misspelling
    spellshow_guesses();                                                                # populate the listbox with guesses
    $::lglobal{hyphen_words} = ();                                                      # hyphenated list of words

    if ( scalar( $::lglobal{seenwords} ) ) {
        $::lglobal{misspelledlabel}
          ->configure( -text => "Not in Dictionary:  -  $::lglobal{seenwords}->{$term} in text." )
          if $::lglobal{seenwords}->{$term};

        # collect hyphenated words for faster, more accurate spell-check later
        foreach my $word ( keys %{ $::lglobal{seenwords} } ) {
            if ( $::lglobal{seenwords}->{$word} >= 1 && $word =~ /-/ ) {
                $::lglobal{hyphen_words}->{$word} =
                  $::lglobal{seenwords}->{$word};
            }
        }
    }
    $::lglobal{nextmiss} = 0;
}

sub spellloadprojectdict {
    getprojectdic();
    if (    ( defined $::lglobal{projectdictname} )
        and ( -e $::lglobal{projectdictname} ) ) {
        open( my $fh, "<:encoding(utf8)", $::lglobal{projectdictname} );
        while ( my $line = <$fh> ) {
            utf8::decode($line);
            if ( $line eq "%projectdict = (\n" ) { next; }
            if ( $line eq ");" )                 { next; }
            $line =~ s/' => '',\n$//g;    # remove ending
            $line =~ s/^'//g;             # remove start
            $line =~ s/\\'/'/g;           # remove \'
            $::projectdict{$line} = '';
        }
    }
}

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
                '(?<!\p{Alpha})'
                  . $::lglobal{misspelledlist}[ $::lglobal{nextmiss} ]
                  . '(?!\p{Alnum})', $::lglobal{lastmatchindex}, 'end'
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
    ::update_indicators();                                                      # update the status bar
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
          if $cur_word ne uc($cur_word);                                        # Add the full-uppercase version to the count
        $spell_count_case += ( $::lglobal{seenwords}->{ lc($cur_word) } || 0 )
          if $cur_word ne lc($cur_word);                                        # Add the full-lowercase version to the count
        $spell_count_case += ( $::lglobal{seenwords}->{$proper_case} || 0 )
          if $cur_word ne $proper_case;                                         # Add the propercase version to the count

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
              . (
                $spell_count_case + $spell_count_non_poss > 0
                ? ", $spell_count_case, $spell_count_non_poss"
                : ''
              )
              . ( $hyphen_count > 0 ? ", $hyphen_count hyphens" : '' )
              . ' in text.'
        );
    }
    return 1;
}

sub spellgettextselection {
    my $textwindow = $::textwindow;
    return $textwindow->get( $::lglobal{matchindex},
        "$::lglobal{matchindex}+$::lglobal{matchlength}c" );    # get the
                                                                # misspelled word
                                                                # as it appears in
                                                                # the text (may be
                                                                # checking case
                                                                # insensitive)
}

sub spellreplace {
    my $textwindow = $::textwindow;
    ::hidepagenums();
    my $replacement = $::lglobal{spreplaceentry}->get;          # get the word for the replacement box
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

# replace all instances of a word with another, pretty straightforward
sub spellreplaceall {
    my $textwindow = $::textwindow;
    ::hidepagenums();
    my $lastindex   = '1.0';
    my $misspelled  = $::lglobal{misspelledentry}->get;
    my $replacement = $::lglobal{spreplaceentry}->get;
    my $repmatchindex;
    $textwindow->FindAndReplaceAll( '-exact', '-nocase', $misspelled, $replacement );
    spellignoreall();
}

# replace the replacement word with one from the guess list
sub spellmisspelled_replace {
    ::hidepagenums();
    $::lglobal{spreplaceentry}->delete( 0, 'end' );
    my $term = $::lglobal{replacementlist}->get('active');
    $::lglobal{spreplaceentry}->insert( 'end', $term );
}

# tell aspell to add a word to the personal dictionary
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

# add a word to the project dictionary
sub spellmyaddword {
    my $textwindow = $::textwindow;
    my $term       = shift;
    unless ($term) {
        ::soundbell();
        return;
    }
    getprojectdic();
    $::projectdict{$term} = '';
    open( my $dic, '>:bytes', "$::lglobal{projectdictname}" );
    my $section = "\%projectdict = (\n";

    for my $term ( sort { $a cmp $b } keys %::projectdict ) {
        $term =~ s/'/\\'/g;
        $section .= "'$term' => '',\n";
    }
    $section .= ");";
    utf8::encode($section);
    print $dic $section;
    close $dic;
}

sub spellclearvars {
    my $textwindow = $::textwindow;
    $::lglobal{misspelledentry}->delete( '0', 'end' );
    $::lglobal{replacementlist}->delete( 0,   'end' );
    $::lglobal{spreplaceentry}->delete( '0', 'end' );
    $textwindow->tagRemove( 'highlight', '1.0', 'end' );
}

# start aspell in interactive mode, repipe stdin and stdout to file handles
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

sub get_spellchecker_version {
    return $::lglobal{spellversion} if $::lglobal{spellversion};
    my $aspell_version;
    my $runner = runner::tofile('aspell.tmp');
    $runner->run( $::globalspellpath, 'help' );
    open my $aspell, '<', 'aspell.tmp';
    while (<$aspell>) {
        $aspell_version = $1 if m/^Aspell ([\d\.]+)/;
    }
    close $aspell;
    unlink 'aspell.tmp';
    return $::lglobal{spellversion} = $aspell_version;
}

sub aspellstop {
    if ( $::lglobal{spellpid} ) {
        close IN;
        close OUT;
        kill 9, $::lglobal{spellpid}
          if $::OS_WIN;    # Brute force kill the aspell process... seems to be necessary
                           # under windows
        waitpid( $::lglobal{spellpid}, 0 );
        $::lglobal{spellpid} = 0;
    }
}

sub spellguesses {         #feed aspell a word to get a list of guess
    my $word = shift;      # word to get guesses for
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

# load the guesses into the guess list box
sub spellshow_guesses {
    $::lglobal{replacementlist}->delete( 0, 'end' );
    $::lglobal{replacementlist}->insert( 0, @{ $::lglobal{guesslist} } );
    $::lglobal{replacementlist}->activate(0);
    $::lglobal{spreplaceentry}->delete( '0', 'end' );
    $::lglobal{spreplaceentry}->insert( 'end', $::lglobal{guesslist}[0] );
    $::lglobal{replacementlist}->update;
    $::lglobal{suggestionlabel}->configure( -text => @{ $::lglobal{guesslist} } . ' Suggestions:' );
}

# only spell check selected text or whole file if nothing selected
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

sub spellget_misspellings {    # get list of misspelled words
    my $textwindow = $::textwindow;
    spellcheckrange();         # get chunk of text to process
    return if ( $::lglobal{spellindexstart} eq $::lglobal{spellindexend} );
    my $section = $textwindow->get( $::lglobal{spellindexstart}, $::lglobal{spellindexend} );    # get selection
    $section =~ s/^-----File:.*//g;
    getmisspelledwords($section);
    ::wordfrequencybuildwordlist($textwindow);

    #wordfrequencygetmisspelled();
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

sub getmisspelledwords {
    if ($::debug) { print "sub getmisspelledwords\n"; }
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

    if ($::debug) {
        print "\$::globalspellpath ", $::globalspellpath, "\n";
        print "\@spellopt\n";
        for my $element (@spellopt) {
            print "$element\n";
        }
        print "checkfil.txt retained\n";
    } else {
        unlink 'checkfil.txt';
    }
    open my $infile, '<', 'temp.txt';
    my ( $ln, $tmp );
    while ( $ln = <$infile> ) {
        $ln =~ s/\r\n/\n/;
        chomp $ln;
        utf8::decode($ln);
        push( @templist, $ln );
    }
    close $infile;
    if ($::debug) {
        print "temp.txt retained\n";
    } else {
        unlink 'temp.txt';
    }
    foreach my $word (@templist) {
        next if ( exists( $::projectdict{$word} ) );
        push @{ $::lglobal{misspelledlist} }, $word;    # filter out project dictionary word list.
    }
}

# remove ignored words from checklist
sub spellignoreall {
    my $textwindow = $::textwindow;
    my $next;
    my $word = $::lglobal{misspelledentry}->get;        # get word you want to ignore
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

sub spelladjust_index {                                  # get the index of the match start (row column)
    my $textwindow = $::textwindow;
    my ( $idx, $match ) = @_;
    my ( $mr,  $mc )    = split /\./, $idx;
    $mc += 1;
    $textwindow->markSet( 'spellindex', "$mr.$mc" );
    return "$mr.$mc";                                    # and return the index of the end of the match
}

# add highlighting to selected word
sub spelladdtexttags {
    my $textwindow = $::textwindow;
    $textwindow->markSet( 'insert', $::lglobal{matchindex} );
    $textwindow->tagAdd( 'highlight', $::lglobal{matchindex},
        "$::lglobal{matchindex}+$::lglobal{matchlength} chars" );
    $textwindow->yview('end');
    $textwindow->see( $::lglobal{matchindex} );
}

sub spelladdgoodwords {
    my $textwindow = $::textwindow;
    my $top        = $::top;
    my $ans        = $top->messageBox(
        -icon    => 'warning',
        -type    => 'YesNo',
        -default => 'yes',
        -title   => 'Warning',
        -message =>
          'Warning: Before adding good_words.txt first check whether they do not contain misspellings, multiple spellings, etc. Continue?'
    );
    if ( $ans =~ /no/i ) {
        return;
    }
    my $pwd = ::getcwd();
    chdir $::globallastpath;
    open( DAT, "good_words.txt" ) or die "Could not open good_words.txt!";

    # Remove all newlines and/or carriage returns whatever the current OS
    my @raw_data = map { s/[\n\r]+$//g; $_ } <DAT>;
    close(DAT);
    chdir $pwd;
    my $word = q{};
    foreach my $word (@raw_data) {
        spellmyaddword($word);
    }
}

sub spellchecker {    # Set up spell check window
    my $textwindow = $::textwindow;
    my $top        = $::top;
    ::operationadd('Spellcheck');
    ::hidepagenums();
    if ( defined( $::lglobal{spellpopup} ) ) {    # If window already exists
        $::lglobal{spellpopup}->deiconify;        # pop it up off the task bar
        $::lglobal{spellpopup}->raise;            # put it on top
        $::lglobal{spellpopup}->focus;            # and give it focus
        spelloptions()
          unless $::globalspellpath && -e $::globalspellpath;    # Whoops, don't know where to find Aspell
        spellclearvars();
        spellcheckfirst();                                       # Start checking the spelling
    } else {                                                     # window doesn't exist so set it up
        $::lglobal{spellpopup} = $top->Toplevel;
        $::lglobal{spellpopup}
          ->title( 'Current Dictionary - ' . $::globalspelldictopt || 'No dictionary!' );
        my $spf1 =
          $::lglobal{spellpopup}->Frame->pack( -side => 'top', -anchor => 'n', -padx => 5 );
        $::lglobal{misspelledlabel} =
          $spf1->Label( -text => 'Not in Dictionary:', )
          ->pack( -side => 'top', -anchor => 'n', -pady => 5 );
        $::lglobal{misspelledentry} = $spf1->Entry(
            -background => $::bkgcolor,
            -width      => 42,
            -font       => 'proofing',
        )->pack( -side => 'top', -anchor => 'n', -pady => 1 );
        my $replacelabel =
          $spf1->Label( -text => 'Replacement Text:', )
          ->pack( -side => 'top', -anchor => 'n', -padx => 6 );
        $::lglobal{spreplaceentry} = $spf1->Entry(
            -background => $::bkgcolor,
            -width      => 42,
            -font       => 'proofing',
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
            -activebackground => $::activecolor,
            -command          => sub {
                ::busy();
                spellreplace();
                ::unbusy();
            },
            -text  => 'Change',
            -width => 14,
        )->pack(
            -side   => 'left',
            -pady   => 2,
            -padx   => 3,
            -anchor => 'nw'
        );
        my $ignorebutton = $spf2->Button(
            -activebackground => $::activecolor,
            -command          => sub {
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
            -activebackground => $::activecolor,
            -command          => sub {
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
        my $replaceallbutton = $spf3->Button(
            -activebackground => $::activecolor,
            -command          => sub {
                ::busy();
                spellreplaceall();
                spellchecknext();
                ::unbusy();
            },
            -text  => 'Change All',
            -width => 14,
        )->pack(
            -side   => 'left',
            -pady   => 2,
            -padx   => 3,
            -anchor => 'nw'
        );
        my $ignoreallbutton = $spf3->Button(
            -activebackground => $::activecolor,
            -command          => sub {
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
            -activebackground => $::activecolor,
            -command          => sub {
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
            -activebackground => $::activecolor,
            -command          => sub {
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
            -activebackground => $::activecolor,
            -command          => sub {
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
        my $dictmybutton = $spf5->Button(
            -activebackground => $::activecolor,
            -command          => sub {
                spelladdgoodwords();
            },
            -text  => 'Add Goodwords To Proj. Dic.',
            -width => 24,
        )->pack(
            -side   => 'left',
            -pady   => 2,
            -padx   => 3,
            -anchor => 'nw'
        );
        my $spelloptionsbutton = $spf5->Button(
            -activebackground => $::activecolor,
            -command          => sub { spelloptions() },
            -text             => 'Options',
            -width            => 12,
        )->pack(
            -side   => 'left',
            -pady   => 2,
            -padx   => 3,
            -anchor => 'nw'
        );
        my $closebutton = $spf5->Button(
            -activebackground => $::activecolor,
            -command          => \&endaspell,
            -text             => 'Close',
            -width            => 12,
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
          unless $::globalspellpath && -e $::globalspellpath;    # Check to see if we know where Aspell is
        spellcheckfirst();                                       # Start the spellcheck
    }
}

sub endaspell {
    my $textwindow = $::textwindow;
    @{ $::lglobal{misspelledlist} } = ();
    ::killpopup('spellpopup');                                   # completely remove spellcheck window
    print OUT "\cC\n" if $::lglobal{spellpid};                   # send quit signal to aspell
    aspellstop();                                                # and remove the process
    $textwindow->tagRemove( 'highlight', '1.0', 'end' );
}

## Spell Check
#needed elsewhere - load projectdict
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

sub spelloptions {
    my $textwindow = $::textwindow;
    my $top        = $::top;
    if ($::globalspellpath) {
        aspellstart() unless $::lglobal{spellpid};
    }
    my $dicts;
    my $dictlist;
    my $spellop = $top->DialogBox(
        -title   => 'Spell Check Options',
        -buttons => ['OK']
    );
    my $spellpathlabel = $spellop->add( 'Label', -text  => 'Aspell executable file:' )->pack;
    my $spellpathentry = $spellop->add( 'Entry', -width => 60, -background => $::bkgcolor )->pack;
    my $spellpathbrowse = $spellop->add(
        'Button',
        -text    => 'Locate Aspell Executable',
        -width   => 24,
        -command => sub {
            ::locateExecutable( 'Aspell', \$::globalspellpath );
            if ($::globalspellpath) {
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

    #$dictlist->insert( 'end', "No dictionary!" );
    if ($::globalspellpath) {
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
        -selectcolor => $::lglobal{checkcolor},
        -text        => 'Ultra Fast',
        -variable    => \$::globalaspellmode,
        -value       => 'ultra'
    )->grid( -row => 0, -sticky => 'w' );
    $spopframe->Radiobutton(
        -selectcolor => $::lglobal{checkcolor},
        -text        => 'Fast',
        -variable    => \$::globalaspellmode,
        -value       => 'fast'
    )->grid( -row => 1, -sticky => 'w' );
    $spopframe->Radiobutton(
        -selectcolor => $::lglobal{checkcolor},
        -text        => 'Normal',
        -variable    => \$::globalaspellmode,
        -value       => 'normal'
    )->grid( -row => 2, -sticky => 'w' );
    $spopframe->Radiobutton(
        -selectcolor => $::lglobal{checkcolor},
        -text        => 'Bad Spellers',
        -variable    => \$::globalaspellmode,
        -value       => 'bad-spellers'
    )->grid( -row => 3, -sticky => 'w' );
    $spellop->Show;
    $spellop->focus;
    $spellop->raise;
}

1;
