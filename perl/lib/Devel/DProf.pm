use 5.006_001;

# This sub is needed for calibration.
package Devel::DProf;

sub NONESUCH_noxs {
	return $Devel::DProf::VERSION;
}

package DB;

#
# As of perl5.003_20, &DB::sub stub is not needed (some versions
# even had problems if stub was redefined with XS version).
#

# disable DB single-stepping
BEGIN { $single = 0; }

# This sub is needed during startup.
sub DB { 
#	print "nonXS DBDB\n";
}

use XSLoader ();

$Devel::DProf::VERSION = '20030813.00';  # this version not authorized by
				         # Dean Roehrich. See "Changes" file.

XSLoader::load 'Devel::DProf', $Devel::DProf::VERSION;

1;
