# Term::ANSIColor -- Color screen output using ANSI escape sequences.
# $Id: ANSIColor.pm,v 1.7 2003/03/26 07:00:51 eagle Exp $
#
# Copyright 1996, 1997, 1998, 2000, 2001, 2002
#   by Russ Allbery <rra@stanford.edu> and Zenin <zenin@bawdycaste.com>
#
# This program is free software; you may redistribute it and/or modify it
# under the same terms as Perl itself.
#
# Ah, September, when the sysadmins turn colors and fall off the trees....
#                               -- Dave Van Domelen

##############################################################################
# Modules and declarations
##############################################################################

package Term::ANSIColor;
require 5.001;

use strict;
use vars qw($AUTOLOAD $AUTORESET $EACHLINE @ISA @EXPORT @EXPORT_OK
            %EXPORT_TAGS $VERSION %attributes %attributes_r);

use Exporter ();
@ISA         = qw(Exporter);
@EXPORT      = qw(color colored);
@EXPORT_OK   = qw(uncolor);
%EXPORT_TAGS = (constants => [qw(CLEAR RESET BOLD UNDERLINE UNDERSCORE BLINK
                                 REVERSE CONCEALED BLACK RED GREEN YELLOW
                                 BLUE MAGENTA CYAN WHITE ON_BLACK ON_RED
                                 ON_GREEN ON_YELLOW ON_BLUE ON_MAGENTA
                                 ON_CYAN ON_WHITE)]);
Exporter::export_ok_tags ('constants');

# Don't use the CVS revision as the version, since this module is also in Perl
# core and too many things could munge CVS magic revision strings.
$VERSION = 1.07;

##############################################################################
# Internal data structures
##############################################################################

%attributes = ('clear'      => 0,
               'reset'      => 0,
               'bold'       => 1,
               'dark'       => 2,
               'underline'  => 4,
               'underscore' => 4,
               'blink'      => 5,
               'reverse'    => 7,
               'concealed'  => 8,

               'black'      => 30,   'on_black'   => 40,
               'red'        => 31,   'on_red'     => 41,
               'green'      => 32,   'on_green'   => 42,
               'yellow'     => 33,   'on_yellow'  => 43,
               'blue'       => 34,   'on_blue'    => 44,
               'magenta'    => 35,   'on_magenta' => 45,
               'cyan'       => 36,   'on_cyan'    => 46,
               'white'      => 37,   'on_white'   => 47);

# Reverse lookup.  Alphabetically first name for a sequence is preferred.
for (reverse sort keys %attributes) {
    $attributes_r{$attributes{$_}} = $_;
}

##############################################################################
# Implementation (constant form)
##############################################################################

# Time to have fun!  We now want to define the constant subs, which are named
# the same as the attributes above but in all caps.  Each constant sub needs
# to act differently depending on whether $AUTORESET is set.  Without
# autoreset:
#
#     BLUE "text\n"  ==>  "\e[34mtext\n"
#
# If $AUTORESET is set, we should instead get:
#
#     BLUE "text\n"  ==>  "\e[34mtext\n\e[0m"
#
# The sub also needs to handle the case where it has no arguments correctly.
# Maintaining all of this as separate subs would be a major nightmare, as well
# as duplicate the %attributes hash, so instead we define an AUTOLOAD sub to
# define the constant subs on demand.  To do that, we check the name of the
# called sub against the list of attributes, and if it's an all-caps version
# of one of them, we define the sub on the fly and then run it.
#
# If the environment variable ANSI_COLORS_DISABLED is set, turn all of the
# generated subs into pass-through functions that don't add any escape
# sequences.  This is to make it easier to write scripts that also work on
# systems without any ANSI support, like Windows consoles.
sub AUTOLOAD {
    my $enable_colors = !defined $ENV{ANSI_COLORS_DISABLED};
    my $sub;
    ($sub = $AUTOLOAD) =~ s/^.*:://;
    my $attr = $attributes{lc $sub};
    if ($sub =~ /^[A-Z_]+$/ && defined $attr) {
        $attr = $enable_colors ? "\e[" . $attr . 'm' : '';
        eval qq {
            sub $AUTOLOAD {
                if (\$AUTORESET && \@_) {
                    '$attr' . "\@_" . "\e[0m";
                } else {
                    ('$attr' . "\@_");
                }
            }
        };
        goto &$AUTOLOAD;
    } else {
        require Carp;
        Carp::croak ("undefined subroutine &$AUTOLOAD called");
    }
}

##############################################################################
# Implementation (attribute string form)
##############################################################################

# Return the escape code for a given set of color attributes.
sub color {
    return '' if defined $ENV{ANSI_COLORS_DISABLED};
    my @codes = map { split } @_;
    my $attribute = '';
    foreach (@codes) {
        $_ = lc $_;
        unless (defined $attributes{$_}) {
            require Carp;
            Carp::croak ("Invalid attribute name $_");
        }
        $attribute .= $attributes{$_} . ';';
    }
    chop $attribute;
    ($attribute ne '') ? "\e[${attribute}m" : undef;
}

# Return a list of named color attributes for a given set of escape codes.
# Escape sequences can be given with or without enclosing "\e[" and "m".  The
# empty escape sequence '' or "\e[m" gives an empty list of attrs.
sub uncolor {
    my (@nums, @result);
    for (@_) {
        my $escape = $_;
        $escape =~ s/^\e\[//;
        $escape =~ s/m$//;
        unless ($escape =~ /^((?:\d+;)*\d*)$/) {
            require Carp;
            Carp::croak ("Bad escape sequence $_");
        }
        push (@nums, split (/;/, $1));
    }
    for (@nums) {
	$_ += 0; # Strip leading zeroes
	my $name = $attributes_r{$_};
	if (!defined $name) {
	    require Carp;
	    Carp::croak ("No name for escape sequence $_" );
	}
	push (@result, $name);
    }
    @result;
}

# Given a string and a set of attributes, returns the string surrounded by
# escape codes to set those attributes and then clear them at the end of the
# string.  The attributes can be given either as an array ref as the first
# argument or as a list as the second and subsequent arguments.  If $EACHLINE
# is set, insert a reset before each occurrence of the string $EACHLINE and
# the starting attribute code after the string $EACHLINE, so that no attribute
# crosses line delimiters (this is often desirable if the output is to be
# piped to a pager or some other program).
sub colored {
    my ($string, @codes);
    if (ref $_[0]) {
        @codes = @{+shift};
        $string = join ('', @_);
    } else {
        $string = shift;
        @codes = @_;
    }
    return $string if defined $ENV{ANSI_COLORS_DISABLED};
    if (defined $EACHLINE) {
        my $attr = color (@codes);
        join '',
            map { $_ && $_ ne $EACHLINE ? $attr . $_ . "\e[0m" : $_ }
                split (/(\Q$EACHLINE\E)/, $string);
    } else {
        color (@codes) . $string . "\e[0m";
    }
}

##############################################################################
# Module return value and documentation
##############################################################################

# Ensure we evaluate to true.
1;
__END__

