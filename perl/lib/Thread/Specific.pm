package Thread::Specific;

our $VERSION = '1.00';

sub import : locked : method {
    require fields;
    fields::->import(@_);
}	

sub key_create : locked : method {
    our %FIELDS;   # suppress "used only once"
    return ++$FIELDS{__MAX__};
}

1;
