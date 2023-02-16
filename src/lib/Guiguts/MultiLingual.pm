package Guiguts::MultiLingual;
use strict;
use warnings;

BEGIN {
    use Exporter();
    our ( $VERSION, @ISA, @EXPORT );
    $VERSION = 0.1;
    @ISA     = qw(Exporter);
    @EXPORT  = qw(&spellmultiplelanguages);
}

#uses
# $::lglobal{seenwords}
# $::lglobal{misspelledlist}
# $::lglobal{spellsort}
my @orderedwords      = ();
my $totalwordcount    = 0;
my $distinctwordcount = 0;
my $speltwordcount    = 0;
my $unspeltwordcount;
my %distinctwords = ();
my %seenwordslc   = ();
my %seenwordslang = ();
my $savedHeader;
my $multidictentry;
my $multiwclistbox;
my $sortorder = 'f';
my @templist  = ();
my $minfreq   = 5;

#startup routine
sub spellmultiplelanguages {
    my ( $textwindow, $top ) = @_;
    ::operationadd('multilingual spelling');
    ::hidepagenums();

    # find Aspell and base language if necessary
    ::spelloptions() unless $::globalspellpath;
    return           unless $::globalspellpath;
    ::spelloptions() unless $::globalspelldictopt;
    return           unless $::globalspelldictopt;
    multilangpopup( $textwindow, $top );
}

#the popup window and menu
sub multilangpopup {
    my ( $textwindow, $top ) = @_;
    ::operationadd('Multilingual Spelling');
    ::hidepagenums();

    # open popup if necessary
    if ( defined( $::lglobal{multispellpop} ) ) {
        $::lglobal{multispellpop}->deiconify;
        $::lglobal{multispellpop}->raise;
        $::lglobal{multispellpop}->focus;
    } else {
        $::lglobal{multispellpop} = $top->Toplevel;
        $::lglobal{multispellpop}->title('Multilingual Spelling');
        ::initialize_popup_without_deletebinding('multispellpop');

        my $f2 = $::lglobal{multispellpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        my $labelone =
          $f2->Label( -text => 'Dictionaries selected:' )
          ->grid( -row => 1, -column => 1, -padx => 1, -pady => 1 );
        $multidictentry = $f2->Entry(
            -background => $::bkgcolor,
            -width      => 40,
        )->grid( -row => 1, -column => 2, -padx => 1, -pady => 1 );
        my $f0 = $::lglobal{multispellpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        $f0->Button(
            -command => sub {
                setmultiplelanguages( $textwindow, $top );
                updateMultiDictEntry();
            },
            -text  => 'Set Languages',
            -width => 20
        )->grid( -row => 1, -column => 2, -padx => 1, -pady => 1 );
        $f0->Button(
            -command => sub {
                ::spelloptions();
                clearmultilanguages();
                updateMultiDictEntry();
            },
            -text  => 'Set Base Language',
            -width => 20
        )->grid( -row => 1, -column => 1, -padx => 1, -pady => 1 );
        $f0->Button(
            -command => sub { createseenwordslang( $textwindow, $top ) },
            -text    => '(Re)create Wordlist',
            -width   => 20
        )->grid( -row => 2, -column => 1, -padx => 1, -pady => 1 );
        $f0->Button(
            -command => sub { multilingualgetmisspelled( $textwindow, $top ) },
            -text    => 'Check spelling',
            -width   => 20
        )->grid( -row => 2, -column => 2, -padx => 1, -pady => 1 );
        $f0->Button(
            -command => sub { includeprojectdict( $textwindow, $top ) },
            -text    => 'Include project words',
            -width   => 20
        )->grid( -row => 2, -column => 3, -padx => 1, -pady => 1 );
        $f0->Button(
            -command => sub { showAllWords() },
            -text    => 'Show all words',
            -width   => 20
        )->grid( -row => 3, -column => 1, -padx => 1, -pady => 1 );
        $f0->Button(
            -command => sub { showUnspeltWords() },
            -text    => 'Show unspelt words',
            -width   => 20
        )->grid( -row => 3, -column => 2, -padx => 1, -pady => 1 );
        $f0->Button(
            -command => sub { showspeltforeignwords() },
            -text    => 'Show spelt foreign words',
            -width   => 20
        )->grid( -row => 3, -column => 3, -padx => 1, -pady => 1 );
        $f0->Button(
            -command => sub { showprojectdict() },
            -text    => 'Show project dictionary',
            -width   => 20
        )->grid( -row => 4, -column => 1, -padx => 1, -pady => 1 );
        $f0->Button(
            -command => sub { addspeltforeignproject() },
            -text    => 'Add foreign to project',
            -width   => 20
        )->grid( -row => 4, -column => 2, -padx => 1, -pady => 1 );
        $f0->Button(
            -command => sub { addminfreqproject() },
            -text    => 'Add frequent to project',
            -width   => 20
        )->grid( -row => 4, -column => 3, -padx => 1, -pady => 1 );

        $f0->Button(
            -command => sub { multi_help_popup($top) },
            -text    => 'Help',
            -width   => 20
        )->grid( -row => 1, -column => 3, -padx => 1, -pady => 1 );
        my $f1 = $::lglobal{multispellpop}->Frame->pack( -fill => 'both', -expand => 'both', );
        $multiwclistbox = $f1->Scrolled(
            'Listbox',
            -scrollbars  => 'se',
            -background  => $::bkgcolor,
            -selectmode  => 'single',
            -activestyle => 'none',
        )->pack(
            -anchor => 'nw',
            -fill   => 'both',
            -expand => 'both',
            -padx   => 2,
            -pady   => 2
        );
        my $f3 = $::lglobal{multispellpop}->Frame->pack( -side => 'top', -anchor => 'n' );
        $f3->Radiobutton(
            -variable    => \$sortorder,
            -selectcolor => $::lglobal{checkcolor},
            -value       => 'a',
            -text        => 'Alph',
        )->pack( -side => 'left', -anchor => 'nw', -pady => 1 );
        $f3->Radiobutton(
            -variable    => \$sortorder,
            -selectcolor => $::lglobal{checkcolor},
            -value       => 'f',
            -text        => 'Frq',
        )->pack( -side => 'left', -anchor => 'nw', -pady => 1 );
        $f3->Radiobutton(
            -variable    => \$sortorder,
            -selectcolor => $::lglobal{checkcolor},
            -value       => 'l',
            -text        => 'Len',
        )->pack( -side => 'left', -anchor => 'nw', -pady => 1 );
        $multiwclistbox->bind(
            '<Control-f>' => sub {
                my ($sword) = $multiwclistbox->get( $multiwclistbox->curselection );
                return unless length $sword;
                print "206 $sword 8 6 s\n";
                my $word = $sword;
                $word =~ s/^.........//;
                $word =~ s/^.......//;
                print "210 $word\n";
            }
        );

        ::drag($multiwclistbox);
        $::lglobal{multispellpop}->protocol(
            'WM_DELETE_WINDOW' => sub {
                ::killpopup('multispellpop');
                undef $multiwclistbox;
            }
        );
    }

    updateMultiDictEntry();
    getwordcounts();
}

sub showAllWords {
    my $lang;
    $savedHeader = "Total words: $totalwordcount, Distinct words: $distinctwordcount\n";
    $multiwclistbox->delete( '0', 'end' );
    $multiwclistbox->insert( 'end', 'Please wait, sorting list....' );
    $multiwclistbox->update;
    if ( $sortorder eq 'f' ) {
        for ( ::natural_sort_freq( \%distinctwords ) ) {
            if   ( $seenwordslang{$_} ) { $lang = $seenwordslang{$_} }
            else                        { $lang = '' }
            my $line = sprintf( "%-8d %-6s %s", $distinctwords{$_}, $lang, $_ );
            $multiwclistbox->insert( 'end', $line );
        }
    } elsif ( $sortorder eq 'a' ) {
        for ( ::natural_sort_alpha( keys %distinctwords ) ) {
            if   ( $seenwordslang{$_} ) { $lang = $seenwordslang{$_} }
            else                        { $lang = '' }
            my $line = sprintf( "%-8d %-6s %s", $distinctwords{$_}, $lang, $_ );
            $multiwclistbox->insert( 'end', $line );
        }
    } elsif ( $sortorder eq 'l' ) {
        for ( ::natural_sort_length( keys %distinctwords ) ) {
            if   ( $seenwordslang{$_} ) { $lang = $seenwordslang{$_} }
            else                        { $lang = '' }
            my $line = sprintf( "%-8d %-6s %s", $distinctwords{$_}, $lang, $_ );
            $multiwclistbox->insert( 'end', $line );
        }
    }
    $multiwclistbox->delete('0');
    $multiwclistbox->insert( '0', $savedHeader );
    $multiwclistbox->update;
}

sub showUnspeltWords {
    if ($unspeltwordcount) {
        $savedHeader = "Spelt words: $speltwordcount, Unspelt words: $unspeltwordcount\n";
    } else {
        $savedHeader = "No spelling undertaken!";
    }
    $multiwclistbox->delete( '0', 'end' );
    $multiwclistbox->insert( 'end', 'Please wait, sorting list....' );
    $multiwclistbox->update;
    if ( $sortorder eq 'f' ) {
        for ( ::natural_sort_freq( \%distinctwords ) ) {
            unless ( $seenwordslang{$_} ) {
                my $line = sprintf( "%-8d %-6s %s", $distinctwords{$_}, '', $_ );
                $multiwclistbox->insert( 'end', $line );
            }
        }
    } elsif ( $sortorder eq 'a' ) {
        for ( ::natural_sort_alpha( keys %distinctwords ) ) {
            unless ( $seenwordslang{$_} ) {
                my $line = sprintf( "%-8d %-6s %s", $distinctwords{$_}, '', $_ );
                $multiwclistbox->insert( 'end', $line );
            }
        }
    } elsif ( $sortorder eq 'l' ) {
        for ( ::natural_sort_length( keys %distinctwords ) ) {
            unless ( $seenwordslang{$_} ) {
                my $line = sprintf( "%-8d %-6s %s", $distinctwords{$_}, '', $_ );
                $multiwclistbox->insert( 'end', $line );
            }
        }
    }
    $multiwclistbox->delete('0');
    $multiwclistbox->insert( '0', $savedHeader );
    $multiwclistbox->update;
}

sub showspeltforeignwords {
    $multiwclistbox->delete( '0', 'end' );
    $multiwclistbox->insert( 'end', 'Please wait, sorting list....' );
    $multiwclistbox->update;
    my $i = 0;
    if ( $sortorder eq 'f' ) {
        for ( ::natural_sort_freq( \%distinctwords ) ) {
            if (   ( $seenwordslang{$_} )
                && ( $seenwordslang{$_} ne $::multidicts[0] ) ) {
                my $line = sprintf( "%-8d %-6s %s", $distinctwords{$_}, $seenwordslang{$_}, $_ );
                $multiwclistbox->insert( 'end', $line );
                $i++;
            }
        }
    } elsif ( $sortorder eq 'a' ) {
        for ( ::natural_sort_alpha( keys %distinctwords ) ) {
            if (   ( $seenwordslang{$_} )
                && ( $seenwordslang{$_} ne $::multidicts[0] ) ) {
                my $line = sprintf( "%-8d %-6s %s", $distinctwords{$_}, $seenwordslang{$_}, $_ );
                $multiwclistbox->insert( 'end', $line );
                $i++;
            }
        }
    } elsif ( $sortorder eq 'l' ) {
        for ( ::natural_sort_length( keys %distinctwords ) ) {
            if (   ( $seenwordslang{$_} )
                && ( $seenwordslang{$_} ne $::multidicts[0] ) ) {
                my $line = sprintf( "%-8d %-6s %s", $distinctwords{$_}, $seenwordslang{$_}, $_ );
                $multiwclistbox->insert( 'end', $line );
                $i++;
            }
        }
    }

    if ($unspeltwordcount) {
        $savedHeader = "Spelt words: $speltwordcount, Spelt foreign words: $i\n";
    } else {
        $savedHeader = "No spelling undertaken!";
    }
    $multiwclistbox->delete('0');
    $multiwclistbox->insert( '0', $savedHeader );
    $multiwclistbox->update;
}

# update global lists
sub updategloballists {
    $::lglobal{seenwords}      = ();
    $::lglobal{misspelledlist} = ();
    $::lglobal{spellsort}      = ();
    for my $key ( sort ( keys %distinctwords ) ) {
        $::lglobal{seenwords}{$key} = $distinctwords{$key};
        unless ( $seenwordslang{$key} ) {
            push @{ $::lglobal{misspelledlist} }, $key;
            push @{ $::lglobal{spellsort} },      $key;
        }
    }
}

#show project dictionary
sub showprojectdict {
    $savedHeader = "Project Dictionary:";
    $multiwclistbox->delete( '0', 'end' );
    $multiwclistbox->insert( 'end', 'Please wait, sorting list....' );
    $multiwclistbox->update;
    ::spellloadprojectdict();
    my $i = 0;
    for my $key ( sort ( keys %::projectdict ) ) {
        $i++;
        my $line = sprintf( "%-8s %-6s %s", $::projectdict{$key}, '', $key );
        $multiwclistbox->insert( 'end', $line );
    }
    $savedHeader = "Project Dictionary: $i words";
    $multiwclistbox->delete('0');
    $multiwclistbox->insert( '0', $savedHeader );
    $multiwclistbox->update;
}

#update all counts
sub getwordcounts {
    my $i = 0;
    my $j = 0;
    my $k = 0;
    my $l = 0;
    my $m = 0;
    if (%distinctwords) {
        for my $key ( keys %distinctwords ) {
            $i++;
            $j += $distinctwords{$key};
        }
    }
    $distinctwordcount = $i;
    $totalwordcount    = $j;
    if (%seenwordslang) {
        for my $key ( keys %distinctwords ) {
            if ( $seenwordslang{$key} ) { $k++; }
        }
    }
    $speltwordcount   = $k;
    $unspeltwordcount = $i - $k;
    if ( $::lglobal{misspelledlist} ) {
        foreach ( @{ $::lglobal{misspelledlist} } ) {
            $m++;
        }
    }
}

#updates the dictionary display
sub updateMultiDictEntry {
    $multidictentry->delete( '0', 'end' );
    for my $element (@::multidicts) {
        $multidictentry->insert( 'end', $element );
        $multidictentry->insert( 'end', ' ' );
    }
}

# set multiple languages in array @multidicts
sub setmultiplelanguages {
    my ( $textwindow, $top ) = @_;
    if ($::globalspellpath) {
        ::aspellstart() unless $::lglobal{spellpid};
    }
    $::multidicts[0] = $::globalspelldictopt;
    my $dicts;
    my $spellop = $top->DialogBox(
        -title   => 'Multiple language selection',
        -buttons => ['OK']
    );
    $spellop->Icon( -image => $::icon );
    my $baselanglabel = $spellop->add( 'Label', -text => 'Base language' )->pack;
    my $baselang      = $spellop->add(
        'ROText',
        -width      => 40,
        -height     => 1,
        -background => $::bkgcolor
    )->pack( -pady => 4 );
    $baselang->delete( '1.0', 'end' );
    $baselang->insert( '1.0', $::globalspelldictopt );
    my $dictlabel = $spellop->add( 'Label', -text => 'Dictionary files' )->pack;
    my $dictlist  = $spellop->add(
        'ScrlListbox',
        -scrollbars => 'e',
        -selectmode => 'browse',
        -background => $::bkgcolor,
        -height     => 10,
        -width      => 40,
    )->pack( -pady => 4 );
    my $multidictlabel = $spellop->add( 'Label', -text => 'Additional Dictionary (ies)' )->pack;
    my $multidictxt    = $spellop->add(
        'ROText',
        -width      => 40,
        -height     => 1,
        -background => $::bkgcolor
    )->pack( -pady => 4 );
    $multidictxt->delete( '1.0', 'end' );

    for my $element (@::multidicts) {
        $multidictxt->insert( 'end', $element );
        $multidictxt->insert( 'end', ' ' );
    }
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
            my $selection = $dictlist->get('active');
            push @::multidicts, $selection;
            $multidictxt->delete( '1.0', 'end' );
            for my $element (@::multidicts) {
                $multidictxt->insert( 'end', $element );
                $multidictxt->insert( 'end', ' ' );
            }
            ::savesettings();
        }
    );
    my $clearmulti = $spellop->add(
        'Button',
        -text    => 'Clear dictionaries',
        -width   => 12,
        -command => sub {
            clearmultilanguages();
            $multidictxt->delete( '1.0', 'end' );
            for my $element (@::multidicts) {
                $multidictxt->insert( 'end', $element );
                $multidictxt->insert( 'end', ' ' );
            }
        }
    )->pack;
    my $freqframe = $spellop->add('Frame')->pack( -side => 'top', -padx => 5, -pady => 3 );

    my $minfreqlabel = $freqframe->Label(
        -width => 25,
        -text  => 'Min frequency for auto-addition',
    )->pack( -side => 'left' );
    my $minfreqcell = $freqframe->Entry(
        -width        => 6,
        -background   => $::bkgcolor,
        -relief       => 'sunken',
        -textvariable => \$minfreq,
    )->pack( -side => 'left' );
    $spellop->Show;
}

# clear array of languages
sub clearmultilanguages {
    @::multidicts = ();
    $::multidicts[0] = $::globalspelldictopt;
}

# create hash %seenwordslang
sub createseenwordslang {
    my ( $textwindow, $top ) = @_;
    @orderedwords      = ();
    $distinctwordcount = 0;
    $speltwordcount    = 0;
    %seenwordslang     = ();
    %seenwordslc       = ();
    $top->Busy( -recurse => 1 );
    $multiwclistbox->focus;
    $multiwclistbox->delete( '0', 'end' );
    $multiwclistbox->insert( 'end', 'Please wait, building word list....' );
    $totalwordcount = buildwordlist($textwindow);

    for my $key ( keys %distinctwords ) {
        $seenwordslang{$key} = undef;
    }
    my $i = 0;

    # ordered list of all words
    foreach ( sort ( keys %distinctwords ) ) { $orderedwords[ $i++ ] = $_; }

    # hash of all words -> lc (word)
    foreach ( keys %distinctwords ) { $seenwordslc{$_} = lc($_); }
    updategloballists();
    getwordcounts();
    $multiwclistbox->delete('0');
    $savedHeader = "Total words: $totalwordcount, Distinct words: $distinctwordcount\n";
    $multiwclistbox->insert( '0', $savedHeader );
    $multiwclistbox->update;
    $top->Unbusy;
}

# build lists of wordsn
sub buildwordlist {
    my $textwindow = shift;
    my ( @words, $match, @savesets );
    my $index = '1.0';
    my $wc    = 0;
    my $end   = $textwindow->index('end');
    %distinctwords = ();
    my $filename = $textwindow->FileName;
    unless ($filename) {
        $filename = 'tempfile.tmp';
        open( my $file, ">", "$filename" );
        my ($lines) = $textwindow->index('end - 1 chars') =~ /^(\d+)\./;
        while ( $textwindow->compare( $index, '<', 'end' ) ) {
            my $end  = $textwindow->index("$index  lineend +1c");
            my $line = $textwindow->get( $index, $end );
            print $file $line;
            $index = $end;
        }
    }
    ::savefile()
      if ( ( $textwindow->FileName )
        && ( $textwindow->numberChanges != 0 ) );
    open my $fh, '<', $filename;
    my $lastwordseen = '';

    # starts here
    while ( my $line = <$fh> ) {
        utf8::decode($line);
        next if $line =~ m/^-----*\s?File:\s?\S+\.(png|jpg)---/;
        $line         =~ s/_/ /g;                                  # underscores to spaces
        $line         =~ s/<!--//g;                                # remove comment starts
        $line         =~ s/-->//g;                                 # remove comment ends

        $line =~ s/['^\.,\*-]/ /g;                                 # get rid of nonalphanumeric
        $line =~ s/\P{Alnum}/ /g;
        $line =~ s/--/ /g;                                         # get rid of --
        $line =~ s/—/ /g;                                          # trying to catch words with real em-dashes, from dp2rst
        $line =~ s/(\D),/$1 /g;                                    # throw away comma after non-digit
        $line =~ s/,(\D)/ $1/g;                                    # and before
        @words = split( /\s+/, $line );

        for my $word (@words) {
            $word =~ s/ //g;
            if ( length($word) == 0 ) { next; }
            $word =~ s/[\.',-]+$//;    # throw away punctuation at end
            $word =~ s/^[\.,'-]+//;    #and at the beginning
            next if ( $word eq '' );
            $wc++;
            $distinctwords{$word}++;
        }
        $index++;
        $index .= '.0';
        $textwindow->update;
    }
    close $fh;
    unlink 'tempfile.tmp' if ( -e 'tempfile.tmp' );
    $totalwordcount = $wc;
    return $wc;
}

#spelling control routine
sub multilingualgetmisspelled {
    my ( $textwindow, $top ) = @_;
    $::lglobal{misspelledlist} = ();
    my $words;
    my $wordw = 0;
    my $line;
    $top->Busy( -recurse => 1 );
    for my $dict (@::multidicts) {
        $words = '';
        my $i = 0;

        # only include words with undef language
        foreach ( sort ( keys %distinctwords ) ) {
            unless ( $seenwordslang{$_} ) {
                $words .= "$_\n";
                $i++;
            }
        }
        $unspeltwordcount = $i;
        $speltwordcount   = $distinctwordcount - $unspeltwordcount;
        $line             = "Dictionary: $dict, Words to spell: $unspeltwordcount";
        $multiwclistbox->insert( 'end', $line );

        #spellcheck
        if ($words) { getmisspelledwordstwo( $dict, $words ); }
        processmisspelledwords( $dict, @templist );

        #update global spelllists
    }
    updategloballists();
    getwordcounts();
    $top->Unbusy;
    return $wordw;
}

#Aspell check routine
#input $dict, $section
sub getmisspelledwordstwo {
    $::lglobal{misspelledlist} = ();
    my $dict    = shift;
    my $section = shift;
    my $word;
    @templist = ();
    open my $save, '>:bytes', 'checkfil.txt';
    utf8::encode($section);
    print $save $section;
    close $save;
    my @spellopt = ( "list", "--encoding=utf-8" );
    push @spellopt, "-d", $dict;
    my $runner = runner::withfiles( 'checkfil.txt', 'temp.txt' );
    $runner->run( $::globalspellpath, @spellopt );
    unlink 'checkfil.txt';    # input file for Aspell
    open my $infile, '<', 'temp.txt';
    my ( $ln, $tmp );

    while ( $ln = <$infile> ) {
        $ln =~ s/\r\n/\n/;
        chomp $ln;
        utf8::decode($ln);
        push( @templist, $ln );
    }
    close $infile;
    unlink 'temp.txt'         # output file of unspelt words from Aspell
}

#post Aspell routine
#update %seenwordslang depending on spelling
#input $dict, @templist
sub processmisspelledwords {
    my $dict         = shift;
    my @startunspelt = ();
    my @endunspelt   = ();
    my $j            = 0;
    my $i            = 0;
    my $compare;
    my $line;

    # ordered list of all unspelt words
    foreach ( sort (@templist) ) { $startunspelt[ $j++ ] = $_; }
    $unspeltwordcount = $j;
    $line             = "Unspelt words from Aspell: $unspeltwordcount";
    $multiwclistbox->insert( 'end', $line );

    #match words and update
    $i = 0;
    $j = 0;
    while ( ( $i < $distinctwordcount ) and ( $j < $unspeltwordcount ) ) {
        $compare = ( $orderedwords[$i] cmp $startunspelt[$j] );
        if ( $compare == -1 ) {    # spelt word
            $seenwordslang{ $orderedwords[$i] } = $dict
              unless ( $seenwordslang{ $orderedwords[$i] } );
            $i++;
        } elsif ( $compare == 0 ) {    # unspelt word
            $i++;
            $j++;
        } else {                       # new word not in seenwords
            $j++;
        }
    }
    getwordcounts();

    $line = "Total words spelt: $speltwordcount";
    $multiwclistbox->insert( 'end', $line );
    $multiwclistbox->update;
}

# includes all projectdict words as spelt
sub includeprojectdict {
    my ( $textwindow, $top ) = @_;
    my $i = 0;
    $top->Busy( -recurse => 1 );
    ::spellloadprojectdict();
    for my $key ( keys %::projectdict ) {
        unless ( $seenwordslang{$key} ) {
            $seenwordslang{$key} = 'user';
            $i++;
        }
    }
    my $line = "$i additional words from project dictionary";
    $multiwclistbox->delete( '0', 'end' );
    $multiwclistbox->insert( 'end', $line );
    $multiwclistbox->update;
    updategloballists();
    getwordcounts();
    $top->Unbusy;
}

#add all spelt foreign words to project dictionary
sub addspeltforeignproject {
    ::spellloadprojectdict();
    my $i = 0;
    for my $key ( sort ( keys %distinctwords ) ) {
        if (   ( $seenwordslang{$key} )
            && ( $seenwordslang{$key} ne $::multidicts[0] )
            && ( $seenwordslang{$key} ne 'user' ) ) {
            $::projectdict{$key} = $seenwordslang{$key};
            $i++;
        }
    }

    my $section = "\%projectdict = (\n";
    for my $key ( sort keys %::projectdict ) {
        $key =~ s/'/\\'/g;
        $section .= "'$key' => '',\n";
    }
    $section .= ");";
    utf8::encode($section);
    open my $save, '>:bytes', $::lglobal{projectdictname};
    print $save $section;
    close $save;
    my $line = "$i words added to project dictionary";
    $multiwclistbox->delete( '0', 'end' );
    $multiwclistbox->insert( 'end', $line );
    $multiwclistbox->update;
    updategloballists();
    getwordcounts();
}

#add words above minfreq to project dictionary
sub addminfreqproject {
    ::spellloadprojectdict();
    my $i = 0;
    for my $key ( keys %distinctwords ) {
        unless ( $seenwordslang{$key} ) {
            if ( $distinctwords{$key} >= $minfreq ) {
                $::projectdict{$key} = 'freq';
                $seenwordslang{$key} = 'freq';
                $i++;
            }
        }
    }

    my $section = "\%projectdict = (\n";
    for my $key ( sort keys %::projectdict ) {
        $key =~ s/'/\\'/g;
        $section .= "'$key' => '',\n";
    }
    $section .= ");";
    utf8::encode($section);
    open my $save, '>:bytes', $::lglobal{projectdictname};
    print $save $section;
    close $save;
    my $line = "$i words added to project dictionary";
    $multiwclistbox->delete( '0', 'end' );
    $multiwclistbox->insert( 'end', $line );
    $multiwclistbox->update;
    updategloballists();
    getwordcounts();
}

sub lowergetmisspelled {
    my ( $textwindow, $top ) = @_;

    #	$::lglobal{misspelledlist}= ();
    $top->Busy( -recurse => 1 );
    for my $dict (@::multidicts) {
        my $words     = '';
        my %unspelt   = ();
        my %lcunspelt = ();
        my $i         = 0;
        foreach ( keys %distinctwords ) {
            unless ( $seenwordslang{$_} ) {
                $unspelt{$_}   = undef;
                $lcunspelt{$_} = lc($_);
                $words .= "$lcunspelt{$_}\n";
                $i++;
            }
        }
        print "to spell $i, dict $dict\n";
        if ($words) { getmisspelledwordstwo( $dict, $words ); }
        my $j = 0;
        my $k = 0;
        $i = 0;
        for my $keya (@templist) {
            $i++;
            for my $keyb ( keys %lcunspelt ) {
                $j++;
                if ( $keya eq $lcunspelt{$keyb} ) {
                    $unspelt{$keyb} = 'unspelt';
                    $k++;
                }
            }
        }
        print "returned words $i\n";
        print "iterations $j\n";
        print "unspelt $k\n";
        $i = 0;
        $j = 0;
        $k = 0;
        for my $key (%distinctwords) {
            $i++;
            unless ( $seenwordslang{$key} ) {
                $j++;
                unless ( $unspelt{$key} ) {
                    $seenwordslang{$key} = 'case';
                    $k++;
                }
            }
        }
        print "distinct words $i\n";
        print "unspelt $j\n";
        print "new spelt words $k\n";
    }
    updategloballists();
    getwordcounts();
    $top->Unbusy;
}

sub multi_help_popup {
    my $top  = shift;
    my $text = <<EOM;
Multilingual spellchecking help:

Aspell interactive spell-checking ignores words from the project dictionary.
This popup allows you to pre-populate the project dictionary with a number of words that
do not need to be further spell-checked.

1. Set Base Language:   Select the base language that is used.

2. Set Languages:       Select one or more foreign languages for additional spell-checking.
Also set minimum frequency for automatic addition of words to project dictionary.

3. (Re)create Wordlist: Identify all distinct words and word counts.

4. Check spelling:
Spell-check in all selected languages.  Note that some unicode words currently appear 
as spelt in the base language. Aspell currently does not handle these words correctly.

5. Include project words:
Amend unspelt words which occur in the project dictionary with the language tag 'user'. Note
that dictionary files have now been given filenames so that two or more volumes labelled 
abc1.txt and abc2.txt in the same directory will share the same project dictionary abc.dic.

Show all words:
Shows all the distinct words together with their frequency, and if available, language 
in which they are correctly spelt.

Show unspelt words:
Shows all words which have not yet been spelt in any language nor are included 
in the project dictionary.

Show spelt foreign words:
Shows all words that have been spelt, other than those in the base language.

Show project dictionary:
Shows all words in the project dictionary.

6. Add foreign to project:  Adds all words that have been correctly spelt in languages other 
than the base language to the project dictionary.

7. Add frequent to project:  Adds all words with a frequency more than or equal to the minimum
frequency to the project dictionary.
EOM
    if ( defined( $::lglobal{multihelppop} ) ) {
        $::lglobal{multihelppop}->deiconify;
        $::lglobal{multihelppop}->raise;
        $::lglobal{multihelppop}->focus;
    } else {
        $::lglobal{multihelppop} = $top->Toplevel;

        $::lglobal{multihelppop}->title('Multilingual help');
        ::initialize_popup_with_deletebinding('multihelppop');
        $::lglobal{multihelppop}->Label(
            -justify => "left",
            -text    => $text
        )->pack;
        $::lglobal{multihelppop}->Button(
            -text    => 'OK',
            -command => sub {
                $::lglobal{multihelppop}->destroy;
                undef $::lglobal{multihelppop};
            }
        )->pack( -pady => 6 );
        $::lglobal{multihelppop}->resizable( 'no', 'no' );
        $::lglobal{multihelppop}->raise;
        $::lglobal{multihelppop}->focus;
    }
}

1;
