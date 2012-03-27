# $Id: AnyDBM_File.pm,v 1.11 2003/10/23 19:11:33 uid39246 Exp $

package WWW::RobotRules::AnyDBM_File;

require  WWW::RobotRules;
@ISA = qw(WWW::RobotRules);
$VERSION = sprintf("%d.%02d", q$Revision: 1.11 $ =~ /(\d+)\.(\d+)/);

use Carp ();
use AnyDBM_File;
use Fcntl;
use strict;

sub new 
{ 
  my ($class, $ua, $file) = @_;
  Carp::croak('WWW::RobotRules::AnyDBM_File filename required') unless $file;

  my $self = bless { }, $class;
  $self->{'filename'} = $file;
  tie %{$self->{'dbm'}}, 'AnyDBM_File', $file, O_CREAT|O_RDWR, 0640
    or Carp::croak("Can't open $file: $!");
  
  if ($ua) {
      $self->agent($ua);
  }
  else {
      # Try to obtain name from DBM file
      $ua = $self->{'dbm'}{"|ua-name|"};
      Carp::croak("No agent name specified") unless $ua;
  }

  $self;
}

sub agent {
    my($self, $newname) = @_;
    my $old = $self->{'dbm'}{"|ua-name|"};
    if (defined $newname) {
	$newname =~ s!/?\s*\d+.\d+\s*$!!;  # loose version
	unless ($old && $old eq $newname) {
	# Old info is now stale.
	    my $file = $self->{'filename'};
	    untie %{$self->{'dbm'}};
	    tie %{$self->{'dbm'}}, 'AnyDBM_File', $file, O_TRUNC|O_RDWR, 0640;
	    %{$self->{'dbm'}} = ();
	    $self->{'dbm'}{"|ua-name|"} = $newname;
	}
    }
    $old;
}

sub no_visits {
    my ($self, $netloc) = @_;
    my $t = $self->{'dbm'}{"$netloc|vis"};
    return 0 unless $t;
    (split(/;\s*/, $t))[0];
}

sub last_visit {
    my ($self, $netloc) = @_;
    my $t = $self->{'dbm'}{"$netloc|vis"};
    return undef unless $t;
    (split(/;\s*/, $t))[1];
}

sub fresh_until {
    my ($self, $netloc, $fresh) = @_;
    my $old = $self->{'dbm'}{"$netloc|exp"};
    if ($old) {
	$old =~ s/;.*//;  # remove cleartext
    }
    if (defined $fresh) {
	$fresh .= "; " . localtime($fresh);
	$self->{'dbm'}{"$netloc|exp"} = $fresh;
    }
    $old;
}

sub visit {
    my($self, $netloc, $time) = @_;
    $time ||= time;

    my $count = 0;
    my $old = $self->{'dbm'}{"$netloc|vis"};
    if ($old) {
	my $last;
	($count,$last) = split(/;\s*/, $old);
	$time = $last if $last > $time;
    }
    $count++;
    $self->{'dbm'}{"$netloc|vis"} = "$count; $time; " . localtime($time);
}

sub push_rules {
    my($self, $netloc, @rules) = @_;
    my $cnt = 1;
    $cnt++ while $self->{'dbm'}{"$netloc|r$cnt"};

    foreach (@rules) {
	$self->{'dbm'}{"$netloc|r$cnt"} = $_;
	$cnt++;
    }
}

sub clear_rules {
    my($self, $netloc) = @_;
    my $cnt = 1;
    while ($self->{'dbm'}{"$netloc|r$cnt"}) {
	delete $self->{'dbm'}{"$netloc|r$cnt"};
	$cnt++;
    }
}

sub rules {
    my($self, $netloc) = @_;
    my @rules = ();
    my $cnt = 1;
    while (1) {
	my $rule = $self->{'dbm'}{"$netloc|r$cnt"};
	last unless $rule;
	push(@rules, $rule);
	$cnt++;
    }
    @rules;
}

sub dump
{
}

1;

