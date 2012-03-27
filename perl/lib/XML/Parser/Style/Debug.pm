# $Id: Debug.pm,v 1.1 2003/07/27 16:07:49 matt Exp $

package XML::Parser::Style::Debug;
use strict;

sub Start {
  my $expat = shift;
  my $tag = shift;
  print STDERR "@{$expat->{Context}} \\\\ (@_)\n";
}

sub End {
  my $expat = shift;
  my $tag = shift;
  print STDERR "@{$expat->{Context}} //\n";
}

sub Char {
  my $expat = shift;
  my $text = shift;
  $text =~ s/([\x80-\xff])/sprintf "#x%X;", ord $1/eg;
  $text =~ s/([\t\n])/sprintf "#%d;", ord $1/eg;
  print STDERR "@{$expat->{Context}} || $text\n";
}

sub Proc {
  my $expat = shift;
  my $target = shift;
  my $text = shift;
  my @foo = @{$expat->{Context}};
  print STDERR "@foo $target($text)\n";
}

1;
__END__

