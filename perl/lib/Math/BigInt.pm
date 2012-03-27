package Math::BigInt;

#
# "Mike had an infinite amount to do and a negative amount of time in which
# to do it." - Before and After
#

# The following hash values are used:
#   value: unsigned int with actual value (as a Math::BigInt::Calc or similiar)
#   sign : +,-,NaN,+inf,-inf
#   _a   : accuracy
#   _p   : precision
#   _f   : flags, used by MBF to flag parts of a float as untouchable

# Remember not to take shortcuts ala $xs = $x->{value}; $CALC->foo($xs); since
# underlying lib might change the reference!

my $class = "Math::BigInt";
require 5.005;

$VERSION = '1.68';
use Exporter;
@ISA =       qw( Exporter );
@EXPORT_OK = qw( objectify bgcd blcm); 
# _trap_inf and _trap_nan are internal and should never be accessed from the
# outside
use vars qw/$round_mode $accuracy $precision $div_scale $rnd_mode 
	    $upgrade $downgrade $_trap_nan $_trap_inf/;
use strict;

# Inside overload, the first arg is always an object. If the original code had
# it reversed (like $x = 2 * $y), then the third paramater is true.
# In some cases (like add, $x = $x + 2 is the same as $x = 2 + $x) this makes
# no difference, but in some cases it does.

# For overloaded ops with only one argument we simple use $_[0]->copy() to
# preserve the argument.

# Thus inheritance of overload operators becomes possible and transparent for
# our subclasses without the need to repeat the entire overload section there.

use overload
'='     =>      sub { $_[0]->copy(); },

# some shortcuts for speed (assumes that reversed order of arguments is routed
# to normal '+' and we thus can always modify first arg. If this is changed,
# this breaks and must be adjusted.)
'+='	=>	sub { $_[0]->badd($_[1]); },
'-='	=>	sub { $_[0]->bsub($_[1]); },
'*='	=>	sub { $_[0]->bmul($_[1]); },
'/='	=>	sub { scalar $_[0]->bdiv($_[1]); },
'%='	=>	sub { $_[0]->bmod($_[1]); },
'^='	=>	sub { $_[0]->bxor($_[1]); },
'&='	=>	sub { $_[0]->band($_[1]); },
'|='	=>	sub { $_[0]->bior($_[1]); },
'**='	=>	sub { $_[0]->bpow($_[1]); },

# not supported by Perl yet
'..'	=>	\&_pointpoint,

'<=>'	=>	sub { $_[2] ?
                      ref($_[0])->bcmp($_[1],$_[0]) : 
                      $_[0]->bcmp($_[1])},
'cmp'	=>	sub {
         $_[2] ? 
               "$_[1]" cmp $_[0]->bstr() :
               $_[0]->bstr() cmp "$_[1]" },

# make cos()/sin()/exp() "work" with BigInt's or subclasses
'cos'	=>	sub { cos($_[0]->numify()) }, 
'sin'	=>	sub { sin($_[0]->numify()) }, 
'exp'	=>	sub { exp($_[0]->numify()) }, 
'atan2'	=>	sub { atan2($_[0]->numify(),$_[1]) }, 

'log'	=>	sub { $_[0]->copy()->blog($_[1]); }, 
'int'	=>	sub { $_[0]->copy(); }, 
'neg'	=>	sub { $_[0]->copy()->bneg(); }, 
'abs'	=>	sub { $_[0]->copy()->babs(); },
'sqrt'  =>	sub { $_[0]->copy()->bsqrt(); },
'~'	=>	sub { $_[0]->copy()->bnot(); },

# for sub it is a bit tricky to keep b: b-a => -a+b
'-'	=>	sub { my $c = $_[0]->copy; $_[2] ?
                   $c->bneg()->badd($_[1]) :
                   $c->bsub( $_[1]) },
'+'	=>	sub { $_[0]->copy()->badd($_[1]); },
'*'	=>	sub { $_[0]->copy()->bmul($_[1]); },

'/'	=>	sub { 
   $_[2] ? ref($_[0])->new($_[1])->bdiv($_[0]) : $_[0]->copy->bdiv($_[1]);
  }, 
'%'	=>	sub { 
   $_[2] ? ref($_[0])->new($_[1])->bmod($_[0]) : $_[0]->copy->bmod($_[1]);
  }, 
'**'	=>	sub { 
   $_[2] ? ref($_[0])->new($_[1])->bpow($_[0]) : $_[0]->copy->bpow($_[1]);
  }, 
'<<'	=>	sub { 
   $_[2] ? ref($_[0])->new($_[1])->blsft($_[0]) : $_[0]->copy->blsft($_[1]);
  }, 
'>>'	=>	sub { 
   $_[2] ? ref($_[0])->new($_[1])->brsft($_[0]) : $_[0]->copy->brsft($_[1]);
  }, 
'&'	=>	sub { 
   $_[2] ? ref($_[0])->new($_[1])->band($_[0]) : $_[0]->copy->band($_[1]);
  }, 
'|'	=>	sub { 
   $_[2] ? ref($_[0])->new($_[1])->bior($_[0]) : $_[0]->copy->bior($_[1]);
  }, 
'^'	=>	sub { 
   $_[2] ? ref($_[0])->new($_[1])->bxor($_[0]) : $_[0]->copy->bxor($_[1]);
  }, 

# can modify arg of ++ and --, so avoid a copy() for speed, but don't
# use $_[0]->bone(), it would modify $_[0] to be 1!
'++'	=>	sub { $_[0]->binc() },
'--'	=>	sub { $_[0]->bdec() },

# if overloaded, O(1) instead of O(N) and twice as fast for small numbers
'bool'  =>	sub {
  # this kludge is needed for perl prior 5.6.0 since returning 0 here fails :-/
  # v5.6.1 dumps on this: return !$_[0]->is_zero() || undef;		    :-(
  my $t = undef;
  $t = 1 if !$_[0]->is_zero();
  $t;
  },

# the original qw() does not work with the TIESCALAR below, why?
# Order of arguments unsignificant
'""' => sub { $_[0]->bstr(); },
'0+' => sub { $_[0]->numify(); }
;

##############################################################################
# global constants, flags and accessory

# these are public, but their usage is not recommended, use the accessor
# methods instead

$round_mode = 'even'; # one of 'even', 'odd', '+inf', '-inf', 'zero' or 'trunc'
$accuracy   = undef;
$precision  = undef;
$div_scale  = 40;

$upgrade = undef;			# default is no upgrade
$downgrade = undef;			# default is no downgrade

# these are internally, and not to be used from the outside

sub MB_NEVER_ROUND () { 0x0001; }

$_trap_nan = 0;				# are NaNs ok? set w/ config()
$_trap_inf = 0;				# are infs ok? set w/ config()
my $nan = 'NaN'; 			# constants for easier life

my $CALC = 'Math::BigInt::Calc';	# module to do the low level math
					# default is Calc.pm
my %CAN;				# cache for $CALC->can(...)
my $IMPORT = 0;				# was import() called yet?
					# used to make require work

my $EMU_LIB = 'Math/BigInt/CalcEmu.pm';	# emulate low-level math
my $EMU = 'Math::BigInt::CalcEmu';	# emulate low-level math

##############################################################################
# the old code had $rnd_mode, so we need to support it, too

$rnd_mode   = 'even';
sub TIESCALAR  { my ($class) = @_; bless \$round_mode, $class; }
sub FETCH      { return $round_mode; }
sub STORE      { $rnd_mode = $_[0]->round_mode($_[1]); }

BEGIN
  { 
  # tie to enable $rnd_mode to work transparently
  tie $rnd_mode, 'Math::BigInt'; 

  # set up some handy alias names
  *as_int = \&as_number;
  *is_pos = \&is_positive;
  *is_neg = \&is_negative;
  }

############################################################################## 

sub round_mode
  {
  no strict 'refs';
  # make Class->round_mode() work
  my $self = shift;
  my $class = ref($self) || $self || __PACKAGE__;
  if (defined $_[0])
    {
    my $m = shift;
    if ($m !~ /^(even|odd|\+inf|\-inf|zero|trunc)$/)
      {
      require Carp; Carp::croak ("Unknown round mode '$m'");
      }
    return ${"${class}::round_mode"} = $m;
    }
  ${"${class}::round_mode"};
  }

sub upgrade
  {
  no strict 'refs';
  # make Class->upgrade() work
  my $self = shift;
  my $class = ref($self) || $self || __PACKAGE__;
  # need to set new value?
  if (@_ > 0)
    {
    my $u = shift;
    return ${"${class}::upgrade"} = $u;
    }
  ${"${class}::upgrade"};
  }

sub downgrade
  {
  no strict 'refs';
  # make Class->downgrade() work
  my $self = shift;
  my $class = ref($self) || $self || __PACKAGE__;
  # need to set new value?
  if (@_ > 0)
    {
    my $u = shift;
    return ${"${class}::downgrade"} = $u;
    }
  ${"${class}::downgrade"};
  }

sub div_scale
  {
  no strict 'refs';
  # make Class->div_scale() work
  my $self = shift;
  my $class = ref($self) || $self || __PACKAGE__;
  if (defined $_[0])
    {
    if ($_[0] < 0)
      {
      require Carp; Carp::croak ('div_scale must be greater than zero');
      }
    ${"${class}::div_scale"} = shift;
    }
  ${"${class}::div_scale"};
  }

sub accuracy
  {
  # $x->accuracy($a);		ref($x)	$a
  # $x->accuracy();		ref($x)
  # Class->accuracy();		class
  # Class->accuracy($a);	class $a

  my $x = shift;
  my $class = ref($x) || $x || __PACKAGE__;

  no strict 'refs';
  # need to set new value?
  if (@_ > 0)
    {
    my $a = shift;
    # convert objects to scalars to avoid deep recursion. If object doesn't
    # have numify(), then hopefully it will have overloading for int() and
    # boolean test without wandering into a deep recursion path...
    $a = $a->numify() if ref($a) && $a->can('numify');

    if (defined $a)
      {
      # also croak on non-numerical
      if (!$a || $a <= 0)
        {
        require Carp;
        Carp::croak ('Argument to accuracy must be greater than zero');
        }
      if (int($a) != $a)
        {
        require Carp; Carp::croak ('Argument to accuracy must be an integer');
        }
      }
    if (ref($x))
      {
      # $object->accuracy() or fallback to global
      $x->bround($a) if $a;             # not for undef, 0
      $x->{_a} = $a;                    # set/overwrite, even if not rounded
      $x->{_p} = undef;                 # clear P
      $a = ${"${class}::accuracy"} unless defined $a;   # proper return value
      }
    else
      {
      # set global
      ${"${class}::accuracy"} = $a;
      ${"${class}::precision"} = undef; # clear P
      }
    return $a;                          # shortcut
    }

  my $r;
  # $object->accuracy() or fallback to global
  $r = $x->{_a} if ref($x);
  # but don't return global undef, when $x's accuracy is 0!
  $r = ${"${class}::accuracy"} if !defined $r;
  $r;
  }

sub precision
  {
  # $x->precision($p);		ref($x)	$p
  # $x->precision();		ref($x)
  # Class->precision();		class
  # Class->precision($p);	class $p

  my $x = shift;
  my $class = ref($x) || $x || __PACKAGE__;

  no strict 'refs';
  if (@_ > 0)
    {
    my $p = shift;
    # convert objects to scalars to avoid deep recursion. If object doesn't
    # have numify(), then hopefully it will have overloading for int() and
    # boolean test without wandering into a deep recursion path...
    $p = $p->numify() if ref($p) && $p->can('numify');
    if ((defined $p) && (int($p) != $p))
      {
      require Carp; Carp::croak ('Argument to precision must be an integer');
      }
    if (ref($x))
      {
      # $object->precision() or fallback to global
      $x->bfround($p) if $p;            # not for undef, 0
      $x->{_p} = $p;                    # set/overwrite, even if not rounded
      $x->{_a} = undef;                 # clear A
      $p = ${"${class}::precision"} unless defined $p;  # proper return value
      }
    else
      {
      # set global
      ${"${class}::precision"} = $p;
      ${"${class}::accuracy"} = undef;  # clear A
      }
    return $p;                          # shortcut
    }

  my $r;
  # $object->precision() or fallback to global
  $r = $x->{_p} if ref($x);
  # but don't return global undef, when $x's precision is 0!
  $r = ${"${class}::precision"} if !defined $r;
  $r;
  }

sub config
  {
  # return (or set) configuration data as hash ref
  my $class = shift || 'Math::BigInt';

  no strict 'refs';
  if (@_ > 0)
    {
    # try to set given options as arguments from hash

    my $args = $_[0];
    if (ref($args) ne 'HASH')
      {
      $args = { @_ };
      }
    # these values can be "set"
    my $set_args = {};
    foreach my $key (
     qw/trap_inf trap_nan
        upgrade downgrade precision accuracy round_mode div_scale/
     )
      {
      $set_args->{$key} = $args->{$key} if exists $args->{$key};
      delete $args->{$key};
      }
    if (keys %$args > 0)
      {
      require Carp;
      Carp::croak ("Illegal key(s) '",
       join("','",keys %$args),"' passed to $class\->config()");
      }
    foreach my $key (keys %$set_args)
      {
      if ($key =~ /^trap_(inf|nan)\z/)
        {
        ${"${class}::_trap_$1"} = ($set_args->{"trap_$1"} ? 1 : 0);
        next;
        }
      # use a call instead of just setting the $variable to check argument
      $class->$key($set_args->{$key});
      }
    }

  # now return actual configuration

  my $cfg = {
    lib => $CALC,
    lib_version => ${"${CALC}::VERSION"},
    class => $class,
    trap_nan => ${"${class}::_trap_nan"},
    trap_inf => ${"${class}::_trap_inf"},
    version => ${"${class}::VERSION"},
    };
  foreach my $key (qw/
     upgrade downgrade precision accuracy round_mode div_scale
     /)
    {
    $cfg->{$key} = ${"${class}::$key"};
    };
  $cfg;
  }

sub _scale_a
  { 
  # select accuracy parameter based on precedence,
  # used by bround() and bfround(), may return undef for scale (means no op)
  my ($x,$s,$m,$scale,$mode) = @_;
  $scale = $x->{_a} if !defined $scale;
  $scale = $s if (!defined $scale);
  $mode = $m if !defined $mode;
  return ($scale,$mode);
  }

sub _scale_p
  { 
  # select precision parameter based on precedence,
  # used by bround() and bfround(), may return undef for scale (means no op)
  my ($x,$s,$m,$scale,$mode) = @_;
  $scale = $x->{_p} if !defined $scale;
  $scale = $s if (!defined $scale);
  $mode = $m if !defined $mode;
  return ($scale,$mode);
  }

##############################################################################
# constructors

sub copy
  {
  my ($c,$x);
  if (@_ > 1)
    {
    # if two arguments, the first one is the class to "swallow" subclasses
    ($c,$x) = @_;
    }
  else
    {
    $x = shift;
    $c = ref($x);
    }
  return unless ref($x); # only for objects

  my $self = {}; bless $self,$c;
  my $r;
  foreach my $k (keys %$x)
    {
    if ($k eq 'value')
      {
      $self->{value} = $CALC->_copy($x->{value}); next;
      }
    if (!($r = ref($x->{$k})))
      {
      $self->{$k} = $x->{$k}; next;
      }
    if ($r eq 'SCALAR')
      {
      $self->{$k} = \${$x->{$k}};
      }
    elsif ($r eq 'ARRAY')
      {
      $self->{$k} = [ @{$x->{$k}} ];
      }
    elsif ($r eq 'HASH')
      {
      # only one level deep!
      foreach my $h (keys %{$x->{$k}})
        {
        $self->{$k}->{$h} = $x->{$k}->{$h};
        }
      }
    else # normal ref
      {
      my $xk = $x->{$k};
      if ($xk->can('copy'))
        {
	$self->{$k} = $xk->copy();
        }
      else
	{
	$self->{$k} = $xk->new($xk);
	}
      }
    }
  $self;
  }

sub new 
  {
  # create a new BigInt object from a string or another BigInt object. 
  # see hash keys documented at top

  # the argument could be an object, so avoid ||, && etc on it, this would
  # cause costly overloaded code to be called. The only allowed ops are
  # ref() and defined.

  my ($class,$wanted,$a,$p,$r) = @_;
 
  # avoid numify-calls by not using || on $wanted!
  return $class->bzero($a,$p) if !defined $wanted;	# default to 0
  return $class->copy($wanted,$a,$p,$r)
   if ref($wanted) && $wanted->isa($class);		# MBI or subclass

  $class->import() if $IMPORT == 0;		# make require work
  
  my $self = bless {}, $class;

  # shortcut for "normal" numbers
  if ((!ref $wanted) && ($wanted =~ /^([+-]?)[1-9][0-9]*\z/))
    {
    $self->{sign} = $1 || '+';
    my $ref = \$wanted;
    if ($wanted =~ /^[+-]/)
     {
      # remove sign without touching wanted to make it work with constants
      my $t = $wanted; $t =~ s/^[+-]//; $ref = \$t;
      }
    # force to string version (otherwise Pari is unhappy about overflowed
    # constants, for instance)
    # not good, BigInt shouldn't need to know about alternative libs:
    # $ref = \"$$ref" if $CALC eq 'Math::BigInt::Pari';
    $self->{value} = $CALC->_new($ref);
    no strict 'refs';
    if ( (defined $a) || (defined $p) 
        || (defined ${"${class}::precision"})
        || (defined ${"${class}::accuracy"}) 
       )
      {
      $self->round($a,$p,$r) unless (@_ == 4 && !defined $a && !defined $p);
      }
    return $self;
    }

  # handle '+inf', '-inf' first
  if ($wanted =~ /^[+-]?inf$/)
    {
    $self->{value} = $CALC->_zero();
    $self->{sign} = $wanted; $self->{sign} = '+inf' if $self->{sign} eq 'inf';
    return $self;
    }
  # split str in m mantissa, e exponent, i integer, f fraction, v value, s sign
  my ($mis,$miv,$mfv,$es,$ev) = _split(\$wanted);
  if (!ref $mis)
    {
    if ($_trap_nan)
      {
      require Carp; Carp::croak("$wanted is not a number in $class");
      }
    $self->{value} = $CALC->_zero();
    $self->{sign} = $nan;
    return $self;
    }
  if (!ref $miv)
    {
    # _from_hex or _from_bin
    $self->{value} = $mis->{value};
    $self->{sign} = $mis->{sign};
    return $self;	# throw away $mis
    }
  # make integer from mantissa by adjusting exp, then convert to bigint
  $self->{sign} = $$mis;			# store sign
  $self->{value} = $CALC->_zero();		# for all the NaN cases
  my $e = int("$$es$$ev");			# exponent (avoid recursion)
  if ($e > 0)
    {
    my $diff = $e - CORE::length($$mfv);
    if ($diff < 0)				# Not integer
      {
      if ($_trap_nan)
        {
        require Carp; Carp::croak("$wanted not an integer in $class");
        }
      #print "NOI 1\n";
      return $upgrade->new($wanted,$a,$p,$r) if defined $upgrade;
      $self->{sign} = $nan;
      }
    else					# diff >= 0
      {
      # adjust fraction and add it to value
      #print "diff > 0 $$miv\n";
      $$miv = $$miv . ($$mfv . '0' x $diff);
      }
    }
  else
    {
    if ($$mfv ne '')				# e <= 0
      {
      # fraction and negative/zero E => NOI
      if ($_trap_nan)
        {
        require Carp; Carp::croak("$wanted not an integer in $class");
        }
      #print "NOI 2 \$\$mfv '$$mfv'\n";
      return $upgrade->new($wanted,$a,$p,$r) if defined $upgrade;
      $self->{sign} = $nan;
      }
    elsif ($e < 0)
      {
      # xE-y, and empty mfv
      #print "xE-y\n";
      $e = abs($e);
      if ($$miv !~ s/0{$e}$//)		# can strip so many zero's?
        {
        if ($_trap_nan)
          {
          require Carp; Carp::croak("$wanted not an integer in $class");
          }
        #print "NOI 3\n";
        return $upgrade->new($wanted,$a,$p,$r) if defined $upgrade;
        $self->{sign} = $nan;
        }
      }
    }
  $self->{sign} = '+' if $$miv eq '0';			# normalize -0 => +0
  $self->{value} = $CALC->_new($miv) if $self->{sign} =~ /^[+-]$/;
  # if any of the globals is set, use them to round and store them inside $self
  # do not round for new($x,undef,undef) since that is used by MBF to signal
  # no rounding
  $self->round($a,$p,$r) unless @_ == 4 && !defined $a && !defined $p;
  $self;
  }

sub bnan
  {
  # create a bigint 'NaN', if given a BigInt, set it to 'NaN'
  my $self = shift;
  $self = $class if !defined $self;
  if (!ref($self))
    {
    my $c = $self; $self = {}; bless $self, $c;
    }
  no strict 'refs';
  if (${"${class}::_trap_nan"})
    {
    require Carp;
    Carp::croak ("Tried to set $self to NaN in $class\::bnan()");
    }
  $self->import() if $IMPORT == 0;		# make require work
  return if $self->modify('bnan');
  if ($self->can('_bnan'))
    {
    # use subclass to initialize
    $self->_bnan();
    }
  else
    {
    # otherwise do our own thing
    $self->{value} = $CALC->_zero();
    }
  $self->{sign} = $nan;
  delete $self->{_a}; delete $self->{_p};	# rounding NaN is silly
  return $self;
  }

sub binf
  {
  # create a bigint '+-inf', if given a BigInt, set it to '+-inf'
  # the sign is either '+', or if given, used from there
  my $self = shift;
  my $sign = shift; $sign = '+' if !defined $sign || $sign !~ /^-(inf)?$/;
  $self = $class if !defined $self;
  if (!ref($self))
    {
    my $c = $self; $self = {}; bless $self, $c;
    }
  no strict 'refs';
  if (${"${class}::_trap_inf"})
    {
    require Carp;
    Carp::croak ("Tried to set $self to +-inf in $class\::binfn()");
    }
  $self->import() if $IMPORT == 0;		# make require work
  return if $self->modify('binf');
  if ($self->can('_binf'))
    {
    # use subclass to initialize
    $self->_binf();
    }
  else
    {
    # otherwise do our own thing
    $self->{value} = $CALC->_zero();
    }
  $sign = $sign . 'inf' if $sign !~ /inf$/;	# - => -inf
  $self->{sign} = $sign;
  ($self->{_a},$self->{_p}) = @_;		# take over requested rounding
  return $self;
  }

sub bzero
  {
  # create a bigint '+0', if given a BigInt, set it to 0
  my $self = shift;
  $self = $class if !defined $self;
 
  if (!ref($self))
    {
    my $c = $self; $self = {}; bless $self, $c;
    }
  $self->import() if $IMPORT == 0;		# make require work
  return if $self->modify('bzero');
  
  if ($self->can('_bzero'))
    {
    # use subclass to initialize
    $self->_bzero();
    }
  else
    {
    # otherwise do our own thing
    $self->{value} = $CALC->_zero();
    }
  $self->{sign} = '+';
  if (@_ > 0)
    {
    if (@_ > 3)
      {
      # call like: $x->bzero($a,$p,$r,$y);
      ($self,$self->{_a},$self->{_p}) = $self->_find_round_parameters(@_);
      }
    else
      {
      $self->{_a} = $_[0]
       if ( (!defined $self->{_a}) || (defined $_[0] && $_[0] > $self->{_a}));
      $self->{_p} = $_[1]
       if ( (!defined $self->{_p}) || (defined $_[1] && $_[1] > $self->{_p}));
      }
    }
  $self;
  }

sub bone
  {
  # create a bigint '+1' (or -1 if given sign '-'),
  # if given a BigInt, set it to +1 or -1, respecively
  my $self = shift;
  my $sign = shift; $sign = '+' if !defined $sign || $sign ne '-';
  $self = $class if !defined $self;

  if (!ref($self))
    {
    my $c = $self; $self = {}; bless $self, $c;
    }
  $self->import() if $IMPORT == 0;		# make require work
  return if $self->modify('bone');

  if ($self->can('_bone'))
    {
    # use subclass to initialize
    $self->_bone();
    }
  else
    {
    # otherwise do our own thing
    $self->{value} = $CALC->_one();
    }
  $self->{sign} = $sign;
  if (@_ > 0)
    {
    if (@_ > 3)
      {
      # call like: $x->bone($sign,$a,$p,$r,$y);
      ($self,$self->{_a},$self->{_p}) = $self->_find_round_parameters(@_);
      }
    else
      {
      # call like: $x->bone($sign,$a,$p,$r);
      $self->{_a} = $_[0]
       if ( (!defined $self->{_a}) || (defined $_[0] && $_[0] > $self->{_a}));
      $self->{_p} = $_[1]
       if ( (!defined $self->{_p}) || (defined $_[1] && $_[1] > $self->{_p}));
      }
    }
  $self;
  }

##############################################################################
# string conversation

sub bsstr
  {
  # (ref to BFLOAT or num_str ) return num_str
  # Convert number from internal format to scientific string format.
  # internal format is always normalized (no leading zeros, "-0E0" => "+0E0")
  my $x = shift; $class = ref($x) || $x; $x = $class->new(shift) if !ref($x); 
  # my ($self,$x) = ref($_[0]) ? (ref($_[0]),$_[0]) : objectify(1,@_); 

  if ($x->{sign} !~ /^[+-]$/)
    {
    return $x->{sign} unless $x->{sign} eq '+inf';	# -inf, NaN
    return 'inf';					# +inf
    }
  my ($m,$e) = $x->parts();
  #$m->bstr() . 'e+' . $e->bstr(); 	# e can only be positive in BigInt
  # 'e+' because E can only be positive in BigInt
  $m->bstr() . 'e+' . ${$CALC->_str($e->{value})}; 
  }

sub bstr 
  {
  # make a string from bigint object
  my $x = shift; $class = ref($x) || $x; $x = $class->new(shift) if !ref($x); 
  # my ($self,$x) = ref($_[0]) ? (ref($_[0]),$_[0]) : objectify(1,@_); 

  if ($x->{sign} !~ /^[+-]$/)
    {
    return $x->{sign} unless $x->{sign} eq '+inf';	# -inf, NaN
    return 'inf';					# +inf
    }
  my $es = ''; $es = $x->{sign} if $x->{sign} eq '-';
  $es.${$CALC->_str($x->{value})};
  }

sub numify 
  {
  # Make a "normal" scalar from a BigInt object
  my $x = shift; $x = $class->new($x) unless ref $x;

  return $x->bstr() if $x->{sign} !~ /^[+-]$/;
  my $num = $CALC->_num($x->{value});
  return -$num if $x->{sign} eq '-';
  $num;
  }

##############################################################################
# public stuff (usually prefixed with "b")

sub sign
  {
  # return the sign of the number: +/-/-inf/+inf/NaN
  my ($self,$x) = ref($_[0]) ? (undef,$_[0]) : objectify(1,@_); 
  
  $x->{sign};
  }

sub _find_round_parameters
  {
  # After any operation or when calling round(), the result is rounded by
  # regarding the A & P from arguments, local parameters, or globals.

  # !!!!!!! If you change this, remember to change round(), too! !!!!!!!!!!

  # This procedure finds the round parameters, but it is for speed reasons
  # duplicated in round. Otherwise, it is tested by the testsuite and used
  # by fdiv().
 
  # returns ($self) or ($self,$a,$p,$r) - sets $self to NaN of both A and P
  # were requested/defined (locally or globally or both)
  
  my ($self,$a,$p,$r,@args) = @_;
  # $a accuracy, if given by caller
  # $p precision, if given by caller
  # $r round_mode, if given by caller
  # @args all 'other' arguments (0 for unary, 1 for binary ops)

  # leave bigfloat parts alone
  return ($self) if exists $self->{_f} && ($self->{_f} & MB_NEVER_ROUND) != 0;

  my $c = ref($self);				# find out class of argument(s)
  no strict 'refs';

  # now pick $a or $p, but only if we have got "arguments"
  if (!defined $a)
    {
    foreach ($self,@args)
      {
      # take the defined one, or if both defined, the one that is smaller
      $a = $_->{_a} if (defined $_->{_a}) && (!defined $a || $_->{_a} < $a);
      }
    }
  if (!defined $p)
    {
    # even if $a is defined, take $p, to signal error for both defined
    foreach ($self,@args)
      {
      # take the defined one, or if both defined, the one that is bigger
      # -2 > -3, and 3 > 2
      $p = $_->{_p} if (defined $_->{_p}) && (!defined $p || $_->{_p} > $p);
      }
    }
  # if still none defined, use globals (#2)
  $a = ${"$c\::accuracy"} unless defined $a;
  $p = ${"$c\::precision"} unless defined $p;

  # A == 0 is useless, so undef it to signal no rounding
  $a = undef if defined $a && $a == 0;
 
  # no rounding today? 
  return ($self) unless defined $a || defined $p;		# early out

  # set A and set P is an fatal error
  return ($self->bnan()) if defined $a && defined $p;		# error

  $r = ${"$c\::round_mode"} unless defined $r;
  if ($r !~ /^(even|odd|\+inf|\-inf|zero|trunc)$/)
    {
    require Carp; Carp::croak ("Unknown round mode '$r'");
    }

  ($self,$a,$p,$r);
  }

sub round
  {
  # Round $self according to given parameters, or given second argument's
  # parameters or global defaults 

  # for speed reasons, _find_round_parameters is embeded here:

  my ($self,$a,$p,$r,@args) = @_;
  # $a accuracy, if given by caller
  # $p precision, if given by caller
  # $r round_mode, if given by caller
  # @args all 'other' arguments (0 for unary, 1 for binary ops)

  # leave bigfloat parts alone
  return ($self) if exists $self->{_f} && ($self->{_f} & MB_NEVER_ROUND) != 0;

  my $c = ref($self);				# find out class of argument(s)
  no strict 'refs';

  # now pick $a or $p, but only if we have got "arguments"
  if (!defined $a)
    {
    foreach ($self,@args)
      {
      # take the defined one, or if both defined, the one that is smaller
      $a = $_->{_a} if (defined $_->{_a}) && (!defined $a || $_->{_a} < $a);
      }
    }
  if (!defined $p)
    {
    # even if $a is defined, take $p, to signal error for both defined
    foreach ($self,@args)
      {
      # take the defined one, or if both defined, the one that is bigger
      # -2 > -3, and 3 > 2
      $p = $_->{_p} if (defined $_->{_p}) && (!defined $p || $_->{_p} > $p);
      }
    }
  # if still none defined, use globals (#2)
  $a = ${"$c\::accuracy"} unless defined $a;
  $p = ${"$c\::precision"} unless defined $p;
 
  # A == 0 is useless, so undef it to signal no rounding
  $a = undef if defined $a && $a == 0;
  
  # no rounding today? 
  return $self unless defined $a || defined $p;		# early out

  # set A and set P is an fatal error
  return $self->bnan() if defined $a && defined $p;

  $r = ${"$c\::round_mode"} unless defined $r;
  if ($r !~ /^(even|odd|\+inf|\-inf|zero|trunc)$/)
    {
    require Carp; Carp::croak ("Unknown round mode '$r'");
    }

  # now round, by calling either fround or ffround:
  if (defined $a)
    {
    $self->bround($a,$r) if !defined $self->{_a} || $self->{_a} >= $a;
    }
  else # both can't be undefined due to early out
    {
    $self->bfround($p,$r) if !defined $self->{_p} || $self->{_p} <= $p;
    }
  $self->bnorm();			# after round, normalize
  }

sub bnorm
  { 
  # (numstr or BINT) return BINT
  # Normalize number -- no-op here
  my ($self,$x) = ref($_[0]) ? (undef,$_[0]) : objectify(1,@_);
  $x;
  }

sub babs 
  {
  # (BINT or num_str) return BINT
  # make number absolute, or return absolute BINT from string
  my ($self,$x) = ref($_[0]) ? (ref($_[0]),$_[0]) : objectify(1,@_);

  return $x if $x->modify('babs');
  # post-normalized abs for internal use (does nothing for NaN)
  $x->{sign} =~ s/^-/+/;
  $x;
  }

sub bneg 
  { 
  # (BINT or num_str) return BINT
  # negate number or make a negated number from string
  my ($self,$x) = ref($_[0]) ? (ref($_[0]),$_[0]) : objectify(1,@_);
  
  return $x if $x->modify('bneg');

  # for +0 dont negate (to have always normalized)
  $x->{sign} =~ tr/+-/-+/ if !$x->is_zero();	# does nothing for NaN
  $x;
  }

sub bcmp 
  {
  # Compares 2 values.  Returns one of undef, <0, =0, >0. (suitable for sort)
  # (BINT or num_str, BINT or num_str) return cond_code
  
  # set up parameters
  my ($self,$x,$y) = (ref($_[0]),@_);

  # objectify is costly, so avoid it 
  if ((!ref($_[0])) || (ref($_[0]) ne ref($_[1])))
    {
    ($self,$x,$y) = objectify(2,@_);
    }

  return $upgrade->bcmp($x,$y) if defined $upgrade &&
    ((!$x->isa($self)) || (!$y->isa($self)));

  if (($x->{sign} !~ /^[+-]$/) || ($y->{sign} !~ /^[+-]$/))
    {
    # handle +-inf and NaN
    return undef if (($x->{sign} eq $nan) || ($y->{sign} eq $nan));
    return 0 if $x->{sign} eq $y->{sign} && $x->{sign} =~ /^[+-]inf$/;
    return +1 if $x->{sign} eq '+inf';
    return -1 if $x->{sign} eq '-inf';
    return -1 if $y->{sign} eq '+inf';
    return +1;
    }
  # check sign for speed first
  return 1 if $x->{sign} eq '+' && $y->{sign} eq '-';	# does also 0 <=> -y
  return -1 if $x->{sign} eq '-' && $y->{sign} eq '+';  # does also -x <=> 0 

  # have same sign, so compare absolute values. Don't make tests for zero here
  # because it's actually slower than testin in Calc (especially w/ Pari et al)

  # post-normalized compare for internal use (honors signs)
  if ($x->{sign} eq '+') 
    {
    # $x and $y both > 0
    return $CALC->_acmp($x->{value},$y->{value});
    }

  # $x && $y both < 0
  $CALC->_acmp($y->{value},$x->{value});	# swaped acmp (lib returns 0,1,-1)
  }

sub bacmp 
  {
  # Compares 2 values, ignoring their signs. 
  # Returns one of undef, <0, =0, >0. (suitable for sort)
  # (BINT, BINT) return cond_code
  
  # set up parameters
  my ($self,$x,$y) = (ref($_[0]),@_);
  # objectify is costly, so avoid it 
  if ((!ref($_[0])) || (ref($_[0]) ne ref($_[1])))
    {
    ($self,$x,$y) = objectify(2,@_);
    }

  return $upgrade->bacmp($x,$y) if defined $upgrade &&
    ((!$x->isa($self)) || (!$y->isa($self)));

  if (($x->{sign} !~ /^[+-]$/) || ($y->{sign} !~ /^[+-]$/))
    {
    # handle +-inf and NaN
    return undef if (($x->{sign} eq $nan) || ($y->{sign} eq $nan));
    return 0 if $x->{sign} =~ /^[+-]inf$/ && $y->{sign} =~ /^[+-]inf$/;
    return +1;	# inf is always bigger
    }
  $CALC->_acmp($x->{value},$y->{value});	# lib does only 0,1,-1
  }

sub badd 
  {
  # add second arg (BINT or string) to first (BINT) (modifies first)
  # return result as BINT

  # set up parameters
  my ($self,$x,$y,@r) = (ref($_[0]),@_);
  # objectify is costly, so avoid it 
  if ((!ref($_[0])) || (ref($_[0]) ne ref($_[1])))
    {
    ($self,$x,$y,@r) = objectify(2,@_);
    }

  return $x if $x->modify('badd');
  return $upgrade->badd($upgrade->new($x),$upgrade->new($y),@r) if defined $upgrade &&
    ((!$x->isa($self)) || (!$y->isa($self)));

  $r[3] = $y;				# no push!
  # inf and NaN handling
  if (($x->{sign} !~ /^[+-]$/) || ($y->{sign} !~ /^[+-]$/))
    {
    # NaN first
    return $x->bnan() if (($x->{sign} eq $nan) || ($y->{sign} eq $nan));
    # inf handling
    if (($x->{sign} =~ /^[+-]inf$/) && ($y->{sign} =~ /^[+-]inf$/))
      {
      # +inf++inf or -inf+-inf => same, rest is NaN
      return $x if $x->{sign} eq $y->{sign};
      return $x->bnan();
      }
    # +-inf + something => +inf
    # something +-inf => +-inf
    $x->{sign} = $y->{sign}, return $x if $y->{sign} =~ /^[+-]inf$/;
    return $x;
    }
    
  my ($sx, $sy) = ( $x->{sign}, $y->{sign} ); 		# get signs

  if ($sx eq $sy)  
    {
    $x->{value} = $CALC->_add($x->{value},$y->{value});	# same sign, abs add
    }
  else 
    {
    my $a = $CALC->_acmp ($y->{value},$x->{value});	# absolute compare
    if ($a > 0)                           
      {
      $x->{value} = $CALC->_sub($y->{value},$x->{value},1); # abs sub w/ swap
      $x->{sign} = $sy;
      } 
    elsif ($a == 0)
      {
      # speedup, if equal, set result to 0
      $x->{value} = $CALC->_zero();
      $x->{sign} = '+';
      }
    else # a < 0
      {
      $x->{value} = $CALC->_sub($x->{value}, $y->{value}); # abs sub
      }
    }
  $x->round(@r) if !exists $x->{_f} || $x->{_f} & MB_NEVER_ROUND == 0;
  $x;
  }

sub bsub 
  {
  # (BINT or num_str, BINT or num_str) return BINT
  # subtract second arg from first, modify first
  
  # set up parameters
  my ($self,$x,$y,@r) = (ref($_[0]),@_);
  # objectify is costly, so avoid it
  if ((!ref($_[0])) || (ref($_[0]) ne ref($_[1])))
    {
    ($self,$x,$y,@r) = objectify(2,@_);
    }

  return $x if $x->modify('bsub');

# upgrade done by badd():
#  return $upgrade->badd($x,$y,@r) if defined $upgrade &&
#   ((!$x->isa($self)) || (!$y->isa($self)));

  if ($y->is_zero())
    { 
    $x->round(@r) if !exists $x->{_f} || $x->{_f} & MB_NEVER_ROUND == 0;
    return $x;
    }

  $y->{sign} =~ tr/+\-/-+/; 	# does nothing for NaN
  $x->badd($y,@r); 		# badd does not leave internal zeros
  $y->{sign} =~ tr/+\-/-+/; 	# refix $y (does nothing for NaN)
  $x;				# already rounded by badd() or no round necc.
  }

sub binc
  {
  # increment arg by one
  my ($self,$x,$a,$p,$r) = ref($_[0]) ? (ref($_[0]),@_) : objectify(1,@_);
  return $x if $x->modify('binc');

  if ($x->{sign} eq '+')
    {
    $x->{value} = $CALC->_inc($x->{value});
    $x->round($a,$p,$r) if !exists $x->{_f} || $x->{_f} & MB_NEVER_ROUND == 0;
    return $x;
    }
  elsif ($x->{sign} eq '-')
    {
    $x->{value} = $CALC->_dec($x->{value});
    $x->{sign} = '+' if $CALC->_is_zero($x->{value}); # -1 +1 => -0 => +0
    $x->round($a,$p,$r) if !exists $x->{_f} || $x->{_f} & MB_NEVER_ROUND == 0;
    return $x;
    }
  # inf, nan handling etc
  $x->badd($self->bone(),$a,$p,$r);		# badd does round
  }

sub bdec
  {
  # decrement arg by one
  my ($self,$x,@r) = ref($_[0]) ? (ref($_[0]),@_) : objectify(1,@_);
  return $x if $x->modify('bdec');
  
  if ($x->{sign} eq '-')
    {
    # < 0
    $x->{value} = $CALC->_inc($x->{value});
    } 
  else
    {
    return $x->badd($self->bone('-'),@r) unless $x->{sign} eq '+'; # inf/NaN
    # >= 0
    if ($CALC->_is_zero($x->{value}))
      {
      # == 0
      $x->{value} = $CALC->_one(); $x->{sign} = '-';		# 0 => -1
      }
    else
      {
      # > 0
      $x->{value} = $CALC->_dec($x->{value});
      }
    }
  $x->round(@r) if !exists $x->{_f} || $x->{_f} & MB_NEVER_ROUND == 0;
  $x;
  }

sub blog
  {
  # calculate $x = $a ** $base + $b and return $a (e.g. the log() to base
  # $base of $x)

  # set up parameters
  my ($self,$x,$base,@r) = (ref($_[0]),@_);
  # objectify is costly, so avoid it
  if ((!ref($_[0])) || (ref($_[0]) ne ref($_[1])))
    {
    ($self,$x,$base,@r) = objectify(2,$class,@_);
    }

  # inf, -inf, NaN, <0 => NaN
  return $x->bnan()
   if $x->{sign} ne '+' || $base->{sign} ne '+';
  
  return $upgrade->blog($upgrade->new($x),$base,@r) if 
    defined $upgrade && (ref($x) ne $upgrade || ref($base) ne $upgrade);

  if ($CAN{log_int})
    {
    my ($rc,$exact) = $CALC->_log_int($x->{value},$base->{value});
    return $x->bnan() unless defined $rc;
    $x->{value} = $rc;
    return $x->round(@r);
    }

  require $EMU_LIB;
  __emu_blog($self,$x,$base,@r);
  }

sub blcm 
  { 
  # (BINT or num_str, BINT or num_str) return BINT
  # does not modify arguments, but returns new object
  # Lowest Common Multiplicator

  my $y = shift; my ($x);
  if (ref($y))
    {
    $x = $y->copy();
    }
  else
    {
    $x = $class->new($y);
    }
  while (@_) { $x = __lcm($x,shift); } 
  $x;
  }

sub bgcd 
  { 
  # (BINT or num_str, BINT or num_str) return BINT
  # does not modify arguments, but returns new object
  # GCD -- Euclids algorithm, variant C (Knuth Vol 3, pg 341 ff)

  my $y = shift;
  $y = __PACKAGE__->new($y) if !ref($y);
  my $self = ref($y);
  my $x = $y->copy();		# keep arguments
  if ($CAN{gcd})
    {
    while (@_)
      {
      $y = shift; $y = $self->new($y) if !ref($y);
      next if $y->is_zero();
      return $x->bnan() if $y->{sign} !~ /^[+-]$/;	# y NaN?
      $x->{value} = $CALC->_gcd($x->{value},$y->{value}); last if $x->is_one();
      }
    }
  else
    {
    while (@_)
      {
      $y = shift; $y = $self->new($y) if !ref($y);
      $x = __gcd($x,$y->copy()); last if $x->is_one();	# _gcd handles NaN
      } 
    }
  $x->babs();
  }

sub bnot 
  {
  # (num_str or BINT) return BINT
  # represent ~x as twos-complement number
  # we don't need $self, so undef instead of ref($_[0]) make it slightly faster
  my ($self,$x,$a,$p,$r) = ref($_[0]) ? (undef,@_) : objectify(1,@_);
 
  return $x if $x->modify('bnot');
  $x->binc()->bneg();			# binc already does round
  }

##############################################################################
# is_foo test routines
# we don't need $self, so undef instead of ref($_[0]) make it slightly faster

sub is_zero
  {
  # return true if arg (BINT or num_str) is zero (array '+', '0')
  my ($self,$x) = ref($_[0]) ? (undef,$_[0]) : objectify(1,@_);
  
  return 0 if $x->{sign} !~ /^\+$/;			# -, NaN & +-inf aren't
  $CALC->_is_zero($x->{value});
  }

sub is_nan
  {
  # return true if arg (BINT or num_str) is NaN
  my ($self,$x) = ref($_[0]) ? (undef,$_[0]) : objectify(1,@_);

  $x->{sign} eq $nan ? 1 : 0;
  }

sub is_inf
  {
  # return true if arg (BINT or num_str) is +-inf
  my ($self,$x,$sign) = ref($_[0]) ? (undef,@_) : objectify(1,@_);

  if (defined $sign)
    {
    $sign = '[+-]inf' if $sign eq '';	# +- doesn't matter, only that's inf
    $sign = "[$1]inf" if $sign =~ /^([+-])(inf)?$/;	# extract '+' or '-'
    return $x->{sign} =~ /^$sign$/ ? 1 : 0;
    }
  $x->{sign} =~ /^[+-]inf$/ ? 1 : 0;		# only +-inf is infinity
  }

sub is_one
  {
  # return true if arg (BINT or num_str) is +1, or -1 if sign is given
  my ($self,$x,$sign) = ref($_[0]) ? (undef,@_) : objectify(1,@_);
    
  $sign = '+' if !defined $sign || $sign ne '-';
 
  return 0 if $x->{sign} ne $sign; 	# -1 != +1, NaN, +-inf aren't either
  $CALC->_is_one($x->{value});
  }

sub is_odd
  {
  # return true when arg (BINT or num_str) is odd, false for even
  my ($self,$x) = ref($_[0]) ? (undef,$_[0]) : objectify(1,@_);

  return 0 if $x->{sign} !~ /^[+-]$/;			# NaN & +-inf aren't
  $CALC->_is_odd($x->{value});
  }

sub is_even
  {
  # return true when arg (BINT or num_str) is even, false for odd
  my ($self,$x) = ref($_[0]) ? (undef,$_[0]) : objectify(1,@_);

  return 0 if $x->{sign} !~ /^[+-]$/;			# NaN & +-inf aren't
  $CALC->_is_even($x->{value});
  }

sub is_positive
  {
  # return true when arg (BINT or num_str) is positive (>= 0)
  my ($self,$x) = ref($_[0]) ? (undef,$_[0]) : objectify(1,@_);
  
  $x->{sign} =~ /^\+/ ? 1 : 0;		# +inf is also positive, but NaN not
  }

sub is_negative
  {
  # return true when arg (BINT or num_str) is negative (< 0)
  my ($self,$x) = ref($_[0]) ? (undef,$_[0]) : objectify(1,@_);
  
  $x->{sign} =~ /^-/ ? 1 : 0; 		# -inf is also negative, but NaN not
  }

sub is_int
  {
  # return true when arg (BINT or num_str) is an integer
  # always true for BigInt, but different for BigFloats
  my ($self,$x) = ref($_[0]) ? (undef,$_[0]) : objectify(1,@_);
  
  $x->{sign} =~ /^[+-]$/ ? 1 : 0;		# inf/-inf/NaN aren't
  }

###############################################################################

sub bmul 
  { 
  # multiply two numbers -- stolen from Knuth Vol 2 pg 233
  # (BINT or num_str, BINT or num_str) return BINT

  # set up parameters
  my ($self,$x,$y,@r) = (ref($_[0]),@_);
  # objectify is costly, so avoid it
  if ((!ref($_[0])) || (ref($_[0]) ne ref($_[1])))
    {
    ($self,$x,$y,@r) = objectify(2,@_);
    }
  
  return $x if $x->modify('bmul');

  return $x->bnan() if (($x->{sign} eq $nan) || ($y->{sign} eq $nan));

  # inf handling
  if (($x->{sign} =~ /^[+-]inf$/) || ($y->{sign} =~ /^[+-]inf$/))
    {
    return $x->bnan() if $x->is_zero() || $y->is_zero();
    # result will always be +-inf:
    # +inf * +/+inf => +inf, -inf * -/-inf => +inf
    # +inf * -/-inf => -inf, -inf * +/+inf => -inf
    return $x->binf() if ($x->{sign} =~ /^\+/ && $y->{sign} =~ /^\+/); 
    return $x->binf() if ($x->{sign} =~ /^-/ && $y->{sign} =~ /^-/); 
    return $x->binf('-');
    }
  
  return $upgrade->bmul($x,$y,@r)
   if defined $upgrade && $y->isa($upgrade);
  
  $r[3] = $y;				# no push here

  $x->{sign} = $x->{sign} eq $y->{sign} ? '+' : '-'; # +1 * +1 or -1 * -1 => +

  $x->{value} = $CALC->_mul($x->{value},$y->{value});	# do actual math
  $x->{sign} = '+' if $CALC->_is_zero($x->{value}); 	# no -0

  $x->round(@r) if !exists $x->{_f} || $x->{_f} & MB_NEVER_ROUND == 0;
  $x;
  }

sub _div_inf
  {
  # helper function that handles +-inf cases for bdiv()/bmod() to reuse code
  my ($self,$x,$y) = @_;

  # NaN if x == NaN or y == NaN or x==y==0
  return wantarray ? ($x->bnan(),$self->bnan()) : $x->bnan()
   if (($x->is_nan() || $y->is_nan())   ||
       ($x->is_zero() && $y->is_zero()));
 
  # +-inf / +-inf == NaN, reminder also NaN
  if (($x->{sign} =~ /^[+-]inf$/) && ($y->{sign} =~ /^[+-]inf$/))
    {
    return wantarray ? ($x->bnan(),$self->bnan()) : $x->bnan();
    }
  # x / +-inf => 0, remainder x (works even if x == 0)
  if ($y->{sign} =~ /^[+-]inf$/)
    {
    my $t = $x->copy();		# bzero clobbers up $x
    return wantarray ? ($x->bzero(),$t) : $x->bzero()
    }
  
  # 5 / 0 => +inf, -6 / 0 => -inf
  # +inf / 0 = inf, inf,  and -inf / 0 => -inf, -inf 
  # exception:   -8 / 0 has remainder -8, not 8
  # exception: -inf / 0 has remainder -inf, not inf
  if ($y->is_zero())
    {
    # +-inf / 0 => special case for -inf
    return wantarray ?  ($x,$x->copy()) : $x if $x->is_inf();
    if (!$x->is_zero() && !$x->is_inf())
      {
      my $t = $x->copy();		# binf clobbers up $x
      return wantarray ?
       ($x->binf($x->{sign}),$t) : $x->binf($x->{sign})
      }
    }
  
  # last case: +-inf / ordinary number
  my $sign = '+inf';
  $sign = '-inf' if substr($x->{sign},0,1) ne $y->{sign};
  $x->{sign} = $sign;
  return wantarray ? ($x,$self->bzero()) : $x;
  }

sub bdiv 
  {
  # (dividend: BINT or num_str, divisor: BINT or num_str) return 
  # (BINT,BINT) (quo,rem) or BINT (only rem)
  
  # set up parameters
  my ($self,$x,$y,@r) = (ref($_[0]),@_);
  # objectify is costly, so avoid it 
  if ((!ref($_[0])) || (ref($_[0]) ne ref($_[1])))
    {
    ($self,$x,$y,@r) = objectify(2,@_);
    } 

  return $x if $x->modify('bdiv');

  return $self->_div_inf($x,$y)
   if (($x->{sign} !~ /^[+-]$/) || ($y->{sign} !~ /^[+-]$/) || $y->is_zero());

  return $upgrade->bdiv($upgrade->new($x),$upgrade->new($y),@r)
   if defined $upgrade;
   
  $r[3] = $y;					# no push!

  # calc new sign and in case $y == +/- 1, return $x
  my $xsign = $x->{sign};				# keep
  $x->{sign} = ($x->{sign} ne $y->{sign} ? '-' : '+'); 

  if (wantarray)
    {
    my $rem = $self->bzero(); 
    ($x->{value},$rem->{value}) = $CALC->_div($x->{value},$y->{value});
    $x->{sign} = '+' if $CALC->_is_zero($x->{value});
    $rem->{_a} = $x->{_a};
    $rem->{_p} = $x->{_p};
    $x->round(@r) if !exists $x->{_f} || ($x->{_f} & MB_NEVER_ROUND) == 0;
    if (! $CALC->_is_zero($rem->{value}))
      {
      $rem->{sign} = $y->{sign};
      $rem = $y->copy()->bsub($rem) if $xsign ne $y->{sign}; # one of them '-'
      }
    else
      {
      $rem->{sign} = '+';			# dont leave -0
      }
    $rem->round(@r) if !exists $rem->{_f} || ($rem->{_f} & MB_NEVER_ROUND) == 0;
    return ($x,$rem);
    }

  $x->{value} = $CALC->_div($x->{value},$y->{value});
  $x->{sign} = '+' if $CALC->_is_zero($x->{value});

  $x->round(@r) if !exists $x->{_f} || ($x->{_f} & MB_NEVER_ROUND) == 0;
  $x;
  }

###############################################################################
# modulus functions

sub bmod 
  {
  # modulus (or remainder)
  # (BINT or num_str, BINT or num_str) return BINT
  
  # set up parameters
  my ($self,$x,$y,@r) = (ref($_[0]),@_);
  # objectify is costly, so avoid it
  if ((!ref($_[0])) || (ref($_[0]) ne ref($_[1])))
    {
    ($self,$x,$y,@r) = objectify(2,@_);
    }

  return $x if $x->modify('bmod');
  $r[3] = $y;					# no push!
  if (($x->{sign} !~ /^[+-]$/) || ($y->{sign} !~ /^[+-]$/) || $y->is_zero())
    {
    my ($d,$r) = $self->_div_inf($x,$y);
    $x->{sign} = $r->{sign};
    $x->{value} = $r->{value};
    return $x->round(@r);
    }

  if ($CAN{mod})
    {
    # calc new sign and in case $y == +/- 1, return $x
    $x->{value} = $CALC->_mod($x->{value},$y->{value});
    if (!$CALC->_is_zero($x->{value}))
      {
      my $xsign = $x->{sign};
      $x->{sign} = $y->{sign};
      if ($xsign ne $y->{sign})
        {
        my $t = $CALC->_copy($x->{value});		# copy $x
        $x->{value} = $CALC->_sub($y->{value},$t,1); 	# $y-$x
        }
      }
    else
      {
      $x->{sign} = '+';				# dont leave -0
      }
    $x->round(@r) if !exists $x->{_f} || $x->{_f} & MB_NEVER_ROUND == 0;
    return $x;
    }
  # disable upgrade temporarily, otherwise endless loop due to bdiv()
  local $upgrade = undef;
  my ($t,$rem) = $self->bdiv($x->copy(),$y,@r);	# slow way (also rounds)
  # modify in place
  foreach (qw/value sign _a _p/)
    {
    $x->{$_} = $rem->{$_};
    }
  $x;
  }

sub bmodinv
  {
  # Modular inverse.  given a number which is (hopefully) relatively
  # prime to the modulus, calculate its inverse using Euclid's
  # alogrithm.  If the number is not relatively prime to the modulus
  # (i.e. their gcd is not one) then NaN is returned.

  # set up parameters
  my ($self,$x,$y,@r) = (ref($_[0]),@_);
  # objectify is costly, so avoid it
  if ((!ref($_[0])) || (ref($_[0]) ne ref($_[1])))
    {
    ($self,$x,$y,@r) = objectify(2,@_);
    }

  return $x if $x->modify('bmodinv');

  return $x->bnan()
        if ($y->{sign} ne '+'                           # -, NaN, +inf, -inf
         || $x->is_zero()                               # or num == 0
         || $x->{sign} !~ /^[+-]$/                      # or num NaN, inf, -inf
        );

  # put least residue into $x if $x was negative, and thus make it positive
  $x->bmod($y) if $x->{sign} eq '-';

  if ($CAN{modinv})
    {
    my $sign;
    ($x->{value},$sign) = $CALC->_modinv($x->{value},$y->{value});
    return $x->bnan() if !defined $x->{value};		# in case no GCD found
    return $x if !defined $sign;			# already real result
    $x->{sign} = $sign;					# flip/flop see below
    $x->bmod($y);					# calc real result
    return $x;
    }

  require $EMU_LIB;
  __emu_bmodinv($self,$x,$y,@r);
  }

sub bmodpow
  {
  # takes a very large number to a very large exponent in a given very
  # large modulus, quickly, thanks to binary exponentation.  supports
  # negative exponents.
  my ($self,$num,$exp,$mod,@r) = objectify(3,@_);

  return $num if $num->modify('bmodpow');

  # check modulus for valid values
  return $num->bnan() if ($mod->{sign} ne '+'		# NaN, - , -inf, +inf
                       || $mod->is_zero());

  # check exponent for valid values
  if ($exp->{sign} =~ /\w/) 
    {
    # i.e., if it's NaN, +inf, or -inf...
    return $num->bnan();
    }

  $num->bmodinv ($mod) if ($exp->{sign} eq '-');

  # check num for valid values (also NaN if there was no inverse but $exp < 0)
  return $num->bnan() if $num->{sign} !~ /^[+-]$/;

  if ($CAN{modpow})
    {
    # $mod is positive, sign on $exp is ignored, result also positive
    $num->{value} = $CALC->_modpow($num->{value},$exp->{value},$mod->{value});
    return $num;
    }

  require $EMU_LIB;
  __emu_bmodpow($self,$num,$exp,$mod,@r);
  }

###############################################################################

sub bfac
  {
  # (BINT or num_str, BINT or num_str) return BINT
  # compute factorial number from $x, modify $x in place
  my ($self,$x,@r) = ref($_[0]) ? (ref($_[0]),@_) : objectify(1,@_);

  return $x if $x->modify('bfac');
 
  return $x if $x->{sign} eq '+inf';		# inf => inf
  return $x->bnan() if $x->{sign} ne '+';	# NaN, <0 etc => NaN

  if ($CAN{fac})
    {
    $x->{value} = $CALC->_fac($x->{value});
    return $x->round(@r);
    }

  require $EMU_LIB;
  __emu_bfac($self,$x,@r);
  }
 
sub bpow 
  {
  # (BINT or num_str, BINT or num_str) return BINT
  # compute power of two numbers -- stolen from Knuth Vol 2 pg 233
  # modifies first argument

  # set up parameters
  my ($self,$x,$y,@r) = (ref($_[0]),@_);
  # objectify is costly, so avoid it
  if ((!ref($_[0])) || (ref($_[0]) ne ref($_[1])))
    {
    ($self,$x,$y,@r) = objectify(2,@_);
    }

  return $x if $x->modify('bpow');

  return $upgrade->bpow($upgrade->new($x),$y,@r)
   if defined $upgrade && !$y->isa($self);

  $r[3] = $y;					# no push!
  return $x if $x->{sign} =~ /^[+-]inf$/;	# -inf/+inf ** x
  return $x->bnan() if $x->{sign} eq $nan || $y->{sign} eq $nan;

  # cases 0 ** Y, X ** 0, X ** 1, 1 ** Y are handled by Calc or Emu

  if ($x->{sign} eq '-' && $CALC->_is_one($x->{value}))
    {
    # if $x == -1 and odd/even y => +1/-1
    return $y->is_odd() ? $x->round(@r) : $x->babs()->round(@r);
    # my Casio FX-5500L has a bug here: -1 ** 2 is -1, but -1 * -1 is 1;
    }
  # 1 ** -y => 1 / (1 ** |y|)
  # so do test for negative $y after above's clause
  return $x->bnan() if $y->{sign} eq '-' && !$x->is_one();

  if ($CAN{pow})
    {
    $x->{value} = $CALC->_pow($x->{value},$y->{value});
    $x->{sign} = '+' if $CALC->_is_zero($y->{value});
    $x->round(@r) if !exists $x->{_f} || $x->{_f} & MB_NEVER_ROUND == 0;
    return $x;
    }

  require $EMU_LIB;
  __emu_bpow($self,$x,$y,@r);
  }

sub blsft 
  {
  # (BINT or num_str, BINT or num_str) return BINT
  # compute x << y, base n, y >= 0
 
  # set up parameters
  my ($self,$x,$y,$n,@r) = (ref($_[0]),@_);
  # objectify is costly, so avoid it
  if ((!ref($_[0])) || (ref($_[0]) ne ref($_[1])))
    {
    ($self,$x,$y,$n,@r) = objectify(2,@_);
    }

  return $x if $x->modify('blsft');
  return $x->bnan() if ($x->{sign} !~ /^[+-]$/ || $y->{sign} !~ /^[+-]$/);
  return $x->round(@r) if $y->is_zero();

  $n = 2 if !defined $n; return $x->bnan() if $n <= 0 || $y->{sign} eq '-';

  my $t; $t = $CALC->_lsft($x->{value},$y->{value},$n) if $CAN{lsft};
  if (defined $t)
    {
    $x->{value} = $t; return $x->round(@r);
    }
  # fallback
  $x->bmul( $self->bpow($n, $y, @r), @r );
  }

sub brsft 
  {
  # (BINT or num_str, BINT or num_str) return BINT
  # compute x >> y, base n, y >= 0
  
  # set up parameters
  my ($self,$x,$y,$n,@r) = (ref($_[0]),@_);
  # objectify is costly, so avoid it
  if ((!ref($_[0])) || (ref($_[0]) ne ref($_[1])))
    {
    ($self,$x,$y,$n,@r) = objectify(2,@_);
    }

  return $x if $x->modify('brsft');
  return $x->bnan() if ($x->{sign} !~ /^[+-]$/ || $y->{sign} !~ /^[+-]$/);
  return $x->round(@r) if $y->is_zero();
  return $x->bzero(@r) if $x->is_zero();		# 0 => 0

  $n = 2 if !defined $n; return $x->bnan() if $n <= 0 || $y->{sign} eq '-';

   # this only works for negative numbers when shifting in base 2
  if (($x->{sign} eq '-') && ($n == 2))
    {
    return $x->round(@r) if $x->is_one('-');	# -1 => -1
    if (!$y->is_one())
      {
      # although this is O(N*N) in calc (as_bin!) it is O(N) in Pari et al
      # but perhaps there is a better emulation for two's complement shift...
      # if $y != 1, we must simulate it by doing:
      # convert to bin, flip all bits, shift, and be done
      $x->binc();			# -3 => -2
      my $bin = $x->as_bin();
      $bin =~ s/^-0b//;			# strip '-0b' prefix
      $bin =~ tr/10/01/;		# flip bits
      # now shift
      if (CORE::length($bin) <= $y)
        {
	$bin = '0'; 			# shifting to far right creates -1
					# 0, because later increment makes 
					# that 1, attached '-' makes it '-1'
					# because -1 >> x == -1 !
        } 
      else
	{
	$bin =~ s/.{$y}$//;		# cut off at the right side
        $bin = '1' . $bin;		# extend left side by one dummy '1'
        $bin =~ tr/10/01/;		# flip bits back
	}
      my $res = $self->new('0b'.$bin);	# add prefix and convert back
      $res->binc();			# remember to increment
      $x->{value} = $res->{value};	# take over value
      return $x->round(@r);		# we are done now, magic, isn't?
      }
    # x < 0, n == 2, y == 1
    $x->bdec();				# n == 2, but $y == 1: this fixes it
    }

  my $t; $t = $CALC->_rsft($x->{value},$y->{value},$n) if $CAN{rsft};
  if (defined $t)
    {
    $x->{value} = $t;
    return $x->round(@r);
    }
  # fallback
  $x->bdiv($self->bpow($n,$y, @r), @r);
  $x;
  }

sub band 
  {
  #(BINT or num_str, BINT or num_str) return BINT
  # compute x & y
 
  # set up parameters
  my ($self,$x,$y,@r) = (ref($_[0]),@_);
  # objectify is costly, so avoid it
  if ((!ref($_[0])) || (ref($_[0]) ne ref($_[1])))
    {
    ($self,$x,$y,@r) = objectify(2,@_);
    }
  
  return $x if $x->modify('band');

  $r[3] = $y;				# no push!

  return $x->bnan() if ($x->{sign} !~ /^[+-]$/ || $y->{sign} !~ /^[+-]$/);

  my $sx = $x->{sign} eq '+' ? 1 : -1;
  my $sy = $y->{sign} eq '+' ? 1 : -1;
  
  if ($CAN{and} && $sx == 1 && $sy == 1)
    {
    $x->{value} = $CALC->_and($x->{value},$y->{value});
    return $x->round(@r);
    }
  
  if ($CAN{signed_and})
    {
    $x->{value} = $CALC->_signed_and($x->{value},$y->{value},$sx,$sy);
    return $x->round(@r);
    }
 
  require $EMU_LIB;
  __emu_band($self,$x,$y,$sx,$sy,@r);
  }

sub bior 
  {
  #(BINT or num_str, BINT or num_str) return BINT
  # compute x | y
  
  # set up parameters
  my ($self,$x,$y,@r) = (ref($_[0]),@_);
  # objectify is costly, so avoid it
  if ((!ref($_[0])) || (ref($_[0]) ne ref($_[1])))
    {
    ($self,$x,$y,@r) = objectify(2,@_);
    }

  return $x if $x->modify('bior');
  $r[3] = $y;				# no push!

  local $Math::BigInt::upgrade = undef;

  return $x->bnan() if ($x->{sign} !~ /^[+-]$/ || $y->{sign} !~ /^[+-]$/);

  my $sx = $x->{sign} eq '+' ? 1 : -1;
  my $sy = $y->{sign} eq '+' ? 1 : -1;

  # the sign of X follows the sign of X, e.g. sign of Y irrelevant for bior()
  
  # don't use lib for negative values
  if ($CAN{or} && $sx == 1 && $sy == 1)
    {
    $x->{value} = $CALC->_or($x->{value},$y->{value});
    return $x->round(@r);
    }

  # if lib can do negative values, let it handle this
  if ($CAN{signed_or})
    {
    $x->{value} = $CALC->_signed_or($x->{value},$y->{value},$sx,$sy);
    return $x->round(@r);
    }

  require $EMU_LIB;
  __emu_bior($self,$x,$y,$sx,$sy,@r);
  }

sub bxor 
  {
  #(BINT or num_str, BINT or num_str) return BINT
  # compute x ^ y
  
  # set up parameters
  my ($self,$x,$y,@r) = (ref($_[0]),@_);
  # objectify is costly, so avoid it
  if ((!ref($_[0])) || (ref($_[0]) ne ref($_[1])))
    {
    ($self,$x,$y,@r) = objectify(2,@_);
    }

  return $x if $x->modify('bxor');
  $r[3] = $y;				# no push!

  return $x->bnan() if ($x->{sign} !~ /^[+-]$/ || $y->{sign} !~ /^[+-]$/);
  
  my $sx = $x->{sign} eq '+' ? 1 : -1;
  my $sy = $y->{sign} eq '+' ? 1 : -1;

  # don't use lib for negative values
  if ($CAN{xor} && $sx == 1 && $sy == 1)
    {
    $x->{value} = $CALC->_xor($x->{value},$y->{value});
    return $x->round(@r);
    }
  
  # if lib can do negative values, let it handle this
  if ($CAN{signed_xor})
    {
    $x->{value} = $CALC->_signed_xor($x->{value},$y->{value},$sx,$sy);
    return $x->round(@r);
    }

  require $EMU_LIB;
  __emu_bxor($self,$x,$y,$sx,$sy,@r);
  }

sub length
  {
  my ($self,$x) = ref($_[0]) ? (undef,$_[0]) : objectify(1,@_);

  my $e = $CALC->_len($x->{value}); 
  wantarray ? ($e,0) : $e;
  }

sub digit
  {
  # return the nth decimal digit, negative values count backward, 0 is right
  my ($self,$x,$n) = ref($_[0]) ? (ref($_[0]),@_) : objectify(1,@_);

  $CALC->_digit($x->{value},$n||0);
  }

sub _trailing_zeros
  {
  # return the amount of trailing zeros in $x (as scalar)
  my $x = shift;
  $x = $class->new($x) unless ref $x;

  return 0 if $x->is_zero() || $x->is_odd() || $x->{sign} !~ /^[+-]$/;

  return $CALC->_zeros($x->{value}) if $CAN{zeros};

  # if not: since we do not know underlying internal representation:
  my $es = "$x"; $es =~ /([0]*)$/;
  return 0 if !defined $1;	# no zeros
  CORE::length("$1");		# as string, not as +0!
  }

sub bsqrt
  {
  # calculate square root of $x
  my ($self,$x,@r) = ref($_[0]) ? (ref($_[0]),@_) : objectify(1,@_);

  return $x if $x->modify('bsqrt');

  return $x->bnan() if $x->{sign} !~ /^\+/;	# -x or -inf or NaN => NaN
  return $x if $x->{sign} eq '+inf';		# sqrt(+inf) == inf

  return $upgrade->bsqrt($x,@r) if defined $upgrade;

  if ($CAN{sqrt})
    {
    $x->{value} = $CALC->_sqrt($x->{value});
    return $x->round(@r);
    }

  require $EMU_LIB;
  __emu_bsqrt($self,$x,@r);
  }

sub broot
  {
  # calculate $y'th root of $x
 
  # set up parameters
  my ($self,$x,$y,@r) = (ref($_[0]),@_);

  $y = $self->new(2) unless defined $y;

  # objectify is costly, so avoid it
  if ((!ref($x)) || (ref($x) ne ref($y)))
    {
    ($self,$x,$y,@r) = objectify(2,$self || $class,@_);
    }

  return $x if $x->modify('broot');

  # NaN handling: $x ** 1/0, x or y NaN, or y inf/-inf or y == 0
  return $x->bnan() if $x->{sign} !~ /^\+/ || $y->is_zero() ||
         $y->{sign} !~ /^\+$/;

  return $x->round(@r)
    if $x->is_zero() || $x->is_one() || $x->is_inf() || $y->is_one();

  return $upgrade->new($x)->broot($upgrade->new($y),@r) if defined $upgrade;

  if ($CAN{root})
    {
    $x->{value} = $CALC->_root($x->{value},$y->{value});
    return $x->round(@r);
    }

  require $EMU_LIB;
  __emu_broot($self,$x,$y,@r);
  }

sub exponent
  {
  # return a copy of the exponent (here always 0, NaN or 1 for $m == 0)
  my ($self,$x) = ref($_[0]) ? (ref($_[0]),$_[0]) : objectify(1,@_);
 
  if ($x->{sign} !~ /^[+-]$/)
    {
    my $s = $x->{sign}; $s =~ s/^[+-]//;  # NaN, -inf,+inf => NaN or inf
    return $self->new($s);
    }
  return $self->bone() if $x->is_zero();

  $self->new($x->_trailing_zeros());
  }

sub mantissa
  {
  # return the mantissa (compatible to Math::BigFloat, e.g. reduced)
  my ($self,$x) = ref($_[0]) ? (ref($_[0]),$_[0]) : objectify(1,@_);

  if ($x->{sign} !~ /^[+-]$/)
    {
    # for NaN, +inf, -inf: keep the sign
    return $self->new($x->{sign});
    }
  my $m = $x->copy(); delete $m->{_p}; delete $m->{_a};
  # that's a bit inefficient:
  my $zeros = $m->_trailing_zeros();
  $m->brsft($zeros,10) if $zeros != 0;
  $m;
  }

sub parts
  {
  # return a copy of both the exponent and the mantissa
  my ($self,$x) = ref($_[0]) ? (undef,$_[0]) : objectify(1,@_);

  ($x->mantissa(),$x->exponent());
  }
   
##############################################################################
# rounding functions

sub bfround
  {
  # precision: round to the $Nth digit left (+$n) or right (-$n) from the '.'
  # $n == 0 || $n == 1 => round to integer
  my $x = shift; $x = $class->new($x) unless ref $x;

  my ($scale,$mode) = $x->_scale_p($x->precision(),$x->round_mode(),@_);

  return $x if !defined $scale || $x->modify('bfround');	# no-op

  # no-op for BigInts if $n <= 0
  $x->bround( $x->length()-$scale, $mode) if $scale > 0;

  $x->{_a} = undef;				# bround sets {_a}
  $x->{_p} = $scale;				# so correct it
  $x;
  }

sub _scan_for_nonzero
  {
  # internal, used by bround()
  my ($x,$pad,$xs) = @_;
 
  my $len = $x->length();
  return 0 if $len == 1;		# '5' is trailed by invisible zeros
  my $follow = $pad - 1;
  return 0 if $follow > $len || $follow < 1;

  # since we do not know underlying represention of $x, use decimal string
  my $r = substr ("$x",-$follow);
  $r =~ /[^0]/ ? 1 : 0;
  }

sub fround
  {
  # Exists to make life easier for switch between MBF and MBI (should we
  # autoload fxxx() like MBF does for bxxx()?)
  my $x = shift;
  $x->bround(@_);
  }

sub bround
  {
  # accuracy: +$n preserve $n digits from left,
  #           -$n preserve $n digits from right (f.i. for 0.1234 style in MBF)
  # no-op for $n == 0
  # and overwrite the rest with 0's, return normalized number
  # do not return $x->bnorm(), but $x

  my $x = shift; $x = $class->new($x) unless ref $x;
  my ($scale,$mode) = $x->_scale_a($x->accuracy(),$x->round_mode(),@_);
  return $x if !defined $scale;			# no-op
  return $x if $x->modify('bround');
  
  if ($x->is_zero() || $scale == 0)
    {
    $x->{_a} = $scale if !defined $x->{_a} || $x->{_a} > $scale; # 3 > 2
    return $x;
    }
  return $x if $x->{sign} !~ /^[+-]$/;		# inf, NaN

  # we have fewer digits than we want to scale to
  my $len = $x->length();
  # convert $scale to a scalar in case it is an object (put's a limit on the
  # number length, but this would already limited by memory constraints), makes
  # it faster
  $scale = $scale->numify() if ref ($scale);

  # scale < 0, but > -len (not >=!)
  if (($scale < 0 && $scale < -$len-1) || ($scale >= $len))
    {
    $x->{_a} = $scale if !defined $x->{_a} || $x->{_a} > $scale; # 3 > 2
    return $x; 
    }
   
  # count of 0's to pad, from left (+) or right (-): 9 - +6 => 3, or |-6| => 6
  my ($pad,$digit_round,$digit_after);
  $pad = $len - $scale;
  $pad = abs($scale-1) if $scale < 0;

  # do not use digit(), it is costly for binary => decimal

  my $xs = $CALC->_str($x->{value});
  my $pl = -$pad-1;

  # pad:   123: 0 => -1, at 1 => -2, at 2 => -3, at 3 => -4
  # pad+1: 123: 0 => 0,  at 1 => -1, at 2 => -2, at 3 => -3
  $digit_round = '0'; $digit_round = substr($$xs,$pl,1) if $pad <= $len;
  $pl++; $pl ++ if $pad >= $len;
  $digit_after = '0'; $digit_after = substr($$xs,$pl,1) if $pad > 0;

  # in case of 01234 we round down, for 6789 up, and only in case 5 we look
  # closer at the remaining digits of the original $x, remember decision
  my $round_up = 1;					# default round up
  $round_up -- if
    ($mode eq 'trunc')				||	# trunc by round down
    ($digit_after =~ /[01234]/)			|| 	# round down anyway,
							# 6789 => round up
    ($digit_after eq '5')			&&	# not 5000...0000
    ($x->_scan_for_nonzero($pad,$xs) == 0)		&&
    (
     ($mode eq 'even') && ($digit_round =~ /[24680]/) ||
     ($mode eq 'odd')  && ($digit_round =~ /[13579]/) ||
     ($mode eq '+inf') && ($x->{sign} eq '-')   ||
     ($mode eq '-inf') && ($x->{sign} eq '+')   ||
     ($mode eq 'zero')		# round down if zero, sign adjusted below
    );
  my $put_back = 0;					# not yet modified
	
  if (($pad > 0) && ($pad <= $len))
    {
    substr($$xs,-$pad,$pad) = '0' x $pad;
    $put_back = 1;
    }
  elsif ($pad > $len)
    {
    $x->bzero();					# round to '0'
    }

  if ($round_up)					# what gave test above?
    {
    $put_back = 1;
    $pad = $len, $$xs = '0' x $pad if $scale < 0;	# tlr: whack 0.51=>1.0	

    # we modify directly the string variant instead of creating a number and
    # adding it, since that is faster (we already have the string)
    my $c = 0; $pad ++;				# for $pad == $len case
    while ($pad <= $len)
      {
      $c = substr($$xs,-$pad,1) + 1; $c = '0' if $c eq '10';
      substr($$xs,-$pad,1) = $c; $pad++;
      last if $c != 0;				# no overflow => early out
      }
    $$xs = '1'.$$xs if $c == 0;

    }
  $x->{value} = $CALC->_new($xs) if $put_back == 1;	# put back in if needed

  $x->{_a} = $scale if $scale >= 0;
  if ($scale < 0)
    {
    $x->{_a} = $len+$scale;
    $x->{_a} = 0 if $scale < -$len;
    }
  $x;
  }

sub bfloor
  {
  # return integer less or equal then number; no-op since it's already integer
  my ($self,$x,@r) = ref($_[0]) ? (undef,@_) : objectify(1,@_);

  $x->round(@r);
  }

sub bceil
  {
  # return integer greater or equal then number; no-op since it's already int
  my ($self,$x,@r) = ref($_[0]) ? (undef,@_) : objectify(1,@_);

  $x->round(@r);
  }

sub as_number
  {
  # An object might be asked to return itself as bigint on certain overloaded
  # operations, this does exactly this, so that sub classes can simple inherit
  # it or override with their own integer conversion routine.
  $_[0]->copy();
  }

sub as_hex
  {
  # return as hex string, with prefixed 0x
  my $x = shift; $x = $class->new($x) if !ref($x);

  return $x->bstr() if $x->{sign} !~ /^[+-]$/;	# inf, nan etc

  my $s = '';
  $s = $x->{sign} if $x->{sign} eq '-';
  if ($CAN{as_hex})
    {
    return $s . ${$CALC->_as_hex($x->{value})};
    }

  require $EMU_LIB;
  __emu_as_hex(ref($x),$x,$s);
  }

sub as_bin
  {
  # return as binary string, with prefixed 0b
  my $x = shift; $x = $class->new($x) if !ref($x);

  return $x->bstr() if $x->{sign} !~ /^[+-]$/;	# inf, nan etc

  my $s = ''; $s = $x->{sign} if $x->{sign} eq '-';
  if ($CAN{as_bin})
    {
    return $s . ${$CALC->_as_bin($x->{value})};
    }

  require $EMU_LIB;
  __emu_as_bin(ref($x),$x,$s);

  }

##############################################################################
# private stuff (internal use only)

sub objectify
  {
  # check for strings, if yes, return objects instead
 
  # the first argument is number of args objectify() should look at it will
  # return $count+1 elements, the first will be a classname. This is because
  # overloaded '""' calls bstr($object,undef,undef) and this would result in
  # useless objects beeing created and thrown away. So we cannot simple loop
  # over @_. If the given count is 0, all arguments will be used.
 
  # If the second arg is a ref, use it as class.
  # If not, try to use it as classname, unless undef, then use $class 
  # (aka Math::BigInt). The latter shouldn't happen,though.

  # caller:			   gives us:
  # $x->badd(1);                => ref x, scalar y
  # Class->badd(1,2);           => classname x (scalar), scalar x, scalar y
  # Class->badd( Class->(1),2); => classname x (scalar), ref x, scalar y
  # Math::BigInt::badd(1,2);    => scalar x, scalar y
  # In the last case we check number of arguments to turn it silently into
  # $class,1,2. (We can not take '1' as class ;o)
  # badd($class,1) is not supported (it should, eventually, try to add undef)
  # currently it tries 'Math::BigInt' + 1, which will not work.

  # some shortcut for the common cases
  # $x->unary_op();
  return (ref($_[1]),$_[1]) if (@_ == 2) && ($_[0]||0 == 1) && ref($_[1]);

  my $count = abs(shift || 0);
  
  my (@a,$k,$d);		# resulting array, temp, and downgrade 
  if (ref $_[0])
    {
    # okay, got object as first
    $a[0] = ref $_[0];
    }
  else
    {
    # nope, got 1,2 (Class->xxx(1) => Class,1 and not supported)
    $a[0] = $class;
    $a[0] = shift if $_[0] =~ /^[A-Z].*::/;	# classname as first?
    }

  no strict 'refs';
  # disable downgrading, because Math::BigFLoat->foo('1.0','2.0') needs floats
  if (defined ${"$a[0]::downgrade"})
    {
    $d = ${"$a[0]::downgrade"};
    ${"$a[0]::downgrade"} = undef;
    }

  my $up = ${"$a[0]::upgrade"};
  #print "Now in objectify, my class is today $a[0], count = $count\n";
  if ($count == 0)
    {
    while (@_)
      {
      $k = shift;
      if (!ref($k))
        {
        $k = $a[0]->new($k);
        }
      elsif (!defined $up && ref($k) ne $a[0])
	{
	# foreign object, try to convert to integer
        $k->can('as_number') ?  $k = $k->as_number() : $k = $a[0]->new($k);
	}
      push @a,$k;
      }
    }
  else
    {
    while ($count > 0)
      {
      $count--; 
      $k = shift; 
      if (!ref($k))
        {
        $k = $a[0]->new($k);
        }
      elsif (!defined $up && ref($k) ne $a[0])
	{
	# foreign object, try to convert to integer
        $k->can('as_number') ?  $k = $k->as_number() : $k = $a[0]->new($k);
	}
      push @a,$k;
      }
    push @a,@_;		# return other params, too
    }
  if (! wantarray)
    {
    require Carp; Carp::croak ("$class objectify needs list context");
    }
  ${"$a[0]::downgrade"} = $d;
  @a;
  }

sub import 
  {
  my $self = shift;

  $IMPORT++;				# remember we did import()
  my @a; my $l = scalar @_;
  for ( my $i = 0; $i < $l ; $i++ )
    {
    if ($_[$i] eq ':constant')
      {
      # this causes overlord er load to step in
      overload::constant 
	integer => sub { $self->new(shift) },
      	binary => sub { $self->new(shift) };
      }
    elsif ($_[$i] eq 'upgrade')
      {
      # this causes upgrading
      $upgrade = $_[$i+1];		# or undef to disable
      $i++;
      }
    elsif ($_[$i] =~ /^lib$/i)
      {
      # this causes a different low lib to take care...
      $CALC = $_[$i+1] || '';
      $i++;
      }
    else
      {
      push @a, $_[$i];
      }
    }
  # any non :constant stuff is handled by our parent, Exporter
  # even if @_ is empty, to give it a chance 
  $self->SUPER::import(@a);			# need it for subclasses
  $self->export_to_level(1,$self,@a);		# need it for MBF

  # try to load core math lib
  my @c = split /\s*,\s*/,$CALC;
  push @c,'Calc';				# if all fail, try this
  $CALC = '';					# signal error
  foreach my $lib (@c)
    {
    next if ($lib || '') eq '';
    $lib = 'Math::BigInt::'.$lib if $lib !~ /^Math::BigInt/i;
    $lib =~ s/\.pm$//;
    if ($] < 5.006)
      {
      # Perl < 5.6.0 dies with "out of memory!" when eval() and ':constant' is
      # used in the same script, or eval inside import().
      my @parts = split /::/, $lib;             # Math::BigInt => Math BigInt
      my $file = pop @parts; $file .= '.pm';    # BigInt => BigInt.pm
      require File::Spec;
      $file = File::Spec->catfile (@parts, $file);
      eval { require "$file"; $lib->import( @c ); }
      }
    else
      {
      eval "use $lib qw/@c/;";
      }
    $CALC = $lib, last if $@ eq '';	# no error in loading lib?
    }
  if ($CALC eq '')
    {
    require Carp;
    Carp::croak ("Couldn't load any math lib, not even 'Calc.pm'");
    }
  _fill_can_cache();
  }

sub _fill_can_cache
  {
  # fill $CAN with the results of $CALC->can(...)

  %CAN = ();
  for my $method (qw/gcd mod modinv modpow fac pow lsft rsft 
	and signed_and or signed_or xor signed_xor
	from_hex as_hex from_bin as_bin
	zeros sqrt root log_int log
	/)
    {
    $CAN{$method} = $CALC->can("_$method") ? 1 : 0;
    }
  }

sub __from_hex
  {
  # convert a (ref to) big hex string to BigInt, return undef for error
  my $hs = shift;

  my $x = Math::BigInt->bzero();
  
  # strip underscores
  $$hs =~ s/([0-9a-fA-F])_([0-9a-fA-F])/$1$2/g;	
  $$hs =~ s/([0-9a-fA-F])_([0-9a-fA-F])/$1$2/g;	
  
  return $x->bnan() if $$hs !~ /^[\-\+]?0x[0-9A-Fa-f]+$/;

  my $sign = '+'; $sign = '-' if ($$hs =~ /^-/);

  $$hs =~ s/^[+-]//;			# strip sign
  if ($CAN{'from_hex'})
    {
    $x->{value} = $CALC->_from_hex($hs);
    }
  else
    {
    # fallback to pure perl
    my $mul = Math::BigInt->bone();
    my $x65536 = Math::BigInt->new(65536);
    my $len = CORE::length($$hs)-2;		# minus 2 for 0x
    $len = int($len/4);				# 4-digit parts, w/o '0x'
    my $val; my $i = -4;
    while ($len >= 0)
      {
      $val = substr($$hs,$i,4);
      $val =~ s/^[+-]?0x// if $len == 0;	# for last part only because
      $val = hex($val); 			# hex does not like wrong chars
      $i -= 4; $len --;
      $x += $mul * $val if $val != 0;
      $mul *= $x65536 if $len >= 0;		# skip last mul
      }
    }
  $x->{sign} = $sign unless $CALC->_is_zero($x->{value}); 	# no '-0'
  $x;
  }

sub __from_bin
  {
  # convert a (ref to) big binary string to BigInt, return undef for error
  my $bs = shift;

  my $x = Math::BigInt->bzero();
  # strip underscores
  $$bs =~ s/([01])_([01])/$1$2/g;	
  $$bs =~ s/([01])_([01])/$1$2/g;	
  return $x->bnan() if $$bs !~ /^[+-]?0b[01]+$/;

  my $sign = '+'; $sign = '-' if ($$bs =~ /^\-/);
  $$bs =~ s/^[+-]//;				# strip sign
  if ($CAN{'from_bin'})
    {
    $x->{value} = $CALC->_from_bin($bs);
    }
  else
    {
    my $mul = Math::BigInt->bone();
    my $x256 = Math::BigInt->new(256);
    my $len = CORE::length($$bs)-2;		# minus 2 for 0b
    $len = int($len/8);				# 8-digit parts, w/o '0b'
    my $val; my $i = -8;
    while ($len >= 0)
      {
      $val = substr($$bs,$i,8);
      $val =~ s/^[+-]?0b// if $len == 0;	# for last part only
      #$val = oct('0b'.$val);	# does not work on Perl prior to 5.6.0
      # slower:
      # $val = ('0' x (8-CORE::length($val))).$val if CORE::length($val) < 8;
      $val = ord(pack('B8',substr('00000000'.$val,-8,8)));
      $i -= 8; $len --;
      $x += $mul * $val if $val != 0;
      $mul *= $x256 if $len >= 0;		# skip last mul
      }
    }
  $x->{sign} = $sign unless $CALC->_is_zero($x->{value}); 	# no '-0'
  $x;
  }

sub _split
  {
  # (ref to num_str) return num_str
  # internal, take apart a string and return the pieces
  # strip leading/trailing whitespace, leading zeros, underscore and reject
  # invalid input
  my $x = shift;

  # strip white space at front, also extranous leading zeros
  $$x =~ s/^\s*([-]?)0*([0-9])/$1$2/g;	# will not strip '  .2'
  $$x =~ s/^\s+//;			# but this will			
  $$x =~ s/\s+$//g;			# strip white space at end

  # shortcut, if nothing to split, return early
  if ($$x =~ /^[+-]?\d+\z/)
    {
    $$x =~ s/^([+-])0*([0-9])/$2/; my $sign = $1 || '+';
    return (\$sign, $x, \'', \'', \0);
    }

  # invalid starting char?
  return if $$x !~ /^[+-]?(\.?[0-9]|0b[0-1]|0x[0-9a-fA-F])/;

  return __from_hex($x) if $$x =~ /^[\-\+]?0x/;	# hex string
  return __from_bin($x) if $$x =~ /^[\-\+]?0b/;	# binary string
  
  # strip underscores between digits
  $$x =~ s/(\d)_(\d)/$1$2/g;
  $$x =~ s/(\d)_(\d)/$1$2/g;		# do twice for 1_2_3

  # some possible inputs: 
  # 2.1234 # 0.12        # 1 	      # 1E1 # 2.134E1 # 434E-10 # 1.02009E-2 
  # .2 	   # 1_2_3.4_5_6 # 1.4E1_2_3  # 1e3 # +.2     # 0e999	

  #return if $$x =~ /[Ee].*[Ee]/;	# more than one E => error

  my ($m,$e,$last) = split /[Ee]/,$$x;
  return if defined $last;		# last defined => 1e2E3 or others
  $e = '0' if !defined $e || $e eq "";

  # sign,value for exponent,mantint,mantfrac
  my ($es,$ev,$mis,$miv,$mfv);
  # valid exponent?
  if ($e =~ /^([+-]?)0*(\d+)$/) # strip leading zeros
    {
    $es = $1; $ev = $2;
    # valid mantissa?
    return if $m eq '.' || $m eq '';
    my ($mi,$mf,$lastf) = split /\./,$m;
    return if defined $lastf;		# lastf defined => 1.2.3 or others
    $mi = '0' if !defined $mi;
    $mi .= '0' if $mi =~ /^[\-\+]?$/;
    $mf = '0' if !defined $mf || $mf eq '';
    if ($mi =~ /^([+-]?)0*(\d+)$/) # strip leading zeros
      {
      $mis = $1||'+'; $miv = $2;
      return unless ($mf =~ /^(\d*?)0*$/);	# strip trailing zeros
      $mfv = $1;
      # handle the 0e999 case here
      $ev = 0 if $miv eq '0' && $mfv eq '';
      return (\$mis,\$miv,\$mfv,\$es,\$ev);
      }
    }
  return; # NaN, not a number
  }

##############################################################################
# internal calculation routines (others are in Math::BigInt::Calc etc)

sub __lcm 
  { 
  # (BINT or num_str, BINT or num_str) return BINT
  # does modify first argument
  # LCM
 
  my $x = shift; my $ty = shift;
  return $x->bnan() if ($x->{sign} eq $nan) || ($ty->{sign} eq $nan);
  return $x * $ty / bgcd($x,$ty);
  }

sub __gcd
  { 
  # (BINT or num_str, BINT or num_str) return BINT
  # does modify both arguments
  # GCD -- Euclids algorithm E, Knuth Vol 2 pg 296
  my ($x,$ty) = @_;

  return $x->bnan() if $x->{sign} !~ /^[+-]$/ || $ty->{sign} !~ /^[+-]$/;

  while (!$ty->is_zero())
    {
    ($x, $ty) = ($ty,bmod($x,$ty));
    }
  $x;
  }

###############################################################################
# this method return 0 if the object can be modified, or 1 for not
# We use a fast constant sub() here, to avoid costly calls. Subclasses
# may override it with special code (f.i. Math::BigInt::Constant does so)

sub modify () { 0; }

1;
__END__

