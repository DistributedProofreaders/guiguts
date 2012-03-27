package Text::Reform;

use strict; use vars qw($VERSION @ISA @EXPORT @EXPORT_OK); use Carp;
use 5.005;
$VERSION = '1.11';

require Exporter;

@ISA = qw(Exporter);
@EXPORT = qw( form );
@EXPORT_OK = qw( tag break_with break_at break_wrap break_TeX debug );

my @bspecials = qw( [ | ] );
my @lspecials = qw( < ^ > );
my $ljustified = '[<]{2,}[>]{2,}';
my $bjustified = '[[]{2,}[]]{2,}';
my $bsingle    = '~+';
my @specials = (@bspecials, @lspecials);
my $fixed_fieldpat = join('|', ($ljustified, $bjustified,
				$bsingle,
				map { "\\$_\{2,}" } @specials));
my ($lfieldmark, $bfieldmark, $fieldmark, $fieldpat, $decimal);
my $emptyref = '';

sub import
{
	use POSIX qw( localeconv );
	$decimal = localeconv()->{decimal_point} || '.';

	my $lnumerical = '[>]+(?:'.quotemeta($decimal).'[<]{1,})';
	my $bnumerical = '[]]+(?:'.quotemeta($decimal).'[[]{1,})';

	$fieldpat = join('|', ($lnumerical, $bnumerical,$fixed_fieldpat));

	$lfieldmark = join '|', ($lnumerical, $ljustified, map { "\\$_\{2}" } @lspecials);
	$bfieldmark = join '|', ($bnumerical, $bjustified, $bsingle, map { "\\$_\{2}" } @bspecials);
	$fieldmark  = join '|', ($lnumerical, $bnumerical,
				 $bsingle,
				 $ljustified, $bjustified,
				 $lfieldmark, $bfieldmark);

	Text::Reform->export_to_level(1, @_);
}

sub carpfirst {
	our %carped;
	my ($msg) = @_;
	return if $carped{$msg}++;
	carp $msg;
}

###### USEFUL TOOLS ######################################

#===== form =============================================#

sub BAD_CONFIG { 'Configuration hash not allowed between format and data' }

sub break_with
{
	my $hyphen = $_[0];
	my $hylen = length($hyphen);
	my @ret;
	sub
	{
		if ($_[2]<=$hylen)
		{
			@ret = (substr($_[0],0,1), substr($_[0],1))
		}
		else
		{
			@ret = (substr($_[0],0,$_[1]-$hylen),
				substr($_[0],$_[1]-$hylen))
		}
		if ($ret[0] =~ /\A\s*\Z/) { return ("",$_[0]); }
		else { return ($ret[0].$hyphen,$ret[1]); }
	}

}

sub break_at {
	my $hyphen = $_[0];
	my $hylen = length($hyphen);
	my @ret;
	sub
	{
		my $max = $_[2]-$hylen;
		if ($max <= 0) {
			@ret = (substr($_[0],0,1), substr($_[0],1))
		}
		elsif ($_[0] =~ /(.{1,$max}$hyphen)(.*)/s) {
			@ret = ($1,$2);
		}
		elsif (length($_[0])>$_[2]) {
			@ret = (substr($_[0],0,$_[1]-$hylen).$hyphen,
				substr($_[0],$_[1]-$hylen))
		}
		else {
			@ret = ("",$_[0]);
		}
		if ($ret[0] =~ /\A\s*\Z/) { return ("",$_[0]); }
		else { return @ret; }
	}

}

sub break_wrap
{
	return \&break_wrap unless @_;
	my ($text, $reqlen, $fldlen) = @_;
	if ($reqlen==$fldlen) { $text =~ m/\A(\s*\S*)(.*)/s }
	else                  { ("", $text) }
}

my %hyp;
sub break_TeX
{
	my $file = $_[0] || "";

	croak "Can't find TeX::Hypen module"
		unless require "TeX/Hyphen.pm";

	$hyp{$file} = TeX::Hyphen->new($file||undef)
			|| croak "Can't open hyphenation file $file"
		unless $hyp{$file};

	return sub {
		for (reverse $hyp{$file}->hyphenate($_[0])) {
			if ($_ < $_[1]) {
				return (substr($_[0],0,$_).'-',
					substr($_[0],$_) );
			}
		}
		return ("",$_[0]);
	}
}

my $debug = 0;
sub _debug { print STDERR @_, "\n" if $debug }
sub debug { $debug = 1; }

sub notempty
{
	my $ne = ${$_[0]} =~ /\S/;
	_debug("\tnotempty('${$_[0]}') = $ne\n");
	return $ne;
}

sub replace($$$$)   # ($fmt, $len, $argref, $config)
{
	my $ref = $_[2];
	my $text = '';
	my $rem = $_[1];
	my $config = $_[3];
	my $filled = 0;

	if ($config->{fill}) { $$ref =~ s/\A\s*// }
	else		     { $$ref =~ s/\A[ \t]*// }

	my $fmtnum = length $_[0];

	if ($$ref =~ /\S/ && $fmtnum>2)
	{
	NUMERICAL:{
		use POSIX qw( strtod );
		my ($ilen,$dlen) = map {length} $_[0] =~ m/([]>]+)\Q$decimal\E([[<]+)/;
		my ($num,$unconsumed) = strtod($$ref);
		if ($unconsumed == length $$ref)
		{
			$$ref =~ s/\s*\S*//;
			redo NUMERICAL if $config->{numeric} =~ m/\bSkipNaN\b/i
				       && $$ref =~ m/\S/;
			$text = '?' x $ilen . $decimal . '?' x $dlen;
			$rem = 0;
			return $text;
		}
		my $formatted = sprintf "%$fmtnum.${dlen}f", $num;
		$text = (length $formatted > $fmtnum)
			? '#' x $ilen . $decimal . '#' x $dlen
			: $formatted;
		$text =~ s/(\Q$decimal\E\d+?)(0+)$/$1 . " " x length $2/e
			unless $config->{numeric} =~ m/\bAllPlaces\b/i
			    || $num =~ /\Q$decimal\E\d\d{$dlen,}$/;
		if ($unconsumed)
		{
			if ($unconsumed == length $$ref)
				{ $$ref =~ s/\A.[^0-9.+-]*// }
			else
				{ substr($$ref,0,-$unconsumed) = ""}
		}
		else            { $$ref = "" }
		$rem = 0;
	    }
	}
	else
	{
		while ($$ref =~ /\S/)
		{
			if (!$config->{fill} && $$ref=~s/\A[ \t]*\n//)
				{ $filled = 2; last }
			last unless $$ref =~ /\A(\s*)(\S+)(.*)\z/s;
			my ($ws, $word, $extra) = ($1,$2,$3);
			my $nonnl = $ws =~ /[^\n]/;
			$ws =~ s/\n/$nonnl? "" : " "/ge if $config->{fill};
			my $lead = ($config->{squeeze} ? ($ws ? " " : "") : $ws);
			my $match = $lead . $word;
			_debug "Extracted [$match]";
			last if $text && $match =~ /\n/;
			my $len1 = length($match);
			if ($len1 <= $rem)
			{
				_debug "Accepted [$match]";
				$text .= $match;
				$rem  -= $len1;
				$$ref = $extra;
			}
			else
			{
				_debug "Need to break [$match]";
				# was: if ($len1 > $_[1] and $rem-length($lead)>$config->{minbreak})
				if ($rem-length($lead)>$config->{minbreak})
				{
					_debug "Trying to break '$match'";
					my ($broken,$left) =
						$config->{break}->($match,$rem,$_[1]);	
					$text .= $broken;
					_debug "Broke as: [$broken][$left]";
					$$ref = $left.$extra;
					$rem -= length $broken;
				}
				last;
			}
		}
		continue { $filled=1 }
	}

	if (!$filled && $rem>0 && $$ref=~/\S/ && length $text == 0)
	{
		$$ref =~ s/^\s*(.{1,$rem})//;
		$text = $1;
		$rem -= length $text;
	}

	if ( $text=~/ / && $_[0] eq 'J' && $$ref=~/\S/ && $filled!=2 ) {
							# FULLY JUSTIFIED
		$text = reverse $text;
		$text =~ s/( +)/($rem-->0?" ":"").$1/ge while $rem>0;
		$text = reverse $text;
	}
	elsif ( $_[0] =~ /\>|\]/ ) {			# RIGHT JUSTIFIED
		substr($text,0,0) =
			substr($config->{filler}{left} x $rem, -$rem)
				if $rem > 0;
	}
	elsif ( $_[0] =~ /\^|\|/ ) {			# CENTRE JUSTIFIED
	    if ($rem>0) {
		my $halfrem = int($rem/2);
		substr($text,0,0) =
			substr($config->{filler}{left}x$halfrem, -$halfrem);
		$halfrem = $rem-$halfrem;
		$text .= substr($config->{filler}{right}x$halfrem, 0, $halfrem);
	    }
	}
	else {						# LEFT JUSTIFIED
		$text .= substr($config->{filler}{right}x$rem, 0, $rem)
			if $rem > 0;
	}

	return $text;
}

my %std_config =
(
	header	   => sub{""},
	footer	   => sub{""},
	pagefeed   => sub{""},
	pagelen	   => 0,
	pagenum	   => undef,
	pagewidth  => 72,
	break	   => break_with('-'),
	minbreak   => 2,
	squeeze	   => 0,
	filler     => {left=>' ', right=>' '},
	interleave => 0,
	numeric	   => "",
	_used      => 1,
);

sub lcr {
	my ($data, $pagewidth, $header) = @_;
	$data->{width}  ||= $pagewidth;
	$data->{left}   ||= "";
	$data->{centre} ||= $data->{center}||"";
	$data->{right}  ||= "";
	return sub {
		my @l = split "\n", (ref $data->{left} eq 'CODE'
				? $data->{left}->(@_) : $data->{left}), -1;
		my @c = split "\n", (ref $data->{centre} eq 'CODE'
				? $data->{centre}->(@_) : $data->{centre}), -1;
		my @r = split "\n", (ref $data->{right} eq 'CODE'
				? $data->{right}->(@_) : $data->{right}), -1;
		my $text = "";
		while (@l||@c||@r) {
			my $l = @l ? shift(@l) : "";
			my $c = @c ? shift(@c) : "";
			my $r = @r ? shift(@r) : "";
			my $gap = int(($data->{width}-length($c))/2-length($l));
			if ($gap < 0) {
				$gap = 0;
				carpfirst "\nWarning: $header is wider than specified page width ($data->{width} chars)" if $^W;
			}
			$text .= $l . " " x $gap
			       . $c . " " x ($data->{width}-length($l)-length($c)-$gap-length($r))
			       . $r
			       . "\n";
		}
		return $text;
	}
}

sub fix_config(\%)
{
	my ($config) = @_;
	if (ref $config->{header} eq 'HASH') {
		$config->{header} =
			lcr $config->{header}, $config->{pagewidth}, 'header';
	}
	elsif (ref $config->{header} eq 'CODE') {
		my $tmp = $config->{header};
		$config->{header} = sub {
			my $header = &$tmp;
			return (ref $header eq 'HASH')
				? lcr($header,$config->{pagewidth},'header')->()
				: $header;
		}
	}
	else {
		my $tmp = $config->{header};
		$config->{header} = sub { $tmp }
	}
	if (ref $config->{footer} eq 'HASH') {
		$config->{footer} =
			lcr $config->{footer}, $config->{pagewidth}, 'footer';
	}
	elsif (ref $config->{footer} eq 'CODE') {
		my $tmp = $config->{footer};
		$config->{footer} = sub {
			my $footer = &$tmp;
			return (ref $footer eq 'HASH')
				? lcr($footer,$config->{pagewidth},'footer')->()
				: $footer;
		}
	}
	else {
		my $tmp = $config->{footer};
		$config->{footer} = sub { $tmp }
	}
	unless (ref $config->{pagefeed} eq 'CODE')
		{ my $tmp = $config->{pagefeed}; $config->{pagefeed} = sub { $tmp } }
	unless (ref $config->{break} eq 'CODE')
		{ $config->{break} = break_at($config->{break}) }
	if (defined $config->{pagenum} && ref $config->{pagenum} ne 'SCALAR') 
		{ my $tmp = $config->{pagenum}+0; $config->{pagenum} = \$tmp }
	unless (ref $config->{filler} eq 'HASH') {
		$config->{filler} = { left  => "$config->{filler}",
			  	      right => "$config->{filler}" }
	}
}

sub FormOpt::DESTROY
{
	print STDERR "\nWarning: lexical &form configuration at $std_config{_line} was never used.\n"
		if $^W && !$std_config{_used};
	%std_config = %{$std_config{_prev}};
}

sub form
{
	our %carped;
	local %carped;
	my $config = {%std_config};
	my $startidx = 0;
	if (@_ && ref($_[0]) eq 'HASH')		# RESETTING CONFIG
	{
		if (@_ > 1)			# TEMPORARY RESET
		{
			$config = {%$config, %{$_[$startidx++]}};
			fix_config(%$config);
			$startidx = 1;
		}
		elsif (defined wantarray)	# CONTEXT BEING CAPTURED
		{
			$_[0]->{_prev} = { %std_config };
			$_[0]->{_used} = 0;
			$_[0]->{_line} = join " line ", (caller)[1..2];;
			%{$_[0]} = %std_config = (%std_config, %{$_[0]});
			fix_config(%std_config);
			return bless $_[0], 'FormOpt';
		}
		else				# PERMANENT RESET
		{
			$_[0]->{_used} = 1;
			$_[0]->{_line} = join " line ", (caller)[1..2];;
			%std_config = (%std_config, %{$_[0]});
			fix_config(%std_config);
			return;
		}
	}
	$config->{pagenum} = do{\(my $tmp=1)}
		unless defined $config->{pagenum};

	$std_config{_used}++;
	my @ref = map { ref } @_;
	my @orig = @_;
	my $caller = caller;
	no strict;

	for (my $nextarg=0; $nextarg<@_; $nextarg++)
	{
		my $next = $_[$nextarg];
		if (!defined $next) {
			my $tmp = "";
			splice @_, $nextarg, 1, \$tmp;
		}
		elsif ($ref[$nextarg] eq 'ARRAY') {
			splice @_, $nextarg, 1, \join("\n", @$next)
		}
		elsif ($ref[$nextarg] eq 'HASH' && $next->{cols} ) {
			croak "Missing 'from' data for 'cols' option"
				unless $next->{from};
			croak "Can't mix other options with 'cols' option"
				if keys %$next > 2;
			my ($cols, $data) = @{$next}{'cols','from'};
			croak "Invalid 'cols' option.\nExpected reference to array of column specifiers but found " . (ref($cols)||"'$cols'")
				unless ref $cols eq 'ARRAY';
			croak "Invalid 'from' data for 'cols' option.\nExpected reference to array of hashes or arrays but found " . (ref($data)||"'$data'")
				unless ref $data eq 'ARRAY';
			splice @_, $nextarg, 2, columns(@$cols,@$data);
			splice @ref, $nextarg, 2, ('ARRAY')x@$cols;
			$nextarg--;
		}
		elsif (!defined eval { local $SIG{__DIE__};
				       $_[$nextarg] = $next;
				       _debug "writeable: [$_[$nextarg]]";
				       1})
		{
		        _debug "unwriteable: [$_[$nextarg]]";
			my $arg = $_[$nextarg];
			splice @_, $nextarg, 1, \$arg;
		}
		elsif (!$ref[$nextarg]) {
			splice @_, $nextarg, 1, \$_[$nextarg];
		}
                elsif ($ref[$nextarg] ne 'HASH' and $ref[$nextarg] ne 'SCALAR')
                {
			splice @_, $nextarg, 1, \"$next";
                }
	}

	my $header = $config->{header}->(${$config->{pagenum}});
	$header.="\n" if $header && substr($header,-1,1) ne "\n";

	my $footer = $config->{footer}->(${$config->{pagenum}});
	$footer.="\n" if $footer && substr($footer,-1,1) ne "\n";

	my $prevfooter = $footer;

	my $linecount = $header=~tr/\n/\n/ + $footer=~tr/\n/\n/;
	my $hfcount = $linecount;

	my $text = $header;
	my @format_stack;

	LINE: while ($startidx < @_ || @format_stack)
	{
		if (($ref[$startidx]||'') eq 'HASH')
		{
			$config = {%$config, %{$_[$startidx++]}};
			fix_config(%$config);
			next;
		}
		unless (@format_stack) {
			@format_stack = $config->{interleave}
				? map "$_\n", split /\n/, ${$_[$startidx++]}||""
				: ${$_[$startidx++]}||"";
		}
		my $format = shift @format_stack;
		_debug("format: [$format]");
	
		my @parts = split /(\n|(?:\\.)+|$fieldpat)/, $format;
		push @parts, "\n" unless @parts && $parts[-1] eq "\n";
		my $fieldcount = 0;
		my $filled = 0;
		my $firstline = 1;
		while (!$filled)
		{
			my $nextarg = $startidx;
			my @data;
			foreach my $part ( @parts )
			{
				if ($part =~ /\A(?:\\.)+/)
				{
					_debug("esc literal: [$part]");
					my $tmp = $part;
					$tmp =~ s/\\(.)/$1/g;
					$text .= $tmp;
				}
				elsif ($part =~ /($lfieldmark)/)
				{
					if ($firstline)
					{
						$fieldcount++;
						if ($nextarg > $#_)
							{ push @_,\$emptyref; push @ref, '' }
						my $type = $1;
						$type = 'J' if $part =~ /$ljustified/;
						croak BAD_CONFIG if ($ref[$startidx] eq 'HASH');
						_debug("once field: [$part]");
						_debug("data was: [${$_[$nextarg]}]");
						$text .= replace($type,length($part),$_[$nextarg],$config);
						_debug("data now: [${$_[$nextarg]}]");
					}
					else
					{
						$text .= substr($config->{filler}{left} x length($part), -length($part));
						_debug("missing once field: [$part]");
					}
					$nextarg++;
				}
				elsif ($part =~ /($fieldmark)/ and substr($part,0,2) ne '~~')
				{
					$fieldcount++ if $firstline;
					if ($nextarg > $#_)
						{ push @_,\$emptyref; push @ref, '' }
					my $type = $1;
					$type = 'J' if $part =~ /$bjustified/;
					croak BAD_CONFIG if ($ref[$startidx] eq 'HASH');
					_debug("multi field: [$part]");
					_debug("data was: [${$_[$nextarg]}]");
					$text .= replace($type,length($part),$_[$nextarg],$config);
					_debug("data now: [${$_[$nextarg]}]");
					push @data, $_[$nextarg];
					$nextarg++;
				}
				else
				{
					_debug("literal: [$part]");
					my $tmp = $part;
					$tmp =~ s/\0(\0*)/$1/g;
					$text .= $tmp;
					if ($part eq "\n")
					{
						$linecount++;
						if ($config->{pagelen} && $linecount>=$config->{pagelen})
						{
							_debug("\tejecting page:  $config->{pagenum}");
							carpfirst "\nWarning: could not format page ${$config->{pagenum}} within specified page length"
								if $^W && $config->{pagelen} && $linecount > $config->{pagelen};
							${$config->{pagenum}}++;
							my $pagefeed = $config->{pagefeed}->(${$config->{pagenum}});
							$header = $config->{header}->(${$config->{pagenum}});
							$header.="\n" if $header && substr($header,-1,1) ne "\n";
							$text .= $footer
							       . $pagefeed
							       . $header;
							$prevfooter = $footer;
							$footer = $config->{footer}->(${$config->{pagenum}});
							$footer.="\n" if $footer && substr($footer,-1,1) ne "\n";
							$linecount = $hfcount =
								$header=~tr/\n/\n/ + $footer=~tr/\n/\n/;
							$header = $pagefeed
								. $header;
						}
					}
				}
				_debug("\tnextarg now:  $nextarg");
				_debug("\tstartidx now: $startidx");
			}
			$firstline = 0;
			$filled = ! grep { notempty $_ } @data;
		}
		$startidx += $fieldcount;
	}

	# ADJUST FINAL PAGE HEADER OR FOOTER AS REQUIRED
	if ($hfcount && $linecount == $hfcount)		# UNNEEDED HEADER
	{
		$text =~ s/\Q$header\E\Z//;
	}
	elsif ($linecount && $config->{pagelen})	# MISSING FOOTER
	{
		$text .= "\n" x ($config->{pagelen}-$linecount)
		       . $footer;
		$prevfooter = $footer;
	}

	# REPLACE LAST FOOTER
	
	if ($prevfooter) {
		my $lastfooter = $config->{footer}->(${$config->{pagenum}},1);
		$lastfooter.="\n"
			if $lastfooter && substr($lastfooter,-1,1) ne "\n";
		my $footerdiff = ($lastfooter =~ tr/\n/\n/)
			       - ($prevfooter =~ tr/\n/\n/);
		# Enough space to squeeze longer final footer in?
		my $tail = '^[^\S\n]*\n' x $footerdiff;
		if ($footerdiff > 0 && $text =~ /($tail\Q$prevfooter\E)\Z/m) {
			$prevfooter = $1;
			$footerdiff = 0;
		}
		# Apparently, not, so create an extra (empty) page for it
		if ($footerdiff > 0) {
			${$config->{pagenum}}++;
			my $lastheader = $config->{header}->(${$config->{pagenum}});
			$lastheader.="\n"
				if $lastheader && substr($lastheader,-1,1) ne "\n";
			$lastfooter = $config->{footer}->(${$config->{pagenum}},1);
			$lastfooter.="\n"
				if $lastfooter && substr($lastfooter,-1,1) ne "\n";

			$text .= $lastheader
			       . ("\n" x ( $config->{pagelen}
					- ($lastheader =~ tr/\n/\n/)
				        - ($lastfooter =~ tr/\n/\n/)
					)
				 )
			       . $lastfooter;
		}
		else {
                        $lastfooter = ("\n"x-$footerdiff).$lastfooter;
                        substr($text, -length($prevfooter)) = $lastfooter;
		}
	}

        # RESTORE ARG LIST
        for my $i (0..$#orig)
        {
                if ($ref[$i] eq 'ARRAY')
                        { eval { @{$orig[$i]} = map "$_\n", split /\n/, ${$_[$i]} } }
                elsif (!$ref[$i])
                        { eval { _debug("restoring $i (".$_[$i].") to " .
                                 defined($orig[$i]) ? $orig[$i] : "<undef>");
                                 ${$_[$i]} = $orig[$i] } }
        }

        ${$config->{pagenum}}++;
        $text =~ s/[ ]+$//gm if $config->{trim};
        return $text unless wantarray;
        return map "$_\n", split /\n/, $text;
}


#==== columns ========================================#

sub columns {
        my @cols;
        my (@fullres, @res);
        while (@_) {
                my $arg = shift @_;
                my $type = ref $arg;
                if ($type eq 'HASH') {
                        push @{$res[$_]}, $arg->{$cols[$_]} for 0..$#cols;
                }
                elsif ($type eq 'ARRAY') {
                        push @{$res[$_]}, $arg->[$cols[$_]] for 0..$#cols;
                }
                else {
                        if (@res) {
                                push @fullres, @res;
                                @res = @cols = ();
                        }
                        push @cols, $arg;
                }
        }
        return @fullres, @res;
}


#==== tag ============================================#

sub invert($)
{
        my $inversion = reverse $_[0];
        $inversion =~ tr/{[<(/}]>)/;
        return $inversion;
}

sub tag         # ($tag, $text; $opt_endtag)
{
        my ($tagleader,$tagindent,$ldelim,$tag,$tagargs,$tagtrailer) = 
                ( $_[0] =~ /\A((?:[ \t]*\n)*)([ \t]*)(\W*)(\w+)(.*?)(\s*)\Z/ );

        $ldelim = '<' unless $ldelim;
        $tagtrailer =~ s/([ \t]*)\Z//;
        my $textindent = $1||"";

        my $rdelim = invert $ldelim;

        my $i;
        for ($i = -1; -1-$i < length $rdelim && -1-$i < length $tagargs; $i--)
        {
                last unless substr($tagargs,$i,1) eq substr($rdelim,$i,1);
        }
        if ($i < -1)
        {
                $i++;
                $tagargs = substr($tagargs,0,$i);
                $rdelim = substr($rdelim,$i);
        }

        my $endtag = $_[2] || "$ldelim/$tag$rdelim";

        return "$tagleader$tagindent$ldelim$tag$tagargs$rdelim$tagtrailer".
                join("\n",map { "$tagindent$textindent$_" } split /\n/, $_[1]).
                "$tagtrailer$tagindent$endtag$tagleader";

}


1;

__END__

