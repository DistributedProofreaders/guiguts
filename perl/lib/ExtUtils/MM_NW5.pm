package ExtUtils::MM_NW5;

use strict;
use Config;
use File::Basename;

use vars qw(@ISA $VERSION);
$VERSION = '2.06';

require ExtUtils::MM_Win32;
@ISA = qw(ExtUtils::MM_Win32);

use ExtUtils::MakeMaker qw( &neatvalue );

$ENV{EMXSHELL} = 'sh'; # to run `commands`

my $BORLAND  = 1 if $Config{'cc'} =~ /^bcc/i;
my $GCC      = 1 if $Config{'cc'} =~ /^gcc/i;
my $DMAKE    = 1 if $Config{'make'} =~ /^dmake/i;


sub os_flavor {
    my $self = shift;
    return ($self->SUPER::os_flavor, 'Netware');
}

sub init_platform {
    my($self) = shift;

    # To get Win32's setup.
    $self->SUPER::init_platform;

    # incpath is copied to makefile var INCLUDE in constants sub, here just 
    # make it empty
    my $libpth = $Config{'libpth'};
    $libpth =~ s( )(;);
    $self->{'LIBPTH'} = $libpth;

    $self->{'BASE_IMPORT'} = $Config{'base_import'};

    # Additional import file specified from Makefile.pl
    if($self->{'base_import'}) {
        $self->{'BASE_IMPORT'} .= ', ' . $self->{'base_import'};
    }
 
    $self->{'NLM_VERSION'} = $Config{'nlm_version'};
    $self->{'MPKTOOL'}	= $Config{'mpktool'};
    $self->{'TOOLPATH'}	= $Config{'toolpath'};

    (my $boot = $self->{'NAME'}) =~ s/:/_/g;
    $self->{'BOOT_SYMBOL'}=$boot;

    # If the final binary name is greater than 8 chars,
    # truncate it here.
    if(length($self->{'BASEEXT'}) > 8) {
        $self->{'NLM_SHORT_NAME'} = substr($self->{'BASEEXT'},0,8);
    }

    # Get the include path and replace the spaces with ;
    # Copy this to makefile as INCLUDE = d:\...;d:\;
    ($self->{INCLUDE} = $Config{'incpath'}) =~ s/([ ]*)-I/;/g;

    # Set the path to CodeWarrior binaries which might not have been set in
    # any other place
    $self->{PATH} = '$(PATH);$(TOOLPATH)';

    $self->{MM_NW5_VERSION} = $VERSION;
}

sub platform_constants {
    my($self) = shift;
    my $make_frag = '';

    # Setup Win32's constants.
    $make_frag .= $self->SUPER::platform_constants;

    foreach my $macro (qw(LIBPTH BASE_IMPORT NLM_VERSION MPKTOOL 
                          TOOLPATH BOOT_SYMBOL NLM_SHORT_NAME INCLUDE PATH
                          MM_NW5_VERSION
                      ))
    {
        next unless defined $self->{$macro};
        $make_frag .= "$macro = $self->{$macro}\n";
    }

    return $make_frag;
}


sub const_cccmd {
    my($self,$libperl)=@_;
    return $self->{CONST_CCCMD} if $self->{CONST_CCCMD};
    return '' unless $self->needs_linking();
    return $self->{CONST_CCCMD} = <<'MAKE_FRAG';
CCCMD = $(CC) $(CCFLAGS) $(INC) $(OPTIMIZE) \
	$(PERLTYPE) $(MPOLLUTE) -o $@ \
	-DVERSION=\"$(VERSION)\" -DXS_VERSION=\"$(XS_VERSION)\"
MAKE_FRAG

}


sub static_lib {
    my($self) = @_;

    return '' unless $self->has_link_code;

    my $m = <<'END';
$(INST_STATIC): $(OBJECT) $(MYEXTLIB) $(INST_ARCHAUTODIR)$(DIRFILESEP).exists
	$(RM_RF) $@
END

    # If this extension has it's own library (eg SDBM_File)
    # then copy that to $(INST_STATIC) and add $(OBJECT) into it.
    $m .= <<'END'  if $self->{MYEXTLIB};
	$self->{CP} $(MYEXTLIB) $@
END

    my $ar_arg;
    if( $BORLAND ) {
        $ar_arg = '$@ $(OBJECT:^"+")';
    }
    elsif( $GCC ) {
        $ar_arg = '-ru $@ $(OBJECT)';
    }
    else {
        $ar_arg = '-type library -o $@ $(OBJECT)';
    }

    $m .= sprintf <<'END', $ar_arg;
	$(AR) %s
	$(NOECHO) $(ECHO) "$(EXTRALIBS)" > $(INST_ARCHAUTODIR)\extralibs.ld
	$(CHMOD) 755 $@
END

    $m .= <<'END' if $self->{PERL_SRC};
	$(NOECHO) $(ECHO) "$(EXTRALIBS)" >> $(PERL_SRC)\ext.libs
    
    
END
    $m .= $self->dir_target('$(INST_ARCHAUTODIR)');
    return $m;
}

sub dynamic_lib {
    my($self, %attribs) = @_;
    return '' unless $self->needs_linking(); #might be because of a subdir

    return '' unless $self->has_link_code;

    my($otherldflags) = $attribs{OTHERLDFLAGS} || ($BORLAND ? 'c0d32.obj': '');
    my($inst_dynamic_dep) = $attribs{INST_DYNAMIC_DEP} || "";
    my($ldfrom) = '$(LDFROM)';

    (my $boot = $self->{NAME}) =~ s/:/_/g;

    my $m = <<'MAKE_FRAG';
# This section creates the dynamically loadable $(INST_DYNAMIC)
# from $(OBJECT) and possibly $(MYEXTLIB).
OTHERLDFLAGS = '.$otherldflags.'
INST_DYNAMIC_DEP = '.$inst_dynamic_dep.'

# Create xdc data for an MT safe NLM in case of mpk build
$(INST_DYNAMIC): $(OBJECT) $(MYEXTLIB) $(BOOTSTRAP)
	$(NOECHO) $(ECHO) Export boot_$(BOOT_SYMBOL) > $(BASEEXT).def
	$(NOECHO) $(ECHO) $(BASE_IMPORT) >> $(BASEEXT).def
	$(NOECHO) $(ECHO) Import @$(PERL_INC)\perl.imp >> $(BASEEXT).def
MAKE_FRAG


    if ( $self->{CCFLAGS} =~ m/ -DMPK_ON /) {
        $m .= <<'MAKE_FRAG';
	$(MPKTOOL) $(XDCFLAGS) $(BASEEXT).xdc
	$(NOECHO) $(ECHO) xdcdata $(BASEEXT).xdc >> $(BASEEXT).def
MAKE_FRAG
    }

    # Reconstruct the X.Y.Z version.
    my $version = join '.', map { sprintf "%d", $_ }
                              $] =~ /(\d)\.(\d{3})(\d{2})/;
    $m .= sprintf '	$(LD) $(LDFLAGS) $(OBJECT:.obj=.obj) -desc "Perl %s Extension ($(BASEEXT))  XS_VERSION: $(XS_VERSION)" -nlmversion $(NLM_VERSION)', $version;

    # Taking care of long names like FileHandle, ByteLoader, SDBM_File etc
    if($self->{NLM_SHORT_NAME}) {
        # In case of nlms with names exceeding 8 chars, build nlm in the 
        # current dir, rename and move to auto\lib.
        $m .= q{ -o $(NLM_SHORT_NAME).$(DLEXT)}
    } else {
        $m .= q{ -o $(INST_AUTODIR)\\$(BASEEXT).$(DLEXT)}
    }

    # Add additional lib files if any (SDBM_File)
    $m .= q{ $(MYEXTLIB) } if $self->{MYEXTLIB};

    $m .= q{ $(PERL_INC)\Main.lib -commandfile $(BASEEXT).def}."\n";

    if($self->{NLM_SHORT_NAME}) {
        $m .= <<'MAKE_FRAG';
	if exist $(INST_AUTODIR)\$(NLM_SHORT_NAME).$(DLEXT) del $(INST_AUTODIR)\$(NLM_SHORT_NAME).$(DLEXT) 
	move $(NLM_SHORT_NAME).$(DLEXT) $(INST_AUTODIR)
MAKE_FRAG
    }

    $m .= <<'MAKE_FRAG';

	$(CHMOD) 755 $@
MAKE_FRAG

    $m .= $self->dir_target('$(INST_ARCHAUTODIR)');

    return $m;
}


1;
__END__


