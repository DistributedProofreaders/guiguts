package User::grent;
use strict;

use 5.006_001;
our $VERSION = '1.00';
our(@EXPORT, @EXPORT_OK, %EXPORT_TAGS);
BEGIN { 
    use Exporter   ();
    @EXPORT      = qw(getgrent getgrgid getgrnam getgr);
    @EXPORT_OK   = qw($gr_name $gr_gid $gr_passwd $gr_mem @gr_members);
    %EXPORT_TAGS = ( FIELDS => [ @EXPORT_OK, @EXPORT ] );
}
use vars      @EXPORT_OK;

# Class::Struct forbids use of @ISA
sub import { goto &Exporter::import }

use Class::Struct qw(struct);
struct 'User::grent' => [
    name    => '$',
    passwd  => '$',
    gid	    => '$',
    members => '@',
];

sub populate (@) {
    return unless @_;
    my $gob = new();
    ($gr_name, $gr_passwd, $gr_gid) = @$gob[0,1,2] = @_[0,1,2];
    @gr_members = @{$gob->[3]} = split ' ', $_[3];
    return $gob;
} 

sub getgrent ( ) { populate(CORE::getgrent()) } 
sub getgrnam ($) { populate(CORE::getgrnam(shift)) } 
sub getgrgid ($) { populate(CORE::getgrgid(shift)) } 
sub getgr    ($) { ($_[0] =~ /^\d+/) ? &getgrgid : &getgrnam } 

1;
__END__

