package Benchmark;

use strict;


# evaluate something in a clean lexical environment
sub _doeval { no strict;  eval shift }

#
# put any lexicals at file scope AFTER here
#

use Carp;
use Exporter;

our(@ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS, $VERSION);

@ISA=qw(Exporter);
@EXPORT=qw(timeit timethis timethese timediff timestr);
@EXPORT_OK=qw(timesum cmpthese countit
	      clearcache clearallcache disablecache enablecache);
%EXPORT_TAGS=( all => [ @EXPORT, @EXPORT_OK ] ) ;

$VERSION = 1.052;

# --- ':hireswallclock' special handling

my $hirestime;

sub mytime () { time }

init();

sub BEGIN {
    if (eval 'require Time::HiRes') {
	import Time::HiRes qw(time);
	$hirestime = \&Time::HiRes::time;
    }
}

sub import {
    my $class = shift;
    if (grep { $_ eq ":hireswallclock" } @_) {
	@_ = grep { $_ ne ":hireswallclock" } @_;
	*mytime = $hirestime if defined $hirestime;
    }
    Benchmark->export_to_level(1, $class, @_);
}

our($Debug, $Min_Count, $Min_CPU, $Default_Format, $Default_Style,
    %_Usage, %Cache, $Do_Cache);

sub init {
    $Debug = 0;
    $Min_Count = 4;
    $Min_CPU   = 0.4;
    $Default_Format = '5.2f';
    $Default_Style = 'auto';
    # The cache can cause a slight loss of sys time accuracy. If a
    # user does many tests (>10) with *very* large counts (>10000)
    # or works on a very slow machine the cache may be useful.
    disablecache();
    clearallcache();
}

sub debug { $Debug = ($_[1] != 0); }

sub usage { 
    my $calling_sub = (caller(1))[3];
    $calling_sub =~ s/^Benchmark:://;
    return $_Usage{$calling_sub} || '';
}

# The cache needs two branches: 's' for strings and 'c' for code.  The
# empty loop is different in these two cases.

$_Usage{clearcache} = <<'USAGE';
usage: clearcache($count);
USAGE

sub clearcache    { 
    die usage unless @_ == 1;
    delete $Cache{"$_[0]c"}; delete $Cache{"$_[0]s"}; 
}

$_Usage{clearallcache} = <<'USAGE';
usage: clearallcache();
USAGE

sub clearallcache { 
    die usage if @_;
    %Cache = (); 
}

$_Usage{enablecache} = <<'USAGE';
usage: enablecache();
USAGE

sub enablecache   {
    die usage if @_;
    $Do_Cache = 1; 
}

$_Usage{disablecache} = <<'USAGE';
usage: disablecache();
USAGE

sub disablecache  {
    die usage if @_;
    $Do_Cache = 0; 
}


# --- Functions to process the 'time' data type

sub new { my @t = (mytime, times, @_ == 2 ? $_[1] : 0);
	  print STDERR "new=@t\n" if $Debug;
	  bless \@t; }

sub cpu_p { my($r,$pu,$ps,$cu,$cs) = @{$_[0]}; $pu+$ps         ; }
sub cpu_c { my($r,$pu,$ps,$cu,$cs) = @{$_[0]};         $cu+$cs ; }
sub cpu_a { my($r,$pu,$ps,$cu,$cs) = @{$_[0]}; $pu+$ps+$cu+$cs ; }
sub real  { my($r,$pu,$ps,$cu,$cs) = @{$_[0]}; $r              ; }
sub iters { $_[0]->[5] ; }


$_Usage{timediff} = <<'USAGE';
usage: $result_diff = timediff($result1, $result2);
USAGE

sub timediff {
    my($a, $b) = @_;

    die usage unless ref $a and ref $b;

    my @r;
    for (my $i=0; $i < @$a; ++$i) {
	push(@r, $a->[$i] - $b->[$i]);
    }
    bless \@r;
}

$_Usage{timesum} = <<'USAGE';
usage: $sum = timesum($result1, $result2);
USAGE

sub timesum {
    my($a, $b) = @_;

    die usage unless ref $a and ref $b;

    my @r;
    for (my $i=0; $i < @$a; ++$i) {
 	push(@r, $a->[$i] + $b->[$i]);
    }
    bless \@r;
}


$_Usage{timestr} = <<'USAGE';
usage: $formatted_result = timestr($result1);
USAGE

sub timestr {
    my($tr, $style, $f) = @_;

    die usage unless ref $tr;

    my @t = @$tr;
    warn "bad time value (@t)" unless @t==6;
    my($r, $pu, $ps, $cu, $cs, $n) = @t;
    my($pt, $ct, $tt) = ($tr->cpu_p, $tr->cpu_c, $tr->cpu_a);
    $f = $Default_Format unless defined $f;
    # format a time in the required style, other formats may be added here
    $style ||= $Default_Style;
    return '' if $style eq 'none';
    $style = ($ct>0) ? 'all' : 'noc' if $style eq 'auto';
    my $s = "@t $style"; # default for unknown style
    my $w = $hirestime ? "%2g" : "%2d";
    $s=sprintf("$w wallclock secs (%$f usr %$f sys + %$f cusr %$f csys = %$f CPU)",
			    $r,$pu,$ps,$cu,$cs,$tt) if $style eq 'all';
    $s=sprintf("$w wallclock secs (%$f usr + %$f sys = %$f CPU)",
			    $r,$pu,$ps,$pt) if $style eq 'noc';
    $s=sprintf("$w wallclock secs (%$f cusr + %$f csys = %$f CPU)",
			    $r,$cu,$cs,$ct) if $style eq 'nop';
    $s .= sprintf(" @ %$f/s (n=$n)", $n / ( $pu + $ps )) if $n && $pu+$ps;
    $s;
}

sub timedebug {
    my($msg, $t) = @_;
    print STDERR "$msg",timestr($t),"\n" if $Debug;
}

# --- Functions implementing low-level support for timing loops

$_Usage{runloop} = <<'USAGE';
usage: runloop($number, [$string | $coderef])
USAGE

sub runloop {
    my($n, $c) = @_;

    $n+=0; # force numeric now, so garbage won't creep into the eval
    croak "negative loopcount $n" if $n<0;
    confess usage unless defined $c;
    my($t0, $t1, $td); # before, after, difference

    # find package of caller so we can execute code there
    my($curpack) = caller(0);
    my($i, $pack)= 0;
    while (($pack) = caller(++$i)) {
	last if $pack ne $curpack;
    }

    my ($subcode, $subref);
    if (ref $c eq 'CODE') {
	$subcode = "sub { for (1 .. $n) { local \$_; package $pack; &\$c; } }";
        $subref  = eval $subcode;
    }
    else {
	$subcode = "sub { for (1 .. $n) { local \$_; package $pack; $c;} }";
        $subref  = _doeval($subcode);
    }
    croak "runloop unable to compile '$c': $@\ncode: $subcode\n" if $@;
    print STDERR "runloop $n '$subcode'\n" if $Debug;

    # Wait for the user timer to tick.  This makes the error range more like 
    # -0.01, +0.  If we don't wait, then it's more like -0.01, +0.01.  This
    # may not seem important, but it significantly reduces the chances of
    # getting a too low initial $n in the initial, 'find the minimum' loop
    # in &countit.  This, in turn, can reduce the number of calls to
    # &runloop a lot, and thus reduce additive errors.
    my $tbase = Benchmark->new(0)->[1];
    while ( ( $t0 = Benchmark->new(0) )->[1] == $tbase ) {} ;
    &$subref;
    $t1 = Benchmark->new($n);
    $td = &timediff($t1, $t0);
    timedebug("runloop:",$td);
    $td;
}

$_Usage{timeit} = <<'USAGE';
usage: $result = timeit($count, 'code' );        or
       $result = timeit($count, sub { code } );
USAGE

sub timeit {
    my($n, $code) = @_;
    my($wn, $wc, $wd);

    die usage unless defined $code and
                     (!ref $code or ref $code eq 'CODE');

    printf STDERR "timeit $n $code\n" if $Debug;
    my $cache_key = $n . ( ref( $code ) ? 'c' : 's' );
    if ($Do_Cache && exists $Cache{$cache_key} ) {
	$wn = $Cache{$cache_key};
    } else {
	$wn = &runloop($n, ref( $code ) ? sub { } : '' );
	# Can't let our baseline have any iterations, or they get subtracted
	# out of the result.
	$wn->[5] = 0;
	$Cache{$cache_key} = $wn;
    }

    $wc = &runloop($n, $code);

    $wd = timediff($wc, $wn);
    timedebug("timeit: ",$wc);
    timedebug("      - ",$wn);
    timedebug("      = ",$wd);

    $wd;
}


my $default_for = 3;
my $min_for     = 0.1;


$_Usage{countit} = <<'USAGE';
usage: $result = countit($time, 'code' );        or
       $result = countit($time, sub { code } );
USAGE

sub countit {
    my ( $tmax, $code ) = @_;

    die usage unless @_;

    if ( not defined $tmax or $tmax == 0 ) {
	$tmax = $default_for;
    } elsif ( $tmax < 0 ) {
	$tmax = -$tmax;
    }

    die "countit($tmax, ...): timelimit cannot be less than $min_for.\n"
	if $tmax < $min_for;

    my ($n, $tc);

    # First find the minimum $n that gives a significant timing.
    for ($n = 1; ; $n *= 2 ) {
	my $td = timeit($n, $code);
	$tc = $td->[1] + $td->[2];
	last if $tc > 0.1;
    }

    my $nmin = $n;

    # Get $n high enough that we can guess the final $n with some accuracy.
    my $tpra = 0.1 * $tmax; # Target/time practice.
    while ( $tc < $tpra ) {
	# The 5% fudge is to keep us from iterating again all
	# that often (this speeds overall responsiveness when $tmax is big
	# and we guess a little low).  This does not noticably affect 
	# accuracy since we're not couting these times.
	$n = int( $tpra * 1.05 * $n / $tc ); # Linear approximation.
	my $td = timeit($n, $code);
	my $new_tc = $td->[1] + $td->[2];
        # Make sure we are making progress.
        $tc = $new_tc > 1.2 * $tc ? $new_tc : 1.2 * $tc;
    }

    # Now, do the 'for real' timing(s), repeating until we exceed
    # the max.
    my $ntot  = 0;
    my $rtot  = 0;
    my $utot  = 0.0;
    my $stot  = 0.0;
    my $cutot = 0.0;
    my $cstot = 0.0;
    my $ttot  = 0.0;

    # The 5% fudge is because $n is often a few % low even for routines
    # with stable times and avoiding extra timeit()s is nice for
    # accuracy's sake.
    $n = int( $n * ( 1.05 * $tmax / $tc ) );

    while () {
	my $td = timeit($n, $code);
	$ntot  += $n;
	$rtot  += $td->[0];
	$utot  += $td->[1];
	$stot  += $td->[2];
	$cutot += $td->[3];
	$cstot += $td->[4];
	$ttot = $utot + $stot;
	last if $ttot >= $tmax;

        $ttot = 0.01 if $ttot < 0.01;
	my $r = $tmax / $ttot - 1; # Linear approximation.
	$n = int( $r * $ntot );
	$n = $nmin if $n < $nmin;
    }

    return bless [ $rtot, $utot, $stot, $cutot, $cstot, $ntot ];
}

# --- Functions implementing high-level time-then-print utilities

sub n_to_for {
    my $n = shift;
    return $n == 0 ? $default_for : $n < 0 ? -$n : undef;
}

$_Usage{timethis} = <<'USAGE';
usage: $result = timethis($time, 'code' );        or
       $result = timethis($time, sub { code } );
USAGE

sub timethis{
    my($n, $code, $title, $style) = @_;
    my($t, $forn);

    die usage unless defined $code and
                     (!ref $code or ref $code eq 'CODE');

    if ( $n > 0 ) {
	croak "non-integer loopcount $n, stopped" if int($n)<$n;
	$t = timeit($n, $code);
	$title = "timethis $n" unless defined $title;
    } else {
	my $fort  = n_to_for( $n );
	$t     = countit( $fort, $code );
	$title = "timethis for $fort" unless defined $title;
	$forn  = $t->[-1];
    }
    local $| = 1;
    $style = "" unless defined $style;
    printf("%10s: ", $title) unless $style eq 'none';
    print timestr($t, $style, $Default_Format),"\n" unless $style eq 'none';

    $n = $forn if defined $forn;

    # A conservative warning to spot very silly tests.
    # Don't assume that your benchmark is ok simply because
    # you don't get this warning!
    print "            (warning: too few iterations for a reliable count)\n"
	if     $n < $Min_Count
	    || ($t->real < 1 && $n < 1000)
	    || $t->cpu_a < $Min_CPU;
    $t;
}


$_Usage{timethese} = <<'USAGE';
usage: timethese($count, { Name1 => 'code1', ... });        or
       timethese($count, { Name1 => sub { code1 }, ... });
USAGE

sub timethese{
    my($n, $alt, $style) = @_;
    die usage unless ref $alt eq 'HASH';

    my @names = sort keys %$alt;
    $style = "" unless defined $style;
    print "Benchmark: " unless $style eq 'none';
    if ( $n > 0 ) {
	croak "non-integer loopcount $n, stopped" if int($n)<$n;
	print "timing $n iterations of" unless $style eq 'none';
    } else {
	print "running" unless $style eq 'none';
    }
    print " ", join(', ',@names) unless $style eq 'none';
    unless ( $n > 0 ) {
	my $for = n_to_for( $n );
	print ", each" if $n > 1 && $style ne 'none';
	print " for at least $for CPU seconds" unless $style eq 'none';
    }
    print "...\n" unless $style eq 'none';

    # we could save the results in an array and produce a summary here
    # sum, min, max, avg etc etc
    my %results;
    foreach my $name (@names) {
        $results{$name} = timethis ($n, $alt -> {$name}, $name, $style);
    }

    return \%results;
}


$_Usage{cmpthese} = <<'USAGE';
usage: cmpthese($count, { Name1 => 'code1', ... });        or
       cmpthese($count, { Name1 => sub { code1 }, ... });  or
       cmpthese($result, $style);
USAGE

sub cmpthese{
    my ($results, $style);

    if( ref $_[0] ) {
        ($results, $style) = @_;
    }
    else {
        my($count, $code) = @_[0,1];
        $style = $_[2] if defined $_[2];

        die usage unless ref $code eq 'HASH';

        $results = timethese($count, $code, ($style || "none"));
    }

    $style = "" unless defined $style;

    # Flatten in to an array of arrays with the name as the first field
    my @vals = map{ [ $_, @{$results->{$_}} ] } keys %$results;

    for (@vals) {
	# The epsilon fudge here is to prevent div by 0.  Since clock
	# resolutions are much larger, it's below the noise floor.
	my $rate = $_->[6] / ( $_->[2] + $_->[3] + 0.000000000000001 );
	$_->[7] = $rate;
    }

    # Sort by rate
    @vals = sort { $a->[7] <=> $b->[7] } @vals;

    # If more than half of the rates are greater than one...
    my $display_as_rate = @vals ? ($vals[$#vals>>1]->[7] > 1) : 0;

    my @rows;
    my @col_widths;

    my @top_row = ( 
        '', 
	$display_as_rate ? 'Rate' : 's/iter', 
	map { $_->[0] } @vals 
    );

    push @rows, \@top_row;
    @col_widths = map { length( $_ ) } @top_row;

    # Build the data rows
    # We leave the last column in even though it never has any data.  Perhaps
    # it should go away.  Also, perhaps a style for a single column of
    # percentages might be nice.
    for my $row_val ( @vals ) {
	my @row;

        # Column 0 = test name
	push @row, $row_val->[0];
	$col_widths[0] = length( $row_val->[0] )
	    if length( $row_val->[0] ) > $col_widths[0];

        # Column 1 = performance
	my $row_rate = $row_val->[7];

	# We assume that we'll never get a 0 rate.
	my $rate = $display_as_rate ? $row_rate : 1 / $row_rate;

	# Only give a few decimal places before switching to sci. notation,
	# since the results aren't usually that accurate anyway.
	my $format = 
	   $rate >= 100 ? 
	       "%0.0f" : 
	   $rate >= 10 ?
	       "%0.1f" :
	   $rate >= 1 ?
	       "%0.2f" :
	   $rate >= 0.1 ?
	       "%0.3f" :
	       "%0.2e";

	$format .= "/s"
	    if $display_as_rate;

	my $formatted_rate = sprintf( $format, $rate );
	push @row, $formatted_rate;
	$col_widths[1] = length( $formatted_rate )
	    if length( $formatted_rate ) > $col_widths[1];

        # Columns 2..N = performance ratios
	my $skip_rest = 0;
	for ( my $col_num = 0 ; $col_num < @vals ; ++$col_num ) {
	    my $col_val = $vals[$col_num];
	    my $out;
	    if ( $skip_rest ) {
		$out = '';
	    }
	    elsif ( $col_val->[0] eq $row_val->[0] ) {
		$out = "--";
		# $skip_rest = 1;
	    }
	    else {
		my $col_rate = $col_val->[7];
		$out = sprintf( "%.0f%%", 100*$row_rate/$col_rate - 100 );
	    }
	    push @row, $out;
	    $col_widths[$col_num+2] = length( $out )
		if length( $out ) > $col_widths[$col_num+2];

	    # A little wierdness to set the first column width properly
	    $col_widths[$col_num+2] = length( $col_val->[0] )
		if length( $col_val->[0] ) > $col_widths[$col_num+2];
	}
	push @rows, \@row;
    }

    return \@rows if $style eq "none";

    # Equalize column widths in the chart as much as possible without
    # exceeding 80 characters.  This does not use or affect cols 0 or 1.
    my @sorted_width_refs = 
       sort { $$a <=> $$b } map { \$_ } @col_widths[2..$#col_widths];
    my $max_width = ${$sorted_width_refs[-1]};

    my $total = @col_widths - 1 ;
    for ( @col_widths ) { $total += $_ }

    STRETCHER:
    while ( $total < 80 ) {
	my $min_width = ${$sorted_width_refs[0]};
	last
	   if $min_width == $max_width;
	for ( @sorted_width_refs ) {
	    last 
		if $$_ > $min_width;
	    ++$$_;
	    ++$total;
	    last STRETCHER
		if $total >= 80;
	}
    }

    # Dump the output
    my $format = join( ' ', map { "%${_}s" } @col_widths ) . "\n";
    substr( $format, 1, 0 ) = '-';
    for ( @rows ) {
	printf $format, @$_;
    }

    return \@rows ;
}


1;
