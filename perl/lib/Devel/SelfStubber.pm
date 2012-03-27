package Devel::SelfStubber;
use File::Spec;
require SelfLoader;
@ISA = qw(SelfLoader);
@EXPORT = 'AUTOLOAD';
$JUST_STUBS = 1;
$VERSION = 1.03;
sub Version {$VERSION}

# Use as
# perl -e 'use Devel::SelfStubber;Devel::SelfStubber->stub(MODULE_NAME,LIB)'
# (LIB defaults to '.') e.g.
# perl -e 'use Devel::SelfStubber;Devel::SelfStubber->stub('Math::BigInt')'
# would print out stubs needed if you added a __DATA__ before the subs.
# Setting $Devel::SelfStubber::JUST_STUBS to 0 will print out the whole
# module with the stubs entered just before the __DATA__

sub _add_to_cache {
    my($self,$fullname,$pack,$lines, $prototype) = @_;
    push(@DATA,@{$lines});
    if($fullname){push(@STUBS,"sub $fullname $prototype;\n")}; # stubs
    '1;';
}

sub _package_defined {
    my($self,$line) = @_;
    push(@DATA,$line);
}

sub stub {
    my($self,$module,$lib) = @_;
    my($line,$end_data,$fh,$mod_file,$found_selfloader);
    $lib ||= File::Spec->curdir();
    ($mod_file = $module) =~ s,::,/,g;
    $mod_file =~ tr|/|:| if $^O eq 'MacOS';
    
    $mod_file = File::Spec->catfile($lib, "$mod_file.pm");
    $fh = "${module}::DATA";
    my (@BEFORE_DATA, @AFTER_DATA, @AFTER_END);
    @DATA = @STUBS = ();

    open($fh,$mod_file) || die "Unable to open $mod_file";
    local $/ = "\n";
    while(defined ($line = <$fh>) and $line !~ m/^__DATA__/) {
	push(@BEFORE_DATA,$line);
	$line =~ /use\s+SelfLoader/ && $found_selfloader++;
    }
    (defined ($line) && $line =~ m/^__DATA__/)
      || die "$mod_file doesn't contain a __DATA__ token";
    $found_selfloader || 
	print 'die "\'use SelfLoader;\' statement NOT FOUND!!\n"',"\n";
    if ($JUST_STUBS) {
        $self->_load_stubs($module);
    } else {
        $self->_load_stubs($module, \@AFTER_END);
    }
    if ( fileno($fh) ) {
	$end_data = 1;
	while(defined($line = <$fh>)) {
	    push(@AFTER_DATA,$line);
	}
    }
    close($fh);
    unless ($JUST_STUBS) {
    	print @BEFORE_DATA;
    }
    print @STUBS;
    unless ($JUST_STUBS) {
    	print "1;\n__DATA__\n",@DATA;
    	if($end_data) { print "__END__ DATA\n",@AFTER_DATA; }
    	if(@AFTER_END) { print "__END__\n",@AFTER_END; }
    }
}

1;
__END__

