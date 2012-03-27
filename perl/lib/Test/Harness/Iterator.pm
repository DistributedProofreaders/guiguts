package Test::Harness::Iterator;

use strict;
use vars qw($VERSION);
$VERSION = 0.02;

sub new {
    my($proto, $thing) = @_;

    my $self = {};
    if( ref $thing eq 'GLOB' ) {
        bless $self, 'Test::Harness::Iterator::FH';
        $self->{fh} = $thing;
    }
    elsif( ref $thing eq 'ARRAY' ) {
        bless $self, 'Test::Harness::Iterator::ARRAY';
        $self->{idx}   = 0;
        $self->{array} = $thing;
    }
    else {
        warn "Can't iterate with a ", ref $thing;
    }

    return $self;
}

package Test::Harness::Iterator::FH;
sub next {
    my $fh = $_[0]->{fh};
    return scalar <$fh>;
}


package Test::Harness::Iterator::ARRAY;
sub next {
    my $self = shift;
    return $self->{array}->[$self->{idx}++];
}
