# XML::Parser
#
# Copyright (c) 1998-2000 Larry Wall and Clark Cooper
# All rights reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package XML::Parser;

use Carp;

BEGIN {
  require XML::Parser::Expat;
  $VERSION = '2.34';
  die "Parser.pm and Expat.pm versions don't match"
    unless $VERSION eq $XML::Parser::Expat::VERSION;
}

use strict;

use vars qw($VERSION $LWP_load_failed);

$LWP_load_failed = 0;

sub new {
  my ($class, %args) = @_;
  my $style = $args{Style};
  
  my $nonexopt = $args{Non_Expat_Options} ||= {};
  
  $nonexopt->{Style}             = 1;
  $nonexopt->{Non_Expat_Options} = 1;
  $nonexopt->{Handlers}          = 1;
  $nonexopt->{_HNDL_TYPES}       = 1;
  $nonexopt->{NoLWP}             = 1;
  
  $args{_HNDL_TYPES} = {%XML::Parser::Expat::Handler_Setters};
  $args{_HNDL_TYPES}->{Init} = 1;
  $args{_HNDL_TYPES}->{Final} = 1;
  
  $args{Handlers} ||= {};
  my $handlers = $args{Handlers};
  
  if (defined($style)) {
    my $stylepkg = $style;
    
    if ($stylepkg !~ /::/) {
      $stylepkg = "\u$style";
      
      eval {
          my $fullpkg = 'XML::Parser::Style::' . $stylepkg;
          my $stylefile = $fullpkg;
          $stylefile =~ s/::/\//g;
          require "$stylefile.pm";
          $stylepkg = $fullpkg;
      };
      if ($@) {
          # fallback to old behaviour
          $stylepkg = 'XML::Parser::' . $stylepkg;
      }
    }
    
    my $htype;
    foreach $htype (keys %{$args{_HNDL_TYPES}}) {
      # Handlers explicity given override
      # handlers from the Style package
      unless (defined($handlers->{$htype})) {
        
        # A handler in the style package must either have
        # exactly the right case as the type name or a
        # completely lower case version of it.
        
        my $hname = "${stylepkg}::$htype";
        if (defined(&$hname)) {
          $handlers->{$htype} = \&$hname;
          next;
        }
        
        $hname = "${stylepkg}::\L$htype";
        if (defined(&$hname)) {
          $handlers->{$htype} = \&$hname;
          next;
        }
      }
    }
  }
  
  unless (defined($handlers->{ExternEnt})
          or defined ($handlers->{ExternEntFin})) {
    
    if ($args{NoLWP} or $LWP_load_failed) {
      $handlers->{ExternEnt} = \&file_ext_ent_handler;
      $handlers->{ExternEntFin} = \&file_ext_ent_cleanup;
    }
    else {
      # The following just bootstraps the real LWP external entity
      # handler

      $handlers->{ExternEnt} = \&initial_ext_ent_handler;

      # No cleanup function available until LWPExternEnt.pl loaded
    }
  }

  $args{Pkg} ||= caller;
  bless \%args, $class;
}                                # End of new

sub setHandlers {
  my ($self, @handler_pairs) = @_;
  
  croak("Uneven number of arguments to setHandlers method")
    if (int(@handler_pairs) & 1);
  
  my @ret;
  while (@handler_pairs) {
    my $type = shift @handler_pairs;
    my $handler = shift @handler_pairs;
    unless (defined($self->{_HNDL_TYPES}->{$type})) {
      my @types = sort keys %{$self->{_HNDL_TYPES}};
      
      croak("Unknown Parser handler type: $type\n Valid types: @types");
    }
    push(@ret, $type, $self->{Handlers}->{$type});
    $self->{Handlers}->{$type} = $handler;
  }

  return @ret;
}

sub parse_start {
  my $self = shift;
  my @expat_options = ();

  my ($key, $val);
  while (($key, $val) = each %{$self}) {
    push (@expat_options, $key, $val)
      unless exists $self->{Non_Expat_Options}->{$key};
  }

  my %handlers = %{$self->{Handlers}};
  my $init = delete $handlers{Init};
  my $final = delete $handlers{Final};

  my $expatnb = new XML::Parser::ExpatNB(@expat_options, @_);
  $expatnb->setHandlers(%handlers);

  &$init($expatnb)
    if defined($init);

  $expatnb->{_State_} = 1;

  $expatnb->{FinalHandler} = $final
    if defined($final);

  return $expatnb;
}

sub parse {
  my $self = shift;
  my $arg  = shift;
  my @expat_options = ();
  my ($key, $val);
  while (($key, $val) = each %{$self}) {
    push(@expat_options, $key, $val)
      unless exists $self->{Non_Expat_Options}->{$key};
  }
  
  my $expat = new XML::Parser::Expat(@expat_options, @_);
  my %handlers = %{$self->{Handlers}};
  my $init = delete $handlers{Init};
  my $final = delete $handlers{Final};
  
  $expat->setHandlers(%handlers);
  
  if ($self->{Base}) {
    $expat->base($self->{Base});
  }

  &$init($expat)
    if defined($init);
  
  my @result = ();
  my $result;
  eval {
    $result = $expat->parse($arg);
  };
  my $err = $@;
  if ($err) {
    $expat->release;
    die $err;
  }
  
  if ($result and defined($final)) {
    if (wantarray) {
      @result = &$final($expat);
    }
    else {
      $result = &$final($expat);
    }
  }
  
  $expat->release;

  return unless defined wantarray;
  return wantarray ? @result : $result;
}

sub parsestring {
  my $self = shift;
  $self->parse(@_);
}

sub parsefile {
  my $self = shift;
  my $file = shift;
  local(*FILE);
  open(FILE, $file) or  croak "Couldn't open $file:\n$!";
  binmode(FILE);
  my @ret;
  my $ret;

  $self->{Base} = $file;

  if (wantarray) {
    eval {
      @ret = $self->parse(*FILE, @_);
    };
  }
  else {
    eval {
      $ret = $self->parse(*FILE, @_);
    };
  }
  my $err = $@;
  close(FILE);
  die $err if $err;
  
  return unless defined wantarray;
  return wantarray ? @ret : $ret;
}

sub initial_ext_ent_handler {
  # This just bootstraps in the real lwp_ext_ent_handler which
  # also loads the URI and LWP modules.

  unless ($LWP_load_failed) {
    local($^W) = 0;

    my $stat =
      eval {
        require('XML/Parser/LWPExternEnt.pl');
      };
      
    if ($stat) {
      $_[0]->setHandlers(ExternEnt    => \&lwp_ext_ent_handler,
                         ExternEntFin => \&lwp_ext_ent_cleanup);
                       
      goto &lwp_ext_ent_handler;
    }

    # Failed to load lwp handler, act as if NoLWP

    $LWP_load_failed = 1;

    my $cmsg = "Couldn't load LWP based external entity handler\n";
    $cmsg .= "Switching to file-based external entity handler\n";
    $cmsg .= " (To avoid this message, use NoLWP option to XML::Parser)\n";
    warn($cmsg);
  }

  $_[0]->setHandlers(ExternEnt    => \&file_ext_ent_handler,
                     ExternEntFin => \&file_ext_ent_cleanup);
  goto &file_ext_ent_handler;

}

sub file_ext_ent_handler {
  my ($xp, $base, $path) = @_;

  # Prepend base only for relative paths

  if (defined($base)
      and not ($path =~ m!^(?:[\\/]|\w+:)!))
    {
      my $newpath = $base;
      $newpath =~ s![^\\/:]*$!$path!;
      $path = $newpath;
    }

  if ($path =~ /^\s*[|>+]/
      or $path =~ /\|\s*$/) {
    $xp->{ErrorMessage}
        .= "System ID ($path) contains Perl IO control characters";
    return undef;
  }

  require IO::File;
  my $fh = new IO::File($path);
  unless (defined $fh) {
    $xp->{ErrorMessage}
      .= "Failed to open $path:\n$!";
    return undef;
  }

  $xp->{_BaseStack} ||= [];
  $xp->{_FhStack} ||= [];

  push(@{$xp->{_BaseStack}}, $base);
  push(@{$xp->{_FhStack}}, $fh);

  $xp->base($path);
  
  return $fh;
}

sub file_ext_ent_cleanup {
  my ($xp) = @_;

  my $fh = pop(@{$xp->{_FhStack}});
  $fh->close;

  my $base = pop(@{$xp->{_BaseStack}});
  $xp->base($base);
}

1;

__END__

