package Search::Dict;
require 5.000;
require Exporter;

use strict;

our $VERSION = '1.02';
our @ISA = qw(Exporter);
our @EXPORT = qw(look);

sub look {
    my($fh,$key,$dict,$fold) = @_;
    my ($comp, $xfrm);
    if (@_ == 3 && ref $dict eq 'HASH') {
	my $params = $dict;
	$dict = 0;
	$dict = $params->{dict} if exists $params->{dict};
	$fold = $params->{fold} if exists $params->{fold};
	$comp = $params->{comp} if exists $params->{comp};
	$xfrm = $params->{xfrm} if exists $params->{xfrm};
    }
    $comp = sub { $_[0] cmp $_[1] } unless defined $comp;
    local($_);
    my(@stat) = stat($fh)
	or return -1;
    my($size, $blksize) = @stat[7,11];
    $blksize ||= 8192;
    $key =~ s/[^\w\s]//g if $dict;
    $key = lc $key       if $fold;
    # find the right block
    my($min, $max) = (0, int($size / $blksize));
    my $mid;
    while ($max - $min > 1) {
	$mid = int(($max + $min) / 2);
	seek($fh, $mid * $blksize, 0)
	    or return -1;
	<$fh> if $mid;			# probably a partial line
	$_ = <$fh>;
	$_ = $xfrm->($_) if defined $xfrm;
	chomp;
	s/[^\w\s]//g if $dict;
	$_ = lc $_   if $fold;
	if (defined($_) && $comp->($_, $key) < 0) {
	    $min = $mid;
	}
	else {
	    $max = $mid;
	}
    }
    # find the right line
    $min *= $blksize;
    seek($fh,$min,0)
	or return -1;
    <$fh> if $min;
    for (;;) {
	$min = tell($fh);
	defined($_ = <$fh>)
	    or last;
	$_ = $xfrm->($_) if defined $xfrm;
	chomp;
	s/[^\w\s]//g if $dict;
	$_ = lc $_   if $fold;
	last if $comp->($_, $key) >= 0;
    }
    seek($fh,$min,0);
    $min;
}

1;
