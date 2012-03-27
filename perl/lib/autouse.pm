package autouse;

#use strict;		# debugging only
use 5.003_90;		# ->can, for my $var

$autouse::VERSION = '1.03';

$autouse::DEBUG ||= 0;

sub vet_import ($);

sub croak {
    require Carp;
    Carp::croak(@_);
}

sub import {
    my $class = @_ ? shift : 'autouse';
    croak "usage: use $class MODULE [,SUBS...]" unless @_;
    my $module = shift;

    (my $pm = $module) =~ s{::}{/}g;
    $pm .= '.pm';
    if (exists $INC{$pm}) {
	vet_import $module;
	local $Exporter::ExportLevel = $Exporter::ExportLevel + 1;
	# $Exporter::Verbose = 1;
	return $module->import(map { (my $f = $_) =~ s/\(.*?\)$//; $f } @_);
    }

    # It is not loaded: need to do real work.
    my $callpkg = caller(0);
    print "autouse called from $callpkg\n" if $autouse::DEBUG;

    my $index;
    for my $f (@_) {
	my $proto;
	$proto = $1 if (my $func = $f) =~ s/\((.*)\)$//;

	my $closure_import_func = $func;	# Full name
	my $closure_func = $func;		# Name inside package
	my $index = rindex($func, '::');
	if ($index == -1) {
	    $closure_import_func = "${callpkg}::$func";
	} else {
	    $closure_func = substr $func, $index + 2;
	    croak "autouse into different package attempted"
		unless substr($func, 0, $index) eq $module;
	}

	my $load_sub = sub {
	    unless ($INC{$pm}) {
		eval {require $pm};
		die if $@;
		vet_import $module;
	    }
            no warnings 'redefine';
	    *$closure_import_func = \&{"${module}::$closure_func"};
	    print "autousing $module; "
		  ."imported $closure_func as $closure_import_func\n"
		if $autouse::DEBUG;
	    goto &$closure_import_func;
	};

	if (defined $proto) {
	    *$closure_import_func = eval "sub ($proto) { &\$load_sub }";
	} else {
	    *$closure_import_func = $load_sub;
	}
    }
}

sub vet_import ($) {
    my $module = shift;
    if (my $import = $module->can('import')) {
	croak "autoused module has unique import() method"
	    unless defined(&Exporter::import)
		   && $import == \&Exporter::import;
    }
}

1;

__END__

