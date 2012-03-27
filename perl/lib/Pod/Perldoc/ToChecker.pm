
require 5;
package Pod::Perldoc::ToChecker;
use strict;
use warnings;
use vars qw(@ISA);

# Pick our superclass...
#
eval 'require Pod::Simple::Checker';
if($@) {
  require Pod::Checker;
  @ISA = ('Pod::Checker');
} else {
  @ISA = ('Pod::Simple::Checker');
}

sub is_pageable        { 1 }
sub write_with_binmode { 0 }
sub output_extension   { 'txt' }

sub if_zero_length {
  my( $self, $file, $tmp, $tmpfd ) = @_;
  print "No Pod errors in $file\n";
}


1;

__END__

