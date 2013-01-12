package Guiguts::Tests;
use strict;
use warnings;

BEGIN {
	use Exporter();
	our ( @ISA, @EXPORT );
	@ISA    = qw(Exporter);
	@EXPORT = qw(&runtests);
}

sub runtests {

	# From the command line run "guiguts.pl runtests"
	my $textwindow = $::textwindow;
	my $top        = $::top;
	use Test::More;    #tests => 34;
	ok( 1 == 1, "Dummy test 1==1" );

	#if ( -e "setting.rc" ) { rename( "setting.rc", "setting.old" ); }
	ok( ::roman(22)       eq 'XXII',  "roman(22)==XXII" );
	ok( ::arabic('XXII.') eq '22',    "arabic(XXII.) eq '22'" );
	ok( not( ::arabic('XXII.') eq '23' ), "not arabic(XXII.) eq '23'" );
	my $ln;
	my @book   = ();
	my $inbody = 0;
	$::lglobal{pageanch} = 1;
	$::lglobal{pagecmt}  = 0;
	ok( 1 == do { 1 }, "do block" );
	my $logfile;
	if ($::OS_WIN) {
		ok( -e "tests/errorcheck.html", "tests/errorcheck.html exists" );
		ok( 1 == do { ::openfile("tests/errorcheck.html"); 1 },
			"openfile on tests/errorcheck.html" );
		::errorcheckpop_up( $textwindow, $top, 'Check All' );
		open $logfile, ">", "tests/errors.err" || die "output file error\n";
		print $logfile $::lglobal{errorchecklistbox}->get( '1.0', 'end' );
		close $logfile;
		ok(
			::compare( "tests/errors.err", 'tests/errorcheckbaseline.txt' ) ==
			  0,
			"Check All was successful"
		);
		print "begin diff\n";
		system "diff tests/errorcheckbaseline.txt tests/errors.err";
		print "end diff\n";
		unlink 'tests/errors.err';
	}
	ok( 1 == do { ::openfile("README.txt"); 1 }, "openfile on README.txt" );
	ok( "README.txt" eq $textwindow->FileName, "File is named README.txt" );
	ok( 1 == do { ::file_close($textwindow); 1 }, "close README.txt" );

	# Test of rewrapping
	ok( -e "tests/testfile.txt", "tests/testfile.txt exists" );
	ok( 1 == do { ::openfile("tests/testfile.txt"); 1 },
		"openfile on tests/testfile.txt" );
	ok( 1 == do { $textwindow->selectAll; 1 }, "Select All" );
	ok(
		1 == do {
			::selectrewrap( $textwindow, $::lglobal{seepagenums},
				$::scannos_highlighted, $::rwhyphenspace );
			1;
		},
		"Rewrap Selection"
	);
	ok( 1 == do { $textwindow->SaveUTF('tests/testfilewrapped.txt'); 1 },
		"File saved as tests/testfilewrapped" );
	ok( -e 'tests/testfilewrapped.txt', "tests/testfilewrapped.txt was saved" );
	ok( -e "tests/testfilebaseline.txt", "tests/testfilebaseline.txt exists" );
	ok(
		::compare( "tests/testfilebaseline.txt", 'tests/testfilewrapped.txt' )
		  == 0,
		"Rewrap was successful"
	);
	print "begin diff\n";
	system "diff tests/testfilebaseline.txt tests/testfilewrapped.txt";
	print "end diff\n";
	unlink 'tests/testfilewrapped.txt';
	ok( not( -e "tests/testfilewrapped.txt" ),
		"Deletion confirmed of tests/testfilewrapped.txt" );
	unlink 'setting.rc';
	if ( -e "setting.old" ) { rename( "setting.old", "setting.rc" ); }

	# Test 1 of HTML generation
	ok( 1 == do { ::openfile("tests/testhtml1.txt"); 1 },
		"openfile on tests/testhtml1.txt" );
	ok( 1 == do { ::htmlautoconvert( $textwindow, $top ); 1 },
		"openfile on tests/testhtml1.txt" );
	ok( 1 == do { $textwindow->SaveUTF('tests/testhtml1.html'); 1 },
		"test of file save as tests/testfilewrapped" );
	ok( -e 'tests/testhtml1.html', "tests/testhtml1.html was saved" );
	ok(
		-e "tests/testhtml1baseline.html",
		"tests/testhtml1baseline.html exists"
	);
	open my $infile, "<", "tests/testhtml1.html" || die "no source file\n";
	open $logfile, ">", "tests/testhtml1temp.html" || die "output file error\n";

	while ( $ln = <$infile> ) {
		if ($inbody) { print $logfile $ln; }
		if ( $ln =~ /<\/head>/ ) {
			$inbody = 1;
		}
	}
	close $infile;
	close $logfile;
	ok(
		::compare( "tests/testhtml1baseline.html", 'tests/testhtml1temp.html' )
		  == 0,
		"Autogenerate HTML successful"
	);
	print "begin diff\n";
	system "diff tests/testhtml1baseline.html tests/testhtml1temp.html";
	print "end diff\n";
	unlink 'tests/testhtml1.html';
	unlink 'tests/testhtml1temp.html';
	unlink 'tests/testhtml1-htmlbak.txt';
	unlink 'tests/testhtml1-htmlbak.txt.bin';
	ok( not( -e "tests/testhtml1temp.html" ),
		"Deletion confirmed of tests/testhtml1temp.html" );
	ok( not( -e "tests/testhtml1.html" ),
		"Deletion confirmed of tests/testhtml1.html" );

	# Test 2 of HTML generation
	ok( 1 == do { ::openfile("tests/testhtml2.txt"); 1 },
		"openfile on tests/testhtml2.txt" );
	ok( 1 == do { ::htmlautoconvert( $textwindow, $top ); 1 },
		"openfile on tests/testhtml2.txt" );
	ok( 1 == do { $textwindow->SaveUTF('tests/testhtml2.html'); 1 },
		"test of file save as tests/testfilewrapped" );
	ok( -e 'tests/testhtml2.html', "tests/testhtml2.html was saved" );
	ok(
		-e "tests/testhtml2baseline.html",
		"tests/testhtml2baseline.html exists"
	);
	open $infile,  "<", "tests/testhtml2.html"     || die "no source file\n";
	open $logfile, ">", "tests/testhtml2temp.html" || die "output file error\n";
	@book   = ();
	$inbody = 0;

	while ( $ln = <$infile> ) {
		if ($inbody) { print $logfile $ln; }
		if ( $ln =~ /<\/head>/ ) {
			$inbody = 1;
		}
	}
	close $infile;
	close $logfile;
	ok(
		::compare( "tests/testhtml2baseline.html", 'tests/testhtml2temp.html' )
		  == 0,
		"Autogenerate HTML successful"
	);
	print "begin diff\n";
	system "diff tests/testhtml2baseline.html tests/testhtml2temp.html";
	print "end diff\n";
	unlink 'tests/testhtml2.html';
	unlink 'tests/testhtml2temp.html';
	unlink 'tests/testhtml2-htmlbak.txt';
	unlink 'tests/testhtml2-htmlbak.txt.bin';
	ok( not( -e "tests/testhtml2temp.html" ),
		"Deletion confirmed of tests/testhtml2temp.html" );
	ok( not( -e "tests/testhtml2.html" ),
		"Deletion confirmed of tests/testhtml2.html" );
	unlink 'null' if ( -e 'null' );

	#	fnview();
	#htmlimage();
##errorcheckpop_up($textwindow,$top,'test');
	#gcheckpop_up();
	#harmonicspop();
	#pnumadjust();
	#searchpopup();
	#asciipopup();
	#alignpopup();
	#wordfrequency();
	#jeebiespop_up();
	#separatorpopup();
	#footnotepop();
	#externalpopup();
	#utfpopup();
	#about_pop_up();
	#opspop_up();
	#greekpopup();
	ok( $::debug == 0, "Do not release with \$debug = 1" );
	ok(
		::deaccentdisplay(
'ÀÁÂÃÄÅàáâãäåÇçÈÉÊËèéêëÌÍÎÏìíîïÒÓÔÕÖØòóôõöøÑñÙÚÛÜùúûüİÿı'
		  ) eq 'AAAAAAaaaaaaCcEEEEeeeeIIIIiiiiOOOOOOooooooNnUUUUuuuuYyy',
"deaccentdisplay('ÀÁÂÃÄÅàáâãäåÇçÈÉÊËèéêëÌÍÎÏìíîïÒÓÔÕÖØòóôõöøÑñÙÚÛÜùúûüİÿı')"
	);
	ok( ( ::entity('\xff') eq '&yuml;' ), "entity('\\xff') eq '&yuml;'" );
	ok( $::debug == 0, "Do not release with \$debug = 1" );
	ok( 1 == 1,        "This is the last test" );
	done_testing();
	exit;
}
1;
