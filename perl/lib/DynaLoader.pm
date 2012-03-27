
# Generated from DynaLoader.pm.PL

package DynaLoader;

#   And Gandalf said: 'Many folk like to know beforehand what is to
#   be set on the table; but those who have laboured to prepare the
#   feast like to keep their secret; for wonder makes the words of
#   praise louder.'

#   (Quote from Tolkien suggested by Anno Siegel.)
#
# See pod text at end of file for documentation.
# See also ext/DynaLoader/README in source tree for other information.
#
# Tim.Bunce@ig.co.uk, August 1994

use vars qw($VERSION *AUTOLOAD);

$VERSION = '1.04';	# avoid typo warning

require AutoLoader;
*AUTOLOAD = \&AutoLoader::AUTOLOAD;

use Config;

# The following require can't be removed during maintenance
# releases, sadly, because of the risk of buggy code that does 
# require Carp; Carp::croak "..."; without brackets dying 
# if Carp hasn't been loaded in earlier compile time. :-( 
# We'll let those bugs get found on the development track.
require Carp if $] < 5.00450; 

# enable debug/trace messages from DynaLoader perl code
$dl_debug = $ENV{PERL_DL_DEBUG} || 0 unless defined $dl_debug;

#
# Flags to alter dl_load_file behaviour.  Assigned bits:
#   0x01  make symbols available for linking later dl_load_file's.
#         (only known to work on Solaris 2 using dlopen(RTLD_GLOBAL))
#         (ignored under VMS; effect is built-in to image linking)
#
# This is called as a class method $module->dl_load_flags.  The
# definition here will be inherited and result on "default" loading
# behaviour unless a sub-class of DynaLoader defines its own version.
#

sub dl_load_flags { 0x00 }

# ($dl_dlext, $dlsrc)
#         = @Config::Config{'dlext', 'dlsrc'};
  ($dl_dlext, $dlsrc) = ('dll','dl_win32.xs')
;
# Some systems need special handling to expand file specifications
# (VMS support by Charles Bailey <bailey@HMIVAX.HUMGEN.UPENN.EDU>)
# See dl_expandspec() for more details. Should be harmless but
# inefficient to define on systems that don't need it.
$Is_VMS    = $^O eq 'VMS';
$do_expand = $Is_VMS;
$Is_MacOS  = $^O eq 'MacOS';

my $Mac_FS;
$Mac_FS = eval { require Mac::FileSpec::Unixish } if $Is_MacOS;

@dl_require_symbols = ();       # names of symbols we need
@dl_resolve_using   = ();       # names of files to link with
@dl_library_path    = ();       # path to look for files

#XSLoader.pm may have added elements before we were required
#@dl_librefs         = ();       # things we have loaded
#@dl_modules         = ();       # Modules we have loaded

# This is a fix to support DLD's unfortunate desire to relink -lc
@dl_resolve_using = dl_findfile('-lc') if $dlsrc eq "dl_dld.xs";

# Initialise @dl_library_path with the 'standard' library path
# for this platform as determined by Configure.

push(@dl_library_path, split(' ', $Config::Config{libpth}));


my $ldlibpthname         = $Config::Config{ldlibpthname};
my $ldlibpthname_defined = defined $Config::Config{ldlibpthname};
my $pthsep               = $Config::Config{path_sep};

# Add to @dl_library_path any extra directories we can gather from environment
# during runtime.

if ($ldlibpthname_defined &&
    exists $ENV{$ldlibpthname}) {
    push(@dl_library_path, split(/$pthsep/, $ENV{$ldlibpthname}));
}

# E.g. HP-UX supports both its native SHLIB_PATH *and* LD_LIBRARY_PATH.

if ($ldlibpthname_defined &&
    $ldlibpthname ne 'LD_LIBRARY_PATH' &&
    exists $ENV{LD_LIBRARY_PATH}) {
    push(@dl_library_path, split(/$pthsep/, $ENV{LD_LIBRARY_PATH}));
}


# No prizes for guessing why we don't say 'bootstrap DynaLoader;' here.
# NOTE: All dl_*.xs (including dl_none.xs) define a dl_error() XSUB
boot_DynaLoader('DynaLoader') if defined(&boot_DynaLoader) &&
                                !defined(&dl_error);

if ($dl_debug) {
    print STDERR "DynaLoader.pm loaded (@INC, @dl_library_path)\n";
    print STDERR "DynaLoader not linked into this perl\n"
	    unless defined(&boot_DynaLoader);
}

1; # End of main code


sub croak   { require Carp; Carp::croak(@_)   }

sub bootstrap_inherit {
    my $module = $_[0];
    local *isa = *{"$module\::ISA"};
    local @isa = (@isa, 'DynaLoader');
    # Cannot goto due to delocalization.  Will report errors on a wrong line?
    bootstrap(@_);
}

# The bootstrap function cannot be autoloaded (without complications)
# so we define it here:

sub bootstrap {
    # use local vars to enable $module.bs script to edit values
    local(@args) = @_;
    local($module) = $args[0];
    local(@dirs, $file);

    unless ($module) {
	require Carp;
	Carp::confess("Usage: DynaLoader::bootstrap(module)");
    }

    # A common error on platforms which don't support dynamic loading.
    # Since it's fatal and potentially confusing we give a detailed message.
    croak("Can't load module $module, dynamic loading not available in this perl.\n".
	"  (You may need to build a new perl executable which either supports\n".
	"  dynamic loading or has the $module module statically linked into it.)\n")
	unless defined(&dl_load_file);

    my @modparts = split(/::/,$module);
    my $modfname = $modparts[-1];

    # Some systems have restrictions on files names for DLL's etc.
    # mod2fname returns appropriate file base name (typically truncated)
    # It may also edit @modparts if required.
    $modfname = &mod2fname(\@modparts) if defined &mod2fname;

    # Truncate the module name to 8.3 format for NetWare
	if (($^O eq 'NetWare') && (length($modfname) > 8)) {
		$modfname = substr($modfname, 0, 8);
	}

    my $modpname = join(($Is_MacOS ? ':' : '/'),@modparts);

    print STDERR "DynaLoader::bootstrap for $module ",
		($Is_MacOS
		       ? "(:auto:$modpname:$modfname.$dl_dlext)\n" :
		       "(auto/$modpname/$modfname.$dl_dlext)\n")
	if $dl_debug;

    foreach (@INC) {
	chop($_ = VMS::Filespec::unixpath($_)) if $Is_VMS;
	my $dir;
	if ($Is_MacOS) {
	    my $path = $_;
	    if ($Mac_FS && ! -d $path) {
		$path = Mac::FileSpec::Unixish::nativize($path);
	    }
	    $path .= ":"  unless /:$/;
	    $dir = "${path}auto:$modpname";
	} else {
	    $dir = "$_/auto/$modpname";
	}
	
	next unless -d $dir; # skip over uninteresting directories
	
	# check for common cases to avoid autoload of dl_findfile
	my $try = $Is_MacOS ? "$dir:$modfname.$dl_dlext" : "$dir/$modfname.$dl_dlext";
	last if $file = ($do_expand) ? dl_expandspec($try) : ((-f $try) && $try);
	
	# no luck here, save dir for possible later dl_findfile search
	push @dirs, $dir;
    }
    # last resort, let dl_findfile have a go in all known locations
    $file = dl_findfile(map("-L$_",@dirs,@INC), $modfname) unless $file;

    croak("Can't locate loadable object for module $module in \@INC (\@INC contains: @INC)")
	unless $file;	# wording similar to error from 'require'

    $file = uc($file) if $Is_VMS && $Config::Config{d_vms_case_sensitive_symbols};
    my $bootname = "boot_$module";
    $bootname =~ s/\W/_/g;
    @dl_require_symbols = ($bootname);

    # Execute optional '.bootstrap' perl script for this module.
    # The .bs file can be used to configure @dl_resolve_using etc to
    # match the needs of the individual module on this architecture.
    my $bs = $file;
    $bs =~ s/(\.\w+)?(;\d*)?$/\.bs/; # look for .bs 'beside' the library
    if (-s $bs) { # only read file if it's not empty
        print STDERR "BS: $bs ($^O, $dlsrc)\n" if $dl_debug;
        eval { do $bs; };
        warn "$bs: $@\n" if $@;
    }

    my $boot_symbol_ref;

    if ($^O eq 'darwin') {
        if ($boot_symbol_ref = dl_find_symbol(0, $bootname)) {
            goto boot; #extension library has already been loaded, e.g. darwin
        }
    }

    # Many dynamic extension loading problems will appear to come from
    # this section of code: XYZ failed at line 123 of DynaLoader.pm.
    # Often these errors are actually occurring in the initialisation
    # C code of the extension XS file. Perl reports the error as being
    # in this perl code simply because this was the last perl code
    # it executed.

    my $libref = dl_load_file($file, $module->dl_load_flags) or
	croak("Can't load '$file' for module $module: ".dl_error());

    push(@dl_librefs,$libref);  # record loaded object

    my @unresolved = dl_undef_symbols();
    if (@unresolved) {
	require Carp;
	Carp::carp("Undefined symbols present after loading $file: @unresolved\n");
    }

    $boot_symbol_ref = dl_find_symbol($libref, $bootname) or
         croak("Can't find '$bootname' symbol in $file\n");

    push(@dl_modules, $module); # record loaded module

  boot:
    my $xs = dl_install_xsub("${module}::bootstrap", $boot_symbol_ref, $file);

    # See comment block above
    &$xs(@args);
}


#sub _check_file {   # private utility to handle dl_expandspec vs -f tests
#    my($file) = @_;
#    return $file if (!$do_expand && -f $file); # the common case
#    return $file if ( $do_expand && ($file=dl_expandspec($file)));
#    return undef;
#}


# Let autosplit and the autoloader deal with these functions:
__END__


sub dl_findfile {
    # Read ext/DynaLoader/DynaLoader.doc for detailed information.
    # This function does not automatically consider the architecture
    # or the perl library auto directories.
    my (@args) = @_;
    my (@dirs,  $dir);   # which directories to search
    my (@found);         # full paths to real files we have found
    my $dl_ext= 'dll'; # $Config::Config{'dlext'} suffix for perl extensions
    my $dl_so = 'dll'; # $Config::Config{'so'} suffix for shared libraries

    print STDERR "dl_findfile(@args)\n" if $dl_debug;

    # accumulate directories but process files as they appear
    arg: foreach(@args) {
        #  Special fast case: full filepath requires no search
        if ($Is_VMS && m%[:>/\]]% && -f $_) {
	    push(@found,dl_expandspec(VMS::Filespec::vmsify($_)));
	    last arg unless wantarray;
	    next;
        }
	elsif ($Is_MacOS) {
	    if (m/:/ && -f $_) {
	    	push(@found,$_);
	    	last arg unless wantarray;
	    }
	}
        elsif (m:/: && -f $_ && !$do_expand) {
	    push(@found,$_);
	    last arg unless wantarray;
	    next;
	}

        # Deal with directories first:
        #  Using a -L prefix is the preferred option (faster and more robust)
        if (m:^-L:) { s/^-L//; push(@dirs, $_); next; }

	if ($Is_MacOS) {
            #  Otherwise we try to try to spot directories by a heuristic
            #  (this is a more complicated issue than it first appears)
	    if (m/:/ && -d $_) {   push(@dirs, $_); next; }
            #  Only files should get this far...
            my(@names, $name);    # what filenames to look for
	    s/^-l//;
	    push(@names, $_);
            foreach $dir (@dirs, @dl_library_path) {
            	next unless -d $dir;
		$dir =~ s/^([^:]+)$/:$1/;
		$dir =~ s/:$//;
            	foreach $name (@names) {
	    	    my($file) = "$dir:$name";
                    print STDERR " checking in $dir for $name\n" if $dl_debug;
		    if (-f $file) {
                    	push(@found, $file);
                    	next arg; # no need to look any further
                    }
                }
	    }
	    next;
	}
	
        #  Otherwise we try to try to spot directories by a heuristic
        #  (this is a more complicated issue than it first appears)
        if (m:/: && -d $_) {   push(@dirs, $_); next; }

        # VMS: we may be using native VMS directory syntax instead of
        # Unix emulation, so check this as well
        if ($Is_VMS && /[:>\]]/ && -d $_) {   push(@dirs, $_); next; }

        #  Only files should get this far...
        my(@names, $name);    # what filenames to look for
        if (m:-l: ) {          # convert -lname to appropriate library name
            s/-l//;
            push(@names,"lib$_.$dl_so");
            push(@names,"lib$_.a");
        } else {                # Umm, a bare name. Try various alternatives:
            # these should be ordered with the most likely first
            push(@names,"$_.$dl_ext")    unless m/\.$dl_ext$/o;
            push(@names,"$_.$dl_so")     unless m/\.$dl_so$/o;
            push(@names,"lib$_.$dl_so")  unless m:/:;
            push(@names,"$_.a")          if !m/\.a$/ and $dlsrc eq "dl_dld.xs";
            push(@names, $_);
        }
        foreach $dir (@dirs, @dl_library_path) {
            next unless -d $dir;
            chop($dir = VMS::Filespec::unixpath($dir)) if $Is_VMS;
            foreach $name (@names) {
		my($file) = "$dir/$name";
                print STDERR " checking in $dir for $name\n" if $dl_debug;
		$file = ($do_expand) ? dl_expandspec($file) : (-f $file && $file);
		#$file = _check_file($file);
		if ($file) {
                    push(@found, $file);
                    next arg; # no need to look any further
                }
            }
        }
    }
    if ($dl_debug) {
        foreach(@dirs) {
            print STDERR " dl_findfile ignored non-existent directory: $_\n" unless -d $_;
        }
        print STDERR "dl_findfile found: @found\n";
    }
    return $found[0] unless wantarray;
    @found;
}


sub dl_expandspec {
    my($spec) = @_;
    # Optional function invoked if DynaLoader.pm sets $do_expand.
    # Most systems do not require or use this function.
    # Some systems may implement it in the dl_*.xs file in which case
    # this autoload version will not be called but is harmless.

    # This function is designed to deal with systems which treat some
    # 'filenames' in a special way. For example VMS 'Logical Names'
    # (something like unix environment variables - but different).
    # This function should recognise such names and expand them into
    # full file paths.
    # Must return undef if $spec is invalid or file does not exist.

    my $file = $spec; # default output to input

    if ($Is_VMS) { # dl_expandspec should be defined in dl_vms.xs
	require Carp;
	Carp::croak("dl_expandspec: should be defined in XS file!\n");
    } else {
	return undef unless -f $file;
    }
    print STDERR "dl_expandspec($spec) => $file\n" if $dl_debug;
    $file;
}

sub dl_find_symbol_anywhere
{
    my $sym = shift;
    my $libref;
    foreach $libref (@dl_librefs) {
	my $symref = dl_find_symbol($libref,$sym);
	return $symref if $symref;
    }
    return undef;
}

