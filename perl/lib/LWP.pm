#
# $Id: LWP.pm,v 1.133 2003/10/23 19:20:00 uid39246 Exp $

package LWP;

$VERSION = "5.75";
sub Version { $VERSION; }

require 5.005;
require LWP::UserAgent;  # this should load everything you need

1;

__END__

