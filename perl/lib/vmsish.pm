package vmsish;

our $VERSION = '1.01';

my $IsVMS = $^O eq 'VMS';

sub bits {
    my $bits = 0;
    my $sememe;
    foreach $sememe (@_) {
	# Those hints are defined in vms/vmsish.h :
	# HINT_M_VMSISH_STATUS and HINT_M_VMSISH_TIME
        $bits |= 0x40000000, next if $sememe eq 'status' || $sememe eq '$?';
	$bits |= 0x80000000, next if $sememe eq 'time';
    }
    $bits;
}

sub import {
    return unless $IsVMS;

    shift;
    $^H |= bits(@_ ? @_ : qw(status time));
    my $sememe;

    foreach $sememe (@_ ? @_ : qw(exit hushed)) {
        $^H{'vmsish_exit'}   = 1 if $sememe eq 'exit';
        vmsish::hushed(1) if $sememe eq 'hushed';
    }
}

sub unimport {
    return unless $IsVMS;

    shift;
    $^H &= ~ bits(@_ ? @_ : qw(status time));
    my $sememe;

    foreach $sememe (@_ ? @_ : qw(exit hushed)) {
        $^H{'vmsish_exit'}   = 0 if $sememe eq 'exit';
        vmsish::hushed(0) if $sememe eq 'hushed';
    }
}

1;
