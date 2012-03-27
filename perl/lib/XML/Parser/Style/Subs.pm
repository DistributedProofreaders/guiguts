# $Id: Subs.pm,v 1.1 2003/07/27 16:07:49 matt Exp $

package XML::Parser::Style::Subs;

sub Start {
  no strict 'refs';
  my $expat = shift;
  my $tag = shift;
  my $sub = $expat->{Pkg} . "::$tag";
  eval { &$sub($expat, $tag, @_) };
}

sub End {
  no strict 'refs';
  my $expat = shift;
  my $tag = shift;
  my $sub = $expat->{Pkg} . "::${tag}_";
  eval { &$sub($expat, $tag) };
}

1;
__END__

