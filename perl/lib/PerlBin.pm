package PerlBin;

#use Carp; #bah, forget it
use Config;
use File::Spec;
use File::Path qw[ mkpath ];
use File::Copy qw[ copy ];
use File::Basename qw[ dirname ];
use Module::ScanDeps(); # i love you ;) but the OO SUCKS!!

# it's best this way (chdir be damned)
BEGIN {
    $PerlBin::VERSION = 0.02;
    $PerlBin::DAT = File::Spec->rel2abs(__FILE__);
    $PerlBin::DAT = File::Spec->catfile( dirname($PerlBin::DAT), qw[ PerlBin PerlBin.dat ] );
}

#$PerlBin::skipTo = 0; # defined here also, don't mean squat


sub new {
    my( $class, $script, $exe ) = @_;
    my $self = bless {}, $class;
    $self->{deps} = {};

    $self->scan_deps($script) if defined $script; # chain chain chain
    $self->PutBinary($script,$exe)->PutDeps(dirname $exe)->PutSO(dirname $exe) if defined $exe;

    return $self;
}

sub clear_deps { $_[0]->{deps} = {}; return $_[0]; } # LAME!!

sub add_deps {
    my($self, @deps ) = @_;

    Module::ScanDeps::add_deps(
        rv => $self->{deps},
        modules => [
            map {
                s[::][/]g;
                $_ .= '.pm' unless /\.pm$/i;
                $_;
            } @deps
        ],
    );

    return $self;
}

sub scan_deps {
    my $self =  shift;

    Module::ScanDeps::scan_deps(
        rv => $self->{deps},
        files => \@_,
        recurse	=> 1, # ALWAYS
    );

    return $self;
}

sub PutBinary {
    my( $self, $appendfile, $outfile ) = @_;

       open PERLBIN, $PerlBin::DAT or die "couldn't open $PerlBin::DAT ($!)";
    binmode PERLBIN;
       read PERLBIN, $perlbin, -s PERLBIN; # slurp is a MUST
      close PERLBIN; 
       open OUTFH, ">".$outfile or die "Holy schnikes, can't write to $outfile ($!)";
    binmode OUTFH;
      print OUTFH $perlbin;
       open APPFH, "<".$appendfile or die "Holy schnikes, couldn't read $appendfile ($!)";
    binmode APPFH;
      print OUTFH $_ while <APPFH>; # wow, an idiom *rimshot*
      close OUTFH;
      close APPFH;

    return $self;
}


BEGIN {
# this is ought to be portable (if it don't work, tell me).
# on Debian libperl is it, so the regex won't substitute anything,
# and all is right with the world
# 'so' is 'dlext' and  'lib_ext' is '_a'
    $PerlBin::PerlSO = $Config{libperl};
    $PerlBin::PerlSO =~ s/\Q$Config{lib_ext}\E$/\.$Config{so}/;     # Perl56.dll
}

sub PutSO {
    my($self, $outdir) = @_;

    copy(
        File::Spec->catfile( $Config{installbin}, $PerlBin::PerlSO ),
        File::Spec->catfile( $outdir, $PerlBin::PerlSO )
    ) or warn "couldn't copy $PerlBin::PerlSO to $outdir ($!)";

    return $self;
}

sub PutDeps {
    my($self, $outdir) = @_;

    my $D = $self->{deps};

    $outdir = File::Spec->catfile($outdir,'lib') ;

    mkpath $outdir or warn "couldn't create $outdir ($!)";

    for my $k(keys %$D){
        my $outfile = File::Spec->catfile( $outdir, $k );
        my $dirToMake = dirname $outfile;

        mkpath $dirToMake unless -e $dirToMake;

        copy( $D->{$k}->{file} => $outfile )
            or warn "Couldn't copy '$D->{$k}->{file}' to '$outfile' ($!)";

    }

    return $self;
}

1;
