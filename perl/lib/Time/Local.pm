package Time::Local;

require Exporter;
use Carp;
use Config;
use strict;
use integer;

use vars qw( $VERSION @ISA @EXPORT @EXPORT_OK );
$VERSION    = '1.07';
@ISA	= qw( Exporter );
@EXPORT	= qw( timegm timelocal );
@EXPORT_OK	= qw( timegm_nocheck timelocal_nocheck );

my @MonthDays = (31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);

# Determine breakpoint for rolling century
my $ThisYear     = (localtime())[5];
my $Breakpoint   = ($ThisYear + 50) % 100;
my $NextCentury  = $ThisYear - $ThisYear % 100;
   $NextCentury += 100 if $Breakpoint < 50;
my $Century      = $NextCentury - 100;
my $SecOff       = 0;

my (%Options, %Cheat);

my $MaxInt = ((1<<(8 * $Config{intsize} - 2))-1)*2 + 1;
my $MaxDay = int(($MaxInt-43200)/86400)-1;

# Determine the EPOC day for this machine
my $Epoc = 0;
if ($^O eq 'vos') {
# work around posix-977 -- VOS doesn't handle dates in
# the range 1970-1980.
  $Epoc = _daygm((0, 0, 0, 1, 0, 70, 4, 0));
}
elsif ($^O eq 'MacOS') {
  no integer;

  $MaxDay *=2 if $^O eq 'MacOS';  # time_t unsigned ... quick hack?
  # MacOS time() is seconds since 1 Jan 1904, localtime
  # so we need to calculate an offset to apply later
  $Epoc = 693901;
  $SecOff = timelocal(localtime(0)) - timelocal(gmtime(0));
  $Epoc += _daygm(gmtime(0));
}
else {
  $Epoc = _daygm(gmtime(0));
}

%Cheat=(); # clear the cache as epoc has changed

sub _daygm {
    $_[3] + ($Cheat{pack("ss",@_[4,5])} ||= do {
	my $month = ($_[4] + 10) % 12;
	my $year = $_[5] + 1900 - $month/10;
	365*$year + $year/4 - $year/100 + $year/400 + ($month*306 + 5)/10 - $Epoc
    });
}


sub _timegm {
    my $sec = $SecOff + $_[0]  +  60 * $_[1]  +  3600 * $_[2];

    no integer;

    $sec +  86400 * &_daygm;
}


sub timegm {
    my ($sec,$min,$hour,$mday,$month,$year) = @_;

    if ($year >= 1000) {
	$year -= 1900;
    }
    elsif ($year < 100 and $year >= 0) {
	$year += ($year > $Breakpoint) ? $Century : $NextCentury;
    }

    unless ($Options{no_range_check}) {
	if (abs($year) >= 0x7fff) {
	    $year += 1900;
	    croak "Cannot handle date ($sec, $min, $hour, $mday, $month, $year)";
	}

	croak "Month '$month' out of range 0..11" if $month > 11 or $month < 0;

	my $md = $MonthDays[$month];
	++$md unless $month != 1 or $year % 4 or !($year % 400);

	croak "Day '$mday' out of range 1..$md"   if $mday  > $md  or $mday  < 1;
	croak "Hour '$hour' out of range 0..23"   if $hour  > 23   or $hour  < 0;
	croak "Minute '$min' out of range 0..59"  if $min   > 59   or $min   < 0;
	croak "Second '$sec' out of range 0..59"  if $sec   > 59   or $sec   < 0;
    }

    my $days = _daygm(undef, undef, undef, $mday, $month, $year);

    unless ($Options{no_range_check} or abs($days) < $MaxDay) {
	$year += 1900;
	croak "Cannot handle date ($sec, $min, $hour, $mday, $month, $year)";
    }

    $sec += $SecOff + 60*$min + 3600*$hour;

    no integer;

    $sec + 86400*$days;
}


sub timegm_nocheck {
    local $Options{no_range_check} = 1;
    &timegm;
}


sub timelocal {
    no integer;
    my $ref_t = &timegm;
    my $loc_t = _timegm(localtime($ref_t));

    # Is there a timezone offset from GMT or are we done
    my $zone_off = $ref_t - $loc_t
	or return $loc_t;

    # Adjust for timezone
    $loc_t = $ref_t + $zone_off;

    # Are we close to a DST change or are we done
    my $dst_off = $ref_t - _timegm(localtime($loc_t))
	or return $loc_t;

    # Adjust for DST change
    $loc_t += $dst_off;

    # for a negative offset from GMT, and if the original date
    # was a non-extent gap in a forward DST jump, we should
    # now have the wrong answer - undo the DST adjust;

    return $loc_t if $zone_off <= 0;

    my ($s,$m,$h) = localtime($loc_t);
    $loc_t -= $dst_off if $s != $_[0] || $m != $_[1] || $h != $_[2];

    $loc_t;
}


sub timelocal_nocheck {
    local $Options{no_range_check} = 1;
    &timelocal;
}

1;

__END__

