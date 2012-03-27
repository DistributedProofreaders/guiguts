package HTML::LinkExtor;

# $Id: LinkExtor.pm,v 1.33 2003/10/10 10:20:56 gisle Exp $

require HTML::Parser;
@ISA = qw(HTML::Parser);
$VERSION = sprintf("%d.%02d", q$Revision: 1.33 $ =~ /(\d+)\.(\d+)/);

use strict;
use HTML::Tagset ();

# legacy (some applications grabs this hash directly)
use vars qw(%LINK_ELEMENT);
*LINK_ELEMENT = \%HTML::Tagset::linkElements;

sub new
{
    my($class, $cb, $base) = @_;
    my $self = $class->SUPER::new(
                    start_h => ["_start_tag", "self,tagname,attr"],
		    report_tags => [keys %HTML::Tagset::linkElements],
	       );
    $self->{extractlink_cb} = $cb;
    if ($base) {
	require URI;
	$self->{extractlink_base} = URI->new($base);
    }
    $self;
}

sub _start_tag
{
    my($self, $tag, $attr) = @_;

    my $base = $self->{extractlink_base};
    my $links = $HTML::Tagset::linkElements{$tag};
    $links = [$links] unless ref $links;

    my @links;
    my $a;
    for $a (@$links) {
	next unless exists $attr->{$a};
	push(@links, $a, $base ? URI->new($attr->{$a}, $base)->abs($base)
                               : $attr->{$a});
    }
    return unless @links;
    $self->_found_link($tag, @links);
}

sub _found_link
{
    my $self = shift;
    my $cb = $self->{extractlink_cb};
    if ($cb) {
	&$cb(@_);
    } else {
	push(@{$self->{'links'}}, [@_]);
    }
}

sub links
{
    my $self = shift;
    exists($self->{'links'}) ? @{delete $self->{'links'}} : ();
}

# We override the parse_file() method so that we can clear the links
# before we start a new file.
sub parse_file
{
    my $self = shift;
    delete $self->{'links'};
    $self->SUPER::parse_file(@_);
}

1;
