# NOTE: Derived from blib\lib\Tk\Frame.pm.
# Changes made here will be lost when autosplit is run again.
# See AutoSplit.pm.
package Tk::Frame;

#line 225 "blib\lib\Tk\Frame.pm (autosplit into blib\lib\auto\Tk\Frame\AddScrollbars.al)"
sub AddScrollbars
{
 require Tk::Scrollbar;
 my ($cw,$w) = @_;
 my $def = '';
 my ($x,$y) = ('','');
 my $s = 0;
 my $c;
 $cw->freeze_on_map;
 foreach $c ($w->configure)
  {
   my $opt = $c->[0];
   if ($opt eq '-yscrollcommand')
    {
     my $slice  = Tk::Frame->new($cw,Name => 'ysbslice');
     my $ysb    = Tk::Scrollbar->new($slice,-orient => 'vertical', -command => [ 'yview', $w ]);
     my $size   = $ysb->cget('-width');
     my $corner = Tk::Frame->new($slice,Name=>'corner','-relief' => 'raised',
                  '-width' => $size, '-height' => $size);
     $ysb->pack(-side => 'left', -fill => 'y');
     $cw->Advertise('yscrollbar' => $ysb);
     $cw->Advertise('corner' => $corner);
     $cw->Advertise('ysbslice' => $slice);
     $corner->{'before'} = $ysb->PathName;
     $slice->{'before'} = $w->PathName;
     $y = 'w';
     $s = 1;
    }
   elsif ($opt eq '-xscrollcommand')
    {
     my $xsb = Tk::Scrollbar->new($cw,-orient => 'horizontal', -command => [ 'xview', $w ]);
     $cw->Advertise('xscrollbar' => $xsb);
     $xsb->{'before'} = $w->PathName;
     $x = 's';
     $s = 1;
    }
  }
 if ($s)
  {
   $cw->Advertise('scrolled' => $w);
   $cw->ConfigSpecs('-scrollbars' => ['METHOD','scrollbars','Scrollbars',$x.$y]);
  }
}

# end of Tk::Frame::AddScrollbars
1;
