#!perl -w

# use strict fails
#Can't use string ("main::glob") as a symbol ref while "strict refs" in use at /usr/lib/perl5/5.005/File/DosGlob.pm line 191.

#
# Documentation at the __END__
#

package File::DosGlob;

our $VERSION = '1.00';
use strict;
use warnings;

sub doglob {
    my $cond = shift;
    my @retval = ();
    #print "doglob: ", join('|', @_), "\n";
  OUTER:
    for my $pat (@_) {
	my @matched = ();
	my @globdirs = ();
	my $head = '.';
	my $sepchr = '/';
        my $tail;
	next OUTER unless defined $pat and $pat ne '';
	# if arg is within quotes strip em and do no globbing
	if ($pat =~ /^"(.*)"\z/s) {
	    $pat = $1;
	    if ($cond eq 'd') { push(@retval, $pat) if -d $pat }
	    else              { push(@retval, $pat) if -e $pat }
	    next OUTER;
	}
	# wildcards with a drive prefix such as h:*.pm must be changed
	# to h:./*.pm to expand correctly
	if ($pat =~ m|^([A-Za-z]:)[^/\\]|s) {
	    substr($_,0,2) = $1 . "./";
	}
	if ($pat =~ m|^(.*)([\\/])([^\\/]*)\z|s) {
	    ($head, $sepchr, $tail) = ($1,$2,$3);
	    #print "div: |$head|$sepchr|$tail|\n";
	    push (@retval, $pat), next OUTER if $tail eq '';
	    if ($head =~ /[*?]/) {
		@globdirs = doglob('d', $head);
		push(@retval, doglob($cond, map {"$_$sepchr$tail"} @globdirs)),
		    next OUTER if @globdirs;
	    }
	    $head .= $sepchr if $head eq '' or $head =~ /^[A-Za-z]:\z/s;
	    $pat = $tail;
	}
	#
	# If file component has no wildcards, we can avoid opendir
	unless ($pat =~ /[*?]/) {
	    $head = '' if $head eq '.';
	    $head .= $sepchr unless $head eq '' or substr($head,-1) eq $sepchr;
	    $head .= $pat;
	    if ($cond eq 'd') { push(@retval,$head) if -d $head }
	    else              { push(@retval,$head) if -e $head }
	    next OUTER;
	}
	opendir(D, $head) or next OUTER;
	my @leaves = readdir D;
	closedir D;
	$head = '' if $head eq '.';
	$head .= $sepchr unless $head eq '' or substr($head,-1) eq $sepchr;

	# escape regex metachars but not glob chars
        $pat =~ s:([].+^\-\${}[|]):\\$1:g;
	# and convert DOS-style wildcards to regex
	$pat =~ s/\*/.*/g;
	$pat =~ s/\?/.?/g;

	#print "regex: '$pat', head: '$head'\n";
	my $matchsub = sub { $_[0] =~ m|^$pat\z|is };
      INNER:
	for my $e (@leaves) {
	    next INNER if $e eq '.' or $e eq '..';
	    next INNER if $cond eq 'd' and ! -d "$head$e";
	    push(@matched, "$head$e"), next INNER if &$matchsub($e);
	    #
	    # [DOS compatibility special case]
	    # Failed, add a trailing dot and try again, but only
	    # if name does not have a dot in it *and* pattern
	    # has a dot *and* name is shorter than 9 chars.
	    #
	    if (index($e,'.') == -1 and length($e) < 9
	        and index($pat,'\\.') != -1) {
		push(@matched, "$head$e"), next INNER if &$matchsub("$e.");
	    }
	}
	push @retval, @matched if @matched;
    }
    return @retval;
}


#
# Do DOS-like globbing on Mac OS 
#
sub doglob_Mac {
    my $cond = shift;
    my @retval = ();

	#print "doglob_Mac: ", join('|', @_), "\n";
  OUTER:
    for my $arg (@_) {
        local $_ = $arg;
	my @matched = ();
	my @globdirs = ();
	my $head = ':';
	my $not_esc_head = $head;
	my $sepchr = ':';	
	next OUTER unless defined $_ and $_ ne '';
	# if arg is within quotes strip em and do no globbing
	if (/^"(.*)"\z/s) {
	    $_ = $1;
		# $_ may contain escaped metachars '\*', '\?' and '\'
	        my $not_esc_arg = $_;
		$not_esc_arg =~ s/\\([*?\\])/$1/g;
	    if ($cond eq 'd') { push(@retval, $not_esc_arg) if -d $not_esc_arg }
	    else              { push(@retval, $not_esc_arg) if -e $not_esc_arg }
	    next OUTER;
	}

	if (m|^(.*?)(:+)([^:]*)\z|s) { # note: $1 is not greedy
	    my $tail;
	    ($head, $sepchr, $tail) = ($1,$2,$3);
	    #print "div: |$head|$sepchr|$tail|\n";
	    push (@retval, $_), next OUTER if $tail eq '';		
		#
		# $head may contain escaped metachars '\*' and '\?'
		
		my $tmp_head = $head;
		# if a '*' or '?' is preceded by an odd count of '\', temporary delete 
		# it (and its preceding backslashes), i.e. don't treat '\*' and '\?' as 
		# wildcards
		$tmp_head =~ s/(\\*)([*?])/$2 x ((length($1) + 1) % 2)/eg;
	
		if ($tmp_head =~ /[*?]/) { # if there are wildcards ...	
		@globdirs = doglob_Mac('d', $head);
		push(@retval, doglob_Mac($cond, map {"$_$sepchr$tail"} @globdirs)),
		    next OUTER if @globdirs;
	    }
		
		$head .= $sepchr; 
		$not_esc_head = $head;
		# unescape $head for file operations
		$not_esc_head =~ s/\\([*?\\])/$1/g;
	    $_ = $tail;
	}
	#
	# If file component has no wildcards, we can avoid opendir
	
	my $tmp_tail = $_;
	# if a '*' or '?' is preceded by an odd count of '\', temporary delete 
	# it (and its preceding backslashes), i.e. don't treat '\*' and '\?' as 
	# wildcards
	$tmp_tail =~ s/(\\*)([*?])/$2 x ((length($1) + 1) % 2)/eg;
	
	unless ($tmp_tail =~ /[*?]/) { # if there are wildcards ...
	    $not_esc_head = $head = '' if $head eq ':';
	    my $not_esc_tail = $_;
	    # unescape $head and $tail for file operations
	    $not_esc_tail =~ s/\\([*?\\])/$1/g;
	    $head .= $_;
		$not_esc_head .= $not_esc_tail;
	    if ($cond eq 'd') { push(@retval,$head) if -d $not_esc_head }
	    else              { push(@retval,$head) if -e $not_esc_head }
	    next OUTER;
	}
	#print "opendir($not_esc_head)\n";
	opendir(D, $not_esc_head) or next OUTER;
	my @leaves = readdir D;
	closedir D;

	# escape regex metachars but not '\' and glob chars '*', '?'
	$_ =~ s:([].+^\-\${}[|]):\\$1:g;
	# and convert DOS-style wildcards to regex,
	# but only if they are not escaped
	$_ =~ s/(\\*)([*?])/$1 . ('.' x ((length($1) + 1) % 2)) . $2/eg;

	#print "regex: '$_', head: '$head', unescaped head: '$not_esc_head'\n";
	my $matchsub = eval 'sub { $_[0] =~ m|^' . $_ . '\\z|ios }';
	warn($@), next OUTER if $@;
      INNER:
	for my $e (@leaves) {
	    next INNER if $e eq '.' or $e eq '..';
	    next INNER if $cond eq 'd' and ! -d "$not_esc_head$e";
		
		if (&$matchsub($e)) {
			my $leave = (($not_esc_head eq ':') && (-f "$not_esc_head$e")) ? 
		            	"$e" : "$not_esc_head$e";
			#
			# On Mac OS, the two glob metachars '*' and '?' and the escape 
			# char '\' are valid characters for file and directory names. 
			# We have to escape and treat them specially.
			$leave =~ s|([*?\\])|\\$1|g;		
			push(@matched, $leave);
			next INNER;
		}
	}
	push @retval, @matched if @matched;
    }
    return @retval;
}

#
# _expand_volume() will only be used on Mac OS (Classic): 
# Takes an array of original patterns as argument and returns an array of  
# possibly modified patterns. Each original pattern is processed like 
# that:
# + If there's a volume name in the pattern, we push a separate pattern 
#   for each mounted volume that matches (with '*', '?' and '\' escaped).  
# + If there's no volume name in the original pattern, it is pushed 
#   unchanged. 
# Note that the returned array of patterns may be empty.
#  
sub _expand_volume {
	
	require MacPerl; # to be verbose
	
	my @pat = @_;
	my @new_pat = ();
	my @FSSpec_Vols = MacPerl::Volumes();
	my @mounted_volumes = ();

	foreach my $spec_vol (@FSSpec_Vols) {		
		# push all mounted volumes into array
     	push @mounted_volumes, MacPerl::MakePath($spec_vol);
	}
	#print "mounted volumes: |@mounted_volumes|\n";
	
	while (@pat) {
		my $pat = shift @pat;	
		if ($pat =~ /^([^:]+:)(.*)\z/) { # match a volume name?
			my $vol_pat = $1;
			my $tail = $2;
			#
			# escape regex metachars but not '\' and glob chars '*', '?'
			$vol_pat =~ s:([].+^\-\${}[|]):\\$1:g;
			# and convert DOS-style wildcards to regex,
			# but only if they are not escaped
			$vol_pat =~ s/(\\*)([*?])/$1 . ('.' x ((length($1) + 1) % 2)) . $2/eg;
			#print "volume regex: '$vol_pat' \n";
				
			foreach my $volume (@mounted_volumes) {
				if ($volume =~ m|^$vol_pat\z|ios) {
					#
					# On Mac OS, the two glob metachars '*' and '?' and the  
					# escape char '\' are valid characters for volume names. 
					# We have to escape and treat them specially.
					$volume =~ s|([*?\\])|\\$1|g;
					push @new_pat, $volume . $tail;
				}
			}			
		} else { # no volume name in pattern, push original pattern
			push @new_pat, $pat;
		}
	}
	return @new_pat;
}


#
# _preprocess_pattern() will only be used on Mac OS (Classic): 
# Resolves any updirs in the pattern. Removes a single trailing colon 
# from the pattern, unless it's a volume name pattern like "*HD:"
#
sub _preprocess_pattern {
	my @pat = @_;
	
	foreach my $p (@pat) {
		my $proceed;
		# resolve any updirs, e.g. "*HD:t?p::a*" -> "*HD:a*"
		do {
			$proceed = ($p =~ s/^(.*):[^:]+::(.*?)\z/$1:$2/);  
		} while ($proceed);
		# remove a single trailing colon, e.g. ":*:" -> ":*"
		$p =~ s/:([^:]+):\z/:$1/;
	}
	return @pat;
}
		
		
#
# _un_escape() will only be used on Mac OS (Classic):
# Unescapes a list of arguments which may contain escaped 
# metachars '*', '?' and '\'.
#
sub _un_escape {
	foreach (@_) {
		s/\\([*?\\])/$1/g;
	}
	return @_;
}

#
# this can be used to override CORE::glob in a specific
# package by saying C<use File::DosGlob 'glob';> in that
# namespace.
#

# context (keyed by second cxix arg provided by core)
my %iter;
my %entries;

sub glob {
    my($pat,$cxix) = @_;
    my @pat;

    # glob without args defaults to $_
    $pat = $_ unless defined $pat;

    # extract patterns
    if ($pat =~ /\s/) {
	require Text::ParseWords;
	@pat = Text::ParseWords::parse_line('\s+',0,$pat);
    }
    else {
	push @pat, $pat;
    }

    # Mike Mestnik: made to do abc{1,2,3} == abc1 abc2 abc3.
    #   abc3 will be the original {3} (and drop the {}).
    #   abc1 abc2 will be put in @appendpat.
    # This was just the esiest way, not nearly the best.
    REHASH: {
	my @appendpat = ();
	for (@pat) {
	    # There must be a "," I.E. abc{efg} is not what we want.
	    while ( /^(.*)(?<!\\)\{(.*?)(?<!\\)\,.*?(?<!\\)\}(.*)$/ ) {
		my ($start, $match, $end) = ($1, $2, $3);
		#print "Got: \n\t$start\n\t$match\n\t$end\n";
		my $tmp = "$start$match$end";
		while ( $tmp =~ s/^(.*?)(?<!\\)\{(?:.*(?<!\\)\,)?(.*\Q$match\E.*?)(?:(?<!\\)\,.*)?(?<!\\)\}(.*)$/$1$2$3/ ) {
		    #print "Striped: $tmp\n";
		    #  these expanshions will be preformed by the original,
		    #  when we call REHASH.
		}
		push @appendpat, ("$tmp");
		s/^\Q$start\E(?<!\\)\{\Q$match\E(?<!\\)\,/$start\{/;
		if ( /^\Q$start\E(?<!\\)\{(?!.*?(?<!\\)\,.*?\Q$end\E$)(.*)(?<!\\)\}\Q$end\E$/ ) {
		    $match = $1;
		    #print "GOT: \n\t$start\n\t$match\n\t$end\n\n";
		    $_ = "$start$match$end";
		}
	    }
	    #print "Sould have "GOT" vs "Got"!\n";
		#FIXME: There should be checking for this.
		#  How or what should be done about failure is beond me.
	}
	if ( $#appendpat != -1
		) {
	    #print "LOOP\n";
	    #FIXME: Max loop, no way! :")
	    for ( @appendpat ) {
	        push @pat, $_;
	    }
	    goto REHASH;
	}
    }
    for ( @pat ) {
	s/\\{/{/g;
	s/\\}/}/g;
	s/\\,/,/g;
    }
    #print join ("\n", @pat). "\n";
 
    # assume global context if not provided one
    $cxix = '_G_' unless defined $cxix;
    $iter{$cxix} = 0 unless exists $iter{$cxix};

    # if we're just beginning, do it all first
    if ($iter{$cxix} == 0) {
	if ($^O eq 'MacOS') {
		# first, take care of updirs and trailing colons
		@pat = _preprocess_pattern(@pat);
		# expand volume names
		@pat = _expand_volume(@pat);
		$entries{$cxix} = (@pat) ? [_un_escape( doglob_Mac(1,@pat) )] : [()];
	} else {
		$entries{$cxix} = [doglob(1,@pat)];
    }
	}

    # chuck it all out, quick or slow
    if (wantarray) {
	delete $iter{$cxix};
	return @{delete $entries{$cxix}};
    }
    else {
	if ($iter{$cxix} = scalar @{$entries{$cxix}}) {
	    return shift @{$entries{$cxix}};
	}
	else {
	    # return undef for EOL
	    delete $iter{$cxix};
	    delete $entries{$cxix};
	    return undef;
	}
    }
}

{
    no strict 'refs';

    sub import {
    my $pkg = shift;
    return unless @_;
    my $sym = shift;
    my $callpkg = ($sym =~ s/^GLOBAL_//s ? 'CORE::GLOBAL' : caller(0));
    *{$callpkg.'::'.$sym} = \&{$pkg.'::'.$sym} if $sym eq 'glob';
    }
}
1;

__END__

