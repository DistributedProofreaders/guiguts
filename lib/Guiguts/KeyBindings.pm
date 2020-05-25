package Guiguts::KeyBindings;
use strict;
use warnings;

BEGIN {
	use Exporter();
	our ( @ISA, @EXPORT );
	@ISA = qw(Exporter);
	@EXPORT =
	  qw( &keybindings );
}

sub keybindings {
	my $textwindow = $::textwindow;
	my $top        = $::top;

# Highlight
	keybind( '<Control-comma>',     sub { ::hilite('\''); }, '<<hlquote>>' );
	keybind( '<Control-period>',    sub { ::hilite('"'); }, '<<hldquote>>' );
	keybind( '<Control-Alt-h>',     sub { ::hilitepopup(); } );
	keybind( '<Control-0>',         sub {
			$textwindow->tagRemove( 'highlight', '1.0', 'end' );
			$textwindow->tagRemove( 'quotemark', '1.0', 'end' ); 
		}, '<<hlrem>>' );
# File
	keybind( '<Control-o>',         sub { ::file_open($textwindow); } );
	keybind( '<Control-s>',         sub { ::savefile(); } );
	keybind( '<Control-Shift-s>',   sub { ::file_saveas($textwindow); } );
# Select, copy, paste
	keybind( '<Control-a>',         sub { $textwindow->selectAll; } );
	keybind( '<Control-c>',         sub { ::textcopy(); }, '<<Copy>>' );
	keybind( '<Control-x>',         sub { ::cut(); }, '<<Cut>>' );
	keybind( '<Control-v>',         sub { ::paste(); } );
	keybind( '<F1>',                sub { ::colcopy($textwindow); } );
	keybind( '<F2>',                sub { ::colcut($textwindow); } );
	keybind( '<F3>',                sub { ::colpaste($textwindow); } );
# Tools
	keybind( '<F5>',                sub { ::wordfrequency(); } );
	keybind( '<F6>',                sub { ::gutcheck(); } );
	keybind( '<F7>',                sub { ::spellchecker(); } );
	keybind( '<F8>',                sub { ::stealthscanno(); } );
# Delete
	keybind( '<Delete>',            sub {
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
		} );
	keybind( '<Control-BackSpace>', sub {
			$textwindow->addGlobStart;
			my $pos = $textwindow->search( '-backwards', '-regexp', '--', '\W',
					'insert -1c', 'insert linestart' );
			if ($pos) {
				$pos = "$pos +1c";
			} else {
				$pos = 'insert linestart';
			}
			$textwindow->delete($pos, 'insert');
			$textwindow->addGlobEnd;
		}, '<<BackSpaceWord>>' );
	keybind( '<Control-Delete>',    sub {
			$textwindow->addGlobStart;
			my $pos = $textwindow->search( '-regexp', '--', '\W',
					'insert +1c', 'insert lineend' );
			$pos = 'insert lineend' unless $pos;
			$textwindow->delete('insert', $pos);
			$textwindow->addGlobEnd;
		}, '<<ForwardDeleteWord>>' );
# Case
	keybind( '<Control-l>',         sub { ::case( $textwindow, 'lc' ); } );
	keybind( '<Control-u>',         sub { ::case( $textwindow, 'uc' ); } );
	keybind( '<Control-t>',         sub { ::case( $textwindow, 'tc' ); $top->break; } );
# Undo, redo
	keybind( '<Control-z>',         sub {
			$textwindow->undo;
			$textwindow->tagRemove( 'highlight', '1.0', 'end' );
			$textwindow->see('insert');
		}, '<<Undo>>' );
	keybind( '<Control-y>',         sub {
			$textwindow->redo;
			$textwindow->see('insert');
		}, '<<Redo>>' );
	keybind( '<Control-Shift-z>',   undef, '<<Redo>>' );	# Add another key-combination
# Search
	keybind( '<Control-f>',         sub { ::searchpopup(); } );
	keybind( '<Control-g>',         sub {
			if ( $::lglobal{searchpop} ) {
				my $searchterm = $::lglobal{searchentry}->get( '1.0', '1.end' );
				::searchtext($searchterm);
			} else {
				::searchpopup();
			}
		}, '<<FindNext>>' );
	keybind( '<Control-Shift-g>',   sub {
			if ( $::lglobal{searchpop} ) {
				my $searchterm = $::lglobal{searchentry}->get( '1.0', '1.end' );
				$::lglobal{searchop2}->toggle;
				::searchtext($searchterm);
				$::lglobal{searchop2}->toggle;
			} else {
				::searchpopup();
			}
		}, '<<FindNextReverse>>' );
# Navigation
	keybind( '<Control-i>',         sub { ::seecurrentimage(); } );
	keybind( '<Control-j>',         sub { ::gotoline(); } );
	keybind( '<Control-p>',         sub { ::gotopage(); } );
	keybind( '<Control-Shift-P>',   sub { ::gotolabel(); } );
# Edit
	keybind( '<Control-e>',         sub {
			if ( $::lglobal{floodpop} ) {
				::floodfill( $textwindow, $::lglobal{ffchar} );
			} else {
				::flood();
			}
		} );
	keybind( '<Control-r>',         sub {
			if ( $::lglobal{surpop} ) {
				::surroundit( $::lglobal{surstrt}, $::lglobal{surend}, $textwindow );
			} else {
				::surround();
			}
		} );
	keybind( '<Control-w>',         sub {
			$textwindow->addGlobStart;
			::selectrewrap( $textwindow, $::lglobal{seepagenums},
							$::scannos_highlighted, $::rwhyphenspace );
			$textwindow->addGlobEnd;
		} );
	keybind( '<Control-Shift-w>',   sub {
			$textwindow->addGlobStart;
			::blockrewrap();
			$textwindow->addGlobEnd;
		} );
# Indent
	keybind( '<Control-m>',         sub { ::indent($textwindow, 'in'); } );
	keybind( '<Control-Shift-m>',   sub { ::indent($textwindow, 'out'); } );
	keybind( '<Control-Alt-m>',     sub {
			$textwindow->addGlobStart;
			::indent( $textwindow, 'in' ) for ( 1 .. 4 );
			$textwindow->addGlobEnd;
		} );
	keybind( '<Control-Alt-Shift-m>', sub {
			$textwindow->addGlobStart;
			::indent( $textwindow, 'out' ) for ( 1 .. 4 );
			$textwindow->addGlobEnd;
		} );
	keybind( '<Alt-Left>',          sub { ::indent($textwindow, 'out'); } );
	keybind( '<Alt-Right>',         sub { ::indent($textwindow, 'in'); } );
	keybind( '<Alt-Up>',            sub { ::indent($textwindow, 'up'); } );
	keybind( '<Alt-Down>',          sub { ::indent($textwindow, 'dn'); } );
# Scratchpad
	keybind( '<Control-Alt-s>',     sub {
			unless ( -e 'scratchpad.txt' ) {
				open my $fh, '>', 'scratchpad.txt'
				  or warn "Could not create file $!";
			}
			::runner('start scratchpad.txt') if $::OS_WIN;
		} );
# Help
	keybind( '<Control-Alt-r>',     sub { ::regexref(); } );
# Mouse
	keybind( '<Shift-B1-Motion>',   sub { $textwindow->shiftB1_Motion(@_); } );
	keybind( '<ButtonRelease-2>',   sub { ::popscroll() unless $Tk::mouseMoved } );
	keybind( '<<ScrollDismiss>>',   sub { ::scrolldismiss(); } );
	keybind( '<FocusIn>',           sub { $::lglobal{hasfocus} = $textwindow; } );
	# Try to trap odd right click error under OSX and Linux
	keybind( '<3>',                 sub {
			::scrolldismiss();
			$::menubar->Popup( -popover => 'cursor' ) if ($::OS_WIN);
		} );
# Extra bindings for Mac
	keybind( '<Meta-q>',            sub { ::_exit(); } ) if $::OS_MAC;
# Bookmarks - multiple key-combinations to allow for keyboard differences
	keybind( '<Control-Shift-exclam>',         sub { ::setbookmark('1'); },	'<<SetBkmk1>>' );
	keybind( '<Control-Shift-at>',             sub { ::setbookmark('2'); },	'<<SetBkmk2>>' );
	keybind( '<Control-Shift-quotedbl>',       undef, 	                    '<<SetBkmk2>>' );
	keybind( '<Control-Shift-numbersign>',     sub { ::setbookmark('3'); },	'<<SetBkmk3>>' );
	keybind( '<Control-Shift-sterling>',       undef, 	                    '<<SetBkmk3>>' );
	keybind( '<Control-Shift-section>',        undef, 	                    '<<SetBkmk3>>' );
	keybind( '<Control-Shift-periodcentered>', undef, 	                    '<<SetBkmk3>>' );
	keybind( '<Control-Shift-dollar>',         sub { ::setbookmark('4'); },	'<<SetBkmk4>>' );
	keybind( '<Control-Shift-currency>',       undef, 	                    '<<SetBkmk4>>' );
	keybind( '<Control-Shift-percent>',        sub { ::setbookmark('5'); },	'<<SetBkmk5>>' );
	keybind( '<Control-KeyPress-1>',           sub { ::gotobookmark('1'); } );
	keybind( '<Control-KeyPress-2>',           sub { ::gotobookmark('2'); } );
	keybind( '<Control-KeyPress-3>',           sub { ::gotobookmark('3'); } );
	keybind( '<Control-KeyPress-4>',           sub { ::gotobookmark('4'); } );
	keybind( '<Control-KeyPress-5>',           sub { ::gotobookmark('5'); } );
}

# Bind a key-combination to a sub allowing for capslock on/off.
# If capslock is on then pressing Ctrl and "k" does not trigger event
# with <Control-k> bound, so bind <Control-K> to the same event.
# If key-combination does not end in "-k>" where k is in [a-z], no
# uppercase binding is added.
# If on Mac, also add <Meta-k> as alternative to <Control-k>
#
# If optional event argument given, link key and event, and bind sub to event.
#
# Safe to call more than once to bind multiple key-combinations to same event:
#	keybind( '<KeyCombo1>', sub { doit(); }, '<<MyEvent>>' );
#	keybind( '<KeyCombo2>', undef,           '<<MyEvent>>' );
#

sub keybind {
	my $textwindow = $::textwindow;
	my $lkey = shift;				# Key-combination (lower-case letter)
	my $subr = shift;				# Subroutine to bind to key/event
	my $event = shift;				# Optional event argument
	
	
	my $mkey = my $ukey = $lkey;
	$ukey =~ s/-([a-z])>/-\u$1>/;			# Create uppercase version
	$mkey =~ s/Control/Meta/ if $::OS_MAC;	# Create Mac alternative to Control key

	if ( defined $event ) {
		$textwindow->eventAdd( $event => $lkey );
		$textwindow->eventAdd( $event => $ukey ) if $ukey ne $lkey;
		$textwindow->eventAdd( $event => $mkey ) if $mkey ne $lkey;
		$textwindow->bind( 'TextUnicode', $event => $subr ) if defined $subr;
	} elsif ( defined $subr ) {
		$textwindow->bind( 'TextUnicode', $lkey => $subr );
		$textwindow->bind( 'TextUnicode', $ukey => $subr ) if $ukey ne $lkey;
		$textwindow->bind( 'TextUnicode', $mkey => $subr ) if $mkey ne $lkey;
	} else {
		print "Undefined arguments to keybind\n";
	}
}

1;
