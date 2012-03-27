package Tk::StayOnTop;

our $VERSION = 0.03;

#==============================================================================#

#==============================================================================#

package Tk::Toplevel;

use strict;
use warnings;
use Carp;

my ($win32_winpos,$repeat_id);

if ($^O =~ /Win32/) {

	# Win32 implementation uses setwindowpos() function.
	# See http://msdn.microsoft.com/library/default.asp?url=/library/en-us/winui/winui/windowsuserinterface/windowing/windows/windowreference/windowfunctions/setwindowpos.asp
	#define SWP_NOSIZE          0x0001
	#define SWP_NOMOVE          0x0002
	#define SWP_NOZORDER        0x0004
	#define SWP_NOREDRAW        0x0008
	#define SWP_NOACTIVATE      0x0010
	#define SWP_FRAMECHANGED    0x0020  
	#define SWP_SHOWWINDOW      0x0040
	#define SWP_HIDEWINDOW      0x0080
	#define SWP_NOCOPYBITS      0x0100
	#define SWP_NOOWNERZORDER   0x0200  
	#define SWP_NOSENDCHANGING  0x0400  
	#define SWP_DRAWFRAME       SWP_FRAMECHANGED
	#define SWP_NOREPOSITION    SWP_NOOWNERZORDER
	#if(WINVER >= 0x0400)
	#define SWP_DEFERERASE      0x2000
	#define SWP_ASYNCWINDOWPOS  0x4000
	#endif /* WINVER >= 0x0400 */
	#define HWND_TOP        ((HWND)0)
	#define HWND_BOTTOM     ((HWND)1)
	#define HWND_TOPMOST    ((HWND)-1)
	#define HWND_NOTOPMOST  ((HWND)-2)

	eval "use Win32::API"; croak $@ if $@;
	$win32_winpos = Win32::API->new(
			'user32', 'SetWindowPos',
			['N','N','N','N','N','N','N'], 'N'
	);
}

#==============================================================================#

sub stayOnTop {
	my ($obj) = @_;
	if ($^O =~ /Win32/) {

		$obj->update;
		# HWND_TOPMOST (-1) and SWP_NOSIZE+SWP_NOMOVE (3)
		$win32_winpos->Call(hex($obj->frame()),-1,0,0,0,0,3);

	} else {

		# This is hard in non windows land. Any ideas?

		$obj->deiconify;
		$obj->raise;
	
		$repeat_id = $obj->repeat(250, sub {
			$obj->deiconify;
			$obj->raise;
		}) unless defined $repeat_id;

	}
}

#==============================================================================#

sub dontStayOnTop {
	my ($obj) = @_;

	if ($^O =~ /Win32/) {
		$obj->update;
		# HWND_NOTOPMOST (-2) and SWP_NOSIZE+SWP_NOMOVE (3)
		$win32_winpos->Call(hex($obj->frame()),-2,0,0,0,0,3);
	} else {
		$obj->afterCancel($repeat_id);
		$repeat_id = undef;
	}

}

#==============================================================================#

# That's all folks..
#==============================================================================#
1;
