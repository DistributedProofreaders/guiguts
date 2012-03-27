package Safe;

use 5.003_11;
use strict;

$Safe::VERSION = "2.10";

# *** Don't declare any lexicals above this point ***
#
# This function should return a closure which contains an eval that can't
# see any lexicals in scope (apart from __ExPr__ which is unavoidable)

sub lexless_anon_sub {
		 # $_[0] is package;
		 # $_[1] is strict flag;
    my $__ExPr__ = $_[2];   # must be a lexical to create the closure that
			    # can be used to pass the value into the safe
			    # world

    # Create anon sub ref in root of compartment.
    # Uses a closure (on $__ExPr__) to pass in the code to be executed.
    # (eval on one line to keep line numbers as expected by caller)
    eval sprintf
    'package %s; %s strict; sub { @_=(); eval q[my $__ExPr__;] . $__ExPr__; }',
		$_[0], $_[1] ? 'use' : 'no';
}

use Carp;

use Opcode 1.01, qw(
    opset opset_to_ops opmask_add
    empty_opset full_opset invert_opset verify_opset
    opdesc opcodes opmask define_optag opset_to_hex
);

*ops_to_opset = \&opset;   # Temporary alias for old Penguins


my $default_root  = 0;
my $default_share = ['*_']; #, '*main::'];

sub new {
    my($class, $root, $mask) = @_;
    my $obj = {};
    bless $obj, $class;

    if (defined($root)) {
	croak "Can't use \"$root\" as root name"
	    if $root =~ /^main\b/ or $root !~ /^\w[:\w]*$/;
	$obj->{Root}  = $root;
	$obj->{Erase} = 0;
    }
    else {
	$obj->{Root}  = "Safe::Root".$default_root++;
	$obj->{Erase} = 1;
    }

    # use permit/deny methods instead till interface issues resolved
    # XXX perhaps new Safe 'Root', mask => $mask, foo => bar, ...;
    croak "Mask parameter to new no longer supported" if defined $mask;
    $obj->permit_only(':default');

    # We must share $_ and @_ with the compartment or else ops such
    # as split, length and so on won't default to $_ properly, nor
    # will passing argument to subroutines work (via @_). In fact,
    # for reasons I don't completely understand, we need to share
    # the whole glob *_ rather than $_ and @_ separately, otherwise
    # @_ in non default packages within the compartment don't work.
    $obj->share_from('main', $default_share);
    Opcode::_safe_pkg_prep($obj->{Root}) if($Opcode::VERSION > 1.04);
    return $obj;
}

sub DESTROY {
    my $obj = shift;
    $obj->erase('DESTROY') if $obj->{Erase};
}

sub erase {
    my ($obj, $action) = @_;
    my $pkg = $obj->root();
    my ($stem, $leaf);

    no strict 'refs';
    $pkg = "main::$pkg\::";	# expand to full symbol table name
    ($stem, $leaf) = $pkg =~ m/(.*::)(\w+::)$/;

    # The 'my $foo' is needed! Without it you get an
    # 'Attempt to free unreferenced scalar' warning!
    my $stem_symtab = *{$stem}{HASH};

    #warn "erase($pkg) stem=$stem, leaf=$leaf";
    #warn " stem_symtab hash ".scalar(%$stem_symtab)."\n";
	# ", join(', ', %$stem_symtab),"\n";

#    delete $stem_symtab->{$leaf};

    my $leaf_glob   = $stem_symtab->{$leaf};
    my $leaf_symtab = *{$leaf_glob}{HASH};
#    warn " leaf_symtab ", join(', ', %$leaf_symtab),"\n";
    %$leaf_symtab = ();
    #delete $leaf_symtab->{'__ANON__'};
    #delete $leaf_symtab->{'foo'};
    #delete $leaf_symtab->{'main::'};
#    my $foo = undef ${"$stem\::"}{"$leaf\::"};

    if ($action and $action eq 'DESTROY') {
        delete $stem_symtab->{$leaf};
    } else {
        $obj->share_from('main', $default_share);
    }
    1;
}


sub reinit {
    my $obj= shift;
    $obj->erase;
    $obj->share_redo;
}

sub root {
    my $obj = shift;
    croak("Safe root method now read-only") if @_;
    return $obj->{Root};
}


sub mask {
    my $obj = shift;
    return $obj->{Mask} unless @_;
    $obj->deny_only(@_);
}

# v1 compatibility methods
sub trap   { shift->deny(@_)   }
sub untrap { shift->permit(@_) }

sub deny {
    my $obj = shift;
    $obj->{Mask} |= opset(@_);
}
sub deny_only {
    my $obj = shift;
    $obj->{Mask} = opset(@_);
}

sub permit {
    my $obj = shift;
    # XXX needs testing
    $obj->{Mask} &= invert_opset opset(@_);
}
sub permit_only {
    my $obj = shift;
    $obj->{Mask} = invert_opset opset(@_);
}


sub dump_mask {
    my $obj = shift;
    print opset_to_hex($obj->{Mask}),"\n";
}



sub share {
    my($obj, @vars) = @_;
    $obj->share_from(scalar(caller), \@vars);
}

sub share_from {
    my $obj = shift;
    my $pkg = shift;
    my $vars = shift;
    my $no_record = shift || 0;
    my $root = $obj->root();
    croak("vars not an array ref") unless ref $vars eq 'ARRAY';
    no strict 'refs';
    # Check that 'from' package actually exists
    croak("Package \"$pkg\" does not exist")
	unless keys %{"$pkg\::"};
    my $arg;
    foreach $arg (@$vars) {
	# catch some $safe->share($var) errors:
	croak("'$arg' not a valid symbol table name")
	    unless $arg =~ /^[\$\@%*&]?\w[\w:]*$/
	    	or $arg =~ /^\$\W$/;
	my ($var, $type);
	$type = $1 if ($var = $arg) =~ s/^(\W)//;
	# warn "share_from $pkg $type $var";
	*{$root."::$var"} = (!$type)       ? \&{$pkg."::$var"}
			  : ($type eq '&') ? \&{$pkg."::$var"}
			  : ($type eq '$') ? \${$pkg."::$var"}
			  : ($type eq '@') ? \@{$pkg."::$var"}
			  : ($type eq '%') ? \%{$pkg."::$var"}
			  : ($type eq '*') ?  *{$pkg."::$var"}
			  : croak(qq(Can't share "$type$var" of unknown type));
    }
    $obj->share_record($pkg, $vars) unless $no_record or !$vars;
}

sub share_record {
    my $obj = shift;
    my $pkg = shift;
    my $vars = shift;
    my $shares = \%{$obj->{Shares} ||= {}};
    # Record shares using keys of $obj->{Shares}. See reinit.
    @{$shares}{@$vars} = ($pkg) x @$vars if @$vars;
}
sub share_redo {
    my $obj = shift;
    my $shares = \%{$obj->{Shares} ||= {}};
    my($var, $pkg);
    while(($var, $pkg) = each %$shares) {
	# warn "share_redo $pkg\:: $var";
	$obj->share_from($pkg,  [ $var ], 1);
    }
}
sub share_forget {
    delete shift->{Shares};
}

sub varglob {
    my ($obj, $var) = @_;
    no strict 'refs';
    return *{$obj->root()."::$var"};
}


sub reval {
    my ($obj, $expr, $strict) = @_;
    my $root = $obj->{Root};

    my $evalsub = lexless_anon_sub($root,$strict, $expr);
    return Opcode::_safe_call_sv($root, $obj->{Mask}, $evalsub);
}

sub rdo {
    my ($obj, $file) = @_;
    my $root = $obj->{Root};

    my $evalsub = eval
	    sprintf('package %s; sub { @_ = (); do $file }', $root);
    return Opcode::_safe_call_sv($root, $obj->{Mask}, $evalsub);
}


1;

__END__

