package Net::servent;
use strict;

use 5.006_001;
our $VERSION = '1.01';
our(@EXPORT, @EXPORT_OK, %EXPORT_TAGS);
BEGIN {
    use Exporter   ();
    @EXPORT      = qw(getservbyname getservbyport getservent getserv);
    @EXPORT_OK   = qw( $s_name @s_aliases $s_port $s_proto );
    %EXPORT_TAGS = ( FIELDS => [ @EXPORT_OK, @EXPORT ] );
}
use vars      @EXPORT_OK;

# Class::Struct forbids use of @ISA
sub import { goto &Exporter::import }

use Class::Struct qw(struct);
struct 'Net::servent' => [
   name		=> '$',
   aliases	=> '@',
   port		=> '$',
   proto	=> '$',
];

sub populate (@) {
    return unless @_;
    my $sob = new();
    $s_name 	 =    $sob->[0]     	     = $_[0];
    @s_aliases	 = @{ $sob->[1] } = split ' ', $_[1];
    $s_port	 =    $sob->[2] 	     = $_[2];
    $s_proto	 =    $sob->[3] 	     = $_[3];
    return $sob;
}

sub getservent    (   ) { populate(CORE::getservent()) }
sub getservbyname ($;$) { populate(CORE::getservbyname(shift,shift||'tcp')) }
sub getservbyport ($;$) { populate(CORE::getservbyport(shift,shift||'tcp')) }

sub getserv ($;$) {
    no strict 'refs';
    return &{'getservby' . ($_[0]=~/^\d+$/ ? 'port' : 'name')}(@_);
}

1;

__END__

