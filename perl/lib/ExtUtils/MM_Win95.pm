package ExtUtils::MM_Win95;

use vars qw($VERSION @ISA);
$VERSION = 0.03;

require ExtUtils::MM_Win32;
@ISA = qw(ExtUtils::MM_Win32);

use Config;
my $DMAKE = 1 if $Config{'make'} =~ /^dmake/i;
my $NMAKE = 1 if $Config{'make'} =~ /^nmake/i;


sub dist_test {
    my($self) = shift;
    return q{
disttest : distdir
	cd $(DISTVNAME)
	$(ABSPERLRUN) Makefile.PL
	$(MAKE) $(PASTHRU)
	$(MAKE) test $(PASTHRU)
	cd ..
};
}

sub subdir_x {
    my($self, $subdir) = @_;

    # Win-9x has nasty problem in command.com that can't cope with
    # &&.  Also, Dmake has an odd way of making a commandseries silent:
    if ($DMAKE) {
      return sprintf <<'EOT', $subdir;

subdirs ::
@[
	cd %s
	$(MAKE) all $(PASTHRU)
	cd ..
]
EOT
    }
    else {
        return sprintf <<'EOT', $subdir;

subdirs ::
	$(NOECHO)cd %s
	$(NOECHO)$(MAKE) all $(PASTHRU)
	$(NOECHO)cd ..
EOT
    }
}

sub xs_c {
    my($self) = shift;
    return '' unless $self->needs_linking();
    '
.xs.c:
	$(PERLRUN) $(XSUBPP) $(XSPROTOARG) $(XSUBPPARGS) $*.xs > $*.c
	'
}


sub xs_cpp {
    my($self) = shift;
    return '' unless $self->needs_linking();
    '
.xs.cpp:
	$(PERLRUN) $(XSUBPP) $(XSPROTOARG) $(XSUBPPARGS) $*.xs > $*.cpp
	';
}

sub xs_o {
    my($self) = shift;
    return '' unless $self->needs_linking();
    # Having to choose between .xs -> .c -> .o and .xs -> .o confuses dmake.
    return '' if $DMAKE;
    '
.xs$(OBJ_EXT):
	$(PERLRUN) $(XSUBPP) $(XSPROTOARG) $(XSUBPPARGS) $*.xs > $*.c
	$(CCCMD) $(CCCDLFLAGS) -I$(PERL_INC) $(DEFINE) $*.c
	';
}

sub clean_subdirs_target {
    my($self) = shift;

    # No subdirectories, no cleaning.
    return <<'NOOP_FRAG' unless @{$self->{DIR}};
clean_subdirs :
	$(NOECHO)$(NOOP)
NOOP_FRAG


    my $clean = "clean_subdirs :\n";

    for my $dir (@{$self->{DIR}}) {
        $clean .= sprintf <<'MAKE_FRAG', $dir;
	cd %s
	$(TEST_F) $(FIRST_MAKEFILE)
	$(MAKE) clean
	cd ..
MAKE_FRAG
    }

    return $clean;
}


sub realclean_subdirs_target {
    my $self = shift;

    return <<'NOOP_FRAG' unless @{$self->{DIR}};
realclean_subdirs :
	$(NOECHO)$(NOOP)
NOOP_FRAG

    my $rclean = "realclean_subdirs :\n";

    foreach my $dir (@{$self->{DIR}}){
        $rclean .= sprintf <<'RCLEAN', $dir;
	-cd %s
	-$(PERLRUN) -e "exit unless -f shift; system q{$(MAKE) realclean}" $(FIRST_MAKEFILE)
	-cd ..
RCLEAN

    }

    return $rclean;
}


sub os_flavor {
    my $self = shift;
    return ($self->SUPER::os_flavor, 'Win9x');
}



1;
