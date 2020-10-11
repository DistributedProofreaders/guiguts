package Guiguts::MenuStructure;
use strict;
use warnings;

BEGIN {
    use Exporter();
    our ( @ISA, @EXPORT );
    @ISA    = qw(Exporter);
    @EXPORT = qw( &menurebuild );
}

# Menus are not easily modifiable in place. Easier to just destroy and
# rebuild every time it is modified
sub menurebuild {

    $::menubar->delete( 0, 'last' );    # Delete any current menus

    menu_toplevel( '~File',        &menu_file );
    menu_toplevel( '~Edit',        &menu_edit );
    menu_toplevel( '~Search',      &menu_search );
    menu_toplevel( '~Tools',       &menu_tools );
    menu_toplevel( 'T~xt',         &menu_txt );
    menu_toplevel( 'HT~ML',        &menu_html );
    menu_toplevel( '~Unicode',     &menu_unicode );
    menu_toplevel( '~Bookmarks',   &menu_bookmarks );
    menu_toplevel( '~Custom',      &menu_custom );
    menu_toplevel( '~Preferences', &menu_preferences );
    menu_toplevel( '~Help',        &menu_help );
}

sub menu_file {
    my ( $textwindow, $top ) = ( $::textwindow, $::top );
    [
        [
            'command', '~Open...',
            -accelerator => 'Ctrl+o',
            -command     => sub { ::file_open($textwindow) }
        ],
        [ 'separator', '' ],
        map ( [
                'command',
                ( $_ < 9 ? '~' : '' ) . ( $_ == 9 ? '1~0' : $_ + 1 ) . ": $::recentfile[$_]",
                -command => [ \&::openfile, $::recentfile[$_] ]
            ],
            ( 0 .. scalar(@::recentfile) - 1 ) ),
        [ 'separator', '' ],
        [
            'command', '~Save',
            -accelerator => 'Ctrl+s',
            -command     => \&::savefile
        ],
        [
            'command', 'Save ~As...',
            -accelerator => 'Ctrl+Shift+s',
            -command     => sub { ::file_saveas($textwindow) }
        ],
        [ 'command',   'Sa~ve a Copy As...', -command => sub { ::file_savecopyas($textwindow) } ],
        [ 'command',   '~Include File...',   -command => sub { ::file_include($textwindow); } ],
        [ 'command',   '~Close',             -command => sub { ::file_close($textwindow) } ],
        [ 'separator', '' ],

        menu_cascade( '~Project', &menu_file_project ),

        [
            'command',
            'I~mport Prep Text Files...',
            -command => sub { ::file_import_preptext( $textwindow, $top ) }
        ],
        [
            'command',
            'E~xport as Prep Text Files...',
            -command => sub { ::file_export_preptext('separatefiles') }
        ],
        [ 'separator', '' ],
        [ 'command', '~Quit', -command => \&::_exit ],
    ];
}

sub menu_file_project {
    [
        [ 'command', 'See ~Image', -command => \&::seecurrentimage ],
        [
            'command',
            'View Operations ~History...' . ( $::trackoperations ? '' : ' (disabled)' ),
            -command => \&::opspop_up
        ],
        [ 'separator', '' ],
        [ 'command',   'View Project ~Comments',         -command => \&::viewprojectcomments ],
        [ 'command',   'View Project Page [~www]',       -command => \&::viewprojectpage ],
        [ 'command',   'View Project ~Discussion [www]', -command => \&::viewprojectdiscussion ],
        [ 'separator', '' ],
        [ 'command',   'Set Project ~Language...', -command => \&::setlang ],
        [ 'command',   'Set Pro~ject ID...',       -command => \&::setprojectid ],
        [ 'command',   'Set I~mage Directory...',  -command => \&::setpngspath ],
        [ 'separator', '' ],
        [ 'command',   'Display/~Adjust Page Markers...', -command => \&::togglepagenums ],
        [ 'command',   '~Guess Page Markers...',          -command => \&::file_guess_page_marks ],
        [ 'command',   '~Set Page Markers',               -command => \&::file_mark_pages ],
        [ 'command',   'Configure Page La~bels...',       -command => \&::pageadjust ],
        [ 'separator', '' ],
        [
            'command',
            'Export One File with Page Separators...',
            -command => sub { ::file_export_preptext('onefile') }
        ],
        [
            'command',
            'Export One File with Page Sep. Markup...',
            -command => sub { ::file_export_pagemarkup(); }
        ],
        [
            'command',
            'Import One File with Page Sep. Markup...',
            -command => sub { ::file_import_markup(); }
        ],
    ]
}

sub menu_edit {
    my $textwindow = $::textwindow;
    [
        [
            'command', 'Undo',
            -accelerator => 'Ctrl+z',
            -command     => sub { $textwindow->undo; $textwindow->see('insert'); },
        ],
        [
            'command', 'Redo',
            -accelerator => 'Ctrl+y',
            -command     => sub { $textwindow->redo; $textwindow->see('insert'); },
        ],
        [ 'separator', '' ],
        [
            'command', 'Cut',
            -accelerator => 'Ctrl+x',
            -command     => sub { ::cut() },
        ],
        [
            'command', 'Copy',
            -accelerator => 'Ctrl+c',
            -command     => sub { ::textcopy() },
        ],
        [
            'command', 'Paste',
            -accelerator => 'Ctrl+v',
            -command     => sub { ::paste() },
        ],
        [ 'separator', '' ],
        [
            'command', 'Column Cut',
            -accelerator => 'F2',
            -command     => sub { ::colcut($textwindow); },
        ],
        [
            'command', 'Column Copy',
            -accelerator => 'F1',
            -command     => sub { ::colcopy($textwindow); },
        ],
        [
            'command', 'Column Paste',
            -accelerator => 'F3',
            -command     => sub { ::colpaste($textwindow); },
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
        [ 'separator', '' ],
        [
            'command',
            '~lowercase selection',
            -accelerator => 'Ctrl+l',
            -command     => sub { ::case( $textwindow, 'lc' ); },
        ],
        [
            'command',
            '~Sentence case Selection',
            -command => sub { ::case( $textwindow, 'sc' ); }
        ],
        [
            'command',
            '~Title Case Selection',
            -accelerator => 'Ctrl+t',
            -command     => sub { ::case( $textwindow, 'tc' ); },
        ],
        [
            'command',
            '~UPPERCASE Selection',
            -accelerator => 'Ctrl+u',
            -command     => sub { ::case( $textwindow, 'uc' ); },
        ],
        [ 'separator', '' ],
        [
            'command',
            'Su~rround Selection With...',
            -accelerator => 'Ctrl+r',
            -command     => \&::surround
        ],
        [
            'command',
            'Fl~ood Fill Selection With...',
            -accelerator => 'Ctrl+e',
            -command     => sub { ::flood() }
        ],
    ];
}

sub menu_search {
    my $textwindow = $::textwindow;
    [
        [
            'command', 'Search & ~Replace...',
            -accelerator => 'Ctrl+f',
            -command     => \&::searchpopup
        ],
        [ 'separator', '' ],
        [
            'command',
            'Goto ~Page...',
            -accelerator => 'Ctrl+p',
            -command     => sub {
                ::gotopage();
                ::update_indicators();
            }
        ],
        [
            'command',
            'Goto Page La~bel...',
            -accelerator => 'Ctrl+Shift+p',
            -command     => sub {
                ::gotolabel();
                ::update_indicators();
            }
        ],
        [
            'command',
            'Goto ~Line...',
            -accelerator => 'Ctrl+j',
            -command     => sub {
                ::gotoline();
                ::update_indicators();
            }
        ],
        [ 'command',   '~Which Line?', -command => sub { $textwindow->WhatLineNumberPopUp } ],
        [ 'separator', '' ],
        [ 'command',   'Find Next Proofer ~Comment', -command => \&::find_proofer_comment ],
        [
            'command',
            'Find Pre~vious Proofer Comment',
            -command => [ \&::find_proofer_comment, 'reverse' ]
        ],
        [ 'separator', '' ],
        [
            'command', 'Find Next /*..*/ Block', -command => [ \&::nextblock, 'default', 'forward' ]
        ],
        [
            'command',
            'Find Previous /*..*/ Block',
            -command => [ \&::nextblock, 'default', 'reverse' ]
        ],
        [ 'command', 'Find Next /#..#/ Block', -command => [ \&::nextblock, 'block', 'forward' ] ],
        [
            'command',
            'Find Previous /#..#/ Block',
            -command => [ \&::nextblock, 'block', 'reverse' ]
        ],
        [ 'command', 'Find Next /$..$/ Block', -command => [ \&::nextblock, 'stet', 'forward' ] ],
        [
            'command',
            'Find Previous /$..$/ Block',
            -command => [ \&::nextblock, 'stet', 'reverse' ]
        ],
        [ 'command', 'Find Next /p..p/ Block', -command => [ \&::nextblock, 'poetry', 'forward' ] ],
        [
            'command',
            'Find Previous /p..p/ Block',
            -command => [ \&::nextblock, 'poetry', 'reverse' ]
        ],
        [
            'command',
            'Find Next Indented Block',
            -command => [ \&::nextblock, 'indent', 'forward' ]
        ],
        [
            'command',
            'Find Previous Indented Block',
            -command => [ \&::nextblock, 'indent', 'reverse' ]
        ],
        [ 'separator', '' ],
        [ 'command',   'Find ~Orphaned DP Markup...', -command => \&::orphanedmarkup ],
        [ 'command',   'Find ~Asterisks w/o Slash',   -command => \&::find_asterisks ],
        [ 'separator', '' ],
        [
            'command', 'Highlight ~Double Quotes in Selection',
            -accelerator => 'Ctrl+.',
            -command     => \&::hilitedoublequotes,
        ],
        [
            'command', 'Highlight ~Single Quotes in Selection',
            -accelerator => 'Ctrl+,',
            -command     => \&::hilitesinglequotes,
        ],
        [
            'command', '~Highlight Arbitrary Characters in Selection...',
            -accelerator => 'Ctrl+Alt+h',
            -command     => \&::hilitepopup,
        ],
        [
            'command', 'Re~move Highlights',
            -accelerator => 'Ctrl+0',
            -command     => \&::hiliteremove,
        ],
    ];
}

sub menu_tools {
    my ( $textwindow, $top ) = ( $::textwindow, $::top );
    [
        [
            'command', '~Word Frequency...',
            -accelerator => 'F5',
            -command     => \&::wordfrequency,
        ],
        [
            'command', 'Bookloupe/~Gutcheck...',
            -accelerator => 'F6',
            -command     => sub { ::errorcheckpop_up( $textwindow, $top, 'Bookloupe/Gutcheck' ); }
        ],
        [ 'command', 'Basic Fi~xup...',             -command => \&::fixpopup ],
        [ 'command', 'Check ~Orphaned Brackets...', -command => \&::orphanedbrackets ],

        menu_cascade( 'Character ~Tools', &menu_tools_charactertools ),

        [ 'separator', '' ],
        [
            'command', 'Spell ~Check...',
            -accelerator => 'F7',
            -command     => \&::spellchecker
        ],
        [
            'command',
            'Spell Check in ~Multiple Languages',
            -command => sub { ::spellmultiplelanguages( $textwindow, $top ) }
        ],
        [
            'command', 'Stealt~h Scannos...',
            -accelerator => 'F8',
            -command     => \&::stealthscanno
        ],
        [
            'command',
            'Run ~Jeebies...',
            -command => sub {
                ::errorcheckpop_up( $textwindow, $top, 'Jeebies' );
            }
        ],
        [
            'command',
            'Load Chec~kfile...',
            -command => sub {
                ::errorcheckpop_up( $textwindow, $top, 'Load Checkfile' );
            }
        ],
        [ 'separator', '' ],
        [ 'command', '~Footnote Fixup...', -command => \&::footnotepop ],
        [ 'command', '~Sidenote Fixup...', -command => \&::sidenotes ],
        [
            'command',
            'Replace [::] with I~ncremental Counter',
            -command => \&::replace_incr_counter
        ],
        [ 'separator', '' ],
        [ 'command', 'Fixup ~Page Separators...', -command => \&::separatorpopup ],
        [
            'command',
            'Remove ~End-of-page Blank Lines',
            -command => sub {
                $textwindow->addGlobStart;
                ::delblanklines();
                $textwindow->addGlobEnd;
            }
        ],
        [
            'command',
            'Remove End-of-~line Spaces',
            -command => sub {
                $textwindow->addGlobStart;
                ::endofline();
                $textwindow->addGlobEnd;
            }
        ],
        [ 'separator', '' ],
        [
            'command',
            'Rewrap ~All',
            -command => sub {
                $textwindow->addGlobStart;
                $textwindow->selectAll;
                ::selectrewrap();
                $textwindow->addGlobEnd;
                $textwindow->see('1.0');
            }
        ],
        [
            'command',
            '~Rewrap Selection',
            -accelerator => 'Ctrl+w',
            -command     => sub {
                $textwindow->addGlobStart;
                ::selectrewrap();
                $textwindow->addGlobEnd;
            }
        ],
        [
            'command',
            '~Block Rewrap Selection',
            -accelerator => 'Ctrl+Shift+w',
            -command     => sub {
                $textwindow->addGlobStart;
                ::blockrewrap();
                $textwindow->addGlobEnd;
            }
        ],
        [ 'command', '~Interrupt Rewrap', -command => sub { $::operationinterrupt = 1 } ],
        [
            'command',
            'Clean ~Up Rewrap Markers',
            -command => sub {
                $textwindow->addGlobStart;
                ::cleanup();
                $textwindow->addGlobEnd;
            }
        ],
    ];
}

sub menu_tools_charactertools {
    [
        [
            'command', 'Convert ~Windows CP 1252 characters to Unicode',
            -command => \&::cp1252toUni
        ],
        [ 'command',   'Search for ~Transliterations...', -command => \&::find_transliterations ],
        [ 'command',   '~Latin-1 Chart',                  -command => \&::latinpopup ],
        [ 'command',   'UTF Character ~Entry',            -command => \&::utfcharentrypopup ],
        [ 'command',   'UTF Character ~Search',           -command => \&::utfcharsearchpopup ],
        [ 'separator', '' ],
        [ 'command',   '~Greek Transliteration',          -command => \&::greekpopup ],
        [ 'command',   'Find and ~Convert Greek...',      -command => \&::findandextractgreek ],
    ]
}

sub menu_txt {
    my ( $textwindow, $top ) = ( $::textwindow, $::top );
    [
        [ 'command', "Txt Conversion ~Palette...", -command => sub { ::txt_convert_palette() } ],
        [ 'separator', '' ],
        [
            'command',
            "Convert ~Italics",
            -command => sub {
                ::text_convert_italic( $textwindow, $::italic_char );
            }
        ],
        [
            'command',
            "Convert ~Bold",
            -command => sub { ::text_convert_bold( $textwindow, $::bold_char ) }
        ],
        [
            'command',
            'Convert <~tb> to Asterisk Breaks',
            -command => sub {
                $textwindow->addGlobStart;
                ::text_convert_tb($textwindow);
                $textwindow->addGlobEnd;
            }
        ],
        [
            'command',
            '~Auto-Convert Italics, Bold and tb',
            -command => sub {
                $textwindow->addGlobStart;
                ::text_convert_italic( $textwindow, $::italic_char );
                ::text_convert_bold( $textwindow, $::bold_char );
                ::text_convert_tb($textwindow);
                $textwindow->addGlobEnd;
            }
        ],
        [ 'command', "Auto-Convert ~Options...", -command => sub { ::text_convert_options($top) } ],
        [ 'separator', '' ],
        [
            'command',
            'Add a Thought Brea~k',
            -command => sub {
                ::text_thought_break($textwindow);
            }
        ],
        [ 'separator', '' ],
        [ 'command', '~Small Caps to ALL CAPS',   -command => \&::text_uppercase_smallcaps ],
        [ 'command', '~Remove Small Caps Markup', -command => \&::text_remove_smallcaps_markup ],
        [
            'command',
            '~Manually Convert Small Caps Markup...',
            -command => \&::txt_manual_sc_conversion
        ],
        [ 'separator', '' ],
        [
            'command',
            'Indent Selection ~1',
            -accelerator => 'Ctrl+m',
            -command     => sub {
                ::indent( $textwindow, 'in' );
            }
        ],
        [
            'command',
            'Indent Selection ~4',
            -accelerator => 'Ctrl+Alt+m',
            -command     => sub {
                $textwindow->addGlobStart;
                ::indent( $textwindow, 'in' ) for ( 1 .. 4 );
                $textwindow->addGlobEnd;
            }
        ],
        [
            'command',
            'In~dent Selection -1',
            -accelerator => 'Ctrl+Shift+m',
            -command     => sub {
                ::indent( $textwindow, 'out' );
            }
        ],
        [ 'separator', '' ],
        [ 'command', "~Center Selection",      -command => sub { ::rcaligntext( 'c', 0 ); } ],
        [ 'command', "~Right-Align Selection", -command => sub { ::rcaligntext( 'r', 0 ); } ],
        [
            'command',
            "Right-Align ~Numbers in Selection",
            -command => sub { ::tocalignselection(0); }
        ],
        [ 'command',   'A~lign text on string...', -command => \&::alignpopup ],
        [ 'separator', '' ],
        [ 'command',   'Dra~w ASCII Boxes...', -command => \&::asciibox_popup ],
        [ 'command',   'ASCII Table E~ffects...', -command => \&::tablefx ],
        [ 'separator', '' ],
        [
            'command',
            'PPt~xt...',
            -command => sub {
                ::errorcheckpop_up( $textwindow, $top, 'pptxt' );
            },
        ],
    ];
}

sub menu_html {
    my ( $textwindow, $top ) = ( $::textwindow, $::top );
    [
        [
            'command', 'HTML ~Generator...', -command => sub { ::htmlgenpopup( $textwindow, $top ) }
        ],
        [ 'command', 'HTML ~Markup...', -command => sub { ::htmlmarkpopup( $textwindow, $top ) } ],
        [ 'command',   'HTML Auto Inde~x (List)', -command => sub { ::autoindex($textwindow) } ],
        [ 'separator', '' ],
        [
            'command',
            'Convert to ~Entities',
            -command => sub {
                ::tonamed($textwindow);
            }
        ],
        [
            'command',
            'Convert from E~ntities',
            -command => sub {
                ::fromnamed($textwindow);
            }
        ],
        [
            'command',
            'Convert ~Fractions to Entities',
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
        [
            'command',
            'HTML ~Validator (' . ( $::w3cremote ? 'online' : 'local' ) . ')',
            -command => sub {
                if ($::w3cremote) {
                    ::errorcheckpop_up( $textwindow, $top, 'W3C Validate Remote' );
                } else {
                    ::errorcheckpop_up( $textwindow, $top, 'W3C Validate' );
                }
            }
        ],
        [
            'command',
            '~CSS Validator',
            -command => sub {
                ::errorcheckpop_up( $textwindow, $top, 'W3C Validate CSS' );
            }
        ],
        [ 'separator', '' ],
        [
            'command',
            'HTML ~Link Checker',
            -command => sub {
                ::errorcheckpop_up( $textwindow, $top, 'Link Check' );
            }
        ],
        [
            'command',
            'HTML ~Tidy',
            -command => sub {
                ::errorcheckpop_up( $textwindow, $top, 'HTML Tidy' );
            }
        ],
        [
            'command',
            '~PPhtml',
            -command => sub {
                ::errorcheckpop_up( $textwindow, $top, 'pphtml' );
            }
        ],
        [
            'command',
            'PPV~image',
            -command => sub {
                ::errorcheckpop_up( $textwindow, $top, 'ppvimage' );
            }
        ],
        [ 'command', 'EB~ookMaker', -command => sub { ::ebookmaker() } ],
    ];
}

sub menu_unicode {
    [
        [
            Radiobutton => ( $::lglobal{utfrangesort} ? 'Sort by Name' : 'Sort by Range' ),
            -variable   => \$::lglobal{utfrangesort},
            -command    => \&menurebuild,
            -value      => ( $::lglobal{utfrangesort} ? 0 : 1 ),
        ],
        map ( [
                'command',
                "$_",
                -columnbreak => menu_unicode_break($_),
                -command =>
                  [ \&::utfpopup, $_, $::lglobal{utfblocks}{$_}[0], $::lglobal{utfblocks}{$_}[1] ],
                -accelerator => $::lglobal{utfblocks}{$_}[0] . ' - ' . $::lglobal{utfblocks}{$_}[1]
            ],
            ( sort menu_unicode_sort ( keys %{ $::lglobal{utfblocks} } ) ) ),
    ],
      ;
}

# Returns 1 if Unicode menu column break should be inserted at the given block name
sub menu_unicode_break {
    my $block = shift;
    if ( $::lglobal{utfrangesort} ) {
        return ( $block eq 'Sinhala' or $block eq 'Miscellaneous Technical' ) ? 1 : 0;
    } else {
        return ( $block eq 'Ethiopic' or $block eq 'Mongolian' ) ? 1 : 0;
    }
}

# Sort function for Unicode menu - either by start of hex range or by block name
sub menu_unicode_sort {
    if ( $::lglobal{utfrangesort} ) {
        $::lglobal{utfblocks}{$a}[0] cmp $::lglobal{utfblocks}{$b}[0];
    } else {
        $a cmp $b;
    }
}

sub menu_bookmarks {
    [
        map ( [
                'command', "Set Bookmark $_",
                -command     => [ \&::setbookmark, "$_" ],
                -accelerator => "Ctrl+Shift+$_"
            ],
            ( 1 .. 5 ) ),
        [ 'separator', '' ],
        map ( [
                'command', "Go To Bookmark $_",
                -command     => [ \&::gotobookmark, "$_" ],
                -accelerator => "Ctrl+$_"
            ],
            ( 1 .. 5 ) ),
    ];
}

sub menu_custom {
    [
        map ( [
                'command',
                ( $_ < 9 ? '~' : '' ) . ( $_ == 9 ? '1~0' : $_ + 1 ) . ": $::extops[$_]{label}",
                -command => [ \&::xtops, $_ ]
            ],
            ( 0 .. $#::extops ) ),
        [ 'separator', '' ],
        [ 'command', 'Set ~External Programs...', -command => \&::externalpopup ],
    ];
}

sub menu_preferences {
    my $textwindow = $::textwindow;
    [
        menu_cascade( '~File Paths', &menu_preferences_filepaths ),
        menu_cascade( '~Appearance', &menu_preferences_appearance ),
        menu_cascade( '~Toolbar',    &menu_preferences_toolbar ),
        menu_cascade( '~Backup',     &menu_preferences_backup ),
        menu_cascade( '~Processing', &menu_preferences_processing )
    ];
}

sub menu_preferences_filepaths {
    [
        [
            'command', 'Set ~File Paths...', -command => sub { ::filePathsPopup(); },
        ],
        [ 'separator', '' ],
        [
            Checkbutton => 'Do W3C Validation Remotely',
            -command    => \&::menurebuild,
            -variable   => \$::w3cremote,
            -onvalue    => 1,
            -offvalue   => 0
        ],
        [ 'command', 'Set DP ~URLs...', -command => \&::setDPurls, ],
    ]
}

sub menu_preferences_appearance {
    my $textwindow = $::textwindow;
    [
        [ 'command', 'Set ~Font...', -command => \&::fontsize ],
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
            -command    => sub { ::displaylinenumbers($::vislnnm) },
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
            'command',
            'Set Background Color...',
            -command => sub {
                my $thiscolor = ::setcolor($::bkgcolor);
                $::bkgcolor = $thiscolor if $thiscolor;
                ::savesettings();
            }
        ],
        [
            'command',
            'Set Button Highlight Color...',
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
            'command',
            'Set Scanno Highlight Color...',
            -command => sub {
                my $thiscolor = ::setcolor($::highlightcolor);
                $::highlightcolor = $thiscolor if $thiscolor;
                $textwindow->tagConfigure( 'scannos', -background => $::highlightcolor );
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
            Checkbutton => 'Use Old Spell Check Layout',
            -variable   => \$::oldspellchecklayout,
            -onvalue    => 1,
            -offvalue   => 0,
            -command    => \&::savesettings,
        ],
    ];
}

sub menu_preferences_toolbar {
    [
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
            -onvalue  => 1,
            -offvalue => 0
        ],
    ],
      ;
}

sub menu_preferences_backup {
    [
        [
            Checkbutton => 'Enable ~Auto Save',
            -variable   => \$::autosave,
            -command    => sub {
                ::reset_autosave();
                ::savesettings();
            }
        ],
        [
            'command',
            'Set Auto Save ~Interval...',
            -command => sub {
                ::saveinterval();
                ::savesettings();
                ::reset_autosave();
            }
        ],
        [
            Checkbutton => 'Keep a ~Backup Before Saving',
            -variable   => \$::autobackup,
            -onvalue    => 1,
            -offvalue   => 0
        ]
    ]
}

sub menu_preferences_processing {
    [
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
            'command',
            'Set Search History Size...',
            -command => sub {
                ::searchsize();
                ::savesettings();
            }
        ],
        [ 'separator', '' ],
        [ 'command',   'Set Spell Check Options...', -command => sub { ::spelloptions() } ],
        [ 'separator', '' ],
        [
            Checkbutton => 'Leave Space After End-Of-Line Hyphens During Rewrap',
            -variable   => \$::rwhyphenspace,
            -onvalue    => 1,
            -offvalue   => 0
        ],
        [ 'command', 'Set Rewrap ~Margins...', -command => \&::setmargins ],
        [
            Checkbutton => "Always Treat as ~UTF-8",
            -variable   => \$::utf8save,
            -onvalue    => 1,
            -offvalue   => 0,
        ],
        [
            Checkbutton => "CSS Validation Level 2.1",
            -variable   => \$::cssvalidationlevel,
            -onvalue    => 'css21',
            -offvalue   => 'css3',
        ],
    ]
}

sub menu_help {
    my $top = $::top;
    [
        [
            'command',
            '~Manual [www]',
            -command => sub {
                ::launchurl('https://www.pgdp.net/wiki/PPTools/Guiguts/Guiguts_1.1_Manual');
            }
        ],
        [
            'command',
            'Guiguts ~Help on DP Forum [www]',
            -command => sub { ::launchurl('https://www.pgdp.net/phpBB3/viewtopic.php?t=11466'); }
        ],
        [ 'command',   '~Keyboard Shortcuts',    -command => \&::hotkeyshelp ],
        [ 'command',   '~Regex Quick Reference', -command => \&::regexref ],
        [ 'separator', '' ],
        [
            'command',
            'GG ~PP Process Checklist [www]',
            -command => sub {
                ::launchurl("https://www.pgdp.net/wiki/Guiguts_PP_Process_Checklist");
            }
        ],
        [ 'separator', '' ],
        [ 'command', '~About Guiguts',     -command => sub { ::about_pop_up($top) } ],
        [ 'command', 'Software ~Versions', -command => [ \&::showversion ] ],
        [ 'command', 'Check for ~Updates', -command => sub { ::checkforupdates("now") } ],
        [
            'command',
            'Report ~Bug or Suggest Enhancement (DP Wiki) [www]',
            -command =>
              sub { ::launchurl('https://www.pgdp.net/wiki/Guiguts_Bugs_and_Enhancements'); }
        ],
    ];
}

# Add a top level menu with given label and menu items
sub menu_toplevel {
    $::menubar->cascade(
        -label     => shift,
        -tearoff   => 1,
        -menuitems => shift,
    );
}

# Add a cascade menu with given label and menu items
sub menu_cascade {
    [
        Cascade    => shift,
        -tearoff   => 1,
        -menuitems => shift,
    ]
}

1;
