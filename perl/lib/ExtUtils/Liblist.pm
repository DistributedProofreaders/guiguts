package ExtUtils::Liblist;

use vars qw($VERSION);
$VERSION = '1.01';

use File::Spec;
require ExtUtils::Liblist::Kid;
@ISA = qw(ExtUtils::Liblist::Kid File::Spec);

# Backwards compatibility with old interface.
sub ext {
    goto &ExtUtils::Liblist::Kid::ext;
}

sub lsdir {
  shift;
  my $rex = qr/$_[1]/;
  opendir DIR, $_[0];
  my @out = grep /$rex/, readdir DIR;
  closedir DIR;
  return @out;
}

__END__

