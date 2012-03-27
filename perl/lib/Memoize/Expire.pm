
package Memoize::Expire;
# require 5.00556;
use Carp;
$DEBUG = 0;
$VERSION = '1.00';

# This package will implement expiration by prepending a fixed-length header
# to the font of the cached data.  The format of the header will be:
# (4-byte number of last-access-time)  (For LRU when I implement it)
# (4-byte expiration time: unsigned seconds-since-unix-epoch)
# (2-byte number-of-uses-before-expire)

sub _header_fmt () { "N N n" }
sub _header_size () { length(_header_fmt) }

# Usage:  memoize func 
#         TIE => [Memoize::Expire, LIFETIME => sec, NUM_USES => n,
#                 TIE => [...] ]

BEGIN {
  eval {require Time::HiRes};
  unless ($@) {
    Time::HiRes->import('time');
  }
}

sub TIEHASH {
  my ($package, %args) = @_;
  my %cache;
  if ($args{TIE}) {
    my ($module, @opts) = @{$args{TIE}};
    my $modulefile = $module . '.pm';
    $modulefile =~ s{::}{/}g;
    eval { require $modulefile };
    if ($@) {
      croak "Memoize::Expire: Couldn't load hash tie module `$module': $@; aborting";
    }
    my $rc = (tie %cache => $module, @opts);
    unless ($rc) {
      croak "Memoize::Expire: Couldn't tie hash to `$module': $@; aborting";
    }
  }
  $args{LIFETIME} ||= 0;
  $args{NUM_USES} ||= 0;
  $args{C} = \%cache;
  bless \%args => $package;
}

sub STORE {
  $DEBUG and print STDERR " >> Store $_[1] $_[2]\n";
  my ($self, $key, $value) = @_;
  my $expire_time = $self->{LIFETIME} > 0 ? $self->{LIFETIME} + time : 0;
  # The call that results in a value to store into the cache is the
  # first of the NUM_USES allowed calls.
  my $header = _make_header(time, $expire_time, $self->{NUM_USES}-1);
  $self->{C}{$key} = $header . $value;
  $value;
}

sub FETCH {
  $DEBUG and print STDERR " >> Fetch cached value for $_[1]\n";
  my ($data, $last_access, $expire_time, $num_uses_left) = _get_item($_[0]{C}{$_[1]});
  $DEBUG and print STDERR " >>   (ttl: ", ($expire_time-time()), ", nuses: $num_uses_left)\n";
  $num_uses_left--;
  $last_access = time;
  _set_header(@_, $data, $last_access, $expire_time, $num_uses_left);
  $data;
}

sub EXISTS {
  $DEBUG and print STDERR " >> Exists $_[1]\n";
  unless (exists $_[0]{C}{$_[1]}) {
    $DEBUG and print STDERR "    Not in underlying hash at all.\n";
    return 0;
  }
  my $item = $_[0]{C}{$_[1]};
  my ($last_access, $expire_time, $num_uses_left) = _get_header($item);
  my $ttl = $expire_time - time;
  if ($DEBUG) {
    $_[0]{LIFETIME} and print STDERR "    Time to live for this item: $ttl\n";
    $_[0]{NUM_USES} and print STDERR "    Uses remaining: $num_uses_left\n";
  }
  if (   (! $_[0]{LIFETIME} || $expire_time > time)
      && (! $_[0]{NUM_USES} || $num_uses_left > 0 )) {
	    $DEBUG and print STDERR "    (Still good)\n";
    return 1;
  } else {
    $DEBUG and print STDERR "    (Expired)\n";
    return 0;
  }
}

# Arguments: last access time, expire time, number of uses remaining
sub _make_header {
  pack "N N n", @_;
}

sub _strip_header {
  substr($_[0], 10);
}

# Arguments: last access time, expire time, number of uses remaining
sub _set_header {
  my ($self, $key, $data, @header) = @_;
  $self->{C}{$key} = _make_header(@header) . $data;
}

sub _get_item {
  my $data = substr($_[0], 10);
  my @header = unpack "N N n", substr($_[0], 0, 10);
#  print STDERR " >> _get_item: $data => $data @header\n";
  ($data, @header);
}

# Return last access time, expire time, number of uses remaining
sub _get_header  {
  unpack "N N n", substr($_[0], 0, 10);
}

1;

