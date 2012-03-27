package constant;

use strict;
use 5.006_00;
use warnings::register;

our($VERSION, %declared);
$VERSION = '1.04';

#=======================================================================

# Some names are evil choices.
my %keywords = map +($_, 1), qw{ BEGIN INIT CHECK END DESTROY AUTOLOAD };

my %forced_into_main = map +($_, 1),
    qw{ STDIN STDOUT STDERR ARGV ARGVOUT ENV INC SIG };

my %forbidden = (%keywords, %forced_into_main);

#=======================================================================
# import() - import symbols into user's namespace
#
# What we actually do is define a function in the caller's namespace
# which returns the value. The function we create will normally
# be inlined as a constant, thereby avoiding further sub calling 
# overhead.
#=======================================================================
sub import {
    my $class = shift;
    return unless @_;			# Ignore 'use constant;'
    my %constants = ();
    my $multiple  = ref $_[0];

    if ( $multiple ) {
	if (ref $_[0] ne 'HASH') {
	    require Carp;
	    Carp::croak("Invalid reference type '".ref(shift)."' not 'HASH'");
	}
	%constants = %{+shift};
    } else {
	$constants{+shift} = undef;
    }

    foreach my $name ( keys %constants ) {
	unless (defined $name) {
	    require Carp;
	    Carp::croak("Can't use undef as constant name");
	}
	my $pkg = caller;

	# Normal constant name
	if ($name =~ /^_?[^\W_0-9]\w*\z/ and !$forbidden{$name}) {
	    # Everything is okay

	# Name forced into main, but we're not in main. Fatal.
	} elsif ($forced_into_main{$name} and $pkg ne 'main') {
	    require Carp;
	    Carp::croak("Constant name '$name' is forced into main::");

	# Starts with double underscore. Fatal.
	} elsif ($name =~ /^__/) {
	    require Carp;
	    Carp::croak("Constant name '$name' begins with '__'");

	# Maybe the name is tolerable
	} elsif ($name =~ /^[A-Za-z_]\w*\z/) {
	    # Then we'll warn only if you've asked for warnings
	    if (warnings::enabled()) {
		if ($keywords{$name}) {
		    warnings::warn("Constant name '$name' is a Perl keyword");
		} elsif ($forced_into_main{$name}) {
		    warnings::warn("Constant name '$name' is " .
			"forced into package main::");
		} else {
		    # Catch-all - what did I miss? If you get this error,
		    # please let me know what your constant's name was.
		    # Write to <rootbeer@redcat.com>. Thanks!
		    warnings::warn("Constant name '$name' has unknown problems");
		}
	    }

	# Looks like a boolean
	# use constant FRED == fred;
	} elsif ($name =~ /^[01]?\z/) {
            require Carp;
	    if (@_) {
		Carp::croak("Constant name '$name' is invalid");
	    } else {
		Carp::croak("Constant name looks like boolean value");
	    }

	} else {
	   # Must have bad characters
            require Carp;
	    Carp::croak("Constant name '$name' has invalid characters");
	}

	{
	    no strict 'refs';
	    my $full_name = "${pkg}::$name";
	    $declared{$full_name}++;
	    if ($multiple) {
		my $scalar = $constants{$name};
		*$full_name = sub () { $scalar };
	    } else {
		if (@_ == 1) {
		    my $scalar = $_[0];
		    *$full_name = sub () { $scalar };
		} elsif (@_) {
		    my @list = @_;
		    *$full_name = sub () { @list };
		} else {
		    *$full_name = sub () { };
		}
	    }
	}
    }
}

1;

__END__

