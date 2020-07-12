#!/usr/bin/env perl

my @modules = (
    # Required modules
    "LWP::UserAgent",
    "Tk",
    "Tk::ToolBar",
    # Optional but recommended modules
    "Text::LevenshteinXS",
    "File::Which",
    "Image::Size",
    # Needed for update checking
    "LWP::Protocol::https",
    # Needed for remote HTML validation
    "WebService::Validator::HTML::W3C",
    "XML::XPath",
);

foreach my $module (@modules) {
    system("cpanm --notest --install $module") == 0
        or die("Failed trying to install $module\n");
}