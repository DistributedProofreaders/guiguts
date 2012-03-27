# -*- Mode: cperl; cperl-indent-level: 4 -*-
# $Id: Harness.pm,v 1.80 2003/12/31 02:39:21 andy Exp $

package Test::Harness;

require 5.004;
use Test::Harness::Straps;
use Test::Harness::Assert;
use Exporter;
use Benchmark;
use Config;
use strict;

use vars qw(
    $VERSION 
    @ISA @EXPORT @EXPORT_OK 
    $Verbose $Switches $Debug
    $verbose $switches $debug
    $Have_Devel_Corestack
    $Curtest
    $Columns 
    $ML $Last_ML_Print
    $Strap
);

$VERSION = '2.40';

# Backwards compatibility for exportable variable names.
*verbose  = *Verbose;
*switches = *Switches;
*debug    = *Debug;

$Have_Devel_Corestack = 0;

$ENV{HARNESS_ACTIVE} = 1;

END {
    # For VMS.
    delete $ENV{HARNESS_ACTIVE};
}

# Some experimental versions of OS/2 build have broken $?
my $Ignore_Exitcode = $ENV{HARNESS_IGNORE_EXITCODE};

my $Files_In_Dir = $ENV{HARNESS_FILELEAK_IN_DIR};

my $Ok_Slow = $ENV{HARNESS_OK_SLOW};

$Strap = Test::Harness::Straps->new;

@ISA = ('Exporter');
@EXPORT    = qw(&runtests);
@EXPORT_OK = qw($verbose $switches);

$Verbose  = $ENV{HARNESS_VERBOSE} || 0;
$Debug    = $ENV{HARNESS_DEBUG} || 0;
$Switches = "-w";
$Columns  = $ENV{HARNESS_COLUMNS} || $ENV{COLUMNS} || 80;
$Columns--;             # Some shells have trouble with a full line of text.

sub runtests {
    my(@tests) = @_;

    local ($\, $,);

    my($tot, $failedtests) = _run_all_tests(@tests);
    _show_results($tot, $failedtests);

    my $ok = _all_ok($tot);

    assert(($ok xor keys %$failedtests), 
           q{ok status jives with $failedtests});

    return $ok;
}

sub _all_ok {
    my($tot) = shift;

    return $tot->{bad} == 0 && ($tot->{max} || $tot->{skipped}) ? 1 : 0;
}

sub _globdir { 
    opendir DIRH, shift; 
    my @f = readdir DIRH; 
    closedir DIRH; 

    return @f;
}

#'#
sub _run_all_tests {
    my(@tests) = @_;
    local($|) = 1;
    my(%failedtests);

    # Test-wide totals.
    my(%tot) = (
                bonus    => 0,
                max      => 0,
                ok       => 0,
                files    => 0,
                bad      => 0,
                good     => 0,
                tests    => scalar @tests,
                sub_skipped  => 0,
                todo     => 0,
                skipped  => 0,
                bench    => 0,
               );

    my @dir_files = _globdir $Files_In_Dir if defined $Files_In_Dir;
    my $t_start = new Benchmark;

    my $width = _leader_width(@tests);
    foreach my $tfile (@tests) {
	if ( $Test::Harness::Debug ) {
	    print "# Running: ", $Strap->_command_line($tfile), "\n";
	}

        $Last_ML_Print = 0;  # so each test prints at least once
        my($leader, $ml) = _mk_leader($tfile, $width);
        local $ML = $ml;

        print $leader;

        $tot{files}++;

        $Strap->{_seen_header} = 0;
        my %results = $Strap->analyze_file($tfile) or
          do { warn $Strap->{error}, "\n";  next };

        # state of the current test.
        my @failed = grep { !$results{details}[$_-1]{ok} }
                     1..@{$results{details}};
        my %test = (
                    ok          => $results{ok},
                    'next'      => $Strap->{'next'},
                    max         => $results{max},
                    failed      => \@failed,
                    bonus       => $results{bonus},
                    skipped     => $results{skip},
                    skip_reason => $results{skip_reason},
                    skip_all    => $Strap->{skip_all},
                    ml          => $ml,
                   );

        $tot{bonus}       += $results{bonus};
        $tot{max}         += $results{max};
        $tot{ok}          += $results{ok};
        $tot{todo}        += $results{todo};
        $tot{sub_skipped} += $results{skip};

        my($estatus, $wstatus) = @results{qw(exit wait)};

        if ($results{passing}) {
            if ($test{max} and $test{skipped} + $test{bonus}) {
                my @msg;
                push(@msg, "$test{skipped}/$test{max} skipped: $test{skip_reason}")
                    if $test{skipped};
                push(@msg, "$test{bonus}/$test{max} unexpectedly succeeded")
                    if $test{bonus};
                print "$test{ml}ok\n        ".join(', ', @msg)."\n";
            } elsif ($test{max}) {
                print "$test{ml}ok\n";
            } elsif (defined $test{skip_all} and length $test{skip_all}) {
                print "skipped\n        all skipped: $test{skip_all}\n";
                $tot{skipped}++;
            } else {
                print "skipped\n        all skipped: no reason given\n";
                $tot{skipped}++;
            }
            $tot{good}++;
        }
        else {
            # List unrun tests as failures.
            if ($test{'next'} <= $test{max}) {
                push @{$test{failed}}, $test{'next'}..$test{max};
            }
            # List overruns as failures.
            else {
                my $details = $results{details};
                foreach my $overrun ($test{max}+1..@$details)
                {
                    next unless ref $details->[$overrun-1];
                    push @{$test{failed}}, $overrun
                }
            }

            if ($wstatus) {
                $failedtests{$tfile} = _dubious_return(\%test, \%tot, 
                                                       $estatus, $wstatus);
                $failedtests{$tfile}{name} = $tfile;
            }
            elsif($results{seen}) {
                if (@{$test{failed}} and $test{max}) {
                    my ($txt, $canon) = _canonfailed($test{max},$test{skipped},
                                                    @{$test{failed}});
                    print "$test{ml}$txt";
                    $failedtests{$tfile} = { canon   => $canon,
                                             max     => $test{max},
                                             failed  => scalar @{$test{failed}},
                                             name    => $tfile, 
                                             percent => 100*(scalar @{$test{failed}})/$test{max},
                                             estat   => '',
                                             wstat   => '',
                                           };
                } else {
                    print "Don't know which tests failed: got $test{ok} ok, ".
                          "expected $test{max}\n";
                    $failedtests{$tfile} = { canon   => '??',
                                             max     => $test{max},
                                             failed  => '??',
                                             name    => $tfile, 
                                             percent => undef,
                                             estat   => '', 
                                             wstat   => '',
                                           };
                }
                $tot{bad}++;
            } else {
                print "FAILED before any test output arrived\n";
                $tot{bad}++;
                $failedtests{$tfile} = { canon       => '??',
                                         max         => '??',
                                         failed      => '??',
                                         name        => $tfile,
                                         percent     => undef,
                                         estat       => '', 
                                         wstat       => '',
                                       };
            }
        }

        if (defined $Files_In_Dir) {
            my @new_dir_files = _globdir $Files_In_Dir;
            if (@new_dir_files != @dir_files) {
                my %f;
                @f{@new_dir_files} = (1) x @new_dir_files;
                delete @f{@dir_files};
                my @f = sort keys %f;
                print "LEAKED FILES: @f\n";
                @dir_files = @new_dir_files;
            }
        }
    }
    $tot{bench} = timediff(new Benchmark, $t_start);

    $Strap->_restore_PERL5LIB;

    return(\%tot, \%failedtests);
}

sub _mk_leader {
    my($te, $width) = @_;
    chomp($te);
    $te =~ s/\.\w+$/./;

    if ($^O eq 'VMS') { $te =~ s/^.*\.t\./\[.t./s; }
    my $blank = (' ' x 77);
    my $leader = "$te" . '.' x ($width - length($te));
    my $ml = "";

    $ml = "\r$blank\r$leader"
      if -t STDOUT and not $ENV{HARNESS_NOTTY} and not $Verbose;

    return($leader, $ml);
}

sub _leader_width {
    my $maxlen = 0;
    my $maxsuflen = 0;
    foreach (@_) {
        my $suf    = /\.(\w+)$/ ? $1 : '';
        my $len    = length;
        my $suflen = length $suf;
        $maxlen    = $len    if $len    > $maxlen;
        $maxsuflen = $suflen if $suflen > $maxsuflen;
    }
    # + 3 : we want three dots between the test name and the "ok"
    return $maxlen + 3 - $maxsuflen;
}


sub _show_results {
    my($tot, $failedtests) = @_;

    my $pct;
    my $bonusmsg = _bonusmsg($tot);

    if (_all_ok($tot)) {
        print "All tests successful$bonusmsg.\n";
    } elsif (!$tot->{tests}){
        die "FAILED--no tests were run for some reason.\n";
    } elsif (!$tot->{max}) {
        my $blurb = $tot->{tests}==1 ? "script" : "scripts";
        die "FAILED--$tot->{tests} test $blurb could be run, ".
            "alas--no output ever seen\n";
    } else {
        $pct = sprintf("%.2f", $tot->{good} / $tot->{tests} * 100);
        my $percent_ok = 100*$tot->{ok}/$tot->{max};
        my $subpct = sprintf " %d/%d subtests failed, %.2f%% okay.",
                              $tot->{max} - $tot->{ok}, $tot->{max}, 
                              $percent_ok;

        my($fmt_top, $fmt) = _create_fmts($failedtests);

        # Now write to formats
        for my $script (sort keys %$failedtests) {
          $Curtest = $failedtests->{$script};
          write;
        }
        if ($tot->{bad}) {
            $bonusmsg =~ s/^,\s*//;
            print "$bonusmsg.\n" if $bonusmsg;
            die "Failed $tot->{bad}/$tot->{tests} test scripts, $pct% okay.".
                "$subpct\n";
        }
    }

    printf("Files=%d, Tests=%d, %s\n",
           $tot->{files}, $tot->{max}, timestr($tot->{bench}, 'nop'));
}


my %Handlers = ();
$Strap->{callback} = sub {
    my($self, $line, $type, $totals) = @_;
    print $line if $Verbose;

    my $meth = $Handlers{$type};
    $meth->($self, $line, $type, $totals) if $meth;
};


$Handlers{header} = sub {
    my($self, $line, $type, $totals) = @_;

    warn "Test header seen more than once!\n" if $self->{_seen_header};

    $self->{_seen_header}++;

    warn "1..M can only appear at the beginning or end of tests\n"
      if $totals->{seen} && 
         $totals->{max}  < $totals->{seen};
};

$Handlers{test} = sub {
    my($self, $line, $type, $totals) = @_;

    my $curr = $totals->{seen};
    my $next = $self->{'next'};
    my $max  = $totals->{max};
    my $detail = $totals->{details}[-1];

    if( $detail->{ok} ) {
        _print_ml_less("ok $curr/$max");

        if( $detail->{type} eq 'skip' ) {
            $totals->{skip_reason} = $detail->{reason}
              unless defined $totals->{skip_reason};
            $totals->{skip_reason} = 'various reasons'
              if $totals->{skip_reason} ne $detail->{reason};
        }
    }
    else {
        _print_ml("NOK $curr");
    }

    if( $curr > $next ) {
        print "Test output counter mismatch [test $curr]\n";
    }
    elsif( $curr < $next ) {
        print "Confused test output: test $curr answered after ".
              "test ", $next - 1, "\n";
    }

};

$Handlers{bailout} = sub {
    my($self, $line, $type, $totals) = @_;

    die "FAILED--Further testing stopped" .
      ($self->{bailout_reason} ? ": $self->{bailout_reason}\n" : ".\n");
};


sub _print_ml {
    print join '', $ML, @_ if $ML;
}


# For slow connections, we save lots of bandwidth by printing only once
# per second.
sub _print_ml_less {
    if( !$Ok_Slow || $Last_ML_Print != time ) {
        _print_ml(@_);
        $Last_ML_Print = time;
    }
}

sub _bonusmsg {
    my($tot) = @_;

    my $bonusmsg = '';
    $bonusmsg = (" ($tot->{bonus} subtest".($tot->{bonus} > 1 ? 's' : '').
               " UNEXPECTEDLY SUCCEEDED)")
        if $tot->{bonus};

    if ($tot->{skipped}) {
        $bonusmsg .= ", $tot->{skipped} test"
                     . ($tot->{skipped} != 1 ? 's' : '');
        if ($tot->{sub_skipped}) {
            $bonusmsg .= " and $tot->{sub_skipped} subtest"
                         . ($tot->{sub_skipped} != 1 ? 's' : '');
        }
        $bonusmsg .= ' skipped';
    }
    elsif ($tot->{sub_skipped}) {
        $bonusmsg .= ", $tot->{sub_skipped} subtest"
                     . ($tot->{sub_skipped} != 1 ? 's' : '')
                     . " skipped";
    }

    return $bonusmsg;
}

# Test program go boom.
sub _dubious_return {
    my($test, $tot, $estatus, $wstatus) = @_;
    my ($failed, $canon, $percent) = ('??', '??');

    printf "$test->{ml}dubious\n\tTest returned status $estatus ".
           "(wstat %d, 0x%x)\n",
           $wstatus,$wstatus;
    print "\t\t(VMS status is $estatus)\n" if $^O eq 'VMS';

    if (_corestatus($wstatus)) { # until we have a wait module
        if ($Have_Devel_Corestack) {
            Devel::CoreStack::stack($^X);
        } else {
            print "\ttest program seems to have generated a core\n";
        }
    }

    $tot->{bad}++;

    if ($test->{max}) {
        if ($test->{'next'} == $test->{max} + 1 and not @{$test->{failed}}) {
            print "\tafter all the subtests completed successfully\n";
            $percent = 0;
            $failed = 0;        # But we do not set $canon!
        }
        else {
            push @{$test->{failed}}, $test->{'next'}..$test->{max};
            $failed = @{$test->{failed}};
            (my $txt, $canon) = _canonfailed($test->{max},$test->{skipped},@{$test->{failed}});
            $percent = 100*(scalar @{$test->{failed}})/$test->{max};
            print "DIED. ",$txt;
        }
    }

    return { canon => $canon,  max => $test->{max} || '??',
             failed => $failed, 
             percent => $percent,
             estat => $estatus, wstat => $wstatus,
           };
}


sub _create_fmts {
    my($failedtests) = @_;

    my $failed_str = "Failed Test";
    my $middle_str = " Stat Wstat Total Fail  Failed  ";
    my $list_str = "List of Failed";

    # Figure out our longest name string for formatting purposes.
    my $max_namelen = length($failed_str);
    foreach my $script (keys %$failedtests) {
        my $namelen = length $failedtests->{$script}->{name};
        $max_namelen = $namelen if $namelen > $max_namelen;
    }

    my $list_len = $Columns - length($middle_str) - $max_namelen;
    if ($list_len < length($list_str)) {
        $list_len = length($list_str);
        $max_namelen = $Columns - length($middle_str) - $list_len;
        if ($max_namelen < length($failed_str)) {
            $max_namelen = length($failed_str);
            $Columns = $max_namelen + length($middle_str) + $list_len;
        }
    }

    my $fmt_top = "format STDOUT_TOP =\n"
                  . sprintf("%-${max_namelen}s", $failed_str)
                  . $middle_str
                  . $list_str . "\n"
                  . "-" x $Columns
                  . "\n.\n";

    my $fmt = "format STDOUT =\n"
              . "@" . "<" x ($max_namelen - 1)
              . "  @>> @>>>> @>>>> @>>> ^##.##%  "
              . "^" . "<" x ($list_len - 1) . "\n"
              . '{ $Curtest->{name}, $Curtest->{estat},'
              . '  $Curtest->{wstat}, $Curtest->{max},'
              . '  $Curtest->{failed}, $Curtest->{percent},'
              . '  $Curtest->{canon}'
              . "\n}\n"
              . "~~" . " " x ($Columns - $list_len - 2) . "^"
              . "<" x ($list_len - 1) . "\n"
              . '$Curtest->{canon}'
              . "\n.\n";

    eval $fmt_top;
    die $@ if $@;
    eval $fmt;
    die $@ if $@;

    return($fmt_top, $fmt);
}

{
    my $tried_devel_corestack;

    sub _corestatus {
        my($st) = @_;

        my $did_core;
        eval { # we may not have a WCOREDUMP
            local $^W = 0;  # *.ph files are often *very* noisy
            require 'wait.ph';
            $did_core = WCOREDUMP($st);
        };
        if( $@ ) {
            $did_core = $st & 0200;
        }

        eval { require Devel::CoreStack; $Have_Devel_Corestack++ } 
          unless $tried_devel_corestack++;

        return $did_core;
    }
}

sub _canonfailed ($$@) {
    my($max,$skipped,@failed) = @_;
    my %seen;
    @failed = sort {$a <=> $b} grep !$seen{$_}++, @failed;
    my $failed = @failed;
    my @result = ();
    my @canon = ();
    my $min;
    my $last = $min = shift @failed;
    my $canon;
    if (@failed) {
        for (@failed, $failed[-1]) { # don't forget the last one
            if ($_ > $last+1 || $_ == $last) {
                if ($min == $last) {
                    push @canon, $last;
                } else {
                    push @canon, "$min-$last";
                }
                $min = $_;
            }
            $last = $_;
        }
        local $" = ", ";
        push @result, "FAILED tests @canon\n";
        $canon = join ' ', @canon;
    } else {
        push @result, "FAILED test $last\n";
        $canon = $last;
    }

    push @result, "\tFailed $failed/$max tests, ";
    if ($max) {
	push @result, sprintf("%.2f",100*(1-$failed/$max)), "% okay";
    } else {
	push @result, "?% okay";
    }
    my $ender = 's' x ($skipped > 1);
    my $good = $max - $failed - $skipped;
    if ($skipped) {
	my $skipmsg = " (less $skipped skipped test$ender: $good okay, ";
	if ($max) {
	    my $goodper = sprintf("%.2f",100*($good/$max));
	    $skipmsg .= "$goodper%)";
	} else {
	    $skipmsg .= "?%)";
	}
	push @result, $skipmsg;
    }
    push @result, "\n";
    my $txt = join "", @result;
    ($txt, $canon);
}


1;
__END__


