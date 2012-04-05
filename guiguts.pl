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

#use criticism 'gentle';
our $VERSION = '1.0.19';

# To debug use Devel::ptkdb perl -d:ptkdb guiguts.pl
our $debug = 1; # turn on to report debug messages. Do not commit with $debug on
use FindBin;
use lib $FindBin::Bin . "/lib";

#use Data::Dumper;
use Cwd;
use Encode;
use FileHandle;
use File::Basename;
use File::Spec::Functions qw(rel2abs);
use File::Spec::Functions qw(catfile);
use File::Spec::Functions qw(catdir);
use File::Copy;
use File::Compare;
use HTML::TokeParser;
use IPC::Open2;
use LWP::UserAgent;
use charnames();
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
### Custom Guiguts modules
use Guiguts::ASCIITables;
use Guiguts::ErrorCheck;
use Guiguts::FileMenu;
use Guiguts::Footnotes;
use Guiguts::Greek;
use Guiguts::Greekgifs;
use Guiguts::HelpMenu;
use Guiguts::Highlight;
use Guiguts::HTMLConvert;
use Guiguts::LineNumberText;
use Guiguts::MenuStructure;
use Guiguts::MultiLingual;
use Guiguts::PageNumbers;
use Guiguts::PageSeparators;
use Guiguts::Preferences;
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
my $no_proofer_url  = 'http://www.pgdp.net/phpBB2/privmsg.php?mode=post';
my $yes_proofer_url = 'http://www.pgdp.net/c/stats/members/mbr_list.php?uname=';
### Application Globals
our $OS_WIN = $^O =~ m{Win};
our $OS_MAC = $^O =~ m{darwin};
our $activecolor      = '#24baec';    #'#f2f818';
our $alpha_sort       = 'f';
our $auto_page_marks  = 1;
our $auto_show_images = 0;
our $autobackup       = 0;
our $autosave         = 0;
our $autosaveinterval = 5;
our $bkgcolor         = '#ffffff';
our $bkmkhl           = 0;
our $blocklmargin     = 5;
our $blockrmargin     = 72;
our $poetrylmargin    = 4;
our $blockwrap;
our $booklang      = 'en';
our $bold_char     = "=";
our $defaultindent = 0;
our $failedsearch  = 0;
our $fontname      = 'Courier New';
our $fontsize      = 10;
our $fontweight    = q{};
our $geometry2     = q{};
our $geometry3     = q{};
our $geometry;
our $globalaspellmode   = 'normal';
our $globalbrowserstart = $ENV{BROWSER};
if ( !$globalbrowserstart ) { $globalbrowserstart = 'xdg-open'; }
if ($::OS_WIN)              { $globalbrowserstart = 'start'; }
if ($OS_MAC)                { $globalbrowserstart = 'open'; }
our $globalfirefoxstart = 'firefox';
if ($OS_MAC) { $globalbrowserstart = 'open -a firefox'; }
our $defaultfilehandler = "$globalbrowserstart \$d\$f\$e";
our $globalimagepath        = q{};
our $globallastpath         = q{};
our $globalspelldictopt     = q{};
our $globalspellpath        = q{};
our $globalviewerpath       = q{};
our $globalprojectdirectory = q{};
our @gsopt;
our $htmldiventry   = ' class="i2"';
our $htmlspanentry  = ' class="i2"';
our $highlightcolor = '#a08dfc';
our $history_size   = 20;
our $italic_char    = "_";
our $ignoreversions =
  "revision";    #ignore revisions by default but not major or minor versions
our $ignoreversionnumber    = "";         #ignore a specific version
our $jeebiesmode            = 'p';
our $lastversioncheck       = time();
our $lastversionrun         = $VERSION;
our $lmargin                = 1;
our $markupthreshold        = 4;
our $nobell                 = 0;
our $donotcenterpagemarkers = 0;
our $nohighlights           = 0;
our $notoolbar              = 0;
our $intelligentWF          = 0;
our $operationinterrupt;
our $pngspath            = q{};
our $projectid           = q{};
our $regexpentry         = q();
our $rmargin             = 72;
our $rwhyphenspace       = 1;
our $scannos_highlighted = 0;
our $scannoslist         = q{wordlist/en-common.txt};
our $scannoslistpath     = q{wordlist};
our $scannospath         = q{};
our $scannosearch        = 0;
our $scrollupdatespd     = 40;
our $searchendindex      = 'end';
our $searchstartindex    = '1.0';
our $multiterm           = 0;
our $spellindexbkmrk     = q{};
our $stayontop           = 0;
our $suspectindex;
our $toolside           = 'bottom';
our $menulayout         = 'old'; 
our $twowordsinhyphencheck = 0;
our $utffontname        = 'Courier New';
our $utffontsize        = 14;
our $verboseerrorchecks = 0;
our $vislnnm            = 0;
our $w3cremote          = 0;
our $wfstayontop        = 0;

# These are set to the default Windows values in initialize()
our $gutcommand          = '';
our $jeebiescommand      = '';
our $tidycommand         = '';
our $validatecommand     = '';
our $validatecsscommand  = '';
our $gnutenbergdirectory = '';
our %gc;
our %jeeb;
our %pagenumbers;
our %projectdict;
our %proofers;
our %reghints = ();
our %scannoslist;
our %geometryhash;    #Geometry of windows in one hash.
$geometryhash{wfpop} = q{};
our @bookmarks = ( 0, 0, 0, 0, 0, 0 );
our @gcopt = ( 0, 0, 0, 0, 0, 0, 1, 0, 1 );
our @joinundolist;
our @joinredolist;
our @multidicts = ();
our @mygcview;
our @operations;
our %operationshash;    # New format {operation, time}
our @pageindex;
our @recentfile;
@recentfile = ('README.txt');
our @replace_history;
our @search_history;
our @sopt = ( 0, 0, 0, 0, 0 );    # default is not whole word search
our %htmllabels;
%htmllabels = (
  'footnote' => 'Footnote',
  'footnoteheading' => 'FOOTNOTES',
  'fnanchor' => 'FNanchor',
  'pagelbl' => 'Page',
  'pageno1' => '[Pg ',
  'pageno2' => ']',
);

our %convertcharsdisplay = qw(Æ AE Å A æ ae å a Ð TH ð th Þ TH þ th ß ss );
our %convertcharssort    = qw(Æ AE Å A æ ae å a Ð TH ð th Þ TH þ th ß ss);

our $convertcharssinglesearch  = "ÀÁÂÃàáâãÇçÐðÈÉÊËèéêëÌÍÎÏìíîïÒÓÔÕòóôõÑñÙÚÛÜùúûüÝÿý";
our $convertcharssinglereplace = "AAAAaaaaCcDdEEEEeeeeIIIIiiiiOOOOooooNnUUUUuuuuYyy";
our $convertcharsmultisearch;
our $convertcharsdisplaysearch;
our @extops = (
	{
		'label'   => 'Open current file in its default program',
		'command' => $defaultfilehandler
	},
	{
		'label'   => 'Open current file in Firefox',
		'command' => "$globalfirefoxstart \$d\$f\$e"
	},
	{
		'label' => "Websters 1913 (Specialist Online Dictionary)",
		'command' =>
"$globalbrowserstart http://www.specialist-online-dictionary.com/websters/headword_search.cgi?query=\$t"
	},
	{
		'label' => "Websters 1828 American Dictionary",
		'command' =>
		  "$globalbrowserstart http://www.1828-dictionary.com/d/word/\$t"
	},
	{
		'label'   => 'Onelook.com (several dictionaries)',
		'command' => "$globalbrowserstart http://www.onelook.com/?ls=a&w=\$t"
	},
	{
		'label'   => 'Shape Catcher (Unicode character finder)',
		'command' => "$globalbrowserstart http://shapecatcher.com/"
	},
	{
		'label'   => 'W3C Markup Validation Service',
		'command' => "$globalbrowserstart http://validator.w3.org/"
	},
	{
		'label' => 'W3C CSS Validation Service',
		'command' =>
"$globalbrowserstart http://jigsaw.w3.org/css-validator/#validate_by_upload"
	},
	{ 'label' => q{}, 'command' => q{} },
	{ 'label' => q{}, 'command' => q{} },
	{ 'label' => q{}, 'command' => q{} },
);

#All local global variables contained in one hash. # now global
our %lglobal;    # need to document each variable
if ( eval { require Text::LevenshteinXS } ) {
	$lglobal{LevenshteinXS} = 1;
}
if ( eval { require Image::Size; 1; } ) {
	$lglobal{ImageSize} = 1;
} else {
	$lglobal{ImageSize} = 0;
}
our $top;
our $icon;
our $text_frame;
our $counter_frame;
our $proofer_frame;
our $text_font;
our $textwindow;
our $menubar;
initialize();    # Initialize a bunch of vars that need it.

readlabels();
# Set up the custom menus
menurebuild();

# Set up the key bindings for the text widget
textbindings();
buildstatusbar();

# Load the icon into the window bar. Needs to happen late in the process
$top->Icon( -image => $icon );
$lglobal{hasfocus} = $textwindow;
toolbar_toggle();
$top->geometry($geometry) if $geometry;
( $lglobal{global_filename} ) = @ARGV;
die "ERROR: too many files specified. \n" if ( @ARGV > 1 );
if (    ( $lglobal{global_filename} )
	and ( $lglobal{global_filename} eq 'runtests' ) )
{
	$lglobal{runtests} = 1;
}
if (@ARGV) {
	$lglobal{global_filename} = shift @ARGV;
	if ( -e $lglobal{global_filename} ) {
		my $userfn = $lglobal{global_filename};
		$top->update;
		$lglobal{global_filename} = $userfn;
		openfile( $lglobal{global_filename} );
	}
} else {
	$lglobal{global_filename} = 'No File Loaded';
}
set_autosave() if $autosave;
$textwindow->CallNextGUICallback;
$top->repeat( 200, sub { _updatesel($textwindow) } );

# Ready to enter main loop
unless ( -e 'header.txt' ) {
	::copy( 'headerdefault.txt', 'header.txt' );
}
::checkforupdatesmonthly();

sub dofile {
	my $filename = shift;
	return do $filename;
}

sub evalstring {
	my $string = shift;
	return eval($string);
}

if ( $lglobal{runtests} ) {
	runtests();
} else {
	print
"If you have any problems, please report any error messages that appear here.\n";
	MainLoop;
}
