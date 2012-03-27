### the gnu tar specification:
### http://www.gnu.org/manual/tar/html_node/tar_toc.html
###
### and the pax format spec, which tar derives from:
### http://www.opengroup.org/onlinepubs/007904975/utilities/pax.html

package Archive::Tar;
require 5.005_03;

use strict;
use vars qw[$DEBUG $error $VERSION $WARN $FOLLOW_SYMLINK $CHOWN $CHMOD];
$DEBUG          = 0;
$WARN           = 1;
$FOLLOW_SYMLINK = 0;
$VERSION        = "1.07";
$CHOWN          = 1;
$CHMOD          = 1;

use IO::File;
use Cwd;
use Carp qw(carp);
use FileHandle;
use File::Spec ();
use File::Spec::Unix ();
use File::Path ();

use Archive::Tar::File;
use Archive::Tar::Constant;

my $tmpl = {
    _data   => [ ],
    _file   => 'Unknown',
};    

### install get/set accessors for this object.
for my $key ( keys %$tmpl ) {
    no strict 'refs';
    *{__PACKAGE__."::$key"} = sub {
        my $self = shift;
        $self->{$key} = $_[0] if @_;
        return $self->{$key};
    }
}

sub new {

    ### copying $tmpl here since a shallow copy makes it use the
    ### same aref, causing for files to remain in memory always.
    my $obj = bless { _data => [ ], _file => 'Unknown' }, shift;

    $obj->read( @_ ) if @_;
    
    return $obj;
}

sub read {
    my $self = shift;    
    my $file = shift || $self->_file;
    my $gzip = shift || 0;
    my $opts = shift || {};
    
    unless( defined $file ) {
        $self->error( qq[No file to read from!] );
        return;
    } else {
        $self->_file( $file );
    }     
    
    my $handle = $self->_get_handle($file, $gzip, READ_ONLY->($gzip) ) 
                    or return;

    my $data = $self->_read_tar( $handle, $opts ) or return;

    $self->_data( $data );    

    return wantarray ? @$data : scalar @$data;
}

sub _get_handle {
    my $self = shift;
    my $file = shift;   return unless defined $file;
                        return $file if ref $file;
                        
    my $gzip = shift || 0;
    my $mode = shift || READ_ONLY->($gzip); # default to read only
    
    my $fh; my $bin;
    
    ### only default to ZLIB if we're not trying to /write/ to a handle ###
    if( ZLIB and $gzip || MODE_READ->( $mode ) ) {
        
        ### IO::Zlib will Do The Right Thing, even when passed a plain file ###
        $fh = new IO::Zlib;
    
    } else {    
        if( $gzip ) {
            $self->_error( qq[Compression not available - Install IO::Zlib!] );
            return;
        
        } else {
            $fh = new IO::File;
            $bin++;
        }
    }
        
    unless( $fh->open( $file, $mode ) ) {
        $self->_error( qq[Could not create filehandle for '$file': $!!] );
        return;
    }
    
    binmode $fh if $bin;
    
    return $fh;
}

sub _read_tar {
    my $self    = shift;
    my $handle  = shift or return;
    my $opts    = shift || {};

    my $count   = $opts->{limit}    || 0;
    my $extract = $opts->{extract}  || 0;
    
    ### set a cap on the amount of files to extract ###
    my $limit   = 0;
    $limit = 1 if $count > 0;
 
    my $tarfile = [ ];
    my $chunk;
    my $read = 0;
    my $real_name;  # to set the name of a file when we're encountering @longlink
    my $data;
         
    LOOP: 
    while( $handle->read( $chunk, HEAD ) ) {        
        
        unless( $read++ ) {
            my $gzip = GZIP_MAGIC_NUM;
            if( $chunk =~ /$gzip/ ) {
                $self->_error( qq[Can not read compressed format in tar-mode] );
                return;
            }
        }
              
        ### if we can't read in all bytes... ###
        last if length $chunk != HEAD;
        
        # Apparently this should really be two blocks of 512 zeroes,
	    # but GNU tar sometimes gets it wrong. See comment in the
	    # source code (tar.c) to GNU cpio.
        last if $chunk eq TAR_END; 
        
        my $entry; 
        unless( $entry = Archive::Tar::File->new( chunk => $chunk ) ) {
            $self->_error( qq[Couldn't read chunk '$chunk'] );
            next;
        }
        
        ### ignore labels:
        ### http://www.gnu.org/manual/tar/html_node/tar_139.html
        next if $entry->is_label;
        
        if( length $entry->type and ($entry->is_file || $entry->is_longlink) ) {
            
            if ( $entry->is_file && !$entry->validate ) {
                $self->_error( $entry->name . qq[: checksum error] );
                next LOOP;
            }
          
            ### part II of the @LongLink munging -- need to do /after/
            ### the checksum check.

            
            my $block = BLOCK_SIZE->( $entry->size );

            $data = $entry->get_content_by_ref;
#            while( $block ) {
#                $handle->read( $data, $block ) or (
#                    $self->_error( qq[Could not read block for ] . $entry->name ),
#                    return
#                );
#                $block > BUFFER 
#                    ? $block -= BUFFER
#                    : last;   
#                last if $block eq TAR_END;             
#            }
            
            ### just read everything into memory 
            ### can't do lazy loading since IO::Zlib doesn't support 'seek'
            ### this is because Compress::Zlib doesn't support it =/            
            if( $handle->read( $$data, $block ) < $block ) {
                $self->_error( qq[Read error on tarfile ']. $entry->name ."'" );
                return;
            }

            ### throw away trailing garbage ###
            substr ($$data, $entry->size) = "";
        }
        
        
        ### clean up of the entries.. posix tar /apparently/ has some
        ### weird 'feature' that allows for filenames > 255 characters
        ### they'll put a header in with as name '././@LongLink' and the
        ### contents will be the name of the /next/ file in the archive
        ### pretty crappy and kludgy if you ask me
        
        ### set the name for the next entry if this is a @LongLink;
        ### this is one ugly hack =/ but needed for direct extraction
        if( $entry->is_longlink ) {
            $real_name = $data;
            next;
        } elsif ( defined $real_name ) {
            $entry->name( $$real_name );
            undef $real_name;      
        }

        $self->_extract_file( $entry )  if $extract && !$entry->is_longlink
                                        && !$entry->is_unknown && !$entry->is_label;
        
        ### Guard against tarfiles with garbage at the end
	    last LOOP if $entry->name eq ''; 
    
        ### push only the name on the rv if we're extracting -- for extract_archive
        push @$tarfile, ($extract ? $entry->name : $entry);
    
        if( $limit ) {
            $count-- unless $entry->is_longlink || $entry->is_dir;    
            last LOOP unless $count;
        }
    } continue {
        undef $data;
    }      
    
    return $tarfile;
}    

sub contains_file {
    my $self = shift;
    my $full = shift or return;
    
    my @parts = File::Spec->splitdir($full);
    my $file  = pop @parts;
    my $path  = File::Spec::Unix->catdir( @parts );
    
    for my $obj ( $self->get_files ) {
        next unless $file eq $obj->name;
        next unless $path eq $obj->prefix;
    
        return 1;       
    }      
    return;
}    

sub extract {
    my $self    = shift;
    my @files   = @_ ? @_ : $self->list_files;

    unless( scalar @files ) {
        $self->_error( qq[No files found for ] . $self->_file );
        return;
    }
    
    for my $file ( @files ) {
        for my $entry ( @{$self->_data} ) {
            next unless $file eq $entry->name;
    
            unless( $self->_extract_file( $entry ) ) {
                $self->_error( qq[Could not extract '$file'] );
                return;
            }        
        }
    }
         
    return @files;        
}

sub _extract_file {
    my $self    = shift;
    my $entry   = shift or return;
    my $cwd     = cwd();
    
                            ### splitpath takes a bool at the end to indicate that it's splitting a dir    
    my ($vol,$dirs,$file)   = File::Spec::Unix->splitpath( $entry->name, $entry->is_dir );
    my @dirs                = File::Spec::Unix->splitdir( $dirs );
    my @cwd                 = File::Spec->splitdir( $cwd );
    my $dir                 = File::Spec->catdir(@cwd, @dirs);               
    
    if( -e $dir && !-d _ ) {
        $^W && $self->_error( qq['$dir' exists, but it's not a directory!\n] );
        return;
    }
    
    unless ( -d _ ) {
        eval { File::Path::mkpath( $dir, 0, 0777 ) };
        if( $@ ) {
            $self->_error( qq[Could not create directory '$dir': $@] );
            return;
        }
    }
    
    ### we're done if we just needed to create a dir ###
    return 1 if $entry->is_dir;
    
    my $full = File::Spec->catfile( $dir, $file );
    
    if( $entry->is_unknown ) {
        $self->_error( qq[Unknown file type for file '$full'] );
        return;
    }
    
    if( length $entry->type && $entry->is_file ) {
        my $fh = new FileHandle;
        $fh->open( '>' . $full ) or (
            $self->_error( qq[Could not open file '$full': $!] ),
            return
        );
    
        if( $entry->size ) {
            binmode $fh;
            syswrite $fh, $entry->data or (
                $self->_error( qq[Could not write data to '$full'] ),
                return
            );
        }
        
        close $fh or (
            $self->_error( qq[Could not close file '$full'] ),
            return
        );     
    
    } else {
        $self->_make_special_file( $entry, $full ) or return;
    } 

    utime time, $entry->mtime - TIME_OFFSET, $full or
        $self->_error( qq[Could not update timestamp] );

    if( $CHOWN && CAN_CHOWN ) {
        chown $entry->uid, $entry->gid, $full or
            $self->_error( qq[Could not set uid/gid on '$full'] );
    }
    
    if( $CHMOD ) {
        chmod $entry->mode, $full or
            $self->_error( qq[Could not chown '$full' to ] . $entry->mode );
    }            
    
    return 1;
}

sub _make_special_file {
    my $self    = shift;
    my $entry   = shift     or return;
    my $file    = shift;    return unless defined $file;
    
    my $err;
    
    if( $entry->is_symlink ) {
        ON_UNIX && symlink( $entry->linkname, $file ) or 
            $err =  qq[Making symbolink link from '] . $entry->linkname .
                    qq[' to '$file' failed]; 
    
    } elsif ( $entry->is_hardlink ) {
        ON_UNIX && link( $entry->linkname, $file ) or 
            $err =  qq[Making hard link from '] . $entry->linkname .
                    qq[' to '$file' failed];     
    
    } elsif ( $entry->is_fifo ) {
        ON_UNIX && !system('mknod', $file, 'p') or 
            $err = qq[Making fifo ']. $entry->name .qq[' failed];
 
    } elsif ( $entry->is_blockdev or $entry->is_chardev ) {
        my $mode = $entry->is_blockdev ? 'b' : 'c';
            
        ON_UNIX && !system('mknod', $file, $mode, $entry->devmajor, $entry->devminor ) or
            $err =  qq[Making block device ']. $entry->name .qq[' (maj=] .
                    $entry->devmajor . qq[ min=] . $entry->devminor .qq[) failed.];          
 
    } elsif ( $entry->is_socket ) {
        ### the original doesn't do anything special for sockets.... ###     
        1;
    }
    
    return $err ? $self->_error( $err ) : 1;
}

sub list_files {
    my $self = shift;
    my $aref = shift || [ ];
    
    unless( $self->_data ) {
        $self->read() or return;
    }
    
    if( @$aref == 0 or ( @$aref == 1 and $aref->[0] eq 'name' ) ) {
        return map { $_->name } @{$self->_data};     
    } else {
    
        #my @rv;
        #for my $obj ( @{$self->_data} ) {
        #    push @rv, { map { $_ => $obj->$_() } @$aref };
        #}
        #return @rv;
        
        ### this does the same as the above.. just needs a +{ }
        ### to make sure perl doesn't confuse it for a block
        return map { my $o=$_; +{ map { $_ => $o->$_() } @$aref } } @{$self->_data}; 
    }    
}

sub _find_entry {
    my $self = shift;
    my $file = shift;

    unless( defined $file ) {
        $self->_error( qq[No file specified] );
        return;
    }
    
    for my $entry ( @{$self->_data} ) {
        return $entry if $entry->name eq $file;      
    }
    
    $self->_error( qq[No such file in archive: '$file'] );
    return;
}    

sub get_files {
    my $self = shift;
    
    return @{ $self->_data } unless @_;
    
    my @list;
    for my $file ( @_ ) {
        push @list, grep { defined } $self->_find_entry( $file );
    }
    
    return @list;
}

sub get_content {
    my $self = shift;
    my $entry = $self->_find_entry( shift ) or return;
    
    return $entry->data;        
}    

sub replace_content {
    my $self = shift;
    my $entry = $self->_find_entry( shift ) or return;

    return $entry->replace_content( shift );
}    

sub rename {
    my $self = shift;
    my $file = shift; return unless defined $file;
    my $new  = shift; return unless defined $new;
    
    my $entry = $self->_find_entry( $file ) or return;
    
    return $entry->rename( $new );
}    

sub remove {
    my $self = shift;
    my @list = @_;
    
    my %seen = map { $_->name => $_ } @{$self->_data};
    delete $seen{ $_ } for @list;
    
    $self->_data( [values %seen] );
    
    return values %seen;   
}

sub clear {
    my $self = shift or return;
    
    $self->_data( [] );
    $self->_file( '' );
    
    return 1;
}    


sub write {
    my $self    = shift;
    my $file    = shift || '';
    my $gzip    = shift || 0;
    my $prefix  = shift || '';

    ### only need a handle if we have a file to print to ###
    my $handle = $file 
                    ? ( $self->_get_handle($file, $gzip, WRITE_ONLY->($gzip) ) 
                        or return )
                    : '';       

    my @rv;
    for my $entry ( @{$self->_data} ) {
    
        ### names are too long, and will get truncated if we don't add a
        ### '@LongLink' file...
        if( length($entry->name)    > NAME_LENGTH or 
            length($entry->prefix)  > PREFIX_LENGTH 
        ) {
            
            my $longlink = Archive::Tar::File->new( 
                            data => LONGLINK_NAME, 
                            File::Spec::Unix->catfile( grep { length } $entry->prefix, $entry->name ),
                            { type => LONGLINK }
                        );
            unless( $longlink ) {
                $self->_error( qq[Could not create 'LongLink' entry for oversize file '] . $entry->name ."'" );
                return;
            };                      
    
    
            if( $file ) {
                unless( $self->_write_to_handle( $handle, $longlink, $prefix ) ) {
                    $self->_error( qq[Could not write 'LongLink' entry for oversize file '] .  $entry->name ."'" );
                    return; 
                }
            } else {
                push @rv, $self->_format_tar_entry( $longlink, $prefix );
                push @rv, $entry->data              if  $entry->has_content;
                push @rv, TAR_PAD->( $entry->size ) if  $entry->has_content &&
                                                        $entry->size % BLOCK;
            }     
        }        
 
        if( $file ) {
            unless( $self->_write_to_handle( $handle, $entry, $prefix ) ) {
                $self->_error( qq[Could not write entry '] . $entry->name . qq[' to archive] );
                return;          
            }
        } else {
            push @rv, $self->_format_tar_entry( $entry, $prefix );
            push @rv, $entry->data              if  $entry->has_content;
            push @rv, TAR_PAD->( $entry->size ) if  $entry->has_content &&
                                                        $entry->size % BLOCK;
        }
    }
    
    if( $file ) {    
        print $handle TAR_END x 2 or (
            $self->_error( qq[Could not write tar end markers] ),
            return
        );
    } else {
        push @rv, TAR_END x 2;
    }
    
    return $file ? 1 : join '', @rv;
}

sub _write_to_handle {
    my $self    = shift;
    my $handle  = shift or return;
    my $entry   = shift or return;
    my $prefix  = shift || '';
    
    ### if the file is a symlink, there are 2 options:
    ### either we leave the symlink intact, but then we don't write any data
    ### OR we follow the symlink, which means we actually make a copy.
    ### if we do the latter, we have to change the TYPE of the entry to 'FILE'
    my $symlink_ok =  $entry->is_symlink && $Archive::Tar::FOLLOW_SYMLINK;
    my $content_ok = !$entry->is_symlink && $entry->has_content ;
    
    ### downgrade to a 'normal' file if it's a symlink we're going to treat
    ### as a regular file
    $entry->_downgrade_to_plainfile if $symlink_ok;
    
    my $header = $self->_format_tar_entry( $entry, $prefix );
        
    unless( $header ) {
        $self->_error( qq[Could not format header for entry: ] . $entry->name );
        return;
    }      

    print $handle $header or (
        $self->_error( qq[Could not write header for: ] . $entry->name ),
        return
    );
    
    if( $symlink_ok or $content_ok ) {
        print $handle $entry->data or (
            $self->_error( qq[Could not write data for: ] . $entry->name ),
            return
        );
        ### pad the end of the entry if required ###
        print $handle TAR_PAD->( $entry->size ) if $entry->size % BLOCK;
    }         
    
    return 1;
}


sub _format_tar_entry {
    my $self        = shift;
    my $entry       = shift or return;
    my $ext_prefix  = shift || '';

    my $file    = $entry->name;
    my $prefix  = $entry->prefix || '';
    my $match   = quotemeta $prefix;
    
    ### remove the prefix from the file name ###
    ### not sure if this is still neeeded --kane ###
    if( length $prefix ) {
        $file =~ s/^$match//;
    } 
    
    $prefix = File::Spec::Unix->catdir($ext_prefix, $prefix) if length $ext_prefix;
    
    ### not sure why this is... ###
    my $l = PREFIX_LENGTH; # is ambiguous otherwise...
    substr ($prefix, 0, -$l) = "" if length $prefix >= PREFIX_LENGTH;
    
    my $f1 = "%06o"; my $f2  = "%11o";
    
    ### this might be optimizable with a 'changed' flag in the file objects ###
    my $tar = pack (
                PACK,
                $file,
                
                (map { sprintf( $f1, $entry->$_() ) } qw[mode uid gid]),
                (map { sprintf( $f2, $entry->$_() ) } qw[size mtime]),
                
                "",  # checksum filed - space padded a bit down 
                
                (map { $entry->$_() }                 qw[type linkname magic]),
                
                $entry->version || TAR_VERSION,
                
                (map { $entry->$_() }                 qw[uname gname]),
                (map { sprintf( $f1, $entry->$_() ) } qw[devmajor devminor]),
                
                $prefix
    );
    
    ### add the checksum ###
    substr($tar,148,7) = sprintf("%6o\0", unpack("%16C*",$tar));

    return $tar;
}           

sub add_files {
    my $self    = shift;
    my @files   = @_ or return ();
    
    my @rv;
    for my $file ( @files ) {
        unless( -e $file ) {
            $self->_error( qq[No such file: '$file'] );
            next;
        }
    
        my $obj = Archive::Tar::File->new( file => $file );
        unless( $obj ) {
            $self->_error( qq[Unable to add file: '$file'] );
            next;
        }      

        push @rv, $obj;
    }
    
    push @{$self->{_data}}, @rv;
    
    return @rv;
}

sub add_data {
    my $self    = shift;
    my ($file, $data, $opt) = @_; 

    my $obj = Archive::Tar::File->new( data => $file, $data, $opt );
    unless( $obj ) {
        $self->_error( qq[Unable to add file: '$file'] );
        return;
    }      

    push @{$self->{_data}}, $obj;

    return $obj;
}

{
    $error = '';
    my $longmess;
    
    sub _error {
        my $self    = shift;
        my $msg     = $error = shift;
        $longmess   = Carp::longmess($error);
        
        ### set Archive::Tar::WARN to 0 to disable printing
        ### of errors
        if( $WARN ) {
            carp $DEBUG ? $longmess : $msg;
        }
        
        return;
    }
    
    sub error {
        my $self = shift;
        return shift() ? $longmess : $error;          
    }
}         


sub create_archive {
    my $class = shift;
    
    my $file    = shift; return unless defined $file;
    my $gzip    = shift || 0;
    my @files   = @_;
    
    unless( @files ) {
        return $class->_error( qq[Cowardly refusing to create empty archive!] );
    }        
    
    my $tar = $class->new;
    $tar->add_files( @files );
    return $tar->write( $file, $gzip );    
}

sub list_archive {
    my $class   = shift;
    my $file    = shift; return unless defined $file;
    my $gzip    = shift || 0;

    my $tar = $class->new($file, $gzip);
    return unless $tar;
    
    return $tar->list_files( @_ ); 
}

sub extract_archive {
    my $class   = shift;
    my $file    = shift; return unless defined $file;
    my $gzip    = shift || 0;
    
    my $tar = $class->new( ) or return;
    
    return $tar->read( $file, $gzip, { extract => 1 } );
}

1;

__END__

