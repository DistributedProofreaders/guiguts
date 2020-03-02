package Guiguts::GifMaker;
use strict;
use warnings;
use MIME::Base64 qw();


#####################################################################################
#                                                                                   #
#       Welcome, friend!                                                            #
#                                                                                   #
#       If you are already a perl monk, you probably won't need this module.        #
#       If, like me, you're merely an itinerent tinker, it may be useful.           #
#                                                                                   #
#       GIF files are represented in perl using base64 string notation. This        #
#       means that they are encoded using 6-bit bites rather than 8-bit bytes.      #
#       Four bites of base64 = 24 bits = three bytes of gif file. The encoding      #
#       exceeds my understanding but is represented below by 2 perl routines.       #
#       Where the base64 string comes out as less than exact multiples of 4 bits    #
#       the strings are padded out to fit with trailing equals marks.               #
#                                                                                   #
#       The gifs used in Greekgifs.pm are 24 pixels square at 72 per inch and       #
#       with 256 colours (although the number actually used is generally less).     #
#                                                                                   #
#       Tony Browne                                                                 #
#                                                                                   #
#####################################################################################


#####################################################################################
#                                                                                   #
#       a)      To convert an existing base64 string into a gif file:               #
#                                                                                   #
#               Set $name = the name part of new gif file;                          #
#               Set $imaj = the string representing some image from Greekgifs.pm;   #
#               Remove the initial hash/comment marks & run this program.           #
#               The new gif file will appear in the 'root' directory.               #
#                                                                                   #
#####################################################################################
#my $name = 'oulig';
#my $imaj = '
#        R0lGODlhGAAYAPcAAAQCBIyOjNTW1FRSVKyyrPTy9GxqbKSmpJSWlNze3GRmZFxWXLy+vPz+/Jya
#        nDw6PNzW3FRWVLS2tPT29Hx6fJSalOTi5AH2KwB+QQC2/wD21wC2Fo56JwEGpQAW1wCaFq/yTFkq
#        UNf6xivKFv/aABUGAACGAADGAABKjwAmFgDuLgCqdAwWAHPSAAluAlI2dACSAAGyAAB2jgAOAJ8e
#        dtCOAABeAAA+AICyVqR+H3b2AAAuAM7+AOnOAEvexQAAFWYArwAAFwD/SwD/AJgAZaQCAHYPRAAo
#        vGz3YqS/gHa2AQBRAPJoALJzAE4oAAAAANu3AP8BAP8AEP8AAAAXAABqAAAAGAABAO8AAOgAAEuf
#        AADQwNgAO7AA0HYnEgBqACUAAAAAAAAnIwAcApiPAKSxAHb5AAC/AGwDRKQAdHbeAAB0AOQDjxwA
#        FlTPSABAdH8AAAgAAPpGxb+XFfzur04TF/X34L+/u/9sYv+jgP92yv8AFf9Qr//wF/+az/+BFh8Q
#        xgRSFgCfAACBAABzAACxAAD5dQC/AQgAzwAwFgB2ZAAAdOIOABOhAPf3AL+/AH8mBwGzAAD3AAC/
#        AGQAh87wAfeadb+BAfcAAEEAAPcAAL8AABQAAFIAAJ8AAIEAAPp/ANoIAPf6AL+/AJDgAJRVAPxQ
#        AL8AAB+UrwSjFwB2hwAAAUBWJQCrAAD4AAC/AIwI/6Lm/3YA/wCA/yQgJdtcAPcAAL+AAFwg2Deq
#        sKkAdoGAAECYAAAQAAABAACAABQAuFIBpJ8AdoEAABMQCAGqtQAAS8CAABTkmFIcpJ9UdoEAAEB/
#        8wAIsgD6TgC/AB/8zAROpAD1dgC/AIC0f0ukCAN2+tIAv9TrbaO2p3b5dgC/AP0E2fTw//dO/78A
#        f/8MSP/wp/9Odv8AAIDc5ACbHAD8VAC/AAO0fwCjCAB2+gAAv0MA5DoBHFwAVGIAAG/gAG9VAGtQ
#        AHMAAFwAr3IASXQAR2bQAFyMSHAIp3IAdmUAAHAcSFwsp3Q8dmXQACH5BAAAAAAALAAAAAAYABgA
#        BwhfABsIHEiwoMGDCBMqXMiwocOHECM2EACAgMSBAQBMuCgQgAGOEwEcAOkAQAKQDwAMiDBgwQCI
#        CQDInBkBZAEACEASACAAJAUAIBsAUAAypkWOCABYACmAQdCnUKMyDAgAOw==
#';
#
#open my $giff, '>', $name.".gif" or die "Can't create image file: ".$name."!\n";
#binmode $giff;
#print $giff dekode_base64 ($imaj);
#close $giff;
#####################################################################################


#####################################################################################
#                                                                                   #
#       b)      To convert an existing gif file into a base64 string:               #
#                                                                                   #
#               Set $name = the name part of gif file;                              #
#               Set $lnth = the length of the gif file;                             #
#               Remove the initial hash/comment marks & run this program.           #
#               The base64 string will be written into the command window from      #
#               where it may be copied and pasted to Greekgifs.pm;                  #
#               For (MS)Windows you may need to add 'cmd' to the end of the         #
#               guiguts.bat file to make it pause long enough.                      #
#                                                                                   #
#####################################################################################
#my $name = 'oulig';
#my $lnth = 896;
#
#my $bufr;
#my $imaj = '';
#open(FILE, $name.".gif") or die "Can't attach image file: ".$name."!\n";
#while (read(FILE, $bufr, $lnth)) {$imaj.=$bufr} print enkode_base64($imaj);
#close FILE;
#####################################################################################



sub enkode_base64
{
	use integer;

	my $eol = "\n";
	my $ins = shift;
	my $res = pack("u", $ins);
	$res =~ s/^.//mg;
	$res =~ s/\n//g;

	$res =~ tr|` -_|AA-Za-z0-9+/|;
	my $padding = (3 - length($ins) % 3) % 3;
	$res =~ s/.{$padding}$/'=' x $padding/e if $padding;
	if (length $eol) {
		$res =~ s/(.{1,76})/$1$eol/g;
	}
	return $res;
}

sub dekode_base64
{
	use integer;

	my $str = shift;
	$str =~ tr|A-Za-z0-9+=/||cd;
	$str =~ s/=+$//;
	$str =~ tr|A-Za-z0-9+/| -_|;
	return "" unless length $str;

	my $uustr = '';
	my ($i, $l);
	$l = length($str) - 60;
	for ($i = 0; $i <= $l; $i += 60) {
		$uustr .= "M" . substr($str, $i, 60);
	}
	$str = substr($str, $i);
	if ($str ne "") {
		$uustr .= chr(32 + length($str)*3/4) . $str;
	}
	return unpack ("u", $uustr);
}

1;
