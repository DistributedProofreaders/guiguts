package Memoize::ExpireTest;

$VERSION = 0.65;
my %cache;

sub TIEHASH {	
  my ($pack) = @_;
  bless \%cache => $pack;
}

sub EXISTS {
  my ($cache, $key) = @_;
  exists $cache->{$key} ? 1 : 0;
}

sub FETCH {
  my ($cache, $key) = @_;
  $cache->{$key};
}

sub STORE {
  my ($cache, $key, $val) = @_;
  $cache->{$key} = $val;
}

sub expire {
  my ($key) = @_;
  delete $cache{$key};
}

1;
