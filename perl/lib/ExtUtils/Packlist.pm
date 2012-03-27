package ExtUtils::Packlist;

use 5.00503;
use strict;
use Carp qw();
use vars qw($VERSION);
$VERSION = '0.04';

# Used for generating filehandle globs.  IO::File might not be available!
my $fhname = "FH1";

sub mkfh()
{
no strict;
my $fh = \*{$fhname++};
use strict;
return($fh);
}

sub new($$)
{
my ($class, $packfile) = @_;
$class = ref($class) || $class;
my %self;
tie(%self, $class, $packfile);
return(bless(\%self, $class));
}

sub TIEHASH
{
my ($class, $packfile) = @_;
my $self = { packfile => $packfile };
bless($self, $class);
$self->read($packfile) if (defined($packfile) && -f $packfile);
return($self);
}

sub STORE
{
$_[0]->{data}->{$_[1]} = $_[2];
}

sub FETCH
{
return($_[0]->{data}->{$_[1]});
}

sub FIRSTKEY
{
my $reset = scalar(keys(%{$_[0]->{data}}));
return(each(%{$_[0]->{data}}));
}

sub NEXTKEY
{
return(each(%{$_[0]->{data}}));
}

sub EXISTS
{
return(exists($_[0]->{data}->{$_[1]}));
}

sub DELETE
{
return(delete($_[0]->{data}->{$_[1]}));
}

sub CLEAR
{
%{$_[0]->{data}} = ();
}

sub DESTROY
{
}

sub read($;$)
{
my ($self, $packfile) = @_;
$self = tied(%$self) || $self;

if (defined($packfile)) { $self->{packfile} = $packfile; }
else { $packfile = $self->{packfile}; }
Carp::croak("No packlist filename specified") if (! defined($packfile));
my $fh = mkfh();
open($fh, "<$packfile") || Carp::croak("Can't open file $packfile: $!");
$self->{data} = {};
my ($line);
while (defined($line = <$fh>))
   {
   chomp $line;
   my ($key, @kvs) = $line;
   if ($key =~ /^(.*?)( \w+=.*)$/)
      {
      $key = $1;
      @kvs = split(' ', $2);
      }
   $key =~ s!/\./!/!g;   # Some .packlists have spurious '/./' bits in the paths
   if (! @kvs)
      {
      $self->{data}->{$key} = undef;
      }
   else
      {
      my ($data) = {};
      foreach my $kv (@kvs)
         {
         my ($k, $v) = split('=', $kv);
         $data->{$k} = $v;
         }
      $self->{data}->{$key} = $data;
      }
   }
close($fh);
}

sub write($;$)
{
my ($self, $packfile) = @_;
$self = tied(%$self) || $self;
if (defined($packfile)) { $self->{packfile} = $packfile; }
else { $packfile = $self->{packfile}; }
Carp::croak("No packlist filename specified") if (! defined($packfile));
my $fh = mkfh();
open($fh, ">$packfile") || Carp::croak("Can't open file $packfile: $!");
foreach my $key (sort(keys(%{$self->{data}})))
   {
   print $fh ("$key");
   if (ref($self->{data}->{$key}))
      {
      my $data = $self->{data}->{$key};
      foreach my $k (sort(keys(%$data)))
         {
         print $fh (" $k=$data->{$k}");
         }
      }
   print $fh ("\n");
   }
close($fh);
}

sub validate($;$)
{
my ($self, $remove) = @_;
$self = tied(%$self) || $self;
my @missing;
foreach my $key (sort(keys(%{$self->{data}})))
   {
   if (! -e $key)
      {
      push(@missing, $key);
      delete($self->{data}{$key}) if ($remove);
      }
   }
return(@missing);
}

sub packlist_file($)
{
my ($self) = @_;
$self = tied(%$self) || $self;
return($self->{packfile});
}

1;

__END__

