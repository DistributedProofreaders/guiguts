package Guiguts::PageSeparators;
use strict;
use warnings;

BEGIN {
    use Exporter();
    our ( @ISA, @EXPORT );
    @ISA    = qw(Exporter);
    @EXPORT = qw(&separatorpopup &delblanklines);
}

sub pageseparatorhelppopup {
    my $top       = $::top;
    my $help_text = <<'EOM';

j -- Join Lines - join lines, remove all blank lines, spaces, asterisks and hyphens
k -- Join, Keep Hyphen - join lines, remove all blank lines, spaces and asterisks, keep hyphen
l -- Blank Line - leave one blank line. Close up any other whitespace (paragraph break)
t -- New Section - leave two blank lines. Close up any other whitespace (section break)
h -- New Chapter - leave four blank lines. Close up any other whitespace (chapter break)
d -- Delete - delete the page separator. Make no other edits
r -- Refresh - search for, highlight and re-center the next page separator
u -- Undo - undo the last edit
e -- Redo - redo the last undo
v -- View - view the current page in the image viewer
a -- Auto - cycle through the automatic modes (No Auto, Auto-Advance, 80% Auto, 99% Auto)
? -- Help - show Page Separator Fixup help

Automatic modes
Auto Advance - automatically search for and center the next page separator after an edit
80% Auto (previously Full) - automatically search for and try conservatively to convert the next page separator
99% Auto - automatically search for and try confidently to convert the next page separator
EOM
    if ( defined( $::lglobal{pagesephelppop} ) ) {
        $::lglobal{pagesephelppop}->deiconify;
        $::lglobal{pagesephelppop}->raise;
        $::lglobal{pagesephelppop}->focus;
    } else {
        $::lglobal{pagesephelppop} = $top->Toplevel;
        $::lglobal{pagesephelppop}
          ->title('Keyboard Shortcuts and Functions for Fixup Page Separators');
        ::initialize_popup_with_deletebinding('pagesephelppop');
        $::lglobal{pagesephelppop}->Label(
            -justify => "left",
            -text    => $help_text
        )->pack;
        my $button_ok = $::lglobal{pagesephelppop}->Button(
            -activebackground => $::activecolor,
            -text             => 'Close',
            -command          => sub { ::killpopup('pagesephelppop'); }
        )->pack;
        $::lglobal{pagesephelppop}->resizable( 'yes', 'yes' );
    }
}

# Called by "Refresh" on Separator popup.
# Wraps single undo around all changes made from this click
sub refreshpageseparatorwrapper {
    my $textwindow = $::textwindow;
    $textwindow->addGlobStart;
    refreshpageseparator();
    $textwindow->addGlobEnd;
}

#
# Search for page separator.
# If automatic, then process it unless 'noauto' argument specified, e.g. after Undo
sub refreshpageseparator {
    my $noauto     = shift;
    my $textwindow = $::textwindow;
    ::hidepagenums();
    findpageseparator();
    $textwindow->tagAdd( 'highlight', $::searchstartindex, $::searchendindex )
      if $::searchstartindex;

    # Handle Automatic
    if ( $::lglobal{pagesepauto} >= 2 and $::searchstartindex ) {
        handleautomaticonrefresh() unless $noauto;
    }
    $textwindow->xviewMoveto(.0);
    $textwindow->markSet( 'insert', "$::searchstartindex+2l" )
      if $::searchstartindex;
}

#
# Once refresh is done, this routine is called to handle auto-joining if needed
sub handleautomaticonrefresh {
    my $textwindow = $::textwindow;
    my $character;
    my ($index);

    # Repeat until no more page separators to join
    # Early exit happens via last if code can't auto-join
    while ($::searchstartindex) {
        $textwindow->markSet( 'page',  $::searchstartindex );        # error here
        $textwindow->markSet( 'page1', "$::searchstartindex+1l" );
        while (1) {
            $index     = $textwindow->index('page');
            $character = $textwindow->get("$index-1c");

            # If the character before ends with \s or \n or -*, (last case cannot happen)
            # delete the character
            if (   ( $character =~ /[\s\n]$/ )
                || ( $character =~ /[\w-]\*$/ ) ) {
                $textwindow->delete("$index-1c");
            } else {
                last;
            }
        }
        $textwindow->insert( $index, "\n" );

        if ( $::lglobal{pagesepauto} == 2 ) {

            # If the last character is a word, ";" or ","
            # and the next character is \n or *, then delete the character
            # Revision: dropped \n
            if ( $character =~ /[\w;,]/ ) {
                while (1) {
                    $index     = $textwindow->index('page1');
                    $character = $textwindow->get($index);
                    if ( $character =~ /[\*]/ ) {    # dropped \n
                        print "deleting:character page1\n";
                        $textwindow->delete($index);
                        last
                          if $textwindow->compare( 'page1 +1l', '>=', 'end' );
                    } else {
                        last;
                    }
                }
            }

            # Join if the next character is lower case or with I
            #print $character.":page?\n";
            if ( ( $character =~ /\p{IsLower}/ ) || ( $character =~ /^I / ) ) {
                processpageseparator('j');
            }
            my ( $r, $c ) = split /\./, $textwindow->index('page-1c');
            my ($size) =
              length( $textwindow->get( 'page+1l linestart', 'page+1l lineend' ) );

            # Insert blank line if the character is ."'?
            if ( ( $character =~ /[\.\"\'\?]/ ) && ( $c < ( $size * 0.5 ) ) ) {
                processpageseparator('l');
            }
        } elsif ( $::lglobal{pagesepauto} == 3 ) {
            my $linebefore = $textwindow->get( "$index -10c",    $index );
            my $lineafter  = $textwindow->get( "$index +1c +1l", "$index +1c +1l +5c" );
            if ( $lineafter =~ /^\n\n\n\n/ ) {
                processpageseparator('h');
            } elsif ( $lineafter =~ /^\n\n/ ) {
                processpageseparator('t');
            } elsif ( $lineafter =~ /^\n/ ) {
                processpageseparator('l');
            } elsif ( $lineafter =~ /^-----File/ ) {
                processpageseparator('l');
            } elsif ( $lineafter =~ /^\S/ ) {
                if ( closeupmarkup() ) {
                    $linebefore = $textwindow->get( "$index -10c",    $index );
                    $lineafter  = $textwindow->get( "$index +1c +1l", "$index +1c +1l +5c" );
                }
                if ( $lineafter =~ /^\n/ ) {    # can be reached if closeupmarkup did something
                    processpageseparator('l');
                } elsif ( $lineafter =~ /^\// ) {
                    last;
                } elsif ( $lineafter =~ /^\*--\S/ ) {
                    processpageseparator('k');
                } elsif ( $lineafter =~ /^-- / ) {
                    processpageseparator('j');
                } elsif ( $lineafter =~ /^\*-- / ) {
                    last;
                } elsif ( $lineafter =~ /^--\S/ ) {
                    last;
                } elsif ( $linebefore =~ /\S--\*$/ ) {
                    processpageseparator('k');
                } elsif ( $linebefore =~ / --$/ ) {
                    processpageseparator('k');
                } elsif ( $linebefore =~ / --\*$/ ) {
                    last;
                } elsif ( $linebefore =~ /\S--$/ ) {
                    last;
                } elsif ( $linebefore =~ /-\*$/ ) {
                    last;
                } elsif ( $linebefore =~ /-$/ ) {
                    processpageseparator('k') if $::rwhyphenspace;
                } else {
                    processpageseparator('j');
                }
            } else {
                last;
            }
        }

        # Get set up for the next page separator (mini-refresh)
        findpageseparator();
        $textwindow->tagAdd( 'highlight', $::searchstartindex, $::searchendindex )
          if $::searchstartindex;
        $textwindow->update unless ::updatedrecently();
    }
}

sub findpageseparator {
    my $textwindow = $::textwindow;
    $textwindow->tagRemove( 'highlight', '1.0', 'end' );
    $::searchstartindex = '1.0';
    $::searchendindex   = '1.0';
    $::searchstartindex =
      $textwindow->search( '-nocase', '-regexp', '--', '^-----*\s?File:',
        $::searchendindex, 'end' );
    unless ($::searchstartindex) {
        ::operationadd('Found last page separator');
        return;
    }
    $::searchendindex = $textwindow->index("$::searchstartindex lineend");
    $textwindow->yview('end');
    $textwindow->see($::searchstartindex) if $::searchstartindex;
}

sub closeupmarkup {
    my $textwindow = $::textwindow;
    my $changemade = 0;
    my $linebefore = $textwindow->get( 'page-1l linestart', 'page-1l lineend' );
    my $lineafter  = $textwindow->get( 'page+1l linestart', 'page+1l lineend' );
    if ( $linebefore =~ /((#|\*|p|x|f|l))\/$/ ) {
        my $closemarkup = "/$1\$";
        $closemarkup = "/\\\*\$" if ( $1 eq '*' );
        if ( $lineafter =~ $closemarkup ) {
            $textwindow->delete( 'page+1l linestart', 'page+1l lineend' );
            $textwindow->delete('page+1l linestart');
            $textwindow->delete( 'page-1l linestart', 'page-1l lineend' );
            $textwindow->delete('page-1l linestart');
            $changemade = 1;
        }
    }
    if ( $linebefore =~ /<\/(i|b|f|g|sc)>([,;*]?)$/ ) {
        my $lengthmarkup = 3 + length($1) + length($2);
        my $lengthpunctuation;
        if ($2) {
            $lengthpunctuation = length($2) if ($2);
        } else {
            $lengthpunctuation = 0;
        }
        my $openmarkup = "^<$1>";
        if ( $lineafter =~ $openmarkup ) {
            $textwindow->delete( 'page+1l linestart',
                'page+1l linestart +' . ( $lengthmarkup - 1 ) . 'c' );
            $textwindow->delete(
                "page-1l lineend-$lengthmarkup" . "c",
                "page-1l lineend-$lengthpunctuation" . "c"
            );
            $changemade = 1;
        }
    } elsif ( $linebefore =~ /\*$/ ) {
        if ( $lineafter =~ /^\*/ ) {
            $textwindow->delete('page+1l linestart');
            $changemade = 1;
        }
    }
    return $changemade;
}

# Process page separator and refresh ready for next one if needed
# Only called via user action, not auto-joining
sub processpageseparatorrefresh {
    my $op         = shift;
    my $textwindow = $::textwindow;
    $textwindow->addGlobStart;    # Single undo around all edits made from this click
    ::hidepagenums();
    processpageseparator($op);
    refreshpageseparator() if $::lglobal{pagesepauto} >= 1;
    $textwindow->addGlobEnd;
}

# Process page separator based on option chosen: j, k, l, t, h, d
# Called either via user action or via auto-joining.
sub processpageseparator {
    my $op         = shift;
    my $textwindow = $::textwindow;
    my ( $line, $index, $r, $c );
    findpageseparator();
    my $pagesep;
    $pagesep = $textwindow->get( $::searchstartindex, $::searchendindex )
      if ( $::searchstartindex && $::searchendindex );
    return unless $pagesep;
    my $pagemark = $pagesep;
    $pagesep =~ m/^-----*\s?File:\s?([^\.]+)/;
    return unless $1;
    $pagesep  = " <!--Pg$1-->";
    $pagemark = 'Pg' . $1;
    my $asterisk = 0;
    $textwindow->delete( $::searchstartindex, $::searchendindex )
      if ( $::searchstartindex && $::searchendindex );
    $textwindow->markSet( 'page',    $::searchstartindex );
    $textwindow->markSet( $pagemark, "$::searchstartindex-1c" );
    $textwindow->markGravity( $pagemark, 'left' );
    $textwindow->markSet( 'insert', "$::searchstartindex+1c" );
    $index = $textwindow->index('page');

    unless ( $op eq 'd' ) {    # if not deleting the page separator
        while (1) {
            $index = $textwindow->index('page');
            $line  = $textwindow->get($index);
            if ( $line =~ /[\n\*]/ ) {
                $textwindow->delete($index);
                last if ( $textwindow->compare( $index, '>=', 'end' ) );
            } else {
                last;
            }
        }
        while (1) {
            $index = $textwindow->index('page');
            last if ( $textwindow->compare( $index, '>=', 'end' ) );
            $line = $textwindow->get("$index-1c");
            if ( $line eq '*' ) {
                $asterisk = 1;
                $line     = $textwindow->get("$index-2c") . '*';
            }
            if ( ( $line =~ /[\s\n]$/ ) || ( $line =~ /[\w-]\*$/ ) ) {
                $textwindow->delete("$index-1c");
            } else {
                last;
            }
        }
    }

    # join lines
    if ( $op eq 'j' ) {
        $index = $textwindow->index('page');

        # Note: $line here and in similar cases actually seems to contain the
        # last _character_ on the previous page.
        $line = $textwindow->get("$index-1c");
        my $hyphens = 0;
        if ( $line =~ /\// ) {
            my $match = $textwindow->get( "$index-3c", "$index+2c" );
            if ( $match =~ /(.)\/\/\1/ ) {
                $textwindow->delete( "$index-3c", "$index+3c" );
            } else {
                $textwindow->insert( "$index", "\n" );
            }
            $index = $textwindow->index('page');
            $line  = $textwindow->get("$index-1c");
            last if ( $textwindow->compare( $index, '>=', 'end' ) );
            while ( $line eq '*' ) {
                $textwindow->delete("$index-1c");
                $index = $textwindow->index('page');
                $line  = $textwindow->get("$index-1c");
            }
            $line = $textwindow->get("$index-1c");
        }
        if ( $line =~ />/ ) {
            my $markupl = $textwindow->get( "$index-4c", $index );
            my $markupn = $textwindow->get( $index,      "$index+3c" );
            if ( ( $markupl =~ /<\/([ibgf])>/i ) && ( $markupn =~ /<$1>/i ) ) {
                $textwindow->delete( $index,      "$index+3c" );
                $textwindow->delete( "$index-4c", $index );
                $index = $textwindow->index('page');
                $line  = $textwindow->get("$index-1c");
                last if ( $textwindow->compare( $index, '>=', 'end' ) );
            }
            if (   ( $textwindow->get( "$index-5c", $index ) =~ /<\/sc>/i )
                && ( $textwindow->get( $index, "$index+4c" ) =~ /<sc>/i ) ) {
                $textwindow->delete( $index,      "$index+4c" );
                $textwindow->delete( "$index-5c", $index );
                $index = $textwindow->index('page');
                $line  = $textwindow->get("$index-1c");
                last if ( $textwindow->compare( $index, '>=', 'end' ) );
            }
            while ( $line eq '*' ) {
                $textwindow->delete("$index-1c");
                $index = $textwindow->index('page');
                $line  = $textwindow->get("$index-1c");
            }
            $line = $textwindow->get("$index-1c");
        }
        if ( $line =~ /\-/ ) {
            unless (
                $textwindow->get( "$index-2c", $index ) =~ /--/    # only remove a hyphen, not a dash
                || $textwindow->search( '-regexp', '--', '-----*\s?File:', $index,
                    "$index lineend" )
            ) {
                while ( $line =~ /\-/ ) {
                    $textwindow->delete("$index-1c");
                    $index = $textwindow->index('page');
                    $line  = $textwindow->get("$index-1c");
                    last if ( $textwindow->compare( $index, '>=', 'end' ) );
                }
                $line = $textwindow->get($index);
                if ( $line =~ /\*/ ) {
                    $textwindow->delete($index);
                }
                $index = $textwindow->search( '-regexp', '--', '\s', $index, 'end' );
                $textwindow->delete($index);
            }
        }
        $textwindow->insert( $index, "\n" );
        $textwindow->insert( $index, $pagesep ) if $::lglobal{htmlpagenum};
    } elsif ( $op eq 'k' ) {    # join lines keep hyphen
        $index = $textwindow->index('page');
        $line  = $textwindow->get("$index-1c");
        if ( $line =~ />/ ) {
            my $markupl = $textwindow->get( "$index-4c", $index );
            my $markupn = $textwindow->get( $index,      "$index+3c" );
            if ( ( $markupl =~ /<\/([ibgf])>/i ) && ( $markupn =~ /<$1>/i ) ) {
                $textwindow->delete( $index,      "$index+3c" );
                $textwindow->delete( "$index-4c", $index );
                $index = $textwindow->index('page');
                $line  = $textwindow->get("$index-1c");
                last if ( $textwindow->compare( $index, '>=', 'end' ) );
            }
            while ( $line eq '*' ) {
                $textwindow->delete("$index-1c");
                $index = $textwindow->index('page');
                $line  = $textwindow->get("$index-1c");
            }
            $line = $textwindow->get($index);
            while ( $line eq '*' ) {
                $textwindow->delete($index);
                $index = $textwindow->index('page');
                $line  = $textwindow->get($index);
            }
            $line = $textwindow->get("$index-1c");
        }
        if ( $line =~ /-/ ) {
            unless ( ( $::rwhyphenspace && !$asterisk )
                || $textwindow->search( '-regexp', '--', '^-----*\s?File:', $index,
                    "$index lineend" ) ) {
                $index = $textwindow->search( '-regexp', '--', '\s', "$index", 'end' );
                $textwindow->insert( "$index", " " );
                $index = $textwindow->search( '-regexp', '--', '\s', "$index+1c", 'end' );
                $textwindow->delete($index);
            }
        }
        $line = $textwindow->get($index);
        if ( $line =~ /-/ ) {
            $index = $textwindow->search( '-regexp', '--', '\s', $index, 'end' );
            $textwindow->delete($index);
        }
        $textwindow->insert( $index, "\n" );
        $textwindow->insert( $index, $pagesep ) if $::lglobal{htmlpagenum};
    } elsif ( $op eq 'l' ) {    # add a line
        $textwindow->insert( $index, "\n\n" );
        $textwindow->insert( $index, $pagesep ) if $::lglobal{htmlpagenum};
    } elsif ( $op eq 't' ) {    # new section
        $textwindow->insert( $index, "\n\n\n" );
        $textwindow->insert( $index, $pagesep ) if $::lglobal{htmlpagenum};
    } elsif ( $op eq 'h' ) {    # new chapter
        $textwindow->insert( $index, "\n\n\n\n\n" );
        $textwindow->insert( $index, $pagesep ) if $::lglobal{htmlpagenum};
    } elsif ( $op eq 'd' ) {    # delete
        $textwindow->insert( $index, $pagesep ) if $::lglobal{htmlpagenum};
        $textwindow->delete("$index-1c");
    }

}

sub undojoin {
    my $textwindow = $::textwindow;
    $textwindow->undo;
    $textwindow->tagRemove( 'highlight', '1.0', 'end' );
    $textwindow->see('insert');

    # Refresh, but don't allow it to restart auto-joining
    refreshpageseparator('noauto');
}

sub redojoin {
    my $textwindow = $::textwindow;
    $textwindow->redo;
    $textwindow->tagRemove( 'highlight', '1.0', 'end' );
    $textwindow->see('insert');
}

sub separatorpopup {
    my $textwindow = $::textwindow;
    my $top        = $::top;
    ::operationadd('Begin Fixup Page Separators');
    $::lglobal{pagesepauto} = 1 if !defined $::lglobal{pagesepauto} || $::lglobal{pagesepauto} >= 2;
    if ( defined( $::lglobal{pageseppop} ) ) {
        $::lglobal{pageseppop}->deiconify;
        $::lglobal{pageseppop}->raise;
        $::lglobal{pageseppop}->focus;
    } else {
        $::lglobal{pageseppop} = $top->Toplevel;
        $::lglobal{pageseppop}->title('Fixup Page Separators');
        my $sf1        = $::lglobal{pageseppop}->Frame->pack( -side => 'top', -anchor => 'n' );
        my $joinbutton = $sf1->Button(
            -activebackground => $::activecolor,
            -command          => sub { processpageseparatorrefresh('j') },
            -text             => 'Join Lines',
            -underline        => 0,
            -width            => 19
        )->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'w' );
        my $joinhybutton = $sf1->Button(
            -activebackground => $::activecolor,
            -command          => sub { processpageseparatorrefresh('k') },
            -text             => 'Join, Keep Hyphen',
            -underline        => 6,
            -width            => 19
        )->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'w' );
        my $sf2 = $::lglobal{pageseppop}->Frame->pack( -side => 'top', -anchor => 'n', -padx => 5 );
        my $blankbutton = $sf2->Button(
            -activebackground => $::activecolor,
            -command          => sub { processpageseparatorrefresh('l') },
            -text             => 'Blank Line',
            -underline        => 6,
            -width            => 12
        )->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'w' );
        my $sectjoinbutton = $sf2->Button(
            -activebackground => $::activecolor,
            -command          => sub { processpageseparatorrefresh('t') },
            -text             => 'New Section',
            -underline        => 7,
            -width            => 12
        )->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'w' );
        my $chjoinbutton = $sf2->Button(
            -activebackground => $::activecolor,
            -command          => sub { processpageseparatorrefresh('h') },
            -text             => 'New Chapter',
            -underline        => 5,
            -width            => 12
        )->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'w' );
        my $sf3 = $::lglobal{pageseppop}->Frame->pack( -side => 'top', -anchor => 'n', -padx => 5 );
        $sf3->Radiobutton(
            -variable    => \$::lglobal{pagesepauto},
            -value       => 0,
            -selectcolor => $::lglobal{checkcolor},
            -text        => 'No Auto',
        )->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'w' );
        $sf3->Radiobutton(
            -variable    => \$::lglobal{pagesepauto},
            -value       => 1,
            -selectcolor => $::lglobal{checkcolor},
            -text        => 'Auto Advance',
        )->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'w' );
        $sf3->Radiobutton(
            -variable    => \$::lglobal{pagesepauto},
            -value       => 2,
            -selectcolor => $::lglobal{checkcolor},
            -text        => '80% Auto',
        )->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'w' );
        $sf3->Radiobutton(
            -variable    => \$::lglobal{pagesepauto},
            -value       => 3,
            -selectcolor => $::lglobal{checkcolor},
            -text        => '99% Auto',
        )->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'w' );
        my $sf4 = $::lglobal{pageseppop}->Frame->pack( -side => 'top', -anchor => 'n', -padx => 5 );
        my $refreshbutton = $sf4->Button(
            -activebackground => $::activecolor,
            -command          => sub { refreshpageseparatorwrapper() },
            -text             => 'Refresh',
            -underline        => 0,
            -width            => 8
        )->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'w' );
        my $delbutton = $sf4->Button(
            -activebackground => $::activecolor,
            -command          => sub { processpageseparatorrefresh('d') },
            -text             => 'Delete',
            -underline        => 0,
            -width            => 8
        )->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'w' );
        my $phelpbutton = $sf4->Button(
            -activebackground => $::activecolor,
            -command          => sub { pageseparatorhelppopup() },
            -text             => '?',
            -width            => 1
        )->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'w' );
        my $sf5 = $::lglobal{pageseppop}->Frame->pack( -side => 'top', -anchor => 'n', -padx => 5 );
        my $undobutton = $sf5->Button(
            -activebackground => $::activecolor,
            -command          => sub { undojoin() },
            -text             => 'Undo',
            -underline        => 0,
            -width            => 8
        )->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'w' );
        my $redobutton = $sf5->Button(
            -activebackground => $::activecolor,
            -command          => sub { redojoin() },
            -text             => 'Redo',
            -underline        => 1,
            -width            => 8
        )->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'w' );
        ::initialize_popup_without_deletebinding('pageseppop');
        $::lglobal{pageseppop}->protocol(
            'WM_DELETE_WINDOW' => sub {
                ::killpopup('pageseppop');
                $textwindow->tagRemove( 'highlight', '1.0', 'end' );
            }
        );
        $::lglobal{pageseppop}->Tk::bind( '<j>' => sub { processpageseparatorrefresh('j') } );
        $::lglobal{pageseppop}->Tk::bind( '<k>' => sub { processpageseparatorrefresh('k') } );
        $::lglobal{pageseppop}->Tk::bind( '<l>' => sub { processpageseparatorrefresh('l') } );
        $::lglobal{pageseppop}->Tk::bind( '<h>' => sub { processpageseparatorrefresh('h') } );
        $::lglobal{pageseppop}->Tk::bind( '<d>' => sub { processpageseparatorrefresh('d') } );
        $::lglobal{pageseppop}->Tk::bind( '<t>' => sub { processpageseparatorrefresh('t') } );
        $::lglobal{pageseppop}->Tk::bind( '<Key-question>' => sub { pageseparatorhelppopup('?') } );
        $::lglobal{pageseppop}->Tk::bind( '<r>' => sub { refreshpageseparatorwrapper() } );
        $::lglobal{pageseppop}->Tk::bind(
            '<v>' => sub {
                ::openpng( $textwindow, ::get_page_number() );
                $::lglobal{pageseppop}->raise;
            }
        );
        $::lglobal{pageseppop}->Tk::bind( '<u>' => \&undojoin );
        $::lglobal{pageseppop}->Tk::bind( '<e>' => \&redojoin );
        $::lglobal{pageseppop}->Tk::bind(
            '<a>' => sub {
                $::lglobal{pagesepauto}++;
                $::lglobal{pagesepauto} = 0 if $::lglobal{pagesepauto} == 4;
            }
        );
    }
    refreshpageseparatorwrapper();
}

# Delete blank lines before page separators
sub delblanklines {
    my $textwindow = $::textwindow;
    ::hidepagenums();
    ::operationadd('Remove blank lines before page separators');
    my ( $line, $index, $r, $c, $pagemark );
    $::searchstartindex = '2.0';
    $::searchendindex   = '2.0';
    $textwindow->Busy;
    $textwindow->addGlobStart;

    while ($::searchstartindex) {
        $::searchstartindex =
          $textwindow->search( '-nocase', '-regexp', '--',
            '^-----*\s*File:\s?(\S+)\.(png|jpg)---.*$',
            $::searchendindex, 'end' );
        last unless $::searchstartindex;
        $::searchstartindex = '2.0' if $::searchstartindex eq '1.0';
        ( $r, $c ) = split /\./, $::searchstartindex;
        if ( $textwindow->get( ( $r - 1 ) . '.0', ( $r - 1 ) . '.end' ) eq '' ) {
            $textwindow->delete( "$::searchstartindex -1c", $::searchstartindex );
            $::searchendindex = $textwindow->index("$::searchstartindex -2l");
            $textwindow->see($::searchstartindex);
            $textwindow->update;
            next;
        }
        $::searchendindex = $r ? "$r.end" : '2.0';
    }
    $textwindow->addGlobEnd;
    $textwindow->Unbusy;
}

1;
