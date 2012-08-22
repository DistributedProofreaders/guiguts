package Guiguts::HTMLConvert;
use strict;
use warnings;

BEGIN {
	use Exporter();
	use List::Util qw[min max];
	our ( @ISA, @EXPORT );
	@ISA = qw(Exporter);
	@EXPORT =
	  qw(&htmlautoconvert &htmlgenpopup &htmlmarkpopup &makeanchor &autoindex &entity &named &tonamed
	  &fromnamed &fracconv &pageadjust &html_convert_pageanchors);
}

sub html_convert_tb {
	my ( $textwindow, $selection, $step ) = @_;
	no warnings;    # FIXME: Warning-- Exiting subroutine via next
	if ( $selection =~ s/\s{7}(\*\s{7}){4}\*/<hr class="tb" \/>/ ) {
		$textwindow->ntdelete( "$step.0", "$step.end" );
		$textwindow->ntinsert( "$step.0", $selection );
		next;
	}
	if ( $selection =~ s/<tb>/<hr class="tb" \/>/ ) {
		$textwindow->ntdelete( "$step.0", "$step.end" );
		$textwindow->ntinsert( "$step.0", $selection );
		next;
	}
	return;
}

sub html_convert_subscripts {
	my ( $textwindow, $selection, $step ) = @_;
	if ( $selection =~ s/_\{([^}]+?)\}/<sub>$1<\/sub>/g ) {
		$textwindow->ntdelete( "$step.0", "$step.end" );
		$textwindow->ntinsert( "$step.0", $selection );
	}
	return;
}

# Doesn't convert Gen^rl; workaround Gen^{rl} - correct behaviour, not a bug, cf. the guidelines
sub html_convert_superscripts {
	my ( $textwindow, $selection, $step ) = @_;
	if ( $selection =~ s/\^\{([^}]+?)\}/<sup>$1<\/sup>/g ) {
		$textwindow->ntdelete( "$step.0", "$step.end" );
		$textwindow->ntinsert( "$step.0", $selection );
	}

  # Fixed a bug--did not handle the case without curly brackets, i.e., Philad^a.
	if ( $selection =~ s/\^(.)/<sup>$1<\/sup>/g ) {
		$textwindow->ntdelete( "$step.0", "$step.end" );
		$textwindow->ntinsert( "$step.0", $selection );
	}

	# handle <g>gesperrt text</g>
	if ( $selection =~ s/<g>(.*)<\/g>/<em class="gesperrt">$1<\/em>/g ) {
		$textwindow->ntdelete( "$step.0", "$step.end" );
		$textwindow->ntinsert( "$step.0", $selection );
	}
	return;
}

sub html_convert_ampersands {
	my $textwindow = shift;
	::working("Converting Ampersands");
	::named( '&(?![\w#])', '&amp;' );
	::named( '&$',         '&amp;' );
	::named( '& ',         '&amp; ' );
	::named( '&c\.',       '&amp;c.' );
	::named( '&c,',        '&amp;c.,' );
	::named( '&c ',        '&amp;c. ' );
	$textwindow->FindAndReplaceAll( '-regexp', '-nocase',
		"(?<![a-zA-Z0-9/\\-\"])>", "&gt;" );
	$textwindow->FindAndReplaceAll( '-regexp', '-nocase',
		"(?![\\n0-9])<(?![a-zA-Z0-9/\\-\\n])", '&lt;' );
	return;
}

# double hyphens go to character entity ref. FIXME: Add option for real emdash.
sub html_convert_emdashes {
	::working("Converting Emdashes");
	::named( '(?<=[^-!])--(?=[^>])', '&mdash;' );
	::named( '(?<=[^<])!--(?=[^>])', '!&mdash;' );
	::named( '(?<=[^-])--$',         '&mdash;' );
	::named( '^--(?=[^-])',          '&mdash;' );
	::named( '^--$',                 '&mdash;' );
	::named( "\x{A0}",               '&nbsp;' );
	return;
}

# convert latin1 and utf charactes to HTML Character Entity Reference's.
sub html_convert_latin1 {
	::working("Converting Latin-1 Characters...");
	for ( 128 .. 255 ) {
		my $from = lc sprintf( "%x", $_ );
		::named( '\x' . $from, ::entity( '\x' . $from ) );
	}
	return;
}

sub html_convert_codepage {
	::working("Converting Windows Codepage 1252\ncharacters to Unicode");
	::cp1252toUni();
	return;
}

sub html_convert_utf {
	my ( $textwindow, $leave_utf, $keep_latin1 ) = @_;
	my $blockstart;
	unless ($leave_utf) {
		::working("Converting UTF-8...");
		while (
			$blockstart = $textwindow->search(
				'-regexp', '--', '[\x{100}-\x{65535}]', '1.0', 'end'
			)
		  )
		{
			my $xchar = ord( $textwindow->get($blockstart) );
			$textwindow->ntdelete($blockstart);
			$textwindow->ntinsert( $blockstart, "&#$xchar;" );
		}
	}
	::working("Converting Named\n and Numeric Characters");
	::named( ' >', ' &gt;' )
	  ;    # see html_convert_ampersands -- probably no effect
	::named( '< ', '&lt; ' );
	if ( !$keep_latin1 ) { html_convert_latin1(); }
	return;
}

sub html_cleanup_markers {
	my ($textwindow) = @_;
	my $thisblockend;
	my $thisblockstart = '1.0';
	my $thisend        = q{};
	my ( $ler, $lec );
	::working("Cleaning up\nblock Markers");
	while ( $::blockstart =
		$textwindow->search( '-regexp', '--', '^\/[\*\$\#]', '1.0', 'end' ) )
	{
		( $::xler, $::xlec ) = split /\./, $::blockstart;
		$::blockend = "$::xler.end";
		$textwindow->ntdelete( "$::blockstart-1c", $::blockend );
	}
	while ( $::blockstart =
		$textwindow->search( '-regexp', '--', '^[\*\$\#]\/', '1.0', 'end' ) )
	{
		( $::xler, $::xlec ) = split /\./, $::blockstart;
		$::blockend = "$::xler.end";
		$textwindow->ntdelete( "$::blockstart-1c", $::blockend );
	}
	while ( $::blockstart =
		$textwindow->search( '-regexp', '--', '<\/h\d><br />', '1.0', 'end' ) )
	{
		$textwindow->ntdelete( "$::blockstart+5c", "$::blockstart+9c" );
	}
	return;
}

sub html_convert_footnotes {
	my ( $textwindow, $fnarray ) = @_;
	my $thisblank = q{};
	my $step      = 0;
	::working('Converting Footnotes');
	::footnotefixup();
	::getlz();

	# Keep track of last footnote to set closing </div>
	$textwindow->markSet( 'lastfnindex', '1.0' );
	$textwindow->tagRemove( 'footnote',  '1.0', 'end' );
	$textwindow->tagRemove( 'highlight', '1.0', 'end' );
	$textwindow->see('1.0');
	$textwindow->update;
	while (1) {
		$step++;
		last if ( $textwindow->compare( "$step.0", '>', 'end' ) );
		last unless $fnarray->[$step][0];
		next unless $fnarray->[$step][3];
		$textwindow->ntdelete( 'fne' . "$step" . '-1c', 'fne' . "$step" );

		#print $step. ":step\n";
		$textwindow->ntinsert( 'fne' . "$step", '</p></div>' );
		$textwindow->ntinsert(
			(
				'fns' . "$step" . '+'
				  . ( length( $fnarray->[$step][4] ) + 11 ) . "c"
			),
			"$::htmllabels{fnanchafter}</span></a>"
		);
		$textwindow->ntdelete(
			'fns' . "$step" . '+'
			  . ( length( $fnarray->[$step][4] ) + 10 ) . 'c',
			"fns" . "$step" . '+'
			  . ( length( $fnarray->[$step][4] ) + 11 ) . 'c'
		);
		$textwindow->ntinsert(
			'fns' . "$step" . '+10c',
			"<div class=\"footnote\"><p><a name=\"$::htmllabels{fnlabel}"
			  . ( $::lglobal{shorthtmlfootnotes} ? '' : $fnarray->[$step][4] . '_' )
			  . $step
			  . "\" id=\"$::htmllabels{fnlabel}"
			  . ( $::lglobal{shorthtmlfootnotes} ? '' : $fnarray->[$step][4] . '_' )
			  . $step
			  . "\"></a><a href=\"#$::htmllabels{fnanchor}"
			  . ( $::lglobal{shorthtmlfootnotes} ? '' : $fnarray->[$step][4] . '_' )
			  . $step
			  . "\"><span class=\"label\">$::htmllabels{fnanchbefore}"
		);
		$textwindow->ntdelete( 'fns' . "$step", 'fns' . "$step" . '+10c' );
		# jump through some hoops to steer clear of page markers
		if ( $fnarray->[$step][3] ) {
			$textwindow->ntinsert( "fnb$step -1c", ']</a>' );
			$textwindow->ntdelete( "fnb$step -1c", "fnb$step");
		}
		unless ( $::htmllabels{fnanchbefore} eq '[' && $::htmllabels{fnanchafter} eq ']' ){
			$textwindow->ntinsert("fna$step +1c", $::htmllabels{fnanchbefore} ); # insert before delete, otherwise it gets excluded from the tag
			$textwindow->ntdelete("fna$step", "fna$step +1c");
			$textwindow->ntdelete("fnb$step -5c", "fnb$step -4c");
			$textwindow->ntinsert("fnb$step -4c", $::htmllabels{fnanchafter} );
		}
		$textwindow->ntinsert(
			'fna' . "$step",
			"<a name=\"$::htmllabels{fnanchor}"
			  . ( $::lglobal{shorthtmlfootnotes} ? '' : $fnarray->[$step][4] . '_' )
			  . $step
			  . "\" id=\"$::htmllabels{fnanchor}"
			  . ( $::lglobal{shorthtmlfootnotes} ? '' : $fnarray->[$step][4] . '_' )
			  . $step
			  . "\"></a><a href=\"#$::htmllabels{fnlabel}"
			  . ( $::lglobal{shorthtmlfootnotes} ? '' : $fnarray->[$step][4] . '_' )
			  . $step
			  . "\" class=\"fnanchor\">"
		) if ( $fnarray->[$step][3] );

		while (
			$thisblank = $textwindow->search(
				'-regexp', '--', '^$',
				'fns' . "$step",
				"fne" . "$step"
			)
		  )
		{
			$textwindow->ntinsert( $thisblank, "</p>\n<p>" );
		}
	}
	return;
}

sub html_convert_body {
	my ( $textwindow, $headertext, $cssblockmarkup, $poetrynumbers ) = @_;

#outline of subroutine: make a single pass through all lines $selection
# with the last four lines stored in @last5
# for a given line, convert subscripts, superscriptions and thought breaks for the line
# /x|/X gets <pre>
# and end tag gets </pre>
# in front matter /F enter close para two lines above if needed
# 	delete close front tag
# 	Now in the title; skip ahead
# 	no longer in title
# 	now in some other header than <h1>
# 	close para end of the last line before if the previous line does not already close
# if poetrynumbers, and line ends with two spaces and digits, create line number
# if end of poetry, delete two characters, insert closing </div></div>
# end of stanza
# if line ends spaces plus digits insert line number
#delete indent based on number of digits
# open poetry, if beginning x/ /p
#   close para if needed before open poetry
# in blockquote
#   close para if needed before open blockquote
# deal with block quotes
# deal with lists
# if nonblank followed by blank, insert close para after the nonblank  unless
#   it already has a closing tag (problematic one)
# at end of block, insert close para
# in a block, insert <br />
# four blank lines--start of chapter
# Sets a mark for the horizontal rule at the page marker rather than just before
# the header.
# make an anchor for autogenerate TOC
# insert chapter heading unless already a para or heading open
# bold face insertion into autogenerated TOC
#open subheading with <p>
#open with para if blank line then nonblank line
#open with para if blank line then two nonblank lines
#open with para if blank line then three nonblank lines
#
	::working('Converting Body');
	my @contents = ("\n");
	my $aname    = q{};
	my $author;
	my $blkquot = 0;
	my $cflag   = 0;
	my $front;

	#my $headertext;
	my $inblock    = 0;
	my $incontents = '1.0';
	my $indent     = 0;
	my $intitle    = 0;
	my $inheader   = 0;
	my $ital       = 0;
	my $listmark   = 0;
	my $pgoffset   = 0;
	my $poetry     = 0;
	my $poetryend  = 0;
	my $selection  = q{};
	my $skip       = 0;
	my $thisblank  = q{};
	my $thisblockend;
	my $thisblockstart   = '1.0';
	my $thisend          = q{};
	my $unindentedpoetry = 0;
	my @last5            = [ '1', '1', '1', '1', '1', '1' ];
	my $step             = 1;
	my ( $ler, $lec );
	$thisblockend = $textwindow->index('end');
	my ( $blkopen, $blkclose );

	if ($cssblockmarkup) {
		$blkopen  = '<div class="blockquot"><p>';
		$blkclose = '</p></div>';
	} else {
		$blkopen  = '<blockquote><p>';
		$blkclose = '</p></blockquote>';
	}

	#last line and column
	( $ler, $lec ) = split /\./, $thisblockend;

	#step through all the lines
	while ( $step <= $ler ) {
		unless ( $step % 500 ) {    #refresh window every 550 steps
			$textwindow->see("$step.0");
			$textwindow->update;
		}

		#with with one row (line) at a time
		$selection = $textwindow->get( "$step.0", "$step.end" );

		#flag--in table of contents
		$incontents = "$step.end"
		  if ( ( $step < 100 )
			&& ( $selection =~ /contents/i )
			&& ( $incontents eq '1.0' ) );
		html_convert_subscripts( $textwindow, $selection, $step );
		html_convert_superscripts( $textwindow, $selection, $step );
		html_convert_tb( $textwindow, $selection, $step );

		# /x|/X gets <pre>
		if ( $selection =~ m"^/x"i ) {
			$skip = 1;

			# delete the line
			$textwindow->ntdelete( "$step.0", "$step.end" );

			#insert <pre> instead
			$textwindow->insert( "$step.0", '<pre>' );

			# added this--was not getting close para before <pre>
			insert_paragraph_close( $textwindow, ( $step - 1 ) . '.end' )
			  if ( ( $last5[3] )
				&& ( $last5[3] !~ /<\/?h\d?|<br.*?>|<\/p>|<\/div>/ ) );
			if ( ( $last5[2] ) && ( !$last5[3] ) ) {
				insert_paragraph_close( $textwindow, ( $step - 2 ) . ".end" )
				  unless (
					$textwindow->get( ( $step - 2 ) . '.0',
						( $step - 2 ) . '.end' ) =~ /<\/p>/
				  );
			}
			$step++;
			next;    #done with this row
		}

		# and end x/ tag gets </pre>
		if ( $selection =~ m"^x/"i ) {
			$skip = 0;
			$textwindow->ntdelete( "$step.0", "$step.end" );
			$textwindow->ntinsert( "$step.0", '</pre>' );
			$step++;
			$step++;
			next;
		}

		# skip the row after /X
		if ($skip) {
			$step++;
			next;
		}

		# in front matter /F enter close para two lines above if needed
		if ( $selection =~ m"^/f"i ) {
			$front = 1;
			$textwindow->ntdelete( "$step.0", "$step.end +1c" );
			if ( ( $last5[2] ) && ( !$last5[3] ) ) {
				insert_paragraph_close( $textwindow, ( $step - 2 ) . ".end" )
				  unless (
					$textwindow->get( ( $step - 2 ) . '.0',
						( $step - 2 ) . '.end' ) =~ /<\/p>/
				  );
			}
			next;
		}
		if ($front) {

			# delete close front tag F/, replace with close para if needed
			if ( $selection =~ m"^f/"i ) {
				$front = 0;
				$textwindow->ntdelete( "$step.0", "$step.end" )
				  ;    #"$step.end +1c"
				insert_paragraph_close( $textwindow, $step . '.end' );
				$step++;
				next;
			}

			# Now in the title; skip ahead
			if ( ( $selection =~ /^<h1/ ) and ( not $selection =~ /<\/h1/ ) ) {
				$intitle = 1;
				push @last5, $selection;
				shift @last5 while ( scalar(@last5) > 4 );
				$step++;
				next;
			}

			# no longer in title
			if ( $selection =~ /<\/h1/ ) {
				$intitle = 0;
				push @last5, $selection;
				shift @last5 while ( scalar(@last5) > 4 );
				$step++;
				next;
			}

			# now in some other header than <h1>
			if ( $selection =~ /^<h/ ) {
				push @last5, $selection;
				shift @last5 while ( scalar(@last5) > 4 );
				$step++;
				next;
			}

# <p class="center"> if selection does not have /h, /d, <br>, </p>, or </div> (or last line closed markup)
#   print "int:$intitle:las:$last5[3]:sel:$selection\n";
			if (
				(
					length($selection) 
					&& (   ( !$last5[3] )
						or ( $last5[3] =~ /<\/?h\d?|<br.*?>|<\/p>|<\/div>/ ) )
					&& ( $selection !~ /<\/?h\d?|<br.*?>|<\/p>|<\/div>/ )
					&& ( not $intitle )
				)
			  )
			{
				$textwindow->ntinsert( "$step.0", '<p class="center">' );
			}

# close para end of the last line before if the previous line does not already close
			insert_paragraph_close( $textwindow, ( $step - 1 ) . '.end' )
			  if (!( length($selection) )
				&& ( $last5[3] )
				&& ( $last5[3] !~ /<\/?h\d?|<br.*?>|<\/p>|<\/div>/ ) );
			push @last5, $selection;
			shift @last5 while ( scalar(@last5) > 4 );
			$step++;
			next;
		}    # done with front matter

 #if poetrynumbers, and line ends with two spaces and digits, create line number
		if ( $poetrynumbers && ( $selection =~ s/\s\s(\d+)$// ) ) {
			$selection .= '<span class="linenum">' . $1 . '</span>';
			$textwindow->ntdelete( "$step.0", "$step.end" );
			$textwindow->ntinsert( "$step.0", $selection );
		}

		# if in a poetry block
		if ($poetry) {

			# if end of p/ block, insert closing </div></div>
			if ( $selection =~ /^\x7f*[pP]\/<?/ ) {
				$poetry    = 0;
				$selection = '</div></div>';

				#delete two characters, insert closing </div></div>
				$textwindow->ntdelete( "$step.0", "$step.0 +2c" );
				$textwindow->ntinsert( "$step.0", $selection );
				push @last5, $selection;
				shift @last5 while ( scalar(@last5) > 4 );
				$ital = 0;
				$step++;
				next;
			}

			# end of stanza
			if ( $selection =~ /^$/ ) {
				$textwindow->ntinsert( "$step.0",
					'</div><div class="stanza">' );
				while (1) {
					$step++;
					$selection = $textwindow->get( "$step.0", "$step.end" );
					last if ( $step ge $ler );
					next if ( $selection =~ /^$/ );
					last;
				}
				next;
			}

			# if line ends spaces plus digits insert line number
			if ( $selection =~
				s/\s{2,}(\d+)\s*$/<span class="linenum">$1<\/span>/ )
			{
				$textwindow->ntdelete( "$step.0", "$step.end" );
				$textwindow->ntinsert( "$step.0", $selection );
			}
			my $indent = 0;

			# indent based on number of spaces
			$indent = length($1) if $selection =~ s/^(\s+)//;
			$textwindow->ntdelete( "$step.0", "$step.$indent" ) if $indent;
			unless ($unindentedpoetry) {
				$indent -= 4;
			}    # rewrapped poetry automatically has indent of 4
			$indent = 0 if ( $indent < 0 );

		   #$indent = 2*int( $indent /2 );    # 2 spaces equals indent by one em
		   # open and close italics within each line
			my ( $op, $cl ) = ( 0, 0 );    #open, close italics
			while ( ( my $temp = index $selection, '<i>', $op ) > 0 ) {
				$op = $temp + 3;
			}
			while ( ( my $temp = index $selection, '</i>', $cl ) > 0 ) {
				$cl = $temp + 4;
			}

			# close italics if needed
			if ( !$cl && $ital ) {
				$textwindow->ntinsert( "$step.end", '</i>' );
			}
			if ( !$op && $ital ) {
				$textwindow->ntinsert( "$step.0", '<i>' );
			}
			if ( $op && $cl && ( $cl < $op ) && $ital ) {
				$textwindow->ntinsert( "$step.0",   '<i>' );
				$textwindow->ntinsert( "$step.end", '</i>' );
			}
			if ( $op && ( $cl < $op ) && !$ital ) {
				$textwindow->ntinsert( "$step.end", '</i>' );
				$ital = 1;
			}
			if ( $cl && ( $op < $cl ) && $ital ) {
				if ($op) {
					$textwindow->ntinsert( "$step.0", '<i>' );
				}
				$ital = 0;
			}

			# collect css to indent poetry; classhash will be added in css
			$::lglobal{classhash}->{$indent} =
			    '    .poem span.i' 
			  . $indent
			  . '     {display: block; margin-left: '
			  . ( $indent / 2 )
			  . 'em; padding-left: 3em; text-indent: -3em;}' . "\n";

			#if ( $indent and ( $indent != 2 ) and ( $indent != 4 ) );
			# the above assumes the header already has i2 and i4 indent
			$textwindow->ntinsert( "$step.0",   "<span class=\"i$indent\">" );
			$textwindow->ntinsert( "$step.end", '<br /></span>' );
			push @last5, $selection;
			shift @last5 while ( scalar(@last5) > 4 );
			$step++;
			next;
		}

		# open poetry, if beginning /p
		if ( $selection =~ /^\x7f*\/[pP]$/ ) {
			$poetry = 1;
			$poetryend =
			  $textwindow->search( '-regexp', '--', '^[pP]/$', $step . '.end',
				'end' );

			# determine poetry is not already indented by four spaces
			if (    # a line beginning with four characters, but not all spaces
				$poetryend
				&& (
					$textwindow->search(
						'-regexp',         '--',
						'^(?!\\s{4}).{4}', $step . '.end',
						$poetryend
					)
				)
			  )
			{
				$unindentedpoetry = 1;
			} else {
				$unindentedpoetry = 0;
			}
			if ( ( $last5[2] ) && ( !$last5[3] ) ) {

				# close para
				insert_paragraph_close( $textwindow, ( $step - 2 ) . ".end" )
				  unless (
					$textwindow->get( ( $step - 2 ) . '.0',
						( $step - 2 ) . '.end' ) =~ /<\/p>/
				  );
			}
			$textwindow->ntdelete( $step . '.end -2c', $step . '.end' );
			$selection = '<div class="poem"><div class="stanza">';
			$textwindow->ntinsert( $step . '.end', $selection );
			push @last5, $selection;
			shift @last5 while ( scalar(@last5) > 4 );
			$step++;
			next;
		}

		# in blockquote /#
		if ( $selection =~ /^\x7f*\/\#/ ) {
			$blkquot = 1;
			push @last5, $selection;
			shift @last5 while ( scalar(@last5) > 4 );
			$step++;
			$selection = $textwindow->get( "$step.0", "$step.end" );
			$selection =~ s/^\s+//;
			$textwindow->ntdelete( "$step.0", "$step.end" );
			$textwindow->ntinsert( "$step.0", $blkopen . $selection );

			# close para
			if ( ( $last5[1] ) && ( !$last5[2] ) ) {
				insert_paragraph_close( $textwindow, ( $step - 3 ) . ".end" )
				  unless (
					$textwindow->get( ( $step - 3 ) . '.0',
						( $step - 2 ) . '.end' ) =~
					/<\/?h\d?|<br.*?>|<\/p>|<\/div>/
				  );
			}

			# close para
			$textwindow->ntinsert( ($step) . ".end", '</p>' )
			  unless (
				length $textwindow->get(
					( $step + 1 ) . '.0', ( $step + 1 ) . '.end'
				)
			  );
			push @last5, $selection;
			shift @last5 while ( scalar(@last5) > 4 );
			$step++;
			next;
		}

		# list
		if ( $selection =~ /^\x7f*\/[Ll]/ ) {
			$listmark = 1;
			if ( ( $last5[2] ) && ( !$last5[3] ) ) {
				insert_paragraph_close( $textwindow, ( $step - 2 ) . ".end" )
				  unless (
					$textwindow->get( ( $step - 2 ) . '.0',
						( $step - 2 ) . '.end' ) =~ /<\/p>/
				  );
			}
			$textwindow->ntdelete( "$step.0", "$step.end" );
			$step++;
			$selection = $textwindow->get( "$step.0", "$step.end" );
			$selection = '<ul><li>' . $selection . '</li>';
			$textwindow->ntdelete( "$step.0", "$step.end" );
			$textwindow->ntinsert( "$step.0", $selection );
			push @last5, $selection;
			shift @last5 while ( scalar(@last5) > 4 );
			$step++;
			next;
		}

		# close blockquote #/
		if ( $selection =~ /^\x7f*\#\// ) {
			$blkquot = 0;
			$textwindow->ntinsert( ( $step - 1 ) . '.end', $blkclose );
			push @last5, $selection;
			shift @last5 while ( scalar(@last5) > 4 );
			$step++;
			next;
		}

		#close list
		if ( $selection =~ /^\x7f*[Ll]\// ) {
			$listmark = 0;
			$textwindow->ntdelete( "$step.0", "$step.end" );
			$textwindow->ntinsert( "$step.end", '</ul>' );
			push @last5, '</ul>';
			shift @last5 while ( scalar(@last5) > 4 );
			$step++;
			next;
		}

		#in list
		if ($listmark) {
			if ( $selection eq '' ) { $step++; next; }
			$textwindow->ntdelete( "$step.0", "$step.end" );
			my ( $op, $cl ) = ( 0, 0 );
			while ( ( my $temp = index $selection, '<i>', $op ) > 0 ) {
				$op = $temp + 3;
			}
			while ( ( my $temp = index $selection, '</i>', $cl ) > 0 ) {
				$cl = $temp + 4;
			}
			if ( !$cl && $ital ) {
				$selection .= '</i>';
			}
			if ( !$op && $ital ) {
				$selection = '<i>' . $selection;
			}
			if ( $op && $cl && ( $cl < $op ) && $ital ) {
				$selection = '<i>' . $selection;
				$selection .= '</i>';
			}
			if ( $op && ( $cl < $op ) && !$ital ) {
				$selection .= '</i>';
				$ital = 1;
			}
			if ( $cl && ( $op < $cl ) && $ital ) {
				if ($op) {
					$selection = '<i>' . $selection;
				}
				$ital = 0;
			}
			$textwindow->ntinsert( "$step.0", '<li>' . $selection . '</li>' );
			push @last5, $selection;
			shift @last5 while ( scalar(@last5) > 4 );
			$step++;
			next;
		}

		# delete spaces
		if ($blkquot) {
			if ( $selection =~ s/^(\s+)// ) {
				my $space = length $1;
				$textwindow->ntdelete( "$step.0", "$step.0 +${space}c" );
			}
		}

		# close para at $/ or */
		if ( $selection =~ /^\x7f*[\$\*]\// ) {
			$inblock = 0;
			$ital    = 0;
			$textwindow->replacewith( "$step.0", "$step.end", '</p>' );
			$step++;
			next;
		}

		#insert close para, open para at /$ or /*
		if ( $selection =~ /^\x7f*\/[\$\*]/ ) {
			$inblock = 1;
			if ( ( $last5[2] ) && ( !$last5[3] ) ) {
				insert_paragraph_close( $textwindow, ( $step - 2 ) . '.end' )
				  unless (
					(
						$textwindow->get( ( $step - 2 ) . '.0',
							( $step - 2 ) . '.end' ) =~
						/<\/?[hd]\d?|<br.*?>|<\/p>/
					)
				  );
			}

			#			$textwindow->replacewith( "$step.0", "$step.end", '<p>' );
			$textwindow->delete( "$step.0", "$step.end" );
			insert_paragraph_open( $textwindow, "$step.0" );
			$step++;
			next;
		}

		# if not in title or in block, close para
		if ( ( $last5[2] ) && ( !$last5[3] ) && ( not $intitle ) ) {
			insert_paragraph_close( $textwindow, ( $step - 2 ) . '.end' )
			  unless (
				(
					$textwindow->get( ( $step - 2 ) . '.0',
						( $step - 2 ) . '.end' ) =~
					/<\/?[hd]\d?|<br.*?>|<\/p>|<\/[uo]l>/
				)
				|| ($inblock)
			  );
		}

		# in block, insert <br />
		if ( $inblock || ( $selection =~ /^\s/ ) ) {
			if ( $last5[3] ) {
				if ( $last5[3] =~ /^\S/ ) {
					$last5[3] .= '<br />';
					$textwindow->ntdelete( ( $step - 1 ) . '.0',
						( $step - 1 ) . '.end' );
					$textwindow->ntinsert( ( $step - 1 ) . '.0', $last5[3] );
				}
			}
			$thisend = $textwindow->index( $step . ".end" );
			$textwindow->ntinsert( $thisend, '<br />' );
			if ( $selection =~ /^(\s+)/ ) {
				$indent = ( length($1) / 2 );
				$selection =~ s/^\s+//;
				$selection =~ s/  /&nbsp; /g;
				$selection =~ s/(&nbsp; ){1,}\s?(<span class="linenum">)/ $2/g;
				my ( $op, $cl ) = ( 0, 0 );
				while ( ( my $temp = index $selection, '<i>', $op ) > 0 ) {
					$op = $temp + 3;
				}
				while ( ( my $temp = index $selection, '</i>', $cl ) > 0 ) {
					$cl = $temp + 4;
				}
				if ( !$cl && $ital ) {
					$selection .= '</i>';
				}
				if ( !$op && $ital ) {
					$selection = '<i>' . $selection;
				}
				if ( $op && $cl && ( $cl < $op ) && $ital ) {
					$selection = '<i>' . $selection;
					$selection .= '</i>';
				}
				if ( $op && ( $cl < $op ) && !$ital ) {
					$selection .= '</i>';
					$ital = 1;
				}
				if ( $cl && ( $op < $cl ) && $ital ) {
					if ($op) {
						$selection = '<i>' . $selection;
					}
					$ital = 0;
				}
				$selection =
				    '<span style="margin-left: ' 
				  . $indent . 'em;">'
				  . $selection
				  . '</span>';
				$textwindow->ntdelete( "$step.0", $thisend );
				$textwindow->ntinsert( "$step.0", $selection );
			}
			if ( ( $last5[2] ) && ( !$last5[3] ) && ( $selection =~ /\/\*/ ) ) {
				insert_paragraph_close( $textwindow, ( $step - 2 ) . ".end" )
				  unless (
					$textwindow->get( ( $step - 2 ) . '.0',
						( $step - 2 ) . '.end' ) =~ /<\/[hd]\d?/
				  );
			}
			push @last5, $selection;
			shift @last5 while ( scalar(@last5) > 4 );
			$step++;
			next;
		}

		# four blank lines--start of chapter
		no warnings qw/uninitialized/;
		if (   ( !$last5[0] )
			&& ( !$last5[1] )
			&& ( !$last5[2] )
			&& ( !$last5[3] )
			&& ($selection) )
		{

			#Find the previous page marker
			my $hmark = $textwindow->markPrevious( ($step) . '.0' );

			#print $hmark.":hmarkprevious\n";
			if ($hmark) {
				my $hmarkindex = $textwindow->index($hmark);
				my ( $pagemarkline, $pagemarkcol ) = split /\./, $hmarkindex;

# This sets a mark for the horizontal rule at the page marker rather than just before
# the header.
				if ( $step - 5 <= $pagemarkline ) {
					$textwindow->markSet( "HRULE$pagemarkline", $hmarkindex );
				} else {
					$textwindow->insert($step . '.0-1l','<hr class="chap" />');
				}
			}

			# make an anchor for autogenerate TOC
			$aname =~ s/<\/?[hscalup].*?>//g;
			$aname = makeanchor( ::deaccentdisplay($selection) );
			my $completeheader = $selection;

			# insert chapter heading unless already a para or heading open
			if ( not $selection =~ /<[ph]/ ) {
				$textwindow->ntinsert( "$step.0",
					"<h2><a name=\"" . $aname . "\" id=\"" . $aname . "\">" );
				my $linesinheader=1;
				while (1) {
					$step++;
					$linesinheader++;
					$selection = $textwindow->get( "$step.0", "$step.end" );
					my $restofheader = $selection;
					$restofheader =~ s/^\s+|\s+$//g;
					if ( length($restofheader) ) {
						# accumulate header for TOC
						$completeheader .= ' ' . $restofheader;
					} else {
						# end of header reached
						$step--;
						$textwindow->ntinsert( "$step.end", '</a></h2>' );
						$linesinheader--;
						if ($linesinheader>3) {
							$textwindow->ntinsert( "$step.end", '<Warning: long header>' );
						}
						last;
					}
				}
			}

			# bold face insertion into autogenerated TOC
			unless ( ( $selection =~ /<p/ ) or ( $selection =~ /<h1/ ) ) {
				$selection =~ s/<sup>.*?<\/sup>//g;
				$selection =~ s/<[^>]+>//g;
				$selection = "<b>$selection</b>";
				push @contents,
				    "<a href=\"#" 
				  . $aname . "\">"
				  . $completeheader
				  . "</a><br />\n";
			}
			$selection .= '<h2>';
			$textwindow->see("$step.0");
			$textwindow->update;

			#open subheading with <p>
		} elsif ( ( $last5[2] =~ /<h2>/ ) && ($selection) ) {
			$textwindow->ntinsert( "$step.0", '<p>' )
			  unless ( ( $selection =~ /<[pd]/ )
				|| ( $selection =~ /<[hb]r>/ )
				|| ($inblock) );

			#open with para if blank line then nonblank line
		} elsif ( ( $last5[2] ) && ( !$last5[3] ) && ($selection) ) {
			$textwindow->ntinsert( "$step.0", '<p>' )
			  unless ( ( $selection =~ /<[phd]/ )
				|| ( $selection =~ /<[hb]r>/ )
				|| ($inblock) );

			#open with para if blank line then two nonblank lines
		} elsif ( ( $last5[1] )
			&& ( !$last5[2] )
			&& ( !$last5[3] )
			&& ($selection) )
		{
			$textwindow->ntinsert( "$step.0", '<p>' )
			  unless ( ( $selection =~ /<[phd]/ )
				|| ( $selection =~ /<[hb]r>/ )
				|| ($inblock) );

			#open with para if blank line then three nonblank lines
		} elsif ( ( $last5[0] )
			&& ( !$last5[1] )
			&& ( !$last5[2] )
			&& ( !$last5[3] )
			&& ($selection) )
		{   #start of new paragraph unless line contains <p, <h, <d, <hr, or <br
			$textwindow->ntinsert( "$step.0", '<p>' )
			  unless ( ( $selection =~ /<[phd]/ )
				|| ( $selection =~ /<[hb]r>/ )
				|| ($inblock) );
		}
		push @last5, $selection;
		shift @last5 while ( scalar(@last5) > 4 );
		$step++;
	}

	# close the autogenerated TOC and insert at line called contents
	#push @contents, '</p>';
	local $" = '';
	my $contentstext =
"\n\n<!-- Autogenerated TOC. Modify or delete as required. -->\n@contents\n<!-- End Autogenerated TOC. -->\n\n";
	$contentstext = "<p>" . $contentstext . "</p>"
	  unless is_paragraph_open( $textwindow, $incontents );
	$textwindow->insert( $incontents, $contentstext ) if @contents;
	return;
}

sub html_convert_underscoresmallcaps {
	my ($textwindow) = @_;
	my $thisblockstart = '1.0';
	::working("Converting underscore and small caps markup");
	while ( $thisblockstart =
		$textwindow->search( '-exact', '--', '<u>', '1.0', 'end' ) )
	{
		$textwindow->ntdelete( $thisblockstart, "$thisblockstart+3c" );
		$textwindow->ntinsert( $thisblockstart, '<span class="u">' );
	}
	while ( $thisblockstart =
		$textwindow->search( '-exact', '--', '</u>', '1.0', 'end' ) )
	{
		$textwindow->ntdelete( $thisblockstart, "$thisblockstart+4c" );
		$textwindow->ntinsert( $thisblockstart, '</span>' );
	}
	while ( $thisblockstart =
		$textwindow->search( '-exact', '--', '<sc>', '1.0', 'end' ) )
	{
		$textwindow->ntdelete( $thisblockstart, "$thisblockstart+4c" );
		$textwindow->ntinsert( $thisblockstart, '<span class="smcap">' );
	}
	while ( $thisblockstart =
		$textwindow->search( '-exact', '--', '</sc>', '1.0', 'end' ) )
	{
		$textwindow->ntdelete( $thisblockstart, "$thisblockstart+5c" );
		$textwindow->ntinsert( $thisblockstart, '</span>' );
	}
	while ( $thisblockstart =
		$textwindow->search( '-exact', '--', '</pre></p>', '1.0', 'end' ) )
	{
		$textwindow->ntdelete( "$thisblockstart+6c", "$thisblockstart+10c" );
	}

	# Set opening and closing markup for footnotes
	$thisblockstart = '1.0';
	while (
		$thisblockstart = $textwindow->search(
			'-exact', '--', '<p>FOOTNOTES:', $thisblockstart, 'end'
		)
	  )
	{
		$textwindow->ntdelete( $thisblockstart, "$thisblockstart+17c" );
		$textwindow->insert( $thisblockstart,
			'<div class="footnotes"><h3>FOOTNOTES:</h3>' );
		# Improved logic for finding end of footnote block: find 
		# the next footnote block
		my $nextfootnoteblock = $textwindow->search(
			'-exact', '--', 'FOOTNOTES:', $thisblockstart.'+1l', 'end'
		);
		unless ($nextfootnoteblock) {
			$nextfootnoteblock='end';			
		}
		unless ($nextfootnoteblock) {
			$nextfootnoteblock='end';			
		}
		# find the start of last footnote 
		my $lastfootnoteinblock = $textwindow->search(
			'-exact','-backwards', '--', '<div class="footnote">', $nextfootnoteblock
		);
		# find the end of the last footnote
		my $endoflastfootnoteinblock = $textwindow->search(
			'-exact', '--', '</p></div>', $lastfootnoteinblock
		);
		$textwindow->insert( $endoflastfootnoteinblock.'+10c', '</div>' );
		if ($endoflastfootnoteinblock){
			$thisblockstart =$endoflastfootnoteinblock
		} else {
			$thisblockstart='end';
		}
	}
	return;
}

sub html_convert_sidenotes {
	my ($textwindow) = @_;
	::working("Converting\nSidenotes");
	my $thisnoteend;
	my $length;
	my $thisblockstart = '1.0';
	while (
		$thisblockstart = $textwindow->search(
			'-regexp',
			'-count' => \$length,
			'--', '(<p>)?\[Sidenote:\s*', '1.0', 'end'
		)
	  )
	{
		$textwindow->ntdelete( $thisblockstart,
			$thisblockstart . '+' . $length . 'c' );
		$textwindow->ntinsert( $thisblockstart, '<div class="sidenote">' );
		$thisnoteend = $textwindow->search( '--', ']', $thisblockstart, 'end' );
		while ( $textwindow->get( "$thisblockstart+1c", $thisnoteend ) =~ /\[/ )
		{
			$thisblockstart = $thisnoteend;
			$thisnoteend =
			  $textwindow->search( '--', ']</p>', $thisblockstart, 'end' );
		}
		$textwindow->ntdelete( $thisnoteend, "$thisnoteend+5c" )
		  if $thisnoteend;
		$textwindow->ntinsert( $thisnoteend, '</div>' ) if $thisnoteend;
	}
	while ( $thisblockstart =
		$textwindow->search( '--', '</div></div></p>', '1.0', 'end' ) )
	{
		$textwindow->ntdelete( "$thisblockstart+12c", "$thisblockstart+16c" );
	}
	return;
}

sub html_convert_pageanchors {
	my $textwindow = $::textwindow;
	::working("Inserting Page Number Markup");
	$|++;
	my $markindex;
	my @pagerefs;   # keep track of first/last page markers at the same position
	my $tempcounter;
	my $mark = '1.0';
	while ( $textwindow->markPrevious($mark) ) {
		$mark = $textwindow->markPrevious($mark);
	}

	# Work through all the text markers
	while ( $mark = $textwindow->markNext($mark) ) {

		# Only look at page markers
		if ( $mark =~ m{Pg(\S+)} ) {

			# This is the custom page label
			my $num = $::pagenumbers{$mark}{label};
			$num =~ s/Pg // if defined $num;

			# Use the marker unless there is a custom page label
			$num = $1 unless $::pagenumbers{$mark}{action};
			next unless length $num;

			# Strip leading zeroes
			$num =~ s/^0+(\d)/$1/;

			# Get the next marker
			$markindex = $textwindow->index($mark);

			# This is not used
			my $check = $textwindow->get( $markindex . 'linestart',
				$markindex . 'linestart +4c' );
			my $pagereference;

			# marknext is the same as markindex?
			my $marknext = $textwindow->markNext($mark);
			my $marknextindex;

			# Skip over non-page markers
			while ($marknext) {
				if ( not $marknext =~ m{Pg(\S+)} ) {
					$marknext = $textwindow->markNext($marknext);
				} else {
					last;
				}
			}
			if ($marknext) {
				$marknextindex = $textwindow->index($marknext);
			} else {
				$marknextindex = 0;
			}

			# Accumulate markers in pagerefs
			if ( $::lglobal{exportwithmarkup} ) {
				push @pagerefs, $mark;    # do not drop leading zeroes
			} else {
				push @pagerefs, $num;
			}

			# Multiple page markers at one place or with 2 characters
			if (
				( $markindex == $marknextindex )
				|| (
					( $marknextindex ne '0' )
					&& (
						$textwindow->compare(
							$markindex, '>', "$marknextindex-1l"
						)
					)
				)
			  )
			{
				$pagereference = "";
			} else {

				# Time to push page markers into text
				if (@pagerefs) {
					my $br = "";
					$pagereference = "";
					no warnings;    # roman numerals are nonnumeric for sort
					for ( sort { $a <=> $b } @pagerefs ) {
						if ( $::lglobal{exportwithmarkup} ) {
							$pagereference .= "$br" . "<$_>";
							$br = '';    # No page break for exportwithmarkup
						} else {
							$pagereference .= "$br"
							  . "<a name=\"$::htmllabels{pglabel}$_\" id=\"$::htmllabels{pglabel}$_\">$::htmllabels{pgnumbefore}$_$::htmllabels{pgnumafter}</a>";
							$br = "<br />";
						}
					}
					@pagerefs = ();
				} else {

					# just one page reference
					if ( $::lglobal{exportwithmarkup} ) {
						$pagereference = "<$mark>";
					} else {
						$pagereference =
"<a name=\"$::htmllabels{pglabel}$num\" id=\"$::htmllabels{pglabel}$num\">$::htmllabels{pgnumbefore}$num$::htmllabels{pgnumafter}</a>";
					}
				}
			}

			# comment only
			$textwindow->ntinsert( $markindex, "<!-- Page $num -->" )
			  if ( $::pagecmt and $num );
			if ($pagereference) {

				# If exporting with page markers, insert where found
				$textwindow->ntinsert( $markindex, $pagereference )
				  if ( $::lglobal{exportwithmarkup} and $num );

				# Otherwise may need to insert elsewhere
				my $insertpoint = $markindex;
				my $inserted    = 0;

				# logic move page ref if at end of paragraph
				my $nextpstart =
				  $textwindow->search( '--', '<p', $markindex, 'end' )
				  || 'end';
				my $nextpend =
				  $textwindow->search( '--', '</p>', $markindex, 'end' )
				  || 'end';
				my $inserttext =
				  "<span class=\"pagenum\">$pagereference</span>";
				if ( $textwindow->compare( $nextpend, '<=', $markindex . '+1c' )
				  )
				{

					#move page anchor from end of paragraph
					$insertpoint = $nextpend . '+4c';
					$inserttext  = '<p>' . $inserttext . '</p>';
				}
				my $pstart =
				  $textwindow->search( '-backwards', '-exact', '--', '<p',
					$markindex, '1.0' )
				  || '1.0';
				my $pend =
				  $textwindow->search( '-backwards', '-exact', '--', '</p>',
					$markindex, '1.0' )
				  || '1.0';
				my $sstart =
				  $textwindow->search( '-backwards', '-exact', '--', '<div ',
					$markindex, '1.0' )
				  || '1.0';
				my $send =
				  $textwindow->search( '-backwards', '-exact', '--', '</div>',
					$markindex, '1.0' )    #$pend
				  || '1.0';                #$pend
				   # if the previous <p> or <div>is not closed, then wrap in <p>
				if (
					not( $textwindow->compare( $pend, '<', $pstart )
						or ( $textwindow->compare( $send, '<', $sstart ) ) )
				  )
				{
					$inserttext = '<p>' . $inserttext . '</p>';
				}

				# Oops find headers not <hr>
				my $hstart =
				  $textwindow->search( '-backwards', '-regexp', '--', '<h\d',
					$markindex, '1.0' )
				  || '1.0';
				my $hend =
				  $textwindow->search( '-backwards', '-exact', '--', '</h',
					$markindex, '1.0' )
				  || '1.0';
				if ( $textwindow->compare( $hend, '<', $hstart ) ) {
					$insertpoint = $textwindow->index("$hstart-1l lineend");
				}
				my $spanstart =
				  $textwindow->search( '-backwards', '-exact', '--', '<span',
					$markindex, '1.0' )
				  || '1.0';
				my $spanend =
				  $textwindow->search( '-backwards', '-exact', '--', '</span',
					$markindex, '1.0' )
				  || '1.0';
				if ( $textwindow->compare( $spanend, '<', $spanstart ) ) {
					$insertpoint = $spanend . '+7c';
				}
				$textwindow->ntinsert( $insertpoint, $inserttext )
				  if $::lglobal{pageanch};
			}
		} else {
			if ( $mark =~ m{HRULE} )
			{    #place the <hr> for a chapter before the page number
				my $hrulemarkindex = $textwindow->index($mark);
				my $pgstart =
				  $textwindow->search( '-backwards', '--', '<p><span',
					$hrulemarkindex . '+10c', '1.0' )
				  || '1.0';
				if (
					$textwindow->compare(
						$hrulemarkindex . '+50c',
						'>', $pgstart
					)
				  )
				{
					$textwindow->ntinsert( $pgstart, '<hr class="chap" />' );
				} else {
					$textwindow->ntinsert( $hrulemarkindex,
						'<hr class="chap" />' );
				}
			}
		}
	}
	::working();
	return;
}

sub html_parse_header {
	my ( $textwindow, $headertext ) = @_;
	my $selection;
	my $step;
	::working('Parsing Header');
	$selection = $textwindow->get( '1.0', '1.end' );
	if ( $selection =~ /DOCTYPE/ ) {
		$step = 1;
		while (1) {
			$selection = $textwindow->get( "$step.0", "$step.end" );
			$headertext .= ( $selection . "\n" );
			$textwindow->ntdelete( "$step.0", "$step.end" );
			last if ( $selection =~ /^\<body/ );
			$step++;
			last if ( $textwindow->compare( "$step.0", '>', 'end' ) );
		}
		$textwindow->ntdelete( '1.0', "$step.0 +1c" );
	} else {
		unless ( -e 'header.txt' ) {
			::copy( 'headerdefault.txt', 'header.txt' );
		}
		open my $infile, '<', 'header.txt'
		  or warn "Could not open header file. $!\n";
		while (<$infile>) {
			$_ =~ s/\cM\cJ|\cM|\cJ/\n/g;

			# FIXME: $_ = eol_convert($_);
			$headertext .= $_;
		}
		close $infile;
	}

	# extract title and author info
	my ( $title, $author ) = get_title_author();
	$headertext =~ s/TITLE/$title/ if $title;
	$headertext =~ s/AUTHOR/$author/ if $author;
	$headertext =~ s/BOOKLANG/$::booklang/g;
	if ( $::lglobal{leave_utf} ) {
		$headertext =~ s/BOOKCHARSET/utf-8/;
	} elsif ( $::lglobal{keep_latin1} ) {
		$headertext =~ s/BOOKCHARSET/iso-8859-1/;
	} else {
		$headertext =~ s/BOOKCHARSET/ascii/;
	}
	eval ( '$headertext =~ s#\{LANG='. uc( $::booklang ) .'\}(.*?)\{/LANG\}#$1#gs' ) ; # code duplicated near footertext

	# locate and markup title
	$step = 0;
	my $intitle       = 0;
	while (1) {
		$step++;
		last if ( $textwindow->compare( "$step.0", '>', 'end' ) );
		$selection = $textwindow->get( "$step.0", "$step.end" );
		next if ( $selection =~ /^\[Illustr/i );    # Skip Illustrations
		next if ( $selection =~ /^\/[\$fx]/i );     # Skip /$|/F tags
		if (    ($intitle)
			and ( ( not length($selection) or ( $selection =~ /^f\//i ) ) ) )
		{
			$step--;
			$textwindow->ntinsert( "$step.end", '</h1>' );
			last;
		}                                           #done finding title
		next if ( $selection =~ /^\/[\$fx]/i );     # Skip /$|/F tags
		next unless length($selection);
		if ( $intitle == 0 ) {
			$textwindow->ntinsert( "$step.0", '<h1>' );
			$intitle       = 1;
		} else {
			if ( ( $title =~ /^by/i ) or ( $title =~ /\Wby\s/i ) ) {
				$step--;
				$textwindow->ntinsert( "$step.end", '</h1>' );
				last;
			}
		}
	}
	return $headertext;
}

sub get_title_author {
	my $textwindow = $::textwindow;
	my $step = 0;
	my ( $selection, $title, $author );
	my $completetitle = '';
	my $intitle = 0;
	while (1) { # find title
		$step++;
		last if ( $textwindow->compare( "$step.0", '>', 'end' ) || $step>500 );
		$selection = $textwindow->get( "$step.0", "$step.end" );
		next if ( $selection =~ /^\[Illustr/i );    # Skip Illustrations
		next if ( $selection =~ /^\/[\$fx]/i );     # Skip /$|/F tags
		if (    ($intitle)
			and ( ( not length($selection) or ( $selection =~ /^f\//i ) ) ) )
		{
			$step--;
			last;
		}                                           #done finding title
		next if ( $selection =~ /^\/[\$fx]/i );     # Skip /$|/F tags
		next unless length($selection);
		$title = $selection;
		$title =~ s/[,.]$//;                        #throw away trailing , or .
		$title =  ::titlecase($title);
		$title =~ s/^\s+|\s+$//g;
		$title =~ s/<[^>]*>//g;
		if ( $intitle == 0 ) {
			$completetitle = $title;
			$intitle       = 1;
		} else {
			if ( ( $title =~ /^by/i ) or ( $title =~ /\Wby\s/i ) ) {
				$step--;
				last;
			}
			$completetitle .= ' ' . $title;
		}
	}
	while (1) {
		$step++;
		last if ( $textwindow->compare( "$step.0", '>', 'end' ) );
		$selection = $textwindow->get( "$step.0", "$step.end" );
		if ( ( $selection =~ /^by/i ) and ( $step < 100 ) ) {
			last if ( $selection =~ /[\/[Ff]/ );
			if ( $selection =~ /^by$/i ) {
				do {
					$step++;
					$selection = $textwindow->get( "$step.0", "$step.end" );
				} until ( $selection ne "" );
				$author = $selection;
				$author =~ s/,$//;
			} else {
				$author = $selection;
				$author =~ s/\s$//i;
			}
		}
		last if $author || ( $step > 100 );
	}
	if ($author) {
		$author =~ s/^by //i;
		$author = ucfirst( lc($author) );
		$author     =~ s/(\W)(\w)/$1\U$2\E/g;
		$author =~ s/Amp/amp/;
	}
	return ( $completetitle, $author );
}

sub html_wrapup {
	my ( $textwindow, $headertext, $leave_utf, $autofraction ) = @_;
	my $thisblockstart;
	::fracconv( $textwindow, '1.0', 'end' ) if $autofraction;
	$textwindow->ntinsert( '1.0', $headertext );
	if ($leave_utf) {
		$thisblockstart =
		  $textwindow->search( '-exact', '--', 'charset=iso-8859-1', '1.0',
			'end' );
		if ($thisblockstart) {
			$textwindow->ntdelete( $thisblockstart, "$thisblockstart+18c" );
			$textwindow->ntinsert( $thisblockstart, 'charset=utf-8' );
		}
	}
	insert_paragraph_close( $textwindow, 'end' );
	if ( -e 'footer.txt' ) {
		my $footertext;
		open my $infile, '<', 'footer.txt';
		while (<$infile>) {
			$_ =~ s/\cM\cJ|\cM|\cJ/\n/g;

			# FIXME: $_ = eol_convert($_);
			$footertext .= $_;
		}
		close $infile;
		$textwindow->ntinsert( 'end', $footertext );
	}
	$textwindow->ntinsert( 'end', "\n<\/body>\n<\/html>" );

	::named ( '><p', ">\n\n<p" ); # improve readability of code
	::named ( '><hr', ">\n\n<hr" );

	$thisblockstart = $textwindow->search( '--', '</style', '1.0', '500.0' );
	$thisblockstart = '75.0' unless $thisblockstart;
	$thisblockstart =
	  $textwindow->search( -backwards, '--', '}', $thisblockstart, '10.0' );
	for ( reverse( sort( values( %{ $::lglobal{classhash} } ) ) ) ) {
		$textwindow->ntinsert( $thisblockstart . ' +1l linestart', $_ )
		  if keys %{ $::lglobal{classhash} };
	}
	%{ $::lglobal{classhash} } = ();
	::working();
	$textwindow->Unbusy;
	$textwindow->see('1.0');
	return;
}

# insert </p> only if there is an open <p> tag
sub insert_paragraph_close {
	my ( $textwindow, $index ) = @_;
	if ( is_paragraph_open( $textwindow, $index ) ) {
		$textwindow->ntinsert( $index, '</p>' );
		return 1;
	}
	return 0;
}

sub is_paragraph_open {
	my ( $textwindow, $index ) = @_;
	my $pstart =
	  $textwindow->search( '-backwards', '-regexp', '--', '<p(>| )', $index,
		'1.0' )
	  || '1.0';
	my $pend = $textwindow->search( '-backwards', '--', '</p>', $index, '1.0' )
	  || '1.0';
	if ( $textwindow->compare( $pend, '<', $pstart ) ) {
		return 1;
	}
	return 0;
}

# insert <p> only if there is not an open <p> tag
sub insert_paragraph_open {
	my ( $textwindow, $index ) = @_;
	if ( not is_paragraph_open( $textwindow, $index ) ) {
		$textwindow->ntinsert( $index, '<p>' );
		return 1;
	}
	return 0;
}

sub htmlimage {
	my ( $textwindow, $top, $thisblockstart, $thisblockend ) = @_;
	$thisblockstart = 'insert'        unless $thisblockstart;
	$thisblockend   = $thisblockstart unless $thisblockend;
	$textwindow->markSet( 'thisblockstart', $thisblockstart );
	$textwindow->markSet( 'thisblockend',   $thisblockend );
	my $selection;
	$selection = $textwindow->get( $thisblockstart, $thisblockend ) if @_;
	$selection = '' unless $selection;
	my $preservep = '';
	$preservep = '<p>' if $selection !~ /<\/p>$/;
	$selection =~ s/<p>\[Illustration:/[Illustration:/;
	$selection =~ s/\[Illustration:?\s*(\.*)/$1/;
	$selection =~ s/\]<\/p>$/]/;
	$selection =~ s/(\.*)\]$/$1/;
	my ( $fname, $extension );
	my $xpad = 0;
	$::globalimagepath = $::globallastpath
	  unless $::globalimagepath;
	my ($alignment);
	$::lglobal{htmlorig}  = $top->Photo;
	$::lglobal{htmlthumb} = $top->Photo;

	if ( defined( $::lglobal{htmlimpop} ) ) {
		$::lglobal{htmlimpop}->deiconify;
		$::lglobal{htmlimpop}->raise;
		$::lglobal{htmlimpop}->focus;
	} else {
		$::lglobal{htmlimpop} = $top->Toplevel;
		$::lglobal{htmlimpop}->title('Image');
		::initialize_popup_without_deletebinding('htmlimpop');
		my $f1 =
		  $::lglobal{htmlimpop}->LabFrame( -label => 'File Name' )
		  ->pack( -side => 'top', -anchor => 'n', -padx => 2 );
		$::lglobal{imgname} =
		  $f1->Entry( -width => 45, )->pack( -side => 'left' );
		my $f3 =
		  $::lglobal{htmlimpop}->LabFrame( -label => 'Alt text' )
		  ->pack( -side => 'top', -anchor => 'n' );
		$::lglobal{alttext} =
		  $f3->Entry( -width => 45, )->pack( -side => 'left' );
		my $f4a =
		  $::lglobal{htmlimpop}->LabFrame( -label => 'Caption text' )
		  ->pack( -side => 'top', -anchor => 'n' );
		$::lglobal{captiontext} =
		  $f4a->Entry( -width => 45, )->pack( -side => 'left' );
		my $f4 =
		  $::lglobal{htmlimpop}->LabFrame( -label => 'Title text' )
		  ->pack( -side => 'top', -anchor => 'n' );
		$::lglobal{titltext} =
		  $f4->Entry( -width => 45, )->pack( -side => 'left' );
		my $f5 =
		  $::lglobal{htmlimpop}->LabFrame( -label => 'Geometry' )
		  ->pack( -side => 'top', -anchor => 'n' );
		my $f51 = $f5->Frame->pack( -side => 'top', -anchor => 'n' );
		$f51->Label( -text => 'Width' )->pack( -side => 'left' );
		$::lglobal{widthent} = $f51->Entry(
			-width    => 10,
			-validate => 'all',
			-vcmd     => sub {
				return 1 if ( !$::lglobal{ImageSize} );
				return 1 unless $::lglobal{htmlimgar};
				return 1 unless ( $_[0] && $_[2] );
				return 0 unless ( defined $_[1] && $_[1] =~ /\d/ );
				my ( $sizex, $sizey ) =
				  Image::Size::imgsize( $::lglobal{imgname}->get );
				$::lglobal{heightent}->delete( 0, 'end' );
				$::lglobal{heightent}
				  ->insert( 'end', ( int( $sizey * ( $_[0] / $sizex ) ) ) );
				return 1;
			}
		)->pack( -side => 'left' );
		$f51->Label( -text => 'Height' )->pack( -side => 'left' );
		$::lglobal{heightent} = $f51->Entry(
			-width    => 10,
			-validate => 'all',
			-vcmd     => sub {
				return 1 if ( !$::lglobal{ImageSize} );
				return 1 unless $::lglobal{htmlimgar};
				return 1 unless ( $_[0] && $_[2] );
				return 0 unless ( defined $_[1] && $_[1] =~ /\d/ );
				my ( $sizex, $sizey ) =
				  Image::Size::imgsize( $::lglobal{imgname}->get );
				$::lglobal{widthent}->delete( 0, 'end' );
				$::lglobal{widthent}
				  ->insert( 'end', ( int( $sizex * ( $_[0] / $sizey ) ) ) );
				return 1;
			}
		)->pack( -side => 'left' );
		my $ar = $f51->Checkbutton(
			-text     => 'Maintain AR',
			-variable => \$::lglobal{htmlimgar},
			-onvalue  => 1,
			-offvalue => 0
		)->pack( -side => 'left' );
		$ar->select;
		my $f52 = $f5->Frame->pack( -side => 'top', -anchor => 'n' );
		$::lglobal{htmlimggeom} =
		  $f52->Label( -text => '' )->pack( -side => 'left' );
		my $f2 =
		  $::lglobal{htmlimpop}->LabFrame( -label => 'Alignment' )
		  ->pack( -side => 'top', -anchor => 'n' );
		$f2->Radiobutton(
			-variable    => \$alignment,
			-text        => 'Left',
			-selectcolor => $::lglobal{checkcolor},
			-value       => 'left',
		)->grid( -row => 1, -column => 1 );
		my $censel = $f2->Radiobutton(
			-variable    => \$alignment,
			-text        => 'Center',
			-selectcolor => $::lglobal{checkcolor},
			-value       => 'center',
		)->grid( -row => 1, -column => 2 );
		$f2->Radiobutton(
			-variable    => \$alignment,
			-text        => 'Right',
			-selectcolor => $::lglobal{checkcolor},
			-value       => 'right',
		)->grid( -row => 1, -column => 3 );
		$censel->select;
		my $f8 =
		  $::lglobal{htmlimpop}->Frame->pack( -side => 'top', -anchor => 'n' );
		$f8->Button(
			-text    => 'Ok',
			-width   => 10,
			-command => sub {
				my $name = $::lglobal{imgname}->get;
				if ($name) {
					my $sizexy =
					    'width="'
					  . $::lglobal{widthent}->get
					  . '" height="'
					  . $::lglobal{heightent}->get . '"';
					my $width = $::lglobal{widthent}->get;
					return unless $name;
					( $fname, $::globalimagepath, $extension ) =
					  ::fileparse($name);
					$::globalimagepath = ::os_normal($::globalimagepath);
					$name =~ s/[\/\\]/\;/g;
					my $tempname = $::globallastpath;
					$tempname =~ s/[\/\\]/\;/g;
					$name     =~ s/$tempname//;
					$name     =~ s/;/\//g;
					$alignment = 'center' unless $alignment;
					$selection = $::lglobal{captiontext}->get;
					$selection ||= '';
					my $alt = $::lglobal{alttext}->get;
					$alt =~ s/"/&quot;/g;
					$alt = " alt=\"$alt\"";
					$selection = "<span class=\"caption\">$selection</span>\n"
					  if $selection;
					$preservep = '' unless $selection;
					my $title = $::lglobal{titltext}->get || '';
					$title =~ s/"/&quot;/g;
					$title = " title=\"$title\"" if $title;
					$textwindow->addGlobStart;
					my $closeimg =
"px;\">\n<img src=\"$name\" $sizexy$alt$title />\n$selection</div>$preservep";

					if ( $alignment eq 'center' ) {
						$textwindow->delete( 'thisblockstart', 'thisblockend' );
						$textwindow->insert( 'thisblockstart',
							    "<div class=\"figcenter\" style=\"width: " 
							  . $width
							  . $closeimg );
					} elsif ( $alignment eq 'left' ) {
						$textwindow->delete( 'thisblockstart', 'thisblockend' );
						$textwindow->insert( 'thisblockstart',
							    "<div class=\"figleft\" style=\"width: " 
							  . $width
							  . $closeimg );
					} elsif ( $alignment eq 'right' ) {
						$textwindow->delete( 'thisblockstart', 'thisblockend' );
						$textwindow->insert( 'thisblockstart',
							    "<div class=\"figright\" style=\"width: " 
							  . $width
							  . $closeimg );
					}
					$textwindow->addGlobEnd;
					$::lglobal{htmlthumb}->delete
					  if $::lglobal{htmlthumb};
					$::lglobal{htmlthumb}->destroy
					  if $::lglobal{htmlthumb};
					$::lglobal{htmlorig}->delete
					  if $::lglobal{htmlorig};
					$::lglobal{htmlorig}->destroy
					  if $::lglobal{htmlorig};
					for (
						$::lglobal{alttext},  $::lglobal{titltext},
						$::lglobal{widthent}, $::lglobal{heightent},
						$::lglobal{imagelbl}, $::lglobal{imgname}
					  )
					{
						$_->destroy;
					}
					$textwindow->tagRemove( 'highlight', '1.0', 'end' );
					$::lglobal{htmlimpop}->destroy
					  if $::lglobal{htmlimpop};
					undef $::lglobal{htmlimpop}
					  if $::lglobal{htmlimpop};
				}
			}
		)->pack;
		my $f = $::lglobal{htmlimpop}->Frame->pack;
		$::lglobal{imagelbl} = $f->Label(
			-text       => 'Thumbnail',
			-justify    => 'center',
			-background => $::bkgcolor,
		)->grid( -row => 1, -column => 1 );
		$::lglobal{imagelbl}
		  ->bind( $::lglobal{imagelbl}, '<1>', \&thumbnailbrowse );
		$::lglobal{htmlimpop}->protocol(
			'WM_DELETE_WINDOW' => sub {
				$::lglobal{htmlthumb}->delete  if $::lglobal{htmlthumb};
				$::lglobal{htmlthumb}->destroy if $::lglobal{htmlthumb};
				$::lglobal{htmlorig}->delete   if $::lglobal{htmlorig};
				$::lglobal{htmlorig}->destroy  if $::lglobal{htmlorig};
				for (
					$::lglobal{alttext},  $::lglobal{titltext},
					$::lglobal{widthent}, $::lglobal{heightent},
					$::lglobal{imagelbl}, $::lglobal{imgname}
				  )
				{
					$_->destroy;
				}
				$textwindow->tagRemove( 'highlight', '1.0', 'end' );
				$::lglobal{htmlimpop}->destroy;
				undef $::lglobal{htmlimpop};
			}
		);
		$::lglobal{htmlimpop}->transient($top);
	}
	$::lglobal{alttext}->delete( 0, 'end' ) if $::lglobal{alttext};
	$::lglobal{titltext}->delete( 0, 'end' ) if $::lglobal{titltext};
	$::lglobal{captiontext}->insert( 'end', $selection );
	&thumbnailbrowse();
}

sub htmlimages {
	my ( $textwindow, $top ) = @_;
	my $length;
	my $start =
	  $textwindow->search( '-regexp', '--', '(<p>)?\[Illustration', '1.0',
		'end' );
	return unless $start;
	$textwindow->see($start);
	my $end = $textwindow->search(
		'-regexp',
		'-count' => \$length,
		'--', '\](<\/p>)?', $start, 'end'
	);
	$end = $textwindow->index( $end . ' +' . $length . 'c' );
	return unless $end;
	$textwindow->tagAdd( 'highlight', $start, $end );
	$textwindow->markSet( 'insert', $start );
	::update_indicators();
	htmlimage( $textwindow, $top, $start, $end );
}

sub htmlautoconvert {
	my ( $textwindow, $top ) = @_;
	::viewpagenums() if ( $::lglobal{seepagenums} );
	my $headertext;
	if ( $::lglobal{global_filename} =~ /No File Loaded/ ) {
		$top->messageBox(
			-icon    => 'warning',
			-type    => 'OK',
			-message => 'File must be saved first.'
		);
		return;
	}

	# Backup file
	$textwindow->Busy;
	my $savefn = $::lglobal{global_filename};
	$::lglobal{global_filename} =~ s/\.[^\.]*?$//;
	my $newfn = $::lglobal{global_filename} . '-htmlbak.txt';
	::working("Saving backup of file\nto $newfn");
	$textwindow->SaveUTF($newfn);
	$::lglobal{global_filename} = $newfn;
	::_bin_save();
	$::lglobal{global_filename} = $savefn;
	$textwindow->FileName($savefn);
	html_convert_codepage();
	html_convert_ampersands($textwindow);
	$headertext = html_parse_header( $textwindow, $headertext );
	html_convert_emdashes();
	$::lglobal{fnsecondpass}  = 0;
	$::lglobal{fnsearchlimit} = 1;
	html_convert_footnotes( $textwindow, $::lglobal{fnarray} );
	html_convert_body(
		$textwindow, $headertext,
		$::lglobal{cssblockmarkup},
		$::lglobal{poetrynumbers}
	);
	html_cleanup_markers($textwindow);
	html_convert_underscoresmallcaps($textwindow);
	html_convert_sidenotes($textwindow);
	html_convert_pageanchors();
	html_convert_utf( $textwindow, $::lglobal{leave_utf},
		$::lglobal{keep_latin1} );
	html_wrapup( $textwindow, $headertext, $::lglobal{leave_utf},
		$::lglobal{autofraction} );
	#$textwindow->ResetUndo;
}

sub thumbnailbrowse {
	my $types =
	  [ [ 'Image Files', [ '.gif', '.jpg', '.png' ] ], [ 'All Files', ['*'] ],
	  ];
	my $name = $::lglobal{htmlimpop}->getOpenFile(
		-filetypes  => $types,
		-title      => 'File Load',
		-initialdir => $::globalimagepath
	);
	return unless ($name);
	my $xythumb = 200;
	if ( $::lglobal{ImageSize} ) {
		my ( $sizex, $sizey ) = Image::Size::imgsize($name);
		$::lglobal{widthent}->delete( 0, 'end' );
		$::lglobal{heightent}->delete( 0, 'end' );
		$::lglobal{widthent}->insert( 'end', $sizex );
		$::lglobal{heightent}->insert( 'end', $sizey );
		$::lglobal{htmlimggeom}
		  ->configure( -text => "Actual image size: $sizex x $sizey pixels" );
	} else {
		$::lglobal{htmlimggeom}
		  ->configure( -text => "Actual image size: unknown" );
	}
	$::lglobal{htmlorig}->blank;
	$::lglobal{htmlthumb}->blank;
	$::lglobal{imgname}->delete( '0', 'end' );
	$::lglobal{imgname}->insert( 'end', $name );
	my ( $fn, $ext );
	( $fn, $::globalimagepath, $ext ) = ::fileparse( $name, '(?<=\.)[^\.]*$' );
	$::globalimagepath = ::os_normal($::globalimagepath);
	$ext =~ s/jpg/jpeg/;

	if ( lc($ext) eq 'gif' ) {
		$::lglobal{htmlorig}->read( $name, -shrink );
	} else {
		$::lglobal{htmlorig}->read( $name, -format => $ext, -shrink );
	}
	my $sw = int( ( $::lglobal{htmlorig}->width ) / $xythumb );
	my $sh = int( ( $::lglobal{htmlorig}->height ) / $xythumb );
	if ( $sh > $sw ) {
		$sw = $sh;
	}
	if ( $sw < 2 ) { $sw += 1 }
	$::lglobal{htmlthumb}
	  ->copy( $::lglobal{htmlorig}, -subsample => ($sw), -shrink )
	  ;    #hkm changed textcopy to copy
	$::lglobal{imagelbl}->configure(
		-image   => $::lglobal{htmlthumb},
		-text    => 'Thumbnail',
		-justify => 'center',
	);
}

sub htmlgenpopup {
	my ( $textwindow, $top ) = ( $::textwindow, $::top );
	::operationadd('Begin HTML Generation');
	::viewpagenums() if ( $::lglobal{seepagenums} );
	if ( defined( $::lglobal{htmlgenpop} ) ) {
		$::lglobal{htmlgenpop}->deiconify;
		$::lglobal{htmlgenpop}->raise;
		$::lglobal{htmlgenpop}->focus;
	} else {
		my $blockmarkup;
		$::lglobal{htmlgenpop} = $top->Toplevel;
		$::lglobal{htmlgenpop}->title('HTML Generator');

		my $f1 =
		  $::lglobal{htmlgenpop}->Frame->pack( -side => 'top', -anchor => 'n' );
		$f1->Button(
			-text    => 'Custom Page Labels',
			-command => sub { pageadjust() },
		)->grid( -row => 1, -column => 2, -padx => 1, -pady => 1 );
		$f1->Button(
			-activebackground => $::activecolor,
			-command          => sub { htmlimages( $textwindow, $top ); },
			-text             => 'Auto Illus Search',
			-width            => 16,
		)->grid( -row => 1, -column => 3, -padx => 1, -pady => 1 );
		my $f0 =
		  $::lglobal{htmlgenpop}->Frame->pack( -side => 'top', -anchor => 'n' );
		my $pagecomments = $f0->Checkbutton(
			-variable    => \$::lglobal{pagecmt},
			-selectcolor => $::lglobal{checkcolor},
			-text        => 'Pg #s as comments',
			-anchor      => 'w',
		  )->grid(
			-row    => 1,
			-column => 1,
			-padx   => 1,
			-pady   => 2,
			-sticky => 'w'
		  );
		my $pageanchors = $f0->Checkbutton(
			-variable    => \$::lglobal{pageanch},
			-selectcolor => $::lglobal{checkcolor},
			-text        => 'Insert Anchors at Pg #s',
			-anchor      => 'w',
		  )->grid(
			-row    => 1,
			-column => 2,
			-padx   => 1,
			-pady   => 2,
			-sticky => 'w'
		  );
		$pageanchors->select;
		my $utfconvert = $f0->Checkbutton(
			-variable    => \$::lglobal{leave_utf},
			-selectcolor => $::lglobal{checkcolor},
			-text        => 'Keep UTF-8 Chars',
			-anchor      => 'w',
		  )->grid(
			-row    => 2,
			-column => 1,
			-padx   => 1,
			-pady   => 2,
			-sticky => 'w'
		  );
		my $latin1_convert = $f0->Checkbutton(
			-variable    => \$::lglobal{keep_latin1},
			-selectcolor => $::lglobal{checkcolor},
			-text        => 'Keep Latin-1 Chars',
			-anchor      => 'w',
		  )->grid(
			-row    => 2,
			-column => 2,
			-padx   => 1,
			-pady   => 2,
			-sticky => 'w'
		  );
		my $fractions = $f0->Checkbutton(
			-variable    => \$::lglobal{autofraction},
			-selectcolor => $::lglobal{checkcolor},
			-text        => 'Convert Fractions',
			-anchor      => 'w',
		  )->grid(
			-row    => 2,
			-column => 3,
			-padx   => 1,
			-pady   => 2,
			-sticky => 'w'
		  );
		my $shortfootnotes = $f0->Checkbutton(
			-variable    => \$::lglobal{shorthtmlfootnotes},
			-selectcolor => $::lglobal{checkcolor},
			-text        => 'Short FN Anchors',
			-anchor      => 'w',
		  )->grid(
			-row    => 3,
			-column => 2,
			-padx   => 1,
			-pady   => 2,
			-sticky => 'w'
		  );
		$blockmarkup = $f0->Checkbutton(
			-variable    => \$::lglobal{cssblockmarkup},
			-selectcolor => $::lglobal{checkcolor},
			-command     => sub {
				if ( $::lglobal{cssblockmarkup} ) {
					$blockmarkup->configure( '-text' => 'CSS blockquote' );
				} else {
					$blockmarkup->configure( '-text' => 'Std. <blockquote>' );
				}
			},
			-text   => 'CSS blockquote',
			-anchor => 'w',
		  )->grid(
			-row    => 3,
			-column => 1,
			-padx   => 1,
			-pady   => 2,
			-sticky => 'w'
		  );

		my $f7 =
		  $::lglobal{htmlgenpop}->Frame->pack( -side => 'top', -anchor => 'n' );
		$f7->Checkbutton(
			-variable    => \$::lglobal{poetrynumbers},
			-selectcolor => $::lglobal{checkcolor},
			-text        => 'Find and Format Poetry Line Numbers'
		)->grid( -row => 1, -column => 1, -pady => 2 );

		my $f2 =
		  $::lglobal{htmlgenpop}->Frame->pack( -side => 'top', -anchor => 'n' );
		$f2->Button(
			-activebackground => $::activecolor,
			-command          => sub { htmlautoconvert( $textwindow, $top ) },
			-text             => 'Autogenerate HTML',
			-width            => 16
		)->grid( -row => 1, -column => 1, -padx => 5, -pady => 1 );
		$f2->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				::runner( ::cmdinterp( $::extops[0]{command} ) );
			},
			-text  => 'View in Browser',
			-width => 16,
		)->grid( -row => 1, -column => 2, -padx => 5, -pady => 1 );

		if ( $::menulayout eq 'old' ) {
			my $f8 =
			  $::lglobal{htmlgenpop}->Frame->pack( -side => 'top', -anchor => 'n' );
			$f8->Button(
				-activebackground => $::activecolor,
				-command          => sub {
					::errorcheckpop_up( $textwindow, $top, 'Link Check' );
					unlink 'null' if ( -e 'null' );
				},
				-text  => 'Link Check',
				-width => 16
			)->grid( -row => 1, -column => 1, -padx => 1, -pady => 2 );
			$f8->Button(
				-activebackground => $::activecolor,
				-command          => sub {
					::errorcheckpop_up( $textwindow, $top, 'Image Check' );
					unlink 'null' if ( -e 'null' );
				},
				-text  => 'Image Check',
				-width => 16
			)->grid( -row => 1, -column => 2, -padx => 1, -pady => 2 );
			$f8->Button(
				-activebackground => $::activecolor,
				-command          => sub {
					::errorcheckpop_up( $textwindow, $top, 'HTML Tidy' );
					unlink 'null' if ( -e 'null' );
				},
				-text  => 'HTML Tidy',
				-width => 16
			)->grid( -row => 1, -column => 3, -padx => 1, -pady => 2 );
			$f8->Button(
				-activebackground => $::activecolor,
				-command          => sub {
					if ($::w3cremote) {
						::errorcheckpop_up( $textwindow, $top,
							'W3C Validate Remote' );
					} else {
						::errorcheckpop_up( $textwindow, $top, 'W3C Validate' );
					}
					unlink 'null' if ( -e 'null' );
				},
				-text  => 'W3C Validate',
				-width => 16
			)->grid( -row => 2, -column => 1, -padx => 1, -pady => 2 );
			$f8->Button(
				-activebackground => $::activecolor,
				-command          => sub {
					::errorcheckpop_up( $textwindow, $top, 'W3C Validate CSS' )
					  ;    #validatecssrun('');
					unlink 'null' if ( -e 'null' );
				},
				-text  => 'W3C Validate CSS',
				-width => 16
			)->grid( -row => 2, -column => 2, -padx => 1, -pady => 2 );
			$f8->Button(
				-activebackground => $::activecolor,
				-command          => sub {
					::errorcheckpop_up( $textwindow, $top, 'pphtml' );
					unlink 'null' if ( -e 'null' );
				},
				-text  => 'pphtml',
				-width => 16
			)->grid( -row => 2, -column => 3, -padx => 1, -pady => 2 );
			#			$f8->Button(
			#				-activebackground => $::activecolor,
			#				-command          => sub {
			#					::errorcheckpop_up( $textwindow, $top, 'Epub Friendly' );
			#					unlink 'null' if ( -e 'null' );
			#				},
			#				-text  => 'Epub Friendly',
			#				-width => 16
			#			)->grid( -row => 3, -column => 3, -padx => 1, -pady => 2 );
			$f8->Button(
				-activebackground => $::activecolor,
				-command          => sub {
					::errorcheckpop_up( $textwindow, $top, 'Check All' );
					unlink 'null' if ( -e 'null' );
				},
				-text  => 'Check All',
				-width => 16
			)->grid( -row => 3, -column => 2, -padx => 1, -pady => 2 );
		}
		::initialize_popup_without_deletebinding('htmlgenpop');
		$::lglobal{htmlgenpop}->protocol(
			'WM_DELETE_WINDOW' => sub {
				$::lglobal{htmlgenpop}->destroy;
				undef $::lglobal{htmlgenpop};
			}
		);
	}
}

sub htmlmarkpopup {
	my ( $textwindow, $top ) = ( $::textwindow, $::top );
	::operationadd('Begin HTML Markup');
	::viewpagenums() if ( $::lglobal{seepagenums} );
	if ( defined( $::lglobal{markpop} ) ) {
		$::lglobal{markpop}->deiconify;
		$::lglobal{markpop}->raise;
		$::lglobal{markpop}->focus;
	} else {
		$::lglobal{markpop} = $top->Toplevel;
		$::lglobal{markpop}->title('HTML Markup');
		my $tableformat;
		my $f1 =
		  $::lglobal{markpop}->Frame->pack( -side => 'top', -anchor => 'n' );
		my ( $inc, $row, $col ) = ( 0, 0, 0 );

	   # Warning: if you add tags to the list below move nbsp and poetry buttons
		for (
			qw/i b h1 h2 h3 h4 h5 h6 p hr br big small ol ul li sup sub table tr td blockquote code /
		  )
		{
			$col = $inc % 5;
			$row = int $inc / 5;
			$f1->Button(
				-activebackground => $::activecolor,
				-command          => [
					sub {
						markup( $textwindow, $top, $_[0] );
					},
					$_
				],
				-text  => "<$_>",
				-width => 10
			  )->grid(
				-row    => $row,
				-column => $col,
				-padx   => 1,
				-pady   => 2
			  );
			++$inc;
		}
		$f1->Button(
			-activebackground => $::activecolor,
			-command          => sub { markup( $textwindow, $top, '&nbsp;' ) },
			-text             => 'nb space',
			-width            => 10
		)->grid( -row => 4, -column => 3, -padx => 1, -pady => 2 );
		$f1->Button(
			-activebackground => $::activecolor,
			-command          => \&poetryhtml,
			-text             => 'Poetry',
			-width            => 10
		)->grid( -row => 4, -column => 4, -padx => 1, -pady => 2 );
		my $f2 =
		  $::lglobal{markpop}->Frame->pack( -side => 'top', -anchor => 'n' );
		my %hbuttons = (
			'anchor', 'Named anchor',  'img',   'Image',
			'elink',  'External Link', 'ilink', 'Internal Link'
		);
		( $row, $col ) = ( 0, 0 );
		for ( keys %hbuttons ) {
			$f2->Button(
				-activebackground => $::activecolor,
				-command          => [
					sub {
						markup( $textwindow, $top, $_[0] );
					},
					$_
				],
				-text  => "$hbuttons{$_}",
				-width => 13
			  )->grid(
				-row    => $row,
				-column => $col,
				-padx   => 1,
				-pady   => 2
			  );
			++$col;
		}
		my $f3 =
		  $::lglobal{markpop}->Frame->pack( -side => 'top', -anchor => 'n' );
		$f3->Button(
			-activebackground => $::activecolor,
			-command          => sub { markup( $textwindow, $top, 'del' ) },
			-text             => 'Remove markup from selection',
			-width            => 28
		)->grid( -row => 1, -column => 1, -padx => 1, -pady => 2 );
		$f3->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				for my $orphan (
					'b',  'i',  'center', 'u',  'sub', 'sup',
					'sc', 'h1', 'h2',     'h3', 'h4',  'h5',
					'h6', 'p',  'span'
				  )
				{
					::working( 'Checking <' . $orphan . '>' );
					last if orphans($orphan);
				}
				::working();
			},
			-text  => 'Find orphaned markup',
			-width => 28
		)->grid( -row => 1, -column => 2, -padx => 1, -pady => 2 );
		my $f4 =
		  $::lglobal{markpop}->Frame->pack( -side => 'top', -anchor => 'n' );
		my $unorderselect = $f4->Radiobutton(
			-text        => 'unordered',
			-selectcolor => $::lglobal{checkcolor},
			-variable    => \$::lglobal{liststyle},
			-value       => 'ul',
		)->grid( -row => 1, -column => 1 );
		my $orderselect = $f4->Radiobutton(
			-text        => 'ordered',
			-selectcolor => $::lglobal{checkcolor},
			-variable    => \$::lglobal{liststyle},
			-value       => 'ol',
		)->grid( -row => 1, -column => 2 );
		my $autolbutton = $f4->Button(
			-activebackground => $::activecolor,
			-command => sub { autolist($textwindow); $textwindow->focus },
			-text    => 'Auto List',
			-width   => 16
		)->grid( -row => 1, -column => 4, -padx => 1, -pady => 2 );
		$f4->Checkbutton(
			-text     => 'ML',
			-variable => \$::lglobal{list_multiline},
			-onvalue  => 1,
			-offvalue => 0
		)->grid( -row => 1, -column => 5 );
		my $leftselect = $f4->Radiobutton(
			-text        => 'left',
			-selectcolor => $::lglobal{checkcolor},
			-variable    => \$::lglobal{tablecellalign},
			-value       => ' align="left"',
		)->grid( -row => 2, -column => 1 );
		my $censelect = $f4->Radiobutton(
			-text        => 'center',
			-selectcolor => $::lglobal{checkcolor},
			-variable    => \$::lglobal{tablecellalign},
			-value       => ' align="center"',
		)->grid( -row => 2, -column => 2 );
		my $rghtselect = $f4->Radiobutton(
			-text        => 'right',
			-selectcolor => $::lglobal{checkcolor},
			-variable    => \$::lglobal{tablecellalign},
			-value       => ' align="right"',
		)->grid( -row => 2, -column => 3 );
		$leftselect->select;
		$unorderselect->select;
		$f4->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				autotable( $textwindow, $tableformat->get );
				$textwindow->focus;
			},
			-text  => 'Auto Table',
			-width => 16
		)->grid( -row => 2, -column => 4, -padx => 1, -pady => 2 );
		$f4->Checkbutton(
			-text     => 'ML',
			-variable => \$::lglobal{tbl_multiline},
			-onvalue  => 1,
			-offvalue => 0
		)->grid( -row => 2, -column => 5 );
		my $f5 =
		  $::lglobal{markpop}->Frame->pack( -side => 'top', -anchor => 'n' );
		$tableformat = $f5->Entry(
			-width      => 40,
			-background => $::bkgcolor,
			-relief     => 'sunken',
		)->grid( -row => 0, -column => 1, -pady => 2 );
		$f5->Label( -text => 'Column Fmt', )
		  ->grid( -row => 0, -column => 2, -padx => 2, -pady => 2 );
		my $diventry = $f5->Entry(
			-width      => 40,
			-background => $::bkgcolor,
			-relief     => 'sunken',
		)->grid( -row => 1, -column => 1, -pady => 2 );
		$f5->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				$::htmldiventry = $diventry->get;
				markup( $textwindow, $top, 'div', $::htmldiventry );
				$textwindow->focus;
			},
			-text  => 'div',
			-width => 8
		)->grid( -row => 1, -column => 2, -padx => 2, -pady => 2 );
		my $f6 =
		  $::lglobal{markpop}->Frame->pack( -side => 'top', -anchor => 'n' );
		my $spanentry = $f6->Entry(
			-width      => 40,
			-background => $::bkgcolor,
			-relief     => 'sunken',
		)->grid( -row => 1, -column => 1, -pady => 2 );
		$f6->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				$::htmlspanentry = $spanentry->get;
				markup( $textwindow, $top, 'span', $::htmlspanentry );
				$textwindow->focus;
			},
			-text  => 'span',
			-width => 8
		)->grid( -row => 1, -column => 2, -padx => 2, -pady => 2 );
		my $f7 =
		  $::lglobal{markpop}->Frame->pack( -side => 'top', -anchor => 'n' );
		$f7->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				open my $infile, '<', 'header.txt'
				  or warn "Could not open header file. $!\n";
				my $headertext;
				while (<$infile>) {
					$_ =~ s/\cM\cJ|\cM|\cJ/\n/g;

					#$_ =::eol_convert($_);
					$headertext .= $_;
				}
				$textwindow->insert( '1.0', $headertext );
				close $infile;
				$textwindow->insert( 'end', "<\/body>\n<\/html>" );
			},
			-text  => 'Header',
			-width => 16
		)->grid( -row => 1, -column => 2, -padx => 1, -pady => 2 );
		my $f8 =
		  $::lglobal{markpop}->Frame->pack( -side => 'top', -anchor => 'n' );
		$f8->Button(
			-activebackground => $::activecolor,
			-command          => \&hyperlinkpagenums,
			-text             => 'Hyperlink Page Nums',
			-width            => 16
		)->grid( -row => 1, -column => 1, -padx => 1, -pady => 2 );
		$diventry->insert( 'end', $::htmldiventry );
		$spanentry->insert( 'end', $::htmlspanentry );
		::initialize_popup_without_deletebinding('markpop');
		$::lglobal{markpop}->protocol(
			'WM_DELETE_WINDOW' => sub {
				$::lglobal{markpop}->destroy;
				undef $::lglobal{markpop};
			}
		);
	}
}

sub markup {
	my $textwindow = shift;
	my $top        = shift;
	my $mark       = shift;
	my $mark1;
	$mark1 = shift if @_;
	::viewpagenums() if ( $::lglobal{seepagenums} );
	::savesettings();
	my @ranges = $textwindow->tagRanges('sel');

	unless (@ranges) {
		push @ranges, $textwindow->index('insert');
		push @ranges, $textwindow->index('insert');
	}
	my $range_total = @ranges;
	my $done        = '';
	my $open        = 0;
	my $close       = 0;
	my @intanchors;
	if ( $range_total == 0 ) {
		return;
	} else {
		my $end            = pop(@ranges);
		my $start          = pop(@ranges);
		my $thisblockstart = $start;
		my $thisblockend   = $end;
		my $selection;
		if ( $mark eq 'del' ) {
			my ( $lsr, $lsc, $ler, $lec, $step, $edited );
			( $lsr, $lsc ) = split /\./, $thisblockstart;
			( $ler, $lec ) = split /\./, $thisblockend;
			$step = $lsr;
			while ( $step <= $ler ) {
				$selection = $textwindow->get( "$step.0", "$step.end" );
				$edited++ if ( $selection =~ s/<\/td>/  /g );
				$edited++ if ( $selection =~ s/<\/?body>//g );
				$edited++ if ( $selection =~ s/<br.*?>//g );
				$edited++ if ( $selection =~ s/<\/?div[^>]*?>//g );
				$edited++
				  if ( $selection =~
					s/<span.*?margin-left: (\d+\.?\d?)em.*?>/' ' x ($1 *2)/e );
				$edited++ if ( $selection =~ s/<\/?span[^>]*?>//g );
				$edited++ if ( $selection =~ s/<\/?[hscalupt].*?>//g );
				$edited++ if ( $selection =~ s/&nbsp;/ /g );
				$edited++ if ( $selection =~ s/<\/?blockquote>//g );
				$edited++ if ( $selection =~ s/\s+$// );
				$textwindow->delete( "$step.0", "$step.end" ) if $edited;
				$textwindow->insert( "$step.0", $selection ) if $edited;
				$step++;
				unless ( $step % 25 ) { $textwindow->update }
			}
			$textwindow->tagAdd( 'sel', $start, $end );
		} elsif ( $mark eq 'br' ) {
			my ( $lsr, $lsc, $ler, $lec, $step );
			( $lsr, $lsc ) = split /\./, $thisblockstart;
			( $ler, $lec ) = split /\./, $thisblockend;
			if ( $lsr eq $ler ) {
				$textwindow->insert( 'insert', '<br />' );
			} else {
				$step = $lsr;
				while ( $step <= $ler ) {
					$selection = $textwindow->get( "$step.0", "$step.end" );
					$selection =~ s/<br.*?>//g;
					$textwindow->insert( "$step.end", '<br />' );
					$step++;
				}
			}
		} elsif ( $mark eq 'hr' ) {
			$textwindow->insert( 'insert', '<hr class="full" />' );
		} elsif ( $mark eq '&nbsp;' ) {
			my ( $lsr, $lsc, $ler, $lec, $step );
			( $lsr, $lsc ) = split /\./, $thisblockstart;
			( $ler, $lec ) = split /\./, $thisblockend;
			if ( $lsr eq $ler ) {
				$textwindow->insert( 'insert', '&nbsp;' );
			} else {
				$step = $lsr;
				while ( $step <= $ler ) {
					$selection = $textwindow->get( "$step.0", "$step.end" );
					if ( $selection =~ /\s\s/ ) {
						$selection =~ s/^\s/&nbsp;/;
						$selection =~ s/  /&nbsp; /g;
						$selection =~ s/&nbsp; /&nbsp;&nbsp;/g;
						$textwindow->delete( "$step.0", "$step.end" );
						$textwindow->insert( "$step.0", $selection );
					}
					$step++;
				}
			}
		} elsif ( $mark eq 'img' ) {
			htmlimage( $textwindow, $top, $thisblockstart, $thisblockend );
		} elsif ( $mark eq 'elink' ) {
			my ( $name, $tempname );
			$name = '';
			if ( $::lglobal{elinkpop} ) {
				$::lglobal{elinkpop}->raise;
			} else {
				$::lglobal{elinkpop} = $top->Toplevel;
				$::lglobal{elinkpop}->title('Link Name');
				my $linkf1 =
				  $::lglobal{elinkpop}
				  ->Frame->pack( -side => 'top', -anchor => 'n' );
				my $linklabel = $linkf1->Label( -text => 'Link name' )->pack;
				$::lglobal{linkentry} =
				  $linkf1->Entry( -width => 60, -background => $::bkgcolor )
				  ->pack;
				my $linkf2 =
				  $::lglobal{elinkpop}
				  ->Frame->pack( -side => 'top', -anchor => 'n' );
				my $extbrowse = $linkf2->Button(
					-activebackground => $::activecolor,
					-text             => 'Browse',
					-width            => 16,
					-command          => sub {
						$name =
						  $::lglobal{elinkpop}
						  ->getOpenFile( -title => 'File Name?' );
						if ($name) {
							$::lglobal{linkentry}->delete( 0, 'end' );
							$::lglobal{linkentry}->insert( 'end', $name );
						}
					}
				)->pack( -side => 'left', -pady => 4 );
				my $linkf3 =
				  $::lglobal{elinkpop}
				  ->Frame->pack( -side => 'top', -anchor => 'n' );
				my $okbut = $linkf3->Button(
					-activebackground => $::activecolor,
					-text             => 'Ok',
					-width            => 16,
					-command          => sub {
						$name = $::lglobal{linkentry}->get;
						if ($name) {
							$name =~ s/[\/\\]/;/g;
							$tempname = $::globallastpath;
							$tempname =~ s/[\/\\]/;/g;
							$name     =~ s/$tempname//;
							$name     =~ s/;/\//g;
							$done = '</a>';
							$textwindow->insert( $thisblockend, $done );
							$done = '<a href="' . $name . "\">";
							$textwindow->insert( $thisblockstart, $done );
						}
						$::lglobal{elinkpop}->destroy;
						undef $::lglobal{elinkpop};
					}
				)->pack( -pady => 4 );
				$::lglobal{elinkpop}->protocol(
					'WM_DELETE_WINDOW' => sub {
						$::lglobal{elinkpop}->destroy;
						undef $::lglobal{elinkpop};
					}
				);
				$::lglobal{elinkpop}->Icon( -image => $::icon );
				$::lglobal{elinkpop}->transient( $::lglobal{markpop} );
				$::lglobal{linkentry}->focus;
			}
			$done = '';
		} elsif ( $mark eq 'ilink' ) {
			my ( $anchorname, $anchorstartindex, $anchorendindex, $length,
				$srow, $scol, $string, $link, $match, $match2 );
			$length     = 0;
			@intanchors = ();
			my %inthash = ();
			$anchorstartindex = $anchorendindex = '1.0';
			while (
				$anchorstartindex = $textwindow->search(
					'-regexp', '--', '<a (name|id)=[\'"].+?[\'"]',
					$anchorendindex, 'end'
				)
			  )
			{
				$anchorendindex =
				  $textwindow->search( '-regexp', '--', '>', $anchorstartindex,
					'end' );
				$string =
				  $textwindow->get( $anchorstartindex, $anchorendindex );
				$string =~ s/\n/ /g;
				$string =~ s/= /=/g;
				$string =~ m/=["'](.+?)['"]/;
				$match = $1;
				push @intanchors, '#' . $match;
				$match2 = $match;

				if ( exists $inthash{ '#' . ( lc($match) ) } ) {
					$textwindow->tagAdd( 'highlight', $anchorstartindex,
						$anchorendindex );
					$textwindow->see($anchorstartindex);
					$textwindow->bell unless $::nobell;
					$top->messageBox(
						-icon => 'error',
						-message =>
"More than one instance of the anchor $match2 in text.",
						-title => 'Duplicate anchor names.',
						-type  => 'Ok',
					);
					return;
				} else {
					$inthash{ '#' . ( lc($match) ) } = '#' . $match2;
				}
			}
			my ( $name, $tempname );
			$name = '';
			if ( $::lglobal{linkpop} ) {
				$::lglobal{linkpop}->deiconify;
			} else {
				my $linklistbox;
				$selection = $textwindow->get( $thisblockstart, $thisblockend );
				return unless length($selection);
				$::lglobal{linkpop} = $top->Toplevel;
				$::lglobal{linkpop}->title('Internal Links');
				$::lglobal{linkpop}->geometry($::geometry2) if $::geometry2;
				$::lglobal{linkpop}->transient($top)        if $::stayontop;
				$::lglobal{fnlinks} = 1;
				my $tframe = $::lglobal{linkpop}->Frame->pack;
				$tframe->Checkbutton(
					-variable    => \$::lglobal{ilinksrt},
					-selectcolor => $::lglobal{checkcolor},
					-text        => 'Sort Alphabetically',
					-command     => sub {
						$linklistbox->delete( '0', 'end' );
						linkpopulate( $linklistbox, \@intanchors );
					},
				  )->pack(
					-side   => 'left',
					-pady   => 2,
					-padx   => 2,
					-anchor => 'n'
				  );
				$tframe->Checkbutton(
					-variable    => \$::lglobal{fnlinks},
					-selectcolor => $::lglobal{checkcolor},
					-text        => 'Hide Footnote Links',
					-command     => sub {
						$linklistbox->delete( '0', 'end' );
						linkpopulate( $linklistbox, \@intanchors );
					},
				  )->pack(
					-side   => 'left',
					-pady   => 2,
					-padx   => 2,
					-anchor => 'n'
				  );
				$tframe->Checkbutton(
					-variable    => \$::lglobal{pglinks},
					-selectcolor => $::lglobal{checkcolor},
					-text        => 'Hide Page Links',
					-command     => sub {
						$linklistbox->delete( '0', 'end' );
						linkpopulate( $linklistbox, \@intanchors );
					},
				  )->pack(
					-side   => 'left',
					-pady   => 2,
					-padx   => 2,
					-anchor => 'n'
				  );
				my $pframe =
				  $::lglobal{linkpop}
				  ->Frame->pack( -fill => 'both', -expand => 'both' );
				$linklistbox = $pframe->Scrolled(
					'Listbox',
					-scrollbars  => 'se',
					-background  => $::bkgcolor,
					-selectmode  => 'single',
					-activestyle => 'none',
				  )->pack(
					-side   => 'top',
					-anchor => 'nw',
					-fill   => 'both',
					-expand => 'both',
					-padx   => 2,
					-pady   => 2
				  );
				::drag($linklistbox);
				$::lglobal{linkpop}->protocol(
					'WM_DELETE_WINDOW' => sub {
						$::lglobal{linkpop}->destroy;
						undef $::lglobal{linkpop};
					}
				);
				$::lglobal{linkpop}->Icon( -image => $::icon );
				::BindMouseWheel($linklistbox);
				$linklistbox->eventAdd( '<<trans>>' => '<Double-Button-1>' );
				$linklistbox->bind(
					'<<trans>>',
					sub {
						$name        = $linklistbox->get('active');
						$::geometry2 = $::lglobal{linkpop}->geometry;
						$done        = '</a>';
						$textwindow->insert( $thisblockend, $done );
						$done = "<a href=\"" . $name . "\">";
						$textwindow->insert( $thisblockstart, $done );
						$::lglobal{linkpop}->destroy;
						undef $::lglobal{linkpop};
					}
				);
				my $tempvar   = lc( makeanchor( ::deaccentdisplay($selection) ) );
				my $flag      = 0;
				my @entrarray = split( /_/, $tempvar );
				$entrarray[1] = '@' unless $entrarray[1];
				$entrarray[2] = '@' unless $entrarray[2];
				for ( sort (@intanchors) ) {
					last unless $tempvar;
					next
					  if ( ( ( $_ =~ /#$::htmllabels{fnlabel}/ ) || ( $_ =~ /#$::htmllabels{fnanchor}/ ) )
						&& $::lglobal{fnlinks} );
					next
					  if ( ( $_ =~ /#$::htmllabels{pglabel}/ ) && $::lglobal{pglinks} );
					next unless ( lc($_) eq '#' . $tempvar );
					$linklistbox->insert( 'end', $_ );
					$flag++;
				}
				$linklistbox->insert( 'end', '  ' );

				#print"$selection2\n";
				if ( $entrarray[1] && ( $entrarray[1] ne '@' ) ) {
					$entrarray[0] = '@'
					  if ( $entrarray[0] =~ /^to$|^a$|^the$|^and$/ );
					$entrarray[1] = '@'
					  if ( $entrarray[1] =~ /^to$|^a$|^the$|^and$/ );
					$entrarray[2] = '@'
					  if ( $entrarray[2] =~ /^to$|^a$|^the$|^and$/ );
				}
				for ( sort (@intanchors) ) {
					next
					  if ( ( ( $_ =~ /#$::htmllabels{fnlabel}/ ) || ( $_ =~ /#$::htmllabels{fnanchor}/ ) )
						&& $::lglobal{fnlinks} );

					next
					  if ( ( $_ =~ /#$::htmllabels{pglabel}/ ) && $::lglobal{pglinks} );
					next
					  unless (
						lc($_) =~
						/\Q$entrarray[0]\E|\Q$entrarray[1]\E|\Q$entrarray[2]\E/
					  );
					$linklistbox->insert( 'end', $_ );
					$flag++;
				}
				$linklistbox->insert( 'end', "  " );
				$flag = 0;
				linkpopulate( $linklistbox, \@intanchors );
				$linklistbox->focus;
			}
		} elsif ( $mark eq 'anchor' ) {
			my $linkname;
			$selection = $textwindow->get( $thisblockstart, $thisblockend )
			  || '';
			$linkname = makeanchor( ::deaccentdisplay($selection) );
			$done     = "<a id=\"" . $linkname . "\"></a>";
			$textwindow->insert( $thisblockstart, $done );
		} elsif ( $mark =~ /h\d/ ) {
			$selection = $textwindow->get( $thisblockstart, $thisblockend );
			if ( $selection =~ s/<\/?p>//g ) {
				$textwindow->delete( $thisblockstart, $thisblockend );
				$textwindow->tagRemove( 'sel', '1.0', 'end' );
				$textwindow->markSet( 'blkend', $thisblockstart );
				$textwindow->insert( $thisblockstart,
					"<$mark>$selection<\/$mark>" );
				$textwindow->tagAdd( 'sel', $thisblockstart,
					$textwindow->index('blkend') );
			} else {
				$textwindow->insert( $thisblockend,   "<\/$mark>" );
				$textwindow->insert( $thisblockstart, "<$mark>" );
			}
		} elsif ( ( $mark =~ /div/ ) || ( $mark =~ /span/ ) ) {
			$done = "<\/" . $mark . ">";
			$textwindow->insert( $thisblockend, $done );
			$mark .= $mark1;
			$done = '<' . $mark . '>';
			$textwindow->insert( $thisblockstart, $done );
		} else {
			$done = "<\/" . $mark . '>';
			$textwindow->insert( $thisblockend, $done );
			$done = '<' . $mark . '>';
			$textwindow->insert( $thisblockstart, $done );
		}
	}
	if ( $open != $close ) {
		$top->messageBox(
			-icon => 'error',
			-message =>
"Mismatching open and close markup removed.\nYou may have orphaned markup.",
			-title => 'Mismatching markup.',
			-type  => 'Ok',
		);
	}
	$textwindow->focus;
}

sub hyperlinkpagenums {
	::searchpopup();
	::searchoptset(qw/0 x x 1/);
	$::lglobal{searchentry}->insert( 'end', "(?<!\\d)(\\d{1,3})" );
	$::lglobal{replaceentry}->insert( 'end', "<a href=\"#$::htmllabels{pglabel}\$1\">\$1</a>" );
}

sub makeanchor {
	my $linkname = shift;
	return unless $linkname;
	$linkname =~ s/-/\x00/g;
	$linkname =~ s/&amp;|&mdash;/\xFF/;
	$linkname =~ s/<sup>.*?<\/sup>//g;
	$linkname =~ s/<\/?[^>]+>//g;
	$linkname =~ s/\p{Punct}//g;
	$linkname =~ s/\x00/-/g;
	$linkname =~ s/\s+/_/g;
	while ( $linkname =~ m/([\x{100}-\x{ffef}])/ ) {
		my $char     = "$1";
		my $ord      = ord($char);
		my $phrase   = charnames::viacode($ord);
		my $case     = 'lc';
		my $notlatin = 1;
		$phrase = '-X-' unless ( $phrase =~ /(LETTER|DIGIT|LIGATURE)/ );
		$case     = 'uc' if $phrase =~ /CAPITAL|^-X-$/;
		$notlatin = 0    if $phrase =~ /LATIN/;
		$phrase =~ s/.+(LETTER|DIGIT|LIGATURE) //;
		$phrase =~ s/ WITH.+//;
		$phrase = lc($phrase) if $case eq 'lc';
		$phrase =~ s/ /_/g;
		$phrase = "-$phrase-" if $notlatin;
		$linkname =~ s/$char/$phrase/g;
	}
	$linkname =~ s/--+/-/g;
	$linkname =~ s/[\x90-\xff\x20\x22]/_/g;
	$linkname =~ s/__+/_/g;
	$linkname =~ s/^[_-]+|[_-]+$//g;
	return $linkname;
}

sub autoindex {
	my $textwindow = shift;
	::viewpagenums() if ( $::lglobal{seepagenums} );
	my @ranges = $textwindow->tagRanges('sel');
	unless (@ranges) {
		push @ranges, $textwindow->index('insert');
		push @ranges, $textwindow->index('insert');
	}
	my $range_total = @ranges;
	if ( $range_total == 0 ) {
		return;
	} else {
		$textwindow->addGlobStart;
		my $end       = pop(@ranges);
		my $start     = pop(@ranges);
		my $paragraph = 0;
		my ( $lsr, $lsc ) = split /\./, $start;
		my ( $ler, $lec ) = split /\./, $end;
		my $step   = $lsr;
		my $blanks = 0;
		my $first  = 1;
		my $indent = 0;

		while ( $textwindow->get( "$step.0", "$step.end" ) eq '' ) {
			$step++;
		}
		while ( $step <= $ler ) {
			my $selection = $textwindow->get( "$step.0", "$step.end" );
			unless ($selection) { $step++; $blanks++; next }
			$selection = ::addpagelinks($selection);
			if ( $first == 1 ) { $blanks = 2; $first = 0 }
			if ( $blanks == 2 ) {
				$selection = '<li class="ifrst">' . $selection . '</li>';
				$first     = 0;
			}
			if ( $blanks == 1 ) {
				$selection = '<li class="indx">' . $selection . '</li>';
			}
			if ( $selection =~ /^(\s+)/ ) {
				$indent = ( int( ( length($1) + 1 ) / 2 ) );
				$selection =~ s/^\s+//;
				$selection =
				  '<li class="isub' . $indent . '">' . $selection . '</li>';
			}
			$textwindow->delete( "$step.0", "$step.end" );
			$selection =~ s/<li<\/li>//;
			$textwindow->insert( "$step.0", $selection );
			$blanks = 0;
			$step++;
		}
		$textwindow->insert( "$ler.end", "</ul>\n" );
		$textwindow->insert( $start,     '<ul class="index">' );
		$textwindow->addGlobEnd;
	}
}

sub autolist {
	my $textwindow = shift;
	::viewpagenums() if ( $::lglobal{seepagenums} );
	my @ranges = $textwindow->tagRanges('sel');
	unless (@ranges) {
		push @ranges, $textwindow->index('insert');
		push @ranges, $textwindow->index('insert');
	}
	my $range_total = @ranges;
	if ( $range_total == 0 ) {
		return;
	} else {
		$textwindow->addGlobStart;
		my $end       = pop(@ranges);
		my $start     = pop(@ranges);
		my $paragraph = 0;
		if ( $::lglobal{list_multiline} ) {
			my $selection = $textwindow->get( $start, $end );
			$selection =~ s/\n +/\n/g;
			$selection =~ s/\n\n+/\x{8A}/g;
			my @lrows = split( /\x{8A}/, $selection );
			for (@lrows) {
				$_ = '<li>' . $_ . "</li>\n\n";
			}
			$selection = "<$::lglobal{liststyle}>\n";
			for my $lrow (@lrows) {
				$selection .= $lrow;
			}
			$selection =~ s/\n$//;
			$selection .= '</' . $::lglobal{liststyle} . ">\n";

			#$selection =~ s/ </</g; # why is this necessary; reported as a bug
			$textwindow->delete( $start, $end );
			$textwindow->insert( $start, $selection );
		} else {
			my ( $lsr, $lsc ) = split /\./, $start;
			my ( $ler, $lec ) = split /\./, $end;
			my $step = $lsr;
			$step++ while ( $textwindow->get( "$step.0", "$step.end" ) eq '' );
			while ( $step <= $ler ) {
				my $selection = $textwindow->get( "$step.0", "$step.end" );
				unless ($selection) { $step++; next }
				if ( $selection =~ s/<br.*?>//g ) {
					$selection = '<li>' . $selection . '</li>';
				}
				if ( $selection =~ s/<p>/<li>/g )     { $paragraph = 1 }
				if ( $selection =~ s/<\/p>/<\/li>/g ) { $paragraph = 0 }
				$textwindow->delete( "$step.0", "$step.end" );
				unless ($paragraph) {
					unless ( $selection =~ /<li>/ ) {
						$selection = '<li>' . $selection . '</li>';
					}
				}
				$selection =~ s/<li><\/li>//;
				$textwindow->insert( "$step.0", $selection );
				$step++;
			}
			$textwindow->insert( "$ler.end", "</$::lglobal{liststyle}>\n" );
			$textwindow->insert( $start,     "<$::lglobal{liststyle}>" );
		}
		$textwindow->addGlobEnd;
	}
}

sub autotable {
	my ( $textwindow, $format ) = @_;
	::viewpagenums() if ( $::lglobal{seepagenums} );
	my @cformat;
	if ($format) {
		@cformat = split( //, $format );
	}
	my @ranges = $textwindow->tagRanges('sel');
	unless (@ranges) {
		push @ranges, $textwindow->index('insert');
		push @ranges, $textwindow->index('insert');
	}
	my $range_total = @ranges;
	if ( $range_total == 0 ) {
		return;
	} else {
		my $table = 1;
		my $end   = pop(@ranges);
		my $start = pop(@ranges);
		my ( @tbl, @trows, @tlines, @twords );
		my $row = 0;
		my $selection = $textwindow->get( $start, $end );
		$selection =~ s/<br.*?>//g;
		$selection =~ s/<\/?p>//g;
		$selection =~ s/\n[\s|]+\n/\n\n/g;
		$selection =~ s/^\n+//;
		$selection =~ s/\n\n+/\x{8A}/g if $::lglobal{tbl_multiline};
		@trows = split( /\x{8A}/, $selection ) if $::lglobal{tbl_multiline};
		$selection =~ s/\n[\s|]*\n/\n/g unless $::lglobal{tbl_multiline};
		@trows = split( /\n/, $selection ) unless $::lglobal{tbl_multiline};

		for my $trow (@trows) {
			@tlines = split( /\n/, $trow );
			for my $tline (@tlines) {
				if ( $selection =~ /\|/ ) {
					@twords = split( /\|/, $tline );
				} else {
					@twords = split( /\s\s+/, $tline );
				}
				for ( 0 .. $#twords ) {
					$tbl[$row][$_] .= "$twords[$_] ";
				}
			}
			$row++;
		}
		$selection = '';
		for my $row ( 0 .. $#tbl ) {
			$selection .= '<tr>';
			for ( $tbl[$row] ) {
				my $cellcnt = 0;
				my $cellalign;
				while (@$_) {
					if ( $cformat[$cellcnt] ) {
						if ( $cformat[$cellcnt] eq '>' ) {
							$cellalign = ' align="right"';
						} elsif ( $cformat[$cellcnt] eq '|' ) {
							$cellalign = ' align="center"';
						} else {
							$cellalign = ' align="left"';
						}
					} else {
						$cellalign = $::lglobal{tablecellalign};
					}
					++$cellcnt;
					$selection .= '<td' . $cellalign . '>';
					$selection .= shift @$_;
					$selection .= '</td>';
				}
			}
			$selection .= "</tr>\n";
		}
		$selection .= '</table></div>';
		$selection =~ s/<td[^>]+><\/td>//g;
		$selection =~ s/ +<\//<\//g;
		$selection =~ s/d> +/d>/g;
		$selection =~ s/ +/ /g;
		$textwindow->delete( $start, $end );
		$textwindow->insert( $start, $selection );
		$textwindow->insert( $start,
			    "\n<div class=\"center\">\n"
			  . '<table border="0" cellpadding="4" cellspacing="0" summary="">'
			  . "\n" )
		  if $table;
		$table = 1;
	}
}

sub orphans {
	my $textwindow = $::textwindow;
	::viewpagenums() if ( $::lglobal{seepagenums} );
	my $br = shift;
	$textwindow->tagRemove( 'highlight', '1.0', 'end' );
	my ( $thisindex, $open, $close, $crow, $ccol, $orow, $ocol, @op );
	$open  = '<' . $br . '>|<' . $br . ' [^>]*>';
	$close = '<\/' . $br . '>';
	my $end = $textwindow->index('end');
	$thisindex = '1.0';
	my ( $lengtho, $lengthc );
	my $opindex = $textwindow->search(
		'-regexp',
		'-count' => \$lengtho,
		'--', $open, $thisindex, 'end'
	);
	push @op, $opindex;
	my $clindex = $textwindow->search(
		'-regexp',
		'-count' => \$lengthc,
		'--', $close, $thisindex, 'end'
	);
	return unless ( $clindex || $opindex );
	push @op, ( $clindex || $end );

	while ($opindex) {
		$opindex = $textwindow->search(
			'-regexp',
			'-count' => \$lengtho,
			'--', $open, $op[0] . '+1c', 'end'
		);
		if ($opindex) {
			push @op, $opindex;
		} else {
			push @op, $textwindow->index('end');
		}
		my $begin = $op[1];
		$begin = 'end' unless $begin;
		$clindex = $textwindow->search(
			'-regexp',
			'-count' => \$lengthc,
			'--', $close, "$begin+1c", 'end'
		);
		if ($clindex) {
			push @op, $clindex;
		} else {
			push @op, $textwindow->index('end');
		}
		if ( $textwindow->compare( $op[1], '==', $op[3] ) ) {
			$textwindow->markSet( 'insert', $op[0] ) if $op[0];
			$textwindow->see( $op[0] ) if $op[0];
			$textwindow->tagAdd( 'highlight', $op[0],
				$op[0] . '+' . length($open) . 'c' );
			return 1;
		}
		if (   ( $textwindow->compare( $op[0], '<', $op[1] ) )
			&& ( $textwindow->compare( $op[1], '<', $op[2] ) )
			&& ( $textwindow->compare( $op[2], '<', $op[3] ) )
			&& ( $op[2] ne $end )
			&& ( $op[3] ne $end ) )
		{
			$textwindow->update;
			$textwindow->focus;
			shift @op;
			shift @op;
			next;
		} elsif ( ( $textwindow->compare( $op[0], '<', $op[1] ) )
			&& ( $textwindow->compare( $op[1], '>', $op[2] ) ) )
		{
			$textwindow->markSet( 'insert', $op[2] ) if $op[2];
			$textwindow->see( $op[2] ) if $op[2];
			$textwindow->tagAdd( 'highlight', $op[2],
				$op[2] . ' +' . $lengtho . 'c' );
			$textwindow->tagAdd( 'highlight', $op[0],
				$op[0] . ' +' . $lengtho . 'c' );
			$textwindow->update;
			$textwindow->focus;
			return 1;
		} elsif ( ( $textwindow->compare( $op[0], '<', $op[1] ) )
			&& ( $textwindow->compare( $op[2], '>', $op[3] ) ) )
		{
			$textwindow->markSet( 'insert', $op[3] ) if $op[3];
			$textwindow->see( $op[3] ) if $op[3];
			$textwindow->tagAdd( 'highlight', $op[3],
				$op[3] . '+' . $lengthc . 'c' );
			$textwindow->tagAdd( 'highlight', $op[1],
				$op[1] . '+' . $lengthc . 'c' );
			$textwindow->update;
			$textwindow->focus;
			return 1;
		} elsif ( ( $textwindow->compare( $op[0], '>', $op[1] ) )
			&& ( $op[0] ne $end ) )
		{
			$textwindow->markSet( 'insert', $op[1] ) if $op[1];
			$textwindow->see( $op[1] ) if $op[1];
			$textwindow->tagAdd( 'highlight', $op[1],
				$op[1] . '+' . $lengthc . 'c' );
			$textwindow->tagAdd( 'highlight', $op[3],
				$op[3] . '+' . $lengtho . 'c' );
			$textwindow->update;
			$textwindow->focus;
			return 1;
		} else {
			if (   ( $op[3] eq $end )
				&& ( $textwindow->compare( $op[2], '>', $op[0] ) ) )
			{
				$textwindow->markSet( 'insert', $op[2] ) if $op[2];
				$textwindow->see( $op[2] ) if $op[2];
				$textwindow->tagAdd( 'highlight', $op[2],
					$op[2] . '+' . $lengthc . 'c' );
			}
			if (   ( $op[2] eq $end )
				&& ( $textwindow->compare( $op[3], '>', $op[1] ) ) )
			{
				$textwindow->markSet( 'insert', $op[3] ) if $op[3];
				$textwindow->see( $op[3] ) if $op[3];
				$textwindow->tagAdd( 'highlight', $op[3],
					$op[3] . '+' . $lengthc . 'c' );
			}
			if ( ( $op[1] eq $end ) && ( $op[2] eq $end ) ) {
				$textwindow->markSet( 'insert', $op[0] ) if $op[0];
				$textwindow->see( $op[0] ) if $op[0];
				$textwindow->tagAdd( 'highlight', $op[0],
					$op[0] . '+' . $lengthc . 'c' );
			}
			::update_indicators();
			return 0;
		}
	}
	return 0;
}

sub poetryhtml {
	my $textwindow = $::textwindow;
	::viewpagenums() if ( $::lglobal{seepagenums} );
	my @ranges      = $textwindow->tagRanges('sel');
	my $range_total = @ranges;
	if ( $range_total == 0 ) {
		return;
	} else {
		my $end   = pop(@ranges);
		my $start = pop(@ranges);
		my ( $lsr, $lsc, $ler, $lec, $step, $ital );
		( $lsr, $lsc ) = split /\./, $start;
		( $ler, $lec ) = split /\./, $end;
		$step = $lsr;
		my $selection = $textwindow->get( "$lsr.0", "$lsr.end" );
		$selection =~ s/&nbsp;/ /g;
		$selection =~ s/^(\s+)//;
		my $indent;
		$indent = length($1) if $1;
		my $class = '';
		$class = ( " class=\"i" . ( $indent - 4 ) . '"' ) if ( $indent - 4 );

		if ( length $selection ) {
			$selection = "<span$class>" . $selection . '<br /></span>';
		} else {
			$selection = '';
		}
		$textwindow->delete( "$lsr.0", "$lsr.end" );
		$textwindow->insert( "$lsr.0", $selection );
		$step++;
		while ( $step <= $ler ) {
			$selection = $textwindow->get( "$step.0", "$step.end" );
			if ( $selection =~ /^$/ ) {
				$textwindow->insert( "$step.0", '</div><div class="stanza">' );
				while (1) {
					$step++;
					$selection = $textwindow->get( "$step.0", "$step.end" );
					last if ( $step ge $ler );
					next if ( $selection =~ /^$/ );
					last;
				}
			}
			$selection =~ s/&nbsp;/ /g;
			$selection =~ s/^(\s+)//;
			$indent = length($1) if $1;
			$textwindow->delete( "$step.0", "$step.$indent" ) if $indent;
			$indent -= 4;
			$indent = 0 if ( $indent < 0 );
			$selection =~ s/^(\s*)//;
			$selection =~ /(<i>)/g;
			my $op = $-[-1];
			$selection =~ s/^(\s*)//;
			$selection =~ /(<\/i>)/g;
			my $cl = $-[-1];

			if ( !$cl && $ital ) {
				$textwindow->ntinsert( "$step.0 lineend", '</i>' );
			}
			if ( !$op && $ital ) {
				$textwindow->ntinsert( "$step.0", '<i>' );
			}
			if ( $op && ( $cl < $op ) && !$ital ) {
				$textwindow->ntinsert( "$step.end", '</i>' );
				$ital = 1;
			}
			if ( $op && $cl && ( $cl < $op ) && $ital ) {
				$textwindow->ntinsert( "$step.0", '<i>' );
				$ital = 0;
			}
			if ( ( $op < $cl ) && $ital ) {
				$textwindow->ntinsert( "$step.0", '<i>' );
				$ital = 0;
			}
			if ($indent) {
				$textwindow->insert( "$step.0", "<span class=\"i$indent\">" );
			} else {
				$textwindow->insert( "$step.0", '<span>' );
			}
			$textwindow->insert( "$step.end", '<br /></span>' );
			$step++;
		}
		$selection = "\n</div></div>";
		$textwindow->insert( "$ler.end", $selection );
		$textwindow->insert( "$lsr.0",
			"<div class=\"poem\"><div class=\"stanza\">\n" );
	}
}

sub linkpopulate {
	my $linklistbox = shift;
	my $anchorsref  = shift;
	if ( $::lglobal{ilinksrt} ) {
		for ( ::natural_sort_alpha( @{$anchorsref} ) ) {
			next
			  if ( ( ( $_ =~ /#$::htmllabels{fnlabel}/ ) || ( $_ =~ /#$::htmllabels{fnanchor}/ ) )
				&& $::lglobal{fnlinks} );
			next if ( ( $_ =~ /#$::htmllabels{pglabel}/ ) && $::lglobal{pglinks} );
			$linklistbox->insert( 'end', $_ );
		}
	} else {
		foreach ( @{$anchorsref} ) {
			next
			  if ( ( ( $_ =~ /#$::htmllabels{fnlabel}/ ) || ( $_ =~ /#$::htmllabels{fnanchor}/ ) )
				&& $::lglobal{fnlinks} );
			next if ( ( $_ =~ /#$::htmllabels{pglabel}/ ) && $::lglobal{pglinks} );
			$linklistbox->insert( 'end', $_ );
		}
	}
	$linklistbox->yviewScroll( 1, 'units' );
	$linklistbox->update;
	$linklistbox->yviewScroll( -1, 'units' );
}

sub entity {
	my $char       = shift;
	my %markuphash = (
		'\x80' => '&#8364;',
		'\x81' => '&#129;',
		'\x82' => '&#8218;',
		'\x83' => '&#402;',
		'\x84' => '&#8222;',
		'\x85' => '&#8230;',
		'\x86' => '&#8224;',
		'\x87' => '&#8225;',
		'\x88' => '&#710;',
		'\x89' => '&#8240;',
		'\x8a' => '&#352;',
		'\x8b' => '&#8249;',
		'\x8c' => '&#338;',
		'\x8d' => '&#141;',
		'\x8e' => '&#381;',
		'\x8f' => '&#143;',
		'\x90' => '&#144;',
		'\x91' => '&#8216;',
		'\x92' => '&#8217;',
		'\x93' => '&#8220;',
		'\x94' => '&#8221;',
		'\x95' => '&#8226;',
		'\x96' => '&#8211;',
		'\x97' => '&#8212;',
		'\x98' => '&#732;',
		'\x99' => '&#8482;',
		'\x9a' => '&#353;',
		'\x9b' => '&#8250;',
		'\x9c' => '&#339;',
		'\x9d' => '&#157;',
		'\x9e' => '&#382;',
		'\x9f' => '&#376;',
		'\xa0' => '&nbsp;',
		'\xa1' => '&iexcl;',
		'\xa2' => '&cent;',
		'\xa3' => '&pound;',
		'\xa4' => '&curren;',
		'\xa5' => '&yen;',
		'\xa6' => '&brvbar;',
		'\xa7' => '&sect;',
		'\xa8' => '&uml;',
		'\xa9' => '&textcopy;',
		'\xaa' => '&ordf;',
		'\xab' => '&laquo;',
		'\xac' => '&not;',
		'\xad' => '&shy;',
		'\xae' => '&reg;',
		'\xaf' => '&macr;',
		'\xb0' => '&deg;',
		'\xb1' => '&plusmn;',
		'\xb2' => '&sup2;',
		'\xb3' => '&sup3;',
		'\xb4' => '&acute;',
		'\xb5' => '&micro;',
		'\xb6' => '&para;',
		'\xb7' => '&middot;',
		'\xb8' => '&cedil;',
		'\xb9' => '&sup1;',
		'\xba' => '&ordm;',
		'\xbb' => '&raquo;',
		'\xbc' => '&frac14;',
		'\xbd' => '&frac12;',
		'\xbe' => '&frac34;',
		'\xbf' => '&iquest;',
		'\xc0' => '&Agrave;',
		'\xc1' => '&Aacute;',
		'\xc2' => '&Acirc;',
		'\xc3' => '&Atilde;',
		'\xc4' => '&Auml;',
		'\xc5' => '&Aring;',
		'\xc6' => '&AElig;',
		'\xc7' => '&Ccedil;',
		'\xc8' => '&Egrave;',
		'\xc9' => '&Eacute;',
		'\xca' => '&Ecirc;',
		'\xcb' => '&Euml;',
		'\xcc' => '&Igrave;',
		'\xcd' => '&Iacute;',
		'\xce' => '&Icirc;',
		'\xcf' => '&Iuml;',
		'\xd0' => '&ETH;',
		'\xd1' => '&Ntilde;',
		'\xd2' => '&Ograve;',
		'\xd3' => '&Oacute;',
		'\xd4' => '&Ocirc;',
		'\xd5' => '&Otilde;',
		'\xd6' => '&Ouml;',
		'\xd7' => '&times;',
		'\xd8' => '&Oslash;',
		'\xd9' => '&Ugrave;',
		'\xda' => '&Uacute;',
		'\xdb' => '&Ucirc;',
		'\xdc' => '&Uuml;',
		'\xdd' => '&Yacute;',
		'\xde' => '&THORN;',
		'\xdf' => '&szlig;',
		'\xe0' => '&agrave;',
		'\xe1' => '&aacute;',
		'\xe2' => '&acirc;',
		'\xe3' => '&atilde;',
		'\xe4' => '&auml;',
		'\xe5' => '&aring;',
		'\xe6' => '&aelig;',
		'\xe7' => '&ccedil;',
		'\xe8' => '&egrave;',
		'\xe9' => '&eacute;',
		'\xea' => '&ecirc;',
		'\xeb' => '&euml;',
		'\xec' => '&igrave;',
		'\xed' => '&iacute;',
		'\xee' => '&icirc;',
		'\xef' => '&iuml;',
		'\xf0' => '&eth;',
		'\xf1' => '&ntilde;',
		'\xf2' => '&ograve;',
		'\xf3' => '&oacute;',
		'\xf4' => '&ocirc;',
		'\xf5' => '&otilde;',
		'\xf6' => '&ouml;',
		'\xf7' => '&divide;',
		'\xf8' => '&oslash;',
		'\xf9' => '&ugrave;',
		'\xfa' => '&uacute;',
		'\xfb' => '&ucirc;',
		'\xfc' => '&uuml;',
		'\xfd' => '&yacute;',
		'\xfe' => '&thorn;',
		'\xff' => '&yuml;',
	);
	my %pukramhash = reverse %markuphash;
	return $markuphash{$char} if $markuphash{$char};
	return $pukramhash{$char} if $pukramhash{$char};
	return $char;
}

sub named {
	my ( $from, $to, $start, $end ) = @_;
	my $length;
	my $textwindow = $::textwindow;

	#print "from:$from:to:$to\n";
	my $searchstartindex = $start;
	$searchstartindex = '1.0' unless $searchstartindex;
	$end              = 'end' unless $end;
	$textwindow->markSet( 'srchend', $end );
	while (
		$searchstartindex = $textwindow->search(
			'-regexp',
			'-count' => \$length,
			'--', $from, $searchstartindex, 'srchend'
		)
	  )
	{
		$textwindow->ntinsert( $searchstartindex, $to );
		$textwindow->ntdelete( $searchstartindex . '+' . length($to) . 'c',
			$searchstartindex . '+' . ($length+length($to)) . 'c' );
		# insert before delete to stay on the right side of page markers
		$searchstartindex = $textwindow->index("$searchstartindex+1c");
	}
}

sub fromnamed {
	my ($textwindow) = @_;
	my @ranges       = $textwindow->tagRanges('sel');
	my $range_total  = @ranges;
	if ( $range_total == 0 ) {
		return;
	} else {
		while (@ranges) {
			my $end   = pop @ranges;
			my $start = pop @ranges;
			$textwindow->markSet( 'srchend', $end );
			my ( $thisblockstart, $length );
			::named( '&amp;',   '&',  $start, 'srchend' );
			::named( '&quot;',  '"',  $start, 'srchend' );
			::named( '&mdash;', '--', $start, 'srchend' );
			::named( ' &gt;',   ' >', $start, 'srchend' );
			::named( '&lt; ',   '< ', $start, 'srchend' );
			my $from;

			for ( 160 .. 255 ) {
				$from = lc sprintf( "%x", $_ );
				::named( ::entity( '\x' . $from ), chr($_), $start, 'srchend' );
			}
			while (
				$thisblockstart = $textwindow->search(
					'-regexp',
					'-count' => \$length,
					'--', '&#\d+;', $start, $end
				)
			  )
			{
				my $xchar =
				  $textwindow->get( $thisblockstart,
					$thisblockstart . '+' . $length . 'c' );
				$textwindow->ntdelete( $thisblockstart,
					$thisblockstart . '+' . $length . 'c' );
				$xchar =~ s/&#(\d+);/$1/;
				$textwindow->ntinsert( $thisblockstart, chr($xchar) );
			}
			$textwindow->markUnset('srchend');
		}
	}
}

sub tonamed {
	my ($textwindow) = @_;
	my @ranges       = $textwindow->tagRanges('sel');
	my $range_total  = @ranges;
	if ( $range_total == 0 ) {
		return;
	} else {
		while (@ranges) {
			my $end   = pop @ranges;
			my $start = pop @ranges;
			$textwindow->markSet( 'srchend', $end );
			my $thisblockstart;
			::named( '&(?![\w#])',           '&amp;',   $start, 'srchend' );
			::named( '&$',                   '&amp;',   $start, 'srchend' );
			::named( '"',                    '&quot;',  $start, 'srchend' );
			::named( '(?<=[^-!])--(?=[^>])', '&mdash;', $start, 'srchend' );
			::named( '(?<=[^-])--$',         '&mdash;', $start, 'srchend' );
			::named( '^--(?=[^-])',          '&mdash;', $start, 'srchend' );
			::named( '& ',                   '&amp; ',  $start, 'srchend' );
			::named( '&c\.',                 '&amp;c.', $start, 'srchend' );
			::named( ' >',                   ' &gt;',   $start, 'srchend' );
			::named( '< ',                   '&lt; ',   $start, 'srchend' );
			my $from;

			for ( 128 .. 255 ) {
				$from = lc sprintf( "%x", $_ );
				::named(
					'\x' . $from,
					::entity( '\x' . $from ),
					$start, 'srchend'
				);
			}
			while (
				$thisblockstart = $textwindow->search(
					'-regexp',             '--',
					'[\x{100}-\x{65535}]', $start,
					'srchend'
				)
			  )
			{
				my $xchar = ord( $textwindow->get($thisblockstart) );
				$textwindow->ntdelete( $thisblockstart, "$thisblockstart+1c" );
				$textwindow->ntinsert( $thisblockstart, "&#$xchar;" );
			}
			$textwindow->markUnset('srchend');
		}
	}
}

sub fracconv {
	my ( $textwindow, $start, $end ) = @_;
	my %frachash = (
		'\b1\/2\b' => '&frac12;',
		'\b1\/4\b' => '&frac14;',
		'\b3\/4\b' => '&frac34;',
	);
	my ( $ascii, $html, $length );
	my $thisblockstart = 1;
	while ( ( $ascii, $html ) = each(%frachash) ) {
		while (
			$thisblockstart = $textwindow->search(
				'-regexp',
				'-count' => \$length,
				'--', "-?$ascii", $start, $end
			)
		  )
		{
			$textwindow->replacewith( $thisblockstart,
				$thisblockstart . "+$length c", $html );
		}
	}
}

sub pageadjust {
	my $textwindow = $::textwindow;
	my $top        = $::top;
	if ( defined $::lglobal{padjpop} ) {
		$::lglobal{padjpop}->deiconify;
		$::lglobal{padjpop}->raise;
	} else {
		my @marks = $textwindow->markNames;
		my @pages = sort grep ( /^Pg\S+$/, @marks );
		my %pagetrack;
		$::lglobal{padjpop} = $top->Toplevel;
		$::lglobal{padjpop}->title('Configure Page Labels');
		$::geometryhash{padjpop} = ('375x500') unless $::geometryhash{padjpop};
		::initialize_popup_with_deletebinding('padjpop');
		my $frame0 =
		  $::lglobal{padjpop}
		  ->Frame->pack( -side => 'top', -anchor => 'n', -pady => 4 );

		unless (@pages) {
			$frame0->Label(
				-text       => 'No Page Markers Found',
				-background => $::bkgcolor,
			)->pack;
			return;
		}
		my $recalc = $frame0->Button(
			-text    => 'Recalculate',
			-width   => 15,
			-command => sub {
				my ( $index, $label );
				my $style = 'Arabic';
				for my $page (@pages) {
					my ($num) = $page =~ /Pg(\S+)/;
					if ( $pagetrack{$num}[4]->cget( -text ) eq 'Start @' ) {
						$index = $pagetrack{$num}[5]->get;
					}
					if ( $pagetrack{$num}[3]->cget( -text ) eq 'Arabic' ) {
						$style = 'Arabic';
					} elsif ( $pagetrack{$num}[3]->cget( -text ) eq 'Roman' ) {
						$style = 'Roman';
					}
					if ( $style eq 'Roman' ) {
						$label = lc( ::roman($index) );
					} else {
						$label = $index;
						$label =~ s/^0+// if $label and length $label;
					}
					if ( $pagetrack{$num}[4]->cget( -text ) eq 'No Count' ) {
						$pagetrack{$num}[2]->configure( -text => '' );
					} else {
						$pagetrack{$num}[2]->configure( -text => "Pg $label" );
						$index++;
					}
				}
			},
		)->grid( -row => 1, -column => 1, -padx => 5, -pady => 4 );
		$frame0->Button(
			-text    => 'Use These Values',
			-width   => 15,
			-command => sub {
				%::pagenumbers = ();
				for my $page (@pages) {
					my ($num) = $page =~ /Pg(\S+)/;
					$::pagenumbers{$page}{label} =
					  $pagetrack{$num}[2]->cget( -text );
					$::pagenumbers{$page}{style} =
					  $pagetrack{$num}[3]->cget( -text );
					$::pagenumbers{$page}{action} =
					  $pagetrack{$num}[4]->cget( -text );
					$::pagenumbers{$page}{base} = $pagetrack{$num}[5]->get;
				}
				$recalc->invoke;
				$::lglobal{padjpopgoem} = $::lglobal{padjpop}->geometry;
				$::lglobal{padjpop}->destroy;
				undef $::lglobal{padjpop};
			}
		)->grid( -row => 1, -column => 2, -padx => 5 );
		my $frame1 = $::lglobal{padjpop}->Scrolled(
			'Pane',
			-scrollbars => 'se',
			-background => $::bkgcolor,
		  )->pack(
			-expand => 1,
			-fill   => 'both',
			-side   => 'top',
			-anchor => 'n'
		  );
		::drag($frame1);
		$top->update;
		my $updatetemp;
		$top->Busy( -recurse => 1 );
		my $row = 0;
		for my $page (@pages) {
			my ($num) = $page =~ /Pg(\S+)/;
			$updatetemp++;
			$::lglobal{padjpop}->update if ( $updatetemp == 20 );
			$pagetrack{$num}[0] = $frame1->Button(
				-text    => "Image# $num",
				-width   => 12,
				-command => [
					sub {
						::openpng( $textwindow, $num );
					},
				],
			)->grid( -row => $row, -column => 0, -padx => 2 );
			$pagetrack{$num}[1] = $frame1->Label(
				-text       => "Label -->",
				-background => $::bkgcolor,
			)->grid( -row => $row, -column => 1 );
			my $temp = $num;
			$temp =~ s/^0+//;
			$pagetrack{$num}[2] = $frame1->Label(
				-text       => "Pg $temp",
				-background => 'yellow',
			)->grid( -row => $row, -column => 2 );
			$pagetrack{$num}[3] = $frame1->Button(
				-text => ( $page eq $pages[0] ) ? 'Arabic' : '"',
				-width   => 8,
				-command => [
					sub {
						if ( $pagetrack{ $_[0] }[3]->cget( -text ) eq 'Arabic' )
						{
							$pagetrack{ $_[0] }[3]
							  ->configure( -text => 'Roman' );
						} elsif (
							$pagetrack{ $_[0] }[3]->cget( -text ) eq 'Roman' )
						{
							$pagetrack{ $_[0] }[3]->configure( -text => '"' );
						} elsif ( $pagetrack{ $_[0] }[3]->cget( -text ) eq '"' )
						{
							$pagetrack{ $_[0] }[3]
							  ->configure( -text => 'Arabic' );
						} else {
							$pagetrack{ $_[0] }[3]->configure( -text => '"' );
						}
					},
					$num
				],
			)->grid( -row => $row, -column => 3, -padx => 2 );
			$pagetrack{$num}[4] = $frame1->Button(
				-text => ( $page eq $pages[0] ) ? 'Start @' : '+1',
				-width   => 8,
				-command => [
					sub {
						if (
							$pagetrack{ $_[0] }[4]->cget( -text ) eq 'Start @' )
						{
							$pagetrack{ $_[0] }[4]->configure( -text => '+1' );
						} elsif (
							$pagetrack{ $_[0] }[4]->cget( -text ) eq '+1' )
						{
							$pagetrack{ $_[0] }[4]
							  ->configure( -text => 'No Count' );
						} elsif ( $pagetrack{ $_[0] }[4]->cget( -text ) eq
							'No Count' )
						{
							$pagetrack{ $_[0] }[4]
							  ->configure( -text => 'Start @' );
						} else {
							$pagetrack{ $_[0] }[4]->configure( -text => '+1' );
						}
					},
					$num
				],
			)->grid( -row => $row, -column => 4, -padx => 2 );
			$pagetrack{$num}[5] = $frame1->Entry(
				-width    => 8,
				-validate => 'all',
				-vcmd     => sub {
					return 0 if ( $_[0] =~ /\D/ );
					return 1;
				}
			)->grid( -row => $row, -column => 5, -padx => 2 );
			if ( $page eq $pages[0] ) {
				$pagetrack{$num}[5]->insert( 'end', $num );
			}
			$row++;
		}
		$top->Unbusy( -recurse => 1 );
		if ( defined $::pagenumbers{ $pages[0] }{action}
			and length $::pagenumbers{ $pages[0] }{action} )
		{
			for my $page (@pages) {
				my ($num) = $page =~ /Pg(\S+)/;
				$pagetrack{$num}[2]
				  ->configure( -text => $::pagenumbers{$page}{label} );
				$pagetrack{$num}[3]->configure(
					-text => ( $::pagenumbers{$page}{style} or 'Arabic' ) );
				$pagetrack{$num}[4]->configure(
					-text => ( $::pagenumbers{$page}{action} or '+1' ) );
				$pagetrack{$num}[5]->delete( '0', 'end' );
				$pagetrack{$num}[5]
				  ->insert( 'end', $::pagenumbers{$page}{base} );
			}
		}
		$frame1->yview( 'scroll', => 1, 'units' );
		$top->update;
		$frame1->yview( 'scroll', -1, 'units' );
	}
}

sub addpagelinks {
	my $selection = shift;
	$selection =~ s/(\d{1,3})-(\d{1,3})/<a href="#$::htmllabels{pglabel}$1">$1-$2<\/a>/g;
	$selection =~ s/(\d{1,3})([,;\.])/<a href="#$::htmllabels{pglabel}$1">$1<\/a>$2/g;
	$selection =~ s/\s(\d{1,3})\s/ <a href="#$::htmllabels{pglabel}$1">$1<\/a> /g;
	$selection =~ s/(\d{1,3})$/<a href="#$::htmllabels{pglabel}$1">$1<\/a>/;
	return $selection;
}
1;
