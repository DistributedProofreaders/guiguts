#---------------------------------------------------------------------
package Win32::Semaphore;
#
# Copyright 1998 Christopher J. Madsen
#
# Created: 3 Feb 1998 from the ActiveWare version
#   (c) 1995 Microsoft Corporation. All rights reserved.
#       Developed by ActiveWare Internet Corp., http://www.ActiveWare.com
#
#   Other modifications (c) 1997 by Gurusamy Sarathy <gsar@activestate.com>
#
# Author: Christopher J. Madsen <chris_madsen@geocities.com>
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
# Use Win32 semaphore objects for synchronization
#---------------------------------------------------------------------

$VERSION = '1.02';

use Win32::IPC 1.00 '/./';      # Import everything
require Exporter;
require DynaLoader;

@ISA = qw(Exporter DynaLoader Win32::IPC);
@EXPORT_OK = qw(
  wait_all wait_any
);

bootstrap Win32::Semaphore;

sub Create  { $_[0] = new('Win32::Semaphore',@_[1..3]) }
sub Open  { $_[0] = Win32::Semaphore->open($_[1]) }
sub Release { &release }

1;
__END__

