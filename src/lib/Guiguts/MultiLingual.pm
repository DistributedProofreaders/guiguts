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
my $debug = 0;    # debug set for now

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
my $multihelppop;
my $minfreq = 5;

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
        $::lglobal{multispellpop}->Icon( -image => $::icon );

        #new frame
        my $f2 = $::lglobal{multispellpop}->Frame->pack( -side => 'top', -anchor => 'n' );

        #new label
        my $labelone =
          $f2->Label( -text => 'Dictionaries selected:' )
          ->grid( -row => 1, -column => 1, -padx => 1, -pady => 1 );

        #new entry
        $multidictentry = $f2->Entry(
            -background => $::bkgcolor,
            -width      => 40,
            -font       => $::lglobal{font},
        )->grid( -row => 1, -column => 2, -padx => 1, -pady => 1 );
        my $f0 = $::lglobal{multispellpop}->Frame->pack( -side => 'top', -anchor => 'n' );

        #new button
        $f0->Button(
            -activebackground => $::activecolor,
            -command          => sub {
                setmultiplelanguages( $textwindow, $top );
                updateMultiDictEntry();
            },
            -text  => 'Set Languages',
            -width => 20
        )->grid( -row => 1, -column => 2, -padx => 1, -pady => 1 );
        $f0->Button(
            -activebackground => $::activecolor,
            -command          => sub {
                ::spelloptions();
                clearmultilanguages();
                updateMultiDictEntry();
            },
            -text  => 'Set Base Language',
            -width => 20
        )->grid( -row => 1, -column => 1, -padx => 1, -pady => 1 );
        $f0->Button(
            -activebackground => $::activecolor,
            -command          => sub { createseenwordslang( $textwindow, $top ) },
            -text             => '(Re)create Wordlist',
            -width            => 20
        )->grid( -row => 2, -column => 1, -padx => 1, -pady => 1 );
        $f0->Button(
            -activebackground => $::activecolor,
            -command          => sub { multilingualgetmisspelled( $textwindow, $top ) },
            -text             => 'Check spelling',
            -width            => 20
        )->grid( -row => 2, -column => 2, -padx => 1, -pady => 1 );
        $f0->Button(
            -activebackground => $::activecolor,
            -command          => sub { includeprojectdict( $textwindow, $top ) },
            -text             => 'Include project words',
            -width            => 20
        )->grid( -row => 2, -column => 3, -padx => 1, -pady => 1 );
        $f0->Button(
            -activebackground => $::activecolor,
            -command          => sub { saveLangDebugFiles() },
            -text             => 'Save Debug Files',
            -width            => 20
        )->grid( -row => 5, -column => 1, -padx => 1, -pady => 1 );
        $f0->Button(
            -activebackground => $::activecolor,
            -command          => sub { showAllWords() },
            -text             => 'Show all words',
            -width            => 20
        )->grid( -row => 3, -column => 1, -padx => 1, -pady => 1 );
        $f0->Button(
            -activebackground => $::activecolor,
            -command          => sub { showUnspeltWords() },
            -text             => 'Show unspelt words',
            -width            => 20
        )->grid( -row => 3, -column => 2, -padx => 1, -pady => 1 );
        $f0->Button(
            -activebackground => $::activecolor,
            -command          => sub { showspeltforeignwords() },
            -text             => 'Show spelt foreign words',
            -width            => 20
        )->grid( -row => 3, -column => 3, -padx => 1, -pady => 1 );
        $f0->Button(
            -activebackground => $::activecolor,
            -command          => sub { showprojectdict() },
            -text             => 'Show project dictionary',
            -width            => 20
        )->grid( -row => 4, -column => 1, -padx => 1, -pady => 1 );
        $f0->Button(
            -activebackground => $::activecolor,
            -command          => sub { addspeltforeignproject() },
            -text             => 'Add foreign to project',
            -width            => 20
        )->grid( -row => 4, -column => 2, -padx => 1, -pady => 1 );
        $f0->Button(
            -activebackground => $::activecolor,
            -command          => sub { addminfreqproject() },
            -text             => 'Add frequent to project',
            -width            => 20
        )->grid( -row => 4, -column => 3, -padx => 1, -pady => 1 );

        #		$f0->Button(
        #					-activebackground => $::activecolor,
        #					-command => sub { lowergetmisspelled( $textwindow, $top ) },
        #					-text    => 'Lower case spellcheck',
        #					-width   => 20
        #		)->grid( -row => 5, -column => 3, -padx => 1, -pady => 1 );
        $f0->Button(
            -activebackground => $::activecolor,
            -command          => sub { multi_help_popup($top) },
            -text             => 'Help',
            -width            => 20
        )->grid( -row => 1, -column => 3, -padx => 1, -pady => 1 );
        my $f1 = $::lglobal{multispellpop}->Frame->pack( -fill => 'both', -expand => 'both', );
        $multiwclistbox = $f1->Scrolled(
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

        #		$f3->Radiobutton(
        #									   -variable    => \$sortorder,
        #									   -selectcolor => $::lglobal{checkcolor},
        #									   -value       => 'g',
        #									   -text        => 'Lang',
        #		)->pack( -side => 'left', -anchor => 'nw', -pady => 1 );
        ::drag($multiwclistbox);
        $::lglobal{multispellpop}->protocol(
            'WM_DELETE_WINDOW' => sub {
                ::killpopup('multispellpop');
                undef $multiwclistbox;
            }
        );
    }

    #	::spellloadprojectdict();
    updateMultiDictEntry();
    getwordcounts();
}

sub showAllWords {
    my $lang;
    $savedHeader = "Total words: $totalwordcount, Distinct words: $distinctwordcount\n";
    $multiwclistbox->delete( '0', 'end' );
    $multiwclistbox->insert( 'end', 'Please wait, sorting list....' );
    $multiwclistbox->update;
    if ($debug) { print $sortorder; }
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
    $multiwclistbox->yview( 'scroll', 1, 'units' );
    $multiwclistbox->update;
    $multiwclistbox->yview( 'scroll', -1, 'units' );
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
    if ($debug) { print $sortorder; }
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
    $multiwclistbox->yview( 'scroll', 1, 'units' );
    $multiwclistbox->update;
    $multiwclistbox->yview( 'scroll', -1, 'units' );
}

sub showspeltforeignwords {
    $multiwclistbox->delete( '0', 'end' );
    $multiwclistbox->insert( 'end', 'Please wait, sorting list....' );
    $multiwclistbox->update;
    my $i = 0;
    if ($debug) { print $sortorder; }
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

    #	for my $key (sort (keys %distinctwords)){
    #		if (($seenwordslang{$key}) && ($seenwordslang{$key} ne $::multidicts[0])) {
    #			my $line = sprintf ( "%-8d %-6s %s", $distinctwords{$key}, $seenwordslang{$key}, $key);
    #			$multiwclistbox->insert( 'end', $line );
    #			$i++;
    #		}
    #	};
    if ($unspeltwordcount) {
        $savedHeader = "Spelt words: $speltwordcount, Spelt foreign words: $i\n";
    } else {
        $savedHeader = "No spelling undertaken!";
    }
    $multiwclistbox->delete('0');
    $multiwclistbox->insert( '0', $savedHeader );
    $multiwclistbox->update;
    $multiwclistbox->yview( 'scroll', 1, 'units' );
    $multiwclistbox->update;
    $multiwclistbox->yview( 'scroll', -1, 'units' );
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

#obsolete
sub showmisspelledlist {
    if ($unspeltwordcount) {
        $savedHeader = "Spelt words: $speltwordcount, Unspelt words: $unspeltwordcount\n";
        $multiwclistbox->delete( '0', 'end' );
        $multiwclistbox->insert( 'end', 'Please wait, sorting list....' );
        $multiwclistbox->update;
        if ( $::lglobal{misspelledlist} ) {
            foreach ( sort @{ $::lglobal{misspelledlist} } ) {
                my $line = sprintf( "%-8d %-6s %s", $distinctwords{$_}, '', $_ );
                $multiwclistbox->insert( 'end', $line );
            }
        } else {
            $savedHeader = "No spelling undertaken";
        }
    } else {
        $savedHeader = "No spelling undertaken!";
    }
    $multiwclistbox->delete('0');
    $multiwclistbox->insert( '0', $savedHeader );
    $multiwclistbox->update;
    $multiwclistbox->yview( 'scroll', 1, 'units' );
    $multiwclistbox->update;
    $multiwclistbox->yview( 'scroll', -1, 'units' );
}

#show project dictionary
sub showprojectdict {
    $savedHeader = "Project Dictionary:";
    $multiwclistbox->delete( '0', 'end' );
    $multiwclistbox->insert( 'end', 'Please wait, sorting list....' );
    $multiwclistbox->update;
    ::spellloadprojectdict();
    if ($debug) { print "$::lglobal{projectdictname}\n"; }
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
    $multiwclistbox->yview( 'scroll', 1, 'units' );
    $multiwclistbox->update;
    $multiwclistbox->yview( 'scroll', -1, 'units' );
}

# outputs various arrays to files
sub saveLangDebugFiles {
    my $section;
    my $save;
    my $i;
    print "\$globalspellpath ", $::globalspellpath, "\n";
    print "saving lglobal_seenwords.txt - distinct words and frequencies\n";
    $section = "\%lglobal{seenwords}\n";
    open $save, '>:bytes', 'lglobal_seenwords.txt';
    for my $key ( keys %distinctwords ) {
        $section .= "$key => $distinctwords{$key}\n";
    }
    utf8::encode($section);
    print $save $section;
    close $save;
    print "saving lglobal_misspelledlist.txt - global misspelledlist\n";
    $section = "\@lglobal{misspelledlist}\n";
    open $save, '>:bytes', 'lglobal_misspelledlist.txt';
    if ( $::lglobal{misspelledlist} ) {

        foreach ( sort @{ $::lglobal{misspelledlist} } ) {
            $section .= "$_\n";
        }
    }
    utf8::encode($section);
    print $save $section;
    close $save;

    #debugging
    #	$section = "\%seenwordslc\n";
    #	open $save, '>:bytes', 'seenwordslc.txt';
    #	for my $key (keys %seenwordslc){
    #		$section .= "$key => $seenwordslc{$key}\n";
    #	};
    #	utf8::encode($section);
    #	print $save $section;
    #	close $save;
    print "saving seenwordslang.txt - distinct words and spelt language\n";
    $section = "\%seenwordslang\n";
    open $save, '>:bytes', 'seenwordslang.txt';
    for my $key ( sort ( keys %seenwordslang ) ) {
        if ( $seenwordslang{$key} ) {
            $section .= "$key => $seenwordslang{$key}\n";
        } else {
            $section .= "$key x=>\n";
        }
    }
    utf8::encode($section);
    print $save $section;
    close $save;
    print "saving seenwordslang_unspelt.txt - distinct unspelt words\n";
    $section = "\%seenwordslang unspelt\n";
    $i       = 0;
    open $save, '>:bytes', 'seenwordslang_unspelt.txt';

    for my $key ( sort ( keys %distinctwords ) ) {
        unless ( $seenwordslang{$key} ) {
            $section .= "$key x=>\n" unless ( $seenwordslang{$key} );
            $i++;
        }
    }
    utf8::encode($section);
    print $save $section;
    close $save;
    print "saving seenwordslang_spelt.txt - distinct spelt words\n";
    $section = "\%seenwordslang spelt\n";
    $i       = 0;
    open $save, '>:bytes', 'seenwordlang_spelt.txt';

    for my $key ( sort ( keys %distinctwords ) ) {
        if ( $seenwordslang{$key} ) {
            $section .= "$key => $seenwordslang{$key}\n";
            $i++;
        }
    }
    utf8::encode($section);
    print $save $section;
    close $save;
    print "saving projectdict.txt - internal project dictionary\n";
    $section = "\%projectdict\n";
    open $save, '>:bytes', 'projectdict.txt';
    for my $key ( sort ( keys %::projectdict ) ) {
        $section .= "$key => $::projectdict{$key}\n";
    }
    utf8::encode($section);
    print $save $section;
    close $save;
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
    if ($debug) {
        print "Total $totalwordcount\nDistinct $distinctwordcount\n";
        print "Spelt $speltwordcount\nUnspelt $unspeltwordcount\nMisspelt $m\n";
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
        -scrollbars => 'oe',
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

        #		$line =~ s/[^'\.,\p{Alnum}-\*]/ /g;    # get rid of nonalphanumeric
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
            $word =~ s/[\.',-]+$//;                                # throw away punctuation at end
            $word =~ s/^[\.,'-]+//;                                #and at the beginning
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
        if ($debug) {
            print "\$dict $dict, words to spell $unspeltwordcount, ";
        }

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
    unlink 'checkfil.txt' unless ($debug);    # input file for Aspell
    open my $infile, '<', 'temp.txt';
    my ( $ln, $tmp );

    while ( $ln = <$infile> ) {
        $ln =~ s/\r\n/\n/;
        chomp $ln;
        utf8::decode($ln);
        push( @templist, $ln );
    }
    close $infile;
    unlink 'temp.txt'
      unless ($debug);                        # output file of unspelt words from Aspell
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
    if ($debug) { print "$unspeltwordcount unspelt words, \n"; }

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
        } elsif ( $compare == 1 ) {    # new word not in seenwords
            if ($debug) {
                print "$startunspelt[$j] returned by Aspell but not in book!\n";
            }
            $j++;
        } else {
            print "How did I get here!!! Multilingual failure line 831\n";
        }
    }
    getwordcounts();

    #	$i = 0;
    #	for my $key (sort (keys %distinctwords)){
    #		if ($seenwordslang{$key}) { $i++; }
    #	};
    #	$speltwordcount = $i;
    #	$unspeltwordcount = $distinctwordcount - $speltwordcount;
    $line = "Total words spelt: $speltwordcount";
    $multiwclistbox->insert( 'end', $line );
    $multiwclistbox->update;
    if ($debug) { print "Total words spelt: $speltwordcount\n"; }
}

# includes all projectdict words as spelt
sub includeprojectdict {
    my ( $textwindow, $top ) = @_;
    my $i = 0;
    $top->Busy( -recurse => 1 );
    ::spellloadprojectdict();
    if ($debug) { print "$::lglobal{projectdictname}\n"; }
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

    #	if ($debug) { print %::projectdict;
    #	print "\n$::lglobal{projectdictname}\n";}
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

    if ($debug) {
        print %::projectdict;
        print "\n$::lglobal{projectdictname}\n";
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

Lower case spellcheck:
Currently not working.
EOM
    if ( defined($multihelppop) ) {
        $multihelppop->deiconify;
        $multihelppop->raise;
        $multihelppop->focus;
    } else {
        $multihelppop = $top->Toplevel;

        #		::initialize_popup_with_deletebinding('aboutpop');
        $multihelppop->title('Mutilingual help');
        $multihelppop->Label(
            -justify => "left",
            -text    => $text
        )->pack;
        my $button_ok = $multihelppop->Button(
            -activebackground => $::activecolor,
            -text             => 'OK',
            -command          => sub {
                $multihelppop->destroy;
                undef $multihelppop;
            }
        )->pack( -pady => 6 );
        $multihelppop->resizable( 'no', 'no' );
        $multihelppop->raise;
        $multihelppop->focus;
    }
}

1;
__END__

=head1 NAME

	Guiguts::MultiLingual - spellcheck in multiple languages

=head1 USAGE

=head2 setmultiplelanguages

	fills array @multidicts with languages to be used

=head1 PLAN

	Variables: base_lang eg 'en'
		   additional_lang eg 'fr', 'la'
	array wordlist => word, (distinct words in book) - already keys in hash lglobal{seenwords}
	  => frequency, (count of words in book) - already values in hash lglobal{seenwords}
	  => language, (language spelt in, eg en, or user, or undef) - new hash %seenwordslang

	A: set languages - DONE
	B: Process  file as per word frequency into array wordlist
		filling frequency and word - DONE
	C: Aspell wordlist where language undef using base_lang
	D: Diff Aspell output with wordlist and
		set language = base_lang for all words not in output
		ie correctly spelt
	E: Repeat (C) where language undef using additional_lang[1]
	F: Repeat (D) setting language = additional_lang[1] where spelt
	G: Repeat E/F for all additional_lang
	H: consider saving wordlist to file
	I: option to add non-base_lang spelt words to project.dic
	J: option to update wordlist language = user for all words in project.dic
	K: display outputs (wordlist) in word frequency window with (frequency)
		and ability to switch between - undef / user / base / spelt
		and ability to alter language values

=cut

