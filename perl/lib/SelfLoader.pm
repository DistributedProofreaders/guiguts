package SelfLoader;
# use Carp;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(AUTOLOAD);
$VERSION = "1.0904";
sub Version {$VERSION}
$DEBUG = 0;

my %Cache;      # private cache for all SelfLoader's client packages

# allow checking for valid ': attrlist' attachments
# (we use 'our' rather than 'my' here, due to the rather complex and buggy
# behaviour of lexicals with qr// and (??{$lex}) )
our $nested;
$nested = qr{ \( (?: (?> [^()]+ ) | (??{ $nested }) )* \) }x;
our $one_attr = qr{ (?> (?! \d) \w+ (?:$nested)? ) (?:\s*\:\s*|\s+(?!\:)) }x;
our $attr_list = qr{ \s* : \s* (?: $one_attr )* }x;

sub croak { require Carp; goto &Carp::croak }

AUTOLOAD {
    print STDERR "SelfLoader::AUTOLOAD for $AUTOLOAD\n" if $DEBUG;
    my $SL_code = $Cache{$AUTOLOAD};
    my $save = $@; # evals in both AUTOLOAD and _load_stubs can corrupt $@
    unless ($SL_code) {
        # Maybe this pack had stubs before __DATA__, and never initialized.
        # Or, this maybe an automatic DESTROY method call when none exists.
        $AUTOLOAD =~ m/^(.*)::/;
        SelfLoader->_load_stubs($1) unless exists $Cache{"${1}::<DATA"};
        $SL_code = $Cache{$AUTOLOAD};
        $SL_code = "sub $AUTOLOAD { }"
            if (!$SL_code and $AUTOLOAD =~ m/::DESTROY$/);
        croak "Undefined subroutine $AUTOLOAD" unless $SL_code;
    }
    print STDERR "SelfLoader::AUTOLOAD eval: $SL_code\n" if $DEBUG;

    eval $SL_code;
    if ($@) {
        $@ =~ s/ at .*\n//;
        croak $@;
    }
    $@ = $save;
    defined(&$AUTOLOAD) || die "SelfLoader inconsistency error";
    delete $Cache{$AUTOLOAD};
    goto &$AUTOLOAD
}

sub load_stubs { shift->_load_stubs((caller)[0]) }

sub _load_stubs {
    # $endlines is used by Devel::SelfStubber to capture lines after __END__
    my($self, $callpack, $endlines) = @_;
    my $fh = \*{"${callpack}::DATA"};
    my $currpack = $callpack;
    my($line,$name,@lines, @stubs, $protoype);

    print STDERR "SelfLoader::load_stubs($callpack)\n" if $DEBUG;
    croak("$callpack doesn't contain an __DATA__ token")
        unless fileno($fh);
    $Cache{"${currpack}::<DATA"} = 1;   # indicate package is cached

    local($/) = "\n";
    while(defined($line = <$fh>) and $line !~ m/^__END__/) {
	if ($line =~ m/^sub\s+([\w:]+)\s*((?:\([\\\$\@\%\&\*\;]*\))?(?:$attr_list)?)/) {
            push(@stubs, $self->_add_to_cache($name, $currpack, \@lines, $protoype));
            $protoype = $2;
            @lines = ($line);
            if (index($1,'::') == -1) {         # simple sub name
                $name = "${currpack}::$1";
            } else {                            # sub name with package
                $name = $1;
                $name =~ m/^(.*)::/;
                if (defined(&{"${1}::AUTOLOAD"})) {
                    \&{"${1}::AUTOLOAD"} == \&SelfLoader::AUTOLOAD ||
                        die 'SelfLoader Error: attempt to specify Selfloading',
                            " sub $name in non-selfloading module $1";
                } else {
                    $self->export($1,'AUTOLOAD');
                }
            }
        } elsif ($line =~ m/^package\s+([\w:]+)/) { # A package declared
            push(@stubs, $self->_add_to_cache($name, $currpack, \@lines, $protoype));
            $self->_package_defined($line);
            $name = '';
            @lines = ();
            $currpack = $1;
            $Cache{"${currpack}::<DATA"} = 1;   # indicate package is cached
            if (defined(&{"${1}::AUTOLOAD"})) {
                \&{"${1}::AUTOLOAD"} == \&SelfLoader::AUTOLOAD ||
                    die 'SelfLoader Error: attempt to specify Selfloading',
                        " package $currpack which already has AUTOLOAD";
            } else {
                $self->export($currpack,'AUTOLOAD');
            }
        } else {
            push(@lines,$line);
        }
    }
    if (defined($line) && $line =~ /^__END__/) { # __END__
        unless ($line =~ /^__END__\s*DATA/) {
            if ($endlines) {
                # Devel::SelfStubber would like us to capture the lines after
                # __END__ so it can write out the entire file
                @$endlines = <$fh>;
            }
            close($fh);
        }
    }
    push(@stubs, $self->_add_to_cache($name, $currpack, \@lines, $protoype));
    eval join('', @stubs) if @stubs;
}


sub _add_to_cache {
    my($self,$fullname,$pack,$lines, $protoype) = @_;
    return () unless $fullname;
    (require Carp), Carp::carp("Redefining sub $fullname")
      if exists $Cache{$fullname};
    $Cache{$fullname} = join('', "package $pack; ",@$lines);
    print STDERR "SelfLoader cached $fullname: $Cache{$fullname}" if $DEBUG;
    # return stub to be eval'd
    defined($protoype) ? "sub $fullname $protoype;" : "sub $fullname;"
}

sub _package_defined {}

1;
__END__

