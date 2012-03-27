# Devel::Peek - A data debugging tool for the XS programmer
# The documentation is after the __END__

package Devel::Peek;

$VERSION = '1.01';
$XS_VERSION = $VERSION;
$VERSION = eval $VERSION;

require Exporter;
use XSLoader ();

@ISA = qw(Exporter);
@EXPORT = qw(Dump mstat DeadCode DumpArray DumpWithOP DumpProg
	     fill_mstats mstats_fillhash mstats2hash runops_debug debug_flags);
@EXPORT_OK = qw(SvREFCNT SvREFCNT_inc SvREFCNT_dec CvGV);
%EXPORT_TAGS = ('ALL' => [@EXPORT, @EXPORT_OK]);

XSLoader::load 'Devel::Peek';

sub import {
  my $c = shift;
  my $ops_rx = qr/^:opd(=[stP]*)?\b/;
  my @db = grep m/$ops_rx/, @_;
  @_ = grep !m/$ops_rx/, @_;
  if (@db) {
    die "Too many :opd options" if @db > 1;
    runops_debug(1);
    my $flags = ($db[0] =~ m/$ops_rx/ and $1);
    $flags = 'st' unless defined $flags;
    my $f = 0;
    $f |= 2  if $flags =~ /s/;
    $f |= 8  if $flags =~ /t/;
    $f |= 64 if $flags =~ /P/;
    $^D |= $f if $f;
  }
  unshift @_, $c;
  goto &Exporter::import;
}

sub DumpWithOP ($;$) {
   local($Devel::Peek::dump_ops)=1;
   my $depth = @_ > 1 ? $_[1] : 4 ;
   Dump($_[0],$depth);
}

$D_flags = 'psltocPmfrxuLHXDSTR';

sub debug_flags (;$) {
  my $out = "";
  for my $i (0 .. length($D_flags)-1) {
    $out .= substr $D_flags, $i, 1 if $^D & (1<<$i);
  }
  my $arg = shift;
  my $num = $arg;
  if (defined $arg and $arg =~ /\D/) {
    die "unknown flags in debug_flags()" if $arg =~ /[^-$D_flags]/;
    my ($on,$off) = split /-/, "$arg-";
    $num = $^D;
    $num |=  (1<<index($D_flags, $_)) for split //, $on;
    $num &= ~(1<<index($D_flags, $_)) for split //, $off;
  }
  $^D = $num if defined $arg;
  $out
}

1;
__END__

