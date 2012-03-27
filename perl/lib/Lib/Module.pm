package Lib::Module;
# $Id: Module.pm,v 1.9 2004/03/21 00:15:26 kiesling Exp $
$VERSION=0.68;
use vars qw( @ISA @EXPORT @EXPORT_OK $VERSION );
push @ISA, qw(Exporter);

@EXPORT_OK = qw($VERSION &libdirs &module_paths &scanlibs &retrieve 
		&pathname &usesTk);

require Exporter;
require Carp;
use File::Basename;
use Lib::ModuleSymbol;
use Lib::SymbolRef;
use IO::Handle;
use DB;

my @modulepathnames;
my @libdirectories;

sub new {
    my $proto = shift;
    my $class = ref( $proto ) || $proto;
    my $self = {
	children => [],
	parents => '',
	pathname => '',
	basename => '',
	packagename => '',
	version => '',
	superclasses => undef,  
	baseclass => '',
	moduleinfo => undef,
	symbols => []
	};
    bless( $self, $class);
    return $self;
}

# Given a file base name, return the Module object.
no warnings;
sub retrieve {
    my $parent = shift;
    my ($n) = @_;
    if ( $parent -> {basename}  =~ /^$n/  || $_ -> {packagename} =~ /^$n/) { 
	return $parent; }
    foreach ( @{$parent -> {children}} ) {
	if ( $_ -> {basename} =~ /^$n/ || $_ -> {packagename} =~ /^$n/) {
	    return $_;
	}
    } 
    foreach ( @{$parent -> {children}}  || $_ -> {packagename} =~ /^$n/) {
	if ( retrieve( $_, $n ) ) { 
	    return $_; }
    }
    return undef;
}
use warnings;

sub pathname {
    my $self = shift;
    my $name = $_[0];
    my $verbose = $_[1];
    autoflush STDOUT 1 if $verbose;
    if ($self -> {basename} =~ /^$name/ || $self->{packagename} =~ /^$name/) { 
	return $self -> {pathname}; }
    foreach ( @{$self -> {children}} ) {
      print '.' if $verbose;
	if ($_ -> {basename} =~ /^$name/ || $self->{packagename} =~ /^$name/) {
	    return $_ -> {pathname};
	}
    } 
    foreach ( @{$self -> {children}} ) {
	if ( pathname ( $_, $name ) ) { 
	    return $_ -> {pathname}; }
    }
    return undef;
}

# Given a module package or sub-package name, return the module object.
# It's probably desirable to use this in preference to retrieve, 
# with external calls, to avoid dealing with the library pathnames 
# unless necessary.
sub retrieve_module {
    my $parent = shift;
    my ($n) = @_;
    if ( $parent -> {packagename}  eq $n ) { 
	return $parent; }
    foreach ( @{$parent -> {children}} ) {
	if ( $_ -> {packagename} eq $n ) {
	    return $_;
	}
    } 
    foreach ( @{$parent -> {children}} ) {
	if ( retrieve( $_, $n ) ) { 
	    return $_; }
    }
    return undef;
}

sub modulepathnames {
    my $self = shift;
    return @modulepathnames;
}

sub libdirectories {
    my $self = shift;
    return @libdirectories;
}

sub scanlibs {
    my $b = shift;
    my $verbose = $_[0];
    my $m;
    my ($path, $bname, $ext);
    autoflush STDOUT 1 if $verbose;
  LOOP: foreach my $i ( @modulepathnames ) {
      print '.' if $verbose;
      ($bname, $path, $ext) = fileparse($i, qw(\.pm$ \.pl$) );
      # Don't use RCS Archives or Emacs bacups
      if( $bname =~ /(,v)|~/ ) { next LOOP; }
      if( $bname =~ /UNIVERSAL/ ) {
	  $b -> modinfo( $i );
      } else {
	  $m = new Lib::Module;
	  next LOOP if ! $m -> modinfo( $i );
	  $m -> {parents} = $b; 
	  push @{$b -> {children}}, ($m); 
      }
  }
}

sub modinfo {
    my $self = shift;
    my ($path) = @_;
    my ($dirs, $bname, $ext);
    my ($supers, $pkg, $ver, @text, @matches); 
    ($bname, $dirs, $ext) = fileparse($path, qw(\.pm \.pl));
    $self -> {pathname} = $path;
    @text = $self -> readfile;
    my $p = new Lib::ModuleSymbol;
    return undef if ! $p -> text_symbols( @text, $path );
    $self -> {moduleinfo} = $p ;
    $self -> {packagename} = $p -> {packagename};
    $self -> {version} = $p -> {version};
    # We do a static match here because it's faster
    # Todo: include base classes from "use base" statements.
    @matches = grep /^\@ISA(.*?)\;/, @text;
    $supers = $matches[0];
    $supers =~ s/(qw)|[=\(\)\;]//gms if $supers;
    $self -> {basename} = $bname;
    $self -> {superclasses} = $supers;
    return 1;
}

# See the perlmod manpage
# Returns a hash of symbol => values.
# Handles as separate ref.
# Typeglob dereferencing deja Symdump.pm and dumpvar.pl, et al.
# Package namespace creation and module loading per base.pm.
sub exportedkeys {
    my $m = shift;
    my ($pkg) = @_;
    my $obj;
    my $key; my $val;
    my $rval;
    my $nval;
    my %keylist = ();
    $m -> {symbols} = ();
    my @vallist;
    my $i = 0;
  EACHKEY: foreach $key( keys %{*{"$pkg"}} ) {
      next unless $key;
      if( defined ($val = ${*{"$pkg"}}{$key} ) ) {
        $rval = $val; $nval = $val; 
	$obj = tie $rval, 'Lib::SymbolRef', $nval;
	push @{$m -> {symbols}}, ($obj);
	foreach( @vallist) { if ( $_ eq $rval ) { next EACHKEY } }
	# Replace the static $VERSION and @ISA values 
	# of the initial library scan with the symbol
	# compile/run-time values.
	local (*v) = $val;
	# Look for the stash values in case they've changed 
	# from the source scan.
	if( $key =~ /VERSION/ ) {
	  $m -> {version} = ${*v{SCALAR}};
	}
	if($key =~ /ISA/ ) {
	  $m -> {superclasses} = "@{*v{ARRAY}}";
	}
      }
    }
    $keylist{$key} = ${*{"$pkg"}}{$key} if $key;
    # for dumping symbol refs to STDOUT.
    # example of how to print listing of symbol refs.
#    foreach my $i ( @{$m -> {symbols}} ) { 
#      foreach( @{$i -> {name}} ) {
#	print $_; 
#      }
#      print "\n--------\n";
#    }
    return %keylist;
}

#
#  Here for example only.  This function (or the statements
# it contains), must be in the package that has the main:: stash
# space in order to list the packages symbols into the correct
# stash context.  
#
# sub modImport {
#  my ($pkg) = @_;
#  eval "package $pkg";
#  eval "use $pkg";
#  eval "require $pkg";
#}

sub readfile {
  my $self = shift;
  my $fn;
  if (@_){ ($fn) = @_; } else { $fn = $self -> PathName; }
  my @text;
  open FILE, $fn or warn "Couldn't open file $fn: $!.\n";
  @text = <FILE>;
  close FILE;
  return @text;
}

# de-allocate module and all its children
sub DESTROY ($) {
    my ($m) = @_;
    @c = $m -> {children};
    $d = @c;
    if ( $d == 0 )  {   
	$m = {
	    children => undef
	};
	return;
      }
    foreach my $i ( @{$m -> {children}} ) {
	Lib::Module -> DESTROY($i);
    }
  }

sub libdirs {
    my $self = shift;
    my $verbose = $_[0];
    my $f; my $f2;
    my $d; 
    autoflush STDOUT 1 if $verbose;
    foreach $d ( @INC ) {
	push @libdirectories, ($d);
	print '.' if $verbose;
	opendir DIR, $d;
	@dirfiles = readdir DIR;
	closedir DIR;
	# look for subdirs of the directories in @INC.
	foreach $f ( @dirfiles ) {
	    next if $f =~ m/^\.{1,2}$/ ;
	    $f2 = $d . '/' . $f;
	    if (opendir SUBDIR, $f2 ) {
		push @libdirectories, ($f2);
		print '.' if $verbose;
		libsubdir( $f2 );
		closedir SUBDIR;
	    }
	}
    }
}

sub libsubdir {
    my ($parent) = @_;
    opendir DIR, $parent;
    my @dirfiles = readdir DIR;
    closedir DIR;
    foreach (@dirfiles) {
	next if $_ =~ m/^\.{1,2}$/ ;
	my $f2 = $parent . '/' . $_;
	if (opendir SUBDIR, $f2 ) {
	    push @libdirectories, ($f2);
	    print '.' if $verbose;
	    libsubdir( $f2 );
	    closedir SUBDIR;
	}
    }
}

sub module_paths {
    my $self = shift;
    my ($f, $pathname, @allfiles);
    foreach ( @libdirectories ) {
	opendir DIR, $_;
	@allfiles = readdir DIR;
	closedir DIR;
	foreach $f ( @allfiles ) {
	    if ( $f =~ /\.p[lm]/ ) {
		$pathname = $_ . '/' . $f;
		push @modulepathnames, ($pathname);
	    }
	}
    }
}


sub Children {
    my $self = shift;
    if (@_) { $self -> {children} = shift; }
    return $self -> {children}
}

sub Parents {
    my $self = shift;
    if (@_) { $self -> {parents} = shift; }
    return $self -> {parents}
}

sub PathName {
    my $self = shift;
    if (@_) { $self -> {pathname} = shift; }
    return $self -> {pathname}
}

sub BaseName {
    my $self = shift;
    if (@_) { $self -> {basename} = shift; }
    return $self -> {basename}
}

sub PackageName {
    my $self = shift;
    if (@_) { $self -> {packagename} = shift; }
    return $self -> {packagename}
}

sub Symbols {
    my $self = shift;
    if (@_) { $self -> {symbols} = shift; }
    return $self -> {symbols}
}

###
### Version, SuperClass -- Module.pm uses hashref directly.
###
sub Version {
    my $self = shift;
    if (@_) { $self -> {version} = shift; }
    return $self -> {version}
}

sub SuperClasses {
    my $self = shift;
    if (@_) { $self -> {superclasses} = shift; }
    return $self -> {superclasses}
}

sub BaseClass {
    my $self = shift;
    if (@_) { $self -> {baseclass} = shift; }
    return $self -> {baseclass}
}

sub ModuleInfo {
    my $self = shift;
    if (@_) { $self -> {moduleinfo} = shift; }
    return $self -> {moduleinfo}
}

sub Import {
  my ($pkg) = @_;
  &Exporter::import( $pkg ); 
}

1;

