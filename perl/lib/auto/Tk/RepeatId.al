# NOTE: Derived from blib\lib\Tk.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Tk;

#line 498 "blib\lib\Tk.pm (autosplit into blib\lib\auto\Tk\RepeatId.al)"
sub RepeatId
{
 my ($w,$id) = @_;
 $w = $w->MainWindow;
 $w->CancelRepeat;
 $w->{_afterId_} = $id;
}

# end of Tk::RepeatId
1;
