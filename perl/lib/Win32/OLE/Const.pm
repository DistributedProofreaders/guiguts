# The documentation is at the __END__

package Win32::OLE::Const;

use strict;
use Carp;
use Win32::OLE;

my $Typelibs;
sub _Typelib {
    my ($clsid,$title,$version,$langid,$filename) = @_;
    # Filenames might have a resource index appended to it.
    $filename = $1 if $filename =~ /^(.*\.(?:dll|exe))(\\\d+)$/i;
    # Ignore if it looks like a file but doesn't exist.
    # We don't verify existance of monikers or filenames
    # without a full pathname.
    return unless -f $filename || $filename !~ /^\w:\\.*\.(exe|dll)$/;
    push @$Typelibs, \@_;
}
__PACKAGE__->_Typelibs;

sub import {
    my ($self,$name,$major,$minor,$language,$codepage) = @_;
    return unless defined($name) && $name !~ /^\s*$/;
    $self->Load($name,$major,$minor,$language,$codepage,scalar caller);
}

sub EnumTypeLibs {
    my ($self,$callback) = @_;
    foreach (@$Typelibs) { &$callback(@$_) }
    return;
}

sub Load {
    my ($self,$name,$major,$minor,$language,$codepage,$caller) = @_;

    if (UNIVERSAL::isa($name,'Win32::OLE')) {
	my $typelib = $name->GetTypeInfo->GetContainingTypeLib;
	return _Constants($typelib, undef);
    }

    undef $minor unless defined $major;
    my $typelib = $self->LoadRegTypeLib($name,$major,$minor,
					$language,$codepage);
    return _Constants($typelib, $caller);
}

sub LoadRegTypeLib {
    my ($self,$name,$major,$minor,$language,$codepage) = @_;
    undef $minor unless defined $major;

    unless (defined($name) && $name !~ /^\s*$/) {
	carp "Win32::OLE::Const->Load: No or invalid type library name";
	return;
    }

    my @found;
    foreach my $Typelib (@$Typelibs) {
	my ($clsid,$title,$version,$langid,$filename) = @$Typelib;
	next unless $title =~ /^$name/;
	next unless $version =~ /^([0-9a-fA-F]+)\.([0-9a-fA-F]+)$/;
	my ($maj,$min) = (hex($1), hex($2));
	next if defined($major) && $maj != $major;
	next if defined($minor) && $min < $minor;
	next if defined($language) && $language != $langid;
	push @found, [$clsid,$maj,$min,$langid,$filename];
    }

    unless (@found) {
	carp "No type library matching \"$name\" found";
	return;
    }

    @found = sort {
	# Prefer greater version number
	my $res = $b->[1] <=> $a->[1];
	$res = $b->[2] <=> $a->[2] if $res == 0;
	# Prefer default language for equal version numbers
	$res = -1 if $res == 0 && $a->[3] == 0;
	$res =  1 if $res == 0 && $b->[3] == 0;
	$res;
    } @found;

    #printf "Loading %s\n", join(' ', @{$found[0]});
    return _LoadRegTypeLib(@{$found[0]},$codepage);
}

1;

__END__

