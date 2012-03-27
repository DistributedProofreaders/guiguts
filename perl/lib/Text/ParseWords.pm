package Text::ParseWords;

use vars qw($VERSION @ISA @EXPORT $PERL_SINGLE_QUOTE);
$VERSION = "3.21";

require 5.000;

use Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(shellwords quotewords nested_quotewords parse_line);
@EXPORT_OK = qw(old_shellwords);


sub shellwords {
    local(@lines) = @_;
    $lines[$#lines] =~ s/\s+$//;
    return(quotewords('\s+', 0, @lines));
}



sub quotewords {
    my($delim, $keep, @lines) = @_;
    my($line, @words, @allwords);
    

    foreach $line (@lines) {
	@words = parse_line($delim, $keep, $line);
	return() unless (@words || !length($line));
	push(@allwords, @words);
    }
    return(@allwords);
}



sub nested_quotewords {
    my($delim, $keep, @lines) = @_;
    my($i, @allwords);
    
    for ($i = 0; $i < @lines; $i++) {
	@{$allwords[$i]} = parse_line($delim, $keep, $lines[$i]);
	return() unless (@{$allwords[$i]} || !length($lines[$i]));
    }
    return(@allwords);
}



sub parse_line {
	# We will be testing undef strings
	no warnings;
	use re 'taint'; # if it's tainted, leave it as such

    my($delimiter, $keep, $line) = @_;
    my($quote, $quoted, $unquoted, $delim, $word, @pieces);

    while (length($line)) {

	($quote, $quoted, undef, $unquoted, $delim, undef) =
	    $line =~ m/^(["'])                 # a $quote
                        ((?:\\.|(?!\1)[^\\])*)    # and $quoted text
                        \1 		       # followed by the same quote
                        ([\000-\377]*)	       # and the rest
		       |                       # --OR--
                       ^((?:\\.|[^\\"'])*?)    # an $unquoted text
		      (\Z(?!\n)|(?-x:$delimiter)|(?!^)(?=["']))  
                                               # plus EOL, delimiter, or quote
                      ([\000-\377]*)	       # the rest
		      /x;		       # extended layout
	return() unless( $quote || length($unquoted) || length($delim));

	$line = $+;

        if ($keep) {
	    $quoted = "$quote$quoted$quote";
	}
        else {
	    $unquoted =~ s/\\(.)/$1/g;
	    if (defined $quote) {
		$quoted =~ s/\\(.)/$1/g if ($quote eq '"');
		$quoted =~ s/\\([\\'])/$1/g if ( $PERL_SINGLE_QUOTE && $quote eq "'");
            }
	}
        $word .= defined $quote ? $quoted : $unquoted;
 
        if (length($delim)) {
            push(@pieces, $word);
            push(@pieces, $delim) if ($keep eq 'delimiters');
            undef $word;
        }
        if (!length($line)) {
            push(@pieces, $word);
	}
    }
    return(@pieces);
}



sub old_shellwords {

    # Usage:
    #	use ParseWords;
    #	@words = old_shellwords($line);
    #	or
    #	@words = old_shellwords(@lines);

    local($_) = join('', @_);
    my(@words,$snippet,$field);

    s/^\s+//;
    while ($_ ne '') {
	$field = '';
	for (;;) {
	    if (s/^"(([^"\\]|\\.)*)"//) {
		($snippet = $1) =~ s#\\(.)#$1#g;
	    }
	    elsif (/^"/) {
		return();
	    }
	    elsif (s/^'(([^'\\]|\\.)*)'//) {
		($snippet = $1) =~ s#\\(.)#$1#g;
	    }
	    elsif (/^'/) {
		return();
	    }
	    elsif (s/^\\(.)//) {
		$snippet = $1;
	    }
	    elsif (s/^([^\s\\'"]+)//) {
		$snippet = $1;
	    }
	    else {
		s/^\s+//;
		last;
	    }
	    $field .= $snippet;
	}
	push(@words, $field);
    }
    @words;
}

1;

__END__

