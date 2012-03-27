package bytes;

our $VERSION = '1.01';

$bytes::hint_bits = 0x00000008;

sub import {
    $^H |= $bytes::hint_bits;
}

sub unimport {
    $^H &= ~$bytes::hint_bits;
}

sub AUTOLOAD {
    require "bytes_heavy.pl";
    goto &$AUTOLOAD;
}

sub length ($);
sub chr ($);
sub ord ($);
sub substr ($$;$$);
sub index ($$;$);
sub rindex ($$;$);

1;
__END__

