package Net::netent;
use strict;

use 5.006_001;
our $VERSION = '1.00';
our(@EXPORT, @EXPORT_OK, %EXPORT_TAGS);
BEGIN { 
    use Exporter   ();
    @EXPORT      = qw(getnetbyname getnetbyaddr getnet);
    @EXPORT_OK   = qw(
			$n_name	    	@n_aliases
			$n_addrtype 	$n_net
		   );
    %EXPORT_TAGS = ( FIELDS => [ @EXPORT_OK, @EXPORT ] );
}
use vars      @EXPORT_OK;

# Class::Struct forbids use of @ISA
sub import { goto &Exporter::import }

use Class::Struct qw(struct);
struct 'Net::netent' => [
   name		=> '$',
   aliases	=> '@',
   addrtype	=> '$',
   net		=> '$',
];

sub populate (@) {
    return unless @_;
    my $nob = new();
    $n_name 	 =    $nob->[0]     	     = $_[0];
    @n_aliases	 = @{ $nob->[1] } = split ' ', $_[1];
    $n_addrtype  =    $nob->[2] 	     = $_[2];
    $n_net	 =    $nob->[3] 	     = $_[3];
    return $nob;
} 

sub getnetbyname ($)  { populate(CORE::getnetbyname(shift)) } 

sub getnetbyaddr ($;$) { 
    my ($net, $addrtype);
    $net = shift;
    require Socket if @_;
    $addrtype = @_ ? shift : Socket::AF_INET();
    populate(CORE::getnetbyaddr($net, $addrtype)) 
} 

sub getnet($) {
    if ($_[0] =~ /^\d+(?:\.\d+(?:\.\d+(?:\.\d+)?)?)?$/) {
	require Socket;
	&getnetbyaddr(Socket::inet_aton(shift));
    } else {
	&getnetbyname;
    } 
} 

1;
__END__

