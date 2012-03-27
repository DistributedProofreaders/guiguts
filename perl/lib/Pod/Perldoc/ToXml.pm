
require 5;
package Pod::Perldoc::ToXml;
use strict;
use warnings;
use vars qw($VERSION);

use base qw( Pod::Simple::XMLOutStream );

$VERSION   # so that ->VERSION is happy
# stop CPAN from seeing this
 =
$Pod::Simple::XMLOutStream::VERSION;


sub is_pageable        { 0 }
sub write_with_binmode { 0 }
sub output_extension   { 'xml' }

1;
__END__

