package Win32::Job;

use strict;
use base qw(DynaLoader);
use vars qw($VERSION);

$VERSION = '0.01';

use constant WIN32s => 0;
use constant WIN9X  => 1;
use constant WINNT  => 2;

my @ver = Win32::GetOSVersion;
die "Win32::Job is not supported on $ver[0]" unless (
    $ver[4] == WINNT and (
	$ver[1] > 5 or
	($ver[1] == 5 and $ver[2] > 0) or
	($ver[1] == 5 and $ver[2] == 0 and $ver[3] >= 0)
    )
);

Win32::Job->bootstrap($VERSION);

1;

__END__

