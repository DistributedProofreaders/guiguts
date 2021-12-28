#!/usr/bin/perl -w

use strict;
use File::Basename;
use File::Spec;
use Getopt::Long;
use Tk;

# ppvimage.pl
# author: David Wilson (DP: dcwilson) adapting ppvhtml.pl written by Roger Frank (DP:rfrank)
#         and incorporating code freely available on the web
#             (see acknowledgements within individual subs)
# thanks: Hanne for enhancement suggestions and integration with GuiGuts
#
# Note: all searches in strings are for ascii stuff, so there is no
#       need to deal with the input file encoding. Any unicode in alts
#       or titles etc will simply pass through as-is to the logfile.
#
# last edit: 29/July/2020

my $vnum = "1.07";

my @book      = ();
my @css       = ();
my @imagelist = ();
my $srctext;
my $makeCSV      = 0;
my $gg           = 0;
my $terse        = 0;
my $outfile      = "";
my $imgcover     = "";
my $imgcoverline = 0;
my $errline      = 0;
my $howbig       = 0;    # for switching definition of "large" between inline and linked images
my $option       = "";

use constant NOLINEINDENT => '           ';

use constant MAXKBINLINE => 256;     # Maximum size of an inline image in KB
use constant MAXKBLINKED => 1024;    # Maximum size of a linked image in KB
use constant MINCOVERWD  => 650;     # Minimum width of cover image
use constant MINCOVERHT  => 1000;    # Minimum height of cover image

# allow commandline operation sans GUI (thanks Katt83)
# perl -w ppvimage.pl [-csv] [-terse] [-gg] [-o logfile.txt] filename.html
if ( $#ARGV >= 0 ) {    # skip the gui
    if ( $ARGV[0] eq '-h' ) {    # print help
        print "perl -w ppvimage.pl [-csv] [-terse] [-gg] [-o logfile.txt] filename.html\n";
        print "The optional -csv argument produces an additional output file in CSV format\n";
        print "The optional -terse argument suppresses informational output\n";
        print
          "The optional -gg argument prepends GuiGuts-style source line numbers to every line of output\n";
        print "The optional -o argument allows you to specify the name of the output file\n";
    } else {                     # process arguments
        $srctext = $ARGV[$#ARGV];
        pop(@ARGV);
        while ( $#ARGV >= 0 ) {
            $option = shift(@ARGV);
            if    ( $option eq '-csv' )   { $makeCSV = 1; }
            elsif ( $option eq '-gg' )    { $gg      = 1; }
            elsif ( $option eq '-terse' ) { $terse   = 1; }
            elsif ( $option eq '-o' )     { $outfile = shift(@ARGV); }
        }
        runProgram();
    }
    exit;
}

# gui interface
# Main Window
my $mw = new MainWindow;

my $filename;
my $outfilename = "ppvimage.log";
my $imgfile;
my $src;
my ( $x, $y ) = ( 0, 0 );
my $wd;
my $ht;

my $label1 = $mw->Label(
    -text       => "ppvimage.pl post processing verification image checker.",
    -background => "#eeeeee",
    -font       => [ -weight => 'bold', -size => 11 ]
);
my $label3 = $mw->Label(
    -textvariable => \$outfilename,
    -relief       => 'sunken',
    -background   => "#eeeeee",
    -font         => [ -weight => 'bold', -size => 10 ]
);

my $button1 = $mw->Button(
    -text    => "Load",
    -command => \&loadFile,
    -font    => [ -weight => 'bold', -size => 10 ],
    -width   => 10
);
my $button2 = $mw->Button(
    -text    => "Run",
    -command => \&runProgram,
    -font    => [ -weight => 'bold', -size => 10 ]
);
my $button3 = $mw->Button(
    -text    => "Quit",
    -command => \&exitProgram,
    -font    => [ -weight => 'bold', -size => 10 ],
    -width   => 10
);

my $txt = $mw->Scrolled( 'Text', -scrollbars => "oe", -width => 80, -height => 30 );

$txt->insert( 'end', "This program will test the <img> tags in an HTML file.\n" );
$txt->insert( 'end', "First, click the Load button to load your .htm or .html file.\n" );

$label1->grid( -row => 0, -column => 0, -columnspan => 3, -sticky => "nsew", -ipady => 5 );

$button1->grid( -row => 2, -column => 0, -sticky => "nsew", -ipady => 5 );
$button3->grid( -row => 2, -column => 2, -sticky => "nse",  -ipady => 5 );

$txt->grid( -row => 3, -column => 0, -columnspan => 3, -sticky => "nsew" );

my $changeoutput = $mw->Button(
    -text    => "Change output log",
    -command => \&setoutputfile,
    -font    => [ -weight => 'bold', -size => 9 ]
);
$changeoutput->grid( -row => 4, -column => 0, -sticky => "nsw" );
my $verbose = $mw->Button(
    -text    => "Verbose",
    -command => \&setverboseoutput,
    -font    => [ -weight => 'bold', -size => 9 ],
    -width   => 10
);
my $notverbose = $mw->Button(
    -text    => "Terse",
    -command => \&setterseoutput,
    -font    => [ -weight => 'bold', -size => 9 ],
    -width   => 10
);
$notverbose->grid( -row => 4, -column => 2, -sticky => "nse" );
$label3->grid( -row => 4, -column => 1, -sticky => "nsw" );

my $revhist = $mw->Button(
    -text    => "History",
    -command => \&rev_hist,
    -font    => [ -weight => 'bold', -size => 9 ]
);
my $about = $mw->Button(
    -text    => "About",
    -command => \&about_ppv,
    -font    => [ -weight => 'bold', -size => 9 ]
);
my $addCSV = $mw->Button(
    -text    => "Include CSV output",
    -command => \&setCSVoutput,
    -font    => [ -weight => 'bold', -size => 9 ]
);
my $removeCSV = $mw->Button(
    -text    => "Remove CSV output",
    -command => \&noCSVoutput,
    -font    => [ -weight => 'bold', -size => 9 ]
);
$revhist->grid( -row => 6, -column => 0, -sticky => "nsw" );
$about->grid( -row => 6, -column => 2, -sticky => "nse" );
$addCSV->grid( -row => 6, -column => 1, -sticky => "ns", -ipadx => 5 );
$mw->gridColumnconfigure( 1, -weight => 2 );

MainLoop;

sub setverboseoutput {
    $terse = 0;
    $verbose->gridForget();
    $notverbose->grid( -row => 4, -column => 2, -sticky => "nse" );
    $txt->insert( 'end',
            "------------------------------------------------------------------------\n"
          . "Including informational output\n" );
    $txt->see('end');
}

sub setterseoutput {
    $terse = 1;
    $notverbose->gridForget();
    $verbose->grid( -row => 4, -column => 2, -sticky => "nse" );
    $txt->insert( 'end',
            "------------------------------------------------------------------------\n"
          . "Suppressing informational output\n" );
    $txt->see('end');
}

sub setoutputfile {
    $outfile = $mw->getSaveFile(
        -defaultextension => ".log",
        -filetypes        => [ [ 'Text Files', [ '.log', '.err' ] ], [ 'All Files', '*', ], ],
        -initialdir       => Cwd::cwd(),
        -initialfile      => "ppvimage.log",
        -title            => "Log file destination",
    );
    if ($outfile) {
        $outfilename = $outfile;
    } else {
        $outfile     = "";
        $outfilename = "ppvimage.log";
    }
    $txt->insert( 'end',
            "------------------------------------------------------------------------\n"
          . "Log will be written to:\n    $outfilename\n" );
    $txt->see('end');
}

sub setCSVoutput {
    $txt->insert( 'end',
            "------------------------------------------------------------------------\n"
          . "Both CSV and logfile will be generated\n" );
    $txt->see('end');
    $makeCSV = 1;
    $removeCSV->grid( -row => 6, -column => 1, -sticky => "ns", -ipadx => 5 );
    $addCSV->gridForget();
}

sub noCSVoutput {
    $txt->insert( 'end',
            "------------------------------------------------------------------------\n"
          . "Just the logfile will be generated\n" );
    $txt->see('end');
    $makeCSV = 0;
    $addCSV->grid( -row => 6, -column => 1, -sticky => "ns", -ipadx => 5 );
    $removeCSV->gridForget();
}

sub about_ppv {
    $mw->messageBox(
        -message =>
          "ppvimage.pl was put together by David Wilson, based on Roger Frank's ppvhtml.pl\n"
          . "for use by distributed proofreaders at http://www.pgdp.net.\n"
          . "questions, comments, suggestions to DP user: dcwilson",
        -type => 'ok',
        -icon => 'info'
    );
}

sub rev_hist {
    $txt->insert( 'end',
            "------------------------------------------------------------------------\n"
          . "current version: $vnum\n"
          . "1.07 23/May/2020 (by DP user windymilla)\n"
          . "  update image size limits\n"
          . "    inline images: max 256KB, but no pixel limits\n"
          . "    linked images: max 1024KB, but no pixel limits\n"
          . "    cover image: min 625x1000 pixels, but no max pixel or KB limits\n"
          . "1.06 10/Dec/2012\n"
          . "  add warnings for unused files in /images folder\n"
          . "  loosen input file syntax requirements\n"
          . "  find multiple images on single source line\n"
          . "  add source line numbers to messages\n"
          . "  add check for lowercase filenames\n"
          . "  add check for epub cover image\n"
          . "  add commandline options to facilitate integration with GuiGuts\n"
          . "  expand gui to expose new options\n"
          . "1.05 21/Nov/2011\n"
          . "  add warning if natural and coded width or height differ\n"
          . "1.04 28/Jul/2011\n"
          . "  add CSV output option following suggestion by Tom Cosmas\n"
          . "  adapt to facilitate command-line execution following suggestion by Katt83\n"
          . "1.03 13/Feb/2009\n"
          . "  add checking of css background images\n"
          . "1.02 03/Feb/2009\n"
          . "  refine messages reported in log file\n"
          . "1.01 03/Feb/2009\n"
          . "  add recognition for width/height supplied via inline CSS\n"
          . "1.00 23/Jan/2009\n"
          . "  initial release in Perl/Tk\n\n" );
    $txt->see('end');
}

sub loadFile {
    $srctext = $mw->getOpenFile(
        -defaultextension => ".htm|.html",
        -filetypes        => [ [ 'Text Files', [ '.htm', '.html' ] ], [ 'All Files', '*', ], ],
        -initialdir       => Cwd::cwd(),
        -initialfile      => "",
        -title            => "Select input HTML",
    );
    if ($srctext) {
        $txt->insert( 'end',
                "------------------------------------------------------------------------\n"
              . "You have selected:\n    "
              . $srctext
              . "\n" );
        if ( not $makeCSV ) {
            $txt->insert( 'end',
                "Click the button below to also generate a comma separated (CSV) summary.\n" );
        }
        $txt->insert( 'end', "\nClick the Run button to analyze the file.\n" );
        $txt->see('end');
        if ( $outfile eq "" ) {
            $outfile     = File::Spec->catfile( dirname($srctext), "ppvimage.log" );
            $outfilename = $outfile;
        }

        # now make Run button visible
        $button2->grid( -row => 2, -column => 1, -sticky => "nsew", -ipady => 5 );
    } else {
        &exitProgram;
    }
}

sub exitProgram {
    $txt->insert( 'end', "\nThanks for using ppvimage.\n" );
    $txt->see('end');
    $mw->update;
    sleep 1;
    exit;
}

sub runProgram {
    if ( $outfile eq "" ) { $outfile = File::Spec->catfile( dirname($srctext), "ppvimage.log" ); }
    open LOGFILE, "> $outfile" || die "output file error\n";
    if ( $gg + $terse == 0 ) {
        print LOGFILE "program " . basename($0) . " version $vnum\n\n";
        print LOGFILE "processing $srctext\n    to $outfile\n\n";
        printf LOGFILE ( "%s\n", "-" x 80 );
    }
    my $CSVfile = $outfile;
    $CSVfile =~ s/\.[^\.]*$/.csv/;
    if ( $CSVfile eq $outfile ) { $CSVfile = $CSVfile . ".csv"; }
    if ($makeCSV) {
        open CSVOUT, "> $CSVfile" || die "output CSV file error\n";
        print CSVOUT (
            "filename, coded_wd, coded_ht, css_wd, css_ht, natural_wd, natural_ht, size_kb");
    }

    # read book a line at a time into the array @book
    open INFILE, $srctext || die "no source file\n";
    @book = <INFILE>;
    chomp @book;
    close INFILE;

    # run checks specified in the following call sequence

    &imgcheck;
    &bgimgcheck;
    &hrefimagecheck;
    &checkepubcover;
    &unusedimagecheck;

    # date stamp in logfile for this run
    ( my $sec, my $min, my $hour, my $mday, my $mon, my $year, my $wday, my $yday, my $isdst ) =
      localtime(time);
    if ( $gg + $terse == 0 ) {
        printf LOGFILE ( "\n%s\n", "=" x 80 );
        printf LOGFILE "run completed: %4d-%02d-%02d %02d:%02d:%02d\n",
          $year + 1900, $mon + 1, $mday, $hour, $min, $sec;
    }

    close LOGFILE;
    if ( not($gg) ) {
        if ($makeCSV) { close CSVOUT; }
        if ($txt) {
            $txt->insert( 'end', "Ok, I'm done analyzing your file.\n" );
            $txt->insert( 'end', "Results were saved in\n   " . $outfile . "\n" );
            if ($makeCSV) {
                $txt->insert( 'end',
                    "Comma Separated Value version saved in\n   " . $CSVfile . "\n" );
            }
            $txt->insert( 'end', "Now press Quit to exit the program.\n" );
            $outfile = "";    # so loading another input file will reset the logfile destination
        }
    }

    # part of NEWgifsize
    sub gif_blockskip {
        my ( $GIF, $skip, $type ) = @_;
        my ($s)     = 0;
        my ($dummy) = '';

        read( $GIF, $dummy, $skip );    # Skip header (if any)
        while (1) {
            if ( eof($GIF) ) {
                warn "Invalid/Corrupted GIF (at EOF in GIF $type)\n";
                return "";
            }
            read( $GIF, $s, 1 );              # Block size
            last if ord($s) == 0;             # Block terminator
            read( $GIF, $dummy, ord($s) );    # Skip data
        }
    }

    # this code by "Daniel V. Klein" <dvk@lonewolf.com>
    sub NEWgifsize {
        my ($GIF) = @_;
        my ( $cmapsize, $a, $b, $c, $d, $e ) = 0;
        my ( $type, $s )                     = ( 0, 0 );
        my ( $x, $y )                        = ( 0, 0 );
        my ($dummy) = '';

        return ( $x, $y ) if ( !defined $GIF );

        read( $GIF, $type, 6 );
        if ( $type !~ /GIF8[7,9]a/ || read( $GIF, $s, 7 ) != 7 ) {
            warn "Invalid/Corrupted GIF (bad header)\n";
            return ( $x, $y );
        }
        ($e) = unpack( "x4 C", $s );
        if ( $e & 0x80 ) {
            $cmapsize = 3 * 2**( ( $e & 0x07 ) + 1 );
            if ( !read( $GIF, $dummy, $cmapsize ) ) {
                warn "Invalid/Corrupted GIF (global color map too small?)\n";
                return ( $x, $y );
            }
        }
      FINDIMAGE:
        while (1) {
            if ( eof($GIF) ) {
                warn "Invalid/Corrupted GIF (at EOF w/o Image Descriptors)\n";
                return ( $x, $y );
            }
            read( $GIF, $s, 1 );
            ($e) = unpack( "C", $s );
            if ( $e == 0x2c ) {    # Image Descriptor (GIF87a, GIF89a 20.c.i)
                if ( read( $GIF, $s, 8 ) != 8 ) {
                    warn "Invalid/Corrupted GIF (missing image header?)\n";
                    return ( $x, $y );
                }
                ( $a, $b, $c, $d ) = unpack( "x4 C4", $s );
                $x = $b << 8 | $a;
                $y = $d << 8 | $c;
                return ( $x, $y );
            }
            if ( $type eq "GIF89a" ) {
                if ( $e == 0x21 ) {    # Extension Introducer (GIF89a 23.c.i)
                    read( $GIF, $s, 1 );
                    ($e) = unpack( "C", $s );
                    if ( $e == 0xF9 ) {    # Graphic Control Extension (GIF89a 23.c.ii)
                        read( $GIF, $dummy, 6 );    # Skip it
                        next FINDIMAGE;             # Look again for Image Descriptor
                    } elsif ( $e == 0xFE ) {    # Comment Extension (GIF89a 24.c.ii)
                        &gif_blockskip( $GIF, 0, "Comment" );
                        next FINDIMAGE;         # Look again for Image Descriptor
                    } elsif ( $e == 0x01 ) {    # Plain Text Label (GIF89a 25.c.ii)
                        &gif_blockskip( $GIF, 12, "text data" );
                        next FINDIMAGE;         # Look again for Image Descriptor
                    } elsif ( $e == 0xFF ) {    # Application Extension Label (GIF89a 26.c.ii)
                        &gif_blockskip( $GIF, 11, "application data" );
                        next FINDIMAGE;         # Look again for Image Descriptor
                    } else {
                        printf STDERR "Invalid/Corrupted GIF (Unknown extension %#x)\n", $e;
                        return ( $x, $y );
                    }
                } else {
                    printf STDERR "Invalid/Corrupted GIF (Unknown code %#x)\n", $e;
                    return ( $x, $y );
                }
            } else {
                warn "Invalid/Corrupted GIF (missing GIF87a Image Descriptor)\n";
                return ( $x, $y );
            }
        }
    }

    #  pngsize : gets the width & height (in pixels) of a png file
    # cor this program is on the cutting edge of technology! (pity it's blunt!)
    #  GRR 970619:  fixed bytesex assumption
    sub pngsize {
        my ($PNG)  = @_;
        my ($head) = "";
        my ( $a, $b, $c, $d, $e, $f, $g, $h ) = 0;

        if (
               defined($PNG)
            && read( $PNG, $head, 8 ) == 8
            && (   $head eq "\x8a\x4d\x4e\x47\x0d\x0a\x1a\x0a"
                || $head eq "\x89\x50\x4e\x47\x0d\x0a\x1a\x0a" )
            && read( $PNG, $head, 4 ) == 4
            && read( $PNG, $head, 4 ) == 4
            && (   $head eq "MHDR"
                || $head eq "IHDR" )
            && read( $PNG, $head, 8 ) == 8
        ) {
            ( $a, $b, $c, $d, $e, $f, $g, $h ) = unpack( "C" x 8, $head );
            return ( $a << 24 | $b << 16 | $c << 8 | $d, $e << 24 | $f << 16 | $g << 8 | $h );
        }
        return ( 0, 0 );
    }

    # jpegsize : gets the width and height (in pixels) of a jpeg file
    # Andrew Tong, werdna@ugcs.caltech.edu           February 14, 1995
    # modified slightly by wtwf.com
    sub jpegsize {
        my ($JPEG) = @_;
        my ($done) = 0;
        my ( $c1, $c2, $ch, $s, $length, $dummy ) = ( 0, 0, 0, 0, 0, 0 );
        my ( $a, $b, $c, $d );

        if (   defined($JPEG)
            && read( $JPEG, $c1, 1 )
            && read( $JPEG, $c2, 1 )
            && ord($c1) == 0xFF
            && ord($c2) == 0xD8 ) {
            while ( ord($ch) != 0xDA && !$done ) {

                # Find next marker (JPEG markers begin with 0xFF)
                # This can hang the program!!
                while ( ord($ch) != 0xFF ) { return ( 0, 0 ) unless read( $JPEG, $ch, 1 ); }

                # JPEG markers can be padded with unlimited 0xFF's
                while ( ord($ch) == 0xFF ) { return ( 0, 0 ) unless read( $JPEG, $ch, 1 ); }

                # Now, $ch contains the value of the marker.
                if ( ( ord($ch) >= 0xC0 ) && ( ord($ch) <= 0xC3 ) ) {
                    return ( 0, 0 ) unless read( $JPEG, $dummy, 3 );
                    return ( 0, 0 ) unless read( $JPEG, $s,     4 );
                    ( $a, $b, $c, $d ) = unpack( "C" x 4, $s );
                    return ( $c << 8 | $d, $a << 8 | $b );
                } else {

                    # We **MUST** skip variables, since FF's within variable names are
                    # NOT valid JPEG markers
                    return ( 0, 0 ) unless read( $JPEG, $s, 2 );
                    ( $c1, $c2 ) = unpack( "C" x 2, $s );
                    $length = $c1 << 8 | $c2;
                    last if ( !defined($length) || $length < 2 );
                    read( $JPEG, $dummy, $length - 2 );
                }
            }
        }
        return ( 0, 0 );
    }

    sub logprint {    # print message to logfile, formatted to suit GG or "normal" output
                      # $_[0] is the body of the message
                      # S_[1] is the source line number
                      # $_[2] is "KEY" if message should be used in "terse" mode
                      # $_[3] is non-GG prefix
                      # $_[4] is non-GG postfix
        if ( not($terse) || ( $_[2] eq "KEY" ) ) {    # generate message
            if ($gg) {
                printf LOGFILE "line %-5d", $_[1];
                print LOGFILE (" $_[0]\n");
            } else {
                print LOGFILE ("$_[3]$_[0]$_[4]\n");
            }
        }
    }
##################################
    sub imgcheck {    # partially parse <img> tag and report
        print LOGFILE ("\n---------- checking <img> images ----------\n");
        my $img        = "";
        my $imgtail    = "";
        my $sourceline = 0;
        my $reportline = 0;
        foreach $_ (@book) {    # find <img> tags and filenames
            $sourceline++;
            $img     = $img . " " . $_;
            $imgtail = "";
            if ( $img =~ m/<img/i ) {    # start of <img> tag
                $reportline = $sourceline;
                $img =~ s/^.*?<img/<img/i;    # trim preceding crap
                $imgtail = $img;
                while ( $img =~ m/>/ ) {      # complete <img> tag present
                    $img     =~ s/^(.*?>).*$/$1/;    # now just the <img>
                    $imgtail =~ s/^.*?>//;           # the rest if any
                    if ( not( $img =~ m/\/>$/ ) ) {
                        logprint( "img tag not properly closed",
                            $reportline, "INFO", "--> $img\n  WARNING: ", "" );
                    }
                    $src = $img;
                    $src =~ s/^.*src *= *['"]?([^'" ]*)['"]?.*$/$1/i;
                    $errline = $reportline;
                    print LOGFILE ("\n");
                    logprint( "Image: $src", $reportline, "KEY", "", "\n  (line $reportline)" );
                    if ($makeCSV) { print CSVOUT ("\n$src, "); }
                    if ( not( $src =~ m/^images\// ) ) {           # image not in images folder
                        logprint( "  image file not in /images folder",
                            $errline, "KEY", "  WARNING:", "" );
                    } else {                                       # add image to list of used images
                        if ( $src =~ m/[A-Z]/ ) {
                            logprint( "  $src name is not lowercase",
                                $errline, "KEY", "  WARNING:", "" );
                        }
                        my $usedimg = $src;
                        $usedimg =~ s/images\/(.*)/$1/;                                  # NB case sensitive: "images" must be lowerecase
                        push( @imagelist, $usedimg );
                        if ( ( $usedimg =~ m/cover/ ) or ( $usedimg =~ m/title/ ) ) {    # potential epub cover page
                            if ( $imgcover eq "" ) {
                                $imgcover     = $src;
                                $imgcoverline = $reportline;
                            }
                        }
                    }
                    my $idspec = $img;
                    $idspec =~ s/^.*id *= *(['"].*$)/$1/i;
                    my $idqt = substr( $idspec, 0, 1 );
                    if ( length($idqt) > 0 ) {    # check if this is a coverpage
                        if    ( $idqt eq '\'' ) { $idspec =~ s/'([^']*)'.*$/$1/; }
                        elsif ( $idqt eq '"' )  { $idspec =~ s/"([^"]*)".*$/$1/; }
                        if    ( $idspec eq "coverpage" or $idspec eq "icon" ) {
                            $imgcover     = $src;
                            $imgcoverline = $reportline;
                        }                         # note id=coverpage has higher precedence
                    }
                    my $alt = $img;
                    $alt =~ s/^.*alt *= *(['"].*$)/$1/i;
                    my $altqt = substr( $alt, 0, 1 );
                    if    ( $altqt eq '\'' ) { $alt =~ s/'([^']*)'.*$/$1/; }
                    elsif ( $altqt eq '"' )  { $alt =~ s/"([^"]*)".*$/$1/; }
                    else {
                        logprint( "  WARNING: <img> has no alt attribute", $errline, "KEY", "",
                            "" );
                        $altqt = "";
                    }
                    if ( length($altqt) > 0 ) {
                        logprint( "  alt=$altqt$alt$altqt", $errline, "INFO", "", "" );
                    }
                    my $ttl = $img;
                    $ttl =~ s/^.*title *= *(['"].*$)/$1/i;
                    my $ttlqt = substr( $ttl, 0, 1 );
                    if    ( $ttlqt eq '\'' ) { $ttl =~ s/'([^']*)'.*$/$1/; }
                    elsif ( $ttlqt eq '"' )  { $ttl =~ s/"([^"]*)".*$/$1/; }
                    else {    # title attribute is optional so no point making a fuss about missing ones
                              # logprint ("  <img> has no title attribute",$errline,"INFO","    NOTE:","");
                        $ttlqt = "";
                    }
                    if ( length($ttlqt) > 0 ) {
                        logprint( "  title=$ttlqt$ttl$ttlqt", $errline, "INFO", "", "" );
                    }
                    my $warn   = "  WARNING";
                    my $wdstyl = "X";
                    my $htstyl = "X";

                    # now check for CSS spec
                    my $styl = $img;
                    $styl =~ s/^.*style *= *(.*$)/$1/i;
                    if ( $styl ne $img ) {    # we have a style spec
                        $wdstyl = $img;
                        $wdstyl =~ s/^.*width *: *([^;]*);.*$/$1/i;
                        if ( $wdstyl eq $img ) { $wdstyl = "X"; }
                        $htstyl = $img;
                        $htstyl =~ s/^.*height *: *([^;]*);.*$/$1/i;
                        if ( $htstyl eq $img ) { $htstyl = "X"; }
                        if ( ( $wdstyl ne "X" ) or ( $htstyl ne "X" ) ) {
                            $warn = "     NOTE";
                        }
                    }

                    # now check for non-CSS spec
                    $wd = $img;
                    $wd =~ s/^.*width *= *['"]?(\d*)['"]?.*$/$1/i;
                    if ( $wd eq $img ) {
                        logprint( "$warn: <img> lacks width attribute", $errline, "INFO", "", "" );
                        $wd = "X";
                    }
                    if ( length($wd) == 0 ) {
                        logprint( "$warn: <img> has empty width attribute",
                            $errline, "KEY", "", "" );
                    }
                    $ht = $img;
                    $ht =~ s/^.*height *= *['"]?(\d*)['"]?.*$/$1/i;
                    if ( $ht eq $img ) {
                        logprint( "$warn: <img> lacks height attribute", $errline, "INFO", "", "" );
                        $ht = "X";
                    }
                    if ( length($ht) == 0 ) {
                        logprint( "$warn: <img> has empty height attribute",
                            $errline, "KEY", "", "" );
                    }
                    $imgfile = File::Spec->catfile( dirname($srctext), $src );
                    my $dimsmessage = "";
                    if ( ( $wd ne "X" ) or ( $ht ne "X" ) ) {
                        $dimsmessage = "    coded ";
                        if ( $wd ne "X" ) {
                            $dimsmessage = $dimsmessage . "width=\"$wd\" ";
                            if ($makeCSV) { print CSVOUT ("$wd"); }
                        }
                        if ($makeCSV) { print CSVOUT (", "); }
                        if ( $ht ne "X" ) {
                            $dimsmessage = $dimsmessage . "height=\"$ht\"";
                            if ($makeCSV) { print CSVOUT ("$ht"); }
                        }
                        if ($makeCSV) { print CSVOUT (", "); }
                        logprint( $dimsmessage, $errline, "INFO", "", "" );
                    } else {
                        if ($makeCSV) { print CSVOUT (", , "); }
                    }
                    if ( ( $wdstyl ne "X" ) or ( $htstyl ne "X" ) ) {
                        $dimsmessage = "   styled ";
                        if ( $wdstyl ne "X" ) {
                            $dimsmessage = $dimsmessage . "width: $wdstyl; ";
                            if ($makeCSV) { print CSVOUT ("$wdstyl"); }
                        }
                        if ($makeCSV) { print CSVOUT (", "); }
                        if ( $htstyl ne "X" ) {
                            $dimsmessage = $dimsmessage . "height: $htstyl;";
                            if ($makeCSV) { print CSVOUT ("$htstyl"); }
                        }
                        if ($makeCSV) { print CSVOUT (", "); }
                        logprint( $dimsmessage, $errline, "INFO", "", "" );
                    } else {
                        if ($makeCSV) { print CSVOUT (", , "); }
                    }
                    open( IMGFILE, "<", $imgfile ) || do {
                        logprint( "  image file $src not found", $errline, "KEY", "  !!!",
                            "  !!!" );
                        goto CHECKFORMORE;
                    };
                    &imgdimens;
                  CHECKFORMORE: if ( $imgtail =~ m/<img/i ) {
                        $img = $imgtail;
                        $img =~ s/^.*?(<img.*$)/$1/i;
                    } else {
                        $img = "";
                    }
                    $imgtail = $img;
                }    # end of while
            } else {
                $img = "";
            }
        }
    }    # end imgcheck

#######
    sub imgdimens {

        # get and report natural size of image
        # (assumes $imgfile already set and IMGFILE already opened,
        # and filename in $src)
        binmode(IMGFILE);
        if ( $src =~ /\.png$/ ) {
            ( $x, $y ) = pngsize( \*IMGFILE );
            if ( ( $x == 0 ) and ( $y == 0 ) ) {    # unable to determine dimensions
                logprint( "  *** is this really a png image? ***", $errline, "KEY", "", "" );
            }
            logprint( "  natural width=\"$x\" height=\"$y\"", $errline, "INFO", "", "" );
            if ($makeCSV) {
                print CSVOUT ("$x, $y, ");
            }
            if ( ( $wd ne "X" ) and ( $x ne $wd ) ) {
                $x = abs( $wd - $x );
                logprint( "   natural/coded widths differ by $x",
                    $errline, "KEY", "      ***", " ***" );
            }
            if ( ( $ht ne "X" ) and ( $y ne $ht ) ) {
                $y = abs( $ht - $y );
                logprint( "   natural/coded heights differ by $y",
                    $errline, "KEY", "      ***", " ***" );
            }
        } elsif ( $src =~ /\.jpe?g$/ ) {
            ( $x, $y ) = jpegsize( \*IMGFILE );
            if ( ( $x == 0 ) and ( $y == 0 ) ) {    # unable to determine dimensions
                logprint( "  *** is this really a jpeg image? ***", $errline, "KEY", "", "" );
            }
            logprint( "  natural width=\"$x\" height=\"$y\"", $errline, "INFO", "", "" );
            if ($makeCSV) {
                print CSVOUT ("$x, $y, ");
            }
            if ( ( $wd ne "X" ) and ( $x ne $wd ) ) {
                $x = abs( $wd - $x );
                logprint( "   natural/coded widths differ by $x",
                    $errline, "KEY", "      ***", " ***" );
            }
            if ( ( $ht ne "X" ) and ( $y ne $ht ) ) {
                $y = abs( $ht - $y );
                logprint( "   natural/coded heights differ by $y",
                    $errline, "KEY", "      ***", " ***" );
            }
        } elsif ( $src =~ /\.gif$/ ) {
            ( $x, $y ) = NEWgifsize( \*IMGFILE );
            if ( ( $x == 0 ) and ( $y == 0 ) ) {    # unable to determine dimensions
                logprint( "  *** is this really a gif image? ***", $errline, "KEY", "", "" );
            }
            logprint( "  natural width=\"$x\" height=\"$y\"", $errline, "INFO", "", "" );
            if ($makeCSV) {
                print CSVOUT ("$x, $y, ");
            }
            if ( ( $wd ne "X" ) and ( $x ne $wd ) ) {
                $x = abs( $wd - $x );
                logprint( "   natural/coded widths differ by $x",
                    $errline, "KEY", "      ***", " ***" );
            }
            if ( ( $ht ne "X" ) and ( $y ne $ht ) ) {
                $y = abs( $ht - $y );
                logprint( "   natural/coded heights differ by $y",
                    $errline, "KEY", "      ***", " ***" );
            }
        } else {
            logprint( "  unknown image type: $src", $errline, "KEY", "", "" );
        }
        close IMGFILE;
        my (
            $dev,  $ino,   $mode,  $nlink, $uid,     $gid, $rdev,
            $size, $atime, $mtime, $ctime, $blksize, $blocks
        ) = stat($imgfile);
        $size = $size / 1024;
        if ( $size < 1 ) { $size = 1; }    # avoid reporting files less than 512 bytes as 0 KB
        my $verylarge = "VERY LARGE";
        if ($howbig) { $verylarge = "LARGE"; }
        if ( $size > MAXKBLINKED ) {
            if ($gg) {
                printf LOGFILE "line %-5d",                          $errline;
                printf LOGFILE "   Filesize: %3u KB ($verylarge)\n", $size;
            } else {
                printf LOGFILE "  Filesize: %3u KB ($verylarge)\n", $size;
            }
        } elsif ( ( $howbig == 0 ) and ( $size > MAXKBINLINE ) ) {
            if ($gg) {
                printf LOGFILE "line %-5d",                     $errline;
                printf LOGFILE "   Filesize: %3u KB (LARGE)\n", $size;
            } else {
                printf LOGFILE "  Filesize: %3u KB (LARGE)\n", $size;
            }
        } elsif ( not($terse) ) {
            if ($gg) {
                printf LOGFILE "line %-5d",             $errline;
                printf LOGFILE "   Filesize: %3u KB\n", $size;
            } else {
                printf LOGFILE "  Filesize: %3u KB\n", $size;
            }
        }
        if ($makeCSV) {
            printf CSVOUT "%u ", $size;
        }
    }    # end imgdimens

##################################
    sub bgimgcheck {
        print LOGFILE ("\n\n---------- checking css background images ----------\n");

        # note we don't attempt to locate background images defined using
        # the background: shorthand, only those defined using background-image:
        my $sourceline = 0;
        my $reportline = 0;
        my $bgimg      = "";
        my $bgimgtail  = "";
        $wd = "X";              # suppress comparison with coded width in imgdimens
        $ht = "X";              # suppress comparison with coded height in imgdimens
        foreach $_ (@book) {    # find background-image spec and filenames
            $sourceline++;
            $bgimg     = $bgimg . " " . $_;
            $bgimgtail = "";
            if ( $bgimg =~ m/background-image/i ) {    # input contains start of defn
                $reportline = $sourceline;
                $bgimg =~ s/^.*?background-image/background-image/i;    # trim preceding crap
                $bgimgtail = $bgimg;
                while ( $bgimg =~ m/[;}]/ ) {                           # spec closed
                    $bgimg     =~ s/(^[^;}]*[;}]).*$/$1/;               # first spec
                    $bgimgtail =~ s/^[^;}]*[;}]//;                      # the rest if any
                    $src = $bgimg;
                    $src =~ s/^.*url *\(['"]?([^'" ]*)['"]?\).*$/$1/i;
                    print LOGFILE ("\n");
                    if ( $src eq $bgimg ) {                             # no url provided (should be "none" or "inherit")
                        logprint( "Background image without url: $src",
                            $reportline, "KEY", "", "\n  (line $reportline)" );
                    } else {
                        logprint( "Background image: $src",
                            $reportline, "KEY", "", "\n  (line $reportline)" );
                        if ($makeCSV) { print CSVOUT ("\n$src,,,,, "); }
                        if ( not( $src =~ m/^images\// ) ) {               # image not in images folder
                            logprint( "  image file not in /images folder",
                                $reportline, "KEY", "  WARNING:", "" );
                        } else {                                           # add image to list of used images
                            if ( $src =~ m/[A-Z]/ ) {
                                logprint( "  $src name is not lowercase",
                                    $errline, "KEY", "  WARNING:", "" );
                            }
                            my $usedimg = $src;
                            $usedimg =~ s/images\/(.*)/$1/;
                            push( @imagelist, $usedimg );
                        }
                        $imgfile = File::Spec->catfile( dirname($srctext), $src );
                        open( IMGFILE, "<", $imgfile ) || do {
                            logprint( "  image file $src not found",
                                $reportline, "KEY", "  !!!", "  !!!" );
                            goto CHECKFORMOREBGS;
                        };
                        $errline = $reportline;
                        &imgdimens;
                    }
                  CHECKFORMOREBGS: if ( $bgimgtail =~ m/background-image/i ) {
                        $bgimg = $bgimgtail;
                        $bgimg =~ s/^.*?background-image/background-image/i;
                    } else {
                        $bgimg = "";
                    }
                    $bgimgtail = $bgimg;
                }    # end of while
            } else {
                $bgimg = "";
            }
        }    # for
    }    # end bgimgcheck

###################
    sub hrefimagecheck {
        print LOGFILE ("\n\n---------- checking linked images ----------\n");

        # search through the file looking for href="images/something"
        # and add to @imagelist
        my $sourceline = 0;
        my $reportline = 0;
        $howbig = 1;    # only report images over 200KB
        my $usedimg     = "";
        my $usedimgtail = "";
        $wd = "X";      # suppress comparison with coded width in imgdimens
        $ht = "X";      # suppress comparison with coded height in imgdimens

        foreach $_ (@book) {
            $sourceline++;
            $usedimg     = $usedimg . " " . $_;
            $usedimgtail = "";
            if ( $usedimg =~ m/href/i ) {    # found a link
                $reportline = $sourceline;
                $usedimg =~ s/^.*?href/href/i;                                    # trim preceding crap
                $usedimgtail = $usedimg;
                while ( $usedimg =~ m/href *= *['"]?images\/[^'" ]*['"]?/i ) {    # /images link
                    $usedimg     =~ s/^.*?href *= *['"]?images\/([^'" ]*)['"]?.*$/$1/i;    # first image linked
                    $usedimgtail =~ s/^.*?href *= *['"]?images\/[^'" ]*['"]?//;            # remaining input
                    print LOGFILE ("\n");
                    logprint( "Linked image: images/$usedimg",
                        $reportline, "KEY", "", "\n  (line $reportline)" );
                    if ($makeCSV) { print CSVOUT ("\nimages/$usedimg,,,,, "); }
                    push( @imagelist, $usedimg );
                    if ( $usedimg =~ m/[A-Z]/ ) {
                        logprint( "  $usedimg name is not lowercase",
                            $reportline, "KEY", "  WARNING:", "" );
                    }
                    $imgfile = File::Spec->catfile( dirname($srctext), "images" );
                    $imgfile = File::Spec->catfile( $imgfile,          $usedimg );
                    open( IMGFILE, "<", $imgfile ) || do {
                        logprint( "  image file $usedimg not found",
                            $reportline, "KEY", "  !!!", "  !!!" );
                        goto CHECKFORMORELINKED;
                    };
                    $src     = $usedimg;
                    $errline = $reportline;
                    &imgdimens;
                  CHECKFORMORELINKED: if ( $usedimgtail =~ m/href/i ) {
                        $usedimg = $usedimgtail;
                        $usedimg =~ s/^.*?href/href/i;
                    } else {
                        $usedimg = "";
                    }
                    $usedimgtail = $usedimg;
                }    # while
            }    # if
            else { $usedimg = ""; }
        }
    }    # end hrefimagecheck

###################
    sub unusedimagecheck {    # no sensible line numbers so don't use logprint
                              # now compare imagelist to list of files in /images
        print LOGFILE ("\n\n---------- checking for unused images ----------\n");
        my $dir = File::Spec->catfile( dirname($srctext), "images" );
        opendir( DIR, $dir ) || do {
            print LOGFILE ( "\n" . NOLINEINDENT . "WARNING: /images folder not found\n" );
            die "no /images folder";
        };
        my @imageslist = grep { -f "$dir/$_" } readdir(DIR);
        closedir(DIR);
        foreach my $img (@imageslist) {
            my $msgwritten = 0;
            if ( $img =~ m/[A-Z]/ ) {
                print LOGFILE ( "\n" . NOLINEINDENT . "WARNING: $img name is not lowercase\n" );
                $msgwritten = 1;
            }
            my $foundmatch = 0;
            foreach my $usedimage (@imagelist) {    # see if we have a match
                if ( lc($usedimage) eq lc($img) ) {
                    $foundmatch = 1;
                    last;
                }
            }
            if ( $foundmatch == 0 ) {
                if ( $msgwritten == 0 ) { print LOGFILE "\n"; }
                print LOGFILE ( NOLINEINDENT . "WARNING: file $img appears to be unused\n" );
            }
        }
    }    # end unusedimgcheck

#######################
    sub checkepubcover {
        print LOGFILE ("\n---------- checking cover image ----------\n");

        # first see if there's a <link rel="icon" (or coverpage) in the header
        my $linkrel    = "";
        my $sourceline = 0;
        my $coverfile  = "";
        foreach $_ (@book) {
            $sourceline++;
            $linkrel = $linkrel . " " . $_;
            if ( $linkrel =~ m/<\/head>/i ) {    # no need to look further
                last;
            } elsif ( $linkrel =~ m/<link/i ) {    # see if it's the right one
                $linkrel =~ s/^.*?<link/<link/i;    # remove any leading stuff
                if ( $linkrel =~
                    m/<link *rel *= *['"]?(coverpage|icon)['"]? *href *= *['"]?images\/[^'" ]*['"]?/i ) { # got one
                    $imgcover = $linkrel;
                    $imgcover =~
                      s/^.*?<link *rel *= *['"]?(coverpage|icon)['"]? *href *= *['"]?(images\/[^'" ]*)['"]?.*$/$2/i;
                    $imgcoverline = $sourceline;
                    last;
                }
            } else {
                $linkrel = "";
            }
        }
        if ( $imgcoverline == 0 ) {    # no epub cover
            print LOGFILE ( "\n\n" . NOLINEINDENT . "*** WARNING: no epub cover image found\n" );
        } else {
            print LOGFILE ("\n\n");
            logprint( "NOTE: epub cover will be $imgcover",
                $imgcoverline, "INFO", "\n", " (line $imgcoverline)" );

            # warn if not jpg or smaller than minimum width & height
            if ( not( $imgcover =~ m/\.jpe?g$/ ) ) {
                logprint( "WARNING: epub cover should be jpg", $imgcoverline, "KEY", "", "" );
            } else {
                $coverfile = File::Spec->catfile( dirname($srctext), $imgcover );
                open( IMGFILE, "<", $coverfile ) || do {
                    logprint( "  epub cover image not found",
                        $imgcoverline, "KEY", "  !!!", "  !!!" );
                    return 0;
                };
                binmode(IMGFILE);
                ( $x, $y ) = jpegsize( \*IMGFILE );
                if ( ( $x < MINCOVERWD ) or ( $y < MINCOVERHT ) ) {
                    logprint(
                        "  WARNING: epub cover should be at least " . MINCOVERWD . "x" . MINCOVERHT,
                        $imgcoverline, "KEY", "", ""
                    );
                }
            }
        }
    }    # end checkepubcover

}
