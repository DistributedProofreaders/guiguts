# NOTE: Derived from ..\blib\lib\Tk\Listbox.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Tk::Listbox;

#line 645 "..\blib\lib\Tk\Listbox.pm (autosplit into ..\blib\lib\auto\Tk\Listbox\BeginToggle.al)"
# BeginToggle --
#
# This procedure is typically invoked on control-button-1 presses. It
# begins the process of toggling a selection in the listbox. Its
# exact behavior depends on the selection mode currently in effect
# for the listbox; see the Motif documentation for details.
#
# Arguments:
# w - The listbox widget.
# el - The element for the selection operation (typically the
# one under the pointer). Must be in numerical form.
sub BeginToggle
{
 my $w = shift;
 my $el = shift;
 if ($w->cget('-selectmode') eq 'extended')
  {
   @Selection = $w->curselection();
   $Prev = $el;
   $w->selectionAnchor($el);
   if ($w->selectionIncludes($el))
    {
     $w->selectionClear($el)
    }
   else
    {
     $w->selectionSet($el)
    }
   $w->eventGenerate("<<ListboxSelect>>");
  }
}

# end of Tk::Listbox::BeginToggle
1;
