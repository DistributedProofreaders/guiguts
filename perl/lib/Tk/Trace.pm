package Tk::Trace;

use vars qw($VERSION);
$VERSION = sprintf '4.%03d', q$Revision: #7 $ =~ /\D(\d+)\s*$/;

use Carp;
use Tie::Watch;
use strict;

# The %TRACE hash is indexed by stringified variable reference. Each hash
# bucket contains an array reference having two elements:
#
# ->[0] = a reference to the variable's Tie::Watch object
# ->[1] = a hash reference with these keys: -fetch, -store, -destroy
#         ->{key} = [ active flag, [ callback list ] ]
#         where each callback is a normalized callback array reference
#
# Thus, each trace type (r w u ) may have multiple traces.

my %TRACE;                      # watchpoints indexed by stringified ref

my %OP = (			# trace to Tie::Watch operation map
    r => '-fetch',
    w => '-store',
    u => '-destroy',
);

sub fetch {

    # fetch() wraps the user's callback with necessary tie() bookkeeping
    # and invokes the callback with the proper arguments. It expects:
    #
    # $_[0] = Tie::Watch object
    # $_[1] = undef for a scalar, an index/key for an array/hash
    #
    # The user's callback is passed these arguments:
    #
    #   $_[0]        = undef for a scalar, index/key for array/hash
    #   $_[1]        = current value
    #   $_[2]        = operation 'r'
    #   $_[3 .. $#_] = optional user callback arguments
    #
    # The user callback returns the final value to assign the variable.

    my $self = shift;                          # Tie::Watch object
    my $val  = $self->Fetch(@_);               # get variable's current value
    my $aref = $self->Args('-fetch');          # argument reference
    my $call = $TRACE{$aref->[0]}->[1]->{-fetch}; # active flag/callbacks
    return $val unless $call->[0];             # if fetch inactive

    my $final_val;
    foreach my $aref (reverse  @$call[ 1 .. $#{@$call} ] ) {
        my ( @args_copy ) = @$aref;
        my $sub = shift @args_copy;            # user's callback
        unshift @_, undef if scalar @_ == 0;   # undef "index" for a scalar
        my @args = @_;                         # save for post-callback work
        $args[1] = &$sub(@_, $val, 'r', @args_copy); # invoke user callback
        shift @args unless defined $args[0];   # drop scalar "index"
        $final_val = $self->Store(@args);      # update variable's value
    }
    $final_val;

} # end fetch

sub store {

    # store() wraps the user's callback with necessary tie() bookkeeping
    # and invokes the callback with the proper arguments. It expects:
    #
    # $_[0] = Tie::Watch object
    # $_[1] = new value for a scalar, index/key for an array/hash
    # $_[2] = undef for a scalar, new value for an array/hash
    #
    # The user's callback is passed these arguments:
    #
    #   $_[0]        = undef for a scalar, index/key for array/hash
    #   $_[1]        = new value
    #   $_[2]        = operation 'w'
    #   $_[3 .. $#_] = optional user callback arguments
    #
    # The user callback returns the final value to assign the variable.

    my $self = shift;                          # Tie::Watch object
    my $val  = $self->Store(@_);               # store variable's new value
    my $aref = $self->Args('-store');          # argument reference
    my $call = $TRACE{$aref->[0]}->[1]->{-store}; # active flag/callbacks
    return $val unless $call->[0];             # if store inactive

    foreach my $aref ( reverse @$call[ 1 .. $#{@$call} ] ) {
        my ( @args_copy ) = @$aref;
        my $sub = shift @args_copy;            # user's callback
        unshift @_, undef if scalar @_ == 1;   # undef "index" for a scalar
        my @args = @_;                         # save for post-callback work
        $args[1] = &$sub(@_, 'w', @args_copy); # invoke user callback
        shift @args unless defined $args[0];   # drop scalar "index"
        $self->Store(@args);                   # update variable's value
    }

} # end store

sub destroy {

    # destroy() wraps the user's callback with necessary tie() bookkeeping
    # and invokes the callback with the proper arguments. It expects:
    #
    # $_[0] = Tie::Watch object
    #
    # The user's callback is passed these arguments:
    #
    #   $_[0]        = undef for a scalar, index/key for array/hash
    #   $_[1]        = final value
    #   $_[2]        = operation 'u'
    #   $_[3 .. $#_] = optional user callback arguments

    my $self = shift;                          # Tie::Watch object
    my $val  = $self->Fetch(@_);               # variable's final value
    my $aref = $self->Args('-destroy');        # argument reference
    my $call = $TRACE{$aref->[0]}->[1]->{-destroy}; # active flag/callbacks
    return $val unless $call->[0];             # if destroy inactive

    foreach my $aref ( reverse @$call[ 1 .. $#{@$call} ] ) {
        my ( @args_copy ) = @$aref;
        my $sub = shift @args_copy;            # user's callback
        my $val = $self->Fetch(@_);            # get final value
        &$sub(undef, $val, 'u', @args_copy);   # invoke user callback
        $self->Destroy(@_);                    # destroy variable
    }

} # end destroy

sub Tk::Widget::traceVariable {

    my( $parent, $vref, $op, $callback ) = @_;

    {
	$^W = 0;
	croak "Illegal parent '$parent', not a widget" unless ref $parent;
	croak "Illegal variable '$vref', not a reference" unless ref $vref;
	croak "Illegal trace operation '$op'" unless $op;
	croak "Illegal trace operation '$op'" if $op =~ /[^rwu]/;
	croak "Illegal callback ($callback)" unless $callback;
    }

    # Need to add our internal callback to user's callback arg list
    # so we can call ours first, followed by the user's callback and
    # any user arguments. Trace callbacks are activated as requied.

    my $trace = $TRACE{$vref};
    if ( not defined $trace ) {
        my $watch = Tie::Watch->new(
            -variable => $vref,
            -fetch    => [ \&fetch,   $vref ],
            -store    => [ \&store,   $vref ],
            -destroy  => [ \&destroy, $vref ],
        );
        $trace = $TRACE{$vref} =
            [$watch,
             {
                 -fetch   => [ 0 ],
                 -store   => [ 0 ],
                 -destroy => [ 0 ],
             }
            ];
    }

    $callback =  [ $callback ] if ref $callback eq 'CODE';

    foreach my $o (split '', $op) {
	push @{$trace->[1]->{$OP{$o}}}, $callback;
	$trace->[1]->{$OP{$o}}->[0] = 1; # activate
    }

    return $trace;		# for peeking

} # end traceVariable

sub Tk::Widget::traceVdelete {

    my ( $parent, $vref, $op_not_honored, $callabck_not_honored ) = @_;

    if ( defined $TRACE{$vref}->[0] ) {
        $$vref = $TRACE{$vref}->[0]->Fetch;
        $TRACE{$vref}->[0]->Unwatch;
        delete $TRACE{$vref};
    }

} # end traceVdelete

sub Tk::Widget::traceVinfo {

    my ( $parent, $vref ) = @_;

    return ( defined $TRACE{$vref}->[0] ) ? $TRACE{$vref}->[0]->Info : undef;

} # end traceVinfo

1;
