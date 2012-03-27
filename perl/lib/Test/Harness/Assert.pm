# $Id: Assert.pm,v 1.3 2003/09/11 15:57:29 andy Exp $

package Test::Harness::Assert;

use strict;
require Exporter;
use vars qw($VERSION @EXPORT @ISA);

$VERSION = '0.02';

@ISA = qw(Exporter);
@EXPORT = qw(assert);


sub assert ($;$) {
    my($assert, $name) = @_;

    unless( $assert ) {
        require Carp;
        my $msg = 'Assert failed';
        $msg .= " - '$name'" if defined $name;
        $msg .= '!';
        Carp::croak($msg);
    }

}

1;
