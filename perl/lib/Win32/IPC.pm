#---------------------------------------------------------------------
package Win32::IPC;
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
# Base class for Win32 synchronization objects
#---------------------------------------------------------------------

$VERSION = '1.02';

require Exporter;
require DynaLoader;
use strict;
use vars qw($AUTOLOAD $VERSION @ISA @EXPORT @EXPORT_OK);

@ISA = qw(Exporter DynaLoader);
@EXPORT = qw(
	INFINITE
	WaitForMultipleObjects
);
@EXPORT_OK = qw(
  wait_any wait_all
);

sub AUTOLOAD {
    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.
    my($constname);
    ($constname = $AUTOLOAD) =~ s/.*:://;
    local $! = 0;
    my $val = constant($constname);
    if ($! != 0) {
        my ($pack,$file,$line) = caller;
        die "Your vendor has not defined Win32::IPC macro $constname, used at $file line $line.";
    }
    eval "sub $AUTOLOAD { $val }";
    goto &$AUTOLOAD;
} # end AUTOLOAD

bootstrap Win32::IPC;

# How's this for cryptic?  Use wait_any or wait_all!
sub WaitForMultipleObjects
{
    my $result = (($_[1] ? wait_all($_[0], $_[2])
                   : wait_any($_[0], $_[2]))
                  ? 1
                  : 0);
    @{$_[0]} = (); # Bug for bug compatibility!  Use wait_any or wait_all!
    $result;
} # end WaitForMultipleObjects

1;
__END__

# Local Variables:
# tmtrack-file-task: "Win32::IPC"
# End:
