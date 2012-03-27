use strict;

package Term::ReadLine::Stub;
our @ISA = qw'Term::ReadLine::Tk Term::ReadLine::TermCap';

$DB::emacs = $DB::emacs;	# To peacify -w
our @rl_term_set;
*rl_term_set = \@Term::ReadLine::TermCap::rl_term_set;

sub PERL_UNICODE_STDIN () { 0x0001 }

sub ReadLine {'Term::ReadLine::Stub'}
sub readline {
  my $self = shift;
  my ($in,$out,$str) = @$self;
  my $prompt = shift;
  print $out $rl_term_set[0], $prompt, $rl_term_set[1], $rl_term_set[2]; 
  $self->register_Tk 
     if not $Term::ReadLine::registered and $Term::ReadLine::toloop
	and defined &Tk::DoOneEvent;
  #$str = scalar <$in>;
  $str = $self->get_line;
  $str =~ s/^\s*\Q$prompt\E// if ($^O eq 'MacOS');
  utf8::upgrade($str)
      if (${^UNICODE} & PERL_UNICODE_STDIN || defined ${^ENCODING}) &&
         utf8::valid($str);
  print $out $rl_term_set[3]; 
  # bug in 5.000: chomping empty string creats length -1:
  chomp $str if defined $str;
  $str;
}
sub addhistory {}

sub findConsole {
    my $console;

    if ($^O eq 'MacOS') {
        $console = "Dev:Console";
    } elsif (-e "/dev/tty") {
	$console = "/dev/tty";
    } elsif (-e "con" or $^O eq 'MSWin32') {
	$console = "con";
    } else {
	$console = "sys\$command";
    }

    if (($^O eq 'amigaos') || ($^O eq 'beos') || ($^O eq 'epoc')) {
	$console = undef;
    }
    elsif ($^O eq 'os2') {
      if ($DB::emacs) {
	$console = undef;
      } else {
	$console = "/dev/con";
      }
    }

    my $consoleOUT = $console;
    $console = "&STDIN" unless defined $console;
    if (!defined $consoleOUT) {
      $consoleOUT = defined fileno(STDERR) ? "&STDERR" : "&STDOUT";
    }
    ($console,$consoleOUT);
}

sub new {
  die "method new called with wrong number of arguments" 
    unless @_==2 or @_==4;
  #local (*FIN, *FOUT);
  my ($FIN, $FOUT, $ret);
  if (@_==2) {
    my($console, $consoleOUT) = $_[0]->findConsole;

    open(FIN, "<$console"); 
    open(FOUT,">$consoleOUT");
    #OUT->autoflush(1);		# Conflicts with debugger?
    my $sel = select(FOUT);
    $| = 1;				# for DB::OUT
    select($sel);
    $ret = bless [\*FIN, \*FOUT];
  } else {			# Filehandles supplied
    $FIN = $_[2]; $FOUT = $_[3];
    #OUT->autoflush(1);		# Conflicts with debugger?
    my $sel = select($FOUT);
    $| = 1;				# for DB::OUT
    select($sel);
    $ret = bless [$FIN, $FOUT];
  }
  if ($ret->Features->{ornaments} 
      and not ($ENV{PERL_RL} and $ENV{PERL_RL} =~ /\bo\w*=0/)) {
    local $Term::ReadLine::termcap_nowarn = 1;
    $ret->ornaments(1);
  }
  return $ret;
}

sub newTTY {
  my ($self, $in, $out) = @_;
  $self->[0] = $in;
  $self->[1] = $out;
  my $sel = select($out);
  $| = 1;				# for DB::OUT
  select($sel);
}

sub IN { shift->[0] }
sub OUT { shift->[1] }
sub MinLine { undef }
sub Attribs { {} }

my %features = (tkRunning => 1, ornaments => 1, 'newTTY' => 1);
sub Features { \%features }

package Term::ReadLine;		# So late to allow the above code be defined?

our $VERSION = '1.01';

my ($which) = exists $ENV{PERL_RL} ? split /\s+/, $ENV{PERL_RL} : undef;
if ($which) {
  if ($which =~ /\bgnu\b/i){
    eval "use Term::ReadLine::Gnu;";
  } elsif ($which =~ /\bperl\b/i) {
    eval "use Term::ReadLine::Perl;";
  } else {
    eval "use Term::ReadLine::$which;";
  }
} elsif (defined $which and $which ne '') {	# Defined but false
  # Do nothing fancy
} else {
  eval "use Term::ReadLine::Gnu; 1" or eval "use Term::ReadLine::Perl; 1";
}

#require FileHandle;

# To make possible switch off RL in debugger: (Not needed, work done
# in debugger).
our @ISA;
if (defined &Term::ReadLine::Gnu::readline) {
  @ISA = qw(Term::ReadLine::Gnu Term::ReadLine::Stub);
} elsif (defined &Term::ReadLine::Perl::readline) {
  @ISA = qw(Term::ReadLine::Perl Term::ReadLine::Stub);
} elsif (defined $which && defined &{"Term::ReadLine::$which\::readline"}) {
  @ISA = "Term::ReadLine::$which";
} else {
  @ISA = qw(Term::ReadLine::Stub);
}

package Term::ReadLine::TermCap;

# Prompt-start, prompt-end, command-line-start, command-line-end
#     -- zero-width beautifies to emit around prompt and the command line.
our @rl_term_set = ("","","","");
# string encoded:
our $rl_term_set = ',,,';

our $terminal;
sub LoadTermCap {
  return if defined $terminal;
  
  require Term::Cap;
  $terminal = Tgetent Term::Cap ({OSPEED => 9600}); # Avoid warning.
}

sub ornaments {
  shift;
  return $rl_term_set unless @_;
  $rl_term_set = shift;
  $rl_term_set ||= ',,,';
  $rl_term_set = 'us,ue,md,me' if $rl_term_set eq '1';
  my @ts = split /,/, $rl_term_set, 4;
  eval { LoadTermCap };
  unless (defined $terminal) {
    warn("Cannot find termcap: $@\n") unless $Term::ReadLine::termcap_nowarn;
    $rl_term_set = ',,,';
    return;
  }
  @rl_term_set = map {$_ ? $terminal->Tputs($_,1) || '' : ''} @ts;
  return $rl_term_set;
}


package Term::ReadLine::Tk;

our($count_handle, $count_DoOne, $count_loop);
$count_handle = $count_DoOne = $count_loop = 0;

our($giveup);
sub handle {$giveup = 1; $count_handle++}

sub Tk_loop {
  # Tk->tkwait('variable',\$giveup);	# needs Widget
  $count_DoOne++, Tk::DoOneEvent(0) until $giveup;
  $count_loop++;
  $giveup = 0;
}

sub register_Tk {
  my $self = shift;
  $Term::ReadLine::registered++ 
    or Tk->fileevent($self->IN,'readable',\&handle);
}

sub tkRunning {
  $Term::ReadLine::toloop = $_[1] if @_ > 1;
  $Term::ReadLine::toloop;
}

sub get_c {
  my $self = shift;
  $self->Tk_loop if $Term::ReadLine::toloop && defined &Tk::DoOneEvent;
  return getc $self->IN;
}

sub get_line {
  my $self = shift;
  $self->Tk_loop if $Term::ReadLine::toloop && defined &Tk::DoOneEvent;
  my $in = $self->IN;
  local ($/) = "\n";
  return scalar <$in>;
}

1;

