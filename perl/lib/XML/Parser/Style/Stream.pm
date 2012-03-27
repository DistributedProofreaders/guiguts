# $Id: Stream.pm,v 1.1 2003/07/27 16:07:49 matt Exp $

package XML::Parser::Style::Stream;
use strict;

# This style invented by Tim Bray <tbray@textuality.com>

sub Init {
  no strict 'refs';
  my $expat = shift;
  $expat->{Text} = '';
  my $sub = $expat->{Pkg} ."::StartDocument";
  &$sub($expat)
    if defined(&$sub);
}

sub Start {
  no strict 'refs';
  my $expat = shift;
  my $type = shift;
  
  doText($expat);
  $_ = "<$type";
  
  %_ = @_;
  while (@_) {
    $_ .= ' ' . shift() . '="' . shift() . '"';
  }
  $_ .= '>';
  
  my $sub = $expat->{Pkg} . "::StartTag";
  if (defined(&$sub)) {
    &$sub($expat, $type);
  } else {
    print;
  }
}

sub End {
  no strict 'refs';
  my $expat = shift;
  my $type = shift;
  
  # Set right context for Text handler
  push(@{$expat->{Context}}, $type);
  doText($expat);
  pop(@{$expat->{Context}});
  
  $_ = "</$type>";
  
  my $sub = $expat->{Pkg} . "::EndTag";
  if (defined(&$sub)) {
    &$sub($expat, $type);
  } else {
    print;
  }
}

sub Char {
  my $expat = shift;
  $expat->{Text} .= shift;
}

sub Proc {
  no strict 'refs';
  my $expat = shift;
  my $target = shift;
  my $text = shift;
  
  doText($expat);

  $_ = "<?$target $text?>";
  
  my $sub = $expat->{Pkg} . "::PI";
  if (defined(&$sub)) {
    &$sub($expat, $target, $text);
  } else {
    print;
  }
}

sub Final {
  no strict 'refs';
  my $expat = shift;
  my $sub = $expat->{Pkg} . "::EndDocument";
  &$sub($expat)
    if defined(&$sub);
}

sub doText {
  no strict 'refs';
  my $expat = shift;
  $_ = $expat->{Text};
  
  if (length($_)) {
    my $sub = $expat->{Pkg} . "::Text";
    if (defined(&$sub)) {
      &$sub($expat);
    } else {
      print;
    }
    
    $expat->{Text} = '';
  }
}

1;
__END__

