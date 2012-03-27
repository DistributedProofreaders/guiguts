package Thread::Queue;

use threads::shared;
use strict;

our $VERSION = '2.00';

sub new {
    my $class = shift;
    my @q : shared = @_;
    return bless \@q, $class;
}

sub dequeue  {
    my $q = shift;
    lock(@$q);
    cond_wait @$q until @$q;
    cond_signal @$q if @$q > 1;
    return shift @$q;
}

sub dequeue_nb {
    my $q = shift;
    lock(@$q);
    return shift @$q;
}

sub enqueue {
    my $q = shift;
    lock(@$q);
    push @$q, @_  and cond_signal @$q;
}

sub pending  {
    my $q = shift;
    lock(@$q);
    return scalar(@$q);
}

1;


