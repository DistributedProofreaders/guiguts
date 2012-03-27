# $Id: MD4.pm,v 1.2 2001/07/30 21:58:13 mikem Exp $
package Digest::MD4;

use strict;
use vars qw($VERSION @ISA @EXPORT);

require Exporter;
require DynaLoader;
require AutoLoader;

@ISA = qw(Exporter AutoLoader DynaLoader);
# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@EXPORT = qw(
	
);
$VERSION = '1.1';

bootstrap Digest::MD4 $VERSION;

# Preloaded methods go here.

sub addfile
{
    no strict 'refs';	# Countermand any strct refs in force so that we
			# can still handle file-handle names.

    my ($self, $handle) = @_;
    my ($package, $file, $line) = caller;
    my ($data) = '';

    if (!ref($handle))
    {
	# Old-style passing of filehandle by name. We need to add
	# the calling package scope qualifier, if there is not one
	# supplied already.

	$handle = $package . '::' . $handle unless ($handle =~ /(\:\:|\')/);
    }

    while (read($handle, $data, 1024))
    {
	$self->add($data);
    }
    return $self;
}

sub hexdigest
{
    my ($self) = shift;

    unpack("H*", ($self->digest()));
}

sub hash
{
    my ($self, $data) = @_;

    if (ref($self))
    {
	# This is an instance method call so reset the current context

	$self->reset();
    }
    else
    {
	# This is a static method invocation, create a temporary MD4 context

	$self = new Digest::MD4;
    }

    # Now do the hash

    $self->add($data);
    $self->digest();
}

sub hexhash
{
    my ($self, $data) = @_;

    unpack("H*", ($self->hash($data)));
}

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__

