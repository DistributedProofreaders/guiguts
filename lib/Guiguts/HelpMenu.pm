package Guiguts::HelpMenu;
use strict;
use warnings;

BEGIN {
	use Exporter();
	our ( @ISA, @EXPORT );
	@ISA    = qw(Exporter);
	@EXPORT = qw(&about_pop_up );
}

sub about_pop_up {
	my $top        = shift;
	my $about_text = <<EOM;
Guiguts.pl post processing toolkit/interface to gutcheck.

Provides easy to use interface to gutcheck and an array of
other useful postprocessing functions.

This version produced by a number of volunteers.
See the Thanks.txt file for details.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

Guiguts 1.0 prepared by Hunter Monroe and many others.
Original guiguts written by Stephen Schulze.
Partially based on the Gedi editor - Gregs editor.
Redistributable on the same terms as Perl.
EOM
	if ( defined( $::lglobal{aboutpop} ) ) {
		$::lglobal{aboutpop}->deiconify;
		$::lglobal{aboutpop}->raise;
		$::lglobal{aboutpop}->focus;
	} else {
		$::lglobal{aboutpop} = $top->Toplevel;
		::initialize_popup_with_deletebinding('aboutpop');
		$::lglobal{aboutpop}->title('About');
		$::lglobal{aboutpop}->Label(
									 -justify => "left",
									 -text    => $about_text
		)->pack;
		my $button_ok = $::lglobal{aboutpop}->Button(
			-activebackground => $::activecolor,
			-text             => 'OK',
			-command          => sub {
				$::lglobal{aboutpop}->destroy;
				undef $::lglobal{aboutpop};
			}
		)->pack( -pady => 6 );
		$::lglobal{aboutpop}->resizable( 'no', 'no' );
		$::lglobal{aboutpop}->raise;
		$::lglobal{aboutpop}->focus;
	}
}

sub hotkeyshelp {
	my $top = $::top;
	if ( defined( $::lglobal{hotpop} ) ) {
		$::lglobal{hotpop}->deiconify;
		$::lglobal{hotpop}->raise;
		$::lglobal{hotpop}->focus;
	} else {
		$::lglobal{hotpop} = $top->Toplevel;
		$::lglobal{hotpop}->title('Hot key combinations');
		::initialize_popup_with_deletebinding('hotpop');
		my $frame =
		  $::lglobal{hotpop}->Frame->pack(
										   -anchor => 'nw',
										   -expand => 'yes',
										   -fill   => 'both'
		  );
		my $rotextbox =
		  $frame->Scrolled(
							'ROText',
							-scrollbars => 'se',
							-background => $::bkgcolor,
							-font       => '{Helvetica} 10',
							-width      => 80,
							-height     => 25,
							-wrap       => 'none',
		  )->pack( -anchor => 'nw', -expand => 'yes', -fill => 'both' );
		::drag($rotextbox);
		$rotextbox->focus;
		$rotextbox->insert( 'end', <<'EOF' );

MAIN WINDOW

<ctrl>+x -- cut or column cut
<ctrl>+c -- copy or column copy
<ctrl>+v -- paste
<ctrl>+` -- column paste
<ctrl>+a -- select all

F1 -- column copy
F2 -- column cut
F3 -- column paste

F7 -- spell check selection (or document, if no selection made)

<ctrl>+z -- undo
<ctrl>+y -- redo

<ctrl>+/ -- select all
<ctrl>+\ -- unselect all
<Esc> -- unselect all

<ctrl>+u -- Convert case of selection to upper case
<ctrl>+l -- Convert case of selection to lower case
<ctrl>+t -- Convert case of selection to title case

<ctrl>+i -- insert a tab character before cursor (Tab)
<ctrl>+j -- insert a newline character before cursor (Enter)
<ctrl>+o -- insert a newline character after cursor

<ctrl>+d -- delete character after cursor (Delete)
<ctrl>+h -- delete character to the left of the cursor (Backspace)
<ctrl>+k -- delete from cursor to end of line

<ctrl>+e -- move cursor to end of current line. (End)
<ctrl>+b -- move cursor left one character (left arrow)
<ctrl>+p -- move cursor up one line (up arrow)
<ctrl>+n -- move cursor down one line (down arrow)

<ctrl>Home -- move cursor to the start of the text
<ctrl>End -- move cursor to end of the text
<ctrl>+right arrow -- move to the start of the next word
<ctrl>+left arrow -- move to the start of the previous word
<ctrl>+up arrow -- move to the start of the current paragraph
<ctrl>+down arrow -- move to the start of the next paragraph
<ctrl>+PgUp -- scroll left one screen
<ctrl>+PgDn -- scroll right one screen

<shift>+Home -- adjust selection to beginning of current line
<shift>+End -- adjust selection to end of current line
<shift>+up arrow -- adjust selection up one line
<shift>+down arrow -- adjust selection down one line
<shift>+left arrow -- adjust selection left one character
<shift>+right arrow -- adjust selection right one character

<shift><ctrl>Home -- adjust selection to the start of the text
<shift><ctrl>End -- adjust selection to end of the text
<shift><ctrl>+left arrow -- adjust selection to the start of the previous word
<shift><ctrl>+right arrow -- adjust selection to the start of the next word
<shift><ctrl>+up arrow -- adjust selection to the start of the current paragraph
<shift><ctrl>+down arrow -- adjust selection to the start of the next paragraph

<ctrl>+' -- highlight all apostrophes in selection.
<ctrl>+\" -- highlight all double quotes in selection.
<ctrl>+0 -- remove all highlights.

<Insert> -- Toggle insert / overstrike mode

Double click left mouse button -- select word
Triple click left mouse button -- select line

<shift> click left mouse button -- adjust selection to click point
<shift> Double click left mouse button -- adjust selection to include word clicked on
<shift> Triple click left mouse button -- adjust selection to include line clicked on

Single click right mouse button -- pop up shortcut to menu bar

BOOKMARKS

<ctrl>+<shift>+1 -- set bookmark 1
<ctrl>+<shift>+2 -- set bookmark 1
<ctrl>+<shift>+3 -- set bookmark 3
<ctrl>+<shift>+4 -- set bookmark 4
<ctrl>+<shift>+5 -- set bookmark 5

<ctrl>+1 -- go to bookmark 1
<ctrl>+2 -- go to bookmark 2
<ctrl>+3 -- go to bookmark 3
<ctrl>+4 -- go to bookmark 4
<ctrl>+5 -- go to bookmark 5

MENUS

<alt>+f -- file menu
<alt>+e -- edit menu
<alt>+b -- bookmarks
<alt>+s -- search menu
<alt>+g -- gutcheck menu
<alt>+x -- fixup menu
<alt>+w -- word frequency menu


SEARCH POPUP

<Enter> -- Search
<shift><Enter> -- Replace
<ctrl><Enter> -- Replace & Search
<ctrl><shift><Enter> -- Replace All

PAGE SEPARATOR POPUP

'j' -- Join Lines - join lines, remove all blank lines, spaces, asterisks and hyphens.
'k' -- Join, Keep Hyphen - join lines, remove all blank lines, spaces and asterisks, keep hyphen.
'l' -- Blank Line - leave one blank line. Close up any other whitespace. (Paragraph Break)
't' -- New Section - leave two blank lines. Close up any other whitespace. (Section Break)
'h' -- New Chapter - leave four blank lines. Close up any other whitespace. (Chapter Break)
'r' -- Refresh - search for, highlight and re-center the next page separator.
'u' -- Undo - undo the last edit. (Note: in Full Automatic mode,\n\tthis just single steps back through the undo buffer)
'd' -- Delete - delete the page separator. Make no other edits.
'v' -- View the current page in the image viewer.
'a' -- Toggle Full Automatic mode.
's' -- Toggle Semi Automatic mode.
'?' -- View hotkey help popup.
EOF
		my $button_ok = $frame->Button(
			-activebackground => $::activecolor,
			-text             => 'OK',
			-command          => sub {
				$::lglobal{hotpop}->destroy;
				undef $::lglobal{hotpop};
			}
		)->pack( -pady => 8 );
	}
}

sub regexref {
	my $top = $::top;
	if ( defined( $::lglobal{regexrefpop} ) ) {
		$::lglobal{regexrefpop}->deiconify;
		$::lglobal{regexrefpop}->raise;
		$::lglobal{regexrefpop}->focus;
	} else {
		$::lglobal{regexrefpop} = $top->Toplevel;
		$::lglobal{regexrefpop}->title('Regex Quick Reference');
		::initialize_popup_with_deletebinding('regexrefpop');
		my $button_ok = $::lglobal{regexrefpop}->Button(
			-activebackground => $::activecolor,
			-text             => 'Close',
			-command          => sub {
				$::lglobal{regexrefpop}->destroy;
				undef $::lglobal{regexrefpop};
			}
		)->pack( -pady => 6 );
		my $regtext =
		  $::lglobal{regexrefpop}->Scrolled(
											 'ROText',
											 -scrollbars => 'se',
											 -background => $::bkgcolor,
											 -font       => $::lglobal{font},
		  )->pack( -anchor => 'n', -expand => 'y', -fill => 'both' );
		::drag($regtext);
		if ( -e 'regref.txt' ) {
			if ( open my $ref, '<', 'regref.txt' ) {
				while (<$ref>) {
					$_ =~ s/\cM\cJ|\cM|\cJ/\n/g;
1;


					#$_ = eol_convert($_);
					$regtext->insert( 'end', $_ );
				}
			} else {
				$regtext->insert( 'end',
						  'Could not open Regex Reference file - regref.txt.' );
			}
		} else {
			$regtext->insert( 'end',
						  'Could not find Regex Reference file - regref.txt.' );
		}
	}
}

1;