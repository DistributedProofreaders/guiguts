package ExtUtils::Command;

use 5.00503;
use strict;
use Carp;
use File::Copy;
use File::Compare;
use File::Basename;
use File::Path qw(rmtree);
require Exporter;
use vars qw(@ISA @EXPORT $VERSION);
@ISA     = qw(Exporter);
@EXPORT  = qw(cp rm_f rm_rf mv cat eqtime mkpath touch test_f);
$VERSION = '1.05';

my $Is_VMS = $^O eq 'VMS';

# VMS uses % instead of ? to mean "one character"
my $wild_regex = $Is_VMS ? '*%' : '*?';
sub expand_wildcards
{
 @ARGV = map(/[$wild_regex]/o ? glob($_) : $_,@ARGV);
}


sub cat ()
{
 expand_wildcards();
 print while (<>);
}

sub eqtime
{
 my ($src,$dst) = @ARGV;
 local @ARGV = ($dst);  touch();  # in case $dst doesn't exist
 utime((stat($src))[8,9],$dst);
}

sub rm_rf
{
 expand_wildcards();
 rmtree([grep -e $_,@ARGV],0,0);
}

sub rm_f
{
 expand_wildcards();
 foreach (@ARGV)
  {
   next unless -f $_;
   next if unlink($_);
   chmod(0777,$_);
   next if unlink($_);
   carp "Cannot delete $_:$!";
  }
}

sub touch {
    my $t    = time;
    expand_wildcards();
    foreach my $file (@ARGV) {
        open(FILE,">>$file") || die "Cannot write $file:$!";
        close(FILE);
        utime($t,$t,$file);
    }
}

sub mv {
    my $dst = pop(@ARGV);
    expand_wildcards();
    croak("Too many arguments") if (@ARGV > 1 && ! -d $dst);
    foreach my $src (@ARGV) {
        move($src,$dst);
    }
}

sub cp {
    my $dst = pop(@ARGV);
    expand_wildcards();
    croak("Too many arguments") if (@ARGV > 1 && ! -d $dst);
    foreach my $src (@ARGV) {
        copy($src,$dst);
    }
}

sub chmod {
    my $mode = shift(@ARGV);
    expand_wildcards();
    chmod(oct $mode,@ARGV) || die "Cannot chmod ".join(' ',$mode,@ARGV).":$!";
}

sub mkpath
{
 expand_wildcards();
 File::Path::mkpath([@ARGV],0,0777);
}

sub test_f
{
 exit !-f shift(@ARGV);
}


1;
__END__ 

