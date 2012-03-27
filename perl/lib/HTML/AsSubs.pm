
require 5;
package HTML::AsSubs;
#Time-stamp: "2000-06-28 13:06:25 MDT"

use strict;
use vars qw(@ISA $VERSION @EXPORT);

require HTML::Element;
require Exporter;
@ISA = qw(Exporter);

$VERSION = '1.16';

# Problem: exports so damned much.  Has no concept of "export only HTML4
#  elements".  TODO:?? make something that make functions that just
#  wrap XML::Generator calls?

use vars qw(@TAGS);
@TAGS = qw(html
	   head title base link meta isindex nextid script style
	   body h1 h2 h3 h4 h5 h6 p pre div blockquote
	   a img br hr
	   ol ul dir menu li
	   dl dt dd
	   dfn cite code em kbd samp strong var address 
	   b i u tt
           center font big small strike
           sub sup
	   table tr td th caption
	   form input select option textarea
           object applet param
           map area
           frame frameset noframe
	  );

my @code;
for (@TAGS) {
    push(@code, "sub $_ { _elem('$_', \@_); }\n");
    push(@EXPORT, $_);
}
eval join('', @code);
if ($@) {
    die $@;
}

sub _elem
{
    my $tag = shift;
    my $attributes;
    if (@_ and defined $_[0] and ref($_[0]) eq "HASH") {
	$attributes = shift;
    }
    my $elem = HTML::Element->new( $tag, %$attributes );
    $elem->push_content(@_);
    $elem;
}

1;
