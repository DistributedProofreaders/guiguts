package diagnostics;

use strict;
use 5.006;
use Carp;

our $VERSION = 1.12;
our $DEBUG;
our $VERBOSE;
our $PRETTY;

use Config;
my($privlib, $archlib) = @Config{qw(privlibexp archlibexp)};
if ($^O eq 'VMS') {
    require VMS::Filespec;
    $privlib = VMS::Filespec::unixify($privlib);
    $archlib = VMS::Filespec::unixify($archlib);
}
my @trypod = (
	   "$archlib/pod/perldiag.pod",
	   "$privlib/pod/perldiag-$Config{version}.pod",
	   "$privlib/pod/perldiag.pod",
	   "$archlib/pods/perldiag.pod",
	   "$privlib/pods/perldiag-$Config{version}.pod",
	   "$privlib/pods/perldiag.pod",
	  );
# handy for development testing of new warnings etc
unshift @trypod, "./pod/perldiag.pod" if -e "pod/perldiag.pod";
(my $PODFILE) = ((grep { -e } @trypod), $trypod[$#trypod])[0];

if ($^O eq 'MacOS') {
    # just updir one from each lib dir, we'll find it ...
    ($PODFILE) = grep { -e } map { "$_:pod:perldiag.pod" } @INC;
}


$DEBUG ||= 0;
my $WHOAMI = ref bless [];  # nobody's business, prolly not even mine

local $| = 1;
local $_;

my $standalone;
my(%HTML_2_Troff, %HTML_2_Latin_1, %HTML_2_ASCII_7);

CONFIG: {
    our $opt_p = our $opt_d = our $opt_v = our $opt_f = '';

    unless (caller) {
	$standalone++;
	require Getopt::Std;
	Getopt::Std::getopts('pdvf:')
	    or die "Usage: $0 [-v] [-p] [-f splainpod]";
	$PODFILE = $opt_f if $opt_f;
	$DEBUG = 2 if $opt_d;
	$VERBOSE = $opt_v;
	$PRETTY = $opt_p;
    }

    if (open(POD_DIAG, $PODFILE)) {
	warn "Happy happy podfile from real $PODFILE\n" if $DEBUG;
	last CONFIG;
    } 

    if (caller) {
	INCPATH: {
	    for my $file ( (map { "$_/$WHOAMI.pm" } @INC), $0) {
		warn "Checking $file\n" if $DEBUG;
		if (open(POD_DIAG, $file)) {
		    while (<POD_DIAG>) {
			next unless
			    /^__END__\s*# wish diag dbase were more accessible/;
			print STDERR "podfile is $file\n" if $DEBUG;
			last INCPATH;
		    }
		}
	    } 
	}
    } else { 
	print STDERR "podfile is <DATA>\n" if $DEBUG;
	*POD_DIAG = *main::DATA;
    }
}
if (eof(POD_DIAG)) { 
    die "couldn't find diagnostic data in $PODFILE @INC $0";
}


%HTML_2_Troff = (
    'amp'	=>	'&',	#   ampersand
    'lt'	=>	'<',	#   left chevron, less-than
    'gt'	=>	'>',	#   right chevron, greater-than
    'quot'	=>	'"',	#   double quote

    "Aacute"	=>	"A\\*'",	#   capital A, acute accent
    # etc

);

%HTML_2_Latin_1 = (
    'amp'	=>	'&',	#   ampersand
    'lt'	=>	'<',	#   left chevron, less-than
    'gt'	=>	'>',	#   right chevron, greater-than
    'quot'	=>	'"',	#   double quote

    "Aacute"	=>	"\xC1"	#   capital A, acute accent

    # etc
);

%HTML_2_ASCII_7 = (
    'amp'	=>	'&',	#   ampersand
    'lt'	=>	'<',	#   left chevron, less-than
    'gt'	=>	'>',	#   right chevron, greater-than
    'quot'	=>	'"',	#   double quote

    "Aacute"	=>	"A"	#   capital A, acute accent
    # etc
);

our %HTML_Escapes;
*HTML_Escapes = do {
    if ($standalone) {
	$PRETTY ? \%HTML_2_Latin_1 : \%HTML_2_ASCII_7; 
    } else {
	\%HTML_2_Latin_1; 
    }
}; 

*THITHER = $standalone ? *STDOUT : *STDERR;

my %transfmt = (); 
my $transmo = <<EOFUNC;
sub transmo {
    #local \$^W = 0;  # recursive warnings we do NOT need!
    study;
EOFUNC

my %msg;
{
    print STDERR "FINISHING COMPILATION for $_\n" if $DEBUG;
    local $/ = '';
    local $_;
    my $header;
    my $for_item;
    while (<POD_DIAG>) {

	unescape();
	if ($PRETTY) {
	    sub noop   { return $_[0] }  # spensive for a noop
	    sub bold   { my $str =$_[0];  $str =~ s/(.)/$1\b$1/g; return $str; } 
	    sub italic { my $str = $_[0]; $str =~ s/(.)/_\b$1/g;  return $str; } 
	    s/[BC]<(.*?)>/bold($1)/ges;
	    s/[LIF]<(.*?)>/italic($1)/ges;
	} else {
	    s/[BC]<(.*?)>/$1/gs;
	    s/[LIF]<(.*?)>/$1/gs;
	} 
	unless (/^=/) {
	    if (defined $header) { 
		if ( $header eq 'DESCRIPTION' && 
		    (   /Optional warnings are enabled/ 
		     || /Some of these messages are generic./
		    ) )
		{
		    next;
		}
		s/^/    /gm;
		$msg{$header} .= $_;
	 	undef $for_item;	
	    }
	    next;
	} 
	unless ( s/=item (.*?)\s*\z//) {

	    if ( s/=head1\sDESCRIPTION//) {
		$msg{$header = 'DESCRIPTION'} = '';
		undef $for_item;
	    }
	    elsif( s/^=for\s+diagnostics\s*\n(.*?)\s*\z// ) {
		$for_item = $1;
	    } 
	    next;
	}

	if( $for_item ) { $header = $for_item; undef $for_item } 
	else {
	    $header = $1;
	    while( $header =~ /[;,]\z/ ) {
		<POD_DIAG> =~ /^\s*(.*?)\s*\z/;
		$header .= ' '.$1;
	    }
	}

	# strip formatting directives from =item line
	$header =~ s/[A-Z]<(.*?)>/$1/g;

        my @toks = split( /(%l?[dx]|%c|%(?:\.\d+)?s)/, $header );
	if (@toks > 1) {
            my $conlen = 0;
            for my $i (0..$#toks){
                if( $i % 2 ){
                    if(      $toks[$i] eq '%c' ){
                        $toks[$i] = '.';
                    } elsif( $toks[$i] eq '%d' ){
                        $toks[$i] = '\d+';
                    } elsif( $toks[$i] eq '%s' ){
                        $toks[$i] = $i == $#toks ? '.*' : '.*?';
                    } elsif( $toks[$i] =~ '%.(\d+)s' ){
                        $toks[$i] = ".{$1}";
                     } elsif( $toks[$i] =~ '^%l*x$' ){
                        $toks[$i] = '[\da-f]+';
                   }
                } elsif( length( $toks[$i] ) ){
                    $toks[$i] =~ s/^.*$/\Q$&\E/;
                    $conlen += length( $toks[$i] );
                }
            }  
            my $lhs = join( '', @toks );
	    $transfmt{$header}{pat} =
              "    s{^$lhs}\n     {\Q$header\E}s\n\t&& return 1;\n";
            $transfmt{$header}{len} = $conlen;
	} else {
            $transfmt{$header}{pat} =
	      "    m{^\Q$header\E} && return 1;\n";
            $transfmt{$header}{len} = length( $header );
	} 

	print STDERR "$WHOAMI: Duplicate entry: \"$header\"\n"
	    if $msg{$header};

	$msg{$header} = '';
    } 


    close POD_DIAG unless *main::DATA eq *POD_DIAG;

    die "No diagnostics?" unless %msg;

    # Apply patterns in order of decreasing sum of lengths of fixed parts
    # Seems the best way of hitting the right one.
    for my $hdr ( sort { $transfmt{$b}{len} <=> $transfmt{$a}{len} }
                  keys %transfmt ){
        $transmo .= $transfmt{$hdr}{pat};
    }
    $transmo .= "    return 0;\n}\n";
    print STDERR $transmo if $DEBUG;
    eval $transmo;
    die $@ if $@;
}

if ($standalone) {
    if (!@ARGV and -t STDIN) { print STDERR "$0: Reading from STDIN\n" } 
    while (defined (my $error = <>)) {
	splainthis($error) || print THITHER $error;
    } 
    exit;
} 

my $olddie;
my $oldwarn;

sub import {
    shift;
    $^W = 1; # yup, clobbered the global variable; 
	     # tough, if you want diags, you want diags.
    return if defined $SIG{__WARN__} && ($SIG{__WARN__} eq \&warn_trap);

    for (@_) {

	/^-d(ebug)?$/ 	   	&& do {
				    $DEBUG++;
				    next;
				   };

	/^-v(erbose)?$/ 	&& do {
				    $VERBOSE++;
				    next;
				   };

	/^-p(retty)?$/ 		&& do {
				    print STDERR "$0: I'm afraid it's too late for prettiness.\n";
				    $PRETTY++;
				    next;
			       };

	warn "Unknown flag: $_";
    } 

    $oldwarn = $SIG{__WARN__};
    $olddie = $SIG{__DIE__};
    $SIG{__WARN__} = \&warn_trap;
    $SIG{__DIE__} = \&death_trap;
} 

sub enable { &import }

sub disable {
    shift;
    return unless $SIG{__WARN__} eq \&warn_trap;
    $SIG{__WARN__} = $oldwarn || '';
    $SIG{__DIE__} = $olddie || '';
} 

sub warn_trap {
    my $warning = $_[0];
    if (caller eq $WHOAMI or !splainthis($warning)) {
	print STDERR $warning;
    } 
    &$oldwarn if defined $oldwarn and $oldwarn and $oldwarn ne \&warn_trap;
};

sub death_trap {
    my $exception = $_[0];

    # See if we are coming from anywhere within an eval. If so we don't
    # want to explain the exception because it's going to get caught.
    my $in_eval = 0;
    my $i = 0;
    while (1) {
      my $caller = (caller($i++))[3] or last;
      if ($caller eq '(eval)') {
	$in_eval = 1;
	last;
      }
    }

    splainthis($exception) unless $in_eval;
    if (caller eq $WHOAMI) { print STDERR "INTERNAL EXCEPTION: $exception"; } 
    &$olddie if defined $olddie and $olddie and $olddie ne \&death_trap;

    return if $in_eval;

    # We don't want to unset these if we're coming from an eval because
    # then we've turned off diagnostics.

    # Switch off our die/warn handlers so we don't wind up in our own
    # traps.
    $SIG{__DIE__} = $SIG{__WARN__} = '';

    # Have carp skip over death_trap() when showing the stack trace.
    local($Carp::CarpLevel) = 1;

    confess "Uncaught exception from user code:\n\t$exception";
	# up we go; where we stop, nobody knows, but i think we die now
	# but i'm deeply afraid of the &$olddie guy reraising and us getting
	# into an indirect recursion loop
};

my %exact_duplicate;
my %old_diag;
my $count;
my $wantspace;
sub splainthis {
    local $_ = shift;
    local $\;
    ### &finish_compilation unless %msg;
    s/\.?\n+$//;
    my $orig = $_;
    # return unless defined;

    # get rid of the where-are-we-in-input part
    s/, <.*?> (?:line|chunk).*$//;

    # Discard 1st " at <file> line <no>" and all text beyond
    # but be aware of messsages containing " at this-or-that"
    my $real = 0;
    my @secs = split( / at / );
    $_ = $secs[0];
    for my $i ( 1..$#secs ){
        if( $secs[$i] =~ /.+? (?:line|chunk) \d+/ ){
            $real = 1;
            last;
        } else {
            $_ .= ' at ' . $secs[$i];
	}
    }
    
    # remove parenthesis occurring at the end of some messages 
    s/^\((.*)\)$/$1/;

    if ($exact_duplicate{$orig}++) {
	return &transmo;
    } else {
	return 0 unless &transmo;
    }

    $orig = shorten($orig);
    if ($old_diag{$_}) {
	autodescribe();
	print THITHER "$orig (#$old_diag{$_})\n";
	$wantspace = 1;
    } else {
	autodescribe();
	$old_diag{$_} = ++$count;
	print THITHER "\n" if $wantspace;
	$wantspace = 0;
	print THITHER "$orig (#$old_diag{$_})\n";
	if ($msg{$_}) {
	    print THITHER $msg{$_};
	} else {
	    if (0 and $standalone) { 
		print THITHER "    **** Error #$old_diag{$_} ",
			($real ? "is" : "appears to be"),
			" an unknown diagnostic message.\n\n";
	    }
	    return 0;
	} 
    }
    return 1;
} 

sub autodescribe {
    if ($VERBOSE and not $count) {
	print THITHER &{$PRETTY ? \&bold : \&noop}("DESCRIPTION OF DIAGNOSTICS"),
		"\n$msg{DESCRIPTION}\n";
    } 
} 

sub unescape { 
    s {
            E<  
            ( [A-Za-z]+ )       
            >   
    } { 
         do {   
             exists $HTML_Escapes{$1}
                ? do { $HTML_Escapes{$1} }
                : do {
                    warn "Unknown escape: E<$1> in $_";
                    "E<$1>";
                } 
         } 
    }egx;
}

sub shorten {
    my $line = $_[0];
    if (length($line) > 79 and index($line, "\n") == -1) {
	my $space_place = rindex($line, ' ', 79);
	if ($space_place != -1) {
	    substr($line, $space_place, 1) = "\n\t";
	} 
    } 
    return $line;
} 


1 unless $standalone;  # or it'll complain about itself
__END__ # wish diag dbase were more accessible
