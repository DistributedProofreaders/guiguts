package Tie::Watch;

use vars qw($VERSION);
$VERSION = '4.006'; # $Id: //depot/Tkutf8/lib/Tie/Watch.pm#6 $

use 5.004_57;
use Carp;
use strict;
use subs qw/normalize_callbacks/;
use vars qw/@array_callbacks @hash_callbacks @scalar_callbacks/;

@array_callbacks  = qw/-clear -destroy -extend -fetch -fetchsize -pop -push
                       -shift -splice -store -storesize -unshift/;
@hash_callbacks   = qw/-clear -delete -destroy -exists -fetch -firstkey
                       -nextkey -store/;
@scalar_callbacks = qw/-destroy -fetch -store/;

sub new {

    # Watch constructor.  The *real* constructor is Tie::Watch->base_watch(),
    # invoked by methods in other Watch packages, depending upon the variable's
    # type.  Here we supply defaulted parameter values and then verify them,
    # normalize all callbacks and bind the variable to the appropriate package.

    my($class, %args) = @_;
    my $version = $Tie::Watch::VERSION;
    my (%arg_defaults) = (-debug => 0, -shadow  => 1);
    my $variable = $args{-variable};
    croak "Tie::Watch::new(): -variable is required." if not defined $variable;

    my($type, $watch_obj) = (ref $variable, undef);
    if ($type =~ /(SCALAR|REF)/) {
	@arg_defaults{@scalar_callbacks} = (
	    [\&Tie::Watch::Scalar::Destroy],  [\&Tie::Watch::Scalar::Fetch],
	    [\&Tie::Watch::Scalar::Store]);
    } elsif ($type =~ /ARRAY/) {
	@arg_defaults{@array_callbacks}  = (
	    [\&Tie::Watch::Array::Clear],     [\&Tie::Watch::Array::Destroy],
	    [\&Tie::Watch::Array::Extend],    [\&Tie::Watch::Array::Fetch],
	    [\&Tie::Watch::Array::Fetchsize], [\&Tie::Watch::Array::Pop],
            [\&Tie::Watch::Array::Push],      [\&Tie::Watch::Array::Shift],
            [\&Tie::Watch::Array::Splice],    [\&Tie::Watch::Array::Store],
            [\&Tie::Watch::Array::Storesize], [\&Tie::Watch::Array::Unshift]);
    } elsif ($type =~ /HASH/) {
	@arg_defaults{@hash_callbacks}   = (
	    [\&Tie::Watch::Hash::Clear],      [\&Tie::Watch::Hash::Delete],
	    [\&Tie::Watch::Hash::Destroy],    [\&Tie::Watch::Hash::Exists],
            [\&Tie::Watch::Hash::Fetch],      [\&Tie::Watch::Hash::Firstkey],
            [\&Tie::Watch::Hash::Nextkey],    [\&Tie::Watch::Hash::Store]);
    } else {
	croak "Tie::Watch::new() - not a variable reference.";
    }
    my(@margs, %ahsh, $args, @args);
    @margs = grep ! defined $args{$_}, keys %arg_defaults;
    %ahsh = %args;                         # argument hash
    @ahsh{@margs} = @arg_defaults{@margs}; # fill in missing values
    normalize_callbacks \%ahsh;

    if ($type =~ /(SCALAR|REF)/) {
        $watch_obj = tie $$variable, 'Tie::Watch::Scalar', %ahsh;
    } elsif ($type =~ /ARRAY/) {
        $watch_obj = tie @$variable, 'Tie::Watch::Array',  %ahsh;
    } elsif ($type =~ /HASH/) {
        $watch_obj = tie %$variable, 'Tie::Watch::Hash',   %ahsh;
    }
    $watch_obj;

} # end new, Watch constructor

sub Args {

    # Return a reference to a list of callback arguments, or undef if none.
    #
    # $_[0] = self
    # $_[1] = callback type

    defined $_[0]->{$_[1]}->[1] ? [@{$_[0]->{$_[1]}}[1 .. $#{$_[0]->{$_[1]}}]]
	: undef;

} # end Args

sub Info {

    # Info() method subclassed by other Watch modules.
    #
    # $_[0] = self
    # @_[1 .. $#_] = optional callback types

    my(%vinfo, @results);
    my(@info) = (qw/-variable -debug -shadow/);
    push @info, @_[1 .. $#_] if scalar @_ >= 2;
    foreach my $type (@info) {
	push @results, 	sprintf('%-10s: ', substr $type, 1) .
	    $_[0]->Say($_[0]->{$type});
	$vinfo{$type} = $_[0]->{$type};
    }
    $vinfo{-legible} = [@results];
    %vinfo;

} # end Info

sub Say {

    # For debugging, mainly.
    #
    # $_[0] = self
    # $_[1] = value

    defined $_[1] ? (ref($_[1]) ne '' ? $_[1] : "'$_[1]'") : "undefined";

} # end Say

sub Unwatch {

    # Stop watching a variable by releasing the last reference and untieing it.
    # Update the original variable with its shadow, if appropriate.
    #
    # $_[0] = self

    my $variable = $_[0]->{-variable};
    my $type = ref $variable;
    my $copy = $_[0]->{-ptr} if $type !~ /(SCALAR|REF)/;
    my $shadow = $_[0]->{-shadow};
    undef $_[0];
    if ($type =~ /(SCALAR|REF)/) {
	untie $$variable;
    } elsif ($type =~ /ARRAY/) {
	untie @$variable;
	@$variable = @$copy if $shadow;
    } elsif ($type =~ /HASH/) {
	untie %$variable;
	%$variable = %$copy if $shadow;
    } else {
	croak "Tie::Watch::Delete() - not a variable reference.";
    }

} # end Unwatch

# Watch private methods.

sub base_watch {

    # Watch base class constructor invoked by other Watch modules.

    my($class, %args) = @_;
    my $watch_obj = {%args};
    $watch_obj;

} # end base_watch

sub callback {

    # Execute a Watch callback, either the default or user specified.
    # Note that the arguments are those supplied by the tied method,
    # not those (if any) specified by the user when the watch object
    # was instantiated.  This is for performance reasons, and why the
    # Args() method exists.
    #
    # $_[0] = self
    # $_[1] = callback type
    # $_[2] through $#_ = tied arguments

    &{$_[0]->{$_[1]}->[0]} ($_[0], @_[2 .. $#_]);

} # end callback

sub normalize_callbacks {

    # Ensure all callbacks are normalized in [\&code, @args] format.

    my($args_ref) = @_;
    my($cb, $ref);
    foreach my $arg (keys %$args_ref) {
	next if $arg =~ /variable|debug|shadow/;
	$cb = $args_ref->{$arg};
	$ref = ref $cb;
	if ($ref =~ /CODE/) {
	    $args_ref->{$arg} = [$cb];
	} elsif ($ref !~ /ARRAY/) {
	    croak "Tie::Watch:  malformed callback $arg=$cb.";
	}
    }

} # end normalize_callbacks

###############################################################################

package Tie::Watch::Scalar;

use Carp;
@Tie::Watch::Scalar::ISA = qw/Tie::Watch/;

sub TIESCALAR {

    my($class, %args) = @_;
    my $variable = $args{-variable};
    my $watch_obj = Tie::Watch->base_watch(%args);
    $watch_obj->{-value} = $$variable;
    print "WatchScalar new: $variable created, \@_=", join(',', @_), "!\n"
	if $watch_obj->{-debug};
    bless $watch_obj, $class;

} # end TIESCALAR

sub Info {$_[0]->SUPER::Info('-value', @Tie::Watch::scalar_callbacks)}

# Default scalar callbacks.

sub Destroy {undef %{$_[0]}}
sub Fetch   {$_[0]->{-value}}
sub Store   {$_[0]->{-value} = $_[1]}

# Scalar access methods.

sub DESTROY {$_[0]->callback(-destroy)}
sub FETCH   {$_[0]->callback(-fetch)}
sub STORE   {$_[0]->callback(-store, $_[1])}

###############################################################################

package Tie::Watch::Array;

use Carp;
@Tie::Watch::Array::ISA = qw/Tie::Watch/;

sub TIEARRAY {

    my($class, %args) = @_;
    my($variable, $shadow) = @args{-variable, -shadow};
    my @copy = @$variable if $shadow; # make a private copy of user's array
    $args{-ptr} = $shadow ? \@copy : [];
    my $watch_obj = Tie::Watch->base_watch(%args);
    print "WatchArray new: $variable created, \@_=", join(',', @_), "!\n"
	if $watch_obj->{-debug};
    bless $watch_obj, $class;

} # end TIEARRAY

sub Info {$_[0]->SUPER::Info('-ptr', @Tie::Watch::array_callbacks)}

# Default array callbacks.

sub Clear     {$_[0]->{-ptr} = ()}
sub Destroy   {undef %{$_[0]}}
sub Extend    {}
sub Fetch     {$_[0]->{-ptr}->[$_[1]]}
sub Fetchsize {scalar @{$_[0]->{-ptr}}}
sub Pop       {pop @{$_[0]->{-ptr}}}
sub Push      {push @{$_[0]->{-ptr}}, @_[1 .. $#_]}
sub Shift     {shift @{$_[0]->{-ptr}}}
sub Splice    {
    my $n = scalar @_;		# splice() is wierd!
    return splice @{$_[0]->{-ptr}}, $_[1]                      if $n == 2;
    return splice @{$_[0]->{-ptr}}, $_[1], $_[2]               if $n == 3;
    return splice @{$_[0]->{-ptr}}, $_[1], $_[2], @_[3 .. $#_] if $n >= 4;
}
sub Store     {$_[0]->{-ptr}->[$_[1]] = $_[2]}
sub Storesize {$#{@{$_[0]->{-ptr}}} = $_[1] - 1}
sub Unshift   {unshift @{$_[0]->{-ptr}}, @_[1 .. $#_]}

# Array access methods.

sub CLEAR     {$_[0]->callback(-clear)}
sub DESTROY   {$_[0]->callback(-destroy)}
sub EXTEND    {$_[0]->callback(-extend, $_[1])}
sub FETCH     {$_[0]->callback(-fetch, $_[1])}
sub FETCHSIZE {$_[0]->callback(-fetchsize)}
sub POP       {$_[0]->callback('-pop')}
sub PUSH      {$_[0]->callback('-push', @_[1 .. $#_])}
sub SHIFT     {$_[0]->callback('-shift')}
sub SPLICE    {$_[0]->callback('-splice', @_[1 .. $#_])}
sub STORE     {$_[0]->callback(-store, $_[1], $_[2])}
sub STORESIZE {$_[0]->callback(-storesize, $_[1])}
sub UNSHIFT   {$_[0]->callback('-unshift', @_[1 .. $#_])}

###############################################################################

package Tie::Watch::Hash;

use Carp;
@Tie::Watch::Hash::ISA = qw/Tie::Watch/;

sub TIEHASH {

    my($class, %args) = @_;
    my($variable, $shadow) = @args{-variable, -shadow};
    my %copy = %$variable if $shadow; # make a private copy of user's hash
    $args{-ptr} = $shadow ? \%copy : {};
    my $watch_obj = Tie::Watch->base_watch(%args);
    print "WatchHash new: $variable created, \@_=", join(',', @_), "!\n"
	if $watch_obj->{-debug};
    bless $watch_obj, $class;

} # end TIEHASH

sub Info {$_[0]->SUPER::Info('-ptr', @Tie::Watch::hash_callbacks)}

# Default hash callbacks.

sub Clear    {$_[0]->{-ptr} = ()}
sub Delete   {delete $_[0]->{-ptr}->{$_[1]}}
sub Destroy  {undef %{$_[0]}}
sub Exists   {exists $_[0]->{-ptr}->{$_[1]}}
sub Fetch    {$_[0]->{-ptr}->{$_[1]}}
sub Firstkey {my $c = keys %{$_[0]->{-ptr}}; each %{$_[0]->{-ptr}}}
sub Nextkey  {each %{$_[0]->{-ptr}}}
sub Store    {$_[0]->{-ptr}->{$_[1]} = $_[2]}

# Hash access methods.

sub CLEAR    {$_[0]->callback(-clear)}
sub DELETE   {$_[0]->callback('-delete', $_[1])}
sub DESTROY  {$_[0]->callback(-destroy)}
sub EXISTS   {$_[0]->callback('-exists', $_[1])}
sub FETCH    {$_[0]->callback(-fetch, $_[1])}
sub FIRSTKEY {$_[0]->callback(-firstkey)}
sub NEXTKEY  {$_[0]->callback(-nextkey)}
sub STORE    {$_[0]->callback(-store, $_[1], $_[2])}

1;
