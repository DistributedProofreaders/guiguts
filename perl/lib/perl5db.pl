package DB;

use IO::Handle;

# Debugger for Perl 5.00x; perl5db.pl patch level:
$VERSION = 1.23;

$header  = "perl5db.pl version $VERSION";

############################################## Begin lexical danger zone

# 'my' variables used here could leak into (that is, be visible in)
# the context that the code being evaluated is executing in. This means that
# the code could modify the debugger's variables.
#
# Fiddling with the debugger's context could be Bad. We insulate things as
# much as we can.

sub eval {

    # 'my' would make it visible from user code
    #    but so does local! --tchrist  
    # Remember: this localizes @DB::res, not @main::res.
    local @res;
    {
        # Try to keep the user code from messing  with us. Save these so that 
        # even if the eval'ed code changes them, we can put them back again. 
        # Needed because the user could refer directly to the debugger's 
        # package globals (and any 'my' variables in this containing scope)
        # inside the eval(), and we want to try to stay safe.
        local $otrace  = $trace; 
        local $osingle = $single;
        local $od      = $^D;

        # Untaint the incoming eval() argument.
        { ($evalarg) = $evalarg =~ /(.*)/s; }

        # $usercontext built in DB::DB near the comment 
        # "set up the context for DB::eval ..."
        # Evaluate and save any results.
        @res =
          eval "$usercontext $evalarg;\n";    # '\n' for nice recursive debug

        # Restore those old values.
        $trace  = $otrace;
        $single = $osingle;
        $^D     = $od;
    }

    # Save the current value of $@, and preserve it in the debugger's copy
    # of the saved precious globals.
    my $at = $@;

    # Since we're only saving $@, we only have to localize the array element
    # that it will be stored in.
    local $saved[0];                          # Preserve the old value of $@
    eval { &DB::save };

    # Now see whether we need to report an error back to the user.
    if ($at) {
        local $\ = '';
        print $OUT $at;
    }

    # Display as required by the caller. $onetimeDump and $onetimedumpDepth
    # are package globals.
    elsif ($onetimeDump) {
        if ($onetimeDump eq 'dump') {
            local $option{dumpDepth} = $onetimedumpDepth
              if defined $onetimedumpDepth;
            dumpit($OUT, \@res);
        }
        elsif ($onetimeDump eq 'methods') {
            methods($res[0]);
        }
    } ## end elsif ($onetimeDump)
    @res;
} ## end sub eval

############################################## End lexical danger zone

# After this point it is safe to introduce lexicals.
# The code being debugged will be executing in its own context, and 
# can't see the inside of the debugger.
#
# However, one should not overdo it: leave as much control from outside as    
# possible. If you make something a lexical, it's not going to be addressable
# from outside the debugger even if you know its name.

# This file is automatically included if you do perl -d.
# It's probably not useful to include this yourself.
#
# Before venturing further into these twisty passages, it is 
# wise to read the perldebguts man page or risk the ire of dragons.
#
# (It should be noted that perldebguts will tell you a lot about
# the uderlying mechanics of how the debugger interfaces into the
# Perl interpreter, but not a lot about the debugger itself. The new
# comments in this code try to address this problem.)

# Note that no subroutine call is possible until &DB::sub is defined
# (for subroutines defined outside of the package DB). In fact the same is
# true if $deep is not defined.
#
# $Log:	perldb.pl,v $

# Enhanced by ilya@math.ohio-state.edu (Ilya Zakharevich)

# modified Perl debugger, to be run from Emacs in perldb-mode
# Ray Lischner (uunet!mntgfx!lisch) as of 5 Nov 1990
# Johan Vromans -- upgrade to 4.0 pl 10
# Ilya Zakharevich -- patches after 5.001 (and some before ;-)

# (We have made efforts to  clarify the comments in the change log
# in other places; some of them may seem somewhat obscure as they
# were originally written, and explaining them away from the code
# in question seems conterproductive.. -JM)

########################################################################
# Changes: 0.94
#   + A lot of things changed after 0.94. First of all, core now informs
#     debugger about entry into XSUBs, overloaded operators, tied operations,
#     BEGIN and END. Handy with `O f=2'.
#   + This can make debugger a little bit too verbose, please be patient
#     and report your problems promptly.
#   + Now the option frame has 3 values: 0,1,2. XXX Document!
#   + Note that if DESTROY returns a reference to the object (or object),
#     the deletion of data may be postponed until the next function call,
#     due to the need to examine the return value.
#
# Changes: 0.95
#   + `v' command shows versions.
#
# Changes: 0.96 
#   + `v' command shows version of readline.
#     primitive completion works (dynamic variables, subs for `b' and `l',
#     options). Can `p %var'
#   + Better help (`h <' now works). New commands <<, >>, {, {{.
#     {dump|print}_trace() coded (to be able to do it from <<cmd).
#   + `c sub' documented.
#   + At last enough magic combined to stop after the end of debuggee.
#   + !! should work now (thanks to Emacs bracket matching an extra
#     `]' in a regexp is caught).
#   + `L', `D' and `A' span files now (as documented).
#   + Breakpoints in `require'd code are possible (used in `R').
#   +  Some additional words on internal work of debugger.
#   + `b load filename' implemented.
#   + `b postpone subr' implemented.
#   + now only `q' exits debugger (overwritable on $inhibit_exit).
#   + When restarting debugger breakpoints/actions persist.
#   + Buglet: When restarting debugger only one breakpoint/action per 
#             autoloaded function persists.
#
# Changes: 0.97: NonStop will not stop in at_exit().
#   + Option AutoTrace implemented.
#   + Trace printed differently if frames are printed too.
#   + new `inhibitExit' option.
#   + printing of a very long statement interruptible.
# Changes: 0.98: New command `m' for printing possible methods
#   + 'l -' is a synonym for `-'.
#   + Cosmetic bugs in printing stack trace.
#   +  `frame' & 8 to print "expanded args" in stack trace.
#   + Can list/break in imported subs.
#   + new `maxTraceLen' option.
#   + frame & 4 and frame & 8 granted.
#   + new command `m'
#   + nonstoppable lines do not have `:' near the line number.
#   + `b compile subname' implemented.
#   + Will not use $` any more.
#   + `-' behaves sane now.
# Changes: 0.99: Completion for `f', `m'.
#   +  `m' will remove duplicate names instead of duplicate functions.
#   + `b load' strips trailing whitespace.
#     completion ignores leading `|'; takes into account current package
#     when completing a subroutine name (same for `l').
# Changes: 1.07: Many fixed by tchrist 13-March-2000
#   BUG FIXES:
#   + Added bare minimal security checks on perldb rc files, plus
#     comments on what else is needed.
#   + Fixed the ornaments that made "|h" completely unusable.
#     They are not used in print_help if they will hurt.  Strip pod
#     if we're paging to less.
#   + Fixed mis-formatting of help messages caused by ornaments
#     to restore Larry's original formatting.  
#   + Fixed many other formatting errors.  The code is still suboptimal, 
#     and needs a lot of work at restructuring.  It's also misindented
#     in many places.
#   + Fixed bug where trying to look at an option like your pager
#     shows "1".  
#   + Fixed some $? processing.  Note: if you use csh or tcsh, you will
#     lose.  You should consider shell escapes not using their shell,
#     or else not caring about detailed status.  This should really be
#     unified into one place, too.
#   + Fixed bug where invisible trailing whitespace on commands hoses you,
#     tricking Perl into thinking you weren't calling a debugger command!
#   + Fixed bug where leading whitespace on commands hoses you.  (One
#     suggests a leading semicolon or any other irrelevant non-whitespace
#     to indicate literal Perl code.)
#   + Fixed bugs that ate warnings due to wrong selected handle.
#   + Fixed a precedence bug on signal stuff.
#   + Fixed some unseemly wording.
#   + Fixed bug in help command trying to call perl method code.
#   + Fixed to call dumpvar from exception handler.  SIGPIPE killed us.
#   ENHANCEMENTS:
#   + Added some comments.  This code is still nasty spaghetti.
#   + Added message if you clear your pre/post command stacks which was
#     very easy to do if you just typed a bare >, <, or {.  (A command
#     without an argument should *never* be a destructive action; this
#     API is fundamentally screwed up; likewise option setting, which
#     is equally buggered.)
#   + Added command stack dump on argument of "?" for >, <, or {.
#   + Added a semi-built-in doc viewer command that calls man with the
#     proper %Config::Config path (and thus gets caching, man -k, etc),
#     or else perldoc on obstreperous platforms.
#   + Added to and rearranged the help information.
#   + Detected apparent misuse of { ... } to declare a block; this used
#     to work but now is a command, and mysteriously gave no complaint.
#
# Changes: 1.08: Apr 25, 2001  Jon Eveland <jweveland@yahoo.com>
#   BUG FIX:
#   + This patch to perl5db.pl cleans up formatting issues on the help
#     summary (h h) screen in the debugger.  Mostly columnar alignment
#     issues, plus converted the printed text to use all spaces, since
#     tabs don't seem to help much here.
#
# Changes: 1.09: May 19, 2001  Ilya Zakharevich <ilya@math.ohio-state.edu>
#   Minor bugs corrected;
#   + Support for auto-creation of new TTY window on startup, either
#     unconditionally, or if started as a kid of another debugger session;
#   + New `O'ption CreateTTY
#       I<CreateTTY>      bits control attempts to create a new TTY on events:
#                         1: on fork()   
#                         2: debugger is started inside debugger
#                         4: on startup
#   + Code to auto-create a new TTY window on OS/2 (currently one
#     extra window per session - need named pipes to have more...);
#   + Simplified interface for custom createTTY functions (with a backward
#     compatibility hack); now returns the TTY name to use; return of ''
#     means that the function reset the I/O handles itself;
#   + Better message on the semantic of custom createTTY function;
#   + Convert the existing code to create a TTY into a custom createTTY
#     function;
#   + Consistent support for TTY names of the form "TTYin,TTYout";
#   + Switch line-tracing output too to the created TTY window;
#   + make `b fork' DWIM with CORE::GLOBAL::fork;
#   + High-level debugger API cmd_*():
#      cmd_b_load($filenamepart)            # b load filenamepart
#      cmd_b_line($lineno [, $cond])        # b lineno [cond]
#      cmd_b_sub($sub [, $cond])            # b sub [cond]
#      cmd_stop()                           # Control-C
#      cmd_d($lineno)                       # d lineno (B)
#      The cmd_*() API returns FALSE on failure; in this case it outputs
#      the error message to the debugging output.
#   + Low-level debugger API
#      break_on_load($filename)             # b load filename
#      @files = report_break_on_load()      # List files with load-breakpoints
#      breakable_line_in_filename($name, $from [, $to])
#                                           # First breakable line in the
#                                           # range $from .. $to.  $to defaults
#                                           # to $from, and may be less than 
#                                           # $to
#      breakable_line($from [, $to])        # Same for the current file
#      break_on_filename_line($name, $lineno [, $cond])
#                                           # Set breakpoint,$cond defaults to 
#                                           # 1
#      break_on_filename_line_range($name, $from, $to [, $cond])
#                                           # As above, on the first
#                                           # breakable line in range
#      break_on_line($lineno [, $cond])     # As above, in the current file
#      break_subroutine($sub [, $cond])     # break on the first breakable line
#      ($name, $from, $to) = subroutine_filename_lines($sub)
#                                           # The range of lines of the text
#      The low-level API returns TRUE on success, and die()s on failure.
#
# Changes: 1.10: May 23, 2001  Daniel Lewart <d-lewart@uiuc.edu>
#   BUG FIXES:
#   + Fixed warnings generated by "perl -dWe 42"
#   + Corrected spelling errors
#   + Squeezed Help (h) output into 80 columns
#
# Changes: 1.11: May 24, 2001  David Dyck <dcd@tc.fluke.com>
#   + Made "x @INC" work like it used to
#
# Changes: 1.12: May 24, 2001  Daniel Lewart <d-lewart@uiuc.edu>
#   + Fixed warnings generated by "O" (Show debugger options)
#   + Fixed warnings generated by "p 42" (Print expression)
# Changes: 1.13: Jun 19, 2001 Scott.L.Miller@compaq.com
#   + Added windowSize option 
# Changes: 1.14: Oct  9, 2001 multiple
#   + Clean up after itself on VMS (Charles Lane in 12385)
#   + Adding "@ file" syntax (Peter Scott in 12014)
#   + Debug reloading selfloaded stuff (Ilya Zakharevich in 11457)
#   + $^S and other debugger fixes (Ilya Zakharevich in 11120)
#   + Forgot a my() declaration (Ilya Zakharevich in 11085)
# Changes: 1.15: Nov  6, 2001 Michael G Schwern <schwern@pobox.com>
#   + Updated 1.14 change log
#   + Added *dbline explainatory comments
#   + Mentioning perldebguts man page
# Changes: 1.16: Feb 15, 2002 Mark-Jason Dominus <mjd@plover.com>
#   + $onetimeDump improvements
# Changes: 1.17: Feb 20, 2002 Richard Foley <richard.foley@rfi.net>
#   Moved some code to cmd_[.]()'s for clarity and ease of handling,
#   rationalised the following commands and added cmd_wrapper() to 
#   enable switching between old and frighteningly consistent new 
#   behaviours for diehards: 'o CommandSet=pre580' (sigh...)
#     a(add),       A(del)            # action expr   (added del by line)
#   + b(add),       B(del)            # break  [line] (was b,D)
#   + w(add),       W(del)            # watch  expr   (was W,W) 
#                                     # added del by expr
#   + h(summary), h h(long)           # help (hh)     (was h h,h)
#   + m(methods),   M(modules)        # ...           (was m,v)
#   + o(option)                       # lc            (was O)
#   + v(view code), V(view Variables) # ...           (was w,V)
# Changes: 1.18: Mar 17, 2002 Richard Foley <richard.foley@rfi.net>
#   + fixed missing cmd_O bug
# Changes: 1.19: Mar 29, 2002 Spider Boardman
#   + Added missing local()s -- DB::DB is called recursively.
# Changes: 1.20: Feb 17, 2003 Richard Foley <richard.foley@rfi.net>
#   + pre'n'post commands no longer trashed with no args
#   + watch val joined out of eval()
# Changes: 1.21: Jun 04, 2003 Joe McMahon <mcmahon@ibiblio.org>
#   + Added comments and reformatted source. No bug fixes/enhancements.
#   + Includes cleanup by Robin Barker and Jarkko Hietaniemi.
# Changes: 1.22  Jun 09, 2003 Alex Vandiver <alexmv@MIT.EDU>
#   + Flush stdout/stderr before the debugger prompt is printed.
# Changes: 1.23: Dec 21, 2003 Dominique Quatravaux
#   + Fix a side-effect of bug #24674 in the perl debugger ("odd taint bug")

####################################################################

# Needed for the statement after exec():
#
# This BEGIN block is simply used to switch off warnings during debugger
# compiliation. Probably it would be better practice to fix the warnings,
# but this is how it's done at the moment.

BEGIN {
    $ini_warn = $^W;
    $^W       = 0;
}    # Switch compilation warnings off until another BEGIN.

local ($^W) = 0;    # Switch run-time warnings off during init.

# This would probably be better done with "use vars", but that wasn't around
# when this code was originally written. (Neither was "use strict".) And on
# the principle of not fiddling with something that was working, this was
# left alone.
warn(               # Do not ;-)
    # These variables control the execution of 'dumpvar.pl'.
    $dumpvar::hashDepth,
    $dumpvar::arrayDepth,
    $dumpvar::dumpDBFiles,
    $dumpvar::dumpPackages,
    $dumpvar::quoteHighBit,
    $dumpvar::printUndef,
    $dumpvar::globPrint,
    $dumpvar::usageOnly,

    # used to save @ARGV and extract any debugger-related flags.
    @ARGS,

    # used to control die() reporting in diesignal()
    $Carp::CarpLevel,

    # used to prevent multiple entries to diesignal()
    # (if for instance diesignal() itself dies)
    $panic,

    # used to prevent the debugger from running nonstop
    # after a restart
    $second_time,
  )
  if 0;

# Command-line + PERLLIB:
# Save the contents of @INC before they are modified elsewhere.
@ini_INC = @INC;

# This was an attempt to clear out the previous values of various
# trapped errors. Apparently it didn't help. XXX More info needed!
# $prevwarn = $prevdie = $prevbus = $prevsegv = ''; # Does not help?!

# We set these variables to safe values. We don't want to blindly turn
# off warnings, because other packages may still want them.
$trace = $signal = $single = 0;   # Uninitialized warning suppression
                                  # (local $^W cannot help - other packages!).

# Default to not exiting when program finishes; print the return
# value when the 'r' command is used to return from a subroutine.
$inhibit_exit = $option{PrintRet} = 1;

@options = qw(
             CommandSet
             hashDepth    arrayDepth    dumpDepth
             DumpDBFiles  DumpPackages  DumpReused
             compactDump  veryCompact   quote
             HighBit      undefPrint    globPrint 
             PrintRet     UsageOnly     frame
             AutoTrace    TTY           noTTY 
             ReadLine     NonStop       LineInfo 
             maxTraceLen  recallCommand ShellBang
             pager        tkRunning     ornaments
             signalLevel  warnLevel     dieLevel 
             inhibit_exit ImmediateStop bareStringify 
             CreateTTY    RemotePort    windowSize
           );

%optionVars = (
    hashDepth     => \$dumpvar::hashDepth,
    arrayDepth    => \$dumpvar::arrayDepth,
    CommandSet    => \$CommandSet,
    DumpDBFiles   => \$dumpvar::dumpDBFiles,
    DumpPackages  => \$dumpvar::dumpPackages,
    DumpReused    => \$dumpvar::dumpReused,
    HighBit       => \$dumpvar::quoteHighBit,
    undefPrint    => \$dumpvar::printUndef,
    globPrint     => \$dumpvar::globPrint,
    UsageOnly     => \$dumpvar::usageOnly,
    CreateTTY     => \$CreateTTY,
    bareStringify => \$dumpvar::bareStringify,
    frame         => \$frame,
    AutoTrace     => \$trace,
    inhibit_exit  => \$inhibit_exit,
    maxTraceLen   => \$maxtrace,
    ImmediateStop => \$ImmediateStop,
    RemotePort    => \$remoteport,
    windowSize    => \$window,
    );

%optionAction = (
    compactDump   => \&dumpvar::compactDump,
    veryCompact   => \&dumpvar::veryCompact,
    quote         => \&dumpvar::quote,
    TTY           => \&TTY,
    noTTY         => \&noTTY,
    ReadLine      => \&ReadLine,
    NonStop       => \&NonStop,
    LineInfo      => \&LineInfo,
    recallCommand => \&recallCommand,
    ShellBang     => \&shellBang,
    pager         => \&pager,
    signalLevel   => \&signalLevel,
    warnLevel     => \&warnLevel,
    dieLevel      => \&dieLevel,
    tkRunning     => \&tkRunning,
    ornaments     => \&ornaments,
    RemotePort    => \&RemotePort,
    );

# Note that this list is not complete: several options not listed here
# actually require that dumpvar.pl be loaded for them to work, but are
# not in the table. A subsequent patch will correct this problem; for
# the moment, we're just recommenting, and we are NOT going to change
# function.
%optionRequire = (
    compactDump => 'dumpvar.pl',
    veryCompact => 'dumpvar.pl',
    quote       => 'dumpvar.pl',
    );

# These guys may be defined in $ENV{PERL5DB} :
$rl          = 1     unless defined $rl;
$warnLevel   = 1     unless defined $warnLevel;
$dieLevel    = 1     unless defined $dieLevel;
$signalLevel = 1     unless defined $signalLevel;
$pre         = []    unless defined $pre;
$post        = []    unless defined $post;
$pretype     = []    unless defined $pretype;
$CreateTTY   = 3     unless defined $CreateTTY;
$CommandSet  = '580' unless defined $CommandSet;

warnLevel($warnLevel);
dieLevel($dieLevel);
signalLevel($signalLevel);

# This routine makes sure $pager is set up so that '|' can use it.
pager(
    # If PAGER is defined in the environment, use it.
    defined $ENV{PAGER} 
      ? $ENV{PAGER}

      # If not, see if Config.pm defines it.
      : eval { require Config } && defined $Config::Config{pager} 
        ? $Config::Config{pager}

      # If not, fall back to 'more'.
        : 'more'
  )
  unless defined $pager;

setman();

# Set up defaults for command recall and shell escape (note:
# these currently don't work in linemode debugging).
&recallCommand("!") unless defined $prc;
&shellBang("!")     unless defined $psh;

sethelp();

# If we didn't get a default for the length of eval/stack trace args,
# set it here.
$maxtrace = 400 unless defined $maxtrace;

# Save the current contents of the environment; we're about to 
# much with it. We'll need this if we have to restart.
$ini_pids = $ENV{PERLDB_PIDS};

if (defined $ENV{PERLDB_PIDS}) { 
    # We're a child. Make us a label out of the current PID structure
    # recorded in PERLDB_PIDS plus our (new) PID. Mark us as not having 
    # a term yet so the parent will give us one later via resetterm().
    $pids = "[$ENV{PERLDB_PIDS}]";
    $ENV{PERLDB_PIDS} .= "->$$";
    $term_pid = -1;
} ## end if (defined $ENV{PERLDB_PIDS...
else {
    # We're the parent PID. Initialize PERLDB_PID in case we end up with a 
    # child debugger, and mark us as the parent, so we'll know to set up
    # more TTY's is we have to.
    $ENV{PERLDB_PIDS} = "$$";
    $pids     = "{pid=$$}";
    $term_pid = $$;
}

$pidprompt = '';

# Sets up $emacs as a synonym for $slave_editor.
*emacs     = $slave_editor if $slave_editor;   # May be used in afterinit()...

# As noted, this test really doesn't check accurately that the debugger
# is running at a terminal or not.
if (-e "/dev/tty") {                           # this is the wrong metric!
    $rcfile = ".perldb";
}
else {
    $rcfile = "perldb.ini";
}

# This wraps a safety test around "do" to read and evaluate the init file.
#
# This isn't really safe, because there's a race
# between checking and opening.  The solution is to
# open and fstat the handle, but then you have to read and
# eval the contents.  But then the silly thing gets
# your lexical scope, which is unfortunate at best.
sub safe_do {
    my $file = shift;

    # Just exactly what part of the word "CORE::" don't you understand?
    local $SIG{__WARN__};
    local $SIG{__DIE__};

    unless (is_safe_file($file)) {
        CORE::warn <<EO_GRIPE;
perldb: Must not source insecure rcfile $file.
        You or the superuser must be the owner, and it must not 
        be writable by anyone but its owner.
EO_GRIPE
        return;
    } ## end unless (is_safe_file($file...

    do $file;
    CORE::warn("perldb: couldn't parse $file: $@") if $@;
} ## end sub safe_do

# This is the safety test itself.
#
# Verifies that owner is either real user or superuser and that no
# one but owner may write to it.  This function is of limited use
# when called on a path instead of upon a handle, because there are
# no guarantees that filename (by dirent) whose file (by ino) is
# eventually accessed is the same as the one tested. 
# Assumes that the file's existence is not in doubt.
sub is_safe_file {
    my $path = shift;
    stat($path) || return;    # mysteriously vaporized
    my ($dev, $ino, $mode, $nlink, $uid, $gid) = stat(_);

    return 0 if $uid != 0 && $uid != $<;
    return 0 if $mode & 022;
    return 1;
} ## end sub is_safe_file

# If the rcfile (whichever one we decided was the right one to read)
# exists, we safely do it. 
if (-f $rcfile) {
    safe_do("./$rcfile");
}
# If there isn't one here, try the user's home directory.
elsif (defined $ENV{HOME} && -f "$ENV{HOME}/$rcfile") {
    safe_do("$ENV{HOME}/$rcfile");
}
# Else try the login directory.
elsif (defined $ENV{LOGDIR} && -f "$ENV{LOGDIR}/$rcfile") {
    safe_do("$ENV{LOGDIR}/$rcfile");
}

# If the PERLDB_OPTS variable has options in it, parse those out next.
if (defined $ENV{PERLDB_OPTS}) {
    parse_options($ENV{PERLDB_OPTS});
}

# Set up the get_fork_TTY subroutine to be aliased to the proper routine.
# Works if you're running an xterm or xterm-like window, or you're on
# OS/2. This may need some expansion: for instance, this doesn't handle
# OS X Terminal windows.       

if (not defined &get_fork_TTY                        # no routine exists,
    and defined $ENV{TERM}                           # and we know what kind
                                                     # of terminal this is,
    and $ENV{TERM} eq 'xterm'                        # and it's an xterm,
    and defined $ENV{WINDOWID}                       # and we know what
                                                     # window this is,
    and defined $ENV{DISPLAY})                       # and what display it's
                                                     # on,
{
    *get_fork_TTY = \&xterm_get_fork_TTY;            # use the xterm version
} ## end if (not defined &get_fork_TTY...
elsif ($^O eq 'os2') {                               # If this is OS/2,
    *get_fork_TTY = \&os2_get_fork_TTY;              # use the OS/2 version
}
# untaint $^O, which may have been tainted by the last statement.
# see bug [perl #24674]
$^O =~ m/^(.*)\z/; $^O = $1;

# "Here begin the unreadable code.  It needs fixing." 

if (exists $ENV{PERLDB_RESTART}) {
    # We're restarting, so we don't need the flag that says to restart anymore.
    delete $ENV{PERLDB_RESTART};
    # $restart = 1;
    @hist          = get_list('PERLDB_HIST');
    %break_on_load = get_list("PERLDB_ON_LOAD");
    %postponed     = get_list("PERLDB_POSTPONE");

    # restore breakpoints/actions
    my @had_breakpoints = get_list("PERLDB_VISITED");
    for (0 .. $#had_breakpoints) {
        my %pf = get_list("PERLDB_FILE_$_");
        $postponed_file{ $had_breakpoints[$_] } = \%pf if %pf;
    }

    # restore options
    my %opt = get_list("PERLDB_OPT");
    my ($opt, $val);
    while (($opt, $val) = each %opt) {
        $val =~ s/[\\\']/\\$1/g;
        parse_options("$opt'$val'");
    }

    # restore original @INC
    @INC       = get_list("PERLDB_INC");
    @ini_INC   = @INC;

    # return pre/postprompt actions and typeahead buffer
    $pretype   = [get_list("PERLDB_PRETYPE")];
    $pre       = [get_list("PERLDB_PRE")];
    $post      = [get_list("PERLDB_POST")];
    @typeahead = get_list("PERLDB_TYPEAHEAD", @typeahead);
} ## end if (exists $ENV{PERLDB_RESTART...

if ($notty) {
    $runnonstop = 1;
}

else {
    # Is Perl being run from a slave editor or graphical debugger?
    # If so, don't use readline, and set $slave_editor = 1.
    $slave_editor =
      ((defined $main::ARGV[0]) and ($main::ARGV[0] eq '-emacs'));
    $rl = 0, shift (@main::ARGV) if $slave_editor;
    #require Term::ReadLine;


    if ($^O eq 'cygwin') {
        # /dev/tty is binary. use stdin for textmode
        undef $console;
    }

    elsif (-e "/dev/tty") {
        $console = "/dev/tty";
    }

    elsif ($^O eq 'dos' or -e "con" or $^O eq 'MSWin32') {
        $console = "con";
    }

    elsif ($^O eq 'MacOS') {
        if ($MacPerl::Version !~ /MPW/) {
            $console =
              "Dev:Console:Perl Debug";    # Separate window for application
        }
        else {
            $console = "Dev:Console";
        }
    } ## end elsif ($^O eq 'MacOS')

    else {
        # everything else is ...
        $console = "sys\$command";
    }

    if (($^O eq 'MSWin32') and ($slave_editor or defined $ENV{EMACS})) {
        # /dev/tty is binary. use stdin for textmode
        $console = undef;
    }

    if ($^O eq 'NetWare') {
        # /dev/tty is binary. use stdin for textmode
        $console = undef;
    }

    # In OS/2, we need to use STDIN to get textmode too, even though
    # it pretty much looks like Unix otherwise.
    if (defined $ENV{OS2_SHELL} and ($slave_editor or $ENV{WINDOWID}))
    {    # In OS/2
        $console = undef;
    }
    # EPOC also falls into the 'got to use STDIN' camp.
    if ($^O eq 'epoc') {
        $console = undef;
    }

    $console = $tty if defined $tty;

    # Handle socket stuff.
    if (defined $remoteport) {
        # If RemotePort was defined in the options, connect input and output
        # to the socket.
        require IO::Socket;
        $OUT = new IO::Socket::INET(
            Timeout  => '10',
            PeerAddr => $remoteport,
            Proto    => 'tcp',
            );
        if (!$OUT) { die "Unable to connect to remote host: $remoteport\n"; }
        $IN = $OUT;
    } ## end if (defined $remoteport)

    # Non-socket.
    else {
        # Two debuggers running (probably a system or a backtick that invokes
        # the debugger itself under the running one). create a new IN and OUT
        # filehandle, and do the necessary mojo to create a new tty if we 
        # know how, and we can.
        create_IN_OUT(4) if $CreateTTY & 4;
        if ($console) {
            # If we have a console, check to see if there are separate ins and
            # outs to open. (They are assumed identiical if not.)
            my ($i, $o) = split /,/, $console;
            $o = $i unless defined $o;

            # read/write on in, or just read, or read on STDIN.
            open(IN, "+<$i") || 
             open(IN, "<$i") || 
              open(IN, "<&STDIN");

            # read/write/create/clobber out, or write/create/clobber out,
            # or merge with STDERR, or merge with STDOUT.
            open(OUT,   "+>$o")     ||
              open(OUT, ">$o")      ||
              open(OUT, ">&STDERR") ||
              open(OUT, ">&STDOUT");    # so we don't dongle stdout

        } ## end if ($console)
        elsif (not defined $console) {
           # No console. Open STDIN.
            open(IN,    "<&STDIN");

           # merge with STDERR, or with STDOUT.
            open(OUT,   ">&STDERR") ||
              open(OUT, ">&STDOUT");     # so we don't dongle stdout

            $console = 'STDIN/OUT';
        } ## end elsif (not defined $console)

        # Keep copies of the filehandles so that when the pager runs, it
        # can close standard input without clobbering ours.
        $IN = \*IN, $OUT = \*OUT if $console or not defined $console;
    } ## end elsif (from if(defined $remoteport))

    # Unbuffer DB::OUT. We need to see responses right away. 
    my $previous = select($OUT);
    $| = 1;                              # for DB::OUT
    select($previous);

    # Line info goes to debugger output unless pointed elsewhere.
    # Pointing elsewhere makes it possible for slave editors to
    # keep track of file and position. We have both a filehandle 
    # and a I/O description to keep track of.
    $LINEINFO = $OUT     unless defined $LINEINFO;
    $lineinfo = $console unless defined $lineinfo;

    # Show the debugger greeting.
    $header =~ s/.Header: ([^,]+),v(\s+\S+\s+\S+).*$/$1$2/;
    unless ($runnonstop) {
        local $\ = '';
        local $, = '';
        if ($term_pid eq '-1') {
            print $OUT "\nDaughter DB session started...\n";
        }
        else {
            print $OUT "\nLoading DB routines from $header\n";
            print $OUT (
                "Editor support ",
                $slave_editor ? "enabled" : "available", ".\n"
                );
            print $OUT
"\nEnter h or `h h' for help, or `$doccmd perldebug' for more help.\n\n";
        } ## end else [ if ($term_pid eq '-1')
    } ## end unless ($runnonstop)
} ## end else [ if ($notty)

# XXX This looks like a bug to me.
# Why copy to @ARGS and then futz with @args?
@ARGS = @ARGV;
for (@args) {
    # Make sure backslashes before single quotes are stripped out, and
    # keep args unless they are numeric (XXX why?)
    s/\'/\\\'/g;
    s/(.*)/'$1'/ unless /^-?[\d.]+$/;
}

# If there was an afterinit() sub defined, call it. It will get 
# executed in our scope, so it can fiddle with debugger globals.
if (defined &afterinit) {    # May be defined in $rcfile
    &afterinit();
}
# Inform us about "Stack dump during die enabled ..." in dieLevel().
$I_m_init = 1;

############################################################ Subroutines

sub DB {

    # Check for whether we should be running continuously or not.
    # _After_ the perl program is compiled, $single is set to 1:
    if ($single and not $second_time++) {
        # Options say run non-stop. Run until we get an interrupt.
        if ($runnonstop) {    # Disable until signal
            # If there's any call stack in place, turn off single
            # stepping into subs throughout the stack.
            for ($i = 0 ; $i <= $stack_depth ;) {
                $stack[$i++] &= ~1;
            }
            # And we are now no longer in single-step mode.
            $single = 0;

            # If we simply returned at this point, we wouldn't get
            # the trace info. Fall on through.
            # return; 
        } ## end if ($runnonstop)

        elsif ($ImmediateStop) {
            # We are supposed to stop here; XXX probably a break. 
            $ImmediateStop = 0;               # We've processed it; turn it off
            $signal        = 1;               # Simulate an interrupt to force
                                              # us into the command loop
        }
    } ## end if ($single and not $second_time...

    # If we're in single-step mode, or an interrupt (real or fake)
    # has occurred, turn off non-stop mode.
    $runnonstop = 0 if $single or $signal;

    # Preserve current values of $@, $!, $^E, $,, $/, $\, $^W.
    # The code being debugged may have altered them.
    &save;

    # Since DB::DB gets called after every line, we can use caller() to
    # figure out where we last were executing. Sneaky, eh? This works because
    # caller is returning all the extra information when called from the 
    # debugger.
    local ($package, $filename, $line) = caller;
    local $filename_ini = $filename;

    # set up the context for DB::eval, so it can properly execute
    # code on behalf of the user. We add the package in so that the
    # code is eval'ed in the proper package (not in the debugger!).
    local $usercontext  =
      '($@, $!, $^E, $,, $/, $\, $^W) = @saved;' .
      "package $package;"; 

    # Create an alias to the active file magical array to simplify
    # the code here.
    local (*dbline) = $main::{ '_<' . $filename };

    # we need to check for pseudofiles on Mac OS (these are files
    # not attached to a filename, but instead stored in Dev:Pseudo)
    if ($^O eq 'MacOS' && $#dbline < 0) {
        $filename_ini = $filename = 'Dev:Pseudo';
        *dbline = $main::{ '_<' . $filename };
    }

    # Last line in the program.
    local $max = $#dbline;

    # if we have something here, see if we should break.
    if ($dbline{$line} && (($stop, $action) = split (/\0/, $dbline{$line}))) {
        # Stop if the stop criterion says to just stop.
        if ($stop eq '1') {
            $signal |= 1;
        }
        # It's a conditional stop; eval it in the user's context and
        # see if we should stop. If so, remove the one-time sigil.
        elsif ($stop) {
            $evalarg = "\$DB::signal |= 1 if do {$stop}";
            &eval;
            $dbline{$line} =~ s/;9($|\0)/$1/;
        }
    } ## end if ($dbline{$line} && ...

    # Preserve the current stop-or-not, and see if any of the W
    # (watch expressions) has changed.
    my $was_signal = $signal;

    # If we have any watch expressions ...
    if ($trace & 2) {
        for (my $n = 0 ; $n <= $#to_watch ; $n++) {
            $evalarg = $to_watch[$n];
            local $onetimeDump;    # Tell DB::eval() to not output results

            # Fix context DB::eval() wants to return an array, but
            # we need a scalar here.
            my ($val) =
              join ( "', '", &eval );
            $val = ((defined $val) ? "'$val'" : 'undef');

            # Did it change?
            if ($val ne $old_watch[$n]) {
                # Yep! Show the difference, and fake an interrupt.
                $signal = 1;
                print $OUT <<EOP;
Watchpoint $n:\t$to_watch[$n] changed:
	old value:\t$old_watch[$n]
	new value:\t$val
EOP
                $old_watch[$n] = $val;
            } ## end if ($val ne $old_watch...
        } ## end for (my $n = 0 ; $n <= ...
    } ## end if ($trace & 2)

    # If there's a user-defined DB::watchfunction, call it with the 
    # current package, filename, and line. The function executes in
    # the DB:: package.
    if ($trace & 4) {    # User-installed watch
        return
          if watchfunction($package, $filename, $line)
          and not $single
          and not $was_signal
          and not($trace & ~4);
    } ## end if ($trace & 4)


    # Pick up any alteration to $signal in the watchfunction, and 
    # turn off the signal now.
    $was_signal = $signal;
    $signal     = 0;

    # Check to see if we should grab control ($single true,
    # trace set appropriately, or we got a signal).
    if ($single || ($trace & 1) || $was_signal) {
        # Yes, grab control.
        if ($slave_editor) {
            # Tell the editor to update its position.
            $position = "\032\032$filename:$line:0\n";
            print_lineinfo($position);
        }

        elsif ($package eq 'DB::fake') {
            # Fallen off the end already.
            $term || &setterm;
            print_help(<<EOP);
Debugged program terminated.  Use B<q> to quit or B<R> to restart,
  use B<O> I<inhibit_exit> to avoid stopping after program termination,
  B<h q>, B<h R> or B<h O> to get additional info.  
EOP

            # Set the DB::eval context appropriately.
            $package     = 'main';
            $usercontext =
              '($@, $!, $^E, $,, $/, $\, $^W) = @saved;' .
              "package $package;";    # this won't let them modify, alas
        } ## end elsif ($package eq 'DB::fake')

        else {
            # Still somewhere in the midst of execution. Set up the
            #  debugger prompt.
            $sub =~ s/\'/::/;    # Swap Perl 4 package separators (') to
                                 # Perl 5 ones (sorry, we don't print Klingon 
                                 #module names)

            $prefix = $sub =~ /::/ ? "" : "${'package'}::";
            $prefix .= "$sub($filename:";
            $after = ($dbline[$line] =~ /\n$/ ? '' : "\n");

            # Break up the prompt if it's really long.
            if (length($prefix) > 30) {
                $position = "$prefix$line):\n$line:\t$dbline[$line]$after";
                $prefix   = "";
                $infix    = ":\t";
            }
            else {
                $infix    = "):\t";
                $position = "$prefix$line$infix$dbline[$line]$after";
            }

            # Print current line info, indenting if necessary.
            if ($frame) {
                print_lineinfo(' ' x $stack_depth,
                    "$line:\t$dbline[$line]$after");
            }
            else {
                print_lineinfo($position);
            }

            # Scan forward, stopping at either the end or the next
            # unbreakable line.
            for ($i = $line + 1 ; $i <= $max && $dbline[$i] == 0 ; ++$i)
            {    #{ vi

                # Drop out on null statements, block closers, and comments.
                last if $dbline[$i] =~ /^\s*[\;\}\#\n]/;

                # Drop out if the user interrupted us.
                last if $signal;
               
                # Append a newline if the line doesn't have one. Can happen
                # in eval'ed text, for instance.
                $after = ($dbline[$i] =~ /\n$/ ? '' : "\n");

                # Next executable line.
                $incr_pos = "$prefix$i$infix$dbline[$i]$after";
                $position .= $incr_pos;
                if ($frame) {
                    # Print it indented if tracing is on.
                    print_lineinfo(' ' x $stack_depth,
                        "$i:\t$dbline[$i]$after");
                }
                else {
                    print_lineinfo($incr_pos);
                }
            } ## end for ($i = $line + 1 ; $i...
        } ## end else [ if ($slave_editor)
    } ## end if ($single || ($trace...

    # If there's an action, do it now.
    $evalarg = $action, &eval if $action;

    # Are we nested another level (e.g., did we evaluate a function
    # that had a breakpoint in it at the debugger prompt)?
    if ($single || $was_signal) {
        # Yes, go down a level.
        local $level = $level + 1;

        # Do any pre-prompt actions.
        foreach $evalarg (@$pre) {
            &eval;
        }

        # Complain about too much recursion if we passed the limit.
        print $OUT $stack_depth . " levels deep in subroutine calls!\n"
          if $single & 4;

        # The line we're currently on. Set $incr to -1 to stay here
        # until we get a command that tells us to advance.
        $start     = $line;
        $incr      = -1;                        # for backward motion.

        # Tack preprompt debugger actions ahead of any actual input.
        @typeahead = (@$pretype, @typeahead);

        # The big command dispatch loop. It keeps running until the
        # user yields up control again.
        #
        # If we have a terminal for input, and we get something back
        # from readline(), keep on processing.
      CMD:
        while (
            # We have a terminal, or can get one ...
            ($term || &setterm),
            # ... and it belogs to this PID or we get one for this PID ...
            ($term_pid == $$ or resetterm(1)),
            # ... and we got a line of command input ...
            defined(
                $cmd = &readline(
                    "$pidprompt  DB" . ('<' x $level) . ($#hist + 1) .
                      ('>' x $level) . " "
                )
            )
          )
        {
            # ... try to execute the input as debugger commands.

            # Don't stop running.
            $single = 0;

            # No signal is active.
            $signal = 0;

            # Handle continued commands (ending with \):
            $cmd =~ s/\\$/\n/ && do {
                $cmd .= &readline("  cont: ");
                redo CMD;
            };

            # Empty input means repeat the last command.
            $cmd =~ /^$/ && ($cmd = $laststep);
            push (@hist, $cmd) if length($cmd) > 1;


          # This is a restart point for commands that didn't arrive
          # via direct user input. It allows us to 'redo PIPE' to
          # re-execute command processing without reading a new command.
          PIPE: {
                $cmd =~ s/^\s+//s;    # trim annoying leading whitespace
                $cmd =~ s/\s+$//s;    # trim annoying trailing whitespace
                ($i) = split (/\s+/, $cmd);

                # See if there's an alias for the command, and set it up if so.
                if ($alias{$i}) {
                    # Squelch signal handling; we want to keep control here
                    # if something goes loco during the alias eval.
                    local $SIG{__DIE__};
                    local $SIG{__WARN__};

                    # This is a command, so we eval it in the DEBUGGER's
                    # scope! Otherwise, we can't see the special debugger
                    # variables, or get to the debugger's subs. (Well, we
                    # _could_, but why make it even more complicated?)
                    eval "\$cmd =~ $alias{$i}";
                    if ($@) {
                        local $\ = '';
                        print $OUT "Couldn't evaluate `$i' alias: $@";
                        next CMD;
                    }
                } ## end if ($alias{$i})

                $cmd =~ /^q$/ && do {
                    $fall_off_end = 1;
                    clean_ENV();
                    exit $?;
                };

                $cmd =~ /^t$/ && do {
                    $trace ^= 1;
                    local $\ = '';
                    print $OUT "Trace = " . (($trace & 1) ? "on" : "off") .
                      "\n";
                    next CMD;
                };

                $cmd =~ /^S(\s+(!)?(.+))?$/ && do {

                    $Srev     = defined $2;     # Reverse scan? 
                    $Spatt    = $3;             # The pattern (if any) to use.
                    $Snocheck = !defined $1;    # No args - print all subs.

                    # Need to make these sane here.
                    local $\ = '';
                    local $, = '';

                    # Search through the debugger's magical hash of subs.
                    # If $nocheck is true, just print the sub name.
                    # Otherwise, check it against the pattern. We then use
                    # the XOR trick to reverse the condition as required.
                    foreach $subname (sort(keys %sub)) {
                        if ($Snocheck or $Srev ^ ($subname =~ /$Spatt/)) {
                            print $OUT $subname, "\n";
                        }
                    }
                    next CMD;
                };

                $cmd =~ s/^X\b/V $package/;

                # Bare V commands get the currently-being-debugged package
                # added.
                $cmd =~ /^V$/ && do {
                    $cmd = "V $package";
                };


                # V - show variables in package.
                $cmd =~ /^V\b\s*(\S+)\s*(.*)/ && do {
                    # Save the currently selected filehandle and
                    # force output to debugger's filehandle (dumpvar
                    # just does "print" for output).
                    local ($savout) = select($OUT);

                    # Grab package name and variables to dump.
                    $packname = $1;
                    @vars = split (' ', $2);

                    # If main::dumpvar isn't here, get it.
                    do 'dumpvar.pl' unless defined &main::dumpvar;
                    if (defined &main::dumpvar) {
                        # We got it. Turn off subroutine entry/exit messages
                        # for the moment, along with return values.
                        local $frame = 0;
                        local $doret = -2;

                        # must detect sigpipe failures  - not catching
                        # then will cause the debugger to die.
                        eval {
                            &main::dumpvar(
                                $packname,
                                defined $option{dumpDepth}
                                ? $option{dumpDepth}
                                : -1,          # assume -1 unless specified
                                @vars
                                );
                        };

                        # The die doesn't need to include the $@, because 
                        # it will automatically get propagated for us.
                        if ($@) {
                            die unless $@ =~ /dumpvar print failed/;
                        }
                    } ## end if (defined &main::dumpvar)
                    else {
                        # Couldn't load dumpvar.
                        print $OUT "dumpvar.pl not available.\n";
                    }
                    # Restore the output filehandle, and go round again.
                    select($savout);
                    next CMD;
                };

                $cmd =~ s/^x\b/ / && do {   # Remainder gets done by DB::eval()
                    $onetimeDump = 'dump';  # main::dumpvar shows the output

                    # handle special  "x 3 blah" syntax XXX propagate
                    # doc back to special variables.
                    if ($cmd =~ s/^\s*(\d+)(?=\s)/ /) {
                        $onetimedumpDepth = $1;
                    }
                };

                $cmd =~ s/^m\s+([\w:]+)\s*$/ / && do {
                    methods($1);
                    next CMD;
                };

                # m expr - set up DB::eval to do the work
                $cmd =~ s/^m\b/ / && do {     # Rest gets done by DB::eval()
                    $onetimeDump = 'methods'; #  method output gets used there
                };

                $cmd =~ /^f\b\s*(.*)/ && do {
                    $file = $1;
                    $file =~ s/\s+$//;

                    # help for no arguments (old-style was return from sub).
                    if (!$file) {
                        print $OUT
                          "The old f command is now the r command.\n";  # hint
                        print $OUT "The new f command switches filenames.\n";
                        next CMD;
                    } ## end if (!$file)

                    # if not in magic file list, try a close match.
                    if (!defined $main::{ '_<' . $file }) {
                        if (($try) = grep(m#^_<.*$file#, keys %main::)) {
                            {
                                $try = substr($try, 2);
                                print $OUT
                                  "Choosing $try matching `$file':\n";
                                $file = $try;
                            }
                        } ## end if (($try) = grep(m#^_<.*$file#...
                    } ## end if (!defined $main::{ ...

                    # If not successfully switched now, we failed.
                    if (!defined $main::{ '_<' . $file }) {
                        print $OUT "No file matching `$file' is loaded.\n";
                        next CMD;
                    }

                    # We switched, so switch the debugger internals around.
                    elsif ($file ne $filename) {
                        *dbline   = $main::{ '_<' . $file };
                        $max      = $#dbline;
                        $filename = $file;
                        $start    = 1;
                        $cmd      = "l";
                    } ## end elsif ($file ne $filename)

                    # We didn't switch; say we didn't.
                    else {
                        print $OUT "Already in $file.\n";
                        next CMD;
                    }
                };

                # . command.
                $cmd =~ /^\.$/ && do {
                    $incr     = -1;              # stay at current line

                    # Reset everything to the old location.
                    $start    = $line;
                    $filename = $filename_ini;
                    *dbline = $main::{ '_<' . $filename };
                    $max    = $#dbline;

                    # Now where are we?
                    print_lineinfo($position);
                    next CMD;
                };

                # - - back a window.
                $cmd =~ /^-$/ && do {
                    # back up by a window; go to 1 if back too far.
                    $start -= $incr + $window + 1;
                    $start = 1 if $start <= 0;
                    $incr = $window - 1;

                    # Generate and execute a "l +" command (handled below).
                    $cmd = 'l ' . ($start) . '+';
                };

                # All of these commands were remapped in perl 5.8.0;
                # we send them off to the secondary dispatcher (see below). 
                $cmd =~ /^([aAbBhlLMoOvwW]\b|[<>\{]{1,2})\s*(.*)/so && do {
                    &cmd_wrapper($1, $2, $line);
                    next CMD;
                };

                $cmd =~ /^y(?:\s+(\d*)\s*(.*))?$/ && do {

                    # See if we've got the necessary support.
                    eval { require PadWalker; PadWalker->VERSION(0.08) }
                      or &warn(
                        $@ =~ /locate/
                        ? "PadWalker module not found - please install\n"
                        : $@
                      )
                      and next CMD;

                    # Load up dumpvar if we don't have it. If we can, that is.
                    do 'dumpvar.pl' unless defined &main::dumpvar;
                    defined &main::dumpvar
                      or print $OUT "dumpvar.pl not available.\n"
                      and next CMD;

                    # Got all the modules we need. Find them and print them.
                    my @vars = split (' ', $2 || '');

                    # Find the pad.
                    my $h = eval { PadWalker::peek_my(($1 || 0) + 1) };

                    # Oops. Can't find it.
                    $@ and $@ =~ s/ at .*//, &warn($@), next CMD;

                    # Show the desired vars with dumplex().
                    my $savout = select($OUT);

                    # Have dumplex dump the lexicals.
                    dumpvar::dumplex(
                        $_,
                        $h->{$_},
                        defined $option{dumpDepth} ? $option{dumpDepth} : -1,
                        @vars
                    ) for sort keys %$h;
                    select($savout);
                    next CMD;
                };

                # n - next 
                $cmd =~ /^n$/ && do {
                    end_report(), next CMD if $finished and $level <= 1;
                    # Single step, but don't enter subs.
                    $single   = 2;
                    # Save for empty command (repeat last).
                    $laststep = $cmd;
                    last CMD;
                };

                # s - single step.
                $cmd =~ /^s$/ && do {
                    # Get out and restart the command loop if program
                    # has finished.
                    end_report(), next CMD if $finished and $level <= 1;
                    # Single step should enter subs.
                    $single   = 1;
                    # Save for empty command (repeat last).
                    $laststep = $cmd;
                    last CMD;
                };

                # c - start continuous execution.
                $cmd =~ /^c\b\s*([\w:]*)\s*$/ && do {
                    # Hey, show's over. The debugged program finished
                    # executing already.
                    end_report(), next CMD if $finished and $level <= 1;

                    # Capture the place to put a one-time break.
                    $subname = $i = $1;

                    #  Probably not needed, since we finish an interactive
                    #  sub-session anyway...
                    # local $filename = $filename;
                    # local *dbline = *dbline; # XXX Would this work?!
                    #
                    # The above question wonders if localizing the alias
                    # to the magic array works or not. Since it's commented
                    # out, we'll just leave that to speculation for now.

                    # If the "subname" isn't all digits, we'll assume it
                    # is a subroutine name, and try to find it.
                    if ($subname =~ /\D/) {    # subroutine name
                        # Qualify it to the current package unless it's
                        # already qualified.
                        $subname = $package . "::" . $subname
                          unless $subname =~ /::/;
                        # find_sub will return "file:line_number" corresponding
                        # to where the subroutine is defined; we call find_sub,
                        # break up the return value, and assign it in one 
                        # operation.
                        ($file, $i) = (find_sub($subname) =~ /^(.*):(.*)$/);

                        # Force the line number to be numeric.
                        $i += 0;

                        # If we got a line number, we found the sub.
                        if ($i) {
                            # Switch all the debugger's internals around so
                            # we're actually working with that file.
                            $filename = $file;
                            *dbline   = $main::{ '_<' . $filename };
                            # Mark that there's a breakpoint in this file.
                            $had_breakpoints{$filename} |= 1;
                            # Scan forward to the first executable line
                            # after the 'sub whatever' line.
                            $max = $#dbline;
                            ++$i while $dbline[$i] == 0 && $i < $max;
                        } ## end if ($i)

                        # We didn't find a sub by that name.
                        else {
                            print $OUT "Subroutine $subname not found.\n";
                            next CMD;
                        }
                    } ## end if ($subname =~ /\D/)

                    # At this point, either the subname was all digits (an
                    # absolute line-break request) or we've scanned through
                    # the code following the definition of the sub, looking
                    # for an executable, which we may or may not have found.
                    #
                    # If $i (which we set $subname from) is non-zero, we
                    # got a request to break at some line somewhere. On 
                    # one hand, if there wasn't any real subroutine name 
                    # involved, this will be a request to break in the current 
                    # file at the specified line, so we have to check to make 
                    # sure that the line specified really is breakable.
                    #
                    # On the other hand, if there was a subname supplied, the
                    # preceeding block has moved us to the proper file and
                    # location within that file, and then scanned forward
                    # looking for the next executable line. We have to make
                    # sure that one was found.
                    #
                    # On the gripping hand, we can't do anything unless the
                    # current value of $i points to a valid breakable line.
                    # Check that.
                    if ($i) {
                        # Breakable?
                        if ($dbline[$i] == 0) {
                            print $OUT "Line $i not breakable.\n";
                            next CMD;
                        }
                        # Yes. Set up the one-time-break sigil.
                        $dbline{$i} =~
                          s/($|\0)/;9$1/;    # add one-time-only b.p.
                    } ## end if ($i)

                    # Turn off stack tracing from here up.
                    for ($i = 0 ; $i <= $stack_depth ;) {
                        $stack[$i++] &= ~1;
                    }
                    last CMD;
                };

                # r - return from the current subroutine.
                $cmd =~ /^r$/ && do {
                    # Can't do anythign if the program's over.
                    end_report(), next CMD if $finished and $level <= 1;
                    # Turn on stack trace.
                    $stack[$stack_depth] |= 1;
                    # Print return value unless the stack is empty.
                    $doret = $option{PrintRet} ? $stack_depth - 1 : -2;
                    last CMD;
                };

                # R - restart execution.
                $cmd =~ /^R$/ && do {
                    # I may not be able to resurrect you, but here goes ...
                    print $OUT
"Warning: some settings and command-line options may be lost!\n";
                    my (@script, @flags, $cl);

                    # If warn was on before, turn it on again.
                    push @flags, '-w' if $ini_warn;

                    # Rebuild the -I flags that were on the initial
                    # command line.
                    for (@ini_INC) {
                        push @flags, '-I', $_;
                    }

                    # Turn on taint if it was on before.
                    push @flags, '-T' if ${^TAINT};

                    # Arrange for setting the old INC:
                    # Save the current @init_INC in the environment.
                    set_list("PERLDB_INC", @ini_INC);

                    # If this was a perl one-liner, go to the "file"
                    # corresponding to the one-liner read all the lines
                    # out of it (except for the first one, which is going
                    # to be added back on again when 'perl -d' runs: that's
                    # the 'require perl5db.pl;' line), and add them back on
                    # to the command line to be executed.
                    if ($0 eq '-e') {
                        for (1 .. $#{'::_<-e'}) {  # The first line is PERL5DB
                            chomp($cl = ${'::_<-e'}[$_]);
                            push @script, '-e', $cl;
                        }
                    } ## end if ($0 eq '-e')

                    # Otherwise we just reuse the original name we had 
                    # before.
                    else {
                        @script = $0;
                    }

                    # If the terminal supported history, grab it and
                    # save that in the environment.
                    set_list("PERLDB_HIST",
                        $term->Features->{getHistory}
                        ? $term->GetHistory
                        : @hist);
                    # Find all the files that were visited during this
                    # session (i.e., the debugger had magic hashes
                    # corresponding to them) and stick them in the environment.
                    my @had_breakpoints = keys %had_breakpoints;
                    set_list("PERLDB_VISITED", @had_breakpoints);

                    # Save the debugger options we chose.
                    set_list("PERLDB_OPT",     %option);

                    # Save the break-on-loads.
                    set_list("PERLDB_ON_LOAD", %break_on_load);

                    # Go through all the breakpoints and make sure they're
                    # still valid.
                    my @hard;
                    for (0 .. $#had_breakpoints) {
                        # We were in this file.
                        my $file = $had_breakpoints[$_];

                        # Grab that file's magic line hash.
                        *dbline = $main::{ '_<' . $file };

                        # Skip out if it doesn't exist, or if the breakpoint
                        # is in a postponed file (we'll do postponed ones 
                        # later).
                        next unless %dbline or $postponed_file{$file};

                        # In an eval. This is a little harder, so we'll
                        # do more processing on that below.
                        (push @hard, $file), next
                          if $file =~ /^\(\w*eval/;
                        # XXX I have no idea what this is doing. Yet. 
                        my @add;
                        @add = %{ $postponed_file{$file} }
                          if $postponed_file{$file};

                        # Save the list of all the breakpoints for this file.
                        set_list("PERLDB_FILE_$_", %dbline, @add);
                    } ## end for (0 .. $#had_breakpoints)

                    # The breakpoint was inside an eval. This is a little
                    # more difficult. XXX and I don't understand it.
                    for (@hard) {    
                        # Get over to the eval in question.
                        *dbline = $main::{ '_<' . $_ };
                        my ($quoted, $sub, %subs, $line) = quotemeta $_;
                        for $sub (keys %sub) {
                            next unless $sub{$sub} =~ /^$quoted:(\d+)-(\d+)$/;
                            $subs{$sub} = [$1, $2];
                        }
                        unless (%subs) {
                            print $OUT
                              "No subroutines in $_, ignoring breakpoints.\n";
                            next;
                        }
                      LINES: for $line (keys %dbline) {

                            # One breakpoint per sub only:
                            my ($offset, $sub, $found);
                          SUBS: for $sub (keys %subs) {
                                if (
                                    $subs{$sub}->[1] >=
                                    $line    # Not after the subroutine
                                    and (
                                        not defined $offset    # Not caught
                                        or $offset < 0
                                    )
                                  )
                                {    # or badly caught
                                    $found  = $sub;
                                    $offset = $line - $subs{$sub}->[0];
                                    $offset = "+$offset", last SUBS
                                      if $offset >= 0;
                                } ## end if ($subs{$sub}->[1] >=...
                            } ## end for $sub (keys %subs)
                            if (defined $offset) {
                                $postponed{$found} =
                                  "break $offset if $dbline{$line}";
                            }
                            else {
                                print $OUT
"Breakpoint in $_:$line ignored: after all the subroutines.\n";
                            }
                        } ## end for $line (keys %dbline)
                    } ## end for (@hard)

                    # Save the other things that don't need to be 
                    # processed.
                    set_list("PERLDB_POSTPONE",  %postponed);
                    set_list("PERLDB_PRETYPE",   @$pretype);
                    set_list("PERLDB_PRE",       @$pre);
                    set_list("PERLDB_POST",      @$post);
                    set_list("PERLDB_TYPEAHEAD", @typeahead);

                    # We are oficially restarting.
                    $ENV{PERLDB_RESTART} = 1;

                    # We are junking all child debuggers.
                    delete $ENV{PERLDB_PIDS};    # Restore ini state

                    # Set this back to the initial pid.
                    $ENV{PERLDB_PIDS} = $ini_pids if defined $ini_pids;

                    # And run Perl again. Add the "-d" flag, all the 
                    # flags we built up, the script (whether a one-liner
                    # or a file), add on the -emacs flag for a slave editor,
                    # and then the old arguments. We use exec() to keep the
                    # PID stable (and that way $ini_pids is still valid).
                    exec($^X, '-d', @flags, @script,
                        ($slave_editor ? '-emacs' : ()), @ARGS) ||
                      print $OUT "exec failed: $!\n";
                    last CMD;
                };

                $cmd =~ /^T$/ && do {
                    print_trace($OUT, 1);        # skip DB
                    next CMD;
                };

                $cmd =~ /^w\b\s*(.*)/s && do { &cmd_w('w', $1); next CMD; };

                $cmd =~ /^W\b\s*(.*)/s && do { &cmd_W('W', $1); next CMD; };

                $cmd =~ /^\/(.*)$/     && do {

                    # The pattern as a string.
                    $inpat = $1;

                    # Remove the final slash.
                    $inpat =~ s:([^\\])/$:$1:;

                    # If the pattern isn't null ...
                    if ($inpat ne "") {

                        # Turn of warn and die procesing for a bit.
                        local $SIG{__DIE__};
                        local $SIG{__WARN__};

                        # Create the pattern.
                        eval '$inpat =~ m' . "\a$inpat\a";
                        if ($@ ne "") {
                            # Oops. Bad pattern. No biscuit.
                            # Print the eval error and go back for more 
                            # commands.
                            print $OUT "$@";
                            next CMD;
                        }
                        $pat = $inpat;
                    } ## end if ($inpat ne "")

                    # Set up to stop on wrap-around.
                    $end  = $start;

                    # Don't move off the current line.
                    $incr = -1;

                    # Done in eval so nothing breaks if the pattern
                    # does something weird.
                    eval '
                        for (;;) {
                            # Move ahead one line.
                            ++$start;

                            # Wrap if we pass the last line.
                            $start = 1 if ($start > $max);

                            # Stop if we have gotten back to this line again,
                            last if ($start == $end);

                            # A hit! (Note, though, that we are doing
                            # case-insensitive matching. Maybe a qr//
                            # expression would be better, so the user could
                            # do case-sensitive matching if desired.
                            if ($dbline[$start] =~ m' . "\a$pat\a" . 'i) {
                                if ($slave_editor) {
                                    # Handle proper escaping in the slave.
                                    print $OUT "\032\032$filename:$start:0\n";
                                } 
                                else {
                                    # Just print the line normally.
                                    print $OUT "$start:\t",$dbline[$start],"\n";
                                }
                                # And quit since we found something.
                                last;
                            }
                         } ';
                    # If we wrapped, there never was a match.
                    print $OUT "/$pat/: not found\n" if ($start == $end);
                    next CMD;
                };

                # ? - backward pattern search.
                $cmd =~ /^\?(.*)$/ && do {

                    # Get the pattern, remove trailing question mark.
                    $inpat = $1;
                    $inpat =~ s:([^\\])\?$:$1:;

                    # If we've got one ...
                    if ($inpat ne "") {

                        # Turn off die & warn handlers.
                        local $SIG{__DIE__};
                        local $SIG{__WARN__};
                        eval '$inpat =~ m' . "\a$inpat\a";

                        if ($@ ne "") {
                            # Ouch. Not good. Print the error.
                            print $OUT $@;
                            next CMD;
                        }
                        $pat = $inpat;
                    } ## end if ($inpat ne "")

                    # Where we are now is where to stop after wraparound.
                    $end  = $start;

                    # Don't move away from this line.
                    $incr = -1;

                    # Search inside the eval to prevent pattern badness
                    # from killing us.
                    eval '
                        for (;;) {
                            # Back up a line.
                            --$start;

                            # Wrap if we pass the first line.
                            $start = $max if ($start <= 0);

                            # Quit if we get back where we started,
                            last if ($start == $end);

                            # Match?
                            if ($dbline[$start] =~ m' . "\a$pat\a" . 'i) {
                                if ($slave_editor) {
                                    # Yep, follow slave editor requirements.
                                    print $OUT "\032\032$filename:$start:0\n";
                                } 
                                else {
                                    # Yep, just print normally.
                                    print $OUT "$start:\t",$dbline[$start],"\n";
                                }

                                # Found, so done.
                                last;
                            }
                        } ';

                    # Say we failed if the loop never found anything,
                    print $OUT "?$pat?: not found\n" if ($start == $end);
                    next CMD;
                };

                # $rc - recall command. 
                $cmd =~ /^$rc+\s*(-)?(\d+)?$/ && do {

                    # No arguments, take one thing off history.
                    pop (@hist) if length($cmd) > 1;

                    # Relative (- found)? 
                    #  Y - index back from most recent (by 1 if bare minus)
                    #  N - go to that particular command slot or the last 
                    #      thing if nothing following.
                    $i = $1 ? ($#hist - ($2 || 1)) : ($2 || $#hist);

                    # Pick out the command desired.
                    $cmd = $hist[$i];

                    # Print the command to be executed and restart the loop
                    # with that command in the buffer.
                    print $OUT $cmd, "\n";
                    redo CMD;
                };

                # $sh$sh - run a shell command (if it's all ASCII).
                # Can't run shell commands with Unicode in the debugger, hmm.
                $cmd =~ /^$sh$sh\s*([\x00-\xff]*)/ && do {
                    # System it.
                    &system($1);
                    next CMD;
                };

                # $rc pattern $rc - find a command in the history. 
                $cmd =~ /^$rc([^$rc].*)$/ && do {
                    # Create the pattern to use.
                    $pat = "^$1";

                    # Toss off last entry if length is >1 (and it always is).
                    pop (@hist) if length($cmd) > 1;

                    # Look backward through the history.
                    for ($i = $#hist ; $i ; --$i) {
                        # Stop if we find it.
                        last if $hist[$i] =~ /$pat/;
                    }

                    if (!$i) {
                        # Never found it.
                        print $OUT "No such command!\n\n";
                        next CMD;
                    }

                    # Found it. Put it in the buffer, print it, and process it.
                    $cmd = $hist[$i];
                    print $OUT $cmd, "\n";
                    redo CMD;
                };

                # $sh - start a shell.
                $cmd =~ /^$sh$/ && do {
                    # Run the user's shell. If none defined, run Bourne.
                    # We resume execution when the shell terminates.
                    &system($ENV{SHELL} || "/bin/sh");
                    next CMD;
                };

                # $sh command - start a shell and run a command in it.
                $cmd =~ /^$sh\s*([\x00-\xff]*)/ && do {
                    # XXX: using csh or tcsh destroys sigint retvals!
                    #&system($1);  # use this instead

                    # use the user's shell, or Bourne if none defined.
                    &system($ENV{SHELL} || "/bin/sh", "-c", $1);
                    next CMD;
                };

                $cmd =~ /^H\b\s*(-(\d+))?/ && do {
                    # Anything other than negative numbers is ignored by 
                    # the (incorrect) pattern, so this test does nothing.
                    $end = $2 ? ($#hist - $2) : 0;

                    # Set to the minimum if less than zero.
                    $hist = 0 if $hist < 0;

                    # Start at the end of the array. 
                    # Stay in while we're still above the ending value.
                    # Tick back by one each time around the loop.
                    for ($i = $#hist ; $i > $end ; $i--) {

                        # Print the command  unless it has no arguments.
                        print $OUT "$i: ", $hist[$i], "\n"
                          unless $hist[$i] =~ /^.?$/;
                    }
                    next CMD;
                };

                # man, perldoc, doc - show manual pages.               
                $cmd =~ /^(?:man|(?:perl)?doc)\b(?:\s+([^(]*))?$/ && do {
                    runman($1);
                    next CMD;
                };

                # p - print (no args): print $_.
                $cmd =~ s/^p$/print {\$DB::OUT} \$_/;

                # p - print the given expression.
                $cmd =~ s/^p\b/print {\$DB::OUT} /;

                 # = - set up a command alias.
                $cmd =~ s/^=\s*// && do {
                    my @keys;
                    if (length $cmd == 0) {
                        # No args, get current aliases.
                        @keys = sort keys %alias;
                    }
                    elsif (my ($k, $v) = ($cmd =~ /^(\S+)\s+(\S.*)/)) {
                        # Creating a new alias. $k is alias name, $v is
                        # alias value.

                        # can't use $_ or kill //g state
                        for my $x ($k, $v) { 
                          # Escape "alarm" characters.
                          $x =~ s/\a/\\a/g 
                        }

                        # Substitute key for value, using alarm chars
                        # as separators (which is why we escaped them in 
                        # the command).
                        $alias{$k} = "s\a$k\a$v\a";

                        # Turn off standard warn and die behavior.
                        local $SIG{__DIE__};
                        local $SIG{__WARN__};

                        # Is it valid Perl?
                        unless (eval "sub { s\a$k\a$v\a }; 1") {
                            # Nope. Bad alias. Say so and get out.
                            print $OUT "Can't alias $k to $v: $@\n";
                            delete $alias{$k};
                            next CMD;
                        }
                        # We'll only list the new one.
                        @keys = ($k);
                    } ## end elsif (my ($k, $v) = ($cmd...

                    # The argument is the alias to list.
                    else {
                        @keys = ($cmd);
                    }

                    # List aliases.
                    for my $k (@keys) {
                        # Messy metaquoting: Trim the substiution code off.
                        # We use control-G as the delimiter because it's not
                        # likely to appear in the alias.
                        if ((my $v = $alias{$k}) =~ ss\a$k\a(.*)\a$1) {
                            # Print the alias.
                            print $OUT "$k\t= $1\n";
                        }
                        elsif (defined $alias{$k}) {
                            # Couldn't trim it off; just print the alias code.
                            print $OUT "$k\t$alias{$k}\n";
                        }
                        else {
                            # No such, dude.
                            print "No alias for $k\n";
                        }
                    } ## end for my $k (@keys)
                    next CMD;
                };

                # source - read commands from a file (or pipe!) and execute. 
                $cmd =~ /^source\s+(.*\S)/ && do {
                    if (open my $fh, $1) {
                        # Opened OK; stick it in the list of file handles.
                        push @cmdfhs, $fh;
                    }
                    else {
                        # Couldn't open it. 
                        &warn("Can't execute `$1': $!\n");
                    }
                    next CMD;
                };

                # || - run command in the pager, with output to DB::OUT.
                $cmd =~ /^\|\|?\s*[^|]/ && do {
                    if ($pager =~ /^\|/) {
                        # Default pager is into a pipe. Redirect I/O.
                        open(SAVEOUT, ">&STDOUT") ||
                          &warn("Can't save STDOUT");
                        open(STDOUT, ">&OUT") ||
                          &warn("Can't redirect STDOUT");
                    } ## end if ($pager =~ /^\|/)
                    else {
                        # Not into a pipe. STDOUT is safe.
                        open(SAVEOUT, ">&OUT") || &warn("Can't save DB::OUT");
                    }

                    # Fix up environment to record we have less if so.
                    fix_less();

                    unless ($piped = open(OUT, $pager)) {
                        # Couldn't open pipe to pager.
                        &warn("Can't pipe output to `$pager'");
                        if ($pager =~ /^\|/) {
                            # Redirect I/O back again.
                            open(OUT, ">&STDOUT")    # XXX: lost message
                              || &warn("Can't restore DB::OUT");
                            open(STDOUT, ">&SAVEOUT") ||
                              &warn("Can't restore STDOUT");
                            close(SAVEOUT);
                        } ## end if ($pager =~ /^\|/)
                        else {
                            # Redirect I/O. STDOUT already safe.
                            open(OUT, ">&STDOUT")    # XXX: lost message
                              || &warn("Can't restore DB::OUT");
                        }
                        next CMD;
                    } ## end unless ($piped = open(OUT,...

                    # Set up broken-pipe handler if necessary.
                    $SIG{PIPE} = \&DB::catch
                      if $pager =~ /^\|/ &&
                      ("" eq $SIG{PIPE} || "DEFAULT" eq $SIG{PIPE});

                    # Save current filehandle, unbuffer out, and put it back.
                    $selected = select(OUT);
                    $|        = 1;

                    # Don't put it back if pager was a pipe.
                    select($selected), $selected = "" unless $cmd =~ /^\|\|/;

                    # Trim off the pipe symbols and run the command now.
                    $cmd =~ s/^\|+\s*//;
                    redo PIPE;
                };


                # t - turn trace on.
                $cmd =~ s/^t\s/\$DB::trace |= 1;\n/;

                # s - single-step. Remember the last command was 's'.
                $cmd =~ s/^s\s/\$DB::single = 1;\n/ && do { $laststep = 's' };

                # n - single-step, but not into subs. Remember last command
                # was 'n'.
                $cmd =~ s/^n\s/\$DB::single = 2;\n/ && do { $laststep = 'n' };

            }    # PIPE:

            # Make sure the flag that says "the debugger's running" is 
            # still on, to make sure we get control again.
            $evalarg = "\$^D = \$^D | \$DB::db_stop;\n$cmd";

            # Run *our* eval that executes in the caller's context.
            &eval;

            # Turn off the one-time-dump stuff now.
            if ($onetimeDump) {
                $onetimeDump      = undef;
                $onetimedumpDepth = undef;
            }
            elsif ($term_pid == $$) {
                STDOUT->flush();
                STDERR->flush();
                # XXX If this is the master pid, print a newline.
                print $OUT "\n";
            }
        } ## end while (($term || &setterm...

        continue {    # CMD:

            # At the end of every command:
            if ($piped) {
                # Unhook the pipe mechanism now.
                if ($pager =~ /^\|/) {
                    # No error from the child.
                    $? = 0;

                    # we cannot warn here: the handle is missing --tchrist
                    close(OUT) || print SAVEOUT "\nCan't close DB::OUT\n";

                    # most of the $? crud was coping with broken cshisms
                    # $? is explicitly set to 0, so this never runs.
                    if ($?) {
                        print SAVEOUT "Pager `$pager' failed: ";
                        if ($? == -1) {
                            print SAVEOUT "shell returned -1\n";
                        }
                        elsif ($? >> 8) {
                            print SAVEOUT ($? & 127)
                              ? " (SIG#" . ($? & 127) . ")"
                              : "", ($? & 128) ? " -- core dumped" : "", "\n";
                        }
                        else {
                            print SAVEOUT "status ", ($? >> 8), "\n";
                        }
                    } ## end if ($?)

                    # Reopen filehandle for our output (if we can) and 
                    # restore STDOUT (if we can).
                    open(OUT, ">&STDOUT") || &warn("Can't restore DB::OUT");
                    open(STDOUT, ">&SAVEOUT") ||
                      &warn("Can't restore STDOUT");

                    # Turn off pipe exception handler if necessary.
                    $SIG{PIPE} = "DEFAULT" if $SIG{PIPE} eq \&DB::catch;

                    # Will stop ignoring SIGPIPE if done like nohup(1)
                    # does SIGINT but Perl doesn't give us a choice.
                } ## end if ($pager =~ /^\|/)
                else {
                    # Non-piped "pager". Just restore STDOUT.
                    open(OUT, ">&SAVEOUT") || &warn("Can't restore DB::OUT");
                }

                # Close filehandle pager was using, restore the normal one
                # if necessary,
                close(SAVEOUT);
                select($selected), $selected = "" unless $selected eq "";

                # No pipes now.
                $piped = "";
            } ## end if ($piped)
        }    # CMD:

        # No more commands? Quit.
        $fall_off_end = 1 unless defined $cmd;    # Emulate `q' on EOF

        # Evaluate post-prompt commands.
        foreach $evalarg (@$post) {
            &eval;
        }
    }    # if ($single || $signal)

    # Put the user's globals back where you found them.
    ($@, $!, $^E, $,, $/, $\, $^W) = @saved;
    ();
} ## end sub DB

# The following code may be executed now:
# BEGIN {warn 4}

sub sub {

    # Whether or not the autoloader was running, a scalar to put the
    # sub's return value in (if needed), and an array to put the sub's
    # return value in (if needed).
    my ($al, $ret, @ret) = "";

    # If the last ten characters are C'::AUTOLOAD', note we've traced
    # into AUTOLOAD for $sub.
    if (length($sub) > 10 && substr($sub, -10, 10) eq '::AUTOLOAD') {
        $al = " for $$sub";
    }

    # We stack the stack pointer and then increment it to protect us
    # from a situation that might unwind a whole bunch of call frames
    # at once. Localizing the stack pointer means that it will automatically
    # unwind the same amount when multiple stack frames are unwound.
    local $stack_depth = $stack_depth + 1;    # Protect from non-local exits

    # Expand @stack.
    $#stack = $stack_depth;

    # Save current single-step setting.
    $stack[-1] = $single;

    # Turn off all flags except single-stepping. 
    $single &= 1;

    # If we've gotten really deeply recursed, turn on the flag that will
    # make us stop with the 'deep recursion' message.
    $single |= 4 if $stack_depth == $deep;

    # If frame messages are on ...
    (
        $frame & 4    # Extended frame entry message
        ? (
            print_lineinfo(' ' x ($stack_depth - 1), "in  "),

            # Why -1? But it works! :-(
            # Because print_trace will call add 1 to it and then call
            # dump_trace; this results in our skipping -1+1 = 0 stack frames
            # in dump_trace.
            print_trace($LINEINFO, -1, 1, 1, "$sub$al")
          )
        : print_lineinfo(' ' x ($stack_depth - 1), "entering $sub$al\n")
          # standard frame entry message
      )
      if $frame;

    # Determine the sub's return type,and capture approppriately.
    if (wantarray) {
        # Called in array context. call sub and capture output.
        # DB::DB will recursively get control again if appropriate; we'll come
        # back here when the sub is finished.
        @ret = &$sub;

        # Pop the single-step value back off the stack.
        $single |= $stack[$stack_depth--];

        # Check for exit trace messages...
        (
            $frame & 4         # Extended exit message
            ? (
                print_lineinfo(' ' x $stack_depth, "out "),
                print_trace($LINEINFO, -1, 1, 1, "$sub$al")
              )
            : print_lineinfo(' ' x $stack_depth, "exited $sub$al\n")
              # Standard exit message
          )
          if $frame & 2;

        # Print the return info if we need to.
        if ($doret eq $stack_depth or $frame & 16) {
            # Turn off output record separator.
            local $\ = '';
            my $fh = ($doret eq $stack_depth ? $OUT : $LINEINFO);

            # Indent if we're printing because of $frame tracing.
            print $fh ' ' x $stack_depth if $frame & 16;

            # Print the return value.
            print $fh "list context return from $sub:\n";
            dumpit($fh, \@ret);

            # And don't print it again.
            $doret = -2;
        } ## end if ($doret eq $stack_depth...
        # And we have to return the return value now.
        @ret;

    } ## end if (wantarray)

    # Scalar context.
    else {
        if (defined wantarray) {
            # Save the value if it's wanted at all. 
            $ret = &$sub;
        }
        else {
            # Void return, explicitly.
            &$sub;
            undef $ret;
        }

        # Pop the single-step value off the stack.
        $single |= $stack[$stack_depth--];

        # If we're doing exit messages...
        (
            $frame & 4                        # Extended messsages
            ? (
                print_lineinfo(' ' x $stack_depth, "out "),
                print_trace($LINEINFO, -1, 1, 1, "$sub$al")
              )
            : print_lineinfo(' ' x $stack_depth, "exited $sub$al\n")
                                              # Standard messages
          )
          if $frame & 2;

        # If we are supposed to show the return value... same as before.
        if ($doret eq $stack_depth or $frame & 16 and defined wantarray) {
            local $\ = '';
            my $fh = ($doret eq $stack_depth ? $OUT : $LINEINFO);
            print $fh (' ' x $stack_depth) if $frame & 16;
            print $fh (
                defined wantarray
                ? "scalar context return from $sub: "
                : "void context return from $sub\n"
                );
            dumpit($fh, $ret) if defined wantarray;
            $doret = -2;
        } ## end if ($doret eq $stack_depth...

        # Return the appropriate scalar value.
        $ret;
    } ## end else [ if (wantarray)
} ## end sub sub

### The API section

my %set = (    #
    'pre580' => {
        'a' => 'pre580_a',
        'A' => 'pre580_null',
        'b' => 'pre580_b',
        'B' => 'pre580_null',
        'd' => 'pre580_null',
        'D' => 'pre580_D',
        'h' => 'pre580_h',
        'M' => 'pre580_null',
        'O' => 'o',
        'o' => 'pre580_null',
        'v' => 'M',
        'w' => 'v',
        'W' => 'pre580_W',
    },
    'pre590' => {
        '<'  => 'pre590_prepost',
        '<<' => 'pre590_prepost',
        '>'  => 'pre590_prepost',
        '>>' => 'pre590_prepost',
        '{'  => 'pre590_prepost',
        '{{' => 'pre590_prepost',
    },
  );

sub cmd_wrapper {
    my $cmd      = shift;
    my $line     = shift;
    my $dblineno = shift;

    # Assemble the command subroutine's name by looking up the 
    # command set and command name in %set. If we can't find it,
    # default to the older version of the command.
    my $call = 'cmd_'
      . ( $set{$CommandSet}{$cmd}
          || ( $cmd =~ /^[<>{]+/o ? 'prepost' : $cmd ) );

    # Call the command subroutine, call it by name.
    return &$call($cmd, $line, $dblineno);
} ## end sub cmd_wrapper

sub cmd_a {
    my $cmd  = shift;
    my $line = shift || '';    # [.|line] expr
    my $dbline = shift;

    # If it's dot (here), or not all digits,  use the current line.
    $line =~ s/^(\.|(?:[^\d]))/$dbline/;

    # Should be a line number followed by an expression. 
    if ($line =~ /^\s*(\d*)\s*(\S.+)/) {
        my ($lineno, $expr) = ($1, $2);

        # If we have an expression ...
        if (length $expr) {
            # ... but the line isn't breakable, complain.
            if ($dbline[$lineno] == 0) {
                print $OUT
                  "Line $lineno($dbline[$lineno]) does not have an action?\n";
            }
            else {
                # It's executable. Record that the line has an action.
                $had_breakpoints{$filename} |= 2;

                # Remove any action, temp breakpoint, etc.
                $dbline{$lineno} =~ s/\0[^\0]*//;

                # Add the action to the line.
                $dbline{$lineno} .= "\0" . action($expr);
            }
        } ## end if (length $expr)
    } ## end if ($line =~ /^\s*(\d*)\s*(\S.+)/)
    else {
        # Syntax wrong.
        print $OUT
          "Adding an action requires an optional lineno and an expression\n"
          ;    # hint
    }
} ## end sub cmd_a

sub cmd_A {
    my $cmd  = shift;
    my $line = shift || '';
    my $dbline = shift;

    # Dot is this line.
    $line =~ s/^\./$dbline/;

    # Call delete_action with a null param to delete them all.
    # The '1' forces the eval to be true. It'll be false only
    # if delete_action blows up for some reason, in which case
    # we print $@ and get out.
    if ($line eq '*') {
        eval { &delete_action(); 1 } or print $OUT $@ and return;
    }

    # There's a real line  number. Pass it to delete_action.
    # Error trapping is as above.
    elsif ($line =~ /^(\S.*)/) {
        eval { &delete_action($1); 1 } or print $OUT $@ and return;
    }

    # Swing and a miss. Bad syntax.
    else {
        print $OUT
          "Deleting an action requires a line number, or '*' for all\n"
          ;    # hint
    }
} ## end sub cmd_A

sub delete_action {
    my $i = shift;
    if (defined($i)) {
        # Can there be one?
        die "Line $i has no action .\n" if $dbline[$i] == 0;

        # Nuke whatever's there.
        $dbline{$i} =~ s/\0[^\0]*//;    # \^a
        delete $dbline{$i} if $dbline{$i} eq '';
    }
    else {
        print $OUT "Deleting all actions...\n";
        for my $file (keys %had_breakpoints) {
            local *dbline = $main::{ '_<' . $file };
            my $max = $#dbline;
            my $was;
            for ($i = 1 ; $i <= $max ; $i++) {
                if (defined $dbline{$i}) {
                    $dbline{$i} =~ s/\0[^\0]*//;
                    delete $dbline{$i} if $dbline{$i} eq '';
                }
                unless ($had_breakpoints{$file} &= ~2) {
                    delete $had_breakpoints{$file};
                }
            } ## end for ($i = 1 ; $i <= $max...
        } ## end for my $file (keys %had_breakpoints)
    } ## end else [ if (defined($i))
} ## end sub delete_action

sub cmd_b {
    my $cmd    = shift;
    my $line   = shift;    # [.|line] [cond]
    my $dbline = shift;

    # Make . the current line number if it's there..
    $line =~ s/^\./$dbline/;

    # No line number, no condition. Simple break on current line. 
    if ($line =~ /^\s*$/) {
        &cmd_b_line($dbline, 1);
    }

    # Break on load for a file.
    elsif ($line =~ /^load\b\s*(.*)/) {
        my $file = $1;
        $file =~ s/\s+$//;
        &cmd_b_load($file);
    }

    # b compile|postpone <some sub> [<condition>]
    # The interpreter actually traps this one for us; we just put the 
    # necessary condition in the %postponed hash.
    elsif ($line =~ /^(postpone|compile)\b\s*([':A-Za-z_][':\w]*)\s*(.*)/) {
        # Capture the condition if there is one. Make it true if none.
        my $cond = length $3 ? $3 : '1';

        # Save the sub name and set $break to 1 if $1 was 'postpone', 0
        # if it was 'compile'.
        my ($subname, $break) = ($2, $1 eq 'postpone');

        # De-Perl4-ify the name - ' separators to ::.
        $subname =~ s/\'/::/g;

        # Qualify it into the current package unless it's already qualified.
        $subname = "${'package'}::" . $subname unless $subname =~ /::/;

        # Add main if it starts with ::.
        $subname = "main" . $subname if substr($subname, 0, 2) eq "::";

        # Save the break type for this sub.
        $postponed{$subname} = $break ? "break +0 if $cond" : "compile";
    } ## end elsif ($line =~ ...

    # b <sub name> [<condition>]
    elsif ($line =~ /^([':A-Za-z_][':\w]*(?:\[.*\])?)\s*(.*)/) {
        # 
        $subname = $1;
        $cond = length $2 ? $2 : '1';
        &cmd_b_sub($subname, $cond);
    }

    # b <line> [<condition>].
    elsif ($line =~ /^(\d*)\s*(.*)/) {
        # Capture the line. If none, it's the current line.
        $line = $1 || $dbline;

        # If there's no condition, make it '1'.
        $cond = length $2 ? $2 : '1';

        # Break on line.
        &cmd_b_line($line, $cond);
    }

    # Line didn't make sense.
    else {
        print "confused by line($line)?\n";
    }
} ## end sub cmd_b

sub break_on_load {
    my $file = shift;
    $break_on_load{$file} = 1;
    $had_breakpoints{$file} |= 1;
}

sub report_break_on_load {
    sort keys %break_on_load;
}

sub cmd_b_load {
    my $file = shift;
    my @files;

    # This is a block because that way we can use a redo inside it
    # even without there being any looping structure at all outside it.
    {
        # Save short name and full path if found.
        push @files, $file;
        push @files, $::INC{$file} if $::INC{$file};

        # Tack on .pm and do it again unless there was a '.' in the name 
        # already.
        $file .= '.pm', redo unless $file =~ /\./;
    }

    # Do the real work here.
    break_on_load($_) for @files;

    # All the files that have break-on-load breakpoints.
    @files = report_break_on_load;

    # Normalize for the purposes of our printing this.
    local $\ = '';
    local $" = ' ';
    print $OUT "Will stop on load of `@files'.\n";
} ## end sub cmd_b_load

$filename_error = '';

sub breakable_line {
    
    my ($from, $to) = @_;

    # $i is the start point. (Where are the FORTRAN programs of yesteryear?)
    my $i = $from;

    # If there are at least 2 arguments, we're trying to search a range.
    if (@_ >= 2) {

        # $delta is positive for a forward search, negative for a backward one.
        my $delta = $from < $to ? +1 : -1;

        # Keep us from running off the ends of the file.
        my $limit = $delta > 0 ? $#dbline : 1;

        # Clever test. If you're a mathematician, it's obvious why this
        # test works. If not:
        # If $delta is positive (going forward), $limit will be $#dbline.
        #    If $to is less than $limit, ($limit - $to) will be positive, times
        #    $delta of 1 (positive), so the result is > 0 and we should use $to
        #    as the stopping point. 
        #
        #    If $to is greater than $limit, ($limit - $to) is negative,
        #    times $delta of 1 (positive), so the result is < 0 and we should 
        #    use $limit ($#dbline) as the stopping point.
        #
        # If $delta is negative (going backward), $limit will be 1. 
        #    If $to is zero, ($limit - $to) will be 1, times $delta of -1
        #    (negative) so the result is > 0, and we use $to as the stopping
        #    point.
        #
        #    If $to is less than zero, ($limit - $to) will be positive,
        #    times $delta of -1 (negative), so the result is not > 0, and 
        #    we use $limit (1) as the stopping point. 
        #
        #    If $to is 1, ($limit - $to) will zero, times $delta of -1
        #    (negative), still giving zero; the result is not > 0, and 
        #    we use $limit (1) as the stopping point.
        #
        #    if $to is >1, ($limit - $to) will be negative, times $delta of -1
        #    (negative), giving a positive (>0) value, so we'll set $limit to
        #    $to.
        
        $limit = $to if ($limit - $to) * $delta > 0;

        # The real search loop.
        # $i starts at $from (the point we want to start searching from).
        # We move through @dbline in the appropriate direction (determined
        # by $delta: either -1 (back) or +1 (ahead). 
        # We stay in as long as we haven't hit an executable line 
        # ($dbline[$i] == 0 means not executable) and we haven't reached
        # the limit yet (test similar to the above).
        $i += $delta while $dbline[$i] == 0 and ($limit - $i) * $delta > 0;

    } ## end if (@_ >= 2)

    # If $i points to a line that is executable, return that.
    return $i unless $dbline[$i] == 0;

    # Format the message and print it: no breakable lines in range.
    my ($pl, $upto) = ('', '');
    ($pl, $upto) = ('s', "..$to") if @_ >= 2 and $from != $to;

    # If there's a filename in filename_error, we'll see it.
    # If not, not.
    die "Line$pl $from$upto$filename_error not breakable\n";
} ## end sub breakable_line

sub breakable_line_in_filename {
    # Capture the file name.
    my ($f) = shift;

    # Swap the magic line array over there temporarily.
    local *dbline         = $main::{ '_<' . $f };

    # If there's an error, it's in this other file.
    local $filename_error = " of `$f'";

    # Find the breakable line.
    breakable_line(@_);

    # *dbline and $filename_error get restored when this block ends.

} ## end sub breakable_line_in_filename

sub break_on_line {
    my ($i, $cond) = @_;

    # Always true if no condition supplied.
    $cond = 1 unless @_ >= 2;

    my $inii  = $i;
    my $after = '';
    my $pl    = '';

    # Woops, not a breakable line. $filename_error allows us to say
    # if it was in a different file.
    die "Line $i$filename_error not breakable.\n" if $dbline[$i] == 0;

    # Mark this file as having breakpoints in it.
    $had_breakpoints{$filename} |= 1;

    # If there is an action or condition here already ... 
    if ($dbline{$i}) { 
        # ... swap this condition for the existing one.
        $dbline{$i} =~ s/^[^\0]*/$cond/; 
    }
    else { 
        # Nothing here - just add the condition.
        $dbline{$i} = $cond; 
    }
} ## end sub break_on_line

sub cmd_b_line {
    eval { break_on_line(@_); 1 } or do {
        local $\ = '';
        print $OUT $@ and return;
    };
} ## end sub cmd_b_line

sub break_on_filename_line {
    my ($f, $i, $cond) = @_;

    # Always true if condition left off.
    $cond = 1 unless @_ >= 3;

    # Switch the magical hash temporarily.
    local *dbline         = $main::{ '_<' . $f };

    # Localize the variables that break_on_line uses to make its message.
    local $filename_error = " of `$f'";
    local $filename       = $f;

    # Add the breakpoint.
    break_on_line($i, $cond);
} ## end sub break_on_filename_line

sub break_on_filename_line_range {
    my ($f, $from, $to, $cond) = @_;

    # Find a breakable line if there is one.
    my $i = breakable_line_in_filename($f, $from, $to);

    # Always true if missing.
    $cond = 1 unless @_ >= 3;

    # Add the breakpoint.
    break_on_filename_line($f, $i, $cond);
} ## end sub break_on_filename_line_range

sub subroutine_filename_lines {
    my ($subname, $cond) = @_;

    # Returned value from find_sub() is fullpathname:startline-endline.
    # The match creates the list (fullpathname, start, end). Falling off
    # the end of the subroutine returns this implicitly.
    find_sub($subname) =~ /^(.*):(\d+)-(\d+)$/;
} ## end sub subroutine_filename_lines

sub break_subroutine {
    my $subname = shift;

    # Get filename, start, and end.
    my ($file, $s, $e) = subroutine_filename_lines($subname)
      or die "Subroutine $subname not found.\n";

    # Null condition changes to '1' (always true).
    $cond = 1 unless @_ >= 2;

    # Put a break the first place possible in the range of lines
    # that make up this subroutine.
    break_on_filename_line_range($file, $s, $e, @_);
} ## end sub break_subroutine

sub cmd_b_sub {
    my ($subname, $cond) = @_;

    # Add always-true condition if we have none.
    $cond = 1 unless @_ >= 2;

    # If the subname isn't a code reference, qualify it so that 
    # break_subroutine() will work right.
    unless (ref $subname eq 'CODE') {
        # Not Perl4.
        $subname =~ s/\'/::/g;
        my $s = $subname;

        # Put it in this package unless it's already qualified.
        $subname = "${'package'}::" . $subname
          unless $subname =~ /::/;

        # Requalify it into CORE::GLOBAL if qualifying it into this
        # package resulted in its not being defined, but only do so
        # if it really is in CORE::GLOBAL.
        $subname = "CORE::GLOBAL::$s"
          if not defined &$subname
          and $s !~ /::/
          and defined &{"CORE::GLOBAL::$s"};

        # Put it in package 'main' if it has a leading ::.
        $subname = "main" . $subname if substr($subname, 0, 2) eq "::";

    } ## end unless (ref $subname eq 'CODE')

    # Try to set the breakpoint.
    eval { break_subroutine($subname, $cond); 1 } or do {
        local $\ = '';
        print $OUT $@ and return;
      }
} ## end sub cmd_b_sub

sub cmd_B {
    my $cmd  = shift;

    # No line spec? Use dbline. 
    # If there is one, use it if it's non-zero, or wipe it out if it is.
    my $line = ($_[0] =~ /^\./) ? $dbline : shift || '';
    my $dbline = shift;

    # If the line was dot, make the line the current one.
    $line =~ s/^\./$dbline/;

    # If it's * we're deleting all the breakpoints.
    if ($line eq '*') {
        eval { &delete_breakpoint(); 1 } or print $OUT $@ and return;
    }

    # If there is a line spec, delete the breakpoint on that line.
    elsif ($line =~ /^(\S.*)/) {
        eval { &delete_breakpoint($line || $dbline); 1 } or do {
            local $\ = '';
            print $OUT $@ and return;
        };
    } ## end elsif ($line =~ /^(\S.*)/)

    # No line spec. 
    else {
        print $OUT
          "Deleting a breakpoint requires a line number, or '*' for all\n"
          ;    # hint
    }
} ## end sub cmd_B

sub delete_breakpoint {
    my $i = shift;

    # If we got a line, delete just that one.
    if (defined($i)) {

        # Woops. This line wasn't breakable at all.
        die "Line $i not breakable.\n" if $dbline[$i] == 0;

        # Kill the condition, but leave any action.
        $dbline{$i} =~ s/^[^\0]*//;

        # Remove the entry entirely if there's no action left.
        delete $dbline{$i} if $dbline{$i} eq '';
    }

    # No line; delete them all.
    else {
        print $OUT "Deleting all breakpoints...\n";

        # %had_breakpoints lists every file that had at least one
        # breakpoint in it.
        for my $file (keys %had_breakpoints) {
            # Switch to the desired file temporarily.
            local *dbline = $main::{ '_<' . $file };

            my $max = $#dbline;
            my $was;

            # For all lines in this file ...
            for ($i = 1 ; $i <= $max ; $i++) {
                # If there's a breakpoint or action on this line ...
                if (defined $dbline{$i}) {
                    # ... remove the breakpoint.
                    $dbline{$i} =~ s/^[^\0]+//;
                    if ($dbline{$i} =~ s/^\0?$//) {
                        # Remove the entry altogether if no action is there.
                        delete $dbline{$i};
                    }
                } ## end if (defined $dbline{$i...
            } ## end for ($i = 1 ; $i <= $max...

            # If, after we turn off the "there were breakpoints in this file"
            # bit, the entry in %had_breakpoints for this file is zero, 
            # we should remove this file from the hash.
            if (not $had_breakpoints{$file} &= ~1) {
                delete $had_breakpoints{$file};
            }
        } ## end for my $file (keys %had_breakpoints)

        # Kill off all the other breakpoints that are waiting for files that
        # haven't been loaded yet.
        undef %postponed;
        undef %postponed_file;
        undef %break_on_load;
    } ## end else [ if (defined($i))
} ## end sub delete_breakpoint

sub cmd_stop {    # As on ^C, but not signal-safy.
    $signal = 1;
}

sub cmd_h {
    my $cmd  = shift;

    # If we have no operand, assume null.
    my $line = shift || '';

    # 'h h'. Print the long-format help.
    if ($line =~ /^h\s*/) {
        print_help($help);
    }

    # 'h <something>'. Search for the command and print only its help.
    elsif ($line =~ /^(\S.*)$/) {

        # support long commands; otherwise bogus errors
        # happen when you ask for h on <CR> for example
        my $asked  = $1;                   # the command requested
                                           # (for proper error message)

        my $qasked = quotemeta($asked);    # for searching; we don't
                                           # want to use it as a pattern.
                                           # XXX: finds CR but not <CR>

        # Search the help string for the command.
        if ($help =~ /^                    # Start of a line
                      <?                   # Optional '<'
                      (?:[IB]<)            # Optional markup
                      $qasked              # The requested command
                     /mx) {
            # It's there; pull it out and print it.
            while ($help =~ /^
                              (<?            # Optional '<'
                                 (?:[IB]<)   # Optional markup
                                 $qasked     # The command
                                 ([\s\S]*?)  # Description line(s)
                              \n)            # End of last description line
                              (?!\s)         # Next line not starting with 
                                             # whitespace
                             /mgx) {
                print_help($1);
            }
        }

        # Not found; not a debugger command.
        else {
            print_help("B<$asked> is not a debugger command.\n");
        }
    } ## end elsif ($line =~ /^(\S.*)$/)

    # 'h' - print the summary help.
    else {
        print_help($summary);
    }
} ## end sub cmd_h

sub cmd_l {
    my $current_line  = $line;

    my $cmd           = shift;
    my $line          = shift;

    # If this is '-something', delete any spaces after the dash.
    $line =~ s/^-\s*$/-/;

    # If the line is '$something', assume this is a scalar containing a 
    # line number.
    if ($line =~ /^(\$.*)/s) {

        # Set up for DB::eval() - evaluate in *user* context.
        $evalarg = $1;
        my ($s) = &eval;

        # Ooops. Bad scalar.
        print($OUT "Error: $@\n"), next CMD if $@;

        # Good scalar. If it's a reference, find what it points to.
        $s = CvGV_name($s);
        print($OUT "Interpreted as: $1 $s\n");
        $line = "$1 $s";

        # Call self recursively to really do the command.
        &cmd_l('l', $s);
    } ## end if ($line =~ /^(\$.*)/s)

    # l name. Try to find a sub by that name. 
    elsif ($line =~ /^([\':A-Za-z_][\':\w]*(\[.*\])?)/s) {
        my $s = $subname = $1;

        # De-Perl4.
        $subname =~ s/\'/::/;

        # Put it in this package unless it starts with ::.
        $subname = $package . "::" . $subname unless $subname =~ /::/;

        # Put it in CORE::GLOBAL if t doesn't start with :: and
        # it doesn't live in this package and it lives in CORE::GLOBAL.
        $subname = "CORE::GLOBAL::$s"
          if not defined &$subname
          and $s !~ /::/
          and defined &{"CORE::GLOBAL::$s"};

        # Put leading '::' names into 'main::'.
        $subname = "main" . $subname if substr($subname, 0, 2) eq "::";

        # Get name:start-stop from find_sub, and break this up at 
        # colons.
        @pieces = split (/:/, find_sub($subname) || $sub{$subname});

        # Pull off start-stop.
        $subrange = pop @pieces;

        # If the name contained colons, the split broke it up.
        # Put it back together.
        $file     = join (':', @pieces);

        # If we're not in that file, switch over to it.
        if ($file ne $filename) {
            print $OUT "Switching to file '$file'.\n"
              unless $slave_editor;

            # Switch debugger's magic structures.
            *dbline   = $main::{ '_<' . $file };
            $max      = $#dbline;
            $filename = $file;
        } ## end if ($file ne $filename)

        # Subrange is 'start-stop'. If this is less than a window full,
        # swap it to 'start+', which will list a window from the start point.
        if ($subrange) {
            if (eval($subrange) < -$window) {
                $subrange =~ s/-.*/+/;
            }
            # Call self recursively to list the range.
            $line = $subrange;
            &cmd_l('l', $subrange);
        } ## end if ($subrange)

        # Couldn't find it.
        else {
            print $OUT "Subroutine $subname not found.\n";
        }
    } ## end elsif ($line =~ /^([\':A-Za-z_][\':\w]*(\[.*\])?)/s)

    # Bare 'l' command.
    elsif ($line =~ /^\s*$/) {
        # Compute new range to list.
        $incr = $window - 1;
        $line = $start . '-' . ($start + $incr);
        # Recurse to do it.
        &cmd_l('l', $line);
    }

    # l [start]+number_of_lines
    elsif ($line =~ /^(\d*)\+(\d*)$/) {
        # Don't reset start for 'l +nnn'.
        $start = $1 if $1;

        # Increment for list. Use window size if not specified.
        # (Allows 'l +' to work.)
        $incr = $2;
        $incr = $window - 1 unless $incr;

        # Create a line range we'll understand, and recurse to do it.
        $line = $start . '-' . ($start + $incr);
        &cmd_l('l', $line);
    } ## end elsif ($line =~ /^(\d*)\+(\d*)$/)

    # l start-stop or l start,stop
    elsif ($line =~ /^((-?[\d\$\.]+)([-,]([\d\$\.]+))?)?/) {

        # Determine end point; use end of file if not specified.
        $end = (!defined $2) ? $max : ($4 ? $4 : $2);

        # Go on to the end, and then stop.
        $end = $max if $end > $max;

        # Determine start line.  
        $i = $2;
        $i = $line if $i eq '.';
        $i = 1 if $i < 1;
        $incr = $end - $i;

        # If we're running under a slave editor, force it to show the lines.
        if ($slave_editor) {
            print $OUT "\032\032$filename:$i:0\n";
            $i = $end;
        }

        # We're doing it ourselves. We want to show the line and special
        # markers for:
        # - the current line in execution 
        # - whether a line is breakable or not
        # - whether a line has a break or not
        # - whether a line has an action or not
        else {
            for (; $i <= $end ; $i++) {
                # Check for breakpoints and actions.
                my ($stop, $action);
                ($stop, $action) = split (/\0/, $dbline{$i})
                  if $dbline{$i};

                # ==> if this is the current line in execution,
                # : if it's breakable.
                $arrow =
                  ($i == $current_line and $filename eq $filename_ini)
                  ? '==>'
                  : ($dbline[$i] + 0 ? ':' : ' ');

                # Add break and action indicators.
                $arrow .= 'b' if $stop;
                $arrow .= 'a' if $action;

                # Print the line.
                print $OUT "$i$arrow\t", $dbline[$i];

                # Move on to the next line. Drop out on an interrupt.
                $i++, last if $signal;
            } ## end for (; $i <= $end ; $i++)

            # Line the prompt up; print a newline if the last line listed
            # didn't have a newline.
            print $OUT "\n" unless $dbline[$i - 1] =~ /\n$/;
        } ## end else [ if ($slave_editor)

        # Save the point we last listed to in case another relative 'l'
        # command is desired. Don't let it run off the end.
        $start = $i;
        $start = $max if $start > $max;
    } ## end elsif ($line =~ /^((-?[\d\$\.]+)([-,]([\d\$\.]+))?)?/)
} ## end sub cmd_l

sub cmd_L {
    my $cmd = shift;

    # If no argument, list everything. Pre-5.8.0 version always lists 
    # everything
    my $arg = shift || 'abw';
    $arg = 'abw' unless $CommandSet eq '580';    # sigh...

    # See what is wanted.
    my $action_wanted = ($arg =~ /a/) ? 1 : 0;
    my $break_wanted  = ($arg =~ /b/) ? 1 : 0;
    my $watch_wanted  = ($arg =~ /w/) ? 1 : 0;

    # Breaks and actions are found together, so we look in the same place
    # for both.
    if ($break_wanted or $action_wanted) {
        # Look in all the files with breakpoints...
        for my $file (keys %had_breakpoints) {
            # Temporary switch to this file.
            local *dbline = $main::{ '_<' . $file };

            # Set up to look through the whole file.
            my $max = $#dbline;
            my $was;                         # Flag: did we print something
                                             # in this file?

            # For each line in the file ...
            for ($i = 1 ; $i <= $max ; $i++) {
                # We've got something on this line.
                if (defined $dbline{$i}) {
                    # Print the header if we haven't.
                    print $OUT "$file:\n" unless $was++;

                    # Print the line.
                    print $OUT " $i:\t", $dbline[$i];

                    # Pull out the condition and the action.
                    ($stop, $action) = split (/\0/, $dbline{$i});

                    # Print the break if there is one and it's wanted.
                    print $OUT "   break if (", $stop, ")\n"
                      if $stop
                      and $break_wanted;

                    # Print the action if there is one and it's wanted.
                    print $OUT "   action:  ", $action, "\n"
                      if $action
                      and $action_wanted;

                    # Quit if the user hit interrupt.
                    last if $signal;
                } ## end if (defined $dbline{$i...
            } ## end for ($i = 1 ; $i <= $max...
        } ## end for my $file (keys %had_breakpoints)
    } ## end if ($break_wanted or $action_wanted)

    # Look for breaks in not-yet-compiled subs:
    if (%postponed and $break_wanted) {
        print $OUT "Postponed breakpoints in subroutines:\n";
        my $subname;
        for $subname (keys %postponed) {
            print $OUT " $subname\t$postponed{$subname}\n";
            last if $signal;
        }
    } ## end if (%postponed and $break_wanted)

    # Find files that have not-yet-loaded breaks:
    my @have = map {    # Combined keys
        keys %{ $postponed_file{$_} }
    } keys %postponed_file;

    # If there are any, list them.
    if (@have and ($break_wanted or $action_wanted)) {
        print $OUT "Postponed breakpoints in files:\n";
        my ($file, $line);

        for $file (keys %postponed_file) {
            my $db = $postponed_file{$file};
            print $OUT " $file:\n";
            for $line (sort { $a <=> $b } keys %$db) {
                print $OUT "  $line:\n";
                my ($stop, $action) = split (/\0/, $$db{$line});
                print $OUT "    break if (", $stop, ")\n"
                  if $stop
                  and $break_wanted;
                print $OUT "    action:  ", $action, "\n"
                  if $action
                  and $action_wanted;
                last if $signal;
            } ## end for $line (sort { $a <=>...
            last if $signal;
        } ## end for $file (keys %postponed_file)
    } ## end if (@have and ($break_wanted...
    if (%break_on_load and $break_wanted) {
        print $OUT "Breakpoints on load:\n";
        my $file;
        for $file (keys %break_on_load) {
            print $OUT " $file\n";
            last if $signal;
        }
    } ## end if (%break_on_load and...
    if ($watch_wanted) {
        if ($trace & 2) {
            print $OUT "Watch-expressions:\n" if @to_watch;
            for my $expr (@to_watch) {
                print $OUT " $expr\n";
                last if $signal;
            }
        } ## end if ($trace & 2)
    } ## end if ($watch_wanted)
} ## end sub cmd_L

sub cmd_M {
    &list_modules();
}

sub cmd_o {
    my $cmd = shift;
    my $opt = shift || '';    # opt[=val]

    # Nonblank. Try to parse and process.
    if ($opt =~ /^(\S.*)/) {
        &parse_options($1);
    }

    # Blank. List the current option settings.
    else {
        for (@options) {
            &dump_option($_);
        }
    }
} ## end sub cmd_o

sub cmd_O {
    print $OUT "The old O command is now the o command.\n";             # hint
    print $OUT "Use 'h' to get current command help synopsis or\n";     #
    print $OUT "use 'o CommandSet=pre580' to revert to old usage\n";    #
}

sub cmd_v {
    my $cmd  = shift;
    my $line = shift;

    # Extract the line to list around. (Astute readers will have noted that
    # this pattern will match whether or not a numeric line is specified,
    # which means that we'll always enter this loop (though a non-numeric
    # argument results in no action at all)).
    if ($line =~ /^(\d*)$/) {
        # Total number of lines to list (a windowful).
        $incr = $window - 1;

        # Set the start to the argument given (if there was one).
       $start = $1 if $1;

        # Back up by the context amount.
        $start -= $preview;

        # Put together a linespec that cmd_l will like.
        $line = $start . '-' . ($start + $incr);

        # List the lines.
        &cmd_l('l', $line);
    } ## end if ($line =~ /^(\d*)$/)
} ## end sub cmd_v

sub cmd_w {
    my $cmd  = shift;

    # Null expression if no arguments.
    my $expr = shift || '';

    # If expression is not null ...
    if ($expr =~ /^(\S.*)/) {
        # ... save it.
        push @to_watch, $expr;

        # Parameterize DB::eval and call it to get the expression's value
        # in the user's context. This version can handle expressions which
        # return a list value.
        $evalarg = $expr;
        my ($val) = join(' ', &eval);
        $val = (defined $val) ? "'$val'" : 'undef';

        # Save the current value of the expression.
        push @old_watch, $val;

        # We are now watching expressions.
        $trace |= 2;
    } ## end if ($expr =~ /^(\S.*)/)

    # You have to give one to get one.
    else {
        print $OUT
          "Adding a watch-expression requires an expression\n";    # hint
    }
} ## end sub cmd_w

sub cmd_W {
    my $cmd  = shift;
    my $expr = shift || '';

    # Delete them all.
    if ($expr eq '*') {
        # Not watching now.
        $trace &= ~2;

        print $OUT "Deleting all watch expressions ...\n";

        # And all gone.
        @to_watch = @old_watch = ();
    }

    # Delete one of them.
    elsif ($expr =~ /^(\S.*)/) {
        # Where we are in the list.
        my $i_cnt = 0;

        # For each expression ...
        foreach (@to_watch) {
            my $val = $to_watch[$i_cnt];

            # Does this one match the command argument?
            if ($val eq $expr) {    # =~ m/^\Q$i$/) {
                # Yes. Turn it off, and its value too.
                splice(@to_watch, $i_cnt, 1);
                splice(@old_watch, $i_cnt, 1);
            }
            $i_cnt++;
        } ## end foreach (@to_watch)

        # We don't bother to turn watching off because
        #  a) we don't want to stop calling watchfunction() it it exists
        #  b) foreach over a null list doesn't do anything anyway

    } ## end elsif ($expr =~ /^(\S.*)/)

    # No command arguments entered.
    else {
        print $OUT
"Deleting a watch-expression requires an expression, or '*' for all\n"
          ;                         # hint
    }
} ## end sub cmd_W

### END of the API section

sub save {
    # Save eval failure, command failure, extended OS error, output field 
    # separator, input record separator, output record separator and 
    # the warning setting.
    @saved = ($@, $!, $^E, $,, $/, $\, $^W);

    $,     = "";             # output field separator is null string
    $/     = "\n";           # input record separator is newline
    $\     = "";             # output record separator is null string
    $^W    = 0;              # warnings are off
} ## end sub save

sub print_lineinfo {
    # Make the terminal sensible if we're not the primary debugger.
    resetterm(1) if $LINEINFO eq $OUT and $term_pid != $$;
    local $\ = '';
    local $, = '';
    print $LINEINFO @_;
} ## end sub print_lineinfo

# The following takes its argument via $evalarg to preserve current @_

sub postponed_sub {
    # Get the subroutine name.
    my $subname = shift;

    # If this is a 'break +<n> if <condition>' ...
    if ($postponed{$subname} =~ s/^break\s([+-]?\d+)\s+if\s//) {
        # If there's no offset, use '+0'.
        my $offset = $1 || 0;

        # find_sub's value is 'fullpath-filename:start-stop'. It's
        # possible that the filename might have colons in it too.
        my ($file, $i) = (find_sub($subname) =~ /^(.*):(\d+)-.*$/);
        if ($i) {
            # We got the start line. Add the offset '+<n>' from 
            # $postponed{subname}.
            $i += $offset;

            # Switch to the file this sub is in, temporarily.
            local *dbline = $main::{ '_<' . $file };

            # No warnings, please.
            local $^W     = 0;                         # != 0 is magical below

            # This file's got a breakpoint in it.
            $had_breakpoints{$file} |= 1;

            # Last line in file.
            my $max = $#dbline;

            # Search forward until we hit a breakable line or get to
            # the end of the file.
            ++$i until $dbline[$i] != 0 or $i >= $max;

            # Copy the breakpoint in and delete it from %postponed.
            $dbline{$i} = delete $postponed{$subname};
        } ## end if ($i)

        # find_sub didn't find the sub.
        else {
            local $\ = '';
            print $OUT "Subroutine $subname not found.\n";
        }
        return;
    } ## end if ($postponed{$subname...
    elsif ($postponed{$subname} eq 'compile') { $signal = 1 }

    #print $OUT "In postponed_sub for `$subname'.\n";
} ## end sub postponed_sub

sub postponed {
    # If there's a break, process it.
    if ($ImmediateStop) {
        # Right, we've stopped. Turn it off.
        $ImmediateStop = 0;

        # Enter the command loop when DB::DB gets called.
        $signal        = 1;
    }

    # If this is a subroutine, let postponed_sub() deal with it.
    return &postponed_sub unless ref \$_[0] eq 'GLOB';

    # Not a subroutine. Deal with the file.
    local *dbline = shift;
    my $filename = $dbline;
    $filename =~ s/^_<//;
    local $\ = '';
    $signal = 1, print $OUT "'$filename' loaded...\n"
      if $break_on_load{$filename};
    print_lineinfo(' ' x $stack_depth, "Package $filename.\n") if $frame;

    # Do we have any breakpoints to put in this file?
    return unless $postponed_file{$filename};

    # Yes. Mark this file as having breakpoints.
    $had_breakpoints{$filename} |= 1;

    # "Cannot be done: unsufficient magic" - we can't just put the
    # breakpoints saved in %postponed_file into %dbline by assigning
    # the whole hash; we have to do it one item at a time for the
    # breakpoints to be set properly.
    #%dbline = %{$postponed_file{$filename}}; 

    # Set the breakpoints, one at a time.
    my $key;

    for $key (keys %{ $postponed_file{$filename} }) {
        # Stash the saved breakpoint into the current file's magic line array.
        $dbline{$key} = ${ $postponed_file{$filename} }{$key};
    }

    # This file's been compiled; discard the stored breakpoints.
    delete $postponed_file{$filename};

} ## end sub postponed

sub dumpit {
    # Save the current output filehandle and switch to the one
    # passed in as the first parameter.
    local ($savout) = select(shift);

    # Save current settings of $single and $trace, and then turn them off.
    my $osingle = $single;
    my $otrace  = $trace;
    $single = $trace = 0;

    # XXX Okay, what do $frame and $doret do, again?
    local $frame = 0;
    local $doret = -2;

    # Load dumpvar.pl unless we've already got the sub we need from it.
    unless (defined &main::dumpValue) {
        do 'dumpvar.pl';
    }

    # If the load succeeded (or we already had dumpvalue()), go ahead
    # and dump things.
    if (defined &main::dumpValue) {
        local $\ = '';
        local $, = '';
        local $" = ' ';
        my $v = shift;
        my $maxdepth = shift || $option{dumpDepth};
        $maxdepth = -1 unless defined $maxdepth;    # -1 means infinite depth
        &main::dumpValue($v, $maxdepth);
    } ## end if (defined &main::dumpValue)

    # Oops, couldn't load dumpvar.pl.
    else {
        local $\ = '';
        print $OUT "dumpvar.pl not available.\n";
    }

    # Reset $single and $trace to their old values.
    $single = $osingle;
    $trace  = $otrace;

    # Restore the old filehandle.
    select($savout);
} ## end sub dumpit

# Tied method do not create a context, so may get wrong message:

sub print_trace {
    local $\ = '';
    my $fh = shift;
    # If this is going to a slave editor, but we're not the primary
    # debugger, reset it first.
    resetterm(1)
      if $fh eq $LINEINFO          # slave editor
      and $LINEINFO eq $OUT        # normal output
      and $term_pid != $$;         # not the primary

    # Collect the actual trace information to be formatted.
    # This is an array of hashes of subroutine call info.
    my @sub = dump_trace($_[0] + 1, $_[1]);

    # Grab the "short report" flag from @_.
    my $short = $_[2];    # Print short report, next one for sub name

    # Run through the traceback info, format it, and print it.
    my $s;
    for ($i = 0 ; $i <= $#sub ; $i++) {
        # Drop out if the user has lost interest and hit control-C.
        last if $signal;

        # Set the separator so arrys print nice. 
        local $" = ', ';

        # Grab and stringify the arguments if they are there.
        my $args =
          defined $sub[$i]{args}
          ? "(@{ $sub[$i]{args} })"
          : '';
        # Shorten them up if $maxtrace says they're too long.
        $args = (substr $args, 0, $maxtrace - 3) . '...'
          if length $args > $maxtrace;

        # Get the file name.
        my $file = $sub[$i]{file};

        # Put in a filename header if short is off.
        $file = $file eq '-e' ? $file : "file `$file'" unless $short;

        # Get the actual sub's name, and shorten to $maxtrace's requirement.
        $s = $sub[$i]{sub};
        $s = (substr $s, 0, $maxtrace - 3) . '...' if length $s > $maxtrace;

        # Short report uses trimmed file and sub names.
        if ($short) {
            my $sub = @_ >= 4 ? $_[3] : $s;
            print $fh
              "$sub[$i]{context}=$sub$args from $file:$sub[$i]{line}\n";
        } ## end if ($short)

        # Non-short report includes full names.
        else {
            print $fh "$sub[$i]{context} = $s$args" . " called from $file" .
              " line $sub[$i]{line}\n";
        }
    } ## end for ($i = 0 ; $i <= $#sub...
} ## end sub print_trace

sub dump_trace {

    # How many levels to skip.
    my $skip = shift;

    # How many levels to show. (1e9 is a cheap way of saying "all of them";
    # it's unlikely that we'll have more than a billion stack frames. If you
    # do, you've got an awfully big machine...)
    my $count = shift || 1e9;

    # We increment skip because caller(1) is the first level *back* from
    # the current one.  Add $skip to the count of frames so we have a 
    # simple stop criterion, counting from $skip to $count+$skip.
    $skip++;
    $count += $skip;

    # These variables are used to capture output from caller();
    my ($p, $file, $line, $sub, $h, $context);

    my ($e, $r, @a, @sub, $args);

    # XXX Okay... why'd we do that?
    my $nothard = not $frame & 8;
    local $frame = 0;    

    # Do not want to trace this.
    my $otrace = $trace;
    $trace = 0;

    # Start out at the skip count.
    # If we haven't reached the number of frames requested, and caller() is
    # still returning something, stay in the loop. (If we pass the requested
    # number of stack frames, or we run out - caller() returns nothing - we
    # quit.
    # Up the stack frame index to go back one more level each time.
    for (
        $i = $skip ;
        $i < $count
        and ($p, $file, $line, $sub, $h, $context, $e, $r) = caller($i) ;
        $i++
      )
    {

        # Go through the arguments and save them for later.
        @a = ();
        for $arg (@args) {
            my $type;
            if (not defined $arg) {                    # undefined parameter
                push @a, "undef";
            }

            elsif ($nothard and tied $arg) {           # tied parameter
                push @a, "tied";
            }
            elsif ($nothard and $type = ref $arg) {    # reference
                push @a, "ref($type)";
            }
            else {                                     # can be stringified
                local $_ =
                  "$arg";    # Safe to stringify now - should not call f().

                # Backslash any single-quotes or backslashes.
                s/([\'\\])/\\$1/g;

                # Single-quote it unless it's a number or a colon-separated
                # name.
                s/(.*)/'$1'/s
                  unless /^(?: -?[\d.]+ | \*[\w:]* )$/x;

                # Turn high-bit characters into meta-whatever.
                s/([\200-\377])/sprintf("M-%c",ord($1)&0177)/eg;

                # Turn control characters into ^-whatever.
                s/([\0-\37\177])/sprintf("^%c",ord($1)^64)/eg;

                push (@a, $_);
            } ## end else [ if (not defined $arg)
        } ## end for $arg (@args)

        # If context is true, this is array (@)context.
        # If context is false, this is scalar ($) context.
        # If neither, context isn't defined. (This is apparently a 'can't 
        # happen' trap.)
        $context = $context ? '@' : (defined $context ? "\$" : '.');

        # if the sub has args ($h true), make an anonymous array of the
        # dumped args.
        $args = $h ? [@a] : undef;

        # remove trailing newline-whitespace-semicolon-end of line sequence
        # from the eval text, if any.
        $e =~ s/\n\s*\;\s*\Z//  if $e;

        # Escape backslashed single-quotes again if necessary.
        $e =~ s/([\\\'])/\\$1/g if $e;

        # if the require flag is true, the eval text is from a require.
        if ($r) {
            $sub = "require '$e'";
        }
        # if it's false, the eval text is really from an eval.
        elsif (defined $r) {
            $sub = "eval '$e'";
        }

        # If the sub is '(eval)', this is a block eval, meaning we don't
        # know what the eval'ed text actually was.
        elsif ($sub eq '(eval)') {
            $sub = "eval {...}";
        }

        # Stick the collected information into @sub as an anonymous hash.
        push (
            @sub,
            {
                context => $context,
                sub     => $sub,
                args    => $args,
                file    => $file,
                line    => $line
            }
            );

        # Stop processing frames if the user hit control-C.
        last if $signal;
    } ## end for ($i = $skip ; $i < ...

    # Restore the trace value again.
    $trace = $otrace;
    @sub;
} ## end sub dump_trace

sub action {
    my $action = shift;

    while ($action =~ s/\\$//) {
        # We have a backslash on the end. Read more.
        $action .= &gets;
    } ## end while ($action =~ s/\\$//)

    # Return the assembled action.
    $action;
} ## end sub action

sub unbalanced {

    # I hate using globals!
    $balanced_brace_re ||= qr{ 
        ^ \{
             (?:
                 (?> [^{}] + )              # Non-parens without backtracking
                |
                 (??{ $balanced_brace_re }) # Group with matching parens
              ) *
          \} $
   }x;
    return $_[0] !~ m/$balanced_brace_re/;
} ## end sub unbalanced

sub gets {
    &readline("cont: ");
}

sub system {

    # We save, change, then restore STDIN and STDOUT to avoid fork() since
    # some non-Unix systems can do system() but have problems with fork().
    open(SAVEIN,  "<&STDIN")  || &warn("Can't save STDIN");
    open(SAVEOUT, ">&STDOUT") || &warn("Can't save STDOUT");
    open(STDIN,   "<&IN")     || &warn("Can't redirect STDIN");
    open(STDOUT,  ">&OUT")    || &warn("Can't redirect STDOUT");

    # XXX: using csh or tcsh destroys sigint retvals!
    system(@_);
    open(STDIN,  "<&SAVEIN")  || &warn("Can't restore STDIN");
    open(STDOUT, ">&SAVEOUT") || &warn("Can't restore STDOUT");
    close(SAVEIN);
    close(SAVEOUT);

    # most of the $? crud was coping with broken cshisms
    if ($? >> 8) {
        &warn("(Command exited ", ($? >> 8), ")\n");
    }
    elsif ($?) {
        &warn(
            "(Command died of SIG#",
            ($? & 127),
            (($? & 128) ? " -- core dumped" : ""),
            ")", "\n"
            );
    } ## end elsif ($?)

    return $?;

} ## end sub system

sub setterm {
    # Load Term::Readline, but quietly; don't debug it and don't trace it.
    local $frame = 0;
    local $doret = -2;
    eval { require Term::ReadLine } or die $@;

    # If noTTY is set, but we have a TTY name, go ahead and hook up to it.
    if ($notty) {
        if ($tty) {
            my ($i, $o) = split $tty, /,/;
            $o = $i unless defined $o;
            open(IN,  "<$i") or die "Cannot open TTY `$i' for read: $!";
            open(OUT, ">$o") or die "Cannot open TTY `$o' for write: $!";
            $IN  = \*IN;
            $OUT = \*OUT;
            my $sel = select($OUT);
            $| = 1;
            select($sel);
        } ## end if ($tty)

        # We don't have a TTY - try to find one via Term::Rendezvous.
        else {
            eval "require Term::Rendezvous;" or die;
            # See if we have anything to pass to Term::Rendezvous.
            # Use /tmp/perldbtty$$ if not.
            my $rv = $ENV{PERLDB_NOTTY} || "/tmp/perldbtty$$";

            # Rendezvous and get the filehandles.
            my $term_rv = new Term::Rendezvous $rv;
            $IN  = $term_rv->IN;
            $OUT = $term_rv->OUT;
        } ## end else [ if ($tty)
    } ## end if ($notty)


    # We're a daughter debugger. Try to fork off another TTY.
    if ($term_pid eq '-1') {    # In a TTY with another debugger
        resetterm(2);
    }

    # If we shouldn't use Term::ReadLine, don't.
    if (!$rl) {
        $term = new Term::ReadLine::Stub 'perldb', $IN, $OUT;
    }

    # We're using Term::ReadLine. Get all the attributes for this terminal.
    else {
        $term = new Term::ReadLine 'perldb', $IN, $OUT;

        $rl_attribs = $term->Attribs;
        $rl_attribs->{basic_word_break_characters} .= '-:+/*,[])}'
          if defined $rl_attribs->{basic_word_break_characters}
          and index($rl_attribs->{basic_word_break_characters}, ":") == -1;
        $rl_attribs->{special_prefixes} = '$@&%';
        $rl_attribs->{completer_word_break_characters} .= '$@&%';
        $rl_attribs->{completion_function} = \&db_complete;
    } ## end else [ if (!$rl)

    # Set up the LINEINFO filehandle.
    $LINEINFO = $OUT     unless defined $LINEINFO;
    $lineinfo = $console unless defined $lineinfo;

    $term->MinLine(2);

    if ($term->Features->{setHistory} and "@hist" ne "?") {
        $term->SetHistory(@hist);
    }

    # XXX Ornaments are turned on unconditionally, which is not
    # always a good thing.
    ornaments($ornaments) if defined $ornaments;
    $term_pid = $$;
} ## end sub setterm

sub xterm_get_fork_TTY {
    (my $name = $0) =~ s,^.*[/\\],,s;
    open XT,
qq[3>&1 xterm -title "Daughter Perl debugger $pids $name" -e sh -c 'tty 1>&3;\
 sleep 10000000' |];

    # Get the output from 'tty' and clean it up a little.
    my $tty = <XT>;
    chomp $tty;

    $pidprompt = '';    # Shown anyway in titlebar

    # There's our new TTY.
    return $tty;
} ## end sub xterm_get_fork_TTY

# This example function resets $IN, $OUT itself
sub os2_get_fork_TTY {
    local $^F = 40;     # XXXX Fixme!
    local $\  = '';
    my ($in1, $out1, $in2, $out2);

    # Having -d in PERL5OPT would lead to a disaster...
    local $ENV{PERL5OPT} = $ENV{PERL5OPT} if $ENV{PERL5OPT};
    $ENV{PERL5OPT} =~ s/(?:^|(?<=\s))-d\b//  if $ENV{PERL5OPT};
    $ENV{PERL5OPT} =~ s/(?:^|(?<=\s))-d\B/-/ if $ENV{PERL5OPT};
    print $OUT "Making kid PERL5OPT->`$ENV{PERL5OPT}'.\n" if $ENV{PERL5OPT};
    local $ENV{PERL5LIB} = $ENV{PERL5LIB} ? $ENV{PERL5LIB} : $ENV{PERLLIB};
    $ENV{PERL5LIB} = '' unless defined $ENV{PERL5LIB};
    $ENV{PERL5LIB} = join ';', @ini_INC, split /;/, $ENV{PERL5LIB};
    (my $name = $0) =~ s,^.*[/\\],,s;
    my @args;

    if (
            pipe $in1, $out1
        and pipe $in2, $out2

        # system P_SESSION will fail if there is another process
        # in the same session with a "dependent" asynchronous child session.
        and @args = (
            $rl, fileno $in1, fileno $out2,
            "Daughter Perl debugger $pids $name"
        )
        and (
            ($kpid = CORE::system 4, $^X, '-we',
                <<'ES', @args) >= 0    # P_SESSION
END {sleep 5 unless $loaded}
BEGIN {open STDIN,  '</dev/con' or warn "reopen stdin: $!"}
use OS2::Process;

my ($rl, $in) = (shift, shift);        # Read from $in and pass through
set_title pop;
system P_NOWAIT, $^X, '-we', <<EOS or die "Cannot start a grandkid";
  open IN, '<&=$in' or die "open <&=$in: \$!";
  \$| = 1; print while sysread IN, \$_, 1<<16;
EOS

my $out = shift;
open OUT, ">&=$out" or die "Cannot open &=$out for writing: $!";
select OUT;    $| = 1;
require Term::ReadKey if $rl;
Term::ReadKey::ReadMode(4) if $rl; # Nodelay on kbd.  Pipe is automatically nodelay...
print while sysread STDIN, $_, 1<<($rl ? 16 : 0);
ES
            or warn "system P_SESSION: $!, $^E" and 0
        )
        and close $in1
        and close $out2
      )
    {
        $pidprompt = '';    # Shown anyway in titlebar
        reset_IN_OUT($in2, $out1);
        $tty = '*reset*';
        return '';          # Indicate that reset_IN_OUT is called
    } ## end if (pipe $in1, $out1 and...
    return;
} ## end sub os2_get_fork_TTY

sub create_IN_OUT {    # Create a window with IN/OUT handles redirected there

    # If we know how to get a new TTY, do it! $in will have
    # the TTY name if get_fork_TTY works.
    my $in = &get_fork_TTY if defined &get_fork_TTY;

    # It used to be that 
    $in = $fork_TTY if defined $fork_TTY;    # Backward compatibility

    if (not defined $in) {
        my $why = shift;

        # We don't know how.
        print_help(<<EOP) if $why == 1;
I<#########> Forked, but do not know how to create a new B<TTY>. I<#########>
EOP

        # Forked debugger.
        print_help(<<EOP) if $why == 2;
I<#########> Daughter session, do not know how to change a B<TTY>. I<#########>
  This may be an asynchronous session, so the parent debugger may be active.
EOP

        # Note that both debuggers are fighting over the same input.
        print_help(<<EOP) if $why != 4;
  Since two debuggers fight for the same TTY, input is severely entangled.

EOP
        print_help(<<EOP);
  I know how to switch the output to a different window in xterms
  and OS/2 consoles only.  For a manual switch, put the name of the created I<TTY>
  in B<\$DB::fork_TTY>, or define a function B<DB::get_fork_TTY()> returning this.

  On I<UNIX>-like systems one can get the name of a I<TTY> for the given window
  by typing B<tty>, and disconnect the I<shell> from I<TTY> by B<sleep 1000000>.

EOP
    } ## end if (not defined $in)
    elsif ($in ne '') {
        TTY($in);
    }
    else {
        $console = '';    # Indicate no need to open-from-the-console
    }
    undef $fork_TTY;
} ## end sub create_IN_OUT

sub resetterm {           # We forked, so we need a different TTY

    # Needs to be passed to create_IN_OUT() as well.
    my $in = shift;

    # resetterm(2): got in here because of a system() starting a debugger.
    # resetterm(1): just forked.
    my $systemed = $in > 1 ? '-' : '';

    # If there's already a list of pids, add this to the end.
    if ($pids) {
        $pids =~ s/\]/$systemed->$$]/;
    }

    # No pid list. Time to make one.
    else {
        $pids = "[$term_pid->$$]";
    }

    # The prompt we're going to be using for this debugger.
    $pidprompt = $pids;

    # We now 0wnz this terminal.
    $term_pid  = $$;

    # Just return if we're not supposed to try to create a new TTY.
    return unless $CreateTTY & $in;

    # Try to create a new IN/OUT pair.
    create_IN_OUT($in);
} ## end sub resetterm

sub readline {

    # Localize to prevent it from being smashed in the program being debugged.
    local $.;

    # Pull a line out of the typeahead if there's stuff there.
    if (@typeahead) {
        # How many lines left.
        my $left = @typeahead;

        # Get the next line.
        my $got  = shift @typeahead;

        # Print a message saying we got input from the typeahead.
        local $\ = '';
        print $OUT "auto(-$left)", shift, $got, "\n";

        # Add it to the terminal history (if possible).
        $term->AddHistory($got)
          if length($got) > 1
          and defined $term->Features->{addHistory};
        return $got;
    } ## end if (@typeahead)

    # We really need to read some input. Turn off entry/exit trace and 
    # return value printing.
    local $frame = 0;
    local $doret = -2;

    # If there are stacked filehandles to read from ...
    while (@cmdfhs) {
        # Read from the last one in the stack.
        my $line = CORE::readline($cmdfhs[-1]);
        # If we got a line ...
        defined $line
          ? (print $OUT ">> $line" and return $line)  # Echo and return
          : close pop @cmdfhs;                        # Pop and close
    } ## end while (@cmdfhs)

    # Nothing on the filehandle stack. Socket?
    if (ref $OUT and UNIVERSAL::isa($OUT, 'IO::Socket::INET')) {
        # Send anyting we have to send.
        $OUT->write(join ('', @_));

        # Receive anything there is to receive.
        my $stuff;
        $IN->recv($stuff, 2048);    # XXX "what's wrong with sysread?"
                                    # XXX Don't know. You tell me.

        # What we got.
        $stuff;
    } ## end if (ref $OUT and UNIVERSAL::isa...

    # No socket. Just read from the terminal.
    else {
        $term->readline(@_);
    }
} ## end sub readline

sub dump_option {
    my ($opt, $val) = @_;
    $val = option_val($opt, 'N/A');
    $val =~ s/([\\\'])/\\$1/g;
    printf $OUT "%20s = '%s'\n", $opt, $val;
} ## end sub dump_option

sub option_val {
    my ($opt, $default) = @_;
    my $val;

    # Does this option exist, and is it a variable?
    # If so, retrieve the value via the value in %optionVars.
    if (    defined $optionVars{$opt}
        and defined ${ $optionVars{$opt} }) {
        $val = ${ $optionVars{$opt} };
    }

    # Does this option exist, and it's a subroutine?
    # If so, call the subroutine via the ref in %optionAction
    # and capture the value.
    elsif ( defined $optionAction{$opt}
        and defined &{ $optionAction{$opt} }) {
        $val = &{ $optionAction{$opt} }();
    }

    # If there's an action or variable for the supplied option,
    # but no value was set, use the default.
    elsif (defined $optionAction{$opt} and not defined $option{$opt}
        or defined $optionVars{$opt} and not defined ${ $optionVars{$opt} })
    {
        $val = $default;
    }

    # Otherwise, do the simple hash lookup.
    else {
        $val = $option{$opt};
    }

    # If the value isn't defined, use the default.
    # Then return whatever the value is.
    $val = $default unless defined $val;
    $val;
} ## end sub option_val

sub parse_options {
    local ($_) = @_;
    local $\ = '';

    # These options need a value. Don't allow them to be clobbered by accident.
    my %opt_needs_val = map { ($_ => 1) } qw{
      dumpDepth arrayDepth hashDepth LineInfo maxTraceLen ornaments windowSize
      pager quote ReadLine recallCommand RemotePort ShellBang TTY CommandSet
      };

    while (length) {
        my $val_defaulted;

        # Clean off excess leading whitespace.
        s/^\s+// && next;

        # Options are always all word characters, followed by a non-word
        # separator.
        s/^(\w+)(\W?)// or print($OUT "Invalid option `$_'\n"), last;
        my ($opt, $sep) = ($1, $2);

        # Make sure that such an option exists.
        my $matches = grep(/^\Q$opt/ && ($option = $_), @options) ||
          grep(/^\Q$opt/i && ($option = $_), @options);

        print($OUT "Unknown option `$opt'\n"), next unless $matches;
        print($OUT "Ambiguous option `$opt'\n"), next if $matches > 1;

        my $val;

        # '?' as separator means query, but must have whitespace after it.
        if ("?" eq $sep) {
            print($OUT "Option query `$opt?' followed by non-space `$_'\n"),
              last
              if /^\S/;

            #&dump_option($opt);
        } ## end if ("?" eq $sep)

        # Separator is whitespace (or just a carriage return).
        # They're going for a default, which we assume is 1.
        elsif ($sep !~ /\S/) {
            $val_defaulted = 1;
            $val           = "1"; #  this is an evil default; make 'em set it!
        }

        # Separator is =. Trying to set a value.
        elsif ($sep eq "=") {
            # If quoted, extract a quoted string.
            if (s/ (["']) ( (?: \\. | (?! \1 ) [^\\] )* ) \1 //x) {
                my $quote = $1;
                ($val = $2) =~ s/\\([$quote\\])/$1/g;
            }

            # Not quoted. Use the whole thing. Warn about 'option='.
            else {
                s/^(\S*)//;
                $val = $1;
                print OUT qq(Option better cleared using $opt=""\n)
                  unless length $val;
            } ## end else [ if (s/ (["']) ( (?: \\. | (?! \1 ) [^\\] )* ) \1 //x)

        } ## end elsif ($sep eq "=")

        # "Quoted" with [], <>, or {}.  
        else {    #{ to "let some poor schmuck bounce on the % key in B<vi>."
            my ($end) = "\\" . substr(")]>}$sep", index("([<{", $sep), 1);  #}
            s/^(([^\\$end]|\\[\\$end])*)$end($|\s+)//
              or print($OUT "Unclosed option value `$opt$sep$_'\n"), last;
            ($val = $1) =~ s/\\([\\$end])/$1/g;
        } ## end else [ if ("?" eq $sep)

        # Impedance-match the code above to the code below.
        my $option = $opt;

        # Exclude non-booleans from getting set to 1 by default.
        if ($opt_needs_val{$option} && $val_defaulted) {
            my $cmd = ($CommandSet eq '580') ? 'o' : 'O';
            print $OUT
"Option `$opt' is non-boolean.  Use `$cmd $option=VAL' to set, `$cmd $option?' to query\n";
            next;
        } ## end if ($opt_needs_val{$option...

        # Save the option value.
        $option{$option} = $val if defined $val;

        # Load any module that this option requires.
        eval qq{
                local \$frame = 0; 
                local \$doret = -2; 
                require '$optionRequire{$option}';
                1;
               } || die    # XXX: shouldn't happen
          if defined $optionRequire{$option} &&
             defined $val;

        # Set it. 
        # Stick it in the proper variable if it goes in a variable.
        ${ $optionVars{$option} } = $val
          if defined $optionVars{$option} &&
          defined $val;

        # Call the appropriate sub if it gets set via sub.
        &{ $optionAction{$option} }($val)
          if defined $optionAction{$option} &&
          defined &{ $optionAction{$option} } &&
          defined $val;

        # Not initialization - echo the value we set it to.
        dump_option($option) unless $OUT eq \*STDERR;
    } ## end while (length)
} ## end sub parse_options

sub set_list {
    my ($stem, @list) = @_;
    my $val;

    # VAR_n: how many we have. Scalar assignment gets the number of items.
    $ENV{"${stem}_n"} = @list;

    # Grab each item in the list, escape the backslashes, encode the non-ASCII
    # as hex, and then save in the appropriate VAR_0, VAR_1, etc.
    for $i (0 .. $#list) {
        $val = $list[$i];
        $val =~ s/\\/\\\\/g;
        $val =~ s/([\0-\37\177\200-\377])/"\\0x" . unpack('H2',$1)/eg;
        $ENV{"${stem}_$i"} = $val;
    } ## end for $i (0 .. $#list)
} ## end sub set_list

sub get_list {
    my $stem = shift;
    my @list;
    my $n = delete $ENV{"${stem}_n"};
    my $val;
    for $i (0 .. $n - 1) {
        $val = delete $ENV{"${stem}_$i"};
        $val =~ s/\\((\\)|0x(..))/ $2 ? $2 : pack('H2', $3) /ge;
        push @list, $val;
    }
    @list;
} ## end sub get_list

sub catch {
    $signal = 1;
    return;    # Put nothing on the stack - malloc/free land!
}

sub warn {
    my ($msg) = join ("", @_);
    $msg .= ": $!\n" unless $msg =~ /\n$/;
    local $\ = '';
    print $OUT $msg;
} ## end sub warn

sub reset_IN_OUT {
    my $switch_li = $LINEINFO eq $OUT;

    # If there's a term and it's able to get a new tty, try to get one.
    if ($term and $term->Features->{newTTY}) {
        ($IN, $OUT) = (shift, shift);
        $term->newTTY($IN, $OUT);
    }

    # This term can't get a new tty now. Better luck later.
    elsif ($term) {
        &warn("Too late to set IN/OUT filehandles, enabled on next `R'!\n");
    }

    # Set the filehndles up as they were.
    else {
        ($IN, $OUT) = (shift, shift);
    }

    # Unbuffer the output filehandle.
    my $o = select $OUT;
    $| = 1;
    select $o;

    # Point LINEINFO to the same output filehandle if it was there before.
    $LINEINFO = $OUT if $switch_li;
} ## end sub reset_IN_OUT

sub TTY {
    if (@_ and $term and $term->Features->{newTTY}) {
        # This terminal supports switching to a new TTY.
        # Can be a list of two files, or on string containing both names,
        # comma-separated.
        # XXX Should this perhaps be an assignment from @_?
        my ($in, $out) = shift; 
        if ($in =~ /,/) {
            # Split list apart if supplied.
            ($in, $out) = split /,/, $in, 2;
        }
        else {
            # Use the same file for both input and output.
            $out = $in;
        }

        # Open file onto the debugger's filehandles, if you can.
        open IN, $in or die "cannot open `$in' for read: $!";
        open OUT, ">$out" or die "cannot open `$out' for write: $!";

        # Swap to the new filehandles.
        reset_IN_OUT(\*IN, \*OUT);

        # Save the setting for later.
        return $tty = $in;
    } ## end if (@_ and $term and $term...

    # Terminal doesn't support new TTY, or doesn't support readline.
    # Can't do it now, try restarting.
    &warn("Too late to set TTY, enabled on next `R'!\n") if $term and @_;
    
    # Useful if done through PERLDB_OPTS:
    $console = $tty = shift if @_;

    # Return whatever the TTY is.
    $tty or $console;
} ## end sub TTY

sub noTTY {
    if ($term) {
        &warn("Too late to set noTTY, enabled on next `R'!\n") if @_;
    }
    $notty = shift if @_;
    $notty;
} ## end sub noTTY

sub ReadLine {
    if ($term) {
        &warn("Too late to set ReadLine, enabled on next `R'!\n") if @_;
    }
    $rl = shift if @_;
    $rl;
} ## end sub ReadLine

sub RemotePort {
    if ($term) {
        &warn("Too late to set RemotePort, enabled on next 'R'!\n") if @_;
    }
    $remoteport = shift if @_;
    $remoteport;
} ## end sub RemotePort

sub tkRunning {
    if (${ $term->Features }{tkRunning}) {
        return $term->tkRunning(@_);
    }
    else {
        local $\ = '';
        print $OUT "tkRunning not supported by current ReadLine package.\n";
        0;
    }
} ## end sub tkRunning

sub NonStop {
    if ($term) {
        &warn("Too late to set up NonStop mode, enabled on next `R'!\n")
          if @_;
    }
    $runnonstop = shift if @_;
    $runnonstop;
} ## end sub NonStop

sub pager {
    if (@_) {
        $pager = shift;
        $pager = "|" . $pager unless $pager =~ /^(\+?\>|\|)/;
    }
    $pager;
} ## end sub pager

sub shellBang {

    # If we got an argument, meta-quote it, and add '\b' if it
    # ends in a word character.
    if (@_) {
        $sh = quotemeta shift;
        $sh .= "\\b" if $sh =~ /\w$/;
    }

    # Generate the printable version for the help:
    $psh = $sh;                       # copy it
    $psh =~ s/\\b$//;                 # Take off trailing \b if any
    $psh =~ s/\\(.)/$1/g;             # De-escape
    $psh;                             # return the printable version
} ## end sub shellBang

sub ornaments {
    if (defined $term) {
        # We don't want to show warning backtraces, but we do want die() ones.
        local ($warnLevel, $dieLevel) = (0, 1);

        # No ornaments if the terminal doesn't support them.
        return '' unless $term->Features->{ornaments};
        eval { $term->ornaments(@_) } || '';
    }

    # Use what was passed in if we can't determine it ourselves.
    else {
        $ornaments = shift;
    }
} ## end sub ornaments

sub recallCommand {

    # If there is input, metaquote it. Add '\b' if it ends with a word
    # character.
    if (@_) {
        $rc = quotemeta shift;
        $rc .= "\\b" if $rc =~ /\w$/;
    }

    # Build it into a printable version.
    $prc = $rc;                             # Copy it
    $prc =~ s/\\b$//;                       # Remove trailing \b
    $prc =~ s/\\(.)/$1/g;                   # Remove escapes
    $prc;                                   # Return the printable version
} ## end sub recallCommand

sub LineInfo {
    return $lineinfo unless @_;
    $lineinfo = shift;

    #  If this is a valid "thing to be opened for output", tack a 
    # '>' onto the front.
    my $stream = ($lineinfo =~ /^(\+?\>|\|)/) ? $lineinfo : ">$lineinfo";

    # If this is a pipe, the stream points to a slave editor.
    $slave_editor = ($stream =~ /^\|/);

    # Open it up and unbuffer it.
    open(LINEINFO, "$stream") || &warn("Cannot open `$stream' for write");
    $LINEINFO = \*LINEINFO;
    my $save = select($LINEINFO);
    $| = 1;
    select($save);

    # Hand the file or pipe back again.
    $lineinfo;
} ## end sub LineInfo

sub list_modules {    # versions
    my %version;
    my $file;
    # keys are the "as-loaded" name, values are the fully-qualified path
    # to the file itself.
    for (keys %INC) {
        $file = $_;                                # get the module name
        s,\.p[lm]$,,i;                             # remove '.pl' or '.pm'
        s,/,::,g;                                  # change '/' to '::'
        s/^perl5db$/DB/;                           # Special case: debugger
                                                   # moves to package DB
        s/^Term::ReadLine::readline$/readline/;    # simplify readline

        # If the package has a $VERSION package global (as all good packages
        # should!) decode it and save as partial message.
        if (defined ${ $_ . '::VERSION' }) {
            $version{$file} = "${ $_ . '::VERSION' } from ";
        }

        # Finish up the message with the file the package came from.
        $version{$file} .= $INC{$file};
    } ## end for (keys %INC)

    # Hey, dumpit() formats a hash nicely, so why not use it?
    dumpit($OUT, \%version);
} ## end sub list_modules

sub sethelp {

    # XXX: make sure there are tabs between the command and explanation,
    #      or print_help will screw up your formatting if you have
    #      eeevil ornaments enabled.  This is an insane mess.

    $help = "
Help is currently only available for the new 5.8 command set. 
No help is available for the old command set. 
We assume you know what you're doing if you switch to it.

B<T>		Stack trace.
B<s> [I<expr>]	Single step [in I<expr>].
B<n> [I<expr>]	Next, steps over subroutine calls [in I<expr>].
<B<CR>>		Repeat last B<n> or B<s> command.
B<r>		Return from current subroutine.
B<c> [I<line>|I<sub>]	Continue; optionally inserts a one-time-only breakpoint
		at the specified position.
B<l> I<min>B<+>I<incr>	List I<incr>+1 lines starting at I<min>.
B<l> I<min>B<->I<max>	List lines I<min> through I<max>.
B<l> I<line>		List single I<line>.
B<l> I<subname>	List first window of lines from subroutine.
B<l> I<\$var>		List first window of lines from subroutine referenced by I<\$var>.
B<l>		List next window of lines.
B<->		List previous window of lines.
B<v> [I<line>]	View window around I<line>.
B<.>		Return to the executed line.
B<f> I<filename>	Switch to viewing I<filename>. File must be already loaded.
		I<filename> may be either the full name of the file, or a regular
		expression matching the full file name:
		B<f> I</home/me/foo.pl> and B<f> I<oo\\.> may access the same file.
		Evals (with saved bodies) are considered to be filenames:
		B<f> I<(eval 7)> and B<f> I<eval 7\\b> access the body of the 7th eval
		(in the order of execution).
B</>I<pattern>B</>	Search forwards for I<pattern>; final B</> is optional.
B<?>I<pattern>B<?>	Search backwards for I<pattern>; final B<?> is optional.
B<L> [I<a|b|w>]		List actions and or breakpoints and or watch-expressions.
B<S> [[B<!>]I<pattern>]	List subroutine names [not] matching I<pattern>.
B<t>		Toggle trace mode.
B<t> I<expr>		Trace through execution of I<expr>.
B<b>		Sets breakpoint on current line)
B<b> [I<line>] [I<condition>]
		Set breakpoint; I<line> defaults to the current execution line;
		I<condition> breaks if it evaluates to true, defaults to '1'.
B<b> I<subname> [I<condition>]
		Set breakpoint at first line of subroutine.
B<b> I<\$var>		Set breakpoint at first line of subroutine referenced by I<\$var>.
B<b> B<load> I<filename> Set breakpoint on 'require'ing the given file.
B<b> B<postpone> I<subname> [I<condition>]
		Set breakpoint at first line of subroutine after 
		it is compiled.
B<b> B<compile> I<subname>
		Stop after the subroutine is compiled.
B<B> [I<line>]	Delete the breakpoint for I<line>.
B<B> I<*>             Delete all breakpoints.
B<a> [I<line>] I<command>
		Set an action to be done before the I<line> is executed;
		I<line> defaults to the current execution line.
		Sequence is: check for breakpoint/watchpoint, print line
		if necessary, do action, prompt user if necessary,
		execute line.
B<a>		Does nothing
B<A> [I<line>]	Delete the action for I<line>.
B<A> I<*>             Delete all actions.
B<w> I<expr>		Add a global watch-expression.
B<w>     		Does nothing
B<W> I<expr>		Delete a global watch-expression.
B<W> I<*>             Delete all watch-expressions.
B<V> [I<pkg> [I<vars>]]	List some (default all) variables in package (default current).
		Use B<~>I<pattern> and B<!>I<pattern> for positive and negative regexps.
B<X> [I<vars>]	Same as \"B<V> I<currentpackage> [I<vars>]\".
B<x> I<expr>		Evals expression in list context, dumps the result.
B<m> I<expr>		Evals expression in list context, prints methods callable
		on the first element of the result.
B<m> I<class>		Prints methods callable via the given class.
B<M>		Show versions of loaded modules.
B<y> [I<n> [I<Vars>]]   List lexicals in higher scope <n>.  Vars same as B<V>.

B<<> ?			List Perl commands to run before each prompt.
B<<> I<expr>		Define Perl command to run before each prompt.
B<<<> I<expr>		Add to the list of Perl commands to run before each prompt.
B<< *>				Delete the list of perl commands to run before each prompt.
B<>> ?			List Perl commands to run after each prompt.
B<>> I<expr>		Define Perl command to run after each prompt.
B<>>B<>> I<expr>		Add to the list of Perl commands to run after each prompt.
B<>>B< *>		Delete the list of Perl commands to run after each prompt.
B<{> I<db_command>	Define debugger command to run before each prompt.
B<{> ?			List debugger commands to run before each prompt.
B<{ *>				Delete the list of debugger commands to run before each prompt.
B<{{> I<db_command>	Add to the list of debugger commands to run before each prompt.
B<$prc> I<number>	Redo a previous command (default previous command).
B<$prc> I<-number>	Redo number'th-to-last command.
B<$prc> I<pattern>	Redo last command that started with I<pattern>.
		See 'B<O> I<recallCommand>' too.
B<$psh$psh> I<cmd>  	Run cmd in a subprocess (reads from DB::IN, writes to DB::OUT)"
      . (
        $rc eq $sh
        ? ""
        : "
B<$psh> [I<cmd>] 	Run I<cmd> in subshell (forces \"\$SHELL -c 'cmd'\")."
      ) 
      . "
		See 'B<O> I<shellBang>' too.
B<source> I<file>		Execute I<file> containing debugger commands (may nest).
B<H> I<-number>	Display last number commands (default all).
B<p> I<expr>		Same as \"I<print {DB::OUT} expr>\" in current package.
B<|>I<dbcmd>		Run debugger command, piping DB::OUT to current pager.
B<||>I<dbcmd>		Same as B<|>I<dbcmd> but DB::OUT is temporarilly select()ed as well.
B<\=> [I<alias> I<value>]	Define a command alias, or list current aliases.
I<command>		Execute as a perl statement in current package.
B<R>		Pure-man-restart of debugger, some of debugger state
		and command-line options may be lost.
		Currently the following settings are preserved:
		history, breakpoints and actions, debugger B<O>ptions 
		and the following command-line options: I<-w>, I<-I>, I<-e>.

B<o> [I<opt>] ...	Set boolean option to true
B<o> [I<opt>B<?>]	Query options
B<o> [I<opt>B<=>I<val>] [I<opt>=B<\">I<val>B<\">] ... 
		Set options.  Use quotes in spaces in value.
    I<recallCommand>, I<ShellBang>	chars used to recall command or spawn shell;
    I<pager>			program for output of \"|cmd\";
    I<tkRunning>			run Tk while prompting (with ReadLine);
    I<signalLevel> I<warnLevel> I<dieLevel>	level of verbosity;
    I<inhibit_exit>		Allows stepping off the end of the script.
    I<ImmediateStop>		Debugger should stop as early as possible.
    I<RemotePort>			Remote hostname:port for remote debugging
  The following options affect what happens with B<V>, B<X>, and B<x> commands:
    I<arrayDepth>, I<hashDepth> 	print only first N elements ('' for all);
    I<compactDump>, I<veryCompact> 	change style of array and hash dump;
    I<globPrint> 			whether to print contents of globs;
    I<DumpDBFiles> 		dump arrays holding debugged files;
    I<DumpPackages> 		dump symbol tables of packages;
    I<DumpReused> 			dump contents of \"reused\" addresses;
    I<quote>, I<HighBit>, I<undefPrint> 	change style of string dump;
    I<bareStringify> 		Do not print the overload-stringified value;
  Other options include:
    I<PrintRet>		affects printing of return value after B<r> command,
    I<frame>		affects printing messages on subroutine entry/exit.
    I<AutoTrace>	affects printing messages on possible breaking points.
    I<maxTraceLen>	gives max length of evals/args listed in stack trace.
    I<ornaments> 	affects screen appearance of the command line.
    I<CreateTTY> 	bits control attempts to create a new TTY on events:
			1: on fork()	2: debugger is started inside debugger
			4: on startup
	During startup options are initialized from \$ENV{PERLDB_OPTS}.
	You can put additional initialization options I<TTY>, I<noTTY>,
	I<ReadLine>, I<NonStop>, and I<RemotePort> there (or use
	`B<R>' after you set them).

B<q> or B<^D>		Quit. Set B<\$DB::finished = 0> to debug global destruction.
B<h>		Summary of debugger commands.
B<h> [I<db_command>]	Get help [on a specific debugger command], enter B<|h> to page.
B<h h>		Long help for debugger commands
B<$doccmd> I<manpage>	Runs the external doc viewer B<$doccmd> command on the 
		named Perl I<manpage>, or on B<$doccmd> itself if omitted.
		Set B<\$DB::doccmd> to change viewer.

Type `|h h' for a paged display if this was too hard to read.

";    # Fix balance of vi % matching: }}}}

    #  note: tabs in the following section are not-so-helpful
    $summary = <<"END_SUM";
I<List/search source lines:>               I<Control script execution:>
  B<l> [I<ln>|I<sub>]  List source code            B<T>           Stack trace
  B<-> or B<.>      List previous/current line  B<s> [I<expr>]    Single step [in expr]
  B<v> [I<line>]    View around line            B<n> [I<expr>]    Next, steps over subs
  B<f> I<filename>  View source in file         <B<CR>/B<Enter>>  Repeat last B<n> or B<s>
  B</>I<pattern>B</> B<?>I<patt>B<?>   Search forw/backw    B<r>           Return from subroutine
  B<M>           Show module versions        B<c> [I<ln>|I<sub>]  Continue until position
I<Debugger controls:>                        B<L>           List break/watch/actions
  B<o> [...]     Set debugger options        B<t> [I<expr>]    Toggle trace [trace expr]
  B<<>[B<<>]|B<{>[B<{>]|B<>>[B<>>] [I<cmd>] Do pre/post-prompt B<b> [I<ln>|I<event>|I<sub>] [I<cnd>] Set breakpoint
  B<$prc> [I<N>|I<pat>]   Redo a previous command     B<B> I<ln|*>      Delete a/all breakpoints
  B<H> [I<-num>]    Display last num commands   B<a> [I<ln>] I<cmd>  Do cmd before line
  B<=> [I<a> I<val>]   Define/list an alias        B<A> I<ln|*>      Delete a/all actions
  B<h> [I<db_cmd>]  Get help on command         B<w> I<expr>      Add a watch expression
  B<h h>         Complete help page          B<W> I<expr|*>    Delete a/all watch exprs
  B<|>[B<|>]I<db_cmd>  Send output to pager        B<$psh>\[B<$psh>\] I<syscmd> Run cmd in a subprocess
  B<q> or B<^D>     Quit                        B<R>           Attempt a restart
I<Data Examination:>     B<expr>     Execute perl code, also see: B<s>,B<n>,B<t> I<expr>
  B<x>|B<m> I<expr>       Evals expr in list context, dumps the result or lists methods.
  B<p> I<expr>         Print expression (uses script's current package).
  B<S> [[B<!>]I<pat>]     List subroutine names [not] matching pattern
  B<V> [I<Pk> [I<Vars>]]  List Variables in Package.  Vars can be ~pattern or !pattern.
  B<X> [I<Vars>]       Same as \"B<V> I<current_package> [I<Vars>]\".
  B<y> [I<n> [I<Vars>]]   List lexicals in higher scope <n>.  Vars same as B<V>.
For more help, type B<h> I<cmd_letter>, or run B<$doccmd perldebug> for all docs.
END_SUM

    # ')}}; # Fix balance of vi % matching

    # and this is really numb...
    $pre580_help = "
B<T>		Stack trace.
B<s> [I<expr>]	Single step [in I<expr>].
B<n> [I<expr>]	Next, steps over subroutine calls [in I<expr>].
B<CR>>			Repeat last B<n> or B<s> command.
B<r>		Return from current subroutine.
B<c> [I<line>|I<sub>]	Continue; optionally inserts a one-time-only breakpoint
		at the specified position.
B<l> I<min>B<+>I<incr>	List I<incr>+1 lines starting at I<min>.
B<l> I<min>B<->I<max>	List lines I<min> through I<max>.
B<l> I<line>		List single I<line>.
B<l> I<subname>	List first window of lines from subroutine.
B<l> I<\$var>		List first window of lines from subroutine referenced by I<\$var>.
B<l>		List next window of lines.
B<->		List previous window of lines.
B<w> [I<line>]	List window around I<line>.
B<.>		Return to the executed line.
B<f> I<filename>	Switch to viewing I<filename>. File must be already loaded.
		I<filename> may be either the full name of the file, or a regular
		expression matching the full file name:
		B<f> I</home/me/foo.pl> and B<f> I<oo\\.> may access the same file.
		Evals (with saved bodies) are considered to be filenames:
		B<f> I<(eval 7)> and B<f> I<eval 7\\b> access the body of the 7th eval
		(in the order of execution).
B</>I<pattern>B</>	Search forwards for I<pattern>; final B</> is optional.
B<?>I<pattern>B<?>	Search backwards for I<pattern>; final B<?> is optional.
B<L>		List all breakpoints and actions.
B<S> [[B<!>]I<pattern>]	List subroutine names [not] matching I<pattern>.
B<t>		Toggle trace mode.
B<t> I<expr>		Trace through execution of I<expr>.
B<b> [I<line>] [I<condition>]
		Set breakpoint; I<line> defaults to the current execution line;
		I<condition> breaks if it evaluates to true, defaults to '1'.
B<b> I<subname> [I<condition>]
		Set breakpoint at first line of subroutine.
B<b> I<\$var>		Set breakpoint at first line of subroutine referenced by I<\$var>.
B<b> B<load> I<filename> Set breakpoint on `require'ing the given file.
B<b> B<postpone> I<subname> [I<condition>]
		Set breakpoint at first line of subroutine after 
		it is compiled.
B<b> B<compile> I<subname>
		Stop after the subroutine is compiled.
B<d> [I<line>]	Delete the breakpoint for I<line>.
B<D>		Delete all breakpoints.
B<a> [I<line>] I<command>
		Set an action to be done before the I<line> is executed;
		I<line> defaults to the current execution line.
		Sequence is: check for breakpoint/watchpoint, print line
		if necessary, do action, prompt user if necessary,
		execute line.
B<a> [I<line>]	Delete the action for I<line>.
B<A>		Delete all actions.
B<W> I<expr>		Add a global watch-expression.
B<W>		Delete all watch-expressions.
B<V> [I<pkg> [I<vars>]]	List some (default all) variables in package (default current).
		Use B<~>I<pattern> and B<!>I<pattern> for positive and negative regexps.
B<X> [I<vars>]	Same as \"B<V> I<currentpackage> [I<vars>]\".
B<x> I<expr>		Evals expression in list context, dumps the result.
B<m> I<expr>		Evals expression in list context, prints methods callable
		on the first element of the result.
B<m> I<class>		Prints methods callable via the given class.

B<<> ?			List Perl commands to run before each prompt.
B<<> I<expr>		Define Perl command to run before each prompt.
B<<<> I<expr>		Add to the list of Perl commands to run before each prompt.
B<>> ?			List Perl commands to run after each prompt.
B<>> I<expr>		Define Perl command to run after each prompt.
B<>>B<>> I<expr>		Add to the list of Perl commands to run after each prompt.
B<{> I<db_command>	Define debugger command to run before each prompt.
B<{> ?			List debugger commands to run before each prompt.
B<{{> I<db_command>	Add to the list of debugger commands to run before each prompt.
B<$prc> I<number>	Redo a previous command (default previous command).
B<$prc> I<-number>	Redo number'th-to-last command.
B<$prc> I<pattern>	Redo last command that started with I<pattern>.
		See 'B<O> I<recallCommand>' too.
B<$psh$psh> I<cmd>  	Run cmd in a subprocess (reads from DB::IN, writes to DB::OUT)"
      . (
        $rc eq $sh
        ? ""
        : "
B<$psh> [I<cmd>] 	Run I<cmd> in subshell (forces \"\$SHELL -c 'cmd'\")."
      ) .
      "
		See 'B<O> I<shellBang>' too.
B<source> I<file>		Execute I<file> containing debugger commands (may nest).
B<H> I<-number>	Display last number commands (default all).
B<p> I<expr>		Same as \"I<print {DB::OUT} expr>\" in current package.
B<|>I<dbcmd>		Run debugger command, piping DB::OUT to current pager.
B<||>I<dbcmd>		Same as B<|>I<dbcmd> but DB::OUT is temporarilly select()ed as well.
B<\=> [I<alias> I<value>]	Define a command alias, or list current aliases.
I<command>		Execute as a perl statement in current package.
B<v>		Show versions of loaded modules.
B<R>		Pure-man-restart of debugger, some of debugger state
		and command-line options may be lost.
		Currently the following settings are preserved:
		history, breakpoints and actions, debugger B<O>ptions 
		and the following command-line options: I<-w>, I<-I>, I<-e>.

B<O> [I<opt>] ...	Set boolean option to true
B<O> [I<opt>B<?>]	Query options
B<O> [I<opt>B<=>I<val>] [I<opt>=B<\">I<val>B<\">] ... 
		Set options.  Use quotes in spaces in value.
    I<recallCommand>, I<ShellBang>	chars used to recall command or spawn shell;
    I<pager>			program for output of \"|cmd\";
    I<tkRunning>			run Tk while prompting (with ReadLine);
    I<signalLevel> I<warnLevel> I<dieLevel>	level of verbosity;
    I<inhibit_exit>		Allows stepping off the end of the script.
    I<ImmediateStop>		Debugger should stop as early as possible.
    I<RemotePort>			Remote hostname:port for remote debugging
  The following options affect what happens with B<V>, B<X>, and B<x> commands:
    I<arrayDepth>, I<hashDepth> 	print only first N elements ('' for all);
    I<compactDump>, I<veryCompact> 	change style of array and hash dump;
    I<globPrint> 			whether to print contents of globs;
    I<DumpDBFiles> 		dump arrays holding debugged files;
    I<DumpPackages> 		dump symbol tables of packages;
    I<DumpReused> 			dump contents of \"reused\" addresses;
    I<quote>, I<HighBit>, I<undefPrint> 	change style of string dump;
    I<bareStringify> 		Do not print the overload-stringified value;
  Other options include:
    I<PrintRet>		affects printing of return value after B<r> command,
    I<frame>		affects printing messages on subroutine entry/exit.
    I<AutoTrace>	affects printing messages on possible breaking points.
    I<maxTraceLen>	gives max length of evals/args listed in stack trace.
    I<ornaments> 	affects screen appearance of the command line.
    I<CreateTTY> 	bits control attempts to create a new TTY on events:
			1: on fork()	2: debugger is started inside debugger
			4: on startup
	During startup options are initialized from \$ENV{PERLDB_OPTS}.
	You can put additional initialization options I<TTY>, I<noTTY>,
	I<ReadLine>, I<NonStop>, and I<RemotePort> there (or use
	`B<R>' after you set them).

B<q> or B<^D>		Quit. Set B<\$DB::finished = 0> to debug global destruction.
B<h> [I<db_command>]	Get help [on a specific debugger command], enter B<|h> to page.
B<h h>		Summary of debugger commands.
B<$doccmd> I<manpage>	Runs the external doc viewer B<$doccmd> command on the 
		named Perl I<manpage>, or on B<$doccmd> itself if omitted.
		Set B<\$DB::doccmd> to change viewer.

Type `|h' for a paged display if this was too hard to read.

";    # Fix balance of vi % matching: }}}}

    #  note: tabs in the following section are not-so-helpful
    $pre580_summary = <<"END_SUM";
I<List/search source lines:>               I<Control script execution:>
  B<l> [I<ln>|I<sub>]  List source code            B<T>           Stack trace
  B<-> or B<.>      List previous/current line  B<s> [I<expr>]    Single step [in expr]
  B<w> [I<line>]    List around line            B<n> [I<expr>]    Next, steps over subs
  B<f> I<filename>  View source in file         <B<CR>/B<Enter>>  Repeat last B<n> or B<s>
  B</>I<pattern>B</> B<?>I<patt>B<?>   Search forw/backw    B<r>           Return from subroutine
  B<v>           Show versions of modules    B<c> [I<ln>|I<sub>]  Continue until position
I<Debugger controls:>                        B<L>           List break/watch/actions
  B<O> [...]     Set debugger options        B<t> [I<expr>]    Toggle trace [trace expr]
  B<<>[B<<>]|B<{>[B<{>]|B<>>[B<>>] [I<cmd>] Do pre/post-prompt B<b> [I<ln>|I<event>|I<sub>] [I<cnd>] Set breakpoint
  B<$prc> [I<N>|I<pat>]   Redo a previous command     B<d> [I<ln>] or B<D> Delete a/all breakpoints
  B<H> [I<-num>]    Display last num commands   B<a> [I<ln>] I<cmd>  Do cmd before line
  B<=> [I<a> I<val>]   Define/list an alias        B<W> I<expr>      Add a watch expression
  B<h> [I<db_cmd>]  Get help on command         B<A> or B<W>      Delete all actions/watch
  B<|>[B<|>]I<db_cmd>  Send output to pager        B<$psh>\[B<$psh>\] I<syscmd> Run cmd in a subprocess
  B<q> or B<^D>     Quit                        B<R>           Attempt a restart
I<Data Examination:>     B<expr>     Execute perl code, also see: B<s>,B<n>,B<t> I<expr>
  B<x>|B<m> I<expr>       Evals expr in list context, dumps the result or lists methods.
  B<p> I<expr>         Print expression (uses script's current package).
  B<S> [[B<!>]I<pat>]     List subroutine names [not] matching pattern
  B<V> [I<Pk> [I<Vars>]]  List Variables in Package.  Vars can be ~pattern or !pattern.
  B<X> [I<Vars>]       Same as \"B<V> I<current_package> [I<Vars>]\".
  B<y> [I<n> [I<Vars>]]   List lexicals in higher scope <n>.  Vars same as B<V>.
For more help, type B<h> I<cmd_letter>, or run B<$doccmd perldebug> for all docs.
END_SUM

    # ')}}; # Fix balance of vi % matching

} ## end sub sethelp

sub print_help {
    local $_ = shift;

    # Restore proper alignment destroyed by eeevil I<> and B<>
    # ornaments: A pox on both their houses!
    #
    # A help command will have everything up to and including
    # the first tab sequence padded into a field 16 (or if indented 20)
    # wide.  If it's wider than that, an extra space will be added.
    s{
        ^                       # only matters at start of line
          ( \040{4} | \t )*     # some subcommands are indented
          ( < ?                 # so <CR> works
            [BI] < [^\t\n] + )  # find an eeevil ornament
          ( \t+ )               # original separation, discarded
          ( .* )                # this will now start (no earlier) than 
                                # column 16
    } {
        my($leadwhite, $command, $midwhite, $text) = ($1, $2, $3, $4);
        my $clean = $command;
        $clean =~ s/[BI]<([^>]*)>/$1/g;  

        # replace with this whole string:
        ($leadwhite ? " " x 4 : "")
      . $command
      . ((" " x (16 + ($leadwhite ? 4 : 0) - length($clean))) || " ")
      . $text;

    }mgex;

    s{                          # handle bold ornaments
       B < ( [^>] + | > ) >
    } {
          $Term::ReadLine::TermCap::rl_term_set[2] 
        . $1
        . $Term::ReadLine::TermCap::rl_term_set[3]
    }gex;

    s{                         # handle italic ornaments
       I < ( [^>] + | > ) >
    } {
          $Term::ReadLine::TermCap::rl_term_set[0] 
        . $1
        . $Term::ReadLine::TermCap::rl_term_set[1]
    }gex;

    local $\ = '';
    print $OUT $_;
} ## end sub print_help

sub fix_less {

    # We already know if this is set.
    return if defined $ENV{LESS} && $ENV{LESS} =~ /r/;

    # Pager is less for sure.
    my $is_less = $pager =~ /\bless\b/;
    if ($pager =~ /\bmore\b/) {
        # Nope, set to more. See what's out there.
        my @st_more = stat('/usr/bin/more');
        my @st_less = stat('/usr/bin/less');

        # is it really less, pretending to be more?
        $is_less = @st_more &&
          @st_less &&
          $st_more[0] == $st_less[0] &&
          $st_more[1] == $st_less[1];
    } ## end if ($pager =~ /\bmore\b/)

    # changes environment!
    # 'r' added so we don't do (slow) stats again.
    $ENV{LESS} .= 'r' if $is_less;
} ## end sub fix_less

sub diesignal {
    # No entry/exit messages.
    local $frame = 0;

    # No return value prints.
    local $doret = -2;

    # set the abort signal handling to the default (just terminate).
    $SIG{'ABRT'} = 'DEFAULT';

    # If we enter the signal handler recursively, kill myself with an
    # abort signal (so we just terminate).
    kill 'ABRT', $$ if $panic++;

    # If we can show detailed info, do so.
    if (defined &Carp::longmess) {
        # Don't recursively enter the warn handler, since we're carping.
        local $SIG{__WARN__} = '';

        # Skip two levels before reporting traceback: we're skipping 
        # mydie and confess. 
        local $Carp::CarpLevel = 2;    # mydie + confess

        # Tell us all about it.
        &warn(Carp::longmess("Signal @_"));
    }

    # No Carp. Tell us about the signal as best we can.
    else {
        local $\ = '';
        print $DB::OUT "Got signal @_\n";
    }

    # Drop dead.
    kill 'ABRT', $$;
} ## end sub diesignal

sub dbwarn {
    # No entry/exit trace. 
    local $frame = 0;

    # No return value printing.
    local $doret = -2;

    # Turn off warn and die handling to prevent recursive entries to this
    # routine.
    local $SIG{__WARN__} = '';
    local $SIG{__DIE__}  = '';

    # Load Carp if we can. If $^S is false (current thing being compiled isn't
    # done yet), we may not be able to do a require.
    eval { require Carp }
      if defined $^S;    # If error/warning during compilation,
                         # require may be broken.

    # Use the core warn() unless Carp loaded OK.
    CORE::warn(@_,
        "\nCannot print stack trace, load with -MCarp option to see stack"),
      return
      unless defined &Carp::longmess;

    # Save the current values of $single and $trace, and then turn them off.
    my ($mysingle, $mytrace) = ($single, $trace);
    $single = 0;
    $trace  = 0;

    # We can call Carp::longmess without its being "debugged" (which we 
    # don't want - we just want to use it!). Capture this for later.
    my $mess = Carp::longmess(@_);

    # Restore $single and $trace to their original values.
    ($single, $trace) = ($mysingle, $mytrace);

    # Use the debugger's own special way of printing warnings to print
    # the stack trace message.
    &warn($mess);
} ## end sub dbwarn

sub dbdie {
    local $frame = 0;
    local $doret = -2;
    local $SIG{__DIE__}  = '';
    local $SIG{__WARN__} = '';
    my $i      = 0;
    my $ineval = 0;
    my $sub;
    if ($dieLevel > 2) {
        local $SIG{__WARN__} = \&dbwarn;
        &warn(@_);    # Yell no matter what
        return;
    }
    if ($dieLevel < 2) {
        die @_ if $^S;    # in eval propagate
    }

    # The code used to check $^S to see if compiliation of the current thing
    # hadn't finished. We don't do it anymore, figuring eval is pretty stable.
    eval { require Carp }; 

    die (@_,
        "\nCannot print stack trace, load with -MCarp option to see stack")
      unless defined &Carp::longmess;

    # We do not want to debug this chunk (automatic disabling works
    # inside DB::DB, but not in Carp). Save $single and $trace, turn them off,
    # get the stack trace from Carp::longmess (if possible), restore $signal
    # and $trace, and then die with the stack trace.
    my ($mysingle, $mytrace) = ($single, $trace);
    $single = 0;
    $trace  = 0;
    my $mess = "@_";
    {

        package Carp;    # Do not include us in the list
        eval { $mess = Carp::longmess(@_); };
    }
    ($single, $trace) = ($mysingle, $mytrace);
    die $mess;
} ## end sub dbdie

sub warnLevel {
    if (@_) {
        $prevwarn = $SIG{__WARN__} unless $warnLevel;
        $warnLevel = shift;
        if ($warnLevel) {
            $SIG{__WARN__} = \&DB::dbwarn;
        }
        elsif ($prevwarn) {
            $SIG{__WARN__} = $prevwarn;
        }
    } ## end if (@_)
    $warnLevel;
} ## end sub warnLevel

sub dieLevel {
    local $\ = '';
    if (@_) {
        $prevdie = $SIG{__DIE__} unless $dieLevel;
        $dieLevel = shift;
        if ($dieLevel) {
            # Always set it to dbdie() for non-zero values.
            $SIG{__DIE__} = \&DB::dbdie;    # if $dieLevel < 2;

           # No longer exists, so don't try  to use it.
           #$SIG{__DIE__} = \&DB::diehard if $dieLevel >= 2;

            # If we've finished initialization, mention that stack dumps
            # are enabled, If dieLevel is 1, we won't stack dump if we die
            # in an eval().
            print $OUT "Stack dump during die enabled",
              ($dieLevel == 1 ? " outside of evals" : ""), ".\n"
              if $I_m_init;

            # XXX This is probably obsolete, given that diehard() is gone.
            print $OUT "Dump printed too.\n" if $dieLevel > 2;
        } ## end if ($dieLevel)

        # Put the old one back if there was one.
        elsif ($prevdie) {
            $SIG{__DIE__} = $prevdie;
            print $OUT "Default die handler restored.\n";
        }
    } ## end if (@_)
    $dieLevel;
} ## end sub dieLevel

sub signalLevel {
    if (@_) {
        $prevsegv = $SIG{SEGV} unless $signalLevel;
        $prevbus  = $SIG{BUS}  unless $signalLevel;
        $signalLevel = shift;
        if ($signalLevel) {
            $SIG{SEGV} = \&DB::diesignal;
            $SIG{BUS}  = \&DB::diesignal;
        }
        else {
            $SIG{SEGV} = $prevsegv;
            $SIG{BUS}  = $prevbus;
        }
    } ## end if (@_)
    $signalLevel;
} ## end sub signalLevel

sub CvGV_name {
    my $in   = shift;
    my $name = CvGV_name_or_bust($in);
    defined $name ? $name : $in;
}

sub CvGV_name_or_bust {
    my $in = shift;
    return if $skipCvGV;    # Backdoor to avoid problems if XS broken...
    return unless ref $in;
    $in = \&$in;            # Hard reference...
    eval { require Devel::Peek; 1 } or return;
    my $gv = Devel::Peek::CvGV($in) or return;
    *$gv{PACKAGE} . '::' . *$gv{NAME};
} ## end sub CvGV_name_or_bust

sub find_sub {
    my $subr = shift;
    $sub{$subr} or do {
        return unless defined &$subr;
        my $name = CvGV_name_or_bust($subr);
        my $data;
        $data = $sub{$name} if defined $name;
        return $data if defined $data;

        # Old stupid way...
        $subr = \&$subr;    # Hard reference
        my $s;
        for (keys %sub) {
            $s = $_, last if $subr eq \&$_;
        }
        $sub{$s} if $s;
      } ## end do
} ## end sub find_sub

sub methods {

    # Figure out the class - either this is the class or it's a reference
    # to something blessed into that class.
    my $class = shift;
    $class = ref $class if ref $class;

    local %seen;
    local %packs;

    # Show the methods that this class has.
    methods_via($class, '', 1);

    # Show the methods that UNIVERSAL has.
    methods_via('UNIVERSAL', 'UNIVERSAL', 0);
} ## end sub methods

sub methods_via {
    # If we've processed this class already, just quit.
    my $class = shift;
    return if $seen{$class}++;

    # This is a package that is contributing the methods we're about to print. 
    my $prefix = shift;
    my $prepend = $prefix ? "via $prefix: " : '';

    my $name;
    for $name (
        # Keep if this is a defined subroutine in this class.
        grep { defined &{ ${"${class}::"}{$_} } }
             # Extract from all the symbols in this class.
             sort keys %{"${class}::"}
      ) {
        # If we printed this already, skip it.
        next if $seen{$name}++;
 
        # Print the new method name.
        local $\ = '';
        local $, = '';
        print $DB::OUT "$prepend$name\n";
    } ## end for $name (grep { defined...

    # If the $crawl_upward argument is false, just quit here.
    return unless shift; 

    # $crawl_upward true: keep going up the tree.
    # Find all the classes this one is a subclass of.
    for $name (@{"${class}::ISA"}) {
        # Set up the new prefix.
        $prepend = $prefix ? $prefix . " -> $name" : $name;
        # Crawl up the tree and keep trying to crawl up. 
        methods_via($name, $prepend, 1);
    }
} ## end sub methods_via

sub setman {
    $doccmd =
      $^O !~ /^(?:MSWin32|VMS|os2|dos|amigaos|riscos|MacOS|NetWare)\z/s
      ? "man"               # O Happy Day!
      : "perldoc";          # Alas, poor unfortunates
} ## end sub setman

sub runman {
    my $page = shift;
    unless ($page) {
        &system("$doccmd $doccmd");
        return;
    }

    # this way user can override, like with $doccmd="man -Mwhatever"
    # or even just "man " to disable the path check.
    unless ($doccmd eq 'man') {
        &system("$doccmd $page");
        return;
    }

    $page = 'perl' if lc($page) eq 'help';

    require Config;
    my $man1dir = $Config::Config{'man1dir'};
    my $man3dir = $Config::Config{'man3dir'};
    for ($man1dir, $man3dir) { s#/[^/]*\z## if /\S/ }
    my $manpath = '';
    $manpath .= "$man1dir:" if $man1dir =~ /\S/;
    $manpath .= "$man3dir:" if $man3dir =~ /\S/ && $man1dir ne $man3dir;
    chop $manpath if $manpath;

    # harmless if missing, I figure
    my $oldpath = $ENV{MANPATH};
    $ENV{MANPATH} = $manpath if $manpath;
    my $nopathopt = $^O =~ /dunno what goes here/;
    if (
        CORE::system(
            $doccmd,

            # I just *know* there are men without -M
            (($manpath && !$nopathopt) ? ("-M", $manpath) : ()),
            split ' ', $page
        )
      )
    {
        unless ($page =~ /^perl\w/) {
            if (
                grep { $page eq $_ }
                qw{
                5004delta 5005delta amiga api apio book boot bot call compile
                cygwin data dbmfilter debug debguts delta diag doc dos dsc embed
                faq faq1 faq2 faq3 faq4 faq5 faq6 faq7 faq8 faq9 filter fork
                form func guts hack hist hpux intern ipc lexwarn locale lol mod
                modinstall modlib number obj op opentut os2 os390 pod port
                ref reftut run sec style sub syn thrtut tie toc todo toot tootc
                trap unicode var vms win32 xs xstut
                }
              )
            {
                $page =~ s/^/perl/;
                CORE::system($doccmd,
                    (($manpath && !$nopathopt) ? ("-M", $manpath) : ()),
                    $page);
            } ## end if (grep { $page eq $_...
        } ## end unless ($page =~ /^perl\w/)
    } ## end if (CORE::system($doccmd...
    if (defined $oldpath) {
        $ENV{MANPATH} = $manpath;
    }
    else {
        delete $ENV{MANPATH};
    }
} ## end sub runman

#use Carp;                          # This did break, left for debugging

# The following BEGIN is very handy if debugger goes havoc, debugging debugger?

BEGIN {    # This does not compile, alas. (XXX eh?)
    $IN      = \*STDIN;     # For bugs before DB::OUT has been opened
    $OUT     = \*STDERR;    # For errors before DB::OUT has been opened

    # Define characters used by command parsing. 
    $sh      = '!';         # Shell escape (does not work)
    $rc      = ',';         # Recall command (does not work)
    @hist    = ('?');       # Show history (does not work)

    # This defines the point at which you get the 'deep recursion' 
    # warning. It MUST be defined or the debugger will not load.
    $deep    = 100;

    # Number of lines around the current one that are shown in the 
    # 'w' command.
    $window  = 10;

    # How much before-the-current-line context the 'v' command should
    # use in calculating the start of the window it will display.
    $preview = 3;

    # We're not in any sub yet, but we need this to be a defined value.
    $sub     = '';

    # Set up the debugger's interrupt handler. It simply sets a flag 
    # ($signal) that DB::DB() will check before each command is executed.
    $SIG{INT} = \&DB::catch;

    # The following lines supposedly, if uncommented, allow the debugger to
    # debug itself. Perhaps we can try that someday. 
    # This may be enabled to debug debugger:
    #$warnLevel = 1 unless defined $warnLevel;
    #$dieLevel = 1 unless defined $dieLevel;
    #$signalLevel = 1 unless defined $signalLevel;

    # This is the flag that says "a debugger is running, please call
    # DB::DB and DB::sub". We will turn it on forcibly before we try to
    # execute anything in the user's context, because we always want to
    # get control back.
    $db_stop = 0;           # Compiler warning ...
    $db_stop = 1 << 30;     # ... because this is only used in an eval() later.

    # This variable records how many levels we're nested in debugging. Used
    # Used in the debugger prompt, and in determining whether it's all over or 
    # not.
    $level   = 0;           # Level of recursive debugging

    # "Triggers bug (?) in perl if we postpone this until runtime."
    # XXX No details on this yet, or whether we should fix the bug instead
    # of work around it. Stay tuned. 
    @postponed = @stack = (0);

    # Used to track the current stack depth using the auto-stacked-variable
    # trick.
    $stack_depth = 0;    # Localized repeatedly; simple way to track $#stack

    # Don't print return values on exiting a subroutine.
    $doret       = -2;

    # No extry/exit tracing.
    $frame       = 0;

} ## end BEGIN

BEGIN { $^W = $ini_warn; }    # Switch warnings back

sub db_complete {

    # Specific code for b c l V m f O, &blah, $blah, @blah, %blah
    # $text is the text to be completed.
    # $line is the incoming line typed by the user.
    # $start is the start of the text to be completed in the incoming line.
    my ($text, $line, $start) = @_;

    # Save the initial text.
    # The search pattern is current package, ::, extract the next qualifier
    # Prefix and pack are set to undef.
    my ($itext, $search, $prefix, $pack) =
      ($text, "^\Q${'package'}::\E([^:]+)\$");

    return sort grep /^\Q$text/, (keys %sub),
      qw(postpone load compile),    # subroutines
      (map { /$search/ ? ($1) : () } keys %sub)
      if (substr $line, 0, $start) =~ /^\|*[blc]\s+((postpone|compile)\s+)?$/;

    return sort grep /^\Q$text/, values %INC    # files
      if (substr $line, 0, $start) =~ /^\|*b\s+load\s+$/;

    return sort map { ($_, db_complete($_ . "::", "V ", 2)) }
      grep /^\Q$text/, map { /^(.*)::$/ ? ($1) : () } keys %::  # top-packages
      if (substr $line, 0, $start) =~ /^\|*[Vm]\s+$/ and $text =~ /^\w*$/;

    return sort map { ($_, db_complete($_ . "::", "V ", 2)) }
      grep !/^main::/, grep /^\Q$text/,
        map { /^(.*)::$/ ? ($prefix . "::$1") : () } keys %{ $prefix . '::' }
          if (substr $line, 0, $start) =~ /^\|*[Vm]\s+$/
              and $text =~ /^(.*[^:])::?(\w*)$/
              and $prefix = $1;

    if ($line =~ /^\|*f\s+(.*)/) {                              # Loaded files
        # We might possibly want to switch to an eval (which has a "filename"
        # like '(eval 9)'), so we may need to clean up the completion text 
        # before proceeding. 
        $prefix = length($1) - length($text);
        $text   = $1;

        return sort
          map { substr $_, 2 + $prefix } grep /^_<\Q$text/, (keys %main::),
          $0;
    } ## end if ($line =~ /^\|*f\s+(.*)/)

    if ((substr $text, 0, 1) eq '&') {    # subroutines
        $text = substr $text, 1;
        $prefix = "&";
        return sort map "$prefix$_", grep /^\Q$text/, (keys %sub),
          (
            map { /$search/ ? ($1) : () }
              keys %sub
              );
    } ## end if ((substr $text, 0, ...

    if ($text =~ /^[\$@%](.*)::(.*)/) {    # symbols in a package

        $pack = ($1 eq 'main' ? '' : $1) . '::';

        $prefix = (substr $text, 0, 1) . $1 . '::';
        $text = $2;

        my @out = map "$prefix$_", grep /^\Q$text/, grep /^_?[a-zA-Z]/,
          keys %$pack;

        if (@out == 1 and $out[0] =~ /::$/ and $out[0] ne $itext) {
            return db_complete($out[0], $line, $start);
        }

        # Return the list of possibles.
        return sort @out;

    } ## end if ($text =~ /^[\$@%](.*)::(.*)/)


    if ($text =~ /^[\$@%]/) {    # symbols (in $package + packages in main)

        $pack = ($package eq 'main' ? '' : $package) . '::';

        $prefix = substr $text, 0, 1;
        $text = substr $text, 1;

        my @out = map "$prefix$_", grep /^\Q$text/,
          (grep /^_?[a-zA-Z]/, keys %$pack),
          ($pack eq '::' ? () : (grep /::$/, keys %::));

        if (@out == 1 and $out[0] =~ /::$/ and $out[0] ne $itext) {
            return db_complete($out[0], $line, $start);
        }

        # Return the list of possibles.
        return sort @out;
    } ## end if ($text =~ /^[\$@%]/)

    my $cmd = ($CommandSet eq '580') ? 'o' : 'O';
    if ((substr $line, 0, $start) =~ /^\|*$cmd\b.*\s$/) { # Options after space
        # We look for the text to be matched in the list of possible options, 
        # and fetch the current value. 
        my @out = grep /^\Q$text/, @options;
        my $val = option_val($out[0], undef);

        # Set up a 'query option's value' command.
        my $out = '? ';
        if (not defined $val or $val =~ /[\n\r]/) {
           # There's really nothing else we can do.
        }

        # We have a value. Create a proper option-setting command.
        elsif ($val =~ /\s/) {
            # XXX This may be an extraneous variable.
            my $found;

            # We'll want to quote the string (because of the embedded
            # whtespace), but we want to make sure we don't end up with
            # mismatched quote characters. We try several possibilities.
            foreach $l (split //, qq/\"\'\#\|/) {
                # If we didn't find this quote character in the value,
                # quote it using this quote character.
                $out = "$l$val$l ", last if (index $val, $l) == -1;
            }
        } ## end elsif ($val =~ /\s/)

        # Don't need any quotes.
        else {
            $out = "=$val ";
        }

        # If there were multiple possible values, return '? ', which
        # makes the command into a query command. If there was just one,
        # have readline append that.
        $rl_attribs->{completer_terminator_character} =
          (@out == 1 ? $out : '? ');

        # Return list of possibilities.
        return sort @out;
    } ## end if ((substr $line, 0, ...

    return $term->filename_list($text);    # filenames

} ## end sub db_complete

sub end_report {
    local $\ = '';
    print $OUT "Use `q' to quit or `R' to restart.  `h q' for details.\n";
}

sub clean_ENV {
    if (defined($ini_pids)) {
        $ENV{PERLDB_PIDS} = $ini_pids;
    }
    else {
        delete($ENV{PERLDB_PIDS});
    }
} ## end sub clean_ENV

END {
    $finished = 1 if $inhibit_exit;    # So that some commands may be disabled.
    $fall_off_end = 1 unless $inhibit_exit;

    # Do not stop in at_exit() and destructors on exit:
    $DB::single = !$fall_off_end && !$runnonstop;
    DB::fake::at_exit() unless $fall_off_end or $runnonstop;
} ## end END

sub cmd_pre580_null {

    # do nothing...
}

sub cmd_pre580_a {
    my $xcmd = shift;
    my $cmd  = shift;

    # Argument supplied. Add the action.
    if ($cmd =~ /^(\d*)\s*(.*)/) {

        # If the line isn't there, use the current line.
        $i = $1 || $line;
        $j = $2;

        # If there is an action ...
        if (length $j) {

            # ... but the line isn't breakable, skip it.
            if ($dbline[$i] == 0) {
                print $OUT "Line $i may not have an action.\n";
            }
            else {
                # ... and the line is breakable:
                # Mark that there's an action in this file.
                $had_breakpoints{$filename} |= 2;

                # Delete any current action.
                $dbline{$i} =~ s/\0[^\0]*//;

                # Add the new action, continuing the line as needed.
                $dbline{$i} .= "\0" . action($j);
            }
        } ## end if (length $j)

        # No action supplied.
        else {
            # Delete the action.
            $dbline{$i} =~ s/\0[^\0]*//;
            # Mark as having no break or action if nothing's left.
            delete $dbline{$i} if $dbline{$i} eq '';
        }
    } ## end if ($cmd =~ /^(\d*)\s*(.*)/)
} ## end sub cmd_pre580_a

sub cmd_pre580_b {
    my $xcmd    = shift;
    my $cmd     = shift;
    my $dbline = shift;

    # Break on load.
    if ($cmd =~ /^load\b\s*(.*)/) {
        my $file = $1;
        $file =~ s/\s+$//;
        &cmd_b_load($file);
    }

    # b compile|postpone <some sub> [<condition>]
    # The interpreter actually traps this one for us; we just put the 
    # necessary condition in the %postponed hash.
    elsif ($cmd =~ /^(postpone|compile)\b\s*([':A-Za-z_][':\w]*)\s*(.*)/) {
        # Capture the condition if there is one. Make it true if none.
        my $cond = length $3 ? $3 : '1';

        # Save the sub name and set $break to 1 if $1 was 'postpone', 0
        # if it was 'compile'.
        my ($subname, $break) = ($2, $1 eq 'postpone');

        # De-Perl4-ify the name - ' separators to ::.
        $subname =~ s/\'/::/g;

        # Qualify it into the current package unless it's already qualified.
        $subname = "${'package'}::" . $subname
          unless $subname =~ /::/;

        # Add main if it starts with ::.
        $subname = "main" . $subname if substr($subname, 0, 2) eq "::";

        # Save the break type for this sub.
        $postponed{$subname} = $break ? "break +0 if $cond" : "compile";
    } ## end elsif ($cmd =~ ...

    # b <sub name> [<condition>]
    elsif ($cmd =~ /^([':A-Za-z_][':\w]*(?:\[.*\])?)\s*(.*)/) {
        my $subname = $1;
        my $cond = length $2 ? $2 : '1';
        &cmd_b_sub($subname, $cond);
    }

    # b <line> [<condition>].
    elsif ($cmd =~ /^(\d*)\s*(.*)/) {
        my $i = $1 || $dbline;
        my $cond = length $2 ? $2 : '1';
        &cmd_b_line($i, $cond);
    }
} ## end sub cmd_pre580_b

sub cmd_pre580_D {
    my $xcmd = shift;
    my $cmd  = shift;
    if ($cmd =~ /^\s*$/) {
        print $OUT "Deleting all breakpoints...\n";

        # %had_breakpoints lists every file that had at least one
        # breakpoint in it.
        my $file;
        for $file (keys %had_breakpoints) {
            # Switch to the desired file temporarily.
            local *dbline = $main::{ '_<' . $file };

            my $max = $#dbline;
            my $was;

            # For all lines in this file ...
            for ($i = 1 ; $i <= $max ; $i++) {
                # If there's a breakpoint or action on this line ...
                if (defined $dbline{$i}) {
                    # ... remove the breakpoint.
                    $dbline{$i} =~ s/^[^\0]+//;
                    if ($dbline{$i} =~ s/^\0?$//) {
                        # Remove the entry altogether if no action is there.
                        delete $dbline{$i};
                    }
                } ## end if (defined $dbline{$i...
            } ## end for ($i = 1 ; $i <= $max...

            # If, after we turn off the "there were breakpoints in this file"
            # bit, the entry in %had_breakpoints for this file is zero, 
            # we should remove this file from the hash.
            if (not $had_breakpoints{$file} &= ~1) {
                delete $had_breakpoints{$file};
            }
        } ## end for $file (keys %had_breakpoints)

        # Kill off all the other breakpoints that are waiting for files that
        # haven't been loaded yet.
        undef %postponed;
        undef %postponed_file;
        undef %break_on_load;
    } ## end if ($cmd =~ /^\s*$/)
} ## end sub cmd_pre580_D

sub cmd_pre580_h {
    my $xcmd = shift;
    my $cmd  = shift;

    # Print the *right* help, long format.
    if ($cmd =~ /^\s*$/) {
        print_help($pre580_help);
    }

    # 'h h' - explicitly-requested summary. 
    elsif ($cmd =~ /^h\s*/) {
        print_help($pre580_summary);
    }

    # Find and print a command's help.
    elsif ($cmd =~ /^h\s+(\S.*)$/) {
        my $asked  = $1;                   # for proper errmsg
        my $qasked = quotemeta($asked);    # for searching
                                           # XXX: finds CR but not <CR>
        if ($pre580_help =~ /^
                              <?           # Optional '<'
                              (?:[IB]<)    # Optional markup
                              $qasked      # The command name
                            /mx) {

            while (
                $pre580_help =~ /^
                                  (             # The command help:
                                   <?           # Optional '<'
                                   (?:[IB]<)    # Optional markup
                                   $qasked      # The command name
                                   ([\s\S]*?)   # Lines starting with tabs
                                   \n           # Final newline
                                  )
                                  (?!\s)/mgx)   # Line not starting with space
                                                # (Next command's help)
            {
                print_help($1);
            }
        } ## end if ($pre580_help =~ /^<?(?:[IB]<)$qasked/m)

        # Help not found.
        else {
            print_help("B<$asked> is not a debugger command.\n");
        }
    } ## end elsif ($cmd =~ /^h\s+(\S.*)$/)
} ## end sub cmd_pre580_h

sub cmd_pre580_W {
    my $xcmd = shift;
    my $cmd  = shift;

    # Delete all watch expressions.
    if ($cmd =~ /^$/) {
        # No watching is going on.
        $trace &= ~2;
        # Kill all the watch expressions and values.
        @to_watch = @old_watch = ();
    }

    # Add a watch expression.
    elsif ($cmd =~ /^(.*)/s) {
        # add it to the list to be watched.
        push @to_watch, $1;

        # Get the current value of the expression. 
        # Doesn't handle expressions returning list values!
        $evalarg = $1;
        my ($val) = &eval;
        $val = (defined $val) ? "'$val'" : 'undef';

        # Save it.
        push @old_watch, $val;

        # We're watching stuff.
        $trace |= 2;

    } ## end elsif ($cmd =~ /^(.*)/s)
} ## end sub cmd_pre580_W

sub cmd_pre590_prepost {
    my $cmd    = shift;
    my $line   = shift || '*';
    my $dbline = shift;

    return &cmd_prepost( $cmd, $line, $dbline );
} ## end sub cmd_pre590_prepost

sub cmd_prepost { my $cmd = shift;

    # No action supplied defaults to 'list'.
    my $line = shift || '?';

    # Figure out what to put in the prompt.
    my $which = '';

    # Make sure we have some array or another to address later.
    # This means that if ssome reason the tests fail, we won't be
    # trying to stash actions or delete them from the wrong place.
    my $aref  = [];

   # < - Perl code to run before prompt.
    if ( $cmd =~ /^\</o ) {
        $which = 'pre-perl';
        $aref  = $pre;
    }

    # > - Perl code to run after prompt.
    elsif ( $cmd =~ /^\>/o ) {
        $which = 'post-perl';
        $aref  = $post;
    }

    # { - first check for properly-balanced braces.
    elsif ( $cmd =~ /^\{/o ) {
        if ( $cmd =~ /^\{.*\}$/o && unbalanced( substr( $cmd, 1 ) ) ) {
            print $OUT
"$cmd is now a debugger command\nuse `;$cmd' if you mean Perl code\n";
        }

        # Properly balanced. Pre-prompt debugger actions.
        else {
            $which = 'pre-debugger';
            $aref  = $pretype;
        }
    } ## end elsif ( $cmd =~ /^\{/o )

    # Did we find something that makes sense?
    unless ($which) {
        print $OUT "Confused by command: $cmd\n";
    }

    # Yes. 
    else {
        # List actions.
        if ( $line =~ /^\s*\?\s*$/o ) {
            unless (@$aref) {
                # Nothing there. Complain.
                print $OUT "No $which actions.\n";
            }
            else {
                # List the actions in the selected list.
                print $OUT "$which commands:\n";
                foreach my $action (@$aref) {
                    print $OUT "\t$cmd -- $action\n";
                }
            } ## end else
        } ## end if ( $line =~ /^\s*\?\s*$/o)

        # Might be a delete.
        else {
            if ( length($cmd) == 1 ) {
                if ( $line =~ /^\s*\*\s*$/o ) {
                    # It's a delete. Get rid of the old actions in the 
                    # selected list..
                    @$aref = ();
                    print $OUT "All $cmd actions cleared.\n";
                }
                else {
                    # Replace all the actions. (This is a <, >, or {).
                    @$aref = action($line);
                }
            } ## end if ( length($cmd) == 1)
            elsif ( length($cmd) == 2 ) { 
                # Add the action to the line. (This is a <<, >>, or {{).
                push @$aref, action($line);
            }
            else {
                # <<<, >>>>, {{{{{{ ... something not a command.
                print $OUT
                  "Confused by strange length of $which command($cmd)...\n";
            }
        } ## end else [ if ( $line =~ /^\s*\?\s*$/o)
    } ## end else
} ## end sub cmd_prepost


package DB::fake;

sub at_exit {
    "Debugged program terminated.  Use `q' to quit or `R' to restart.";
}

package DB;    # Do not trace this 1; below!

1;

