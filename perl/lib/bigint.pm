package bigint;
require 5.005;

$VERSION = '0.04';
use Exporter;
@ISA		= qw( Exporter );
@EXPORT_OK	= qw( ); 
@EXPORT		= qw( inf NaN ); 

use strict;
use overload;

############################################################################## 

# These are all alike, and thus faked by AUTOLOAD

my @faked = qw/round_mode accuracy precision div_scale/;
use vars qw/$VERSION $AUTOLOAD $_lite/;		# _lite for testsuite

sub AUTOLOAD
  {
  my $name = $AUTOLOAD;

  $name =~ s/.*:://;    # split package
  no strict 'refs';
  foreach my $n (@faked)
    {
    if ($n eq $name)
      {
      *{"bigint::$name"} = sub 
        {
        my $self = shift;
        no strict 'refs';
        if (defined $_[0])
          {
          return Math::BigInt->$name($_[0]);
          }
        return Math::BigInt->$name();
        };
      return &$name;
      }
    }
 
  # delayed load of Carp and avoid recursion
  require Carp;
  Carp::croak ("Can't call bigint\-\>$name, not a valid method");
  }

sub upgrade
  {
  my $self = shift;
  no strict 'refs';
#  if (defined $_[0])
#    {
#    $Math::BigInt::upgrade = $_[0];
#    }
  return $Math::BigInt::upgrade;
  }

sub _constant
  {
  # this takes a floating point constant string and returns it truncated to
  # integer. For instance, '4.5' => '4', '1.234e2' => '123' etc
  my $float = shift;

  # some simple cases first
  return $float if ($float =~ /^[+-]?[0-9]+$/);		# '+123','-1','0' etc
  return $float 
    if ($float =~ /^[+-]?[0-9]+\.?[eE]\+?[0-9]+$/);	# 123e2, 123.e+2
  return '0' if ($float =~ /^[+-]?[0]*\.[0-9]+$/);	# .2, 0.2, -.1
  if ($float =~ /^[+-]?[0-9]+\.[0-9]*$/)		# 1., 1.23, -1.2 etc
    {
    $float =~ s/\..*//;
    return $float;
    }
  my ($mis,$miv,$mfv,$es,$ev) = Math::BigInt::_split(\$float);
  return $float if !defined $mis; 	# doesn't look like a number to me
  my $ec = int($$ev);
  my $sign = $$mis; $sign = '' if $sign eq '+';
  if ($$es eq '-')
    {
    # ignore fraction part entirely
    if ($ec >= length($$miv))			# 123.23E-4
      {
      return '0';
      }
    return $sign . substr ($$miv,0,length($$miv)-$ec);	# 1234.45E-2 = 12
    }
  # xE+y
  if ($ec >= length($$mfv))
    {
    $ec -= length($$mfv);			
    return $sign.$$miv.$$mfv if $ec == 0;	# 123.45E+2 => 12345
    return $sign.$$miv.$$mfv.'E'.$ec; 		# 123.45e+3 => 12345e1
    }
  $mfv = substr($$mfv,0,$ec);
  return $sign.$$miv.$mfv; 			# 123.45e+1 => 1234
  }

sub import 
  {
  my $self = shift;

  # some defaults
  my $lib = 'Calc';

  my @import = ( ':constant' );				# drive it w/ constant
  my @a = @_; my $l = scalar @_; my $j = 0;
  my ($ver,$trace);					# version? trace?
  my ($a,$p);						# accuracy, precision
  for ( my $i = 0; $i < $l ; $i++,$j++ )
    {
    if ($_[$i] =~ /^(l|lib)$/)
      {
      # this causes a different low lib to take care...
      $lib = $_[$i+1] || '';
      my $s = 2; $s = 1 if @a-$j < 2;	# avoid "can not modify non-existant..."
      splice @a, $j, $s; $j -= $s; $i++;
      }
    elsif ($_[$i] =~ /^(a|accuracy)$/)
      {
      $a = $_[$i+1];
      my $s = 2; $s = 1 if @a-$j < 2;	# avoid "can not modify non-existant..."
      splice @a, $j, $s; $j -= $s; $i++;
      }
    elsif ($_[$i] =~ /^(p|precision)$/)
      {
      $p = $_[$i+1];
      my $s = 2; $s = 1 if @a-$j < 2;	# avoid "can not modify non-existant..."
      splice @a, $j, $s; $j -= $s; $i++;
      }
    elsif ($_[$i] =~ /^(v|version)$/)
      {
      $ver = 1;
      splice @a, $j, 1; $j --;
      }
    elsif ($_[$i] =~ /^(t|trace)$/)
      {
      $trace = 1;
      splice @a, $j, 1; $j --;
      }
    else { die "unknown option $_[$i]"; }
    }
  my $class;
  $_lite = 0;					# using M::BI::L ?
  if ($trace)
    {
    require Math::BigInt::Trace; $class = 'Math::BigInt::Trace';
    }
  else
    {
    # see if we can find Math::BigInt::Lite
    if (!defined $a && !defined $p)		# rounding won't work to well
      {
      eval 'require Math::BigInt::Lite;';
      if ($@ eq '')
        {
        @import = ( );				# :constant in Lite, not MBI
        Math::BigInt::Lite->import( ':constant' );
        $_lite= 1;				# signal okay
        }
      }
    require Math::BigInt if $_lite == 0;	# not already loaded?
    $class = 'Math::BigInt';			# regardless of MBIL or not
    } 
  # Math::BigInt::Trace or plain Math::BigInt
  $class->import(@import, lib => $lib);

  bigint->accuracy($a) if defined $a;
  bigint->precision($p) if defined $p;
  if ($ver)
    {
    print "bigint\t\t\t v$VERSION\n";
    print "Math::BigInt::Lite\t v$Math::BigInt::Lite::VERSION\n" if $_lite;
    print "Math::BigInt\t\t v$Math::BigInt::VERSION";
    my $config = Math::BigInt->config();
    print " lib => $config->{lib} v$config->{lib_version}\n";
    exit;
    }
  # we take care of floating point constants, since BigFloat isn't available
  # and BigInt doesn't like them:
  overload::constant float => sub { Math::BigInt->new( _constant(shift) ); };

  $self->export_to_level(1,$self,@a);           # export inf and NaN
  }

sub inf () { Math::BigInt->binf(); }
sub NaN () { Math::BigInt->bnan(); }

1;

__END__

