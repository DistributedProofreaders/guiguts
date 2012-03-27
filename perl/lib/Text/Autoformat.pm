package Text::Autoformat;

use strict; use vars qw($VERSION @ISA @EXPORT @EXPORT_OK); use Carp;
use 5.005;
$VERSION = '1.12';

require Exporter;

use Text::Reform qw( form tag break_at break_with break_wrap break_TeX );

@ISA = qw(Exporter);
@EXPORT = qw( autoformat );
@EXPORT_OK =
	qw( form tag break_at break_with break_wrap break_TeX ignore_headers );


my %ignore = map {$_=>1} qw {
	a an at as and are
	but by 
	ere
	for from
	in into is
	of on onto or over
	per
	the to that than
	until unto upon
	via
	with while whilst within without
};

my @entities = qw {
	&Aacute;   &aacute;      &Acirc;    &acirc;        &AElig;    &aelig;
	&Agrave;   &agrave;      &Alpha;    &alpha;        &Atilde;   &atilde;
	&Auml;     &auml;        &Beta;     &beta;         &Ccedil;   &ccedil;
	&Chi;      &chi;         &Delta;    &delta;        &Eacute;   &eacute;
	&Ecirc;    &ecirc;       &Egrave;   &egrave;       &Epsilon;  &epsilon;
	&Eta;      &eta;         &ETH;      &eth;          &Euml;     &euml;
	&Gamma;    &gamma;       &Iacute;   &iacute;       &Icirc;    &icirc;
	&Igrave;   &igrave;      &Iota;     &iota;         &Iuml;     &iuml;
	&Kappa;    &kappa;       &Lambda;   &lambda;       &Mu;       &mu;
	&Ntilde;   &ntilde;      &Nu;       &nu;           &Oacute;   &oacute;
	&Ocirc;    &ocirc;       &OElig;    &oelig;        &Ograve;   &ograve;
	&Omega;    &omega;       &Omicron;  &omicron;      &Otilde;   &otilde;
	&Ouml;     &ouml;        &Phi;      &phi;          &Pi;       &pi;
	&Prime;    &prime;       &Psi;      &psi;          &Rho;      &rho;
	&Scaron;   &scaron;      &Sigma;    &sigma;        &Tau;      &tau;
	&Theta;    &theta;       &THORN;    &thorn;        &Uacute;   &uacute;
	&Ucirc;    &ucirc;       &Ugrave;   &ugrave;       &Upsilon;  &upsilon;
	&Uuml;     &uuml;        &Xi;       &xi;           &Yacute;   &yacute;
	&Yuml;     &yuml;        &Zeta;     &zeta;         
};

my %lower_entities = @entities;
my %upper_entities = reverse @entities;

my %casing = (
	lower => [ \%lower_entities,  \%lower_entities,
		   sub { $_ = lc },   sub { $_ = lc } ],
	upper => [ \%upper_entities,  \%upper_entities,
		   sub { $_ = uc },   sub { $_ = uc } ],
	title => [ \%upper_entities,  \%lower_entities,
		   sub { $_ = ucfirst lc }, sub { $_ = lc } ],
);

my $default_margin = 72;
my $default_widow  = 10;

$Text::Autoformat::widow_slack = 0.1;


sub defn($)
{
	return $_[0] if defined $_[0];
	return "";
}

my $ignore_headers = qr/\A(From\b.*$)?([^:]+:.*$([ \t].*$)*)+\s*\Z/m;
my $ignore_indent  = qr/^[^\S\n].*(\n[^\S\n].*)*$/;

sub ignore_headers { $_[0]==1 && /$ignore_headers/ }

# BITS OF A TEXT LINE

my $quotechar = qq{[!#%=|:]};
my $quotechunk = qq{(?:$quotechar(?![a-z])|[a-z]*>+)};
my $quoter = qq{(?:(?i)(?:$quotechunk(?:[ \\t]*$quotechunk)*))};

my $separator = q/(?:[-_]{2,}|[=#*]{3,}|[+~]{4,})/;

use overload;
sub autoformat	# ($text, %args)
{
	my ($text,%args,$toSTDOUT);

	foreach ( @_ )
	{
		if (ref eq 'HASH')
			{ %args = (%args, %$_) }
		elsif (!defined($text) && !ref || overload::Method($_,'""'))
			{ $text = "$_" }
		else {
			croak q{Usage: autoformat([text],[{options}])}
		}
	}

	unless (defined $text) {
		$text = join("",<STDIN>);
		$toSTDOUT = !defined wantarray();
	}

	return unless length $text;

	$args{right}   = $default_margin unless exists $args{right};
	$args{justify} = "" unless exists $args{justify};
	$args{widow}   = 0 if $args{justify}||"" =~ /full/;
	$args{widow}   = $default_widow unless exists $args{widow};
	$args{case}    = '' unless exists $args{case};
	$args{squeeze} = 1 unless exists $args{squeeze};
	$args{gap}     = 0 unless exists $args{gap};
	$args{break}  = break_at('-') unless exists $args{break};
	$args{impfill} = ! exists $args{fill};
	$args{expfill} = $args{fill};
	$args{renumber} = 1 unless exists $args{renumber};
	$args{autocentre} = 1 unless exists $args{autocentre};
	$args{_centred} = 1 if $args{justify} =~ /cent(er(ed)?|red?)/;

	# SPECIAL IGNORANCE...
	if ($args{ignore}) {
		$args{all} = 1;
		my $ig_type = ref $args{ignore};
		if ($ig_type eq 'Regexp') {
			my $regex = $args{ignore};
			$args{ignore} = sub { /$regex/ };
		}
		elsif ($args{ignore} =~ /^indent/i) {
			$args{ignore} = sub { ignore_headers(@_) || /$ignore_indent/ };
		}
		croak "Expected suboutine reference as value for -ignore option"
			if ref $args{ignore} ne 'CODE';
	}
	else {
		$args{ignore} = \&ignore_headers;
	}
	
	# DETABIFY
	my @rawlines = split /\n/, $text;
	use Text::Tabs;
	@rawlines = expand(@rawlines);

	# PARSE EACH LINE

	my $pre = 0;
	my @lines;
	foreach (@rawlines)
	{
			push @lines, { raw	   => $_ };
			s/\A([ \t]*)($quoter?)([ \t]*)//
				or die "Internal Error ($@) on '$_'";
			$lines[-1]{presig} =  $lines[-1]{prespace}   = defn $1;
			$lines[-1]{presig} .= $lines[-1]{quoter}     = defn $2;
			$lines[-1]{presig} .= $lines[-1]{quotespace} = defn $3;

			$lines[-1]{hang}       = Hang->new($_);

			s/([ \t]*)(.*?)(\s*)$//
				or die "Internal Error ($@) on '$_'";
			$lines[-1]{hangspace} = defn $1;
			$lines[-1]{text} = defn $2;
			$lines[-1]{empty} = $lines[-1]{hang}->empty() && $2 !~ /\S/;
			$lines[-1]{separator} = $lines[-1]{text} =~ /^$separator$/;
	}

	# SUBDIVIDE DOCUMENT INTO COHERENT SUBSECTIONS

	my @chunks;
	push @chunks, [shift @lines];
	foreach my $line (@lines)
	{
		if ($line->{separator} ||
		    $line->{quoter} ne $chunks[-1][-1]->{quoter} ||
		    $line->{empty} ||
		    @chunks && $chunks[-1][-1]->{empty})
		{
			push @chunks, [$line];
		}
		else
		{
			push @{$chunks[-1]}, $line;
		}
	}



 # DETECT CENTRED PARAS

	CHUNK: foreach my $chunk ( @chunks )
	{
		next CHUNK if !$args{autocentre} || @$chunk < 2;
		my @length;
		my $ave = 0;
		foreach my $line (@$chunk)
		{
			my $prespace = $line->{quoter}  ? $line->{quotespace}
							: $line->{prespace};
			my $pagewidth = 
				2*length($prespace) + length($line->{text});
			push @length, [length $prespace,$pagewidth];
			$ave += $pagewidth;
		}
		$ave /= @length;
		my $diffpre = 0;
		foreach my $l (0..$#length)
		{
			next CHUNK unless abs($length[$l][1]-$ave) <= 2;
			$diffpre ||= $length[$l-1][0] != $length[$l][0]
				if $l > 0;
		}
		next CHUNK unless $diffpre;
		foreach my $line (@$chunk)
		{
			$line->{centred} = 1;
			($line->{quoter} ? $line->{quotespace}
					 : $line->{prespace}) = "";
		}
	}

	# REDIVIDE INTO PARAGRAPHS

	my @paras;
	foreach my $chunk ( @chunks )
	{
		my $first = 1;
		my $firstfrom;
		foreach my $line ( @{$chunk} )
		{
			if ($first ||
			    $line->{quoter} ne $paras[-1]->{quoter} ||
			    $paras[-1]->{separator} ||
			    !$line->{hang}->empty
			   )
			{
				push @paras, $line;
				$first = 0;
				$firstfrom = length($line->{raw}) - length($line->{text});
			}
			else
			{
    my $extraspace = length($line->{raw}) - length($line->{text}) - $firstfrom;
				$paras[-1]->{text} .= "\n" . q{ }x$extraspace . $line->{text};
				$paras[-1]->{raw} .= "\n" . $line->{raw};
			}
		}
	}

	# SELECT PARAS TO HANDLE

	my $remainder = "";
	if ($args{all}) { # STOP AT MAIL TERMINATOR
		for my $index (0..$#paras) {
		    local $_ = $paras[$index]{raw};
		    $paras[$index]{ignore} = $args{ignore}($index+1);
		    next unless /^--$/;
		    $remainder = join "\n", map { $_->{raw} } splice @paras, $index;
	            $remainder .= "\n" unless $remainder =~ /\n\z/;
		    last;
		}
	}
	else { # JUST THE FIRST PARA
		$remainder = join "\n", map { $_->{raw} } @paras[1..$#paras];
	        $remainder .= "\n" unless $remainder =~ /\n\z/;
		@paras = ( $paras[0] );
	}

	# RE-CASE TEXT
	if ($args{case}) {
		foreach my $para ( @paras ) {
			next if $para->{ignore};
			if ($args{case} =~ /upper/i) {
				$para->{text} = recase($para->{text}, 'upper');
			}
			if ($args{case} =~ /lower/i) {
				$para->{text} = recase($para->{text}, 'lower');
			}
			if ($args{case} =~ /title/i) {
				entitle($para->{text},0);
			}
			if ($args{case} =~ /highlight/i) {
				entitle($para->{text},1);
			}
			if ($args{case} =~ /sentence(\s*)/i) {
				my $trailer = $1;
				$args{squeeze}=0 if $trailer && $trailer ne " ";
				ensentence();
				$para->{text} =~ s/(\S+(\s+|$))/ensentence($1, $trailer)/ge;
			}
			$para->{text} =~ s/\b([A-Z])[.]/\U$1./gi; # ABBREVS
		}
	}

	# ALIGN QUOTERS
	# DETERMINE HANGING MARKER TYPE (BULLET, ALPHA, ROMAN, ETC.)

	my %sigs;
	my $lastquoted = 0;
	my $lastprespace = 0;
	for my $i ( 0..$#paras )
	{
		my $para = $paras[$i];
		next if $para->{ignore};

	 if ($para->{quoter})
		{
			if ($lastquoted) { $para->{prespace} = $lastprespace }
			else		 { $lastquoted = 1; $lastprespace = $para->{prespace} }
		}
		else
		{
			$lastquoted = 0;
		}
	}

# RENUMBER PARAGRAPHS

	for my $para ( @paras ) {
		next if $para->{ignore};
		my $sig = $para->{presig} . $para->{hang}->signature();
		push @{$sigs{$sig}{hangref}}, $para;
		$sigs{$sig}{hangfields} = $para->{hang}->fields()-1
			unless defined $sigs{$sig}{hangfields};
	}

	while (my ($sig,$val) = each %sigs) {
		next unless $sig =~ /rom/;
		field: for my $field ( 0..$val->{hangfields} )
		{
			my $romlen = 0;
			foreach my $para ( @{$val->{hangref}} )
			{
				my $hang = $para->{hang};
				my $fieldtype = $hang->field($field);
				next field 
					unless $fieldtype && $fieldtype =~ /rom|let/;
				if ($fieldtype eq 'let') {
					foreach my $para ( @{$val->{hangref}} ) {
						$hang->field($field=>'let')
					}
				}
				else {
					$romlen += length $hang->val($field);
				}
			}
			# NO ROMAN LETTER > 1 CHAR -> ALPHABETICS
			if ($romlen <= @{$val->{hangref}}) {
				foreach my $para ( @{$val->{hangref}} ) {
					$para->{hang}->field($field=>'let')
				}
			}
		}
	}

	my %prev;

	for my $para ( @paras ) {
		next if $para->{ignore};
		my $sig = $para->{presig} . $para->{hang}->signature();
		if ($args{renumber}) {
			unless ($para->{quoter}) {
				$para->{hang}->incr($prev{""}, $prev{$sig});
				$prev{""} = $prev{$sig} = $para->{hang}
					unless $para->{hang}->empty;
			}
		}
			
		# COLLECT MAXIMAL HANG LENGTHS BY SIGNATURE

		my $siglen = $para->{hang}->length();
		$sigs{$sig}{hanglen} = $siglen
			if ! $sigs{$sig}{hanglen} ||
			   $sigs{$sig}{hanglen} < $siglen;
	}

	# PROPAGATE MAXIMAL HANG LENGTH

	while (my ($sig,$val) = each %sigs)
	{
		foreach (@{$val->{hangref}}) {
			$_->{hanglen} = $val->{hanglen};
		}
	}

	# BUILD FORMAT FOR EACH PARA THEN FILL IT 

	$text = "";
	my $gap = $paras[0]->{empty} ? 0 : $args{gap};
	for my $para ( @paras )
	{
	    if ($para->{empty}) {
		$gap += 1 + ($para->{text} =~ tr/\n/\n/);
	    }
	    if ($para->{ignore}) {
	        $text .= (!$para->{empty} ? "\n"x($args{gap}-$gap) : "") ;
		$text .= $para->{raw};
		$text .= "\n" unless $para->{raw} =~ /\n\z/;
	    }
	    else {
	        my $leftmargin = $args{left} ? " "x($args{left}-1)
					 : $para->{prespace};
	        my $hlen = $para->{hanglen} || $para->{hang}->length;
	        my $hfield = ($hlen==1 ? '~' : '>'x$hlen);
	        my @hang;
	        push @hang, $para->{hang}->stringify if $hlen;
	        my $format = $leftmargin
			   . quotemeta($para->{quoter})
			   . $para->{quotespace}
			   . $hfield
			   . $para->{hangspace};
	        my $rightslack = int (($args{right}-length $leftmargin)*$Text::Autoformat::widow_slack);
	        my ($widow_okay, $rightindent, $firsttext, $newtext) = (0,0);
	        do {
	            my $tlen = $args{right}-$rightindent-length($leftmargin
			 			    . $para->{quoter}
			 			    . $para->{quotespace}
			 			    . $hfield
			 			    . $para->{hangspace});
	            next if blockquote($text,$para, $format, $tlen, \@hang, \%args);
	            my $tfield = ( $tlen==1                          ? '~'
			         : $para->{centred}||$args{_centred} ? '|'x$tlen
			         : $args{justify} eq 'right'         ? ']'x$tlen
			         : $args{justify} eq 'full'          ? '['x($tlen-2) . ']]'
			         : $para->{centred}||$args{_centred} ? '|'x$tlen
			         :                                     '['x$tlen
        		         );
		    my $tryformat = "$format$tfield";
		    $newtext = (!$para->{empty} ? "\n"x($args{gap}-$gap) : "") 
		             . form( { squeeze=>$args{squeeze}, trim=>1,
				       break=>$args{break},
				       fill => !(!($args{expfill}
					    || $args{impfill} &&
					       !$para->{centred}))
			           },
				    $tryformat, @hang,
				    $para->{text});
		    $firsttext ||= $newtext;
		    $newtext =~ /\s*([^\n]*)$/;
		    $widow_okay = $para->{empty} || length($1) >= $args{widow};
	        } until $widow_okay || ++$rightindent > $rightslack;
    
	        $text .= $widow_okay ? $newtext : $firsttext;
	    }
	    $gap = 0 unless $para->{empty};
	}


	# RETURN FORMATTED TEXT

	if ($toSTDOUT) { print STDOUT $text . $remainder; return }
	return $text . $remainder;
}

use utf8;

my $alpha = qr/[^\W\d_]/;
my $notalpha = qr/[\W\d_]/;
my $word = qr/\pL(?:\pL'?)*/;
my $upper = qr/[^\Wa-z\d_]/;
my $lower = qr/[^\WA-Z\d_]/;
my $mixed = qr/$alpha*?(?:$lower$upper|$upper$lower)$alpha*/;

sub recase {
	my ($origtext, $case) = @_;
	my ($entities, $other_entities, $first, $rest) = @{$casing{$case}};

	my $text = "";
	my @pieces = split /(&[a-z]+;)/i, $origtext;
	use Data::Dumper 'Dumper';
	push @pieces, "" if @pieces % 2;
	return $text unless @pieces;
	local $_ = shift @pieces;
	if (length $_) {
		$entities = $other_entities;
		&$first;
		$text .= $_;
	}
	return $text unless @pieces;
	$_ = shift @pieces;
	$text .= $entities->{$_} || $_;
	while (@pieces) {
		$_ = shift @pieces; &$rest; $text .= $_;
		$_ = shift @pieces; $text .= $other_entities->{$_} || $_;
	}
	return $text;
}

my $alword = qr{(?:\pL|&[a-z]+;)(?:[\pL']|&[a-z]+;)*}i;

sub entitle {
	my $ignore = pop;
	local *_ = \shift;

	# put into lowercase if on stop list, else titlecase
	s{($alword)}
	 { $ignore && $ignore{lc $1} ? recase($1,'lower') : recase($1,'title') }gex;

	s/^($alword) /recase($1,'title')/ex;  # last word always to cap
	s/ ($alword)$/recase($1,'title')/ex;  # first word always to cap

	# treat parethesized portion as a complete title
	s/\( ($alword) /'('.recase($1,'title')/ex;
	s/($alword) \) /recase($1,'title').')'/ex;

	# capitalize first word following colon or semi-colon
	s/ ( [:;] \s+ ) ($alword) /$1 . recase($2,'title')/ex;
}

my $abbrev = join '|', qw{
	etc[.]	pp[.]	ph[.]?d[.]	U[.]S[.]
};

my $gen_abbrev = join '|', $abbrev, qw{
 	(^[^a-z]*([a-z][.])+)
};

my $term = q{(?:[.]|[!?]+)};

my $eos = 1;
my $brsent = 0;

sub ensentence {
	do { $eos = 1; return } unless @_;
	my ($str, $trailer) = @_;
	if ($str =~ /^([^a-z]*)I[^a-z]*?($term?)[^a-z]*$/i) {
		$eos = $2;
		$brsent = $1 =~ /^[[(]/;
		return uc $str
	}
	unless ($str =~ /[a-z].*[A-Z]|[A-Z].*[a-z]/) {
		$str = lc $str;
	}
	if ($eos) {
		$str =~ s/([a-z])/uc $1/ie;
		$brsent = $str =~ /^[[(]/;
	}
	$eos = $str !~ /($gen_abbrev)[^a-z]*\s/i
	    && $str =~ /[a-z][^a-z]*$term([^a-z]*)\s/
	    && !($1=~/[])]/ && !$brsent);
	$str =~ s/\s+$/$trailer/ if $eos && $trailer;
	return $str;
}

# blockquote($text,$para, $format, $tlen, \@hang, \%args);
sub blockquote {
	my ($dummy, $para, $format, $tlen, $hang, $args) = @_;
=begin other
	print STDERR "[", join("|", $para->{raw} =~
/ \A(\s*)		# $1 - leading whitespace (quotation)
	   (["']|``)		# $2 - opening quotemark
	   (.*)			# $3 - quotation
	   (''|\2)		# $4 closing quotemark
	   \s*?\n		# trailing whitespace
	   (\1[ ]+)		# $5 - leading whitespace (attribution)
	   (--|-)		# $6 - attribution introducer
	   ([^\n]*?$)		# $7 - attribution line 1
	   ((\5[^\n]*?$)*)		# $8 - attributions lines 2-N
	   \s*\Z
	 /xsm
), "]\n";
=cut
	$para->{text} =~
		/ \A(\s*)		# $1 - leading whitespace (quotation)
	   (["']|``)		# $2 - opening quotemark
	   (.*)			# $3 - quotation
	   (''|\2)		# $4 closing quotemark
	   \s*?\n		# trailing whitespace
	   (\1[ ]+)		# $5 - leading whitespace (attribution)
	   (--|-)		# $6 - attribution introducer
	   (.*?$)		# $7 - attribution line 1
	   ((\5.*?$)*)		# $8 - attributions lines 2-N
	   \s*\Z
	 /xsm
	 or return;

	#print "[$1][$2][$3][$4][$5][$6][$7]\n";
	my $indent = length $1;
	my $text = $2.$3.$4;
	my $qindent = length $2;
	my $aindent = length $5;
	my $attribintro = $6;
	my $attrib = $7.$8;
	$text =~ s/\n/ /g;

	$_[0] .= 

				form {squeeze=>$args->{squeeze}, trim=>1,
          fill => $args->{expfill}
			       },
	   $format . q{ }x$indent . q{<}x$tlen,
             @$hang, $text,
	   $format . q{ }x($qindent) . q{[}x($tlen-$qindent), 
             @$hang, $text,
	   {squeeze=>0},
	   $format . q{ } x $aindent . q{>> } . q{[}x($tlen-$aindent-3),
             @$hang, $attribintro, $attrib;
	return 1;
}

package Hang;

# ROMAN NUMERALS

sub inv($@) { my ($k, %inv)=shift; for(0..$#_) {$inv{$_[$_]}=$_*$k} %inv } 
my @unit= ( "" , qw ( I II III IV V VI VII VIII IX ));
my @ten = ( "" , qw ( X XX XXX XL L LX LXX LXXX XC ));
my @hund= ( "" , qw ( C CC CCC CD D DC DCC DCCC CM ));
my @thou= ( "" , qw ( M MM MMM ));
my %rval= (inv(1,@unit),inv(10,@ten),inv(100,@hund),inv(1000,@thou));
my $rbpat= join ")(",join("|",reverse @thou), join("|",reverse @hund), join("|",reverse @ten), join("|",reverse @unit);
my $rpat= join ")(?:",join("|",reverse @thou), join("|",reverse @hund), join("|",reverse @ten), join("|",reverse @unit);

sub fromRoman($)
{
    return 0 unless $_[0] =~ /^.*?($rbpat).*$/i;
    return $rval{uc $1} + $rval{uc $2} + $rval{uc $3} + $rval{uc $4};
}

sub toRoman($$)
{
    my ($num,$example) = @_;
    return '' unless $num =~ /^([0-3]??)(\d??)(\d??)(\d)$/;
    my $roman = $thou[$1||0] . $hund[$2||0] . $ten[$3||0] . $unit[$4||0];
    return $example=~/[A-Z]/ ? uc $roman : lc $roman;
}

# BITS OF A NUMERIC VALUE

my $num = q/(?:\d{1,3}\b)/;
my $rom = qq/(?:(?=[MDCLXVI])(?:$rpat))/;
my $let = q/[A-Za-z]/;
my $pbr = q/[[(<]/;
my $sbr = q/])>/;
my $ows = q/[ \t]*/;
my %close = ( '[' => ']', '(' => ')', '<' => '>', "" => '' );

my $hangPS      = qq{(?i:ps:|(?:p\\.?)+s\\b\\.?(?:[ \\t]*:)?)};
my $hangNB      = qq{(?i:n\\.?b\\.?(?:[ \\t]*:)?)};
my $hangword    = qq{(?:(?:Note)[ \\t]*:)};
my $hangbullet  = qq{[*.+-]};
my $hang        = qq{(?:(?i)(?:$hangNB|$hangword|$hangbullet)(?=[ \t]))};

# IMPLEMENTATION

sub new { 
	my ($class, $orig) = @_;
	my $origlen = length $orig;
	my @vals;
	if ($_[1] =~ s#\A($hangPS)##) {
		@vals = { type => 'ps', val => $1 }
	}
	elsif ($_[1] =~ s#\A($hang)##) {
		@vals = { type => 'bul', val => $1 }
	}
	else {
		local $^W;
		my $cut;
		while (length $_[1]) {
			last if $_[1] =~ m#\A($ows)($abbrev)#
			     && (length $1 || !@vals);	# ws-separated or first

			$cut = $origlen - length $_[1];
			my $pre = $_[1] =~ s#\A($ows$pbr$ows)## ? $1 : "";
			my $val =  $_[1] =~ s#\A($num)##  && { type=>'num', val=>$1 }
			       || $_[1] =~ s#\A($rom)##i && { type=>'rom', val=>$1, nval=>fromRoman($1) }
			       || $_[1] =~ s#\A($let(?!$let))##i && { type=>'let', val=>$1 }
			       || { val => "", type => "" };
			$_[1] = $pre.$_[1] and last unless $val->{val};
			$val->{post} = $pre && $_[1] =~ s#\A($ows()[.:/]?[$close{$pre}][.:/]?)## && $1
		                     || $_[1] =~ s#\A($ows()[$sbr.:/])## && $1
		                     || "";
			$val->{pre}  = $pre;
			$val->{cut}  = $cut;
			push @vals, $val;
		}
		while (@vals && !$vals[-1]{post}) {
			$_[1] = substr($orig,pop(@vals)->{cut});
		}
	}
	# check for orphaned years...
	if (@vals==1 && $vals[0]->{type} eq 'num'
		     && $vals[0]->{val} >= 1000
		     && $vals[0]->{post} eq '.')  {
		$_[1] = substr($orig,pop(@vals)->{cut});

        }
	return NullHang->new if !@vals;
	bless \@vals, $class;
} 

sub incr {
	local $^W;
	my ($self, $prev, $prevsig) = @_;
	my $level;
	# check compatibility

	return unless $prev && !$prev->empty;

	for $level (0..(@$self<@$prev ? $#$self : $#$prev)) {
		if ($self->[$level]{type} ne $prev->[$level]{type}) {
			return if @$self<=@$prev;	# no incr if going up
			$prev = $prevsig;
			last;
		}
	}
	return unless $prev && !$prev->empty;
	if ($self->[0]{type} eq 'ps') {
		my $count = 1 + $prev->[0]{val} =~ s/(p[.]?)/$1/gi;
		$prev->[0]{val} =~ /^(p[.]?).*(s[.]?[:]?)/;
		$self->[0]{val} = $1  x $count . $2;
	}
	elsif ($self->[0]{type} eq 'bul') {
		# do nothing
	}
	elsif (@$self>@$prev) {	# going down level(s)
		for $level (0..$#$prev) {
				@{$self->[$level]}{'val','nval'} = @{$prev->[$level]}{'val','nval'};
		}
		for $level (@$prev..$#$self) {
				_reset($self->[$level]);
		}
	}
	else	# same level or going up
	{
		for $level (0..$#$self) {
			@{$self->[$level]}{'val','nval'} = @{$prev->[$level]}{'val','nval'};
		}
		_incr($self->[-1])
	}
}

sub _incr {
	local $^W;
	if ($_[0]{type} eq 'rom') {
		$_[0]{val} = toRoman(++$_[0]{nval},$_[0]{val});
	}
	else {
		$_[0]{val}++ unless $_[0]{type} eq 'let' && $_[0]{val}=~/Z/i;
	}
}

sub _reset {
	local $^W;
	if ($_[0]{type} eq 'rom') {
		$_[0]{val} = toRoman($_[0]{nval}=1,$_[0]{val});
	}
	elsif ($_[0]{type} eq 'let') {
		$_[0]{val} = $_[0]{val} =~ /[A-Z]/ ? 'A' : 'a';
	}
	else {
		$_[0]{val} = 1;
	}
}

sub stringify {
	my ($self) = @_;
	my ($str, $level) = ("");
	for $level (@$self) {
		local $^W;
		$str .= join "", @{$level}{'pre','val','post'};
	}
	return $str;
} 

sub val {
	my ($self, $i) = @_;
	return $self->[$i]{val};
}

sub fields { return scalar @{$_[0]} }

sub field {
	my ($self, $i, $newval) = @_;
	$self->[$i]{type} = $newval if @_>2;
	return $self->[$i]{type};
}

sub signature {
	local $^W;
	my ($self) = @_;
	my ($str, $level) = ("");
	for $level (@$self) {
		$level->{type} ||= "";
		$str .= join "", $level->{pre},
		                 ($level->{type} =~ /rom|let/ ? "romlet" : $level->{type}),
		                 $level->{post};
	}
	return $str;
} 

sub length {
	length $_[0]->stringify
}

sub empty { 0 }

package NullHang;

sub new       { bless {}, $_[0] }
sub stringify { "" }
sub length    { 0 }
sub incr      {}
sub empty     { 1 }
sub signature     { "" }
sub fields { return 0 }
sub field { return "" }
sub val { return "" }
1;

__END__

