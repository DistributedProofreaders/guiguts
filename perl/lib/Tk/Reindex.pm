package Tk::Reindex;


use vars qw($VERSION);
$VERSION = '4.004'; # $Id: //depot/Tkutf8/TextList/Reindex.pm#4 $

use Tk;
use base qw(Tk::Derived);


sub Populate
{
 my ($w, $args) = @_;

 $w->_callbase('Populate',$args);

 $w->ConfigSpecs(-linestart    => ["PASSIVE", "lineStart",    "LineStart", 0],
                 -toindexcmd   => ["CALLBACK", "toIndexCmd",  "ToIndexCmd" ,  [\&to_index,$w]],
                 -fromindexcmd => ["CALLBACK", "fromIndexCmd","FromIndexCmd", [\&from_index,$w]]);
}

sub import
{
  my($module,$base)=@_;
  my $pkg=(caller)[0];

  no strict 'refs';
  *{"${pkg}::_reindexbase"}=sub{$base};
}

sub _callbase
{
  my($w,$sub)=(shift,shift);
  my $supersub=$w->_reindexbase()."::$sub";
  $w->$supersub(@_);
}

BEGIN
{
  # list of subroutines and index argument number (-1 as first element means return value)
  my %subs=('bbox'      => [0],
            'compare'   => [0,2],
            'delete'    => [0,1],
            'dlineinfo' => [0],
            'dump'      => \&_find_dump_index,
            'get'       => [0,1],
            'index'     => [-1,0],
            'insert'    => [0],
            'mark'      => \&_find_mark_index,
            'search'    => \&_find_search_index,
            'see'       => [0],
            'tag'       => \&_find_tag_index,
            'window'    => [1],
            'image'     => [1],
           );

  foreach my $sub (keys %subs)
  {
    my $args=$subs{$sub};
    my $argsub=ref $args eq 'CODE'?$args:sub{$args};
    my $newsub=sub
    {
      my($w)=shift;
      my(@iargs)=grep($_<=$#_,@{$argsub->(@_)});
      my $iret=shift @iargs if @iargs && $iargs[0]==-1;
      my(@args)=@_;
      @args[@iargs]=$w->Callback(-toindexcmd,@args[@iargs]);
      my(@ret)=$w->_callbase($sub,@args);
      @ret=$w->Callback(-fromindexcmd,@ret) if $iret;
      wantarray?@ret:$ret[0];
    };
    no strict 'refs';
    *{$sub}=$newsub;
  }
}

sub to_index
{
  my $w=shift;
  my $offset=$w->cget(-linestart)+1;
  my(@args)=@_;
  foreach (@args)
   {
    s/^\d+(?=\.)/$&+$offset/e;
   }
  @args;
}

sub from_index
{
  my $w=shift;
  my $offset=$w->cget(-linestart)+1;
  my(@args)=@_;
  foreach (@args)
   {
    s/^\d+(?=\.)/$&-$offset/e
   }
  @args;
}

sub _find_dump_index
{
  my $idx=_count_options(@_);
  [$idx,$idx+1];
}

sub _find_search_index
{
  my $idx=_count_options(@_);
  [$idx+1,$idx+2];
}

sub _count_options
{
  my $idx=0;
  while($_[$idx]=~/^-/g)
  {
    $idx++;
    $idx++ if $' eq 'count' or $' eq 'command';
    last if $' eq '-';
  }
  $idx;
}

sub _find_tag_index
{
  return [1]   if $_[0] eq 'names';
  return [2,3] if $_[0]=~/^(add|remove|nextrange|prevrange)$/;
  return [-1]  if $_[0] eq 'ranges';
  return [];
}

sub _find_mark_index
{
  return [2] if $_[0] eq 'set';
  return [1] if $_[0] eq 'next' or $_[0] eq 'previous';
  return [];
}

1;

