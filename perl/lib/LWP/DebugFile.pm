package LWP::DebugFile;

# $Id: DebugFile.pm,v 1.3 2003/10/23 18:56:01 uid39246 Exp $

use strict;
use LWP::Debug ();

use vars qw($outname $outpath @ISA $last_message_time);
@ISA = ('LWP::Debug');

_init() unless $^C or !caller;
$LWP::Debug::current_level{'conns'} = 1;



sub _init {
  $outpath = $ENV{'LWPDEBUGPATH'} || ''
   unless defined $outpath;
  $outname = $ENV{'LWPDEBUGFILE'} ||
    sprintf "%slwp_%x_%x.log", $outpath, $^T,
     defined( &Win32::GetTickCount )
      ? (Win32::GetTickCount() & 0xFFFF)
      : $$
        # Using $$ under Win32 isn't nice, because the OS usually
        # reuses the $$ value almost immediately!!  So the lower
        # 16 bits of the uptime tick count is a great substitute.
   unless defined $outname;

  open LWPERR, ">>$outname" or die "Can't write-open $outname: $!";
  # binmode(LWPERR);
  {
    no strict;
    my $x = select(LWPERR);
    ++$|;
    select($x);
  }

  $last_message_time = time();
  die "Can't print to LWPERR"
   unless print LWPERR "\n# ", __PACKAGE__, " logging to $outname\n";
   # check at least the first print, just for sanity's sake!

  print LWPERR "# Time now: \{$last_message_time\} = ",
          scalar(localtime($last_message_time)), "\n";

  LWP::Debug::level($ENV{'LWPDEBUGLEVEL'} || '+');
  return;
}


BEGIN { # So we don't get redefinition warnings...
  undef &LWP::Debug::conns;
  undef &LWP::Debug::_log;
}


sub LWP::Debug::conns {
  if($LWP::Debug::current_level{'conns'}) {
    my $msg = $_[0];
    my $line;
    my $prefix = '0';
    while($msg =~ m/([^\n\r]*[\n\r]*)/g) {
      next unless length($line = $1);
      # Hex escape it:
      $line =~ s/([^\x20\x21\x23-\x7a\x7c\x7e])/
        (ord($1)<256) ? sprintf('\x%02X',ord($1))
         : sprintf('\x{%x}',ord($1))
      /eg;
      LWP::Debug::_log("S>$prefix \"$line\"");
      $prefix = '+';
    }
  }
}


sub LWP::Debug::_log
{
    my $msg = shift;
    $msg .= "\n" unless $msg =~ /\n$/;  # ensure trailing "\n"

    my($package,$filename,$line,$sub) = caller(2);
    unless((my $this_time = time()) == $last_message_time) {
      print LWPERR "# Time now: \{$this_time\} = ",
        scalar(localtime($this_time)), "\n";
      $last_message_time = $this_time;
    }
    print LWPERR "$sub: $msg";
}


1;

__END__

