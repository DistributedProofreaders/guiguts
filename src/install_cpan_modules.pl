#!/usr/bin/env perl

my @modules = (

    # Needed for locating tools
    "File::HomeDir",

    # Needed for user interface
    "Tk",
    "Tk::ToolBar",

    # Needed for word frequency harmonics
    "Text::LevenshteinXS",

    # Needed to check if a tool is on the path
    "File::Which",

    # Needed to determine the dimensions of images for HTML
    "Image::Size",

    # Needed for update checking
    "LWP::UserAgent",
);

# Windows-specific modules
if ( $^O eq 'MSWin32' ) {
    push @modules, "Win32::Unicode::Process";
}

# Command to use to run cpanm, default to the command directly
$cpanm = "cpanm";

# On Mac, we want to run cpanm with the version of perl on the path -- which
# should be the homebrew-installed version -- not whatever version cpanm is
# pointing to which might be the one that came with macOS.
if ( $^O eq 'darwin' ) {

    # Intel
    if ( -e "/usr/local/bin/cpanm" ) {
        $cpanm = "perl /usr/local/bin/cpanm";
    }

    # Apple Silicon
    elsif ( -e "/opt/homebrew/bin/cpanm" ) {
        $cpanm = "perl /opt/homebrew/bin/cpanm";
    }

    # fall-through to using cpanm directly
}

foreach my $module (@modules) {
    system("$cpanm --notest $module") == 0
      or die("Failed trying to install $module\n");
}
