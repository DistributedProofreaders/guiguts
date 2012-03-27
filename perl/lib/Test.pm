
require 5.004;
package Test;
# Time-stamp: "2003-04-18 21:48:01 AHDT"

use strict;

use Carp;
use vars (qw($VERSION @ISA @EXPORT @EXPORT_OK $ntest $TestLevel), #public-ish
          qw($TESTOUT $TESTERR %Program_Lines
             $ONFAIL %todo %history $planned @FAILDETAIL) #private-ish
         );

# In case a test is run in a persistent environment.
sub _reset_globals {
    %todo       = ();
    %history    = ();
    @FAILDETAIL = ();
    $ntest      = 1;
    $TestLevel  = 0;		# how many extra stack frames to skip
    $planned    = 0;
}

$VERSION = '1.24';
require Exporter;
@ISA=('Exporter');

@EXPORT    = qw(&plan &ok &skip);
@EXPORT_OK = qw($ntest $TESTOUT $TESTERR);

$|=1;
$TESTOUT = *STDOUT{IO};
$TESTERR = *STDERR{IO};

# Use of this variable is strongly discouraged.  It is set mainly to
# help test coverage analyzers know which test is running.
$ENV{REGRESSION_TEST} = $0;


sub plan {
    croak "Test::plan(%args): odd number of arguments" if @_ & 1;
    croak "Test::plan(): should not be called more than once" if $planned;

    local($\, $,);   # guard against -l and other things that screw with
                     # print

    _reset_globals();

    _read_program( (caller)[1] );

    my $max=0;
    for (my $x=0; $x < @_; $x+=2) {
	my ($k,$v) = @_[$x,$x+1];
	if ($k =~ /^test(s)?$/) { $max = $v; }
	elsif ($k eq 'todo' or 
	       $k eq 'failok') { for (@$v) { $todo{$_}=1; }; }
	elsif ($k eq 'onfail') { 
	    ref $v eq 'CODE' or croak "Test::plan(onfail => $v): must be CODE";
	    $ONFAIL = $v; 
	}
	else { carp "Test::plan(): skipping unrecognized directive '$k'" }
    }
    my @todo = sort { $a <=> $b } keys %todo;
    if (@todo) {
	print $TESTOUT "1..$max todo ".join(' ', @todo).";\n";
    } else {
	print $TESTOUT "1..$max\n";
    }
    ++$planned;
    print $TESTOUT "# Running under perl version $] for $^O",
      (chr(65) eq 'A') ? "\n" : " in a non-ASCII world\n";

    print $TESTOUT "# Win32::BuildNumber ", &Win32::BuildNumber(), "\n"
      if defined(&Win32::BuildNumber) and defined &Win32::BuildNumber();

    print $TESTOUT "# MacPerl version $MacPerl::Version\n"
      if defined $MacPerl::Version;

    printf $TESTOUT
      "# Current time local: %s\n# Current time GMT:   %s\n",
      scalar(localtime($^T)), scalar(gmtime($^T));
      
    print $TESTOUT "# Using Test.pm version $VERSION\n";

    # Retval never used:
    return undef;
}

sub _read_program {
  my($file) = shift;
  return unless defined $file and length $file
    and -e $file and -f _ and -r _;
  open(SOURCEFILE, "<$file") || return;
  $Program_Lines{$file} = [<SOURCEFILE>];
  close(SOURCEFILE);
  
  foreach my $x (@{$Program_Lines{$file}})
   { $x =~ tr/\cm\cj\n\r//d }
  
  unshift @{$Program_Lines{$file}}, '';
  return 1;
}

sub _to_value {
    my ($v) = @_;
    return (ref $v or '') eq 'CODE' ? $v->() : $v;
}

# A past maintainer of this module said:
# <<ok(...)'s special handling of subroutine references is an unfortunate
#   "feature" that can't be removed due to compatibility.>>
#

sub ok ($;$$) {
    croak "ok: plan before you test!" if !$planned;

    local($\,$,);   # guard against -l and other things that screw with
                    # print

    my ($pkg,$file,$line) = caller($TestLevel);
    my $repetition = ++$history{"$file:$line"};
    my $context = ("$file at line $line".
		   ($repetition > 1 ? " fail \#$repetition" : ''));

    # Are we comparing two values?
    my $compare = 0;

    my $ok=0;
    my $result = _to_value(shift);
    my ($expected,$diag,$isregex,$regex);
    if (@_ == 0) {
	$ok = $result;
    } else {
        $compare = 1;
	$expected = _to_value(shift);
	if (!defined $expected) {
	    $ok = !defined $result;
	} elsif (!defined $result) {
	    $ok = 0;
	} elsif ((ref($expected)||'') eq 'Regexp') {
	    $ok = $result =~ /$expected/;
            $regex = $expected;
	} elsif (($regex) = ($expected =~ m,^ / (.+) / $,sx) or
	    (undef, $regex) = ($expected =~ m,^ m([^\w\s]) (.+) \1 $,sx)) {
	    $ok = $result =~ /$regex/;
	} else {
	    $ok = $result eq $expected;
	}
    }
    my $todo = $todo{$ntest};
    if ($todo and $ok) {
	$context .= ' TODO?!' if $todo;
	print $TESTOUT "ok $ntest # ($context)\n";
    } else {
        # Issuing two seperate prints() causes problems on VMS.
        if (!$ok) {
            print $TESTOUT "not ok $ntest\n";
        }
	else {
            print $TESTOUT "ok $ntest\n";
        }
	
	if (!$ok) {
	    my $detail = { 'repetition' => $repetition, 'package' => $pkg,
			   'result' => $result, 'todo' => $todo };
	    $$detail{expected} = $expected if defined $expected;

            # Get the user's diagnostic, protecting against multi-line
            # diagnostics.
	    $diag = $$detail{diagnostic} = _to_value(shift) if @_;
            $diag =~ s/\n/\n#/g if defined $diag;

	    $context .= ' *TODO*' if $todo;
	    if (!$compare) {
		if (!$diag) {
		    print $TESTERR "# Failed test $ntest in $context\n";
		} else {
		    print $TESTERR "# Failed test $ntest in $context: $diag\n";
		}
	    } else {
		my $prefix = "Test $ntest";
		print $TESTERR "# $prefix got: ".
		    (defined $result? "'$result'":'<UNDEF>')." ($context)\n";
		$prefix = ' ' x (length($prefix) - 5);
		if (defined $regex) {
		    $expected = 'qr{'.$regex.'}';
		}
                elsif (defined $expected) {
		    $expected = "'$expected'";
		}
                else {
                    $expected = '<UNDEF>';
                }
		if (!$diag) {
		    print $TESTERR "# $prefix Expected: $expected\n";
		} else {
		    print $TESTERR "# $prefix Expected: $expected ($diag)\n";
		}
	    }

            if(defined $Program_Lines{$file}[$line]) {
                print $TESTERR
                  "#  $file line $line is: $Program_Lines{$file}[$line]\n"
                 if
                  $Program_Lines{$file}[$line] =~ m/[^\s\#\(\)\{\}\[\]\;]/
                   # Otherwise it's a pretty uninteresting line!
                ;
                
                undef $Program_Lines{$file}[$line];
                 # So we won't repeat it.
            }

	    push @FAILDETAIL, $detail;
	}
    }
    ++ $ntest;
    $ok;
}

sub skip ($;$$$) {
    local($\, $,);   # guard against -l and other things that screw with
                     # print

    my $whyskip = _to_value(shift);
    if (!@_ or $whyskip) {
	$whyskip = '' if $whyskip =~ m/^\d+$/;
        $whyskip =~ s/^[Ss]kip(?:\s+|$)//;  # backwards compatibility, old
                                            # versions required the reason
                                            # to start with 'skip'
        # We print in one shot for VMSy reasons.
        my $ok = "ok $ntest # skip";
        $ok .= " $whyskip" if length $whyskip;
        $ok .= "\n";
        print $TESTOUT $ok;
        ++ $ntest;
        return 1;
    } else {
        # backwards compatiblity (I think).  skip() used to be
        # called like ok(), which is weird.  I haven't decided what to do with
        # this yet.
#        warn <<WARN if $^W;
#This looks like a skip() using the very old interface.  Please upgrade to
#the documented interface as this has been deprecated.
#WARN

	local($TestLevel) = $TestLevel+1;  #to ignore this stack frame
        return &ok(@_);
    }
}

END {
    $ONFAIL->(\@FAILDETAIL) if @FAILDETAIL && $ONFAIL;
}

1;
__END__

# "Your mistake was a hidden intention."
#  -- /Oblique Strategies/,  Brian Eno and Peter Schmidt
