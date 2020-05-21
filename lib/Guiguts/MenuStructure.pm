package Guiguts::MenuStructure;
use strict;
use warnings;

BEGIN {
	use Exporter();
	our ( @ISA, @EXPORT );
	@ISA = qw(Exporter);
	@EXPORT =
	  qw( &menurebuild );
}

sub menu_file {
	my ( $textwindow, $top ) = ( $::textwindow, $::top );
	[
		[	'command', '~Open...',
			-command => sub { ::file_open($textwindow) }
		],
		[ 'separator', '' ],
		map ( [
				Button   => ($_<9?'~':'').($_==9?'1~0':$_+1).": $::recentfile[$_]",
				-command => [ \&::openfile, $::recentfile[$_] ]
			],
			( 0 .. scalar(@::recentfile) - 1 ) ),
		[ 'separator', '' ],
		[	'command', '~Save',
			-accelerator => 'Ctrl+s',
			-command     => \&::savefile
		],
		[	'command', 'Save ~As...',
			-command => sub { ::file_saveas($textwindow) }
		],
		[	'command', 'Sa~ve a Copy As...',
			-command => sub { ::file_savecopyas($textwindow) }
		],
		[	'command', '~Include File...',
			-command => sub { ::file_include($textwindow); }
		],
		[	'command', '~Close',
			-command => sub { ::file_close($textwindow) }
		],
		[ 'separator', '' ],
		[
			Cascade    => '~Project',
			-tearoff   => 1,
			-menuitems => [
				[	'command', 'See ~Image',
					-command => \&::seecurrentimage
				],
				[	'command', 'See ~Proofers...',
					-command => \&::showproofers
				],
				[	'command' => 'View Operations ~History...'.($::trackoperations?'':' (disabled)'),
					-command => \&::opspop_up ],
				[ 'separator', '' ],
				[	'command', 'View Project ~Comments',
					-command => \&::viewprojectcomments
				],
				[	'command', 'View Project Page [~www]',
					-command => \&::viewprojectpage
				],
				[	'command', 'View Project ~Discussion [www]',
					-command => \&::viewprojectdiscussion
				],
				[ 'separator', '' ],
			        [	'command', 'Set Project ~Language...',
					-command => \&::setlang ],
			        [	'command', 'Set Pro~ject ID...',
					-command => \&::setprojectid ],
				[	'command', 'Set I~mage Directory...',
					 -command => \&::setpngspath
				],
				[ 'separator', '' ],
				[	'command', 'Display/~Adjust Page Markers...',
					-command => \&::togglepagenums
				],
				[	'command', '~Guess Page Markers...',
					-command => \&::file_guess_page_marks
				],
				[	'command', '~Set Page Markers',
					-command => \&::file_mark_pages
				],
				[	'command', 'Configure Page La~bels...',
					-command => \&::pageadjust
				],
				[ 'separator', '' ],
				[	'command', 'Export One File with Page Separators...',
					-command => sub { ::file_export_preptext('onefile') }
				],
				[	'command', 'Export One File with Page Sep. Markup...',
					-command => sub { ::file_export_pagemarkup(); }
				],
				[	'command', 'Import One File with Page Sep. Markup...',
					-command => sub { ::file_import_markup(); }
				],
			]
		],
		[	'command', 'I~mport Prep Text Files...',
			-command =>
			  sub { ::file_import_preptext( $textwindow, $top ) }
		],
		[	'command', 'E~xport as Prep Text Files...',
			-command => sub { ::file_export_preptext('separatefiles') }
		],
		[ 'separator', '' ],
		[ 'command', '~Quit', -command => \&::_exit ],
	];
}

sub menu_help {
	my ( $textwindow, $top ) = ( $::textwindow, $::top);
	my $help_top = [
		[ Button   => '~Manual [www]',
			-command => sub {
				::launchurl( "http://www.pgdp.net/wiki/PPTools/Guiguts" );
			  }
		],
		[ Button  => 'Guiguts ~Help on DP Forum [www]',
		  -command => sub { ::launchurl('http://www.pgdp.net/phpBB2/viewtopic.php?t=30324'); }
		],
		[ Button => '~Keyboard Shortcuts',    -command => \&::hotkeyshelp ],
		[ Button => '~Regex Quick Reference', -command => \&::regexref ],
		[ Button => 'Re~wrap Markers [www]',
		  -command => sub {
			::launchurl( 'http://www.pgdp.net/wiki/PPTools/Guiguts/Rewrapping#Rewrap_Markers' );
		  }
		],
	];
	my $character_help = [
		[ 'separator', '' ],
		[ Button => '~Greek Transliteration', -command => \&::greekpopup ],
		[ Button => '~Latin-1 Chart',         -command => \&::latinpopup ],
		[ Button => 'UTF Character ~Entry',   -command => \&::utfcharentrypopup ],
		[ Button => 'UTF Character ~Search',  -command => \&::utfcharsearchpopup ],
	];
	my $help_bottom = [
		[ 'separator', '' ],
		[ Button   => 'GG ~PP Process Checklist [www]',
		  -command => sub {
			::launchurl( "http://www.pgdp.net/wiki/Guiguts_PP_Process_Checklist" );
		  }
		],
		[ 'separator', '' ],
		[ Button => '~About Guiguts', -command => sub { ::about_pop_up($top) } ],
		[ Button => 'Software ~Versions', -command => [ \&::showversion ] ],
		# FIXME: Disable update check until it works - so? does it now?
		[
			Button   => 'Check for ~Updates',
			-command => sub { ::checkforupdates(0) }
		],
		[ Cascade => '~Bugs and Enhancements',
		  -tearoff => 1,
		  -menuitems =>
		  [
		    [ Button  => 'Report a ~Bug or Suggest Enhancement (Github Issues) [www]',
		      -command => sub { ::launchurl('https://github.com/DistributedProofreaders/guiguts/issues'); }
		    ],
		    [ Button  => 'Suggest Enhancement (DP ~Wiki) [www]',
		      -command => sub { ::launchurl('https://www.pgdp.net/wiki/Guiguts_Enhancements'); }
		    ],
		  ]
		],
	];
	push (@$help_top, @$character_help) if $::menulayout eq 'old';
	push (@$help_top, @$help_bottom);
	return $help_top;
}

sub menu_preferences {
	my $textwindow = $::textwindow;
	[
		[
			Cascade  => '~File Paths',
			-tearoff => 1,
			-menuitems =>
			  [
				[
					Button   => 'Set ~File Paths...',
					-command => sub { ::filePathsPopup(); },
				],
				[ 'separator', '' ],
				[
					Button   => 'Locate Gnutenberg Press (if self-installed)',
					-command => sub {
						my $types;
						$types = [
							[ 'Perl file', [ '.pl', ] ],
							[ 'All Files', ['*'] ],
						];
						$::gnutenbergdirectory = $textwindow->getOpenFile(
							-filetypes  => $types,
							-initialdir => $::gnutenbergdirectory,
							-title =>
							  'Where is the Gnutenberg Press (transform.pl)?'
						);
						return unless $::gnutenbergdirectory;
						$::gnutenbergdirectory =
						  ::os_normal($::gnutenbergdirectory);
						$::gnutenbergdirectory =
						  ::dirname($::gnutenbergdirectory);
						::savesettings();
					  }
				],
				[ 'separator', '' ],
				[
					Checkbutton => 'Do W3C Validation Remotely',
					-variable   => \$::w3cremote,
					-onvalue    => 1,
					-offvalue   => 0
				],
				[
					Button   => 'Set DP ~URLs...',
					-command => \&::setDPurls,
				],
			  ]
		],
		[
			Cascade  => '~Appearance',
			-tearoff => 1,
			-menuitems =>
			  [ # FIXME: sub this and generalize for all occurences in menu code.
				[ Button => '~Font...', -command => \&::fontsize ],
				[ 'separator', '' ],
				[
					Checkbutton => 'Keep Pop-ups On Top',
					-variable   => \$::stayontop,
					-onvalue    => 1,
					-offvalue   => 0
				],
				[
					Checkbutton => 'Keep Word Frequency Pop-up On Top',
					-variable   => \$::wfstayontop,
					-onvalue    => 1,
					-offvalue   => 0
				],
				[ 'separator', '' ],
				[
					Checkbutton => 'Enable Bell',
					-variable   => \$::nobell,
					-onvalue    => 0,
					-offvalue   => 1
				],
				[
					Checkbutton => 'Display Line Numbers',
					-variable   => \$::vislnnm,
					-onvalue    => 1,
					-offvalue   => 0,
				 	-command    => sub { $::vislnnm ?
								 $textwindow->showlinenum :
								 $textwindow->hidelinenum;
							     ::savesettings();
					}
				],
				[
					Checkbutton => 'Auto Show Page Images',
					-variable   => \$::auto_show_images,
					-onvalue    => 1,
					-offvalue   => 0
				],
				[
					Checkbutton => 'Do Not Center Page Markers',
					-variable   => \$::donotcenterpagemarkers,
					-onvalue    => 1,
					-offvalue   => 0
				],
				[ 'separator', '' ],
				[
					Button   => 'Set Background Color...',
					-command => sub {
						my $thiscolor = ::setcolor($::bkgcolor);
						$::bkgcolor = $thiscolor if $thiscolor;
						::savesettings();
					  }
				],
				[
					Button   => 'Set Button Highlight Color...',
					-command => sub {
						my $thiscolor = ::setcolor($::activecolor);
						$::activecolor = $thiscolor if $thiscolor;
						$::OS_WIN
						  ? $::lglobal{checkcolor} = 'white'
						  : $::lglobal{checkcolor} = $::activecolor;
						::savesettings();
					  }
				],
				[
					Button   => 'Set Scanno Highlight Color...',
					-command => sub {
						my $thiscolor = ::setcolor($::highlightcolor);
						$::highlightcolor = $thiscolor if $thiscolor;
						$textwindow->tagConfigure( 'scannos',
							-background => $::highlightcolor );
						::savesettings();
					  }
				],
				[ 'separator', '' ],
				[
					Checkbutton => 'Enable Quotes Highlighting',
					-variable   => \$::nohighlights,
					-onvalue    => 1,
					-offvalue   => 0
				],
				[
					Checkbutton => 'Enable Scanno Highlighting',
					-variable   => \$::scannos_highlighted,
					-onvalue    => 1,
					-offvalue   => 0,
					-command    => \&::highlight_scannos
				],
				[
					Checkbutton => 'Leave Bookmarks Highlighted',
					-variable   => \$::bkmkhl,
					-onvalue    => 1,
					-offvalue   => 0
				],
				[
					Checkbutton => 'Enable Shortcuts for Set Bookmark (beta)',
					-variable   => \$::hotkeybookmarks,
					-onvalue    => 1,
					-offvalue   => 0,
					-command    => sub { ::keybindings(); ::menurebuild(); ::savesettings(); },
				],
				[
					Checkbutton => 'Use Old Spellcheck Layout',
					-variable   => \$::oldspellchecklayout,
					-onvalue    => 1,
					-offvalue   => 0,
					-command    => \&::savesettings,
				],
			  ]
		],
		[
			Cascade  => '~Menu structure',
			-tearoff => 0,
			-menuitems => &select_menulayout
		],
		[
			Cascade    => '~Toolbar',
			-tearoff   => 1,
			-menuitems => [
				[
					Checkbutton => 'Enable Toolbar',
					-variable   => \$::notoolbar,
					-command    => [ \&::toolbar_toggle ],
					-onvalue    => 0,
					-offvalue   => 1
				],
				[
					Radiobutton => 'Toolbar on Top',
					-variable   => \$::toolside,
					-command    => sub {
						$::lglobal{toptool}->destroy
						  if $::lglobal{toptool};
						undef $::lglobal{toptool};
						::toolbar_toggle();
					},
					-value => 'top'
				],
				[
					Radiobutton => 'Toolbar on Bottom',
					-variable   => \$::toolside,
					-command    => sub {
						$::lglobal{toptool}->destroy
						  if $::lglobal{toptool};
						undef $::lglobal{toptool};
						::toolbar_toggle();
					},
					-value => 'bottom'
				],
				[
					Radiobutton => 'Toolbar on Left',
					-variable   => \$::toolside,
					-command    => sub {
						$::lglobal{toptool}->destroy
						  if $::lglobal{toptool};
						undef $::lglobal{toptool};
						::toolbar_toggle();
					},
					-value => 'left'
				],
				[
					Radiobutton => 'Toolbar on Right',
					-variable   => \$::toolside,
					-command    => sub {
						$::lglobal{toptool}->destroy
						  if $::lglobal{toptool};
						undef $::lglobal{toptool};
						::toolbar_toggle();
					},
					-value => 'right'
				],
				[ 'separator', '' ],
				[
					Checkbutton => 'Display Character Names',
					-variable   => \$::lglobal{longordlabel},
					-command    => sub {
						$::lglobal{longordlabel} = 1 - $::lglobal{longordlabel};
						::togglelongordlabel();
					},
					-onvalue    => 1,
					-offvalue   => 0
				],
				[
					Checkbutton => 'Display Proofer Bar',
					-variable   => \$::lglobal{proofbarvisible},
					-command    => sub {
						if ( $::lglobal{img_num_label} ) {
							$::lglobal{proofbarvisible} = 1 - $::lglobal{proofbarvisible};
							::tglprfbar();
						}
					},
					-onvalue    => 1,
					-offvalue   => 0
				],
			],
		],
		[
			Cascade  => '~Backup',
			-tearoff => 0,
			-menuitems =>
			  [ # FIXME: sub this and generalize for all occurences in menu code.
				[
					Checkbutton => 'Enable ~Auto Save',
					-variable   => \$::autosave,
					-command    => sub {
						::toggle_autosave();
						::savesettings();
					  }
				],
				[
					Button   => 'Auto Save ~Interval...',
					-command => sub {
						::saveinterval();
						::savesettings();
						::set_autosave() if $::autosave;
					  }
				],
				[
					Checkbutton => 'Keep a ~Backup Before Saving',
					-variable   => \$::autobackup,
					-onvalue    => 1,
					-offvalue   => 0
				]
			  ]
		],
		[
			Cascade  => '~Processing',
			-tearoff => 1,
			-menuitems =>
			  [ # FIXME: sub this and generalize for all occurences in menu code.
				[
					Checkbutton => 'Auto Set Page Markers On File Open',
					-variable   => \$::auto_page_marks,
					-onvalue    => 1,
					-offvalue   => 0
				],
				[
					Checkbutton => 'Track Operations History',
					-variable   => \$::trackoperations,
					-onvalue    => 1,
					-offvalue   => 0,
					-command    => \&menurebuild,
				],
				[ 'separator', '' ],
				[
					Checkbutton => 'Filter Word Freqs Intelligently',
					-variable   => \$::intelligentWF,
					-onvalue    => 1,
					-offvalue   => 0
				],
				[
					Checkbutton => "Include Two Words ('flash light') in WF Hyphen Check (beta)",
					-variable   => \$::twowordsinhyphencheck,
					-onvalue    => 1,
					-offvalue   => 0
				],
				[ 'separator', '' ],
				[
					Checkbutton => 'Return After Failed Search',
					-variable   => \$::failedsearch,
					-onvalue    => 1,
					-offvalue   => 0
				],
				[
					Button   => 'Search History Size...',
					-command => sub {
						::searchsize();
						::savesettings();
					  }
				],
				[ 'separator', '' ],
				[
					Button   => 'Spellcheck Dictionary Select...',
					-command => sub { ::spelloptions() }
				],
				[ 'separator', '' ],
				[
					Checkbutton =>
					  'Leave Space After End-Of-Line Hyphens During Rewrap',
					-variable => \$::rwhyphenspace,
					-onvalue  => 1,
					-offvalue => 0
				],
				[
					Checkbutton => "Use Greedy, Traditional Rewrap Algorithm",
					-variable   => \$::rewrapalgo,
					-onvalue    => 1,
					-offvalue   => 2,
				],
				[
					Button   => 'Set Rewrap ~Margins...',
					-command => \&::setmargins
				],
			  ]
		]
	];
}

sub menu_bookmarks {
	[
		map ( [
				Button       => "Set Bookmark $_",
				-command     => [ \&::setbookmark, "$_" ],
				-accelerator => ( $::hotkeybookmarks ? "Ctrl+Shift+$_" : '' ),
			],
			( 1 .. 5 ) ),
		[ 'separator', '' ],
		map ( [
				Button       => "Go To Bookmark $_",
				-command     => [ \&::gotobookmark, "$_" ],
				-accelerator => "Ctrl+$_"
			],
			( 1 .. 5 ) ),
	];
}

sub menu_external {
	[
		map ( [
				Button   => ($_<9?'~':'').($_==9?'1~0':$_+1).": $::extops[$_]{label}",
				-command => [ \&::xtops, $_ ]
			],
			( 0 .. $::extops_size-1 ) ),
		[ 'separator', '' ],
		[
			Button   => 'Setup ~External Operations...',
			-command => \&::externalpopup
		],
	];
}

sub menubuildold {
	my $textwindow = $::textwindow;
	my $top        = $::top;
	my $file       = $::menubar->cascade(
		-label     => '~File',
		-tearoff   => 1,
		-menuitems => menu_file
	);
	my $edit = $::menubar->cascade(
		-label     => '~Edit',
		-tearoff   => 1,
		-menuitems => [
			[
				'command', 'Undo',
				-command     => sub { $textwindow->undo; $textwindow->see('insert'); },
				-accelerator => 'Ctrl+z'
			],
			[
				'command', 'Redo',
				-command     => sub { $textwindow->redo; $textwindow->see('insert'); },
				-accelerator => 'Ctrl+y'
			],
			[ 'separator', '' ],
			[
				'command', 'Cut',
				-command     => sub { ::cut() },
				-accelerator => 'Ctrl+x'
			],
			[
				'command', 'Copy',
				-command     => sub { ::textcopy() },
				-accelerator => 'Ctrl+c'
			],
			[
				'command', 'Paste',
				-command     => sub { ::paste() },
				-accelerator => 'Ctrl+v'
			],
			[ 'separator', '' ],
			[
				'command',
				'Column Cut',
				-command => sub { ::colcut($textwindow); },
				-accelerator => 'F2'
			],
			[
				'command',
				'Column Copy',
				-command => sub { ::colcopy($textwindow); },
				-accelerator => 'F1'
			],
			[
				'command',
				'Column Paste',
				-command => sub { ::colpaste($textwindow); },
				-accelerator => 'F3'
			],
			[ 'separator', '' ],
			[
				'command',
				'Select All',
				-command => sub {
					$textwindow->selectAll;
				},
				-accelerator => 'Ctrl+a'
			],
			[
				'command',
				'Unselect All',
				-command => sub {
					$textwindow->unselectAll;
				},
			],
		]
	);
	my $search = $::menubar->cascade(
		-label     => 'Search & ~Replace',
		-tearoff   => 1,
		-menuitems => [
			[ 'command', 'Search & ~Replace...',
			  -accelerator => 'Ctrl+f',
			  -command => \&::searchpopup
			],
			[ 'command', '~Stealth Scannos...',
			  -accelerator => 'F8',
			  -command => \&::stealthscanno
			],
			[ 'command', 'Spell ~Check...',
			  -accelerator => 'F7',
			  -command => \&::spellchecker
			],
			[
				Button => 'Spell Check in Multiple Languages',
				-command =>
				  sub { ::spellmultiplelanguages( $textwindow, $top ) }
			],
			[
				'command',
				'Goto ~Line...',
				-command => sub {
					::gotoline();
					::update_indicators();
				  }
			],
			[
				'command',
				'Goto ~Page...',
				-accelerator => 'Ctrl+p',
				-command => sub {
					::gotopage();
					::update_indicators();
				  }
			],
			[
				'command', '~Which Line?',
				-command => sub { $textwindow->WhatLineNumberPopUp }
			],
			[ 'separator', '' ],
			[
				'command',
				'Find next /*..*/ block',
				-command => [ \&::nextblock, 'default', 'forward' ]
			],
			[
				'command',
				'Find previous /*..*/ block',
				-command => [ \&::nextblock, 'default', 'reverse' ]
			],
			[
				'command',
				'Find next /#..#/ block',
				-command => [ \&::nextblock, 'block', 'forward' ]
			],
			[
				'command',
				'Find previous /#..#/ block',
				-command => [ \&::nextblock, 'block', 'reverse' ]
			],
			[
				'command',
				'Find next /$..$/ block',
				-command => [ \&::nextblock, 'stet', 'forward' ]
			],
			[
				'command',
				'Find previous /$..$/ block',
				-command => [ \&::nextblock, 'stet', 'reverse' ]
			],
			[
				'command',
				'Find next /p..p/ block',
				-command => [ \&::nextblock, 'poetry', 'forward' ]
			],
			[
				'command',
				'Find previous /p..p/ block',
				-command => [ \&::nextblock, 'poetry', 'reverse' ]
			],
			[
				'command',
				'Find next indented block',
				-command => [ \&::nextblock, 'indent', 'forward' ]
			],
			[
				'command',
				'Find previous indented block',
				-command => [ \&::nextblock, 'indent', 'reverse' ]
			],
			[ 'separator', '' ],
			[
				'command',
				'Find ~Orphaned Brackets...',
				-command => \&::orphanedbrackets
			],
			[
				'command',
				'Find Orphaned DP Markup...',
				-command => \&::orphanedmarkup
			],
			[
				'command',
				'Find Proofer Comments',
				-command => \&::find_proofer_comment
			],
			[
				'command',
				'Find Asterisks w/o slash',
				-command => \&::find_asterisks
			],
			[
				'command',
				'Find Transliterations...',
				-command => \&::find_transliterations
			],
			[ 'separator', '' ],
		        [
			   Button => 'Replace [::] with incremental counter',
			   -command => \&::replace_incr_counter
			],
			[ 'separator', '' ],
			[
				'command', 'Highlight double quotes in selection',
				-command     => [ \&::hilite, '"' ],
				-accelerator => 'Ctrl+.'
			],
			[
				'command', 'Highlight single quotes in selection',
				-command     => [ \&::hilite, '\'' ],
				-accelerator => 'Ctrl+,'
			],
			[
				'command', 'Highlight arbitrary characters in selection...',
				-command     => \&::hilitepopup,
				-accelerator => 'Ctrl+Alt+h'
			],
			[
				'command',
				'Remove Highlights',
				-command => sub {    # FIXME: sub search_rm_hilites
					$textwindow->tagRemove( 'highlight', '1.0', 'end' );
					$textwindow->tagRemove( 'quotemark', '1.0', 'end' );
				},
				-accelerator => 'Ctrl+0'
			],
		]
	);
	my $bookmarks = $::menubar->cascade(
		-label     => '~Bookmarks',
		-tearoff   => 1,
		-menuitems => &menu_bookmarks,
	);
	my $selection = $::menubar->cascade(
		-label     => '~Selection',
		-tearoff   => 1,
		-menuitems => [
			[
				Button   => '~lowercase selection',
				-command => sub {
					::case( $textwindow, 'lc' );
				  },
				-accelerator => 'Ctrl+l'
			],
			[
				Button   => '~Sentence case Selection',
				-command => sub { ::case( $textwindow, 'sc' ); }
			],
			[
				Button   => '~Title Case Selection',
				-command => sub { ::case( $textwindow, 'tc' ); },
				-accelerator => 'Ctrl+t'
			],
			[
				Button   => '~UPPERCASE Selection',
				-command => sub { ::case( $textwindow, 'uc' ); },
				-accelerator => 'Ctrl+u'
			],
			[ 'separator', '' ],
			[
				Button   => 'Surroun~d Selection With...',
				-accelerator => 'Ctrl+r',
				-command => \&::surround
			],
			[
				Button   => '~Flood Fill Selection With...',
				-accelerator => 'Ctrl+o',
				-command => sub { ::flood() }
			],
			[ 'separator', '' ],
			[
				Button   => 'Indent Selection 1',
				-command => sub {
					::indent( $textwindow, 'in' );
				  }
			],
			[
				Button   => 'Indent Selection 4',
				-command => sub {
					$textwindow->addGlobStart;
					::indent( $textwindow, 'in' );
					::indent( $textwindow, 'in' );
					::indent( $textwindow, 'in' );
					::indent( $textwindow, 'in' );
					$textwindow->addGlobEnd;
				  }
			],
			[
				Button   => 'Indent Selection -1',
				-command => sub {
					::indent( $textwindow, 'out', $::operationinterrupt );
				  }
			],
			[ 'separator', '' ],
			[
				Button   => '~Rewrap Selection',
				-command => sub {
					$textwindow->addGlobStart;
					::selectrewrap( $textwindow, $::lglobal{seepagenums},
						$::scannos_highlighted, $::rwhyphenspace );
					$textwindow->addGlobEnd;
				  }
			],
			[
				Button   => '~Block Rewrap Selection',
				-command => sub {
					$textwindow->addGlobStart;
					::blockrewrap();
					$textwindow->addGlobEnd;
				  }
			],
			[
				Button   => 'Interrupt Rewrap',
				-command => sub { $::operationinterrupt = 1 }
			],
			[ 'separator', '' ],
			[ Button => 'ASCII Boxes...', -command => \&::asciibox_popup ],
			[
				Button   => '~Align text on string...',
				-command => \&::alignpopup
			],
			[ 'separator', '' ],
			[
				Button   => 'Convert To Named/Numeric Entities',
				-command => sub {
					::tonamed($textwindow);
				  }
			],
			[
				Button   => 'Convert From Named/Numeric Entities',
				-command => sub {
					::fromnamed($textwindow);
				  }
			],
			[
				Button   => 'Convert Fractions',
				-command => sub {
					my @ranges = $textwindow->tagRanges('sel');
					$textwindow->addGlobStart;
					if (@ranges) {
						while (@ranges) {
							my $end   = pop @ranges;
							my $start = pop @ranges;
							::fracconv( $textwindow, $start, $end );
						}
					} else {
						::fracconv( $textwindow, '1.0', 'end' );
					}
					$textwindow->addGlobEnd;
				  }
			],
		]
	);
	my $fixup = $::menubar->cascade(
		-label     => 'Fi~xup',
		-tearoff   => 1,
		-menuitems => [
			[
				Button   => 'Run ~Word Frequency Routine...',
				-accelerator => 'F5',
				-command => sub {
					::wordfrequency();
				  }
			],
			[ 'separator', '' ],
			[ 	Button => 'Run Bookloupe/~Gutcheck...',
				-accelerator => 'F6',
				-command => \&::gutcheck
			],
			[ Button => 'Run ~Jeebies...',     -command => \&::jeebiespop_up ],
			[
				Button   => 'pptxt...',
				-command => sub {
					::errorcheckpop_up( $textwindow, $top, 'pptxt' );
					unlink 'null' if ( -e 'null' );
				},
			],
			[	Button => 'Load Chec~kfile...',
				-command => sub {
					::errorcheckpop_up( $textwindow, $top, 'Load Checkfile' );
				}
			],
			[ 'separator', '' ],
			[
				Button   => 'Remove ~End-of-line Spaces',
				-command => sub {
					$textwindow->addGlobStart;
					::endofline();
					$textwindow->addGlobEnd;
				  }
			],
			[ Button => 'Run Fi~xup...', -command => \&::fixpopup ],
			[ 'separator', '' ],
			[
				Button   => 'Fixup ~Page Separators...',
				-command => \&::separatorpopup
			],
			[
				Button   => 'Remove End-of-page ~Blank Lines',
				-command => sub {
					$textwindow->addGlobStart;
					::delblanklines();
					$textwindow->addGlobEnd;
				  }
			],
			[ 'separator', '' ],
			[ Button => '~Footnote Fixup...', -command => \&::footnotepop ],
			[
				Button   => 'H~TML Generator & Checks...',
				-command => sub { ::htmlgenpopup( $textwindow, $top ) }
			],
			[
				Button   => '~HTML Markup...',
				-command => sub { ::htmlmarkpopup( $textwindow, $top ) }
			],
			[ Button => '~Sidenote Fixup...', -command => \&::sidenotes ],
			[
				Button   => 'Reformat Poetry ~Line Numbers',
				-command => \&::poetrynumbers
			],
			[
				Button   => 'Convert Windows CP 1252 characters to Unicode',
				-command => \&::cp1252toUni
			],
			[
				Button   => 'HTML Auto ~Index (List)',
				-command => sub { ::autoindex($textwindow) }
			],
			[
				Cascade    => 'PGTEI Tools',
				-tearoff   => 1,
				-menuitems => [
					[
						Button   => 'W3C Validate PGTEI',
						-command => sub {
							::errorcheckpop_up( $textwindow, $top,
								'W3C Validate' );
						  }
					],
					[
						Button   => 'Gnutenberg Press (HTML only)',
						-command => sub { ::gnutenberg('html') }
					],
					[
						Button   => 'Gnutenberg Press (Text only)',
						-command => sub { ::gnutenberg('txt') }
					],
					[
						Button   => 'Gnutenberg Press Online',
						-command => sub {
							::launchurl( "http://pgtei.pglaf.org/marcello/0.4/tei-online"
							);
						  }
					],
				]
			],
			[
				Cascade    => 'RST Tools',
				-tearoff   => 1,
				-menuitems => [
					[
						Button   => 'EpubMaker Online',
						-command => sub {
							::launchurl ( "http://epubmaker.pglaf.org/" );
						  }
					],
					[
						Button   => 'EpubMaker (all formats)',
						-command => sub { ::epubmaker() }
					],
					[
						Button   => 'EpubMaker (HTML only)',
						-command => sub { ::epubmaker('html') }
					],
					[
						Button   => 'dp2rst Conversion',
						-command => sub {
							::launchurl( "http://www.pgdp.net/wiki/Dp2rst" );
						  }
					],
				]
			],
			[ 'separator', '' ],
			[
				Button   => 'ASCII Table Special Effects...',
				-command => \&::tablefx
			],
			[ 'separator', '' ],
			[
				Button   => 'Clean Up Rewrap ~Markers',
				-command => sub {
					$textwindow->addGlobStart;
					::cleanup();
					$textwindow->addGlobEnd;
				  }
			],
			[ 'separator', '' ],
			[ Button => 'Find G~reek...', -command => \&::findandextractgreek ]
		]
	);
	my $text = $::menubar->cascade(
		-label     => '~Txt Processing',
		-tearoff   => 1,
		-menuitems => [
			[
				Button   => "Txt Conversion ~Palette...",
				-command => sub { ::txt_convert_palette() }
			],
			[ 'separator', '' ],
			[
				Button   => "Convert ~Italics",
				-command => sub {
					::text_convert_italic( $textwindow, $::italic_char );
				  }
			],
			[
				Button => "Convert ~Bold",
				-command =>
				  sub { ::text_convert_bold( $textwindow, $::bold_char ) }
			],
			[
				Button   => 'Convert <~tb> to asterisk break',
				-command => sub {
					$textwindow->addGlobStart;
					::text_convert_tb($textwindow);
					$textwindow->addGlobEnd;
				  }
			],
			[
				Button   => '~All of the above',
				-command => sub {
					$textwindow->addGlobStart;
					::text_convert_italic( $textwindow, $::italic_char );
					::text_convert_bold( $textwindow, $::bold_char );
					::text_convert_tb($textwindow);
					$textwindow->addGlobEnd;
				  }
			],
			[
				Button   => "~Options...",
				-command => sub { ::text_convert_options($top) }
			],
			[ 'separator', '' ],
			[
				Button   => 'Add a Thought Break',
				-command => sub {
					::text_thought_break($textwindow);
				  }
			],
			[
				Button   => 'Small caps to all caps...',
				-command => \&::text_uppercase_smallcaps
			],
			[
				Button   => 'Remove small caps markup...',
				-command => \&::text_remove_smallcaps_markup
			],
			[
				Button   => 'Manually convert small caps markup...',
				-command => \&::txt_manual_sc_conversion
			],
			[ 'separator', '' ],
			[
				Button   => "~Center Selection",
				-command => sub { ::rcaligntext( 'c', 0 ); }
			],
			[
				Button   => "~Right-Align Selection",
				-command => sub { ::rcaligntext( 'r', 0 ); }
			],
			#[
			#	Button   => "Right-Align Selection -4",
			#	-command => sub { ::rcaligntext( 'r', -4 ); }
			#],
			[
				Button   => "TOC-Align Selection",
				-command => sub { ::tocalignselection( 0 ); }
			],
		]
	);
	my $external = $::menubar->cascade(
		-label     => 'Exter~nal',
		-tearoff   => 1,
		-menuitems => &menu_external,
	);
	unicodemenu();
	$::menubar->Cascade(
		-label     => '~Preferences',
		-tearoff   => 1,
		-menuitems => menu_preferences
	);
	$::menubar->Cascade(
		-label     => '~Help',
		-tearoff   => 1,
		-menuitems => menu_help
	);
}

sub menubuilddefault {
	my $textwindow = $::textwindow;
	my $top        = $::top;

	my $file       = $::menubar->cascade(
		-label     => '~File',
		-tearoff   => 1,
		-menuitems => menu_file
	);

	my $edit = $::menubar->cascade(
		-label     => '~Edit',
		-tearoff   => 1,
		-menuitems => [
			[	'command', 'Undo',
				-accelerator => 'Ctrl+z',
				-command     => sub { $textwindow->undo; $textwindow->see('insert'); },
			],
			[	'command', 'Redo',
				-accelerator => 'Ctrl+y',
				-command     => sub { $textwindow->redo; $textwindow->see('insert'); },
			],
			[ 'separator', '' ],
			[	'command', 'Cut',
				-accelerator => 'Ctrl+x',
				-command     => sub { ::cut() },
			],
			[	'command', 'Copy',
				-accelerator => 'Ctrl+c',
				-command     => sub { ::textcopy() },
			],
			[	'command', 'Paste',
				-accelerator => 'Ctrl+v',
				-command     => sub { ::paste() },
			],
			[ 'separator', '' ],
			[	'command', 'Column Cut',
				-accelerator => 'F2',
				-command => sub { ::colcut($textwindow); },
			],
			[	'command', 'Column Copy',
				-accelerator => 'F1',
				-command => sub { ::colcopy($textwindow); },
			],
			[	'command', 'Column Paste',
				-accelerator => 'F3',
				-command => sub { ::colpaste($textwindow); },
			],
			[ 'separator', '' ],
			[	'command', 'Select All',
				-command => sub {
					$textwindow->selectAll;
				},
				-accelerator => 'Ctrl+a'
			],
			[	'command', 'Unselect All',
				-command => sub {
					$textwindow->unselectAll;
				},
			],
			[ 'separator', '' ],
			[	Button   => '~lowercase selection',
				-accelerator => 'Ctrl+l',
				-command => sub { ::case( $textwindow, 'lc' ); },
			],
			[	Button   => '~Sentence case Selection',
				-command => sub { ::case( $textwindow, 'sc' ); }
			],
			[	Button   => '~Title Case Selection',
				-accelerator => 'Ctrl+t',
				-command => sub { ::case( $textwindow, 'tc' ); },
			],
			[	Button   => '~UPPERCASE Selection',
				-accelerator => 'Ctrl+u',
				-command => sub { ::case( $textwindow, 'uc' ); },
			],
			[ 'separator', '' ],
			[	Button   => 'Su~rround Selection With...',
				-accelerator => 'Ctrl+r',
				-command => \&::surround
			],
			[	Button   => 'Fl~ood Fill Selection With...',
				-accelerator => 'Ctrl+o',
				-command => sub { ::flood() }
			],
		]
	);

	my $search = $::menubar->cascade(
		-label     => '~Search',
		-tearoff   => 1,
		-menuitems => [
			[	'command', 'Search & ~Replace...',
				-accelerator => 'Ctrl+f',
				-command => \&::searchpopup
			],
			[ 'separator', '' ],
			[	'command', 'Goto ~Page...',
				-accelerator => 'Ctrl+p',
				-command => sub {
					::gotopage();
					::update_indicators();
				  }
			],
			[	'command', 'Goto Page La~bel...',
				-accelerator => 'Ctrl+P',
				-command => sub {
					::gotolabel();
					::update_indicators();
				  }
			],
			[	'command', 'Goto ~Line...',
				-command => sub {
					::gotoline();
					::update_indicators();
				  }
			],
			[	'command', '~Which Line?',
				-command => sub { $textwindow->WhatLineNumberPopUp }
			],
			[ 'separator', '' ],
			[	'command', 'Find Next Proofer ~Comment',
				-command => \&::find_proofer_comment
			],
			[	'command', 'Find Pre~vious Proofer Comment',
				-command => [ \&::find_proofer_comment, 'reverse' ]
			],
			[ 'separator', '' ],
			[	'command', 'Find Next /*..*/ Block',
				-command => [ \&::nextblock, 'default', 'forward' ]
			],
			[	'command', 'Find Previous /*..*/ Block',
				-command => [ \&::nextblock, 'default', 'reverse' ]
			],
			[	'command', 'Find Next /#..#/ Block',
				-command => [ \&::nextblock, 'block', 'forward' ]
			],
			[	'command', 'Find Previous /#..#/ Block',
				-command => [ \&::nextblock, 'block', 'reverse' ]
			],
			[	'command', 'Find Next /$..$/ Block',
				-command => [ \&::nextblock, 'stet', 'forward' ]
			],
			[	'command', 'Find Previous /$..$/ Block',
				-command => [ \&::nextblock, 'stet', 'reverse' ]
			],
			[	'command', 'Find Next /p..p/ Block',
				-command => [ \&::nextblock, 'poetry', 'forward' ]
			],
			[	'command', 'Find Previous /p..p/ Block',
				-command => [ \&::nextblock, 'poetry', 'reverse' ]
			],
			[	'command', 'Find Next Indented Block',
				-command => [ \&::nextblock, 'indent', 'forward' ]
			],
			[	'command', 'Find Previous Indented Block',
				-command => [ \&::nextblock, 'indent', 'reverse' ]
			],
			[ 'separator', '' ],
			[	'command', 'Find ~Orphaned DP Markup...',
				-command => \&::orphanedmarkup
			],
			[	'command', 'Find ~Asterisks w/o Slash',
				-command => \&::find_asterisks
			],
			[ 'separator', '' ],
			[	'command', 'Highlight ~Double Quotes in Selection',
				-accelerator => 'Ctrl+.',
				-command     => [ \&::hilite, '"' ],
			],
			[	'command', 'Highlight ~Single Quotes in Selection',
				-accelerator => 'Ctrl+,',
				-command     => [ \&::hilite, '\'' ],
			],
			[	'command', '~Highlight Arbitrary Characters in Selection...',
				-accelerator => 'Ctrl+Alt+h',
				-command     => \&::hilitepopup,
			],
			[	'command', 'Re~move Highlights',
				-accelerator => 'Ctrl+0',
				-command => sub {    # FIXME: sub search_rm_hilites
					$textwindow->tagRemove( 'highlight', '1.0', 'end' );
					$textwindow->tagRemove( 'quotemark', '1.0', 'end' );
				},
			],
		]
	);

	my $tools = $::menubar->cascade(
		-label     => '~Tools',
		-tearoff   => 1,
		-menuitems => [
			[	Button   => '~Word Frequency...',
				-accelerator => 'F5',
				-command => \&::wordfrequency,
			],
			[ 	Button   => 'Bookloupe/~Gutcheck...',
				-accelerator => 'F6',
				-command => \&::gutcheck
			],
			[	Button   => 'Basic Fi~xup...',
				-command => \&::fixpopup
			],
			[	Button   => 'Check ~Orphaned Brackets...',
				-command => \&::orphanedbrackets
			],
			[	Cascade    => 'Character ~Tools',
				-tearoff   => 1,
				-menuitems => [
					[	Button   => 'Convert ~Windows CP 1252 characters to Unicode',
						-command => \&::cp1252toUni
					],
					[	Button   => 'Search for ~Transliterations...',
						-command => \&::find_transliterations
					],
					[	Button => '~Latin-1 Chart',
						-command => \&::latinpopup
					],
					[	Button => 'UTF Character ~Entry',
						-command => \&::utfcharentrypopup
					],
					[	Button => 'UTF Character ~Search',
						-command => \&::utfcharsearchpopup
					],
					[ 'separator', '' ],
					[	Button => '~Greek Transliteration',
						-command => \&::greekpopup
					],
					[	Button   => 'Find and ~Convert Greek...',
						-command => \&::findandextractgreek
					],
				]
			],
			[ 'separator', '' ],
			[	Button   => 'Spell ~Check...',
				-accelerator => 'F7',
				-command => \&::spellchecker
			],
			[	Button   => 'Spell Check in ~Multiple Languages',
				-command =>
				  sub { ::spellmultiplelanguages( $textwindow, $top ) }
			],
			[	Button => 'Stealt~h Scannos...',
				-accelerator => 'F8',
				-command => \&::stealthscanno
			],
			[	Button   => '~Jeebies...',
				-command => \&::jeebiespop_up
			],
			[	Button => 'Load Chec~kfile...',
				-command => sub {
					::errorcheckpop_up( $textwindow, $top, 'Load Checkfile' );
				}
			],
			[ 'separator', '' ],
			[	Button => '~Footnote Fixup...',
				-command => \&::footnotepop
			],
			[	Button => '~Sidenote Fixup...',
				-command => \&::sidenotes
			],
		        [	Button => 'Replace [::] with I~ncremental Counter',
				-command => \&::replace_incr_counter
			],
			[ 'separator', '' ],
			[	Button   => 'Fixup ~Page Separators...',
				-command => \&::separatorpopup
			],
			[	Button   => 'Remove ~End-of-page Blank Lines',
				-command => sub {
					$textwindow->addGlobStart;
					::delblanklines();
					$textwindow->addGlobEnd;
				  }
			],
			[	Button   => 'Remove End-of-~line Spaces',
				-command => sub {
					$textwindow->addGlobStart;
					::endofline();
					$textwindow->addGlobEnd;
				  }
			],
			[ 'separator', '' ],
			[	Button   => 'Rewrap ~All',
				-command => sub {
					$textwindow->addGlobStart;
					$textwindow->selectAll;
					::selectrewrap( $textwindow, $::lglobal{seepagenums},
						$::scannos_highlighted, $::rwhyphenspace );
					$textwindow->addGlobEnd;
					$textwindow->see('1.0');
				  }
			],
			[	Button   => '~Rewrap Selection',
				-command => sub {
					$textwindow->addGlobStart;
					::selectrewrap( $textwindow, $::lglobal{seepagenums},
						$::scannos_highlighted, $::rwhyphenspace );
					$textwindow->addGlobEnd;
				  }
			],
			[	Button   => '~Block Rewrap Selection',
				-command => sub {
					$textwindow->addGlobStart;
					::blockrewrap();
					$textwindow->addGlobEnd;
				  }
			],
			[	Button   => '~Interrupt Rewrap',
				-command => sub { $::operationinterrupt = 1 }
			],
			[	Button   => 'Clean ~Up Rewrap Markers',
				-command => sub {
					$textwindow->addGlobStart;
					::cleanup();
					$textwindow->addGlobEnd;
				  }
			],
			[ 'separator', '' ],
			[	Cascade    => 'PGTEI Tools',
				-tearoff   => 1,
				-menuitems => [
					[	Button   => 'W3C Validate PGTEI',
						-command => sub {
							::errorcheckpop_up( $textwindow, $top,
								'W3C Validate' );
						  }
					],
					[	Button   => 'Gnutenberg Press (HTML only)',
						-command => sub { ::gnutenberg('html') }
					],
					[	Button   => 'Gnutenberg Press (Text only)',
						-command => sub { ::gnutenberg('txt') }
					],
					[	Button   => 'Gnutenberg Press Online',
						-command => sub {
							::launchurl( "http://pgtei.pglaf.org/marcello/0.4/tei-online" );
						  }
					],
				]
			],
			[	Cascade    => 'RST Tools',
				-tearoff   => 1,
				-menuitems => [
					[	Button   => 'EpubMaker Online',
						-command => sub {
							::launchurl ( "http://epubmaker.pglaf.org/" );
						  }
					],
					[	Button   => 'EpubMaker (all formats)',
						-command => sub { ::epubmaker() }
					],
					[	Button   => 'EpubMaker (HTML only)',
						-command => sub { ::epubmaker('html') }
					],
					[	Button   => 'dp2rst Conversion',
						-command => sub {
							::launchurl( "http://www.pgdp.net/wiki/Dp2rst" );
						  }
					],
				]
			],
		]
	);

	my $txt = $::menubar->cascade(
		-label     => 'T~xt',
		-tearoff   => 1,
		-menuitems => [
			[	Button   => "Txt Conversion ~Palette...",
				-command => sub { ::txt_convert_palette() }
			],
			[ 'separator', '' ],
			[	Button   => "Convert ~Italics",
				-command => sub {
					::text_convert_italic( $textwindow, $::italic_char );
				  }
			],
			[	Button => "Convert ~Bold",
				-command =>
				  sub { ::text_convert_bold( $textwindow, $::bold_char ) }
			],
			[	Button   => 'Convert <~tb> to Asterisk Breaks',
				-command => sub {
					$textwindow->addGlobStart;
					::text_convert_tb($textwindow);
					$textwindow->addGlobEnd;
				  }
			],
			[	Button   => '~Auto-Conv. Italics, Bold and tb',
				-command => sub {
					$textwindow->addGlobStart;
					::text_convert_italic( $textwindow, $::italic_char );
					::text_convert_bold( $textwindow, $::bold_char );
					::text_convert_tb($textwindow);
					$textwindow->addGlobEnd;
				  }
			],
			[	Button   => "Auto-Convert ~Options...",
				-command => sub { ::text_convert_options($top) }
			],
			[ 'separator', '' ],
			[	Button   => 'Add a Thought Brea~k',
				-command => sub {
					::text_thought_break($textwindow);
				  }
			],
			[ 'separator', '' ],
			[	Button   => '~Small Caps to ALL CAPS',
				-command => \&::text_uppercase_smallcaps
			],
			[	Button   => '~Remove Small Caps Markup',
				-command => \&::text_remove_smallcaps_markup
			],
			[	Button   => '~Manually Convert Small Caps Markup...',
				-command => \&::txt_manual_sc_conversion
			],
			[ 'separator', '' ],
			[	Button   => 'Indent Selection ~1',
				-command => sub {
					::indent( $textwindow, 'in' );
				  }
			],
			[	Button   => 'Indent Selection ~4',
				-command => sub {
					$textwindow->addGlobStart;
					::indent( $textwindow, 'in' );
					::indent( $textwindow, 'in' );
					::indent( $textwindow, 'in' );
					::indent( $textwindow, 'in' );
					$textwindow->addGlobEnd;
				  }
			],
			[	Button   => 'In~dent Selection -1',
				-command => sub {
					::indent( $textwindow, 'out', $::operationinterrupt );
				  }
			],
			[ 'separator', '' ],
			[	Button   => "~Center Selection",
				-command => sub { ::rcaligntext( 'c', 0 ); }
			],
			[	Button   => "~Right-Align Selection",
				-command => sub { ::rcaligntext( 'r', 0 ); }
			],
			#[	Button   => "Right-Align Selection -4",
			#	-command => sub { ::rcaligntext( 'r', -4 ); }
			#],
			[	Button   => "Right-Align ~Numbers in Selection",
				-command => sub { ::tocalignselection( 0 ); }
			],
			[	Button   => 'A~lign text on string...',
				-command => \&::alignpopup
			],
			[ 'separator', '' ],
			[	Button   => 'Dra~w ASCII Boxes...',
				-command => \&::asciibox_popup
			],
			[	Button   => 'ASCII Table E~ffects...',
				-command => \&::tablefx
			],
			[ 'separator', '' ],
			[	Button   => 'PPt~xt...',
				-command => sub {
					::errorcheckpop_up( $textwindow, $top, 'pptxt' );
					unlink 'null' if ( -e 'null' );
				},
			],
		]
	);

	my $html = $::menubar->cascade(
		-label     => 'HT~ML',
		-tearoff   => 1,
		-menuitems => [
			[	Button   => 'HTML ~Generator...',
				-command => sub { ::htmlgenpopup( $textwindow, $top ) }
			],
			[	Button   => 'HTML ~Markup...',
				-command => sub { ::htmlmarkpopup( $textwindow, $top ) }
			],
			[	Button   => 'HTML Auto Inde~x (List)',
				-command => sub { ::autoindex($textwindow) }
			],
			[ 'separator', '' ],
			[	Button   => 'Convert to ~Entities',
				-command => sub {
					::tonamed($textwindow);
				  }
			],
			[	Button   => 'Convert from E~ntities',
				-command => sub {
					::fromnamed($textwindow);
				  }
			],
			[	Button   => 'Convert ~Fractions to Entities',
				-command => sub {
					my @ranges = $textwindow->tagRanges('sel');
					$textwindow->addGlobStart;
					if (@ranges) {
						while (@ranges) {
							my $end   = pop @ranges;
							my $start = pop @ranges;
							::fracconv( $textwindow, $start, $end );
						}
					} else {
						::fracconv( $textwindow, '1.0', 'end' );
					}
					$textwindow->addGlobEnd;
				  }
			],
			[ 'separator', '' ],
			[	Button   => 'HTML ~Validator ('.($::w3cremote?'online':'local').')',
				-command => sub {
					if ($::w3cremote) {
						::errorcheckpop_up( $textwindow, $top, 'W3C Validate Remote' );
					} else {
						::errorcheckpop_up( $textwindow, $top, 'W3C Validate' );
					}
					unlink 'null' if ( -e 'null' );
				}
			],
			[	Button   => '~CSS Validator',
				-command => sub {
					::errorcheckpop_up( $textwindow, $top, 'W3C Validate CSS' );
					unlink 'null' if ( -e 'null' );
				}
			],
			[ 'separator', '' ],
			[	Button => 'HTML ~Link Checker',
				-command => sub {
					::errorcheckpop_up( $textwindow, $top, 'Link Check' );
					unlink 'null' if ( -e 'null' );
				}
			],
			[	Button => 'HTML ~Tidy',
				-command => sub {
					::errorcheckpop_up( $textwindow, $top, 'HTML Tidy' );
					unlink 'null' if ( -e 'null' );
				}
			],
			[	Button   => '~PPhtml',
				-command => sub {
					::errorcheckpop_up( $textwindow, $top, 'pphtml' );
					unlink 'null' if ( -e 'null' );
				}
			],
			[	Button   => 'PPV~image',
				-command => sub {
					::errorcheckpop_up( $textwindow, $top, 'ppvimage' );
					unlink 'null' if ( -e 'null' );
				}
			],
			[	Button   => 'Check Some Common eP~ub Issues',
				-command => sub {
					::errorcheckpop_up( $textwindow, $top, 'Epub Friendly' );
					unlink 'null' if ( -e 'null' );
				}
			],
		]
	);

	unicodemenu();

	my $bookmarks = $::menubar->cascade(
		-label     => '~Bookmarks',
		-tearoff   => 1,
		-menuitems => &menu_bookmarks,
	);

	my $custom = $::menubar->cascade(
		-label     => '~Custom',
		-tearoff   => 1,
		-menuitems => &menu_external,
	);

	my $preferences = $::menubar->cascade(
		-label     => '~Preferences',
		-tearoff   => 1,
		-menuitems => &menu_preferences,
	);

	my $help = $::menubar->cascade(
		-label     => '~Help',
		-tearoff   => 1,
		-menuitems => &menu_help,
	);
}

sub unicodemenu {
	# FIXME: We'll leave this alone for now.
	if ( $Tk::VERSION =~ m{804} ) {
		my %utfsorthash;
		for ( keys %{ $::lglobal{utfblocks} } ) {
			$utfsorthash{ $::lglobal{utfblocks}{$_}->[0] } = $_;
		}
		if ( $::lglobal{utfrangesort} ) {
			$::menubar->Cascade(
				qw/-label ~Unicode -tearoff 1 -menuitems/ => [
					[
						Radiobutton => 'Sort by Name',
						-variable   => \$::lglobal{utfrangesort},
						-command    => \&menurebuild,
						-value      => 0,
					],
					map ( [
							Button   => "$utfsorthash{$_}",
							-columnbreak => (
								($::unicodemenusplit==3 && ($_ eq '0D80' || $_ eq '2300'))
								|| ($::unicodemenusplit==2 && $_ eq '1740') ? 1 : 0 ),
							-command => [
								\&::utfpopup,
								$utfsorthash{$_},
								$::lglobal{utfblocks}{ $utfsorthash{$_} }[0],
								$::lglobal{utfblocks}{ $utfsorthash{$_} }[1]
							],
							-accelerator =>
							  $::lglobal{utfblocks}{ $utfsorthash{$_} }[0]
							  . ' - '
							  . $::lglobal{utfblocks}{ $utfsorthash{$_} }[1]
						],
						( sort ( keys %utfsorthash ) )[ 0 .. 67 ] ),
				],
			);
		} else {
			$::menubar->Cascade(
				qw/-label ~Unicode -tearoff 1 -menuitems/ => [
					[
						Radiobutton => 'Sort by Range',
						-variable   => \$::lglobal{utfrangesort},
						-command    => \&menurebuild,
						-value      => 1,
					],
					map ( [
							Button   => "$_",
							-columnbreak => (
								($::unicodemenusplit==3 && ($_ eq 'Ethiopic' || $_ eq 'Mongolian'))
								|| ($::unicodemenusplit==2 && $_ eq 'Lao') ? 1 : 0 ),
							-command => [
								\&::utfpopup,
								$_,
								$::lglobal{utfblocks}{$_}[0],
								$::lglobal{utfblocks}{$_}[1]
							],
							-accelerator => $::lglobal{utfblocks}{$_}[0] . ' - '
							  . $::lglobal{utfblocks}{$_}[1]
						],
						( sort ( keys %{ $::lglobal{utfblocks} } ) )[ 0 .. 67 ]
					),
				],
			);
		}
	}
}

# Menus are not easily modifiable in place. Easier to just destroy and
## rebuild every time it is modified
sub menurebuild { 
   for ( 0 .. 12 ) { 
      $::menubar->delete('last'); 
   } 
   if($::menulayout eq 'old'){ 
      menubuildold(); 
   } else {
      menubuilddefault();
   }
   ::savesettings();
   return; 
}

sub select_menulayout {
	[
		[
			Radiobutton => '~Default Menu Structure',
			-variable   => \$::menulayout,
			-value      => 'default',
			-command    => \&::menurebuild,
		],
		[
			Radiobutton => '~Old Menu Structure',
			-variable   => \$::menulayout,
			-value      => 'old',
			-command    => \&::menurebuild,
		],
	];
}

1;
