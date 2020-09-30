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

    runtesterrorcheck( "Bookloupe/Gutcheck", "textcheck.txt",   "blgcbaseline.txt" );
    runtesterrorcheck( "Jeebies",            "textcheck.txt",   "jeebiesbaseline.txt" );
    runtesterrorcheck( "pptxt",              "textcheck.txt",   "pptxtbaseline.txt" );
    runtesterrorcheck( "W3C Validate",       "errorcheck.html", "htmlvalidatebaseline.txt" );
    runtesterrorcheck( "HTML Tidy",          "errorcheck.html", "tidybaseline.txt" );
    runtesterrorcheck( "ppvimage",           "errorcheck.html", "ppvimagebaseline.txt" );
    runtesterrorcheck( "Link Check",         "errorcheck.html", "linkcheckline.txt" );
    runtesterrorcheck( "W3C Validate CSS",   "errorcheck.html", "cssvalidatebaseline.txt" );
    runtesterrorcheck( "pphtml",             "errorcheck.html", "pphtmlbaseline.txt" );

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

# Run an error check conversion test given the test type,
# input filename and baseline output filename
sub runtesterrorcheck {
    my $TESTTYPE      = shift;
    my $CHECKINFILE   = "tests/" . shift;
    my $CHECKBASEFILE = "tests/" . shift;

    my $textwindow = $::textwindow;
    my $top        = $::top;

    ok( 1 == do { ::openfile($CHECKINFILE); 1 }, "openfile on $CHECKINFILE" );

    my $lfname = $CHECKBASEFILE;
    $lfname =~ s/baseline//;
    open my $logfile, ">", $lfname
      or die "Unable to open $lfname for writing\n";

    binmode $logfile, ":encoding(UTF-8)";
    ::errorcheckpop_up( $textwindow, $top, $TESTTYPE );
    for ( $::lglobal{errorchecklistbox}->get( 0, 'end' ) ) {
        print $logfile "$_\n";
    }

    close $logfile;
    unlink $lfname
      if ok( File::Compare::compare_text( $lfname, $CHECKBASEFILE ) == 0, "$TESTTYPE successful" );
}

1;
