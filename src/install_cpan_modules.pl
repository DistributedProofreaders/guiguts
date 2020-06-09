#!/usr/bin/env perl

my @modules = (
    "LWP::UserAgent",
    "Tk",
    "Tk::ToolBar",
);

foreach my $module (@modules) {
    system("cpanm --notest --install $module") == 0
        or die("Failed trying to install $module\n");
}