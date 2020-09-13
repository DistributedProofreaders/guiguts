package Guiguts::Tests;
use strict;
use warnings;

BEGIN {
    use Exporter();
    our ( @ISA, @EXPORT );
    @ISA    = qw(Exporter);
    @EXPORT = qw(&runtests);
}

# From the command line run "guiguts.pl runtests"
# Results will be reported to the command window
sub runtests {

    my $textwindow = $::textwindow;
    my $top        = $::top;

    use Test::More;

    #use File::Compare qw(compare_text);

    # Avoid tests being affected by user's settings
    if ( -e "setting.rc" ) {
        unlink 'setting.old';
        rename( "setting.rc", "setting.old" );
    }

    ok( 1 == 1, "Dummy test 1==1" );

    ok( ::roman(22) eq 'XXII', "roman(22)==XXII" );

    ok( ::arabic('XXII.') eq '22', "arabic(XXII.) eq '22'" );

    ok( not( ::arabic('XXII.') eq '23' ), "not arabic(XXII.) eq '23'" );

    ok(
        ::deaccentdisplay('ÀÁÂÃÄÅàáâãäåÇçÈÉÊËèéêëÌÍÎÏìíîïÒÓÔÕÖØòóôõöøÑñÙÚÛÜùúûüÝÿý') eq
          'AAAAAAaaaaaaCcEEEEeeeeIIIIiiiiOOOOOOooooooNnUUUUuuuuYyy',
        "deaccentdisplay('ÀÁÂÃÄÅàáâãäåÇçÈÉÊËèéêëÌÍÎÏìíîïÒÓÔÕÖØòóôõöøÑñÙÚÛÜùúûüÝÿý')"
    );

    ok( ( ::entity('\xff') eq '&yuml;' ), "entity('\\xff') eq '&yuml;'" );

    ok( $::debug == 0, "Do not release with \$debug = 1" );

    ok( 1 == do { 1 }, "do block" );

    ok( -e "tests/errorcheck.html", "tests/errorcheck.html exists" );

    ok( 1 == do { ::openfile("tests/errorcheck.html"); 1 }, "openfile on tests/errorcheck.html" );

    # Test of all HTML checks
    ::errorcheckpop_up( $textwindow, $top, 'Check All' );
    my $LFNAME = "tests/errorcheckresults.txt";
    open my $logfile, ">", $LFNAME
      or die "Unable to open $LFNAME for writing\n";
    for ( $::lglobal{errorchecklistbox}->get( 0, 'end' ) ) {
        print $logfile "$_\n";
    }
    close $logfile;
    unlink $LFNAME
      if ok( File::Compare::compare_text( $LFNAME, 'tests/errorcheckbaseline.txt' ) == 0,
        "Check All successful" );

    # Open/close README - allow for development system run from src subdirectory
    ok( ( -e "../README.md" or -e "README.md" ), "README.md exists" );

    my $READMEFILE = ( -e "../README.md" ? "../README.md" : "README.md" );
    ok( 1 == do { ::openfile($READMEFILE); 1 }, "openfile on $READMEFILE" );

    ok( $READMEFILE eq $textwindow->FileName, "File is named $READMEFILE" );

    ok( 1 == do { ::file_close($textwindow); 1 }, "close $READMEFILE" );

    # Test of rewrapping
    my $WRAPINFILE   = "tests/testfile.txt";
    my $WRAPOUTFILE  = "tests/testfilewrapped.txt";
    my $WRAPBASEFILE = "tests/testfilebaseline.txt";
    ok( -e $WRAPINFILE, "$WRAPINFILE exists" );

    ok( 1 == do { ::openfile($WRAPINFILE); 1 }, "openfile on $WRAPINFILE" );

    ok( 1 == do { $textwindow->selectAll; 1 }, "Select All" );

    ok(
        1 == do {
            ::selectrewrap( $textwindow, $::lglobal{seepagenums},
                $::scannos_highlighted, $::rwhyphenspace );
            1;
        },
        "Rewrap Selection"
    );

    ok( 1 == do { $textwindow->SaveUTF($WRAPOUTFILE); ::setedited(0); 1 },
        "File saved as $WRAPOUTFILE" );

    ok( -e $WRAPOUTFILE, "$WRAPOUTFILE was saved" );

    ok( -e $WRAPBASEFILE, "$WRAPBASEFILE exists" );

    unlink $WRAPOUTFILE
      if ok( File::Compare::compare_text( $WRAPBASEFILE, $WRAPOUTFILE ) == 0,
        "Rewrap was successful" );

    runtesthtml(1);
    runtesthtml(2);
    runtesthtml(3);
    runtesthtml(4);
    runtesthtml(5);

    ok( 1 == 1, "This is the last test" );

    done_testing();

    # Restore user's settings
    if ( -e "setting.old" ) {
        unlink 'setting.rc';
        rename( "setting.old", "setting.rc" );
    }

    exit;
}

# Run an HTML conversion test with filenames determined by input argument
sub runtesthtml {
    my $number       = shift;
    my $HTMLINFILE   = "tests/testhtml${number}.txt";
    my $HTMLOUTFILE  = "tests/testhtml${number}.html";
    my $HTMLBASEFILE = "tests/testhtml${number}baseline.html";
    my $HTMLBAKFILE  = "tests/testhtml${number}-htmlbak.txt";

    my $textwindow = $::textwindow;
    my $top        = $::top;

    ok( 1 == do { ::openfile($HTMLINFILE); 1 }, "openfile on $HTMLINFILE" );

    ok( 1 == do { ::htmlautoconvert( $textwindow, $top ); 1 }, "HTML convert on $HTMLINFILE" );

    # Remove CSS header before saving
    my $bodystart = $textwindow->search( '--', '<body>', '1.0', 'end' );
    ok( $bodystart, "Found start of body in $HTMLOUTFILE" );

    $textwindow->delete( '1.0', $bodystart );
    ok( 1 == do { $textwindow->SaveUTF($HTMLOUTFILE); ::setedited(0); 1 },
        "File saved as $HTMLOUTFILE" );

    ok( -e $HTMLOUTFILE, "$HTMLOUTFILE was saved" );

    ok( -e $HTMLBASEFILE, "$HTMLBASEFILE exists" );

    unlink $HTMLOUTFILE
      if ok( File::Compare::compare_text( $HTMLBASEFILE, $HTMLOUTFILE ) == 0,
        "Autogenerate HTML successful" );

    # Delete backup files created during HTML generation
    unlink $HTMLBAKFILE;
    unlink "$HTMLBAKFILE.bin";
}

1;
