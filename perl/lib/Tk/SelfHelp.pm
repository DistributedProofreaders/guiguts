package Tk::SelfHelp;
$VERSION = 1.3;
use vars qw( $VERSION );

@ISA=qw{Exporter};
use vars qw( @ISA @EXPORT @EXPORT_OK );
@EXPORT=qw(self_help);

use Tk;
use Tk::MainWindow;
use Tk::Button;

my $defaulttextfont="*-courier-medium-r-*-*-12-*";
my $menufont="*-helvetica-medium-r-*-*-12-*";

sub self_help {
    my ($appfilename) = @_;
    my $help_text;
    my $helpwindow;
    my $textwidget;

    open( HELP, ("pod2text < $appfilename |") ) or $help_text = 
"Unable to process help text for $appfilename."; 
    while (<HELP>) {
	$help_text .= $_;
    }
    close( HELP );

    $helpwindow = new MainWindow( -title => "$appfilename Help" );
    my $textframe = $helpwindow -> Frame( -container => 0, 
					  -borderwidth => 1 ) -> pack;
    my $buttonframe = $helpwindow -> Frame( -container => 0, 
					  -borderwidth => 1 ) -> pack;
    $textwidget = $textframe  
	-> Scrolled( 'Text', 
		     -font => $defaulttextfont,
		     -scrollbars => 'e' ) -> pack( -fill => 'both',
						   -expand => 1 );
    $textwidget -> insert( 'end', $help_text );

    $buttonframe -> Button( -text => 'Close',
			    -font => $menufont,
			    -command => sub{$helpwindow -> DESTROY} ) ->
				pack;
}

1;
