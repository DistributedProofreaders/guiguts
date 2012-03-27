package Archive::Tar::File;
use strict;

use File::Spec::Unix ();
use File::Spec ();
use File::Basename ();
use Archive::Tar::Constant;

use vars qw[@ISA $VERSION];
@ISA        = qw[Archive::Tar];
$VERSION    = 0.01;

### set value to 1 to oct() it during the unpack ###
my $tmpl = [
        name        => 0,   # string   
        mode        => 1,   # octal
        uid         => 1,   # octal
        gid         => 1,   # octal
        size        => 1,   # octal
        mtime       => 1,   # octal
        chksum      => 1,   # octal
        type        => 0,   # character
        linkname    => 0,   # string
        magic       => 0,   # string
        version     => 0,   # 2 bytes
        uname       => 0,   # string
        gname       => 0,   # string
        devmajor    => 1,   # octal
        devminor    => 1,   # octal
        prefix      => 0,

### end UNPACK items ###    
        raw         => 0,   # the raw data chunk
        data        => 0,   # the data associated with the file -- 
                            # This  might be very memory intensive
];

### install get/set accessors for this object.
for ( my $i=0; $i<scalar @$tmpl ; $i+=2 ) {
    my $key = $tmpl->[$i];
    no strict 'refs';
    *{__PACKAGE__."::$key"} = sub {
        my $self = shift;
        $self->{$key} = $_[0] if @_;
        
        ### just in case the key is not there or undef or something ###    
        {   local $^W = 0;
            return $self->{$key};
        }
    }
}

sub new {
    my $class   = shift;
    my $what    = shift;
    
    my $obj =   ($what eq 'chunk') ? __PACKAGE__->_new_from_chunk( @_ ) :
                ($what eq 'file' ) ? __PACKAGE__->_new_from_file( @_ ) :
                ($what eq 'data' ) ? __PACKAGE__->_new_from_data( @_ ) :
                undef;
    
    return $obj;
}

sub _new_from_chunk {
    my $class = shift;
    my $chunk = shift or return undef;
    
    ### makes it start at 0 actually... :) ###
    my $i = -1;
    my %entry = map { 
        $tmpl->[++$i] => $tmpl->[++$i] ? oct $_ : $_    
    } map { /^([^\0]*)/ } unpack( UNPACK, $chunk );
    
    my $obj = bless \%entry, $class;

	### magic is a filetype string.. it should have something like 'ustar' or
	### something similar... if the chunk is garbage, skip it
	return unless $obj->magic !~ /\W/;

    ### store the original chunk ###
    $obj->raw( $chunk );

    ### do some cleaning up ###
    ### all paths are unix paths as per tar format spec ###
    $obj->name( File::Spec::Unix->catfile( $obj->prefix, $obj->name ) ) if $obj->prefix;
    
    ### no reason to drop it, makes writing it out easier ###
    #$obj->prefix('');
    
    $obj->type(FILE) if ( (!length $obj->type) or ($obj->type =~ /\W/) );

    $obj->type(DIR) if ( ($obj->is_file) && ($obj->name =~ m|/$|) );    

    ### weird thing in tarfiles -- if the file is actually a @LongLink,
    ### the data part seems to have a trailing ^@ (unprintable) char.
    ### to display, pipe output through less.
    ### at any rate, we better remove that character here, or tests like
    ### 'eq' and hashlook ups bases on names will SO not work
    $obj->size( $obj->size - 1 ) if $obj->is_longlink;
             
    return $obj;
}

sub _new_from_file {
    my $class       = shift;
    my $path        = shift or return undef;

    my $fh = new FileHandle;
    $fh->open("$path") or return undef;
    
    ### binmode needed to read files properly on win32 ###
    binmode $fh;
   
    my ($prefix,$file) = $class->_prefix_and_file($path);

    my @items       = qw[mode uid gid size mtime];
    my %hash        = map { shift(@items), $_ } (lstat $path)[2,4,5,7,9];
    $hash{mtime}    -= TIME_OFFSET;

    my $type        = __PACKAGE__->_filetype($path);
    
    ### probably requires some file path munging here ... ###
    my $obj = {
        %hash,
        name        => $file,
        chksum      => CHECK_SUM,
        type        => $type,         
        linkname    => ($type == SYMLINK and CAN_READLINK) ? readlink $path : '',
        magic       => MAGIC,
        version     => TAR_VERSION,
        uname       => UNAME->( $hash{uid} ),
        gname       => GNAME->( $hash{gid} ),
        devmajor    => 0,   # not handled
        devminor    => 0,   # not handled
        prefix      => $prefix,
        data        => scalar do { local $/; <$fh> },
    };      

    close $fh;
    
    return bless $obj, $class;
}

sub _new_from_data {
    my $class   = shift;
    my $path    = shift     or return undef;
    my $data    = shift;    return undef unless defined $data;
    my $opt     = shift;
    
    my ($prefix,$file) = $class->_prefix_and_file($path);

    my $obj = {
        data        => $data,
        name        => $file,
        mode        => MODE,
        uid         => UID,
        gid         => GID,
        size        => length $data,
        mtime       => time - TIME_OFFSET,
        chksum      => CHECK_SUM,
        type        => FILE,
        linkname    => '',
        magic       => MAGIC,
        version     => TAR_VERSION,
        uname       => UNAME->( UID ),
        gname       => GNAME->( GID ),
        devminor    => 0,
        devmajor    => 0,
        prefix      => $prefix,
    };      
    
    ### overwrite with user options, if provided ###
    if( $opt and ref $opt eq 'HASH' ) {
        for my $key ( keys %$opt ) {
            
            ### don't write bogus options ###
            next unless exists $obj->{key};
            $obj->{$key} = $opt->{key};
        }
    }

    return bless $obj, $class;

}

sub _prefix_and_file {
    my $self = shift;
    my $path = shift;
    
    my ($vol, $dirs, $file) = File::Spec->splitpath( $path );
      
    my $prefix = File::Spec::Unix->catdir(
                        grep { length } 
                        $vol,
                        File::Spec->splitdir( $dirs ),
                    );           
    return( $prefix, $file );
}
    
sub _filetype {
    my $self = shift;
    my $file = shift or return undef;

    return SYMLINK  if (-l $file);	# Symlink

    return FILE     if (-f _);		# Plain file

    return DIR      if (-d _);		# Directory

    return FIFO     if (-p _);		# Named pipe

    return SOCKET   if (-S _);		# Socket

    return BLOCKDEV if (-b _);		# Block special

    return CHARDEV  if (-c _);		# Character special
    
    ### shouldn't happen, this is when making archives, not reading ###
    return LONGLINK if ( $file eq LONGLINK_NAME );

    return UNKNOWN;		            # Something else (like what?)

}

### this method 'downgrades' a file to plain file -- this is used for
### symlinks when FOLLOW_SYMLINKS is true.
sub _downgrade_to_plainfile {
    my $entry = shift;
    $entry->type( FILE );
    $entry->mode( MODE );
    $entry->linkname('');   

    return 1;
}    

sub validate {
    my $self = shift;
    
    my $raw = $self->raw;    
    
    ### don't know why this one is different from the one we /write/ ###
    substr ($raw, 148, 8) = "        ";
	return unpack ("%16C*", $raw) == $self->chksum ? 1 : 0;	
}

sub has_content {
    my $self = shift;
    return defined $self->data() && length $self->data() ? 1 : 0;
}

sub get_content {
    my $self = shift;
    $self->data( );
}

sub get_content_by_ref {
    my $self = shift;
    
    return \$self->{data};
}

sub replace_content {
    my $self = shift;
    my $data = shift || '';
    
    $self->data( $data );
    $self->size( length $data );
    return 1;
}

sub rename {
    my $self = shift;
    my $path = shift or return undef;
    
    my ($prefix,$file) = $self->_prefix_and_file( $path );    
    
    $self->name( $path );
    $self->prefix( $prefix );

	return 1;
}

#stupid perl5.5.3 needs to warn if it's not numeric 
sub is_file     { local $^W;    FILE      == $_[0]->type }    
sub is_dir      { local $^W;    DIR       == $_[0]->type }
sub is_hardlink { local $^W;    HARDLINK  == $_[0]->type }
sub is_symlink  { local $^W;    SYMLINK   == $_[0]->type }
sub is_chardev  { local $^W;    CHARDEV   == $_[0]->type }
sub is_blockdev { local $^W;    BLOCKDEV  == $_[0]->type }
sub is_fifo     { local $^W;    FIFO      == $_[0]->type }
sub is_socket   { local $^W;    SOCKET    == $_[0]->type }
sub is_unknown  { local $^W;    UNKNOWN   == $_[0]->type } 
sub is_longlink { local $^W;    LONGLINK  eq $_[0]->type }
sub is_label    { local $^W;    LABEL     eq $_[0]->type }

1;
