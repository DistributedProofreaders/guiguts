package File::Spec::Unix;

use strict;
use vars qw($VERSION);

$VERSION = '1.5';

sub canonpath {
    my ($self,$path) = @_;
    
    # Handle POSIX-style node names beginning with double slash (qnx, nto)
    # Handle network path names beginning with double slash (cygwin)
    # (POSIX says: "a pathname that begins with two successive slashes
    # may be interpreted in an implementation-defined manner, although
    # more than two leading slashes shall be treated as a single slash.")
    my $node = '';
    if ( $^O =~ m/^(?:qnx|nto|cygwin)$/ && $path =~ s:^(//[^/]+)(/|\z):/:s ) {
      $node = $1;
    }
    # This used to be
    # $path =~ s|/+|/|g unless($^O eq 'cygwin');
    # but that made tests 29, 30, 35, 46, and 213 (as of #13272) to fail
    # (Mainly because trailing "" directories didn't get stripped).
    # Why would cygwin avoid collapsing multiple slashes into one? --jhi
    $path =~ s|/+|/|g;                             # xx////xx  -> xx/xx
    $path =~ s@(/\.)+(/|\Z(?!\n))@/@g;             # xx/././xx -> xx/xx
    $path =~ s|^(\./)+||s unless $path eq "./";    # ./xx      -> xx
    $path =~ s|^/(\.\./)+|/|s;                     # /../../xx -> xx
    $path =~ s|/\Z(?!\n)|| unless $path eq "/";          # xx/       -> xx
    return "$node$path";
}

sub catdir {
    my $self = shift;

    $self->canonpath(join('/', @_, '')); # '' because need a trailing '/'
}

sub catfile {
    my $self = shift;
    my $file = $self->canonpath(pop @_);
    return $file unless @_;
    my $dir = $self->catdir(@_);
    $dir .= "/" unless substr($dir,-1) eq "/";
    return $dir.$file;
}

sub curdir () { '.' }

sub devnull () { '/dev/null' }

sub rootdir () { '/' }

my $tmpdir;
sub _tmpdir {
    return $tmpdir if defined $tmpdir;
    my $self = shift;
    my @dirlist = @_;
    {
	no strict 'refs';
	if (${"\cTAINT"}) { # Check for taint mode on perl >= 5.8.0
            require Scalar::Util;
	    @dirlist = grep { ! Scalar::Util::tainted($_) } @dirlist;
	}
    }
    foreach (@dirlist) {
	next unless defined && -d && -w _;
	$tmpdir = $_;
	last;
    }
    $tmpdir = $self->curdir unless defined $tmpdir;
    $tmpdir = defined $tmpdir && $self->canonpath($tmpdir);
    return $tmpdir;
}

sub tmpdir {
    return $tmpdir if defined $tmpdir;
    my $self = shift;
    $tmpdir = $self->_tmpdir( $ENV{TMPDIR}, "/tmp" );
}

sub updir () { '..' }

sub no_upwards {
    my $self = shift;
    return grep(!/^\.{1,2}\Z(?!\n)/s, @_);
}

sub case_tolerant () { 0 }

sub file_name_is_absolute {
    my ($self,$file) = @_;
    return scalar($file =~ m:^/:s);
}

sub path {
    return () unless exists $ENV{PATH};
    my @path = split(':', $ENV{PATH});
    foreach (@path) { $_ = '.' if $_ eq '' }
    return @path;
}

sub join {
    my $self = shift;
    return $self->catfile(@_);
}

sub splitpath {
    my ($self,$path, $nofile) = @_;

    my ($volume,$directory,$file) = ('','','');

    if ( $nofile ) {
        $directory = $path;
    }
    else {
        $path =~ m|^ ( (?: .* / (?: \.\.?\Z(?!\n) )? )? ) ([^/]*) |xs;
        $directory = $1;
        $file      = $2;
    }

    return ($volume,$directory,$file);
}


sub splitdir {
    return split m|/|, $_[1], -1;  # Preserve trailing fields
}


sub catpath {
    my ($self,$volume,$directory,$file) = @_;

    if ( $directory ne ''                && 
         $file ne ''                     && 
         substr( $directory, -1 ) ne '/' && 
         substr( $file, 0, 1 ) ne '/' 
    ) {
        $directory .= "/$file" ;
    }
    else {
        $directory .= $file ;
    }

    return $directory ;
}

sub abs2rel {
    my($self,$path,$base) = @_;

    # Clean up $path
    if ( ! $self->file_name_is_absolute( $path ) ) {
        $path = $self->rel2abs( $path ) ;
    }
    else {
        $path = $self->canonpath( $path ) ;
    }

    # Figure out the effective $base and clean it up.
    if ( !defined( $base ) || $base eq '' ) {
        $base = $self->_cwd();
    }
    elsif ( ! $self->file_name_is_absolute( $base ) ) {
        $base = $self->rel2abs( $base ) ;
    }
    else {
        $base = $self->canonpath( $base ) ;
    }

    # Now, remove all leading components that are the same
    my @pathchunks = $self->splitdir( $path);
    my @basechunks = $self->splitdir( $base);

    while (@pathchunks && @basechunks && $pathchunks[0] eq $basechunks[0]) {
        shift @pathchunks ;
        shift @basechunks ;
    }

    $path = CORE::join( '/', @pathchunks );
    $base = CORE::join( '/', @basechunks );

    # $base now contains the directories the resulting relative path 
    # must ascend out of before it can descend to $path_directory.  So, 
    # replace all names with $parentDir
    $base =~ s|[^/]+|..|g ;

    # Glue the two together, using a separator if necessary, and preventing an
    # empty result.
    if ( $path ne '' && $base ne '' ) {
        $path = "$base/$path" ;
    } else {
        $path = "$base$path" ;
    }

    return $self->canonpath( $path ) ;
}

sub rel2abs {
    my ($self,$path,$base ) = @_;

    # Clean up $path
    if ( ! $self->file_name_is_absolute( $path ) ) {
        # Figure out the effective $base and clean it up.
        if ( !defined( $base ) || $base eq '' ) {
	    $base = $self->_cwd();
        }
        elsif ( ! $self->file_name_is_absolute( $base ) ) {
            $base = $self->rel2abs( $base ) ;
        }
        else {
            $base = $self->canonpath( $base ) ;
        }

        # Glom them together
        $path = $self->catdir( $base, $path ) ;
    }

    return $self->canonpath( $path ) ;
}

# Internal routine to File::Spec, no point in making this public since
# it is the standard Cwd interface.  Most of the platform-specific
# File::Spec subclasses use this.
sub _cwd {
    require Cwd;
    Cwd::cwd();
}

1;
