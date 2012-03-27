# -*- Mode: cperl; cperl-indent-level: 4 -*-
# $Id: Straps.pm,v 1.35 2003/12/31 02:34:22 andy Exp $

package Test::Harness::Straps;

use strict;
use vars qw($VERSION);
use Config;
$VERSION = '0.19';

use Test::Harness::Assert;
use Test::Harness::Iterator;

# Flags used as return values from our methods.  Just for internal 
# clarification.
my $TRUE  = (1==1);
my $FALSE = !$TRUE;
my $YES   = $TRUE;
my $NO    = $FALSE;


sub new {
    my($proto) = shift;
    my($class) = ref $proto || $proto;

    my $self = bless {}, $class;
    $self->_init;

    return $self;
}

sub _init {
    my($self) = shift;

    $self->{_is_vms}   = ( $^O eq 'VMS' );
    $self->{_is_win32} = ( $^O =~ /^(MS)?Win32$/ );
    $self->{_is_macos} = ( $^O eq 'MacOS' );
}

sub analyze {
    my($self, $name, $test_output) = @_;

    my $it = Test::Harness::Iterator->new($test_output);
    return $self->_analyze_iterator($name, $it);
}


sub _analyze_iterator {
    my($self, $name, $it) = @_;

    $self->_reset_file_state;
    $self->{file} = $name;
    my %totals  = (
                   max      => 0,
                   seen     => 0,

                   ok       => 0,
                   todo     => 0,
                   skip     => 0,
                   bonus    => 0,

                   details  => []
                  );

    # Set them up here so callbacks can have them.
    $self->{totals}{$name}         = \%totals;
    while( defined(my $line = $it->next) ) {
        $self->_analyze_line($line, \%totals);
        last if $self->{saw_bailout};
    }

    $totals{skip_all} = $self->{skip_all} if defined $self->{skip_all};

    my $passed = ($totals{max} == 0 && defined $totals{skip_all}) ||
                 ($totals{max} && $totals{seen} &&
                  $totals{max} == $totals{seen} && 
                  $totals{max} == $totals{ok});
    $totals{passing} = $passed ? 1 : 0;

    return %totals;
}


sub _analyze_line {
    my($self, $line, $totals) = @_;

    my %result = ();

    $self->{line}++;

    my $type;
    if( $self->_is_header($line) ) {
        $type = 'header';

        $self->{saw_header}++;

        $totals->{max} += $self->{max};
    }
    elsif( $self->_is_test($line, \%result) ) {
        $type = 'test';

        $totals->{seen}++;
        $result{number} = $self->{'next'} unless $result{number};

        # sometimes the 'not ' and the 'ok' are on different lines,
        # happens often on VMS if you do:
        #   print "not " unless $test;
        #   print "ok $num\n";
        if( $self->{saw_lone_not} && 
            ($self->{lone_not_line} == $self->{line} - 1) ) 
        {
            $result{ok} = 0;
        }

        my $pass = $result{ok};
        $result{type} = 'todo' if $self->{todo}{$result{number}};

        if( $result{type} eq 'todo' ) {
            $totals->{todo}++;
            $pass = 1;
            $totals->{bonus}++ if $result{ok}
        }
        elsif( $result{type} eq 'skip' ) {
            $totals->{skip}++;
            $pass = 1;
        }

        $totals->{ok}++ if $pass;

        if( $result{number} > 100000 && $result{number} > $self->{max} ) {
            warn "Enormous test number seen [test $result{number}]\n";
            warn "Can't detailize, too big.\n";
        }
        else {
            $totals->{details}[$result{number} - 1] = 
                               {$self->_detailize($pass, \%result)};
        }

        # XXX handle counter mismatch
    }
    elsif ( $self->_is_bail_out($line, \$self->{bailout_reason}) ) {
        $type = 'bailout';
        $self->{saw_bailout} = 1;
    }
    else {
        $type = 'other';
    }

    $self->{callback}->($self, $line, $type, $totals) if $self->{callback};

    $self->{'next'} = $result{number} + 1 if $type eq 'test';
}

sub analyze_fh {
    my($self, $name, $fh) = @_;

    my $it = Test::Harness::Iterator->new($fh);
    $self->_analyze_iterator($name, $it);
}

sub analyze_file {
    my($self, $file) = @_;

    unless( -e $file ) {
        $self->{error} = "$file does not exist";
        return;
    }

    unless( -r $file ) {
        $self->{error} = "$file is not readable";
        return;
    }

    local $ENV{PERL5LIB} = $self->_INC2PERL5LIB;

    # *sigh* this breaks under taint, but open -| is unportable.
    my $line = $self->_command_line($file);
    unless( open(FILE, "$line|") ) {
        print "can't run $file. $!\n";
        return;
    }

    my %results = $self->analyze_fh($file, \*FILE);
    my $exit = close FILE;
    $results{'wait'} = $?;
    if( $? && $self->{_is_vms} ) {
        eval q{use vmsish "status"; $results{'exit'} = $?};
    }
    else {
        $results{'exit'} = _wait2exit($?);
    }
    $results{passing} = 0 unless $? == 0;

    $self->_restore_PERL5LIB();

    return %results;
}


eval { require POSIX; &POSIX::WEXITSTATUS(0) };
if( $@ ) {
    *_wait2exit = sub { $_[0] >> 8 };
}
else {
    *_wait2exit = sub { POSIX::WEXITSTATUS($_[0]) }
}

sub _command_line {
    my $self = shift;
    my $file = shift;

    my $command =  $self->_command();
    my $switches = $self->_switches($file);

    $file = qq["$file"] if ($file =~ /\s/) && ($file !~ /^".*"$/);
    my $line = "$command $switches $file";

    return $line;
}


sub _command {
    my $self = shift;

    return $ENV{HARNESS_PERL}           if defined $ENV{HARNESS_PERL};
    return "MCR $^X"                    if $self->{_is_vms};
    return Win32::GetShortPathName($^X) if $self->{_is_win32};
    return $^X;
}


sub _switches {
    my($self, $file) = @_;

    my @existing_switches = $self->_cleaned_switches( $Test::Harness::Switches, $ENV{HARNESS_PERL_SWITCHES} );
    my @derived_switches;

    local *TEST;
    open(TEST, $file) or print "can't open $file. $!\n";
    my $shebang = <TEST>;
    close(TEST) or print "can't close $file. $!\n";

    my $taint = ( $shebang =~ /^#!.*\bperl.*\s-\w*([Tt]+)/ );
    push( @derived_switches, "-$1" ) if $taint;

    # When taint mode is on, PERL5LIB is ignored.  So we need to put
    # all that on the command line as -Is.
    # MacPerl's putenv is broken, so it will not see PERL5LIB, tainted or not.
    if ( $taint || $self->{_is_macos} ) {
	my @inc = $self->_filtered_INC;
	push @derived_switches, map { "-I$_" } @inc;
    }

    # Quote the argument if there's any whitespace in it, or if
    # we're VMS, since VMS requires all parms quoted.  Also, don't quote
    # it if it's already quoted.
    for ( @derived_switches ) {
	$_ = qq["$_"] if ((/\s/ || $self->{_is_vms}) && !/^".*"$/ );
    }
    return join( " ", @existing_switches, @derived_switches );
}

sub _cleaned_switches {
    my $self = shift;

    local $_;

    my @switches;
    for ( @_ ) {
	my $switch = $_;
	next unless defined $switch;
	$switch =~ s/^\s+//;
	$switch =~ s/\s+$//;
	push( @switches, $switch ) if $switch ne "";
    }

    return @switches;
}

sub _INC2PERL5LIB {
    my($self) = shift;

    $self->{_old5lib} = $ENV{PERL5LIB};

    return join $Config{path_sep}, $self->_filtered_INC;
}

sub _filtered_INC {
    my($self, @inc) = @_;
    @inc = @INC unless @inc;

    if( $self->{_is_vms} ) {
	# VMS has a 255-byte limit on the length of %ENV entries, so
	# toss the ones that involve perl_root, the install location
        @inc = grep !/perl_root/i, @inc;

    } elsif ( $self->{_is_win32} ) {
	# Lose any trailing backslashes in the Win32 paths
	s/[\\\/+]$// foreach @inc;
    }

    my %dupes;
    @inc = grep !$dupes{$_}++, @inc;

    return @inc;
}


sub _restore_PERL5LIB {
    my($self) = shift;

    return unless $self->{_is_vms};

    if (defined $self->{_old5lib}) {
        $ENV{PERL5LIB} = $self->{_old5lib};
    }
}

sub _is_comment {
    my($self, $line, $comment) = @_;

    if( $line =~ /^\s*\#(.*)/ ) {
        $$comment = $1;
        return $YES;
    }
    else {
        return $NO;
    }
}

# Regex for parsing a header.  Will be run with /x
my $Extra_Header_Re = <<'REGEX';
                       ^
                        (?: \s+ todo \s+ ([\d \t]+) )?      # optional todo set
                        (?: \s* \# \s* ([\w:]+\s?) (.*) )?     # optional skip with optional reason
REGEX

sub _is_header {
    my($self, $line) = @_;

    if( my($max, $extra) = $line =~ /^1\.\.(\d+)(.*)/ ) {
        $self->{max}  = $max;
        assert( $self->{max} >= 0,  'Max # of tests looks right' );

        if( defined $extra ) {
            my($todo, $skip, $reason) = $extra =~ /$Extra_Header_Re/xo;

            $self->{todo} = { map { $_ => 1 } split /\s+/, $todo } if $todo;

            if( $self->{max} == 0 ) {
                $reason = '' unless defined $skip and $skip =~ /^Skip/i;
            }

            $self->{skip_all} = $reason;
        }

        return $YES;
    }
    else {
        return $NO;
    }
}

my $Report_Re = <<'REGEX';
                 ^
                  (not\ )?               # failure?
                  ok\b
                  (?:\s+(\d+))?         # optional test number
                  \s*
                  (.*)                  # and the rest
REGEX

my $Extra_Re = <<'REGEX';
                 ^
                  (.*?) (?:(?:[^\\]|^)# (.*))?
                 $
REGEX

sub _is_test {
    my($self, $line, $test) = @_;

    # We pulverize the line down into pieces in three parts.
    if( my($not, $num, $extra)    = $line  =~ /$Report_Re/ox ) {
        my ($name, $control) = $extra ? split(/(?:[^\\]|^)#/, $extra) : ();
        my ($type, $reason)  = $control ? $control =~ /^\s*(\S+)(?:\s+(.*))?$/ : ();

        $test->{number} = $num;
        $test->{ok}     = $not ? 0 : 1;
        $test->{name}   = $name;

        if( defined $type ) {
            $test->{type}   = $type =~ /^TODO$/i ? 'todo' :
                              $type =~ /^Skip/i  ? 'skip' : 0;
        }
        else {
            $test->{type} = '';
        }
        $test->{reason} = $reason;

        return $YES;
    }
    else{
        # Sometimes the "not " and "ok" will be on separate lines on VMS.
        # We catch this and remember we saw it.
        if( $line =~ /^not\s+$/ ) {
            $self->{saw_lone_not} = 1;
            $self->{lone_not_line} = $self->{line};
        }

        return $NO;
    }
}

sub _is_bail_out {
    my($self, $line, $reason) = @_;

    if( $line =~ /^Bail out!\s*(.*)/i ) {
        $$reason = $1 if $1;
        return $YES;
    }
    else {
        return $NO;
    }
}

sub _reset_file_state {
    my($self) = shift;

    delete @{$self}{qw(max skip_all todo)};
    $self->{line}       = 0;
    $self->{saw_header} = 0;
    $self->{saw_bailout}= 0;
    $self->{saw_lone_not} = 0;
    $self->{lone_not_line} = 0;
    $self->{bailout_reason} = '';
    $self->{'next'}       = 1;
}

sub _detailize {
    my($self, $pass, $test) = @_;

    my %details = ( ok         => $pass,
                    actual_ok  => $test->{ok}
                  );

    assert( !(grep !defined $details{$_}, keys %details),
            'test contains the ok and actual_ok info' );

    # We don't want these to be undef because they are often
    # checked and don't want the checker to have to deal with
    # uninitialized vars.
    foreach my $piece (qw(name type reason)) {
        $details{$piece} = defined $test->{$piece} ? $test->{$piece} : '';
    }

    return %details;
}

1;
