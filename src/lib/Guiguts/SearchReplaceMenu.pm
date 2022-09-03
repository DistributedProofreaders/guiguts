package Guiguts::SearchReplaceMenu;
use strict;
use warnings;

BEGIN {
    use Exporter();
    our ( @ISA, @EXPORT );
    @ISA    = qw(Exporter);
    @EXPORT = qw(&update_sr_histories &searchtext &reg_check &getnextscanno &updatesearchlabels
      &isvalid &swapterms &findascanno &reghint &replace &replaceall
      &searchfromstartifnew &searchoptset &searchpopup &stealthscanno &find_proofer_comment
      &find_asterisks &find_transliterations &orphanedbrackets &orphanedmarkup &searchsize
      &loadscannos &replace_incr_counter &countmatches &setsearchpopgeometry &quickcount);
}

# Update both the search and replace histories from their dialog fields
sub update_sr_histories {
    return if $::scannosearch;
    ::add_entry_history( $::lglobal{searchentry}->get,  \@::search_history );
    ::add_entry_history( $::lglobal{replaceentry}->get, \@::replace_history );
}

sub searchtext {
    my $searchterm      = shift;
    my $silentmode      = shift;                                  # 1 = don't update main window; 2 = total silence for counting only
    my $silentcountmode = ( $silentmode and $silentmode == 2 );
    my $textwindow      = $::textwindow;
    my $top             = $::top;
    ::hidepagenums();

    # $::sopt[0] --> 0 = pattern search               1 = whole word search
    # $::sopt[1] --> 0 = case sensitive               1 = case insensitive search
    # $::sopt[2] --> 0 = search forwards              1 = search backwards
    # $::sopt[3] --> 0 = normal search term           1 = regex search term - 3 and 0 are mutually exclusive
    # $::sopt[4] --> 0 = search from last index       1 = Start from beginning
    #	$::searchstartindex--where the last search for this $searchterm ended
    #   replaced with the insertion point if the user has clicked someplace else
    $searchterm = '' unless defined $searchterm;
    $::lglobal{lastsearchterm} = 'stupid variable needs to be initialized'
      unless length( $::lglobal{lastsearchterm} );
    $textwindow->tagRemove( 'highlight', '1.0', 'end' )
      if $::searchstartindex and not $silentcountmode;
    my ( $start, $end );
    my $foundone    = 1;
    my @ranges      = $textwindow->tagRanges('sel');
    my $range_total = @ranges;
    $::searchstartindex = $textwindow->index('insert')
      unless $::searchstartindex;
    my $searchstartingpoint = $silentcountmode ? $::searchstartindex : $textwindow->index('insert');

    # to avoid next search finding same match
    my $stepforward = '+1c';

    # this is starting a search within a selection
    if ( $range_total > 0 ) {
        $end                        = pop(@ranges);
        $start                      = pop(@ranges);
        $::lglobal{selectionsearch} = $end;
        $::searchstartindex         = $end if $::sopt[2];

        # don't skip first character if counting in selection or may miss first occurrence
        $stepforward = '' if $silentcountmode;

        # this is continuing a search within a selection
    } elsif ( $::lglobal{selectionsearch} ) {
        $start = $silentcountmode ? $::searchstartindex : $textwindow->index('insert');
        $end   = $::lglobal{selectionsearch};

        # this is a search through end/start of the document
    } else {
        $start = $silentcountmode ? $::searchstartindex : $textwindow->index('insert');
        $end   = $::sopt[2]       ? '1.0'               : 'end';
    }

    # this is user requesting Start at Beginning (End if reverse)
    if ( $::sopt[4] ) {
        $start = $::sopt[2] ? 'end' : '1.0';
        $end   = $::sopt[2] ? '1.0' : 'end';
        $::lglobal{searchop4}->deselect if ( defined $::lglobal{searchpop} );
        $::lglobal{lastsearchterm} = "resetresetreset";
    }

    if ( $::sopt[2] ) {    # if backwards
        $::searchstartindex = $start;
    } else {

        # continued forward search begins +1c or next search would find the same match
        $::searchendindex = $start . $stepforward;
    }

    # use the string in the dialog search field if none passed in as an argument
    $searchterm = $::lglobal{searchentry}->get if $searchterm eq '';
    return ('') unless length($searchterm);
    if ( $::sopt[3] ) {
        unless ( ::isvalid($searchterm) ) {
            badreg();
            return;
        }
    }

    # if this is a new searchterm
    unless ( $searchterm eq $::lglobal{lastsearchterm} ) {
        $::lglobal{lastsearchterm} = $searchterm
          unless ( ( $searchterm =~ m/\\n/ ) && ( $::sopt[3] ) );
        clearmarks() if ( ( $searchterm =~ m/\\n/ ) && ( $::sopt[3] ) );
    }

    # may need to clear count label if term has changed
    countlabelclear($searchterm) unless $silentcountmode;

    $textwindow->tagRemove( 'sel', '1.0', 'end' );
    my $length = '0';
    my ($tempindex);

    # Can't find anything if last search ended at end of file - avoid bug regex searching for "^"
    if ( $textwindow->compare( $::searchendindex, '>=', 'end-1c' ) ) {
        $::searchstartindex = 0;
    } else {

        # Search across line boundaries with regexp "this\nand"
        if ( ( $searchterm =~ m/\\n/ ) && ( $::sopt[3] ) ) {
            unless ( $searchterm eq $::lglobal{lastsearchterm} ) {
                {
                    $top->Busy;

                    # have to search on the whole file
                    my $wholefile = $textwindow->get( '1.0', $end );

                    # search is case sensitive if $::sopt[1] is set
                    # Note that regex match options "sm" are needed here and when handling ()/$ grouping
                    # in sub replaceeval. These options should match or weird behaviour will ensue.
                    # The "g" option is only required here, and finds all matches of the searchterm
                    # within the file via the while loop
                    if ( $::sopt[1] ) {
                        while ( $wholefile =~ m/$searchterm/smgi ) {
                            push @{ $::lglobal{nlmatches} }, [ $-[0], ( $+[0] - $-[0] ) ];
                        }
                    } else {
                        while ( $wholefile =~ m/$searchterm/smg ) {
                            push @{ $::lglobal{nlmatches} }, [ $-[0], ( $+[0] - $-[0] ) ];
                        }
                    }
                    $top->Unbusy;
                }
                my $matchidx = 0;
                my $lineidx  = 1;
                my $matchacc = 0;
                foreach my $match ( @{ $::lglobal{nlmatches} } ) {
                    while (1) {
                        my $linelen =
                          length( $textwindow->get( "$lineidx.0", "$lineidx.end" ) ) + 1;
                        last if ( ( $matchacc + $linelen ) > $match->[0] );
                        $matchacc += $linelen;
                        $lineidx++;
                    }
                    $matchidx++;
                    my $offset = $match->[0] - $matchacc;
                    $textwindow->markSet( "nls${matchidx}q" . $match->[1], "$lineidx.$offset" );
                }
                $::lglobal{lastsearchterm} = $searchterm;
            }
            my $mark;
            if ( $::sopt[2] ) {
                $mark = getmark($::searchstartindex);
            } else {
                $mark = getmark($::searchendindex);
            }
            while ($mark) {
                if ( $mark =~ /nls\d+q(\d+)/ ) {
                    $length = $1;

                    $::searchstartindex = $textwindow->index($mark);
                    last;
                } else {
                    $mark = getmark($mark) if $mark;
                    next;
                }
            }
            $::searchstartindex        = 0       unless $mark;
            $::lglobal{lastsearchterm} = 'reset' unless $mark;
        } else {    # not a search across line boundaries
            my $exactsearch = $searchterm;
            $exactsearch = ::escape_regexmetacharacters($exactsearch);
            $searchterm  = '(?<!\p{Alnum})' . $exactsearch . '(?!\p{Alnum})'
              if $::sopt[0];
            my ( $direction, $searchstart, $mode );
            if   ( $::sopt[2] ) { $searchstart = $::searchstartindex }
            else                { $searchstart = $::searchendindex }
            if   ( $::sopt[2] ) { $direction = '-backwards' }
            else                { $direction = '-forwards' }
            if   ( $::sopt[0] or $::sopt[3] ) { $mode = '-regexp' }
            else                              { $mode = '-exact' }

            #finally we actually do some searching
            if ( $::sopt[1] ) {
                $::searchstartindex = $textwindow->search(
                    $mode, $direction, '-nocase',
                    '-count' => \$length,
                    '--', $searchterm, $searchstart, $end
                );
            } else {
                $::searchstartindex = $textwindow->search(
                    $mode, $direction,
                    '-count' => \$length,
                    '--', $searchterm, $searchstart, $end
                );
            }
        }
        if ($::searchstartindex) {
            $tempindex = $::searchstartindex;

            my ( $row, $col ) = split /\./, $tempindex;

            $col += $length;
            $::searchendindex = "$row.$col" if $length;

            $::searchendindex = $textwindow->index("$::searchstartindex +${length}c")
              if ( $searchterm =~ m/\\n/ );

            $::searchendindex = $textwindow->index("$::searchstartindex +1c")
              unless $length;

            unless ($silentcountmode) {
                $textwindow->markSet( 'insert', $::searchstartindex )
                  if $::searchstartindex;    # position the cursor at the index
                $textwindow->tagAdd( 'highlight', $::searchstartindex, $::searchendindex )
                  if $::searchstartindex;    # highlight the text

                # scroll text window, to make found text visible
                unless ($silentmode) {
                    $textwindow->yviewMoveto(1);
                    $textwindow->see($::searchstartindex)
                      if ( $::searchendindex && $::sopt[2] );
                    $textwindow->see($::searchendindex)
                      if ( $::searchendindex && !$::sopt[2] );
                }
            }
            $::searchendindex = $::searchstartindex unless $length;
        }
    }
    unless ($::searchstartindex) {
        $foundone = 0;
        unless ( $::lglobal{selectionsearch} ) { $start = '1.0'; $end = 'end' }
        if     ( $::sopt[2] ) {
            $::searchstartindex = $end;

            unless ($silentcountmode) {
                $textwindow->markSet( 'insert', $::searchstartindex );
                $textwindow->see($::searchendindex) unless $silentmode;
            }
        } else {
            $::searchendindex = $start;

            unless ($silentcountmode) {
                $textwindow->markSet( 'insert', $start );
                $textwindow->see($start) unless $silentmode;
            }
        }
        $::lglobal{selectionsearch} = 0;

        # Warn user string was not found, unless auto-advancing scannos, or silent count mode
        unless ( ( $::scannosearch and $::lglobal{regaa} ) or $silentcountmode ) {
            ::soundbell('noflash');
            $::lglobal{searchbutton}->flash if defined $::lglobal{searchpop};
            $::lglobal{searchbutton}->flash if defined $::lglobal{searchpop};

            # If nothing found, return cursor to starting point
            if ($::failedsearch) {
                $::searchendindex = $searchstartingpoint;
                $textwindow->markSet( 'insert', $searchstartingpoint );
                $textwindow->see($searchstartingpoint);
            }
        }
    }
    unless ($silentmode) {
        ::updatesearchlabels();
        ::update_indicators();
    }
    return $foundone;    # return index of where found text started
}

# Use searchtext routine to find how many matches in file for search string
sub countmatches {
    my ($searchterm) = @_;
    countlabelclear($searchterm);
    return if $searchterm eq '';

    # save various global variables to restore later
    # save selection range
    my $textwindow = $::textwindow;
    my @ranges     = $textwindow->tagRanges('sel');

    # save previous start & end of found text
    my $savesearchstartindex = $::searchstartindex;
    $::searchstartindex = '1.0';
    my $savesearchendindex = $::searchendindex;

    # save whether searching backwards & set to forwards
    my $savesopt2 = $::sopt[2];
    $::sopt[2] = 0;

    # save Start at Beginning flag, because searching clears it
    my $savesopt4 = $::sopt[4];

    # save selectionsearch flag and clear it
    my $saveselectionsearch = $::lglobal{selectionsearch};
    $::lglobal{selectionsearch} = 0;

    my $count = 0;
    ++$count while searchtext( $searchterm, 2 );    # search very silently, counting matches
    $::lglobal{searchnumlabel}->configure( -text => searchnumtext($count) );

    # restore saved globals
    $::searchstartindex         = $savesearchstartindex;
    $::searchendindex           = $savesearchendindex;
    $::sopt[2]                  = $savesopt2;
    $::sopt[4]                  = $savesopt4;
    $::lglobal{selectionsearch} = $saveselectionsearch;

    # restore selection range if there was one before counting
    $textwindow->tagAdd( 'sel', shift(@ranges), shift(@ranges) ) if @ranges > 0;
}

BEGIN {    # restrict scope of $countlastterm
           # remember last term counted / searched
    my $countlastterm = '';

    # only need to clear counted label if current term is different
    sub countlabelclear {
        my $newterm = shift;
        if ( $newterm ne $countlastterm ) {
            $countlastterm = $newterm;
            $::lglobal{searchnumlabel}->configure( -text => "" ) if defined $::lglobal{searchpop};
        }
    }
}

# Set search entry box to red/black text if invalid/valid search term
# Also used as a validation routine, but always returns OK because we still want
# the text to be shown, even if it's a bad regex - user may not have finished typing
sub reg_check {
    my $term  = shift;
    my $color = ( $::sopt[3] and not ::isvalid($term) ) ? 'red' : 'black';
    $::lglobal{searchentry}->configure( -foreground => $color );
    return 1;
}

sub regedit {
    my $top    = $::top;
    my $editor = $top->DialogBox(
        -title   => 'Regex editor',
        -buttons => [ 'Save', 'Cancel' ]
    );
    my $regsearchlabel = $editor->add( 'Label', -text => 'Search Term' )->pack;
    $::lglobal{regsearch} = $editor->add(
        'Text',
        -background => $::bkgcolor,
        -width      => 40,
        -height     => 1,
    )->pack;
    my $regreplacelabel = $editor->add( 'Label', -text => 'Replacement Term' )->pack;
    $::lglobal{regreplace} = $editor->add(
        'Text',
        -background => $::bkgcolor,
        -width      => 40,
        -height     => 1,
    )->pack;
    my $reghintlabel = $editor->add( 'Label', -text => 'Hint Text' )->pack;
    $::lglobal{reghinted} = $editor->add(
        'Text',
        -background => $::bkgcolor,
        -width      => 40,
        -height     => 8,
        -wrap       => 'word',
    )->pack;
    my $buttonframe = $editor->add('Frame')->pack;
    $buttonframe->Button(
        -activebackground => $::activecolor,
        -text             => '<--',
        -command          => sub {
            $::lglobal{scannosindex}-- if $::lglobal{scannosindex};
            regload();
        },
    )->pack( -side => 'left', -pady => 5, -padx => 2, -anchor => 'w' );
    $buttonframe->Button(
        -activebackground => $::activecolor,
        -text             => '-->',
        -command          => sub {
            $::lglobal{scannosindex}++
              if $::lglobal{scannosarray}[ $::lglobal{scannosindex} ];
            regload();
        },
    )->pack( -side => 'left', -pady => 5, -padx => 2, -anchor => 'w' );
    $buttonframe->Button(
        -activebackground => $::activecolor,
        -text             => 'Add',
        -command          => \&regadd,
    )->pack( -side => 'left', -pady => 5, -padx => 2, -anchor => 'w' );
    $buttonframe->Button(
        -activebackground => $::activecolor,
        -text             => 'Del',
        -command          => \&regdel,
    )->pack( -side => 'left', -pady => 5, -padx => 2, -anchor => 'w' );
    $::lglobal{regsearch}->insert( 'end', ( $::lglobal{searchentry}->get ) )
      if $::lglobal{searchentry}->get;
    $::lglobal{regreplace}->insert( 'end', ( $::lglobal{replaceentry}->get ) )
      if $::lglobal{replaceentry}->get;
    $::lglobal{reghinted}->insert( 'end', ( $::reghints{ $::lglobal{searchentry}->get } ) )
      if $::reghints{ $::lglobal{searchentry}->get };
    my $button = $editor->Show;
    if ( defined $button and $button =~ /save/i ) {
        open my $reg, ">", "$::lglobal{scannosfilename}";
        print $reg "\%::scannoslist = (\n";
        foreach my $word ( sort ( keys %::scannoslist ) ) {
            my $srch = $word;
            $srch =~ s/([\'\\])/\\$1/g;
            my $repl = $::scannoslist{$word};
            $repl =~ s/([\'\\])/\\$1/g;
            print $reg "'$srch' => '$repl',\n";
        }
        print $reg ");\n";
        print $reg <<'EOF';

# For a hint, use the regex expression EXACTLY as it appears in the %::scannoslist hash
# but replace the replacement term (heh!) with the hint text. Note: if a single quote
# appears anywhere in the hint text, you'll need to escape it with a backslash. E.G. isn't -> isn\'t
# I could have made this more compact by converting the scannoslist hash into a two dimensional
# hash, but would have sacrificed backward compatibility.

EOF
        print $reg '%::reghints = (' . "\n";
        foreach my $word ( sort ( keys %::reghints ) ) {
            my $srch = $word;
            $srch =~ s/([\'\\])/\\$1/g;
            my $repl = $::reghints{$word};
            $repl =~ s/([\'\\])/\\$1/g;
            print $reg "'$srch' => '$repl',\n";
        }
        print $reg ");\n";
        close $reg;
    }
}

sub regload {
    my $word = '';
    $word = $::lglobal{scannosarray}[ $::lglobal{scannosindex} ];
    $::lglobal{regsearch}->delete( '1.0', 'end' );
    $::lglobal{regreplace}->delete( '1.0', 'end' );
    $::lglobal{reghinted}->delete( '1.0', 'end' );
    $::lglobal{regsearch}->insert( 'end', $word ) if defined $word;
    $::lglobal{regreplace}->insert( 'end', $::scannoslist{$word} )
      if defined $word;
    $::lglobal{reghinted}->insert( 'end', $::reghints{$word} ) if defined $word;
}

sub regadd {
    my $st = $::lglobal{regsearch}->get( '1.0', '1.end' );
    unless ( isvalid($st) ) {
        badreg();
        return;
    }
    my $rt = $::lglobal{regreplace}->get( '1.0', '1.end' );
    my $rh = $::lglobal{reghinted}->get( '1.0', 'end' );
    $rh =~ s/(?!<\\)'/\\'/;
    $rh =~ s/\n/ /;
    $rh =~ s/  / /;
    $rh =~ s/\s+$//;
    $::reghints{$st} = $rh;

    unless ( defined $::scannoslist{$st} ) {
        $::scannoslist{$st} = $rt;
        $::lglobal{scannosindex} = 0;
        @{ $::lglobal{scannosarray} } = ();
        foreach ( sort ( keys %::scannoslist ) ) {
            push @{ $::lglobal{scannosarray} }, $_;
        }
        foreach ( @{ $::lglobal{scannosarray} } ) {
            $::lglobal{scannosindex}++ unless ( $_ eq $st );
            next                       unless ( $_ eq $st );
            last;
        }
    } else {
        $::scannoslist{$st} = $rt;
    }
    regload();
}

sub regdel {
    my $word = '';
    my $st   = $::lglobal{regsearch}->get( '1.0', '1.end' );
    delete $::reghints{$st};
    delete $::scannoslist{$st};
    $::lglobal{scannosindex}--;
    @{ $::lglobal{scannosarray} } = ();
    foreach my $word ( sort ( keys %::scannoslist ) ) {
        push @{ $::lglobal{scannosarray} }, $word;
    }
    regload();
}

sub reghint {
    my $message = 'No hints for this entry.';
    my $reg     = $::lglobal{searchentry}->get;
    if ( $::reghints{$reg} ) { $message = $::reghints{$reg} }
    if ( defined( $::lglobal{hintpop} ) ) {
        $::lglobal{hintpop}->deiconify;
        $::lglobal{hintpop}->raise;
        $::lglobal{hintpop}->focus;
        $::lglobal{hintmessage}->delete( '1.0', 'end' );
        $::lglobal{hintmessage}->insert( 'end', $message );
    } else {
        $::lglobal{hintpop} = $::lglobal{searchpop}->Toplevel;
        ::initialize_popup_with_deletebinding('hintpop');
        $::lglobal{hintpop}->title('Search Term Hint');
        my $frame = $::lglobal{hintpop}->Frame->pack(
            -anchor => 'nw',
            -expand => 'yes',
            -fill   => 'both'
        );
        $::lglobal{hintmessage} = $frame->ROText(
            -width      => 40,
            -height     => 6,
            -background => $::bkgcolor,
            -wrap       => 'word',
        )->pack(
            -anchor => 'nw',
            -expand => 'yes',
            -fill   => 'both',
            -padx   => 4,
            -pady   => 4
        );
        $::lglobal{hintmessage}->insert( 'end', $message );
    }
}

sub getnextscanno {
    $::scannosearch = 1;
    ::findascanno();
    unless ( searchtext() ) {
        if ( $::lglobal{regaa} ) {
            while (1) {
                if ( $::lglobal{scannosindex}++ >= $#{ $::lglobal{scannosarray} } ) {
                    $::lglobal{scannosindex} = $#{ $::lglobal{scannosarray} };
                    last;
                }
                ::findascanno();
                last if searchtext();
            }
        }
    }
}

sub swapterms {
    my $tempholder = $::lglobal{replaceentry}->get;
    $::lglobal{replaceentry}->delete( 0, 'end' );
    $::lglobal{replaceentry}->insert( 'end', $::lglobal{searchentry}->get );
    $::lglobal{searchentry}->delete( 0, 'end' );
    $::lglobal{searchentry}->insert( 'end', $tempholder );
    searchtext();
}

# Check if a regex is valid by attempting to eval it
#
# Two possible errors:
#   1. eval block fails to compile and $@ contains the compile error
#   2. regex compiles OK, but causes warning to be issued,
#      e.g. "...matches null string many times in regex"
#
# Case 2 is caught by temporarily overriding warning handling via "local $SIG{__WARN__}"
# Since Perl avoids outputting a duplicate warning, if the same bad regex is checked again,
# case 2 would not trigger. Therefore it is necessary to remember the bad regex and check
# against that as well.
#
# Block to ensure persistence of $lastbad
{
    my $lastbad = '^*';    # initialise to a regex that would generate a warning

    sub isvalid {
        my $regex = shift;

        # assume a new regex is a good one
        my $valid = $regex ne $lastbad;

        # local warning handler to trap regex warnings
        local $SIG{__WARN__} = sub {
            $lastbad = $regex;
            $valid   = 0;
        };

        # try compiling it - note warning handler may set $valid to 0 at this point
        eval { qr/$regex/ };

        $valid = 0 if $@;    # if compile failed
        return $valid;
    }
}

# End of enclosing block

sub badreg {
    my $warning = $::top->Dialog(
        -text    => "Invalid Regex search term.\nDo you have mismatched\nbrackets or parenthesis?",
        -title   => 'Invalid Regex',
        -bitmap  => 'warning',
        -buttons => ['Ok'],
    );
    $warning->Icon( -image => $::icon );
    $warning->Show;
}

sub clearmarks {
    @{ $::lglobal{nlmatches} } = ();
    my ( $mark, $mindex );
    $mark = $::textwindow->markNext($::searchendindex);
    while ($mark) {
        if ( $mark =~ /nls\d+q(\d+)/ ) {
            $mindex = $::textwindow->index($mark);
            $::textwindow->markUnset($mark);
            $mark = $mindex;
        }
        $mark = $::textwindow->markNext($mark) if $mark;
    }
}

sub getmark {
    my $start = shift;
    if ( $::sopt[2] ) {    # search reverse
        return $::textwindow->markPrevious($start);
    } else {               # search forward
        return $::textwindow->markNext($start);
    }
}

sub updatesearchlabels {
    if ( $::lglobal{searchpop} ) {
        my $searchterm1 = $::lglobal{searchentry}->get;

        if ( $searchterm1 eq '' ) {
            $::lglobal{searchnumlabel}->configure( -text => "" );
        } elsif ( $::lglobal{seenwords} && $::sopt[0] ) {
            $::lglobal{searchnumlabel}
              ->configure( -text => searchnumtext( $::lglobal{seenwords}->{$searchterm1} ) );
        }
    }
}

# Return text for searchnumlabel depending on number of times found.
sub searchnumtext {
    my $count = shift;
    return "Not found" if not $count;
    return "Found $count " . ( $count == 1 ? "time" : "times" );

}

# calls the replacewith command after calling replaceeval
# to allow arbitrary perl code to be included in the replace entry
sub replace {
    ::hidepagenums();
    my $replaceterm = shift;
    $replaceterm = '' unless length $replaceterm;
    return unless $::searchstartindex;
    my $searchterm = $::lglobal{searchentry}->get;
    $replaceterm = replaceeval( $searchterm, $replaceterm ) if ( $::sopt[3] );

    # If matching string is zero-length, just insert replacement text because Perl/Tk won't replace a zero-length string
    if ( $::textwindow->compare( $::searchstartindex, '==', $::searchendindex ) ) {
        $::textwindow->insert( $::searchstartindex, $replaceterm );
    } elsif ($::searchstartindex) {
        $::textwindow->replacewith( $::searchstartindex, $::searchendindex, $replaceterm );
    }
    return 1;
}

sub findascanno {
    my $textwindow = $::textwindow;
    $::searchendindex = '1.0';
    my $word = '';
    $word = $::lglobal{scannosarray}[ $::lglobal{scannosindex} ];
    $::lglobal{searchentry}->delete( 0, 'end' );
    $::lglobal{replaceentry}->delete( 0, 'end' );
    ::soundbell('noflash')          unless ( $word || $::lglobal{regaa} );
    $::lglobal{searchbutton}->flash unless ( $word || $::lglobal{regaa} );
    $::lglobal{regtracker}->configure(
        -text => ( $::lglobal{scannosindex} + 1 ) . '/' . ( $#{ $::lglobal{scannosarray} } + 1 ) )
      if Tk::Exists( $::lglobal{regtracker} );
    $::lglobal{hintmessage}->delete( '1.0', 'end' )
      if ( defined( $::lglobal{hintpop} ) );
    return 0 unless $word;
    $::lglobal{searchentry}->insert( 'end', $word );
    $::lglobal{replaceentry}->insert( 'end', ( $::scannoslist{$word} ) );
    $::sopt[2]
      ? $textwindow->markSet( 'insert', 'end' )
      : $textwindow->markSet( 'insert', '1.0' );
    reghint() if ( defined( $::lglobal{hintpop} ) );
    $textwindow->update;
    return 1;
}

# allow the replacment term to contain arbitrary perl code
# called only from replace()
sub replaceeval {
    my $textwindow = $::textwindow;
    my $top        = $::top;
    my ( $searchterm, $replaceterm ) = @_;
    my @replarray = ();
    my ( $replaceseg, $seg1,   $seg2,   $replbuild );
    my ( $m1,         $m2,     $m3,     $m4,     $m5,     $m6,     $m7,     $m8 );
    my ( $cfound,     $lfound, $ufound, $tfound, $xfound, $bfound, $gfound, $afound, $rfound );

    # convert \Ix (insert something) codes early, since they don't rely on the match string
    if ( $replaceterm =~ /\\IP/ ) {    # Replace \IP with the page label of the start of the matched text
        my $label = $::pagenumbers{ "Pg" . ::get_page_number($::searchstartindex) }{label};
        $label =~ s/Pg //;
        $label = "999999" if $label eq "";    # Alert PPer if no label
        $replaceterm =~ s/\\IP/$label/g;
    }

    #check for control codes before the $1 codes for text found are inserted
    $replaceterm =~ s/\\GA/\\GX/g;
    $replaceterm =~ s/\\GX/\\X/g;
    $replaceterm =~ s/\\GB/\\B/g;
    $replaceterm =~ s/\\GG/\\G/g;
    $cfound = ( $replaceterm =~ /\\C/ );
    $lfound = ( $replaceterm =~ /\\L/ );
    $ufound = ( $replaceterm =~ /\\U/ );
    $tfound = ( $replaceterm =~ /\\T/ );
    $xfound = ( $replaceterm =~ /\\X/ );
    $bfound = ( $replaceterm =~ /\\B/ );
    $gfound = ( $replaceterm =~ /\\G/ );
    $afound = ( $replaceterm =~ /\\A/ );
    $rfound = ( $replaceterm =~ /\\R/ );

    my $found = $textwindow->get( $::searchstartindex, $::searchendindex );
    $searchterm =~ s/\Q(?<=\E.*?\)//;
    $searchterm =~ s/\Q(?=\E.*?\)//;

    # Handle regex grouping via () and $
    # Don't want dollars in text to be interpreted during substitution (e.g. $2 inserted
    # as a result of match 1 then being substituted for match 2), so escape dollars in match strings
    # Note that regex match options "sm" are needed here and in the "search on the whole file"
    # section of sub searchtext - these options should match or weird behaviour will ensue.
    # The "g" option is not required here since that is to support multiple matches of the searchterm
    # within the file.
    my @matches = $::sopt[1] ? ( $found =~ m/$searchterm/smi ) : ( $found =~ m/$searchterm/sm );
    for my $idx ( 1 .. 8 ) {    # Up to 8 groups supported
        my $match = $matches[ $idx - 1 ];
        next unless defined $match;
        $match       =~ s/\\/\\\\/g;
        $match       =~ s/\$/\\\$/g;
        $replaceterm =~ s/(?<!\\)\$$idx/$match/g;
    }
    $replaceterm =~ s/\\\$/\$/g;    # Unescape dollars

    # \C indicates perl code to be run
    if ($cfound) {
        if ( $::lglobal{codewarn} ) {
            my $message = <<'END';
WARNING!! The replacement term will execute arbitrary perl code.
If you do not want to, or are not sure of what you are doing, cancel the operation.
It is unlikely that there is a problem. However, it is possible (and not terribly difficult)
to construct an expression that would delete files, execute arbitrary malicious code,
reformat hard drives, etc.
Do you want to proceed?
END
            my $dialog = $top->Dialog(
                -text    => $message,
                -bitmap  => 'warning',
                -title   => 'WARNING! Code in term.',
                -buttons => [ 'OK', 'Warnings Off', 'Cancel' ],
            );
            my $answer = $dialog->Show;
            $::lglobal{codewarn} = 0 if ( $answer eq 'Warnings Off' );
            return $replaceterm unless $answer eq 'OK' or $answer eq 'Warnings Off';
        }
        $replaceterm = replaceevalaction( $replaceterm, 'C', sub { eval shift; } );
    }

    # \L converts to lower case
    $replaceterm = replaceevalaction( $replaceterm, 'L', sub { lc shift; } ) if $lfound;

    # \U converts to upper case
    $replaceterm = replaceevalaction( $replaceterm, 'U', sub { uc shift; } ) if $ufound;

    # \T converts to title case
    $replaceterm = replaceevalaction( $replaceterm, 'T', \&::titlecase ) if $tfound;

    # \X (aka \GA aka \GX) runs betaascii
    $replaceterm = replaceevalaction( $replaceterm, 'X', \&::betaascii ) if $xfound;

    # \B (aka \GB) runs greekbeta
    $replaceterm = replaceevalaction( $replaceterm, 'B', \&::greekbeta ) if $bfound;

    # \G (aka \GG) runs betagreek
    $replaceterm = replaceevalaction( $replaceterm, 'G', \&::betagreek ) if $gfound;

    # \A converts to anchor
    $replaceterm =
      replaceevalaction( $replaceterm, 'A', sub { ::makeanchor( ::deaccentdisplay(shift) ); } )
      if $afound;

    # \R converts to Roman numerals
    $replaceterm = replaceevalaction( $replaceterm, 'R', \&::roman ) if $rfound;

    # Sort out escaped backslashes
    $replaceterm =~ s/^\\n/\n/;                        # No pairs @ string start
    $replaceterm =~ s/^\\\\\\n/\\\\\n/;                # 1 pair @ string start
    $replaceterm =~ s/^((\\\\)*)\\n/$1\n/;             # Multiple pairs @ string start
    $replaceterm =~ s/\n\\n/\n\n/g;                    # No pairs @ line start
    $replaceterm =~ s/\n\\\\\\n/\n\\\\\n/g;            # 1 pair @ line start
    $replaceterm =~ s/\n((\\\\)*)\\n/\n$1\n/g;         # Multiple pairs @ line start
    $replaceterm =~ s/([^\\])\\n/$1\n/g;               # No pairs in string middle
    $replaceterm =~ s/([^\\])\\\\\\n/$1\\\\\n/g;       # 1 pair in string middle
    $replaceterm =~ s/([^\\])((\\\\)*)\\n/$1$2\n/g;    # Multiple pairs in string middle

    $replaceterm =~ s/^\\t/\t/;                        # Same but now for tab not newline
    $replaceterm =~ s/^\\\\\\t/\\\\\t/;
    $replaceterm =~ s/^((\\\\)*)\\t/$1\t/;
    $replaceterm =~ s/\n\\t/\n\t/g;
    $replaceterm =~ s/\n\\\\\\t/\n\\\\\t/g;
    $replaceterm =~ s/\n((\\\\)*)\\t/\n$1\t/g;
    $replaceterm =~ s/([^\\])\\t/$1\t/g;
    $replaceterm =~ s/([^\\])\\\\\\t/$1\\\\\t/g;
    $replaceterm =~ s/([^\\])((\\\\)*)\\t/$1$2\t/g;

    $replaceterm =~ s/\\\\/\\/g;                       # Ghastly, but it does work!!!

    return $replaceterm;
}

# Execute extended regex actions of one type, e.g. all the \L...\E for lowercase
sub replaceevalaction {
    my $replaceterm = shift;
    my $type        = shift;
    my $callback    = shift;

    # Split into segments delimited by \type
    my @replarray = split /\\$type/, $replaceterm;
    my $replbuild = shift @replarray;    # start with replace term up to first \type (may be empty)

    # For each segment that began with \type, split into 2 segments: before/after next \E
    while ( my $replaceseg = shift @replarray ) {
        my ( $seg1, $seg2 ) = split /\\E/, $replaceseg, 2;
        $replbuild .= &$callback($seg1);    # Append segment after processing according to \type
        $replbuild .= $seg2 if $seg2;       # Append segment after \E without processing
    }
    return $replbuild;
}

sub replaceall {
    my $replacement = shift;
    $replacement = '' unless $replacement;
    my $textwindow = $::textwindow;
    my $top        = $::top;

    # Check if replaceall applies only to a selection
    my @ranges = $textwindow->tagRanges('sel');
    if (@ranges) {
        $::lglobal{lastsearchterm} = $::lglobal{replaceentry}->get;
        $::searchstartindex        = pop @ranges;
        $::searchendindex          = pop @ranges;
    } else {
        my $searchterm = $::lglobal{searchentry}->get;
        $::lglobal{lastsearchterm} = '';

        # unless it's a regex search
        # or replacement contains searchterm, including case insensitive form
        # (to avoid an infinite loop bug in TextEdit's FindAndReplaceAll function)
        # do a speedy FindAndReplaceAll
        unless ( $::sopt[3]
            or index( $replacement, $searchterm ) >= 0
            or ( $::sopt[1] and index( lc($replacement), lc($searchterm) ) >= 0 ) ) {

            # escape metacharacters and check before/after for non-alpha if whole word matching
            if ( $::sopt[0] ) {
                my $exactsearch = ::escape_regexmetacharacters($searchterm);
                $searchterm = '(?<!\p{Alnum})' . $exactsearch . '(?!\p{Alnum})';
            }

            # regex search is needed for whole word matching
            my $mode = $::sopt[0] ? '-regexp' : '-exact';
            my $case = $::sopt[1] ? '-nocase' : '-case';
            ::working("Replace All");
            $textwindow->FindAndReplaceAll( $mode, $case, $searchterm, $replacement );
            ::working();
            return;
        }
    }

    ::hidelinenumbers();    # To speed updating of text window
    $textwindow->focus;
    ::enable_interrupt();

    # Keep calling searchtext() and replace() until no more matches
    # Use silentmode=1 for searchtext() or it will do window updates
    while ( searchtext( undef, 1 ) ) {
        last unless replace($replacement);
        last if ::query_interrupt();
        $textwindow->update unless ::updatedrecently();    # Too slow if update window after every match
    }
    ::disable_interrupt();
    ::restorelinenumbers();
}

# Reset search from start of doc if new search term
sub searchfromstartifnew {
    my $new_term = shift;
    if ( $new_term ne $::lglobal{lastsearchterm} ) {
        searchoptset(qw/x x x x 1/);
    }
}

sub searchoptset {
    my @opt       = @_;
    my $opt_count = @opt;

    # $::sopt[0] --> 0 = pattern search               1 = whole word search
    # $::sopt[1] --> 0 = case sensitive               1 = case insensitive search
    # $::sopt[2] --> 0 = search forwards              1 = search backwards
    # $::sopt[3] --> 0 = normal search term   1 = regex search term - 3 and 0 are mutually exclusive
    # $::sopt[4] --> 1 = start search at beginning
    for ( 0 .. $opt_count - 1 ) {
        if ( defined( $::lglobal{searchpop} ) ) {
            if ( $opt[$_] !~ /[a-zA-Z]/ ) {
                $opt[$_]
                  ? $::lglobal{"searchop$_"}->select
                  : $::lglobal{"searchop$_"}->deselect;
            }
        } else {
            if ( $opt[$_] !~ /[a-zA-Z]/ ) { $::sopt[$_] = $opt[$_] }
        }
    }

    # Changing options may affect if search string is valid, so re-check it
    reg_check( $::lglobal{searchentry}->get ) if $::lglobal{searchpop};
}
### Search
sub searchpopup {
    my $textwindow = $::textwindow;
    my $top        = $::top;
    ::hidepagenums();
    ::operationadd('Stealth Scannos') if $::lglobal{doscannos};
    my $aacheck;
    my $searchterm = '';

    # If text is selected when dialog is popped, it is used for the search term.
    # Search term must not have actual newline characters because you could end up with a really
    # long string which breaks the history menu, e.g. if select whole file then pop dialog.
    # Trim a multiline string to just the first line.
    my @ranges = $textwindow->tagRanges('sel');
    $searchterm = $textwindow->get( $ranges[0], $ranges[1] ) if @ranges;
    $searchterm =~ s/[\n\r].*//s;    # Trailing 's' makes '.' match newlines

    if ( defined( $::lglobal{searchpop} ) ) {
        $::lglobal{searchpop}->deiconify;
        $::lglobal{searchpop}->raise;
        $::lglobal{searchpop}->focus;
        $::lglobal{searchentry}->focus;
    } else {

        # If popping dialog when it has previously been dismissed, decide whether search options
        # should be retained from last search (i.e. sticky) or reset
        unless ($::searchstickyoptions) {
            $::sopt[0] = $::sopt[1] = $::sopt[2] = $::sopt[3] = 0;
        }
        $::lglobal{searchpop} = $top->Toplevel;
        $::lglobal{searchpop}->title('Search & Replace');
        my $sf1 = $::lglobal{searchpop}->Frame->pack( -side => 'top', -anchor => 'n', -pady => 1 );
        my $searchlabel =
          $sf1->Label( -text => 'Search Text', )
          ->pack( -side => 'left', -anchor => 'w', -padx => 80 );
        $::lglobal{searchpopcountbutton} = $sf1->Button(
            -activebackground => $::activecolor,
            -command          => sub {
                update_sr_histories();
                countmatches( $::lglobal{searchentry}->get );
            },
            -text  => 'Count',
            -width => 6
        )->pack( -side => 'right', -anchor => 'e', -padx => 1 );
        $::lglobal{searchnumlabel} = $sf1->Label(
            -text    => '',
            -width   => 20,
            -anchor  => 'e',
            -justify => 'right'
        )->pack( -side => 'right', -anchor => 'e', -padx => 1 );
        my $sf11 = $::lglobal{searchpop}->Frame->pack(
            -side   => 'top',
            -anchor => 'nw',
            -padx   => 3,
            -pady   => 1,
            -expand => 'y',
            -fill   => 'x'
        );
        $sf11->Button(
            -activebackground => $::activecolor,
            -command          => sub {
                $textwindow->undo;
                $textwindow->tagRemove( 'highlight', '1.0', 'end' );
                $textwindow->see('insert');
            },
            -text  => 'Undo',
            -width => 6
        )->pack( -side => 'right', -anchor => 'w' );
        $::lglobal{searchbutton} = $sf11->Button(
            -activebackground => $::activecolor,
            -command          => sub {
                update_sr_histories();
                searchtext('');
            },
            -text  => 'Search',
            -width => 6
        )->pack(
            -side   => 'right',
            -padx   => 2,
            -anchor => 'w'
        );
        search_shiftreverse( $::lglobal{searchbutton} );
        $sf11->Button(
            -activebackground => $::activecolor,
            -command          => sub {
                ::entry_history( $::lglobal{searchentry}, \@::search_history );
            },
            -image  => $::lglobal{hist_img},
            -width  => 9,
            -height => 15,
        )->pack( -side => 'left', -anchor => 'w' );
        $::lglobal{searchentry} = $sf11->Entry(
            -background => $::bkgcolor,
            -foreground => 'black',
            -validate   => 'all',
            -vcmd       => sub { reg_check(shift); }
        )->pack(
            -side   => 'left',
            -anchor => 'w',
            -expand => 'y',
            -fill   => 'x'
        );
        my $sf2 = $::lglobal{searchpop}->Frame->pack(
            -side   => 'top',
            -anchor => 'w',
            -pady   => 1
        );
        $::lglobal{searchop1} = $sf2->Checkbutton(
            -variable    => \$::sopt[1],
            -selectcolor => $::lglobal{checkcolor},
            -text        => 'Case Insensitive'
        )->grid( -row => 1, -column => 1, -padx => 1 );
        $::lglobal{searchop0} = $sf2->Checkbutton(
            -variable    => \$::sopt[0],
            -command     => [ \&searchoptset, 'x', 'x', 'x', 0 ],
            -selectcolor => $::lglobal{checkcolor},
            -text        => 'Whole Word'
        )->grid( -row => 1, -column => 2, -padx => 1 );
        $::lglobal{searchop3} = $sf2->Checkbutton(
            -variable    => \$::sopt[3],
            -command     => [ \&searchoptset, 0, 'x', 'x', 'x' ],
            -selectcolor => $::lglobal{checkcolor},
            -text        => 'Regex'
        )->grid( -row => 1, -column => 3, -padx => 1 );
        $::lglobal{searchop2} = $sf2->Checkbutton(
            -variable    => \$::sopt[2],
            -selectcolor => $::lglobal{checkcolor},
            -text        => 'Reverse'
        )->grid( -row => 1, -column => 4, -padx => 1 );
        $::lglobal{searchop4} = $sf2->Checkbutton(
            -variable    => \$::sopt[4],
            -selectcolor => $::lglobal{checkcolor},
            -text        => 'Start at Beginning'
        )->grid( -row => 1, -column => 5, -padx => 1 );

        my $sf5;
        my @multisearch;
        my $sf10 = $::lglobal{searchpop}->Frame->pack(
            -side   => 'top',
            -anchor => 'n',
            -expand => '1',
            -fill   => 'x',
            -pady   => 1
        );
        my $replacelabel =
          $sf10->Label( -text => "Replacement Text\t\t", )->grid( -row => 1, -column => 1 );
        $sf10->Label( -text => 'Terms - ' )->grid( -row => 1, -column => 2 );
        $::lglobal{searchsingle} = $sf10->Radiobutton(
            -text     => 'single',
            -variable => \$::multiterm,
            -value    => 0,
            -command  => sub {
                for ( 0 .. $::multisearchsize - 2 ) {
                    $multisearch[$_]->packForget;
                }
                setsearchpopgeometry();
            },
        )->grid( -row => 1, -column => 3 );
        $::lglobal{searchmulti} = $sf10->Radiobutton(
            -text     => 'multi  ',
            -variable => \$::multiterm,
            -value    => 1,
            -command  => sub {
                searchshowterms( \@multisearch, 0, $::multisearchsize - 2, $sf5 );
                setsearchpopgeometry();
            },
        )->grid( -row => 1, -column => 4 );

        # Button to increment number of multiterms (also switches to multi)
        # Add frame/field/buttons if necessary
        $::lglobal{searchmultiadd} = $sf10->Button(
            -activebackground => $::activecolor,
            -command          => sub {
                if ( $::multisearchsize < 10 ) {    # don't go above 10 in multi-term mode
                    ++$::multisearchsize;
                    searchaddterms( \@multisearch, $::multisearchsize - 2 );
                }
                if ($::multiterm) {                 # if already multi, only need to show new term
                    searchshowterms(
                        \@multisearch,
                        $::multisearchsize - 2,
                        $::multisearchsize - 2, $sf5
                    );
                } else {                            # need to show all terms and switch to multi
                    searchshowterms( \@multisearch, 0, $::multisearchsize - 2, $sf5 );
                    $::lglobal{searchmulti}->select;
                    $::multiterm = 1;
                }
                setsearchpopgeometry();
            },
            -text  => '+',
            -width => 3,
        )->grid( -row => 1, -column => 5 );

        # Button to decrement number of multiterms (also switches to multi)
        # Don't destroy field/buttons, just hide their frame
        $sf10->Button(
            -activebackground => $::activecolor,
            -command          => sub {
                if ( $::multisearchsize > 2 ) {    # don't go below 2 in multi-term mode
                    --$::multisearchsize;

                    # if already multi, only need to hide last term
                    $multisearch[ $::multisearchsize - 1 ]->packForget if $::multiterm;
                }

                # if not in multi, show all the remaining terms and switch to multi
                if ( not $::multiterm ) {
                    searchshowterms( \@multisearch, 0, $::multisearchsize - 2, $sf5 );
                    $::lglobal{searchmulti}->select;
                    $::multiterm = 1;
                }
                setsearchpopgeometry();
            },
            -text  => '-',
            -width => 3,
        )->grid( -row => 1, -column => 6 );
        my $sf12 = $::lglobal{searchpop}->Frame->pack(
            -side   => 'top',
            -anchor => 'w',
            -padx   => 3,
            -expand => 'y',
            -fill   => 'x',
            -pady   => 1
        );
        $sf12->Button(
            -activebackground => $::activecolor,
            -command          => sub {
                update_sr_histories();
                replaceall( $::lglobal{replaceentry}->get );
            },
            -text  => 'Rpl All',
            -width => 5
        )->pack(
            -side   => 'right',
            -padx   => 2,
            -anchor => 'w'
        );
        my $sf12rs = $sf12->Button(
            -activebackground => $::activecolor,
            -command          => sub {
                update_sr_histories();
                replace( $::lglobal{replaceentry}->get );
                searchtext('');
            },
            -text  => 'R & S',
            -width => 5
        )->pack(
            -side   => 'right',
            -padx   => 2,
            -anchor => 'w'
        );
        search_shiftreverse($sf12rs);
        $sf12->Button(
            -activebackground => $::activecolor,
            -command          => sub {
                update_sr_histories();
                replace( $::lglobal{replaceentry}->get );
            },
            -text  => 'Replace',
            -width => 6
        )->pack(
            -side   => 'right',
            -padx   => 2,
            -anchor => 'w'
        );
        $sf12->Button(
            -activebackground => $::activecolor,
            -command          => sub {
                ::entry_history( $::lglobal{replaceentry}, \@::replace_history );
            },
            -image  => $::lglobal{hist_img},
            -width  => 9,
            -height => 15,
        )->pack( -side => 'left', -anchor => 'w' );
        $::lglobal{replaceentry} = $sf12->Entry( -background => $::bkgcolor, )->pack(
            -side   => 'left',
            -anchor => 'w',
            -padx   => 1,
            -expand => 'y',
            -fill   => 'x'
        );

        searchaddterms( \@multisearch, $::multisearchsize - 2 );
        if ($::multiterm) {
            for ( 0 .. $::multisearchsize - 2 ) {
                $multisearch[$_]->pack(
                    -side   => 'top',
                    -anchor => 'w',
                    -padx   => 3,
                    -expand => 'y',
                    -fill   => 'x',
                    -pady   => 1
                );
            }
        }
        $sf5 = $::lglobal{searchpop}->Frame->pack( -side => 'top', -anchor => 'n', -pady => 1 );
        if ( $::lglobal{doscannos} ) {
            my $nextbutton = $sf5->Button(
                -activebackground => $::activecolor,
                -command          => sub {
                    $::lglobal{scannosindex}++
                      unless $::lglobal{scannosindex} >= $#{ $::lglobal{scannosarray} };
                    getnextscanno();
                },
                -text  => 'Next Stealtho',
                -width => 15
            )->pack(
                -side   => 'left',
                -padx   => 2,
                -anchor => 'w'
            );
            $::lglobal{nextoccurrencebutton} = $sf5->Button(
                -activebackground => $::activecolor,
                -command          => sub {
                    searchtext('');
                },
                -text  => 'Next Occurrence',
                -width => 15
            )->pack(
                -side   => 'left',
                -padx   => 2,
                -anchor => 'w'
            );
            search_shiftreverse( $::lglobal{nextoccurrencebutton} );
            my $lastbutton = $sf5->Button(
                -activebackground => $::activecolor,
                -command          => sub {
                    $aacheck->deselect;
                    $::lglobal{scannosindex}--
                      unless ( $::lglobal{scannosindex} == 0 );
                    getnextscanno();
                },
                -text  => 'Prev Stealtho',
                -width => 15
            )->pack(
                -side   => 'left',
                -padx   => 2,
                -anchor => 'w'
            );
            my $switchbutton = $sf5->Button(
                -activebackground => $::activecolor,
                -command          => sub { swapterms() },
                -text             => 'Swap Terms',
                -width            => 15
            )->pack(
                -side   => 'left',
                -padx   => 2,
                -anchor => 'w'
            );
            my $hintbutton = $sf5->Button(
                -activebackground => $::activecolor,
                -command          => sub { reghint() },
                -text             => 'Hint',
                -width            => 5
            )->pack(
                -side   => 'left',
                -padx   => 2,
                -anchor => 'w'
            );
            my $editbutton = $sf5->Button(
                -activebackground => $::activecolor,
                -command          => sub { regedit() },
                -text             => 'Edit',
                -width            => 5
            )->pack(
                -side   => 'left',
                -padx   => 2,
                -anchor => 'w'
            );
            my $sf6 =
              $::lglobal{searchpop}->Frame->pack( -side => 'top', -anchor => 'n', -pady => 1 );
            $::lglobal{regtracker} = $sf6->Label( -width => 15 )->pack(
                -side   => 'left',
                -padx   => 2,
                -anchor => 'w'
            );
            $aacheck = $sf6->Checkbutton(
                -text     => 'Auto Advance',
                -variable => \$::lglobal{regaa},
            )->pack(
                -side   => 'left',
                -padx   => 2,
                -anchor => 'w'
            );
        }
        $::lglobal{searchpop}->resizable( 'yes', 'no' );
        setsearchpopgeometry();
        ::initialize_popup_without_deletebinding( 'searchpop',
            $::lglobal{doscannos} ? 'scannos' : 'search' );
        $::lglobal{searchentry}->focus;

        $::lglobal{searchpop}->protocol(
            'WM_DELETE_WINDOW' => sub {
                ::killpopup('searchpop');
                $textwindow->tagRemove( 'highlight', '1.0', 'end' );
                undef $::lglobal{hintpop}    if $::lglobal{hintpop};
                undef $::lglobal{regtracker} if $::lglobal{regtracker};
                $::scannosearch = 0;    #no longer in a scanno search
            }
        );

        # Return: find in current direction
        searchbind(
            '<Return>',
            sub {
                update_sr_histories();
                searchtext();
                $top->raise;
            }
        );

        # Control-Return: find & replace
        searchbind(
            '<Control-Return>',
            sub {
                update_sr_histories();
                replace( $::lglobal{replaceentry}->get );
                searchtext();
                $top->raise;
            }
        );

        # Shift-Return: replace
        searchbind(
            '<Shift-Return>',
            sub {
                update_sr_histories();
                replace( $::lglobal{replaceentry}->get );
                $top->raise;
            }
        );

        # Control-Shift-Return: replace all
        searchbind(
            '<Control-Shift-Return>',
            sub {
                update_sr_histories();
                replaceall( $::lglobal{replaceentry}->get );
                $top->raise;
            }
        );

        # Control-f: find in current direction
        searchbind(
            '<Control-f>',
            sub {
                update_sr_histories();
                searchtext();
                $top->raise;
            }
        );

        # Control-g: repeat find in current direction
        searchbind(
            '<Control-g>',
            sub {
                update_sr_histories();
                searchtext( $::lglobal{searchentry}->get );
                $textwindow->focus;
            }
        );

        # Control-Shift-g: repeat find in opposite direction
        searchbind(
            '<Control-Shift-g>',
            sub {
                update_sr_histories();
                $::lglobal{searchop2}->toggle;
                searchtext( $::lglobal{searchentry}->get );
                $::lglobal{searchop2}->toggle;
                $textwindow->focus;
            }
        );

        # Control-b: count occurrences
        searchbind(
            '<Control-b>',
            sub {
                update_sr_histories();
                countmatches( $::lglobal{searchentry}->get );
            }
        );

        # Compose
        searchbind( "<$::composepopbinding>", sub { ::composepopup(); } );

        $::lglobal{searchentry}->{_MENU_}  = ();
        $::lglobal{replaceentry}->{_MENU_} = ();
        $::lglobal{searchentry}->bind(
            '<FocusIn>',
            sub {
                $::lglobal{hasfocus} = $::lglobal{searchentry};
            }
        );
        $::lglobal{replaceentry}->bind(
            '<FocusIn>',
            sub {
                $::lglobal{hasfocus} = $::lglobal{replaceentry};
            }
        );
        for ( 1 .. $::multisearchsize - 1 ) {
            $::lglobal{"replaceentry$_"}->{_MENU_} = ();
            $::lglobal{"replaceentry$_"}->bind( '<FocusIn>',
                eval " sub { \$::lglobal{hasfocus} = \$::lglobal{replaceentry$_}; } " );
        }
    }
    if ( length $searchterm ) {
        $::lglobal{searchentry}->delete( 0, 'end' );
        $::lglobal{searchentry}->insert( 'end', $searchterm );
        $::lglobal{searchentry}->selectionRange( 0, 'end' );
        update_sr_histories();
        searchtext('');
    }
}

# Create bindings so Shift key causes a one-off reversal of Search or Replace & Search direction.
# Shift-Button toggles the reverse flag before the class's ButtonRelease event
# executes the search command.
# It is necessary to remember this has been done so it can be toggled back via
# the instance's ButtonRelease event, which is executed after the class's event.
# This also ensures we trap the case where the user releases the Shift key between
# Button and ButtonRelease, which a simple toggle in a Shift-ButtonRelease event would not.
sub search_shiftreverse {
    my $btn = shift;
    $btn->bind(
        '<Shift-Button-1>',
        sub {
            $::lglobal{searchop2}->invoke;
            $::lglobal{searchreversetemp} = 1;
        }
    );
    $btn->bind(
        '<ButtonRelease-1>',
        sub {
            if ( $::lglobal{searchreversetemp} ) {
                $::lglobal{searchop2}->invoke;
                $::lglobal{searchreversetemp} = 0;
            }
        }
    );
}

# Bind a key-combination to a sub for the S&R dialog
# Also disable default class behaviour for key on Entry widgets
# (e.g. Ctrl-b does "move left" by default)
# See KeyBindings.pm for main text window equivalent
sub searchbind {
    my $lkey = shift;    # Key-combination (lower-case letter)
    my $subr = shift;    # Subroutine to bind to key

    my $ukey = $lkey;
    $ukey =~ s/-([a-z])>/-\u$1>/;    # Create uppercase version

    $::lglobal{searchpop}->bind( $lkey => $subr );
    $::lglobal{searchpop}->bind( $ukey => $subr ) if $ukey ne $lkey;

    # Disable default class bindings for Entry widgets
    $::lglobal{searchpop}->MainWindow->bind( "Tk::Entry", $lkey, 'NoOp' );
    $::lglobal{searchpop}->MainWindow->bind( "Tk::Entry", $ukey, 'NoOp' ) if $ukey ne $lkey;
}

# Add frames containing field and buttons for replacement terms
sub searchaddterms {
    my $msref  = shift;              # Array of frames
    my $termno = shift;              # Highest number frame required
    my $mslen  = @$msref;
    for ( $mslen .. $termno ) {      # Create as many as needed
        push @$msref, $::lglobal{searchpop}->Frame;
        my $replaceentry = "replaceentry" . ( $_ + 1 );
        $msref->[$_]->Button(
            -activebackground => $::activecolor,
            -command          => sub {
                update_sr_histories();
                replaceall( $::lglobal{$replaceentry}->get );
            },
            -text  => 'Rpl All',
            -width => 5
        )->pack(
            -side   => 'right',
            -padx   => 2,
            -anchor => 'w'
        );
        my $rsbtn = $msref->[$_]->Button(
            -activebackground => $::activecolor,
            -command          => sub {
                update_sr_histories();
                replace( $::lglobal{$replaceentry}->get );
                searchtext('');
            },
            -text  => 'R & S',
            -width => 5
        )->pack(
            -side   => 'right',
            -padx   => 2,
            -anchor => 'w'
        );
        search_shiftreverse($rsbtn);
        $msref->[$_]->Button(
            -activebackground => $::activecolor,
            -command          => sub {
                update_sr_histories();
                replace( $::lglobal{$replaceentry}->get );
            },
            -text  => 'Replace',
            -width => 6
        )->pack(
            -side   => 'right',
            -padx   => 2,
            -anchor => 'w'
        );
        $msref->[$_]->Button(
            -activebackground => $::activecolor,
            -command          => sub {
                ::entry_history( $::lglobal{$replaceentry}, \@::replace_history );
            },
            -image  => $::lglobal{hist_img},
            -width  => 9,
            -height => 15,
        )->pack( -side => 'left', -anchor => 'w' );
        $::lglobal{$replaceentry} = $msref->[$_]->Entry( -background => $::bkgcolor, )->pack(
            -side   => 'left',
            -anchor => 'w',
            -padx   => 1,
            -expand => 'y',
            -fill   => 'x'
        );
        $::lglobal{$replaceentry}->{_MENU_} = ();
        $::lglobal{$replaceentry}->bind( '<FocusIn>',
            eval " sub { \$::lglobal{hasfocus} = \$::lglobal{$replaceentry}; } " );
    }
}

sub searchshowterms {
    my ( $msref, $start, $end, $before ) = @_;
    for ( $start .. $end ) {
        $msref->[$_]->pack(
            -before => $before,
            -side   => 'top',
            -anchor => 'w',
            -padx   => 3,
            -expand => 'y',
            -fill   => 'x'
        );
    }
}

#
# Set search dialog height by adding all widget heights and override the value
# in the geometry hash. This allows the user to vary the width, but allows the
# program to keep the height correct when widgets are added/removed
sub setsearchpopgeometry {
    return unless $::lglobal{searchpop};

    # Without the following line to set the geometry before the update,
    # Linux versions may pop the dialog in the old location and not
    # correct it when the geometry is set at the end of the routine
    $::lglobal{searchpop}->geometry( $::geometryhash{searchpop} );
    $::lglobal{searchpop}->update;    # dialog must be drawn to get heights

    # Some rows have button, some have entry field, some have toggle - all have padding of 1 above and below
    my $buttonheight = $::lglobal{searchpopcountbutton}->height + 2;
    my $rowheight    = $::lglobal{searchentry}->height + 2;
    $rowheight = $buttonheight if $buttonheight > $rowheight;
    my $toggleheight = $::lglobal{searchop1}->height + 2;

    my $height = $buttonheight +                                  # Count row
      $rowheight +                                                # Search row
      $toggleheight +                                             # Toggles row
      $buttonheight +                                             # Multi row
      $rowheight * ( $::multiterm ? $::multisearchsize : 1 ) +    # Replace rows
      2;                                                          # Padding on final frame

    # Extra button row and toggle row if scannos widgets are shown (not the same as checking $::lglobal{doscannos})
    $height += $buttonheight + $toggleheight if $::lglobal{regtracker};

    $::geometryhash{searchpop} =~ s/x\d+/x$height/;
    $::lglobal{searchpop}->geometry( $::geometryhash{searchpop} );
}

sub stealthscanno {
    my $textwindow = $::textwindow;
    my $top        = $::top;
    $::lglobal{doscannos} = 1;
    ::killpopup('hintpop');
    ::killpopup('searchpop');
    searchoptset(qw/1 x x 0 1/);    # force search to begin at start of doc, whole word
    if ( ::loadscannos() ) {
        ::savesettings();
        ::wordfrequencybuildwordlist($textwindow);
        searchpopup();
        getnextscanno();
        searchtext() unless $::lglobal{regaa};    # getnextscanno has already done a search if auto-advance
    }
    $::lglobal{doscannos} = 0;
}

sub find_proofer_comment {
    my $direction = shift;
    $direction = 'forward' unless $direction;
    my $textwindow = $::textwindow;
    my $pattern    = '[**';

    # Avoid finding same one again
    my $start   = $direction eq 'reverse' ? 'insert -1c' : 'insert';
    my $comment = $textwindow->search( $direction eq 'reverse' ? '-backwards' : '-forwards',
        '--', $pattern, $start );
    if ($comment) {
        my $index = $textwindow->index("$comment +1c");
        $textwindow->SetCursor($index);
    } else {
        ::operationadd('Found no more proofer comments')
          if $direction ne 'reverse';
    }
}

sub find_asterisks {
    my $textwindow = $::textwindow;
    my $pattern    = "(?<!/)\\*(?!/)";
    my $comment    = $textwindow->search( '-regexp', '--', $pattern, "insert" );
    if ($comment) {
        my $index = $textwindow->index("$comment +1c");
        $textwindow->SetCursor($index);
    } else {
        ::operationadd('Found no more asterisks without slash');
    }
}

sub find_transliterations {
    my $textwindow = $::textwindow;
    my $pattern    = "\\[[^FIS\\d]";
    searchpopup();
    searchoptset(qw/0 x x 1/);
    $::lglobal{searchsingle}->invoke;
    $::lglobal{searchentry}->delete( 0, 'end' );
    $::lglobal{searchentry}->insert( 'end', $pattern );
    $::lglobal{searchbutton}->invoke;

    #my $comment    = $textwindow->search( '-regexp', '--', $pattern, "insert" );
    #if ($comment) {
    #	my $index = $textwindow->index("$comment +1c");
    #	$textwindow->SetCursor($index);
    #} else {
    #	::operationadd('Found no more transliterations (\\[[^FIS\\d])');
    #}
}

sub orphanedbrackets {
    my $textwindow = $::textwindow;
    my $top        = $::top;
    if ( defined( $::lglobal{brkpop} ) ) {
        $::lglobal{brkpop}->deiconify;
        $::lglobal{brkpop}->raise;
        $::lglobal{brkpop}->focus;
    } else {
        $::lglobal{brkpop} = $top->Toplevel;
        $::lglobal{brkpop}->title('Find orphan brackets');
        $::lglobal{brkpop}->Label( -text => 'Bracket or Markup Style' )->pack;
        my $frame = $::lglobal{brkpop}->Frame->pack;

        # The list of radio buttons below must be the same as the matches in sub brsel
        my $psel = $frame->Radiobutton(
            -variable    => \$::lglobal{brsel},
            -selectcolor => $::lglobal{checkcolor},
            -value       => '[\(\)]',
            -text        => '(  )',
        )->grid( -row => 1, -column => 1 );
        $psel->select;
        $frame->Radiobutton(
            -variable    => \$::lglobal{brsel},
            -selectcolor => $::lglobal{checkcolor},
            -value       => '[\[\]]',
            -text        => '[  ]',
        )->grid( -row => 1, -column => 2 );
        $frame->Radiobutton(
            -variable    => \$::lglobal{brsel},
            -selectcolor => $::lglobal{checkcolor},
            -value       => '[\{\}]',
            -text        => '{  }',
        )->grid( -row => 1, -column => 3, -pady => 5 );
        $frame->Radiobutton(
            -variable    => \$::lglobal{brsel},
            -selectcolor => $::lglobal{checkcolor},
            -value       => '[<>]',
            -text        => '<  >',
        )->grid( -row => 1, -column => 4, -pady => 5 );
        my $frame1 = $::lglobal{brkpop}->Frame->pack;
        $frame1->Radiobutton(
            -variable    => \$::lglobal{brsel},
            -selectcolor => $::lglobal{checkcolor},
            -value       => '\/\*|\*\/',
            -text        => '/* */',
        )->grid( -row => 1, -column => 1 );
        $frame1->Radiobutton(
            -variable    => \$::lglobal{brsel},
            -selectcolor => $::lglobal{checkcolor},
            -value       => '\/#|#\/',
            -text        => '/# #/',
        )->grid( -row => 1, -column => 2 );
        $frame1->Radiobutton(
            -variable    => \$::lglobal{brsel},
            -selectcolor => $::lglobal{checkcolor},
            -value       => '\/\$|\$\/',
            -text        => '/$ $/',
        )->grid( -row => 1, -column => 3 );
        $frame1->Radiobutton(
            -variable    => \$::lglobal{brsel},
            -selectcolor => $::lglobal{checkcolor},
            -value       => '^\/[Pp]|[Pp]\/',
            -text        => '/P P/',
        )->grid( -row => 1, -column => 4 );
        $frame1->Radiobutton(
            -variable    => \$::lglobal{brsel},
            -selectcolor => $::lglobal{checkcolor},
            -value       => '^\/[Xx]|[Xx]\/',
            -text        => '/X X/',
        )->grid( -row => 1, -column => 5 );
        $frame1->Radiobutton(
            -variable    => \$::lglobal{brsel},
            -selectcolor => $::lglobal{checkcolor},
            -value       => '^\/[Ff]|[Ff]\/',
            -text        => '/F F/',
        )->grid( -row => 2, -column => 1 );
        $frame1->Radiobutton(
            -variable    => \$::lglobal{brsel},
            -selectcolor => $::lglobal{checkcolor},
            -value       => '^\/[Ll]|[Ll]\/',
            -text        => '/L L/',
        )->grid( -row => 2, -column => 2 );
        $frame1->Radiobutton(
            -variable    => \$::lglobal{brsel},
            -selectcolor => $::lglobal{checkcolor},
            -value       => '^\/[Ii]|[Ii]\/',
            -text        => '/I I/',
        )->grid( -row => 2, -column => 3 );
        $frame1->Radiobutton(
            -variable    => \$::lglobal{brsel},
            -selectcolor => $::lglobal{checkcolor},
            -value       => '^\/[Cc]|[Cc]\/',
            -text        => '/C C/',
        )->grid( -row => 2, -column => 4 );
        $frame1->Radiobutton(
            -variable    => \$::lglobal{brsel},
            -selectcolor => $::lglobal{checkcolor},
            -value       => '^\/[Rr]|[Rr]\/',
            -text        => '/R R/',
        )->grid( -row => 2, -column => 5 );
        my $frame3 = $::lglobal{brkpop}->Frame->pack;
        $frame3->Radiobutton(
            -variable    => \$::lglobal{brsel},
            -selectcolor => $::lglobal{checkcolor},
            -value       => "«|»",
            -text        => 'French angle quotes « »',
        )->grid( -row => 2, -column => 2, -pady => 1, -sticky => 'w' );
        $frame3->Radiobutton(
            -variable    => \$::lglobal{brsel},
            -selectcolor => $::lglobal{checkcolor},
            -value       => '»|«',
            -text        => 'German angle quotes » «',
        )->grid( -row => 3, -column => 2, -pady => 1, -sticky => 'w' );
        $frame3->Radiobutton(
            -variable    => \$::lglobal{brsel},
            -selectcolor => $::lglobal{checkcolor},
            -value       => "\x{201c}|\x{201d}",
            -text        => "English curly quotes \x{201c} \x{201d}",
        )->grid( -row => 4, -column => 2, -pady => 1, -sticky => 'w' );
        $frame3->Radiobutton(
            -variable    => \$::lglobal{brsel},
            -selectcolor => $::lglobal{checkcolor},
            -value       => "\x{201e}|\x{201c}",
            -text        => "German curly quotes \x{201e} \x{201c}",
        )->grid( -row => 5, -column => 2, -pady => 1, -sticky => 'w' );

        #		my $allqsel =
        #		  $frame3->Radiobutton(
        #								-variable    => \$::lglobal{brsel},
        #								-selectcolor => $::lglobal{checkcolor},
        #								-value       => 'all',
        #								-text        => 'All brackets ( )',
        #		  )->grid( -row => 3, -column => 2 );
        my $frame2 = $::lglobal{brkpop}->Frame->pack;
        my ( $brkresult, $brnextbt );
        $brkresult =
          $frame2->Label( -text => '', )->grid( -row => 0, -column => 1, -columnspan => 2 );
        my $brsearchbt = $frame2->Button(
            -activebackground => $::activecolor,
            -text             => 'Search',
            -command          => sub { brsearch( $brkresult, $brnextbt ); },
            -width            => 16,
        )->grid( -row => 1, -column => 1, -padx => 4, -pady => 5 );
        $brnextbt = $frame2->Button(
            -activebackground => $::activecolor,
            -text             => 'Next',
            -command          => sub {
                shift @{ $::lglobal{brbrackets} }
                  if @{ $::lglobal{brbrackets} };
                shift @{ $::lglobal{brindices} }
                  if @{ $::lglobal{brindices} };
                unless ( $::lglobal{brbrackets}[1] ) {
                    my $brackets = printable_brackets( $::lglobal{brsel} );
                    ::operationadd("Found no more orphaned $brackets");
                    $brkresult->configure( -text => "No more orphaned $brackets found." );
                    $brnextbt->configure( -state => 'disabled', -text => 'Next' );
                    $textwindow->tagRemove( 'highlight', '1.0', 'end' );
                    ::soundbell();
                    return;
                }
                brnext( $brkresult, $brnextbt );
            },
            -state => 'disabled',
            -width => 16,
        )->grid( -row => 1, -column => 2, -padx => 4, -pady => 5 );
        ::initialize_popup_without_deletebinding('brkpop');
        $::lglobal{brkpop}->protocol(
            'WM_DELETE_WINDOW' => sub {
                ::killpopup('brkpop');
                $textwindow->tagRemove( 'highlight', '1.0', 'end' );
            }
        );
    }

    sub brsearch {
        my ( $brkresult, $brnextbt ) = @_;
        my $textwindow = $::textwindow;
        ::hidepagenums();
        $brkresult->configure( -text => '' );
        @{ $::lglobal{brbrackets} } = ();
        @{ $::lglobal{brindices} }  = ();
        $::lglobal{brindex} = '1.0';
        my $brcount = 0;
        my $brlength;

        while ( $::lglobal{brindex} ) {
            $::lglobal{brindex} = $textwindow->search(
                '-regexp',
                '-count' => \$brlength,
                '--', "$::lglobal{brsel}", $::lglobal{brindex}, 'end'
            );
            last unless $::lglobal{brindex};
            $::lglobal{brbrackets}[$brcount] =
              $textwindow->get( $::lglobal{brindex}, $::lglobal{brindex} . '+' . $brlength . 'c' );
            $::lglobal{brindices}[$brcount] = $::lglobal{brindex};
            $brcount++;
            $::lglobal{brindex} .= '+1c';
        }
        my $brackets = printable_brackets( $::lglobal{brsel} );
        $brnextbt->configure( -text => "Next $brackets", -state => 'normal' );
        if ( @{ $::lglobal{brbrackets} } ) {
            brnext( $brkresult, $brnextbt );
        } else {
            ::operationadd("Found no more orphaned $brackets");
            $brkresult->configure( -text => "No more orphaned $brackets found." );
            $brnextbt->configure( -text => 'Next', -state => 'disabled' );
            $textwindow->tagRemove( 'highlight', '1.0', 'end' );
            ::soundbell();
        }
    }

    sub printable_brackets {
        my $brackets = shift;
        if ( $brackets =~ /^\[(.*)\]$/ ) {
            $brackets = $1;
            $brackets =~ s/\\//g;
        } elsif ( $brackets =~ /\^?\\\/(.*)\\\// ) {
            $brackets = $1;
            $brackets =~ s/\\//g;
            $brackets = "/$brackets/";
            if ( $brackets =~ /\^?\/\[([A-Z])([a-z])]\|\[\g1\g2\]\// ) {    # e.g. "^/[Pp]|[Pp]/"
                $brackets = "/$1 $1/";
            }
        }
        $brackets =~ s/\|/ /;
        return $brackets;
    }

    sub brnext {
        my ( $brkresult, $brnextbt ) = @_;
        my $textwindow = $::textwindow;
        ::hidepagenums();
        $textwindow->tagRemove( 'highlight', '1.0', 'end' );
        while (1) {

            last unless defined $::lglobal{brbrackets}[1];    # No attempt to close markup

            # The list of matches below must be the same as the radio buttons in sub orphanedbrackets
            if ( $::lglobal{brsel} eq '»|«' ) {
                last
                  unless ( $::lglobal{brbrackets}[0] eq '»'
                    && $::lglobal{brbrackets}[1] eq '«' );
            } elsif ( $::lglobal{brsel} eq '«|»' ) {
                last
                  unless ( $::lglobal{brbrackets}[0] eq '«'
                    && $::lglobal{brbrackets}[1] eq '»' );
            } elsif ( $::lglobal{brsel} eq "\x{201c}|\x{201d}" ) {
                last
                  unless ( $::lglobal{brbrackets}[0] eq "\x{201c}"
                    && $::lglobal{brbrackets}[1] eq "\x{201d}" );
            } elsif ( $::lglobal{brsel} eq "\x{201e}|\x{201c}" ) {
                last
                  unless ( $::lglobal{brbrackets}[0] eq "\x{201e}"
                    && $::lglobal{brbrackets}[1] eq "\x{201c}" );
            } else {
                last
                  unless (
                    (
                           ( $::lglobal{brbrackets}[0] =~ m{[\[\(\{<]} )
                        && ( $::lglobal{brbrackets}[1] =~ m{[\]\)\}>]} )
                    )
                    || (   ( $::lglobal{brbrackets}[0] =~ m{^/\*} )
                        && ( $::lglobal{brbrackets}[1] =~ m{^\*/} ) )
                    || (   ( $::lglobal{brbrackets}[0] =~ m{^/#} )
                        && ( $::lglobal{brbrackets}[1] =~ m{^#/} ) )
                    || (   ( $::lglobal{brbrackets}[0] =~ m{^/\$} )
                        && ( $::lglobal{brbrackets}[1] =~ m{^\$/} ) )
                    || (   ( $::lglobal{brbrackets}[0] =~ m{^/p}i )
                        && ( $::lglobal{brbrackets}[1] =~ m{^p/}i ) )
                    || (   ( $::lglobal{brbrackets}[0] =~ m{^/x}i )
                        && ( $::lglobal{brbrackets}[1] =~ m{^x/}i ) )
                    || (   ( $::lglobal{brbrackets}[0] =~ m{^/f}i )
                        && ( $::lglobal{brbrackets}[1] =~ m{^f/}i ) )
                    || (   ( $::lglobal{brbrackets}[0] =~ m{^/l}i )
                        && ( $::lglobal{brbrackets}[1] =~ m{^l/}i ) )
                    || (   ( $::lglobal{brbrackets}[0] =~ m{^/i}i )
                        && ( $::lglobal{brbrackets}[1] =~ m{^i/}i ) )
                    || (   ( $::lglobal{brbrackets}[0] =~ m{^/c}i )
                        && ( $::lglobal{brbrackets}[1] =~ m{^c/}i ) )
                    || (   ( $::lglobal{brbrackets}[0] =~ m{^/r}i )
                        && ( $::lglobal{brbrackets}[1] =~ m{^r/}i ) )
                  );
            }
            shift @{ $::lglobal{brbrackets} };
            shift @{ $::lglobal{brbrackets} };
            shift @{ $::lglobal{brindices} };
            shift @{ $::lglobal{brindices} };
            $::lglobal{brbrackets}[0] = $::lglobal{brbrackets}[0] || '';
            $::lglobal{brbrackets}[1] = $::lglobal{brbrackets}[1] || '';
            last unless @{ $::lglobal{brbrackets} };
        }
        if ( @{ $::lglobal{brbrackets} } && $::lglobal{brindices}[0] ) {
            $textwindow->markSet( 'insert', $::lglobal{brindices}[0] )
              if $::lglobal{brindices}[0];
            $textwindow->see( $::lglobal{brindices}[0] )
              if $::lglobal{brindices}[0];
            $textwindow->tagAdd(
                'highlight',
                $::lglobal{brindices}[0],
                $::lglobal{brindices}[0] . '+' . ( length( $::lglobal{brbrackets}[0] ) ) . 'c'
            ) if $::lglobal{brindices}[0];
            $textwindow->tagAdd(
                'highlight',
                $::lglobal{brindices}[1],
                $::lglobal{brindices}[1] . '+' . ( length( $::lglobal{brbrackets}[1] ) ) . 'c'
            ) if $::lglobal{brindices}[1];
            $textwindow->focus;
        } else {
            my $brackets = printable_brackets( $::lglobal{brsel} );
            ::operationadd("Found no more orphaned $brackets");
            $brkresult->configure( -text => "No more orphaned $brackets found." );
            $brnextbt->configure( -text => 'Next', -state => 'disabled' );
            $textwindow->tagRemove( 'highlight', '1.0', 'end' );
            ::soundbell();
        }
    }
}

sub orphanedmarkup {
    searchpopup();
    searchoptset(qw/0 x x 1/);
    $::lglobal{searchentry}->delete( 0, 'end' );
    $::lglobal{searchentry}
      ->insert( 'end', "<(?!tb)(\\w+)>(\\n|[^<])+<(?!/\\1>)|<(?!/?(tb|sc|[bfgi])>)" );
    $::lglobal{searchbutton}->invoke;
}

sub searchsize {    # Pop up a window where you can adjust the search history size
    my $top = $::top;
    if ( $::lglobal{srchhistsizepop} ) {
        $::lglobal{srchhistsizepop}->deiconify;
        $::lglobal{srchhistsizepop}->raise;
    } else {
        $::lglobal{srchhistsizepop} = $top->Toplevel;
        $::lglobal{srchhistsizepop}->title('Search History Size');
        my $frame =
          $::lglobal{srchhistsizepop}->Frame->pack( -fill => 'x', -padx => 5, -pady => 5 );
        $frame->Label( -text => 'History Size: # of terms to save - ' )->pack( -side => 'left' );
        my $entry = $frame->Entry(
            -background   => $::bkgcolor,
            -width        => 5,
            -textvariable => \$::history_size,
            -validate     => 'key',
            -vcmd         => sub {
                return 1 unless $_[0];
                return 0 if ( $_[0] =~ /\D/ );
                return 0 if ( $_[0] < 1 );
                return 0 if ( $_[0] > 200 );
                return 1;
            },
        )->pack( -side => 'left', -fill => 'x' );
        my $frame2 =
          $::lglobal{srchhistsizepop}->Frame->pack( -fill => 'x', -padx => 5, -pady => 5 );
        $frame2->Button(
            -text    => 'OK',
            -width   => 10,
            -command => sub {
                ::savesettings();
                ::killpopup('srchhistsizepop');
            }
        )->pack;
        $::lglobal{srchhistsizepop}->resizable( 'no', 'no' );
        ::initialize_popup_with_deletebinding('srchhistsizepop');
        $::lglobal{srchhistsizepop}->raise;
        $::lglobal{srchhistsizepop}->focus;
    }
}

# Do not move from guiguts.pl; do command must be run in main
sub loadscannos {
    my $top = $::top;
    $::lglobal{scannosfilename} = '';
    %::scannoslist = ();
    @{ $::lglobal{scannosarray} } = ();
    $::lglobal{scannosindex} = 0;
    my $types = [ [ 'Scannos', ['.rc'] ], [ 'All Files', ['*'] ], ];
    $::lglobal{scannosfilename} = $top->getOpenFile(
        -filetypes  => $types,
        -title      => 'Scannos list?',
        -initialdir => $::scannospath
    );

    if ( $::lglobal{scannosfilename} ) {
        unless ( my $return = ::dofile( $::lglobal{scannosfilename} ) ) {    # load scannos list
            unless ( defined $return ) {
                if ($@) {
                    $top->messageBox(
                        -icon    => 'error',
                        -message => 'Could not parse scannos file, file may be corrupted.',
                        -title   => 'Problem with file',
                        -type    => 'Ok',
                    );
                } else {
                    $top->messageBox(
                        -icon    => 'error',
                        -message => 'Could not find scannos file.',
                        -title   => 'Problem with file',
                        -type    => 'Ok',
                    );
                }
                $::lglobal{doscannos} = 0;
                return 0;
            }
        }
        foreach ( sort ( keys %::scannoslist ) ) {
            push @{ $::lglobal{scannosarray} }, $_;
        }
        if ( $::lglobal{scannosfilename} =~ /reg/i ) {
            searchoptset(qw/0 0 x 1/);    # For a regex scannos file, force regex flag and case-sensitive
        } else {
            searchoptset(qw/x x x 0/);
        }
        return 1;
    }
}

sub replace_incr_counter {
    my $counter    = 1;
    my $textwindow = $::textwindow;
    my $pos        = '1.0';
    $textwindow->addGlobStart;
    while (1) {
        my $newpos = $textwindow->search( '-exact', '--', '[::]', "$pos", 'end' );
        last unless $newpos;
        $textwindow->delete( "$newpos", "$newpos+4c" );
        $textwindow->insert( "$newpos", $counter );
        $pos = $newpos;
        $counter++;
    }
    $textwindow->addGlobEnd;
}

#
# Quickly count & report number of occurrences of selected text (case-insensitive, whole-word)
sub quickcount {
    my $textwindow = $::textwindow;

    # Get string to be searched for
    my @ranges      = $textwindow->tagRanges('sel');
    my $range_total = @ranges;
    return unless @ranges;
    my $end    = pop(@ranges);
    my $start  = pop(@ranges);
    my $string = $textwindow->get( $start, $end );

    # Escape any regex metacharacters, and force whole-word searching
    $string = '(?<!\p{Alnum})' . ::escape_regexmetacharacters($string) . '(?!\p{Alnum})';

    # Loop through whole file, counting number of occurrences
    my $length      = 0;
    my $count       = 0;
    my $searchstart = "1.0";
    while (
        $searchstart = $textwindow->search(
            '-regexp', '-nocase',
            '-count' => \$length,
            '--', $string, $searchstart, 'end'
        )
    ) {
        ++$count;
        $searchstart = "$searchstart + $length c";
    }

    # Inform user
    my $dlg = $::top->Dialog(
        -text    => "Count: $count",
        -bitmap  => "info",
        -title   => "Count",
        -buttons => ['Ok']
    );
    $dlg->Tk::bind( '<Escape>' => sub { $dlg->Subwidget('B_Ok')->invoke; } );
    $dlg->Show;
}
1;
