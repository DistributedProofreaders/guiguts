package CGI::Carp;

require 5.000;
use Exporter;
#use Carp;
BEGIN { 
  require Carp; 
  *CORE::GLOBAL::die = \&CGI::Carp::die;
}

use File::Spec;

@ISA = qw(Exporter);
@EXPORT = qw(confess croak carp);
@EXPORT_OK = qw(carpout fatalsToBrowser warningsToBrowser wrap set_message set_progname cluck ^name= die);

$main::SIG{__WARN__}=\&CGI::Carp::warn;

$CGI::Carp::VERSION    = '1.27';
$CGI::Carp::CUSTOM_MSG = undef;


# fancy import routine detects and handles 'errorWrap' specially.
sub import {
    my $pkg = shift;
    my(%routines);
    my(@name);
  
    if (@name=grep(/^name=/,@_))
      {
        my($n) = (split(/=/,$name[0]))[1];
        set_progname($n);
        @_=grep(!/^name=/,@_);
      }

    grep($routines{$_}++,@_,@EXPORT);
    $WRAP++ if $routines{'fatalsToBrowser'} || $routines{'wrap'};
    $WARN++ if $routines{'warningsToBrowser'};
    my($oldlevel) = $Exporter::ExportLevel;
    $Exporter::ExportLevel = 1;
    Exporter::import($pkg,keys %routines);
    $Exporter::ExportLevel = $oldlevel;
    $main::SIG{__DIE__} =\&CGI::Carp::die if $routines{'fatalsToBrowser'};
#    $pkg->export('CORE::GLOBAL','die');
}

# These are the originals
sub realwarn { CORE::warn(@_); }
sub realdie { CORE::die(@_); }

sub id {
    my $level = shift;
    my($pack,$file,$line,$sub) = caller($level);
    my($dev,$dirs,$id) = File::Spec->splitpath($file);
    return ($file,$line,$id);
}

sub stamp {
    my $time = scalar(localtime);
    my $frame = 0;
    my ($id,$pack,$file,$dev,$dirs);
    if (defined($CGI::Carp::PROGNAME)) {
        $id = $CGI::Carp::PROGNAME;
    } else {
        do {
  	  $id = $file;
	  ($pack,$file) = caller($frame++);
        } until !$file;
    }
    ($dev,$dirs,$id) = File::Spec->splitpath($id);
    return "[$time] $id: ";
}

sub set_progname {
    $CGI::Carp::PROGNAME = shift;
    return $CGI::Carp::PROGNAME;
}


sub warn {
    my $message = shift;
    my($file,$line,$id) = id(1);
    $message .= " at $file line $line.\n" unless $message=~/\n$/;
    _warn($message) if $WARN;
    my $stamp = stamp;
    $message=~s/^/$stamp/gm;
    realwarn $message;
}

sub _warn {
    my $msg = shift;
    if ($EMIT_WARNINGS) {
	# We need to mangle the message a bit to make it a valid HTML
	# comment.  This is done by substituting similar-looking ISO
	# 8859-1 characters for <, > and -.  This is a hack.
	$msg =~ tr/<>-/\253\273\255/;
	chomp $msg;
	print STDOUT "<!-- warning: $msg -->\n";
    } else {
	push @WARNINGS, $msg;
    }
}


# The mod_perl package Apache::Registry loads CGI programs by calling
# eval, as does PerlEx.  These evals don't count when looking at the 
# stack backtrace.
sub _longmess {
    my $message = Carp::longmess();
    my $mod_perl = exists $ENV{MOD_PERL};
    my $plex = exists($ENV{'GATEWAY_INTERFACE'})
               && $ENV{'GATEWAY_INTERFACE'} =~ /^CGI-PerlEx/;
    $message =~ s,eval[^\n]+((ModPerl|Apache)/Registry\w*\.pm|\s*PerlEx::Precompiler).*,,s
	if $mod_perl or $plex;
    return $message;    
}

sub ineval {
  (exists $ENV{MOD_PERL} ? 0 : $^S) || _longmess() =~ /eval [\{\']/m
}

sub die {
  my ($arg) = @_;
  realdie @_ if ineval;
  if (!ref($arg)) {
    $arg = join("", @_);
    my($file,$line,$id) = id(1);
    $arg .= " at $file line $line." unless $arg=~/\n$/;
    &fatalsToBrowser($arg) if $WRAP;
    if (($arg =~ /\n$/) || !exists($ENV{MOD_PERL})) {
      my $stamp = stamp;
      $arg=~s/^/$stamp/gm;
    }
    if ($arg !~ /\n$/) {
      $arg .= "\n";
    }
  }
  realdie $arg;
}

sub set_message {
    $CGI::Carp::CUSTOM_MSG = shift;
    return $CGI::Carp::CUSTOM_MSG;
}

sub confess { CGI::Carp::die Carp::longmess @_; }
sub croak   { CGI::Carp::die Carp::shortmess @_; }
sub carp    { CGI::Carp::warn Carp::shortmess @_; }
sub cluck   { CGI::Carp::warn Carp::longmess @_; }

# We have to be ready to accept a filehandle as a reference
# or a string.
sub carpout {
    my($in) = @_;
    my($no) = fileno(to_filehandle($in));
    realdie("Invalid filehandle $in\n") unless defined $no;
    
    open(SAVEERR, ">&STDERR");
    open(STDERR, ">&$no") or 
	( print SAVEERR "Unable to redirect STDERR: $!\n" and exit(1) );
}

sub warningsToBrowser {
    $EMIT_WARNINGS = @_ ? shift : 1;
    _warn(shift @WARNINGS) while $EMIT_WARNINGS and @WARNINGS;
}

# headers
sub fatalsToBrowser {
  my($msg) = @_;
  $msg=~s/&/&amp;/g;
  $msg=~s/>/&gt;/g;
  $msg=~s/</&lt;/g;
  $msg=~s/\"/&quot;/g;
  my($wm) = $ENV{SERVER_ADMIN} ? 
    qq[the webmaster (<a href="mailto:$ENV{SERVER_ADMIN}">$ENV{SERVER_ADMIN}</a>)] :
      "this site's webmaster";
  my ($outer_message) = <<END;
For help, please send mail to $wm, giving this error message 
and the time and date of the error.
END
    ;
    my $mod_perl = exists $ENV{MOD_PERL};
    my $plex = exists($ENV{'GATEWAY_INTERFACE'})
	&& $ENV{'GATEWAY_INTERFACE'} =~ /^CGI-PerlEx/;

  warningsToBrowser(1);    # emit warnings before dying

  if ($CUSTOM_MSG) {
    if (ref($CUSTOM_MSG) eq 'CODE') {
      print STDOUT "Content-type: text/html\n\n" 
        unless $mod_perl || $plex;
      &$CUSTOM_MSG($msg); # nicer to perl 5.003 users
      return;
    } else {
      $outer_message = $CUSTOM_MSG;
    }
  }

  my $mess = <<END;
<h1>Software error:</h1>
<pre>$msg</pre>
<p>
$outer_message
</p>
END
  ;

  if ($mod_perl) {
    require mod_perl;
    if ($mod_perl::VERSION >= 1.99) {
      $mod_perl = 2;
      require Apache::RequestRec;
      require Apache::RequestIO;
      require Apache::RequestUtil;
      require APR::Pool;
      require ModPerl::Util;
      require Apache::Response;
    }
    my $r = Apache->request;
    # If bytes have already been sent, then
    # we print the message out directly.
    # Otherwise we make a custom error
    # handler to produce the doc for us.
    if ($r->bytes_sent) {
      $r->print($mess);
      $mod_perl == 2 ? ModPerl::Util::exit(0) : $r->exit;
    } else {
      # MSIE won't display a custom 500 response unless it is >512 bytes!
      if ($ENV{HTTP_USER_AGENT} =~ /MSIE/) {
        $mess = "<!-- " . (' ' x 513) . " -->\n$mess";
      }
      $r->custom_response(500,$mess);
    }
  } else {
    my $bytes_written = eval{tell STDOUT};
    if (defined $bytes_written && $bytes_written > 0) {
        print STDOUT $mess;
    }
    else {
        print STDOUT "Content-type: text/html\n\n";
        print STDOUT $mess;
    }
  }
}

# Cut and paste from CGI.pm so that we don't have the overhead of
# always loading the entire CGI module.
sub to_filehandle {
    my $thingy = shift;
    return undef unless $thingy;
    return $thingy if UNIVERSAL::isa($thingy,'GLOB');
    return $thingy if UNIVERSAL::isa($thingy,'FileHandle');
    if (!ref($thingy)) {
	my $caller = 1;
	while (my $package = caller($caller++)) {
	    my($tmp) = $thingy=~/[\':]/ ? $thingy : "$package\:\:$thingy"; 
	    return $tmp if defined(fileno($tmp));
	}
    }
    return undef;
}

1;
