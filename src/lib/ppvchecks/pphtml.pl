#!/usr/bin/perl -w

use strict;
use File::Basename;
use Getopt::Long;

# pphtml.pl
# command line version of pphtml.pl
# author: Roger Frank (DP:rfrank)

my $vnum = "1.16";

my @book         = ();
my @css          = ();
my @cssline      = ();
my %classes_used = ();

my $help    = 0;              # set true if help requested
my $srctext = "book.html";    # default source file
my $outfile = "xxx";

my $filename;
my $frm_detail;
my $detailLevel;

usage()
  if (
    !GetOptions(
        'help|?' => \$help,       # display help
        'i=s'    => \$srctext,    # requires input filename if used
        'o=s'    => \$outfile,    # output filename (optional)
    )
    or $help
  );

sub usage {
    print "Unknown option: @_\n" if (@_);
    print "usage: pphtml.pl [-i infile.txt] [-o pphtml.log]\n";
    exit;
}

sub runProgram {
    if ( $outfile eq "xxx" ) {
        $outfile = dirname($srctext) . "/pphtml.log";
    }
    open LOGFILE, "> $outfile" || die "output file error\n";

    # read book a line at a time into the array @book
    open INFILE, $srctext || die "no source file\n";
    my $ln;
    while ( $ln = <INFILE> ) {
        $ln =~ s/\r\n/\n/;
        chomp $ln;
        push( @book, $ln );
    }
    close INFILE;

    # run checks specified in the following call sequence
    &header_check;
    &css_check;
    &specials;

    # close out the program
    ( my $sec, my $min, my $hour, my $mday, my $mon, my $year, my $wday, my $yday, my $isdst ) =
      localtime(time);

    sub header_check {

        #print LOGFILE "Please confirm title is: 'The Project Gutenberg eBook of TITLE, by AUTHOR.\n";
        my $printing = 0;
        my $count    = 0;

        foreach my $line (@book) {
            $count++;
            if ( $line =~ /<title>/ ) {
                $printing = 1;
                printf LOGFILE ( "%d:0 Confirm title:\n", $count );

                #next;
            }
            if ($printing) {
                printf LOGFILE ( "%d:0 %s\n", $count, trim($line) );
            }
            if ( $line =~ /<\/title>/ ) {
                $printing = 0;
            }
        }
    }

    sub specials {
        my ($linenum);

        # Illustration markup
        #
        my $count    = 0;
        my $lastline = "trash";
        foreach my $line (@book) {
            $count = $count + 1;
            if ( $line =~ /\[Illustration/ ) {
                printf LOGFILE ( "%d:0 Unconverted illustration: %s\n", $count, $line );
            }
            if ( $line =~ /<table/
                and ( ( $line !~ /summary/ ) or ( $line =~ /summary=""/ ) ) ) {
                printf LOGFILE ( "%d:0 Missing table summary: %s\n", $count, $line );
            }
            if ( $line =~ /Blank Page/ ) {
                printf LOGFILE ( "%d:0 Blank page\n", $count );
            }
            if ( $line =~ /\[[o|a]e\]/ ) {
                printf LOGFILE ( "%d:0 Unconverted lig: %s\n", $count, $line );
            }
            if ( $line =~ /hr style/ ) {
                printf LOGFILE ( "%d:0 Unconverted HR: %s\n", $count, $line );
            }
            if ( $line =~ /&amp;amp/ ) {
                printf LOGFILE ( "%d:0 Ampersand: %s\n", $count, $line );
            }
            if ( $line =~ /<p>\./ ) {
                printf LOGFILE ( "%d:0 Possible PPG command: %s\n", $count, $line );
            }
            if ( $line =~ /\`/ ) {
                printf LOGFILE ( "%d:0 Tick-mark check: %s\n", $count, $line );
            }
            if ( $line =~ /[^=]''/ ) {
                printf LOGFILE ( "%d:0 Quote problem: %s\n", $count, $line );
            }
            if ( $line =~ /\&#8216;\s/ ) {
                printf LOGFILE ( "%d:0 Left single quote followed by whitespace: %s\n", $count,
                    $line );
            }
            if ( $line =~ /\&#8220;\s/ ) {
                printf LOGFILE ( "%d:0 Left double quote followed by whitespace: %s\n", $count,
                    $line );
            }
            if ( $line =~ /^\&#8221;/ ) {
                printf LOGFILE ( "%d:0 Right double quote at start of line: %s\n", $count, $line );
            }
            if ( $line =~ /<p>\&#8221;/ ) {
                printf LOGFILE ( "%d:0 Right double quote at start of line: %s\n", $count, $line );
            }
            if ( $line =~ /\&#8220;$/ ) {
                printf LOGFILE ( "%d:0 Left double quote at end of line: %s\n", $count, $line );
            }
            if ( $line =~ /\&#8220;<\/p>/ ) {
                printf LOGFILE ( "%d:0 Left double quote at end of line: %s\n", $count, $line );
            }
        }

        printf LOGFILE "Verbose checks:\n";

        # check missing mdashes
        # need to use "--" in alt strings of images
        $count = 0;
        foreach my $line (@book) {
            $count += 1;
            if ( $line =~ /--/
                and ( $line !~ /<!--/ and $line !~ /-->/ and $line !~ /alt=/ ) ) {
                printf LOGFILE ( "  %s\n", $line );
            }
            if ( $lastline =~ /^$/ and $line =~ /^$/ ) {
                printf LOGFILE ( "%d:0 Double-blank\n", $count );
            }
            $lastline = $line;
        }
        printf LOGFILE ( "  *** %d suspected missing mdashes\n", $count );

        foreach $_ (@book) {
            if ( m{\*} && not m{XML} ) {
                printf LOGFILE ( "  asterisk: %s\n", $_ );
            }
        }

        # show lines containing left or right braces (will catch [oe] and [ae] also)
        # and exclude those used in page numbers (or footnotes)
        $count = 0;
        foreach my $line (@book) {
            next if ( $line =~ /XML/ );
            my $savedline = $line;
            $line =~ s=["']>\[=XXX=g;
            $line =~ s=\]<\/=XXX=g;
            if ( $line =~ /[\[\]]/ ) {
                printf LOGFILE ( "  %s\n", $savedline );
                $count += 1;
            }
            $line = $savedline;
        }
        printf LOGFILE ( "  *** %d suspected lines containing left or right braces\n", $count );

        # check for sloppy equal sign placement
        foreach $_ (@book) {
            if (/(= )|( =)/) {
                printf LOGFILE ( "  EQUAL SIGN: %s\n", $_ );
            }
        }
    }

    sub css_check {
        &show_classes;
        &show_styles;
        &css_block;
        &css_crosscheck;
    }

    # show classes used in <body> of text.
    sub show_classes {
        print LOGFILE ("----- classes used -----\n");
        my $intextbody = 0;
        foreach $_ (@book) {
            if ( not $intextbody and not /<body/ ) {
                next;
            }
            $intextbody = 1;

            # special case <h?>
            if (/<(h\d)/) {
                my $h = $1;

                #        $h =~ s/<(h\d).*$/$1/;
                $classes_used{$h} += 1;
            }

            # special case <h?>
            if (/<table/) {
                $classes_used{"table"} += 1;
            }
            if (/<(block[a-z]*)/) {
                my $h = $1;
                $classes_used{$h} += 1;
            }
            if (/<ins/) {
                $classes_used{"ins"} += 1;
            }
            my $x = 0;
            while (/^.*? class=['"]([^'"]+)['"](.*)$/) {
                my $kew = $_;
                my $tmp = $2;
                my @sp  = split( / /, $1 );
                foreach my $t (@sp) {
                    $classes_used{$t} += 1;
                }
                $x = $x + 1;
                $_ = $tmp;

                #        s/class/-----/;
            }
        }

        foreach my $key ( sort { $a cmp $b } ( keys %classes_used ) ) {
            printf LOGFILE ( "- %4d | %s\n", $classes_used{$key}, $key );
        }
    }

    # show styles used in <body> of text.
    sub show_styles {
        print LOGFILE ("----- styles used -----\n");
        my %hash       = ();
        my $intextbody = 0;
        foreach $_ (@book) {
            if ( not $intextbody and not /<body>/ ) {
                next;
            }
            $intextbody = 1;
            while (/style=['"]/) {
                my $tmp = $_;
                s/^.*? style=['"](.*?)['"].*$/$1/;
                $hash{$_} += 1;
                $_ = $tmp;
                s/style/-----/;
            }
        }
        foreach my $key ( keys %hash ) {
            printf LOGFILE ( "- %4d | %s\n", $hash{$key}, $key );
        }
    }

    # Perl trim function to remove whitespace from the start and end of the string
    sub trim($) {
        my $string = shift;
        $string =~ s/^\s+//;
        $string =~ s/\s+$//;
        return $string;
    }

    sub css_block {
        print LOGFILE ("----- CSS block definitions -----\n");
        my @splitcss     = ();
        my @splitcssline = ();    # Keep track of line number where CSS was defined
        my $incss        = 0;
        my $count        = 0;
        foreach $_ (@book) {
            $count++;
            if (/text\/css/) {
                $incss = 1;
            }
            if ( $incss and /<\/style>/ ) {
                $incss = 0;
            }
            if ( $incss and /{/ ) {
                push @css,     $_;
                push @cssline, $count;
            }
        }

        # strip definition
        my $ccount = 0;
        foreach my $idx ( 0 .. $#css ) {
            my $cssdef = $css[$idx];
            my $count  = $cssline[$idx];
            $cssdef =~ s/^(.*?)\{.*$/$1/;
            $cssdef = trim($cssdef);
            my @sp = split( /,/, $cssdef );
            foreach my $t (@sp) {
                printf LOGFILE ( "- %-19s", $t );
                $ccount++;
                if ( $ccount % 4 == 3 ) {
                    print LOGFILE ("\n");
                }
                unshift( @splitcss,     $t );
                unshift( @splitcssline, $count )    # Continue to align CSS array with line number array
            }
        }
        @css     = @splitcss;
        @cssline = @splitcssline;
    }

    sub css_crosscheck {
        print LOGFILE ("----- CSS crosscheck -----\n");
        foreach my $idx ( 0 .. $#css ) {
            my $cssdef = $css[$idx];
            $cssdef =~ s/^.*?\.?([^\. ]+)$/$1/;
            if ( $cssdef =~ /\b(p|body)\b/ ) {
                next;
            }
            my $found = 0;
            foreach my $cssused ( keys %classes_used ) {
                if ( $cssused eq $cssdef ) {
                    $found++;
                }
            }
            if ( not $found ) {
                printf LOGFILE ( "%d:0 CSS possibly not used: %s\n", $cssline[$idx], $cssdef );
            }
        }

        foreach my $cssused ( sort keys %classes_used ) {
            my $found = 0;
            foreach my $cssdef (@css) {
                $cssdef =~ s/^.*?\.?([^\. ]+)$/$1/;

                #        $cssdef =~ s/^.*?\.(.*)$/$1/;
                if ( $cssdef =~ /\b(p)\b/ ) {    #/\b(p|body)\b/ ) {
                    next;
                }
                if ( $cssused eq $cssdef ) {
                    $found++;
                }
            }
            if ( ( not $found ) and ( not $cssused eq "blockquote" ) ) {
                print LOGFILE "+$cssused: CSS possibly not defined\n";
            }
        }

    }
}

# main program
runProgram()
