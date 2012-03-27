package Win32::Clipboard;
#######################################################################
#
# Win32::Clipboard - Interaction with the Windows clipboard
#
# Version: 0.51
# Author: Aldo Calpini <dada@perl.it>
#
#######################################################################

require Exporter;       # to export the constants to the main:: space
require DynaLoader;     # to dynuhlode the module.

@ISA = qw( Exporter DynaLoader );
@EXPORT = qw(
	CF_TEXT
	CF_BITMAP
	CF_METAFILEPICT
	CF_SYLK
	CF_DIF
	CF_TIFF
	CF_OEMTEXT
	CF_DIB
	CF_PALETTE
	CF_PENDATA
	CF_RIFF
	CF_WAVE
	CF_UNICODETEXT
	CF_ENHMETAFILE
	CF_HDROP
	CF_LOCALE
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
        if ($! =~ /Invalid/) {
            $AutoLoader::AUTOLOAD = $AUTOLOAD;
            goto &AutoLoader::AUTOLOAD;
        } else {
            my ($pack, $file, $line) = caller;
            die "Win32::Clipboard::$constname is not defined, used at $file line $line.";
        }
    }
    eval "sub $AUTOLOAD { $val }";
    goto &$AUTOLOAD;
}


#######################################################################
# STATIC OBJECT PROPERTIES
#
$VERSION = "0.51";

#######################################################################
# FUNCTIONS
#

sub new {
    my($class, $value) = @_;
    my $self = "I'm the Clipboard!";
    Set($value) if defined($value);
    return bless(\$self);
}

sub Version {
    return $VERSION;
}

sub Get {
	if(    IsBitmap() ) { return GetBitmap(); }
	elsif( IsFiles()  ) { return GetFiles();  }
	else                { return GetText();   }
}

sub TIESCALAR {
	my $class = shift;
	my $value = shift;
	Set($value) if defined $value;
	my $self = "I'm the Clipboard!";
	return bless \$self, $class;
}

sub FETCH { Get() }
sub STORE { shift; Set(@_) }

sub DESTROY {
    my($self) = @_;
    undef $self;
    StopClipboardViewer();
}

END {
    StopClipboardViewer();
}

#######################################################################
# dynamically load in the Clipboard.pll module.
#

bootstrap Win32::Clipboard;

#######################################################################
# a little hack to use the module itself as a class.
#

sub main::Win32::Clipboard {
    my($value) = @_;
    my $self={};
    my $result = Win32::Clipboard::Set($value) if defined($value);
    return bless($self, "Win32::Clipboard");
}

1;

__END__

