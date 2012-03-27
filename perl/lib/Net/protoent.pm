package Net::protoent;
use strict;

use 5.006_001;
our $VERSION = '1.00';
our(@EXPORT, @EXPORT_OK, %EXPORT_TAGS);
BEGIN { 
    use Exporter   ();
    @EXPORT      = qw(getprotobyname getprotobynumber getprotoent getproto);
    @EXPORT_OK   = qw( $p_name @p_aliases $p_proto );
    %EXPORT_TAGS = ( FIELDS => [ @EXPORT_OK, @EXPORT ] );
}
use vars      @EXPORT_OK;

# Class::Struct forbids use of @ISA
sub import { goto &Exporter::import }

use Class::Struct qw(struct);
struct 'Net::protoent' => [
   name		=> '$',
   aliases	=> '@',
   proto	=> '$',
];

sub populate (@) {
    return unless @_;
    my $pob = new();
    $p_name 	 =    $pob->[0]     	     = $_[0];
    @p_aliases	 = @{ $pob->[1] } = split ' ', $_[1];
    $p_proto	 =    $pob->[2] 	     = $_[2];
    return $pob;
} 

sub getprotoent      ( )  { populate(CORE::getprotoent()) } 
sub getprotobyname   ($)  { populate(CORE::getprotobyname(shift)) } 
sub getprotobynumber ($)  { populate(CORE::getprotobynumber(shift)) } 

sub getproto ($;$) {
    no strict 'refs';
    return &{'getprotoby' . ($_[0]=~/^\d+$/ ? 'number' : 'name')}(@_);
}

1;

__END__

