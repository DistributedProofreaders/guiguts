#!/usr/bin/perl -w

use strict;
use File::Basename;
use Getopt::Long;

# pphtml.pl
# command line version of pphtml.pl
# author: Roger Frank (DP:rfrank)

my $vnum = "1.17";

my @book         = ();
my @css          = ();
my @cssline      = ();
my %classes_used = ();
my %classes_line = ();

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
        my $printing = 0;
        my $count    = 0;

        my $guttitle  = 0;                        # No <title> at all
        my $gutstring = " | Project Gutenberg";
        foreach my $line (@book) {
            $count++;
            if ( $line =~ /<title>/ ) {
                $printing = 1;
                printf LOGFILE ( "%d:0 Confirm title:\n", $count );
                $guttitle = 1;    # <title>, but gutstring not found yet
            }
            if ($printing) {
                printf LOGFILE ( "%d:0 %s\n", $count, trim($line) );
                $guttitle = 2 if $line =~ /\Q$gutstring\E/;    # gutstring found
            }
            if ( $line =~ /<\/title>/ ) {
                $printing = 0;
                last;
            }
        }
        printf LOGFILE ( "%d:0 No <title> field found\n", $count ) if $guttitle == 0;
        printf LOGFILE ( "%d:0 <title> field must end with '%s'\n", $count, $gutstring )
          if $guttitle == 1;
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
        my $count      = 0;
        foreach $_ (@book) {
            $count++;
            if ( not $intextbody and not /<body/ ) {
                next;
            }
            $intextbody = 1;

            my $x = 0;
            while (/^.*? class=['"]([^'"]+)['"](.*)$/) {
                my $tmp = $2;
                my @sp  = split( / /, $1 );
                foreach my $t (@sp) {
                    $classes_used{$t} += 1;
                    $classes_line{$t} = $count unless exists $classes_line{$t};
                }
                $x = $x + 1;
                $_ = $tmp;
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
            $incss = 1 if /<style/;
            last       if ( $incss and /<\/style>/ );

            # Either "{" on same line as class name, or on its own on next line
            if ( $incss and /{/ or $count < $#book and $book[$count] =~ /^\s*{\s*$/ ) {
                push @css,     $_;
                push @cssline, $count;
            }
        }

        # strip definition
        my $ccount = 0;
        foreach my $idx ( 0 .. $#css ) {
            my $cssdef = $css[$idx];
            my $count  = $cssline[$idx];
            $cssdef =~ s/\@media\s+[^\{]+\{//;    # Remove any @media query
            $cssdef =~ s/^(.*?)\{.*$/$1/;         # Remove any declaration block
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

        # Tidy up list of classes defined in CSS
        foreach (@splitcss) {
            s/^.*?\.?([^\. ]+)$/$1/;
            s/:{1,2}first-letter//;
        }
        @css     = @splitcss;
        @cssline = @splitcssline;
    }

    # Warn about classes unless they are used/defined, or ones we want to ignore, or ebookmaker specials
    sub css_crosscheck {
        print LOGFILE ("----- CSS crosscheck -----\n");
        foreach my $idx ( 0 .. $#css ) {
            printf LOGFILE ( "%d:0 CSS possibly not used: %s\n", $cssline[$idx], $css[$idx] )
              unless classisknown( $css[$idx], keys %classes_used );
        }
        foreach my $cssused ( sort keys %classes_used ) {
            printf LOGFILE ( "%d:0 CSS possibly not defined: %s\n", $classes_line{$cssused},
                $cssused )
              unless classisknown( $cssused, @css );
        }
    }

    # Return true if class/element is in given list (i.e. used/defined)
    # or if it's one we want to ignore, or it's a special ebookmaker class
    sub classisknown {
        my $class = shift;
        my @list  = shift;
        return (
            grep      { $_ eq $class } @list                                                       # class is used/defined
              or grep { $_ eq $class } qw(a blockquote body h1 h2 h3 h4 h5 h6 hr img ins p table)  # ignore these element names
              or $class =~ /^x-ebookmaker/                                                         # special ebookmaker class
        );
    }
}

# main program
runProgram()
