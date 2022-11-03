#$Id: TextUnicode.pm 1138 2012-02-22 04:41:14Z hmonroe $
package TextUnicode;
use strict;
use warnings;
use base qw(Tk::TextEdit);
use File::Temp qw/tempfile/;
use File::Basename;
use constant OS_Win => $^O =~ /Win/;
Construct Tk::Widget 'TextUnicode';

# Custom File load routine; will automatically handle Unicode and line endings
sub Load {
    my ( $w, $filename ) = @_;
    $filename = $w->FileName unless ( defined($filename) );
    return 0 unless defined $filename;
    if ( open my $fh, '<', $filename ) {
        $w->MainWindow->Busy;
        $w->EmptyDocument;
        my $count = 1;
        my $progress;
        my $line = <$fh>;
        if ($line) {
            utf8::decode($line);
            $line =~ s/^\x{FEFF}?//;
            $line =~ s/\cM\cJ|\cM|\cJ/\n/g;
            $w->ntinsert( 'end', $line );
        }
        while (<$fh>) {
            utf8::decode($_);
            $_ =~ s/\cM\cJ|\cM|\cJ/\n/g;
            $_ =~ s/[\t \xA0]+$//;
            $w->ntinsert( 'end', $_ );
            if ( ( $count++ % 1000 ) == 0 ) {
                $progress = $w->TextUndoFileProgress(
                    Loading => $filename,
                    $count, tell($fh), -s $filename
                );
            }
        }
        close($fh);
        $progress->withdraw if defined $progress;
        $w->markSet( 'insert' => '1.0' );
        $w->FileName($filename);
        $w->MainWindow->Unbusy;
    } else {
        my $msg = "Cannot open $filename:$!.";
        $w->messageBox(
            -icon    => 'warning',
            -title   => 'Warning',
            -type    => 'OK',
            -message => $msg . ( OS_Win ? " (Are you using Windows Explorer Preview?)" : "" ),
        );
        $w->BackTrace($msg);
    }
}

# Custom file save routine to handle unicode files
sub SaveUTF {
    my ( $w, $filename ) = @_;
    $filename = $w->FileName unless defined $filename;
    my $dir   = dirname($filename);
    my $perms = ( stat($dir) )[2] & 07777;
    unless ( $perms & 0200 ) {
        $perms = $perms | 0200;
        chmod $perms, $dir
          or $w->BackTrace("Can not write to directory $dir: $!\n")
          and return;
    }
    my ( $tempfh, $tempfilename ) = tempfile( DIR => $dir );
    my $status;
    my $count = 0;
    my $index = '1.0';
    my $progress;
    my $fileend = $w->index('end -1c');
    my ($lines) = $fileend =~ /^(\d+)\./;

    while ( $w->compare( $index, '<', $fileend ) ) {
        my $end  = $w->index("$index lineend +1c");
        my $line = $w->get( $index, $end );
        $line =~ s/[\t \xA0]+$//;
        $line =~ s/\cM\cJ|\cM|\cJ/\cM\cJ/g;    # Ensure DP-style (CRLF) line endings
        utf8::encode($line);
        $w->BackTrace("Cannot write to temp file:$!\n") and return
          unless print $tempfh $line;
        $index = $end;
        if ( ( $count++ % 1000 ) == 0 ) {
            $progress = $w->TextUndoFileProgress(
                Saving => $filename,
                $count, $count, $lines
            );
        }
    }
    $progress->withdraw if defined $progress;
    close $tempfh;
    my $permsave;
    if ( -e $filename ) {
        $permsave = ( stat($filename) )[2] & 0777;
        chmod 0777, $filename;
        unlink $filename;
    }
    if ( rename( $tempfilename, $filename ) ) {
        chmod $permsave, $filename if $permsave;    # copy file permissions if overwriting
                                                    #$w->ResetUndo; #serves no purpose to reset undo
        $w->FileName($filename);
        return 1;
    } else {
        my $msg = "Cannot save $filename:$!. Text is in the temporary file $tempfilename.";
        $w->messageBox(
            -icon    => 'warning',
            -title   => 'Warning',
            -type    => 'OK',
            -message => $msg . ( OS_Win ? " (Are you using Windows Explorer Preview?)" : "" ),
        );
        $w->BackTrace($msg);
        return 0;
    }
}

#Custom File Include routine to handle Unicode and line ends
sub IncludeFile {
    my ( $w, $filename ) = @_;
    unless ( defined($filename) ) {
        $w->BackTrace('filename not specified');
        return;
    }
    if ( open my $fh, '<', $filename ) {
        $w->Busy;
        my $count = 1;
        $w->addGlobStart;
        my $progress;
        my $line = <$fh>;
        utf8::decode($line);
        $line =~ s/^\x{FFEF}?//;
        $line =~ s/\cM\cJ|\cM|\cJ/\n/g;
        $line =~ s/[\t \xA0]+$//;
        $w->insert( 'insert', $line );

        while (<$fh>) {
            utf8::decode($_);
            $_ =~ s/\cM\cJ|\cM|\cJ/\n/g;
            $_ =~ s/[\t \xA0]+$//;
            $w->insert( 'insert', $_ );
            if ( ( $count++ % 1000 ) == 0 ) {
                $progress = $w->TextUndoFileProgress(
                    Including => $filename,
                    $count, tell($fh), -s $filename
                );
            }
        }
        $progress->withdraw if defined $progress;
        $w->addGlobEnd;
        close $fh;
        $w->Unbusy;
    } else {
        $w->BackTrace("Cannot open $filename:$!");
    }
}

sub ntinsert {    # no undo tracking insert
    my ( $w, $index, $string ) = @_;
    $w->Tk::Text::insert( $index, $string );
}

sub ntdelete {    # no undo tracking delete
    my ( $w, $start, $end ) = @_;
    $end = "$start +1c" unless $end;
    $w->Tk::Text::delete( $start, $end );
}

# Override TextUndo::insert_UNDO to avoid bug when undoing multi-line insert in the case
# when the string ends in a newline character. See code for details.
sub insert_UNDO {
    my $w      = shift;
    my $index  = shift;
    my $string = '';

    # This possible call: ->insert (index, string, tag, string, tag...);
    # if more than one string, keep reading strings in (discarding tags)
    # until all strings are read in and $string contains entire text inserted.
    while (@_) {
        $string .= shift;
        shift if (@_);    # discard tag
    }

    # calculate index
    # possible things to insert:
    # carriage return
    # single character (not CR)
    # single line of characters (not ending in CR)
    # single line of characters ending with a CR
    # multi-line characters. last line does not end with CR
    # multi-line characters, last line does end with CR.
    my ( $line, $col ) = split( /\./, $index );

    # START of changed code
    # In Tk::TextUndo original, $string is tested against /\n(.*)$/ to check for newlines in the
    # string, and sets $col to length($1). However, this does not correctly give 0 when last char
    # is newline, giving length of last full line instead. This causes undo to delete too much.
    my $lastnl = rindex( $string, "\n" );
    if ( $lastnl >= 0 ) {
        $line += $string =~ tr/\n/\n/;
        $col = length($string) - $lastnl - 1;
    }    # END of changed code
    else {
        $col += length($string);
    }
    return [ 'delete', $index, $line . '.' . $col ];
}

sub replacewith {    #One step cut and insert without undo tracking
    my ( $w, $start, $end, $string ) = @_;
    $w->tagRemove( 'sel', '1.0', 'end' );
    $w->tagAdd( 'sel', $start, $end );
    $w->ReplaceSelectionsWith($string);
}

# Override TextUndo::ReplaceSelectionsWith
# Default behaviour on text replacement was for all
# page markers to move to start of replacement string.
#
# If it finds page markers within the string to be replaced,
# this version inserts replacement text in the same proportions
# between page numbers as the original string was
sub ReplaceSelectionsWith {
    my ( $w, $new_text ) = @_;

    my @ranges      = $w->tagRanges('sel');
    my $range_total = @ranges;

    # if nothing selected, then ignore
    return if ( $range_total == 0 );

    $w->addGlobStart;

    # insert marks where selections are located
    # marks will move with text even as text is inserted and deleted
    # in a previous selection.
    for ( my $i = 0 ; $i < $range_total ; $i++ ) {
        $w->markSet( 'mark_sel_' . $i => $ranges[$i] );
    }

    # for every selected mark pair, insert new text and delete old text
    my ( $first, $last );
    for ( my $i = 0 ; $i < $range_total ; $i = $i + 2 ) {
        $first = $w->index( 'mark_sel_' . $i );
        $last  = $w->index( 'mark_sel_' . ( $i + 1 ) );

        # If whole file is selected, $last ends up at the start of the line after
        # the last actual line, which results in part of the inserted string being deleted.
        # Bug is in the original TextUndo version too
        $last = $w->index( $last . ' -1c' ) if $w->compare( $last, '==', 'end' );

        # First pass through page markers to store length of old string
        # from start to each page marker in @lengths.
        # In reverse order to avoid a replace affecting positions for the next
        my @lengths;
        my $mark = $last;
        while ( $mark = $w->markPrevious($mark) ) {
            next unless ( $mark =~ m{Pg(\S+)} );          # Only look at page markers
            last if $w->compare( $mark, '<', $first );    # Stop if before start of old string

            my $fmstring = $w->get( $first, $mark );
            my $fmlen    = length $fmstring;
            push( @lengths, $fmlen );
        }

        # Set gravity of page marker after string to "right" to keep it after string
        # It doesn't matter if it's not immediately after - no harmful effect since restored later
        my $end_mark = "";    # Assume there isn't one
        $mark = $last;
        while ( $mark = $w->markNext($mark) ) {
            if ( $mark =~ m{Pg(\S+)} ) {    # Only look at page markers
                $end_mark = $mark;
                $w->markGravity( $end_mark, 'right' );
                last;
            }
        }

        if ( !@lengths ) {    # No page markers, so simply insert new and delete old text
            $w->insert( $last, $new_text );
            $w->delete( $first, $last );
        } else {              # We found page markers, so need to place text round them
                              # Scale string lengths based on ratio of new and old text lengths
            my $newlen = length $new_text;
            my $oldlen = length $w->get( $first, $last );
            foreach (@lengths) {
                $_ = int( $_ * $newlen / $oldlen + 0.5 );
            }
            unshift( @lengths, $newlen );    # first element is whole length of new string

            # Second pass through page markers to replace the text in chunks
            # In reverse order to avoid one replace affecting positions for the next
            $mark = $last;
            my $prev = $last;
            my $idx  = 0;
            while ( $mark = $w->markPrevious($mark) ) {
                next unless ( $mark =~ m{Pg(\S+)} );          # Only look at page markers
                last if $w->compare( $mark, '<', $first );    # Stop if before start of old string
                next if ( $mark eq $prev );                   # Skip if we find same position again

                $w->markGravity( $prev, 'right' ) if ( $prev =~ m{Pg(\S+)} );    # Keep page marker to right of replaced string
                $w->delete( $mark, $prev );
                $w->insert(
                    $mark,
                    substr(
                        $new_text, $lengths[ $idx + 1 ], $lengths[$idx] - $lengths[ $idx + 1 ]
                    )
                );
                $w->markGravity( $prev, 'left' ) if ( $prev =~ m{Pg(\S+)} );     # Restore page marker behaviour
                $prev = $mark;
                ++$idx;
            }

            # delete final (first) chunk and insert remainder
            $w->markGravity( $prev, 'right' ) if ( $prev =~ m{Pg(\S+)} );    # Keep page marker to right of replaced string
            $w->delete( $first, $prev );
            $w->insert( $first, substr( $new_text, 0, $lengths[$idx] ) );
            $w->markGravity( $prev, 'left' ) if ( $prev =~ m{Pg(\S+)} );     # Restore page marker behaviour
        }

        # restore gravity for page mark after replaced text
        $w->markGravity( $end_mark, 'left' ) if $end_mark;
    }

    # set the insert cursor to the end of the last insertion mark
    $w->markSet( 'insert', $w->index( 'mark_sel_' . ( $range_total - 1 ) ) );

    # delete the marks
    for ( my $i = 0 ; $i < $range_total ; $i++ ) {
        $w->markUnset( 'mark_sel_' . $i );
    }

    $w->addGlobEnd;
}

sub shiftB1_Motion {    # Alternate selection mode, for block selection
    my ($w) = @_;
    return unless defined $Tk::mouseMoved;
    my $Ev = $w->XEvent;
    $Tk::x = $Ev->x;
    $Tk::y = $Ev->y;
    $w->SelectTo( $Ev->xy, 'block' );
    Tk::break;
}

sub Button1 {
    my ( $w, $x, $y ) = @_;
    $w->eventGenerate('<<ScrollDismiss>>');
    $Tk::selectMode = 'char';
    $Tk::mouseMoved = 0;
    $w->SetCursor("\@$x,$y");
    $w->markSet( 'anchor', 'insert' );
    $w->focus if ( $w->cget('-state') eq 'normal' );
}

#
# Modified selectWord/Line routines from Text.pm bound to double/triple click
# Originals end with
#   Tk::catch { $w->markSet('insert','sel.first') }
# but that overrides SelectTo's positioning of cursor to improve subsequent selection extension
sub selectWord {
    my ($w) = @_;
    my $Ev = $w->XEvent;
    $w->SelectTo( $Ev->xy, 'word' );
}

sub selectLine {
    my ($w) = @_;
    my $Ev = $w->XEvent;
    $w->SelectTo( $Ev->xy, 'line' );
}

#
# Modified selection routine from Text.pm to deal with block selections
# Also uses safeword() - see below
#
# This procedure is invoked to extend the selection, typically when
# dragging it with the mouse. Depending on the selection mode (character,
# word, line) it selects in different-sized units. This procedure
# ignores mouse motions initially until the mouse has moved from
# one character to another or until there have been multiple clicks.
#
# Arguments:
# w - The text window in which the button was pressed.
# index - Index of character at which the mouse button was pressed.
sub SelectTo {
    my ( $w, $index, $mode ) = @_;
    $Tk::selectMode = $mode if defined $mode;
    my $cur    = $w->index($index);
    my $anchor = Tk::catch { $w->index('anchor') };
    if ( !defined $anchor ) {
        $w->markSet( 'anchor', $anchor = $cur );
        $Tk::mouseMoved = 0;
    } elsif ( $w->compare( $cur, '!=', $anchor ) ) {
        $Tk::mouseMoved = 1;
    }
    $Tk::selectMode = 'char' unless ( defined $Tk::selectMode );
    $mode           = $Tk::selectMode;
    my ( $first, $last );
    if ( $mode eq 'char' ) {
        if ( $w->compare( $cur, '<', 'anchor' ) ) {
            $first = $cur;
            $last  = 'anchor';
        } else {
            $first = 'anchor';
            $last  = $cur;
        }
    } elsif ( $mode eq 'word' ) {
        if ( $w->compare( $cur, '<', 'anchor' ) ) {
            $first = $w->index( $w->safeword( "$cur + 1c wordstart", 'strictword' ) );
            $last  = $w->index( $w->safeword( 'anchor - 1c wordend', 'strictword' ) );
        } else {
            $first = $w->index( $w->safeword( 'anchor + 1c wordstart', 'strictword' ) );
            $last  = $w->index( $w->safeword( "$cur wordend",          'strictword' ) );
        }
    } elsif ( $mode eq 'line' ) {
        if ( $w->compare( $cur, '<', 'anchor' ) ) {
            $first = $w->index("$cur linestart");
            $last  = $w->index('anchor - 1c lineend + 1c');
        } else {
            $first = $w->index('anchor linestart');
            $last  = $w->index("$cur lineend + 1c");
        }
    } elsif ( $mode eq 'block' ) {
        my ( $srow, $scol, $erow, $ecol );
        $w->tagRemove( 'sel', '1.0', 'end' );
        if ( $w->compare( $cur, '<', 'anchor' ) ) {
            ( $srow, $scol ) = split /\./, $cur;
            ( $erow, $ecol ) = split /\./, $w->index('anchor');
        } else {
            ( $erow, $ecol ) = split /\./, $cur;
            ( $srow, $scol ) = split /\./, $w->index('anchor');
        }
        if ( $ecol < $scol ) {
            ( $scol, $ecol ) = ( $ecol, $scol );
        }
        if ( "$erow.$ecol" eq $w->index("$erow.$ecol lineend") ) {
            for ( $srow .. $erow ) {
                $w->tagAdd( 'sel', "$_.$scol", "$_.$ecol lineend" );
            }
        } else {
            for ( $srow .. $erow ) {
                $w->tagAdd( 'sel', "$_.$scol", "$_.$ecol" );
            }
        }
        $w->idletasks;
        $first = "$srow.$scol";
        $last  = "$erow.$ecol";
        $w->markSet( 'selstart', $first );
        $w->markSet( 'selend',   $last );
    }
    if ( ( $Tk::mouseMoved || $Tk::selectMode ne 'char' )
        && $Tk::selectMode ne 'block' ) {
        $w->tagRemove( 'sel', '1.0', $first );
        $w->tagAdd( 'sel', $first, $last );
        $w->tagRemove( 'sel', $last, 'end' );
        $w->markSet( 'selstart', $first );
        $w->markSet( 'selend',   $last );
        $w->idletasks;
    }

    # Change to default behavior of Text.pm:
    # When user selects word or line via double/triple click, force the anchor to the start
    # and the cursor to the end for more predictable selection extension behavior.
    if ( $mode eq 'word' or $mode eq 'line' ) {
        $w->markSet( 'anchor', $first );
        $w->markSet( 'insert', $last );
    } elsif ( $w->compare( $cur, '<', $last ) ) {
        $w->markSet( 'insert', $cur );
    } else {
        $w->markSet( 'insert', $last );
    }
}

# Taken from Text.pm with addition of safeword() to safely find the start and end
# of a word - see safeword() for details
#
# SetCursor
# Move the insertion cursor to a given position in a text. Also
# clears the selection, if there is one in the text, and makes sure
# that the insertion cursor is visible.
#
# Arguments:
# w - The text window.
# pos - The desired new position for the cursor in the window.
sub SetCursor {
    my ( $w, $pos ) = @_;
    $pos = $w->safeword($pos);
    $pos = 'end - 1 chars' if $w->compare( $pos, '==', 'end' );
    $w->markSet( 'insert', $pos );
    $w->unselectAll;
    $w->see('insert');
}

# Taken from Text.pm with addition of safeword() to safely find the start and end
# of a word - see safeword() for details
#
# KeySelect
# This procedure is invoked when stroking out selections using the
# keyboard. It moves the cursor to a new position, then extends
# the selection to that position.
#
# Arguments:
# w - The text window.
# new - A new position for the insertion cursor (the cursor has not
# actually been moved to this position yet).
sub KeySelect {
    my ( $w, $new ) = @_;
    $new = $w->safeword($new);

    my ( $first, $last );
    if ( !defined $w->tag( 'ranges', 'sel' ) ) {

        # No selection yet
        $w->markSet( 'anchor', 'insert' );
        if ( $w->compare( $new, '<', 'insert' ) ) {
            $w->tagAdd( 'sel', $new, 'insert' );
        } else {
            $w->tagAdd( 'sel', 'insert', $new );
        }
    } else {

        # Selection exists
        if ( $w->compare( $new, '<', 'anchor' ) ) {
            $first = $new;
            $last  = 'anchor';
        } else {
            $first = 'anchor';
            $last  = $new;
        }
        $w->tagRemove( 'sel', '1.0', $first );
        $w->tagAdd( 'sel', $first, $last );
        $w->tagRemove( 'sel', $last, 'end' );
    }
    $w->markSet( 'insert', $new );
    $w->see('insert');
    $w->idletasks;
}

#
# Replaces indexes of form "xxx wordstart" or "xxx wordend" with the index
# of the start or end of the word - internal Tk processing of these
# fails with some Unicode strings - either treating an accented character as a
# non-word character, or giving "Malformed UTF-8 character" errors
#
# Note this version interprets "wordend" as the beginning of the next word,
# not the end of the current word since this is more common in modern editors
# This can be overridden by passing a true value for the optional "strictword" argument
#
# A sequence of word characters counts as a "word", as does a sequence of
# non-word non-space characters. Apostrophes count as word characters
#
# Start & end of line always count as word breaks
sub safeword {
    my $w          = shift;
    my $pos        = shift;
    my $strictword = shift;
    my $new        = '';

    # Word characters include straight & curly apostrophes, although this means
    # that close single quotes also count as word characters.
    # The most widely-used word processor displays the same behavior
    my $REGWORD = "[\\w'\x{2019}]";
    my $REGNONW = "[^\\w'\x{2019}]";

    # Backward
    if ( $pos =~ s/ wordstart// ) {

        # If already at start of file, stay there
        if ( $w->compare( $pos, '<=', '1.0' ) ) {
            $new = '1.0';
        }

        # If at start of line return end of previous line
        elsif ( $w->compare( $pos, '==', "$pos linestart" ) ) {
            $new = $w->index("$pos - 1l lineend");

        } else {
            my $ch = $w->get("$pos - 1c");    # get character before insert position

            # If after space, skip spaces and resample non-space character
            if ( $ch =~ ' ' ) {
                $new = $w->search( '-regexp', '-backwards', '--', '[^ ]', "$pos - 1c",
                    "$pos linestart" );    # Trap later if all space to start of line (i.e. $new undefined)
                $ch = $w->get($new) if $new;
            } else {
                $new = $w->index("$pos - 1c");
            }

            # Find start of sequence of word or non-word characters by searching
            # back for the opposite character (non-word or word) or a space
            # If none found, return start of line
            if ($new) {
                my $reg = $w->get($new) =~ $REGWORD ? $REGNONW : $REGWORD;
                $new =
                  $w->search( '-regexp', '-backwards', '--', "($reg| )", $new, "$pos linestart" );
                $new = $w->index("$new + 1c")      if $new;
                $new = $w->index("$pos linestart") if not $new;
            }

            # All space to start of line ($new undefined) - return start of line
            else {
                $new = $w->index("$pos linestart");
            }
        }
        return $new;
    }

    # Forward
    elsif ( $pos =~ s/ wordend// ) {
        my $ch = $w->get($pos);    # get character after insert position

        # If already at end of file, stay there
        if ( $w->compare( $pos, '>=', 'end-1c' ) ) {
            $new = 'end-1c';
        }

        # If at end of line return start of next line,
        elsif ( $w->compare( $pos, '==', "$pos lineend" ) ) {
            $new = $w->index("$pos + 1l linestart") if not $new;
        }

        # If before space, return next non-space on this line,
        # or return end of line
        elsif ( $ch =~ ' ' ) {
            $new = $w->search( '-regexp', '--', '[^ ]', "$pos", "$pos lineend" );
            $new = $w->index("$pos lineend") if not $new;
        }

        # Must be before non-space character
        # Find end of sequence of word or non-word characters by searching
        # for the opposite character (non-word or word) or a space
        # Then skip spaces (unless "strictword" mode)
        else {
            my $reg = $ch =~ $REGWORD ? $REGNONW : $REGWORD;
            $new = $w->search( '-regexp', '--', "($reg| )", "$pos", "$pos lineend" );
            $new = $w->search( '-regexp', '--', '[^ ]',     "$new", "$pos lineend" )
              if $new and not $strictword;
            $new = $w->index("$pos lineend") if not $new;
        }
        return $new;
    }

    # Neither wordstart nor wordend was specified
    return $pos;
}

#modified Column Cut & Copy routine to handle block selection
sub Column_Copy_or_Cut {
    my ( $w, $cut ) = @_;
    my @ranges = $w->tagRanges('sel');
    return unless @ranges;
    my $start = $ranges[0];
    $w->clipboardClear;
    while (@ranges) {
        my $start_index = shift @ranges;
        my $end_index   = shift @ranges;
        my $string      = $w->get( $start_index, $end_index );
        $w->clipboardAppend( $string . "\n" );
        if ($cut) {
            my $replace = $w->{'OVERSTRIKE_MODE'} ? ' ' x length $string : '';
            $w->replacewith( $start_index, $end_index, $replace );
        }
    }
    $w->markSet( 'insert', $start );
}

#modified Column Paste routine to handle block selection
sub clipboardColumnPaste {
    my ($w)           = @_;
    my $current_index = $w->index('insert');
    my @ranges        = $w->tagRanges('sel');
    if (@ranges) {
        for (@ranges) {
            my $end   = pop @ranges;
            my $start = pop @ranges;
            if ( $w->OverstrikeMode ) {
                $w->replacewith( $start, $end, ( ' ' x ( length $w->get( $start, $end ) ) ) );
            } else {
                $w->delete( $start, $end );
            }
        }
    }
    my $clipboard_text;
    eval { $clipboard_text = $w->SelectionGet( -selection => "CLIPBOARD" ); };
    return unless ( defined $clipboard_text and length $clipboard_text );
    my ( $current_line, $current_column ) = split /\./, $current_index;
    my @clipboard_lines = split /\n/, $clipboard_text;
    foreach my $line (@clipboard_lines) {
        my $lineend = $w->index("$current_line.$current_column lineend");
        my ( $lerow, $lecol ) = split( /\./, $lineend );
        if ( $lecol < $current_column ) {
            $w->insert( $lineend, ( ' ' x ( $current_column - $lecol ) ) );
            $lineend = $w->index("$current_line.$current_column lineend");
        }
        if ( $w->OverstrikeMode ) {
            my $string = $w->get( "$current_line.$current_column", $lineend );
            if ( ( length $string ) >= ( length $line ) ) {
                $w->replacewith( "$current_line.$current_column",
                    ( $w->index("$current_line.$current_column +@{[length $line]}c") ), $line );
            } else {
                $w->delete( "$current_line.$current_column", $lineend );
                $w->insert( "$current_line.$current_column", $line );
            }
        } else {
            $w->insert( "$current_line.$current_column", $line );
        }
        $current_line++;
    }
    $w->markSet( 'insert', $current_index );
}

#
# Find the bounding box for a character, but never returns undefined values
# Must only be used when the character is known to be visible on-screen
# Avoids bug where a Zero Width No-Break Space / or Byte Order Mark returns
# undefined values instead of sensible ones
# In that case, this routine returns x,y and height of whole line, and zero width
sub bbox_safe {
    my $w     = shift;
    my $index = shift;
    my ( $bx, $by, $bw, $bh ) = $w->bbox($index);
    if ( not defined $bx ) {    # zero-width character - use line measures except for width
        my ( $lx, $ly, $lw, $lh ) = $w->dlineinfo($index);
        $bx = $lx;
        $by = $ly;
        $bw = 0;
        $bh = $lh;
    }
    return ( $bx, $by, $bw, $bh );
}

sub UpDownLine {
    my ( $w, $n ) = @_;
    $w->see('insert');
    my $i = $w->index('insert');
    my ( $line, $char ) = split( /\./, $i );
    my $testX;    #used to check the "new" position
    my $testY;    #used to check the "new" position
    my ( $bx, $by, $bw, $bh ) = $w->bbox_safe($i);
    my ( $lx, $ly, $lw, $lh ) = $w->dlineinfo($i);

    if ( ( $n == -1 ) and ( $by <= $bh ) ) {

        #On first display line.. so scroll up and recalculate..
        $w->yview( 'scroll', -1, 'units' );
        unless ( ( $w->yview )[0] ) {

            #first line of entire text - keep same position.
            return $i;
        }
        ( $bx, $by, $bw, $bh ) = $w->bbox_safe($i);
        ( $lx, $ly, $lw, $lh ) = $w->dlineinfo($i);
    } elsif ( ( $n == 1 )
        and ( $ly + $lh ) >
        ( $w->height - 2 * $w->cget( -bd ) - 2 * $w->cget( -highlightthickness ) - $lh + 1 ) ) {

        #On last display line.. so scroll down and recalculate..
        $w->yview( 'scroll', 1, 'units' );
        ( $bx, $by, $bw, $bh ) = $w->bbox_safe($i);
        ( $lx, $ly, $lw, $lh ) = $w->dlineinfo($i);
    }

    # Calculate the vertical position of the next display line
    my $Yoffset = 0;
    $Yoffset = $by - $ly + 1       if ( $n == -1 );
    $Yoffset = $ly + $lh + 1 - $by if ( $n == 1 );
    $Yoffset *= $n;
    $testY = $by + $Yoffset;

    # Save the original 'x' position of the insert cursor if:
    # 1. This is the first time through -- or --
    # 2. The insert cursor position has changed from the previous
    #    time the up or down key was pressed -- or --
    # 3. The cursor has reached the beginning or end of the widget.
    if ( not defined $w->{'origx'}
        or ( ( defined $w->{'lastindex'} ) && ( $w->{'lastindex'} != $i ) ) ) {
        $w->{'origx'} = $bx;
    }

    # Try to keep the same column if possible
    $testX = $w->{'origx'};

    # Get the coordinates of the possible new position
    my $testindex = $w->index("\@$testX,$testY");
    $w->see($testindex);
    my ( $nx, $ny, $nw, $nh ) = $w->bbox_safe($testindex);

    # Which side of the character should we position the cursor -
    # mainly for a proportional font
    if ( $testX > $nx + $nw / 2 ) {
        $testX = $nx + $nw + 1;
    }
    my $newindex = $w->index("\@$testX,$testY");
    return $i
      if ( $w->compare( $newindex, '==', 'end - 1 char' )
        and ( $ny == $ly ) );

    # Then we are trying to the 'end' of the text from
    # the same display line - don't do that
    $w->{'lastindex'} = $newindex;
    $w->see($newindex);
    return $newindex;
}

sub InsertKeypress {    # Supress inserting control characters into the text
    my ( $w, $char ) = @_;
    $w->SUPER::InsertKeypress($char) if ( ord($char) > 26 );
    $w->eventGenerate('<<ScrollDismiss>>');
}

# Modified to generate autoscroll events and accellerated scrolling.
sub AutoScan {
    my ($w) = @_;
    $w->eventGenerate('<<autoscroll>>');
    if ( $Tk::y >= $w->height ) {
        my $scroll = int( ( $Tk::y - $w->height )**2 / 1000 );
        $w->yview( 'scroll', $scroll, 'units' );
    } elsif ( $Tk::y < 0 ) {
        my $scroll = int( ( $Tk::y - $w->height )**2 / 1000 );
        $w->yview( 'scroll', -$scroll, 'units' );
    } elsif ( $Tk::x >= $w->width ) {
        $w->xview( 'scroll', 2, 'units' );
    } elsif ( $Tk::x < 0 ) {
        $w->xview( 'scroll', -2, 'units' );
    } else {
        return;
    }
    $w->SelectTo( '@' . $Tk::x . ',' . $Tk::y );
    $w->RepeatId( $w->after( 70, [ 'AutoScan', $w ] ) );
}

1;
