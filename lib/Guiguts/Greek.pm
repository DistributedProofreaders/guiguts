package Guiguts::Greek;
use strict;
use warnings;

BEGIN {
	use Exporter();
	our ( @ISA, @EXPORT );
	@ISA    = qw(Exporter);
	@EXPORT = qw(&greekpopup &findandextractgreek &betagreek);
}

sub fromgreektr {
	my $phrase = shift;
	$phrase =~ s/\x{03C2}($|\W)/s$1/g;
	$phrase =~ s/\x{03B8}/th/g;
	$phrase =~ s/\x{03B3}\x{03B3}/ng/g;
	$phrase =~ s/\x{03B3}\x{03BA}/nk/g;
	$phrase =~ s/\x{03B3}\x{03BE}/nx/g;
	$phrase =~ s/\x{1FE5}/rh/g;
	$phrase =~ s/\x{03C6}/ph/g;
	$phrase =~ s/\x{03B3}\x{03C7}/nch/g;
	$phrase =~ s/\x{03C7}/ch/g;
	$phrase =~ s/\x{03C8}/ps/g;
	$phrase =~ s/\x{1F01}/ha/g;
	$phrase =~ s/\x{1F11}/he/g;
	$phrase =~ s/\x{1F21}/hê/g;
	$phrase =~ s/\x{1F31}/hi/g;
	$phrase =~ s/\x{1F41}/ho/g;
	$phrase =~ s/\x{1F51}/hy/g;
	$phrase =~ s/\x{1F61}/hô/g;
	$phrase =~ s/\x{03A7}/Ch/g;
	$phrase =~ s/\x{0398}/Th/g;
	$phrase =~ s/\x{03A6}/Ph/g;
	$phrase =~ s/\x{03A8}/Ps/g;
	$phrase =~ s/\x{1F09}/Ha/g;
	$phrase =~ s/\x{1F19}/He/g;
	$phrase =~ s/\x{1F29}/Hê/g;
	$phrase =~ s/\x{1F39}/Hi/g;
	$phrase =~ s/\x{1F49}/Ho/g;
	$phrase =~ s/\x{1F59}/Hy/g;
	$phrase =~ s/\x{1F69}/Hô/g;
	$phrase =~ s/\x{0391}/A/g;
	$phrase =~ s/\x{03B1}/a/g;
	$phrase =~ s/\x{0392}/B/g;
	$phrase =~ s/\x{03B2}/b/g;
	$phrase =~ s/\x{0393}/G/g;
	$phrase =~ s/\x{03B3}/g/g;
	$phrase =~ s/\x{0394}/D/g;
	$phrase =~ s/\x{03B4}/d/g;
	$phrase =~ s/\x{0395}/E/g;
	$phrase =~ s/\x{03B5}/e/g;
	$phrase =~ s/\x{0396}/Z/g;
	$phrase =~ s/\x{03B6}/z/g;
	$phrase =~ s/\x{0397}/Ê/g;
	$phrase =~ s/\x{03B7}/ê/g;
	$phrase =~ s/\x{0399}/I/g;
	$phrase =~ s/\x{03B9}/i/g;
	$phrase =~ s/\x{039A}/K/g;
	$phrase =~ s/\x{03BA}/k/g;
	$phrase =~ s/\x{039B}/L/g;
	$phrase =~ s/\x{03BB}/l/g;
	$phrase =~ s/\x{039C}/M/g;
	$phrase =~ s/\x{03BC}/m/g;
	$phrase =~ s/\x{039D}/N/g;
	$phrase =~ s/\x{03BD}/n/g;
	$phrase =~ s/\x{039E}/X/g;
	$phrase =~ s/\x{03BE}/x/g;
	$phrase =~ s/\x{039F}/O/g;
	$phrase =~ s/\x{03BF}/o/g;
	$phrase =~ s/\x{03A0}/P/g;
	$phrase =~ s/\x{03C0}/p/g;
	$phrase =~ s/\x{03A1}/R/g;
	$phrase =~ s/\x{03C1}/r/g;
	$phrase =~ s/\x{03A3}/S/g;
	$phrase =~ s/\x{03C3}/s/g;
	$phrase =~ s/\x{03A4}/T/g;
	$phrase =~ s/\x{03C4}/t/g;
	$phrase =~ s/\x{03A9}/Ô/g;
	$phrase =~ s/\x{03C9}/ô/g;
	$phrase =~ s/\x{03A5}(?=\W)/Y/g;
	$phrase =~ s/\x{03C5}(?=\W)/y/g;
	$phrase =~ s/(?<=\W)\x{03A5}/U/g;
	$phrase =~ s/(?<=\W)\x{03C5}/u/g;
	$phrase =~ s/([AEIOU])\x{03A5}/$1U/g;
	$phrase =~ s/([AEIOUaeiou])\x{03C5}/$1u/g;
	$phrase =~ s/\x{03A5}/Y/g;
	$phrase =~ s/\x{03C5}/y/g;
	$phrase =~ s/\x{037E}/?/g;
	$phrase =~ s/\x{0387}/;/g;
	$phrase =~ s/(\p{Upper}\p{Lower}\p{Upper})/\U$1\E/g;
	$phrase =~ s/([AEIOUaeiou])y/$1u/g;
	return $phrase;
}
## Find Greek
sub findandextractgreek {
	my $top        = $::top;
	my $textwindow = $::textwindow;
	$textwindow->tagRemove( 'highlight', '1.0', 'end' );
	my ( $greekIndex, $closeIndex ) = findgreek('insert');
	if ($closeIndex) {
		$textwindow->markSet( 'insert', $greekIndex );
		$textwindow->tagAdd( 'highlight', $greekIndex, $greekIndex . "+7c" );
		$textwindow->see('insert');
		$textwindow->tagAdd( 'highlight', $greekIndex, $greekIndex . "+1c" );
		if ( !defined( $::lglobal{grpop} ) ) {
			greekpopup();
		}
		$textwindow->markSet( 'insert', $greekIndex . '+8c' );
		my $text = $textwindow->get( $greekIndex . '+8c', $closeIndex );
		$textwindow->delete( $greekIndex . '+8c', $closeIndex );
		$::lglobal{grtext}->delete( '1.0', 'end' );
		$::lglobal{grtext}->insert( '1.0', $text );
	}
}

sub greekpopup {
	my $top        = $::top;
	my $textwindow = $::textwindow;
	my $buildlabel;
	my %attributes;
	if ( defined( $::lglobal{grpop} ) ) {
		$::lglobal{grpop}->deiconify;
		$::lglobal{grpop}->raise;
		$::lglobal{grpop}->focus;
	} else {
		my @greek = (
					  [ 'a',  'calpha',   'lalpha',   'chalpha',   'halpha' ],
					  [ 'b',  'cbeta',    'lbeta',    '',          '' ],
					  [ 'g',  'cgamma',   'lgamma',   'ng',        '' ],
					  [ 'd',  'cdelta',   'ldelta',   '',          '' ],
					  [ 'e',  'cepsilon', 'lepsilon', 'chepsilon', 'hepsilon' ],
					  [ 'z',  'czeta',    'lzeta',    '',          '' ],
					  [ 'ê', 'ceta',     'leta',     'cheta',     'heta' ],
					  [ 'th', 'ctheta',   'ltheta',   '',          '' ],
					  [ 'i',  'ciota',    'liota',    'chiota',    'hiota' ],
					  [ 'k',  'ckappa',   'lkappa',   'nk',        '' ],
					  [ 'l',  'clambda',  'llambda',  '',          '' ],
					  [ 'm',  'cmu',      'lmu',      '',          '' ],
					  [ 'n',  'cnu',      'lnu',      '',          '' ],
					  [ 'x',  'cxi',      'lxi',      'nx',        '' ],
					  [ 'o',  'comicron', 'lomicron', 'chomicron', 'homicron' ],
					  [ 'p',  'cpi',      'lpi',      '',          '' ],
					  [ 'r',  'crho',     'lrho',     'hrho',      '' ],
					  [ 's',  'csigma',   'lsigma',   'lsigmae',   '' ],
					  [ 't',  'ctau',     'ltau',     '',          '' ],
					  [
						 '(yu)', 'cupsilon', 'lupsilon', 'chupsilon',
						 'hupsilon'
					  ],
					  [ 'ph',  'cphi',     'lphi',     '',        '' ],
					  [ 'ch',  'cchi',     'lchi',     'nch',     '' ],
					  [ 'ps',  'cpsi',     'lpsi',     '',        '' ],
					  [ 'ô',  'comega',   'lomega',   'chomega', 'homega' ],
					  [ 'st',  'cstigma',  'lstigma',  '',        '' ],
					  [ '6',   'cdigamma', 'ldigamma', '',        '' ],
					  [ '90',  'ckoppa',   'lkoppa',   '',        '' ],
					  [ '900', 'csampi',   'lsampi',   '',        '' ]
		);
		%attributes = (
			'calpha'  => [ 'A',  'Alpha', '&#913;',  "\x{0391}" ],
			'lalpha'  => [ 'a',  'alpha', '&#945;',  "\x{03B1}" ],
			'chalpha' => [ 'Ha', 'Alpha', '&#7945;', "\x{1F09}" ],
			'halpha'  => [ 'ha', 'alpha', '&#7937;', "\x{1F01}" ],
			'cbeta'   => [ 'B',  'Beta',  '&#914;',  "\x{0392}" ],
			'lbeta'   => [ 'b',  'beta',  '&#946;',  "\x{03B2}" ],
			'cgamma'  => [ 'G',  'Gamma', '&#915;',  "\x{0393}" ],
			'lgamma'  => [ 'g',  'gamma', '&#947;',  "\x{03B3}" ],
			'ng' => [ 'ng', 'gamma gamma', '&#947;&#947;', "\x{03B3}\x{03B3}" ],
			'cdelta'    => [ 'D',   'Delta',   '&#916;',  "\x{0394}" ],
			'ldelta'    => [ 'd',   'delta',   '&#948;',  "\x{03B4}" ],
			'cepsilon'  => [ 'E',   'Epsilon', '&#917;',  "\x{0395}" ],
			'lepsilon'  => [ 'e',   'epsilon', '&#949;',  "\x{03B5}" ],
			'chepsilon' => [ 'He',  'Epsilon', '&#7961;', "\x{1F19}" ],
			'hepsilon'  => [ 'he',  'epsilon', '&#7953;', "\x{1F11}" ],
			'czeta'     => [ 'Z',   'Zeta',    '&#918;',  "\x{0396}" ],
			'lzeta'     => [ 'z',   'zeta',    '&#950;',  "\x{03B6}" ],
			'ceta'      => [ 'Ê',  'Eta',     '&#919;',  "\x{0397}" ],
			'leta'      => [ 'ê',  'eta',     '&#951;',  "\x{03B7}" ],
			'cheta'     => [ 'Hê', 'Eta',     '&#7977;', "\x{1F29}" ],
			'heta'      => [ 'hê', 'eta',     '&#7969;', "\x{1F21}" ],
			'ctheta'    => [ 'Th',  'Theta',   '&#920;',  "\x{0398}" ],
			'ltheta'    => [ 'th',  'theta',   '&#952;',  "\x{03B8}" ],
			'ciota'     => [ 'I',   'Iota',    '&#921;',  "\x{0399}" ],
			'liota'     => [ 'i',   'iota',    '&#953;',  "\x{03B9}" ],
			'chiota'    => [ 'Hi',  'Iota',    '&#7993;', "\x{1F39}" ],
			'hiota'     => [ 'hi',  'iota',    '&#7985;', "\x{1F31}" ],
			'ckappa'    => [ 'K',   'Kappa',   '&#922;',  "\x{039A}" ],
			'lkappa'    => [ 'k',   'kappa',   '&#954;',  "\x{03BA}" ],
			'nk' => [ 'nk', 'gamma kappa', '&#947;&#954;', "\x{03B3}\x{03BA}" ],
			'clambda' => [ 'L', 'Lambda', '&#923;', "\x{039B}" ],
			'llambda' => [ 'l', 'lambda', '&#955;', "\x{03BB}" ],
			'cmu'     => [ 'M', 'Mu',     '&#924;', "\x{039C}" ],
			'lmu'     => [ 'm', 'mu',     '&#956;', "\x{03BC}" ],
			'cnu'     => [ 'N', 'Nu',     '&#925;', "\x{039D}" ],
			'lnu'     => [ 'n', 'nu',     '&#957;', "\x{03BD}" ],
			'cxi'     => [ 'X', 'Xi',     '&#926;', "\x{039E}" ],
			'lxi'     => [ 'x', 'xi',     '&#958;', "\x{03BE}" ],
			'nx' => [ 'nx', 'gamma xi', '&#947;&#958;', "\x{03B3}\x{03BE}" ],
			'comicron'  => [ 'O',  'Omicron', '&#927;',  "\x{039F}" ],
			'lomicron'  => [ 'o',  'omicron', '&#959;',  "\x{03BF}" ],
			'chomicron' => [ 'Ho', 'Omicron', '&#8009;', "\x{1F49}" ],
			'homicron'  => [ 'ho', 'omicron', '&#8001;', "\x{1F41}" ],
			'cpi'       => [ 'P',  'Pi',      '&#928;',  "\x{03A0}" ],
			'lpi'       => [ 'p',  'pi',      '&#960;',  "\x{03C0}" ],
			'crho'      => [ 'R',  'Rho',     '&#929;',  "\x{03A1}" ],
			'lrho'      => [ 'r',  'rho',     '&#961;',  "\x{03C1}" ],
			'hrho'      => [ 'rh', 'rho',     '&#8165;', "\x{1FE5}" ],
			'csigma'    => [ 'S',  'Sigma',   '&#931;',  "\x{03A3}" ],
			'lsigma'    => [ 's',  'sigma',   '&#963;',  "\x{03C3}" ],
			'lsigmae'   => [ 's',  'sigma',   '&#962;',  "\x{03C2}" ],
			'ctau'      => [ 'T',  'Tau',     '&#932;',  "\x{03A4}" ],
			'ltau'      => [ 't',  'tau',     '&#964;',  "\x{03C4}" ],
			'cupsilon'  => [ 'Y',  'Upsilon', '&#933;',  "\x{03A5}" ],
			'lupsilon'  => [ 'y',  'upsilon', '&#965;',  "\x{03C5}" ],
			'chupsilon' => [ 'Hy', 'Upsilon', '&#8025;', "\x{1F59}" ],
			'hupsilon'  => [ 'hy', 'upsilon', '&#8017;', "\x{1F51}" ],
			'cphi'      => [ 'Ph', 'Phi',     '&#934;',  "\x{03A6}" ],
			'lphi'      => [ 'ph', 'phi',     '&#966;',  "\x{03C6}" ],
			'cchi'      => [ 'Ch', 'Chi',     '&#935;',  "\x{03A7}" ],
			'lchi'      => [ 'ch', 'chi',     '&#967;',  "\x{03C7}" ],
			'nch' => [ 'nch', 'gamma chi', '&#947;&#967;', "\x{03B3}\x{03C7}" ],
			'cpsi'     => [ 'Ps',  'Psi',     '&#936;',  "\x{03A8}" ],
			'lpsi'     => [ 'ps',  'psi',     '&#968;',  "\x{03C8}" ],
			'comega'   => [ 'Ô',  'Omega',   '&#937;',  "\x{03A9}" ],
			'lomega'   => [ 'ô',  'omega',   '&#969;',  "\x{03C9}" ],
			'chomega'  => [ 'Hô', 'Omega',   '&#8041;', "\x{1F69}" ],
			'homega'   => [ 'hô', 'omega',   '&#8033;', "\x{1F61}" ],
			'cstigma'  => [ 'St',  'Stigma',  '&#986;',  "\x{03DA}" ],
			'lstigma'  => [ 'st',  'stigma',  '&#987;',  "\x{03DB}" ],
			'cdigamma' => [ '6',   'Digamma', '&#988;',  "\x{03DC}" ],
			'ldigamma' => [ '6',   'digamma', '&#989;',  "\x{03DD}" ],
			'ckoppa'   => [ '9',   'Koppa',   '&#990;',  "\x{03DE}" ],
			'lkoppa'   => [ '9',   'koppa',   '&#991;',  "\x{03DF}" ],
			'csampi'   => [ '9',   'Sampi',   '&#992;',  "\x{03E0}" ],
			'lsampi'   => [ '9',   'sampi',   '&#993;',  "\x{03E1}" ],
			'oulig' => [ 'ou', 'oulig', '&#959;&#965;', "\x{03BF}\x{03C5}" ]
		);
		my $grfont = '{Times} 14';
		for my $image ( keys %attributes ) {
			$::lglobal{images}->{$image} =
			  $top->Photo( -format => 'gif',
						   -data   => $Guiguts::Greekgifs::grkgifs{$image}, );
		}
		$::lglobal{grpop} = $top->Toplevel;
		::initialize_popup_without_deletebinding('grpop');
		$::lglobal{grpop}->title('Greek Transliteration');
		my $tframe =
		  $::lglobal{grpop}
		  ->Frame->pack( -expand => 'no', -fill => 'none', -anchor => 'n' );
		my $glatin =
		  $tframe->Radiobutton(
								-variable    => \$::lglobal{groutp},
								-selectcolor => $::lglobal{checkcolor},
								-value       => 'l',
								-text        => 'Latin-1',
		  )->grid( -row => 1, -column => 1 );
		$tframe->Radiobutton(
							  -variable    => \$::lglobal{groutp},
							  -selectcolor => $::lglobal{checkcolor},
							  -value       => 'n',
							  -text        => 'Greek Name',
		)->grid( -row => 1, -column => 2 );
		$tframe->Radiobutton(
							  -variable    => \$::lglobal{groutp},
							  -selectcolor => $::lglobal{checkcolor},
							  -value       => 'h',
							  -text        => 'HTML code',
		)->grid( -row => 1, -column => 3 );

		if ( $Tk::version ge 8.4 ) {
			$tframe->Radiobutton(
								  -variable    => \$::lglobal{groutp},
								  -selectcolor => $::lglobal{checkcolor},
								  -value       => 'u',
								  -text        => 'UTF-8',
			)->grid( -row => 1, -column => 4 );
		}
		$tframe->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				my $spot = $::lglobal{grtext}->index('insert');
				$::lglobal{grtext}->insert( 'insert', ' ' );
				$::lglobal{grtext}->markSet( 'insert', "$spot+1c" );
				$::lglobal{grtext}->focus;
				$::lglobal{grtext}->see('insert');
			},
			-text => 'Space',
		)->grid( -row => 1, -column => 5 );
		$tframe->Button(
						 -activebackground => $::activecolor,
						 -command          => \&movegreek,
						 -text             => 'Transfer',
		)->grid( -row => 1, -column => 6 );
		$tframe->Button(
						-activebackground => $::activecolor,
						-command => sub { movegreek(); findandextractgreek(); },
						-text    => 'Transfer and get next',
		)->grid( -row => 1, -column => 7 );
		if ( $Tk::version ge 8.4 ) {
			my $tframe2 =
			  $::lglobal{grpop}->Frame->pack(
											  -expand => 'no',
											  -fill   => 'none',
											  -anchor => 'n',
											  -pady   => 3
			  );
			$tframe2->Button(
				-activebackground => $::activecolor,
				-command          => sub {
					my @ranges      = $::lglobal{grtext}->tagRanges('sel');
					my $range_total = @ranges;
					if ( $range_total == 0 ) {
						push @ranges, ( '1.0', 'end' );
					}
					my $textindex = 0;
					my $end       = pop(@ranges);
					my $start     = pop(@ranges);
					my $selection = $::lglobal{grtext}->get( $start, $end );
					$::lglobal{grtext}->delete( $start, $end );
					$::lglobal{grtext}->insert( $start, togreektr($selection) );
					if ( $::lglobal{grtext}->get( 'end -1c', 'end' ) =~ /^$/ ) {
						$::lglobal{grtext}->delete( 'end -1c', 'end' );
					}
				},
				-text => 'ASCII->Greek',
			)->grid( -row => 1, -column => 1, -padx => 2 );
			$tframe2->Button(
				-activebackground => $::activecolor,
				-command          => sub {
					my @ranges      = $::lglobal{grtext}->tagRanges('sel');
					my $range_total = @ranges;
					if ( $range_total == 0 ) {
						push @ranges, ( '1.0', 'end' );
					}
					my $textindex = 0;
					my $end       = pop(@ranges);
					my $start     = pop(@ranges);
					my $selection = $::lglobal{grtext}->get( $start, $end );
					$::lglobal{grtext}->delete( $start, $end );
					$::lglobal{grtext}
					  ->insert( $start, fromgreektr($selection) );
					if ( $::lglobal{grtext}->get( 'end -1c', 'end' ) =~ /^$/ ) {
						$::lglobal{grtext}->delete( 'end -1c', 'end' );
					}
				},
				-text => 'Greek->ASCII',
			)->grid( -row => 1, -column => 2, -padx => 2 );
			$tframe2->Button(
				-activebackground => $::activecolor,
				-command          => sub {
					my @ranges      = $::lglobal{grtext}->tagRanges('sel');
					my $range_total = @ranges;
					if ( $range_total == 0 ) {
						push @ranges, ( '1.0', 'end' );
					}
					my $textindex = 0;
					my $end       = pop(@ranges);
					my $start     = pop(@ranges);
					my $selection = $::lglobal{grtext}->get( $start, $end );
					$::lglobal{grtext}->delete( $start, $end );
					$::lglobal{grtext}
					  ->insert( $start, betagreek( 'unicode', $selection ) );
					if ( $::lglobal{grtext}->get( 'end -1c', 'end' ) =~ /^$/ ) {
						$::lglobal{grtext}->delete( 'end -1c', 'end' );
					}
				},
				-text => 'Beta code->Unicode',
			)->grid( -row => 1, -column => 3, -padx => 2 );
			$tframe2->Button(
				-activebackground => $::activecolor,
				-command          => sub {
					my @ranges      = $::lglobal{grtext}->tagRanges('sel');
					my $range_total = @ranges;
					if ( $range_total == 0 ) {
						push @ranges, ( '1.0', 'end' );
					}
					my $textindex = 0;
					my $end       = pop(@ranges);
					my $start     = pop(@ranges);
					my $selection = $::lglobal{grtext}->get( $start, $end );
					$::lglobal{grtext}->delete( $start, $end );
					$::lglobal{grtext}
					  ->insert( $start, betagreek( 'beta', $selection ) );
					if ( $::lglobal{grtext}->get( 'end -1c', 'end' ) =~ /^$/ ) {
						$::lglobal{grtext}->delete( 'end -1c', 'end' );
					}
				},
				-text => 'Unicode->Beta code',
			)->grid( -row => 1, -column => 4, -padx => 2 );
		}
		my $frame =
		  $::lglobal{grpop}->Frame( -background => $::bkgcolor )
		  ->pack( -expand => 'no', -fill => 'none', -anchor => 'n' );
		my $index = 0;
		for my $column (@greek) {
			my $row = 1;
			$index++;
			$frame->Label(
						   -text       => ${$column}[0],
						   -font       => $grfont,
						   -background => $::bkgcolor,
			)->grid( -row => $row, -column => $index, -padx => 2 );
			$row++;
			$::lglobal{buttons}->{ ${$column}[1] } =
			  $frame->Button(
				   -activebackground => $::activecolor,
				   -image            => $::lglobal{images}->{ ${$column}[1] },
				   -relief           => 'flat',
				   -borderwidth      => 0,
				   -command =>
					 [ sub { putgreek( $_[0], \%attributes ) }, ${$column}[1] ],
				   -highlightthickness => 0,
			  )->grid( -row => $row, -column => $index, -padx => 2 );
			$row++;
			$::lglobal{buttons}->{ ${$column}[2] } =
			  $frame->Button(
				   -activebackground => $::activecolor,
				   -image            => $::lglobal{images}->{ ${$column}[2] },
				   -relief           => 'flat',
				   -borderwidth      => 0,
				   -command =>
					 [ sub { putgreek( $_[0], \%attributes ) }, ${$column}[2] ],
				   -highlightthickness => 0,
			  )->grid( -row => $row, -column => $index, -padx => 2 );
			$row++;
			next unless ( ${$column}[3] );
			$::lglobal{buttons}->{ ${$column}[3] } =
			  $frame->Button(
				   -activebackground => $::activecolor,
				   -image            => $::lglobal{images}->{ ${$column}[3] },
				   -relief           => 'flat',
				   -borderwidth      => 0,
				   -command =>
					 [ sub { putgreek( $_[0], \%attributes ) }, ${$column}[3] ],
				   -highlightthickness => 0,
			  )->grid( -row => $row, -column => $index, -padx => 2 );
			$row++;
			next unless ( ${$column}[4] );
			$::lglobal{buttons}->{ ${$column}[4] } =
			  $frame->Button(
				   -activebackground => $::activecolor,
				   -image            => $::lglobal{images}->{ ${$column}[4] },
				   -relief           => 'flat',
				   -borderwidth      => 0,
				   -command =>
					 [ sub { putgreek( $_[0], \%attributes ) }, ${$column}[4] ],
				   -highlightthickness => 0,
			  )->grid( -row => $row, -column => $index, -padx => 2 );
		}
		$frame->Label(
					   -text       => 'ou',
					   -font       => $grfont,
					   -background => $::bkgcolor,
		)->grid( -row => 4, -column => 16, -padx => 2 );
		$::lglobal{buttons}->{'oulig'} =
		  $frame->Button(
						  -activebackground => $::activecolor,
						  -image            => $::lglobal{images}->{'oulig'},
						  -relief           => 'flat',
						  -borderwidth      => 0,
						  -command => sub { putgreek( 'oulig', \%attributes ) },
						  -highlightthickness => 0,
		  )->grid( -row => 5, -column => 16 );
		my $bframe =
		  $::lglobal{grpop}->Frame->pack(
										  -expand => 'yes',
										  -fill   => 'both',
										  -anchor => 'n'
		  );
		$::lglobal{grtext} =
		  $bframe->Scrolled(
							 'TextEdit',
							 -height     => 8,
							 -width      => 50,
							 -wrap       => 'word',
							 -background => $::bkgcolor,
							 -font       => $::lglobal{utffont},
							 -wrap       => 'none',
							 -setgrid    => 'true',
							 -scrollbars => 'se',
		  )->pack(
				   -expand => 'yes',
				   -fill   => 'both',
				   -anchor => 'nw',
				   -pady   => 5
		  );
		$::lglobal{grtext}->bind(
			'<FocusIn>',
			sub {
				$::lglobal{hasfocus} = $::lglobal{grtext};
			}
		);
		::drag( $::lglobal{grtext} );
		if ( $Tk::version ge 8.4 ) {
			my $bframe2 =
			  $::lglobal{grpop}->Frame( -relief => 'ridge' )
			  ->pack( -expand => 'n', -anchor => 's' );
			$bframe2->Label(
							 -text => 'Character Builder',
							 -font => $::lglobal{utffont},
			)->pack( -side => 'left', -padx => 2 );
			$buildlabel =
			  $bframe2->Label(
							   -text       => '',
							   -width      => 5,
							   -font       => $::lglobal{utffont},
							   -background => $::bkgcolor,
							   -relief     => 'ridge'
			  )->pack( -side => 'left', -padx => 2 );
			$::lglobal{buildentry} = $bframe2->Entry(
				-width      => 5,
				-font       => $::lglobal{utffont},
				-background => $::bkgcolor,
				-relief     => 'ridge',
				-validate   => 'all',
				-vcmd       => sub {
					my %hash = (
								 %{ $::lglobal{grkbeta1} },
								 %{ $::lglobal{grkbeta2} },
								 %{ $::lglobal{grkbeta3} }
					);
					%hash         = reverse %hash;
					$hash{'a'}    = "\x{3B1}";
					$hash{'A'}    = "\x{391}";
					$hash{'e'}    = "\x{3B5}";
					$hash{'E'}    = "\x{395}";
					$hash{"Ê"}   = "\x{397}";
					$hash{"ê"}   = "\x{3B7}";
					$hash{'I'}    = "\x{399}";
					$hash{'i'}    = "\x{3B9}";
					$hash{'O'}    = "\x{39F}";
					$hash{'o'}    = "\x{3BF}";
					$hash{'Y'}    = "\x{3A5}";
					$hash{'y'}    = "\x{3C5}";
					$hash{'U'}    = "\x{3A5}";
					$hash{'u'}    = "\x{3C5}";
					$hash{"Ô"}   = "\x{3A9}";
					$hash{"ô"}   = "\x{3C9}";
					$hash{'R'}    = "\x{3A1}";
					$hash{'r'}    = "\x{3C1}";
					$hash{'B'}    = "\x{392}";
					$hash{'b'}    = "\x{3B2}";
					$hash{'G'}    = "\x{393}";
					$hash{'g'}    = "\x{3B3}";
					$hash{'D'}    = "\x{394}";
					$hash{'d'}    = "\x{3B4}";
					$hash{'Z'}    = "\x{396}";
					$hash{'z'}    = "\x{3B6}";
					$hash{'K'}    = "\x{39A}";
					$hash{'k'}    = "\x{3BA}";
					$hash{'L'}    = "\x{39B}";
					$hash{'l'}    = "\x{3BB}";
					$hash{'M'}    = "\x{39C}";
					$hash{'m'}    = "\x{3BC}";
					$hash{'N'}    = "\x{39D}";
					$hash{'n'}    = "\x{3BD}";
					$hash{'X'}    = "\x{39E}";
					$hash{'x'}    = "\x{3BE}";
					$hash{'P'}    = "\x{3A0}";
					$hash{'p'}    = "\x{3C0}";
					$hash{'R'}    = "\x{3A1}";
					$hash{'r'}    = "\x{3C1}";
					$hash{'S'}    = "\x{3A3}";
					$hash{'s'}    = "\x{3C3}";
					$hash{'s '}   = "\x{3C2}";
					$hash{'T'}    = "\x{3A4}";
					$hash{'t'}    = "\x{3C4}";
					$hash{'th'}   = "\x{03B8}";
					$hash{'ng'}   = "\x{03B3}\x{03B3}";
					$hash{'nk'}   = "\x{03B3}\x{03BA}";
					$hash{'nx'}   = "\x{03B3}\x{03BE}";
					$hash{'rh'}   = "\x{1FE5}";
					$hash{'ph'}   = "\x{03C6}";
					$hash{'nch'}  = "\x{03B3}\x{03C7}";
					$hash{'nc'}   = "";
					$hash{'c'}    = "";
					$hash{'C'}    = "";
					$hash{'ch'}   = "\x{03C7}";
					$hash{'ps'}   = "\x{03C8}";
					$hash{'CH'}   = "\x{03A7}";
					$hash{'TH'}   = "\x{0398}";
					$hash{'PH'}   = "\x{03A6}";
					$hash{'PS'}   = "\x{03A8}";
					$hash{'Ch'}   = "\x{03A7}";
					$hash{'Th'}   = "\x{0398}";
					$hash{'Ph'}   = "\x{03A6}";
					$hash{'Ps'}   = "\x{03A8}";
					$hash{'e^'}   = "\x{397}";
					$hash{'E^'}   = "\x{3B7}";
					$hash{'O^'}   = "\x{3A9}";
					$hash{'o^'}   = "\x{3C9}";
					$hash{'H'}    = "\x{397}";
					$hash{'h'}    = "\x{3B7}";
					$hash{'W'}    = "\x{3A9}";
					$hash{'w'}    = "\x{3C9}";
					$hash{' '}    = ' ';
					$hash{'u\+'}  = "\x{1FE2}";
					$hash{'u/+'}  = "\x{1FE3}";
					$hash{'u~+'}  = "\x{1FE7}";
					$hash{'u/+'}  = "\x{03B0}";
					$hash{'u)\\'} = "\x{1F52}";
					$hash{'u(\\'} = "\x{1F53}";
					$hash{'u)/'}  = "\x{1F54}";
					$hash{'u(/'}  = "\x{1F55}";
					$hash{'u~)'}  = "\x{1F56}";
					$hash{'u~('}  = "\x{1F57}";
					$hash{'U(\\'} = "\x{1F5B}";
					$hash{'U(/'}  = "\x{1F5D}";
					$hash{'U~('}  = "\x{1F5F}";
					$hash{'u+'}   = "\x{03CB}";
					$hash{'U+'}   = "\x{03AB}";
					$hash{'u='}   = "\x{1FE0}";
					$hash{'u_'}   = "\x{1FE1}";
					$hash{'r)'}   = "\x{1FE4}";
					$hash{'r('}   = "\x{1FE5}";
					$hash{'u~'}   = "\x{1FE6}";
					$hash{'U='}   = "\x{1FE8}";
					$hash{'U_'}   = "\x{1FE9}";
					$hash{'U\\'}  = "\x{1FEA}";
					$hash{'U/'}   = "\x{1FEB}";
					$hash{'u\\'}  = "\x{1F7A}";
					$hash{'u/'}   = "\x{1F7B}";
					$hash{'u)'}   = "\x{1F50}";
					$hash{'u('}   = "\x{1F51}";
					$hash{'U('}   = "\x{1F59}";

					if ( ( $_[0] eq '' ) or ( exists $hash{ $_[0] } ) ) {
						$buildlabel->configure( -text => $hash{ $_[0] } );
						return 1;
					}
				}
			)->pack( -side => 'left', -padx => 2 );
			$::lglobal{buildentry}->bind(
				'<FocusIn>',
				sub {
					$::lglobal{hasfocus} = $::lglobal{buildentry};
				}
			);
			$::lglobal{buildentry}->bind(
				$::lglobal{buildentry},
				'<Return>',
				sub {
					my $index = $::lglobal{grtext}->index('insert');
					$index = 'end' unless $index;
					my $char = $buildlabel->cget( -text );
					$char = "\n" unless $char;
					$::lglobal{grtext}->insert( $index, $char );
					$::lglobal{grtext}->markSet( 'insert', "$index+1c" );
					$::lglobal{buildentry}->delete( '0', 'end' );
					$::lglobal{buildentry}->focus;
				}
			);
			$::lglobal{buildentry}->bind(
				$::lglobal{buildentry},
				'<asciicircum>',
				sub {
					my $string = $::lglobal{buildentry}->get;
					if ( $string =~ /(O\^|o\^|E\^|e\^)/ ) {
						$string =~ tr/OoEe/ÔôÊê/;
						$string =~ s/\^//;
					}
					$::lglobal{buildentry}->delete( '0', 'end' );
					$::lglobal{buildentry}->insert( 'end', $string );
				}
			);
			$::lglobal{buildentry}
			  ->eventAdd( '<<alias>>' => '<h>', '<H>', '<w>', '<W>' );
			$::lglobal{buildentry}->bind(
				$::lglobal{buildentry},
				'<<alias>>',
				sub {
					my $string = $::lglobal{buildentry}->get;
					if ( $string =~ /(^h$|^H$|^w$|^W$)/ ) {
						$string =~ tr/WwHh/ÔôÊê/;
						$::lglobal{buildentry}->delete( '0', 'end' );
						$::lglobal{buildentry}->insert( 'end', $string );
					}
				}
			);
			$::lglobal{buildentry}->bind(
				$::lglobal{buildentry},
				'<BackSpace>',
				sub {
					if ( $::lglobal{buildentry}->get ) {
						$::lglobal{buildentry}->delete('insert');
					} else {
						$::lglobal{grtext}->delete( 'insert -1c', 'insert' );
					}
				}
			);
			for (qw!( ) / \ | ~ + = _!) {
				$bframe2->Button(
								  -activebackground => $::activecolor,
								  -text             => $_,
								  -font             => $::lglobal{utffont},
								  -borderwidth      => 0,
								  -command          => \&placechar,
				)->pack( -side => 'left', -padx => 1 );
			}
		}
		$::lglobal{grpop}->protocol(
			'WM_DELETE_WINDOW' => sub {
				$textwindow->tagRemove( 'highlight', '1.0', 'end' );
				movegreek();
				for my $image ( keys %attributes ) {
					my $pic = $::lglobal{buttons}->{$image}->cget( -image );
					$pic->delete;
					$::lglobal{buttons}->{$image}->destroy;
				}
				%attributes = ();
				$::lglobal{grpop}->destroy;
				undef $::lglobal{grpop};
			}
		);
		$glatin->select;
		$::lglobal{grtext}->SetGUICallbacks( [] );
	}
}

sub findmatchingclosebracket {
	my $textwindow   = $::textwindow;
	my ($startIndex) = @_;
	my $indentLevel  = 1;
	my $closeIndex;
	while ($indentLevel) {
		$closeIndex =
		  $textwindow->search( '-exact', '--', ']', "$startIndex" . '+1c',
							   'end' );
		my $openIndex =
		  $textwindow->search( '-exact', '--', '[', "$startIndex" . '+1c',
							   'end' );
		if ( !$closeIndex ) {

			# no matching ]
			return $startIndex;
		}
		if ( !$openIndex ) {

			# no [
			return $closeIndex;
		}
		if ( $textwindow->compare( $openIndex, '<', $closeIndex ) ) {
			$indentLevel++;
			$startIndex = $openIndex;
		} else {
			$indentLevel--;
			$startIndex = $closeIndex;
		}
	}
	return $closeIndex;
}

sub findgreek {
	my $startIndex = shift;
	my $textwindow = $::textwindow;
	$startIndex = $textwindow->index($startIndex);
	my $chars;
	my $greekIndex =
	  $textwindow->search( '-exact', '--', '[Greek:', "$startIndex", 'end' );
	if ($greekIndex) {
		my $closeIndex = findmatchingclosebracket($greekIndex);
		return ( $greekIndex, $closeIndex );
	} else {
		return ( $greekIndex, $greekIndex );
	}
}

# Puts Greek character into the Greek popup
sub putgreek {
	my ( $attrib, $hash ) = @_;
	my $textwindow = $::textwindow;
	my $letter;
	$letter = $$hash{$attrib}[0]       if ( $::lglobal{groutp} eq 'l' );
	$letter = $$hash{$attrib}[1] . ' ' if ( $::lglobal{groutp} eq 'n' );
	$letter = $$hash{$attrib}[2]       if ( $::lglobal{groutp} eq 'h' );
	$letter = $$hash{$attrib}[3]       if ( $::lglobal{groutp} eq 'u' );
	my $spot = $::lglobal{grtext}->index('insert');

	if ( $::lglobal{groutp} eq 'l' and $letter eq 'y' or $letter eq 'Y' ) {
		if ( $::lglobal{grtext}->get('insert -1c') =~ /[AEIOUaeiou]/ ) {
			$letter = chr( ord($letter) - 4 );
		}
	}
	$::lglobal{grtext}->insert( 'insert', $letter );
	$::lglobal{grtext}
	  ->markSet( 'insert', $spot . '+' . length($letter) . 'c' );
	$::lglobal{grtext}->focus;
	$::lglobal{grtext}->see('insert');
}

sub movegreek {
	my $textwindow = $::textwindow;
	my $phrase = $::lglobal{grtext}->get( '1.0', 'end' );
	$::lglobal{grtext}->delete( '1.0', 'end' );
	chomp $phrase;
	$textwindow->insert( 'insert', $phrase );
}

sub placechar {
	my ( $widget, @xy, $letter );
	@xy     = $::lglobal{grpop}->pointerxy;
	$widget = $::lglobal{grpop}->containing(@xy);
	my $char = $widget->cget( -text );
	$char =~ s/\s//;
	if ( $char =~ /[AaEeÊêIiOoYyÔôRr]/ ) {
		$::lglobal{buildentry}->delete( '0', 'end' );
		$::lglobal{buildentry}->insert( 'end', $char );
		$::lglobal{buildentry}->focus;
	}
	if ( $char =~ /[\(\)\\\/\|~+=_]/ ) {
		$::lglobal{buildentry}->insert( 'end', $char );
		$::lglobal{buildentry}->focus;
	}
}

sub togreektr {
	my $phrase = shift;
	$phrase =~ s/s($|\W)/\x{03C2}$1/g;
	$phrase =~ s/th/\x{03B8}/g;
	$phrase =~ s/nch/\x{03B3}\x{03C7}/g;
	$phrase =~ s/ch/\x{03C7}/g;
	$phrase =~ s/ph/\x{03C6}/g;
	$phrase =~ s/CH/\x{03A7}/gi;
	$phrase =~ s/TH/\x{0398}/gi;
	$phrase =~ s/PH/\x{03A6}/gi;
	$phrase =~ s/ng/\x{03B3}\x{03B3}/g;
	$phrase =~ s/nk/\x{03B3}\x{03BA}/g;
	$phrase =~ s/nx/\x{03B3}\x{03BE}/g;
	$phrase =~ s/rh/\x{1FE5}/g;
	$phrase =~ s/ps/\x{03C8}/g;
	$phrase =~ s/ha/\x{1F01}/g;
	$phrase =~ s/he/\x{1F11}/g;
	$phrase =~ s/hê/\x{1F21}/g;
	$phrase =~ s/hi/\x{1F31}/g;
	$phrase =~ s/ho/\x{1F41}/g;
	$phrase =~ s/hy/\x{1F51}/g;
	$phrase =~ s/hô/\x{1F61}/g;
	$phrase =~ s/ou/\x{03BF}\x{03C5}/g;
	$phrase =~ s/PS/\x{03A8}/gi;
	$phrase =~ s/HA/\x{1F09}/gi;
	$phrase =~ s/HE/\x{1F19}/gi;
	$phrase =~ s/HÊ|Hê/\x{1F29}/g;
	$phrase =~ s/HI/\x{1F39}/gi;
	$phrase =~ s/HO/\x{1F49}/gi;
	$phrase =~ s/HY/\x{1F59}/gi;
	$phrase =~ s/HÔ|Hô/\x{1F69}/g;
	$phrase =~ s/A/\x{0391}/g;
	$phrase =~ s/a/\x{03B1}/g;
	$phrase =~ s/B/\x{0392}/g;
	$phrase =~ s/b/\x{03B2}/g;
	$phrase =~ s/G/\x{0393}/g;
	$phrase =~ s/g/\x{03B3}/g;
	$phrase =~ s/D/\x{0394}/g;
	$phrase =~ s/d/\x{03B4}/g;
	$phrase =~ s/E/\x{0395}/g;
	$phrase =~ s/e/\x{03B5}/g;
	$phrase =~ s/Z/\x{0396}/g;
	$phrase =~ s/z/\x{03B6}/g;
	$phrase =~ s/Ê/\x{0397}/g;
	$phrase =~ s/ê/\x{03B7}/g;
	$phrase =~ s/I/\x{0399}/g;
	$phrase =~ s/i/\x{03B9}/g;
	$phrase =~ s/K/\x{039A}/g;
	$phrase =~ s/k/\x{03BA}/g;
	$phrase =~ s/L/\x{039B}/g;
	$phrase =~ s/l/\x{03BB}/g;
	$phrase =~ s/M/\x{039C}/g;
	$phrase =~ s/m/\x{03BC}/g;
	$phrase =~ s/N/\x{039D}/g;
	$phrase =~ s/n/\x{03BD}/g;
	$phrase =~ s/X/\x{039E}/g;
	$phrase =~ s/x/\x{03BE}/g;
	$phrase =~ s/O/\x{039F}/g;
	$phrase =~ s/o/\x{03BF}/g;
	$phrase =~ s/P/\x{03A0}/g;
	$phrase =~ s/p/\x{03C0}/g;
	$phrase =~ s/R/\x{03A1}/g;
	$phrase =~ s/r/\x{03C1}/g;
	$phrase =~ s/S/\x{03A3}/g;
	$phrase =~ s/s/\x{03C3}/g;
	$phrase =~ s/T/\x{03A4}/g;
	$phrase =~ s/t/\x{03C4}/g;
	$phrase =~ s/Y/\x{03A5}/g;
	$phrase =~ s/y/\x{03C5}/g;
	$phrase =~ s/U/\x{03A5}/g;
	$phrase =~ s/u/\x{03C5}/g;
	$phrase =~ s/Ô/\x{03A9}/g;
	$phrase =~ s/ô/\x{03C9}/g;
	$phrase =~ s/\?/\x{037E}/g;
	$phrase =~ s/;/\x{0387}/g;
	return $phrase;
}

sub betagreek {
	my ( $direction, $phrase ) = @_;
	if ( $direction eq 'unicode' ) {
		$phrase =~ s/s(\s|\n|$)/\x{03C2}$1/g;
		$phrase =~ s/th/\x{03B8}/g;
		$phrase =~ s/ph/\x{03C6}/g;
		$phrase =~ s/TH/\x{0398}/gi;
		$phrase =~ s/PH/\x{03A6}/gi;
		$phrase =~ s/u\\\+/\x{1FE2}/g;
		$phrase =~ s/u\/\+/\x{1FE3}/g;
		$phrase =~ s/u~\+/\x{1FE7}/g;
		$phrase =~ s/u\/\+/\x{03B0}/g;
		$phrase =~ s/u\)\\/\x{1F52}/g;
		$phrase =~ s/u\(\\/\x{1F53}/g;
		$phrase =~ s/u\)\//\x{1F54}/g;
		$phrase =~ s/u\(\//\x{1F55}/g;
		$phrase =~ s/u~\)/\x{1F56}/g;
		$phrase =~ s/u~\(/\x{1F57}/g;
		$phrase =~ s/U\(\\/\x{1F5B}/g;
		$phrase =~ s/U\(\//\x{1F5D}/g;
		$phrase =~ s/U~\(/\x{1F5F}/g;
		$phrase =~ s/u\+/\x{03CB}/g;
		$phrase =~ s/U\+/\x{03AB}/g;
		$phrase =~ s/u=/\x{1FE0}/g;
		$phrase =~ s/u_/\x{1FE1}/g;
		$phrase =~ s/r\)/\x{1FE4}/g;
		$phrase =~ s/r\(/\x{1FE5}/g;
		$phrase =~ s/u~/\x{1FE6}/g;
		$phrase =~ s/U=/\x{1FE8}/g;
		$phrase =~ s/U_/\x{1FE9}/g;
		$phrase =~ s/U\\/\x{1FEA}/g;
		$phrase =~ s/U\//\x{1FEB}/g;
		$phrase =~ s/u\\/\x{1F7A}/g;
		$phrase =~ s/u\//\x{1F7B}/g;
		$phrase =~ s/u\)/\x{1F50}/g;
		$phrase =~ s/u\(/\x{1F51}/g;
		$phrase =~ s/U\(/\x{1F59}/g;
		$phrase =~ s/\?/\x{037E}/g;
		$phrase =~ s/;/\x{0387}/g;
		my %atebkrg = reverse %{ $::lglobal{grkbeta3} };

		for ( keys %atebkrg ) {
			$phrase =~ s/\Q$_\E/$atebkrg{$_}/g;
		}
		%atebkrg = reverse %{ $::lglobal{grkbeta2} };
		for ( keys %atebkrg ) {
			$phrase =~ s/\Q$_\E/$atebkrg{$_}/g;
		}
		%atebkrg = reverse %{ $::lglobal{grkbeta1} };
		for ( keys %atebkrg ) {
			$phrase =~ s/\Q$_\E/$atebkrg{$_}/g;
		}
		return togreektr($phrase);
	} else {
		for ( keys %{ $::lglobal{grkbeta1} } ) {
			$phrase =~ s/$_/$::lglobal{grkbeta1}{$_}/g;
		}
		for ( keys %{ $::lglobal{grkbeta2} } ) {
			$phrase =~ s/$_/$::lglobal{grkbeta2}{$_}/g;
		}
		for ( keys %{ $::lglobal{grkbeta3} } ) {
			$phrase =~ s/$_/$::lglobal{grkbeta3}{$_}/g;
		}
		$phrase =~ s/\x{0386}/A\//g;
		$phrase =~ s/\x{0388}/E\//g;
		$phrase =~ s/\x{0389}/Ê\//g;
		$phrase =~ s/\x{038C}/O\//g;
		$phrase =~ s/\x{038E}/Y\//g;
		$phrase =~ s/\x{038F}/Ô\//g;
		$phrase =~ s/\x{03AC}/a\//g;
		$phrase =~ s/\x{03AD}/e\//g;
		$phrase =~ s/\x{03AE}/ê\//g;
		$phrase =~ s/\x{03AF}/i\//g;
		$phrase =~ s/\x{03CC}/o\//g;
		$phrase =~ s/\x{03CE}/ô\//g;
		$phrase =~ s/\x{03CD}/y\//g;
		$phrase =~ s/\x{037E}/?/g;
		$phrase =~ s/\x{0387}/;/g;
		return fromgreektr($phrase);
	}
}

sub betaascii {

	# Discards the accents
	my ($phrase) = @_;
	$phrase =~ s/[\)\/\\\|\~\+=_]//g;
	$phrase =~ s/r\(/rh/g;
	$phrase =~ s/([AEIOUYÊÔ])\(/H$1/g;
	$phrase =~ s/([aeiouyêô]+)\(/h$1/g;
	return $phrase;
}
1;
