
# Call.pm
#
# Copyright (c) 1995-2001 Paul Marquess. All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
 
package Filter::Util::Call ;

require 5.002 ;
require DynaLoader;
require Exporter;
use Carp ;
use strict;
use warnings;
use vars qw($VERSION @ISA @EXPORT) ;

@ISA = qw(Exporter DynaLoader);
@EXPORT = qw( filter_add filter_del filter_read filter_read_exact) ;
$VERSION = "1.0601" ;

sub filter_read_exact($)
{
    my ($size)   = @_ ;
    my ($left)   = $size ;
    my ($status) ;

    croak ("filter_read_exact: size parameter must be > 0")
	unless $size > 0 ;

    # try to read a block which is exactly $size bytes long
    while ($left and ($status = filter_read($left)) > 0) {
        $left = $size - length $_ ;
    }

    # EOF with pending data is a special case
    return 1 if $status == 0 and length $_ ;

    return $status ;
}

sub filter_add($)
{
    my($obj) = @_ ;

    # Did we get a code reference?
    my $coderef = (ref $obj eq 'CODE') ;

    # If the parameter isn't already a reference, make it one.
    $obj = \$obj unless ref $obj ;

    $obj = bless ($obj, (caller)[0]) unless $coderef ;

    # finish off the installation of the filter in C.
    Filter::Util::Call::real_import($obj, (caller)[0], $coderef) ;
}

bootstrap Filter::Util::Call ;

1;
__END__

