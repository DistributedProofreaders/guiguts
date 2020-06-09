#!/usr/bin/perl -w

# usage: epubfriendly.pl [-i infile.txt] [-o epubfriendly.log]\n";
use strict;
use File::Basename;
use Getopt::Long;
my @book    = ();
my $srctext = "book.html";    # default source file
my $outfile;
my $filename;
GetOptions( 'i=s' => \$srctext, 'o=s' => \$outfile );
open LOGFILE, "> $outfile" || die "output file error\n";
open INFILE,  $srctext     || die "no source file\n";

while ( my $ln = <INFILE> ) {
	$ln =~ s/\r\n/\n/;
	chomp $ln;
	push( @book, $ln );
}
close INFILE;
my ($linenum);
my $count    = 0;
my $lastline = "trash";
foreach my $line (@book) {
	$count = $count + 1;
	if ( $line =~ /style=/ ) {
		printf LOGFILE ( "%d:1 Inline style (style=): %s\n", $count, $line );
	}
	if ( $line =~ /Page_/ ) {
		printf LOGFILE ( "%d:1 Page numbering 'Page_': %s\n", $count,$line );
	}
	if ( $line =~ /float:/i ) {
		printf LOGFILE ( "%d:1 Float 'float:': %s\n", $count, $line );
	}
	if ( $line =~ /position:fixed/i ) {
		printf LOGFILE ( "%d:1 CSS fixed position 'position:fixed': %s\n",
						 $count, $line );
	}
	if ( $line =~ /position:absolute/i ) {
		printf LOGFILE (
						 "%d:1 CSS absolute position 'position:absolute': %s\n",
						 $count, $line
		);
	}
	if ( $line =~ /margin:.*auto/i ) {
		printf LOGFILE ( "%d:1 CSS auto margin 'margin:auto': %s\n", $count,
						 $line );
	}
	if ( $line =~ /margin:.*px/i ) {
		printf LOGFILE ( "%d:1 Not a percentage margin 'margin: px': %s\n",
						 $count, $line );
	}
	if ( $line =~ /margin/i ) {
		printf LOGFILE (
"%d:1 Warning: any margin wastes real estate on small width screens: %s\n",
			$count, $line
		);
	}
	if ( $line =~ /<table/i ) {
		printf LOGFILE (
						 "%d:1 Warning: tables may run off small screens: %s\n",
						 $count, $line
		);
	}
	if ( $line =~ /(width|height).*px/i ) {
		printf LOGFILE ( "%d:1 Image size specified: %s\n", $count, $line );
	}
	if ( $line =~ /background-image/i ) {
		printf LOGFILE (
						 "%d:1 CSS background image 'background-image': %s\n",
						 $count, $line
		);
	}
}
printf LOGFILE ( "\n\n%d:1 Check headers (used to generate table of contents\n" ,1);
$count = 0;
foreach my $line (@book) {
	$count = $count + 1;
	if ( $line =~ /<h(\d)>/ ) {
		printf LOGFILE ( "%d:1" . '     ' x $1 . "%s\n", $count, $line );
	}
}
