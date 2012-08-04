package Guiguts::PageSeparators;
use strict;
use warnings;

BEGIN {
	use Exporter();
	our ( @ISA, @EXPORT );
	@ISA    = qw(Exporter);
	@EXPORT = qw(&separatorpopup &delblanklines);
}

sub pageseparatorhelppopup {
	my $top       = $::top;
	my $help_text = <<'EOM';
    Join Lines - join lines removing any spaces, asterisks and hyphens as necessary. - Hotkey j
    Join, Keep hyphen - join lines removing any spaces and asterisks as necessary. - Hotkey k
    Blank line - remove spaces as necessary. Keep one blank line. (paragraph break). - Hotkey l
    New Section - remove spaces as necessary. Keep two blank lines (section break). - Hotkey t
    New Chapter - remove spaces as necessary. Keep four blank lines (chapter break). - Hotkey h
    Refresh - search for and center next page separator. - Hotkey r
    Undo - undo the previous page separator edit. - Hotkey u
    Delete - delete the page separator. Make no other edits. - Hotkey d
    Full Auto - automatically search for and convert if possible the next page separator. - Toggle - a
    Semi Auto - automatically search for and center the next page separator after an edit. - Toggle - s
    View page image - Hotkey v
    View Page Separator help -Hotkey ?
EOM
	if ( defined( $::lglobal{phelppop} ) ) {
		$::lglobal{phelppop}->deiconify;
		$::lglobal{phelppop}->raise;
		$::lglobal{phelppop}->focus;
	} else {
		$::lglobal{phelppop} = $top->Toplevel;
		$::lglobal{phelppop}->title('Functions and Hotkeys for Page Separator Fixup');
		::initialize_popup_with_deletebinding('phelppop');
		$::lglobal{phelppop}->Label(
			-justify => "left",
			-text    => $help_text
		)->pack;
		my $button_ok = $::lglobal{phelppop}->Button(
			-activebackground => $::activecolor,
			-text             => 'OK',
			-command          => sub {
				$::lglobal{phelppop}->destroy;
				undef $::lglobal{phelppop};
			}
		)->pack;
		$::lglobal{phelppop}->resizable( 'no', 'no' );
	}
}

# Called by "Refresh" on Separator popup.
# Search for page separator. If automatic, then process it.
sub refreshpageseparator {
	my $textwindow = $::textwindow;
	::viewpagenums() if ( $::lglobal{seepagenums} );
	findpageseparator();
	$textwindow->tagAdd( 'highlight', $::searchstartindex, $::searchendindex )
	  if $::searchstartindex;

	# Handle Automatic
	if ( ( $::lglobal{jautomatic} )
		&& $::searchstartindex )
	{
		handleautomaticonrefresh();
	}
	$textwindow->xviewMoveto(.0);
	$textwindow->markSet( 'insert', "$::searchstartindex+2l" )
	  if $::searchstartindex;
}

sub handleautomaticonrefresh {
	my $textwindow = $::textwindow;
	my $character;
	my ($index);
	$textwindow->markSet( 'page',  $::searchstartindex );        # error here
	$textwindow->markSet( 'page1', "$::searchstartindex+1l" );
	while (1) {
		$index     = $textwindow->index('page');
		$character = $textwindow->get("$index-1c");

   # If the character before ends with \s or \n or -*, (last case cannot happen)
   # delete the character
		if (   ( $character =~ /[\s\n]$/ )
			|| ( $character =~ /[\w-]\*$/ ) )
		{
			$textwindow->delete("$index-1c");
			$::lglobal{joinundo}++;
		} else {
			last;
		}
	}
	$textwindow->insert( $index, "\n" );
	$::lglobal{joinundo}++;

	# If the last character is a word, ";" or ","
	# and the next character is \n or *, then delete the character
	# Revision: dropped \n
	if ( $character =~ /[\w;,]/ ) {
		while (1) {
			$index     = $textwindow->index('page1');
			$character = $textwindow->get($index);
			if ( $character =~ /[\*]/ ) {    # dropped \n
				print "deleting:character page1\n";
				$textwindow->delete($index);
				$::lglobal{joinundo}++;
				last
				  if $textwindow->compare( 'page1 +1l', '>=', 'end' );
			} else {
				last;
			}
		}
	}

	# Do all specific
	if ( $::lglobal{joindoall} ) {
		if ( closeupmarkup() ) {
			refreshpageseparator();
		}    #else {
		     #	processpageseparator('d');
		     #}
	} else {

		# Join if the next character is lower case or with I
		#print $character.":page?\n";
		if ( ( $character =~ /\p{IsLower}/ ) || ( $character =~ /^I / ) ) {
			processpageseparator('j');
		}
		my ( $r, $c ) = split /\./, $textwindow->index('page-1c');
		my ($size) =
		  length( $textwindow->get( 'page+1l linestart', 'page+1l lineend' ) );

		# Insert blank line if the character is ."'?
		if ( ( $character =~ /[\.\"\'\?]/ ) && ( $c < ( $size * 0.5 ) ) ) {
			processpageseparator('l');
		}
	}
}

sub findpageseparator {
	my $textwindow = $::textwindow;
	$textwindow->tagRemove( 'highlight', '1.0', 'end' );
	$::searchstartindex = '1.0';
	$::searchendindex   = '1.0';
	$::searchstartindex =
	  $textwindow->search( '-nocase', '-regexp', '--', '^-----*\s?File:',
		$::searchendindex, 'end' );
	unless ($::searchstartindex) {
		::operationadd('Found last page separator');
		return;
	}
	$::searchendindex = $textwindow->index("$::searchstartindex lineend");
	$textwindow->yview('end');
	$textwindow->see($::searchstartindex) if $::searchstartindex;
}

sub closeupmarkup {
	my $textwindow = $::textwindow;
	my $changemade = 0;
	my $linebefore = $textwindow->get( 'page-1l linestart', 'page-1l lineend' );
	my $lineafter  = $textwindow->get( 'page+1l linestart', 'page+1l lineend' );
	if ( $linebefore =~ /((#|\*|p|x|f))\/$/ ) {
		my $closemarkup = "/$1\$";
		if ( $lineafter =~ $closemarkup ) {
			$textwindow->delete( 'page+1l linestart', 'page+1l lineend' );
			$textwindow->delete('page+1l linestart');
			$textwindow->delete( 'page-1l linestart', 'page-1l lineend' );
			$textwindow->delete('page-1l linestart');
			$changemade = 1;
		}
	} elsif ( $linebefore =~ /<\/(i|b|sc)>([,;*]?)$/ ) {
		my $lengthmarkup = 4 + length($2);
		my $lengthpunctuation;
		if ($2) {
			$lengthpunctuation = length($2) if ($2);
		} else {
			$lengthpunctuation = 0;
		}
		my $openmarkup = "^<$1>";
		if ( $lineafter =~ $openmarkup ) {
			$textwindow->delete( 'page+1l linestart', 'page+1l linestart+3c' );
			$textwindow->delete(
				"page-1l lineend-$lengthmarkup" . "c",
				"page-1l lineend-$lengthpunctuation" . "c"
			);
			$changemade = 1;
		}
	} elsif ( $linebefore =~ /\*$/ ) {
		if ( $lineafter =~ /^\*/ ) {
			$textwindow->delete('page+1l linestart');
			$changemade = 1;
		}
	}
	return $changemade;
}

# Process page separator based on option chosen: j, k, l, t, h, d
sub processpageseparator {
	my $op         = shift;
	my $textwindow = $::textwindow;
	::viewpagenums() if ( $::lglobal{seepagenums} );
	my ( $line, $index, $r, $c );
	findpageseparator();
	$::lglobal{joinundo} = 0;
	my $pagesep;
	$pagesep = $textwindow->get( $::searchstartindex, $::searchendindex )
	  if ( $::searchstartindex && $::searchendindex );
	my $pagemark = $pagesep;
	$pagesep =~ m/^-----*\s?File:\s?([^\.]+)/;
	return unless $1;
	$pagesep  = " <!--Pg$1-->";
	$pagemark = 'Pg' . $1;
	my $asterisk = 0;
	$textwindow->delete( $::searchstartindex, $::searchendindex )
	  if ( $::searchstartindex && $::searchendindex );
	$textwindow->markSet( 'page',    $::searchstartindex );
	$textwindow->markSet( $pagemark, "$::searchstartindex-1c" );
	$textwindow->markGravity( $pagemark, 'left' );
	$textwindow->markSet( 'insert', "$::searchstartindex+1c" );
	$index = $textwindow->index('page');

	unless ( $op eq 'd' ) {    # if not deleting the page separator
		while (1) {
			$index = $textwindow->index('page');
			$line  = $textwindow->get($index);
			if ( $line =~ /[\n\*]/ ) {
				$textwindow->delete($index);
				$::lglobal{joinundo}++;
				last if ( $textwindow->compare( $index, '>=', 'end' ) );
			} else {
				last;
			}
		}
		while (1) {
			$index = $textwindow->index('page');
			last if ( $textwindow->compare( $index, '>=', 'end' ) );
			$line = $textwindow->get("$index-1c");
			if ( $line eq '*' ) {
				$asterisk = 1;
				$line = $textwindow->get("$index-2c") . '*';
			}
			if ( ( $line =~ /[\s\n]$/ ) || ( $line =~ /[\w-]\*$/ ) ) {
				$textwindow->delete("$index-1c");
				$::lglobal{joinundo}++;
			} else {
				last;
			}
		}
	}

	# join lines
	if ( $op eq 'j' ) {
		$index = $textwindow->index('page');

		# Note: $line here and in similar cases actually seems to contain the
		# last _character_ on the previous page.
		$line = $textwindow->get("$index-1c");
		my $hyphens = 0;
		if ( $line =~ /\// ) {
			my $match = $textwindow->get( "$index-3c", "$index+2c" );
			if ( $match =~ /(.)\/\/\1/ ) {
				$textwindow->delete( "$index-3c", "$index+3c" );
				$::lglobal{joinundo}++;
			} else {
				$textwindow->insert( "$index", "\n" );
			}
			$index = $textwindow->index('page');
			$line  = $textwindow->get("$index-1c");
			last if ( $textwindow->compare( $index, '>=', 'end' ) );
			while ( $line eq '*' ) {
				$textwindow->delete("$index-1c");
				$index = $textwindow->index('page');
				$line  = $textwindow->get("$index-1c");
			}
			$line = $textwindow->get("$index-1c");
		}
		if ( $line =~ />/ ) {
			my $markupl = $textwindow->get( "$index-4c", $index );
			my $markupn = $textwindow->get( $index,      "$index+3c" );
			if ( ( $markupl =~ /<\/([ib])>/i ) && ( $markupn =~ /<$1>/i ) ) {
				$textwindow->delete( $index, "$index+3c" );
				$::lglobal{joinundo}++;
				$textwindow->delete( "$index-4c", $index );
				$::lglobal{joinundo}++;
				$index = $textwindow->index('page');
				$line  = $textwindow->get("$index-1c");
				last if ( $textwindow->compare( $index, '>=', 'end' ) );
			}
			while ( $line eq '*' ) {
				$textwindow->delete("$index-1c");
				$index = $textwindow->index('page');
				$line  = $textwindow->get("$index-1c");
			}
			$line = $textwindow->get("$index-1c");
		}
		if ( $line =~ /\-/ ) {
			unless (
				$textwindow->search(
					'-regexp', '--', '-----*\s?File:', $index,
					"$index lineend"
				)
			  )
			{
				while ( $line =~ /\-/ ) {
					$textwindow->delete("$index-1c");
					$::lglobal{joinundo}++;
					$index = $textwindow->index('page');
					$line  = $textwindow->get("$index-1c");
					last if ( $textwindow->compare( $index, '>=', 'end' ) );
				}
				$line = $textwindow->get($index);
				if ( $line =~ /\*/ ) {
					$textwindow->delete($index);
					$::lglobal{joinundo}++;
				}
				$index =
				  $textwindow->search( '-regexp', '--', '\s', $index, 'end' );
				$textwindow->delete($index);
				$::lglobal{joinundo}++;
			}
		}
		$textwindow->insert( $index, "\n" );
		$::lglobal{joinundo}++;
		$textwindow->insert( $index, $pagesep ) if $::lglobal{htmlpagenum};
		$::lglobal{joinundo}++ if $::lglobal{htmlpagenum};
	} elsif ( $op eq 'k' ) {    # join lines keep hyphen
		$index = $textwindow->index('page');
		$line  = $textwindow->get("$index-1c");
		if ( $line =~ />/ ) {
			my $markupl = $textwindow->get( "$index-4c", $index );
			my $markupn = $textwindow->get( $index,      "$index+3c" );
			if ( ( $markupl =~ /<\/[ib]>/i ) && ( $markupn =~ /<[ib]>/i ) ) {
				$textwindow->delete( $index, "$index+3c" );
				$::lglobal{joinundo}++;
				$textwindow->delete( "$index-4c", $index );
				$::lglobal{joinundo}++;
				$index = $textwindow->index('page');
				$line  = $textwindow->get("$index-1c");
				last if ( $textwindow->compare( $index, '>=', 'end' ) );
			}
			while ( $line eq '*' ) {
				$textwindow->delete("$index-1c");
				$index = $textwindow->index('page');
				$line  = $textwindow->get("$index-1c");
			}
			$line = $textwindow->get($index);
			while ( $line eq '*' ) {
				$textwindow->delete($index);
				$index = $textwindow->index('page');
				$line  = $textwindow->get($index);
			}
			$line = $textwindow->get("$index-1c");
		}
		if ( $line =~ /-/ ) {
			unless (
				$textwindow->search(
					'-regexp', '--', '^-----*\s?File:', $index,
					"$index lineend"
				)
			  )
			{
				# if the hyphen is starred, it should be clothed, no matter rwhyphenspace
				# (in fact, we shouldn't even move anything up if it's unstarred)
				if ( !$asterisk && $::rwhyphenspace ) {
					$textwindow->insert( "$index", " " );
					$index =
					  $textwindow->search( '-regexp', '--', '\s', "$index+1c",
						'end' );
				} else {
					$index =
					  $textwindow->search( '-regexp', '--', '\s', "$index",
						'end' );
				}
				$textwindow->insert( "$index", " " );
				$index =
				  $textwindow->search( '-regexp', '--', '\s', "$index+1c",
					'end' );
				$textwindow->delete($index);
				$::lglobal{joinundo}++;
			}
		}
		$line = $textwindow->get($index);
		if ( $line =~ /-/ ) {
			$::lglobal{joinundo}++;
			$index =
			  $textwindow->search( '-regexp', '--', '\s', $index, 'end' );
			$textwindow->delete($index);
			$::lglobal{joinundo}++;
		}
		$textwindow->insert( $index, "\n" );
		$::lglobal{joinundo}++;
		$textwindow->insert( $index, $pagesep ) if $::lglobal{htmlpagenum};
		$::lglobal{joinundo}++ if $::lglobal{htmlpagenum};
	} elsif ( $op eq 'l' ) {    # add a line
		$textwindow->insert( $index, "\n\n" );
		$::lglobal{joinundo}++;
		$textwindow->insert( $index, $pagesep ) if $::lglobal{htmlpagenum};
		$::lglobal{joinundo}++ if $::lglobal{htmlpagenum};
	} elsif ( $op eq 't' ) {    # new section
		$textwindow->insert( $index, "\n\n\n" );
		$::lglobal{joinundo}++;
		$textwindow->insert( $index, $pagesep ) if $::lglobal{htmlpagenum};
		$::lglobal{joinundo}++ if $::lglobal{htmlpagenum};
	} elsif ( $op eq 'h' ) {    # new chapter
		$textwindow->insert( $index, "\n\n\n\n\n" );
		$::lglobal{joinundo}++;
		$textwindow->insert( $index, $pagesep ) if $::lglobal{htmlpagenum};
		$::lglobal{joinundo}++ if $::lglobal{htmlpagenum};
	} elsif ( $op eq 'd' ) {    # delete
		$textwindow->insert( $index, $pagesep ) if $::lglobal{htmlpagenum};
		$::lglobal{joinundo}++ if $::lglobal{htmlpagenum};
		$textwindow->delete("$index-1c");
		$::lglobal{joinundo}++;
	}

	# refreshpageseparator and processpageseparator call each other
	# recursively
	refreshpageseparator()
	  if ( $::lglobal{jautomatic} || $::lglobal{jsemiautomatic} )
	  ;                         # || $::lglobal{joindoall}
	push @::joinundolist, $::lglobal{joinundo};
}

sub undojoin {
	my $textwindow = $::textwindow;
	if ( $::lglobal{jautomatic} ) {
		$textwindow->undo;
		$textwindow->tagRemove( 'highlight', '1.0', 'end' );
		return;
	}
	my $joinundo = pop @::joinundolist;
	push @::joinredolist, $joinundo;
	$textwindow->undo for ( 0 .. $joinundo );
	refreshpageseparator();
}

sub redojoin {
	my $textwindow = $::textwindow;
	if ( $::lglobal{jautomatic} ) {
		$textwindow->redo;
		$textwindow->tagRemove( 'highlight', '1.0', 'end' );
		return;
	}
	my $joinredo = pop @::joinredolist;
	push @::joinundolist, $joinredo;
	$textwindow->redo for ( 0 .. $joinredo );

	#refreshpageseparator();
}

sub separatorpopup {
	my $textwindow = $::textwindow;
	my $top        = $::top;
	::operationadd('Begin Page Separators Fixup');
	refreshpageseparator();
	if ( defined( $::lglobal{pagepop} ) ) {
		$::lglobal{pagepop}->deiconify;
		$::lglobal{pagepop}->raise;
		$::lglobal{pagepop}->focus;
	} else {
		$::lglobal{pagepop} = $top->Toplevel;
		::initialize_popup_without_deletebinding('pagepop');
		$::lglobal{pagepop}->title('Page Separator Fixup');
		my $sf1 =
		  $::lglobal{pagepop}->Frame->pack( -side => 'top', -anchor => 'n' );
		my $joinbutton = $sf1->Button(
			-activebackground => $::activecolor,
			-command          => sub { processpageseparator('j') },
			-text             => 'Join Lines',
			-underline        => 0,
			-width            => 19
		)->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'w' );
		my $joinhybutton = $sf1->Button(
			-activebackground => $::activecolor,
			-command          => sub { processpageseparator('k') },
			-text             => 'Join, Keep Hyphen',
			-underline        => 6,
			-width            => 19
		)->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'w' );
		my $sf2 =
		  $::lglobal{pagepop}
		  ->Frame->pack( -side => 'top', -anchor => 'n', -padx => 5 );
		my $blankbutton = $sf2->Button(
			-activebackground => $::activecolor,
			-command          => sub { processpageseparator('l') },
			-text             => 'Blank Line',
			-underline        => 6,
			-width            => 12
		)->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'w' );
		my $sectjoinbutton = $sf2->Button(
			-activebackground => $::activecolor,
			-command          => sub { processpageseparator('t') },
			-text             => 'New Section',
			-underline        => 7,
			-width            => 12
		)->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'w' );
		my $chjoinbutton = $sf2->Button(
			-activebackground => $::activecolor,
			-command          => sub { processpageseparator('h') },
			-text             => 'New Chapter',
			-underline        => 5,
			-width            => 12
		)->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'w' );
		my $sf3 =
		  $::lglobal{pagepop}
		  ->Frame->pack( -side => 'top', -anchor => 'n', -padx => 5 );
		my $jautobutton = $sf3->Checkbutton(
			-variable => \$::lglobal{jautomatic},
			-command  => sub {
				$::lglobal{jsemiautomatic} = 0 if $::lglobal{jsemiautomatic};
				$::lglobal{joindoall}      = 0 if $::lglobal{joindoall};
			},
			-selectcolor => $::lglobal{checkcolor},
			-text        => 'Full Auto',
		)->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'w' );
		my $jsautobutton = $sf3->Checkbutton(
			-variable => \$::lglobal{jsemiautomatic},
			-command  => sub {
				$::lglobal{jautomatic} = 0 if $::lglobal{jautomatic};
				$::lglobal{joindoall}  = 0 if $::lglobal{joindoall};
			},
			-selectcolor => $::lglobal{checkcolor},
			-text        => 'Semi Auto',
		)->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'w' );
		$::lglobal{jsshowimagebutton} = $sf3->Checkbutton(
			-variable    => \$::auto_show_images,
			-selectcolor => $::lglobal{checkcolor},
			-text        => 'Images'
		)->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'w' );
		my $sf4 =
		  $::lglobal{pagepop}
		  ->Frame->pack( -side => 'top', -anchor => 'n', -padx => 5 );
		my $refreshbutton = $sf4->Button(
			-activebackground => $::activecolor,
			-command          => sub { refreshpageseparator() },
			-text             => 'Refresh',
			-underline        => 0,
			-width            => 8
		)->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'w' );
		my $delbutton = $sf4->Button(
			-activebackground => $::activecolor,
			-command          => sub { processpageseparator('d') },
			-text             => 'Delete',
			-underline        => 0,
			-width            => 8
		)->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'w' );
		my $phelpbutton = $sf4->Button(
			-activebackground => $::activecolor,
			-command          => sub { pageseparatorhelppopup() },
			-text             => '?',
			-width            => 1
		)->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'w' );
		my $sf5 =
		  $::lglobal{pagepop}
		  ->Frame->pack( -side => 'top', -anchor => 'n', -padx => 5 );
		my $undobutton = $sf5->Button(
			-activebackground => $::activecolor,
			-command          => sub { undojoin() },
			-text             => 'Undo',
			-underline        => 0,
			-width            => 8
		)->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'w' );
		my $redobutton = $sf5->Button(
			-activebackground => $::activecolor,
			-command          => sub { redojoin() },
			-text             => 'Redo',
			-underline        => 0,
			-width            => 8
		)->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'w' );
		my $doall2button = $sf5->Button(
			-activebackground => $::activecolor,
			-command  => sub {
				$::lglobal{jsemiautomatic} = 0 if $::lglobal{jsemiautomatic};
				$::lglobal{jautomatic}     = 0 if $::lglobal{jautomatic};
				iterateeautomatic();
			},
			-text             => 'Do All (beta)',
			-underline        => 0,
			-width            => 12
		)->pack( -side => 'left', -pady => 2, -padx => 2, -anchor => 'w' );
		$::lglobal{jsemiautomatic} = 1
		  unless ( ( $::lglobal{jautomatic} ) || ( $::lglobal{joindoall} ) );
	}
	$::lglobal{pagepop}->protocol(
		'WM_DELETE_WINDOW' => sub {
			$::lglobal{pagepop}->destroy;
			undef $::lglobal{pagepop};
			$textwindow->tagRemove( 'highlight', '1.0', 'end' );
		}
	);
	$::lglobal{pagepop}->Tk::bind( '<j>' => sub { processpageseparator('j') } );
	$::lglobal{pagepop}->Tk::bind( '<k>' => sub { processpageseparator('k') } );
	$::lglobal{pagepop}->Tk::bind( '<l>' => sub { processpageseparator('l') } );
	$::lglobal{pagepop}->Tk::bind( '<h>' => sub { processpageseparator('h') } );
	$::lglobal{pagepop}->Tk::bind( '<d>' => sub { processpageseparator('d') } );
	$::lglobal{pagepop}->Tk::bind( '<t>' => sub { processpageseparator('t') } );
	$::lglobal{pagepop}
	  ->Tk::bind( '<?>' => sub { pageseparatorhelppopup('?') } );
	$::lglobal{pagepop}->Tk::bind( '<r>' => \&refreshpageseparator );
	$::lglobal{pagepop}->Tk::bind(
		'<v>' => sub {
			::openpng( $textwindow, ::get_page_number() );
			$::lglobal{pagepop}->raise;
		}
	);
	$::lglobal{pagepop}->Tk::bind( '<u>' => \&undojoin );
	$::lglobal{pagepop}->Tk::bind( '<e>' => \&redojoin );
	$::lglobal{pagepop}->Tk::bind(
		'<a>' => sub {
			if   ( $::lglobal{jautomatic} ) { $::lglobal{jautomatic} = 0 }
			else                            { $::lglobal{jautomatic} = 1 }
		}
	);
	$::lglobal{pagepop}->Tk::bind(
		'<s>' => sub {
			if ( $::lglobal{jsemiautomatic} ) { $::lglobal{jsemiautomatic} = 0 }
			else                              { $::lglobal{jsemiautomatic} = 1 }
		}
	);
	$::lglobal{pagepop}->transient($top) if $::stayontop;
}

# Run through automatic cases without deep recursion
sub iterateeautomatic {
	::working('Do All Page Separators');
	my $iterationlimit = 0;
	while ($::searchstartindex) {
		findpageseparator();
		unless ($::searchstartindex) {
			last;
		}
		handleautomaticonrefresh();
		processpageseparator('d');
		if ($iterationlimit++ > 5000) {
			last;
		}
	}
	::working();
}

# Delete blank lines before page separators
sub delblanklines {
	my $textwindow = $::textwindow;
	::viewpagenums() if ( $::lglobal{seepagenums} );
	::operationadd('Remove blank lines before page separators');
	my ( $line, $index, $r, $c, $pagemark );
	$::searchstartindex = '2.0';
	$::searchendindex   = '2.0';
	$textwindow->Busy;
	while ($::searchstartindex) {
		$::searchstartindex =
		  $textwindow->search( '-nocase', '-regexp', '--',
			'^-----*\s*File:\s?(\S+)\.(png|jpg)---.*$',
			$::searchendindex, 'end' );
		{
			no warnings 'uninitialized';
			$::searchstartindex = '2.0' if $::searchstartindex eq '1.0';
		}
		last unless $::searchstartindex;
		( $r, $c ) = split /\./, $::searchstartindex;
		if ( $textwindow->get( ( $r - 1 ) . '.0', ( $r - 1 ) . '.end' ) eq '' )
		{
			$textwindow->delete( "$::searchstartindex -1c",
				$::searchstartindex );
			$::searchendindex = $textwindow->index("$::searchstartindex -2l");
			$textwindow->see($::searchstartindex);
			$textwindow->update;
			next;
		}
		$::searchendindex = $r ? "$r.end" : '2.0';
	}
	$textwindow->Unbusy;
}
1;
