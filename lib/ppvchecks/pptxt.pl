#!/usr/bin/perl -w

use strict;
use File::Basename;
use Getopt::Long;

# pptxt.pl
# author: Roger Frank (DP:rfrank)
# Copyright (C) 2009, Asylum Computer Services LLC
# Licensed under the MIT license:
# http://www.opensource.org/licenses/mit-license.php
# last edit: 03-Sep-2009 10:41 PM

my $vnum  = "1.19k";

my (@book, @para);
my $outfile = "xxx";

my $help     = 0;                   # set true if help requested
my $srctext = "book.txt";           # default source file
my $filename;
my $frm_detail;
my $detailLevel;

usage()
    if (
    !GetOptions(
        'help|?'  => \$help,        # display help
        'i=s'     => \$srctext,     # requires input filename if used
        'o=s'     => \$outfile,     # output filename (optional)
    )                               
    or $help
    );
    
sub usage {
    print "Unknown option: @_\n" if (@_);
    print "usage: pptxt.pl [-i infile.txt] [-o pptxt.log]\n";
    exit;
}
    
sub runProgram {
  @book = ();
  @para = ();
   
  # read book a line at a time into the array @book
  if ( not -e $srctext ) {
        print( "no source file: " . $srctext . "\n" );
        exit;
  }   
  if ($outfile eq "xxx") {
     $outfile = dirname($srctext)."/pptxt.log";
  }

  open LOGFILE,"> $outfile" || die "output file error\n";
   
  print LOGFILE "processing $srctext to $outfile\n\n";
  printf LOGFILE ("%s\n", "-" x 80);
   
 
  open INFILE, $srctext;

  my ($ln, $tmp);
  while ($ln = <INFILE>) {
    $ln =~ s/\r\n/\n/;
    chomp $ln;
    push(@book, $ln);
  }
  close INFILE ;

  # read the book again, this time a paragraph at a time.
  @para = ();
  open INFILE,$srctext;

  $tmp = "";
  while ($ln = <INFILE>) {
    $ln =~ s/\r\n/\n/;
    chomp $ln;
    if (length $ln == 0) {
      if (length $tmp > 0) {
        push(@para, $tmp);
        $tmp = "";
      }
    }
    if (length $ln > 0) {
      $ln = " ".$ln;
    }
    $tmp = $tmp.$ln;
  }
  if (length $tmp > 0) {
    push(@para, $tmp);
  }
  
  # run checks specified in the following call sequence
  &asterisk_check;
  &adjacent_spaces;
  &trailing_spaces;
  &wierd_characters;
  &spacing_check;
  &linelength_check;
  &double_word;
  &html_checks;
  &ellipsis_review;
  &dash_review;
  &scanno_check;
  # &poetrybq_checks;
  # &ampm_checks;
  &quote_checks;
  &had_bad;  
  &specials;
  
  (my $sec, my $min, my $hour, my $mday, my $mon,
    my $year, my $wday, my $yday, my $isdst) = localtime(time);
  printf LOGFILE ("\n%s\n", "=" x 80);
  printf LOGFILE "run completed: %4d-%02d-%02d %02d:%02d:%02d\n",
    $year+1900,$mon+1,$mday,$hour,$min,$sec; 
  close LOGFILE; 	
}

# scan book for two or more adjacent spaces on a line that
# does not start with a space
sub adjacent_spaces {
  print LOGFILE "adjacent spaces check\n";
  my($adjsp_count) = 0;
  my $lc = 0;
  foreach my $line (@book) {
    $lc++;
    if ($line =~ /  / and $line !~ /^\s/) {
      $adjsp_count += 1;
      printf LOGFILE ("line %d:1 %s\n", $lc, $line);
    }
  }
  if ($adjsp_count > 0) {
    printf LOGFILE ("  %d lines with adjacent spaces\n", $adjsp_count);
  }
  else {
    printf LOGFILE ("  no lines with adjacent spaces found.\n");
  }
  printf LOGFILE ("%s\n", "-" x 80);
}

# scan book for trailing spaces
sub trailing_spaces {
  print LOGFILE "trailing spaces check\n";
  my($trailsp_count) = 0;
  my $lc = 0;
  foreach my $line (@book) {
    $lc++;
    if ($line =~ / $/) {
      $trailsp_count += 1;
      printf LOGFILE ("  line %4d: %s\n", $lc, $line);
    }
  }
  if ($trailsp_count > 0) {
    printf LOGFILE ("  %d lines with trailing spaces\n", $trailsp_count);
  }
  else {
    printf LOGFILE ("  no lines with trailing spaces found.\n");
  }
  printf LOGFILE ("%s\n", "-" x 80);
}

# wierd characters check
# gather them, by line, then sort and save to log
sub wierd_characters {
  print LOGFILE "unusual characters check\n";
  my $ebcheck = 0;
  my(@wierdlist, @sortlist, $oddchars);
  @wierdlist = ();
  @sortlist = ();
  foreach my $line (@book) {
    if ($line !~ /^[a-zA-Z0-9 .,?!:;\"\'_-]*$/) {
      $oddchars = "";
      for (my $i=0; $i<length $line; $i++) {
        if (substr ($line, $i, 1) !~ /^[a-zA-Z0-9 .,?!:;\"\'_-]*$/ ) {
          if ( substr($line, $i, 2) eq "&c" ) {
            $ebcheck++;
          } else {
            $oddchars = $oddchars . substr ($line, $i, 1);
          }
        }
      }
      if ( length $oddchars > 0 ) {
        push(@wierdlist, sprintf("%10s | %s\n", $oddchars, $line));
      }
    }
  }
  @sortlist = sort(@wierdlist);
  foreach my $line (@sortlist) {
    print LOGFILE $line;
  }
  printf LOGFILE ("\n");
  if ( $ebcheck > 0 ) {
     printf LOGFILE ("&c (EB check) count: %d\n", $ebcheck);
  }
  printf LOGFILE ("%s\n", "-" x 80);
}

# blank line spacing check
sub spacing_check {
  print LOGFILE "line spacing check\n";
  my($consec_blank_lines) = 0;
  my($print_entries) = 0;
  foreach my $line (@book) {
    if (length $line == 0) {
      $consec_blank_lines += 1;
    }
    else {
      if ($consec_blank_lines > 0) {
        # if we see three or more, it's the start of another text division
        if ($consec_blank_lines >=3) {
          # if we had at least 20, show there are more with trailing ellipsis
          if ($print_entries >= 40) {
            printf LOGFILE ("...");
          }
          # either way, start a new line
          printf LOGFILE ("\n");
          $print_entries = 0;
        }
        if ($print_entries == 0) {
          print LOGFILE "  ";
        }
        if ($print_entries < 40 or $consec_blank_lines != 1) {
          printf LOGFILE ("%d ", $consec_blank_lines);
        }
        $consec_blank_lines = 0;
        $print_entries += 1;
      }
    }
  }
  printf LOGFILE ("\n");
  printf LOGFILE ("%s\n", "-" x 80);
}

# line length check
sub linelength_check {
  print LOGFILE "line length check\n";
  
  # find the start postition of text and line length of each line in the file
  my @lineld;   # leading space count, per line
  my @lineln;   # line length, per line
  foreach my $line (@book) {
    $_ = $line;
    my $leadsp = 0;
    while ( /^ / ) {
        s/^ (.*)/$1/;
        $leadsp++;
    };
    push(@lineld, $leadsp); 
    push(@lineln, length $line); 
  }       

  # find short line that does not end a paragraph and is not in poetry or bq.
  # find longest line of text.
  my $shortlen = 1000;
  my $longlen = 0;
  my $shortln=0; my $longln=0;
  for (my $lc = 0; $lc <= $#lineld-2; $lc++) {
      if ($lineln[$lc] > $longlen) {
          $longln = $lc;
          $longlen = $lineln[$lc];
      }
      if ($lineln[$lc] > $lineln[$lc+1] and $lineln[$lc+1] < $lineln[$lc+2]
         and $lineln[$lc+1] > 0 and $lineld[$lc+1] == 0) {
          if ($lineln[$lc+1] < $shortlen) {
              $shortlen = $lineln[$lc+1];
              $shortln = $lc + 1;
          }
      }
  }
  # user's idea of line numbers start at 1, not 0
  printf LOGFILE ("  longest line %d at line %d\n", $longlen, $longln+1);
  printf LOGFILE ("  shortest line %d at line %d\n", $shortlen, $shortln+1);
  printf LOGFILE ("%s\n", "-" x 80);
}

# scan book for superfluous asterisks
sub asterisk_check {
  print LOGFILE "asterisk check\n";
  my($ast_count) = 0;
  foreach my $line (@book) {
    if ($line =~ /\*       \*       \*       \*       \*$/) {
      next;
    }
    if ($line =~ /\*/) {
      if ($ast_count == 0) {
        printf LOGFILE ("%s\n", "-" x 80) ;
      }
      $ast_count += 1;
      printf LOGFILE ("  %s\n", $line);
    }
  }
  if ($ast_count > 0) {
    printf LOGFILE ("%d lines contain an expected asterisk\n", $ast_count);
  }
  else {
    printf LOGFILE ("  no unexpected asterisks found in text.\n");
  }
  printf LOGFILE ("%s\n", "-" x 80);
}

# had/bad error
sub had_bad {
  print LOGFILE "had/bad check\n";
  foreach my $p (@para) {
      my $p1 = $p;
      if ($p1 =~ /(\W+\w+\W+)(s?he\W+)(bad)(\W+\w+\W+)/) {
          printf LOGFILE ("%s\n", $1.$2.$3.$4)
      }
  }
  printf LOGFILE ("%s\n", "-" x 80);
}

# repeated word checks rely on the array of paragraphs.
sub double_word {
  print LOGFILE "repeated word check\n";
  my $reported = 0;
  foreach my $p (@para) {
    my $p1 = $p;
    
    # thought break asterisk not repeated word
    next if $p1 =~ /\*\s+\*/;  
    
    $p =~ s/--/ /g;
    $p =~ s/[;\.!"\?\)\(]/ /g;
    $p =~ s/ +/ /g;
    my @a = split(/ /, $p.lc);
    # shift(@a);
    my $last = "";
    my $offset = 0;
    foreach my $w (@a) {
        if ( $w =~ /[\.\?\+\[\]]/ ) {
          $last = "";
          next;
        }
        if ($w eq $last and length $w > 0) {
            print LOGFILE ("  ");
            $reported = 0;        
                     
            if ($p1 =~ /(\w+\W+)($last.?.?$w)$/) {
                printf LOGFILE ("%s\n", $1.$2);
                $reported = 1;
            }
            
            if ($p1 =~ /^($last.?.?$w)(\W+\w+)/) {
                printf LOGFILE ("%s\n", $1.$2);
                $reported = 1;
            }
            
            if ($p1 =~ /(\w+\W+)($last.?.?$w)(\W+\w+)/) {
                printf LOGFILE ("%s\n", $1.$2.$3);
                $reported = 1;
            }   
            
            if (!$reported) {
              printf LOGFILE ("repeated: \"%s\" in paragraph starting %s\n", $w, substr $p1,0, 40);
            }
         }
      $last = $w;
      $offset += 1;
    }
  }
  printf LOGFILE ("%s\n", "-" x 80);
}

# quote_checks
sub quote_checks {
  print LOGFILE "quote mark check\n";
  my($checknext, $openquot, $startpos, $endpos, $i, $quot_cnt, $lastchar, $thischar, $length);
  foreach my $p (@para) {
    $quot_cnt = 0;
    for ($i = 0; $i < length $p; $i++) {
      $thischar = substr($p,$i,1);
      if ($checknext) {
        # we've just seen an opening double quote. check next character
        if ($openquot and $thischar eq " ") {
           $startpos = $i - 20 < 0 ? 0 : $i - 20;
           while ($startpos > 0 and substr($p,$startpos,1) ne " ") {
             $startpos--;
           }
           $endpos = $i + 20 > length $p ? length $p : $i + 20;
           while ($endpos < length $p and substr($p,$startpos,1) ne " ") {
             $endpos++;
           }          
           $length = $endpos - $startpos + 1;
           printf LOGFILE "%10s | %s\n", "misplaced", substr($p,$startpos,$length);
        }
        # allow special characters following a quotation
        if (not $openquot 
           and $thischar ne " "     # commonly followed by a space
           and $thischar ne "["     # start of a footnote
           and $thischar ne "]"     # end of a quoted illustration caption           
           and $thischar ne ")"     # close of a parenthesised quote          
           and $thischar ne "-") {  # hyphen as a space
           $startpos = $i - 20 < 0 ? 0 : $i - 20;
           while ($startpos > 0 and substr($p,$startpos,1) ne " ") {
             $startpos--;
           }
           $endpos = $i + 20 > length $p ? length $p : $i + 20;
           while ($endpos < length $p and substr($p,$startpos,1) ne " ") {
             $endpos++;
           }          
           $length = $endpos - $startpos + 1;
           printf LOGFILE "%10s | %s\n", "misplaced", substr($p,$startpos,$length);
        }
        $checknext = 0;
      }
      if( substr($p,$i,1) eq "\"" ) {
        $openquot = ($quot_cnt % 2 == 0);
        $checknext = 1;
        $quot_cnt += 1;
        # we're on a double quote. look at previous character
        if ($openquot
          and $lastchar ne ""       # no last character
          and $lastchar ne "-"      # hyphen as space
          and $lastchar ne "("      # quote in parenthesis
          and $lastchar ne " ") {   # commonly preceeded by a space

           $startpos = $i - 20 < 0 ? 0 : $i - 20;
           while ($startpos > 0 and substr($p,$startpos,1) ne " ") {
             $startpos--;
           }
           $endpos = $i + 20 > length $p ? length $p : $i + 20;
           while ($endpos < length $p and substr($p,$startpos,1) ne " ") {
             $endpos++;
           }          
           $length = $endpos - $startpos + 1;
           printf LOGFILE "%10s | %s\n", "misplaced", substr($p,$startpos,$length);
           $checknext = 0;
        }
        if (not $openquot and $lastchar ne "" and $lastchar eq " ") {
           $startpos = $i - 20 < 0 ? 0 : $i - 20;
           while ($startpos > 0 and substr($p,$startpos,1) ne " ") {
             $startpos--;
           }
           $endpos = $i + 20 > length $p ? length $p : $i + 20;
           while ($endpos < length $p and substr($p,$startpos,1) ne " ") {
             $endpos++;
           }          
           $length = $endpos - $startpos + 1;
           printf LOGFILE "%10s | %s\n", "misplaced", substr($p,$startpos,$length);
           $checknext = 0;
        }
      }
      $lastchar = $thischar;
    }
    # done with the paragraph. verify even number of quote marks.
    if ($quot_cnt % 2 != 0) {
      my $endpos = 50;
      if ($endpos > length $p) {
        $endpos = length $p;
      } else {
        while ($endpos < length $p and substr($p,$endpos,1) ne " ") {
          $endpos++; 
        }
      }
      printf LOGFILE "%10s | %s....\n", "count", substr($p,0,$endpos);
    }
  }
  printf LOGFILE ("%s\n", "-" x 80);
}

# look for abandoned HTML tags
sub html_checks {
  print LOGFILE "abandoned HTML tags\n";
  my $errcnt = 0;
  foreach my $line (@book) {
    if ($line =~ /\<[a-zA-Z]+\>/ or $line =~ /\<\/[a-zA-Z]+\>/) {
      print LOGFILE "  $line\n";
      $errcnt++;
    }
  }
  if ($errcnt == 0) {
    print LOGFILE "  no HTML tags found in text.\n";
  } 
  printf LOGFILE ("%s\n", "-" x 80);
}

# ellipsis review
sub ellipsis_review {
  print LOGFILE "ellipsis review\n";
  my $ellcnt = 0;
  foreach my $line (@book) {
    if ($line =~ /\.\./) {
      print LOGFILE "  $line\n";
      $ellcnt++;
    }
  }
  if ($ellcnt == 0) {
    print LOGFILE "  no ellipsis found in text.\n";
  }
  printf LOGFILE ("%s\n", "-" x 80);
}

# dash review
sub dash_review {
  print LOGFILE "dash review\n";
  my($nsuspects, $hypdash);
  $nsuspects = $hypdash = 0;
  foreach my $line (@book) {
    if ($line =~ /- / or $line =~ / -/) {
      printf LOGFILE ("* %s\n", $line);
      $nsuspects += 1;
    }
    if ($line =~ /[^-]---[^-]/ || $line =~ /[^-]---$/) {
      printf LOGFILE ("# %s\n", $line);
      $nsuspects += 1;
    }
    if ($line =~ /--/) {
      $hypdash += 1;
    }
  }
  if ($nsuspects == 0) {
    printf LOGFILE ("  %d hyphen/dashes, no suspects\n", $hypdash);
    } else {
      printf LOGFILE ("  %d hyphen/dashes, %d suspects\n", $hypdash, $nsuspects);
    }
    printf LOGFILE ("%s\n", "-" x 80);
  }

  # common scanno words check
  # note: common scannos 'he|be', 'be|he', 'is|as' are not automatically checked.
  # use jeebies for specific he/be checks.
  sub scanno_check {
    print LOGFILE "common scanno check\n";
    my @scannolist = ();

    my @sl = ('lie', 'arid', 'yon', 'bad', 'tip', 'tho', 'arc', 'hut',
    'tiling', 'bat', 'Ms', 'tune', 'coining', 'tor', 'hack', 'tie',
    'tinder', 'ail', 'tier', 'fee', 'die', 'docs', 'lime', 'ease',
    'ray', 'ringers', 'fail', 'bow', 'clay', 'borne', 'modem', 'cast',
    'bar', 'bear', 'cheek', 'carnage', 'boon', 'car', 'band', 'ball',
    'carne', 'tile', 'ho', 'bo', 'tight', 'bit', 'wen', 'haying',
    'rioted', 'cat', 'tie', 'ringer', 'ray', 'loth', '1', 'comer',
    'cat', 'tram', 'bumbled', 'bead', 'beads', 'hi', 'ho', 'bach', 'tunes');

    my @sl_pre1923 = ("Banged", "banger", "Breams", "carnages", "celling",
    "clanger", "has-relief", "hex", "hitman", "hooka","Iamb", "nans",
    "Or,", "PUKE", "ratter", "SACKED", "Spam", "GOO", "Ids",
    "FOB", "ml.", "Mm", "oilier", "Ms", "lier", "tilings", "docs",
    "denned", "aa", "eon", "bo", "sonic", "ABE", "Prance", "clone",
    "baud", "BO", "OP", "euro", "mom", "hi", "ip", "ID", "Bather",
    "mall", "V'", "Beading", "oiler", "TUB", "fanner", "alt", "email",
    "ail", "appeal's", "Tier", "winch", "BOW", "TEX", "mads", "Primed",
    "tor", "baa", "Prom", "tiling", "conies", "seances", "Hue", "teen",
    "arid", "natter", "tipper", "fax", "rilled", "mil", "tine",
    "carne", "modem", "Rut", "eases", "Ami", "FOE", "titan", "rattier",
    "Icings", "parsed", "Borne", "tho", "OK", "j", "AH", "scat", "Hie",
    "PACK", "Ac", "gays", "ms", "Tightness", "nil", "MEW", "OS",
    "lores", "hitter", "ho", "stilt", "gnus", "vet", "arc", "Twos",
    "verifiable", "tad", "/'", "gel", "BOOK", "fending", "bur", "info",
    "ft", "Thai", "eave", "gamed", "Rerun", "loots", "Bat", "OX",
    "dement", "Gist", "lather", "Urn", "Jet", "nickered", "thai",
    "Signer", "readied", "easting", "TEAR", "nicker", "hone", "eves",
    "Hew", "persona", "coining", "TV", "welt", "oat", "tins", "tome",
    "porn", "Cue", "HAKE", "fetal", "Due", "fie", "Id", "yon", "Mile",
    "laud", "Pact", "clement", "Pans", "ringers", "fiat", "flay",
    "sec", "chanty", "awl", "bis", "haying", "ding", "nib", "groat",
    "CHARTER", "tare", "gram", "abort", "mt", "helium", "lint", "Bide",
    "bat", "Toe", "bum", "rick", "anal", "whore", "pare", "hare",
    "ostentations", "roe", "Eke", "rums", "surfer", "minder", "faking",
    "elopes", "Outs", "tinder", "hack", "foil", "Pie", "Tin", "tee",
    "Jaw", "Agues", "Bate", "tile", "Hose", "fen", "Pox", "fad",
    "mined", "ringer", "tut", "wag", "OWE", "Mend", "whoa", "Bought",
    "ton", "Eves", "patty", "wen", "hist", "Bast", "Ken", "trill",
    "tier", "vas", "Rive", "lilted", "passible", "IS", "moat", "ban",
    "coiner", "Pate", "cur", "Bays", "urn", "mot", "loth",
    "deliriously", "fin", "mat", "Hiss", "duets", "slated", "harry",
    "fake", "formers", "Brawn", "poof", "nudes", "CHATTER", "assort",
    "Sips", "righting", "clown", "loft", "flue", "Tour", "eared",
    "hest", "tire", "lauds", "clays", "sue", "mam", "Bound", "ray",
    "Airs.", "dutch", "nagged", "hushes", "Teachings", "Arable", "fee",
    "bead", "grout", "hoard", "parries", "lull", "Jay", "Pea", "aft",
    "ramie", "menus", "Surd", "Hushing", "sot", "riot", "oases", "cad",
    "gee", "Bed", "tilled", "oar", "tames", "cue", "rook", "straggle",
    "tally", "Tract", "rill", "Yak", "dosing", "lone", "skew",
    "bonding", "tilt", "fife", "thorn", "Hum", "Lot", "frustrations",
    "vended", "burred", "hag", "lees", "Boot", "Bach", "sadden",
    "fads", "rue", "diem", "Ill", "hind", "bailing", "mow", "Pair",
    "primes", "aide", "wan", "oft", "polities", "tittered", "tram",
    "nave", "Tack", "Iris", "snore", "Pacing", "dubs", "Mold", "guru",
    "slimmer");

    my %hash = ();

    foreach my $w (@sl) {
#kew      $hash{$w} = 1;
    }
    foreach my $w (@sl_pre1923) {
      $hash{$w} = 1;
    }

    foreach my $line (@book) {
      foreach my $key (keys %hash) {
        if ( $line =~ /\b$key\b/) {
          # print "$key = $hash{$key};"
          $line =~ s/$key/[$key]/;
          push(@scannolist, sprintf("%10s | %s\n", $key, $line));
        }
      }
    }
    my @sortlist = sort(@scannolist);
    foreach my $line (@sortlist) {
      print LOGFILE $line;
    }
    printf LOGFILE ("\n");
    printf LOGFILE ("%s\n", "-" x 80);
  }

  # poetry/block quote checks
  sub poetrybq_checks {
    print LOGFILE "poetry/blockquote check\n";
    # unusual blocks:
    # - blank line followed by two short lines at left margin (prob. error)
    # - blank line followed by two or more indented lines

    # find the start postition of text and line length of each line in the file
    my @lineld;   # leading space count, per line
    my @lineln;   # line length, per line
    foreach my $line (@book) {
      $_ = $line;
      my $leadsp = 0;
      while ( /^ / ) {
          s/^ (.*)/$1/;
          $leadsp++;
      };
      push(@lineld, $leadsp); 
      push(@lineln, length $line); 
    }       
    
    # find where the text starts so we don't interpret title page as poetry
    my $lc = 0;
    my $ccount = 0;
    my $txtstart = -1;
    for ($lc = 0; $lc <= $#lineld; $lc++) {
        if ($lineld[$lc] == 0 and $lineln[$lc] > 60) {
            $ccount++;
        } else {
            $ccount = 0;
        }
        if ($ccount == 3) {
            $txtstart = $lc - 2;
            last;
        }
    }
    # print "text starts at line ".$txtstart."\n";

    my $indentlncnt = 0;
    my ($ibstart, $ibend);
    for ($lc = 0; $lc <= $#lineld; $lc++) {
      # thought breaks excluded from poetry checks
      my $acount = 0;
      $_ = $book[$lc];
      while (/\*/g) { $acount++; }
      next if ($acount == 5);
      if ($lineld[$lc] > 0 and $lineln[$lc] > $lineld[$lc]) {
        # have an indented line
        $indentlncnt++;
        if ($indentlncnt == 1) {
          $ibstart = $lc + 1;
          # printf ("indented block starts at line %d\n", $lc+1);
        }
      }
      # see if we're out of the poetry block
      my $outofblock = 0;
      # at end of file
      $outofblock = 1 if ($lc == $#lineln );
      # one regular line, then EOF
      $outofblock = 1 if (($lineld[$lc] == 0 and $lineln[$lc] > 0 ) and ($lc+1 == $#lineln));
      # two regular lines
      $outofblock = 1 if ($lc < $#lineln
                          and ($lineld[$lc] == 0 and $lineln[$lc] > 0)
                          and ($lineld[$lc+1] == 0 and $lineln[$lc+1] > 0));
      # one regular line, then a blank line.
      $outofblock = 1 if ($lc < $#lineln
                          and ($lineld[$lc] == 0 and $lineln[$lc] > 0)
                          and $lineln[$lc+1] == 0);                          
      if ( $indentlncnt > 0 and $outofblock ) {
          # printf ("indented block ends at line %d\n", $lc-1);
          $ibend = $lc - 1;
          $indentlncnt = 0;
          printf LOGFILE ("  indented block lines %d-%d\n", $ibstart, $ibend);
      }      
    }    
    printf LOGFILE ("%s\n", "-" x 80);
  }

  # AM/PM consistency check
  sub ampm_checks {
    print LOGFILE "AM/PM consistency check\n";
    my $ampmcnt = 0;
    foreach my $line (@book) {
      if ($line =~ /[AaPp]\.\s*[Mm]\./) {
        $ampmcnt++;
        my $t = $line;
        $t =~ s/^.*?(\d+\s[AaPp]\.\s*[Mm]).*$/$1/;
        printf LOGFILE "%10s | %s\n", $t, $line;
      }
    }
    # now check for degenerate cases
    for (my $lc = 0; $lc < @book-1; $lc++) {
      if ($book[$lc] =~ /[AaPp]\.$/ and $book[$lc+1] =~ /^[Mm]\./) {
        printf LOGFILE "     wrap? | %s\n           | %s\n", $book[$lc], $book[$lc+1];
        $ampmcnt++;
      }
    }
    if ($ampmcnt == 0) {
      print LOGFILE "  AM/PM not found in text.\n";
    }    
    printf LOGFILE ("%s\n", "-" x 80);
  }

  # specials
  # little things that go bump in the night
  sub specials {
    print LOGFILE "special situations check\n";
    my $errcnt = 0;
    my ($line);
    foreach $line (@book) {
        
      if ($line =~ /,1\d\d\d/ ) {
        printf LOGFILE "          date format |  %s\n", $line;
        $errcnt++;
      }
      
      if ($line =~ /\s+"\s+/) {
        printf LOGFILE "floating double quote |  %s\n", $line;
        $errcnt++;
      }
      if ($line =~ /I"/) {
        printf LOGFILE "            I/! check |  %s\n", $line;
        $errcnt++;        
      }
      if ($line =~ / n't | 've | 'll | 'm /) {
        printf LOGFILE "           disjointed |  %s\n", $line;
        $errcnt++;        
      }
      if ($line =~ /Blank Page/) {
        printf LOGFILE "           blank page |  %s\n", $line;        
        $errcnt++;        
      }      
      
      if ($line =~ /(Mr,)|(Mrs,)|(Dr,)/) {
        printf LOGFILE "                title |  %s\n", $line;        
        $errcnt++;        
      }      
      
      # comma check group
      if ($line =~ /[a-zA-Z_],[a-zA-Z_]/ ) { 
        printf LOGFILE "          comma check |  %s\n", $line;
        $errcnt++;        
      }
      if ($line =~ /\s,\D/) { 
        printf LOGFILE "          comma check |  %s\n", $line;
        $errcnt++;        
      }
      if ($line =~ /\s,\s/) { 
        printf LOGFILE "          comma check |  %s\n", $line;
        $errcnt++;        
      }
      if ($line =~ /\d, \d/) {
        printf LOGFILE "          comma check |  %s\n", $line;
        $errcnt++;        
      }
      if ($line =~ /\s,$/) {
        printf LOGFILE "          comma check |  %s\n", $line;
        $errcnt++;        
      }
      if ($line =~ /^,/) { 
        printf LOGFILE "          comma check |  %s\n", $line;
        $errcnt++;        
      }  

      if ($line =~ /^\.[a-z][a-z]/) { 
        printf LOGFILE "     ppg directive? |  %s\n", $line;
        $errcnt++;        
      }  

      if ($line =~ /\`/) {
        printf LOGFILE "      tick-mark check |  %s\n", $line;
        $errcnt++;
      }

      if ($line =~ /''/) {
        printf LOGFILE "      bad quote marks |  %s\n", $line;
        $errcnt++;
      }

      # miscapitalization
      if ($line =~ /[a-z]'[A-Z]/) { 
        printf LOGFILE "   miscapitalization? |  %s\n", $line;
        $errcnt++;        
      }   

      # duplicate italics/bold
      if ($line =~ /_ ?_/) { 
        printf LOGFILE "   doubled italics? |  %s\n", $line;
        $errcnt++;        
      }
      if ($line =~ /= ?=/) { 
        printf LOGFILE "   doubled bold? |  %s\n", $line;
        $errcnt++;        
      }
    }

    # spacey-quotes per papeters
        
    for (my $lc = 0; $lc < @book-1; $lc++) {
      if ( $book[$lc] =~ / " /) {
        printf LOGFILE "         spacey quote |  %s\n", $book[$lc];        
        $errcnt++;  
      }   
      if ( $book[$lc] =~ /^" /) {
        printf LOGFILE "         spacey quote |  %s\n", $book[$lc];        
        $errcnt++;  
      }   
      if ( $book[$lc] =~ / "$/) {
        printf LOGFILE "         spacey quote |  %s\n", $book[$lc];        
        $errcnt++;  
      }   
            if ( $book[$lc] =~ / ' /) {
        printf LOGFILE "         spacey quote |  %s\n", $book[$lc];        
        $errcnt++;  
      }   
      if ( $book[$lc] =~ /^' /) {
        printf LOGFILE "         spacey quote |  %s\n", $book[$lc];        
        $errcnt++;  
      }   
      if ( $book[$lc] =~ / '$/) {
        printf LOGFILE "         spacey quote |  %s\n", $book[$lc];        
        $errcnt++;  
      }  
      
      if ( $book[$lc] =~ /[A-Z0-9]---+[a-z]/) {
        printf LOGFILE "         dash space?  |  %s\n", $book[$lc];        
        $errcnt++;  
      } 
      
      if ( $book[$lc] =~ /Mr,|Mrs,|Dr,/) {
        printf LOGFILE "         abbreviation |  %s\n", $book[$lc];        
        $errcnt++;  
      }       
      
      if ( $book[$lc] =~ /^'( ll | m | ve | d )\s/x ) {
        printf LOGFILE "      disjoint punct? |  %s\n", $book[$lc];        
        $errcnt++;  
      }       
      
    }
    
    if ($errcnt == 0) {
      print LOGFILE "  no special checks failed.\n";
    }
    printf LOGFILE ("%s\n", "-" x 80);
}

# main program
runProgram();

