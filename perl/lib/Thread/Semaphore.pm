package Thread::Semaphore;

use threads::shared;

our $VERSION = '2.01';

sub new {
    my $class = shift;
    my $val : shared = @_ ? shift : 1;
    bless \$val, $class;
}

sub down {
    my $s = shift;
    lock($$s);
    my $inc = @_ ? shift : 1;
    cond_wait $$s until $$s >= $inc;
    $$s -= $inc;
}

sub up {
    my $s = shift;
    lock($$s);
    my $inc = @_ ? shift : 1;
    ($$s += $inc) > 0 and cond_broadcast $$s;
}

1;
