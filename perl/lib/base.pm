package base;

use strict 'vars';
use vars qw($VERSION);
$VERSION = '2.04';

# constant.pm is slow
sub SUCCESS () { 1 }

sub PUBLIC     () { 2**0  }
sub PRIVATE    () { 2**1  }
sub INHERITED  () { 2**2  }
sub PROTECTED  () { 2**3  }


my $Fattr = \%fields::attr;

sub has_fields {
    my($base) = shift;
    my $fglob = ${"$base\::"}{FIELDS};
    return( ($fglob && *$fglob{HASH}) ? 1 : 0 );
}

sub has_version {
    my($base) = shift;
    my $vglob = ${$base.'::'}{VERSION};
    return( ($vglob && *$vglob{SCALAR}) ? 1 : 0 );
}

sub has_attr {
    my($proto) = shift;
    my($class) = ref $proto || $proto;
    return exists $Fattr->{$class};
}

sub get_attr {
    $Fattr->{$_[0]} = [1] unless $Fattr->{$_[0]};
    return $Fattr->{$_[0]};
}

sub get_fields {
    # Shut up a possible typo warning.
    () = \%{$_[0].'::FIELDS'};

    return \%{$_[0].'::FIELDS'};
}

sub import {
    my $class = shift;

    return SUCCESS unless @_;

    # List of base classes from which we will inherit %FIELDS.
    my $fields_base;

    my $inheritor = caller(0);

    foreach my $base (@_) {
        next if $inheritor->isa($base);

        if (has_version($base)) {
	    ${$base.'::VERSION'} = '-1, set by base.pm' 
	      unless defined ${$base.'::VERSION'};
        }
        else {
            local $SIG{__DIE__} = 'IGNORE';
            eval "require $base";
            # Only ignore "Can't locate" errors from our eval require.
            # Other fatal errors (syntax etc) must be reported.
            die if $@ && $@ !~ /^Can't locate .*? at \(eval /;
            unless (%{"$base\::"}) {
                require Carp;
                Carp::croak(<<ERROR);
Base class package "$base" is empty.
    (Perhaps you need to 'use' the module which defines that package first.)
ERROR

            }
            ${$base.'::VERSION'} = "-1, set by base.pm"
              unless defined ${$base.'::VERSION'};
        }
        push @{"$inheritor\::ISA"}, $base;

        if ( has_fields($base) || has_attr($base) ) {
	    # No multiple fields inheritence *suck*
	    if ($fields_base) {
		require Carp;
		Carp::croak("Can't multiply inherit %FIELDS");
	    } else {
		$fields_base = $base;
	    }
        }
    }

    if( defined $fields_base ) {
        inherit_fields($inheritor, $fields_base);
    }
}


sub inherit_fields {
    my($derived, $base) = @_;

    return SUCCESS unless $base;

    my $battr = get_attr($base);
    my $dattr = get_attr($derived);
    my $dfields = get_fields($derived);
    my $bfields = get_fields($base);

    $dattr->[0] = @$battr;

    if( keys %$dfields ) {
        warn "$derived is inheriting from $base but already has its own ".
             "fields!\n".
             "This will cause problems.\n".
             "Be sure you use base BEFORE declaring fields\n";
    }

    # Iterate through the base's fields adding all the non-private
    # ones to the derived class.  Hang on to the original attribute
    # (Public, Private, etc...) and add Inherited.
    # This is all too complicated to do efficiently with add_fields().
    while (my($k,$v) = each %$bfields) {
        my $fno;
	if ($fno = $dfields->{$k} and $fno != $v) {
	    require Carp;
	    Carp::croak ("Inherited %FIELDS can't override existing %FIELDS");
	}

        if( $battr->[$v] & PRIVATE ) {
            $dattr->[$v] = PRIVATE | INHERITED;
        }
        else {
            $dattr->[$v] = INHERITED | $battr->[$v];
            $dfields->{$k} = $v;
        }
    }

    unless( keys %$bfields ) {
        foreach my $idx (1..$#{$battr}) {
            $dattr->[$idx] = $battr->[$idx] & INHERITED;
        }
    }
}


1;

__END__

