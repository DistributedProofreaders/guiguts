#############################################################################
## Name:        Carp.pm
## Purpose:     Wx::Carp class (a replacement for Carp in Wx applications)
## Author:      D.H. aka PodMaster
## Modified by:
## Created:      12/24/2002
## RCS-ID:      
## Copyright:   (c) 2002 D.H.
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

package Wx::Carp;

BEGIN {
    require Carp;
    require Wx;
}

use Exporter;
@ISA         = qw( Exporter );
@EXPORT      = qw( confess croak carp die warn);
@EXPORT_OK   = qw( cluck verbose );
@EXPORT_FAIL = qw( verbose );              # hook to enable verbose mode

sub export_fail { Carp::export_fail( @_) } # make verbose work for me
sub croak   { Wx::LogFatalError( Carp::shortmess(@_) ) }
sub confess { Wx::LogFatalError( Carp::longmess(@_) ) }
sub carp    { Wx::LogWarning( Carp::shortmess(@_) ) }
sub cluck   { Wx::LogWarning( Carp::longmess(@_) ) }
sub warn    { Wx::LogWarning( @_ ) }
sub die     { Wx::LogFatalError( @_ ) }

1;
