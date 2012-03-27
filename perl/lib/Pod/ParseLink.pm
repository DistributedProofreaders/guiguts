# Pod::ParseLink -- Parse an L<> formatting code in POD text.
# $Id: ParseLink.pm,v 1.6 2002/07/15 05:46:00 eagle Exp $
#
# Copyright 2001 by Russ Allbery <rra@stanford.edu>
#
# This program is free software; you may redistribute it and/or modify it
# under the same terms as Perl itself.
#
# This module implements parsing of the text of an L<> formatting code as
# defined in perlpodspec.  It should be suitable for any POD formatter.  It
# exports only one function, parselink(), which returns the five-item parse
# defined in perlpodspec.
#
# Perl core hackers, please note that this module is also separately
# maintained outside of the Perl core as part of the podlators.  Please send
# me any patches at the address above in addition to sending them to the
# standard Perl mailing lists.

##############################################################################
# Modules and declarations
##############################################################################

package Pod::ParseLink;

require 5.004;

use strict;
use vars qw(@EXPORT @ISA $VERSION);

use Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw(parselink);

# Don't use the CVS revision as the version, since this module is also in Perl
# core and too many things could munge CVS magic revision strings.  This
# number should ideally be the same as the CVS revision in podlators, however.
$VERSION = 1.06;


##############################################################################
# Implementation
##############################################################################

# Parse the name and section portion of a link into a name and section.
sub _parse_section {
    my ($link) = @_;
    $link =~ s/^\s+//;
    $link =~ s/\s+$//;

    # If the whole link is enclosed in quotes, interpret it all as a section
    # even if it contains a slash.
    return (undef, $1) if ($link =~ /^"\s*(.*?)\s*"$/);

    # Split into page and section on slash, and then clean up quoting in the
    # section.  If there is no section and the name contains spaces, also
    # guess that it's an old section link.
    my ($page, $section) = split (/\s*\/\s*/, $link, 2);
    $section =~ s/^"\s*(.*?)\s*"$/$1/ if $section;
    if ($page && $page =~ / / && !defined ($section)) {
        $section = $page;
        $page = undef;
    } else {
        $page = undef unless $page;
        $section = undef unless $section;
    }
    return ($page, $section);
}

# Infer link text from the page and section.
sub _infer_text {
    my ($page, $section) = @_;
    my $inferred;
    if ($page && !$section) {
        $inferred = $page;
    } elsif (!$page && $section) {
        $inferred = '"' . $section . '"';
    } elsif ($page && $section) {
        $inferred = '"' . $section . '" in ' . $page;
    }
    return $inferred;
}

# Given the contents of an L<> formatting code, parse it into the link text,
# the possibly inferred link text, the name or URL, the section, and the type
# of link (pod, man, or url).
sub parselink {
    my ($link) = @_;
    $link =~ s/\s+/ /g;
    if ($link =~ /\A\w+:[^:\s]\S*\Z/) {
        return (undef, $link, $link, undef, 'url');
    } else {
        my $text;
        if ($link =~ /\|/) {
            ($text, $link) = split (/\|/, $link, 2);
        }
        my ($name, $section) = _parse_section ($link);
        my $inferred = $text || _infer_text ($name, $section);
        my $type = ($name && $name =~ /\(\S*\)/) ? 'man' : 'pod';
        return ($text, $inferred, $name, $section, $type);
    }
}


##############################################################################
# Module return value and documentation
##############################################################################

# Ensure we evaluate to true.
1;
__END__

