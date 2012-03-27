package CGI::Cookie;

# See the bottom of this file for the POD documentation.  Search for the
# string '=head'.

# You can run this file through either pod2man or pod2html to produce pretty
# documentation in manual or html file format (these utilities are part of the
# Perl 5 distribution).

# Copyright 1995-1999, Lincoln D. Stein.  All rights reserved.
# It may be used and modified freely, but I do request that this copyright
# notice remain attached to the file.  You may modify this module as you 
# wish, but if you redistribute a modified version, please attach a note
# listing the modifications you have made.

$CGI::Cookie::VERSION='1.24';

use CGI::Util qw(rearrange unescape escape);
use overload '""' => \&as_string,
    'cmp' => \&compare,
    'fallback'=>1;

# Turn on special checking for Doug MacEachern's modperl
my $MOD_PERL = 0;
if (exists $ENV{MOD_PERL}) {
  eval "require mod_perl";
  if (defined $mod_perl::VERSION) {
    if ($mod_perl::VERSION >= 1.99) {
      $MOD_PERL = 2;
      require Apache::RequestUtil;
    } else {
      $MOD_PERL = 1;
      require Apache;
    }
  }
}

# fetch a list of cookies from the environment and
# return as a hash.  the cookies are parsed as normal
# escaped URL data.
sub fetch {
    my $class = shift;
    my $raw_cookie = get_raw_cookie(@_) or return;
    return $class->parse($raw_cookie);
}

# Fetch a list of cookies from the environment or the incoming headers and
# return as a hash. The cookie values are not unescaped or altered in any way.
 sub raw_fetch {
   my $class = shift;
   my $raw_cookie = get_raw_cookie(@_) or return;
   my %results;
   my($key,$value);
   
   my(@pairs) = split("; ?",$raw_cookie);
   foreach (@pairs) {
     s/\s*(.*?)\s*/$1/;
     if (/^([^=]+)=(.*)/) {
       $key = $1;
       $value = $2;
     }
     else {
       $key = $_;
       $value = '';
     }
     $results{$key} = $value;
   }
   return \%results unless wantarray;
   return %results;
}

sub get_raw_cookie {
  my $r = shift;
  $r ||= eval { Apache->request() } if $MOD_PERL;
  if ($r) {
    $raw_cookie = $r->headers_in->{'Cookie'};
  } else {
    if ($MOD_PERL && !exists $ENV{REQUEST_METHOD}) {
      die "Run $r->subprocess_env; before calling fetch()";
    }
    $raw_cookie = $ENV{HTTP_COOKIE} || $ENV{COOKIE};
  }
}


sub parse {
  my ($self,$raw_cookie) = @_;
  my %results;

  my(@pairs) = split("; ?",$raw_cookie);
  foreach (@pairs) {
    s/\s*(.*?)\s*/$1/;
    my($key,$value) = split("=",$_,2);

    # Some foreign cookies are not in name=value format, so ignore
    # them.
    next if !defined($value);
    my @values = ();
    if ($value ne '') {
      @values = map unescape($_),split(/[&;]/,$value.'&dmy');
      pop @values;
    }
    $key = unescape($key);
    # A bug in Netscape can cause several cookies with same name to
    # appear.  The FIRST one in HTTP_COOKIE is the most recent version.
    $results{$key} ||= $self->new(-name=>$key,-value=>\@values);
  }
  return \%results unless wantarray;
  return %results;
}

sub new {
  my $class = shift;
  $class = ref($class) if ref($class);
  my($name,$value,$path,$domain,$secure,$expires) =
    rearrange([NAME,[VALUE,VALUES],PATH,DOMAIN,SECURE,EXPIRES],@_);
  
  # Pull out our parameters.
  my @values;
  if (ref($value)) {
    if (ref($value) eq 'ARRAY') {
      @values = @$value;
    } elsif (ref($value) eq 'HASH') {
      @values = %$value;
    }
  } else {
    @values = ($value);
  }
  
  bless my $self = {
		    'name'=>$name,
		    'value'=>[@values],
		   },$class;

  # IE requires the path and domain to be present for some reason.
  $path   ||= "/";
  # however, this breaks networks which use host tables without fully qualified
  # names, so we comment it out.
  #    $domain = CGI::virtual_host()    unless defined $domain;

  $self->path($path)     if defined $path;
  $self->domain($domain) if defined $domain;
  $self->secure($secure) if defined $secure;
  $self->expires($expires) if defined $expires;
#  $self->max_age($expires) if defined $expires;
  return $self;
}

sub as_string {
    my $self = shift;
    return "" unless $self->name;

    my(@constant_values,$domain,$path,$expires,$max_age,$secure);

    push(@constant_values,"domain=$domain")   if $domain = $self->domain;
    push(@constant_values,"path=$path")       if $path = $self->path;
    push(@constant_values,"expires=$expires") if $expires = $self->expires;
    push(@constant_values,"max-age=$max_age") if $max_age = $self->max_age;
    push(@constant_values,"secure") if $secure = $self->secure;

    my($key) = escape($self->name);
    my($cookie) = join("=",$key,join("&",map escape($_),$self->value));
    return join("; ",$cookie,@constant_values);
}

sub compare {
    my $self = shift;
    my $value = shift;
    return "$self" cmp $value;
}

# accessors
sub name {
    my $self = shift;
    my $name = shift;
    $self->{'name'} = $name if defined $name;
    return $self->{'name'};
}

sub value {
    my $self = shift;
    my $value = shift;
      if (defined $value) {
              my @values;
        if (ref($value)) {
            if (ref($value) eq 'ARRAY') {
                @values = @$value;
            } elsif (ref($value) eq 'HASH') {
                @values = %$value;
            }
        } else {
            @values = ($value);
        }
      $self->{'value'} = [@values];
      }
    return wantarray ? @{$self->{'value'}} : $self->{'value'}->[0]
}

sub domain {
    my $self = shift;
    my $domain = shift;
    $self->{'domain'} = $domain if defined $domain;
    return $self->{'domain'};
}

sub secure {
    my $self = shift;
    my $secure = shift;
    $self->{'secure'} = $secure if defined $secure;
    return $self->{'secure'};
}

sub expires {
    my $self = shift;
    my $expires = shift;
    $self->{'expires'} = CGI::Util::expires($expires,'cookie') if defined $expires;
    return $self->{'expires'};
}

sub max_age {
  my $self = shift;
  my $expires = shift;
  $self->{'max-age'} = CGI::Util::expire_calc($expires)-time() if defined $expires;
  return $self->{'max-age'};
}

sub path {
    my $self = shift;
    my $path = shift;
    $self->{'path'} = $path if defined $path;
    return $self->{'path'};
}

1;

