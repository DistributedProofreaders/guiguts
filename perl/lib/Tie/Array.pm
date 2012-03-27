package Tie::Array;

use 5.006_001;
use strict;
use Carp;
our $VERSION = '1.03';

# Pod documentation after __END__ below.

sub DESTROY { }
sub EXTEND  { }
sub UNSHIFT { scalar shift->SPLICE(0,0,@_) }
sub SHIFT { shift->SPLICE(0,1) }
sub CLEAR   { shift->STORESIZE(0) }

sub PUSH
{
 my $obj = shift;
 my $i   = $obj->FETCHSIZE;
 $obj->STORE($i++, shift) while (@_);
}

sub POP
{
 my $obj = shift;
 my $newsize = $obj->FETCHSIZE - 1;
 my $val;
 if ($newsize >= 0)
  {
   $val = $obj->FETCH($newsize);
   $obj->STORESIZE($newsize);
  }
 $val;
}

sub SPLICE {
    my $obj = shift;
    my $sz  = $obj->FETCHSIZE;
    my $off = (@_) ? shift : 0;
    $off += $sz if ($off < 0);
    my $len = (@_) ? shift : $sz - $off;
    $len += $sz - $off if $len < 0;
    my @result;
    for (my $i = 0; $i < $len; $i++) {
        push(@result,$obj->FETCH($off+$i));
    }
    $off = $sz if $off > $sz;
    $len -= $off + $len - $sz if $off + $len > $sz;
    if (@_ > $len) {
        # Move items up to make room
        my $d = @_ - $len;
        my $e = $off+$len;
        $obj->EXTEND($sz+$d);
        for (my $i=$sz-1; $i >= $e; $i--) {
            my $val = $obj->FETCH($i);
            $obj->STORE($i+$d,$val);
        }
    }
    elsif (@_ < $len) {
        # Move items down to close the gap
        my $d = $len - @_;
        my $e = $off+$len;
        for (my $i=$off+$len; $i < $sz; $i++) {
            my $val = $obj->FETCH($i);
            $obj->STORE($i-$d,$val);
        }
        $obj->STORESIZE($sz-$d);
    }
    for (my $i=0; $i < @_; $i++) {
        $obj->STORE($off+$i,$_[$i]);
    }
    return wantarray ? @result : pop @result;
}

sub EXISTS {
    my $pkg = ref $_[0];
    croak "$pkg doesn't define an EXISTS method";
}

sub DELETE {
    my $pkg = ref $_[0];
    croak "$pkg doesn't define a DELETE method";
}

package Tie::StdArray;
use vars qw(@ISA);
@ISA = 'Tie::Array';

sub TIEARRAY  { bless [], $_[0] }
sub FETCHSIZE { scalar @{$_[0]} }
sub STORESIZE { $#{$_[0]} = $_[1]-1 }
sub STORE     { $_[0]->[$_[1]] = $_[2] }
sub FETCH     { $_[0]->[$_[1]] }
sub CLEAR     { @{$_[0]} = () }
sub POP       { pop(@{$_[0]}) }
sub PUSH      { my $o = shift; push(@$o,@_) }
sub SHIFT     { shift(@{$_[0]}) }
sub UNSHIFT   { my $o = shift; unshift(@$o,@_) }
sub EXISTS    { exists $_[0]->[$_[1]] }
sub DELETE    { delete $_[0]->[$_[1]] }

sub SPLICE
{
 my $ob  = shift;
 my $sz  = $ob->FETCHSIZE;
 my $off = @_ ? shift : 0;
 $off   += $sz if $off < 0;
 my $len = @_ ? shift : $sz-$off;
 return splice(@$ob,$off,$len,@_);
}

1;

__END__

