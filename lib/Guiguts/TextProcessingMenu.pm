package Guiguts::TextProcessingMenu;
use strict;
use warnings;

BEGIN {
	use Exporter();
	our ( @ISA, @EXPORT );
	@ISA = qw(Exporter);
	@EXPORT =
	  qw(&text_convert_italic &text_convert_bold &text_thought_break &text_convert_tb
	  &text_convert_options &fixpopup &text_convert_smallcaps &text_remove_smallcaps_markup
	  &endofline &cleanup);
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

sub fixpopup {
	my $top = $::top;
	::viewpagenums() if ( $::lglobal{seepagenums} );
	if ( defined( $::lglobal{fixpop} ) ) {
		$::lglobal{fixpop}->deiconify;
		$::lglobal{fixpop}->raise;
		$::lglobal{fixpop}->focus;
	} else {
		$::lglobal{fixpop} = $top->Toplevel;
		$::lglobal{fixpop}->title('Fixup Options');
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
		my $pframe = $::lglobal{fixpop}->Frame->pack;
		$pframe->Label( -text => 'Select options for the fixup routine.', )
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
							-text => 'French style angle quotes «guillemots»',
		)->grid( -row => $row, -column => 1 );
		++$row;
		$pframe1->Radiobutton(
							-variable    => \${ $::lglobal{fixopt} }[15],
							-selectcolor => $::lglobal{checkcolor},
							-value       => 0,
							-text => 'German style angle quotes »guillemots«',
		)->grid( -row => $row, -column => 1 );
		::initialize_popup_with_deletebinding('fixpop');
	}
}
## Fixup Popup
sub fixup {
	my $textwindow = $::textwindow;
	::operationadd('Fixup Routine' );
	::viewpagenums() if ( $::lglobal{seepagenums} );
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
			;        # format guillemots correctly
			;        # french guillemots
			if ( ${ $::lglobal{fixopt} }[14] and ${ $::lglobal{fixopt} }[15] ) {
				$edited++ if $line =~ s/«\s+/«/g;
				$edited++ if $line =~ s/\s+»/»/g;
			}
			;        # german guillemots
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

sub text_convert_smallcaps {
	::searchpopup();
	::searchoptset(qw/0 x x 1/);
	$::lglobal{searchentry}->delete( '1.0', 'end' );
	$::lglobal{searchentry}->insert( 'end', "<sc>(\\n?[^<]+)</sc>" );
	$::lglobal{replaceentry}->delete( '1.0', 'end' );
	$::lglobal{replaceentry}->insert( 'end', "\\U\$1\\E" );
}

sub text_remove_smallcaps_markup {
	::searchpopup();
	::searchoptset(qw/0 x x 1/);
	$::lglobal{searchentry}->delete( '1.0', 'end' );
	$::lglobal{searchentry}->insert( 'end', "<sc>(\\n?[^<]+)</sc>" );
	$::lglobal{replaceentry}->delete( '1.0', 'end' );
	$::lglobal{replaceentry}->insert( 'end', "\$1" );
}
## End of Line Cleanup
sub endofline {
	my $textwindow = $::textwindow;
	::operationadd('Remove end-of-line spaces' );
	::viewpagenums() if ( $::lglobal{seepagenums} );
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
	::viewpagenums() if ( $::lglobal{seepagenums} );
	while (1) {
		$::searchstartindex =
		  $textwindow->search( '-regexp', '--',
							   '^\/[\*\$#pPfFLlXx]|^[Pp\*\$#fFLlXx]\/',
							   $::searchstartindex, 'end' );
		last unless $::searchstartindex;
		$textwindow->delete( "$::searchstartindex -1c",
							 "$::searchstartindex lineend" );
	}
	$top->Unbusy( -recurse => 1 );
}
1;
