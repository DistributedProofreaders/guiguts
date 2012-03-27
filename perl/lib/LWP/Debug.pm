package LWP::Debug;

# $Id: Debug.pm,v 1.14 2003/10/23 19:11:32 uid39246 Exp $

require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw(level trace debug conns);

use Carp ();

my @levels = qw(trace debug conns);
%current_level = ();


sub import
{
    my $pack = shift;
    my $callpkg = caller(0);
    my @symbols = ();
    my @levels = ();
    for (@_) {
	if (/^[-+]/) {
	    push(@levels, $_);
	}
	else {
	    push(@symbols, $_);
	}
    }
    Exporter::export($pack, $callpkg, @symbols);
    level(@levels);
}


sub level
{
    for (@_) {
	if ($_ eq '+') {              # all on
	    # switch on all levels
	    %current_level = map { $_ => 1 } @levels;
	}
	elsif ($_ eq '-') {           # all off
	    %current_level = ();
	}
	elsif (/^([-+])(\w+)$/) {
	    $current_level{$2} = $1 eq '+';
	}
	else {
	    Carp::croak("Illegal level format $_");
	}
    }
}


sub trace  { _log(@_) if $current_level{'trace'}; }
sub debug  { _log(@_) if $current_level{'debug'}; }
sub conns  { _log(@_) if $current_level{'conns'}; }


sub _log
{
    my $msg = shift;
    $msg .= "\n" unless $msg =~ /\n$/;  # ensure trailing "\n"

    my($package,$filename,$line,$sub) = caller(2);
    print STDERR "$sub: $msg";
}

1;


__END__

