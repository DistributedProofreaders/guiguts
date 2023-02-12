package Guiguts::MenuStructure;
use strict;
use warnings;

BEGIN {
    use Exporter();
    our ( @ISA, @EXPORT );
    @ISA    = qw(Exporter);
    @EXPORT = qw( &menurebuild &showcontextmenu );
}

# Menus are not easily modifiable in place. Easier to just destroy and
# rebuild every time it is modified
sub menurebuild {

    return unless Tk::Exists($::menubar);    # Abort calls made before menubar is created

    $::menubar->delete( 0, 'last' );         # Delete any current menus

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
    my $textwindow = $::textwindow;
    [
        [
            'command', '~Open...',
            -accelerator => 'Ctrl+o',
            -command     => sub { ::file_open($textwindow); }
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
            -command     => sub { ::file_saveas($textwindow); }
        ],
        [
            'command',
            'Sa~ve a Copy As...',
            -command => sub { ::file_saveas( $textwindow, "copy" ); }
        ],
        [ 'command',   '~Include File...', -command => sub { ::file_include($textwindow); } ],
        [ 'command',   '~Close',           -command => sub { ::file_close($textwindow); } ],
        [ 'separator', '' ],

        menu_cascade( '~Project', &menu_file_project ),

        menu_cascade( 'Co~ntent Providing', &menu_file_content_providing ),

        [ 'separator', '' ],
        [ 'command',   '~Quit', -command => \&::_exit ],
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
    ];
}

sub menu_file_content_providing {
    my ( $textwindow, $top ) = ( $::textwindow, $::top );
    [
        [
            'command',
            '~Import Prep Text Files...',
            -command => sub { ::file_import_preptext( $textwindow, $top ); }
        ],
        [
            'command',
            '~Export as Prep Text Files...',
            -command => sub { ::file_export_preptext('separatefiles'); }
        ],
        [ 'separator', '' ],
        [
            'command',
            'Export One File with Page ~Separators...',
            -command => sub { ::file_export_preptext('onefile'); }
        ],
        [
            'command',
            'I~mport One File with Page Sep. Markup...',
            -command => sub { ::file_import_markup(); }
        ],
        [
            'command',
            'E~xport One File with Page Sep. Markup...',
            -command => sub { ::file_export_pagemarkup(); }
        ],
        [
            'command', 'Import ~TIA Abbyy OCR File...', -command => sub { ::file_import_ocr(); }
        ],
        [ 'separator', '' ],
        [
            Checkbutton => '~Highlight WF Characters Not in Selected Suites',
            -command    => sub { ::sortanddisplayhighlight('force'); },
            -variable   => \$::charsuitewfhighlight,
            -onvalue    => 1,
            -offvalue   => 0
        ],
        [
            'command', 'Manage ~Character Suites...', -command => sub { ::charsuitespopup(); }
        ],
        [ 'separator', '' ],
        [
            'command', 'CP Character S~ubstitutions', -command => sub { ::cpcharactersubs(); },
        ],
    ];
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
        menu_edit_cutcopypaste(),
        [
            'command', 'Alternative Paste',
            -accelerator => "Ctrl+$::altkeyname+v",
            -command     => sub { ::paste('alternative'); },
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
            'command', 'Select All',
            -accelerator => 'Ctrl+a',
            -command     => sub { $textwindow->selectAll; },
        ],
        [
            'command', 'Unselect All', -command => sub { $textwindow->unselectAll; },
        ],
        [ 'separator', '' ],
        [
            'command', '~lowercase selection',
            -accelerator => 'Ctrl+l',
            -command     => sub { ::case( $textwindow, 'lc' ); },
        ],
        [
            'command', '~Sentence case Selection', -command => sub { ::case( $textwindow, 'sc' ); }
        ],
        [
            'command', '~Title Case Selection',
            -accelerator => 'Ctrl+t',
            -command     => sub { ::case( $textwindow, 'tc' ); },
        ],
        [
            'command', '~UPPERCASE Selection',
            -accelerator => 'Ctrl+u',
            -command     => sub { ::case( $textwindow, 'uc' ); },
        ],
        [ 'separator', '' ],
        [
            'command', 'Su~rround Selection With...',
            -accelerator => 'Ctrl+r',
            -command     => \&::surround
        ],
        [
            'command',
            'Fl~ood Fill Selection With...',
            -accelerator => 'Ctrl+e',
            -command     => sub { ::flood(); }
        ],
    ];
}

sub menu_edit_cutcopypaste {
    [
        'command', 'Cut',
        -accelerator => 'Ctrl+x',
        -command     => sub { ::cut(); },
    ],
      [
        'command', 'Copy',
        -accelerator => 'Ctrl+c',
        -command     => sub { ::textcopy(); },
      ],
      [
        'command', 'Paste',
        -accelerator => 'Ctrl+v',
        -command     => sub { ::paste(); },
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
        [
            'command', 'Quic~k Search...',
            -accelerator => 'Shift+Ctrl+f',
            -command     => \&::quicksearchpopup
        ],
        [
            'command', '~Quick Count',
            -accelerator => 'Shift+Ctrl+b',
            -command     => \&::quickcount
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
        [ 'command',   'Find ~Orphaned DP Markup...', -command => \&::orphanedmarkup ],
        [ 'command',   'Find ~Asterisks w/o Slash',   -command => \&::find_asterisks ],
        menu_cascade( '~Find Block Markup', &menu_search_block ),
        [ 'command',   'Find ~Match', -command => \&::hilitematch ],
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
            'command', '~Highlight Character, String or Regex...',
            -accelerator => "Ctrl+$::altkeyname+h",
            -command     => \&::hilitepopup,
        ],
        [
            Checkbutton  => 'Highlight S~urrounding Quotes & Brackets',
            -variable    => \$::nohighlights,
            -onvalue     => 1,
            -offvalue    => 0,
            -accelerator => "Ctrl+;",
            -command     => \&::highlight_quotbrac
        ],
        [
            Checkbutton  => 'Highlight Al~ignment Column',
            -accelerator => 'Ctrl+Shift+a',
            -variable    => \$::lglobal{highlightalignment},
            -onvalue     => 1,
            -offvalue    => 0,
            -command     => sub {
                if ( $::lglobal{highlightalignment} ) {
                    ::hilite_alignment_start();
                } else {
                    ::hilite_alignment_stop();
                }
            }
        ],
        [
            'command', 'Re~move Highlights',
            -accelerator => 'Ctrl+0',
            -command     => \&::hiliteremove,
        ],
    ];
}

sub menu_search_block {
    [
        [
            'command', 'Find Next Block', -command => [ \&::nextblock, 'all' ]
        ],
        [
            'command', 'Find Previous Block', -command => [ \&::nextblock, 'all', 'reverse' ]
        ],
        [
            'command', 'Find Next Indented Block', -command => [ \&::nextblock, 'indent' ]
        ],
        [
            'command',
            'Find Previous Indented Block',
            -command => [ \&::nextblock, 'indent', 'reverse' ]
        ],
        [
            'command', 'Find Next /* Block', -command => [ \&::nextblock, '/*' ]
        ],
        [
            'command', 'Find Previous /* Block', -command => [ \&::nextblock, '/*', 'reverse' ]
        ],
        [ 'command', 'Find Next /# Block', -command => [ \&::nextblock, '/#' ] ],
        [
            'command', 'Find Previous /# Block', -command => [ \&::nextblock, '/#', 'reverse' ]
        ],
        [ 'command', 'Find Next /$ Block', -command => [ \&::nextblock, '/$' ] ],
        [
            'command', 'Find Previous /$ Block', -command => [ \&::nextblock, '/$', 'reverse' ]
        ],
        [ 'command', 'Find Next /P Block', -command => [ \&::nextblock, '/P' ] ],
        [
            'command', 'Find Previous /P Block', -command => [ \&::nextblock, '/P', 'reverse' ]
        ],
        [ 'command', 'Find Next /C Block', -command => [ \&::nextblock, '/C' ] ],
        [
            'command', 'Find Previous /C Block', -command => [ \&::nextblock, '/C', 'reverse' ]
        ],
        [ 'command', 'Find Next /R Block', -command => [ \&::nextblock, '/R' ] ],
        [
            'command', 'Find Previous /R Block', -command => [ \&::nextblock, '/R', 'reverse' ]
        ],
        [ 'command', 'Find Next /F Block', -command => [ \&::nextblock, '/F' ] ],
        [
            'command', 'Find Previous /F Block', -command => [ \&::nextblock, '/F', 'reverse' ]
        ],
        [ 'command', 'Find Next /L Block', -command => [ \&::nextblock, '/L' ] ],
        [
            'command', 'Find Previous /L Block', -command => [ \&::nextblock, '/L', 'reverse' ]
        ],
        [ 'command', 'Find Next /X Block', -command => [ \&::nextblock, '/X' ] ],
        [
            'command', 'Find Previous /X Block', -command => [ \&::nextblock, '/X', 'reverse' ]
        ],
        [ 'command', 'Find Next /I Block', -command => [ \&::nextblock, '/I' ] ],
        [
            'command', 'Find Previous /I Block', -command => [ \&::nextblock, '/I', 'reverse' ]
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
            'command', 'Boo~kloupe...',
            -accelerator => 'F6',
            -command     => sub { ::errorcheckpop_up( $textwindow, $top, 'Bookloupe' ); }
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
            -command => sub { ::spellmultiplelanguages( $textwindow, $top ); }
        ],
        [
            'command',
            'Spell ~Query...',
            -accelerator => 'Shift+F7',
            -command     => sub {
                ::errorcheckpop_up( $textwindow, $top, 'Spell Query' );
            }
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
            'Load Checkf~ile...',
            -command => sub {
                ::errorcheckpop_up( $textwindow, $top, 'Load Checkfile' );
            }
        ],
        [ 'separator', '' ],
        [ 'command',   '~Footnote Fixup...', -command => \&::footnotepop ],
        [ 'command',   '~Sidenote Fixup...', -command => \&::sidenotes ],
        [
            'command',
            'Replace [::] with I~ncremental Counter',
            -command => \&::replace_incr_counter
        ],
        menu_cascade( 'Con~vert Fractions', &menu_tools_convertfractions ),
        [ 'separator', '' ],
        [ 'command',   'Fixup ~Page Separators...', -command => \&::separatorpopup ],
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
        [ 'command', 'Search for ~Transliterations...', -command => \&::find_transliterations ],
        [ 'command', 'Common~ly-Used Characters Chart', -command => \&::commoncharspopup ],
        [ 'command', 'Unicode Character ~Entry',        -command => \&::utfcharentrypopup ],
        [ 'command', 'Unicode Character ~Search',       -command => \&::utfcharsearchpopup ],
        [
            'command', 'C~ompose Sequence',
            -accelerator => 'AltGr / Ctrl+m',
            -command     => \&::composepopup
        ],
        [ 'command',   '~Normalize Selected Characters', -command => \&::utfcharnormalize ],
        [ 'separator', '' ],
        [ 'command',   '~Greek Transliteration',     -command => \&::greekpopup ],
        [ 'command',   'Find and ~Convert Greek...', -command => \&::findandextractgreek ],
    ];
}

sub menu_tools_convertfractions {
    [
        [ 'command', 'Unicode fractions only', -command => sub { ::fractionconvert('unicode'); } ],
        [
            'command',
            'Unicode fractions or superscript/subscript',
            -command => sub { ::fractionconvert('mixed'); }
        ],
        [
            'command',
            'All to superscript/subscript',
            -command => sub { ::fractionconvert('supsub'); }
        ],
    ];
}

sub menu_txt {
    my ( $textwindow, $top ) = ( $::textwindow, $::top );
    [
        [ 'command',   "Txt Conversion ~Palette...", -command => sub { ::txt_convert_palette(); } ],
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
            -command => sub { ::text_convert_bold( $textwindow, $::bold_char ); }
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
        [
            'command', "Auto-Convert ~Options...", -command => sub { ::text_convert_options($top); }
        ],
        [
            'command', "Convert to Curly ~Quotes", -command => sub { ::text_quotes_convert(); }
        ],
        menu_cascade( 'Curly Quote Corrections', &menu_txt_curlycorrections ),
        [ 'separator', '' ],
        [
            'command',
            'Add a Thought Brea~k',
            -command => sub {
                ::text_thought_break($textwindow);
            }
        ],
        [ 'separator', '' ],
        [ 'command',   '~Small Caps to ALL CAPS',   -command => \&::text_uppercase_smallcaps ],
        [ 'command',   '~Remove Small Caps Markup', -command => \&::text_remove_smallcaps_markup ],
        [
            'command',
            '~Manually Convert Small Caps Markup...',
            -command => \&::txt_manual_sc_conversion
        ],
        [ 'separator', '' ],
        [
            'command',
            'Indent Selection ~1',
            -accelerator => "$::altkeyname\x{2192},Ctrl+m",
            -command     => sub {
                ::indent( $textwindow, 'in' );
            }
        ],
        [
            'command',
            'Indent Selection ~4',
            -accelerator => "Ctrl+$::altkeyname+m",
            -command     => sub {
                $textwindow->addGlobStart;
                ::indent( $textwindow, 'in' ) for ( 1 .. 4 );
                $textwindow->addGlobEnd;
            }
        ],
        [
            'command',
            'In~dent Selection -1',
            -accelerator => "$::altkeyname\x{2190},Ctrl+Shift+m",
            -command     => sub {
                ::indent( $textwindow, 'out' );
            }
        ],
        [ 'separator', '' ],
        [ 'command',   "~Center Selection",      -command => sub { ::rcaligntext( 'c', 0 ); } ],
        [ 'command',   "~Right-Align Selection", -command => sub { ::rcaligntext( 'r', 0 ); } ],
        [
            'command',
            "Right-Align ~Numbers in Selection",
            -command => sub { ::tocalignselection(0); }
        ],
        [ 'command',   'A~lign text on string...', -command => \&::alignpopup ],
        [ 'separator', '' ],
        [ 'command',   'Dra~w ASCII Boxes...',    -command => \&::asciibox_popup ],
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

sub menu_txt_curlycorrections {
    [
        [ 'command', '~Select Next @ Line', -command => sub { ::text_quotes_select(); } ],
        [ 'command', '~Flip Double Quotes', -command => sub { ::text_quotes_flipdouble(); } ],
        [
            'command',
            '~Use Spaces To Correct Double Quotes',
            -command => sub { ::text_quotes_usespaces(); }
        ],
        [
            'command',
            'Re~move @ Symbols From Selection',
            -command => sub { ::text_quotes_removeat(); }
        ],
        [ 'separator', '' ],
        [
            'command',
            'Select Ne~xt Straight Single Quote',
            -command => sub { ::text_straight_quote_select(); }
        ],
        [
            'command',
            'Convert to Left Single ~Quote and Select Next',
            -command =>
              sub { ::text_straight_quote_convert("\x{2018}"); ::text_straight_quote_select(); }
        ],
        [
            'command',
            'Convert to Right Single/~Apostrophe and Select Next',
            -command =>
              sub { ::text_straight_quote_convert("\x{2019}"); ::text_straight_quote_select(); }
        ],
        [ 'separator', '' ],
        [
            'command',
            'Insert ~Left Double Quote',
            -command => sub { ::text_quotes_insert("\x{201c}"); }
        ],
        [
            'command',
            'Insert ~Right Double Quote',
            -command => sub { ::text_quotes_insert("\x{201d}"); }
        ],
        [
            'command',
            'Insert L~eft Single Quote',
            -command => sub { ::text_quotes_insert("\x{2018}"); }
        ],
        [
            'command',
            'Insert R~ight Single Quote/Apostrophe',
            -command => sub { ::text_quotes_insert("\x{2019}"); }
        ],
    ];
}

sub menu_html {
    my ( $textwindow, $top ) = ( $::textwindow, $::top );
    [
        [
            'command',
            'HTML ~Generator...',
            -command => sub { ::htmlgenpopup( $textwindow, $top ); }
        ],
        [ 'command', 'HTML ~Markup...', -command => sub { ::htmlmarkpopup( $textwindow, $top ); } ],
        [ 'command', 'HTML Auto Inde~x (List)', -command => sub { ::autoindex($textwindow); } ],
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
            'N~u HTML Checker',
            -command => sub {
                ::errorcheckpop_up( $textwindow, $top, 'Nu HTML Check' );
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
            'Unclo~sed Tag Check',
            -command => sub {
                ::errorcheckpop_up( $textwindow, $top, 'HTML Tags' );
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
        [ 'separator', '' ],
        [
            'command', 'EB~ookMaker epub/mobi Generation', -command => sub { ::ebookmaker("epub"); }
        ],
        [
            'command',
            'W3C EPU~BCheck',
            -command => sub {
                ::errorcheckpop_up( $textwindow, $top, 'EPUBCheck' );
            }
        ],

        # Uncomment for option to generate HTML5 using ebookmaker - files are written to "out" subfolder
        # [
        # 'command', 'HTML~5 Generation', -command => sub { ::ebookmaker("html"); }
        # ],
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
                -command     =>
                  [ \&::utfpopup, $_, $::lglobal{utfblocks}{$_}[0], $::lglobal{utfblocks}{$_}[1] ],
                -accelerator => $::lglobal{utfblocks}{$_}[0] . ' - ' . $::lglobal{utfblocks}{$_}[1]
            ],
            ( sort menu_unicode_sort ( keys %{ $::lglobal{utfblocks} } ) ) ),
    ];
}

# Returns 1 if Unicode menu column break should be inserted at the given block name
sub menu_unicode_break {
    my $block = shift;
    if ( $::lglobal{utfrangesort} ) {
        return ( $block eq 'Malayalam' or $block eq 'Mathematical Operators' ) ? 1 : 0;
    } else {
        return ( $block eq 'Ethiopic' or $block eq 'Miscellaneous Technical' ) ? 1 : 0;
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
                ( $_ < 9                   ? '~'                  : '' )
                  . ( $_ == 9              ? '1~0'                : $_ + 1 ) . ": "
                  . ( $::extops[$_]{label} ? $::extops[$_]{label} : "" ),
                -command => [ \&::xtops, $_ ]
            ],
            ( 0 .. $#::extops ) ),
        [ 'separator', '' ],
        [ 'command',   'Set ~External Programs...', -command => \&::externalpopup ],
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
        [ 'command', 'Set DP ~URLs...',                  -command => \&::setDPurls, ],
        [ 'command', 'Copy ~Settings From A Release...', -command => \&::copysettings, ],
    ];
}

sub menu_preferences_appearance {
    my $textwindow = $::textwindow;
    [
        [ 'command',   'Set ~Fonts...', -command => \&::setfonts ],
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
        [
            Checkbutton => 'Keep Search/Replace Pop-up On Top',
            -variable   => \$::srstayontop,
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
            Checkbutton => 'Display Column Numbers',
            -variable   => \$::viscolnm,
            -onvalue    => 1,
            -offvalue   => 0,
            -command    => sub { ::displaycolnumbers($::viscolnm) },
        ],
        [
            Checkbutton => 'Auto Show Page Images',
            -variable   => \$::auto_show_images,
            -onvalue    => 1,
            -offvalue   => 0,
            -command    => sub { ::set_auto_img($::auto_show_images); },
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
                $::lglobal{checkcolor} = $::OS_WIN ? 'white' : $::activecolor;
                ::savesettings();
            }
        ],
        [
            'command',
            'Set Scanno/Quote Highlight Color...',
            -command => sub {
                my $thiscolor = ::setcolor($::highlightcolor);
                $::highlightcolor = $thiscolor if $thiscolor;
                $textwindow->tagConfigure( 'scannos',   -background => $::highlightcolor );
                $textwindow->tagConfigure( 'quotemark', -background => $::highlightcolor );
                ::savesettings();
            }
        ],
        [ 'separator', '' ],
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
            -command    => sub { ::toolbar_toggle(); },
            -value      => 'top'
        ],
        [
            Radiobutton => 'Toolbar on Bottom',
            -variable   => \$::toolside,
            -command    => sub { ::toolbar_toggle(); },
            -value      => 'bottom'
        ],
        [
            Radiobutton => 'Toolbar on Left',
            -variable   => \$::toolside,
            -command    => sub { ::toolbar_toggle(); },
            -value      => 'left'
        ],
        [
            Radiobutton => 'Toolbar on Right',
            -variable   => \$::toolside,
            -command    => sub { ::toolbar_toggle(); },
            -value      => 'right'
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
    ];
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
    ];
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
            'command',
            'Set Threshold Word Count for Marked Up Phrases...',
            -command => sub {
                ::ital_adjust();
            }
        ],
        [
            Checkbutton => "Include Two Words ('flash light') in WF Hyphen Check",
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
        [
            Checkbutton => 'Sticky Search Options',
            -variable   => \$::searchstickyoptions,
            -onvalue    => 1,
            -offvalue   => 0
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
            Checkbutton => "CSS Validation Level 2.1",
            -variable   => \$::cssvalidationlevel,
            -onvalue    => 'css21',
            -offvalue   => 'css3',
        ],
        [ 'command', 'Set Compose Key...', -command => sub { ::composekeypopup() } ],
        [
            Checkbutton => 'Allow px Sizes for HTML Images',
            -variable   => \$::htmlimageallowpixels,
            -onvalue    => 1,
            -offvalue   => 0
        ],
    ];
}

sub menu_help {
    my $top = $::top;
    [
        [
            'command',
            '~Manual [www]',
            -command => sub {
                ::launchurl('https://www.pgdp.net/wiki/PPTools/Guiguts/Guiguts_Manual');
            }
        ],
        [
            'command',
            'Guiguts ~Help on DP Forum [www]',
            -command => sub { ::launchurl('https://www.pgdp.net/phpBB3/viewtopic.php?t=11466'); }
        ],
        [ 'command', '~Keyboard Shortcuts',    -command => sub { ::display_manual("hotkeys"); } ],
        [ 'command', '~Regex Quick Reference', -command => sub { ::display_manual("regexref"); } ],
        [ 'command', '~Compose Sequences',     -command => \&::composeref ],
        [ 'command', 'Message ~Log',           -command => \&::poperror ],
        [ 'separator', '' ],
        [
            'command',
            'GG ~PP Process Checklist [www]',
            -command => sub {
                ::launchurl("https://www.pgdp.net/wiki/Guiguts_PP_Process_Checklist");
            }
        ],
        [ 'separator', '' ],
        [ 'command',   '~About Guiguts',     -command => sub { ::about_pop_up($top) } ],
        [ 'command',   'Software ~Versions', -command => [ \&::showversion ] ],
        [ 'command',   'Check for ~Updates', -command => sub { ::checkforupdates("now") } ],
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
    ];
}

#
# Show reduced menu when the text window is right-clicked
my $contextmenu;

sub showcontextmenu {
    ::scrolldismiss();    # Cancel any middle button/mouse wheel scrolling

    # Create the menu when it is first requested
    unless ($contextmenu) {
        $contextmenu =
          $::top->Menu( -menuitems => [ menu_edit_cutcopypaste(), [ 'separator', '' ], ] );
        $contextmenu->cascade(
            -label     => '~Bookmarks',
            -tearoff   => 1,
            -menuitems => menu_bookmarks(),
        );
    }

    # Convert mouse root xy to location in text widget and position insert cursor there
    # so that Paste & other operations get the right location
    # Can't call Text::SetCursor directly since it cancels any current text selection
    my ( $w, $x, $y ) = @_;
    my $wx  = $x - $w->rootx;
    my $wy  = $y - $w->rooty;
    my $pos = "\@$wx,$wy";
    $pos = 'end - 1 chars' if $w->compare( $pos, '==', 'end' );
    $w->markSet( 'insert', $pos );

    # Finally post the menu
    $contextmenu->post( $x, $y );
}

1;
