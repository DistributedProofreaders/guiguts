package UNIVERSAL;

our $VERSION = '1.01';

# UNIVERSAL should not contain any extra subs/methods beyond those
# that it exists to define. The use of Exporter below is a historical
# accident that can't be fixed without breaking code.  Note that we
# *don't* set @ISA here, don't want all classes/objects inheriting from
# Exporter.  It's bad enough that all classes have a import() method
# whenever UNIVERSAL.pm is loaded.
require Exporter;
*import = \&Exporter::import;
@EXPORT_OK = qw(isa can VERSION);

1;
__END__

