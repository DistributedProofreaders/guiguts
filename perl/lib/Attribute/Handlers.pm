package Attribute::Handlers;
use 5.006;
use Carp;
use warnings;
$VERSION = '0.78';
# $DB::single=1;

my %symcache;
sub findsym {
	my ($pkg, $ref, $type) = @_;
	return $symcache{$pkg,$ref} if $symcache{$pkg,$ref};
	$type ||= ref($ref);
	my $found;
        foreach my $sym ( values %{$pkg."::"} ) {
            return $symcache{$pkg,$ref} = \$sym
		if *{$sym}{$type} && *{$sym}{$type} == $ref;
	}
}

my %validtype = (
	VAR	=> [qw[SCALAR ARRAY HASH]],
        ANY	=> [qw[SCALAR ARRAY HASH CODE]],
        ""	=> [qw[SCALAR ARRAY HASH CODE]],
        SCALAR	=> [qw[SCALAR]],
        ARRAY	=> [qw[ARRAY]],
        HASH	=> [qw[HASH]],
        CODE	=> [qw[CODE]],
);
my %lastattr;
my @declarations;
my %raw;
my %phase;
my %sigil = (SCALAR=>'$', ARRAY=>'@', HASH=>'%');
my $global_phase = 0;
my %global_phases = (
	BEGIN	=> 0,
	CHECK	=> 1,
	INIT	=> 2,
	END	=> 3,
);
my @global_phases = qw(BEGIN CHECK INIT END);

sub _usage_AH_ {
	croak "Usage: use $_[0] autotie => {AttrName => TieClassName,...}";
}

my $qual_id = qr/^[_a-z]\w*(::[_a-z]\w*)*$/i;

sub import {
    my $class = shift @_;
    return unless $class eq "Attribute::Handlers";
    while (@_) {
	my $cmd = shift;
        if ($cmd =~ /^autotie((?:ref)?)$/) {
	    my $tiedata = ($1 ? '$ref, ' : '') . '@$data';
            my $mapping = shift;
	    _usage_AH_ $class unless ref($mapping) eq 'HASH';
	    while (my($attr, $tieclass) = each %$mapping) {
                $tieclass =~ s/^([_a-z]\w*(::[_a-z]\w*)*)(.*)/$1/is;
		my $args = $3||'()';
		_usage_AH_ $class unless $attr =~ $qual_id
		                 && $tieclass =~ $qual_id
		                 && eval "use base $tieclass; 1";
	        if ($tieclass->isa('Exporter')) {
		    local $Exporter::ExportLevel = 2;
		    $tieclass->import(eval $args);
	        }
		$attr =~ s/__CALLER__/caller(1)/e;
		$attr = caller()."::".$attr unless $attr =~ /::/;
	        eval qq{
	            sub $attr : ATTR(VAR) {
			my (\$ref, \$data) = \@_[2,4];
			my \$was_arrayref = ref \$data eq 'ARRAY';
			\$data = [ \$data ] unless \$was_arrayref;
			my \$type = ref(\$ref)||"value (".(\$ref||"<undef>").")";
			 (\$type eq 'SCALAR')? tie \$\$ref,'$tieclass',$tiedata
			:(\$type eq 'ARRAY') ? tie \@\$ref,'$tieclass',$tiedata
			:(\$type eq 'HASH')  ? tie \%\$ref,'$tieclass',$tiedata
			: die "Can't autotie a \$type\n"
	            } 1
	        } or die "Internal error: $@";
	    }
        }
        else {
            croak "Can't understand $_"; 
        }
    }
}
sub _resolve_lastattr {
	return unless $lastattr{ref};
	my $sym = findsym @lastattr{'pkg','ref'}
		or die "Internal error: $lastattr{pkg} symbol went missing";
	my $name = *{$sym}{NAME};
	warn "Declaration of $name attribute in package $lastattr{pkg} may clash with future reserved word\n"
		if $^W and $name !~ /[A-Z]/;
	foreach ( @{$validtype{$lastattr{type}}} ) {
		*{"$lastattr{pkg}::_ATTR_${_}_${name}"} = $lastattr{ref};
	}
	%lastattr = ();
}

sub AUTOLOAD {
	my ($class) = $AUTOLOAD =~ m/(.*)::/g;
	$AUTOLOAD =~ m/_ATTR_(.*?)_(.*)/ or
	    croak "Can't locate class method '$AUTOLOAD' via package '$class'";
	croak "Attribute handler '$2' doesn't handle $1 attributes";
}

sub DESTROY {}

my $builtin = qr/lvalue|method|locked|unique|shared/;

sub _gen_handler_AH_() {
	return sub {
	    _resolve_lastattr;
	    my ($pkg, $ref, @attrs) = @_;
	    foreach (@attrs) {
		my ($attr, $data) = /^([a-z_]\w*)(?:[(](.*)[)])?$/is or next;
		if ($attr eq 'ATTR') {
			$data ||= "ANY";
			$raw{$ref} = $data =~ s/\s*,?\s*RAWDATA\s*,?\s*//;
			$phase{$ref}{BEGIN} = 1
				if $data =~ s/\s*,?\s*(BEGIN)\s*,?\s*//;
			$phase{$ref}{INIT} = 1
				if $data =~ s/\s*,?\s*(INIT)\s*,?\s*//;
			$phase{$ref}{END} = 1
				if $data =~ s/\s*,?\s*(END)\s*,?\s*//;
			$phase{$ref}{CHECK} = 1
				if $data =~ s/\s*,?\s*(CHECK)\s*,?\s*//
				|| ! keys %{$phase{$ref}};
			# Added for cleanup to not pollute next call.
			(%lastattr = ()),
			croak "Can't have two ATTR specifiers on one subroutine"
				if keys %lastattr;
			croak "Bad attribute type: ATTR($data)"
				unless $validtype{$data};
			%lastattr=(pkg=>$pkg,ref=>$ref,type=>$data);
		}
		else {
			my $type = ref $ref;
			my $handler = $pkg->can("_ATTR_${type}_${attr}");
			next unless $handler;
		        my $decl = [$pkg, $ref, $attr, $data,
				    $raw{$handler}, $phase{$handler}];
			foreach my $gphase (@global_phases) {
			    _apply_handler_AH_($decl,$gphase)
				if $global_phases{$gphase} <= $global_phase;
			}
			if ($global_phase != 0) {
				# if _gen_handler_AH_ is being called after 
				# CHECK it's for a lexical, so make sure
				# it didn't want to run anything later
			
				local $Carp::CarpLevel = 2;
				carp "Won't be able to apply END handler"
					if $phase{$handler}{END};
			}
			else {
				push @declarations, $decl
			}
		}
		$_ = undef;
	    }
	    return grep {defined && !/$builtin/} @attrs;
	}
}

*{"MODIFY_${_}_ATTRIBUTES"} = _gen_handler_AH_ foreach @{$validtype{ANY}};
push @UNIVERSAL::ISA, 'Attribute::Handlers'
	unless grep /^Attribute::Handlers$/, @UNIVERSAL::ISA;

sub _apply_handler_AH_ {
	my ($declaration, $phase) = @_;
	my ($pkg, $ref, $attr, $data, $raw, $handlerphase) = @$declaration;
	return unless $handlerphase->{$phase};
	# print STDERR "Handling $attr on $ref in $phase with [$data]\n";
	my $type = ref $ref;
	my $handler = "_ATTR_${type}_${attr}";
	my $sym = findsym($pkg, $ref);
	$sym ||= $type eq 'CODE' ? 'ANON' : 'LEXICAL';
	no warnings;
	my $evaled = !$raw && eval("package $pkg; no warnings;
				    local \$SIG{__WARN__}=sub{die}; [$data]");
	$data = ($evaled && $data =~ /^\s*\[/)  ? [$evaled]
	      : ($evaled)			? $evaled
	      :					  [$data];
	$pkg->$handler($sym,
		       (ref $sym eq 'GLOB' ? *{$sym}{ref $ref}||$ref : $ref),
		       $attr,
		       (@$data>1? $data : $data->[0]),
		       $phase,
		      );
	return 1;
}

{
        no warnings 'void';
        CHECK {
               $global_phase++;
               _resolve_lastattr;
               _apply_handler_AH_($_,'CHECK') foreach @declarations;
        }

        INIT {
                $global_phase++;
                _apply_handler_AH_($_,'INIT') foreach @declarations
        }
}

END { $global_phase++; _apply_handler_AH_($_,'END') foreach @declarations }

1;
__END__

