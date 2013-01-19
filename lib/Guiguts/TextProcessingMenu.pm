package Guiguts::TextProcessingMenu;
use strict;
use warnings;

BEGIN {
	use Exporter();
	our ( @ISA, @EXPORT );
	@ISA = qw(Exporter);
	@EXPORT =
	  qw(&text_convert_italic &text_convert_bold &txt_convert_simple_markup &text_thought_break &text_convert_tb
	  &text_convert_options &txt_convert_palette &fixpopup &text_uppercase_smallcaps &text_remove_smallcaps_markup
	  &txt_manual_sc_conversion &endofline &cleanup);
}

sub text_convert_italic {
	my ( $textwindow, $italic_char ) = @_;
	my $italic  = qr/<\/?i>/;
	my $replace = $italic_char;
	$textwindow->FindAndReplaceAll( '-regexp', '-nocase', $italic, $replace );
}

sub text_convert_bold {
	my ( $textwindow, $bold_char ) = @_;
	my $bold    = qr{</?b>};
	my $replace = "$bold_char";
	$textwindow->FindAndReplaceAll( '-regexp', '-nocase', $bold, $replace );
}

sub txt_convert_simple_markup {
	my ( $textwindow, $markup, $replace ) = @_;
	my $search    = eval ( 'qr{'.$markup.'}' );
	$textwindow->FindAndReplaceAll( '-regexp', '-nocase', $search, $replace );
}

## Insert a "Thought break" (duh)
sub text_thought_break {
	my ($textwindow) = @_;
	$textwindow->insert( ( $textwindow->index('insert') ) . ' lineend',
						 '       *' x 5 );
}

sub text_convert_tb {
	my ($textwindow) = @_;
	my $tb = '       *       *       *       *       *';
	$textwindow->FindAndReplaceAll( '-exact', '-nocase', '<tb>', $tb );
}

sub text_convert_options {
	my $top = shift;
	my $options = $top->DialogBox( -title   => "Text Processing Options",
								   -buttons => ["OK"], );
	my $italic_frame =
	  $options->add('Frame')->pack( -side => 'top', -padx => 5, -pady => 3 );
	my $italic_label =
	  $italic_frame->Label(
							-width => 25,
							-text  => "Italic Replace Character"
	  )->pack( -side => 'left' );
	my $italic_entry =
	  $italic_frame->Entry(
							-width        => 6,
							-background   => $::bkgcolor,
							-relief       => 'sunken',
							-textvariable => \$::italic_char,
	  )->pack( -side => 'left' );
	my $bold_frame =
	  $options->add('Frame')->pack( -side => 'top', -padx => 5, -pady => 3 );
	my $bold_label =
	  $bold_frame->Label(
						  -width => 25,
						  -text  => "Bold Replace Character"
	  )->pack( -side => 'left' );
	my $bold_entry =
	  $bold_frame->Entry(
						  -width        => 6,
						  -background   => $::bkgcolor,
						  -relief       => 'sunken',
						  -textvariable => \$::bold_char,
	  )->pack( -side => 'left' );
	$options->Show;
	::savesettings();
}

sub txt_convert_palette {
	my ($textwindow, $top) = ( $::textwindow, $::top);
	if ( defined( $::lglobal{txtconvpop} ) ) {
		$::lglobal{txtconvpop}->deiconify;
		$::lglobal{txtconvpop}->raise;
		$::lglobal{txtconvpop}->focus;
	} else {
		$::lglobal{txtconvpop} = $top->Toplevel;
		$::lglobal{txtconvpop}->title('Txt Markup');

		my $italic_frame =
		  $::lglobal{txtconvpop}->Frame->pack( -side => 'top', -padx => 5, -pady => 3 );
		$italic_frame->Label(
			-text     => '<i></i>',
			-width    => 8,
		)->pack(-side => 'left' );
		my $italic_check = $italic_frame->Checkbutton(
			-variable => \$::txt_conv_italic,
			-width => 10,
			-text  => 'convert to:'
		)->pack( -side => 'left' );
		my $italic_entry = $italic_frame->Entry(
			-width        => 6,
			-background   => $::bkgcolor,
			-relief       => 'sunken',
			-textvariable => \$::italic_char,
		)->pack( -side => 'left' );
		my $italic_button = $italic_frame->Button(
			-width        => 16,
			-text         => 'Convert <i></i> now',
			-command      => sub { txt_convert_simple_markup( $textwindow, "</?i>", $::italic_char ); }
		)->pack( -side => 'left' );
		my $bold_frame =
		  $::lglobal{txtconvpop}->Frame->pack( -side => 'top', -padx => 5, -pady => 3 );
		$bold_frame->Label(
			-text     => '<b></b>',
			-width    => 8,
		)->pack(-side => 'left' );
		my $bold_check = $bold_frame->Checkbutton(
			-variable => \$::txt_conv_bold,
			-width => 10,
			-text  => 'convert to:'
		)->pack( -side => 'left' );
		my $bold_entry = $bold_frame->Entry(
			-width        => 6,
			-background   => $::bkgcolor,
			-relief       => 'sunken',
			-textvariable => \$::bold_char,
		)->pack( -side => 'left' );
		my $bold_button = $bold_frame->Button(
			-width        => 16,
			-text         => 'Convert <b></b> now',
			-command      => sub { txt_convert_simple_markup( $textwindow, "</?b>", $::bold_char ); }
		)->pack( -side => 'left' );
		my $g_frame =
		  $::lglobal{txtconvpop}->Frame->pack( -side => 'top', -padx => 5, -pady => 3 );
		$g_frame->Label(
			-text     => '<g></g>',
			-width    => 8,
		)->pack(-side => 'left' );
		my $g_check = $g_frame->Checkbutton(
			-variable => \$::txt_conv_gesperrt,
			-text     => 'convert to:',
			-width    => 10,
		)->pack(-side => 'left' );
		my $g_entry = $g_frame->Entry(
			-width        => 6,
			-background   => $::bkgcolor,
			-relief       => 'sunken',
			-textvariable => \$::gesperrt_char,
		)->pack( -side => 'left' );
		my $g_button = $g_frame->Button(
			-width        => 16,
			-text         => 'Convert <g></g> now',
			-command      => sub { txt_convert_simple_markup( $textwindow, "</?g>", $::gesperrt_char ); }
		)->pack( -side => 'left' );
		my $f_frame =
		  $::lglobal{txtconvpop}->Frame->pack( -side => 'top', -padx => 5, -pady => 3 );
		$f_frame->Label(
			-text     => '<f></f>',
			-width    => 8,
		)->pack(-side => 'left' );
		my $f_check = $f_frame->Checkbutton(
			-variable => \$::txt_conv_font,
			-text     => 'convert to:',
			-width    => 10,
		)->pack(-side => 'left' );
		my $f_entry = $f_frame->Entry(
			-width        => 6,
			-background   => $::bkgcolor,
			-relief       => 'sunken',
			-textvariable => \$::font_char,
		)->pack( -side => 'left' );
		my $f_button = $f_frame->Button(
			-width        => 16,
			-text         => 'Convert <f></f> now',
			-command      => sub { txt_convert_simple_markup( $textwindow, "</?f>", $::font_char ); }
		)->pack( -side => 'left' );
		my $sc_frame =
		  $::lglobal{txtconvpop}->Frame->pack( -side => 'top', -padx => 5, -pady => 3 );
		my $sc_label = $sc_frame->Label(
			-text     => "<sc></sc>",
			-width    => 9,
		)->pack(-side => 'left' );
		my $sc_none = $sc_frame->Radiobutton(
			-variable => \$::txt_conv_sc,
			-value    => 0,
			-text     => "ignore",
			-width    => 7,
		)->pack(-side => 'left' );
		my $sc_uc = $sc_frame->Radiobutton(
			-variable => \$::txt_conv_sc,
			-value    => 2,
			-text     => "UPPERCASE",
			-width    => 10,
		)->pack(-side => 'left' );
		my $sc_char = $sc_frame->Radiobutton(
			-variable => \$::txt_conv_sc,
			-value    => 1,
			-text     => "convert to:",
			-width    => 8,
		)->pack(-side => 'left' );
		my $sc_entry = $sc_frame->Entry(
			-width        => 6,
			-background   => $::bkgcolor,
			-relief       => 'sunken',
			-textvariable => \$::sc_char,
		)->pack( -side => 'left' );
		my $tb_frame =
		  $::lglobal{txtconvpop}->Frame->pack( -side => 'top', -padx => 5, -pady => 3 );
		$tb_frame->Label(
			-text     => "<tb>",
			-width    => 8,
		)->pack(-side => 'left' );
		my $tb_check = $tb_frame->Checkbutton(
			-variable => \$::txt_conv_tb,
			-text     => 'convert to stars',
			-width    => 15,
		)->pack(-side => 'left' );
		my $tb_button = $tb_frame->Button(
			-width        => 16,
			-text         => 'Convert <tb> now',
			-command      => sub { ::text_convert_tb($textwindow); }
		)->pack( -side => 'left' );
		my $all_frame =
		  $::lglobal{txtconvpop}->Frame->pack( -side => 'top', -padx => 5, -pady => 3 );
		my $sc_manual = $all_frame->Button(
			-width        => 20,
			-text         => 'Do <sc> manually...',
			-command      => sub { ::txt_manual_sc_conversion() },
		)->pack( -side => 'left', -padx => 10 );
		my $all_button = $all_frame->Button(
			-width        => 20,
			-text         => 'Do All Selected',
			-command      => sub {
			  $textwindow->addGlobStart;
			  txt_convert_simple_markup( $textwindow, "</?i>", $::italic_char )
			    if ( $::txt_conv_italic );
			  txt_convert_simple_markup( $textwindow, "</?b>", $::bold_char )
			    if ( $::txt_conv_bold );
			  txt_convert_simple_markup( $textwindow, "</?g>", $::gesperrt_char )
			    if ( $::txt_conv_gesperrt );
			  txt_convert_simple_markup( $textwindow, "</?f>", $::font_char )
			    if ( $::txt_conv_font );
			  text_convert_tb( $textwindow )
			    if ( $::txt_conv_tb );
			  if ( $::txt_conv_sc ) {
				txt_auto_uppercase_smallcaps() if ( $::txt_conv_sc == 2 );
				txt_convert_simple_markup( $textwindow, "</?sc>", $::sc_char)
				    if ( $::txt_conv_sc == 1 );
			  }
			  $textwindow->addGlobEnd;
			}
		)->pack( -side => 'left' );
		::initialize_popup_with_deletebinding('txtconvpop');
	}
	::savesettings();
}

sub fixpopup {
	my $top = $::top;
	::hidepagenums();
	if ( defined( $::lglobal{fixpop} ) ) {
		$::lglobal{fixpop}->deiconify;
		$::lglobal{fixpop}->raise;
		$::lglobal{fixpop}->focus;
	} else {
		$::lglobal{fixpop} = $top->Toplevel;
		$::lglobal{fixpop}->title('Fixup Options');
		my $pframe = $::lglobal{fixpop}->Frame->pack;
		$pframe->Label( -text => 'Select options for the fixup routine:', )
		  ->pack;
		my $pframe1 = $::lglobal{fixpop}->Frame->pack;
		${ $::lglobal{fixopt} }[15] = 1;
		my @rbuttons = (
			'Skip /* */, /$ $/, and /X X/ marked blocks.',
			'Fix up spaces around hyphens.',
			'Convert multiple spaces to single spaces.',
			'Remove spaces before periods.',
			'Remove spaces before exclamation marks.',
			'Remove spaces before question marks.',
			'Remove spaces before semicolons.',
			'Remove spaces before colons.',
			'Remove spaces before commas.',
			'Remove spaces after beginning and before ending double quote.',
'Remove spaces after opening and before closing brackets, () [], {}.',
			'Mark up a line with 4 or more * and nothing else as <tb>.',
			'Fix obvious l<->1 problems, lst, llth, etc.',
			'Format ellipses correctly',
'Remove spaces after beginning and before ending angle quotes « ».',
		);
		my $row = 0;
		for (@rbuttons) {
			$pframe1->Checkbutton(
								   -variable => \${ $::lglobal{fixopt} }[$row],
								   -selectcolor => $::lglobal{checkcolor},
								   -text        => $_,
			)->grid( -row => $row, -column => 1, -sticky => 'nw' );
			++$row;
		}
		$pframe1->Radiobutton(
							-variable    => \${ $::lglobal{fixopt} }[15],
							-selectcolor => $::lglobal{checkcolor},
							-value       => 1,
							-text => 'French style angle quotes «guillemets»',
		)->grid( -row => $row, -column => 1 );
		++$row;
		$pframe1->Radiobutton(
							-variable    => \${ $::lglobal{fixopt} }[15],
							-selectcolor => $::lglobal{checkcolor},
							-value       => 0,
							-text => 'German style angle quotes »guillemets«',
		)->grid( -row => $row, -column => 1 );
		my $tframe = $::lglobal{fixpop}->Frame->pack;
		$tframe->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				$::lglobal{fixpop}->UnmapWindow;
				fixup();
				$::lglobal{fixpop}->destroy;
				undef $::lglobal{fixpop};
			},
			-text  => 'Go!',
			-width => 14
		)->pack( -pady => 6 );
		::initialize_popup_with_deletebinding('fixpop');
	}
}

## Fixup Popup
sub fixup {
	my $textwindow = $::textwindow;
	::operationadd('Fixup Routine' );
	::hidepagenums();
	my ($line);
	my $index     = '1.0';
	my $lastindex = '1.0';
	my $inblock   = 0;
	my $update    = 0;
	my $edited    = 0;
	my $end       = $textwindow->index('end');
	$::operationinterrupt = 0;

	while ( $lastindex < $end ) {
		$line = $textwindow->get( $lastindex, $index );
		if ( $line =~ /\/[\$\*Xx]/ ) { $inblock = 1 }
		if ( $line =~ /[\$\*]\// )   { $inblock = 0 }
		unless ( $inblock && ${ $::lglobal{fixopt} }[0] ) {
			if ( ${ $::lglobal{fixopt} }[2] ) {
				while ( $line =~ s/(?<=\S)\s\s+(?=\S)/ / ) { $edited++ }
				;    # remove multiple spaces
			}
			if ( ${ $::lglobal{fixopt} }[1] ) {
				; # Remove spaces before hyphen (only if hyphen isn't first on line, like poetry)
				$edited++ if $line =~ s/(\S) +-/$1-/g;
				$edited++ if $line =~ s/- /-/g;    # Remove space after hyphen
				$edited++
				  if $line =~ s/(?<![-])([-]*---)(?=[^\s\\"F-])/$1 /g
				; # Except leave a space after a string of three or more hyphens
			}
			if ( ${ $::lglobal{fixopt} }[3] ) {
				; # Remove space before periods (only if not first on line, like poetry's ellipses)
				$edited++ if $line =~ s/(\S) +\.(?=\D)/$1\./g;
			}
			;     # Get rid of space before periods
			if ( ${ $::lglobal{fixopt} }[4] ) {
				$edited++
				  if $line =~ s/ +!/!/g;
			}
			;     # Get rid of space before exclamation points
			if ( ${ $::lglobal{fixopt} }[5] ) {
				$edited++
				  if $line =~ s/ +\?/\?/g;
			}
			;     # Get rid of space before question marks
			if ( ${ $::lglobal{fixopt} }[6] ) {
				$edited++
				  if $line =~ s/ +\;/\;/g;
			}
			;     # Get rid of space before semicolons
			if ( ${ $::lglobal{fixopt} }[7] ) {
				$edited++
				  if $line =~ s/ +:/:/g;
			}
			;     # Get rid of space before colons
			if ( ${ $::lglobal{fixopt} }[8] ) {
				$edited++
				  if $line =~ s/ +,/,/g;
			}
			;     # Get rid of space before commas
			      # FIXME way to go on managing quotes
			if ( ${ $::lglobal{fixopt} }[9] ) {
				$edited++
				  if $line =~ s/^\" +/\"/
				; # Remove space after doublequote if it is the first character on a line
				$edited++
				  if $line =~ s/ +\"$/\"/
				; # Remove space before doublequote if it is the last character on a line
			}
			if ( ${ $::lglobal{fixopt} }[10] ) {
				$edited++
				  if $line =~ s/(?<=(\(|\{|\[)) //g
				;    # Get rid of space after opening brackets
				$edited++
				  if $line =~ s/ (?=(\)|\}|\]))//g
				;    # Get rid of space before closing brackets
			}
			;        # FIXME format to standard thought breaks - changed to <tb>
			if ( ${ $::lglobal{fixopt} }[11] ) {
				$edited++

		   #				  if $line =~
		   # s/^\s*(\*\s*){5}$/       \*       \*       \*       \*       \*\n/;
				  if $line =~ s/^\s*(\*\s*){4,}$/<tb>\n/;
			}
			$edited++ if ( $line =~ s/ +$// );
			;        # Fix llth, lst
			if ( ${ $::lglobal{fixopt} }[12] ) {
				$edited++ if $line =~ s/llth/11th/g;
				$edited++ if $line =~ s/(?<=\d)lst/1st/g;
				$edited++ if $line =~ s/(?<=\s)lst/1st/g;
				$edited++ if $line =~ s/^lst/1st/;
			}
			;        # format ellipses correctly
			if ( ${ $::lglobal{fixopt} }[13] ) {
				$edited++ if $line =~ s/(?<![\.\!\?])\.{3}(?!\.)/ \.\.\./g;
				$edited++ if $line =~ s/^ \./\./;
			}
			;        # format guillemets correctly
			;        # french guillemets
			if ( ${ $::lglobal{fixopt} }[14] and ${ $::lglobal{fixopt} }[15] ) {
				$edited++ if $line =~ s/«\s+/«/g;
				$edited++ if $line =~ s/\s+»/»/g;
			}
			;        # german guillemets
			if ( ${ $::lglobal{fixopt} }[14] and !${ $::lglobal{fixopt} }[15] )
			{
				$edited++ if $line =~ s/\s+«/«/g;
				$edited++ if $line =~ s/»\s+/»/g;
			}
			$update++ if ( ( $index % 250 ) == 0 );
			$textwindow->see($index) if ( $edited || $update );
			if ($edited) {
				$textwindow->replacewith( $lastindex, $index, $line );
			}
		}
		$textwindow->markSet( 'insert', $index ) if $update;
		$textwindow->update   if ( $edited || $update );
		::update_indicators() if ( $edited || $update );
		$edited    = 0;
		$update    = 0;
		$lastindex = $index;
		$index++;
		$index .= '.0';
		if ( $index > $end ) { $index = $end }
		if ($::operationinterrupt) { $::operationinterrupt = 0; return }
	}
	$textwindow->markSet( 'insert', 'end' );
	$textwindow->see('end');
	::update_indicators();
}

sub text_uppercase_smallcaps {
	::searchpopup();
	::searchoptset(qw/0 x x 1/);
	$::lglobal{searchentry}->delete( '1.0', 'end' );
	$::lglobal{searchentry}->insert( 'end', "<sc>(\\n?[^<]+)</sc>" );
	$::lglobal{replaceentry}->delete( '1.0', 'end' );
	$::lglobal{replaceentry}->insert( 'end', "\\U\$1\\E" );
}

sub txt_auto_uppercase_smallcaps {
	my $textwindow = $::textwindow;
	$textwindow->addGlobStart;
	my ( $thisblockstart, $thisblockend, $selection );
	while ( $thisblockstart =
		$textwindow->search( '-exact', '--', '<sc>', '1.0', 'end' ) )
	{
		$thisblockend = $textwindow->search( '-exact', '--', '</sc>', $thisblockstart, 'end' );
		$selection = $textwindow->get( "$thisblockstart +4c", $thisblockend );
		$textwindow->replacewith( $thisblockstart, "$thisblockend +5c", uc($selection) );
	}
	$textwindow->addGlobEnd;
}

sub text_remove_smallcaps_markup {
	::searchpopup();
	::searchoptset(qw/0 x x 1/);
	$::lglobal{searchentry}->delete( '1.0', 'end' );
	$::lglobal{searchentry}->insert( 'end', "<sc>(\\n?[^<]+)</sc>" );
	$::lglobal{replaceentry}->delete( '1.0', 'end' );
	$::lglobal{replaceentry}->insert( 'end', "\$1" );
}

sub txt_manual_sc_conversion {
	::searchpopup();
	::searchoptset(qw/0 x x 1/);
	$::lglobal{searchentry}->delete( '1.0', 'end' );
	$::lglobal{replaceentry}->delete( '1.0', 'end' );
	$::lglobal{replaceentry1}->delete( '1.0', 'end' );
	$::lglobal{replaceentry2}->delete( '1.0', 'end' );
	$::lglobal{searchentry}->insert( 'end', '<sc>(\\n?[^<]+)</sc>' );
	$::lglobal{replaceentry}->insert( 'end', '$1' );
	$::lglobal{replaceentry1}->insert( 'end', '\U$1\E' );
	$::lglobal{replaceentry2}->insert( 'end', "$::sc_char\$1$::sc_char" );
	$::lglobal{searchmulti}->invoke;
}

## End of Line Cleanup
sub endofline {
	my $textwindow = $::textwindow;
	::operationadd('Remove end-of-line spaces' );
	::hidepagenums();
	my $start  = '1.0';
	my $end    = $textwindow->index('end');
	my @ranges = $textwindow->tagRanges('sel');
	if (@ranges) {
		$start = $ranges[0];
		$end   = $ranges[-1];
	}
	$::operationinterrupt = 0;
	$textwindow->FindAndReplaceAll( '-regex', '-nocase', '\s+$', '' );
	::update_indicators();
}

## Clean Up Rewrap
sub cleanup {
	my $textwindow = $::textwindow;
	my $top        = $::top;
	$top->Busy( -recurse => 1 );
	$::searchstartindex = '1.0';
	::hidepagenums();
	$textwindow->addGlobStart;
	while (1) {
		$::searchstartindex =
		  $textwindow->search( '-regexp', '--',
							   '^\/[\*\$#pPfFLlXx]|^[Pp\*\$#fFLlXx]\/',
							   $::searchstartindex, 'end' );
		last unless $::searchstartindex;
		# if a start rewrap block marker is followed by a start rewrap block marker,
		# also delete the blank line between the two
		if ( $textwindow->get($::searchstartindex, "$::searchstartindex +1c") eq '/'
		     && $textwindow->get("$::searchstartindex +3c", "$::searchstartindex +6c")
		          =~ /\n\/[\*\$#pPfFlLxX]/ ) {
			$textwindow->delete( "$::searchstartindex -1c",
							 "$::searchstartindex +5c lineend" );
		} else {
			$textwindow->delete( "$::searchstartindex -1c",
							 "$::searchstartindex lineend" );
		}
	}
	$textwindow->addGlobEnd;
	$top->Unbusy( -recurse => 1 );
}

1;
