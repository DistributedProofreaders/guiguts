package Guiguts::ErrorCheck;
use strict;
use warnings;
BEGIN {
	use Exporter();
	our ( @ISA, @EXPORT );
	@ISA = qw(Exporter);
	@EXPORT =
	  qw(&errorcheckpop_up &gcheckpop_up &gutcheck &jeebiespop_up);
}

# General error check window
# Handles HTML & CSS Validate, Tidy, Link Check
# pphtml, pptxt and Load External Checkfile,
# TODO: Incorporate Gutcheck & Jeebies as well to avoid code duplication and divergence?
sub errorcheckpop_up {
	my ( $textwindow, $top, $errorchecktype ) = @_;
	my ( %errors,     @errorchecklines );
	my ( $line,       $lincol );
	::hidepagenums();
	if ( $::lglobal{errorcheckpop} ) {
		$::lglobal{errorcheckpop}->destroy;
		undef $::lglobal{errorcheckpop};
	}
	$::lglobal{errorcheckpop} = $top->Toplevel;
	$::lglobal{errorcheckpop}->title($errorchecktype);
	my $ptopframe = $::lglobal{errorcheckpop}->Frame->pack;
	my $buttonlabel = 'Run Checks';
	$buttonlabel = 'Load Checkfile' if $errorchecktype eq 'Load Checkfile';
	my $opsbutton = $ptopframe->Button(
		-activebackground => $::activecolor,
		-command          => sub {
			errorcheckpop_up( $textwindow, $top, $errorchecktype );
			unlink 'null' if ( -e 'null' );
		},
		-text  => $buttonlabel,
		-width => 16
	  )->pack(
			   -side   => 'left',
			   -pady   => 10,
			   -padx   => 2,
			   -anchor => 'n'
	  );

	# Add verbose checkbox only for certain error check types
	if (    ( $errorchecktype eq 'Check All' )
		 or ( $errorchecktype eq 'Link Check' )
		 or ( $errorchecktype eq 'W3C Validate CSS' )
		 or ( $errorchecktype eq 'ppvimage' )
		 or ( $errorchecktype eq 'pphtml' ) )
	{
		$ptopframe->Checkbutton(
								 -variable    => \$::verboseerrorchecks,
								 -selectcolor => $::lglobal{checkcolor},
								 -text        => 'Verbose'
		  )->pack(
				   -side   => 'left',
				   -pady   => 10,
				   -padx   => 2,
				   -anchor => 'n'
		  );
	}
	my $pframe =
	  $::lglobal{errorcheckpop}
	  ->Frame->pack( -fill => 'both', -expand => 'both', );
	$::lglobal{errorchecklistbox} =
	  $pframe->Scrolled(
						 'Listbox',
						 -scrollbars  => 'se',
						 -background  => $::bkgcolor,
						 -font        => $::lglobal{font},
						 -selectmode  => 'single',
						 -activestyle => 'none',
	  )->pack(
			   -anchor => 'nw',
			   -fill   => 'both',
			   -expand => 'both',
			   -padx   => 2,
			   -pady   => 2
	  );
	::initialize_popup_with_deletebinding('errorcheckpop');

	::drag( $::lglobal{errorchecklistbox} );
	::BindMouseWheel( $::lglobal{errorchecklistbox} );
	$::lglobal{errorchecklistbox}
	  ->eventAdd( '<<view>>' => '<Button-1>', '<Return>' );
	$::lglobal{errorchecklistbox}->bind(
		'<<view>>',
		sub { errorcheckview(); }
	);
	# buttons 2 & 3 delete the clicked error and select the next error
	$::lglobal{errorchecklistbox}->eventAdd('<<remove>>' => '<ButtonRelease-2>',
											'<ButtonRelease-3>' );
	$::lglobal{errorchecklistbox}->bind(
		'<<remove>>',
		sub {
			$::lglobal{errorchecklistbox}->activate(
							   $::lglobal{errorchecklistbox}->index(
								   '@'
									 . (
									   $::lglobal{errorchecklistbox}->pointerx -
										 $::lglobal{errorchecklistbox}->rootx
									 )
									 . ','
									 . (
									   $::lglobal{errorchecklistbox}->pointery -
										 $::lglobal{errorchecklistbox}->rooty
									 )
							   )
			);
			$::lglobal{errorchecklistbox}->selectionClear( 0, 'end' );
			$::lglobal{errorchecklistbox}
			  ->selectionSet( $::lglobal{errorchecklistbox}->index('active') );
			$::lglobal{errorchecklistbox}->delete('active');
			$::lglobal{errorchecklistbox}->selectionSet('active');
			errorcheckview();
			$::lglobal{errorchecklistbox}->after( $::lglobal{delay} );
		}
	);
	$::lglobal{errorcheckpop}->update;

	# End presentation; begin logic
	my (@errorchecktypes);    # Multiple errorchecktypes in one popup
	if ( $errorchecktype eq 'Check All' ) {
		@errorchecktypes = (
							 'W3C Validate',
							 'HTML Tidy',
							 'ppvimage',
							 'Link Check',
							 'W3C Validate CSS',
							 'pphtml'
		);
	} else {
		@errorchecktypes = ($errorchecktype);
	}
	%errors          = ();
	@errorchecklines = ();
	my $mark  = 0;
	my @marks = $textwindow->markNames;
	for (@marks) {
		if ( $_ =~ /^t\d+$/ ) {
			$textwindow->markUnset($_);
		}
	}
	my $unicode = ::currentfileisunicode();
	foreach my $thiserrorchecktype (@errorchecktypes) {
		my $fname = '';
		if ( $thiserrorchecktype eq 'Load Checkfile' ) {
			$fname = $::lglobal{errorcheckpop}->getOpenFile( -title => 'File Name?' );
			last if ( not $fname );
		} else {
			::working($thiserrorchecktype);
			push @errorchecklines, "Beginning check: " . $thiserrorchecktype;
			if ( errorcheckrun($thiserrorchecktype) ) {
				push @errorchecklines, "Failed to run: " . $thiserrorchecktype;
			}
			$fname = "errors.err";
		}
		my $fh = FileHandle->new("< $fname");
		if ( not defined($fh) ) {
			my $dialog = $top->Dialog(
									   -text => 'Could not find '
										 . $thiserrorchecktype
										 . ' error file.',
									   -bitmap  => 'question',
									   -title   => 'File not found',
									   -buttons => [qw/OK/],
			);
			$dialog->Show;
		} else {
			while ( $line = <$fh> ) {
				utf8::decode($line) if $unicode;
				$line =~ s/^\s//g;
				chomp $line;

				# Skip rest of CSS
				if (
					     ( not $::verboseerrorchecks )
					 and ( $thiserrorchecktype eq 'W3C Validate CSS' )
					 and (    ( $line =~ /^To show your readers/i )
						   or ( $line =~ /^Valid CSS Information/i ) )
				  )
				{
					last;
				}
				if (
					( $line =~ /^\s*$/i
					)    # skip some unnecessary lines from W3C Validate CSS
					or ( $line =~ /^{output/i and not $::verboseerrorchecks )
					or ( $line =~ /^W3C/i )
					or ( $line =~ /^URI/i )
				  )
				{
					next;
				}
				if ( !$::OS_WIN && $thiserrorchecktype eq 'W3C Validate CSS' ) {
					$line =~ s/(\x0d)$//;
				}

				# Skip verbose informational warnings in Link Check
				if (     ( not $::verboseerrorchecks )
					 and ( $thiserrorchecktype eq 'Link Check' )
					 and ( $line =~ /^Link statistics/i ) )
				{
					last;
				}
				if ( $thiserrorchecktype eq 'pphtml' ) {
					if ( $line =~ /^-/i ) {    # skip lines beginning with '-'
						next;
					}
					if ( ( not $::verboseerrorchecks )
						 and $line =~ /^Verbose checks/i )
					{    # stop with verbose specials check
						last;
					}
				}
				no warnings 'uninitialized';
				if ( $thiserrorchecktype eq 'HTML Tidy' ) {
					if (     ( $line =~ /^[lI\d]/ )
						 and ( $line ne $errorchecklines[-1] ) )
					{
						push @errorchecklines, $line;
						$::errors{$line} = '';
						$lincol = '';
						if ( $line =~ /^line (\d+) column (\d+)/i ) {
							$lincol = "$1.$2";
							$mark++;
							$textwindow->markSet( "t$mark", $lincol );
							$::errors{$line} = "t$mark";
						}
					}
				} elsif (    ( $thiserrorchecktype eq "W3C Validate" )
						  or ( $thiserrorchecktype eq "W3C Validate Remote" )
						  or ( $thiserrorchecktype eq "pphtml" )
						  or ( $thiserrorchecktype eq "ppvimage" ) )
				{
					$line =~ s/^.*:(\d+:\d+)/line $1/;
					$line =~ s/^(\d+:\d+)/line $1/;
					$line =~ s/^(line \d+) /$1:1/;
					$::errors{$line} = '';
					$lincol = '';
					if ( $line =~ /line (\d+):(\d+)/ ) {
						$lincol = "$1.$2";
						$lincol =~ s/\.0/\.1/;  # change column zero to column 1
						$mark++;
						$textwindow->markSet( "t$mark", $lincol );
						$::errors{$line} = "t$mark";
					}
					push @errorchecklines, $line unless $line eq '';
				} elsif (    ( $thiserrorchecktype eq "W3C Validate CSS" )
						  or ( $thiserrorchecktype eq "Link Check" )
						  or ( $thiserrorchecktype eq "pptxt" ) )
				{
					$line =~ s/Line : (\d+)/line $1:1/;
					push @errorchecklines, $line;
					$::errors{$line} = '';
					$lincol = '';
					if ( $line =~ /line (\d+):(\d+)/ ) {
						my $plusone = $1 + 1;
						$lincol = "$plusone.$2";
						$mark++;
						$textwindow->markSet( "t$mark", $lincol );
						$::errors{$line} = "t$mark";
					}
				# Load a checkfile from an external tool, e.g. online ppcomp, pptxt, pphtml
				# File may be in HTML format or a text file
				} elsif ( $thiserrorchecktype eq "Load Checkfile" ) {
					# if HTML file, ignore the header & footer
					if ( $line =~ /<body>/ ) { 
						@errorchecklines = ();
						next;
					}
					last if ( $line =~ /<\/body>/ );
					# Mark *red text* (used by pptxt)
					$line =~ s/<span class='red'>([^<]*)<\/span>/*$1*/g;				
					# Mark >>>inserted<<< and ###deleted### text (used by ppcomp)
					$line =~ s/<ins>([^<]*)<\/ins>/>>>$1<<</g;				
					$line =~ s/<del>([^<]*)<\/del>/###$1###/g;				
					# Remove some unwanted HTML
					$line =~ s/<\/?span[^>]*>//g;
					$line =~ s/<\/?a[^>]*>//g;
					$line =~ s/<\/?pre>//g;
					$line =~ s/<\/?p[^>]*>//g;
					$line =~ s/<\/?div[^>]*>//g;
					$line =~ s/<br[^>]*>/ /g;			# Line break becomes space - can't insert \n
					$line =~ s/<\/?h[1-6][^>]*>/***/g;	# Put asterisks round headers
					$line =~ s/<hr[^>]*>/====/g;		# Replace horizontal rules with ====
					$line =~ s/\&lt;/</g;				# Restore < & > characters
					$line =~ s/\&gt;/>/g;
					
					# if line has a number at the start, assume it is the error line number
					$::errors{$line} = '';
					$lincol = '';
					if ( $line =~ /^\s*\d+/ ) {
						$line =~ s/^\s*(\d+)/line $1/;
						$lincol = "$1.0";
						$mark++;
						# add a new mark in the main text at the correct point
						$textwindow->markSet( "t$mark", $lincol );
						# remember which line goes with which mark
						$::errors{$line} = "t$mark";
					}
					# display all lines, even those without line numbers
					push @errorchecklines, $line;
				}
			}
		}
		$fh->close if $fh;
		unlink 'errors.err' unless $thiserrorchecktype eq 'Load Checkfile';
		my $size = @errorchecklines;
		if ( ( $thiserrorchecktype eq "W3C Validate CSS" ) and ( $size <= 1 ) )
		{    # handle errors.err file with zero lines
			push @errorchecklines,
"Could not perform validation: install java or use W3C CSS Validation web site.";
		} else {
			push @errorchecklines, "Check is complete: " . $thiserrorchecktype
				unless $thiserrorchecktype eq 'Load Checkfile';
			if ( $thiserrorchecktype eq "W3C Validate" ) {
				push @errorchecklines,
				  "Don't forget to do the final validation at http://validator.w3.org";
			}
			if ( $thiserrorchecktype eq "W3C Validate CSS" ) {
				push @errorchecklines,
"Don't forget to do the final validation at http://jigsaw.w3.org/css-validator/";
			}
			push @errorchecklines, "";
		}
		::working() unless $thiserrorchecktype eq 'Load Checkfile';
	}
	$::lglobal{errorchecklistbox}->insert( 'end', @errorchecklines );
	$::lglobal{errorchecklistbox}->yview( 'scroll', 1, 'units' );
	$::lglobal{errorchecklistbox}->update;
	$::lglobal{errorchecklistbox}->yview( 'scroll', -1, 'units' );
	$::lglobal{errorchecklistbox}->focus;
	$::lglobal{errorcheckpop}->raise;
}

sub errorcheckrun {    # Runs Tidy, W3C Validate, and other error checks
	                   #my ( $textwindow, $top, $errorchecktype ) = @_;
	my $errorchecktype = shift;
	my $textwindow     = $::textwindow;
	my $top            = $::top;
	if ( $errorchecktype eq 'W3C Validate Remote' ) {
		unless ( eval { require WebService::Validator::HTML::W3C } ) {
			print
"Install the module WebService::Validator::HTML::W3C to do W3C Validation remotely. Defaulting to local validation.\n";
			$errorchecktype = 'W3C Validate';
		}
	}
	::operationadd( "$errorchecktype" );
	::hidepagenums();
	if ( $::lglobal{errorcheckpop} ) {
		$::lglobal{errorchecklistbox}->delete( '0', 'end' );
	}
	my ( $name, $fname, $path, $extension, @path );
	$textwindow->focus;
	::update_indicators();
	my $title = $top->cget('title');
	if ( $title =~ /No File Loaded/ ) { ::savefile( $textwindow, $top ) }
	if ( $errorchecktype eq 'HTML Tidy' ) {
		unless ( $::tidycommand ) {
			::locateExecutable( 'HTML Tidy', \$::tidycommand );
			return 1 unless $::tidycommand;
		}
	} elsif (     ( $errorchecktype eq "W3C Validate" )
			  and ( $::w3cremote == 0 ) )
	{
		unless ( $::validatecommand ) {
			::locateExecutable( 'W3C HTML Validator (onsgmls)', \$::validatecommand);
			return 1 unless $::validatecommand;
		}
	} elsif ( $errorchecktype eq 'W3C Validate CSS' ) {
		unless ($::validatecsscommand) {
			my $types = [ [ 'JAR file', [ '.jar', ] ], [ 'All Files', ['*'] ], ];
			::locateExecutable('W3C CSS Validator (css-validate.jar)', \$::validatecsscommand, $types);
			return 1 unless $::validatecsscommand;
		}
	}
	::savesettings();
	$top->Busy( -recurse => 1 );
	if (    ( $errorchecktype eq 'W3C Validate Remote' )
		 or ( $errorchecktype eq 'W3C Validate CSS' ) )
	{
		$name = 'validate.html';
	} elsif ( $errorchecktype eq 'ppvimage' ) {
		my ( $f, $d, $e ) =
		  ::fileparse( $::lglobal{global_filename}, qr{\.[^\.]*$} );
		$name = $d . 'errors.tmp'; # ppvimage requires tmp file to be in the right dir, so the paths match
	} else {
		$name = 'errors.tmp';
	}
	my $unicode = ::currentfileisunicode();
	if ( open my $td, '>', $name ) {
		my $count = 0;
		my $index = '1.0';
		my ($lines) = $textwindow->index('end - 1c') =~ /^(\d+)\./;
		while ( $textwindow->compare( $index, '<', 'end' ) ) {
			my $end = $textwindow->index("$index  lineend +1c");
			my $gettext = $textwindow->get( $index, $end );
			utf8::encode($gettext) if ( $unicode );
			print $td $gettext;
			$index = $end;
		}
		close $td;
	} else {
		warn "Could not open temp file for writing. $!";
		my $dialog = $top->Dialog(
				-text => 'Could not write to the '
				  . cwd()
				  . ' directory. Check for write permission or space problems.',
				-bitmap  => 'question',
				-title   => "$errorchecktype problem",
				-buttons => [qw/OK/],
		);
		$dialog->Show;
		return;
	}
	if ( $::lglobal{errorcheckpop} ) {
		$::lglobal{errorchecklistbox}->delete( '0', 'end' );
	}
	if ( $errorchecktype eq 'HTML Tidy' ) {
		if ( $unicode ) {
			::run( $::tidycommand, "-f", "errors.err", "-o", "null", "-utf8", $name );
		} else {
			::run( $::tidycommand, "-f", "errors.err", "-o", "null", $name );
		}
	} elsif ( $errorchecktype eq 'W3C Validate' ) {
		if ( $::w3cremote == 0 ) {
			my $validatepath = ::dirname($::validatecommand);
			$ENV{SP_BCTF} = 'UTF-8' if $unicode;
			::run(
					$::validatecommand,    "--directory=$validatepath",
					"--catalog=".($::OS_WIN?"xhtml.soc":"tools/W3C/xhtml.soc"),
					"--no-output",
					"--open-entities",     "--error-file=errors.err",
					$name
			);
		}
	} elsif ( $errorchecktype eq 'W3C Validate Remote' ) {
		my $validator = WebService::Validator::HTML::W3C->new( detailed => 1 );
		if ( $validator->validate_file('./validate.html') ) {
			if ( open my $td, '>', "errors.err" ) {
				if ( $validator->is_valid ) {
				} else {
					my $errors = $validator->errors();
					my $warnings = $validator->warnings();
					my $warnidx = 0;
					# print all the errors and warnings in correct line order
					foreach my $error ( @$errors ) {
						# print any warnings that should come before the next error
						while ( $warnidx < @$warnings ) {
							my $warn = $warnings->[$warnidx];
							last if $warn->line > $error->line or
						            $warn->line == $error->line and $warn->col > $error->line;
							printf $td ( "%s:%s:W: %s\n",
										 $warn->line, $warn->col, $warn->msg );
							++$warnidx;
						}
						# print next error
						printf $td ( "%s:%s:E: %s\n",
									 $error->line, $error->col, $error->msg );
					}
					# print any remaining warnings beyond the last error
					while ( $warnidx < @$warnings ) {
						my $warn = $warnings->[$warnidx];
						printf $td ( "%s:%s:W: %s\n",
									 $warn->line, $warn->col, $warn->msg );
						++$warnidx;
					}
					print $td "Remote response complete";
				}
				close $td;
			}
		} else {
			if ( open my $td, '>', "errors.err" ) {
				print $td $validator->validator_error() . "\n";
				print $td "Try using local validator onsgmls\n";
				close $td;
			}
		}
	} elsif ( $errorchecktype eq 'W3C Validate CSS' ) {
		my $runner = ::runner::tofile( "errors.err", "errors.err" ); # stdout & stderr
		$runner->run( "java", "-jar", $::validatecsscommand, "--profile=$::lglobal{cssvalidationlevel}", "file:$name" );
	} elsif ( $errorchecktype eq 'pphtml' ) {
		::run( "perl", "lib/ppvchecks/pphtml.pl", "-i", $name, "-o",
				"errors.err" );
	} elsif ( $errorchecktype eq 'Link Check' ) {
		linkcheckrun();
	} elsif ( $errorchecktype eq 'ppvimage' ) {
		if ( $::verboseerrorchecks ) {
			::run( 'perl', 'tools/ppvimage/ppvimage.pl',
			  '-gg', '-o', 'errors.err', $name );
		} else {
			::run( 'perl', 'tools/ppvimage/ppvimage.pl',
			  '-gg', '-terse', '-o', 'errors.err', $name );
		}
	} elsif ( $errorchecktype eq 'pptxt' ) {
		::run( "perl", "lib/ppvchecks/pptxt.pl", "-i", $name, "-o",
				"errors.err" );
	}
	$top->Unbusy;
	unlink $name;
	return;
}

sub linkcheckrun {
	my $textwindow = $::textwindow;
	my $top        = $::top;
	open my $logfile, ">", "errors.err" || die "output file error\n";
	my ( %anchor,  %id,  %link,   %image,  %badlink, $length, $upper );
	my ( $anchors, $ids, $ilinks, $elinks, $images,  $count,  $css ) =
	  ( 0, 0, 0, 0, 0, 0, 0 );
	my @warning = ();
	my $fname   = $::lglobal{global_filename};
	if ( $fname =~ /(No File Loaded)/ ) {
		print $logfile "You need to save your file first.";
		return;
	}
	my ( $f, $d, $e ) = ::fileparse( $fname, qr{\.[^\.]*$} );
	my %imagefiles;
	my @ifiles   = ();
	my $imagedir = '';
	push @warning, '';
	my ( $fh, $filename );
	my @temp = split( /[\\\/]/, $textwindow->FileName );
	my $tempfilename = $temp[-1];

	if ( $tempfilename =~ /projectid/i ) {
		print $logfile "Choose a human readable filename: $tempfilename\n";
	}
	if ( $tempfilename =~ /[A-Z]/ ) {
		print $logfile "Use only lower case in filename: $tempfilename\n";
	}
	if ( $textwindow->numberChanges ) {
		$filename = 'tempfile.tmp';
		open( my $fh, ">", "$filename" );
		my ($lines) = $textwindow->index('end - 1 chars') =~ /^(\d+)\./;
		my $index = '1.0';
		while ( $textwindow->compare( $index, '<', 'end' ) ) {
			my $end = $textwindow->index("$index lineend +1c");
			my $line = $textwindow->get( $index, $end );
			print $fh $line;
			$index = $end;
		}
		$fname = $filename;
		close $fh;
	}
	my $parser = HTML::TokeParser->new($fname);
	while ( my $token = $parser->get_token ) {
		if ( $token->[0] eq 'S' and $token->[1] eq 'style' ) {
			$token = $parser->get_token;
			if ( $token->[0] eq 'T' and $token->[2] ) {
				my @urls = $token->[1] =~ m/\burl\(['"](.+?)['"]\)/gs;
				for my $img (@urls) {
					if ($img) {
						if ( !$imagedir ) {
							$imagedir = $img;
							$imagedir =~ s/\/.*?$/\//;
							@ifiles = glob( ::dos_path( $d . $imagedir ) . '*.*' );
							for (@ifiles) { $_ =~ s/\Q$d\E// }
							for (@ifiles) { $imagefiles{$_} = '' }
						}
						$image{$img}++;
						$upper++ if ( $img ne lc($img) );
						delete $imagefiles{$img}
						  if (    ( defined $imagefiles{$img} )
							   || ( defined $link{$img} ) );
						push @warning, "+$img: contains uppercase characters!\n"
						  if ( $img ne lc($img) );
						push @warning, "+$img: not found!\n"
						  unless ( -e $d . $img );
						$css++;
					}
				}
			}
		}
		next unless $token->[0] eq 'S';
		my $url    = $token->[2]{href} || '';
		my $anchor = $token->[2]{name} || '';
		my $img    = $token->[2]{src}  || '';
		my $id     = $token->[2]{id}   || '';
		if ($anchor) {
			$anchor{ '#' . $anchor } = $anchor;
			$anchors++;
		} elsif ($id) {
			$id{ '#' . $id } = $id;
			$ids++;
		}
		if ( $url =~ m/^(#?)(.+)$/ ) {
			$link{ $1 . $2 } = $2;
			$ilinks++ if $1;
			$elinks++ unless $1;
		}
		if ($img) {
			if ( !$imagedir ) {
				$imagedir = $img;
				$imagedir =~ s/\/.*?$/\//;
				@ifiles = glob( $d . $imagedir . '*.*' );
				for (@ifiles) { $_ =~ s/\Q$d\E// }
				for (@ifiles) { $imagefiles{$_} = '' }
			}
			$image{$img}++;
			$upper++ if ( $img ne lc($img) );
			delete $imagefiles{$img}
			  if (    ( defined $imagefiles{$img} )
				   || ( defined $link{$img} ) );
			push @warning, "+$img: contains uppercase characters!\n"
			  if ( $img ne lc($img) );
			push @warning, "+$img: not found!\n"
			  unless ( -e $d . $img );
			$images++;
		}
	}
	for ( keys %link ) {
		$badlink{$_} = $_ if ( $_ =~ m/\\|\%5C|\s|\%20/ );
		delete $imagefiles{$_} if ( defined $imagefiles{$_} );
	}
	for ( ::natural_sort_alpha( keys %link ) ) {
		unless (    ( defined $anchor{$_} )
				 || ( defined $id{$_} )
				 || ( $link{$_} eq $_ ) )
		{
			print $logfile "+#$link{$_}: Internal link without anchor\n";
			$count++;
		}
	}
	my $externflag;
	for ( ::natural_sort_alpha( keys %link ) ) {
		if ( $link{$_} eq $_ ) {
			if ( $_ =~ /:\/\// ) {
				print $logfile "+$link{$_}: External link\n";
			} else {
				my $temp = $_;
				$temp =~ s/^([^#]+).*/$1/;
				unless ( -e $d . $temp ) {
					print $logfile "local file(s) not found!\n"
					  unless $externflag;
					print $logfile "+$link{$_}:\n";
					$externflag++;
				}
			}
		}
	}
	for ( ::natural_sort_alpha( keys %badlink ) ) {
		print $logfile "+$badlink{$_}: Link with bad characters\n";
	}
	print $logfile @warning if @warning;
	print $logfile "";
	if ( keys %imagefiles ) {
		for ( ::natural_sort_alpha( keys %imagefiles ) ) {
			print $logfile "+" . $_ . ": File not used!\n"
			  if ( $_ =~ /\.(png|jpg|gif|bmp)/ );
		}
		print $logfile "";
	}
	print $logfile "Link statistics:\n";
	print $logfile "$anchors named anchors\n";
	print $logfile "$ids unnamed anchors (tag with id attribute)\n";
	print $logfile "$ilinks internal links\n";
	print $logfile "$images image links\n";
	print $logfile "$css CSS style image links\n";
	print $logfile "$elinks external links\n";
	print $logfile "ANCHORS WITHOUT LINKS. - (INFORMATIONAL)\n";

	for ( ::natural_sort_alpha( keys %anchor ) ) {
		unless ( exists $link{$_} ) {
			print $logfile "$anchor{$_}\n";
			$count++;
		}
	}
	print $logfile "$count  anchors without links\n";
	unlink $filename if $filename;
	close $logfile;
}

sub gutcheckview {
	my $textwindow = $::textwindow;
	$textwindow->tagRemove( 'highlight', '1.0', 'end' );
	my $line = $::lglobal{gclistbox}->get('active');
	if ( $line and $::gc{$line} and $line =~ /Line/ ) {
		$textwindow->see('end');
		$textwindow->see( $::gc{$line} );
		$textwindow->markSet( 'insert', $::gc{$line} );

# Highlight pretty close to GC error (2 chars before just in case error is at end of line)
		$textwindow->tagAdd( 'highlight',
							 $::gc{$line} . "- 2c",
							 $::gc{$line} . " lineend" );
		::update_indicators();
	}
}

# Equivalent to gutcheckview for the general errors window
# When user clicks on an error, show the correct place in the main text window
sub errorcheckview {
	my $textwindow = $::textwindow;
	$textwindow->tagRemove( 'highlight', '1.0', 'end' );
	my $line = $::lglobal{errorchecklistbox}->get('active');
	if ( $line =~ /^line/ ) {	# normally line number of error is shown
		$textwindow->see( $::errors{$line} );
		$textwindow->markSet( 'insert', $::errors{$line} );
		::update_indicators();
	} else { 					# some tools output error without line number 
		if ( $line =~ /^\+(.*):/ ) {    # search on text between + and :
			my @savesets = @::sopt;
			::searchoptset( qw/0 x x 0/ );
			::searchfromstartifnew( $1 );
			::searchtext( $1 );
			::searchoptset( @savesets );
			$::top->raise;
		}
	}
	$textwindow->focus;
	$::lglobal{errorcheckpop}->raise;
}


sub gcwindowpopulate {
	my $linesref = shift;
	return unless defined $::lglobal{gcpop};
	my $start = 0;
	my $count = 0;
	$::lglobal{gclistbox}->delete( '0', 'end' );
	foreach my $line ( @{$linesref} ) {
		my $flag = 0;
		next unless defined $::gc{$line};
		for ( 0 .. $#{ $::lglobal{gcarray} } ) {
			next unless ( index( $line, $::lglobal{gcarray}->[$_] ) > 0 );
			$::gsopt[$_] = 0 unless defined $::gsopt[$_];
			$flag = 1 if $::gsopt[$_];
			last;
		}
		next if $flag;
		unless ( $count == 0 and $line =~ /^\s*$/ ) { # Don't add blank line at top
			$start++ unless ( index( $line, 'Line', 0 ) > 0 );
			$count++;
			$::lglobal{gclistbox}->insert( 'end', $line );
		}
	}
	$count -= $start;
	$::lglobal{gclistbox}->insert( $start, "  --> $count queries.", '' );
	$::lglobal{gclistbox}->insert( $start, '' ) unless $start == 0; # Don't add blank line at top
	$::lglobal{gclistbox}->update;

	#$::lglobal{gclistbox}->yview( 'scroll', 1,  'units' );
	#    $::lglobal{gclistbox}->yview( 'scroll', -1, 'units' );
}

sub gcviewopts {
	my $linesref = shift;
	my $top      = $::top;
	my @gsoptions;
	@{ $::lglobal{gcarray} } = (
								 'Asterisk',
								 'Begins with punctuation',
								 'Broken em-dash',
								 'Capital "S"',
								 'Carat character',
								 'CR without LF',
								 'Double punctuation',
								 'endquote missing punctuation',
								 'Extra period',
								 'Forward slash',
								 'HTML symbol',
								 'HTML Tag',
								 'Hyphen at end of line',
								 'Long line',
								 'Mismatched curly brackets',
								 'Mismatched quotes',
								 'Mismatched round brackets',
								 'Mismatched singlequotes',
								 'Mismatched square brackets',
								 'Mismatched underscores',
								 'Missing space',
								 'No CR',
								 'No punctuation at para end',
								 'Non-ASCII character',
								 'Non-ISO-8859 character',
								 'Paragraph starts with lower-case',
								 'Query angled bracket with From',
								 'Query digit in',
								 "Query had\/bad error",
								 "Query he\/be error",
								 "Query hut\/but error",
								 'Query I=exclamation mark',
								 'Query missing paragraph break',
								 'Query possible scanno',
								 'Query punctuation after',
								 'Query single character line',
								 'Query standalone 0',
								 'Query standalone 1',
								 'Query word',
								 'Short line',
								 'Spaced dash',
								 'Spaced doublequote',
								 'Spaced em-dash',
								 'Spaced punctuation',
								 'Spaced quote',
								 'Spaced singlequote',
								 'Tab character',
								 'Tilde character',
								 'Two successive CRs',
								 'Unspaced bracket',
								 'Unspaced quotes',
								 'Wrongspaced quotes',
								 'Wrongspaced singlequotes',
	);
	my $gcrows = int( ( @{ $::lglobal{gcarray} } / 3 ) + .9 );
	if ( defined( $::lglobal{gcviewoptspop} ) ) {
		$::lglobal{gcviewoptspop}->deiconify;
		$::lglobal{gcviewoptspop}->raise;
		$::lglobal{gcviewoptspop}->focus;
	} else {
		$::lglobal{gcviewoptspop} = $top->Toplevel;
		$::lglobal{gcviewoptspop}->title('Bookloupe/Gutcheck View Options');
		my $pframe = $::lglobal{gcviewoptspop}->Frame->pack;
		$pframe->Label( -text => 'Select option to hide that error.', )->pack;
		my $pframe1 = $::lglobal{gcviewoptspop}->Frame->pack;
		my ( $gcrow, $gccol );
		for ( 0 .. $#{ $::lglobal{gcarray} } ) {
			$gccol = int( $_ / $gcrows );
			$gcrow = $_ % $gcrows;
			$gsoptions[$_] =
			  $pframe1->Checkbutton(
							   -variable => \$::gsopt[$_],
							   -command => sub { gcwindowpopulate($linesref) },
							   -selectcolor => $::lglobal{checkcolor},
							   -text        => $::lglobal{gcarray}->[$_],
			  )->grid( -row => $gcrow, -column => $gccol, -sticky => 'nw' );
		}
		my $pframe2 = $::lglobal{gcviewoptspop}->Frame->pack;
		$pframe2->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				for ( 0 .. $#gsoptions ) {
					$gsoptions[$_]->select;
				}
				gcwindowpopulate($linesref);
			},
			-text  => 'Hide All',
			-width => 12
		  )->pack(
				   -side   => 'left',
				   -pady   => 10,
				   -padx   => 2,
				   -anchor => 'n'
		  );
		$pframe2->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				for ( 0 .. $#gsoptions ) {
					$gsoptions[$_]->deselect;
				}
				gcwindowpopulate($linesref);
			},
			-text  => 'See All',
			-width => 12
		  )->pack(
				   -side   => 'left',
				   -pady   => 10,
				   -padx   => 2,
				   -anchor => 'n'
		  );
		if ( $::booklang !~ /^en/ && @::gcviewlang ) {
		  $pframe2->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				for ( 0 .. $#::gcviewlang ) {
					if ( $::gcviewlang[$_] ) {
						$gsoptions[$_]->select;
					} else {
						$gsoptions[$_]->deselect;
					}
				}
				gcwindowpopulate($linesref);
			},
			-text  => "Load View: '$::booklang'",
			-width => 12
		  )->pack(
				   -side   => 'left',
				   -pady   => 10,
				   -padx   => 2,
				   -anchor => 'n'
		  );
		} else {
		$pframe2->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				for ( 0 .. $#gsoptions ) {
					$gsoptions[$_]->toggle;
				}
				gcwindowpopulate($linesref);
			},
			-text  => 'Toggle View',
			-width => 12
		  )->pack(
				   -side   => 'left',
				   -pady   => 10,
				   -padx   => 2,
				   -anchor => 'n'
		  );
		}
		$pframe2->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				for ( 0 .. $#::mygcview ) {
					if ( $::mygcview[$_] ) {
						$gsoptions[$_]->select;
					} else {
						$gsoptions[$_]->deselect;
					}
				}
				gcwindowpopulate($linesref);
			},
			-text  => 'Load My View',
			-width => 12
		  )->pack(
				   -side   => 'left',
				   -pady   => 10,
				   -padx   => 2,
				   -anchor => 'n'
		  );
		$pframe2->Button(
			-activebackground => $::activecolor,
			-command          => sub {
				for ( 0 .. $#::gsopt ) {
					$::mygcview[$_] = $::gsopt[$_];
				}
				::savesettings();
			},
			-text  => 'Save My View',
			-width => 12
		  )->pack(
				   -side   => 'left',
				   -pady   => 10,
				   -padx   => 2,
				   -anchor => 'n'
		  );
		$::lglobal{gcviewoptspop}->resizable( 'no', 'no' );
		::initialize_popup_without_deletebinding('gcviewoptspop');
		$::lglobal{gcviewoptspop}->protocol(
			'WM_DELETE_WINDOW' => sub {
				$::lglobal{gcviewoptspop}->destroy;
				@{ $::lglobal{gcarray} } = ();
				undef $::lglobal{gcviewoptspop};
				unlink 'gutreslts.tmp';    #cat('gutreslts.tmp')
			}
		);
	}
}

sub gcheckpop_up {
	my $top        = $::top;
	my $textwindow = $::textwindow;
	my @gclines;
	my ( $line, $linenum, $colnum, $lincol, $word );
	::hidepagenums();
	if ( $::lglobal{gcpop} ) {
		$::lglobal{gcpop}->deiconify;
		$::lglobal{gclistbox}->delete( '0', 'end' );
	} else {
		$::lglobal{gcpop} = $top->Toplevel;
		$::lglobal{gcpop}->title('Bookloupe/Gutcheck');
		$::lglobal{gcpop}->geometry($::geometryhash{gcpop});
		$::lglobal{gcpop}->transient($top)        if $::stayontop;
		my $ptopframe = $::lglobal{gcpop}->Frame->pack;
		my $opsbutton =
		  $ptopframe->Button(
							  -activebackground => $::activecolor,
							  -command          => sub { ::gutcheck() },
							  -text             => 'Re-run check',
							  -width            => 16
		  )->pack(
				   -side   => 'left',
				   -pady   => 10,
				   -padx   => 80,
				   -anchor => 'n'
		  );
		my $opsbutton2 =
		  $ptopframe->Button(
							  -activebackground => $::activecolor,
							  -command          => sub { gcrunopts() },
							  -text             => 'GC Run Options',
							  -width            => 16
		  )->pack(
				   -side   => 'left',
				   -pady   => 10,
				   -padx   => 2,
				   -anchor => 'n'
		  );
		my $opsbutton3 =
		  $ptopframe->Button(
							  -activebackground => $::activecolor,
							  -command          => sub { gcviewopts( \@gclines ) },
							  -text             => 'GC View Options',
							  -width            => 16
		  )->pack(
				   -side   => 'left',
				   -pady   => 10,
				   -padx   => 2,
				   -anchor => 'n'
		  );
		my $pframe =
		  $::lglobal{gcpop}->Frame->pack( -fill => 'both', -expand => 'both', );
		$::lglobal{gclistbox} =
		  $pframe->Scrolled(
							 'Listbox',
							 -scrollbars  => 'se',
							 -background  => $::bkgcolor,
							 -font        => $::lglobal{font},
							 -selectmode  => 'single',
							 -activestyle => 'none',
		  )->pack(
				   -anchor => 'nw',
				   -fill   => 'both',
				   -expand => 'both',
				   -padx   => 2,
				   -pady   => 2
		  );
		::drag( $::lglobal{gclistbox} );
		$::lglobal{gcpop}->protocol(
			'WM_DELETE_WINDOW' => sub {
				$::lglobal{gcviewoptspop}->iconify if defined $::lglobal{gcviewoptspop};
				$::lglobal{gcpop}->destroy;
				undef $::lglobal{gcpop};
				$textwindow->markUnset($_) for values %::gc;
				unlink 'gutreslts.tmp';
			}
		);
		$::lglobal{gcpop}->Icon( -image => $::icon );
		::BindMouseWheel( $::lglobal{gclistbox} );
		$::lglobal{gclistbox}
		  ->eventAdd( '<<view>>' => '<Button-1>', '<Return>' );
		$::lglobal{gclistbox}->bind( '<<view>>', sub { gutcheckview() } );
		$::lglobal{gcpop}->bind(
			'<Configure>' => sub {
				$::lglobal{gcpop}->XEvent;
				$::geometryhash{gcpop} = $::lglobal{gcpop}->geometry;
				$::lglobal{geometryupdate} = 1;
			}
		);
		$::lglobal{gclistbox}->eventAdd( '<<remove>>' => '<ButtonRelease-2>',
										 '<ButtonRelease-3>' );
		$::lglobal{gclistbox}->bind(
			'<<remove>>',
			sub {
				$::lglobal{gclistbox}->activate(
									   $::lglobal{gclistbox}->index(
										   '@'
											 . (
											   $::lglobal{gclistbox}->pointerx -
												 $::lglobal{gclistbox}->rootx
											 )
											 . ','
											 . (
											   $::lglobal{gclistbox}->pointery -
												 $::lglobal{gclistbox}->rooty
											 )
									   )
				);
				$textwindow->markUnset(
								$::gc{ $::lglobal{gclistbox}->get('active') } );
				undef $::gc{ $::lglobal{gclistbox}->get('active') };
				$::lglobal{gclistbox}->delete('active');
				$::lglobal{gclistbox}->selectionClear( '0', 'end' );
				$::lglobal{gclistbox}->selectionSet('active');
				gutcheckview();
				$::lglobal{gclistbox}->after( $::lglobal{delay} );
			}
		);
		$::lglobal{gclistbox}->bind(
			'<Button-3>',
			sub {
				$::lglobal{gclistbox}->activate(
									   $::lglobal{gclistbox}->index(
										   '@'
											 . (
											   $::lglobal{gclistbox}->pointerx -
												 $::lglobal{gclistbox}->rootx
											 )
											 . ','
											 . (
											   $::lglobal{gclistbox}->pointery -
												 $::lglobal{gclistbox}->rooty
											 )
									   )
				);
			}
		);
	}
	$::lglobal{gclistbox}->focus;
	my $results;
	unless ( open $results, '<', 'gutrslts.tmp' ) {
		my $dialog = $top->Dialog(
			   -text =>
				 'Could not read results file. Problem with Bookloupe/Gutcheck.',
			   -bitmap  => 'question',
			   -title   => 'Bookloupe/Gutcheck problem',
			   -buttons => [qw/OK/],
		);
		$dialog->Show;
		return;
	}
	my $mark = 0;
	%::gc    = ();
	@gclines = ();
	my $countblank = 0; # number of blank lines
	while ( $line = <$results> ) {
		$line =~ s/^\s//g;
		chomp $line;
		# distinguish blank lines by setting them to varying numbers
		# of spaces, otherwise if user deletes one, it deletes them all
		$line = ' ' x ++$countblank if ( $line eq '' );
		$line =~ s/^(File: )gutchk.tmp/$1$::lglobal{global_filename}/g;
		{
			no warnings 'uninitialized';
			next if $line eq $gclines[-1];
		}
		push @gclines, $line;
		$::gc{$line} = '';
		$colnum      = '0';
		$lincol      = '';
		if ( $line =~ /Line (\d+)/ ) {
			$linenum = $1;
			if ( $line =~ /Line \d+ column (\d+)/ ) {
				$colnum = $1;
				$colnum--
				  unless ( $line =~ /Long|Short|digit|space|bracket\?/ );
				my $tempvar =
				  $textwindow->get( "$linenum.0", "$linenum.$colnum" );
				while ( $tempvar =~ s/<[ib]>// ) {
					$tempvar .= $textwindow->get( "$linenum.$colnum",
												  "$linenum.$colnum +3c" );
					$colnum += 3;
				}
				while ( $tempvar =~ s/<\/[ib]>// ) {
					$tempvar .= $textwindow->get( "$linenum.$colnum",
												  "$linenum.$colnum +4c" );
					$colnum += 4;
				}
			} else {
				if ( $line =~ /Query digit in ([\w\d]+)/ ) {
					$word   = $1;
					$lincol = $textwindow->search( '--', $word, "$linenum.0",
												   "$linenum.0 +1l" );
				}
				if ( $line =~ /Query standalone (\d)/ ) {
					$word = '(?<=\D)' . $1 . '(?=\D)';
					$lincol =
					  $textwindow->search( '-regexp', '--', $word, "$linenum.0",
										   "$linenum.0 +1l" );
				}
				if ( $line =~ /Asterisk?/ ) {
					$lincol = $textwindow->search( '--', '*', "$linenum.0",
												   "$linenum.0 +1l" );
				}
				if ( $line =~ /Hyphen at end of line?/ ) {
					$lincol =
					  $textwindow->search(
										   '-regexp', '--',
										   '-$',      "$linenum.0",
										   "$linenum.0 +1l"
					  );
				}
				if ( $line =~ /Non-ASCII character (\d+)/ ) {
					$word   = chr($1);
					$lincol = $textwindow->search( $word, "$linenum.0",
												   "$linenum.0 +1l" );
				}
				if ( $line =~ /dash\?/ ) {
					$lincol =
					  $textwindow->search(
										   '-regexp',       '--',
										   '-- | --| -|- ', "$linenum.0",
										   "$linenum.0 +1l"
					  );
				}
				if ( $line =~ /HTML symbol/ ) {
					$lincol =
					  $textwindow->search(
										   '-regexp', '--',
										   '&',       "$linenum.0",
										   "$linenum.0 +1l"
					  );
				}
				if ( $line =~ /HTML Tag/ ) {
					$lincol =
					  $textwindow->search(
										   '-regexp', '--',
										   '<',       "$linenum.0",
										   "$linenum.0 +1l"
					  );
				}
				if ( $line =~ /Query word ([\p{Alnum}']+)/ ) {
					$word = $1;
					if ( $word =~ /[\xA0-\xFF]/ ) {
						$lincol =
						  $textwindow->search( '-regexp', '--',
									 '(?<!\p{Alnum})' . $word . '(?!\p{Alnum})',
									 "$linenum.0", "$linenum.0 +1l" );
					} elsif ( $word eq 'i' ) {
						$lincol =
						  $textwindow->search(
										   '-regexp',              '--',
										   ' ' . $word . '[^a-z]', "$linenum.0",
										   "$linenum.0 +1l"
						  );
						$lincol =
						  $textwindow->search( '-regexp', '--',
									'[^A-Za-z0-9<\/]' . $word . '[^A-Za-z0-9>]',
									"$linenum.0", "$linenum.0 +1l" )
						  unless $lincol;
						$lincol = $textwindow->index("$lincol +1c")
						  if ($lincol);
					} else {
						$lincol =
						  $textwindow->search(
											  '-regexp',           '--',
											  '\b' . $word . '\b', "$linenum.0",
											  "$linenum.0 +1l"
						  );
					}
				}
				if ( $line =~ /Query had\/bad/ ) {
					$lincol =
					  $textwindow->search(
										   '-regexp',       '--',
										   '(?<= )[bh]ad\W', "$linenum.0",
										   "$linenum.0 +1l"
					  );
				}
				if ( $line =~ /Query he\/be/ ) {
					$lincol =
					  $textwindow->search(
										   '-regexp',       '--',
										   '(?<= )[bh]e\W', "$linenum.0",
										   "$linenum.0 +1l"
					  );
				}
				if ( $line =~ /Query hut\/but/ ) {
					$lincol =
					  $textwindow->search(
										   '-regexp',        '--',
										   '(?<= )[bh]ut\W', "$linenum.0",
										   "$linenum.0 +1l"
					  );
				}
			}
			$mark++;
			if ($lincol) {
				$textwindow->markSet( "g$mark", $lincol );
			} else {
				$colnum = '0' unless $colnum;
				$textwindow->markSet( "g$mark", "$linenum.$colnum" );
			}
			$::gc{$line} = "g$mark";
		}
	}
	close $results;
	unlink 'gutrslts.tmp';
	gcwindowpopulate( \@gclines );
}

sub jeebiesrun {
	my $listbox    = shift;
	my $top        = $::top;
	my $textwindow = $::textwindow;
	$listbox->delete( '0', 'end' );
	::savefile() if ( $textwindow->numberChanges );
	my $title = ::os_normal( $::lglobal{global_filename} );
	unless ( $::jeebiescommand ) {
		::locateExecutable('Jeebies', \$::jeebiescommand);
		return unless $::jeebiescommand;
	}
	my $jeebiesoptions = "-$::jeebiesmode" . 'e';
	$::jeebiescommand = ::os_normal($::jeebiescommand);
	%::jeeb           = ();
	my $mark = 0;
	$top->Busy( -recurse => 1 );
	$listbox->insert( 'end',
				 '---------------- Please wait: Processing. ----------------' );
	$listbox->update;
	my $runner = runner::tofile('results.tmp');
	$runner->run( $::jeebiescommand, $jeebiesoptions, $title );

	if ( not $? ) {
		open my $fh, '<', 'results.tmp';
		while ( my $line = <$fh> ) {
			$line =~ s/\n//;
			$line =~ s/^\s+/  /;
			if ($line) {
				$::jeeb{$line} = '';
				my ( $linenum, $colnum );
				$linenum = $1 if ( $line =~ /Line (\d+)/ );
				$colnum  = $1 if ( $line =~ /Line \d+ column (\d+)/ );
				$mark++ if $linenum;
				$textwindow->markSet( "j$mark", "$linenum.$colnum" )
				  if $linenum;
				$::jeeb{$line} = "j$mark";
				$listbox->insert( 'end', $line );
			}
		}
	} else {
		warn "Unable to run Jeebies. $!";
	}
	unlink 'results.tmp';
	$listbox->delete('0');
	$listbox->insert( 2, "  --> $mark queries." );
	$top->Unbusy( -recurse => 1 );
}

sub jeebiesview {
	my $textwindow = $::textwindow;
	$textwindow->tagRemove( 'highlight', '1.0', 'end' );
	my $line = $::lglobal{jelistbox}->get('active');
	return unless $line;
	if ( $line =~ /Line/ ) {
		$textwindow->see('end');
		$textwindow->see( $::jeeb{$line} );
		$textwindow->markSet( 'insert', $::jeeb{$line} );
		::update_indicators();
	}
	$textwindow->focus;
	$::lglobal{jeepop}->raise;
	$::geometryhash{jeepop} = $::lglobal{jeepop}->geometry;
}

## Gutcheck
sub gutcheck {
	my $textwindow = $::textwindow;
	my $top        = $::top;
	no warnings;
	::operationadd('Bookloupe/Gutcheck' );
	::hidepagenums();
	my ( $name, $path, $extension, @path );
	$textwindow->focus;
	::update_indicators();
	my $title = $top->cget('title');

	if ( $title =~ /No File Loaded/ ) {
		::nofileloadedwarning();
		return;
	}

	#$top->Busy( -recurse => 1 );
	
	# Bookloupe is utf-8 friendly, but if still using gutcheck, revert to "bytes" encoding
	my $encoding = ">:encoding(UTF-8)";
	if ( $::gutcommand and ::basename($::gutcommand) =~ /gutcheck/ ) {
		$encoding = ">:bytes";
	}
	if ( open my $gc, $encoding, 'gutchk.tmp' ) {
		my $count = 0;
		my $index = '1.0';
		my ($lines) = $textwindow->index('end - 1c') =~ /^(\d+)\./;
		while ( $textwindow->compare( $index, '<', 'end' ) ) {
			my $end = $textwindow->index("$index  lineend +1c");
			print $gc $textwindow->get( $index, $end );
			$index = $end;
		}
		close $gc;
	} else {
		warn "Could not open temp file for writing. $!";
		my $dialog = $top->Dialog(
				-text => 'Could not write to the '
				  . cwd()
				  . ' directory. Check for write permission or space problems.',
				-bitmap  => 'question',
				-title   => 'Bookloupe/Gutcheck problem',
				-buttons => [qw/OK/],
		);
		$dialog->Show;
		return;
	}
	$title =~ s/$::window_title - //
	  ;    #FIXME: sub this out; this and next in the tidy code
	$title =~ s/edited - //;
	$title = ::os_normal($title);
	( $name, $path, $extension ) = ::fileparse( $title, '\.[^\.]*$' );
	unless ( $::gutcommand ) {
		::locateExecutable('Bookloupe/Gutcheck', \$::gutcommand);
		return unless $::gutcommand;
	}
	my $gutcheckoptions = '-ey'
	  ;    # e - echo queried line. y - puts errors to stdout instead of stderr.
	if ( $::gcopt[0] ) { $gutcheckoptions .= 't' }
	;      # Check common typos
	if ( $::gcopt[1] ) { $gutcheckoptions .= 'x' }
	;      # "Trust no one" Paranoid mode. Queries everything
	if ( $::gcopt[2] ) { $gutcheckoptions .= 'p' }
	;      # Require closure of quotes on every paragraph
	if ( $::gcopt[3] ) { $gutcheckoptions .= 's' }
	;      # Force checking for matched pairs of single quotes
	if ( $::gcopt[4] ) { $gutcheckoptions .= 'm' }
	;      # Ignore markup in < >
	if ( $::gcopt[5] ) { $gutcheckoptions .= 'l' }
	;      # Line end checking - defaults on
	if ( $::gcopt[6] ) { $gutcheckoptions .= 'v' }
	;      # Verbose - list EVERYTHING!
	if ( $::gcopt[7] ) { $gutcheckoptions .= 'u' }
	;      # Use file of User-defined Typos
	if ( $::gcopt[8] ) { $gutcheckoptions .= 'd' }
	;      # Ignore DP style page separators
	$::gutcommand = ::os_normal($::gutcommand);
	::savesettings();

	if ( $::lglobal{gcpop} ) {
		$::lglobal{gclistbox}->delete( '0', 'end' );
	}
	my $runner = ::runner::tofile('gutrslts.tmp');
	$runner->run( $::gutcommand, $gutcheckoptions, 'gutchk.tmp' );

	#$top->Unbusy;
	unlink 'gutchk.tmp';
	gcheckpop_up();
}

sub gcrunopts {
	my $textwindow = $::textwindow;
	my $top        = $::top;
	$::lglobal{gcrunoptspop} =
	  $top->DialogBox( -title => 'Bookloupe/Gutcheck Run Options', -buttons => ['OK'] );
	my $gcopt6 =
	  $::lglobal{gcrunoptspop}->add(
							   'Checkbutton',
							   -variable    => \$::gcopt[6],
							   -selectcolor => $::lglobal{checkcolor},
							   -text => '-v Enable verbose mode (Recommended).',
	  )->pack( -side => 'top', -anchor => 'nw', -padx => 5 );
	my $gcopt0 =
	  $::lglobal{gcrunoptspop}->add(
								 'Checkbutton',
								 -variable    => \$::gcopt[0],
								 -selectcolor => $::lglobal{checkcolor},
								 -text => '-t Disable check for common typos.',
	  )->pack( -side => 'top', -anchor => 'nw', -padx => 5 );
	my $gcopt1 =
	  $::lglobal{gcrunoptspop}->add(
								 'Checkbutton',
								 -variable    => \$::gcopt[1],
								 -selectcolor => $::lglobal{checkcolor},
								 -text        => '-x Disable paranoid mode.',
	  )->pack( -side => 'top', -anchor => 'nw', -padx => 5 );
	my $gcopt2 =
	  $::lglobal{gcrunoptspop}->add(
							 'Checkbutton',
							 -variable    => \$::gcopt[2],
							 -selectcolor => $::lglobal{checkcolor},
							 -text => '-p Report ALL unbalanced double quotes.',
	  )->pack( -side => 'top', -anchor => 'nw', -padx => 5 );
	my $gcopt3 =
	  $::lglobal{gcrunoptspop}->add(
							 'Checkbutton',
							 -variable    => \$::gcopt[3],
							 -selectcolor => $::lglobal{checkcolor},
							 -text => '-s Report ALL unbalanced single quotes.',
	  )->pack( -side => 'top', -anchor => 'nw', -padx => 5 );
	my $gcopt4 =
	  $::lglobal{gcrunoptspop}->add(
								 'Checkbutton',
								 -variable    => \$::gcopt[4],
								 -selectcolor => $::lglobal{checkcolor},
								 -text        => '-m Interpret HTML markup.',
	  )->pack( -side => 'top', -anchor => 'nw', -padx => 5 );
	my $gcopt5 =
	  $::lglobal{gcrunoptspop}->add(
								 'Checkbutton',
								 -variable    => \$::gcopt[5],
								 -selectcolor => $::lglobal{checkcolor},
								 -text => '-l Do not report non DOS newlines.',
	  )->pack( -side => 'top', -anchor => 'nw', -padx => 5 );
	my $gcopt7 =
	  $::lglobal{gcrunoptspop}->add(
								 'Checkbutton',
								 -variable    => \$::gcopt[7],
								 -selectcolor => $::lglobal{checkcolor},
								 -text => '-u Flag words from the .typ file.',
	  )->pack( -side => 'top', -anchor => 'nw', -padx => 5 );
	my $gcopt8 =
	  $::lglobal{gcrunoptspop}->add(
								 'Checkbutton',
								 -variable    => \$::gcopt[8],
								 -selectcolor => $::lglobal{checkcolor},
								 -text => '-d Ignore DP style page separators.',
	  )->pack( -side => 'top', -anchor => 'nw', -padx => 5 );
	::initialize_popup_without_deletebinding('gcrunoptspop');
	$::lglobal{gcrunoptspop}->Show;
	::savesettings();
}

sub jeebiespop_up {
	my $textwindow = $::textwindow;
	my $top        = $::top;
	my @jlines;
	::hidepagenums();
	if ( $::lglobal{jeepop} ) {
		$::lglobal{jeepop}->deiconify;
	} else {
		$::lglobal{jeepop} = $top->Toplevel;
		$::lglobal{jeepop}->title('Jeebies');
		::initialize_popup_with_deletebinding('jeepop');
		my $ptopframe = $::lglobal{jeepop}->Frame->pack;
		$ptopframe->Label( -text => 'Search mode:', )
		  ->pack( -side => 'left', -padx => 2 );
		my %rbutton = ( 'Paranoid', 'p', 'Normal', '', 'Tolerant', 't' );
		for ( keys %rbutton ) {
			$ptopframe->Radiobutton(
									 -text     => $_,
									 -variable => \$::jeebiesmode,
									 -value    => $rbutton{$_},
									 -command  => \&saveset,
			)->pack( -side => 'left', -padx => 2 );
		}
		$ptopframe->Button(
						-activebackground => $::activecolor,
						-command => sub { jeebiesrun( $::lglobal{jelistbox} ) },
						-text    => 'Re-run Jeebies',
						-width   => 16
		  )->pack(
				   -side   => 'left',
				   -pady   => 10,
				   -padx   => 2,
				   -anchor => 'n'
		  );
		my $pframe =
		  $::lglobal{jeepop}
		  ->Frame->pack( -fill => 'both', -expand => 'both', );
		$::lglobal{jelistbox} =
		  $pframe->Scrolled(
							 'Listbox',
							 -scrollbars  => 'se',
							 -background  => $::bkgcolor,
							 -font        => $::lglobal{font},
							 -selectmode  => 'single',
							 -activestyle => 'none',
		  )->pack(
				   -anchor => 'nw',
				   -fill   => 'both',
				   -expand => 'both',
				   -padx   => 2,
				   -pady   => 2
		  );
		::drag( $::lglobal{jelistbox} );
		::BindMouseWheel( $::lglobal{jelistbox} );
		$::lglobal{jelistbox}
		  ->eventAdd( '<<jview>>' => '<Button-1>', '<Return>' );
		$::lglobal{jelistbox}->bind( '<<jview>>', sub { jeebiesview() } );
		$::lglobal{jelistbox}->eventAdd( '<<jremove>>' => '<ButtonRelease-2>',
										 '<ButtonRelease-3>' );
		$::lglobal{jelistbox}->bind(
			'<<jremove>>',
			sub {
				$::lglobal{jelistbox}->activate(
									   $::lglobal{jelistbox}->index(
										   '@'
											 . (
											   $::lglobal{jelistbox}->pointerx -
												 $::lglobal{jelistbox}->rootx
											 )
											 . ','
											 . (
											   $::lglobal{jelistbox}->pointery -
												 $::lglobal{jelistbox}->rooty
											 )
									   )
				);
				undef $::gc{ $::lglobal{jelistbox}->get('active') };
				$::lglobal{jelistbox}->delete('active');
				jeebiesview();
				$::lglobal{jelistbox}->selectionClear( '0', 'end' );
				$::lglobal{jelistbox}->selectionSet('active');
				$::lglobal{jelistbox}->after( $::lglobal{delay} );
			}
		);
		jeebiesrun( $::lglobal{jelistbox} );
	}
}
1;
