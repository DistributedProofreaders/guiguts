package DirHandle;

our $VERSION = '1.00';

require 5.000;
use Carp;
use Symbol;

sub new {
    @_ >= 1 && @_ <= 2 or croak 'usage: new DirHandle [DIRNAME]';
    my $class = shift;
    my $dh = gensym;
    if (@_) {
	DirHandle::open($dh, $_[0])
	    or return undef;
    }
    bless $dh, $class;
}

sub DESTROY {
    my ($dh) = @_;
    closedir($dh);
}

sub open {
    @_ == 2 or croak 'usage: $dh->open(DIRNAME)';
    my ($dh, $dirname) = @_;
    opendir($dh, $dirname);
}

sub close {
    @_ == 1 or croak 'usage: $dh->close()';
    my ($dh) = @_;
    closedir($dh);
}

sub read {
    @_ == 1 or croak 'usage: $dh->read()';
    my ($dh) = @_;
    readdir($dh);
}

sub rewind {
    @_ == 1 or croak 'usage: $dh->rewind()';
    my ($dh) = @_;
    rewinddir($dh);
}

1;
