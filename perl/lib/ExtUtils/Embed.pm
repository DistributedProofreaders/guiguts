# $Id: Embed.pm,v 1.1.1.1 2002/01/16 19:27:19 schwern Exp $
require 5.002;

package ExtUtils::Embed;
require Exporter;
require FileHandle;
use Config;
use Getopt::Std;
use File::Spec;

#Only when we need them
#require ExtUtils::MakeMaker;
#require ExtUtils::Liblist;

use vars qw(@ISA @EXPORT $VERSION
	    @Extensions $Verbose $lib_ext
	    $opt_o $opt_s 
	    );
use strict;

$VERSION = 1.2506_01;

@ISA = qw(Exporter);
@EXPORT = qw(&xsinit &ldopts 
	     &ccopts &ccflags &ccdlflags &perl_inc
	     &xsi_header &xsi_protos &xsi_body);

#let's have Miniperl borrow from us instead
#require ExtUtils::Miniperl;
#*canon = \&ExtUtils::Miniperl::canon;

$Verbose = 0;
$lib_ext = $Config{lib_ext} || '.a';

sub is_cmd { $0 eq '-e' }

sub my_return {
    my $val = shift;
    if(is_cmd) {
	print $val;
    }
    else {
	return $val;
    }
}

sub xsinit { 
    my($file, $std, $mods) = @_;
    my($fh,@mods,%seen);
    $file ||= "perlxsi.c";
    my $xsinit_proto = "pTHX";

    if (@_) {
       @mods = @$mods if $mods;
    }
    else {
       getopts('o:s:');
       $file = $opt_o if defined $opt_o;
       $std  = $opt_s  if defined $opt_s;
       @mods = @ARGV;
    }
    $std = 1 unless scalar @mods;

    if ($file eq "STDOUT") {
	$fh = \*STDOUT;
    }
    else {
	$fh = new FileHandle "> $file";
    }

    push(@mods, static_ext()) if defined $std;
    @mods = grep(!$seen{$_}++, @mods);

    print $fh &xsi_header();
    print $fh "EXTERN_C void xs_init ($xsinit_proto);\n\n";     
    print $fh &xsi_protos(@mods);

    print $fh "\nEXTERN_C void\nxs_init($xsinit_proto)\n{\n";
    print $fh &xsi_body(@mods);
    print $fh "}\n";

}

sub xsi_header {
    return <<EOF;
#include <EXTERN.h>
#include <perl.h>

EOF
}    

sub xsi_protos {
    my(@exts) = @_;
    my(@retval,%seen);
    my $boot_proto = "pTHX_ CV* cv";
    foreach $_ (@exts){
        my($pname) = canon('/', $_);
        my($mname, $cname);
        ($mname = $pname) =~ s!/!::!g;
        ($cname = $pname) =~ s!/!__!g;
	my($ccode) = "EXTERN_C void boot_${cname} ($boot_proto);\n";
	next if $seen{$ccode}++;
        push(@retval, $ccode);
    }
    return join '', @retval;
}

sub xsi_body {
    my(@exts) = @_;
    my($pname,@retval,%seen);
    my($dl) = canon('/','DynaLoader');
    push(@retval, "\tchar *file = __FILE__;\n");
    push(@retval, "\tdXSUB_SYS;\n") if $] > 5.002;
    push(@retval, "\n");

    foreach $_ (@exts){
        my($pname) = canon('/', $_);
        my($mname, $cname, $ccode);
        ($mname = $pname) =~ s!/!::!g;
        ($cname = $pname) =~ s!/!__!g;
        if ($pname eq $dl){
            # Must NOT install 'DynaLoader::boot_DynaLoader' as 'bootstrap'!
            # boot_DynaLoader is called directly in DynaLoader.pm
            $ccode = "\t/* DynaLoader is a special case */\n\tnewXS(\"${mname}::boot_${cname}\", boot_${cname}, file);\n";
            push(@retval, $ccode) unless $seen{$ccode}++;
        } else {
            $ccode = "\tnewXS(\"${mname}::bootstrap\", boot_${cname}, file);\n";
            push(@retval, $ccode) unless $seen{$ccode}++;
        }
    }
    return join '', @retval;
}

sub static_ext {
    unless (scalar @Extensions) {
	@Extensions = sort split /\s+/, $Config{static_ext};
	unshift @Extensions, qw(DynaLoader);
    }
    @Extensions;
}

sub _escape {
    my $arg = shift;
    $$arg =~ s/([\(\)])/\\$1/g;
}

sub _ldflags {
    my $ldflags = $Config{ldflags};
    _escape(\$ldflags);
    return $ldflags;
}

sub _ccflags {
    my $ccflags = $Config{ccflags};
    _escape(\$ccflags);
    return $ccflags;
}

sub _ccdlflags {
    my $ccdlflags = $Config{ccdlflags};
    _escape(\$ccdlflags);
    return $ccdlflags;
}

sub ldopts {
    require ExtUtils::MakeMaker;
    require ExtUtils::Liblist;
    my($std,$mods,$link_args,$path) = @_;
    my(@mods,@link_args,@argv);
    my($dllib,$config_libs,@potential_libs,@path);
    local($") = ' ' unless $" eq ' ';
    if (scalar @_) {
       @link_args = @$link_args if $link_args;
       @mods = @$mods if $mods;
    }
    else {
       @argv = @ARGV;
       #hmm
       while($_ = shift @argv) {
	   /^-std$/  && do { $std = 1; next; };
	   /^--$/    && do { @link_args = @argv; last; };
	   /^-I(.*)/ && do { $path = $1 || shift @argv; next; };
	   push(@mods, $_); 
       }
    }
    $std = 1 unless scalar @link_args;
    my $sep = $Config{path_sep} || ':';
    @path = $path ? split(/\Q$sep/, $path) : @INC;

    push(@potential_libs, @link_args)    if scalar @link_args;
    # makemaker includes std libs on windows by default
    if ($^O ne 'MSWin32' and defined($std)) {
	push(@potential_libs, $Config{perllibs});
    }

    push(@mods, static_ext()) if $std;

    my($mod,@ns,$root,$sub,$extra,$archive,@archives);
    print STDERR "Searching (@path) for archives\n" if $Verbose;
    foreach $mod (@mods) {
	@ns = split(/::|\/|\\/, $mod);
	$sub = $ns[-1];
	$root = File::Spec->catdir(@ns);
	
	print STDERR "searching for '$sub${lib_ext}'\n" if $Verbose;
	foreach (@path) {
	    next unless -e ($archive = File::Spec->catdir($_,"auto",$root,"$sub$lib_ext"));
	    push @archives, $archive;
	    if(-e ($extra = File::Spec->catdir($_,"auto",$root,"extralibs.ld"))) {
		local(*FH); 
		if(open(FH, $extra)) {
		    my($libs) = <FH>; chomp $libs;
		    push @potential_libs, split /\s+/, $libs;
		}
		else {  
		    warn "Couldn't open '$extra'"; 
		}
	    }
	    last;
	}
    }
    #print STDERR "\@potential_libs = @potential_libs\n";

    my $libperl;
    if ($^O eq 'MSWin32') {
	$libperl = $Config{libperl};
    }
    else {
	$libperl = (grep(/^-l\w*perl\w*$/, @link_args))[0] || "-lperl";
    }

    my $lpath = File::Spec->catdir($Config{archlibexp}, 'CORE');
    $lpath = qq["$lpath"] if $^O eq 'MSWin32';
    my($extralibs, $bsloadlibs, $ldloadlibs, $ld_run_path) =
	MM->ext(join ' ', "-L$lpath", $libperl, @potential_libs);

    my $ld_or_bs = $bsloadlibs || $ldloadlibs;
    print STDERR "bs: $bsloadlibs ** ld: $ldloadlibs" if $Verbose;
    my $ccdlflags = _ccdlflags();
    my $ldflags   = _ldflags();
    my $linkage = "$ccdlflags $ldflags @archives $ld_or_bs";
    print STDERR "ldopts: '$linkage'\n" if $Verbose;

    return $linkage if scalar @_;
    my_return("$linkage\n");
}

sub ccflags {
    my $ccflags = _ccflags();
    my_return(" $ccflags ");
}

sub ccdlflags {
    my $ccdlflags = _ccdlflags();
    my_return(" $ccdlflags ");
}

sub perl_inc {
    my $dir = File::Spec->catdir($Config{archlibexp}, 'CORE');
    $dir = qq["$dir"] if $^O eq 'MSWin32';
    my_return(" -I$dir ");
}

sub ccopts {
   ccflags . perl_inc;
}

sub canon {
    my($as, @ext) = @_;
    foreach(@ext) {
       # might be X::Y or lib/auto/X/Y/Y.a
       next if s!::!/!g;
       s:^(lib|ext)/(auto/)?::;
       s:/\w+\.\w+$::;
    }
    grep(s:/:$as:, @ext) if ($as ne '/');
    @ext;
}

__END__

