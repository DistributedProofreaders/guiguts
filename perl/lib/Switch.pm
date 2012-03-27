package Switch;

use strict;
use vars qw($VERSION);
use Carp;

$VERSION = '2.10';


# LOAD FILTERING MODULE...
use Filter::Util::Call;

sub __();

# CATCH ATTEMPTS TO CALL case OUTSIDE THE SCOPE OF ANY switch

$::_S_W_I_T_C_H = sub { croak "case/when statement not in switch/given block" };

my $offset;
my $fallthrough;
my ($Perl5, $Perl6) = (0,0);

sub import
{
	$fallthrough = grep /\bfallthrough\b/, @_;
	$offset = (caller)[2]+1;
	filter_add({}) unless @_>1 && $_[1] eq 'noimport';
	my $pkg = caller;
	no strict 'refs';
	for ( qw( on_defined on_exists ) )
	{
		*{"${pkg}::$_"} = \&$_;
	}
	*{"${pkg}::__"} = \&__ if grep /__/, @_;
	$Perl6 = 1 if grep(/Perl\s*6/i, @_);
	$Perl5 = 1 if grep(/Perl\s*5/i, @_) || !grep(/Perl\s*6/i, @_);
	1;
}

sub unimport
{	
	filter_del()
}

sub filter
{
	my($self) = @_ ;
	local $Switch::file = (caller)[1];

	my $status = 1;
	$status = filter_read(10_000);
	return $status if $status<0;
    	$_ = filter_blocks($_,$offset);
	$_ = "# line $offset\n" . $_ if $offset; undef $offset;
	return $status;
}

use Text::Balanced ':ALL';

sub line
{
	my ($pretext,$offset) = @_;
	($pretext=~tr/\n/\n/)+($offset||0);
}

sub is_block
{
	local $SIG{__WARN__}=sub{die$@};
	local $^W=1;
	my $ishash = defined  eval 'my $hr='.$_[0];
	undef $@;
	return !$ishash;
}


my $EOP = qr/\n\n|\Z/;
my $CUT = qr/\n=cut.*$EOP/;
my $pod_or_DATA = qr/ ^=(?:head[1-4]|item) .*? $CUT
                    | ^=pod .*? $CUT
                    | ^=for .*? $EOP
                    | ^=begin \s* (\S+) .*? \n=end \s* \1 .*? $EOP
                    | ^__(DATA|END)__\n.*
                    /smx;

my $casecounter = 1;
sub filter_blocks
{
	my ($source, $line) = @_;
	return $source unless $Perl5 && $source =~ /case|switch/
			   || $Perl6 && $source =~ /when|given/;
	pos $source = 0;
	my $text = "";
	component: while (pos $source < length $source)
	{
		if ($source =~ m/(\G\s*use\s+Switch\b)/gc)
		{
			$text .= q{use Switch 'noimport'};
			next component;
		}
		my @pos = Text::Balanced::_match_quotelike(\$source,qr/\s*/,1,0);
		if (defined $pos[0])
		{
			$text .= " " if $pos[0] < $pos[2];
			$text .= substr($source,$pos[2],$pos[18]-$pos[2]);
			next component;
		}
		if ($source =~ m/\G\s*($pod_or_DATA)/gc) {
			next component;
		}
		@pos = Text::Balanced::_match_variable(\$source,qr/\s*/);
		if (defined $pos[0])
		{
			$text .= " " if $pos[0] < $pos[2];
			$text .= substr($source,$pos[0],$pos[4]-$pos[0]);
			next component;
		}

		if ($Perl5 && $source =~ m/\G(\n*)(\s*)(switch)\b(?=\s*[(])/gc
		 || $Perl6 && $source =~ m/\G(\n*)(\s*)(given)\b(?=\s*[(])/gc
		 || $Perl6 && $source =~ m/\G(\n*)(\s*)(given)\b(.*)(?=\{)/gc)
		{
			my $keyword = $3;
			my $arg = $4;
			# print  STDERR "[$arg]\n";
			$text .= $1.$2.'S_W_I_T_C_H: while (1) ';
			unless ($arg) {
				@pos = Text::Balanced::_match_codeblock(\$source,qr/\s*/,qr/\(/,qr/\)/,qr/[[{(<]/,qr/[]})>]/,undef) 
				or do {
					die "Bad $keyword statement (problem in the parentheses?) near $Switch::file line ", line(substr($source,0,pos $source),$line), "\n";
				};
				$arg = filter_blocks(substr($source,$pos[0],$pos[4]-$pos[0]),line(substr($source,0,$pos[0]),$line));
			}
			$arg =~ s {^\s*[(]\s*%}   { ( \\\%}	||
			$arg =~ s {^\s*[(]\s*m\b} { ( qr}	||
			$arg =~ s {^\s*[(]\s*/}   { ( qr/}	||
			$arg =~ s {^\s*[(]\s*qw}  { ( \\qw};
			@pos = Text::Balanced::_match_codeblock(\$source,qr/\s*/,qr/\{/,qr/\}/,qr/\{/,qr/\}/,undef)
			or do {
				die "Bad $keyword statement (problem in the code block?) near $Switch::file line ", line(substr($source,0, pos $source), $line), "\n";
			};
			my $code = filter_blocks(substr($source,$pos[0],$pos[4]-$pos[0]),line(substr($source,0,$pos[0]),$line));
			$code =~ s/{/{ local \$::_S_W_I_T_C_H; Switch::switch $arg;/;
			$text .= $code . 'continue {last}';
			next component;
		}
		elsif ($Perl5 && $source =~ m/\G(\s*)(case\b)(?!\s*=>)/gc
		    || $Perl6 && $source =~ m/\G(\s*)(when\b)(?!\s*=>)/gc)
		{
			my $keyword = $2;
			$text .= $1."if (Switch::case";
			if (@pos = Text::Balanced::_match_codeblock(\$source,qr/\s*/,qr/\{/,qr/\}/,qr/\{/,qr/\}/,undef)) {
				my $code = substr($source,$pos[0],$pos[4]-$pos[0]);
				$text .= " " if $pos[0] < $pos[2];
				$text .= "sub " if is_block $code;
				$text .= filter_blocks($code,line(substr($source,0,$pos[0]),$line)) . ")";
			}
			elsif (@pos = Text::Balanced::_match_codeblock(\$source,qr/\s*/,qr/[[(]/,qr/[])]/,qr/[[({]/,qr/[])}]/,undef)) {
				my $code = filter_blocks(substr($source,$pos[0],$pos[4]-$pos[0]),line(substr($source,0,$pos[0]),$line));
				$code =~ s {^\s*[(]\s*%}   { ( \\\%}	||
				$code =~ s {^\s*[(]\s*m\b} { ( qr}	||
				$code =~ s {^\s*[(]\s*/}   { ( qr/}	||
				$code =~ s {^\s*[(]\s*qw}  { ( \\qw};
				$text .= " " if $pos[0] < $pos[2];
				$text .= "$code)";
			}
			elsif ($Perl6 && do{@pos = Text::Balanced::_match_variable(\$source,qr/\s*/)}) {
				my $code = filter_blocks(substr($source,$pos[0],$pos[4]-$pos[0]),line(substr($source,0,$pos[0]),$line));
				$code =~ s {^\s*%}  { \%}	||
				$code =~ s {^\s*@}  { \@};
				$text .= " " if $pos[0] < $pos[2];
				$text .= "$code)";
			}
			elsif ( @pos = Text::Balanced::_match_quotelike(\$source,qr/\s*/,1,0)) {
				my $code = substr($source,$pos[2],$pos[18]-$pos[2]);
				$code = filter_blocks($code,line(substr($source,0,$pos[2]),$line));
				$code =~ s {^\s*m}  { qr}	||
				$code =~ s {^\s*/}  { qr/}	||
				$code =~ s {^\s*qw} { \\qw};
				$text .= " " if $pos[0] < $pos[2];
				$text .= "$code)";
			}
			elsif ($Perl5 && $source =~ m/\G\s*(([^\$\@{])[^\$\@{]*)(?=\s*{)/gc
			   ||  $Perl6 && $source =~ m/\G\s*([^;{]*)()/gc) {
				my $code = filter_blocks($1,line(substr($source,0,pos $source),$line));
				$text .= ' \\' if $2 eq '%';
				$text .= " $code)";
			}
			else {
				die "Bad $keyword statement (invalid $keyword value?) near $Switch::file line ", line(substr($source,0,pos $source), $line), "\n";
			}

		        die "Missing opening brace or semi-colon after 'when' value near $Switch::file line ", line(substr($source,0,pos $source), $line), "\n"
				unless !$Perl6 || $source =~ m/\G(\s*)(?=;|\{)/gc;

			do{@pos = Text::Balanced::_match_codeblock(\$source,qr/\s*/,qr/\{/,qr/\}/,qr/\{/,qr/\}/,undef)}
			or do {
				if ($source =~ m/\G\s*(?=([};]|\Z))/gc) {
					$casecounter++;
					next component;
				}
				die "Bad $keyword statement (problem in the code block?) near $Switch::file line ", line(substr($source,0,pos $source),$line), "\n";
			};
			my $code = filter_blocks(substr($source,$pos[0],$pos[4]-$pos[0]),line(substr($source,0,$pos[0]),$line));
			$code =~ s/}(?=\s*\Z)/;last S_W_I_T_C_H }/
				unless $fallthrough;
			$text .= "{ while (1) $code continue { goto C_A_S_E_$casecounter } last S_W_I_T_C_H; C_A_S_E_$casecounter: }";
			$casecounter++;
			next component;
		}

		$source =~ m/\G(\s*(-[sm]\s+|\w+|#.*\n|\W))/gc;
		$text .= $1;
	}
	$text;
}



sub in
{
	my ($x,$y) = @_;
	my @numy;
	for my $nextx ( @$x )
	{
		my $numx = ref($nextx) || defined $nextx && (~$nextx&$nextx) eq 0;
		for my $j ( 0..$#$y )
		{
			my $nexty = $y->[$j];
			push @numy, ref($nexty) || defined $nexty && (~$nexty&$nexty) eq 0
				if @numy <= $j;
			return 1 if $numx && $numy[$j] && $nextx==$nexty
			         || $nextx eq $nexty;
			
		}
	}
	return "";
}

sub on_exists
{
	my $ref = @_==1 && ref($_[0]) eq 'HASH' ? $_[0] : { @_ };
	[ keys %$ref ]
}

sub on_defined
{
	my $ref = @_==1 && ref($_[0]) eq 'HASH' ? $_[0] : { @_ };
	[ grep { defined $ref->{$_} } keys %$ref ]
}

sub switch(;$)
{
	my ($s_val) = @_ ? $_[0] : $_;
	my $s_ref = ref $s_val;
	
	if ($s_ref eq 'CODE')
	{
		$::_S_W_I_T_C_H =
		      sub { my $c_val = $_[0];
			    return $s_val == $c_val  if ref $c_val eq 'CODE';
			    return $s_val->(@$c_val) if ref $c_val eq 'ARRAY';
			    return $s_val->($c_val);
			  };
	}
	elsif ($s_ref eq "" && defined $s_val && (~$s_val&$s_val) eq 0)	# NUMERIC SCALAR
	{
		$::_S_W_I_T_C_H =
		      sub { my $c_val = $_[0];
			    my $c_ref = ref $c_val;
			    return $s_val == $c_val 	if $c_ref eq ""
							&& defined $c_val
							&& (~$c_val&$c_val) eq 0;
			    return $s_val eq $c_val 	if $c_ref eq "";
			    return in([$s_val],$c_val)	if $c_ref eq 'ARRAY';
			    return $c_val->($s_val)	if $c_ref eq 'CODE';
			    return $c_val->call($s_val)	if $c_ref eq 'Switch';
			    return scalar $s_val=~/$c_val/
							if $c_ref eq 'Regexp';
			    return scalar $c_val->{$s_val}
							if $c_ref eq 'HASH';
		            return;	
			  };
	}
	elsif ($s_ref eq "")				# STRING SCALAR
	{
		$::_S_W_I_T_C_H =
		      sub { my $c_val = $_[0];
			    my $c_ref = ref $c_val;
			    return $s_val eq $c_val 	if $c_ref eq "";
			    return in([$s_val],$c_val)	if $c_ref eq 'ARRAY';
			    return $c_val->($s_val)	if $c_ref eq 'CODE';
			    return $c_val->call($s_val)	if $c_ref eq 'Switch';
			    return scalar $s_val=~/$c_val/
							if $c_ref eq 'Regexp';
			    return scalar $c_val->{$s_val}
							if $c_ref eq 'HASH';
		            return;	
			  };
	}
	elsif ($s_ref eq 'ARRAY')
	{
		$::_S_W_I_T_C_H =
		      sub { my $c_val = $_[0];
			    my $c_ref = ref $c_val;
			    return in($s_val,[$c_val]) 	if $c_ref eq "";
			    return in($s_val,$c_val)	if $c_ref eq 'ARRAY';
			    return $c_val->(@$s_val)	if $c_ref eq 'CODE';
			    return $c_val->call(@$s_val)
							if $c_ref eq 'Switch';
			    return scalar grep {$_=~/$c_val/} @$s_val
							if $c_ref eq 'Regexp';
			    return scalar grep {$c_val->{$_}} @$s_val
							if $c_ref eq 'HASH';
		            return;	
			  };
	}
	elsif ($s_ref eq 'Regexp')
	{
		$::_S_W_I_T_C_H =
		      sub { my $c_val = $_[0];
			    my $c_ref = ref $c_val;
			    return $c_val=~/s_val/ 	if $c_ref eq "";
			    return scalar grep {$_=~/s_val/} @$c_val
							if $c_ref eq 'ARRAY';
			    return $c_val->($s_val)	if $c_ref eq 'CODE';
			    return $c_val->call($s_val)	if $c_ref eq 'Switch';
			    return $s_val eq $c_val	if $c_ref eq 'Regexp';
			    return grep {$_=~/$s_val/ && $c_val->{$_}} keys %$c_val
							if $c_ref eq 'HASH';
		            return;	
			  };
	}
	elsif ($s_ref eq 'HASH')
	{
		$::_S_W_I_T_C_H =
		      sub { my $c_val = $_[0];
			    my $c_ref = ref $c_val;
			    return $s_val->{$c_val} 	if $c_ref eq "";
			    return scalar grep {$s_val->{$_}} @$c_val
							if $c_ref eq 'ARRAY';
			    return $c_val->($s_val)	if $c_ref eq 'CODE';
			    return $c_val->call($s_val)	if $c_ref eq 'Switch';
			    return grep {$_=~/$c_val/ && $s_val->{"$_"}} keys %$s_val
							if $c_ref eq 'Regexp';
			    return $s_val==$c_val	if $c_ref eq 'HASH';
		            return;	
			  };
	}
	elsif ($s_ref eq 'Switch')
	{
		$::_S_W_I_T_C_H =
		      sub { my $c_val = $_[0];
			    return $s_val == $c_val  if ref $c_val eq 'Switch';
			    return $s_val->call(@$c_val)
						     if ref $c_val eq 'ARRAY';
			    return $s_val->call($c_val);
			  };
	}
	else
	{
		croak "Cannot switch on $s_ref";
	}
	return 1;
}

sub case($) { local $SIG{__WARN__} = \&carp;
	      $::_S_W_I_T_C_H->(@_); }

# IMPLEMENT __

my $placeholder = bless { arity=>1, impl=>sub{$_[1+$_[0]]} };

sub __() { $placeholder }

sub __arg($)
{
	my $index = $_[0]+1;
	bless { arity=>0, impl=>sub{$_[$index]} };
}

sub hosub(&@)
{
	# WRITE THIS
}

sub call
{
	my ($self,@args) = @_;
	return $self->{impl}->(0,@args);
}

sub meta_bop(&)
{
	my ($op) = @_;
	sub
	{
		my ($left, $right, $reversed) = @_;
		($right,$left) = @_ if $reversed;

		my $rop = ref $right eq 'Switch'
			? $right
			: bless { arity=>0, impl=>sub{$right} };

		my $lop = ref $left eq 'Switch'
			? $left
			: bless { arity=>0, impl=>sub{$left} };

		my $arity = $lop->{arity} + $rop->{arity};

		return bless {
				arity => $arity,
				impl  => sub { my $start = shift;
					       return $op->($lop->{impl}->($start,@_),
						            $rop->{impl}->($start+$lop->{arity},@_));
					     }
			     };
	};
}

sub meta_uop(&)
{
	my ($op) = @_;
	sub
	{
		my ($left) = @_;

		my $lop = ref $left eq 'Switch'
			? $left
			: bless { arity=>0, impl=>sub{$left} };

		my $arity = $lop->{arity};

		return bless {
				arity => $arity,
				impl  => sub { $op->($lop->{impl}->(@_)) }
			     };
	};
}


use overload
	"+"	=> 	meta_bop {$_[0] + $_[1]},
	"-"	=> 	meta_bop {$_[0] - $_[1]},  
	"*"	=>  	meta_bop {$_[0] * $_[1]},
	"/"	=>  	meta_bop {$_[0] / $_[1]},
	"%"	=>  	meta_bop {$_[0] % $_[1]},
	"**"	=>  	meta_bop {$_[0] ** $_[1]},
	"<<"	=>  	meta_bop {$_[0] << $_[1]},
	">>"	=>  	meta_bop {$_[0] >> $_[1]},
	"x"	=>  	meta_bop {$_[0] x $_[1]},
	"."	=>  	meta_bop {$_[0] . $_[1]},
	"<"	=>  	meta_bop {$_[0] < $_[1]},
	"<="	=>  	meta_bop {$_[0] <= $_[1]},
	">"	=>  	meta_bop {$_[0] > $_[1]},
	">="	=>  	meta_bop {$_[0] >= $_[1]},
	"=="	=>  	meta_bop {$_[0] == $_[1]},
	"!="	=>  	meta_bop {$_[0] != $_[1]},
	"<=>"	=>  	meta_bop {$_[0] <=> $_[1]},
	"lt"	=>  	meta_bop {$_[0] lt $_[1]},
	"le"	=> 	meta_bop {$_[0] le $_[1]},
	"gt"	=> 	meta_bop {$_[0] gt $_[1]},
	"ge"	=> 	meta_bop {$_[0] ge $_[1]},
	"eq"	=> 	meta_bop {$_[0] eq $_[1]},
	"ne"	=> 	meta_bop {$_[0] ne $_[1]},
	"cmp"	=> 	meta_bop {$_[0] cmp $_[1]},
	"\&"	=> 	meta_bop {$_[0] & $_[1]},
	"^"	=> 	meta_bop {$_[0] ^ $_[1]},
	"|"	=>	meta_bop {$_[0] | $_[1]},
	"atan2"	=>	meta_bop {atan2 $_[0], $_[1]},

	"neg"	=>	meta_uop {-$_[0]},
	"!"	=>	meta_uop {!$_[0]},
	"~"	=>	meta_uop {~$_[0]},
	"cos"	=>	meta_uop {cos $_[0]},
	"sin"	=>	meta_uop {sin $_[0]},
	"exp"	=>	meta_uop {exp $_[0]},
	"abs"	=>	meta_uop {abs $_[0]},
	"log"	=>	meta_uop {log $_[0]},
	"sqrt"  =>	meta_uop {sqrt $_[0]},
	"bool"  =>	sub { croak "Can't use && or || in expression containing __" },

	#	"&()"	=>	sub { $_[0]->{impl} },

	#	"||"	=>	meta_bop {$_[0] || $_[1]},
	#	"&&"	=>	meta_bop {$_[0] && $_[1]},
	# fallback => 1,
	;
1;

__END__


