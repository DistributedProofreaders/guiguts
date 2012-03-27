#############################################################################
# Pod/InputObjects.pm -- package which defines objects for input streams
# and paragraphs and commands when parsing POD docs.
#
# Copyright (C) 1996-2000 by Bradford Appleton. All rights reserved.
# This file is part of "PodParser". PodParser is free software;
# you can redistribute it and/or modify it under the same terms
# as Perl itself.
#############################################################################

package Pod::InputObjects;

use vars qw($VERSION);
$VERSION = 1.14;  ## Current version of this package
require  5.005;    ## requires this Perl version or later

#############################################################################

#############################################################################

use strict;
#use diagnostics;
#use Carp;

#############################################################################

package Pod::InputSource;

##---------------------------------------------------------------------------

##---------------------------------------------------------------------------

sub new {
    ## Determine if we were called via an object-ref or a classname
    my $this = shift;
    my $class = ref($this) || $this;

    ## Any remaining arguments are treated as initial values for the
    ## hash that is used to represent this object. Note that we default
    ## certain values by specifying them *before* the arguments passed.
    ## If they are in the argument list, they will override the defaults.
    my $self = { -name        => '(unknown)',
                 -handle      => undef,
                 -was_cutting => 0,
                 @_ };

    ## Bless ourselves into the desired class and perform any initialization
    bless $self, $class;
    return $self;
}

##---------------------------------------------------------------------------

sub name {
   (@_ > 1)  and  $_[0]->{'-name'} = $_[1];
   return $_[0]->{'-name'};
}

## allow 'filename' as an alias for 'name'
*filename = \&name;

##---------------------------------------------------------------------------

sub handle {
   return $_[0]->{'-handle'};
}

##---------------------------------------------------------------------------

sub was_cutting {
   (@_ > 1)  and  $_[0]->{-was_cutting} = $_[1];
   return $_[0]->{-was_cutting};
}

##---------------------------------------------------------------------------

#############################################################################

package Pod::Paragraph;

##---------------------------------------------------------------------------

##---------------------------------------------------------------------------

sub new {
    ## Determine if we were called via an object-ref or a classname
    my $this = shift;
    my $class = ref($this) || $this;

    ## Any remaining arguments are treated as initial values for the
    ## hash that is used to represent this object. Note that we default
    ## certain values by specifying them *before* the arguments passed.
    ## If they are in the argument list, they will override the defaults.
    my $self = {
          -name       => undef,
          -text       => (@_ == 1) ? shift : undef,
          -file       => '<unknown-file>',
          -line       => 0,
          -prefix     => '=',
          -separator  => ' ',
          -ptree => [],
          @_
    };

    ## Bless ourselves into the desired class and perform any initialization
    bless $self, $class;
    return $self;
}

##---------------------------------------------------------------------------

sub cmd_name {
   (@_ > 1)  and  $_[0]->{'-name'} = $_[1];
   return $_[0]->{'-name'};
}

## let name() be an alias for cmd_name()
*name = \&cmd_name;

##---------------------------------------------------------------------------

sub text {
   (@_ > 1)  and  $_[0]->{'-text'} = $_[1];
   return $_[0]->{'-text'};
}       

##---------------------------------------------------------------------------

sub raw_text {
   return $_[0]->{'-text'}  unless (defined $_[0]->{'-name'});
   return $_[0]->{'-prefix'} . $_[0]->{'-name'} . 
          $_[0]->{'-separator'} . $_[0]->{'-text'};
}

##---------------------------------------------------------------------------

sub cmd_prefix {
   return $_[0]->{'-prefix'};
}

##---------------------------------------------------------------------------

sub cmd_separator {
   return $_[0]->{'-separator'};
}

##---------------------------------------------------------------------------

sub parse_tree {
   (@_ > 1)  and  $_[0]->{'-ptree'} = $_[1];
   return $_[0]->{'-ptree'};
}       

## let ptree() be an alias for parse_tree()
*ptree = \&parse_tree;

##---------------------------------------------------------------------------

sub file_line {
   my @loc = ($_[0]->{'-file'} || '<unknown-file>',
              $_[0]->{'-line'} || 0);
   return (wantarray) ? @loc : join(':', @loc);
}

##---------------------------------------------------------------------------

#############################################################################

package Pod::InteriorSequence;

##---------------------------------------------------------------------------

##---------------------------------------------------------------------------

sub new {
    ## Determine if we were called via an object-ref or a classname
    my $this = shift;
    my $class = ref($this) || $this;

    ## See if first argument has no keyword
    if (((@_ <= 2) or (@_ % 2)) and $_[0] !~ /^-\w/) {
       ## Yup - need an implicit '-name' before first parameter
       unshift @_, '-name';
    }

    ## See if odd number of args
    if ((@_ % 2) != 0) {
       ## Yup - need an implicit '-ptree' before the last parameter
       splice @_, $#_, 0, '-ptree';
    }

    ## Any remaining arguments are treated as initial values for the
    ## hash that is used to represent this object. Note that we default
    ## certain values by specifying them *before* the arguments passed.
    ## If they are in the argument list, they will override the defaults.
    my $self = {
          -name       => (@_ == 1) ? $_[0] : undef,
          -file       => '<unknown-file>',
          -line       => 0,
          -ldelim     => '<',
          -rdelim     => '>',
          @_
    };

    ## Initialize contents if they havent been already
    my $ptree = $self->{'-ptree'} || new Pod::ParseTree();
    if ( ref $ptree =~ /^(ARRAY)?$/ ) {
        ## We have an array-ref, or a normal scalar. Pass it as an
        ## an argument to the ptree-constructor
        $ptree = new Pod::ParseTree($1 ? [$ptree] : $ptree);
    }
    $self->{'-ptree'} = $ptree;

    ## Bless ourselves into the desired class and perform any initialization
    bless $self, $class;
    return $self;
}

##---------------------------------------------------------------------------

sub cmd_name {
   (@_ > 1)  and  $_[0]->{'-name'} = $_[1];
   return $_[0]->{'-name'};
}

## let name() be an alias for cmd_name()
*name = \&cmd_name;

##---------------------------------------------------------------------------

## Private subroutine to set the parent pointer of all the given
## children that are interior-sequences to be $self

sub _set_child2parent_links {
   my ($self, @children) = @_;
   ## Make sure any sequences know who their parent is
   for (@children) {
      next  unless (length  and  ref  and  ref ne 'SCALAR');
      if (UNIVERSAL::isa($_, 'Pod::InteriorSequence') or
          UNIVERSAL::can($_, 'nested'))
      {
          $_->nested($self);
      }
   }
}

## Private subroutine to unset child->parent links

sub _unset_child2parent_links {
   my $self = shift;
   $self->{'-parent_sequence'} = undef;
   my $ptree = $self->{'-ptree'};
   for (@$ptree) {
      next  unless (length  and  ref  and  ref ne 'SCALAR');
      $_->_unset_child2parent_links()
          if UNIVERSAL::isa($_, 'Pod::InteriorSequence');
   }
}

##---------------------------------------------------------------------------

sub prepend {
   my $self  = shift;
   $self->{'-ptree'}->prepend(@_);
   _set_child2parent_links($self, @_);
   return $self;
}       

##---------------------------------------------------------------------------

sub append {
   my $self = shift;
   $self->{'-ptree'}->append(@_);
   _set_child2parent_links($self, @_);
   return $self;
}       

##---------------------------------------------------------------------------

sub nested {
   my $self = shift;
  (@_ == 1)  and  $self->{'-parent_sequence'} = shift;
   return  $self->{'-parent_sequence'} || undef;
}

##---------------------------------------------------------------------------

sub raw_text {
   my $self = shift;
   my $text = $self->{'-name'} . $self->{'-ldelim'};
   for ( $self->{'-ptree'}->children ) {
      $text .= (ref $_) ? $_->raw_text : $_;
   }
   $text .= $self->{'-rdelim'};
   return $text;
}

##---------------------------------------------------------------------------

sub left_delimiter {
   (@_ > 1)  and  $_[0]->{'-ldelim'} = $_[1];
   return $_[0]->{'-ldelim'};
}

## let ldelim() be an alias for left_delimiter()
*ldelim = \&left_delimiter;

##---------------------------------------------------------------------------

sub right_delimiter {
   (@_ > 1)  and  $_[0]->{'-rdelim'} = $_[1];
   return $_[0]->{'-rdelim'};
}

## let rdelim() be an alias for right_delimiter()
*rdelim = \&right_delimiter;

##---------------------------------------------------------------------------

sub parse_tree {
   (@_ > 1)  and  $_[0]->{'-ptree'} = $_[1];
   return $_[0]->{'-ptree'};
}       

## let ptree() be an alias for parse_tree()
*ptree = \&parse_tree;

##---------------------------------------------------------------------------

sub file_line {
   my @loc = ($_[0]->{'-file'}  || '<unknown-file>',
              $_[0]->{'-line'}  || 0);
   return (wantarray) ? @loc : join(':', @loc);
}

##---------------------------------------------------------------------------

sub DESTROY {
   ## We need to get rid of all child->parent pointers throughout the
   ## tree so their reference counts will go to zero and they can be
   ## garbage-collected
   _unset_child2parent_links(@_);
}

##---------------------------------------------------------------------------

#############################################################################

package Pod::ParseTree;

##---------------------------------------------------------------------------

##---------------------------------------------------------------------------

sub new {
    ## Determine if we were called via an object-ref or a classname
    my $this = shift;
    my $class = ref($this) || $this;

    my $self = (@_ == 1  and  ref $_[0]) ? $_[0] : [];

    ## Bless ourselves into the desired class and perform any initialization
    bless $self, $class;
    return $self;
}

##---------------------------------------------------------------------------

sub top {
   my $self = shift;
   if (@_ > 0) {
      @{ $self } = (@_ == 1  and  ref $_[0]) ? ${ @_ } : @_;
   }
   return $self;
}

## let parse_tree() & ptree() be aliases for the 'top' method
*parse_tree = *ptree = \&top;

##---------------------------------------------------------------------------

sub children {
   my $self = shift;
   if (@_ > 0) {
      @{ $self } = (@_ == 1  and  ref $_[0]) ? ${ @_ } : @_;
   }
   return @{ $self };
}

##---------------------------------------------------------------------------

use vars qw(@ptree);  ## an alias used for performance reasons

sub prepend {
   my $self = shift;
   local *ptree = $self;
   for (@_) {
      next  unless length;
      if (@ptree  and  !(ref $ptree[0])  and  !(ref $_)) {
         $ptree[0] = $_ . $ptree[0];
      }
      else {
         unshift @ptree, $_;
      }
   }
}

##---------------------------------------------------------------------------

sub append {
   my $self = shift;
   local *ptree = $self;
   my $can_append = @ptree && !(ref $ptree[-1]);
   for (@_) {
      if (ref) {
         push @ptree, $_;
      }
      elsif(!length) {
         next;
      }
      elsif ($can_append) {
         $ptree[-1] .= $_;
      }
      else {
         push @ptree, $_;
      }
   }
}

sub raw_text {
   my $self = shift;
   my $text = "";
   for ( @$self ) {
      $text .= (ref $_) ? $_->raw_text : $_;
   }
   return $text;
}

##---------------------------------------------------------------------------

## Private routines to set/unset child->parent links

sub _unset_child2parent_links {
   my $self = shift;
   local *ptree = $self;
   for (@ptree) {
       next  unless (defined and length  and  ref  and  ref ne 'SCALAR');
       $_->_unset_child2parent_links()
           if UNIVERSAL::isa($_, 'Pod::InteriorSequence');
   }
}

sub _set_child2parent_links {
    ## nothing to do, Pod::ParseTrees cant have parent pointers
}

sub DESTROY {
   ## We need to get rid of all child->parent pointers throughout the
   ## tree so their reference counts will go to zero and they can be
   ## garbage-collected
   _unset_child2parent_links(@_);
}

#############################################################################

1;
