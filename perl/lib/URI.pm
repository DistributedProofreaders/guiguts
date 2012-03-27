package URI;

use strict;
use vars qw($VERSION);
$VERSION = "1.27"; # $Date: 2003/10/06 10:38:31 $

use vars qw($ABS_REMOTE_LEADING_DOTS $ABS_ALLOW_RELATIVE_SCHEME);

my %implements;  # mapping from scheme to implementor class

# Some "official" character classes

use vars qw($reserved $mark $unreserved $uric $scheme_re);
$reserved   = q(;/?:@&=+$,[]);
$mark       = q(-_.!~*'());                                    #'; emacs
$unreserved = "A-Za-z0-9\Q$mark\E";
$uric       = quotemeta($reserved) . $unreserved . "%";

$scheme_re  = '[a-zA-Z][a-zA-Z0-9.+\-]*';

use Carp ();
use URI::Escape ();

use overload ('""'     => sub { ${$_[0]} },
	      '=='     => sub { overload::StrVal($_[0]) eq
                                overload::StrVal($_[1])
                              },
              fallback => 1,
             );

sub new
{
    my($class, $uri, $scheme) = @_;

    $uri = defined ($uri) ? "$uri" : "";   # stringify
    # Get rid of potential wrapping
    $uri =~ s/^<(?:URL:)?(.*)>$/$1/;  # 
    $uri =~ s/^"(.*)"$/$1/;
    $uri =~ s/^\s+//;
    $uri =~ s/\s+$//;

    my $impclass;
    if ($uri =~ m/^($scheme_re):/so) {
	$scheme = $1;
    }
    else {
	if (($impclass = ref($scheme))) {
	    $scheme = $scheme->scheme;
	}
	elsif ($scheme && $scheme =~ m/^($scheme_re)(?::|$)/o) {
	    $scheme = $1;
        }
    }
    $impclass ||= implementor($scheme) ||
	do {
	    require URI::_foreign;
	    $impclass = 'URI::_foreign';
	};

    return $impclass->_init($uri, $scheme);
}


sub new_abs
{
    my($class, $uri, $base) = @_;
    $uri = $class->new($uri, $base);
    $uri->abs($base);
}


sub _init
{
    my $class = shift;
    my($str, $scheme) = @_;
    $str =~ s/([^$uric\#])/$URI::Escape::escapes{$1}/go;
    $str = "$scheme:$str" unless $str =~ /^$scheme_re:/o ||
                                 $class->_no_scheme_ok;
    my $self = bless \$str, $class;
    $self;
}


sub implementor
{
    my($scheme, $impclass) = @_;
    if (!$scheme || $scheme !~ /\A$scheme_re\z/o) {
	require URI::_generic;
	return "URI::_generic";
    }

    $scheme = lc($scheme);

    if ($impclass) {
	# Set the implementor class for a given scheme
        my $old = $implements{$scheme};
        $impclass->_init_implementor($scheme);
        $implements{$scheme} = $impclass;
        return $old;
    }

    my $ic = $implements{$scheme};
    return $ic if $ic;

    # scheme not yet known, look for internal or
    # preloaded (with 'use') implementation
    $ic = "URI::$scheme";  # default location

    # turn scheme into a valid perl identifier by a simple tranformation...
    $ic =~ s/\+/_P/g;
    $ic =~ s/\./_O/g;
    $ic =~ s/\-/_/g;

    no strict 'refs';
    # check we actually have one for the scheme:
    unless (@{"${ic}::ISA"}) {
        # Try to load it
        eval "require $ic";
        die $@ if $@ && $@ !~ /Can\'t locate.*in \@INC/;
        return unless @{"${ic}::ISA"};
    }

    $ic->_init_implementor($scheme);
    $implements{$scheme} = $ic;
    $ic;
}


sub _init_implementor
{
    my($class, $scheme) = @_;
    # Remember that one implementor class may actually
    # serve to implement several URI schemes.
}


sub clone
{
    my $self = shift;
    my $other = $$self;
    bless \$other, ref $self;
}


sub _no_scheme_ok { 0 }

sub _scheme
{
    my $self = shift;

    unless (@_) {
	return unless $$self =~ /^($scheme_re):/o;
	return $1;
    }

    my $old;
    my $new = shift;
    if (defined($new) && length($new)) {
	Carp::croak("Bad scheme '$new'") unless $new =~ /^$scheme_re$/o;
	$old = $1 if $$self =~ s/^($scheme_re)://o;
	my $newself = URI->new("$new:$$self");
	$$self = $$newself; 
	bless $self, ref($newself);
    }
    else {
	if ($self->_no_scheme_ok) {
	    $old = $1 if $$self =~ s/^($scheme_re)://o;
	    Carp::carp("Oops, opaque part now look like scheme")
		if $^W && $$self =~ m/^$scheme_re:/o
	}
	else {
	    $old = $1 if $$self =~ m/^($scheme_re):/o;
	}
    }

    return $old;
}

sub scheme
{
    my $scheme = shift->_scheme(@_);
    return unless defined $scheme;
    lc($scheme);
}


sub opaque
{
    my $self = shift;

    unless (@_) {
	$$self =~ /^(?:$scheme_re:)?([^\#]*)/o or die;
	return $1;
    }

    $$self =~ /^($scheme_re:)?    # optional scheme
	        ([^\#]*)          # opaque
                (\#.*)?           # optional fragment
              $/sx or die;

    my $old_scheme = $1;
    my $old_opaque = $2;
    my $old_frag   = $3;

    my $new_opaque = shift;
    $new_opaque = "" unless defined $new_opaque;
    $new_opaque =~ s/([^$uric])/$URI::Escape::escapes{$1}/go;

    $$self = defined($old_scheme) ? $old_scheme : "";
    $$self .= $new_opaque;
    $$self .= $old_frag if defined $old_frag;

    $old_opaque;
}

*path = \&opaque;  # alias


sub fragment
{
    my $self = shift;
    unless (@_) {
	return unless $$self =~ /\#(.*)/s;
	return $1;
    }

    my $old;
    $old = $1 if $$self =~ s/\#(.*)//s;

    my $new_frag = shift;
    if (defined $new_frag) {
	$new_frag =~ s/([^$uric])/$URI::Escape::escapes{$1}/go;
	$$self .= "#$new_frag";
    }
    $old;
}


sub as_string
{
    my $self = shift;
    $$self;
}


sub canonical
{
    my $self = shift;

    # Make sure scheme is lowercased
    my $scheme = $self->_scheme || "";
    my $uc_scheme = $scheme =~ /[A-Z]/;
    my $lc_esc    = $$self =~ /%(?:[a-f][a-fA-F0-9]|[A-F0-9][a-f])/;
    if ($uc_scheme || $lc_esc) {
	my $other = $self->clone;
	$other->_scheme(lc $scheme) if $uc_scheme;
	$$other =~ s/(%(?:[a-f][a-fA-F0-9]|[A-F0-9][a-f]))/uc($1)/ge
	    if $lc_esc;
	return $other;
    }
    $self;
}

# Compare two URIs, subclasses will provide a more correct implementation
sub eq {
    my($self, $other) = @_;
    $self  = URI->new($self, $other) unless ref $self;
    $other = URI->new($other, $self) unless ref $other;
    ref($self) eq ref($other) &&                # same class
	$self->canonical->as_string eq $other->canonical->as_string;
}

# generic-URI transformation methods
sub abs { $_[0]; }
sub rel { $_[0]; }

# help out Storable
sub STORABLE_freeze {
       my($self, $cloning) = @_;
       return $$self;
}

sub STORABLE_thaw {
       my($self, $cloning, $str) = @_;
       $$self = $str;
}

1;

__END__

