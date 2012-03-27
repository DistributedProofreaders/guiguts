package Env;

our $VERSION = '1.00';

sub import {
    my ($callpack) = caller(0);
    my $pack = shift;
    my @vars = grep /^[\$\@]?[A-Za-z_]\w*$/, (@_ ? @_ : keys(%ENV));
    return unless @vars;

    @vars = map { m/^[\$\@]/ ? $_ : '$'.$_ } @vars;

    eval "package $callpack; use vars qw(" . join(' ', @vars) . ")";
    die $@ if $@;
    foreach (@vars) {
	my ($type, $name) = m/^([\$\@])(.*)$/;
	if ($type eq '$') {
	    tie ${"${callpack}::$name"}, Env, $name;
	} else {
	    if ($^O eq 'VMS') {
		tie @{"${callpack}::$name"}, Env::Array::VMS, $name;
	    } else {
		tie @{"${callpack}::$name"}, Env::Array, $name;
	    }
	}
    }
}

sub TIESCALAR {
    bless \($_[1]);
}

sub FETCH {
    my ($self) = @_;
    $ENV{$$self};
}

sub STORE {
    my ($self, $value) = @_;
    if (defined($value)) {
	$ENV{$$self} = $value;
    } else {
	delete $ENV{$$self};
    }
}

######################################################################

package Env::Array;
 
use Config;
use Tie::Array;

@ISA = qw(Tie::Array);

my $sep = $Config::Config{path_sep};

sub TIEARRAY {
    bless \($_[1]);
}

sub FETCHSIZE {
    my ($self) = @_;
    my @temp = split($sep, $ENV{$$self});
    return scalar(@temp);
}

sub STORESIZE {
    my ($self, $size) = @_;
    my @temp = split($sep, $ENV{$$self});
    $#temp = $size - 1;
    $ENV{$$self} = join($sep, @temp);
}

sub CLEAR {
    my ($self) = @_;
    $ENV{$$self} = '';
}

sub FETCH {
    my ($self, $index) = @_;
    return (split($sep, $ENV{$$self}))[$index];
}

sub STORE {
    my ($self, $index, $value) = @_;
    my @temp = split($sep, $ENV{$$self});
    $temp[$index] = $value;
    $ENV{$$self} = join($sep, @temp);
    return $value;
}

sub PUSH {
    my $self = shift;
    my @temp = split($sep, $ENV{$$self});
    push @temp, @_;
    $ENV{$$self} = join($sep, @temp);
    return scalar(@temp);
}

sub POP {
    my ($self) = @_;
    my @temp = split($sep, $ENV{$$self});
    my $result = pop @temp;
    $ENV{$$self} = join($sep, @temp);
    return $result;
}

sub UNSHIFT {
    my $self = shift;
    my @temp = split($sep, $ENV{$$self});
    my $result = unshift @temp, @_;
    $ENV{$$self} = join($sep, @temp);
    return $result;
}

sub SHIFT {
    my ($self) = @_;
    my @temp = split($sep, $ENV{$$self});
    my $result = shift @temp;
    $ENV{$$self} = join($sep, @temp);
    return $result;
}

sub SPLICE {
    my $self = shift;
    my $offset = shift;
    my $length = shift;
    my @temp = split($sep, $ENV{$$self});
    if (wantarray) {
	my @result = splice @temp, $self, $offset, $length, @_;
	$ENV{$$self} = join($sep, @temp);
	return @result;
    } else {
	my $result = scalar splice @temp, $offset, $length, @_;
	$ENV{$$self} = join($sep, @temp);
	return $result;
    }
}

######################################################################

package Env::Array::VMS;
use Tie::Array;

@ISA = qw(Tie::Array);
 
sub TIEARRAY {
    bless \($_[1]);
}

sub FETCHSIZE {
    my ($self) = @_;
    my $i = 0;
    while ($i < 127 and defined $ENV{$$self . ';' . $i}) { $i++; };
    return $i;
}

sub FETCH {
    my ($self, $index) = @_;
    return $ENV{$$self . ';' . $index};
}

1;
