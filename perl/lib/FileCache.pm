package FileCache;

our $VERSION = 1.03;

require 5.006;
use Carp;
use Config;
use strict;
no strict 'refs';
# These are not C<my> for legacy reasons.
# Previous versions requested the user set $cacheout_maxopen by hand.
# Some authors fiddled with %saw to overcome the clobber on initial open.
use vars qw(%saw $cacheout_maxopen);
my %isopen;
my $cacheout_seq = 0;

sub import {
    my ($pkg,%args) = @_;
    $pkg = caller(1);
    *{$pkg.'::cacheout'} = \&cacheout;
    *{$pkg.'::close'}    = \&cacheout_close;

    # Reap our children
    ${"$pkg\::SIG"}{'CLD'}  = 'IGNORE' if $Config{sig_name} =~ /\bCLD\b/;
    ${"$pkg\::SIG"}{'CHLD'} = 'IGNORE' if $Config{sig_name} =~ /\bCHLD\b/;
    ${"$pkg\::SIG"}{'PIPE'} = 'IGNORE' if $Config{sig_name} =~ /\bPIPE\b/;

    # Truth is okay here because setting maxopen to 0 would be bad
    return $cacheout_maxopen = $args{maxopen} if $args{maxopen};
    foreach my $param ( '/usr/include/sys/param.h' ){
      if (open($param, '<', $param)) {
	local ($_, $.);
	while (<$param>) {
	  if( /^\s*#\s*define\s+NOFILE\s+(\d+)/ ){
	    $cacheout_maxopen = $1 - 4;
	    close($param);
	    last;
	  }
	}
	close $param;
      }
    }
    $cacheout_maxopen ||= 16;
}

# Open in their package.
sub cacheout_open {
  return open(*{caller(1) . '::' . $_[1]}, $_[0], $_[1]) && $_[1];
}

# Close in their package.
sub cacheout_close {
  # Short-circuit in case the filehandle disappeared
  my $pkg = caller($_[1]||0);
  fileno(*{$pkg . '::' . $_[0]}) &&
    CORE::close(*{$pkg . '::' . $_[0]});
  delete $isopen{$_[0]};
}

# But only this sub name is visible to them.
sub cacheout {
    my($mode, $file, $class, $ret, $ref, $narg);
    croak "Not enough arguments for cacheout"  unless $narg = scalar @_;
    croak "Too many arguments for cacheout"    if $narg > 2;

    ($mode, $file) = @_;
    ($file, $mode) = ($mode, $file) if $narg == 1;
    croak "Invalid mode for cacheout" if $mode &&
      ( $mode !~ /^\s*(?:>>|\+?>|\+?<|\|\-|)|\-\|\s*$/ );
    
    # Mode changed?
    if( $isopen{$file} && ($mode||'>') ne $isopen{$file}->[2] ){
      &cacheout_close($file, 1);
    }
    
    if( $isopen{$file}) {
      $ret = $file;
      $isopen{$file}->[0]++;
    }
    else{
      if( scalar keys(%isopen) > $cacheout_maxopen -1 ) {
	my @lru = sort{ $isopen{$a}->[0] <=> $isopen{$b}->[0] } keys(%isopen);
	$cacheout_seq = 0;
	$isopen{$_}->[0] = $cacheout_seq++ for
	  splice(@lru, int($cacheout_maxopen / 3)||$cacheout_maxopen);
	&cacheout_close($_, 1) for @lru;
      }

      unless( $ref ){
	$mode ||= $saw{$file} ? '>>' : ($saw{$file}=1, '>');
      }
      #XXX should we just return the value from cacheout_open, no croak?
      $ret = cacheout_open($mode, $file) or croak("Can't create $file: $!");
      
      $isopen{$file} = [++$cacheout_seq, $mode];
    }
    return $ret;
}
1;
