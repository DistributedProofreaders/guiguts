package sigtrap;

use Carp;

$VERSION = 1.02;
$Verbose ||= 0;

sub import {
    my $pkg = shift;
    my $handler = \&handler_traceback;
    my $saw_sig = 0;
    my $untrapped = 0;
    local $_;

  Arg_loop:
    while (@_) {
	$_ = shift;
	if (/^[A-Z][A-Z0-9]*$/) {
	    $saw_sig++;
	    unless ($untrapped and $SIG{$_} and $SIG{$_} ne 'DEFAULT') {
		print "Installing handler $handler for $_\n" if $Verbose;
		$SIG{$_} = $handler;
	    }
	}
	elsif ($_ eq 'normal-signals') {
	    unshift @_, grep(exists $SIG{$_}, qw(HUP INT PIPE TERM));
	}
	elsif ($_ eq 'error-signals') {
	    unshift @_, grep(exists $SIG{$_},
			     qw(ABRT BUS EMT FPE ILL QUIT SEGV SYS TRAP));
	}
	elsif ($_ eq 'old-interface-signals') {
	    unshift @_,
	    grep(exists $SIG{$_},
		 qw(ABRT BUS EMT FPE ILL PIPE QUIT SEGV SYS TERM TRAP));
	}
    	elsif ($_ eq 'stack-trace') {
	    $handler = \&handler_traceback;
	}
	elsif ($_ eq 'die') {
	    $handler = \&handler_die;
	}
	elsif ($_ eq 'handler') {
	    @_ or croak "No argument specified after 'handler'";
	    $handler = shift;
	    unless (ref $handler or $handler eq 'IGNORE'
			or $handler eq 'DEFAULT') {
    	    	require Symbol;
		$handler = Symbol::qualify($handler, (caller)[0]);
	    }
	}
	elsif ($_ eq 'untrapped') {
	    $untrapped = 1;
	}
	elsif ($_ eq 'any') {
	    $untrapped = 0;
	}
	elsif ($_ =~ /^\d/) {
	    $VERSION >= $_ or croak "sigtrap.pm version $_ required,"
		    	    	    	. " but this is only version $VERSION";
	}
	else {
	    croak "Unrecognized argument $_";
	}
    }
    unless ($saw_sig) {
	@_ = qw(old-interface-signals);
	goto Arg_loop;
    }
}

sub handler_die {
    croak "Caught a SIG$_[0]";
}

sub handler_traceback {
    package DB;		# To get subroutine args.
    $SIG{'ABRT'} = DEFAULT;
    kill 'ABRT', $$ if $panic++;
    syswrite(STDERR, 'Caught a SIG', 12);
    syswrite(STDERR, $_[0], length($_[0]));
    syswrite(STDERR, ' at ', 4);
    ($pack,$file,$line) = caller;
    syswrite(STDERR, $file, length($file));
    syswrite(STDERR, ' line ', 6);
    syswrite(STDERR, $line, length($line));
    syswrite(STDERR, "\n", 1);

    # Now go for broke.
    for ($i = 1; ($p,$f,$l,$s,$h,$w,$e,$r) = caller($i); $i++) {
        @a = ();
	for $arg (@args) {
	    $_ = "$arg";
	    s/([\'\\])/\\$1/g;
	    s/([^\0]*)/'$1'/
	      unless /^(?: -?[\d.]+ | \*[\w:]* )$/x;
	    s/([\200-\377])/sprintf("M-%c",ord($1)&0177)/eg;
	    s/([\0-\37\177])/sprintf("^%c",ord($1)^64)/eg;
	    push(@a, $_);
	}
	$w = $w ? '@ = ' : '$ = ';
	$a = $h ? '(' . join(', ', @a) . ')' : '';
	$e =~ s/\n\s*\;\s*\Z// if $e;
	$e =~ s/[\\\']/\\$1/g if $e;
	if ($r) {
	    $s = "require '$e'";
	} elsif (defined $r) {
	    $s = "eval '$e'";
	} elsif ($s eq '(eval)') {
	    $s = "eval {...}";
	}
	$f = "file `$f'" unless $f eq '-e';
	$mess = "$w$s$a called from $f line $l\n";
	syswrite(STDERR, $mess, length($mess));
    }
    kill 'ABRT', $$;
}

1;

__END__

