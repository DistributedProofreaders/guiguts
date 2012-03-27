#############################################################################
# Pod/Usage.pm -- print usage messages for the running script.
#
# Copyright (C) 1996-2000 by Bradford Appleton. All rights reserved.
# This file is part of "PodParser". PodParser is free software;
# you can redistribute it and/or modify it under the same terms
# as Perl itself.
#############################################################################

package Pod::Usage;

use vars qw($VERSION);
$VERSION = 1.16;  ## Current version of this package
require  5.005;    ## requires this Perl version or later

#############################################################################

use strict;
#use diagnostics;
use Carp;
use Config;
use Exporter;
use File::Spec;

use vars qw(@ISA @EXPORT);
@EXPORT = qw(&pod2usage);
BEGIN {
    if ( $] >= 5.005_58 ) {
       require Pod::Text;
       @ISA = qw( Pod::Text );
    }
    else {
       require Pod::PlainText;
       @ISA = qw( Pod::PlainText );
    }
}


##---------------------------------------------------------------------------

##---------------------------------
## Function definitions begin here
##---------------------------------

sub pod2usage {
    local($_) = shift || "";
    my %opts;
    ## Collect arguments
    if (@_ > 0) {
        ## Too many arguments - assume that this is a hash and
        ## the user forgot to pass a reference to it.
        %opts = ($_, @_);
    }
    elsif (ref $_) {
        ## User passed a ref to a hash
        %opts = %{$_}  if (ref($_) eq 'HASH');
    }
    elsif (/^[-+]?\d+$/) {
        ## User passed in the exit value to use
        $opts{"-exitval"} =  $_;
    }
    else {
        ## User passed in a message to print before issuing usage.
        $_  and  $opts{"-message"} = $_;
    }

    ## Need this for backward compatibility since we formerly used
    ## options that were all uppercase words rather than ones that
    ## looked like Unix command-line options.
    ## to be uppercase keywords)
    %opts = map {
        my $val = $opts{$_};
        s/^(?=\w)/-/;
        /^-msg/i   and  $_ = '-message';
        /^-exit/i  and  $_ = '-exitval';
        lc($_) => $val;    
    } (keys %opts);

    ## Now determine default -exitval and -verbose values to use
    if ((! defined $opts{"-exitval"}) && (! defined $opts{"-verbose"})) {
        $opts{"-exitval"} = 2;
        $opts{"-verbose"} = 0;
    }
    elsif (! defined $opts{"-exitval"}) {
        $opts{"-exitval"} = ($opts{"-verbose"} > 0) ? 1 : 2;
    }
    elsif (! defined $opts{"-verbose"}) {
        $opts{"-verbose"} = ($opts{"-exitval"} < 2);
    }

    ## Default the output file
    $opts{"-output"} = (lc($opts{"-exitval"}) eq "noexit" ||
                        $opts{"-exitval"} < 2) ? \*STDOUT : \*STDERR
            unless (defined $opts{"-output"});
    ## Default the input file
    $opts{"-input"} = $0  unless (defined $opts{"-input"});

    ## Look up input file in path if it doesnt exist.
    unless ((ref $opts{"-input"}) || (-e $opts{"-input"})) {
        my ($dirname, $basename) = ('', $opts{"-input"});
        my $pathsep = ($^O =~ /^(?:dos|os2|MSWin32)$/) ? ";"
                            : (($^O eq 'MacOS' || $^O eq 'VMS') ? ',' :  ":");
        my $pathspec = $opts{"-pathlist"} || $ENV{PATH} || $ENV{PERL5LIB};

        my @paths = (ref $pathspec) ? @$pathspec : split($pathsep, $pathspec);
        for $dirname (@paths) {
            $_ = File::Spec->catfile($dirname, $basename)  if length;
            last if (-e $_) && ($opts{"-input"} = $_);
        }
    }

    ## Now create a pod reader and constrain it to the desired sections.
    my $parser = new Pod::Usage(USAGE_OPTIONS => \%opts);
    if ($opts{"-verbose"} == 0) {
        $parser->select("SYNOPSIS");
    }
    elsif ($opts{"-verbose"} == 1) {
        my $opt_re = '(?i)' .
                     '(?:OPTIONS|ARGUMENTS)' .
                     '(?:\s*(?:AND|\/)\s*(?:OPTIONS|ARGUMENTS))?';
        $parser->select( 'SYNOPSIS', $opt_re, "DESCRIPTION/$opt_re" );
    }

    ## Now translate the pod document and then exit with the desired status
    if ( $opts{"-verbose"} >= 2 
             and  !ref($opts{"-input"})
             and  $opts{"-output"} == \*STDOUT )
    {
       ## spit out the entire PODs. Might as well invoke perldoc
       my $progpath = File::Spec->catfile($Config{scriptdir}, "perldoc");
       system($progpath, $opts{"-input"});
    }
    else {
       $parser->parse_from_file($opts{"-input"}, $opts{"-output"});
    }

    exit($opts{"-exitval"})  unless (lc($opts{"-exitval"}) eq 'noexit');
}

##---------------------------------------------------------------------------

##-------------------------------
## Method definitions begin here
##-------------------------------

sub new {
    my $this = shift;
    my $class = ref($this) || $this;
    my %params = @_;
    my $self = {%params};
    bless $self, $class;
    $self->initialize();
    return $self;
}

sub begin_pod {
    my $self = shift;
    $self->SUPER::begin_pod();  ## Have to call superclass
    my $msg = $self->{USAGE_OPTIONS}->{-message}  or  return 1;
    my $out_fh = $self->output_handle();
    print $out_fh "$msg\n";
}

sub preprocess_paragraph {
    my $self = shift;
    local $_ = shift;
    my $line = shift;
    ## See if this is a heading and we arent printing the entire manpage.
    if (($self->{USAGE_OPTIONS}->{-verbose} < 2) && /^=head/) {
        ## Change the title of the SYNOPSIS section to USAGE
        s/^=head1\s+SYNOPSIS\s*$/=head1 USAGE/;
        ## Try to do some lowercasing instead of all-caps in headings
        s{([A-Z])([A-Z]+)}{((length($2) > 2) ? $1 : lc($1)) . lc($2)}ge;
        ## Use a colon to end all headings
        s/\s*$/:/  unless (/:\s*$/);
        $_ .= "\n";
    }
    return  $self->SUPER::preprocess_paragraph($_);
}

1; # keep require happy
