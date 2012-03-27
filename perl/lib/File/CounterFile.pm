package File::CounterFile;

# $Id: CounterFile.pm,v 0.18 2003/10/06 12:47:40 gisle Exp $

require 5.004;

use strict;

use Carp   qw(croak);
use Symbol qw(gensym);
use Fcntl qw(O_RDWR O_CREAT);

use vars qw($VERSION $MAGIC $DEFAULT_INITIAL $DEFAULT_DIR);

sub Version { $VERSION; }
$VERSION = "1.01";

$MAGIC = "#COUNTER-1.0\n";             # first line in counter files
$DEFAULT_INITIAL = 0;                  # default initial counter value

 # default location for counter files
$DEFAULT_DIR = $ENV{TMPDIR} || "/usr/tmp";

# Experimental overloading.
use overload ('++'     => \&inc,
	      '--'     => \&dec,
	      '""'     => \&value,
	      fallback => 1,
             );


sub new
{
    my($class, $file, $initial) = @_;
    croak("No file specified\n") unless defined $file;

    $file = "$DEFAULT_DIR/$file" unless $file =~ /^[\.\/]/;
    $initial = $DEFAULT_INITIAL unless defined $initial;

    my $value;
    local($/, $\) = ("\n", undef);
    local *F;
    sysopen(F, $file, O_RDWR|O_CREAT) or croak("Can't open $file: $!");
    flock(F, 2) or croak("Can't flock: $!");
    my $first_line = <F>;
    if (defined $first_line) {
	croak "Bad counter magic '$first_line' in $file" unless $first_line eq $MAGIC;
	$value = <F>;
	chomp($value);
    }
    else {
	seek(F, 0, 0);
	print F $MAGIC;
	print F "$initial\n";
	$value = $initial;
    }
    close(F) || croak("Can't close $file: $!");

    bless { file    => $file,  # the filename for the counter
	   'value'  => $value, # the current value
	    updated => 0,      # flag indicating if value has changed
	    # handle => XXX,   # file handle symbol. Only present when locked
	  };
}


sub locked
{
    exists shift->{handle};
}


sub lock
{
    my($self) = @_;
    $self->unlock if $self->locked;

    my $fh = gensym();
    my $file = $self->{file};

    open($fh, "+<$file") or croak "Can't open $file: $!";
    flock($fh, 2) or croak "Can't flock: $!";  # 2 = exlusive lock

    local($/) = "\n";
    my $magic = <$fh>;
    if ($magic ne $MAGIC) {
	$self->unlock;
	croak("Bad counter magic '$magic' in $file");
    }
    chomp($self->{'value'} = <$fh>);

    $self->{handle}  = $fh;
    $self->{updated} = 0;
    $self;
}


sub unlock
{
    my($self) = @_;
    return unless $self->locked;

    my $fh = $self->{handle};

    if ($self->{updated}) {
	# write back new value
	local($\) = undef;
	seek($fh, 0, 0) or croak "Can't seek to beginning: $!";
	print $fh $MAGIC;
	print $fh "$self->{'value'}\n";
    }

    close($fh) or warn "Can't close: $!";
    delete $self->{handle};
    $self;
}


sub inc
{
    my($self) = @_;

    if ($self->locked) {
	$self->{'value'}++;
	$self->{updated} = 1;
    } else {
	$self->lock;
	$self->{'value'}++;
	$self->{updated} = 1;
	$self->unlock;
    }
    $self->{'value'}; # return value
}


sub dec
{
    my($self) = @_;

    if ($self->locked) {
	unless ($self->{'value'} =~ /^\d+$/) {
	    $self->unlock;
	    croak "Autodecrement is not magical in perl";
	}
	$self->{'value'}--;
	$self->{updated} = 1;
    }
    else {
	$self->lock;
	unless ($self->{'value'} =~ /^\d+$/) {
	    $self->unlock;
	    croak "Autodecrement is not magical in perl";
	}
	$self->{'value'}--;
	$self->{updated} = 1;
	$self->unlock;
    }
    $self->{'value'}; # return value
}


sub value
{
    my($self) = @_;
    my $value;
    if ($self->locked) {
	$value = $self->{'value'};
    }
    else {
	$self->lock;
	$value = $self->{'value'};
	$self->unlock;
    }
    $value;
}


sub DESTROY
{
    my $self = shift;
    $self->unlock;
}

1;

__END__

