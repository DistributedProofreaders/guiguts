# NOTE: Derived from blib\lib\Tk.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Tk;

#line 681 "blib\lib\Tk.pm (autosplit into blib\lib\auto\Tk\focusFollowsMouse.al)"
sub focusFollowsMouse
{
 my $widget = shift;
 $widget->bind('all','<Enter>','EnterFocus');
}

# end of Tk::focusFollowsMouse
1;
