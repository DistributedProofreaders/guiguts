#!/usr/bin/perl -w

use strict;
use File::Basename;
use Getopt::Long;
use Tk;

# ppvimage.pl
# author: David Wilson (DP: dcwilson) adapting ppvhtml.pl written by Roger Frank (DP:rfrank)
#         and incorporating code freely available on the web (see acknowledgements within individual subs)
# last edit: 13/Feb/2009

my $vnum = "1.03k";

my @book = ();
my @css  = ();
my $srctext;
my $homedir;
my $lineindex;
my $warn;

if ( $#ARGV >= 0 ) {

	# Skip the GUI and just process the text
	$srctext = $ARGV[0];
	$homedir = $ARGV[1];

	runProgram();
	exit;
}

# Main Window
my $mw = new MainWindow;

my $filename;
my $imgfile;
my $src;
my ( $x, $y ) = ( 0, 0 );
my $frm_detail;
my $detailLevel;

my $label1 = $mw->Label(
			-text => "ppvhtml.pl post processing verification image checker." );

my $button1 = $mw->Button( -text => "Load", -command => \&loadFile );
my $button2 = $mw->Button( -text => "Run",  -command => \&runProgram );
my $button3 = $mw->Button( -text => "Quit", -command => \&exitProgram );

my $txt = $mw->Text( -width => 80, -height => 30 )->pack();
$txt->insert( 'end',
			  "This program will test the <img> tags in an HTML file.\n" );
$txt->insert( 'end',
			"First, click the Load button to load your .htm or .html file.\n" );

$label1->grid( -row => 0, -column => 0, -columnspan => 3 );

$button1->grid( -row => 2, -column => 0, -sticky => "ew" );
$button2->grid( -row => 2, -column => 1, -sticky => "ew" );
$button3->grid( -row => 2, -column => 2, -sticky => "ew" );

$txt->grid( -row => 3, -column => 0, -columnspan => 3 );

my $revhist = $mw->Button( -text => "History", -command => \&rev_hist );
my $about   = $mw->Button( -text => "About",   -command => \&about_ppv );
$revhist->grid( -row => 4, -column => 0, -sticky => "w" );
$about->grid( -row => 4, -column => 2, -sticky => "e" );

MainLoop;

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
		  . "1.03 13/Feb/2009\n"
		  . "  add checking of css background images\n"
		  . "1.02 03/Feb/2009\n"
		  . "  refine messages reported in log file\n"
		  . "1.01 03/Feb/2009\n"
		  . "  add recognition for width/height supplied via inline CSS\n"
		  . "1.00 23/Jan/2009\n"
		  . "  initial release in Perl/Tk\n"
		  . "------------------------------------------------------------------------\n"
	);
}

sub loadFile {
	$srctext = $mw->getOpenFile(
			-defaultextension => ".htm|.html",
			-filetypes =>
			  [ [ 'Text Files', [ '.htm', '.html' ] ], [ 'All Files', '*', ], ],
			-initialdir  => Cwd::cwd(),
			-initialfile => "getopenfile",
			-title       => "Post Processing (HTML)",
	);
	$txt->insert( 'end', "You have selected:\n    " . $srctext . "\n" );

	#kew -- Run automatically
	#  $txt -> insert('end',"Now click the Run button to analyze the file.\n");
	runProgram();
}

sub exitProgram {
	$txt->insert( 'end', "Thanks for using ppvimage.\n" );
	$mw->update;
	sleep 1;
	exit;
}

sub runProgram {
	my $outfile = dirname($srctext) . "/errors.err";    # modified by hmonroe
	open LOGFILE, "> $outfile" || die "output file error\n";

	# read book a line at a time into the array @book
	open INFILE, $srctext || die "no source file\n";
	@book = <INFILE>;
	chomp @book;
	close INFILE;

	# run checks specified in the following call sequence

	&imgcheck;
	&bgimgcheck;

	# date stamp in logfile for this run

	close LOGFILE;

####################

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
			read( $GIF, $s, 1 );        # Block size
			last if ord($s) == 0;       # Block terminator
			read( $GIF, $dummy, ord($s) );    # Skip data
		}
	}

	# this code by "Daniel V. Klein" <dvk@lonewolf.com>
	sub NEWgifsize {
		my ($GIF) = @_;
		my ( $cmapsize, $a, $b, $c, $d, $e ) = 0;
		my ( $type, $s ) = ( 0, 0 );
		my ( $x,    $y ) = ( 0, 0 );
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
					if ( $e == 0xF9 )
					{    # Graphic Control Extension (GIF89a 23.c.ii)
						read( $GIF, $dummy, 6 );    # Skip it
						next FINDIMAGE;    # Look again for Image Descriptor
					} elsif ( $e == 0xFE )
					{                      # Comment Extension (GIF89a 24.c.ii)
						&gif_blockskip( $GIF, 0, "Comment" );
						next FINDIMAGE;    # Look again for Image Descriptor
					} elsif ( $e == 0x01 ) { # Plain Text Label (GIF89a 25.c.ii)
						&gif_blockskip( $GIF, 12, "text data" );
						next FINDIMAGE;      # Look again for Image Descriptor
					} elsif ( $e == 0xFF )
					{    # Application Extension Label (GIF89a 26.c.ii)
						&gif_blockskip( $GIF, 11, "application data" );
						next FINDIMAGE;    # Look again for Image Descriptor
					} else {
						printf STDERR
						  "Invalid/Corrupted GIF (Unknown extension %#x)\n", $e;
						return ( $x, $y );
					}
				} else {
					printf STDERR "Invalid/Corrupted GIF (Unknown code %#x)\n",
					  $e;
					return ( $x, $y );
				}
			} else {
				warn
				  "Invalid/Corrupted GIF (missing GIF87a Image Descriptor)\n";
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

		# my($x,$y);
		my ( $a, $b, $c, $d, $e, $f, $g, $h ) = 0;

		if (
			    defined($PNG)
			 && read( $PNG, $head, 8 ) == 8
			 && (    $head eq "\x8a\x4d\x4e\x47\x0d\x0a\x1a\x0a"
				  || $head eq "\x89\x50\x4e\x47\x0d\x0a\x1a\x0a" )
			 && read( $PNG, $head, 4 ) == 4
			 && read( $PNG, $head, 4 ) == 4
			 && (    $head eq "MHDR"
				  || $head eq "IHDR" )
			 && read( $PNG, $head, 8 ) == 8
		  )
		{

	 #   ($x,$y)=unpack("I"x2,$head);   # doesn't work on little-endian machines
	 #   return ($x,$y);
			( $a, $b, $c, $d, $e, $f, $g, $h ) = unpack( "C" x 8, $head );
			return ( $a << 24 | $b << 16 | $c << 8 | $d,
					 $e << 24 | $f << 16 | $g << 8 | $h );
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

		if (    defined($JPEG)
			 && read( $JPEG, $c1, 1 )
			 && read( $JPEG, $c2, 1 )
			 && ord($c1) == 0xFF
			 && ord($c2) == 0xD8 )
		{
			while ( ord($ch) != 0xDA && !$done ) {

				# Find next marker (JPEG markers begin with 0xFF)
				# This can hang the program!!
				while ( ord($ch) != 0xFF ) {
					return ( 0, 0 ) unless read( $JPEG, $ch, 1 );
				}

				# JPEG markers can be padded with unlimited 0xFF's
				while ( ord($ch) == 0xFF ) {
					return ( 0, 0 ) unless read( $JPEG, $ch, 1 );
				}

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

	sub imgcheck {
		my $keepreading = 0;
		my $haveimage   = 0;
		my $img         = "";
		my $stylewidth =0;
		my $stylewidthline = 0;


		$lineindex=0;
		foreach $_ (@book) {    # find <img> tags and filenames
			$lineindex++;
			if (/style="width: (\d+)px/) {
				$stylewidth=$1;
				$stylewidthline=$lineindex;
			}
			$haveimage = 0;
			if ($keepreading) {
				$img = $img . " " . $_;
				$img =~ s/(^[^>]*>).*$/$1/;
				my $imgtail = $_;
				$imgtail =~ s/^[^>]*>(.*$)/$1/;
				if ( not />/ ) {
					$keepreading = 1;
					next;
				} else {  # need to process imgtail in case it contains <img too
					$keepreading = 0;
					$haveimage   = 1;
				}
			} else {
				if (/<img/i) {    # found one
				# what line number is this
				#print LOGFILE "Line : $lineindex This is the dollar underscore $_";
					$img = $_;
					$img =~ s/.*<img/<img/i;
					if ( not /<img.*>/i )
					{             # tag not closed on same line; get more lines
						$keepreading = 1;
						next;
					} else {
						$haveimage = 1;
					}
				}
			}
			if ($haveimage) {
				if ( not( $img =~ m/\/>/ ) ) {
					print LOGFILE (
						  "line $lineindex:1 img tag not properly closed $img\n");
				}
				$src = $img;
				$src =~ s/^.*src=['"]([^'" ]*)['"].*$/$1/i;
				#print LOGFILE ("image: $src\n");
				if ( not( $src =~ m/^images\// ) )
				{    # image not in images directory
					print LOGFILE (
							 "line $lineindex:1 image file not in images directory for $src\n");
				}
				my $alt = $img;
				$alt =~ s/^.*alt=(['"].*$)/$1/i;
				my $altqt = substr( $alt, 0, 1 );
				if    ( $altqt eq '\'' ) { $alt =~ s/'([^']*)'.*$/$1/; }
				elsif ( $altqt eq '"' )  { $alt =~ s/"([^"]*)".*$/$1/; }
				else {
					print LOGFILE ("  WARNING: <img> has no alt attribute for $src\n");
					$altqt = "";
				}
				if ( length($altqt) > 0 ) {
					#print LOGFILE ("  alt=$altqt$alt$altqt\n");
				}
				my $ttl = $img;
				$ttl =~ s/^.*title=(['"].*$)/$1/i;
				my $ttlqt = substr( $ttl, 0, 1 );
				if    ( $ttlqt eq '\'' ) { $ttl =~ s/'([^']*)'.*$/$1/; }
				elsif ( $ttlqt eq '"' )  { $ttl =~ s/"([^"]*)".*$/$1/; }
				else {
					print LOGFILE ("     NOTE: <img> has no title attribute\n");
					$ttlqt = "";
				}
				if ( length($ttlqt) > 0 ) {
					#print LOGFILE ("  title=$ttlqt$ttl$ttlqt\n");
				}
				$warn   = " line $lineindex:1";
				my $wdstyl = "X";
				my $htstyl = "X";

				# now check for CSS spec
				my $styl = $img;
				$styl =~ s/^.*style=(.*$)/$1/i;
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
				my $wd = $img;
				$wd =~ s/^.*width=['"](\d*)['"].*$/$1/i;
				if ( $wd eq $img ) {
					print LOGFILE ("$warn: <img> lacks width attribute for $src\n");
					$wd = "X";
				}
				if ( length($wd) == 0 ) {
					print LOGFILE ("$warn: <img> has empty width attribute for $src\n");
				}
				my $ht = $img;
				$ht =~ s/^.*height=['"](\d*)['"].*$/$1/i;
				if ( $ht eq $img ) {
					print LOGFILE ("$warn: <img> lacks height attribute for $src\n");
					$ht = "X";
				}
				if ( length($ht) == 0 ) {
					print LOGFILE ("$warn: <img> has empty length attribute $src\n");
				}
				$imgfile = $homedir . "/" . $src;

				open( IMGFILE, "<", $imgfile ) || do {
					print LOGFILE ("$warn image file $src not found\n");
					next;
				};
				if (($wd ne $stylewidth) and ($lineindex-$stylewidthline<5)) {
					print LOGFILE (
"line $stylewidthline:1 img tag width is $wd width in style tag is $stylewidth for $src\n"
					);
				}
				&imgdimens;
				if ( ( $wd ne $x ) or ( $ht ne $y ) ) {
					print LOGFILE (
"$warn coded dimensions are $wd $ht but actual dimensions are $x $y for $src\n"
					);
				}
			}
		}
	}

	sub imgdimens {

# get and report natural size of image (assumes $imgfile already set and IMGFILE already opened)
		binmode(IMGFILE);
		if ( $src =~ /\.png$/ ) {
			( $x, $y ) = pngsize( \*IMGFILE );
			#print LOGFILE ("  natural width=\"$x\" height=\"$y\"\n");
		} elsif ( $src =~ /\.je?pg$/ ) {
			( $x, $y ) = jpegsize( \*IMGFILE );
			#print LOGFILE ("  natural width=\"$x\" height=\"$y\"\n");
		} elsif ( $src =~ /\.gif$/ ) {
			( $x, $y ) = NEWgifsize( \*IMGFILE );
			#print LOGFILE ("  natural width=\"$x\" height=\"$y\"\n");
		} else {
			#print LOGFILE ("  unknown image type: $src\n");
		}
		close IMGFILE;
		my (
			 $dev,   $ino,     $mode, $nlink, $uid,
			 $gid,   $rdev,    $size, $atime, $mtime,
			 $ctime, $blksize, $blocks
		) = stat($imgfile);
		$size = $size / 1024;
		if ( $size < 1 ) {
			$size = 1;
		}    # avoid reporting files less than 512 bytes as 0 KB
		     #printf LOGFILE "  Filesize: %u KB\n", $size;
		if ( $size > 100 ) {
			print LOGFILE "line $lineindex:1 ";
			printf LOGFILE "filesize %uKB exceeds 100KB for $src\n", $size;
		}
	}
##################################
	sub bgimgcheck {
		#print LOGFILE ("----- checking css background images -----\n");
		my $keepreading = 0;
		my $haveimage   = 0;
		my $bgimg       = "";
		foreach $_ (@book) {    # find background-image spec and filenames
			$haveimage = 0;
			if ($keepreading) {
				$bgimg = $bgimg . " " . $_;
				$bgimg =~ s/(^[^;]*;).*$/$1/;
				my $bgimgtail = $_;
				$bgimgtail =~ s/^[^;]*;(.*$)/$1/;
				if ( not /;/ ) {
					$keepreading = 1;
					next;
				} else { # need to process imgtail in case it contains background-image: too
					$keepreading = 0;
					$haveimage   = 1;
				}
			} else {
				if (/background-image/i) {    # found one
					$bgimg = $_;
					$bgimg =~ s/.*background-image/background-image/i;
					if ( not /background-image.*;/i )
					{    # spec not closed on same line; get more lines
						$keepreading = 1;
						next;
					} else {
						$haveimage = 1;
					}
				}
			}
			if ($haveimage) {
				if ( not( $bgimg =~ m/;/ ) ) {
					print LOGFILE (
"--> $bgimg\n  WARNING: background-image spec not properly closed\n"
					);
				}
				$src = $bgimg;
				$src =~ s/^.*url\(['"]([^'" ]*)['"].*$/$1/i;
				print LOGFILE ("\nbackground image: $src\n");
				if ( not( $src =~ m/^images\// ) )
				{    # image not in images directory
					print LOGFILE (
							 "  WARNING: image file not in images directory\n");
				}
				$imgfile = dirname($srctext) . "/" . $src;
				open( IMGFILE, "<", $imgfile ) || do {
					print LOGFILE ("  !!! image file $src not found !!!\n");
					next;
				};
				&imgdimens;
			}
		}    # for
	}
}
