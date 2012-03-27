package sort;

our $VERSION = '1.02';

# Currently the hints for pp_sort are stored in the global variable
# $sort::hints. An improvement would be to store them in $^H{SORT} and have
# this information available somewhere in the listop OP_SORT, to allow lexical
# scoping of this pragma. -- rgs 2002-04-30

our $hints	       = 0;

$sort::quicksort_bit   = 0x00000001;
$sort::mergesort_bit   = 0x00000002;
$sort::sort_bits       = 0x000000FF; # allow 256 different ones
$sort::stable_bit      = 0x00000100;

use strict;

sub import {
    shift;
    if (@_ == 0) {
	require Carp;
	Carp::croak("sort pragma requires arguments");
    }
    local $_;
    no warnings 'uninitialized';	# bitops would warn
    while ($_ = shift(@_)) {
	if (/^_q(?:uick)?sort$/) {
	    $hints &= ~$sort::sort_bits;
	    $hints |=  $sort::quicksort_bit;
	} elsif ($_ eq '_mergesort') {
	    $hints &= ~$sort::sort_bits;
	    $hints |=  $sort::mergesort_bit;
	} elsif ($_ eq 'stable') {
	    $hints |=  $sort::stable_bit;
	} elsif ($_ eq 'defaults') {
	    $hints =   0;
	} else {
	    require Carp;
	    Carp::croak("sort: unknown subpragma '$_'");
	}
    }
}

sub unimport {
    shift;
    if (@_ == 0) {
	require Carp;
	Carp::croak("sort pragma requires arguments");
    }
    local $_;
    no warnings 'uninitialized';	# bitops would warn
    while ($_ = shift(@_)) {
	if (/^_q(?:uick)?sort$/) {
	    $hints &= ~$sort::sort_bits;
	} elsif ($_ eq '_mergesort') {
	    $hints &= ~$sort::sort_bits;
	} elsif ($_ eq 'stable') {
	    $hints &= ~$sort::stable_bit;
	} else {
	    require Carp;
	    Carp::croak("sort: unknown subpragma '$_'");
	}
    }
}

sub current {
    my @sort;
    if ($hints) {
	push @sort, 'quicksort' if $hints & $sort::quicksort_bit;
	push @sort, 'mergesort' if $hints & $sort::mergesort_bit;
	push @sort, 'stable'    if $hints & $sort::stable_bit;
    }
    push @sort, 'mergesort' unless @sort;
    join(' ', @sort);
}

1;
__END__

