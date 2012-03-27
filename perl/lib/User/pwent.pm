package User::pwent;

use 5.006;
our $VERSION = '1.00';

use strict;
use warnings;

use Config;
use Carp;

our(@EXPORT, @EXPORT_OK, %EXPORT_TAGS);
BEGIN {
    use Exporter   ();
    @EXPORT      = qw(getpwent getpwuid getpwnam getpw);
    @EXPORT_OK   = qw(
                        pw_has

                        $pw_name    $pw_passwd  $pw_uid  $pw_gid
                        $pw_gecos   $pw_dir     $pw_shell
                        $pw_expire  $pw_change  $pw_class
                        $pw_age
                        $pw_quota   $pw_comment
                        $pw_expire

                   );
    %EXPORT_TAGS = (
        FIELDS => [ grep(/^\$pw_/, @EXPORT_OK), @EXPORT ],
        ALL    => [ @EXPORT, @EXPORT_OK ],
    );
}
use vars grep /^\$pw_/, @EXPORT_OK;

#
# XXX: these mean somebody hacked this module's source
#      without understanding the underlying assumptions.
#
my $IE = "[INTERNAL ERROR]";

# Class::Struct forbids use of @ISA
sub import { goto &Exporter::import }

use Class::Struct qw(struct);
struct 'User::pwent' => [
    name    => '$',         # pwent[0]
    passwd  => '$',         # pwent[1]
    uid     => '$',         # pwent[2]
    gid     => '$',         # pwent[3]

    # you'll only have one/none of these three
    change  => '$',         # pwent[4]
    age     => '$',         # pwent[4]
    quota   => '$',         # pwent[4]

    # you'll only have one/none of these two
    comment => '$',         # pwent[5]
    class   => '$',         # pwent[5]

    # you might not have this one
    gecos   => '$',         # pwent[6]

    dir     => '$',         # pwent[7]
    shell   => '$',         # pwent[8]

    # you might not have this one
    expire  => '$',         # pwent[9]

];


# init our groks hash to be true if the built platform knew how
# to do each struct pwd field that perl can ever under any circumstances
# know about.  we do not use /^pw_?/, but just the tails.
sub _feature_init {
    our %Groks;         # whether build system knew how to do this feature
    for my $feep ( qw{
                         pwage      pwchange   pwclass    pwcomment
                         pwexpire   pwgecos    pwpasswd   pwquota
                     }
                 )
    {
        my $short = $feep =~ /^pw(.*)/
                  ? $1
                  : do {
                        # not cluck, as we know we called ourselves,
                        # and a confession is probably imminent anyway
                        warn("$IE $feep is a funny struct pwd field");
                        $feep;
                    };

        exists $Config{ "d_" . $feep }
            || confess("$IE Configure doesn't d_$feep");
        $Groks{$short} = defined $Config{ "d_" . $feep };
    }
    # assume that any that are left are always there
    for my $feep (grep /^\$pw_/s, @EXPORT_OK) {
        $feep =~ /^\$pw_(.*)/;
        $Groks{$1} = 1 unless defined $Groks{$1};
    }
}

# With arguments, reports whether one or more fields are all implemented
# in the build machine's struct pwd pw_*.  May be whitespace separated.
# We do not use /^pw_?/, just the tails.
#
# Without arguments, returns the list of fields implemented on build
# machine, space separated in scalar context.
#
# Takes exception to being asked whether this machine's struct pwd has
# a field that Perl never knows how to provide under any circumstances.
# If the module does this idiocy to itself, the explosion is noisier.
#
sub pw_has {
    our %Groks;         # whether build system knew how to do this feature
    my $cando = 1;
    my $sploder = caller() ne __PACKAGE__
                    ? \&croak
                    : sub { confess("$IE @_") };
    if (@_ == 0) {
        my @valid = sort grep { $Groks{$_} } keys %Groks;
        return wantarray ? @valid : "@valid";
    }
    for my $feep (map { split } @_) {
        defined $Groks{$feep}
            || $sploder->("$feep is never a valid struct pwd field");
        $cando &&= $Groks{$feep};
    }
    return $cando;
}

sub _populate (@) {
    return unless @_;
    my $pwob = new();

    # Any that haven't been pw_had are assumed on "all" platforms of
    # course, this may not be so, but you can't get here otherwise,
    # since the underlying core call already took exception to your
    # impudence.

    $pw_name    = $pwob->name   ( $_[0] );
    $pw_passwd  = $pwob->passwd ( $_[1] )   if pw_has("passwd");
    $pw_uid     = $pwob->uid    ( $_[2] );
    $pw_gid     = $pwob->gid    ( $_[3] );

    if (pw_has("change")) {
        $pw_change      = $pwob->change ( $_[4] );
    }
    elsif (pw_has("age")) {
        $pw_age         = $pwob->age    ( $_[4] );
    }
    elsif (pw_has("quota")) {
        $pw_quota       = $pwob->quota  ( $_[4] );
    }

    if (pw_has("class")) {
        $pw_class       = $pwob->class  ( $_[5] );
    }
    elsif (pw_has("comment")) {
        $pw_comment     = $pwob->comment( $_[5] );
    }

    $pw_gecos   = $pwob->gecos  ( $_[6] ) if pw_has("gecos");

    $pw_dir     = $pwob->dir    ( $_[7] );
    $pw_shell   = $pwob->shell  ( $_[8] );

    $pw_expire  = $pwob->expire ( $_[9] ) if pw_has("expire");

    return $pwob;
}

sub getpwent ( ) { _populate(CORE::getpwent()) }
sub getpwnam ($) { _populate(CORE::getpwnam(shift)) }
sub getpwuid ($) { _populate(CORE::getpwuid(shift)) }
sub getpw    ($) { ($_[0] =~ /^\d+\z/s) ? &getpwuid : &getpwnam }

_feature_init();

1;
__END__

