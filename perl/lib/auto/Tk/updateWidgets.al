# NOTE: Derived from blib\lib\Tk.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Tk;

#line 748 "blib\lib\Tk.pm (autosplit into blib\lib\auto\Tk\updateWidgets.al)"
sub updateWidgets
{
 my ($w) = @_;
 while ($w->DoOneEvent(DONT_WAIT|IDLE_EVENTS|WINDOW_EVENTS))
  {
  }
 $w;
}

# end of Tk::updateWidgets
1;
