# -*- mode: perl; perl-indent-level: 2; -*-
# Memoize.pm
#
# Transparent memoization of idempotent functions
#
# Copyright 1998, 1999, 2000, 2001 M-J. Dominus.
# You may copy and distribute this program under the
# same terms as Perl itself.  If in doubt, 
# write to mjd-perl-memoize+@plover.com for a license.
#
# Version 1.01 $Revision: 1.18 $ $Date: 2001/06/24 17:16:47 $

package Memoize;
$VERSION = '1.01';

# Compile-time constants
sub SCALAR () { 0 } 
sub LIST () { 1 } 


#
# Usage memoize(functionname/ref,
#               { NORMALIZER => coderef, INSTALL => name,
#                 LIST_CACHE => descriptor, SCALAR_CACHE => descriptor }
#

use Carp;
use Exporter;
use vars qw($DEBUG);
use Config;                     # Dammit.
@ISA = qw(Exporter);
@EXPORT = qw(memoize);
@EXPORT_OK = qw(unmemoize flush_cache);
use strict;

my %memotable;
my %revmemotable;
my @CONTEXT_TAGS = qw(MERGE TIE MEMORY FAULT HASH);
my %IS_CACHE_TAG = map {($_ => 1)} @CONTEXT_TAGS;

# Raise an error if the user tries to specify one of thesepackage as a
# tie for LIST_CACHE

my %scalar_only = map {($_ => 1)} qw(DB_File GDBM_File SDBM_File ODBM_File NDBM_File);

sub memoize {
  my $fn = shift;
  my %options = @_;
  my $options = \%options;
  
  unless (defined($fn) && 
	  (ref $fn eq 'CODE' || ref $fn eq '')) {
    croak "Usage: memoize 'functionname'|coderef {OPTIONS}";
  }

  my $uppack = caller;		# TCL me Elmo!
  my $cref;			# Code reference to original function
  my $name = (ref $fn ? undef : $fn);

  # Convert function names to code references
  $cref = &_make_cref($fn, $uppack);

  # Locate function prototype, if any
  my $proto = prototype $cref;
  if (defined $proto) { $proto = "($proto)" }
  else { $proto = "" }

  # I would like to get rid of the eval, but there seems not to be any
  # other way to set the prototype properly.  The switch here for
  # 'usethreads' works around a bug in threadperl having to do with
  # magic goto.  It would be better to fix the bug and use the magic
  # goto version everywhere.
  my $wrapper = 
      $Config{usethreads} 
        ? eval "sub $proto { &_memoizer(\$cref, \@_); }" 
        : eval "sub $proto { unshift \@_, \$cref; goto &_memoizer; }";

  my $normalizer = $options{NORMALIZER};
  if (defined $normalizer  && ! ref $normalizer) {
    $normalizer = _make_cref($normalizer, $uppack);
  }
  
  my $install_name;
  if (defined $options->{INSTALL}) {
    # INSTALL => name
    $install_name = $options->{INSTALL};
  } elsif (! exists $options->{INSTALL}) {
    # No INSTALL option provided; use original name if possible
    $install_name = $name;
  } else {
    # INSTALL => undef  means don't install
  }

  if (defined $install_name) {
    $install_name = $uppack . '::' . $install_name
	unless $install_name =~ /::/;
    no strict;
    local($^W) = 0;	       # ``Subroutine $install_name redefined at ...''
    *{$install_name} = $wrapper; # Install memoized version
  }

  $revmemotable{$wrapper} = "" . $cref; # Turn code ref into hash key

  # These will be the caches
  my %caches;
  for my $context (qw(SCALAR LIST)) {
    # suppress subsequent 'uninitialized value' warnings
    $options{"${context}_CACHE"} ||= ''; 

    my $cache_opt = $options{"${context}_CACHE"};
    my @cache_opt_args;
    if (ref $cache_opt) {
      @cache_opt_args = @$cache_opt;
      $cache_opt = shift @cache_opt_args;
    }
    if ($cache_opt eq 'FAULT') { # no cache
      $caches{$context} = undef;
    } elsif ($cache_opt eq 'HASH') { # user-supplied hash
      my $cache = $cache_opt_args[0];
      my $package = ref(tied %$cache);
      if ($context eq 'LIST' && $scalar_only{$package}) {
        croak("You can't use $package for LIST_CACHE because it can only store scalars");
      }
      $caches{$context} = $cache;
    } elsif ($cache_opt eq '' ||  $IS_CACHE_TAG{$cache_opt}) {
      # default is that we make up an in-memory hash
      $caches{$context} = {};
      # (this might get tied later, or MERGEd away)
    } else {
      croak "Unrecognized option to `${context}_CACHE': `$cache_opt' should be one of (@CONTEXT_TAGS); aborting";
    }
  }

  # Perhaps I should check here that you didn't supply *both* merge
  # options.  But if you did, it does do something reasonable: They
  # both get merged to the same in-memory hash.
  if ($options{SCALAR_CACHE} eq 'MERGE') {
    $caches{SCALAR} = $caches{LIST};
  } elsif ($options{LIST_CACHE} eq 'MERGE') {
    $caches{LIST} = $caches{SCALAR};
  }

  # Now deal with the TIE options
  {
    my $context;
    foreach $context (qw(SCALAR LIST)) {
      # If the relevant option wasn't `TIE', this call does nothing.
      _my_tie($context, $caches{$context}, $options);  # Croaks on failure
    }
  }
  
  # We should put some more stuff in here eventually.
  # We've been saying that for serveral versions now.
  # And you know what?  More stuff keeps going in!
  $memotable{$cref} = 
  {
    O => $options,  # Short keys here for things we need to access frequently
    N => $normalizer,
    U => $cref,
    MEMOIZED => $wrapper,
    PACKAGE => $uppack,
    NAME => $install_name,
    S => $caches{SCALAR},
    L => $caches{LIST},
  };

  $wrapper			# Return just memoized version
}

# This function tries to load a tied hash class and tie the hash to it.
sub _my_tie {
  my ($context, $hash, $options) = @_;
  my $fullopt = $options->{"${context}_CACHE"};

  # We already checked to make sure that this works.
  my $shortopt = (ref $fullopt) ? $fullopt->[0] : $fullopt;
  
  return unless defined $shortopt && $shortopt eq 'TIE';
  carp("TIE option to memoize() is deprecated; use HASH instead")
      if $^W;

  my @args = ref $fullopt ? @$fullopt : ();
  shift @args;
  my $module = shift @args;
  if ($context eq 'LIST' && $scalar_only{$module}) {
    croak("You can't use $module for LIST_CACHE because it can only store scalars");
  }
  my $modulefile = $module . '.pm';
  $modulefile =~ s{::}{/}g;
  eval { require $modulefile };
  if ($@) {
    croak "Memoize: Couldn't load hash tie module `$module': $@; aborting";
  }
  my $rc = (tie %$hash => $module, @args);
  unless ($rc) {
    croak "Memoize: Couldn't tie hash to `$module': $!; aborting";
  }
  1;
}

sub flush_cache {
  my $func = _make_cref($_[0], scalar caller);
  my $info = $memotable{$revmemotable{$func}};
  die "$func not memoized" unless defined $info;
  for my $context (qw(S L)) {
    my $cache = $info->{$context};
    if (tied %$cache && ! (tied %$cache)->can('CLEAR')) {
      my $funcname = defined($info->{NAME}) ? 
          "function $info->{NAME}" : "anonymous function $func";
      my $context = {S => 'scalar', L => 'list'}->{$context};
      croak "Tied cache hash for $context-context $funcname does not support flushing";
    } else {
      %$cache = ();
    }
  }
}

# This is the function that manages the memo tables.
sub _memoizer {
  my $orig = shift;		# stringized version of ref to original func.
  my $info = $memotable{$orig};
  my $normalizer = $info->{N};
  
  my $argstr;
  my $context = (wantarray() ? LIST : SCALAR);

  if (defined $normalizer) { 
    no strict;
    if ($context == SCALAR) {
      $argstr = &{$normalizer}(@_);
    } elsif ($context == LIST) {
      ($argstr) = &{$normalizer}(@_);
    } else {
      croak "Internal error \#41; context was neither LIST nor SCALAR\n";
    }
  } else {                      # Default normalizer
    local $^W = 0;
    $argstr = join chr(28),@_;  
  }

  if ($context == SCALAR) {
    my $cache = $info->{S};
    _crap_out($info->{NAME}, 'scalar') unless $cache;
    if (exists $cache->{$argstr}) { 
      return $cache->{$argstr};
    } else {
      my $val = &{$info->{U}}(@_);
      # Scalars are considered to be lists; store appropriately
      if ($info->{O}{SCALAR_CACHE} eq 'MERGE') {
	$cache->{$argstr} = [$val];
      } else {
	$cache->{$argstr} = $val;
      }
      $val;
    }
  } elsif ($context == LIST) {
    my $cache = $info->{L};
    _crap_out($info->{NAME}, 'list') unless $cache;
    if (exists $cache->{$argstr}) {
      my $val = $cache->{$argstr};
      # If LISTCONTEXT=>MERGE, then the function never returns lists,
      # so we have a scalar value cached, so just return it straightaway:
      return ($val) if $info->{O}{LIST_CACHE} eq 'MERGE';
      # Maybe in a later version we can use a faster test.

      # Otherwise, we cached an array containing the returned list:
      return @$val;
    } else {
      my $q = $cache->{$argstr} = [&{$info->{U}}(@_)];
      @$q;
    }
  } else {
    croak "Internal error \#42; context was neither LIST nor SCALAR\n";
  }
}

sub unmemoize {
  my $f = shift;
  my $uppack = caller;
  my $cref = _make_cref($f, $uppack);

  unless (exists $revmemotable{$cref}) {
    croak "Could not unmemoize function `$f', because it was not memoized to begin with";
  }
  
  my $tabent = $memotable{$revmemotable{$cref}};
  unless (defined $tabent) {
    croak "Could not figure out how to unmemoize function `$f'";
  }
  my $name = $tabent->{NAME};
  if (defined $name) {
    no strict;
    local($^W) = 0;	       # ``Subroutine $install_name redefined at ...''
    *{$name} = $tabent->{U}; # Replace with original function
  }
  undef $memotable{$revmemotable{$cref}};
  undef $revmemotable{$cref};

  # This removes the last reference to the (possibly tied) memo tables
  # my ($old_function, $memotabs) = @{$tabent}{'U','S','L'};
  # undef $tabent; 

#  # Untie the memo tables if they were tied.
#  my $i;
#  for $i (0,1) {
#    if (tied %{$memotabs->[$i]}) {
#      warn "Untying hash #$i\n";
#      untie %{$memotabs->[$i]};
#    }
#  }

  $tabent->{U};
}

sub _make_cref {
  my $fn = shift;
  my $uppack = shift;
  my $cref;
  my $name;

  if (ref $fn eq 'CODE') {
    $cref = $fn;
  } elsif (! ref $fn) {
    if ($fn =~ /::/) {
      $name = $fn;
    } else {
      $name = $uppack . '::' . $fn;
    }
    no strict;
    if (defined $name and !defined(&$name)) {
      croak "Cannot operate on nonexistent function `$fn'";
    }
#    $cref = \&$name;
    $cref = *{$name}{CODE};
  } else {
    my $parent = (caller(1))[3]; # Function that called _make_cref
    croak "Usage: argument 1 to `$parent' must be a function name or reference.\n";
  }
  $DEBUG and warn "${name}($fn) => $cref in _make_cref\n";
  $cref;
}

sub _crap_out {
  my ($funcname, $context) = @_;
  if (defined $funcname) {
    croak "Function `$funcname' called in forbidden $context context; faulting";
  } else {
    croak "Anonymous function called in forbidden $context context; faulting";
  }
}

1;





