package Encode::Guess;
use strict;

use Encode qw(:fallbacks find_encoding);
our $VERSION = do { my @r = (q$Revision: 1.9 $ =~ /\d+/g); sprintf "%d."."%02d" x $#r, @r };

my $Canon = 'Guess';
sub DEBUG () { 0 }
our %DEF_SUSPECTS = map { $_ => find_encoding($_) } qw(ascii utf8);
$Encode::Encoding{$Canon} = 
    bless { 
	   Name       => $Canon,
	   Suspects => { %DEF_SUSPECTS },
	  } => __PACKAGE__;

use base qw(Encode::Encoding);
sub needs_lines { 1 }
sub perlio_ok { 0 }

our @EXPORT = qw(guess_encoding);
our $NoUTFAutoGuess = 0;

sub import { # Exporter not used so we do it on our own
    my $callpkg = caller;
    for my $item (@EXPORT){
	no strict 'refs';
	*{"$callpkg\::$item"} = \&{"$item"};
    }
    set_suspects(@_);
}

sub set_suspects{
    my $class = shift;
    my $self = ref($class) ? $class : $Encode::Encoding{$Canon};
    $self->{Suspects} = { %DEF_SUSPECTS };
    $self->add_suspects(@_);
}

sub add_suspects{
    my $class = shift;
    my $self = ref($class) ? $class : $Encode::Encoding{$Canon};
    for my $c (@_){
	my $e = find_encoding($c) or die "Unknown encoding: $c";
	$self->{Suspects}{$e->name} = $e;
	DEBUG and warn "Added: ", $e->name;
    }
}

sub decode($$;$){
    my ($obj, $octet, $chk) = @_;
    my $guessed = guess($obj, $octet);
    unless (ref($guessed)){
	require Carp;
	Carp::croak($guessed);
    }
    my $utf8 = $guessed->decode($octet, $chk);
    $_[1] = $octet if $chk;
    return $utf8;
}

sub guess_encoding{
    guess($Encode::Encoding{$Canon}, @_);
}

sub guess {
    my $class = shift;
    my $obj   = ref($class) ? $class : $Encode::Encoding{$Canon};
    my $octet = shift;

    # sanity check
    return unless defined $octet and length $octet;

    # cheat 0: utf8 flag;
    if ( Encode::is_utf8($octet) ) {
	return find_encoding('utf8') unless $NoUTFAutoGuess;
	Encode::_utf8_off($octet);
    }
    # cheat 1: BOM
    use Encode::Unicode;
    unless ($NoUTFAutoGuess) {
	my $BOM = unpack('n', $octet);
	return find_encoding('UTF-16')
	    if (defined $BOM and ($BOM == 0xFeFF or $BOM == 0xFFFe));
	$BOM = unpack('N', $octet);
	return find_encoding('UTF-32')
	    if (defined $BOM and ($BOM == 0xFeFF or $BOM == 0xFFFe0000));
	if ($octet =~ /\x00/o){ # if \x00 found, we assume UTF-(16|32)(BE|LE)
	    my $utf;
	    my ($be, $le) = (0, 0);
	    if ($octet =~ /\x00\x00/o){ # UTF-32(BE|LE) assumed
		$utf = "UTF-32";
		for my $char (unpack('N*', $octet)){
		    $char & 0x0000ffff and $be++;
		    $char & 0xffff0000 and $le++;
		}
	    }else{ # UTF-16(BE|LE) assumed
		$utf = "UTF-16";
		for my $char (unpack('n*', $octet)){
		    $char & 0x00ff and $be++;
		    $char & 0xff00 and $le++;
		}
	    }
	    DEBUG and warn "$utf, be == $be, le == $le";
	    $be == $le 
		and return
		    "Encodings ambiguous between $utf BE and LE ($be, $le)";
	    $utf .= ($be > $le) ? 'BE' : 'LE';
	    return find_encoding($utf);
	}
    }
    my %try =  %{$obj->{Suspects}};
    for my $c (@_){
	my $e = find_encoding($c) or die "Unknown encoding: $c";
	$try{$e->name} = $e;
	DEBUG and warn "Added: ", $e->name;
    }
    my $nline = 1;
    for my $line (split /\r\n?|\n/, $octet){
	# cheat 2 -- \e in the string
	if ($line =~ /\e/o){
	    my @keys = keys %try;
	    delete @try{qw/utf8 ascii/};
	    for my $k (@keys){
		ref($try{$k}) eq 'Encode::XS' and delete $try{$k};
	    }
	}
	my %ok = %try;
	# warn join(",", keys %try);
	for my $k (keys %try){
	    my $scratch = $line;
	    $try{$k}->decode($scratch, FB_QUIET);
	    if ($scratch eq ''){
		DEBUG and warn sprintf("%4d:%-24s ok\n", $nline, $k);
	    }else{
		use bytes ();
		DEBUG and 
		    warn sprintf("%4d:%-24s not ok; %d bytes left\n", 
				 $nline, $k, bytes::length($scratch));
		delete $ok{$k};
	    }
	}
	%ok or return "No appropriate encodings found!";
	if (scalar(keys(%ok)) == 1){
	    my ($retval) = values(%ok);
	    return $retval;
	}
	%try = %ok; $nline++;
    }
    $try{ascii} or 
	return  "Encodings too ambiguous: ", join(" or ", keys %try);
    return $try{ascii};
}



1;
__END__

