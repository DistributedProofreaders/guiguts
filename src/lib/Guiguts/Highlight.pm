package Guiguts::Highlight;
use strict;
use warnings;

BEGIN {
    use Exporter();
    our ( @ISA, @EXPORT );
    @ISA = qw(Exporter);
    @EXPORT =
      qw(&scannosfile &hilite &hiliteremove &hilitesinglequotes &hilitedoublequotes &hilitepopup &highlight_scannos
      &highlight_quotbrac &hilite_alignment_start &hilite_alignment_stop &hilite_alignment_toggle
      &hilitematch &hilitematchfind &hilitematchtag &hilitematchvoid);
}

my $TAGCH = "[a-z0-9]";    # Permissible characters in HTML tag name

# Routine to find highlight word list
sub scannosfile {
    my $top = $::top;
    $::scannoslistpath = ::os_normal($::scannoslistpath);
    my $types       = [ [ 'Text file', [ '.txt', ] ], [ 'All Files', ['*'] ], ];
    my $scannosfile = $top->getOpenFile(
        -title      => 'List of words to highlight?',
        -filetypes  => $types,
        -initialdir => $::scannoslistpath
    );
    if ($scannosfile) {
        $::scannoslist = $scannosfile;
        my ( $name, $path, $extension ) = ::fileparse( $::scannoslist, '\.[^\.]*$' );
        $::scannoslistpath = $path;
        ::highlight_scannos() if ($::scannos_highlighted);
        %{ $::lglobal{wordlist} } = ();
        ::highlight_scannos();
        read_word_list();
    }
    return;
}
##routine to automatically highlight words in the text
sub highlightscannos {
    my $textwindow = $::textwindow;
    my $top        = $::top;
    return 0 unless $::scannos_highlighted;
    unless ( $::lglobal{wordlist} ) { read_word_list(); }
    my ( $fileend, undef ) = split /\./, $textwindow->index('end');
    if ( $::lglobal{hl_index} < $fileend ) {
        for ( 0 .. 99 ) {
            my $textline = $textwindow->get( "$::lglobal{hl_index}.0", "$::lglobal{hl_index}.end" );
            while ( $textline =~ s/ [^\p{Alnum} ]|[^\p{Alnum} ] |[^\p{Alnum} ][^\p{Alnum} ]/  / ) {
            }
            $textline =~ s/^'|[,']+$/"/;
            $textline =~ s/--/  /g;
            my @words = split( /[^'\p{Alnum},-]+/, $textline );
            for my $word (@words) {
                if ( defined $::lglobal{wordlist}->{$word} ) {
                    my $indx = 0;
                    my $index;
                    while (1) {
                        $index = index( $textline, $word, $indx );
                        last if ( $index < 0 );
                        $indx = $index + length($word);
                        if ( $index > 0 ) {
                            next
                              if ( $textwindow->get("$::lglobal{hl_index}.@{[$index-1]}") =~
                                m{\p{Alnum}} );
                        }
                        next
                          if (
                            $textwindow->get("$::lglobal{hl_index}.@{[$index + length $word]}") =~
                            m{\p{Alnum}} );
                        $textwindow->tagAdd(
                            'scannos',
                            "$::lglobal{hl_index}.$index",
                            "$::lglobal{hl_index}.$index +@{[length $word]}c"
                        );
                    }
                }
            }
            $::lglobal{hl_index}++;
            last if ( $::lglobal{hl_index} > $fileend );
        }
    }
    my $idx1 = $textwindow->index('@0,0');    # First visible line in text widget
    $::lglobal{visibleline} = $idx1;
    $textwindow->tagRemove( 'scannos', $idx1,
        $textwindow->index( '@' . $textwindow->width . ',' . $textwindow->height ) );
    my ( $dummy, $ypix ) = $textwindow->dlineinfo($idx1);
    my $theight = $textwindow->height;
    my $oldy    = my $lastline = -99;
    while (1) {
        my $idx = $textwindow->index( '@0,' . "$ypix" );
        ( my $realline ) = split( /\./, $idx );
        my ( $x, $y, $wi, $he ) = $textwindow->dlineinfo($idx);
        my $textline = $textwindow->get( "$realline.0", "$realline.end" );
        while ( $textline =~ s/ [^\p{Alnum} ]|[^\p{Alnum} ] |[^\p{Alnum} ][^\p{Alnum} ]/  / ) {
        }
        $textline =~ s/^'|[,']+$/"/;
        $textline =~ s/--/  /g;
        my @words = split( /[^'\p{Alnum},-]/, $textline );

        for my $word (@words) {
            if ( defined $::lglobal{wordlist}->{$word} ) {
                my $indx = 0;
                my $index;
                while (1) {
                    $index = index( $textline, $word, $indx );
                    last if ( $index < 0 );
                    $indx = $index + length($word);
                    if ( $index > 0 ) {
                        next
                          if ( $textwindow->get("$realline.@{[$index - 1]}") =~ m{\p{Alnum}} );
                    }
                    next
                      if (
                        $textwindow->get("$realline.@{[$index + length $word]}") =~ m{\p{Alnum}} );
                    $textwindow->tagAdd( 'scannos', "$realline.$index",
                        "$realline.$index +@{[length $word]}c" );
                }
            }
        }
        last unless defined $he;
        last if ( $oldy == $y );    #line is the same as the last one
        $oldy = $y;
        $ypix += $he;
        last
          if $ypix >= ( $theight - 1 );    #we have reached the end of the display
        last if ( $y == $ypix );
    }
    return;
}

sub read_word_list {
    my $top = $::top;
    ::scannosfile() unless ( defined $::scannoslist && -e $::scannoslist );
    return 0        unless $::scannoslist;
    if ( open my $fh, '<', $::scannoslist ) {
        while (<$fh>) {
            utf8::decode($_);
            if ( $_ =~ 'scannoslist' ) {
                my $dialog = $top->Dialog(
                    -text    => 'Warning: File must contain only a list of words.',
                    -bitmap  => 'warning',
                    -title   => 'Warning!',
                    -buttons => ['OK'],
                );
                my $answer = $dialog->Show;
                $::scannos_highlighted = 0;
                undef $::scannoslist;
                return;
            }
            $_ =~ s/^\x{FFEF}?// if ( $. < 2 );
            s/\cM\cJ|\cM|\cJ//g;
            next unless length $_;
            my @words = split /[\s \xA0]+/, $_;
            for my $word (@words) {
                next unless length $word;
                $word =~ s/^\p{Punct}*|\p{Punct}*$//g;
                $::lglobal{wordlist}->{$word} = '';
            }
        }
    } else {
        warn "Cannot open $::scannoslist: $!";
        return 0;
    }
}

sub hilite {
    my $textwindow = $::textwindow;
    my $top        = $::top;
    my $mark       = shift;
    my $matchtype  = shift;

    $mark = quotemeta($mark) if $matchtype eq 'exact';
    my @ranges      = $textwindow->tagRanges('sel');
    my $range_total = @ranges;
    my ( $index, $lastindex );

    if ( $range_total == 0 ) {
        return;
    } else {
        my $end            = pop(@ranges);
        my $start          = pop(@ranges);
        my $thisblockstart = $start;
        $lastindex = $start;
        my $thisblockend = $end;
        hiliteremove();
        my $length;
        while ($lastindex) {
            $index = $textwindow->search(
                '-regexp',
                -count => \$length,
                '--', $mark, $lastindex, $thisblockend
            );
            $textwindow->tagAdd( 'quotemark', $index, $index . ' +' . $length . 'c' )
              if $index;
            if   ($index) { $lastindex = "$index+1c" }
            else          { $lastindex = '' }
        }
    }
}

# Remove all highlights from file
sub hiliteremove {
    my $textwindow = $::textwindow;
    $textwindow->tagRemove( 'highlight', '1.0', 'end' );
    $textwindow->tagRemove( 'quotemark', '1.0', 'end' );
    hilite_alignment_stop();
    $::nohighlights = 0;
    ::highlight_quotbrac();
}

# Highlight straight and curly single quotes in selection
sub hilitesinglequotes {
    hilite( '[\'\x{2018}\x{2019}]', 'regex' );
}

# Highlight straight and curly double quotes in selection
sub hilitedoublequotes {
    hilite( '["\x{201c}\x{201d}]', 'regex' );
}

# Popup for highlighting arbitrary characters in selection
sub hilitepopup {
    my $textwindow = $::textwindow;
    my $top        = $::top;
    ::hidepagenums();
    if ( defined( $::lglobal{hilitepop} ) ) {
        $::lglobal{hilitepop}->deiconify;
        $::lglobal{hilitepop}->raise;
        $::lglobal{hilitepop}->focus;
    } else {
        $::lglobal{hilitepop} = $top->Toplevel;
        $::lglobal{hilitepop}->title('Character Highlight');
        ::initialize_popup_with_deletebinding('hilitepop');
        my $hilitemode = 'exact';
        my $f          = $::lglobal{hilitepop}->Frame->pack( -side => 'top', -anchor => 'n' );
        $f->Label( -text => 'Highlight Character(s) or Regex', )
          ->pack( -side => 'top', -pady => 2, -padx => 2, -anchor => 'n' );
        my $entry = $f->Entry(
            -width      => 40,
            -background => $::bkgcolor,
            -relief     => 'sunken',
        )->pack(
            -expand => 1,
            -fill   => 'x',
            -padx   => 3,
            -pady   => 3,
            -anchor => 'n'
        );
        my $f2 = $::lglobal{hilitepop}->Frame->pack( -side => 'top', -anchor => 'n' );
        $f2->Radiobutton(
            -variable    => \$hilitemode,
            -selectcolor => $::lglobal{checkcolor},
            -value       => 'exact',
            -text        => 'Exact',
        )->grid( -row => 0, -column => 1 );
        $f2->Radiobutton(
            -variable    => \$hilitemode,
            -selectcolor => $::lglobal{checkcolor},
            -value       => 'regex',
            -text        => 'Regex',
        )->grid( -row => 0, -column => 2 );
        my $f3 = $::lglobal{hilitepop}->Frame->pack( -side => 'top', -anchor => 'n' );
        $f3->Button(
            -activebackground => $::activecolor,
            -command          => sub {

                if ( $textwindow->markExists('selstart') ) {
                    $textwindow->tagAdd( 'sel', 'selstart', 'selend' );
                }
            },
            -text  => 'Previous Selection',
            -width => 16,
        )->grid( -row => 1, -column => 1, -padx => 2, -pady => 2 );
        $f3->Button(
            -activebackground => $::activecolor,
            -command          => sub { $textwindow->tagAdd( 'sel', '1.0', 'end' ) },
            -text             => 'Select Whole File',
            -width            => 16,
        )->grid( -row => 1, -column => 2, -padx => 2, -pady => 2 );
        $f3->Button(
            -activebackground => $::activecolor,
            -command          => sub { hilite( $entry->get, $hilitemode ) },
            -text             => 'Apply Highlights',
            -width            => 16,
        )->grid( -row => 2, -column => 1, -padx => 2, -pady => 2 );
        $f3->Button(
            -activebackground => $::activecolor,
            -command          => \&::hiliteremove,
            -text             => 'Remove Highlight',
            -width            => 16,
        )->grid( -row => 2, -column => 2, -padx => 2, -pady => 2 );
    }
}

sub highlight_scannos {    # Enable / disable word highlighting in the text
    my $textwindow = $::textwindow;
    my $top        = $::top;
    if ($::scannos_highlighted) {
        $::lglobal{hl_index} = 1;
        highlightscannos();
        $::lglobal{scannos_highlightedid} = $top->repeat( 400, \&highlightscannos );
    } else {
        $::lglobal{scannos_highlightedid}->cancel
          if $::lglobal{scannos_highlightedid};
        undef $::lglobal{scannos_highlightedid};
        $textwindow->tagRemove( 'scannos', '1.0', 'end' );
    }
    ::savesettings();
}

#
# Enable/disable quote/bracket highlighting in the text
sub highlight_quotbrac {
    my $textwindow = $::textwindow;
    my $top        = $::top;
    if ($::nohighlights) {
        highlightquotbrac();
        $::lglobal{quotbrac_highlightedid} = $top->repeat( 400, \&highlightquotbrac );
    } else {
        $::lglobal{quotbrac_highlightedid}->cancel if $::lglobal{quotbrac_highlightedid};
        undef $::lglobal{quotbrac_highlightedid};
        highlight_quotbrac_remove();
    }
    ::savesettings();
}

#
# Action routine to highlight quotes/brackets
# Calls to HighlightSinglePairBracketingCursor adapted from TextEdit.pm
sub highlightquotbrac {
    my $textwindow = $::textwindow;
    my $top        = $::top;
    return 0 unless $::nohighlights;
    $textwindow->HighlightSinglePairBracketingCursor( '(', ')', '[()]', 'CURSOR_HIGHLIGHT_PARENS',
        'CURSOR_HIGHLIGHT_PARENS', 0 );
    $textwindow->HighlightSinglePairBracketingCursor( '{', '}', '[{}]', 'CURSOR_HIGHLIGHT_CURLIES',
        'CURSOR_HIGHLIGHT_CURLIES', 0 );
    $textwindow->HighlightSinglePairBracketingCursor( '[', ']', '[][]', 'CURSOR_HIGHLIGHT_BRACES',
        'CURSOR_HIGHLIGHT_BRACES', 0 );
    $textwindow->HighlightSinglePairBracketingCursor(
        '"', '"', '"',
        'CURSOR_HIGHLIGHT_DOUBLEQUOTE',
        'CURSOR_HIGHLIGHT_DOUBLEQUOTE', 0
    );
    $textwindow->HighlightSinglePairBracketingCursor(
        "\x{201c}", "\x{201d}", "[\x{201c}\x{201d}]",
        'CURSOR_HIGHLIGHT_DOUBLECURLY',
        'CURSOR_HIGHLIGHT_DOUBLECURLY', 0
    );
    $textwindow->HighlightSinglePairBracketingCursor(
        "'", "'", "'",
        'CURSOR_HIGHLIGHT_SINGLEQUOTE',
        'CURSOR_HIGHLIGHT_SINGLEQUOTE', 0
    );
    $textwindow->HighlightSinglePairBracketingCursor(
        "\x{2018}", "\x{2019}", "[\x{2018}\x{2019}]",
        'CURSOR_HIGHLIGHT_SINGLECURLY',
        'CURSOR_HIGHLIGHT_SINGLECURLY', 0
    );
}

#
# Remove quote/bracket highlighting tags from file
sub highlight_quotbrac_remove {
    my $textwindow = $::textwindow;
    $textwindow->tagRemove( 'CURSOR_HIGHLIGHT_PARENS',      '1.0', 'end' );
    $textwindow->tagRemove( 'CURSOR_HIGHLIGHT_CURLIES',     '1.0', 'end' );
    $textwindow->tagRemove( 'CURSOR_HIGHLIGHT_BRACES',      '1.0', 'end' );
    $textwindow->tagRemove( 'CURSOR_HIGHLIGHT_DOUBLEQUOTE', '1.0', 'end' );
    $textwindow->tagRemove( 'CURSOR_HIGHLIGHT_DOUBLECURLY', '1.0', 'end' );
    $textwindow->tagRemove( 'CURSOR_HIGHLIGHT_SINGLEQUOTE', '1.0', 'end' );
    $textwindow->tagRemove( 'CURSOR_HIGHLIGHT_SINGLECURLY', '1.0', 'end' );
}

#
# Start alignment highlighter at column of current insert position
sub hilite_alignment_start {
    hilite_alignment_stop();    # Cancel any previous highlight repeat

    # Set global variable to contain current column
    return unless $::lglobal{highlightalignmentcolumn} = $::textwindow->index('insert');
    $::lglobal{highlightalignmentcolumn} =~ s/.+\.//;

    # Repeatedly call highlighting routine to keep up to date
    $::lglobal{align_id}           = $::top->repeat( 200, \&hilite_alignment );
    $::lglobal{highlightalignment} = 1;
}

#
# Stop alignment highlighter
sub hilite_alignment_stop {
    $::lglobal{align_id}->cancel if $::lglobal{align_id};
    undef $::lglobal{align_id};
    $::lglobal{highlightalignment} = 0;
    $::textwindow->tagRemove( 'alignment', '1.0', 'end' );    # Remove any existing tags
}

#
# Toggle alignment highlighter
sub hilite_alignment_toggle {
    if ( $::lglobal{highlightalignment} ) {
        ::hilite_alignment_stop();
    } else {
        ::hilite_alignment_start();
    }
}

#
# Refresh alignment highlight
sub hilite_alignment {
    my $textwindow = $::textwindow;

    $textwindow->tagRemove( 'alignment', '1.0', 'end' );    # Remove any existing tags
    my $top = $textwindow->index('@0,0');                   # Find top line visible on screen (line at pixel 0,0)
    my ( $line, $col ) = split( /\./, $top );
    $col = $::lglobal{highlightalignmentcolumn} - 1;        # Highlight column immediately preceding cursor for consistency with ruler

    # Add tags to each subsequent line that is visible on-screen, unless line is too short
    while ( $textwindow->compare( "$line.0", "<", "end" ) and $textwindow->dlineinfo("$line.0") ) {
        my ( $ldummy, $maxcol ) = split( /\./, $textwindow->index("$line.0 lineend") );
        $textwindow->tagAdd( 'alignment', "$line.$col" ) unless $col < 0 or $col >= $maxcol;
        $line++;
    }
}

#
# Highlight character/tag that matches the selected one,
# or if nothing selected, match the one adjacent to cursor
sub hilitematch {
    my $textwindow = $::textwindow;

    $textwindow->tagRemove( 'highlight', '1.0', 'end' );

    my ( $selection, $start, $end, $adjafter, $adjbefore, $htmltag );
    my @ranges = $textwindow->tagRanges('sel');
    if (@ranges) {    # Character/string is selected
        $end   = pop(@ranges);
        $start = pop(@ranges);
    } else {          # Nothing selected - work from cursor position
        $start = $end = 'insert';

        # If character after or before insert position has a match, then use that,
        # otherwise leave empty selection for HTML tag searching below
        # Note, checking "after" first to correspond with fact that cursor is
        # placed before match (see end of routine)
        my $achr = $textwindow->get( $start, "$start +1c" );
        my ( $amatch, $dummy ) = hilitematchpair($achr);
        if ($amatch) {
            $end .= " +1c";
        } else {
            my $bchr = $textwindow->get( "$start -1c", $start );
            my ( $bmatch, $dummy ) = hilitematchpair($bchr);
            $start .= " -1c" if $bmatch;
        }
    }

    $selection = $textwindow->get( $start,             $end );
    $adjafter  = $textwindow->get( $end,               "$end lineend" );
    $adjbefore = $textwindow->get( "$start linestart", $start );

    # Check simple pairs, e.g. brackets, quotes
    my ( $matchstr, $reverse ) = hilitematchpair($selection);

    # No single character match, so look around for HTML tag
    unless ($matchstr) {
        if ( $selection !~ />$/ and $adjafter =~ /^(<?\/?$TAGCH*)/ ) {    # look forward for more unless already have end of tag in selection
            $selection .= $1;
            $end       .= '+' . length($1) . 'c';
        }
        if ( $selection !~ /^</ && $adjbefore =~ /(<?\/?$TAGCH*>?)$/ ) {    # look back for more unless already have start of tag in selection
            $selection = $1 . $selection;
            $start .= '-' . length($1) . 'c';
        }
        $end .= '-1c' if $selection =~ s/^(<\/?$TAGCH+)>$/$1/;              # Remove closing > - permits match if cursor just after "</div>"

        ( $matchstr, $reverse ) = hilitematchtag($selection);
    }

    my $index;
    if ($matchstr) {
        $index = hilitematchfind( $start, $end, $selection, $matchstr, $reverse );
        if ($index) {
            $textwindow->tagAdd( 'highlight', $start, $end );
            $textwindow->tagAdd( 'highlight', $index, $index . ' +' . length($matchstr) . 'c' );
            $textwindow->tagRemove( 'sel', '1.0', 'end' );

            # For HTML tags, position cursor inside tag; for simple pairs, just before character
            # to correspond with checking "after" first (see top of routine)
            # Repeated use of Find Match should then re-find matching one, rather than adjacent
            my $inside = 0;
            if ( $matchstr =~ /^</ ) {
                $inside = $matchstr =~ /^<\// ? 2 : 1;
            }
            $textwindow->markSet( 'insert', "$index +$inside c" );
            $textwindow->see('insert');
        }
    }
    ::soundbell() unless $index;    # Match not found (or attempt to match unsupported string)
}

#
# Given the location of the selected string and its matching string,
# find the matching occurrence in the file, returning index to its location.
# Keep track of depth to cope with nested quotes, brackets, tags, etc.
sub hilitematchfind {
    my $start      = shift;
    my $end        = shift;
    my $selection  = shift;
    my $match      = shift;
    my $reverse    = shift;
    my $textwindow = $::textwindow;

    # Regex searches for either the tag or its match, since if nested you may find the tag
    # several times before finding the matches.
    my $regexp = "(\Q$match\E|\Q$selection\E)";

    # If an HTML tag, don't want "<b" to match "</blockquote...", for example,
    # so use negative lookahead to ensure there's not an alphanumeric character
    # after "</b".
    $regexp .= "(?!$TAGCH)" if substr( $selection, 0, 1 ) eq '<';

    my $index;
    my $length;
    my $depth = 1;
    while ( $depth > 0 ) {    # Keep going until we get back to match at same level
        $index = $textwindow->search(
            ( $reverse ? '-backwards' : '-forwards' ),
            '-regexp',
            '-count' => \$length,
            '--',
            $regexp,
            ( $reverse ? $start : $end ),
            ( $reverse ? '1.0'  : 'end' )
        );
        last unless ($index);

        # Found match or another occurrence of the selected tag, so adjust depth
        my $found = $textwindow->get( $index, "$index + $length c" );
        $depth += $found eq $selection ? 1 : -1;

        # Adjust start position of next search
        if ($reverse) {
            $start = $index;
        } else {
            $end = "$index + $length c";
        }
    }
    return $index;
}

#
# Return matching pair to given character and whether given character
# was closing/right member of pair
sub hilitematchpair {
    my $selection = shift;
    my $right     = 0;
    my $match     = '';

    # Don't add angle brackets to this list, because they will clash with HTML tag markup
    my @pairs = (
        [ '(',        ')' ],
        [ '[',        ']' ],
        [ '{',        '}' ],
        [ "\x{201c}", "\x{201d}" ],
        [ "\x{2018}", "\x{2019}" ],
    );
    for my $pairr (@pairs) {
        if ( $selection eq $pairr->[0] ) {
            $match = $pairr->[1];
            last;
        }
        if ( $selection eq $pairr->[1] ) {
            $match = $pairr->[0];
            $right = 1;
            last;
        }
    }
    return ( $match, $right );
}

#
# Return matching tag for given tag and whether given string was closing tag
# Expects something like "<div" or "</div"
sub hilitematchtag {
    my $selection = shift;
    my $right     = 0;
    my $match     = '';
    if ( $selection =~ /^<\// ) {
        $right = 1;
        $match = '<' . substr( $selection, 2 );
    } elsif ( $selection =~ /^</ ) {
        $match = '</' . substr( $selection, 1 );
    }
    return ( $match, $right );
}

#
# Return true if given tag is for a void element,
# i.e. does not need separate open/close tags
sub hilitematchvoid {
    my $tag   = shift;
    my @voids = (
        'area', 'base', 'br',    'col',    'embed', 'hr', 'img', 'input',
        'link', 'meta', 'param', 'source', 'track', 'wbr',
    );
    $tag =~ s/<?\/?($TAGCH+)>?/$1/;
    return grep { /^$tag$/ } @voids;
}
1;
