package B::Terse;

our $VERSION = '1.02';

use strict;
use B qw(class);
use B::Asmdata qw(@specialsv_name);
use B::Concise qw(concise_subref set_style_standard);
use Carp;

sub terse {
    my ($order, $subref) = @_;
    set_style_standard("terse");
    if ($order eq "exec") {
	concise_subref('exec', $subref);
    } else {
	concise_subref('basic', $subref);
    }

}

sub compile {
    my @args = @_;
    my $order = @args ? shift(@args) : "";
    $order = "-exec" if $order eq "exec";
    unshift @args, $order if $order ne "";
    B::Concise::compile("-terse", @args);
}

sub indent {
    my $level = @_ ? shift : 0;
    return "    " x $level;
}

# Don't use this, at least on OPs in subroutines: it has no way of
# getting to the pad, and will give wrong answers or crash.
sub B::OP::terse {
    carp "B::OP::terse is deprecated; use B::Concise instead";
    B::Concise::b_terse(@_);
}

sub B::SV::terse {
    my($sv, $level) = (@_, 0);
    my %info;
    B::Concise::concise_sv($sv, \%info);
    my $s = B::Concise::fmt_line(\%info, "#svclass~(?((#svaddr))?)~#svval", 0);
    print indent($level), $s, "\n";
}

sub B::NULL::terse {
    my ($sv, $level) = @_;
    print indent($level);
    printf "%s (0x%lx)\n", class($sv), $$sv;
}

sub B::SPECIAL::terse {
    my ($sv, $level) = @_;
    print indent($level);
    printf "%s #%d %s\n", class($sv), $$sv, $specialsv_name[$$sv];
}

1;

__END__

