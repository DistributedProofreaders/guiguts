package File::Temp;

# 5.6.0 gives us S_IWOTH, S_IWGRP, our and auto-vivifying filehandls
# People would like a version on 5.005 so give them what they want :-)
use 5.005;
use strict;
use Carp;
use File::Spec 0.8;
use File::Path qw/ rmtree /;
use Fcntl 1.03;
use Errno;
require VMS::Stdio if $^O eq 'VMS';

# Need the Symbol package if we are running older perl
require Symbol if $] < 5.006;

### For the OO interface
use base qw/ IO::Handle /;
use overload '""' => "STRINGIFY";


# use 'our' on v5.6.0
use vars qw($VERSION @EXPORT_OK %EXPORT_TAGS $DEBUG);

$DEBUG = 0;

# We are exporting functions

use base qw/Exporter/;

# Export list - to allow fine tuning of export table

@EXPORT_OK = qw{
	      tempfile
	      tempdir
	      tmpnam
	      tmpfile
	      mktemp
	      mkstemp
	      mkstemps
	      mkdtemp
	      unlink0
		};

# Groups of functions for export

%EXPORT_TAGS = (
		'POSIX' => [qw/ tmpnam tmpfile /],
		'mktemp' => [qw/ mktemp mkstemp mkstemps mkdtemp/],
	       );

# add contents of these tags to @EXPORT
Exporter::export_tags('POSIX','mktemp');

# Version number

$VERSION = '0.14';

# This is a list of characters that can be used in random filenames

my @CHARS = (qw/ A B C D E F G H I J K L M N O P Q R S T U V W X Y Z
	         a b c d e f g h i j k l m n o p q r s t u v w x y z
	         0 1 2 3 4 5 6 7 8 9 _
	     /);

# Maximum number of tries to make a temp file before failing

use constant MAX_TRIES => 10;

# Minimum number of X characters that should be in a template
use constant MINX => 4;

# Default template when no template supplied

use constant TEMPXXX => 'X' x 10;

# Constants for the security level

use constant STANDARD => 0;
use constant MEDIUM   => 1;
use constant HIGH     => 2;

# OPENFLAGS. If we defined the flag to use with Sysopen here this gives
# us an optimisation when many temporary files are requested

my $OPENFLAGS = O_CREAT | O_EXCL | O_RDWR;

unless ($^O eq 'MacOS') {
  for my $oflag (qw/ FOLLOW BINARY LARGEFILE EXLOCK NOINHERIT /) {
    my ($bit, $func) = (0, "Fcntl::O_" . $oflag);
    no strict 'refs';
    $OPENFLAGS |= $bit if eval {
      # Make sure that redefined die handlers do not cause problems
      # eg CGI::Carp
      local $SIG{__DIE__} = sub {};
      local $SIG{__WARN__} = sub {};
      $bit = &$func();
      1;
    };
  }
}

# On some systems the O_TEMPORARY flag can be used to tell the OS
# to automatically remove the file when it is closed. This is fine
# in most cases but not if tempfile is called with UNLINK=>0 and
# the filename is requested -- in the case where the filename is to
# be passed to another routine. This happens on windows. We overcome
# this by using a second open flags variable

my $OPENTEMPFLAGS = $OPENFLAGS;
unless ($^O eq 'MacOS') {
  for my $oflag (qw/ TEMPORARY /) {
    my ($bit, $func) = (0, "Fcntl::O_" . $oflag);
    no strict 'refs';
    $OPENTEMPFLAGS |= $bit if eval {
      # Make sure that redefined die handlers do not cause problems
      # eg CGI::Carp
      local $SIG{__DIE__} = sub {};
      local $SIG{__WARN__} = sub {};
      $bit = &$func();
      1;
    };
  }
}

# INTERNAL ROUTINES - not to be used outside of package

# Generic routine for getting a temporary filename
# modelled on OpenBSD _gettemp() in mktemp.c

# The template must contain X's that are to be replaced
# with the random values

#  Arguments:

#  TEMPLATE   - string containing the XXXXX's that is converted
#           to a random filename and opened if required

# Optionally, a hash can also be supplied containing specific options
#   "open" => if true open the temp file, else just return the name
#             default is 0
#   "mkdir"=> if true, we are creating a temp directory rather than tempfile
#             default is 0
#   "suffixlen" => number of characters at end of PATH to be ignored.
#                  default is 0.
#   "unlink_on_close" => indicates that, if possible,  the OS should remove
#                        the file as soon as it is closed. Usually indicates
#                        use of the O_TEMPORARY flag to sysopen.
#                        Usually irrelevant on unix

# Optionally a reference to a scalar can be passed into the function
# On error this will be used to store the reason for the error
#   "ErrStr"  => \$errstr

# "open" and "mkdir" can not both be true
# "unlink_on_close" is not used when "mkdir" is true.

# The default options are equivalent to mktemp().

# Returns:
#   filehandle - open file handle (if called with doopen=1, else undef)
#   temp name  - name of the temp file or directory

# For example:
#   ($fh, $name) = _gettemp($template, "open" => 1);

# for the current version, failures are associated with
# stored in an error string and returned to give the reason whilst debugging
# This routine is not called by any external function
sub _gettemp {

  croak 'Usage: ($fh, $name) = _gettemp($template, OPTIONS);'
    unless scalar(@_) >= 1;

  # the internal error string - expect it to be overridden
  # Need this in case the caller decides not to supply us a value
  # need an anonymous scalar
  my $tempErrStr;

  # Default options
  my %options = (
		 "open" => 0,
		 "mkdir" => 0,
		 "suffixlen" => 0,
		 "unlink_on_close" => 0,
		 "ErrStr" => \$tempErrStr,
		);

  # Read the template
  my $template = shift;
  if (ref($template)) {
    # Use a warning here since we have not yet merged ErrStr
    carp "File::Temp::_gettemp: template must not be a reference";
    return ();
  }

  # Check that the number of entries on stack are even
  if (scalar(@_) % 2 != 0) {
    # Use a warning here since we have not yet merged ErrStr
    carp "File::Temp::_gettemp: Must have even number of options";
    return ();
  }

  # Read the options and merge with defaults
  %options = (%options, @_)  if @_;

  # Make sure the error string is set to undef
  ${$options{ErrStr}} = undef;

  # Can not open the file and make a directory in a single call
  if ($options{"open"} && $options{"mkdir"}) {
    ${$options{ErrStr}} = "doopen and domkdir can not both be true\n";
    return ();
  }

  # Find the start of the end of the  Xs (position of last X)
  # Substr starts from 0
  my $start = length($template) - 1 - $options{"suffixlen"};

  # Check that we have at least MINX x X (eg 'XXXX") at the end of the string
  # (taking suffixlen into account). Any fewer is insecure.

  # Do it using substr - no reason to use a pattern match since
  # we know where we are looking and what we are looking for

  if (substr($template, $start - MINX + 1, MINX) ne 'X' x MINX) {
    ${$options{ErrStr}} = "The template must contain at least ".
      MINX . " 'X' characters\n";
    return ();
  }

  # Replace all the X at the end of the substring with a
  # random character or just all the XX at the end of a full string.
  # Do it as an if, since the suffix adjusts which section to replace
  # and suffixlen=0 returns nothing if used in the substr directly
  # and generate a full path from the template

  my $path = _replace_XX($template, $options{"suffixlen"});


  # Split the path into constituent parts - eventually we need to check
  # whether the directory exists
  # We need to know whether we are making a temp directory
  # or a tempfile

  my ($volume, $directories, $file);
  my $parent; # parent directory
  if ($options{"mkdir"}) {
    # There is no filename at the end
    ($volume, $directories, $file) = File::Spec->splitpath( $path, 1);

    # The parent is then $directories without the last directory
    # Split the directory and put it back together again
    my @dirs = File::Spec->splitdir($directories);

    # If @dirs only has one entry (i.e. the directory template) that means
    # we are in the current directory
    if ($#dirs == 0) {
      $parent = File::Spec->curdir;
    } else {

      if ($^O eq 'VMS') {  # need volume to avoid relative dir spec
        $parent = File::Spec->catdir($volume, @dirs[0..$#dirs-1]);
        $parent = 'sys$disk:[]' if $parent eq '';
      } else {

	# Put it back together without the last one
	$parent = File::Spec->catdir(@dirs[0..$#dirs-1]);

	# ...and attach the volume (no filename)
	$parent = File::Spec->catpath($volume, $parent, '');
      }

    }

  } else {

    # Get rid of the last filename (use File::Basename for this?)
    ($volume, $directories, $file) = File::Spec->splitpath( $path );

    # Join up without the file part
    $parent = File::Spec->catpath($volume,$directories,'');

    # If $parent is empty replace with curdir
    $parent = File::Spec->curdir
      unless $directories ne '';

  }

  # Check that the parent directories exist
  # Do this even for the case where we are simply returning a name
  # not a file -- no point returning a name that includes a directory
  # that does not exist or is not writable

  unless (-d $parent) {
    ${$options{ErrStr}} = "Parent directory ($parent) is not a directory";
    return ();
  }
  unless (-w _) {
    ${$options{ErrStr}} = "Parent directory ($parent) is not writable\n";
      return ();
  }


  # Check the stickiness of the directory and chown giveaway if required
  # If the directory is world writable the sticky bit
  # must be set

  if (File::Temp->safe_level == MEDIUM) {
    my $safeerr;
    unless (_is_safe($parent,\$safeerr)) {
      ${$options{ErrStr}} = "Parent directory ($parent) is not safe ($safeerr)";
      return ();
    }
  } elsif (File::Temp->safe_level == HIGH) {
    my $safeerr;
    unless (_is_verysafe($parent, \$safeerr)) {
      ${$options{ErrStr}} = "Parent directory ($parent) is not safe ($safeerr)";
      return ();
    }
  }


  # Now try MAX_TRIES time to open the file
  for (my $i = 0; $i < MAX_TRIES; $i++) {

    # Try to open the file if requested
    if ($options{"open"}) {
      my $fh;

      # If we are running before perl5.6.0 we can not auto-vivify
      if ($] < 5.006) {
	$fh = &Symbol::gensym;
      }

      # Try to make sure this will be marked close-on-exec
      # XXX: Win32 doesn't respect this, nor the proper fcntl,
      #      but may have O_NOINHERIT. This may or may not be in Fcntl.
      local $^F = 2;

      # Store callers umask
      my $umask = umask();

      # Set a known umask
      umask(066);

      # Attempt to open the file
      my $open_success = undef;
      if ( $^O eq 'VMS' and $options{"unlink_on_close"} ) {
        # make it auto delete on close by setting FAB$V_DLT bit
	$fh = VMS::Stdio::vmssysopen($path, $OPENFLAGS, 0600, 'fop=dlt');
	$open_success = $fh;
      } else {
	my $flags = ( $options{"unlink_on_close"} ?
		      $OPENTEMPFLAGS :
		      $OPENFLAGS );
	$open_success = sysopen($fh, $path, $flags, 0600);
      }
      if ( $open_success ) {

	# Reset umask
	umask($umask) if defined $umask;

	# Opened successfully - return file handle and name
	return ($fh, $path);

      } else {
	# Reset umask
	umask($umask) if defined $umask;

	# Error opening file - abort with error
	# if the reason was anything but EEXIST
	unless ($!{EEXIST}) {
	  ${$options{ErrStr}} = "Could not create temp file $path: $!";
	  return ();
	}

	# Loop round for another try

      }
    } elsif ($options{"mkdir"}) {

      # Store callers umask
      my $umask = umask();

      # Set a known umask
      umask(066);

      # Open the temp directory
      if (mkdir( $path, 0700)) {
	# created okay
	# Reset umask
	umask($umask) if defined $umask;

	return undef, $path;
      } else {

	# Reset umask
	umask($umask) if defined $umask;

	# Abort with error if the reason for failure was anything
	# except EEXIST
	unless ($!{EEXIST}) {
	  ${$options{ErrStr}} = "Could not create directory $path: $!";
	  return ();
	}

	# Loop round for another try

      }

    } else {

      # Return true if the file can not be found
      # Directory has been checked previously

      return (undef, $path) unless -e $path;

      # Try again until MAX_TRIES

    }

    # Did not successfully open the tempfile/dir
    # so try again with a different set of random letters
    # No point in trying to increment unless we have only
    # 1 X say and the randomness could come up with the same
    # file MAX_TRIES in a row.

    # Store current attempt - in principal this implies that the
    # 3rd time around the open attempt that the first temp file
    # name could be generated again. Probably should store each
    # attempt and make sure that none are repeated

    my $original = $path;
    my $counter = 0;  # Stop infinite loop
    my $MAX_GUESS = 50;

    do {

      # Generate new name from original template
      $path = _replace_XX($template, $options{"suffixlen"});

      $counter++;

    } until ($path ne $original || $counter > $MAX_GUESS);

    # Check for out of control looping
    if ($counter > $MAX_GUESS) {
      ${$options{ErrStr}} = "Tried to get a new temp name different to the previous value $MAX_GUESS times.\nSomething wrong with template?? ($template)";
      return ();
    }

  }

  # If we get here, we have run out of tries
  ${ $options{ErrStr} } = "Have exceeded the maximum number of attempts ("
    . MAX_TRIES . ") to open temp file/dir";

  return ();

}

# Internal routine to return a random character from the
# character list. Does not do an srand() since rand()
# will do one automatically

# No arguments. Return value is the random character

# No longer called since _replace_XX runs a few percent faster if
# I inline the code. This is important if we are creating thousands of
# temporary files.

sub _randchar {

  $CHARS[ int( rand( $#CHARS ) ) ];

}

# Internal routine to replace the XXXX... with random characters
# This has to be done by _gettemp() every time it fails to
# open a temp file/dir

# Arguments:  $template (the template with XXX),
#             $ignore   (number of characters at end to ignore)

# Returns:    modified template

sub _replace_XX {

  croak 'Usage: _replace_XX($template, $ignore)'
    unless scalar(@_) == 2;

  my ($path, $ignore) = @_;

  # Do it as an if, since the suffix adjusts which section to replace
  # and suffixlen=0 returns nothing if used in the substr directly
  # Alternatively, could simply set $ignore to length($path)-1
  # Don't want to always use substr when not required though.

  if ($ignore) {
    substr($path, 0, - $ignore) =~ s/X(?=X*\z)/$CHARS[ int( rand( $#CHARS ) ) ]/ge;
  } else {
    $path =~ s/X(?=X*\z)/$CHARS[ int( rand( $#CHARS ) ) ]/ge;
  }

  return $path;
}

# internal routine to check to see if the directory is safe
# First checks to see if the directory is not owned by the
# current user or root. Then checks to see if anyone else
# can write to the directory and if so, checks to see if
# it has the sticky bit set

# Will not work on systems that do not support sticky bit

#Args:  directory path to check
#       Optionally: reference to scalar to contain error message
# Returns true if the path is safe and false otherwise.
# Returns undef if can not even run stat() on the path

# This routine based on version written by Tom Christiansen

# Presumably, by the time we actually attempt to create the
# file or directory in this directory, it may not be safe
# anymore... Have to run _is_safe directly after the open.

sub _is_safe {

  my $path = shift;
  my $err_ref = shift;

  # Stat path
  my @info = stat($path);
  unless (scalar(@info)) {
    $$err_ref = "stat(path) returned no values";
    return 0;
  };
  return 1 if $^O eq 'VMS';  # owner delete control at file level

  # Check to see whether owner is neither superuser (or a system uid) nor me
  # Use the real uid from the $< variable
  # UID is in [4]
  if ($info[4] > File::Temp->top_system_uid() && $info[4] != $<) {

    Carp::cluck(sprintf "uid=$info[4] topuid=%s \$<=$< path='$path'",
		File::Temp->top_system_uid());

    $$err_ref = "Directory owned neither by root nor the current user"
      if ref($err_ref);
    return 0;
  }

  # check whether group or other can write file
  # use 066 to detect either reading or writing
  # use 022 to check writability
  # Do it with S_IWOTH and S_IWGRP for portability (maybe)
  # mode is in info[2]
  if (($info[2] & &Fcntl::S_IWGRP) ||   # Is group writable?
      ($info[2] & &Fcntl::S_IWOTH) ) {  # Is world writable?
    # Must be a directory
    unless (-d _) {
      $$err_ref = "Path ($path) is not a directory"
      if ref($err_ref);
      return 0;
    }
    # Must have sticky bit set
    unless (-k _) {
      $$err_ref = "Sticky bit not set on $path when dir is group|world writable"
	if ref($err_ref);
      return 0;
    }
  }

  return 1;
}

# Internal routine to check whether a directory is safe
# for temp files. Safer than _is_safe since it checks for
# the possibility of chown giveaway and if that is a possibility
# checks each directory in the path to see if it is safe (with _is_safe)

# If _PC_CHOWN_RESTRICTED is not set, does the full test of each
# directory anyway.

# Takes optional second arg as scalar ref to error reason

sub _is_verysafe {

  # Need POSIX - but only want to bother if really necessary due to overhead
  require POSIX;

  my $path = shift;
  print "_is_verysafe testing $path\n" if $DEBUG;
  return 1 if $^O eq 'VMS';  # owner delete control at file level

  my $err_ref = shift;

  # Should Get the value of _PC_CHOWN_RESTRICTED if it is defined
  # and If it is not there do the extensive test
  my $chown_restricted;
  $chown_restricted = &POSIX::_PC_CHOWN_RESTRICTED()
    if eval { &POSIX::_PC_CHOWN_RESTRICTED(); 1};

  # If chown_resticted is set to some value we should test it
  if (defined $chown_restricted) {

    # Return if the current directory is safe
    return _is_safe($path,$err_ref) if POSIX::sysconf( $chown_restricted );

  }

  # To reach this point either, the _PC_CHOWN_RESTRICTED symbol
  # was not avialable or the symbol was there but chown giveaway
  # is allowed. Either way, we now have to test the entire tree for
  # safety.

  # Convert path to an absolute directory if required
  unless (File::Spec->file_name_is_absolute($path)) {
    $path = File::Spec->rel2abs($path);
  }

  # Split directory into components - assume no file
  my ($volume, $directories, undef) = File::Spec->splitpath( $path, 1);

  # Slightly less efficient than having a function in File::Spec
  # to chop off the end of a directory or even a function that
  # can handle ../ in a directory tree
  # Sometimes splitdir() returns a blank at the end
  # so we will probably check the bottom directory twice in some cases
  my @dirs = File::Spec->splitdir($directories);

  # Concatenate one less directory each time around
  foreach my $pos (0.. $#dirs) {
    # Get a directory name
    my $dir = File::Spec->catpath($volume,
				  File::Spec->catdir(@dirs[0.. $#dirs - $pos]),
				  ''
				  );

    print "TESTING DIR $dir\n" if $DEBUG;

    # Check the directory
    return 0 unless _is_safe($dir,$err_ref);

  }

  return 1;
}



# internal routine to determine whether unlink works on this
# platform for files that are currently open.
# Returns true if we can, false otherwise.

# Currently WinNT, OS/2 and VMS can not unlink an opened file
# On VMS this is because the O_EXCL flag is used to open the
# temporary file. Currently I do not know enough about the issues
# on VMS to decide whether O_EXCL is a requirement.

sub _can_unlink_opened_file {

  if ($^O eq 'MSWin32' || $^O eq 'os2' || $^O eq 'VMS' || $^O eq 'dos' || $^O eq 'MacOS') {
    return 0;
  } else {
    return 1;
  }

}

# internal routine to decide which security levels are allowed
# see safe_level() for more information on this

# Controls whether the supplied security level is allowed

#   $cando = _can_do_level( $level )

sub _can_do_level {

  # Get security level
  my $level = shift;

  # Always have to be able to do STANDARD
  return 1 if $level == STANDARD;

  # Currently, the systems that can do HIGH or MEDIUM are identical
  if ( $^O eq 'MSWin32' || $^O eq 'os2' || $^O eq 'cygwin' || $^O eq 'dos' || $^O eq 'MacOS' || $^O eq 'mpeix') {
    return 0;
  } else {
    return 1;
  }

}

# This routine sets up a deferred unlinking of a specified
# filename and filehandle. It is used in the following cases:
#  - Called by unlink0 if an opened file can not be unlinked
#  - Called by tempfile() if files are to be removed on shutdown
#  - Called by tempdir() if directories are to be removed on shutdown

# Arguments:
#   _deferred_unlink( $fh, $fname, $isdir );
#
#   - filehandle (so that it can be expclicitly closed if open
#   - filename   (the thing we want to remove)
#   - isdir      (flag to indicate that we are being given a directory)
#                 [and hence no filehandle]

# Status is not referred to since all the magic is done with an END block

{
  # Will set up two lexical variables to contain all the files to be
  # removed. One array for files, another for directories
  # They will only exist in this block
  # This means we only have to set up a single END block to remove all files
  # @files_to_unlink contains an array ref with the filehandle and filename
  my (@files_to_unlink, @dirs_to_unlink);

  # Set up an end block to use these arrays
  END {
    # Files
    foreach my $file (@files_to_unlink) {
      # close the filehandle without checking its state
      # in order to make real sure that this is closed
      # if its already closed then I dont care about the answer
      # probably a better way to do this
      close($file->[0]);  # file handle is [0]

      if (-f $file->[1]) {  # file name is [1]
	unlink $file->[1] or warn "Error removing ".$file->[1];
      }
    }
    # Dirs
    foreach my $dir (@dirs_to_unlink) {
      if (-d $dir) {
	rmtree($dir, $DEBUG, 0);
      }
    }

  }

  # This is the sub called to register a file for deferred unlinking
  # This could simply store the input parameters and defer everything
  # until the END block. For now we do a bit of checking at this
  # point in order to make sure that (1) we have a file/dir to delete
  # and (2) we have been called with the correct arguments.
  sub _deferred_unlink {

    croak 'Usage:  _deferred_unlink($fh, $fname, $isdir)'
      unless scalar(@_) == 3;

    my ($fh, $fname, $isdir) = @_;

    warn "Setting up deferred removal of $fname\n"
      if $DEBUG;

    # If we have a directory, check that it is a directory
    if ($isdir) {

      if (-d $fname) {

	# Directory exists so store it
	# first on VMS turn []foo into [.foo] for rmtree
	$fname = VMS::Filespec::vmspath($fname) if $^O eq 'VMS';
	push (@dirs_to_unlink, $fname);

      } else {
	carp "Request to remove directory $fname could not be completed since it does not exist!\n" if $^W;
      }

    } else {

      if (-f $fname) {

	# file exists so store handle and name for later removal
	push(@files_to_unlink, [$fh, $fname]);

      } else {
	carp "Request to remove file $fname could not be completed since it is not there!\n" if $^W;
      }

    }

  }


}

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;

  # read arguments and convert keys to upper case
  my %args = @_;
  %args = map { uc($_), $args{$_} } keys %args;

  # see if they are unlinking (defaulting to yes)
  my $unlink = (exists $args{UNLINK} ? $args{UNLINK} : 1 );
  delete $args{UNLINK};

  # template (store it in an error so that it will
  # disappear from the arg list of tempfile
  my @template = ( exists $args{TEMPLATE} ? $args{TEMPLATE} : () );
  delete $args{TEMPLATE};

  # Protect OPEN
  delete $args{OPEN};

  # Open the file and retain file handle and file name
  my ($fh, $path) = tempfile( @template, %args );

  print "Tmp: $fh - $path\n" if $DEBUG;

  # Store the filename in the scalar slot
  ${*$fh} = $path;

  # Store unlink information in hash slot (plus other constructor info)
  %{*$fh} = %args;
  ${*$fh}{UNLINK} = $unlink;

  bless $fh, $class;

  return $fh;
}

sub filename {
  my $self = shift;
  return ${*$self};
}

sub STRINGIFY {
  my $self = shift;
  return $self->filename;
}

sub DESTROY {
  my $self = shift;
  if (${*$self}{UNLINK}) {
    print "# --------->   Unlinking $self\n" if $DEBUG;

    # The unlink1 may fail if the file has been closed
    # by the caller. This leaves us with the decision
    # of whether to refuse to remove the file or simply
    # do an unlink without test. Seems to be silly
    # to do this when we are trying to be careful
    # about security
    unlink1( $self, $self->filename )
      or unlink($self->filename);
  }
}

sub tempfile {

  # Can not check for argument count since we can have any
  # number of args

  # Default options
  my %options = (
		 "DIR"    => undef,  # Directory prefix
                "SUFFIX" => '',     # Template suffix
                "UNLINK" => 0,      # Do not unlink file on exit
                "OPEN"   => 1,      # Open file
		);

  # Check to see whether we have an odd or even number of arguments
  my $template = (scalar(@_) % 2 == 1 ? shift(@_) : undef);

  # Read the options and merge with defaults
  %options = (%options, @_)  if @_;

  # First decision is whether or not to open the file
  if (! $options{"OPEN"}) {

    warn "tempfile(): temporary filename requested but not opened.\nPossibly unsafe, consider using tempfile() with OPEN set to true\n"
      if $^W;

  }

  if ($options{"DIR"} and $^O eq 'VMS') {

      # on VMS turn []foo into [.foo] for concatenation
      $options{"DIR"} = VMS::Filespec::vmspath($options{"DIR"});
  }

  # Construct the template

  # Have a choice of trying to work around the mkstemp/mktemp/tmpnam etc
  # functions or simply constructing a template and using _gettemp()
  # explicitly. Go for the latter

  # First generate a template if not defined and prefix the directory
  # If no template must prefix the temp directory
  if (defined $template) {
    if ($options{"DIR"}) {

      $template = File::Spec->catfile($options{"DIR"}, $template);

    }

  } else {

    if ($options{"DIR"}) {

      $template = File::Spec->catfile($options{"DIR"}, TEMPXXX);

    } else {

      $template = File::Spec->catfile(File::Spec->tmpdir, TEMPXXX);

    }

  }

  # Now add a suffix
  $template .= $options{"SUFFIX"};

  # Determine whether we should tell _gettemp to unlink the file
  # On unix this is irrelevant and can be worked out after the file is
  # opened (simply by unlinking the open filehandle). On Windows or VMS
  # we have to indicate temporary-ness when we open the file. In general
  # we only want a true temporary file if we are returning just the
  # filehandle - if the user wants the filename they probably do not
  # want the file to disappear as soon as they close it.
  # For this reason, tie unlink_on_close to the return context regardless
  # of OS.
  my $unlink_on_close = ( wantarray ? 0 : 1);

  # Create the file
  my ($fh, $path, $errstr);
  croak "Error in tempfile() using $template: $errstr"
    unless (($fh, $path) = _gettemp($template,
				    "open" => $options{'OPEN'},
				    "mkdir"=> 0 ,
                                    "unlink_on_close" => $unlink_on_close,
				    "suffixlen" => length($options{'SUFFIX'}),
				    "ErrStr" => \$errstr,
				   ) );

  # Set up an exit handler that can do whatever is right for the
  # system. This removes files at exit when requested explicitly or when
  # system is asked to unlink_on_close but is unable to do so because
  # of OS limitations.
  # The latter should be achieved by using a tied filehandle.
  # Do not check return status since this is all done with END blocks.
  _deferred_unlink($fh, $path, 0) if $options{"UNLINK"};

  # Return
  if (wantarray()) {

    if ($options{'OPEN'}) {
      return ($fh, $path);
    } else {
      return (undef, $path);
    }

  } else {

    # Unlink the file. It is up to unlink0 to decide what to do with
    # this (whether to unlink now or to defer until later)
    unlink0($fh, $path) or croak "Error unlinking file $path using unlink0";

    # Return just the filehandle.
    return $fh;
  }


}

# '

sub tempdir  {

  # Can not check for argument count since we can have any
  # number of args

  # Default options
  my %options = (
		 "CLEANUP"    => 0,  # Remove directory on exit
		 "DIR"        => '', # Root directory
		 "TMPDIR"     => 0,  # Use tempdir with template
		);

  # Check to see whether we have an odd or even number of arguments
  my $template = (scalar(@_) % 2 == 1 ? shift(@_) : undef );

  # Read the options and merge with defaults
  %options = (%options, @_)  if @_;

  # Modify or generate the template

  # Deal with the DIR and TMPDIR options
  if (defined $template) {

    # Need to strip directory path if using DIR or TMPDIR
    if ($options{'TMPDIR'} || $options{'DIR'}) {

      # Strip parent directory from the filename
      #
      # There is no filename at the end
      $template = VMS::Filespec::vmspath($template) if $^O eq 'VMS';
      my ($volume, $directories, undef) = File::Spec->splitpath( $template, 1);

      # Last directory is then our template
      $template = (File::Spec->splitdir($directories))[-1];

      # Prepend the supplied directory or temp dir
      if ($options{"DIR"}) {

        $template = File::Spec->catdir($options{"DIR"}, $template);

      } elsif ($options{TMPDIR}) {

	# Prepend tmpdir
	$template = File::Spec->catdir(File::Spec->tmpdir, $template);

      }

    }

  } else {

    if ($options{"DIR"}) {

      $template = File::Spec->catdir($options{"DIR"}, TEMPXXX);

    } else {

      $template = File::Spec->catdir(File::Spec->tmpdir, TEMPXXX);

    }

  }

  # Create the directory
  my $tempdir;
  my $suffixlen = 0;
  if ($^O eq 'VMS') {  # dir names can end in delimiters
    $template =~ m/([\.\]:>]+)$/;
    $suffixlen = length($1);
  }
  if ( ($^O eq 'MacOS') && (substr($template, -1) eq ':') ) {
    # dir name has a trailing ':'
    ++$suffixlen;
  }

  my $errstr;
  croak "Error in tempdir() using $template: $errstr"
    unless ((undef, $tempdir) = _gettemp($template,
				    "open" => 0,
				    "mkdir"=> 1 ,
				    "suffixlen" => $suffixlen,
				    "ErrStr" => \$errstr,
				   ) );

  # Install exit handler; must be dynamic to get lexical
  if ( $options{'CLEANUP'} && -d $tempdir) {
    _deferred_unlink(undef, $tempdir, 1);
  }

  # Return the dir name
  return $tempdir;

}



sub mkstemp {

  croak "Usage: mkstemp(template)"
    if scalar(@_) != 1;

  my $template = shift;

  my ($fh, $path, $errstr);
  croak "Error in mkstemp using $template: $errstr"
    unless (($fh, $path) = _gettemp($template,
				    "open" => 1,
				    "mkdir"=> 0 ,
				    "suffixlen" => 0,
				    "ErrStr" => \$errstr,
				   ) );

  if (wantarray()) {
    return ($fh, $path);
  } else {
    return $fh;
  }

}


sub mkstemps {

  croak "Usage: mkstemps(template, suffix)"
    if scalar(@_) != 2;


  my $template = shift;
  my $suffix   = shift;

  $template .= $suffix;

  my ($fh, $path, $errstr);
  croak "Error in mkstemps using $template: $errstr"
    unless (($fh, $path) = _gettemp($template,
				    "open" => 1,
				    "mkdir"=> 0 ,
				    "suffixlen" => length($suffix),
				    "ErrStr" => \$errstr,
				   ) );

  if (wantarray()) {
    return ($fh, $path);
  } else {
    return $fh;
  }

}

#' # for emacs

sub mkdtemp {

  croak "Usage: mkdtemp(template)"
    if scalar(@_) != 1;

  my $template = shift;
  my $suffixlen = 0;
  if ($^O eq 'VMS') {  # dir names can end in delimiters
    $template =~ m/([\.\]:>]+)$/;
    $suffixlen = length($1);
  }
  if ( ($^O eq 'MacOS') && (substr($template, -1) eq ':') ) {
    # dir name has a trailing ':'
    ++$suffixlen;
  }
  my ($junk, $tmpdir, $errstr);
  croak "Error creating temp directory from template $template\: $errstr"
    unless (($junk, $tmpdir) = _gettemp($template,
					"open" => 0,
					"mkdir"=> 1 ,
					"suffixlen" => $suffixlen,
					"ErrStr" => \$errstr,
				       ) );

  return $tmpdir;

}

sub mktemp {

  croak "Usage: mktemp(template)"
    if scalar(@_) != 1;

  my $template = shift;

  my ($tmpname, $junk, $errstr);
  croak "Error getting name to temp file from template $template: $errstr"
    unless (($junk, $tmpname) = _gettemp($template,
					 "open" => 0,
					 "mkdir"=> 0 ,
					 "suffixlen" => 0,
					 "ErrStr" => \$errstr,
					 ) );

  return $tmpname;
}

sub tmpnam {

   # Retrieve the temporary directory name
   my $tmpdir = File::Spec->tmpdir;

   croak "Error temporary directory is not writable"
     if $tmpdir eq '';

   # Use a ten character template and append to tmpdir
   my $template = File::Spec->catfile($tmpdir, TEMPXXX);

   if (wantarray() ) {
       return mkstemp($template);
   } else {
       return mktemp($template);
   }

}

sub tmpfile {

  # Simply call tmpnam() in a list context
  my ($fh, $file) = tmpnam();

  # Make sure file is removed when filehandle is closed
  # This will fail on NFS
  unlink0($fh, $file)
    or return undef;

  return $fh;

}

sub tempnam {

  croak 'Usage tempnam($dir, $prefix)' unless scalar(@_) == 2;

  my ($dir, $prefix) = @_;

  # Add a string to the prefix
  $prefix .= 'XXXXXXXX';

  # Concatenate the directory to the file
  my $template = File::Spec->catfile($dir, $prefix);

  return mktemp($template);

}

sub unlink0 {

  croak 'Usage: unlink0(filehandle, filename)'
    unless scalar(@_) == 2;

  # Read args
  my ($fh, $path) = @_;

  cmpstat($fh, $path) or return 0;

  # attempt remove the file (does not work on some platforms)
  if (_can_unlink_opened_file()) {
    # XXX: do *not* call this on a directory; possible race
    #      resulting in recursive removal
    croak "unlink0: $path has become a directory!" if -d $path;
    unlink($path) or return 0;

    # Stat the filehandle
    my @fh = stat $fh;

    print "Link count = $fh[3] \n" if $DEBUG;

    # Make sure that the link count is zero
    # - Cygwin provides deferred unlinking, however,
    #   on Win9x the link count remains 1
    # On NFS the link count may still be 1 but we cant know that
    # we are on NFS
    return ( $fh[3] == 0 or $^O eq 'cygwin' ? 1 : 0);

  } else {
    _deferred_unlink($fh, $path, 0);
    return 1;
  }

}

sub cmpstat {

  croak 'Usage: cmpstat(filehandle, filename)'
    unless scalar(@_) == 2;

  # Read args
  my ($fh, $path) = @_;

  warn "Comparing stat\n"
    if $DEBUG;

  # Stat the filehandle - which may be closed if someone has manually
  # closed the file. Can not turn off warnings without using $^W
  # unless we upgrade to 5.006 minimum requirement
  my @fh;
  {
    local ($^W) = 0;
    @fh = stat $fh;
  }
  return unless @fh;

  if ($fh[3] > 1 && $^W) {
    carp "unlink0: fstat found too many links; SB=@fh" if $^W;
  }

  # Stat the path
  my @path = stat $path;

  unless (@path) {
    carp "unlink0: $path is gone already" if $^W;
    return;
  }

  # this is no longer a file, but may be a directory, or worse
  unless (-f _) {
    confess "panic: $path is no longer a file: SB=@fh";
  }

  # Do comparison of each member of the array
  # On WinNT dev and rdev seem to be different
  # depending on whether it is a file or a handle.
  # Cannot simply compare all members of the stat return
  # Select the ones we can use
  my @okstat = (0..$#fh);  # Use all by default
  if ($^O eq 'MSWin32') {
    @okstat = (1,2,3,4,5,7,8,9,10);
  } elsif ($^O eq 'os2') {
    @okstat = (0, 2..$#fh);
  } elsif ($^O eq 'VMS') { # device and file ID are sufficient
    @okstat = (0, 1);
  } elsif ($^O eq 'dos') {
    @okstat = (0,2..7,11..$#fh);
  } elsif ($^O eq 'mpeix') {
    @okstat = (0..4,8..10);
  }

  # Now compare each entry explicitly by number
  for (@okstat) {
    print "Comparing: $_ : $fh[$_] and $path[$_]\n" if $DEBUG;
    # Use eq rather than == since rdev, blksize, and blocks (6, 11,
    # and 12) will be '' on platforms that do not support them.  This
    # is fine since we are only comparing integers.
    unless ($fh[$_] eq $path[$_]) {
      warn "Did not match $_ element of stat\n" if $DEBUG;
      return 0;
    }
  }

  return 1;
}

sub unlink1 {
  croak 'Usage: unlink1(filehandle, filename)'
    unless scalar(@_) == 2;

  # Read args
  my ($fh, $path) = @_;

  cmpstat($fh, $path) or return 0;

  # Close the file
  close( $fh ) or return 0;

  # remove the file
  return unlink($path);
}

{
  # protect from using the variable itself
  my $LEVEL = STANDARD;
  sub safe_level {
    my $self = shift;
    if (@_) {
      my $level = shift;
      if (($level != STANDARD) && ($level != MEDIUM) && ($level != HIGH)) {
	carp "safe_level: Specified level ($level) not STANDARD, MEDIUM or HIGH - ignoring\n" if $^W;
      } else {
	# Dont allow this on perl 5.005 or earlier
	if ($] < 5.006 && $level != STANDARD) {
	  # Cant do MEDIUM or HIGH checks
	  croak "Currently requires perl 5.006 or newer to do the safe checks";
	}
	# Check that we are allowed to change level
	# Silently ignore if we can not.
        $LEVEL = $level if _can_do_level($level);
      }
    }
    return $LEVEL;
  }
}

{
  my $TopSystemUID = 10;
  sub top_system_uid {
    my $self = shift;
    if (@_) {
      my $newuid = shift;
      croak "top_system_uid: UIDs should be numeric"
        unless $newuid =~ /^\d+$/s;
      $TopSystemUID = $newuid;
    }
    return $TopSystemUID;
  }
}

1;
