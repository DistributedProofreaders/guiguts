package Tie::Handle;

use 5.006_001;
our $VERSION = '4.1';

use Carp;
use warnings::register;

sub new {
    my $pkg = shift;
    $pkg->TIEHANDLE(@_);
}

# "Grandfather" the new, a la Tie::Hash

sub TIEHANDLE {
    my $pkg = shift;
    if (defined &{"{$pkg}::new"}) {
	warnings::warnif("WARNING: calling ${pkg}->new since ${pkg}->TIEHANDLE is missing");
	$pkg->new(@_);
    }
    else {
	croak "$pkg doesn't define a TIEHANDLE method";
    }
}

sub PRINT {
    my $self = shift;
    if($self->can('WRITE') != \&WRITE) {
	my $buf = join(defined $, ? $, : "",@_);
	$buf .= $\ if defined $\;
	$self->WRITE($buf,length($buf),0);
    }
    else {
	croak ref($self)," doesn't define a PRINT method";
    }
}

sub PRINTF {
    my $self = shift;
    
    if($self->can('WRITE') != \&WRITE) {
	my $buf = sprintf(shift,@_);
	$self->WRITE($buf,length($buf),0);
    }
    else {
	croak ref($self)," doesn't define a PRINTF method";
    }
}

sub READLINE {
    my $pkg = ref $_[0];
    croak "$pkg doesn't define a READLINE method";
}

sub GETC {
    my $self = shift;
    
    if($self->can('READ') != \&READ) {
	my $buf;
	$self->READ($buf,1);
	return $buf;
    }
    else {
	croak ref($self)," doesn't define a GETC method";
    }
}

sub READ {
    my $pkg = ref $_[0];
    croak "$pkg doesn't define a READ method";
}

sub WRITE {
    my $pkg = ref $_[0];
    croak "$pkg doesn't define a WRITE method";
}

sub CLOSE {
    my $pkg = ref $_[0];
    croak "$pkg doesn't define a CLOSE method";
}

package Tie::StdHandle; 
our @ISA = 'Tie::Handle';
use Carp;

sub TIEHANDLE 
{
 my $class = shift;
 my $fh    = \do { local *HANDLE};
 bless $fh,$class;
 $fh->OPEN(@_) if (@_);
 return $fh;
}

sub EOF     { eof($_[0]) }
sub TELL    { tell($_[0]) }
sub FILENO  { fileno($_[0]) }
sub SEEK    { seek($_[0],$_[1],$_[2]) }
sub CLOSE   { close($_[0]) }
sub BINMODE { binmode($_[0]) }

sub OPEN
{
 $_[0]->CLOSE if defined($_[0]->FILENO);
 @_ == 2 ? open($_[0], $_[1]) : open($_[0], $_[1], $_[2]);
}

sub READ     { read($_[0],$_[1],$_[2]) }
sub READLINE { my $fh = $_[0]; <$fh> }
sub GETC     { getc($_[0]) }

sub WRITE
{
 my $fh = $_[0];
 print $fh substr($_[1],0,$_[2])
}


1;
