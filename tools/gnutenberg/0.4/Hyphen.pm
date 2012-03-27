# The Gnutenberg Press - Conversion Process Driver
# Copyright (C) 2004-2005  Marcello Perathoner
# 
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#

# provides hyphenation using TeX hyphenation patterns

package Hyphen;
use strict;

sub new {
    my $class = shift;
    my %opts  = @_;

    my $file = $opts{'file'};

    open (FILE, '<:utf8', $file) or die ("Error opening file `$file'");

    my $self = {};
    bless $self, $class;

    # defaults

    $self->{'leftmin'}    = exists $opts{'leftmin'}    ? $opts{'leftmin'}    : 2;
    $self->{'rightmin'}   = exists $opts{'rightmin'}   ? $opts{'rightmin'}   : 2;
    $self->{'hyphenchar'} = exists $opts{'hyphenchar'} ? $opts{'hyphenchar'} : '-';
    $self->{'debug'}      = exists $opts{'debug'}      ? $opts{'debug'}      : 0;

    $self->{'tree'} = {};

    while (<FILE>) {
        next if m/^%/;
        chomp;

        my ($tag, $value) = ($_, $_);
        $tag   =~ s!\d!!g;	# get the string
        $value =~ s!\D!!g;	# and numbers apart

        # build the tree

        my $n = $self->{'tree'};
        foreach my $c (split (//, $tag)) {
            $n->{$c} = {} if (!exists $n->{$c});
            $n = $n->{$c};
        }
        $n->{'value'} = $value;
    }
    close FILE;

    return $self;
}

sub hyphenate {
    my ($self, $word) = (shift, shift);

    my @patterns;
    my $i;

    return $word if (length ($word) < $self->{'rightmin'} + $self->{'leftmin'});

    for ($i = 0; $i < length ($word) + 1; $i++) {
        $patterns[$i] = 0;
    }
    my $patlen = scalar (@patterns);

    ### walk the tree and find matching patterns

    my @chars = split (//, '.' . lc ($word) . '.');
    my $len = scalar (@chars);

    for ($i = 0; $i < $len; $i++) {
        my $n = $self->{'tree'};
        # print ("|");
        for my $c (@chars[$i .. $len - 1]) {
            last if (!exists ($n->{$c}));
            # print $c;
            $n = $n->{$c};
            if (exists ($n->{'value'})) {
                # print "($n->{'value'})";
                my @p = split (//, $n->{'value'});
                my ($j, $k);
                for ($k = 0; $k < scalar @p; $k++) {
                    my $j = $k + $i -1;
                    $patterns[$j] = $p[$k] if ($j < $patlen && $p[$k] > $patterns[$j]);
                }
            }
        }
    }

    if ($self->{'debug'}) {
        my $s = join (' ', @patterns);
        my $i = 1;
        foreach my $c (split (//, $word)) {
            substr ($s, $i, 1) = $c;
            $i += 2;
        }
        $self->{'lastpattern'} = $s;
    }

    for ($i = $len - 2 - $self->{'rightmin'}; $i >= $self->{'leftmin'}; $i--) {
        if ($patterns[$i] % 2) {
            substr ($word, $i, 0) = $self->{'hyphenchar'};
        }
    }

    return $word;
}

1;
