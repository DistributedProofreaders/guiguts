package NEXT;
$VERSION = '0.60';
use Carp;
use strict;

sub NEXT::ELSEWHERE::ancestors
{
	my @inlist = shift;
	my @outlist = ();
	while (my $next = shift @inlist) {
		push @outlist, $next;
		no strict 'refs';
		unshift @inlist, @{"$outlist[-1]::ISA"};
	}
	return @outlist;
}

sub NEXT::ELSEWHERE::ordered_ancestors
{
	my @inlist = shift;
	my @outlist = ();
	while (my $next = shift @inlist) {
		push @outlist, $next;
		no strict 'refs';
		push @inlist, @{"$outlist[-1]::ISA"};
	}
	return sort { $a->isa($b) ? -1
	            : $b->isa($a) ? +1
	            :                0 } @outlist;
}

sub AUTOLOAD
{
	my ($self) = @_;
	my $caller = (caller(1))[3]; 
	my $wanted = $NEXT::AUTOLOAD || 'NEXT::AUTOLOAD';
	undef $NEXT::AUTOLOAD;
	my ($caller_class, $caller_method) = $caller =~ m{(.*)::(.*)}g;
	my ($wanted_class, $wanted_method) = $wanted =~ m{(.*)::(.*)}g;
	croak "Can't call $wanted from $caller"
		unless $caller_method eq $wanted_method;

	local ($NEXT::NEXT{$self,$wanted_method}, $NEXT::SEEN) =
	      ($NEXT::NEXT{$self,$wanted_method}, $NEXT::SEEN);


	unless ($NEXT::NEXT{$self,$wanted_method}) {
		my @forebears =
			NEXT::ELSEWHERE::ancestors ref $self || $self,
						   $wanted_class;
		while (@forebears) {
			last if shift @forebears eq $caller_class
		}
		no strict 'refs';
		@{$NEXT::NEXT{$self,$wanted_method}} = 
			map { *{"${_}::$caller_method"}{CODE}||() } @forebears
				unless $wanted_method eq 'AUTOLOAD';
		@{$NEXT::NEXT{$self,$wanted_method}} = 
			map { (*{"${_}::AUTOLOAD"}{CODE}) ? "${_}::AUTOLOAD" : ()} @forebears
				unless @{$NEXT::NEXT{$self,$wanted_method}||[]};
		$NEXT::SEEN->{$self,*{$caller}{CODE}}++;
	}
	my $call_method = shift @{$NEXT::NEXT{$self,$wanted_method}};
	while ($wanted_class =~ /^NEXT\b.*\b(UNSEEN|DISTINCT)\b/
	       && defined $call_method
	       && $NEXT::SEEN->{$self,$call_method}++) {
		$call_method = shift @{$NEXT::NEXT{$self,$wanted_method}};
	}
	unless (defined $call_method) {
		return unless $wanted_class =~ /^NEXT:.*:ACTUAL/;
		(local $Carp::CarpLevel)++;
		croak qq(Can't locate object method "$wanted_method" ),
		      qq(via package "$caller_class");
	};
	return $self->$call_method(@_[1..$#_]) if ref $call_method eq 'CODE';
	no strict 'refs';
	($wanted_method=${$caller_class."::AUTOLOAD"}) =~ s/.*:://
		if $wanted_method eq 'AUTOLOAD';
	$$call_method = $caller_class."::NEXT::".$wanted_method;
	return $call_method->(@_);
}

no strict 'vars';
package NEXT::UNSEEN;		@ISA = 'NEXT';
package NEXT::DISTINCT;		@ISA = 'NEXT';
package NEXT::ACTUAL;		@ISA = 'NEXT';
package NEXT::ACTUAL::UNSEEN;	@ISA = 'NEXT';
package NEXT::ACTUAL::DISTINCT;	@ISA = 'NEXT';
package NEXT::UNSEEN::ACTUAL;	@ISA = 'NEXT';
package NEXT::DISTINCT::ACTUAL;	@ISA = 'NEXT';

package EVERY::LAST;		@ISA = 'EVERY';
package EVERY;			@ISA = 'NEXT';
sub AUTOLOAD
{
	my ($self) = @_;
	my $caller = (caller(1))[3]; 
	my $wanted = $EVERY::AUTOLOAD || 'EVERY::AUTOLOAD';
	undef $EVERY::AUTOLOAD;
	my ($wanted_class, $wanted_method) = $wanted =~ m{(.*)::(.*)}g;

	local $NEXT::ALREADY_IN_EVERY{$self,$wanted_method} =
	      $NEXT::ALREADY_IN_EVERY{$self,$wanted_method};

	return if $NEXT::ALREADY_IN_EVERY{$self,$wanted_method}++;
	
	my @forebears = NEXT::ELSEWHERE::ordered_ancestors ref $self || $self,
					                   $wanted_class;
	@forebears = reverse @forebears if $wanted_class =~ /\bLAST\b/;
	no strict 'refs';
	my %seen;
	my @every = map { my $sub = "${_}::$wanted_method";
		          !*{$sub}{CODE} || $seen{$sub}++ ? () : $sub
		        } @forebears
				unless $wanted_method eq 'AUTOLOAD';

	my $want = wantarray;
	if (@every) {
		if ($want) {
			return map {($_, [$self->$_(@_[1..$#_])])} @every;
		}
		elsif (defined $want) {
			return { map {($_, scalar($self->$_(@_[1..$#_])))}
				     @every
			       };
		}
		else {
			$self->$_(@_[1..$#_]) for @every;
			return;
		}
	}

	@every = map { my $sub = "${_}::AUTOLOAD";
		       !*{$sub}{CODE} || $seen{$sub}++ ? () : "${_}::AUTOLOAD"
		     } @forebears;
	if ($want) {
		return map { $$_ = ref($self)."::EVERY::".$wanted_method;
			     ($_, [$self->$_(@_[1..$#_])]);
			   } @every;
	}
	elsif (defined $want) {
		return { map { $$_ = ref($self)."::EVERY::".$wanted_method;
			       ($_, scalar($self->$_(@_[1..$#_])))
			     } @every
		       };
	}
	else {
		for (@every) {
			$$_ = ref($self)."::EVERY::".$wanted_method;
			$self->$_(@_[1..$#_]);
		}
		return;
	}
}


1;

__END__

