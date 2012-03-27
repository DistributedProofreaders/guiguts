
# This class is just a hack to act as a "formatter" for
# actually unformatted Pod.
# 
# Note that this isn't the same as just passing thru whatever
# we're given -- we pass thru only the pod source, and suppress
# the Perl code (or whatever non-pod stuff is in the source file).


require 5;
package Pod::Perldoc::ToPod;
use strict;
use warnings;

use base qw(Pod::Perldoc::BaseTo);
sub is_pageable        { 1 }
sub write_with_binmode { 0 }
sub output_extension   { 'pod' }

sub new { return bless {}, ref($_[0]) || $_[0] }

sub parse_from_file {
  my( $self, $in, $outfh ) = @_;

  open(IN, "<", $in) or die "Can't read-open $in: $!\nAborting";

  my $cut_mode = 1;
  
  # A hack for finding things between =foo and =cut, inclusive
  local $_;
  while (<IN>) {
    if(  m/^=(\w+)/s ) {
      if($cut_mode = ($1 eq 'cut')) {
        print $outfh "\n=cut\n\n";
         # Pass thru the =cut line with some harmless
         #  (and occasionally helpful) padding
      }
    }
    next if $cut_mode;
    print $outfh $_ or die "Can't print to $outfh: $!";
  }
  
  close IN or die "Can't close $in: $!";
  return;
}

1;
__END__

