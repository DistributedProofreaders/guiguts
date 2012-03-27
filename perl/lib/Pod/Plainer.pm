package Pod::Plainer;
use strict;
use Pod::Parser;
our @ISA = qw(Pod::Parser);
our $VERSION = '0.01';

our %E = qw( < lt > gt );
 
sub escape_ltgt {
    (undef, my $text) = @_;
    $text =~ s/([<>])/E<$E{$1}>/g;
    $text 
} 

sub simple_delimiters {
    (undef, my $seq) = @_;
    $seq -> left_delimiter( '<' ); 
    $seq -> right_delimiter( '>' );  
    $seq;
}

sub textblock {
    my($parser,$text,$line) = @_;
    print {$parser->output_handle()}
	$parser->parse_text(
	    { -expand_text => q(escape_ltgt),
	      -expand_seq => q(simple_delimiters) },
	    $text, $line ) -> raw_text(); 
}

1;

__END__

