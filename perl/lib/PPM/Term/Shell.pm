package PPM::Term::Shell;

use strict;
use Data::Dumper;
use Term::ReadLine;
use vars qw($VERSION);

$VERSION = '0.02';

#=============================================================================
# Term::Shell API methods
#=============================================================================
sub new {
    my $cls = shift;
    my %args = (
	term => ['shell'],
	pager => 'internal',
	@_,
    );
    my $o = bless {
	term	=> eval {
	    Term::ReadLine->new(@{$args{term}});
	} || undef,
    }, ref($cls) || $cls;

    # Set up the API hash:
    $o->{command} = {};
    $o->{API} = {
	args		=> \%args,
	case_ignore	=> ($^O eq 'MSWin32' ? 1 : 0),
	check_idle	=> 0,	# changing this isn't supported
	class		=> $cls,
	command		=> $o->{command},
	cmd		=> $o->{command}, # shorthand
	match_uniq	=> 1,
	pager		=> $args{pager},
	readline	=> eval { $o->term->ReadLine } || 'none',
	script		=> (caller(0))[1],
	version		=> $VERSION,
    };

    # Note: the rl_completion_function doesn't pass an object as the first
    # argument, so we have to use a closure. This has the unfortunate effect
    # of preventing two instances of Term::ReadLine from coexisting.
    my $completion_handler = sub {
	$o->rl_complete(@_);
    };
    if ($o->{API}{readline} eq 'Term::ReadLine::Gnu') {
	my $attribs = $o->term->Attribs;
	$attribs->{completion_function} = $completion_handler;
    }
    elsif ($o->{API}{readline} eq 'Term::ReadLine::Perl') {
	$readline::rl_completion_function = 
	$readline::rl_completion_function = $completion_handler;
    }
    $o->find_handlers;
    $o->init;
    $o;
}

sub DESTROY {
    my $o = shift;
    $o->fini;
}

sub cmd {
    my $o = shift;
    $o->{line} = shift;
    if ($o->line =~ /\S/) {
	my ($cmd, @args) = $o->line_parsed;
	$o->run($cmd, @args);
	unless ($o->{command}{run}{found}) {
	    my @c = sort $o->possible_actions($cmd, 'run', 1);
	    if (@c) {
		print $o->msg_ambiguous_cmd($cmd, @c);
	    }
	    else {
		print $o->msg_unknown_cmd($cmd);
	    }
	}
    }
    else {
	$o->run('');
    }
}

sub stoploop { $_[0]->{stop}++ }
sub cmdloop {
    my $o = shift;
    $o->{stop} = 0;
    $o->preloop;
    while (defined (my $line = $o->readline($o->prompt_str))) {
	$o->cmd($line);
	last if $o->{stop};
    }
    $o->postloop;
}
*mainloop = \&cmdloop;

sub readline {
    my $o = shift;
    my $prompt = shift;
    return $o->term->readline($prompt)
	if $o->{API}{check_idle} == 0
	    or not defined $o->term->IN;

    # They've asked for idle-time running of some user command.
    local $Term::ReadLine::toloop = 1;
    local *Tk::fileevent = sub {
	my $cls = shift;
	my ($file, $boring, $callback) = @_;
	$o->{fh} = $file;	# save the filehandle!
	$o->{cb} = $callback;	# save the callback!
    };
    local *Tk::DoOneEvent = sub {
	# We'll totally cheat and do a select() here -- the timeout will be
	# $o->{API}{check_idle}; if the handle is ready, we'll call &$cb;
	# otherwise we'll call $o->idle(), which can do some processing.
	my $timeout = $o->{API}{check_idle};
	use IO::Select;
	if (IO::Select->new($o->{fh})->can_read($timeout)) {
	    # Input is ready: stop the event loop.
	    $o->{cb}->();
	}
	else {
	    $o->idle;
	}
    };
    $o->term->readline($prompt);
}

sub term { $_[0]->{term} }

# These are likely candidates for overriding in subclasses
sub init { }		# called last in the ctor
sub fini { }		# called first in the dtor
sub preloop { }
sub postloop { }
sub precmd { }
sub postcmd { }
sub prompt_str { 'shell> ' }
sub idle { }
sub cmd_prefix { '' }
sub cmd_suffix { '' }

#=============================================================================
# The pager
#=============================================================================
sub page {
    my $o         = shift;
    my $text      = shift;
    my $terminfo  = $o->termsize;
    my $maxlines  = shift || $terminfo->{rows};
    my $pager     = $o->{API}{pager};

    # First, wrap the text to the width of the screen (so our line-count is
    # correct):
    eval {
	require Text::Wrap;
	Text::Wrap->import('wrap');
	local $Text::Wrap::columns = $terminfo->{cols};
	$text = wrap('', '', $text);
    };

    # Count the number of lines in the text:
    my $lines = ($text =~ tr/\n//);

    # If there are fewer lines than the page-lines, just print it.
    if ($lines < $maxlines or $maxlines == 0 or $pager eq 'none') {
	print $text;
    }
    # If there are more, page it, either using the external pager...
    elsif ($pager and $pager ne 'internal') {
	require File::Temp;
	my ($handle, $name) = File::Temp::tempfile();
	select((select($handle), $| = 1)[0]);
	print $handle $text;
	close $handle;
	system($pager, $name) == 0
	    or print <<END;
Warning: can't run external pager '$pager': $!.
END
	unlink $name;
    }
    # ... or the internal one
    else {
	my $togo = $lines;
	my $line = 0;
	my @lines = split '^', $text;
	while ($togo > 0) {
	    my @text = @lines[$line .. $#lines];
	    my $ret = $o->page_internal(\@text, $maxlines, $togo, $line);
	    last if $ret == -1;
	    $line += $ret;
	    $togo -= $ret;
	}
	return $line;
    }
    return $lines
}

sub page_internal {
    my $o           = shift;
    my $lines       = shift;
    my $maxlines    = shift;
    my $togo        = shift;
    my $start       = shift;

    my $line = 1;
    local $| = 1;
    while ($_ = shift @$lines) {
	print;
	last if $line >= ($maxlines - 1); # leave room for the prompt
	$line++;
    }
    my $lines_left = $togo - $line;
    my $current_line = $start + $line;
    my $total_lines = $togo + $start;

    my $instructions;
    if ($o->have_readkey) {
	$instructions = "any key for more, or q to quit";
    }
    else {
	$instructions = "enter for more, or q to quit";
    }
    
    if ($lines_left > 0) {
	local $| = 1;
	my $l = "---line $current_line/$total_lines ($instructions)---";
	my $b = ' ' x length($l);
	print $l;
	my $ans = $o->readkey;
	print "\r$b\r" if $o->have_readkey();
	print "\n" if $ans =~ /q/i or not $o->have_readkey();
	$line = -1 if $ans =~ /q/i;
    }
    $line;
}

#=============================================================================
# Run actions
#=============================================================================
sub run {
    my $o = shift;
    my $action = shift;
    my @args = @_;
    $o->do_action($action, \@args, 'run')
}

sub complete {
    my $o = shift;
    my $action = shift;
    my @args = @_;
    my @compls = $o->do_action($action, \@args, 'comp');
    return () unless $o->{command}{comp}{found};
    return @compls;
}

sub help {
    my $o = shift;
    my $topic = shift;
    my @subtopics = @_;
    $o->do_action($topic, \@subtopics, 'help')
}

sub summary {
    my $o = shift;
    my $topic = shift;
    $o->do_action($topic, [], 'smry')
}

#=============================================================================
# Manually add & remove handlers
#=============================================================================
sub add_handlers {
    my $o = shift;
    # The sort in the following line guarantees that "alias_xxx" will be sorted
    # first.  Otherwise the remaining entries won't be applied to all aliases.
    for my $hnd (sort @_) {
	next unless $hnd =~ /^(run|help|smry|comp|catch|alias)_/o;
	my $t = $1;
	my $a = substr($hnd, length($t) + 1);
	# Add on the prefix and suffix if the command is defined
	if (length $a) {
	    substr($a, 0, 0) = $o->cmd_prefix;
	    $a .= $o->cmd_suffix;
	}
	$o->{handlers}{$a}{$t} = $hnd;
	if ($o->has_aliases($a)) {
	    my @a = $o->get_aliases($a);
	    for my $alias (@a) {
		substr($alias, 0, 0) = $o->cmd_prefix;
		$alias .= $o->cmd_suffix;
		$o->{handlers}{$alias}{$t} = $hnd;
	    }
	}
    }
}

sub add_commands {
    my $o = shift;
    while (@_) {
	my ($cmd, $hnd) = (shift, shift);
	$o->{handlers}{$cmd} = $hnd;
    }
}

sub remove_handlers {
    my $o = shift;
    for my $hnd (@_) {
	next unless $hnd =~ /^(run|help|smry|comp|catch|alias)_/o;
	my $t = $1;
	my $a = substr($hnd, length($t) + 1);
	# Add on the prefix and suffix if the command is defined
	if (length $a) {
	    substr($a, 0, 0) = $o->cmd_prefix;
	    $a .= $o->cmd_suffix;
	}
	delete $o->{handlers}{$a}{$t};
    }
}

sub remove_commands {
    my $o = shift;
    for my $name (@_) {
	delete $o->{handlers}{$name};
    }
}

*add_handler = \&add_handlers;
*add_command = \&add_commands;
*remove_handler = \&remove_handlers;
*remove_command = \&remove_commands;

#=============================================================================
# Utility methods
#=============================================================================
sub termsize {
    my $o = shift;
    my ($rows, $cols) = (24, 80);
    return { rows => $rows, cols => $cols } unless -t STDOUT;
    my $OUT = ref($o) ? $o->term->OUT : \*STDOUT;
    my $TERM = ref($o) ? $o->term : undef;
    if ($TERM and $o->{API}{readline} eq 'Term::ReadLine::Gnu') {
	($rows, $cols) = $TERM->get_screen_size;
    }
    elsif (ref($o) and $^O eq 'MSWin32' and eval { require Win32::Console }) {
	Win32::Console->import;
	# Win32::Console's DESTROY does a CloseHandle(), so save the object:
	$o->{win32_stdout} ||= Win32::Console->new(STD_OUTPUT_HANDLE());
	my @info = $o->{win32_stdout}->Info;
	$cols = $info[7] - $info[5] + 1; # right - left + 1
	$rows = $info[8] - $info[6] + 1; # bottom - top + 1
    }
    elsif (eval { require Term::Size }) {
	($cols, $rows) = Term::Size::chars($OUT);
    }
    elsif (eval { require Term::ReadKey }) {
	($cols, $rows) = Term::ReadKey::GetTerminalSize($OUT);
    }
    elsif (eval { require Term::Screen }) {
	my $screen = Term::Screen->new;
	($rows, $cols) = @$screen{qw(ROWS COLS)};
    }
    elsif ($ENV{LINES} or $ENV{ROWS} or $ENV{COLUMNS}) {
	$rows = $ENV{LINES} || $ENV{ROWS} || $rows;
	$cols = $ENV{COLUMNS} || $cols;
    }
    else {
	local $^W;
	local *STTY;
	open (STTY, "stty size |") and do {
	    my $l = <STTY>;
	    ($rows, $cols) = split /\s+/, $l;
	    close STTY;
	};
    }
    { rows => $rows, cols => $cols};
}

sub readkey {
    my $o = shift;
    $o->{readkey}->();
}

sub have_readkey {
    my $o = shift;
    return 1 if $o->{have_readkey};
    my $IN = $o->term->IN;
    my $t = -t $IN;
    if ($t and $^O ne 'MSWin32' and eval { require Term::InKey }) {
	$o->{readkey} = \&Term::InKey::ReadKey;
    }
    elsif ($t and $^O eq 'MSWin32' and eval { require Win32::Console }) {
	$o->{readkey} = sub {
	    my $c;
	    # from Term::InKey:
	    eval {
		Win32::Console->import;
		$o->{win32_stdin} ||= Win32::Console->new(STD_INPUT_HANDLE());
		my $mode = my $orig = $o->{win32_stdin}->Mode or die $^E;
		$mode &= ~(ENABLE_LINE_INPUT() | ENABLE_ECHO_INPUT());
		$o->{win32_stdin}->Mode($mode) or die $^E;

		$o->{win32_stdin}->Flush or die $^E;
		$c = $o->{win32_stdin}->InputChar(1);
		die $^E unless defined $c;
		$o->{win32_stdin}->Mode($orig) or die $^E;
	    };
	    die "Not implemented on $^O: $@" if $@;
	    $c;
	};
    }
    elsif ($t and eval { require Term::ReadKey }) {
	$o->{readkey} = sub {
	    Term::ReadKey::ReadMode(4, $IN);
	    my $c = getc($IN);
	    Term::ReadKey::ReadMode(0, $IN);
	    $c;
	};
    }
    else {
	$o->{readkey} = sub { scalar <$IN> };
	return $o->{have_readkey} = 0;
    }
    return $o->{have_readkey} = 1;
}
*has_readkey = \&have_readkey;

sub prompt {
    my $o = shift;
    my ($prompt, $default, $completions, $casei) = @_;

    # A closure to read the line.
    my $line;
    my $readline = sub {
	my ($sh, $gh) = @{$o->term->Features}{qw(setHistory getHistory)};
	my @history = $o->term->GetHistory if $gh;
	$o->term->SetHistory() if $sh;
	$line = $o->readline($prompt);
	$line = $default
	    if ((not defined $line or $line =~ /^\s*$/) and defined $default);
	# Restore the history
	$o->term->SetHistory(@history) if $sh;
	$line;
    };
    # A closure to complete the line.
    my $complete = sub {
	my ($word, $line, $start) = @_;
	return $o->completions($word, $completions, $casei);
    };
    if ($o->term->ReadLine eq 'Term::ReadLine::Gnu') {
	my $attribs = $o->term->Attribs;
	local $attribs->{completion_function} = $complete;
	&$readline;
    }
    elsif ($o->term->ReadLine eq 'Term::ReadLine::Perl') {
	local $readline::rl_completion_function = $complete;
	&$readline;
    }
    else {
	&$readline;
    }
    $line;
}

sub format_pairs {
    my $o    = shift;
    my @keys = @{shift(@_)};
    my @vals = @{shift(@_)};
    my $sep  = shift || ": ";
    my $left = shift || 0;
    my $ind  = shift || "";
    my $len  = shift || 0;
    my $wrap = shift || 0;
    if ($wrap) {
	eval {
	    require Text::Autoformat;
	    Text::Autoformat->import(qw(autoformat));
	};
	if ($@) {
	    warn (
		"Term::Shell::format_pairs(): Text::Autoformat is required " .
		"for wrapping. Wrapping disabled"
	    ) if $^W;
	    $wrap = 0;
	}
    }
    my $cols = shift || $o->termsize->{cols};
    $len < length($_) and $len = length($_) for @keys;
    my @text;
    for my $i (0 .. $#keys) {
	next unless defined $vals[$i];
	my $sz   = ($len - length($keys[$i]));
	my $lpad = $left ? "" : " " x $sz;
	my $rpad = $left ? " " x $sz : "";
	my $l = "$ind$lpad$keys[$i]$rpad$sep";
	my $wrap = $wrap & ($vals[$i] =~ /\s/ and $vals[$i] !~ /^\d/);
	my $form = (
	    $wrap
	    ? autoformat(
		"$vals[$i]", # force stringification
		{ left => length($l)+1, right => $cols, all => 1 },
	    )
	    : "$l$vals[$i]\n"
	);
	substr($form, 0, length($l), $l);
	push @text, $form;
    }
    my $text = join '', @text;
    return wantarray ? ($text, $len) : $text;
}

sub print_pairs {
    my $o = shift;
    my ($text, $len) = $o->format_pairs(@_);
    $o->page($text);
    return $len;
}

# Handle backslash translation; doesn't do anything complicated yet.
sub process_esc {
    my $o = shift;
    my $c = shift;
    my $q = shift;
    my $n;
    return '\\' if $c eq '\\';
    return $q if $c eq $q;
    return "\\$c";
}

# Parse a quoted string
sub parse_quoted {
    my $o = shift;
    my $raw = shift;
    my $quote = shift;
    my $i=1;
    my $string = '';
    my $c;
    while($i <= length($raw) and ($c=substr($raw, $i, 1)) ne $quote) {
	if ($c eq '\\') {
	    $string .= $o->process_esc(substr($raw, $i+1, 1), $quote);
	    $i++;
	}
	else {
	    $string .= substr($raw, $i, 1);
	}
	$i++;
    }
    return ($string, $i);
};

sub line {
    my $o = shift;
    $o->{line}
}
sub line_args {
    my $o = shift;
    my $line = shift || $o->line;
    $o->line_parsed($line);
    $o->{line_args} || '';
}
sub line_parsed {
    my $o = shift;
    my $args = shift || $o->line || return ();
    my @args;

    # Parse an array of arguments. Whitespace separates, unless quoted.
    my $arg = undef;
    $o->{line_args} = undef;
    for(my $i=0; $i<length($args); $i++) {
	my $c = substr($args, $i, 1);
	if ($c =~ /\S/ and @args == 1) {
	    $o->{line_args} ||= substr($args, $i);
	}
	if ($c =~ /['"]/) {
	    my ($str, $n) = $o->parse_quoted(substr($args,$i),$c);
	    $i += $n;
	    $arg = (defined($arg) ? $arg : '') . $str;
	}
# We do not parse outside of strings
#	elsif ($c eq '\\') {
#	    $arg = (defined($arg) ? $arg : '') 
#	      . $o->process_esc(substr($args,$i+1,1));
#	    $i++;
#	}
	elsif ($c =~ /\s/) {
	    push @args, $arg if defined $arg;
	    $arg = undef
	} 
	else {
	    $arg .= substr($args,$i,1);
	}
    }
    push @args, $arg if defined($arg);
    return @args;
}

sub handler {
    my $o = shift;
    my ($command, $type, $args, $preserve_args) = @_;

    # First try finding the standard handler, then fallback to the
    # catch_$type method. The columns represent "action", "type", and "push",
    # which control whether the name of the command should be pushed onto the
    # args.
    my @tries = (
	[$command, $type, 0],
	[$o->cmd_prefix . $type . $o->cmd_suffix, 'catch', 1],
    );

    # The user can control whether or not to search for "unique" matches,
    # which means calling $o->possible_actions(). We always look for exact
    # matches.
    my @matches = qw(exact_action);
    push @matches, qw(possible_actions) if $o->{API}{match_uniq};

    for my $try (@tries) {
	my ($cmd, $type, $add_cmd_name) = @$try;
	for my $match (@matches) {
	    my @handlers = $o->$match($cmd, $type);
	    next unless @handlers == 1;
	    unshift @$args, $command
		if $add_cmd_name and not $preserve_args;
	    return $o->unalias($handlers[0], $type)
	}
    }
    return undef;
}

sub completions {
    my $o = shift;
    my $action = shift;
    my $compls = shift || [];
    my $casei  = shift;
    $casei = $o->{API}{case_ignore} unless defined $casei;
    $casei = $casei ? '(?i)' : '';
    return grep { $_ =~ /$casei^\Q$action\E/ } @$compls;
}

#=============================================================================
# Term::Shell error messages
#=============================================================================
sub msg_ambiguous_cmd {
    my ($o, $cmd, @c) = @_;
    local $" = "\n\t";
    <<END;
Ambiguous command '$cmd': possible commands:
	@c
END
}

sub msg_unknown_cmd {
    my ($o, $cmd) = @_;
    <<END;
Unknown command '$cmd'; type 'help' for a list of commands.
END
}

#=============================================================================
# Term::Shell private methods
#=============================================================================
sub do_action {
    my $o = shift;
    my $cmd = shift;
    my $args = shift || [];
    my $type = shift || 'run';
    my $handler = $o->handler($cmd, $type, $args);
    $o->{command}{$type} = {
	name	=> $cmd,
	found	=> defined $handler ? 1 : 0,
	handler	=> $handler,
    };
    if (defined $handler) {
	# We've found a handler. Set up a value which will call the postcmd()
	# action as the subroutine leaves. Then call the precmd(), then return
	# the result of running the handler.
	$o->precmd(\$handler, \$cmd, $args);
	my $postcmd = Term::Shell::OnScopeLeave->new(sub {
	    $o->postcmd(\$handler, \$cmd, $args);
	});
	return $o->$handler(@$args);
    }
}

sub uniq {
    my $o = shift;
    my %seen;
    $seen{$_}++ for @_;
    my @ret;
    for (@_) { push @ret, $_ if $seen{$_}-- == 1 }
    @ret;
}

sub possible_actions {
    my $o = shift;
    my $action = shift;
    my $type = shift;
    my $strip = shift || 0;
    my $casei = $o->{API}{case_ignore} ? '(?i)' : '';
    my @keys =	grep { $_ =~ /$casei^\Q$action\E/ } 
		grep { exists $o->{handlers}{$_}{$type} }
		keys %{$o->{handlers}};
    return @keys if $strip;
    return map { "${type}_$_" } @keys;
}

sub exact_action {
    my $o = shift;
    my $action = shift;
    my $type = shift;
    my $strip = shift || 0;
    my $casei = $o->{API}{case_ignore} ? '(?i)' : '';
    my @key = grep { $action =~ /$casei^\Q$_\E$/ } keys %{$o->{handlers}};
    return () unless @key == 1;
    return () unless exists $o->{handlers}{$key[0]}{$type};
    my $handler = $o->{handlers}{$key[0]}{$type};
    $handler =~ s/\Q${type}_\E// if $strip;
    return $handler;
}

sub is_alias {
    my $o = shift;
    my $action = shift;
    exists $o->{handlers}{$action}{alias} ? 1 : 0;
}

sub has_aliases {
    my $o = shift;
    my $action = shift;
    my @a = $o->get_aliases($action);
    @a ? 1 : 0;
}

sub get_aliases {
    my $o = shift;
    my $action = shift;
    my @a = eval {
	my $hndlr = $o->{handlers}{$action}{alias};
	return () unless $hndlr;
	$o->$hndlr();
    };
    $o->{aliases}{$_} = $action for @a;
    @a;
}

sub unalias {
    my $o = shift;
    my $alias = shift;
    my $type  = shift;
    return $alias unless $type;
    my @stuff = split '_', $alias;
    $stuff[1] ||= '';
    return $alias unless $stuff[0] eq $type;
    return $alias unless exists $o->{aliases}{$stuff[1]};
    return $type . '_' . $o->{aliases}{$stuff[1]};
}

sub find_handlers {
    my $o = shift;
    my $pkg = shift || $o->{API}{class};

    # Find the handlers in the given namespace:
    my %handlers;
    {
	no strict 'refs';
	my @r = keys %{ $pkg . "::" };
	$o->add_handlers(@r);
    }

    # Find handlers in its base classes.
    {
	no strict 'refs';
	my @isa = @{ $pkg . "::ISA" };
	for my $pkg (@isa) {
	    $o->find_handlers($pkg);
	}
    }
}

sub rl_complete {
    my $o = shift;
    my ($word, $line, $start) = @_;

    # If it's a command, complete 'run_':
    if ($start == 0 or substr($line, 0, $start) =~ /^\s*$/) {
	my @compls = $o->complete('', $word, $line, $start);
	return @compls if $o->{command}{comp}{found};
    }

    # If it's a subcommand, send it to any custom completion function for the
    # function:
    else {
	my $command = ($o->line_parsed($line))[0];
	my @compls = $o->complete($command, $word, $line, $start);
	return @compls if $o->{command}{comp}{found};
    }

    ()
}

#=============================================================================
# Two action handlers provided by default: help and exit.
#=============================================================================
sub smry_exit { "exits the program" }
sub help_exit {
    <<'END';
Exits the program.
END
}
sub run_exit {
    my $o = shift;
    $o->stoploop;
}

sub smry_help { "prints this screen, or help on 'command'" }
sub help_help {
    <<'END'
Provides help on commands...
END
}
sub comp_help {
    my ($o, $word, $line, $start) = @_;
    my @words = $o->line_parsed($line);
    return []
      if (@words > 2 or @words == 2 and $start == length($line));
    sort $o->possible_actions($word, 'help', 1);
}
sub run_help {
    my $o = shift;
    my $cmd = shift;
    if ($cmd) {
	my $txt = $o->help($cmd, @_);
	if ($o->{command}{help}{found}) {
	    $o->page($txt)
	}
	else {
	    my @c = sort $o->possible_actions($cmd, 'help', 1);
	    if (@c) {
		local $" = "\n\t";
		print <<END;
Ambiguous help topic '$cmd': possible help topics:
	@c
END
	    }
	    else {
		print <<END;
Unknown help topic '$cmd'; type 'help' for a list of help topics.
END
	    }
	}
    }
    else {
	print "Type 'help command' for more detailed help on a command.\n";
	my (%cmds, %docs);
	my %done;
	my %handlers;
	for my $h (keys %{$o->{handlers}}) {
	    next unless length($h);
	    next unless grep{defined$o->{handlers}{$h}{$_}} qw(run smry help);
	    my $dest = exists $o->{handlers}{$h}{run} ? \%cmds : \%docs;
	    my $smry = exists $o->{handlers}{$h}{smry}
		? $o->summary($h)
		: "undocumented";
	    my $help = exists $o->{handlers}{$h}{help}
		? (exists $o->{handlers}{$h}{smry}
		    ? ""
		    : " - but help available")
		: " - no help available";
	    $dest->{"    $h"} = "$smry$help";
	}
	my @t;
	push @t, "  Commands:\n" if %cmds;
	push @t, scalar $o->format_pairs(
	    [sort keys %cmds], [map {$cmds{$_}} sort keys %cmds], ' - ', 1
	);
	push @t, "  Extra Help Topics: (not commands)\n" if %docs;
	push @t, scalar $o->format_pairs(
	    [sort keys %docs], [map {$docs{$_}} sort keys %docs], ' - ', 1
	);
	$o->page(join '', @t);
    }
}

sub run_ { }
sub comp_ {
    my ($o, $word, $line, $start) = @_;
    my @comp = grep { length($_) } sort $o->possible_actions($word, 'run', 1);
    return @comp;
}

package Term::Shell::OnScopeLeave;

sub new {
    return bless [@_[1 .. $#_]], ref($_[0]) || $_[0];
}

sub DESTROY {
    my $o = shift;
    for my $c (@$o) {
	&$c;
    }
}

1;
