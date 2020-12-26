#!/usr/bin/env perl

my @modules = (

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

    # Needed for remote HTML validation
    "WebService::Validator::HTML::W3C",
    "XML::XPath",
);

foreach my $module (@modules) {
    system("cpanm --notest $module") == 0
      or die("Failed trying to install $module\n");
}
