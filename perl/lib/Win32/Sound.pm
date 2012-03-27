#######################################################################
#
# Win32::Sound - An extension to play with Windows sounds
# 
# Author: Aldo Calpini <dada@divinf.it>
# Version: 0.47
# Info:
#       http://www.divinf.it/dada/perl
#       http://www.perl.com/CPAN/authors/Aldo_Calpini
#
#######################################################################
# Version history: 
# 0.01 (19 Nov 1996) file created
# 0.03 (08 Apr 1997) first release
# 0.30 (20 Oct 1998) added Volume/Format/Devices/DeviceInfo
#                    (thanks Dave Roth!)
# 0.40 (16 Mar 1999) added the WaveOut object
# 0.45 (09 Apr 1999) added $! support, documentation et goodies
# 0.46 (25 Sep 1999) fixed small bug in DESTROY, wo was used without being
#		     initialized (Gurusamy Sarathy <gsar@activestate.com>)
# 0.47 (22 May 2000) support for passing Unicode string to Play()
#                    (Doug Lankshear <dougl@activestate.com>)

package Win32::Sound;

# See the bottom of this file for the POD documentation.  
# Search for the string '=head'.

require Exporter;       # to export the constants to the main:: space
require DynaLoader;     # to dynuhlode the module.

@ISA= qw( Exporter DynaLoader );
@EXPORT = qw(
    SND_ASYNC
    SND_NODEFAULT
    SND_LOOP
    SND_NOSTOP
);

#######################################################################
# This AUTOLOAD is used to 'autoload' constants from the constant()
# XS function.  If a constant is not found then control is passed
# to the AUTOLOAD in AutoLoader.
#

sub AUTOLOAD {
    my($constname);
    ($constname = $AUTOLOAD) =~ s/.*:://;
    #reset $! to zero to reset any current errors.
    local $! = 0;
    my $val = constant($constname, @_ ? $_[0] : 0);
    if ($! != 0) {

    # [dada] This results in an ugly Autoloader error

    #if ($! =~ /Invalid/) {
    #    $AutoLoader::AUTOLOAD = $AUTOLOAD;
    #    goto &AutoLoader::AUTOLOAD;
    #} else {
    
    # [dada] ... I prefer this one :)

        ($pack, $file, $line) = caller;
        undef $pack; # [dada] and get rid of "used only once" warning...
        die "Win32::Sound::$constname is not defined, used at $file line $line.";

    #}
    }
    eval "sub $AUTOLOAD { $val }";
    goto &$AUTOLOAD;
}


#######################################################################
# STATIC OBJECT PROPERTIES
#
$VERSION="0.47"; 
undef unless $VERSION; # [dada] to avoid "possible typo" warning

#######################################################################
# METHODS
#

sub Version { $VERSION }

sub Volume {
    my(@in) = @_;
    # Allows '0%'..'100%'   
    $in[0] =~ s{ ([\d\.]+)%$ }{ int($1*100/255) }ex if defined $in[0];
    $in[1] =~ s{ ([\d\.]+)%$ }{ int($1*100/255) }ex if defined $in[1];
    _Volume(@in);
}

#######################################################################
# dynamically load in the Sound.dll module.
#

bootstrap Win32::Sound;

#######################################################################
# Win32::Sound::WaveOut
#

package Win32::Sound::WaveOut;

sub new {
    my($class, $one, $two, $three) = @_;
    my $self = {};
    bless($self, $class);
    
    if($one !~ /^\d+$/ 
    and not defined($two)
    and not defined($three)) {
        # Looks like a file
        $self->Open($one);
    } else {
        # Default format if not given
        $self->{samplerate} = ($one   or 44100);
        $self->{bits}       = ($two   or 16);
        $self->{channels}   = ($three or 2);
        $self->OpenDevice();
    }
    return $self;
}

sub Volume {
    my(@in) = @_;
    # Allows '0%'..'100%'   
    $in[0] =~ s{ ([\d\.]+)%$ }{ int($1*255/100) }ex if defined $in[0];
    $in[1] =~ s{ ([\d\.]+)%$ }{ int($1*255/100) }ex if defined $in[1];
    _Volume(@in);
}

sub Pitch {
    my($self, $pitch) = @_;
    my($int, $frac);
    if(defined($pitch)) {
        $pitch =~ /(\d+).?(\d+)?/;
        $int = $1;
        $frac = $2 or 0;
        $int = $int << 16;
        $frac = eval("0.$frac * 65536");
        $pitch = $int + $frac;
        return _Pitch($self, $pitch);
    } else {
        $pitch = _Pitch($self);
        $int = ($pitch & 0xFFFF0000) >> 16;
        $frac = $pitch & 0x0000FFFF;
        return eval("$int.$frac");
    }
}

sub PlaybackRate {
    my($self, $rate) = @_;
    my($int, $frac);
    if(defined($rate)) {
        $rate =~ /(\d+).?(\d+)?/;
        $int = $1;
        $frac = $2 or 0;
        $int = $int << 16;
        $frac = eval("0.$frac * 65536");
        $rate = $int + $frac;
        return _PlaybackRate($self, $rate);
    } else {
        $rate = _PlaybackRate($self);
        $int = ($rate & 0xFFFF0000) >> 16;
        $frac = $rate & 0x0000FFFF;
        return eval("$int.$frac");
    }
}

# Preloaded methods go here.

#Currently Autoloading is not implemented in Perl for win32
# Autoload methods go after __END__, and are processed by the autosplit program.

1;
__END__



