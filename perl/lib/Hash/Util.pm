package Hash::Util;

require 5.007003;
use strict;
use Carp;

require Exporter;
our @ISA        = qw(Exporter);
our @EXPORT_OK  = qw(lock_keys unlock_keys lock_value unlock_value
                     lock_hash unlock_hash hash_seed
                    );
our $VERSION    = 0.05;

sub lock_keys (\%;@) {
    my($hash, @keys) = @_;

    Internals::hv_clear_placeholders %$hash;
    if( @keys ) {
        my %keys = map { ($_ => 1) } @keys;
        my %original_keys = map { ($_ => 1) } keys %$hash;
        foreach my $k (keys %original_keys) {
            die sprintf "Hash has key '$k' which is not in the new key ".
                        "set at %s line %d\n", (caller)[1,2]
              unless $keys{$k};
        }
    
        foreach my $k (@keys) {
            $hash->{$k} = undef unless exists $hash->{$k};
        }
        Internals::SvREADONLY %$hash, 1;

        foreach my $k (@keys) {
            delete $hash->{$k} unless $original_keys{$k};
        }
    }
    else {
        Internals::SvREADONLY %$hash, 1;
    }

    return;
}

sub unlock_keys (\%) {
    my($hash) = shift;

    Internals::SvREADONLY %$hash, 0;
    return;
}

sub lock_value (\%$) {
    my($hash, $key) = @_;
    carp "Cannot usefully lock values in an unlocked hash" 
      unless Internals::SvREADONLY %$hash;
    Internals::SvREADONLY $hash->{$key}, 1;
}

sub unlock_value (\%$) {
    my($hash, $key) = @_;
    Internals::SvREADONLY $hash->{$key}, 0;
}


sub lock_hash (\%) {
    my($hash) = shift;

    lock_keys(%$hash);

    foreach my $key (keys %$hash) {
        lock_value(%$hash, $key);
    }

    return 1;
}

sub unlock_hash (\%) {
    my($hash) = shift;

    foreach my $key (keys %$hash) {
        unlock_value(%$hash, $key);
    }

    unlock_keys(%$hash);

    return 1;
}


sub hash_seed () {
    Internals::rehash_seed();
}

1;
