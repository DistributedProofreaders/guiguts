# NOTE: Derived from ..\blib\lib\Tk\Scale.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Tk::Scale;

#line 255 "..\blib\lib\Tk\Scale.pm (autosplit into ..\blib\lib\auto\Tk\Scale\ControlPress.al)"
# ControlPress --
# This procedure handles button presses that are made with the Control
# key down. Depending on the mouse position, it adjusts the scale
# value to one end of the range or the other.
#
# Arguments:
# w - The scale widget.
# x, y - Mouse coordinates where the button was pressed.
sub ControlPress
{
 my ($w,$x,$y) = @_;
 my $el = $w->identify($x,$y);
 return unless ($el);
 if ($el eq 'trough1')
  {
   $w->set($w->cget('-from'))
  }
 elsif ($el eq 'trough2')
  {
   $w->set($w->cget('-to'))
  }
}

1;
# end of Tk::Scale::ControlPress
