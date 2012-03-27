# NOTE: Derived from ..\blib\lib\Tk\Listbox.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Tk::Listbox;

#line 748 "..\blib\lib\Tk\Listbox.pm (autosplit into ..\blib\lib\auto\Tk\Listbox\ExtendUpDown.al)"
# ExtendUpDown --
#
# Does nothing unless we're in extended selection mode; in this
# case it moves the location cursor (active element) up or down by
# one element, and extends the selection to that point.
#
# Arguments:
# w - The listbox widget.
# amount - +1 to move down one item, -1 to move back one item.
sub ExtendUpDown
{
 my $w = shift;
 my $amount = shift;
 if ($w->cget('-selectmode') ne 'extended')
  {
   return;
  }
 my $active = $w->index('active');
 if (!@Selection)
  {
   $w->selectionSet($active);
   @Selection = $w->curselection;
  }
 $w->activate($active + $amount);
 $w->see('active');
 $w->Motion($w->index('active'))
}

# end of Tk::Listbox::ExtendUpDown
1;
