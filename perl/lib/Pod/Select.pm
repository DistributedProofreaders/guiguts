#############################################################################
# Pod/Select.pm -- function to select portions of POD docs
#
# Copyright (C) 1996-2000 by Bradford Appleton. All rights reserved.
# This file is part of "PodParser". PodParser is free software;
# you can redistribute it and/or modify it under the same terms
# as Perl itself.
#############################################################################

package Pod::Select;

use vars qw($VERSION);
$VERSION = 1.13;  ## Current version of this package
require  5.005;    ## requires this Perl version or later

#############################################################################

#############################################################################

use strict;
#use diagnostics;
use Carp;
use Pod::Parser 1.04;
use vars qw(@ISA @EXPORT $MAX_HEADING_LEVEL);

@ISA = qw(Pod::Parser);
@EXPORT = qw(&podselect);

## Maximum number of heading levels supported for '=headN' directives
*MAX_HEADING_LEVEL = \3;

#############################################################################

##---------------------------------------------------------------------------

## =begin _PRIVATE_
## 
## =head1 B<_init_headings()>
## 
## Initialize the current set of active section headings.
## 
## =cut
## 
## =end _PRIVATE_

use vars qw(%myData @section_headings);

sub _init_headings {
    my $self = shift;
    local *myData = $self;

    ## Initialize current section heading titles if necessary
    unless (defined $myData{_SECTION_HEADINGS}) {
        local *section_headings = $myData{_SECTION_HEADINGS} = [];
        for (my $i = 0; $i < $MAX_HEADING_LEVEL; ++$i) {
            $section_headings[$i] = '';
        }
    }
}

##---------------------------------------------------------------------------

sub curr_headings {
    my $self = shift;
    $self->_init_headings()  unless (defined $self->{_SECTION_HEADINGS});
    my @headings = @{ $self->{_SECTION_HEADINGS} };
    return (@_ > 0  and  $_[0] =~ /^\d+$/) ? $headings[$_[0] - 1] : @headings;
}

##---------------------------------------------------------------------------

use vars qw(@selected_sections);

sub select {
    my $self = shift;
    my @sections = @_;
    local *myData = $self;
    local $_;

### NEED TO DISCERN A SECTION-SPEC FROM A RANGE-SPEC (look for m{^/.+/$}?)

    ##---------------------------------------------------------------------
    ## The following is a blatant hack for backward compatibility, and for
    ## implementing add_selection(). If the *first* *argument* is the
    ## string "+", then the remaining section specifications are *added*
    ## to the current set of selections; otherwise the given section
    ## specifications will *replace* the current set of selections.
    ##
    ## This should probably be fixed someday, but for the present time,
    ## it seems incredibly unlikely that "+" would ever correspond to
    ## a legitimate section heading
    ##---------------------------------------------------------------------
    my $add = ($sections[0] eq "+") ? shift(@sections) : "";

    ## Reset the set of sections to use
    unless (@sections > 0) {
        delete $myData{_SELECTED_SECTIONS}  unless ($add);
        return;
    }
    $myData{_SELECTED_SECTIONS} = []
        unless ($add  &&  exists $myData{_SELECTED_SECTIONS});
    local *selected_sections = $myData{_SELECTED_SECTIONS};

    ## Compile each spec
    my $spec;
    for $spec (@sections) {
        if ( defined($_ = &_compile_section_spec($spec)) ) {
            ## Store them in our sections array
            push(@selected_sections, $_);
        }
        else {
            carp "Ignoring section spec \"$spec\"!\n";
        }
    }
}

##---------------------------------------------------------------------------

sub add_selection {
    my $self = shift;
    $self->select("+", @_);
}

##---------------------------------------------------------------------------

sub clear_selections {
    my $self = shift;
    $self->select();
}

##---------------------------------------------------------------------------

sub match_section {
    my $self = shift;
    my (@headings) = @_;
    local *myData = $self;

    ## Return true if no restrictions were explicitly specified
    my $selections = (exists $myData{_SELECTED_SECTIONS})
                       ?  $myData{_SELECTED_SECTIONS}  :  undef;
    return  1  unless ((defined $selections) && (@{$selections} > 0));

    ## Default any unspecified sections to the current one
    my @current_headings = $self->curr_headings();
    for (my $i = 0; $i < $MAX_HEADING_LEVEL; ++$i) {
        (defined $headings[$i])  or  $headings[$i] = $current_headings[$i];
    }

    ## Look for a match against the specified section expressions
    my ($section_spec, $regex, $negated, $match);
    for $section_spec ( @{$selections} ) {
        ##------------------------------------------------------
        ## Each portion of this spec must match in order for
        ## the spec to be matched. So we will start with a 
        ## match-value of 'true' and logically 'and' it with
        ## the results of matching a given element of the spec.
        ##------------------------------------------------------
        $match = 1;
        for (my $i = 0; $i < $MAX_HEADING_LEVEL; ++$i) {
            $regex   = $section_spec->[$i];
            $negated = ($regex =~ s/^\!//);
            $match  &= ($negated ? ($headings[$i] !~ /${regex}/)
                                 : ($headings[$i] =~ /${regex}/));
            last unless ($match);
        }
        return  1  if ($match);
    }
    return  0;  ## no match
}

##---------------------------------------------------------------------------

sub is_selected {
    my ($self, $paragraph) = @_;
    local $_;
    local *myData = $self;

    $self->_init_headings()  unless (defined $myData{_SECTION_HEADINGS});

    ## Keep track of current sections levels and headings
    $_ = $paragraph;
    if (/^=((?:sub)*)(?:head(?:ing)?|sec(?:tion)?)(\d*)\s+(.*)\s*$/) {
        ## This is a section heading command
        my ($level, $heading) = ($2, $3);
        $level = 1 + (length($1) / 3)  if ((! length $level) || (length $1));
        ## Reset the current section heading at this level
        $myData{_SECTION_HEADINGS}->[$level - 1] = $heading;
        ## Reset subsection headings of this one to empty
        for (my $i = $level; $i < $MAX_HEADING_LEVEL; ++$i) {
            $myData{_SECTION_HEADINGS}->[$i] = '';
        }
    }

    return  $self->match_section();
}

#############################################################################

##---------------------------------------------------------------------------

sub podselect {
    my(@argv) = @_;
    my %defaults   = ();
    my $pod_parser = new Pod::Select(%defaults);
    my $num_inputs = 0;
    my $output = ">&STDOUT";
    my %opts = ();
    local $_;
    for (@argv) {
        if (ref($_)) {
            next unless (ref($_) eq 'HASH');
            %opts = (%defaults, %{$_});

            ##-------------------------------------------------------------
            ## Need this for backward compatibility since we formerly used
            ## options that were all uppercase words rather than ones that
            ## looked like Unix command-line options.
            ## to be uppercase keywords)
            ##-------------------------------------------------------------
            %opts = map {
                my ($key, $val) = (lc $_, $opts{$_});
                $key =~ s/^(?=\w)/-/;
                $key =~ /^-se[cl]/  and  $key  = '-sections';
                #! $key eq '-range'    and  $key .= 's';
                ($key => $val);    
            } (keys %opts);

            ## Process the options
            (exists $opts{'-output'})  and  $output = $opts{'-output'};

            ## Select the desired sections
            $pod_parser->select(@{ $opts{'-sections'} })
                if ( (defined $opts{'-sections'})
                     && ((ref $opts{'-sections'}) eq 'ARRAY') );

            #! ## Select the desired paragraph ranges
            #! $pod_parser->select(@{ $opts{'-ranges'} })
            #!     if ( (defined $opts{'-ranges'})
            #!          && ((ref $opts{'-ranges'}) eq 'ARRAY') );
        }
        else {
            $pod_parser->parse_from_file($_, $output);
            ++$num_inputs;
        }
    }
    $pod_parser->parse_from_file("-")  unless ($num_inputs > 0);
}

#############################################################################

##---------------------------------------------------------------------------

sub _compile_section_spec {
    my ($section_spec) = @_;
    my (@regexs, $negated);

    ## Compile the spec into a list of regexs
    local $_ = $section_spec;
    s|\\\\|\001|g;  ## handle escaped backward slashes
    s|\\/|\002|g;   ## handle escaped forward slashes

    ## Parse the regexs for the heading titles
    @regexs = split('/', $_, $MAX_HEADING_LEVEL);

    ## Set default regex for ommitted levels
    for (my $i = 0; $i < $MAX_HEADING_LEVEL; ++$i) {
        $regexs[$i]  = '.*'  unless ((defined $regexs[$i])
                                     && (length $regexs[$i]));
    }
    ## Modify the regexs as needed and validate their syntax
    my $bad_regexs = 0;
    for (@regexs) {
        $_ .= '.+'  if ($_ eq '!');
        s|\001|\\\\|g;       ## restore escaped backward slashes
        s|\002|\\/|g;        ## restore escaped forward slashes
        $negated = s/^\!//;  ## check for negation
        eval "/$_/";         ## check regex syntax
        if ($@) {
            ++$bad_regexs;
            carp "Bad regular expression /$_/ in \"$section_spec\": $@\n";
        }
        else {
            ## Add the forward and rear anchors (and put the negator back)
            $_ = '^' . $_  unless (/^\^/);
            $_ = $_ . '$'  unless (/\$$/);
            $_ = '!' . $_  if ($negated);
        }
    }
    return  (! $bad_regexs) ? [ @regexs ] : undef;
}

##---------------------------------------------------------------------------

##---------------------------------------------------------------------------

#############################################################################

1;

