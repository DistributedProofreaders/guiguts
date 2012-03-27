package File::Spec::Cygwin;

use strict;
use vars qw(@ISA $VERSION);
require File::Spec::Unix;

$VERSION = '1.1';

@ISA = qw(File::Spec::Unix);

sub canonpath {
    my($self,$path) = @_;
    $path =~ s|\\|/|g;
    return $self->SUPER::canonpath($path);
}


sub file_name_is_absolute {
    my ($self,$file) = @_;
    return 1 if $file =~ m{^([a-z]:)?[\\/]}is; # C:/test
    return $self->SUPER::file_name_is_absolute($file);
}

my $tmpdir;
sub tmpdir {
    return $tmpdir if defined $tmpdir;
    my $self = shift;
    $tmpdir = $self->_tmpdir( $ENV{TMPDIR}, "/tmp", 'C:/temp' );
}

1;
