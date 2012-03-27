package blib;

use Cwd;
use File::Spec;

use vars qw($VERSION $Verbose);
$VERSION = '1.02';
$Verbose = 0;

sub import
{
 my $package = shift;
 my $dir = getcwd;
 if ($^O eq 'VMS') { ($dir = VMS::Filespec::unixify($dir)) =~ s-/\z--; }
 if (@_)
  {
   $dir = shift;
   $dir =~ s/blib\z//;
   $dir =~ s,/+\z,,;
   $dir = File::Spec->curdir unless ($dir);
   die "$dir is not a directory\n" unless (-d $dir);
  }
 my $i = 5;
 my($blib, $blib_lib, $blib_arch);
 while ($i--)
  {
   $blib = File::Spec->catdir($dir, "blib");
   $blib_lib = File::Spec->catdir($blib, "lib");

   if ($^O eq 'MacOS')
    {
     $blib_arch = File::Spec->catdir($blib_lib, $MacPerl::Architecture);
    }
   else
    {
     $blib_arch = File::Spec->catdir($blib, "arch");
    }

   if (-d $blib && -d $blib_arch && -d $blib_lib)
    {
     unshift(@INC,$blib_arch,$blib_lib);
     warn "Using $blib\n" if $Verbose;
     return;
    }
   $dir = File::Spec->catdir($dir, File::Spec->updir);
  }
 die "Cannot find blib even in $dir\n";
}

1;
