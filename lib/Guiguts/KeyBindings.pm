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

	$textwindow->eventAdd( '<<hlquote>>' => '<Control-comma>' );
	$textwindow->bind( '<<hlquote>>', sub { ::hilite('\'') } );
	$textwindow->eventAdd( '<<hldquote>>' => '<Control-period>' );
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
	$textwindow->bind( 'TextUnicode',
		'<Control-a>' => sub { $textwindow->selectAll } );
	$textwindow->eventAdd( '<<Copy>>' => '<Control-c>' );
	$textwindow->bind( 'TextUnicode', '<<Copy>>' => \&::textcopy );
	$textwindow->eventAdd( '<<Cut>>' => '<Control-x>' );
	$textwindow->bind( 'TextUnicode', '<<Cut>>'     => sub { ::cut() } );
	$textwindow->bind( 'TextUnicode', '<Control-v>' => sub { ::paste() } );
	$textwindow->bind( 'TextUnicode', '<F1>' => sub { ::colcopy($textwindow); } );
	$textwindow->bind( 'TextUnicode', '<F2>' => sub { ::colcut($textwindow); } );
	$textwindow->bind( 'TextUnicode', '<F3>' => sub { ::colpaste($textwindow); } );
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
	$textwindow->eventAdd('<<BackSpaceWord>>'     => '<Control-BackSpace>');
	$textwindow->eventAdd('<<ForwardDeleteWord>>' => '<Control-Delete>');
	$textwindow->bind(
		'TextUnicode',
		'<<BackSpaceWord>>' => sub {
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
		}
	);
	$textwindow->bind(
		'TextUnicode',
		'<<ForwardDeleteWord>>' => sub {
			$textwindow->addGlobStart;
			my $pos = $textwindow->search( '-regexp', '--', '\W',
					'insert +1c', 'insert lineend' );
			$pos = 'insert lineend' unless $pos;
			$textwindow->delete('insert', $pos);
			$textwindow->addGlobEnd;
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
		'<<Undo>>' => sub {
			$textwindow->undo;
			$textwindow->tagRemove( 'highlight', '1.0', 'end' );
			$textwindow->see('insert');
		}
	);
	$textwindow->bind( 'TextUnicode', '<<Redo>>' => sub { $textwindow->redo; $textwindow->see('insert'); } );
	$textwindow->eventAdd( '<<Undo>>' => '<Control-z>' );
	$textwindow->eventAdd( '<<Redo>>' => '<Control-y>', '<Control-Z>' );

	if ( $::OS_MAC ) {
		$textwindow->bind( 'TextUnicode', '<Meta-q>' => \&::_exit );
		$textwindow->bind( 'TextUnicode', '<Meta-s>' => \&::savefile );
		$textwindow->bind( 'TextUnicode', '<Meta-a>' => sub { $textwindow->selectAll } );
		$textwindow->bind( 'TextUnicode', '<Meta-c>' => \&::textcopy );
		$textwindow->bind( 'TextUnicode', '<Meta-x>' => \&::cut );
		$textwindow->bind( 'TextUnicode', '<Meta-v>' => \&::paste );
		$textwindow->bind( 'TextUnicode', '<Meta-f>' => \&::searchpopup );
		$textwindow->eventAdd( '<<Undo>>' => '<Meta-z>' );
		$textwindow->eventAdd( '<<Redo>>' => '<Meta-y>' );
	}

	$textwindow->bind( 'TextUnicode', '<Control-f>' => \&::searchpopup );
	$textwindow->bind( 'TextUnicode', '<Control-i>' => \&::seecurrentimage );
	$textwindow->bind( 'TextUnicode', '<Control-p>' => \&::gotopage );
	$textwindow->bind( 'TextUnicode', '<Control-P>' => \&::gotolabel );
	$textwindow->bind( 'TextUnicode', '<Control-o>' => sub {
		if ( $::lglobal{floodpop} ) {
			::floodfill( $textwindow, $::lglobal{ffchar} );
		} else {
			::flood();
		}
	});
	$textwindow->bind( 'TextUnicode', '<Control-r>' => sub {
		if ( $::lglobal{surpop} ) {
			::surroundit( $::lglobal{surstrt}, $::lglobal{surend}, $textwindow );
		} else {
			::surround();
		}
	});
	$textwindow->bind( 'TextUnicode', '<F5>' => \&::wordfrequency );
	$textwindow->bind( 'TextUnicode', '<F6>' => \&::gutcheck );
	$textwindow->bind( 'TextUnicode', '<F7>' => \&::spellchecker );
	$textwindow->bind( 'TextUnicode', '<F8>' => \&::stealthscanno );

	if ( $::hotkeybookmarks ) {
		$textwindow->bind( 'TextUnicode', '<<SetBkmk1>>' => sub { ::setbookmark('1'); } );
		$textwindow->bind( 'TextUnicode', '<<SetBkmk2>>' => sub { ::setbookmark('2'); } );
		$textwindow->bind( 'TextUnicode', '<<SetBkmk3>>' => sub { ::setbookmark('3'); } );
		$textwindow->bind( 'TextUnicode', '<<SetBkmk4>>' => sub { ::setbookmark('4'); } );
		$textwindow->bind( 'TextUnicode', '<<SetBkmk5>>' => sub { ::setbookmark('5'); } );
		$textwindow->bind( 'TextUnicode', '<<Dummy>>' => '' );
		$textwindow->eventAdd( '<<SetBkmk1>>' => '<Control-Shift-exclam>' );
		$textwindow->eventAdd( '<<SetBkmk2>>' => '<Control-Shift-at>', '<Control-Shift-quotedbl>' );
		$textwindow->eventAdd( '<<SetBkmk3>>' => '<Control-Shift-numbersign>', 
			'<Control-Shift-sterling>', '<Control-Shift-section>', '<Control-Shift-periodcentered>' );
		$textwindow->eventAdd( '<<SetBkmk4>>' => '<Control-Shift-dollar>', '<Control-Shift-currency>' );
		$textwindow->eventAdd( '<<SetBkmk5>>' => '<Control-Shift-percent>' );
	}
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
			::indent($textwindow, 'out');
		}
	);
	$textwindow->bind(
		'TextUnicode',
		'<Alt-Right>' => sub {
			::indent($textwindow, 'in');
		}
	);
	$textwindow->bind(
		'TextUnicode',
		'<Alt-Up>' => sub {
			::indent($textwindow, 'up');
		}
	);
	$textwindow->bind(
		'TextUnicode',
		'<Alt-Down>' => sub {
			::indent($textwindow, 'dn');
		}
	);

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
	$textwindow->bind( '<<ScrollDismiss>>', \&::scrolldismiss );
	$textwindow->bind( 'TextUnicode', '<ButtonRelease-2>',
		sub { ::popscroll() unless $Tk::mouseMoved } );

	$textwindow->eventAdd( '<<FindNext>>' => '<Control-Key-g>' );
	$textwindow->eventAdd( '<<FindNextReverse>>' => '<Control-Key-G>' );
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
	$textwindow->bind(
		'<<FindNextReverse>>',
		sub {
			if ( $::lglobal{searchpop} ) {
				my $searchterm = $::lglobal{searchentry}->get( '1.0', '1.end' );
				$::lglobal{searchop2}->toggle;
				::searchtext($searchterm);
				$::lglobal{searchop2}->toggle;
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
