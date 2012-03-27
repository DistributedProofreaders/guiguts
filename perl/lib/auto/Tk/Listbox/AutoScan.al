# NOTE: Derived from ..\blib\lib\Tk\Listbox.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Tk::Listbox;

#line 676 "..\blib\lib\Tk\Listbox.pm (autosplit into ..\blib\lib\auto\Tk\Listbox\AutoScan.al)"
# AutoScan --
# This procedure is invoked when the mouse leaves an entry window
# with button 1 down. It scrolls the window up, down, left, or
# right, depending on where the mouse left the window, and reschedules
# itself as an "after" command so that the window continues to scroll until
# the mouse moves back into the window or the mouse button is released.
#
# Arguments:
# w - The entry window.
# x - The x-coordinate of the mouse when it left the window.
# y - The y-coordinate of the mouse when it left the window.
sub AutoScan
{
 my $w = shift;
 return if !Tk::Exists($w);
 my $x = shift;
 my $y = shift;
 if ($y >= $w->height)
  {
   $w->yview('scroll',1,'units')
  }
 elsif ($y < 0)
  {
   $w->yview('scroll',-1,'units')
  }
 elsif ($x >= $w->width)
  {
   $w->xview('scroll',2,'units')
  }
 elsif ($x < 0)
  {
   $w->xview('scroll',-2,'units')
  }
 else
  {
   return;
  }
 $w->Motion($w->index("@" . $x . ',' . $y));
 $w->RepeatId($w->after(50,'AutoScan',$w,$x,$y));
}

# end of Tk::Listbox::AutoScan
1;
