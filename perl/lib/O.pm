package O;

our $VERSION = '1.00';

use B qw(minus_c save_BEGINs);
use Carp;

sub import {
    my ($class, @options) = @_;
    my ($quiet, $veryquiet) = (0, 0);
    if ($options[0] eq '-q' || $options[0] eq '-qq') {
	$quiet = 1;
	open (SAVEOUT, ">&STDOUT");
	close STDOUT;
	open (STDOUT, ">", \$O::BEGIN_output);
	if ($options[0] eq '-qq') {
	    $veryquiet = 1;
	}
	shift @options;
    }
    my $backend = shift (@options);
    eval q[
	BEGIN {
	    minus_c;
	    save_BEGINs;
	}

	CHECK {
	    if ($quiet) {
		close STDOUT;
		open (STDOUT, ">&SAVEOUT");
		close SAVEOUT;
	    }

	    # Note: if you change the code after this 'use', please
	    # change the fudge factors in B::Concise (grep for
	    # "fragile kludge") so that its output still looks
	    # nice. Thanks. --smcc
	    use B::].$backend.q[ ();
	    if ($@) {
		croak "use of backend $backend failed: $@";
	    }


	    my $compilesub = &{"B::${backend}::compile"}(@options);
	    if (ref($compilesub) ne "CODE") {
		die $compilesub;
	    }

	    local $savebackslash = $\;
	    local ($\,$",$,) = (undef,' ','');
	    &$compilesub();

	    close STDERR if $veryquiet;
	}
    ];
    die $@ if $@;
}

1;

__END__

