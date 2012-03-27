package Memoize::AnyDBM_File;

use vars qw(@ISA $VERSION);
$VERSION = 0.65;
@ISA = qw(DB_File GDBM_File Memoize::NDBM_File Memoize::SDBM_File ODBM_File) unless @ISA;

my $verbose = 1;

my $mod;
for $mod (@ISA) {
#  (my $truemod = $mod) =~ s/^Memoize:://;
#  my $file = "$mod.pm";
#  $file =~ s{::}{/}g;
  if (eval "require $mod") {
    print STDERR "AnyDBM_File => Selected $mod.\n" if $Verbose;
    @ISA = ($mod);	# if we leave @ISA alone, warnings abound
    return 1;
  }
}

die "No DBM package was successfully found or installed";
