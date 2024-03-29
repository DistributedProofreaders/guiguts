package Guiguts::Greek;
use strict;
use warnings;

BEGIN {
    use Exporter();
    our ( @ISA, @EXPORT );
    @ISA    = qw(Exporter);
    @EXPORT = qw(&greekpopup &findandextractgreek &betagreek &greekbeta);
}

#
# Convert simple Greek characters in string to betacode ("ASCII")
sub fromgreektr {
    my $phrase = shift;
    $phrase =~ s/\x{03DA}/St/g;
    $phrase =~ s/\x{03DB}/st/g;
    $phrase =~ s/\x{0223}/ou/g;
    $phrase =~ s/\x{03B3}\x{03B3}/ng/g;
    $phrase =~ s/\x{0393}\x{0393}/NG/g;
    $phrase =~ s/\x{03B3}\x{03BA}/nk/g;
    $phrase =~ s/\x{0393}\x{039A}/NK/g;
    $phrase =~ s/\x{0393}\x{03BE}/nx/g;
    $phrase =~ s/\x{0393}\x{03BE}/NX/g;
    $phrase =~ s/\x{03B3}\x{03C7}/nch/g;
    $phrase =~ s/\x{0393}\x{03A7}/NCH/g;
    $phrase =~ s/\x{1F09}/Ha/g;                            #Not needed as already in grkbeta1
    $phrase =~ s/\x{1F01}/ha/g;                            #Not needed as already in grkbeta1
    $phrase =~ s/\x{1F19}/He/g;                            #Not needed as already in grkbeta1
    $phrase =~ s/\x{1F11}/he/g;                            #Not needed as already in grkbeta1
    $phrase =~ s/\x{1F29}/H�/g;                            #Not needed as already in grkbeta1
    $phrase =~ s/\x{1F21}/h�/g;                            #Not needed as already in grkbeta1
    $phrase =~ s/\x{1F39}/Hi/g;                            #Not needed as already in grkbeta1
    $phrase =~ s/\x{1F31}/hi/g;                            #Not needed as already in grkbeta1
    $phrase =~ s/\x{1F49}/Ho/g;                            #Not needed as already in grkbeta1
    $phrase =~ s/\x{1F41}/ho/g;                            #Not needed as already in grkbeta1
    $phrase =~ s/\x{1F59}/Hy/g;                            #Not needed as already in grkbeta1
    $phrase =~ s/\x{1F51}/hy/g;                            #Not needed as already in grkbeta1
    $phrase =~ s/\x{1F69}/H�/g;                            #Not needed as already in grkbeta1
    $phrase =~ s/\x{1F61}/h�/g;                            #Not needed as already in grkbeta1
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
    $phrase =~ s/\x{0397}/�/g;
    $phrase =~ s/\x{03B7}/�/g;
    $phrase =~ s/\x{0398}/Th/g;
    $phrase =~ s/\x{03B8}/th/g;
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
    $phrase =~ s/\x{03C2}/s/g;
    $phrase =~ s/\x{03A4}/T/g;
    $phrase =~ s/\x{03C4}/t/g;
    $phrase =~ s/\x{03A5}/Y/g;
    $phrase =~ s/\x{03C5}/y/g;
    $phrase =~ s/yi/ui/g;
    $phrase =~ s/YI/UI/g;
    $phrase =~ s/Yi/Ui/g;
    $phrase =~ s/([ae�o])y/$1u/g;
    $phrase =~ s/([AE�O])Y/$1U/g;
    $phrase =~ s/([AE�O])y/$1u/g;
    $phrase =~ s/\x{03A6}/Ph/g;
    $phrase =~ s/\x{03C6}/ph/g;
    $phrase =~ s/\x{03A7}/Ch/g;
    $phrase =~ s/\x{03C7}/ch/g;
    $phrase =~ s/\x{03A8}/Ps/g;
    $phrase =~ s/\x{03C8}/ps/g;
    $phrase =~ s/\x{03A9}/�/g;
    $phrase =~ s/\x{03C9}/�/g;
    $phrase =~ s/\x{03AA}/�/g;
    $phrase =~ s/\x{03CA}/�/g;
    $phrase =~ s/\x{03AB}/�/g;
    $phrase =~ s/\x{03CB}/�/g;
    $phrase =~ s/\x{03D8}/J/g;
    $phrase =~ s/\x{03D9}/j/g;
    $phrase =~ s/\x{03DC}/W/g;
    $phrase =~ s/\x{03DD}/w/g;
    $phrase =~ s/\x{03DE}/Q/g;
    $phrase =~ s/\x{03DF}/q/g;
    $phrase =~ s/\x{03E0}/C/g;
    $phrase =~ s/\x{03E1}/c/g;
    $phrase =~ s/\x{037E}/?/g;                             #�Not needed? as already in betagreek(b)
    $phrase =~ s/\x{0387}/;/g;                             #�Not needed? as already in betagreek(b)
    $phrase =~ s/(\p{Upper}\p{Lower}\p{Upper})/\U$1\E/g;
    return $phrase;
}

#
# Find next Greek phrase in text & load into Greek dialog
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
        $::lglobal{grtextoriginal} = $text;
    }
}

#
# Pop the Greek transcription/creation dialog
sub greekpopup {
    if ( defined( $::lglobal{grpop} ) ) {
        $::lglobal{grpop}->deiconify;
        $::lglobal{grpop}->raise;
        $::lglobal{grpop}->focus;
        return;
    }
    my $top        = $::top;
    my $textwindow = $::textwindow;
    my @greek      = (
        [ 'a',   'calpha',   'lalpha',   'chalpha',   'halpha' ],
        [ 'b',   'cbeta',    'lbeta',    '',          '' ],
        [ 'g',   'cgamma',   'lgamma',   'ng',        '' ],
        [ 'd',   'cdelta',   'ldelta',   '',          '' ],
        [ 'e',   'cepsilon', 'lepsilon', 'chepsilon', 'hepsilon' ],
        [ 'z',   'czeta',    'lzeta',    '',          '' ],
        [ '�',   'ceta',     'leta',     'cheta',     'heta' ],
        [ 'th',  'ctheta',   'ltheta',   '',          '' ],
        [ 'i',   'ciota',    'liota',    'chiota',    'hiota' ],
        [ 'k',   'ckappa',   'lkappa',   'nk',        '' ],
        [ 'l',   'clambda',  'llambda',  '',          '' ],
        [ 'm',   'cmu',      'lmu',      '',          '' ],
        [ 'n',   'cnu',      'lnu',      '',          '' ],
        [ 'x',   'cxi',      'lxi',      'nx',        '' ],
        [ 'o',   'comicron', 'lomicron', 'chomicron', 'homicron' ],
        [ 'p',   'cpi',      'lpi',      '',          'oulig' ],
        [ 'r',   'crho',     'lrho',     'hrho',      '' ],
        [ 's',   'csigma',   'lsigma',   'lsigmae',   '' ],
        [ 't',   'ctau',     'ltau',     '',          '' ],
        [ 'y/u', 'cupsilon', 'lupsilon', 'chupsilon', 'hupsilon' ],
        [ 'ph',  'cphi',     'lphi',     '',          '' ],
        [ 'ch',  'cchi',     'lchi',     'nch',       '' ],
        [ 'ps',  'cpsi',     'lpsi',     '',          '' ],
        [ '�',   'comega',   'lomega',   'chomega',   'homega' ],
        [ 'st',  'cstigma',  'lstigma',  '',          '' ],
        [ 'w',   'cdigamma', 'ldigamma', '',          '' ],
        [ 'q',   'cqoppa',   'lqoppa',   '',          '' ],
        [ 'c',   'csampi',   'lsampi',   '',          '' ],
        [ 'j',   'ckoppa',   'lkoppa',   '',          '' ]
    );
    my %attributes = (
        'calpha'    => [ 'A',   'Alpha',       '&#913;',       "\x{0391}" ],
        'lalpha'    => [ 'a',   'alpha',       '&#945;',       "\x{03B1}" ],
        'chalpha'   => [ 'Ha',  'Alpha',       '&#7945;',      "\x{1F09}" ],
        'halpha'    => [ 'ha',  'alpha',       '&#7937;',      "\x{1F01}" ],
        'cbeta'     => [ 'B',   'Beta',        '&#914;',       "\x{0392}" ],
        'lbeta'     => [ 'b',   'beta',        '&#946;',       "\x{03B2}" ],
        'cgamma'    => [ 'G',   'Gamma',       '&#915;',       "\x{0393}" ],
        'lgamma'    => [ 'g',   'gamma',       '&#947;',       "\x{03B3}" ],
        'ng'        => [ 'ng',  'gamma gamma', '&#947;&#947;', "\x{03B3}\x{03B3}" ],
        'cdelta'    => [ 'D',   'Delta',       '&#916;',       "\x{0394}" ],
        'ldelta'    => [ 'd',   'delta',       '&#948;',       "\x{03B4}" ],
        'cepsilon'  => [ 'E',   'Epsilon',     '&#917;',       "\x{0395}" ],
        'lepsilon'  => [ 'e',   'epsilon',     '&#949;',       "\x{03B5}" ],
        'chepsilon' => [ 'He',  'Epsilon',     '&#7961;',      "\x{1F19}" ],
        'hepsilon'  => [ 'he',  'epsilon',     '&#7953;',      "\x{1F11}" ],
        'czeta'     => [ 'Z',   'Zeta',        '&#918;',       "\x{0396}" ],
        'lzeta'     => [ 'z',   'zeta',        '&#950;',       "\x{03B6}" ],
        'ceta'      => [ '�',   'Eta',         '&#919;',       "\x{0397}" ],
        'leta'      => [ '�',   'eta',         '&#951;',       "\x{03B7}" ],
        'cheta'     => [ 'H�',  'Eta',         '&#7977;',      "\x{1F29}" ],
        'heta'      => [ 'h�',  'eta',         '&#7969;',      "\x{1F21}" ],
        'ctheta'    => [ 'Th',  'Theta',       '&#920;',       "\x{0398}" ],
        'ltheta'    => [ 'th',  'theta',       '&#952;',       "\x{03B8}" ],
        'ciota'     => [ 'I',   'Iota',        '&#921;',       "\x{0399}" ],
        'liota'     => [ 'i',   'iota',        '&#953;',       "\x{03B9}" ],
        'chiota'    => [ 'Hi',  'Iota',        '&#7993;',      "\x{1F39}" ],
        'hiota'     => [ 'hi',  'iota',        '&#7985;',      "\x{1F31}" ],
        'ckappa'    => [ 'K',   'Kappa',       '&#922;',       "\x{039A}" ],
        'lkappa'    => [ 'k',   'kappa',       '&#954;',       "\x{03BA}" ],
        'nk'        => [ 'nk',  'gamma kappa', '&#947;&#954;', "\x{03B3}\x{03BA}" ],
        'clambda'   => [ 'L',   'Lambda',      '&#923;',       "\x{039B}" ],
        'llambda'   => [ 'l',   'lambda',      '&#955;',       "\x{03BB}" ],
        'cmu'       => [ 'M',   'Mu',          '&#924;',       "\x{039C}" ],
        'lmu'       => [ 'm',   'mu',          '&#956;',       "\x{03BC}" ],
        'cnu'       => [ 'N',   'Nu',          '&#925;',       "\x{039D}" ],
        'lnu'       => [ 'n',   'nu',          '&#957;',       "\x{03BD}" ],
        'cxi'       => [ 'X',   'Xi',          '&#926;',       "\x{039E}" ],
        'lxi'       => [ 'x',   'xi',          '&#958;',       "\x{03BE}" ],
        'nx'        => [ 'nx',  'gamma xi',    '&#947;&#958;', "\x{03B3}\x{03BE}" ],
        'comicron'  => [ 'O',   'Omicron',     '&#927;',       "\x{039F}" ],
        'lomicron'  => [ 'o',   'omicron',     '&#959;',       "\x{03BF}" ],
        'chomicron' => [ 'Ho',  'Omicron',     '&#8009;',      "\x{1F49}" ],
        'homicron'  => [ 'ho',  'omicron',     '&#8001;',      "\x{1F41}" ],
        'cpi'       => [ 'P',   'Pi',          '&#928;',       "\x{03A0}" ],
        'lpi'       => [ 'p',   'pi',          '&#960;',       "\x{03C0}" ],
        'crho'      => [ 'R',   'Rho',         '&#929;',       "\x{03A1}" ],
        'lrho'      => [ 'r',   'rho',         '&#961;',       "\x{03C1}" ],
        'hrho'      => [ 'rh',  'rho',         '&#8165;',      "\x{1FE5}" ],
        'csigma'    => [ 'S',   'Sigma',       '&#931;',       "\x{03A3}" ],
        'lsigma'    => [ 's',   'sigma',       '&#963;',       "\x{03C3}" ],
        'lsigmae'   => [ 's',   'sigma',       '&#962;',       "\x{03C2}" ],
        'ctau'      => [ 'T',   'Tau',         '&#932;',       "\x{03A4}" ],
        'ltau'      => [ 't',   'tau',         '&#964;',       "\x{03C4}" ],
        'cupsilon'  => [ 'Y',   'Upsilon',     '&#933;',       "\x{03A5}" ],
        'lupsilon'  => [ 'y',   'upsilon',     '&#965;',       "\x{03C5}" ],
        'chupsilon' => [ 'Hy',  'Upsilon',     '&#8025;',      "\x{1F59}" ],
        'hupsilon'  => [ 'hy',  'upsilon',     '&#8017;',      "\x{1F51}" ],
        'cphi'      => [ 'Ph',  'Phi',         '&#934;',       "\x{03A6}" ],
        'lphi'      => [ 'ph',  'phi',         '&#966;',       "\x{03C6}" ],
        'cchi'      => [ 'Ch',  'Chi',         '&#935;',       "\x{03A7}" ],
        'lchi'      => [ 'ch',  'chi',         '&#967;',       "\x{03C7}" ],
        'nch'       => [ 'nch', 'gamma chi',   '&#947;&#967;', "\x{03B3}\x{03C7}" ],
        'cpsi'      => [ 'Ps',  'Psi',         '&#936;',       "\x{03A8}" ],
        'lpsi'      => [ 'ps',  'psi',         '&#968;',       "\x{03C8}" ],
        'comega'    => [ '�',   'Omega',       '&#937;',       "\x{03A9}" ],
        'lomega'    => [ '�',   'omega',       '&#969;',       "\x{03C9}" ],
        'chomega'   => [ 'H�',  'Omega',       '&#8041;',      "\x{1F69}" ],
        'homega'    => [ 'h�',  'omega',       '&#8033;',      "\x{1F61}" ],
        'cstigma'   => [ 'St',  'Stigma',      '&#986;',       "\x{03DA}" ],
        'lstigma'   => [ 'st',  'stigma',      '&#987;',       "\x{03DB}" ],
        'cdigamma'  => [ 'W',   'Digamma',     '&#988;',       "\x{03DC}" ],
        'ldigamma'  => [ 'w',   'digamma',     '&#989;',       "\x{03DD}" ],
        'cqoppa'    => [ 'Q',   'Qoppa',       '&#990;',       "\x{03DE}" ],
        'lqoppa'    => [ 'q',   'qoppa',       '&#991;',       "\x{03DF}" ],
        'csampi'    => [ 'C',   'Sampi',       '&#992;',       "\x{03E0}" ],
        'lsampi'    => [ 'c',   'sampi',       '&#993;',       "\x{03E1}" ],
        'ckoppa'    => [ 'J',   'AKoppa',      '&#984;',       "\x{03D8}" ],
        'lkoppa'    => [ 'j',   'akoppa',      '&#985;',       "\x{03D9}" ],
        'oulig'     => [ 'ou',  'oulig',       '&#547;',       "\x{0223}" ]
    );
    $::lglobal{grpop} = $top->Toplevel;
    ::initialize_popup_without_deletebinding('grpop');
    $::lglobal{grpop}->title('Greek Transliteration');

    # Radio buttons determine type of input obtained by pressing letter buttons
    my $tframe = $::lglobal{grpop}->Frame->pack( -expand => 'no', -fill => 'none', -anchor => 'n' );
    $tframe->Radiobutton(
        -variable => \$::lglobal{groutp},
        -value    => 'l',
        -text     => 'Latin-1',
    )->grid( -row => 1, -column => 1 );
    $tframe->Radiobutton(
        -variable => \$::lglobal{groutp},
        -value    => 'n',
        -text     => 'Greek Name',
    )->grid( -row => 1, -column => 2 );
    $tframe->Radiobutton(
        -variable => \$::lglobal{groutp},
        -value    => 'h',
        -text     => 'HTML code',
    )->grid( -row => 1, -column => 3 );
    $tframe->Radiobutton(
        -variable => \$::lglobal{groutp},
        -value    => 'u',
        -text     => 'UTF-8',
    )->grid( -row => 1, -column => 4 );

    # Fill frame with Greek letter buttons - first row consists of labels
    my $frame = $::lglobal{grpop}->Frame( -background => $::bkgcolor )
      ->pack( -expand => 'no', -fill => 'none', -anchor => 'n' );
    my $index = 0;
    for my $column (@greek) {
        $index++;
        my $row = 1;
        greekpopuplabel( $frame, $row, $index, $$column[ $row - 1 ] );
        for $row ( 2 .. 5 ) {
            greekpopupbutton( $frame, $row, $index, $attributes{ $$column[ $row - 1 ] } );
        }
    }

    # Just above the Greek ou ligature button in the pi column, add an English ou label
    greekpopuplabel( $frame, 4, 16, 'ou' );

    # Character builder widgets
    my $bframe2 =
      $::lglobal{grpop}->Frame( -relief => 'ridge' )
      ->pack( -expand => 'n', -fill => 'none', -anchor => 'n' );
    $bframe2->Label( -text => 'Character Builder', )->pack( -side => 'left', -padx => 2 );
    $::lglobal{buildlabel} = $bframe2->Label(
        -text       => '',
        -width      => 5,
        -font       => 'unicode',
        -background => $::bkgcolor,
        -relief     => 'ridge'
    )->pack( -side => 'left', -padx => 2 );
    $::lglobal{buildentry} = $bframe2->Entry(
        -width    => 5,
        -font     => 'unicode',
        -validate => 'all',
        -vcmd     => \&buildvalidator,
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
            my $char = $::lglobal{buildlabel}->cget( -text );
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
                $string =~ tr/OoEe/����/;
                $string =~ s/\^//;
            }
            $::lglobal{buildentry}->delete( '0', 'end' );
            $::lglobal{buildentry}->insert( 'end', $string );
        }
    );
    $::lglobal{buildentry}->eventAdd( '<<alias>>' => '<h>', '<H>', '<w>', '<W>' );
    $::lglobal{buildentry}->bind(
        $::lglobal{buildentry},
        '<<alias>>',
        sub {
            my $string = $::lglobal{buildentry}->get;
            if ( $string =~ /(^h$|^H$|^w$|^W$)/ ) {
                $string =~ tr/WwHh/����/;
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
            -text        => $_,
            -font        => 'unicode',
            -borderwidth => 0,
            -command     => \&placechar,
        )->pack( -side => 'left' );
    }
    $bframe2->Button(
        -command => sub {
            my $spot = $::lglobal{grtext}->index('insert');
            $::lglobal{grtext}->insert( 'insert', ' ' );
            $::lglobal{grtext}->markSet( 'insert', "$spot+1c" );
            $::lglobal{grtext}->focus;
            $::lglobal{grtext}->see('insert');
        },
        -text => 'Space',
    )->pack( -side => 'left', -padx => 20 );

    # Main Greek text edit widget
    my $bframe = $::lglobal{grpop}->Frame->pack(
        -expand => 'yes',
        -fill   => 'both',
        -anchor => 'n'
    );
    $::lglobal{grtext} = $bframe->Scrolled(
        'TextEdit',
        -height     => 8,
        -width      => 50,
        -background => $::bkgcolor,
        -font       => 'unicode',
        -wrap       => 'none',
        -scrollbars => 'se',
    )->pack(
        -expand => 'yes',
        -fill   => 'both',
        -pady   => 5
    );
    $::lglobal{grtext}->bind(
        '<FocusIn>',
        sub {
            $::lglobal{hasfocus} = $::lglobal{grtext};
        }
    );
    ::drag( $::lglobal{grtext} );

    # Convert contents of text widget from one form to the other
    my $tframe2 = $::lglobal{grpop}->Frame->pack(
        -expand => 'no',
        -fill   => 'none',
        -anchor => 'n',
        -pady   => 3
    );
    $tframe2->Button(
        -command => sub { greekpopuptranslate( \&togreektr ); },
        -text    => 'ASCII->Greek',
    )->pack( -side => 'left', -padx => 5 );
    $tframe2->Button(
        -command => sub { greekpopuptranslate( \&fromgreektr ); },
        -text    => 'Greek->ASCII',
    )->pack( -side => 'left', -padx => 5 );
    $tframe2->Button(
        -command => sub { greekpopuptranslate( \&bettergreek ); },
        -text    => 'Beta code->Unicode',
    )->pack( -side => 'left', -padx => 5 );
    $tframe2->Button(
        -command => sub { greekpopuptranslate( \&greekbetter ); },
        -text    => 'Unicode->Beta code',
    )->pack( -side => 'left', -padx => 5 );

    my $oframe = $::lglobal{grpop}
      ->Frame->pack( -expand => 'no', -fill => 'none', -anchor => 's', -pady => 3 );

    $oframe->Button(
        -command => \&movegreek,
        -text    => 'Transfer',
    )->pack( -side => 'left', -padx => 5 );
    $oframe->Button(
        -command => sub { movegreek(); findandextractgreek(); },
        -text    => 'Transfer & Get Next',
    )->pack( -side => 'left', -padx => 5 );

    $oframe->Button(
        -command => sub {
            $textwindow->tagRemove( 'highlight', '1.0', 'end' );
            movegreek();
            %attributes = ();
            ::killpopup('grpop');
        },
        -text => 'OK',
    )->pack( -side => 'left', -padx => 10 );
    my $cancel = $oframe->Button(
        -command => sub {
            $textwindow->tagRemove( 'highlight', '1.0', 'end' );
            %attributes = ();
            ::killpopup('grpop');
            $textwindow->insert( 'insert', $::lglobal{grtextoriginal} )
              if $::lglobal{grtextoriginal};
            undef $::lglobal{grtextoriginal};
        },
        -text => 'Cancel',
    )->pack( -side => 'left' );

    $::lglobal{grpop}->protocol(
        'WM_DELETE_WINDOW' => sub {
            $cancel->invoke;
        }
    );
    $::lglobal{grtext}->SetGUICallbacks( [] );
}

#
# Create a label that simulates a button containing a Greek character for the
# Greek popup dialog - labels take up less space than even a 1x1 character button.
# Label is positioned in the given frame at the given row & column.
# Label string and the text to insert is in array from %attributes
sub greekpopupbutton {
    my $frame  = shift;
    my $row    = shift;
    my $col    = shift;
    my $attrib = shift;
    return unless $attrib;
    my $w = $frame->Label(
        -text               => $attrib->[3],
        -font               => 'unicode',
        -relief             => 'flat',
        -borderwidth        => 0,
        -background         => $::bkgcolor,
        -highlightthickness => 0,
    )->grid( -row => $row, -column => $col );

    # Show label active when cursor enters
    $w->bind( '<Enter>', sub { $w->configure( -background => $::activecolor ); } );
    $w->bind( '<Leave>', sub { $w->configure( -background => $::bkgcolor ); } );

    # Manually bind command to be executed when clicked
    $w->bind( '<ButtonRelease-1>', sub { putgreek($attrib); } );
}

#
# Create a label for the Greek popup dialog with the given text
# Label is positioned in the given frame at the given row & column
sub greekpopuplabel {
    my $frame = shift;
    my $row   = shift;
    my $col   = shift;
    my $text  = shift;
    $frame->Label(
        -text       => $text,
        -font       => 'unicode',
        -background => $::bkgcolor,
    )->grid( -row => $row, -column => $col );
}

#
# Translate the (selected) text in the Greek popup dialog using the given sub
sub greekpopuptranslate {
    my $translatorsub = shift;

    # Get selected text, if nothing selected, translate everything
    my @ranges = $::lglobal{grtext}->tagRanges('sel');
    push @ranges, ( '1.0', 'end' ) if @ranges == 0;
    my $end       = pop(@ranges);
    my $start     = pop(@ranges);
    my $selection = $::lglobal{grtext}->get( $start, $end );

    # Replace text with the translation
    $::lglobal{grtext}->delete( $start, $end );
    $::lglobal{grtext}->insert( $start, &$translatorsub($selection) );

    # Delete any trailing blank line
    if ( $::lglobal{grtext}->get( 'end -1c', 'end' ) =~ /^$/ ) {
        $::lglobal{grtext}->delete( 'end -1c', 'end' );
    }
}

#
# Check the characters in the RHS character builder entry field validly define a Greek character
# and if so, display it in the LHS field
sub buildvalidator {
    my %hash = ( %{ $::lglobal{grkbeta1} }, %{ $::lglobal{grkbeta2} }, %{ $::lglobal{grkbeta3} } );

    # LHS of table goes into RHS of Character Builder
    # RHS of table comes out LHS of Character Builder
    %hash         = reverse %hash;
    $hash{'a'}    = "\x{3B1}";
    $hash{'A'}    = "\x{391}";
    $hash{'e'}    = "\x{3B5}";
    $hash{'E'}    = "\x{395}";
    $hash{"�"}    = "\x{397}";
    $hash{"�"}    = "\x{3B7}";
    $hash{'I'}    = "\x{399}";
    $hash{'i'}    = "\x{3B9}";
    $hash{'O'}    = "\x{39F}";
    $hash{'o'}    = "\x{3BF}";
    $hash{'Y'}    = "\x{3A5}";
    $hash{'y'}    = "\x{3C5}";
    $hash{'U'}    = "\x{3A5}";
    $hash{'u'}    = "\x{3C5}";
    $hash{"�"}    = "\x{3A9}";
    $hash{"�"}    = "\x{3C9}";
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
    $hash{'e^'}   = "\x{3B7}";
    $hash{'E^'}   = "\x{397}";
    $hash{'O^'}   = "\x{3A9}";
    $hash{'o^'}   = "\x{3C9}";
    $hash{'H'}    = "\x{397}";
    $hash{'h'}    = "\x{3B7}";
    $hash{'W'}    = "\x{3DC}";
    $hash{'w'}    = "\x{3DD}";
    $hash{' '}    = ' ';
    $hash{'u\+'}  = "\x{1FE2}";
    $hash{'u/+'}  = "\x{1FE3}";
    $hash{'u~+'}  = "\x{1FE7}";
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
        $::lglobal{buildlabel}->configure( -text => $hash{ $_[0] } );
        return 1;
    }
}

#
# Find closing bracket that matches the open bracket starting Greek phrase
sub findmatchingclosebracket {
    my $textwindow   = $::textwindow;
    my ($startIndex) = @_;
    my $indentLevel  = 1;
    my $closeIndex;
    while ($indentLevel) {
        $closeIndex = $textwindow->search( '-exact', '--', ']', "$startIndex" . '+1c', 'end' );
        my $openIndex = $textwindow->search( '-exact', '--', '[', "$startIndex" . '+1c', 'end' );
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

#
# Find the extent of the next Greek phrase
sub findgreek {
    my $startIndex = shift;
    my $textwindow = $::textwindow;
    $startIndex = $textwindow->index($startIndex);
    my $chars;
    my $greekIndex = $textwindow->search( '-exact', '--', '[Greek:', "$startIndex", 'end' );
    if ($greekIndex) {
        my $closeIndex = findmatchingclosebracket($greekIndex);
        return ( $greekIndex, $closeIndex );
    } else {
        return ( $greekIndex, $greekIndex );
    }
}

#
# Inserts given Greek character into the Greek popup
sub putgreek {
    my $attrib     = shift;
    my $textwindow = $::textwindow;
    my $letter;
    $letter = $attrib->[0]       if ( $::lglobal{groutp} eq 'l' );
    $letter = $attrib->[1] . ' ' if ( $::lglobal{groutp} eq 'n' );
    $letter = $attrib->[2]       if ( $::lglobal{groutp} eq 'h' );
    $letter = $attrib->[3]       if ( $::lglobal{groutp} eq 'u' );
    my $spot = $::lglobal{grtext}->index('insert');

    if ( $::lglobal{groutp} eq 'l' and $letter eq 'y' or $letter eq 'Y' ) {
        if ( $::lglobal{grtext}->get('insert -1c') =~ /[AEIOUaeiou]/ ) {
            $letter = chr( ord($letter) - 4 );
        }
    }
    $::lglobal{grtext}->insert( 'insert', $letter );
    $::lglobal{grtext}->markSet( 'insert', $spot . '+' . length($letter) . 'c' );
    $::lglobal{grtext}->focus;
    $::lglobal{grtext}->see('insert');
}

#
# Transfer the phrase from the Greek dialog into the main text window
sub movegreek {
    my $textwindow = $::textwindow;
    my $phrase     = $::lglobal{grtext}->get( '1.0', 'end' );
    $::lglobal{grtext}->delete( '1.0', 'end' );
    chomp $phrase;
    $textwindow->insert( 'insert', $phrase );
    undef $::lglobal{grtextoriginal};
}

#
# Put the given char into the character builder field
sub placechar {
    my ( $widget, @xy, $letter );
    @xy     = $::lglobal{grpop}->pointerxy;
    $widget = $::lglobal{grpop}->containing(@xy);
    my $char = $widget->cget( -text );
    $char =~ s/\s//;
    if ( $char =~ /[AaEe��IiOoYy��Rr]/ ) {
        $::lglobal{buildentry}->delete( '0', 'end' );
        $::lglobal{buildentry}->insert( 'end', $char );
        $::lglobal{buildentry}->focus;
    }
    if ( $char =~ /[\(\)\\\/\|~+=_]/ ) {
        $::lglobal{buildentry}->insert( 'end', $char );
        $::lglobal{buildentry}->focus;
    }
}

#
# Convert given phrase from Betacode to Greek
sub togreektr {
    my $phrase = shift;
    $phrase =~ s/nch/\x{03B3}\x{03C7}/g;
    $phrase =~ s/NCH/\x{0393}\x{03A7}/g;
    $phrase =~ s/ch/\x{03C7}/g;
    $phrase =~ s/CH/\x{03A7}/g;
    $phrase =~ s/Ch/\x{03A7}/g;
    $phrase =~ s/th/\x{03B8}/g;
    $phrase =~ s/TH/\x{0398}/g;
    $phrase =~ s/Th/\x{0398}/g;
    $phrase =~ s/ph/\x{03C6}/g;
    $phrase =~ s/PH/\x{03A6}/g;
    $phrase =~ s/Ph/\x{03A6}/g;
    $phrase =~ s/ng/\x{03B3}\x{03B3}/g;
    $phrase =~ s/NG/\x{0393}\x{0393}/g;
    $phrase =~ s/nk/\x{03B3}\x{03BA}/g;
    $phrase =~ s/NK/\x{0393}\x{039A}/g;
    $phrase =~ s/nx/\x{03B3}\x{03BE}/g;
    $phrase =~ s/NX/\x{0393}\x{039E}/g;
    $phrase =~ s/rh/\x{1FE5}/g;
    $phrase =~ s/RH/\x{1FEC}/g;
    $phrase =~ s/Rh/\x{1FEC}/g;
    $phrase =~ s/ps/\x{03C8}/g;
    $phrase =~ s/PS/\x{03A8}/g;
    $phrase =~ s/Ps/\x{03A8}/g;
    $phrase =~ s/ha/\x{1F01}/g;
    $phrase =~ s/he/\x{1F11}/g;
    $phrase =~ s/h�/\x{1F21}/g;
    $phrase =~ s/hi/\x{1F31}/g;
    $phrase =~ s/ho/\x{1F41}/g;
    $phrase =~ s/hy/\x{1F51}/g;
    $phrase =~ s/hu/\x{1F51}/g;
    $phrase =~ s/h�/\x{1F61}/g;
    $phrase =~ s/HA/\x{1F09}/g;
    $phrase =~ s/HE/\x{1F19}/g;
    $phrase =~ s/H�/\x{1F29}/g;
    $phrase =~ s/HI/\x{1F39}/g;
    $phrase =~ s/HO/\x{1F49}/g;
    $phrase =~ s/HY/\x{1F59}/g;
    $phrase =~ s/HU/\x{1F59}/g;
    $phrase =~ s/H�/\x{1F69}/g;
    $phrase =~ s/Ha/\x{1F09}/g;
    $phrase =~ s/He/\x{1F19}/g;
    $phrase =~ s/H�/\x{1F29}/g;
    $phrase =~ s/Hi/\x{1F39}/g;
    $phrase =~ s/Ho/\x{1F49}/g;
    $phrase =~ s/Hy/\x{1F59}/g;
    $phrase =~ s/Hu/\x{1F59}/g;
    $phrase =~ s/H�/\x{1F69}/g;
    $phrase =~ s/ou/\x{03BF}\x{03C5}/g;
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
    $phrase =~ s/�/\x{0397}/g;
    $phrase =~ s/�/\x{03B7}/g;
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
    $phrase =~ s/s'/\x{03C3}'/g;
    $phrase =~ s/s(\s|\n|$|\W)/\x{03C2}$1/g;
    $phrase =~ s/s/\x{03C3}/g;
    $phrase =~ s/T/\x{03A4}/g;
    $phrase =~ s/t/\x{03C4}/g;
    $phrase =~ s/Y/\x{03A5}/g;
    $phrase =~ s/y/\x{03C5}/g;
    $phrase =~ s/U/\x{03A5}/g;                 #Moved from betagreek-unicode
    $phrase =~ s/u/\x{03C5}/g;                 #Moved from betagreek-unicode
    $phrase =~ s/�/\x{03A9}/g;
    $phrase =~ s/�/\x{03C9}/g;
    $phrase =~ s/�/\x{03AA}/g;
    $phrase =~ s/�/\x{03CA}/g;
    $phrase =~ s/�/\x{03AB}/g;
    $phrase =~ s/�/\x{03CB}/g;
    $phrase =~ s/�/\x{03CB}/g;
    $phrase =~ s/J/\x{03D8}/g;
    $phrase =~ s/j/\x{03D9}/g;
    $phrase =~ s/W/\x{03DC}/g;
    $phrase =~ s/w/\x{03DD}/g;
    $phrase =~ s/Q/\x{03DE}/g;
    $phrase =~ s/q/\x{03DF}/g;
    $phrase =~ s/C/\x{03E0}/g;
    $phrase =~ s/c/\x{03E1}/g;
    $phrase =~ s/\?/\x{037E}/g;
    $phrase =~ s/;/\x{0387}/g;
    return $phrase;
}

#
# Convert beta code to Greek, but better
sub bettergreek {
    my $phrase = shift;
    $phrase =~ s/\\/\\\\/g;
    my $answer = betagreek($phrase);
    $answer =~ s/\\\\/\\/g;
    return $answer;
}

#
# Convert Greek to beta code, but better
sub greekbetter {
    my $phrase = shift;
    $phrase =~ s/\\/\\\\/g;
    my $answer = greekbeta($phrase);
    $answer =~ s/\\\\/\\/g;
    return $answer;
}

#
# Convert beta code to Greek
sub betagreek {
    my $phrase = shift;
    $phrase =~ s/u\)\//\x{1F54}/g;
    $phrase =~ s/u~\)/\x{1F56}/g;
    $phrase =~ s/u\)\\\\/\x{1F52}/g;
    $phrase =~ s/u\(\//\x{1F55}/g;
    $phrase =~ s/u~\(/\x{1F57}/g;
    $phrase =~ s/u\(\\\\/\x{1F53}/g;
    $phrase =~ s/u\/\+/\x{1FE3}/g;
    $phrase =~ s/u~\+/\x{1FE7}/g;
    $phrase =~ s/u\\\\\+/\x{1FE2}/g;
    $phrase =~ s/u\)/\x{1F50}/g;
    $phrase =~ s/u\(/\x{1F51}/g;
    $phrase =~ s/u\+/\x{03CB}/g;
    $phrase =~ s/u\//\x{1F7B}/g;
    $phrase =~ s/u~/\x{1FE6}/g;
    $phrase =~ s/u\\\\/\x{1F7A}/g;
    $phrase =~ s/u=/\x{1FE0}/g;
    $phrase =~ s/u_/\x{1FE1}/g;
    $phrase =~ s/U\(\//\x{1F5D}/g;
    $phrase =~ s/U~\(/\x{1F5F}/g;
    $phrase =~ s/U\(\\\\/\x{1F5B}/g;
    $phrase =~ s/U\(/\x{1F59}/g;
    $phrase =~ s/U\+/\x{03AB}/g;
    $phrase =~ s/U\//\x{1FEB}/g;
    $phrase =~ s/U\\\\/\x{1FEA}/g;
    $phrase =~ s/U=/\x{1FE8}/g;
    $phrase =~ s/U_/\x{1FE9}/g;
    $phrase =~ s/�~/\x{1FD7}/g;
    $phrase =~ s/�~/\x{1FE7}/g;
    $phrase =~ s/�~/\x{1FE7}/g;
    $phrase =~ s/�\\\\/\x{1FD2}/g;
    $phrase =~ s/�\\\\/\x{1FE2}/g;
    $phrase =~ s/�\\\\/\x{1FE2}/g;
    $phrase =~ s/�\//\x{1FD3}/g;
    $phrase =~ s/�\//\x{1FE3}/g;
    $phrase =~ s/�\//\x{1FE3}/g;
    $phrase =~ s/�/\x{03AA}/g;
    $phrase =~ s/�/\x{03CA}/g;
    $phrase =~ s/�/\x{03AB}/g;
    $phrase =~ s/�/\x{03CB}/g;
    $phrase =~ s/�/\x{03CB}/g;

    my %atebkrg = reverse %{ $::lglobal{grkbeta3} };
    for ( keys %atebkrg ) {    #Triply marked Greek <- Beta
        $phrase =~ s/\Q$_\E/$atebkrg{$_}/g;
    }
    %atebkrg = reverse %{ $::lglobal{grkbeta2} };
    for ( keys %atebkrg ) {    #Doubly marked Greek <- Beta
        $phrase =~ s/\Q$_\E/$atebkrg{$_}/g;
    }
    %atebkrg = reverse %{ $::lglobal{grkbeta1} };
    for ( keys %atebkrg ) {    #Singly marked Greek <- Beta
        $phrase =~ s/\Q$_\E/$atebkrg{$_}/g;
    }
    return togreektr($phrase);    #Un-marked & specials
}

#
# Convert Greek to beta code
sub greekbeta {
    my $phrase = shift;
    for ( keys %{ $::lglobal{grkbeta1} } ) {    #Singly marked Greek -> Beta
        $phrase =~ s/$_/$::lglobal{grkbeta1}{$_}/g;
    }
    for ( keys %{ $::lglobal{grkbeta2} } ) {    #Doubly marked Greek -> Beta
        $phrase =~ s/$_/$::lglobal{grkbeta2}{$_}/g;
    }
    for ( keys %{ $::lglobal{grkbeta3} } ) {    #Triply marked Greek -> Beta
        $phrase =~ s/$_/$::lglobal{grkbeta3}{$_}/g;
    }
    $phrase =~ s/\x{037E}/?/g;
    $phrase =~ s/\x{0387}/;/g;
    $phrase =~ s/\x{0390}/u\/\+/g;
    $phrase =~ s/\x{03B0}/i\/\+/g;
    $phrase =~ s/\x{0386}/A\//g;
    $phrase =~ s/\x{0388}/E\//g;
    $phrase =~ s/\x{0389}/�\//g;
    $phrase =~ s/\x{038A}/I\//g;
    $phrase =~ s/\x{038C}/O\//g;
    $phrase =~ s/\x{038E}/Y\//g;
    $phrase =~ s/\x{038F}/�\//g;
    $phrase =~ s/\x{03AC}/a\//g;
    $phrase =~ s/\x{03AD}/e\//g;
    $phrase =~ s/\x{03AE}/�\//g;
    $phrase =~ s/\x{03AF}/i\//g;
    $phrase =~ s/\x{03CC}/o\//g;
    $phrase =~ s/\x{03CD}/y\//g;
    $phrase =~ s/\x{03CE}/�\//g;
    return fromgreektr($phrase);    #Un-marked & specials
}

#
# Convert betacode to "ASCII" (no longer used IRL, but still accessible via \G...\E regex directive)
sub betaascii {    #Actually it's beta->ANSI

    # Discards the accents
    my ($phrase) = @_;
    $phrase =~ s/[\)\/\\\|\~\+=_]//g;
    $phrase =~ s/R\(/Rh/g;
    $phrase =~ s/r\(/rh/g;
    $phrase =~ s/([AEIOUY��])\(/H\L$1\E/g;
    $phrase =~ s/([aeiouy��]+)\(/h$1/g;
    $phrase =~ s/(\p{Upper}\p{Lower}\p{Upper})/\U$1\E/g;
    return $phrase;
}
1;
