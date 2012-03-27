#---------------------------------------------------------------------
package Win32::Event;
#
# Copyright 1998 Christopher J. Madsen
#
# Author: Christopher J. Madsen <chris_madsen@geocities.com>
# Created: 3 Feb 1998 from the ActiveWare version
# Version: 1.00 (6-Feb-1998)
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either the
# GNU General Public License or the Artistic License for more details.
#
# Use Win32 event objects for synchronization
#---------------------------------------------------------------------

$VERSION = '1.01';

use Win32::IPC 1.00 '/./';      # Import everything
require Exporter;
require DynaLoader;

@ISA = qw(Exporter DynaLoader Win32::IPC);
@EXPORT_OK = qw(
  wait_all wait_any INFINITE
);

bootstrap Win32::Event;

1;
__END__

# Local Variables:
# tmtrack-file-task: "Win32::Event"
# End:
