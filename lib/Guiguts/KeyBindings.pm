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

	# Set up a bunch of events and key bindings for the widget
	$textwindow->tagConfigure( 'footnote', -background => 'cyan' );
	$textwindow->tagConfigure( 'scannos',  -background => $::highlightcolor );
	$textwindow->tagConfigure( 'bkmk',     -background => 'green' );
	$textwindow->tagConfigure( 'table',    -background => '#E7B696' );
	$textwindow->tagRaise('sel');
	$textwindow->tagConfigure( 'quotemark', -background => '#CCCCFF' );
	$textwindow->tagConfigure( 'highlight', -background => 'orange' );
	$textwindow->tagConfigure( 'linesel',   -background => '#8EFD94' );
	$textwindow->tagConfigure(
		'pagenum',
		-background  => 'yellow',
		-relief      => 'raised',
		-borderwidth => 2
	);
	$textwindow->tagBind( 'pagenum', '<ButtonRelease-1>', \&::pnumadjust );
	$textwindow->eventAdd( '<<hlquote>>' => '<Control-quoteright>' );
	$textwindow->bind( '<<hlquote>>', sub { ::hilite('\'') } );
	$textwindow->eventAdd( '<<hldquote>>' => '<Control-quotedbl>' );
	$textwindow->bind( '<<hldquote>>', sub { ::hilite('"') } );
	$textwindow->eventAdd( '<<hlrem>>' => '<Control-0>' );
	$textwindow->bind(
		'<<hlrem>>',
		sub {
			$textwindow->tagRemove( 'highlight', '1.0', 'end' );
			$textwindow->tagRemove( 'quotemark', '1.0', 'end' );
		}
	);
	$textwindow->bind( 'TextUnicode', '<Control-s>' => \&::savefile );
	$textwindow->bind( 'TextUnicode', '<Control-S>' => \&::savefile );
	$textwindow->bind( 'TextUnicode',
		'<Control-a>' => sub { $textwindow->selectAll } );
	$textwindow->bind( 'TextUnicode',
		'<Control-A>' => sub { $textwindow->selectAll } );
	$textwindow->eventAdd(
		'<<Copy>>' => '<Control-C>',
		'<Control-c>', '<F1>'
	);
	$textwindow->bind( 'TextUnicode', '<<Copy>>' => \&::textcopy );
	$textwindow->eventAdd(
		'<<Cut>>' => '<Control-X>',
		'<Control-x>', '<F2>'
	);
	$textwindow->bind( 'TextUnicode', '<<Cut>>'     => sub { ::cut() } );
	$textwindow->bind( 'TextUnicode', '<Control-V>' => sub { ::paste() } );
	$textwindow->bind( 'TextUnicode', '<Control-v>' => sub { ::paste() } );
	$textwindow->bind(
		'TextUnicode',
		'<F3>' => sub {
			$textwindow->addGlobStart;
			$textwindow->clipboardColumnPaste;
			$textwindow->addGlobEnd;
		}
	);
	$textwindow->bind(
		'TextUnicode',
		'<Control-quoteleft>' => sub {
			$textwindow->addGlobStart;
			$textwindow->clipboardColumnPaste;
			$textwindow->addGlobEnd;
		}
	);
	$textwindow->bind(
		'TextUnicode',
		'<Delete>' => sub {
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
	$textwindow->bind( 'TextUnicode',
		'<Control-l>' => sub { ::case( $textwindow, 'lc' ); } );
	$textwindow->bind( 'TextUnicode',
		'<Control-u>' => sub { ::case( $textwindow, 'uc' ); } );
	$textwindow->bind( 'TextUnicode',
		'<Control-t>' => sub { ::case( $textwindow, 'tc' ); $top->break } );
	$textwindow->bind(
		'TextUnicode',
		'<Control-z>' => sub {
			$textwindow->undo;
			$textwindow->tagRemove( 'highlight', '1.0', 'end' );
			$textwindow->see('insert');
		}
	);
	$textwindow->bind( 'TextUnicode',
		'<Control-y>' => sub { $textwindow->redo; $textwindow->see('insert'); } );
	$textwindow->bind( 'TextUnicode', '<Control-f>' => \&::searchpopup );
	$textwindow->bind( 'TextUnicode', '<Control-F>' => \&::searchpopup );
	$textwindow->bind( 'TextUnicode', '<Control-p>' => \&::gotopage );
	$textwindow->bind( 'TextUnicode', '<Control-P>' => \&::gotopage );
	$textwindow->bind(
		'TextUnicode',
		'<Control-w>' => sub {
			$textwindow->addGlobStart;
			::floodfill();
			$textwindow->addGlobEnd;
		}
	);
	$textwindow->bind(
		'TextUnicode',
		'<Control-W>' => sub {
			$textwindow->addGlobStart;
			::floodfill();
			$textwindow->addGlobEnd;
		}
	);
	$textwindow->bind( 'TextUnicode',
		'<Control-Shift-exclam>' => sub { ::setbookmark('1') } );
	$textwindow->bind( 'TextUnicode',
		'<Control-Shift-at>' => sub { ::setbookmark('2') } );
	$textwindow->bind( 'TextUnicode',
		'<Control-Shift-numbersign>' => sub { ::setbookmark('3') } );
	$textwindow->bind( 'TextUnicode',
		'<Control-Shift-dollar>' => sub { ::setbookmark('4') } );
	$textwindow->bind( 'TextUnicode',
		'<Control-Shift-percent>' => sub { ::setbookmark('5') } );
	$textwindow->bind( 'TextUnicode',
		'<Control-KeyPress-1>' => sub { ::gotobookmark('1') } );
	$textwindow->bind( 'TextUnicode',
		'<Control-KeyPress-2>' => sub { ::gotobookmark('2') } );
	$textwindow->bind( 'TextUnicode',
		'<Control-KeyPress-3>' => sub { ::gotobookmark('3') } );
	$textwindow->bind( 'TextUnicode',
		'<Control-KeyPress-4>' => sub { ::gotobookmark('4') } );
	$textwindow->bind( 'TextUnicode',
		'<Control-KeyPress-5>' => sub { ::gotobookmark('5') } );
	$textwindow->bind(
		'TextUnicode',
		'<Alt-Left>' => sub {
			$textwindow->addGlobStart;
			::indent('out');
			$textwindow->addGlobEnd;
		}
	);
	$textwindow->bind(
		'TextUnicode',
		'<Alt-Right>' => sub {
			$textwindow->addGlobStart;
			::indent('in');
			$textwindow->addGlobEnd;
		}
	);
	$textwindow->bind(
		'TextUnicode',
		'<Alt-Up>' => sub {
			$textwindow->addGlobStart;
			::indent('up');
			$textwindow->addGlobEnd;
		}
	);
	$textwindow->bind(
		'TextUnicode',
		'<Alt-Down>' => sub {
			$textwindow->addGlobStart;
			::indent('dn');
			$textwindow->addGlobEnd;
		}
	);
	$textwindow->bind( 'TextUnicode', '<F7>' => \&::spellchecker );
	$textwindow->bind(
		'TextUnicode',
		'<Control-Alt-s>' => sub {
			unless ( -e 'scratchpad.txt' ) {
				open my $fh, '>', 'scratchpad.txt'
				  or warn "Could not create file $!";
			}
			::runner('start scratchpad.txt') if $::OS_WIN;
		}
	);
	$textwindow->bind( 'TextUnicode',
		'<Control-Alt-r>' => sub { ::regexref() } );
	$textwindow->bind( 'TextUnicode', '<Shift-B1-Motion>', 'shiftB1_Motion' );
	$textwindow->eventAdd(
		'<<FindNext>>' => '<Control-Key-G>',
		'<Control-Key-g>'
	);
	$textwindow->bind( '<<ScrollDismiss>>', \&::scrolldismiss );
	$textwindow->bind( 'TextUnicode', '<ButtonRelease-2>',
		sub { ::popscroll() unless $Tk::mouseMoved } );
	$textwindow->bind(
		'<<FindNext>>',
		sub {
			if ( $::lglobal{searchpop} ) {
				my $searchterm = $::lglobal{searchentry}->get( '1.0', '1.end' );
				::searchtext($searchterm);
			} else {
				::searchpopup();
			}
		}
	);
	if ($::OS_WIN) {
		$textwindow->bind(
			'TextUnicode',
			'<3>' => sub {
				::scrolldismiss();
				$::menubar->Popup( -popover => 'cursor' );
			}
		);
	} else {
		$textwindow->bind( 'TextUnicode', '<3>' => sub { &::scrolldismiss() } )
		  ;    # Try to trap odd right click error under OSX and Linux
	}
	$textwindow->bind( 'TextUnicode', '<Control-Alt-h>' => \&::hilitepopup );
	$textwindow->bind( 'TextUnicode',
		'<FocusIn>' => sub { $::lglobal{hasfocus} = $textwindow } );
}

1;
