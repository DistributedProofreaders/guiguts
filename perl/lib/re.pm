package re;

our $VERSION = 0.04;

# N.B. File::Basename contains a literal for 'taint' as a fallback.  If
# taint is changed here, File::Basename must be updated as well.
my %bitmask = (
taint		=> 0x00100000, # HINT_RE_TAINT
eval		=> 0x00200000, # HINT_RE_EVAL
);

sub setcolor {
 eval {				# Ignore errors
  require Term::Cap;

  my $terminal = Tgetent Term::Cap ({OSPEED => 9600}); # Avoid warning.
  my $props = $ENV{PERL_RE_TC} || 'md,me,so,se,us,ue';
  my @props = split /,/, $props;
  my $colors = join "\t", map {$terminal->Tputs($_,1)} @props;

  $colors =~ s/\0//g;
  $ENV{PERL_RE_COLORS} = $colors;
 };
}

sub bits {
    my $on = shift;
    my $bits = 0;
    unless (@_) {
	require Carp;
	Carp::carp("Useless use of \"re\" pragma");
    }
    foreach my $s (@_){
      if ($s eq 'debug' or $s eq 'debugcolor') {
 	  setcolor() if $s eq 'debugcolor';
	  require XSLoader;
	  XSLoader::load('re');
	  install() if $on;
	  uninstall() unless $on;
	  next;
      }
      if (exists $bitmask{$s}) {
	  $bits |= $bitmask{$s};
      } else {
	  require Carp;
	  Carp::carp("Unknown \"re\" subpragma '$s' (known ones are: @{[join(', ', map {qq('$_')} 'debug', 'debugcolor', sort keys %bitmask)]})");
      }
    }
    $bits;
}

sub import {
    shift;
    $^H |= bits(1, @_);
}

sub unimport {
    shift;
    $^H &= ~ bits(0, @_);
}

1;
