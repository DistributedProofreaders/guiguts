package ExtUtils::Command::MM;

use strict;

require 5.005_03;
require Exporter;
use vars qw($VERSION @ISA @EXPORT);
@ISA = qw(Exporter);

@EXPORT  = qw(test_harness pod2man perllocal_install uninstall 
              warn_if_old_packlist);
$VERSION = '0.03';

my $Is_VMS = $^O eq 'VMS';

sub test_harness {
    require Test::Harness;
    require File::Spec;

    $Test::Harness::verbose = shift;

    local @INC = @INC;
    unshift @INC, map { File::Spec->rel2abs($_) } @_;
    Test::Harness::runtests(sort { lc $a cmp lc $b } @ARGV);
}



sub pod2man {
    require Pod::Man;
    require Getopt::Long;

    my %options = ();

    # We will cheat and just use Getopt::Long.  We fool it by putting
    # our arguments into @ARGV.  Should be safe.
    local @ARGV = @_ ? @_ : @ARGV;
    Getopt::Long::config ('bundling_override');
    Getopt::Long::GetOptions (\%options, 
                'section|s=s', 'release|r=s', 'center|c=s',
                'date|d=s', 'fixed=s', 'fixedbold=s', 'fixeditalic=s',
                'fixedbolditalic=s', 'official|o', 'quotes|q=s', 'lax|l',
                'name|n=s', 'perm_rw:i'
    );

    # If there's no files, don't bother going further.
    return 0 unless @ARGV;

    # Official sets --center, but don't override things explicitly set.
    if ($options{official} && !defined $options{center}) {
        $options{center} = 'Perl Programmers Reference Guide';
    }

    # This isn't a valid Pod::Man option and is only accepted for backwards
    # compatibility.
    delete $options{lax};

    my $parser = Pod::Man->new(%options);

    do {{  # so 'next' works
        my ($pod, $man) = splice(@ARGV, 0, 2);

        next if ((-e $man) &&
                 (-M $man < -M $pod) &&
                 (-M $man < -M "Makefile"));

        print "Manifying $man\n";

        $parser->parse_from_file($pod, $man)
          or do { warn("Could not install $man\n");  next };

        if (length $options{perm_rw}) {
            chmod(oct($options{perm_rw}), $man)
              or do { warn("chmod $options{perm_rw} $man: $!\n"); next };
        }
    }} while @ARGV;

    return 1;
}


sub warn_if_old_packlist {
    my $packlist = $ARGV[0];

    return unless -f $packlist;
    print <<"PACKLIST_WARNING";
WARNING: I have found an old package in
    $packlist.
Please make sure the two installations are not conflicting
PACKLIST_WARNING

}


sub perllocal_install {
    my($type, $name) = splice(@ARGV, 0, 2);

    # VMS feeds args as a piped file on STDIN since it usually can't
    # fit all the args on a single command line.
    @ARGV = split /\|/, <STDIN> if $Is_VMS;

    my $pod;
    $pod = sprintf <<POD, scalar localtime;
 =head2 %s: C<$type> L<$name|$name>
 
 =over 4
 
POD

    do {
        my($key, $val) = splice(@ARGV, 0, 2);

        $pod .= <<POD
 =item *
 
 C<$key: $val>
 
POD

    } while(@ARGV);

    $pod .= "=back\n\n";
    $pod =~ s/^ //mg;
    print $pod;

    return 1;
}

sub uninstall {
    my($packlist) = shift;

    require ExtUtils::Install;

    print <<'WARNING';

Uninstall is unsafe and deprecated, the uninstallation was not performed.
We will show what would have been done.

WARNING

    ExtUtils::Install::uninstall($packlist, 1, 1);

    print <<'WARNING';

Uninstall is unsafe and deprecated, the uninstallation was not performed.
Please check the list above carefully, there may be errors.
Remove the appropriate files manually.
Sorry for the inconvenience.

WARNING

}

1;
