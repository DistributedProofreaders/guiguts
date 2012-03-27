package Thread::Signal;
use Thread qw(async);

our $VERSION = '1.00';

if (!init_thread_signals()) {
    require Carp;
    Carp::croak("init_thread_signals failed: $!");
}

async {
    my $sig;
    while ($sig = await_signal()) {
	&$sig();
    }
};

END {
    kill_sighandler_thread();
}

1;
