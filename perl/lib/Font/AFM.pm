# This -*- perl -*-  module is a simple parser for Adobe Font Metrics files.
# $Id: AFM.pm,v 1.18 1999/01/30 11:04:36 aas Exp $

package Font::AFM;

#-------perl resumes here--------------------------------------------

use Carp;
use strict;
use vars qw($VERSION @ISOLatin1Encoding);

$VERSION = sprintf("%d.%02d", q$Revision: 1.18 $ =~ /(\d+)\.(\d+)/);


# The metrics_path is used to locate metrics files
#
my $metrics_path = $ENV{METRICS} ||
    "/usr/lib/afm:/usr/local/lib/afm:/usr/openwin/lib/fonts/afm/:.";
my @metrics_path = split(/:/, $metrics_path);
foreach (@metrics_path) { s,/$,, }    # reove trailing slashes

@ISOLatin1Encoding = qw(
 .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef
 .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef
 .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef
 .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef space
 exclam quotedbl numbersign dollar percent ampersand quoteright
 parenleft parenright asterisk plus comma minus period slash zero one
 two three four five six seven eight nine colon semicolon less equal
 greater question at A B C D E F G H I J K L M N O P Q R S
 T U V W X Y Z bracketleft backslash bracketright asciicircum
 underscore quoteleft a b c d e f g h i j k l m n o p q r s
 t u v w x y z braceleft bar braceright asciitilde .notdef .notdef
 .notdef .notdef .notdef .notdef .notdef .notdef .notdef .notdef
 .notdef .notdef .notdef .notdef .notdef .notdef .notdef dotlessi grave
 acute circumflex tilde macron breve dotaccent dieresis .notdef ring
 cedilla .notdef hungarumlaut ogonek caron space exclamdown cent
 sterling currency yen brokenbar section dieresis copyright ordfeminine
 guillemotleft logicalnot hyphen registered macron degree plusminus
 twosuperior threesuperior acute mu paragraph periodcentered cedilla
 onesuperior ordmasculine guillemotright onequarter onehalf threequarters
 questiondown Agrave Aacute Acircumflex Atilde Adieresis Aring AE
 Ccedilla Egrave Eacute Ecircumflex Edieresis Igrave Iacute Icircumflex
 Idieresis Eth Ntilde Ograve Oacute Ocircumflex Otilde Odieresis
 multiply Oslash Ugrave Uacute Ucircumflex Udieresis Yacute Thorn
 germandbls agrave aacute acircumflex atilde adieresis aring ae
 ccedilla egrave eacute ecircumflex edieresis igrave iacute icircumflex
 idieresis eth ntilde ograve oacute ocircumflex otilde odieresis divide
 oslash ugrave uacute ucircumflex udieresis yacute thorn ydieresis
);


# Creates a new Font::AFM object.  Pass it the name of the font as parameter.
# Synopisis:
#
#    $h = new Font::AFM "Helvetica";
#

sub new
{
   my($class, $fontname) = @_;
   my $file;
   $fontname =~ s/\.afm$//;
   if ($^O eq 'VMS') {
       $file = "sys\$ps_font_metrics:$fontname.afm";
   } else {
       $file = "$fontname.afm";
       unless ($file =~ m,^/,) {
	   # not absolute, search the metrics path for the file
	   foreach (@metrics_path) {
	       if (-f "$_/$file") {
		   $file = "$_/$file";
		   last;
	       }
	   }
       }
   }
   open(AFM, $file) or croak "Can't find the AFM file for $fontname";
   my $self = bless { }, $class;
   local($/, $_) = ("\n", undef);  # ensure correct $INPUT_RECORD_SEPARATOR
   while (<AFM>) {
       next if /^StartKernData/ .. /^EndKernData/;  # kern data not parsed yet
       next if /^StartComposites/ .. /^EndComposites/; # same for composites
       if (/^StartCharMetrics/ .. /^EndCharMetrics/) {
	   # only lines that start with "C" or "CH" are parsed
	   next unless /^CH?\s/;
	   my($name) = /\bN\s+(\.?\w+)\s*;/;
	   my($wx)   = /\bWX\s+(\d+)\s*;/;
	   my($bbox)    = /\bB\s+([^;]+);/;
	   $bbox =~ s/\s+$//;
	   # Should also parse lingature data (format: L successor lignature)
	   $self->{'wx'}{$name} = $wx;
	   $self->{'bbox'}{$name} = $bbox;
	   next;
       }
       last if /^EndFontMetrics/;
       if (/(^\w+)\s+(.*)/) {
	   my($key,$val) = ($1, $2);
	   $key = lc $key;
	   if (defined $self->{$key}) {
	       $self->{$key} = [ $self->{$key} ] unless ref $self->{$key};
	       push(@{$self->{$key}}, $val);
	   } else {
	       $self->{$key} = $val;
	   }
       } else {
	   print STDERR "Can't parse: $_";
       }
   }
   close(AFM);
   unless (exists $self->{wx}->{'.notdef'}) {
       $self->{wx}->{'.notdef'} = 0;
       $self->{bbox}{'.notdef'} = "0 0 0 0";
   }
   $self;
}

# Returns an 256 element array that maps from characters to width
sub latin1_wx_table
{
    my($self) = @_;
    unless ($self->{'_wx_table'}) {
	my @wx;
	for (0..255) {
	    my $name = $ISOLatin1Encoding[$_];
	    if (exists $self->{wx}->{$name}) {
		push(@wx, $self->{wx}->{$name})
	    } else {
		push(@wx, $self->{wx}->{'.notdef'});
	    }
	}
	$self->{'_wx_table'} = \@wx;
    }
    wantarray ? @{ $self->{'_wx_table'} } : $self->{'_wx_table'};
}

sub stringwidth
{
    my($self, $string, $pointsize) = @_;
    return 0.0 unless defined $string;
    return 0.0 unless length $string;

    my @wx = $self->latin1_wx_table;
    my $width = 0.0;
    for (unpack("C*", $string)) {
	$width += $wx[$_];
    }
    if ($pointsize) {
	$width *= $pointsize / 1000;
    }
    $width;
}

sub FontName;
sub FullName;
sub FamilyName;
sub Weight;
sub ItalicAngle;
sub IsFixedPitch;
sub FontBBox;
sub UnderlinePosition;
sub UnderlineThickness;
sub Version;
sub Notice;
sub Comment;
sub EncodingScheme;
sub CapHeight;
sub XHeight;
sub Ascender;
sub Descender;
sub Wx;
sub BBox;

# We implement all the access functions within this simple autoload
# function.

sub AUTOLOAD
{
    no strict 'vars';  # don't want to declare $AUTOLOAD

    #print "AUTOLOAD: $AUTOLOAD\n";
    if ($AUTOLOAD =~ /::DESTROY$/) {
	eval "sub $AUTOLOAD {}";
	goto &$AUTOLOAD;
    } else {
	my $name = $AUTOLOAD;
	$name =~ s/^.*:://;
	croak "Attribute $name not defined for AFM object"
	    unless defined $_[0]->{lc $name};
	return $_[0]->{lc $name};
    }
}


# Dumping might be useful for debugging

sub dump
{
    my($self) = @_;
    my($key, $val);
    foreach $key (sort keys %$self) {
	if (ref $self->{$key}) {
	    if (ref $self->{$key} eq "ARRAY") {
		print "$key = [\n\t", join("\n\t", @{$self->{$key}}), "\n]\n";
	    } elsif (ref $self->{$key} eq "HASH") {
		print "$key = {\n";
		my $key2;
		foreach $key2 (sort keys %{$self->{$key}}) {
		    print "\t$key2 => $self->{$key}{$key2},\n";
		}
		print "}\n";
	    } else {
		print "$key = $self->{$key}\n";
	    }
	} else {
	    print "$key = $self->{$key}\n";
	}
    }
}

1;
