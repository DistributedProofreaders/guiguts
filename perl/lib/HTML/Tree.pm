
require 5; # -*-Text-*- Time-stamp: "2003-09-15 00:32:59 ADT"
package HTML::Tree;
$VERSION = $VERSION = 3.18;
  # This is where the dist gets its version from.

# Basically just a happy alias to HTML::TreeBuilder
use HTML::TreeBuilder ();

sub new {
  shift; unshift @_, 'HTML::TreeBuilder';
  goto &HTML::TreeBuilder::new;
}
sub new_from_file {
  shift; unshift @_, 'HTML::TreeBuilder';
  goto &HTML::TreeBuilder::new_from_file;
}
sub new_from_content {
  shift; unshift @_, 'HTML::TreeBuilder';
  goto &HTML::TreeBuilder::new_from_content;
}

1;  

__END__

