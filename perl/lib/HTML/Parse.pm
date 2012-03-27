
require 5;
package HTML::Parse;
  # Time-stamp: "2000-05-18 23:40:06 MDT"


require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(parse_html parse_htmlfile);

use strict;
use vars qw($VERSION
            $IMPLICIT_TAGS $IGNORE_UNKNOWN $IGNORE_TEXT $WARN
           );

# Backwards compatability
$IMPLICIT_TAGS  = 1;
$IGNORE_UNKNOWN = 1;
$IGNORE_TEXT    = 0;
$WARN           = 0;

require HTML::TreeBuilder;

$VERSION = '2.71';


sub parse_html ($;$)
{
    my $p = $_[1];
    $p = _new_tree_maker() unless $p;
    $p->parse($_[0]);
}


sub parse_htmlfile ($;$)
{
    my($file, $p) = @_;
    local(*HTML);
    open(HTML, $file) or return undef;
    $p = _new_tree_maker() unless $p;
    $p->parse_file(\*HTML);
}

sub _new_tree_maker
{
    my $p = HTML::TreeBuilder->new(
      implicit_tags  => $IMPLICIT_TAGS,
      ignore_unknown => $IGNORE_UNKNOWN,
      ignore_text    => $IGNORE_TEXT,
      'warn'         => $WARN,
    );
    $p->strict_comment(1);
    $p;
}

1;
