#!/usr/bin/perl
# $Id: guiguts.pl 1195 2012-03-27 03:36:48Z hmonroe $
# GuiGuts text editor
#This program is free software; you can redistribute it and/or
#modify it under the terms of the GNU General Public License
#as published by the Free Software Foundation; either version 2
#of the License, or (at your option) any later version.
#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.
#You should have received a copy of the GNU General Public License
#along with this program; if not, write to the Free Software
#Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
use strict;
use warnings;

use lib '.';

#use criticism 'gentle';
our $VERSION = '1.4.0';

# DON'T FORGET to update the version number in makefile too

use FindBin;
use lib $FindBin::Bin . "/lib";

#use Data::Dumper;
use charnames();
use Cwd;
use Encode;
use FileHandle;
use File::Basename;
use File::Spec::Functions qw(rel2abs);
use File::Spec::Functions qw(catfile);
use File::Spec::Functions qw(catdir);
use File::Copy;
use File::Compare;
use File::Which;
use HTML::Entities;
use HTML::TokeParser;
use Image::Size;
use IPC::Open2;
use LWP::UserAgent;
use Text::LevenshteinXS;
use Tk;
use Tk::widgets qw{Balloon
  BrowseEntry
  Checkbutton
  Dialog
  DialogBox
  DropSite
  Font
  JPEG
  LabFrame
  Listbox
  PNG
  Pane
  Photo
  ProgressBar
  Radiobutton
  TextEdit
  ToolBar
};

our $APP_NAME     = 'Guiguts';
our $window_title = $APP_NAME . '-' . $VERSION;
our $icondata;
our $OS_WIN = $^O =~ m{Win};
our $OS_MAC = $^O =~ m{darwin};

### Custom Guiguts modules
use Guiguts::ASCIITables;
use Guiguts::ErrorCheck;
use Guiguts::FileMenu;
use Guiguts::Footnotes;
use Guiguts::Greek;
use Guiguts::HelpMenu;
use Guiguts::Highlight;
use Guiguts::HTMLConvert;
use Guiguts::KeyBindings;
use Guiguts::LineNumberText;
use Guiguts::MenuStructure;
use Guiguts::MultiLingual;
use Guiguts::PageNumbers;
use Guiguts::PageSeparators;
use Guiguts::Preferences;
use Guiguts::ReflowGG;
use Guiguts::SearchReplaceMenu;
use Guiguts::SelectionMenu;
use Guiguts::SpellCheck;
use Guiguts::StatusBar;
use Guiguts::Tests;
use Guiguts::TextProcessingMenu;
use Guiguts::TextUnicode;
use Guiguts::CharacterTools;
use Guiguts::Utilities;
use Guiguts::WordFrequency;

### Constants
our $allblocktypes        = quotemeta '#$*FfIiLlPpXxCcRr';
our $urlprojectpage       = 'https://www.pgdp.net/c/project.php?id=';
our $urlprojectdiscussion = 'https://www.pgdp.net/c/tools/proofers/project_topic.php?project=';

### Application Globals
our $activecolor      = '#24baec';                      #'#f2f818';
our $alpha_sort       = 'f';
our $altkey           = $OS_MAC ? "Meta"    : "Alt";    # Alt key used in binding routine calls
our $altkeyname       = $OS_MAC ? "Command" : "Alt";    # Name of Alt key for display to user
our $auto_page_marks  = 1;
our $auto_show_images = 0;
our $autobackup       = 0;
our $autosave         = 0;
our $autosaveinterval = 5;
our $bkgcolor         = '#ffffff';
our $bkmkhl           = 0;
our $blocklmargin     = 1;
our $blockrmargin     = 72;
our $poetrylmargin    = 4;
our $blockwrap;
our $booklang             = 'en';
our $charsuitewfhighlight = 0;                  # Don't do charsuite availability highlighting in WF dialog
our $composepopbinding    = 'Alt_R';            # Default key to pop the Compose dialog (Right hand Alt key, also labelled AltGr)
$composepopbinding = 'Control-m' if $OS_MAC;    # Default to Ctrl+m on a Mac - Alt+RightArrow does the same indent operation
our %composehash;                               # Keystrokes to insert character
our %composehelp;                               # Optional help text to identify character
our $cssvalidationlevel  = 'css3';              # CSS level checked by validator (css3 or css21)
our $defaultindent       = 2;
our $epubpercentoverride = 1;                   # True = override % img widths to 100% for epubs
our $failedsearch        = 0;
our $fontname            = 'Courier New';
our $fontsize            = 10;
our $fontweight          = 'normal';
our $geometry;
our $gblfontname        = 'Helvetica';
our $gblfontsize        = 10;
our $gblfontweight      = 'normal';
our $gblfontsystemuse   = 1;                    # Default to use system font
our $globalaspellmode   = 'normal';
our $globalbrowserstart = $ENV{BROWSER};
if ( !$globalbrowserstart ) { $globalbrowserstart = 'xdg-open'; }
if ($OS_WIN)                { $globalbrowserstart = 'start'; }
if ($OS_MAC)                { $globalbrowserstart = 'open'; }
our $globalimagepath        = q{};
our $globallastpath         = q{};
our $globalspelldictopt     = q{};
our $globalspellpath        = q{};
our $globalviewerpath       = q{};
our $globalprojectdirectory = q{};
our @gsopt;
our $highlightcolor         = '#a08dfc';
our $history_size           = 20;
our $htmlimageallowpixels   = 0;                           # Don't allow user to specify image size in pixels by default
our $htmlimagewidthtype     = '%';                         # Default to specifying image size by percentage
our $ignoreversions         = "none";                      # Don't ignore any updates by default
our $ignoreversionnumber    = "";                          # Ignore a specific version
our $jeebiesmode            = 'p';
our $lastversioncheck       = time();
our $lastversionrun         = $VERSION;
our $lmargin                = 0;
our $markupthreshold        = 4;
our $multisearchsize        = 3;
our $nobell                 = 0;
our $donotcenterpagemarkers = 0;
our $nohighlights           = 0;
our $notoolbar              = 0;
our $pagesepauto            = 3;                           # How automatically to fix page separators
our $intelligentWF          = 0;
our $defaultpngspath        = ::os_normal('pngs/');
our $pngspath               = q{};
our $projectid              = q{};
our $projectfileslocation   = '';
our $recentfile_size        = 9;
our $regexpentry            = q();
our $rmargin                = 72;
our $rmargindiff            = 1;
our $rwhyphenspace          = 1;
our $scannos_highlighted    = 0;
our $scannoslist            = q{wordlist/en-common.txt};
our $scannoslistpath        = q{wordlist};
our $scannospath            = q{};
our $scannosearch           = 0;
our $scrollupdatespd        = 40;
our $searchendindex         = 'end';
our $searchstartindex       = '1.0';
our $searchstickyoptions    = 1;
our $multiterm              = 0;
our $spellcheckwithenchant  = 0;
our $spellindexbkmrk        = q{};
our $spellquerythreshold    = 3;
our $stayontop              = 0;
our $suspectindex;
our $toolside              = 'bottom';
our $trackoperations       = 0;               # Default to off (tracking triggers edited flag)
our $txtfontname           = 'Courier New';
our $txtfontsize           = 10;
our $txtfontweight         = 'normal';
our $txtfontsystemuse      = 1;               # Default to use system font
our $twowordsinhyphencheck = 0;
our $utfcharentrybase      = 'dec';           # 'dec' or 'hex' allowed
our $utffontname           = 'Courier New';
our $utffontsize           = 14;
our $utffontweight         = 'normal';
our $verboseerrorchecks    = 0;
our $vislnnm               = 0;
our $wfstayontop           = 0;

# These are set to the default values in initialize()
our $gutcommand         = '';
our $jeebiescommand     = '';
our $tidycommand        = '';
our $validatecommand    = '';
our $validatecsscommand = '';
our $ebookmakercommand  = '';
our $kindlegencommand   = '';
our %charsuiteenabled   = ( 'Basic Latin' => 1 );    # All projects allow Basic Latin character suite
our %pagenumbers;
our %projectdict;
our %reghints = ();
our %scannoslist;
our %geometryhash;                                   #Geometry of some windows in one hash.
$geometryhash{wfpop} = q{};
our %positionhash;                                   #Position of other windows in one hash.
our %manualhash;                                     # subpage of manual for each dialog
our @bookmarks  = ( 0, 0, 0, 0, 0, 0 );
our @multidicts = ();
our @mygcview;
our %operationshash;                                 # New format {operation, time}
our @pageindex;
our @recentfile;
@recentfile = ('README.md');
our @replace_history;
our @search_history;
our @sopt = ( 0, 0, 0, 0, 0 );                       # default is not whole word search
our @wfsearchopt;
our @userchars;                                      # user defined chars for common characters dialog

# html markup dialog
our @htmlentry = ('') x 4;                           # class/attributes for each div, span, i button
our @htmlentryhistory;                               # single shared history list htmlentry
our %htmlentryattribhash;                            # class/attributes for each element button

our %htmllabels;
our %convertcharsdisplay;
our %convertcharssort;
our $convertcharssinglesearch;
our $convertcharssinglereplace;
our $convertcharsmultisearch;
our $convertcharsdisplaysearch;

our (
    $txt_conv_bold, $txt_conv_italic, $txt_conv_gesperrt,
    $txt_conv_font, $txt_conv_sc,     $txt_conv_tb
) = ( 1, 1, 0, 0, 0, 1 );
our ( $bold_char, $italic_char, $gesperrt_char, $font_char, $sc_char ) =
  ( '=', '_', '~', '=', '+' );

our @extops = (
    {
        'label'   => 'View in browser',
        'command' => "$globalbrowserstart \"\$d\$f\$e\""
    },
    {
        'label'   => 'Onelook.com (several dictionaries)',
        'command' => "$globalbrowserstart https://www.onelook.com/?w=\$t"
    },
    {
        'label'   => 'Google Books Ngram Viewer',
        'command' => "$globalbrowserstart https://books.google.com/ngrams/graph?content=\$t"
    },
    {
        'label'   => 'Shape Catcher (Unicode character finder)',
        'command' => "$globalbrowserstart https://shapecatcher.com/"
    },
    {
        'label'   => 'W3C HTML Validation Service',
        'command' => "$globalbrowserstart https://validator.w3.org/#validate_by_upload+with_options"
    },
    {
        'label'   => 'W3C CSS Validation Service',
        'command' =>
          "$globalbrowserstart https://jigsaw.w3.org/css-validator/#validate_by_upload+with_options"
    },
    {
        'label'   => 'EBookMaker Online',
        'command' => "$globalbrowserstart https://ebookmaker.pglaf.org/"
    },
    {
        'label'   => 'Post-Processing Workbench',
        'command' => "$globalbrowserstart https://www.pgdp.net/ppwb/"
    },
);

# All local global variables contained in one global hash.
our %lglobal;    # need to document each variable

our $top;
our $icon;
our $text_frame;
our $counter_frame;
our $text_font;
our $textwindow;
our $menubar;

# End of declarations - start of code

# Override handling of die and warn to display errors via user interface

# Redirect die in recommended way so it doesn't catch compilation errors.
# Note that where die is used as a result of a Tk action such as a button
# or key press, it will abort the action rather than the whole program
# and will use warnerror below not dieerror.
BEGIN { *CORE::GLOBAL::die = \&::dieerror }

# Redirect warn by overriding signal handler
local $SIG{__WARN__} = \&::warnerror;

# An alternative for catching Tk background errors,
# but they are caught by the warn override above
# sub Tk::Error {
#     my($w, $error, @msgs) = @_;
#     warnerror($error);
#     warnerror($_) for @msgs;
# }

# Process command-line arguments before calling initialize().
processcommandline();

initialize();    # Initialize a bunch of vars that need it.

# Set up language-dependent labels and sorting (default English)
readlabels();

# Set up the custom menus
menurebuild();

# Set up the key bindings for the text widget
keybindings();
buildstatusbar();

# Load the icon into the window bar. Needs to happen late in the process
$top->Icon( -image => $icon );
$lglobal{hasfocus} = $textwindow;
$textwindow->focus;
toolbar_toggle();
$top->geometry($geometry) if $geometry;

# Non-filename args were handled by Getopt::Long. If anything
# is still in @ARGV it should be a filename or file position
# reference (01, 02, etc.). A limit of 1 argument applies now.
die "ERROR: too many files specified. \n" if ( @ARGV > 1 );

if (@ARGV) {
    $lglobal{global_filename} = shift @ARGV;
    if ( $lglobal{global_filename} =~ /^0(\d)$/ ) {
        $lglobal{global_filename} = $::recentfile[ $1 - 1 ];
    }
    if ( -e $lglobal{global_filename} ) {
        my $userfn = $lglobal{global_filename};
        $top->update;
        $lglobal{global_filename} = $userfn;
        openfile( $lglobal{global_filename} );
    }
} else {
    $lglobal{global_filename} = 'No File Loaded';
}
::reset_autosave();
$textwindow->CallNextGUICallback;
$top->repeat( 200, sub { _updatesel($textwindow) } );

# Ready to enter main loop
unless ( -e ::path_htmlheader() ) {
    ::copy( ::path_defaulthtmlheader(), ::path_htmlheader() );
}
::checkforupdatesmonthly();

if ( $lglobal{runtests} ) {
    runtests();
} else {
    ::infoerror(
        "Guiguts $VERSION: If you have any problems, please include any error messages that appear here with your bug report.\n"
    );
    MainLoop;
}

#
# "do" setting.rc, bin file, etc.
# Routine is in guiguts.pl because the files assume the global variables being set are in local scope,
# e.g. "$alpha_sort = 'a';" rather than "$::alpha_sort = 'a';"
sub dofile {
    my $filename = shift;
    return do $filename;
}

#
# "eval" string from exported .gut file, etc.
# Routine is in guiguts.pl because the files assume some global variables being set are in local scope,
# e.g. "$scannoslistpath = 'wordlist';" rather than "$::scannoslistpath = 'wordlist';"
sub evalstring {
    my $string = shift;
    return eval($string);
}
