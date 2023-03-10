package Guiguts::ReflowGG;
require 5.005_62;
use strict;
use warnings;
use integer;
use Carp;

BEGIN {
    use Exporter();
    our ( @ISA, @EXPORT );
    @ISA    = qw(Exporter);
    @EXPORT = qw( &reflow_string );
}

# ReflowGG based on Text::Reflow, with some modifications,
# especially for the way we want to handle dashes.
# https://metacpan.org/pod/Text::Reflow
# Subsequently modified further to pass arguments as Perl arrays
# rather than converting to hex with pack & unpack (the original
# had to be able to pass arguments to a C XSUB).
# Also reflow_file and reflow_array removed since unused.

# Original Reflow script written by Michael Larsen, larsen@edu.upenn.math
# Modified by Martin Ward, martin@gkc.org.uk
# Copyright 1994 Michael Larsen and Martin Ward
# Email: martin@gkc.org.uk
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of either the Artistic License or
# the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#

# This is the perl version of the C function reflow_trial

sub reflow_trial($$$$$$$) {
    my ( $optimum, $maximum, $wordcount, $penaltylimit, $word_len, $space_len, $best_linkbreak ) =
      @_;
    my ( $lastbreak,      @linkbreak );
    my ( $j,              $k, $interval, $penalty, @totalpenalty, $bestsofar );
    my ( $best_lastbreak, $opt );
    my $best = $penaltylimit * 21;
    foreach $opt (@$optimum) {
        @linkbreak = ();
        for ( $j = 0 ; $j < $wordcount ; $j++ ) {    # Optimize preceding break
            $interval = 0;
            $totalpenalty[$j] = $penaltylimit * 2;
            for ( $k = $j ; $k >= 0 ; $k-- ) {
                $interval += $word_len->[$k];
                last
                  if (
                    ( $k < $j )
                    && (   ( $interval > $opt + 10 )
                        || ( $interval >= $maximum ) )
                  );
                $penalty = ( $interval - $opt ) * ( $interval - $opt );
                $interval += $space_len->[$k];
                $penalty  += $totalpenalty[ $k - 1 ] if ( $k > 0 );
                if ( $penalty < $totalpenalty[$j] ) {
                    $totalpenalty[$j] = $penalty;
                    $linkbreak[$j]    = $k - 1;
                }
            }
        }
        $interval  = 0;
        $bestsofar = $penaltylimit * 20;
        $lastbreak = $wordcount - 2;

        # Pick a break for the last line which gives
        # the least penalties for previous lines:
        for ( $k = $wordcount - 2 ; $k >= -1 ; $k-- ) {    # Break after k?
            $interval += $word_len->[ $k + 1 ];
            last if ( ( $interval > $opt + 10 ) || ( $interval > $maximum ) );
            if ( $interval > $opt ) {                      # Don't make last line too long
                $penalty = ( $interval - $opt ) * ( $interval - $opt );
            } else {
                $penalty = 0;
            }
            $interval += $space_len->[ $k + 1 ];
            $penalty  += $totalpenalty[$k] if ( $k >= 0 );
            if ( $penalty <= $bestsofar ) {
                $bestsofar = $penalty;
                $lastbreak = $k;
            }
        }

        # Save these breaks if they are an improvement:
        if ( $bestsofar < $best ) {
            $best_lastbreak  = $lastbreak;
            @$best_linkbreak = @linkbreak;
            $best            = $bestsofar;
        }
    }    # Next $opt
    return ($best_lastbreak);
}

use vars qw(
  $lastbreak     @output        $maximum    %keys
  @space_len     @tmp           @from	    @to
  $indent1       $optimum	    @linewords	@word_len
  $indent2       $penaltylimit  @linkbreak	@words
  $pin	         $wordcount     @optimum
);

# The following parameters can be twiddled to taste:

%keys = (
    optimum => '.*',
    maximum => '\d+',
    indent1 => '.*',
    indent2 => '.*',
);

$optimum      = [65];        # Best line length 65.  Also try [60..70]
$maximum      = 75;          # Maximum possible line length 80
$indent1      = "";          # Indentation for first line
$indent2      = "";          # Indentation for each line after the first
                             # before the group of lines will be skipped
$penaltylimit = 0x2000000;
$pin          = " ";         # minimum indent indicating poetry

# NB By default there must be two consecutive indented lines for it to count
# as poetry, so the program will not mistake a paragraph indentation
# for a line of poetry.

#
# Rewraps the given string
sub reflow_string($@) {
    my ( $input, @opts ) = @_;

    # Create the array from the string, keep trailing empty lines.
    # We split on newlines and then restore them, being careful
    # not to add an extra newline at the end:
    local @from = split( /\n/, $input, -1 );
    pop(@from) if ( $#from >= 0 and $from[$#from] eq "" );
    @from = map { "$_\n" } @from;
    local @to = ();
    process_opts(@opts);
    reflow();
    return ( join( "", @to ) );
}

#
# Process the keyword options, set module global variables as required
sub process_opts(@) {
    my @opts = @_;
    my ( $key, $value );
    no strict 'refs';

    while (@opts) {
        $key = shift(@opts);
        croak "No value for option key `$key'" unless (@opts);
        $value = shift(@opts);
        croak "`$key' is not a valid option" unless ( $keys{$key} );
        croak "`$value' is not a suitable value for `$key'"
          unless ( $value =~ /^$keys{$key}$/ );

        if ( $key eq "optimum" ) {
            if ( $value =~ /^\d+$/ ) {
                $value = [$value];
            } elsif ( ref($value) ne 'ARRAY' ) {
                croak "`$value' is not a suitable value for `$key'";
            }
        }
        ${$key} = $value;
    }

    # Adjust $optimum and $maximum by $indent2 length:
    if ( $indent2 ne "" ) {
        $maximum -= length($indent2);
        $optimum = [ map { $_ - length($indent2) } @$optimum ];
    }
}

#
# Get next line from string to be rewrapped
sub get_line() {
    return shift(@from);
}

#
# Trim EOL spaces and store the lines in the output buffer:
sub print_lines(@) {
    my @lines = @_;
    map { s/[ \t]+\n/\n/gs } @lines;
    push( @to, @lines );
}

#
# Actually do the rewrapping
sub reflow() {
    my ( $line, $last );

    while ( defined( $line = get_line() ) ) {
        if ( $line =~ /^($pin|\t).*\S/ ) {

            # current line may be poetry, check next line:
            $last = $line;
            $line = get_line();
            if ( !defined($line) ) {
                process($last);
                last;
            }
            if ( $line =~ /^($pin|\t).*\S/ ) {

                # found some poetry, skip indented lines until end of input
                # or a non-indented line found:
                reflow_para();
                print_lines( $indent1 . $last );
                print_lines( $indent1 . $line );
                while ( defined( $line = get_line() ) ) {
                    last
                      unless ( $line =~ /^($pin|\t).*\S/ );
                    print_lines( $indent1 . $line );
                }
                last unless ( defined($line) );    # poetry at end of document
                                                   # $line is a non-poetic line
            } else {

                # $last had a poetry indent, but current line doesn't.
                # Process last line:
                process($last);
            }
        }    # end of first poetry test
             # current line is non-poetic, so process it:
        process($line);
    }

    # reflow any remaining @words:
    reflow_para();
}

# Process a non-poetry line by pushing the words onto @words
# If the line is blank, then reflow the paragraph of @words:
sub process($) {
    my ($line) = @_;

    # protect ". . ." ellipses by replacing space with unused byte \x9f
    $line =~ s/ \. \. \./\x9f\.\x9f\.\x9f\./g;
    $line =~ s/\. \. \./\.\x9f\.\x9f\./g;
    @linewords = split( /\s+/, $line );
    shift(@linewords) if ( @linewords && ( $linewords[0] eq "" ) );

    if ( $#linewords == -1 ) {    # No words on this line - end of paragraph
        reflow_para();
        print_lines("$indent1\n");
    } else {

        # add @linewords to @words,
        my $word;
        foreach $word (@linewords) {
            push( @words, $word );
        }
    }
}

#
# Rewrap paragraph
sub reflow_para {
    return () unless (@words);
    reflow_penalties();
    $lastbreak = 0;
    $linkbreak[$wordcount] = 0;
    $lastbreak =
      reflow_trial( $optimum, $maximum, $wordcount, $penaltylimit, \@word_len, \@space_len,
        \@linkbreak );
    compute_output();
    grep ( s/\x9f/ /g, @output );    # Restore spaces in ellipses
    print_lines(@output);
    @words = ();
}

#
# Initialize word- and space-length arrays
sub reflow_penalties {
    my $j;
    $wordcount = $#words + 1;

    # Add paragraph indentation to first word:
    $words[0] = $indent1 . $words[0] if ($wordcount);

    @word_len  = ();    # Length of each word (excluding spaces)
    @space_len = ();    # Length the space after this word
    for ( $j = 0 ; $j < $wordcount ; $j++ ) {
        if ( $words[$j] =~ / $/ ) {
            $word_len[$j]  = length( $words[$j] ) - 1;
            $space_len[$j] = 2;
        } else {
            $word_len[$j]  = length( $words[$j] );
            $space_len[$j] = 1;
        }
    }

    # First word already has $indent1 added and will not be indented further:
    $word_len[0] -= length($indent2) if ($wordcount);
}

#
# compute @output from $wordcount, @words, $lastbreak and @linkbreak
sub compute_output {
    my ( $j, $terminus );
    @output   = ();
    $terminus = $wordcount - 1;
    for ( $j = 0 ; $terminus >= 0 ; $j++ ) {
        $output[$j] = join( ' ', @words[ $lastbreak + 1 .. $terminus ] ) . "\n";
        $terminus   = $lastbreak;
        $lastbreak  = $linkbreak[$lastbreak];
    }
    @output = reverse(@output);

    # Add the indent to all but the first line:
    map { $_ = $indent2 . $_ } @output[ 1 .. $#output ];
}

1;

