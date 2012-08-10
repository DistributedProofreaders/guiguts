package Guiguts::HelpMenu;
use strict;
use warnings;

BEGIN {
	use Exporter();
	our ( @ISA, @EXPORT );
	@ISA    = qw(Exporter);
	@EXPORT = qw( &about_pop_up &hotkeyshelp &regexref );
}

sub about_pop_up {
	my $top        = $::top;
	my $about_text = <<EOM;
Guiguts.pl post processing toolkit/interface to gutcheck.

Provides easy to use interface to gutcheck and an array of
other useful postprocessing functions.

This version produced by a number of volunteers.
See the Thanks.txt file for details.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

Guiguts 1.0 prepared by Hunter Monroe and many others.
Original guiguts written by Stephen Schulze.
Partially based on the Gedi editor - Gregs editor.
Redistributable on the same terms as Perl.
EOM
	if ( defined( $::lglobal{aboutpop} ) ) {
		$::lglobal{aboutpop}->deiconify;
		$::lglobal{aboutpop}->raise;
		$::lglobal{aboutpop}->focus;
	} else {
		$::lglobal{aboutpop} = $top->Toplevel;
		::initialize_popup_with_deletebinding('aboutpop');
		$::lglobal{aboutpop}->title('About');
		$::lglobal{aboutpop}->Label(
									 -justify => "left",
									 -text    => $about_text
		)->pack;
		my $button_ok = $::lglobal{aboutpop}->Button(
			-activebackground => $::activecolor,
			-text             => 'OK',
			-command          => sub {
				$::lglobal{aboutpop}->destroy;
				undef $::lglobal{aboutpop};
			}
		)->pack( -pady => 6 );
		$::lglobal{aboutpop}->resizable( 'no', 'no' );
		$::lglobal{aboutpop}->raise;
		$::lglobal{aboutpop}->focus;
	}
}

sub hotkeyshelp {
	my $top = $::top;
	if ( defined( $::lglobal{hotpop} ) ) {
		$::lglobal{hotpop}->deiconify;
		$::lglobal{hotpop}->raise;
		$::lglobal{hotpop}->focus;
	} else {
		$::lglobal{hotpop} = $top->Toplevel;
		$::lglobal{hotpop}->title('Keyboard Shortcuts');
		my $frame =
		  $::lglobal{hotpop}->Frame->pack(
										   -anchor => 'nw',
										   -expand => 'yes',
										   -fill   => 'both'
		  );
		my $rotextbox =
		  $frame->Scrolled(
							'ROText',
							-scrollbars => 'se',
							-background => $::bkgcolor,
							-font       => $::lglobal{font},
							-width      => 80,
							-height     => 25,
							-wrap       => 'none',
		  )->pack( -anchor => 'nw', -expand => 'yes', -fill => 'both' );
		my $button_ok = $frame->Button(
			-activebackground => $::activecolor,
			-text             => 'Close',
			-command          => sub {
				$::lglobal{hotpop}->destroy;
				undef $::lglobal{hotpop};
			}
		)->pack;
		::initialize_popup_with_deletebinding('hotpop');
		::drag($rotextbox);
		$rotextbox->focus;
		if ( -e 'hotkeys.txt' ) {
			if ( open my $ref, '<', 'hotkeys.txt' ) {
				while (<$ref>) {
					$_ =~ s/\cM\cJ|\cM|\cJ/\n/g;
					$rotextbox->insert( 'end', $_ );
				}
			} else {
				$rotextbox->insert( 'end',
						    'Could not open Hotkeys file - hotkeys.txt.' );
			}
		} else {
			$rotextbox->insert( 'end',
						    'Could not find Hotkeys file - hotkeys.txt.' );
		}
	}
}

sub regexref {
	my $top = $::top;
	if ( defined( $::lglobal{regexrefpop} ) ) {
		$::lglobal{regexrefpop}->deiconify;
		$::lglobal{regexrefpop}->raise;
		$::lglobal{regexrefpop}->focus;
	} else {
		$::lglobal{regexrefpop} = $top->Toplevel;
		$::lglobal{regexrefpop}->title('Regex Quick Reference');
		my $regtext =
		  $::lglobal{regexrefpop}->Scrolled(
			'ROText',
			-scrollbars => 'se',
			-background => $::bkgcolor,
			-font       => $::lglobal{font},
		  )->pack( -anchor => 'n', -expand => 'y', -fill => 'both' );
		my $button_ok = $::lglobal{regexrefpop}->Button(
			-activebackground => $::activecolor,
			-text             => 'Close',
			-command          => sub {
				$::lglobal{regexrefpop}->destroy;
				undef $::lglobal{regexrefpop};
			}
		)->pack;
		::initialize_popup_with_deletebinding('regexrefpop');
		::drag($regtext);
		if ( -e 'regref.txt' ) {
			if ( open my $ref, '<', 'regref.txt' ) {
				while (<$ref>) {
					$_ =~ s/\cM\cJ|\cM|\cJ/\n/g;
					#$_ = eol_convert($_);
					$regtext->insert( 'end', $_ );
				}
			} else {
				$regtext->insert( 'end',
						  'Could not open Regex Reference file - regref.txt.' );
			}
		} else {
			$regtext->insert( 'end',
						  'Could not find Regex Reference file - regref.txt.' );
		}
	}
}

1;
