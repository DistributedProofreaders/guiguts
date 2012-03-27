package HTTP::Message;

# $Id: Message.pm,v 1.30 2003/10/24 10:25:16 gisle Exp $

use strict;
use vars qw($VERSION $AUTOLOAD);
$VERSION = sprintf("%d.%02d", q$Revision: 1.30 $ =~ /(\d+)\.(\d+)/);

require HTTP::Headers;
require Carp;

$HTTP::URI_CLASS ||= $ENV{PERL_HTTP_URI_CLASS} || "URI";
eval "require $HTTP::URI_CLASS"; die $@ if $@;



sub new
{
    my($class, $header, $content) = @_;
    if (defined $header) {
	Carp::croak("Bad header argument") unless ref $header;
	$header = $header->clone;
    }
    else {
	$header = HTTP::Headers->new;
    }
    $content = '' unless defined $content;
    bless {
	'_headers' => $header,
	'_content' => $content,
    }, $class;
}


sub clone
{
    my $self  = shift;
    my $clone = HTTP::Message->new($self->{'_headers'}, $self->{'_content'});
    $clone;
}


sub protocol { shift->_elem('_protocol',  @_); }
sub content  { shift->_elem('_content',  @_); }


sub add_content
{
    my $self = shift;
    if (ref($_[0])) {
	$self->{'_content'} .= ${$_[0]};  # for backwards compatability
    }
    else {
	$self->{'_content'} .= $_[0];
    }
}


sub content_ref
{
    my $self = shift;
    \$self->{'_content'};
}


sub as_string
{
    "";  # To be overridden in subclasses
}


sub headers            { shift->{'_headers'};                }
sub headers_as_string  { shift->{'_headers'}->as_string(@_); }


# delegate all other method calls the the _headers object.
sub AUTOLOAD
{
    my $method = substr($AUTOLOAD, rindex($AUTOLOAD, '::')+2);
    return if $method eq "DESTROY";

    # We create the function here so that it will not need to be
    # autoloaded the next time.
    no strict 'refs';
    *$method = eval "sub { shift->{'_headers'}->$method(\@_) }";
    goto &$method;
}


# Private method to access members in %$self
sub _elem
{
    my $self = shift;
    my $elem = shift;
    my $old = $self->{$elem};
    $self->{$elem} = $_[0] if @_;
    return $old;
}


1;


__END__

