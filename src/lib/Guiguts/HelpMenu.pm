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
Guiguts post processing toolkit.

Provides an easy to use interface to an array of useful post processing
functions.

This version was produced by a number of volunteers. See THANKS.md for details.

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

Original guiguts written by Stephen Schulze.
Later versions prepared by Hunter Monroe and many others.
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
            -command          => sub { ::killpopup('aboutpop'); }
        )->pack( -pady => 6 );
        $::lglobal{aboutpop}->resizable( 'yes', 'yes' );
        $::lglobal{aboutpop}->raise;
        $::lglobal{aboutpop}->focus;
    }
}

sub hotkeyshelp {
    my $top = $::top;
    if ( defined( $::lglobal{hotkeyspop} ) ) {
        $::lglobal{hotkeyspop}->deiconify;
        $::lglobal{hotkeyspop}->raise;
        $::lglobal{hotkeyspop}->focus;
    } else {
        $::lglobal{hotkeyspop} = $top->Toplevel;
        $::lglobal{hotkeyspop}->title('Keyboard Shortcuts');
        my $frame = $::lglobal{hotkeyspop}->Frame->pack(
            -anchor => 'nw',
            -expand => 'yes',
            -fill   => 'both'
        );
        my $rotextbox = $frame->Scrolled(
            'ROText',
            -scrollbars => 'se',
            -background => $::bkgcolor,
            -font       => 'proofing',
            -width      => 80,
            -height     => 25,
            -wrap       => 'none',
        )->pack( -anchor => 'nw', -expand => 'yes', -fill => 'both' );
        my $button_ok = $frame->Button(
            -activebackground => $::activecolor,
            -text             => 'Close',
            -command          => sub { ::killpopup('hotkeyspop'); }
        )->pack;
        ::initialize_popup_with_deletebinding('hotkeyspop');
        ::drag($rotextbox);
        $rotextbox->focus;

        if ( -e 'hotkeys.txt' ) {
            if ( open my $ref, '<', 'hotkeys.txt' ) {
                while (<$ref>) {
                    $_ =~ s/\cM\cJ|\cM|\cJ/\n/g;
                    $rotextbox->insert( 'end', $_ );
                }
            } else {
                $rotextbox->insert( 'end', 'Could not open Hotkeys file - hotkeys.txt.' );
            }
        } else {
            $rotextbox->insert( 'end', 'Could not find Hotkeys file - hotkeys.txt.' );
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
        my $regtext = $::lglobal{regexrefpop}->Scrolled(
            'ROText',
            -scrollbars => 'se',
            -background => $::bkgcolor,
            -font       => 'proofing',
        )->pack( -anchor => 'n', -expand => 'y', -fill => 'both' );
        my $button_ok = $::lglobal{regexrefpop}->Button(
            -activebackground => $::activecolor,
            -text             => 'Close',
            -command          => sub { ::killpopup('regexrefpop'); }
        )->pack;
        ::initialize_popup_with_deletebinding('regexrefpop');
        ::drag($regtext);
        if ( -e 'regref.txt' ) {
            if ( open my $ref, '<', 'regref.txt' ) {
                while (<$ref>) {
                    $_ =~ s/\cM\cJ|\cM|\cJ/\n/g;
                    $regtext->insert( 'end', $_ );
                }
            } else {
                $regtext->insert( 'end', 'Could not open Regex Reference file - regref.txt.' );
            }
        } else {
            $regtext->insert( 'end', 'Could not find Regex Reference file - regref.txt.' );
        }
    }
}

1;
