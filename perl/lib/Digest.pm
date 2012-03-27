package Digest;

use strict;
use vars qw($VERSION %MMAP $AUTOLOAD);

$VERSION = "1.05";

%MMAP = (
  "SHA-1"      => ["Digest::SHA1", ["Digest::SHA", 1], ["Digest::SHA2", 1]],
  "SHA-256"    => [["Digest::SHA", 256], ["Digest::SHA2", 256]],
  "SHA-384"    => [["Digest::SHA", 384], ["Digest::SHA2", 384]],
  "SHA-512"    => [["Digest::SHA", 512], ["Digest::SHA2", 512]],
  "HMAC-MD5"   => "Digest::HMAC_MD5",
  "HMAC-SHA-1" => "Digest::HMAC_SHA1",
);

sub new
{
    shift;  # class ignored
    my $algorithm = shift;
    my $impl = $MMAP{$algorithm} || do {
	$algorithm =~ s/\W+//;
	"Digest::$algorithm";
    };
    $impl = [$impl] unless ref($impl);
    my $err;
    for  (@$impl) {
	my $class = $_;
	my @args;
	($class, @args) = @$class if ref($class);
	no strict 'refs';
	unless (exists ${"$class\::"}{"VERSION"}) {
	    eval "require $class";
	    if ($@) {
		$err ||= $@;
		next;
	    }
	}
	return $class->new(@args, @_);
    }
    die $err;
}

sub AUTOLOAD
{
    my $class = shift;
    my $algorithm = substr($AUTOLOAD, rindex($AUTOLOAD, '::')+2);
    $class->new($algorithm, @_);
}

1;

__END__

