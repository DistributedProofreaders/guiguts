package File::stat;
use 5.006;

use strict;
use warnings;

our(@EXPORT, @EXPORT_OK, %EXPORT_TAGS);

our $VERSION = '1.00';

BEGIN { 
    use Exporter   ();
    @EXPORT      = qw(stat lstat);
    @EXPORT_OK   = qw( $st_dev	   $st_ino    $st_mode 
		       $st_nlink   $st_uid    $st_gid 
		       $st_rdev    $st_size 
		       $st_atime   $st_mtime  $st_ctime 
		       $st_blksize $st_blocks
		    );
    %EXPORT_TAGS = ( FIELDS => [ @EXPORT_OK, @EXPORT ] );
}
use vars @EXPORT_OK;

# Class::Struct forbids use of @ISA
sub import { goto &Exporter::import }

use Class::Struct qw(struct);
struct 'File::stat' => [
     map { $_ => '$' } qw{
	 dev ino mode nlink uid gid rdev size
	 atime mtime ctime blksize blocks
     }
];

sub populate (@) {
    return unless @_;
    my $stob = new();
    @$stob = (
	$st_dev, $st_ino, $st_mode, $st_nlink, $st_uid, $st_gid, $st_rdev,
        $st_size, $st_atime, $st_mtime, $st_ctime, $st_blksize, $st_blocks ) 
	    = @_;
    return $stob;
} 

sub lstat ($)  { populate(CORE::lstat(shift)) }

sub stat ($) {
    my $arg = shift;
    my $st = populate(CORE::stat $arg);
    return $st if $st;
	my $fh;
    {
		local $!;
		no strict 'refs';
		require Symbol;
		$fh = \*{ Symbol::qualify( $arg, caller() )};
		return unless defined fileno $fh;
	}
    return populate(CORE::stat $fh);
}

1;
__END__

