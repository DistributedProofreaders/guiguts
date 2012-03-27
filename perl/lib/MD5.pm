package MD5;  # legacy stuff

use strict;
use vars qw($VERSION @ISA);

$VERSION = '2.02';  # $Date: 2001/03/14 04:44:31 $

require Digest::MD5;
@ISA=qw(Digest::MD5);

sub hash    { shift->new->add(@_)->digest;    }
sub hexhash { shift->new->add(@_)->hexdigest; }

1;
__END__

