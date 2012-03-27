# Getopt::Long.pm -- Universal options parsing

package Getopt::Long;

# RCS Status      : $Id: GetoptLong.pm,v 2.68 2003-09-23 15:24:53+02 jv Exp $
# Author          : Johan Vromans
# Created On      : Tue Sep 11 15:00:12 1990
# Last Modified By: Johan Vromans
# Last Modified On: Tue Sep 23 15:21:23 2003
# Update Count    : 1364
# Status          : Released

################ Copyright ################

# This program is Copyright 1990,2002 by Johan Vromans.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the Perl Artistic License or the
# GNU General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any
# later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# If you do not have a copy of the GNU General Public License write to
# the Free Software Foundation, Inc., 675 Mass Ave, Cambridge,
# MA 02139, USA.

################ Module Preamble ################

use 5.004;

use strict;

use vars qw($VERSION);
$VERSION        =  2.34;
# For testing versions only.
#use vars qw($VERSION_STRING);
#$VERSION_STRING = "2.33_03";

use Exporter;
use vars qw(@ISA @EXPORT @EXPORT_OK);
@ISA = qw(Exporter);

# Exported subroutines.
sub GetOptions(@);		# always
sub Configure(@);		# on demand
sub HelpMessage(@);		# on demand
sub VersionMessage(@);		# in demand

BEGIN {
    # Init immediately so their contents can be used in the 'use vars' below.
    @EXPORT    = qw(&GetOptions $REQUIRE_ORDER $PERMUTE $RETURN_IN_ORDER);
    @EXPORT_OK = qw(&HelpMessage &VersionMessage &Configure);
}

# User visible variables.
use vars @EXPORT, @EXPORT_OK;
use vars qw($error $debug $major_version $minor_version);
# Deprecated visible variables.
use vars qw($autoabbrev $getopt_compat $ignorecase $bundling $order
	    $passthrough);
# Official invisible variables.
use vars qw($genprefix $caller $gnu_compat $auto_help $auto_version);

# Public subroutines.
sub config(@);			# deprecated name

# Private subroutines.
sub ConfigDefaults();
sub ParseOptionSpec($$);
sub OptCtl($);
sub FindOption($$$$);

################ Local Variables ################

# $requested_version holds the version that was mentioned in the 'use'
# or 'require', if any. It can be used to enable or disable specific
# features.
my $requested_version = 0;

################ Resident subroutines ################

sub ConfigDefaults() {
    # Handle POSIX compliancy.
    if ( defined $ENV{"POSIXLY_CORRECT"} ) {
	$genprefix = "(--|-)";
	$autoabbrev = 0;		# no automatic abbrev of options
	$bundling = 0;			# no bundling of single letter switches
	$getopt_compat = 0;		# disallow '+' to start options
	$order = $REQUIRE_ORDER;
    }
    else {
	$genprefix = "(--|-|\\+)";
	$autoabbrev = 1;		# automatic abbrev of options
	$bundling = 0;			# bundling off by default
	$getopt_compat = 1;		# allow '+' to start options
	$order = $PERMUTE;
    }
    # Other configurable settings.
    $debug = 0;			# for debugging
    $error = 0;			# error tally
    $ignorecase = 1;		# ignore case when matching options
    $passthrough = 0;		# leave unrecognized options alone
    $gnu_compat = 0;		# require --opt=val if value is optional
}

# Override import.
sub import {
    my $pkg = shift;		# package
    my @syms = ();		# symbols to import
    my @config = ();		# configuration
    my $dest = \@syms;		# symbols first
    for ( @_ ) {
	if ( $_ eq ':config' ) {
	    $dest = \@config;	# config next
	    next;
	}
	push(@$dest, $_);	# push
    }
    # Hide one level and call super.
    local $Exporter::ExportLevel = 1;
    push(@syms, qw(&GetOptions)) if @syms; # always export GetOptions
    $pkg->SUPER::import(@syms);
    # And configure.
    Configure(@config) if @config;
}

################ Initialization ################

# Values for $order. See GNU getopt.c for details.
($REQUIRE_ORDER, $PERMUTE, $RETURN_IN_ORDER) = (0..2);
# Version major/minor numbers.
($major_version, $minor_version) = $VERSION =~ /^(\d+)\.(\d+)/;

ConfigDefaults();

################ OO Interface ################

package Getopt::Long::Parser;

# Store a copy of the default configuration. Since ConfigDefaults has
# just been called, what we get from Configure is the default.
my $default_config = do {
    Getopt::Long::Configure ()
};

sub new {
    my $that = shift;
    my $class = ref($that) || $that;
    my %atts = @_;

    # Register the callers package.
    my $self = { caller_pkg => (caller)[0] };

    bless ($self, $class);

    # Process config attributes.
    if ( defined $atts{config} ) {
	my $save = Getopt::Long::Configure ($default_config, @{$atts{config}});
	$self->{settings} = Getopt::Long::Configure ($save);
	delete ($atts{config});
    }
    # Else use default config.
    else {
	$self->{settings} = $default_config;
    }

    if ( %atts ) {		# Oops
	die(__PACKAGE__.": unhandled attributes: ".
	    join(" ", sort(keys(%atts)))."\n");
    }

    $self;
}

sub configure {
    my ($self) = shift;

    # Restore settings, merge new settings in.
    my $save = Getopt::Long::Configure ($self->{settings}, @_);

    # Restore orig config and save the new config.
    $self->{settings} = Getopt::Long::Configure ($save);
}

sub getoptions {
    my ($self) = shift;

    # Restore config settings.
    my $save = Getopt::Long::Configure ($self->{settings});

    # Call main routine.
    my $ret = 0;
    $Getopt::Long::caller = $self->{caller_pkg};

    eval {
	# Locally set exception handler to default, otherwise it will
	# be called implicitly here, and again explicitly when we try
	# to deliver the messages.
	local ($SIG{__DIE__}) = '__DEFAULT__';
	$ret = Getopt::Long::GetOptions (@_);
    };

    # Restore saved settings.
    Getopt::Long::Configure ($save);

    # Handle errors and return value.
    die ($@) if $@;
    return $ret;
}

package Getopt::Long;

################ Back to Normal ################

# Indices in option control info.
# Note that ParseOptions uses the fields directly. Search for 'hard-wired'.
use constant CTL_TYPE    => 0;
#use constant   CTL_TYPE_FLAG   => '';
#use constant   CTL_TYPE_NEG    => '!';
#use constant   CTL_TYPE_INCR   => '+';
#use constant   CTL_TYPE_INT    => 'i';
#use constant   CTL_TYPE_INTINC => 'I';
#use constant   CTL_TYPE_XINT   => 'o';
#use constant   CTL_TYPE_FLOAT  => 'f';
#use constant   CTL_TYPE_STRING => 's';

use constant CTL_CNAME   => 1;

use constant CTL_MAND    => 2;

use constant CTL_DEST    => 3;
 use constant   CTL_DEST_SCALAR => 0;
 use constant   CTL_DEST_ARRAY  => 1;
 use constant   CTL_DEST_HASH   => 2;
 use constant   CTL_DEST_CODE   => 3;

use constant CTL_DEFAULT => 4;

# FFU.
#use constant CTL_RANGE   => ;
#use constant CTL_REPEAT  => ;

sub GetOptions(@) {

    my @optionlist = @_;	# local copy of the option descriptions
    my $argend = '--';		# option list terminator
    my %opctl = ();		# table of option specs
    my $pkg = $caller || (caller)[0];	# current context
				# Needed if linkage is omitted.
    my @ret = ();		# accum for non-options
    my %linkage;		# linkage
    my $userlinkage;		# user supplied HASH
    my $opt;			# current option
    my $prefix = $genprefix;	# current prefix

    $error = '';

    if ( $debug ) {
	# Avoid some warnings if debugging.
	local ($^W) = 0;
	print STDERR
	  ("Getopt::Long $Getopt::Long::VERSION (",
	   '$Revision: 2.68 $', ") ",
	   "called from package \"$pkg\".",
	   "\n  ",
	   "ARGV: (@ARGV)",
	   "\n  ",
	   "autoabbrev=$autoabbrev,".
	   "bundling=$bundling,",
	   "getopt_compat=$getopt_compat,",
	   "gnu_compat=$gnu_compat,",
	   "order=$order,",
	   "\n  ",
	   "ignorecase=$ignorecase,",
	   "requested_version=$requested_version,",
	   "passthrough=$passthrough,",
	   "genprefix=\"$genprefix\".",
	   "\n");
    }

    # Check for ref HASH as first argument.
    # First argument may be an object. It's OK to use this as long
    # as it is really a hash underneath.
    $userlinkage = undef;
    if ( @optionlist && ref($optionlist[0]) and
	 "$optionlist[0]" =~ /^(?:.*\=)?HASH\([^\(]*\)$/ ) {
	$userlinkage = shift (@optionlist);
	print STDERR ("=> user linkage: $userlinkage\n") if $debug;
    }

    # See if the first element of the optionlist contains option
    # starter characters.
    # Be careful not to interpret '<>' as option starters.
    if ( @optionlist && $optionlist[0] =~ /^\W+$/
	 && !($optionlist[0] eq '<>'
	      && @optionlist > 0
	      && ref($optionlist[1])) ) {
	$prefix = shift (@optionlist);
	# Turn into regexp. Needs to be parenthesized!
	$prefix =~ s/(\W)/\\$1/g;
	$prefix = "([" . $prefix . "])";
	print STDERR ("=> prefix=\"$prefix\"\n") if $debug;
    }

    # Verify correctness of optionlist.
    %opctl = ();
    while ( @optionlist ) {
	my $opt = shift (@optionlist);

	# Strip leading prefix so people can specify "--foo=i" if they like.
	$opt = $+ if $opt =~ /^$prefix+(.*)$/s;

	if ( $opt eq '<>' ) {
	    if ( (defined $userlinkage)
		&& !(@optionlist > 0 && ref($optionlist[0]))
		&& (exists $userlinkage->{$opt})
		&& ref($userlinkage->{$opt}) ) {
		unshift (@optionlist, $userlinkage->{$opt});
	    }
	    unless ( @optionlist > 0
		    && ref($optionlist[0]) && ref($optionlist[0]) eq 'CODE' ) {
		$error .= "Option spec <> requires a reference to a subroutine\n";
		# Kill the linkage (to avoid another error).
		shift (@optionlist)
		  if @optionlist && ref($optionlist[0]);
		next;
	    }
	    $linkage{'<>'} = shift (@optionlist);
	    next;
	}

	# Parse option spec.
	my ($name, $orig) = ParseOptionSpec ($opt, \%opctl);
	unless ( defined $name ) {
	    # Failed. $orig contains the error message. Sorry for the abuse.
	    $error .= $orig;
	    # Kill the linkage (to avoid another error).
	    shift (@optionlist)
	      if @optionlist && ref($optionlist[0]);
	    next;
	}

	# If no linkage is supplied in the @optionlist, copy it from
	# the userlinkage if available.
	if ( defined $userlinkage ) {
	    unless ( @optionlist > 0 && ref($optionlist[0]) ) {
		if ( exists $userlinkage->{$orig} &&
		     ref($userlinkage->{$orig}) ) {
		    print STDERR ("=> found userlinkage for \"$orig\": ",
				  "$userlinkage->{$orig}\n")
			if $debug;
		    unshift (@optionlist, $userlinkage->{$orig});
		}
		else {
		    # Do nothing. Being undefined will be handled later.
		    next;
		}
	    }
	}

	# Copy the linkage. If omitted, link to global variable.
	if ( @optionlist > 0 && ref($optionlist[0]) ) {
	    print STDERR ("=> link \"$orig\" to $optionlist[0]\n")
		if $debug;
	    my $rl = ref($linkage{$orig} = shift (@optionlist));

	    if ( $rl eq "ARRAY" ) {
		$opctl{$name}[CTL_DEST] = CTL_DEST_ARRAY;
	    }
	    elsif ( $rl eq "HASH" ) {
		$opctl{$name}[CTL_DEST] = CTL_DEST_HASH;
	    }
	    elsif ( $rl eq "SCALAR" ) {
#		if ( $opctl{$name}[CTL_DEST] == CTL_DEST_ARRAY ) {
#		    my $t = $linkage{$orig};
#		    $$t = $linkage{$orig} = [];
#		}
#		elsif ( $opctl{$name}[CTL_DEST] == CTL_DEST_HASH ) {
#		}
#		else {
		    # Ok.
#		}
	    }
	    elsif ( $rl eq "CODE" ) {
		# Ok.
	    }
	    else {
		$error .= "Invalid option linkage for \"$opt\"\n";
	    }
	}
	else {
	    # Link to global $opt_XXX variable.
	    # Make sure a valid perl identifier results.
	    my $ov = $orig;
	    $ov =~ s/\W/_/g;
	    if ( $opctl{$name}[CTL_DEST] == CTL_DEST_ARRAY ) {
		print STDERR ("=> link \"$orig\" to \@$pkg","::opt_$ov\n")
		    if $debug;
		eval ("\$linkage{\$orig} = \\\@".$pkg."::opt_$ov;");
	    }
	    elsif ( $opctl{$name}[CTL_DEST] == CTL_DEST_HASH ) {
		print STDERR ("=> link \"$orig\" to \%$pkg","::opt_$ov\n")
		    if $debug;
		eval ("\$linkage{\$orig} = \\\%".$pkg."::opt_$ov;");
	    }
	    else {
		print STDERR ("=> link \"$orig\" to \$$pkg","::opt_$ov\n")
		    if $debug;
		eval ("\$linkage{\$orig} = \\\$".$pkg."::opt_$ov;");
	    }
	}
    }

    # Bail out if errors found.
    die ($error) if $error;
    $error = 0;

    # Supply --version and --help support, if needed and allowed.
    if ( defined($auto_version) ? $auto_version : ($requested_version >= 2.3203) ) {
	if ( !defined($opctl{version}) ) {
	    $opctl{version} = ['','version',0,CTL_DEST_CODE,undef];
	    $linkage{version} = \&VersionMessage;
	}
	$auto_version = 1;
    }
    if ( defined($auto_help) ? $auto_help : ($requested_version >= 2.3203) ) {
	if ( !defined($opctl{help}) && !defined($opctl{'?'}) ) {
	    $opctl{help} = $opctl{'?'} = ['','help',0,CTL_DEST_CODE,undef];
	    $linkage{help} = \&HelpMessage;
	}
	$auto_help = 1;
    }

    # Show the options tables if debugging.
    if ( $debug ) {
	my ($arrow, $k, $v);
	$arrow = "=> ";
	while ( ($k,$v) = each(%opctl) ) {
	    print STDERR ($arrow, "\$opctl{$k} = $v ", OptCtl($v), "\n");
	    $arrow = "   ";
	}
    }

    # Process argument list
    my $goon = 1;
    while ( $goon && @ARGV > 0 ) {

	# Get next argument.
	$opt = shift (@ARGV);
	print STDERR ("=> arg \"", $opt, "\"\n") if $debug;

	# Double dash is option list terminator.
	if ( $opt eq $argend ) {
	  push (@ret, $argend) if $passthrough;
	  last;
	}

	# Look it up.
	my $tryopt = $opt;
	my $found;		# success status
	my $key;		# key (if hash type)
	my $arg;		# option argument
	my $ctl;		# the opctl entry

	($found, $opt, $ctl, $arg, $key) =
	  FindOption ($prefix, $argend, $opt, \%opctl);

	if ( $found ) {

	    # FindOption undefines $opt in case of errors.
	    next unless defined $opt;

	    if ( defined $arg ) {

		# Get the canonical name.
		print STDERR ("=> cname for \"$opt\" is ") if $debug;
		$opt = $ctl->[CTL_CNAME];
		print STDERR ("\"$ctl->[CTL_CNAME]\"\n") if $debug;

		if ( defined $linkage{$opt} ) {
		    print STDERR ("=> ref(\$L{$opt}) -> ",
				  ref($linkage{$opt}), "\n") if $debug;

		    if ( ref($linkage{$opt}) eq 'SCALAR' ) {
			if ( $ctl->[CTL_TYPE] eq '+' ) {
			    print STDERR ("=> \$\$L{$opt} += \"$arg\"\n")
			      if $debug;
			    if ( defined ${$linkage{$opt}} ) {
			        ${$linkage{$opt}} += $arg;
			    }
		            else {
			        ${$linkage{$opt}} = $arg;
			    }
			}
			elsif ( $ctl->[CTL_DEST] == CTL_DEST_ARRAY ) {
			    print STDERR ("=> ref(\$L{$opt}) auto-vivified",
					  " to ARRAY\n")
			      if $debug;
			    my $t = $linkage{$opt};
			    $$t = $linkage{$opt} = [];
			    print STDERR ("=> push(\@{\$L{$opt}, \"$arg\")\n")
			      if $debug;
			    push (@{$linkage{$opt}}, $arg);
			}
			elsif ( $ctl->[CTL_DEST] == CTL_DEST_HASH ) {
			    print STDERR ("=> ref(\$L{$opt}) auto-vivified",
					  " to HASH\n")
			      if $debug;
			    my $t = $linkage{$opt};
			    $$t = $linkage{$opt} = {};
			    print STDERR ("=> \$\$L{$opt}->{$key} = \"$arg\"\n")
			      if $debug;
			    $linkage{$opt}->{$key} = $arg;
			}
			else {
			    print STDERR ("=> \$\$L{$opt} = \"$arg\"\n")
			      if $debug;
			    ${$linkage{$opt}} = $arg;
		        }
		    }
		    elsif ( ref($linkage{$opt}) eq 'ARRAY' ) {
			print STDERR ("=> push(\@{\$L{$opt}, \"$arg\")\n")
			    if $debug;
			push (@{$linkage{$opt}}, $arg);
		    }
		    elsif ( ref($linkage{$opt}) eq 'HASH' ) {
			print STDERR ("=> \$\$L{$opt}->{$key} = \"$arg\"\n")
			    if $debug;
			$linkage{$opt}->{$key} = $arg;
		    }
		    elsif ( ref($linkage{$opt}) eq 'CODE' ) {
			print STDERR ("=> &L{$opt}(\"$opt\"",
				      $ctl->[CTL_DEST] == CTL_DEST_HASH ? ", \"$key\"" : "",
				      ", \"$arg\")\n")
			    if $debug;
			my $eval_error = do {
			    local $@;
			    local $SIG{__DIE__}  = '__DEFAULT__';
			    eval {
				&{$linkage{$opt}}($opt,
						  $ctl->[CTL_DEST] == CTL_DEST_HASH ? ($key) : (),
						  $arg);
			    };
			    $@;
			};
			print STDERR ("=> die($eval_error)\n")
			  if $debug && $eval_error ne '';
			if ( $eval_error =~ /^!/ ) {
			    if ( $eval_error =~ /^!FINISH\b/ ) {
				$goon = 0;
			    }
			}
			elsif ( $eval_error ne '' ) {
			    warn ($eval_error);
			    $error++;
			}
		    }
		    else {
			print STDERR ("Invalid REF type \"", ref($linkage{$opt}),
				      "\" in linkage\n");
			die("Getopt::Long -- internal error!\n");
		    }
		}
		# No entry in linkage means entry in userlinkage.
		elsif ( $ctl->[CTL_DEST] == CTL_DEST_ARRAY ) {
		    if ( defined $userlinkage->{$opt} ) {
			print STDERR ("=> push(\@{\$L{$opt}}, \"$arg\")\n")
			    if $debug;
			push (@{$userlinkage->{$opt}}, $arg);
		    }
		    else {
			print STDERR ("=>\$L{$opt} = [\"$arg\"]\n")
			    if $debug;
			$userlinkage->{$opt} = [$arg];
		    }
		}
		elsif ( $ctl->[CTL_DEST] == CTL_DEST_HASH ) {
		    if ( defined $userlinkage->{$opt} ) {
			print STDERR ("=> \$L{$opt}->{$key} = \"$arg\"\n")
			    if $debug;
			$userlinkage->{$opt}->{$key} = $arg;
		    }
		    else {
			print STDERR ("=>\$L{$opt} = {$key => \"$arg\"}\n")
			    if $debug;
			$userlinkage->{$opt} = {$key => $arg};
		    }
		}
		else {
		    if ( $ctl->[CTL_TYPE] eq '+' ) {
			print STDERR ("=> \$L{$opt} += \"$arg\"\n")
			  if $debug;
			if ( defined $userlinkage->{$opt} ) {
			    $userlinkage->{$opt} += $arg;
			}
			else {
			    $userlinkage->{$opt} = $arg;
			}
		    }
		    else {
			print STDERR ("=>\$L{$opt} = \"$arg\"\n") if $debug;
			$userlinkage->{$opt} = $arg;
		    }
		}
	    }
	}

	# Not an option. Save it if we $PERMUTE and don't have a <>.
	elsif ( $order == $PERMUTE ) {
	    # Try non-options call-back.
	    my $cb;
	    if ( (defined ($cb = $linkage{'<>'})) ) {
		print STDERR ("=> &L{$tryopt}(\"$tryopt\")\n")
		  if $debug;
		my $eval_error = do {
		    local $@;
		    local $SIG{__DIE__}  = '__DEFAULT__';
		    eval { &$cb ($tryopt) };
		    $@;
		};
		print STDERR ("=> die($eval_error)\n")
		  if $debug && $eval_error ne '';
		if ( $eval_error =~ /^!/ ) {
		    if ( $eval_error =~ /^!FINISH\b/ ) {
			$goon = 0;
		    }
		}
		elsif ( $eval_error ne '' ) {
		    warn ($eval_error);
		    $error++;
		}
	    }
	    else {
		print STDERR ("=> saving \"$tryopt\" ",
			      "(not an option, may permute)\n") if $debug;
		push (@ret, $tryopt);
	    }
	    next;
	}

	# ...otherwise, terminate.
	else {
	    # Push this one back and exit.
	    unshift (@ARGV, $tryopt);
	    return ($error == 0);
	}

    }

    # Finish.
    if ( @ret && $order == $PERMUTE ) {
	#  Push back accumulated arguments
	print STDERR ("=> restoring \"", join('" "', @ret), "\"\n")
	    if $debug;
	unshift (@ARGV, @ret);
    }

    return ($error == 0);
}

# A readable representation of what's in an optbl.
sub OptCtl ($) {
    my ($v) = @_;
    my @v = map { defined($_) ? ($_) : ("<undef>") } @$v;
    "[".
      join(",",
	   "\"$v[CTL_TYPE]\"",
	   "\"$v[CTL_CNAME]\"",
	   $v[CTL_MAND] ? "O" : "M",
	   ("\$","\@","\%","\&")[$v[CTL_DEST] || 0],
	   "\"$v[CTL_DEFAULT]\"",
#	   $v[CTL_RANGE] || '',
#	   $v[CTL_REPEAT] || '',
	  ). "]";
}

# Parse an option specification and fill the tables.
sub ParseOptionSpec ($$) {
    my ($opt, $opctl) = @_;

    # Match option spec.
    if ( $opt !~ m;^
		   (
		     # Option name
		     (?: \w+[-\w]* )
		     # Alias names, or "?"
		     (?: \| (?: \? | \w[-\w]* )? )*
		   )?
		   (
		     # Either modifiers ...
		     [!+]
		     |
		     # ... or a value/dest specification
		     [=:] [ionfs] [@%]?
		     |
		     # ... or an optional-with-default spec
		     : (?: -?\d+ | \+ ) [@%]?
		   )?
		   $;x ) {
	return (undef, "Error in option spec: \"$opt\"\n");
    }

    my ($names, $spec) = ($1, $2);
    $spec = '' unless defined $spec;

    # $orig keeps track of the primary name the user specified.
    # This name will be used for the internal or external linkage.
    # In other words, if the user specifies "FoO|BaR", it will
    # match any case combinations of 'foo' and 'bar', but if a global
    # variable needs to be set, it will be $opt_FoO in the exact case
    # as specified.
    my $orig;

    my @names;
    if ( defined $names ) {
	@names =  split (/\|/, $names);
	$orig = $names[0];
    }
    else {
	@names = ('');
	$orig = '';
    }

    # Construct the opctl entries.
    my $entry;
    if ( $spec eq '' || $spec eq '+' || $spec eq '!' ) {
	# Fields are hard-wired here.
	$entry = [$spec,$orig,0,CTL_DEST_SCALAR,undef];
    }
    elsif ( $spec =~ /:(-?\d+|\+)([@%])?/ ) {
	my $def = $1;
	my $dest = $2;
	my $type = $def eq '+' ? 'I' : 'i';
	$dest ||= '$';
	$dest = $dest eq '@' ? CTL_DEST_ARRAY
	  : $dest eq '%' ? CTL_DEST_HASH : CTL_DEST_SCALAR;
	# Fields are hard-wired here.
	$entry = [$type,$orig,0,$dest,$def eq '+' ? undef : $def];
    }
    else {
	my ($mand, $type, $dest) = $spec =~ /([=:])([ionfs])([@%])?/;
	$type = 'i' if $type eq 'n';
	$dest ||= '$';
	$dest = $dest eq '@' ? CTL_DEST_ARRAY
	  : $dest eq '%' ? CTL_DEST_HASH : CTL_DEST_SCALAR;
	# Fields are hard-wired here.
	$entry = [$type,$orig,$mand eq '=',$dest,undef];
    }

    # Process all names. First is canonical, the rest are aliases.
    my $dups = '';
    foreach ( @names ) {

	$_ = lc ($_)
	  if $ignorecase > (($bundling && length($_) == 1) ? 1 : 0);

	if ( exists $opctl->{$_} ) {
	    $dups .= "Duplicate specification \"$opt\" for option \"$_\"\n";
	}

	if ( $spec eq '!' ) {
	    $opctl->{"no$_"} = $entry;
	    $opctl->{"no-$_"} = $entry;
	    $opctl->{$_} = [@$entry];
	    $opctl->{$_}->[CTL_TYPE] = '';
	}
	else {
	    $opctl->{$_} = $entry;
	}
    }

    if ( $dups && $^W ) {
	foreach ( split(/\n+/, $dups) ) {
	    warn($_."\n");
	}
    }
    ($names[0], $orig);
}

# Option lookup.
sub FindOption ($$$$) {

    # returns (1, $opt, $ctl, $arg, $key) if okay,
    # returns (1, undef) if option in error,
    # returns (0) otherwise.

    my ($prefix, $argend, $opt, $opctl) = @_;

    print STDERR ("=> find \"$opt\"\n") if $debug;

    return (0) unless $opt =~ /^$prefix(.*)$/s;
    return (0) if $opt eq "-" && !defined $opctl->{''};

    $opt = $+;
    my $starter = $1;

    print STDERR ("=> split \"$starter\"+\"$opt\"\n") if $debug;

    my $optarg;			# value supplied with --opt=value
    my $rest;			# remainder from unbundling

    # If it is a long option, it may include the value.
    # With getopt_compat, only if not bundling.
    if ( ($starter eq "--" 
          || ($getopt_compat && ($bundling == 0 || $bundling == 2)))
	  && $opt =~ /^([^=]+)=(.*)$/s ) {
	$opt = $1;
	$optarg = $2;
	print STDERR ("=> option \"", $opt,
		      "\", optarg = \"$optarg\"\n") if $debug;
    }

    #### Look it up ###

    my $tryopt = $opt;		# option to try

    if ( $bundling && $starter eq '-' ) {

	# To try overrides, obey case ignore.
	$tryopt = $ignorecase ? lc($opt) : $opt;

	# If bundling == 2, long options can override bundles.
	if ( $bundling == 2 && length($tryopt) > 1
	     && defined ($opctl->{$tryopt}) ) {
	    print STDERR ("=> $starter$tryopt overrides unbundling\n")
	      if $debug;
	}
	else {
	    $tryopt = $opt;
	    # Unbundle single letter option.
	    $rest = length ($tryopt) > 0 ? substr ($tryopt, 1) : '';
	    $tryopt = substr ($tryopt, 0, 1);
	    $tryopt = lc ($tryopt) if $ignorecase > 1;
	    print STDERR ("=> $starter$tryopt unbundled from ",
			  "$starter$tryopt$rest\n") if $debug;
	    $rest = undef unless $rest ne '';
	}
    }

    # Try auto-abbreviation.
    elsif ( $autoabbrev ) {
	# Sort the possible long option names.
	my @names = sort(keys (%$opctl));
	# Downcase if allowed.
	$opt = lc ($opt) if $ignorecase;
	$tryopt = $opt;
	# Turn option name into pattern.
	my $pat = quotemeta ($opt);
	# Look up in option names.
	my @hits = grep (/^$pat/, @names);
	print STDERR ("=> ", scalar(@hits), " hits (@hits) with \"$pat\" ",
		      "out of ", scalar(@names), "\n") if $debug;

	# Check for ambiguous results.
	unless ( (@hits <= 1) || (grep ($_ eq $opt, @hits) == 1) ) {
	    # See if all matches are for the same option.
	    my %hit;
	    foreach ( @hits ) {
		$_ = $opctl->{$_}->[CTL_CNAME]
		  if defined $opctl->{$_}->[CTL_CNAME];
		$hit{$_} = 1;
	    }
	    # Remove auto-supplied options (version, help).
	    if ( keys(%hit) == 2 ) {
		if ( $auto_version && exists($hit{version}) ) {
		    delete $hit{version};
		}
		elsif ( $auto_help && exists($hit{help}) ) {
		    delete $hit{help};
		}
	    }
	    # Now see if it really is ambiguous.
	    unless ( keys(%hit) == 1 ) {
		return (0) if $passthrough;
		warn ("Option ", $opt, " is ambiguous (",
		      join(", ", @hits), ")\n");
		$error++;
		return (1, undef);
	    }
	    @hits = keys(%hit);
	}

	# Complete the option name, if appropriate.
	if ( @hits == 1 && $hits[0] ne $opt ) {
	    $tryopt = $hits[0];
	    $tryopt = lc ($tryopt) if $ignorecase;
	    print STDERR ("=> option \"$opt\" -> \"$tryopt\"\n")
		if $debug;
	}
    }

    # Map to all lowercase if ignoring case.
    elsif ( $ignorecase ) {
	$tryopt = lc ($opt);
    }

    # Check validity by fetching the info.
    my $ctl = $opctl->{$tryopt};
    unless  ( defined $ctl ) {
	return (0) if $passthrough;
	# Pretend one char when bundling.
	if ( $bundling == 1) {
	    $opt = substr($opt,0,1);
            unshift (@ARGV, $starter.$rest) if defined $rest;
	}
	warn ("Unknown option: ", $opt, "\n");
	$error++;
	return (1, undef);
    }
    # Apparently valid.
    $opt = $tryopt;
    print STDERR ("=> found ", OptCtl($ctl),
		  " for \"", $opt, "\"\n") if $debug;

    #### Determine argument status ####

    # If it is an option w/o argument, we're almost finished with it.
    my $type = $ctl->[CTL_TYPE];
    my $arg;

    if ( $type eq '' || $type eq '!' || $type eq '+' ) {
	if ( defined $optarg ) {
	    return (0) if $passthrough;
	    warn ("Option ", $opt, " does not take an argument\n");
	    $error++;
	    undef $opt;
	}
	elsif ( $type eq '' || $type eq '+' ) {
	    # Supply explicit value.
	    $arg = 1;
	}
	else {
	    $opt =~ s/^no-?//i;	# strip NO prefix
	    $arg = 0;		# supply explicit value
	}
	unshift (@ARGV, $starter.$rest) if defined $rest;
	return (1, $opt, $ctl, $arg);
    }

    # Get mandatory status and type info.
    my $mand = $ctl->[CTL_MAND];

    # Check if there is an option argument available.
    if ( $gnu_compat && defined $optarg && $optarg eq '' ) {
	return (1, $opt, $ctl, $type eq 's' ? '' : 0) unless $mand;
	$optarg = 0 unless $type eq 's';
    }

    # Check if there is an option argument available.
    if ( defined $optarg
	 ? ($optarg eq '')
	 : !(defined $rest || @ARGV > 0) ) {
	# Complain if this option needs an argument.
	if ( $mand ) {
	    return (0) if $passthrough;
	    warn ("Option ", $opt, " requires an argument\n");
	    $error++;
	    return (1, undef);
	}
	if ( $type eq 'I' ) {
	    # Fake incremental type.
	    my @c = @$ctl;
	    $c[CTL_TYPE] = '+';
	    return (1, $opt, \@c, 1);
	}
	return (1, $opt, $ctl,
		defined($ctl->[CTL_DEFAULT]) ? $ctl->[CTL_DEFAULT] :
		$type eq 's' ? '' : 0);
    }

    # Get (possibly optional) argument.
    $arg = (defined $rest ? $rest
	    : (defined $optarg ? $optarg : shift (@ARGV)));

    # Get key if this is a "name=value" pair for a hash option.
    my $key;
    if ($ctl->[CTL_DEST] == CTL_DEST_HASH && defined $arg) {
	($key, $arg) = ($arg =~ /^([^=]*)=(.*)$/s) ? ($1, $2)
	  : ($arg, defined($ctl->[CTL_DEFAULT]) ? $ctl->[CTL_DEFAULT] :
	     ($mand ? undef : ($type eq 's' ? "" : 1)));
	if (! defined $arg) {
	    warn ("Option $opt, key \"$key\", requires a value\n");
	    $error++;
	    # Push back.
	    unshift (@ARGV, $starter.$rest) if defined $rest;
	    return (1, undef);
	}
    }

    #### Check if the argument is valid for this option ####

    my $key_valid = $ctl->[CTL_DEST] == CTL_DEST_HASH ? "[^=]+=" : "";

    if ( $type eq 's' ) {	# string
	# A mandatory string takes anything.
	return (1, $opt, $ctl, $arg, $key) if $mand;

	# An optional string takes almost anything.
	return (1, $opt, $ctl, $arg, $key)
	  if defined $optarg || defined $rest;
	return (1, $opt, $ctl, $arg, $key) if $arg eq "-"; # ??

	# Check for option or option list terminator.
	if ($arg eq $argend ||
	    $arg =~ /^$prefix.+/) {
	    # Push back.
	    unshift (@ARGV, $arg);
	    # Supply empty value.
	    $arg = '';
	}
    }

    elsif ( $type eq 'i'	# numeric/integer
            || $type eq 'I'	# numeric/integer w/ incr default
	    || $type eq 'o' ) { # dec/oct/hex/bin value

	my $o_valid =
	  $type eq 'o' ? "[-+]?[1-9][0-9]*|0x[0-9a-f]+|0b[01]+|0[0-7]*"
	    : "[-+]?[0-9]+";

	if ( $bundling && defined $rest
	     && $rest =~ /^($key_valid)($o_valid)(.*)$/si ) {
	    ($key, $arg, $rest) = ($1, $2, $+);
	    chop($key) if $key;
	    $arg = ($type eq 'o' && $arg =~ /^0/) ? oct($arg) : 0+$arg;
	    unshift (@ARGV, $starter.$rest) if defined $rest && $rest ne '';
	}
	elsif ( $arg =~ /^($o_valid)$/si ) {
	    $arg = ($type eq 'o' && $arg =~ /^0/) ? oct($arg) : 0+$arg;
	}
	else {
	    if ( defined $optarg || $mand ) {
		if ( $passthrough ) {
		    unshift (@ARGV, defined $rest ? $starter.$rest : $arg)
		      unless defined $optarg;
		    return (0);
		}
		warn ("Value \"", $arg, "\" invalid for option ",
		      $opt, " (",
		      $type eq 'o' ? "extended " : '',
		      "number expected)\n");
		$error++;
		# Push back.
		unshift (@ARGV, $starter.$rest) if defined $rest;
		return (1, undef);
	    }
	    else {
		# Push back.
		unshift (@ARGV, defined $rest ? $starter.$rest : $arg);
		if ( $type eq 'I' ) {
		    # Fake incremental type.
		    my @c = @$ctl;
		    $c[CTL_TYPE] = '+';
		    return (1, $opt, \@c, 1);
		}
		# Supply default value.
		$arg = defined($ctl->[CTL_DEFAULT]) ? $ctl->[CTL_DEFAULT] : 0;
	    }
	}
    }

    elsif ( $type eq 'f' ) { # real number, int is also ok
	# We require at least one digit before a point or 'e',
	# and at least one digit following the point and 'e'.
	# [-]NN[.NN][eNN]
	if ( $bundling && defined $rest &&
	     $rest =~ /^($key_valid)([-+]?[0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)?)(.*)$/s ) {
	    ($key, $arg, $rest) = ($1, $2, $+);
	    chop($key) if $key;
	    unshift (@ARGV, $starter.$rest) if defined $rest && $rest ne '';
	}
	elsif ( $arg !~ /^[-+]?[0-9.]+(\.[0-9]+)?([eE][-+]?[0-9]+)?$/ ) {
	    if ( defined $optarg || $mand ) {
		if ( $passthrough ) {
		    unshift (@ARGV, defined $rest ? $starter.$rest : $arg)
		      unless defined $optarg;
		    return (0);
		}
		warn ("Value \"", $arg, "\" invalid for option ",
		      $opt, " (real number expected)\n");
		$error++;
		# Push back.
		unshift (@ARGV, $starter.$rest) if defined $rest;
		return (1, undef);
	    }
	    else {
		# Push back.
		unshift (@ARGV, defined $rest ? $starter.$rest : $arg);
		# Supply default value.
		$arg = 0.0;
	    }
	}
    }
    else {
	die("Getopt::Long internal error (Can't happen)\n");
    }
    return (1, $opt, $ctl, $arg, $key);
}

# Getopt::Long Configuration.
sub Configure (@) {
    my (@options) = @_;

    my $prevconfig =
      [ $error, $debug, $major_version, $minor_version,
	$autoabbrev, $getopt_compat, $ignorecase, $bundling, $order,
	$gnu_compat, $passthrough, $genprefix, $auto_version, $auto_help ];

    if ( ref($options[0]) eq 'ARRAY' ) {
	( $error, $debug, $major_version, $minor_version,
	  $autoabbrev, $getopt_compat, $ignorecase, $bundling, $order,
	  $gnu_compat, $passthrough, $genprefix, $auto_version, $auto_help ) =
	    @{shift(@options)};
    }

    my $opt;
    foreach $opt ( @options ) {
	my $try = lc ($opt);
	my $action = 1;
	if ( $try =~ /^no_?(.*)$/s ) {
	    $action = 0;
	    $try = $+;
	}
	if ( ($try eq 'default' or $try eq 'defaults') && $action ) {
	    ConfigDefaults ();
	}
	elsif ( ($try eq 'posix_default' or $try eq 'posix_defaults') ) {
	    local $ENV{POSIXLY_CORRECT};
	    $ENV{POSIXLY_CORRECT} = 1 if $action;
	    ConfigDefaults ();
	}
	elsif ( $try eq 'auto_abbrev' or $try eq 'autoabbrev' ) {
	    $autoabbrev = $action;
	}
	elsif ( $try eq 'getopt_compat' ) {
	    $getopt_compat = $action;
	}
	elsif ( $try eq 'gnu_getopt' ) {
	    if ( $action ) {
		$gnu_compat = 1;
		$bundling = 1;
		$getopt_compat = 0;
		$order = $PERMUTE;
	    }
	}
	elsif ( $try eq 'gnu_compat' ) {
	    $gnu_compat = $action;
	}
	elsif ( $try =~ /^(auto_?)?version$/ ) {
	    $auto_version = $action;
	}
	elsif ( $try =~ /^(auto_?)?help$/ ) {
	    $auto_help = $action;
	}
	elsif ( $try eq 'ignorecase' or $try eq 'ignore_case' ) {
	    $ignorecase = $action;
	}
	elsif ( $try eq 'ignore_case_always' ) {
	    $ignorecase = $action ? 2 : 0;
	}
	elsif ( $try eq 'bundling' ) {
	    $bundling = $action;
	}
	elsif ( $try eq 'bundling_override' ) {
	    $bundling = $action ? 2 : 0;
	}
	elsif ( $try eq 'require_order' ) {
	    $order = $action ? $REQUIRE_ORDER : $PERMUTE;
	}
	elsif ( $try eq 'permute' ) {
	    $order = $action ? $PERMUTE : $REQUIRE_ORDER;
	}
	elsif ( $try eq 'pass_through' or $try eq 'passthrough' ) {
	    $passthrough = $action;
	}
	elsif ( $try =~ /^prefix=(.+)$/ && $action ) {
	    $genprefix = $1;
	    # Turn into regexp. Needs to be parenthesized!
	    $genprefix = "(" . quotemeta($genprefix) . ")";
	    eval { '' =~ /$genprefix/; };
	    die("Getopt::Long: invalid pattern \"$genprefix\"") if $@;
	}
	elsif ( $try =~ /^prefix_pattern=(.+)$/ && $action ) {
	    $genprefix = $1;
	    # Parenthesize if needed.
	    $genprefix = "(" . $genprefix . ")"
	      unless $genprefix =~ /^\(.*\)$/;
	    eval { '' =~ /$genprefix/; };
	    die("Getopt::Long: invalid pattern \"$genprefix\"") if $@;
	}
	elsif ( $try eq 'debug' ) {
	    $debug = $action;
	}
	else {
	    die("Getopt::Long: unknown config parameter \"$opt\"")
	}
    }
    $prevconfig;
}

# Deprecated name.
sub config (@) {
    Configure (@_);
}

# Issue a standard message for --version.
#
# The arguments are mostly the same as for Pod::Usage::pod2usage:
#
#  - a number (exit value)
#  - a string (lead in message)
#  - a hash with options. See Pod::Usage for details.
#
sub VersionMessage(@) {
    # Massage args.
    my $pa = setup_pa_args("version", @_);

    my $v = $main::VERSION;
    my $fh = $pa->{-output} ||
      ($pa->{-exitval} eq "NOEXIT" || $pa->{-exitval} < 2) ? \*STDOUT : \*STDERR;

    print $fh (defined($pa->{-message}) ? $pa->{-message} : (),
	       $0, defined $v ? " version $v" : (),
	       "\n",
	       "(", __PACKAGE__, "::", "GetOptions",
	       " version ",
	       defined($Getopt::Long::VERSION_STRING)
	         ? $Getopt::Long::VERSION_STRING : $VERSION, ";",
	       " Perl version ",
	       $] >= 5.006 ? sprintf("%vd", $^V) : $],
	       ")\n");
    exit($pa->{-exitval}) unless $pa->{-exitval} eq "NOEXIT";
}

# Issue a standard message for --help.
#
# The arguments are the same as for Pod::Usage::pod2usage:
#
#  - a number (exit value)
#  - a string (lead in message)
#  - a hash with options. See Pod::Usage for details.
#
sub HelpMessage(@) {
    eval {
	require Pod::Usage;
	import Pod::Usage;
	1;
    } || die("Cannot provide help: cannot load Pod::Usage\n");

    # Note that pod2usage will issue a warning if -exitval => NOEXIT.
    pod2usage(setup_pa_args("help", @_));

}

# Helper routine to set up a normalized hash ref to be used as
# argument to pod2usage.
sub setup_pa_args($@) {
    my $tag = shift;		# who's calling

    # If called by direct binding to an option, it will get the option
    # name and value as arguments. Remove these, if so.
    @_ = () if @_ == 2 && $_[0] eq $tag;

    my $pa;
    if ( @_ > 1 ) {
	$pa = { @_ };
    }
    else {
	$pa = shift || {};
    }

    # At this point, $pa can be a number (exit value), string
    # (message) or hash with options.

    if ( UNIVERSAL::isa($pa, 'HASH') ) {
	# Get rid of -msg vs. -message ambiguity.
	$pa->{-message} = $pa->{-msg};
	delete($pa->{-msg});
    }
    elsif ( $pa =~ /^-?\d+$/ ) {
	$pa = { -exitval => $pa };
    }
    else {
	$pa = { -message => $pa };
    }

    # These are _our_ defaults.
    $pa->{-verbose} = 0 unless exists($pa->{-verbose});
    $pa->{-exitval} = 0 unless exists($pa->{-exitval});
    $pa;
}

# Sneak way to know what version the user requested.
sub VERSION {
    $requested_version = $_[1];
    shift->SUPER::VERSION(@_);
}

1;

################ Documentation ################

