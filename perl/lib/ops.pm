package ops;

our $VERSION = '1.00';

use Opcode qw(opmask_add opset invert_opset);

sub import {
    shift;
    # Not that unimport is the prefered form since import's don't
	# accumulate well owing to the 'only ever add opmask' rule.
	# E.g., perl -Mops=:set1 -Mops=:setb is unlikely to do as expected.
    opmask_add(invert_opset opset(@_)) if @_;
}

sub unimport {
    shift;
    opmask_add(opset(@_)) if @_;
}

1;

__END__

