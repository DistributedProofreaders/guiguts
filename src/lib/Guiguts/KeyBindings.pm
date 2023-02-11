package Guiguts::KeyBindings;
use strict;
use warnings;

BEGIN {
    use Exporter();
    our ( @ISA, @EXPORT );
    @ISA    = qw(Exporter);
    @EXPORT = qw( &keybindings &keybind );
}

sub keybindings {
    my $textwindow = $::textwindow;
    my $top        = $::top;

    # Highlight
    keybind( '<Control-comma>',       sub { ::hilitesinglequotes(); } );
    keybind( '<Control-period>',      sub { ::hilitedoublequotes(); } );
    keybind( "<Control-$::altkey-h>", sub { ::hilitepopup(); } );
    keybind( '<Control-Shift-a>',     sub { ::hilite_alignment_toggle(); } );
    keybind( '<Control-0>',           sub { ::hiliteremove(); } );
    keybind(
        '<Control-semicolon>',
        sub {
            $::nohighlights = 1 - $::nohighlights;
            ::highlight_quotbrac();
        }
    );

    # File
    keybind( '<Control-o>',       sub { ::file_open($textwindow); } );
    keybind( '<Control-s>',       sub { ::savefile(); } );
    keybind( '<Control-Shift-s>', sub { ::file_saveas($textwindow); } );

    # Select, copy, paste
    keybind( '<Control-a>',           sub { $textwindow->selectAll; } );
    keybind( '<Control-c>',           sub { ::textcopy(); }, '<<Copy>>' );
    keybind( '<Control-x>',           sub { ::cut(); },      '<<Cut>>' );
    keybind( '<Control-v>',           sub { ::paste(); } );
    keybind( "<Control-$::altkey-v>", sub { ::paste('alternative'); } );    # to avoid Perl/Tk paste bug
    keybind( '<F1>',                  sub { ::colcopy($textwindow); } );
    keybind( '<F2>',                  sub { ::colcut($textwindow); } );
    keybind( '<F3>',                  sub { ::colpaste($textwindow); } );

    # Tools
    keybind( '<F5>',       sub { ::wordfrequency(); } );
    keybind( '<F6>',       sub { ::errorcheckpop_up( $textwindow, $top, 'Bookloupe' ); } );
    keybind( '<F7>',       sub { ::spellchecker(); } );
    keybind( '<Shift-F7>', sub { ::errorcheckpop_up( $textwindow, $top, 'Spell Query' ); } );
    keybind( '<F8>',       sub { ::stealthscanno(); } );

    # Delete
    keybind(
        '<Delete>',
        sub {
            my @ranges      = $textwindow->tagRanges('sel');
            my $range_total = @ranges;
            if ($range_total) {
                $textwindow->addGlobStart;
                while (@ranges) {
                    my $end   = pop @ranges;
                    my $start = pop @ranges;
                    $textwindow->delete( $start, $end );
                }
                $textwindow->addGlobEnd;
                $top->break;
            } else {
                $textwindow->Delete;
            }
        }
    );
    keybind(
        '<Control-BackSpace>',
        sub {
            my $end = $textwindow->index('insert');
            $textwindow->SetCursor('insert wordstart');
            $textwindow->delete( 'insert', $end );
        },
        '<<BackSpaceWord>>'
    );
    keybind(
        '<Control-Delete>',
        sub {
            my $start = $textwindow->index('insert');
            $textwindow->SetCursor('insert wordend');
            $textwindow->delete( $start, 'insert' );
        },
        '<<ForwardDeleteWord>>'
    );

    # Case
    keybind( '<Control-l>', sub { ::case( $textwindow, 'lc' ); } );
    keybind( '<Control-u>', sub { ::case( $textwindow, 'uc' ); } );
    keybind( '<Control-t>', sub { ::case( $textwindow, 'tc' ); $top->break; } );

    # Undo, redo
    keybind(
        '<Control-z>',
        sub {
            $textwindow->undo;
            $textwindow->tagRemove( 'highlight', '1.0', 'end' );
            $textwindow->see('insert');
        },
        '<<Undo>>'
    );
    keybind(
        '<Control-y>',
        sub {
            $textwindow->redo;
            $textwindow->see('insert');
        },
        '<<Redo>>'
    );
    keybind( '<Control-Shift-z>', undef, '<<Redo>>' );    # Add another key-combination

    # Search
    keybind( '<Control-f>',       sub { ::searchpopup(); } );
    keybind( '<Control-Shift-f>', sub { ::quicksearchpopup(); } );
    keybind(
        '<Control-g>',
        sub {
            if ( $::lglobal{searchpop} ) {
                ::update_sr_histories();
                my $searchterm = $::lglobal{searchentry}->get;
                ::searchtext($searchterm);
            } else {
                ::searchpopup();
            }
        },
        '<<FindNext>>'
    );
    keybind(
        '<Control-Shift-g>',
        sub {
            if ( $::lglobal{searchpop} ) {
                ::update_sr_histories();
                my $searchterm = $::lglobal{searchentry}->get;
                $::lglobal{searchop2}->toggle;
                ::searchtext($searchterm);
                $::lglobal{searchop2}->toggle;
            } else {
                ::searchpopup();
            }
        },
        '<<FindNextReverse>>'
    );
    keybind(
        '<Control-b>',
        sub {
            if ( $::lglobal{searchpop} ) {
                ::update_sr_histories();
                my $searchterm = $::lglobal{searchentry}->get;
                ::countmatches($searchterm);
            }
        }
    );
    keybind( '<Control-Shift-B>', sub { ::quickcount(); } );

    # Navigation
    keybind( '<Control-i>',       sub { ::seecurrentimage(); } );
    keybind( '<Control-j>',       sub { ::gotoline(); } );
    keybind( '<Control-p>',       sub { ::gotopage(); } );
    keybind( '<Control-Shift-P>', sub { ::gotolabel(); } );

    # Edit
    keybind(
        '<Control-e>',
        sub {
            if ( $::lglobal{floodpop} ) {
                ::floodfill( $textwindow, $::lglobal{ffchar} );
            } else {
                ::flood();
            }
        }
    );
    keybind(
        '<Control-r>',
        sub {
            if ( $::lglobal{surpop} ) {
                ::surroundit( $::lglobal{surstrt}, $::lglobal{surend}, $textwindow );
            } else {
                ::surround();
            }
        }
    );
    keybind(
        '<Control-w>',
        sub {
            $textwindow->addGlobStart;
            ::selectrewrap();
            $textwindow->addGlobEnd;
        }
    );
    keybind(
        '<Control-Shift-w>',
        sub {
            $textwindow->addGlobStart;
            ::blockrewrap();
            $textwindow->addGlobEnd;
        }
    );

    # Indent
    keybind( '<Control-m>',       sub { ::indent( $textwindow, 'in' ); } );
    keybind( '<Control-Shift-m>', sub { ::indent( $textwindow, 'out' ); } );
    keybind(
        "<Control-$::altkey-m>",
        sub {
            $textwindow->addGlobStart;
            ::indent( $textwindow, 'in' ) for ( 1 .. 4 );
            $textwindow->addGlobEnd;
        }
    );
    keybind(
        "<Control-$::altkey-Shift-m>",
        sub {
            $textwindow->addGlobStart;
            ::indent( $textwindow, 'out' ) for ( 1 .. 4 );
            $textwindow->addGlobEnd;
        }
    );
    keybind( "<$::altkey-Left>",  sub { ::indent( $textwindow, 'out' ); } );
    keybind( "<$::altkey-Right>", sub { ::indent( $textwindow, 'in' ); } );

    # Help
    keybind( "<Control-$::altkey-r>", sub { ::display_manual("regexref"); } );

    # Mouse
    keybind( '<Shift-B1-Motion>', sub { $textwindow->shiftB1_Motion(@_); } );
    keybind( '<ButtonRelease-2>', sub { ::popscroll() unless $Tk::mouseMoved } );
    keybind( '<<ScrollDismiss>>', sub { ::scrolldismiss(); } );
    keybind( '<FocusIn>',         sub { $::lglobal{hasfocus} = $textwindow; } );

    keybind( '<3>', [ \&::showcontextmenu, ::Ev('X'), ::Ev('Y') ] );

    # Extra bindings for Mac
    if ($::OS_MAC) {
        keybind( '<Meta-q>',          sub { ::_exit(); } );
        keybind( '<Meta-s>',          sub { ::savefile(); } );
        keybind( '<Meta-a>',          sub { $textwindow->selectAll; } );
        keybind( '<Meta-c>',          sub { ::textcopy(); } );
        keybind( '<Meta-x>',          sub { ::cut(); } );
        keybind( '<Meta-v>',          sub { ::paste(); } );
        keybind( '<Meta-f>',          sub { ::searchpopup(); } );
        keybind( '<Meta-z>',          undef, '<<Undo>>' );
        keybind( '<Meta-y>',          undef, '<<Redo>>' );
        keybind( '<Meta-Up>',         [ 'SetCursor', '1.0' ] );
        keybind( '<Meta-Shift-Up>',   [ 'KeySelect', '1.0' ] );
        keybind( '<Meta-Down>',       [ 'SetCursor', 'end-1c' ] );
        keybind( '<Meta-Shift-Down>', [ 'KeySelect', '1.0' ] );
    }

    # Bookmarks - multiple key-combinations to allow for keyboard differences
    keybind( '<Control-Shift-exclam>',         sub { ::setbookmark('1'); }, '<<SetBkmk1>>' );
    keybind( '<Control-Shift-at>',             sub { ::setbookmark('2'); }, '<<SetBkmk2>>' );
    keybind( '<Control-Shift-quotedbl>',       undef,                       '<<SetBkmk2>>' );
    keybind( '<Control-Shift-numbersign>',     sub { ::setbookmark('3'); }, '<<SetBkmk3>>' );
    keybind( '<Control-Shift-sterling>',       undef,                       '<<SetBkmk3>>' );
    keybind( '<Control-Shift-section>',        undef,                       '<<SetBkmk3>>' );
    keybind( '<Control-Shift-periodcentered>', undef,                       '<<SetBkmk3>>' );
    keybind( '<Control-Shift-dollar>',         sub { ::setbookmark('4'); }, '<<SetBkmk4>>' );
    keybind( '<Control-Shift-currency>',       undef,                       '<<SetBkmk4>>' );
    keybind( '<Control-Shift-percent>',        sub { ::setbookmark('5'); }, '<<SetBkmk5>>' );
    keybind( '<Control-KeyPress-1>',           sub { ::gotobookmark('1'); } );
    keybind( '<Control-KeyPress-2>',           sub { ::gotobookmark('2'); } );
    keybind( '<Control-KeyPress-3>',           sub { ::gotobookmark('3'); } );
    keybind( '<Control-KeyPress-4>',           sub { ::gotobookmark('4'); } );
    keybind( '<Control-KeyPress-5>',           sub { ::gotobookmark('5'); } );

    # Compose - define last since user could set the compose key to one of the above that they never use
    keybind( "<$::composepopbinding>", sub { ::composepopup(); } );

    # Override wordstart/end moves because Tk fails to safely find wordstart/end with utf-8 characters.
    # Also bindings were inconsistent in Text.pm, meaning that moving/selecting forward/backward
    # behaved inconsistently.
    # Retain the words 'wordstart' and 'wordend' for ease of comparison, though not totally accurate
    # with the modern algorithm. A better description would be "wordforward" and "word backward".
    # See TextUnicode.pm for more details
    $textwindow->MainWindow->bind( 'TextUnicode', '<Control-Left>',
        [ 'SetCursor', 'insert wordstart' ] );
    $textwindow->MainWindow->bind( 'TextUnicode', '<Shift-Control-Left>',
        [ 'KeySelect', 'insert wordstart' ] );
    $textwindow->MainWindow->bind( 'TextUnicode', '<Control-Right>',
        [ 'SetCursor', 'insert wordend' ] );
    $textwindow->MainWindow->bind( 'TextUnicode', '<Shift-Control-Right>',
        [ 'KeySelect', 'insert wordend' ] );

    # Override Paste binding, so that Entry widgets delete any selected text
    # in the field, just like happens in the main textwindow
    # Note that for this to work, a dummy Entry is created in initialize() routine previously,
    # because default class bindings don't get set up until first Entry is created. So without
    # the dummy widget, the binding below would be overwritten by the default at a later point.
    $textwindow->MainWindow->bind( 'Tk::Entry', '<<Paste>>' => sub { ::entrypaste(shift); }, );

    # Alternative paste to give user a second option if Perl/Tk utf8 bug strikes
    $textwindow->MainWindow->bind( 'Tk::Entry',
        "<Control-$::altkey-v>" => sub { ::entrypaste( shift, 'alternative' ); }, );

    # Override bindings relating to word movement/selection in Entry fields
    $textwindow->MainWindow->bind( 'Tk::Entry',
        '<Control-Left>', [ \&entrysetcursorword, 'backward' ] );
    $textwindow->MainWindow->bind( 'Tk::Entry',
        '<Control-Right>', [ \&entrysetcursorword, 'forward' ] );
    $textwindow->MainWindow->bind( 'Tk::Entry',
        '<Shift-Control-Left>', [ \&entrykeyselectword, 'backward' ] );
    $textwindow->MainWindow->bind( 'Tk::Entry',
        '<Shift-Control-Right>', [ \&entrykeyselectword, 'forward' ] );
    $textwindow->MainWindow->bind( 'Tk::Entry',
        '<Double-1>', [ \&entrymouseselect, Tk::Ev('x'), 'word', 'sel.first' ] );
    $textwindow->MainWindow->bind( 'Tk::Entry',
        '<Double-Shift-1>', [ \&entrymouseselect, Tk::Ev('x'), 'word' ] );
    $textwindow->MainWindow->bind( 'Tk::Entry',
        '<B1-Motion>', [ \&entrymousemotion, Tk::Ev('x'), Tk::Ev('y') ] );
}

# Bind a key-combination to a sub allowing for capslock on/off.
# If capslock is on then pressing Ctrl and "k" does not trigger event
# with <Control-k> bound, so bind <Control-K> to the same event.
# If key-combination does not end in "-k>" where k is in [a-z], no
# uppercase binding is added.
#
# If optional event argument given, link key and event, and bind sub to event.
#
# Safe to call more than once to bind multiple key-combinations to same event:
#	keybind( '<KeyCombo1>', sub { doit(); }, '<<MyEvent>>' );
#	keybind( '<KeyCombo2>', undef,           '<<MyEvent>>' );
#
# Warning: Actually binds event to class TextUnicode rather than the text window
# instance. Currently the main text window is the only instance anyway.
# If changed in the future, see comments below about bindtags order.

sub keybind {
    my $textwindow = $::textwindow;
    my $lkey       = shift;           # Key-combination (lower-case letter)
    my $subr       = shift;           # Subroutine to bind to key/event (undef will unbind)
    my $event      = shift;           # Optional event argument

    $lkey =~ s/-([A-Z])>/-\l$1>/;     # Ensure key letter is lowercase
    my $ukey = $lkey;
    $ukey =~ s/-([a-z])>/-\u$1>/;     # Create uppercase version

    if ( defined $event ) {
        $textwindow->eventAdd( $event => $lkey );
        $textwindow->eventAdd( $event => $ukey ) if $ukey ne $lkey;
        $textwindow->bind( 'TextUnicode', $event => $subr ) if defined $subr;
    } else {
        $textwindow->bind( 'TextUnicode', $lkey => $subr );
        $textwindow->bind( 'TextUnicode', $ukey => $subr ) if $ukey ne $lkey;
    }
}

# Notes on bindtags order in case of future development:
#
# The callback subs executed depend on the bindtags list.
# Default taglist order for Perl/Tk is class, instance, toplevel, all.
# (Tcl/Tk default is instance, class, toplevel, all, so beware when reading docs.)
#
# A callback can "break" out of the taglist search, so if you want to avoid
# default class behaviour for a specific widget, but don't want to change
# it for the whole class, you must reorder the taglist
# so the instance callback precedes the class one (like Tcl/Tk), e.g.
#	my @tags = $widget->bindtags;
#	$widget->bindtags([@tags[1, 0, 2, 3]]);
# Finish instance callback with $widget->break so class callback won't be called

##
## Start of Entry overrides for word navigation/selection
## Entry widgets only consider spaces to be word boundaries. This is particularly a
## problem with hyphenated words, where the Text widget considers them two separate words.
## The default Text widget also has inconsistencies, but they are not dealt with here.
## The routines below are bound to Ctrl-arrow and double-mouse-clicks and treat word
## boundaries the same as Notepad++.
##

#
# Positions the cursor backward or forward one word from its current point
sub entrysetcursorword {
    my $w         = shift;
    my $direction = shift;
    my $new       = entryindexword( $w, $direction, 'insert' );    # Backward or forward one word from insert
    $w->icursor($new);
    $w->selectionClear;
    $w->SeeInsert;
}

#
# Selects backward or forward one word, or extends selection by a word
sub entrykeyselectword {
    my $w         = shift;
    my $direction = shift;
    my $new       = entryindexword( $w, $direction, 'insert' );    # Backward or forward one word from insert
    if ( !$w->selectionPresent ) {
        $w->selectionFrom('insert');
        $w->selectionTo($new);
    } else {
        $w->selectionAdjust($new);
    }
    $w->icursor($new);
    $w->SeeInsert;
}

#
# Code taken from Entry.pm MouseSelect
# Handles character and line selection and mouse dragging
sub entrymouseselect {
    my $w = shift;
    my $x = shift;    # x-coordinate of mouse

    return if UNIVERSAL::isa( $w, 'Tk::Spinbox' ) and $w->{_element} ne 'entry';
    $Tk::selectMode = shift if (@_);    # char, word or line selection
    my $cur = $w->index( $w->ClosestGap($x) );
    return unless defined $cur;
    my $anchor = $w->index('anchor');
    return unless defined $anchor;
    $Tk::pressX ||= $x;

    if ( ( $cur != $anchor ) || ( abs( $Tk::pressX - $x ) >= 3 ) ) {
        $Tk::mouseMoved = 1;
    }
    my $mode = $Tk::selectMode;
    return unless $mode;
    if ( $mode eq 'char' ) {
        if ($Tk::mouseMoved) {
            if ( $cur < $anchor ) {
                $w->selectionTo($cur);
            } else {
                $w->selectionTo( $cur + 1 );
            }
        }
    } elsif ( $mode eq 'word' ) {    # Use our routine to find the start/end of the word
        my ( $start, $end );
        if ( $cur < $w->index('anchor') ) {
            $start = entryindexword( $w, 'backward', $cur );
            $end   = entryindexword( $w, 'forward',  $anchor - 1 );

            # Don't include trailing spaces
            $end-- while substr( $w->get(), $end - 1, 1 ) eq ' ' and $end > $start;
        } else {
            $start = entryindexword( $w, 'backward', $anchor );
            $end   = entryindexword( $w, 'forward',  $cur );

            # Don't include trailing spaces
            $end-- while substr( $w->get(), $end - 1, 1 ) eq ' ' and $end > $start;
        }
        $w->selectionRange( $start, $end );
    } elsif ( $mode eq 'line' ) {
        $w->selectionRange( 0, 'end' );
    }
    if (@_) {
        my $ipos = shift;
        eval { local $SIG{__DIE__}; $w->icursor($ipos) };
    }
    $w->idletasks;
}

#
# Code taken from Entry widget - handles mouse drag, with the change in behaviour
# needed after double-click, which extends select in word chunks
sub entrymousemotion {
    my ( $w, $x, $y ) = @_;
    $Tk::x = $x;
    entrymouseselect( $w, $x );    # Use our routine instead of the default
}

#
# Given an Entry widget and a direction, returns the index
# either backward or forward one "word" from the given index
sub entryindexword {
    my $w         = shift;
    my $direction = shift;              # 'backward' or 'forward'
    my $index     = $w->index(shift);

    my $string = $w->get();
    if ( $direction eq 'backward' ) {
        --$index while $index > 0 and substr( $string, $index - 1, 1 ) =~ '\s';    # skip spaces before cursor
        if ( substr( $string, $index - 1, 1 ) =~ '\w' ) {                          # prev char is a word character
            --$index while $index > 0 and substr( $string, $index - 1, 1 ) =~ '\w';    # skip rest of word
        } else {    # currently on a non-word character (not a space)
            --$index while $index > 0 and substr( $string, $index - 1, 1 ) !~ '[ \w]';    # skip rest of non-word
        }
    } else {
        my $len = length($string);
        if ( substr( $string, $index, 1 ) =~ '\w' ) {                                     # currently on a word character
            ++$index while $index < $len and substr( $string, $index, 1 ) =~ '\w';        # skip rest of word
        } else {    # currently on a non-word character
            ++$index while $index < $len and substr( $string, $index, 1 ) !~ '[ \w]';    # skip rest of non-word
        }
        ++$index while $index < $len and substr( $string, $index, 1 ) =~ ' ';            # skip spaces after word/non-word
    }
    return $index;
}

## End of Entry overrides for word navigation/selection

1;
