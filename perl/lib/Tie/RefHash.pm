package Tie::RefHash;

our $VERSION = 1.31;

use Tie::Hash;
use vars '@ISA';
@ISA = qw(Tie::Hash);
use strict;

require overload; # to support objects with overloaded ""

sub TIEHASH {
  my $c = shift;
  my $s = [];
  bless $s, $c;
  while (@_) {
    $s->STORE(shift, shift);
  }
  return $s;
}

sub FETCH {
  my($s, $k) = @_;
  if (ref $k) {
      my $kstr = overload::StrVal($k);
      if (defined $s->[0]{$kstr}) {
        $s->[0]{$kstr}[1];
      }
      else {
        undef;
      }
  }
  else {
      $s->[1]{$k};
  }
}

sub STORE {
  my($s, $k, $v) = @_;
  if (ref $k) {
    $s->[0]{overload::StrVal($k)} = [$k, $v];
  }
  else {
    $s->[1]{$k} = $v;
  }
  $v;
}

sub DELETE {
  my($s, $k) = @_;
  (ref $k) ? delete($s->[0]{overload::StrVal($k)}) : delete($s->[1]{$k});
}

sub EXISTS {
  my($s, $k) = @_;
  (ref $k) ? exists($s->[0]{overload::StrVal($k)}) : exists($s->[1]{$k});
}

sub FIRSTKEY {
  my $s = shift;
  keys %{$s->[0]};	# reset iterator
  keys %{$s->[1]};	# reset iterator
  $s->[2] = 0;      # flag for iteration, see NEXTKEY
  $s->NEXTKEY;
}

sub NEXTKEY {
  my $s = shift;
  my ($k, $v);
  if (!$s->[2]) {
    if (($k, $v) = each %{$s->[0]}) {
      return $v->[0];
    }
    else {
      $s->[2] = 1;
    }
  }
  return each %{$s->[1]};
}

sub CLEAR {
  my $s = shift;
  $s->[2] = 0;
  %{$s->[0]} = ();
  %{$s->[1]} = ();
}

package Tie::RefHash::Nestable;
use vars '@ISA';
@ISA = 'Tie::RefHash';

sub STORE {
  my($s, $k, $v) = @_;
  if (ref($v) eq 'HASH' and not tied %$v) {
      my @elems = %$v;
      tie %$v, ref($s), @elems;
  }
  $s->SUPER::STORE($k, $v);
}

1;
