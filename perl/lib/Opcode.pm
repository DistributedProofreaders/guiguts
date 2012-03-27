package Opcode;

use 5.006_001;

use strict;

our($VERSION, $XS_VERSION, @ISA, @EXPORT_OK);

$VERSION = "1.05";
$XS_VERSION = "1.03";

use Carp;
use Exporter ();
use XSLoader ();

BEGIN {
    @ISA = qw(Exporter);
    @EXPORT_OK = qw(
	opset ops_to_opset
	opset_to_ops opset_to_hex invert_opset
	empty_opset full_opset
	opdesc opcodes opmask define_optag
	opmask_add verify_opset opdump
    );
}

sub opset (;@);
sub opset_to_hex ($);
sub opdump (;$);
use subs @EXPORT_OK;

XSLoader::load 'Opcode', $XS_VERSION;

_init_optags();

sub ops_to_opset { opset @_ }	# alias for old name

sub opset_to_hex ($) {
    return "(invalid opset)" unless verify_opset($_[0]);
    unpack("h*",$_[0]);
}

sub opdump (;$) {
	my $pat = shift;
    # handy utility: perl -MOpcode=opdump -e 'opdump File'
    foreach(opset_to_ops(full_opset)) {
        my $op = sprintf "  %12s  %s\n", $_, opdesc($_);
		next if defined $pat and $op !~ m/$pat/i;
		print $op;
    }
}



sub _init_optags {
    my(%all, %seen);
    @all{opset_to_ops(full_opset)} = (); # keys only

    local($_);
    local($/) = "\n=cut"; # skip to optags definition section
    <DATA>;
    $/ = "\n=";		# now read in 'pod section' chunks
    while(<DATA>) {
	next unless m/^item\s+(:\w+)/;
	my $tag = $1;

	# Split into lines, keep only indented lines
	my @lines = grep { m/^\s/    } split(/\n/);
	foreach (@lines) { s/--.*//  } # delete comments
	my @ops   = map  { split ' ' } @lines; # get op words

	foreach(@ops) {
	    warn "$tag - $_ already tagged in $seen{$_}\n" if $seen{$_};
	    $seen{$_} = $tag;
	    delete $all{$_};
	}
	# opset will croak on invalid names
	define_optag($tag, opset(@ops));
    }
    close(DATA);
    warn "Untagged opnames: ".join(' ',keys %all)."\n" if %all;
}


1;

__DATA__

# the =cut above is used by _init_optags() to get here quickly

