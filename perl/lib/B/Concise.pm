package B::Concise;
# Copyright (C) 2000-2003 Stephen McCamant. All rights reserved.
# This program is free software; you can redistribute and/or modify it
# under the same terms as Perl itself.

# Note: we need to keep track of how many use declarations/BEGIN
# blocks this module uses, so we can avoid printing them when user
# asks for the BEGIN blocks in her program. Update the comments and
# the count in concise_specials if you add or delete one. The
# -MO=Concise counts as use #1.

use strict; # use #2
use warnings; # uses #3 and #4, since warnings uses Carp

use Exporter (); # use #5

our $VERSION   = "0.56";
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(set_style set_style_standard add_callback
		    concise_subref concise_cv concise_main);

# use #6
use B qw(class ppname main_start main_root main_cv cstring svref_2object
	 SVf_IOK SVf_NOK SVf_POK SVf_IVisUV SVf_FAKE OPf_KIDS CVf_ANON);

my %style = 
  ("terse" =>
   ["(?(#label =>\n)?)(*(    )*)#class (#addr) #name (?([#targ])?) "
    . "#svclass~(?((#svaddr))?)~#svval~(?(label \"#coplabel\")?)\n",
    "(*(    )*)goto #class (#addr)\n",
    "#class pp_#name"],
   "concise" =>
   ["#hyphseq2 (*(   (x( ;)x))*)<#classsym> "
    . "#exname#arg(?([#targarglife])?)~#flags(?(/#private)?)(x(;~->#next)x)\n",
    "  (*(    )*)     goto #seq\n",
    "(?(<#seq>)?)#exname#arg(?([#targarglife])?)"],
   "linenoise" =>
   ["(x(;(*( )*))x)#noise#arg(?([#targarg])?)(x( ;\n)x)",
    "gt_#seq ",
    "(?(#seq)?)#noise#arg(?([#targarg])?)"],
   "debug" =>
   ["#class (#addr)\n\top_next\t\t#nextaddr\n\top_sibling\t#sibaddr\n\t"
    . "op_ppaddr\tPL_ppaddr[OP_#NAME]\n\top_type\t\t#typenum\n\top_seq\t\t"
    . "#seqnum\n\top_flags\t#flagval\n\top_private\t#privval\n"
    . "(?(\top_first\t#firstaddr\n)?)(?(\top_last\t\t#lastaddr\n)?)"
    . "(?(\top_sv\t\t#svaddr\n)?)",
    "    GOTO #addr\n",
    "#addr"],
   "env" => [$ENV{B_CONCISE_FORMAT}, $ENV{B_CONCISE_GOTO_FORMAT},
	     $ENV{B_CONCISE_TREE_FORMAT}],
  );

my($format, $gotofmt, $treefmt);
my $curcv;
my $cop_seq_base;
my @callbacks;

sub set_style {
    ($format, $gotofmt, $treefmt) = @_;
}

sub set_style_standard {
    my($name) = @_;
    set_style(@{$style{$name}});
}

sub add_callback {
    push @callbacks, @_;
}

sub concise_subref {
    my($order, $subref) = @_;
    concise_cv_obj($order, svref_2object($subref));
}

# This should have been called concise_subref, but it was exported
# under this name in versions before 0.56
sub concise_cv { concise_subref(@_); }

sub concise_cv_obj {
    my ($order, $cv) = @_;
    $curcv = $cv;
    sequence($cv->START);
    if ($order eq "exec") {
	walk_exec($cv->START);
    } elsif ($order eq "basic") {
	walk_topdown($cv->ROOT, sub { $_[0]->concise($_[1]) }, 0);
    } else {
	print tree($cv->ROOT, 0)
    }
}

sub concise_main {
    my($order) = @_;
    sequence(main_start);
    $curcv = main_cv;
    if ($order eq "exec") {
	return if class(main_start) eq "NULL";
	walk_exec(main_start);
    } elsif ($order eq "tree") {
	return if class(main_root) eq "NULL";
	print tree(main_root, 0);
    } elsif ($order eq "basic") {
	return if class(main_root) eq "NULL";
	walk_topdown(main_root,
		     sub { $_[0]->concise($_[1]) }, 0);
    }
}

sub concise_specials {
    my($name, $order, @cv_s) = @_;
    my $i = 1;
    if ($name eq "BEGIN") {
	splice(@cv_s, 0, 7); # skip 7 BEGIN blocks in this file
    } elsif ($name eq "CHECK") {
	pop @cv_s; # skip the CHECK block that calls us
    }
    for my $cv (@cv_s) {	
	print "$name $i:\n";
	$i++;
	concise_cv_obj($order, $cv);
    }
}

my $start_sym = "\e(0"; # "\cN" sometimes also works
my $end_sym   = "\e(B"; # "\cO" respectively

my @tree_decorations = 
  (["  ", "--", "+-", "|-", "| ", "`-", "-", 1],
   [" ", "-", "+", "+", "|", "`", "", 0],
   ["  ", map("$start_sym$_$end_sym", "qq", "wq", "tq", "x ", "mq", "q"), 1],
   [" ", map("$start_sym$_$end_sym", "q", "w", "t", "x", "m"), "", 0],
  );
my $tree_style = 0;

my $base = 36;
my $big_endian = 1;

my $order = "basic";

set_style_standard("concise");

sub compile {
    my @options = grep(/^-/, @_);
    my @args = grep(!/^-/, @_);
    my $do_main = 0;
    for my $o (@options) {
	if ($o eq "-basic") {
	    $order = "basic";
	} elsif ($o eq "-exec") {
	    $order = "exec";
	} elsif ($o eq "-tree") {
	    $order = "tree";
	} elsif ($o eq "-compact") {
	    $tree_style |= 1;
	} elsif ($o eq "-loose") {
	    $tree_style &= ~1;
	} elsif ($o eq "-vt") {
	    $tree_style |= 2;
	} elsif ($o eq "-ascii") {
	    $tree_style &= ~2;
	} elsif ($o eq "-main") {
	    $do_main = 1;
	} elsif ($o =~ /^-base(\d+)$/) {
	    $base = $1;
	} elsif ($o eq "-bigendian") {
	    $big_endian = 1;
	} elsif ($o eq "-littleendian") {
	    $big_endian = 0;
	} elsif (exists $style{substr($o, 1)}) {
	    set_style(@{$style{substr($o, 1)}});
	} else {
	    warn "Option $o unrecognized";
	}
    }
    return sub {
	if (@args) {
	    for my $objname (@args) {
		if ($objname eq "BEGIN") {
		    concise_specials("BEGIN", $order,
				     B::begin_av->isa("B::AV") ?
				     B::begin_av->ARRAY : ());
		} elsif ($objname eq "INIT") {
		    concise_specials("INIT", $order,
				     B::init_av->isa("B::AV") ?
				     B::init_av->ARRAY : ());
		} elsif ($objname eq "CHECK") {
		    concise_specials("CHECK", $order,
				     B::check_av->isa("B::AV") ?
				     B::check_av->ARRAY : ());
		} elsif ($objname eq "END") {
		    concise_specials("END", $order,
				     B::end_av->isa("B::AV") ?
				     B::end_av->ARRAY : ());
		} else {
		    $objname = "main::" . $objname unless $objname =~ /::/;
		    print "$objname:\n";
		    eval "concise_subref(\$order, \\&$objname)";
		    die "concise_subref($order, \\&$objname) failed: $@" if $@;
		}
	    }
	}
	if (!@args or $do_main) {
	    print "main program:\n" if $do_main;
	    concise_main($order);
	}
    }
}

my %labels;
my $lastnext;

my %opclass = ('OP' => "0", 'UNOP' => "1", 'BINOP' => "2", 'LOGOP' => "|",
	       'LISTOP' => "@", 'PMOP' => "/", 'SVOP' => "\$", 'GVOP' => "*",
	       'PVOP' => '"', 'LOOP' => "{", 'COP' => ";", 'PADOP' => "#");

no warnings 'qw'; # "Possible attempt to put comments..."; use #7
my @linenoise =
  qw'#  () sc (  @? 1  $* gv *{ m$ m@ m% m? p/ *$ $  $# & a& pt \\ s\\ rf bl
     `  *? <> ?? ?/ r/ c/ // qr s/ /c y/ =  @= C  sC Cp sp df un BM po +1 +I
     -1 -I 1+ I+ 1- I- ** *  i* /  i/ %$ i% x  +  i+ -  i- .  "  << >> <  i<
     >  i> <= i, >= i. == i= != i! <? i? s< s> s, s. s= s! s? b& b^ b| -0 -i
     !  ~  a2 si cs rd sr e^ lg sq in %x %o ab le ss ve ix ri sf FL od ch cy
     uf lf uc lc qm @  [f [  @[ eh vl ky dl ex %  ${ @{ uk pk st jn )  )[ a@
     a% sl +] -] [- [+ so rv GS GW MS MW .. f. .f && || ^^ ?: &= |= -> s{ s}
     v} ca wa di rs ;; ;  ;d }{ {  }  {} f{ it {l l} rt }l }n }r dm }g }e ^o
     ^c ^| ^# um bm t~ u~ ~d DB db ^s se ^g ^r {w }w pf pr ^O ^K ^R ^W ^d ^v
     ^e ^t ^k t. fc ic fl .s .p .b .c .l .a .h g1 s1 g2 s2 ?. l? -R -W -X -r
     -w -x -e -o -O -z -s -M -A -C -S -c -b -f -d -p -l -u -g -k -t -T -B cd
     co cr u. cm ut r. l@ s@ r@ mD uD oD rD tD sD wD cD f$ w$ p$ sh e$ k$ g3
     g4 s4 g5 s5 T@ C@ L@ G@ A@ S@ Hg Hc Hr Hw Mg Mc Ms Mr Sg Sc So rq do {e
     e} {t t} g6 G6 6e g7 G7 7e g8 G8 8e g9 G9 9e 6s 7s 8s 9s 6E 7E 8E 9E Pn
     Pu GP SP EP Gn Gg GG SG EG g0 c$ lk t$ ;s n> // /= CO';

my $chars = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";

sub op_flags {
    my($x) = @_;
    my(@v);
    push @v, "v" if ($x & 3) == 1;
    push @v, "s" if ($x & 3) == 2;
    push @v, "l" if ($x & 3) == 3;
    push @v, "K" if $x & 4;
    push @v, "P" if $x & 8;
    push @v, "R" if $x & 16;
    push @v, "M" if $x & 32;
    push @v, "S" if $x & 64;
    push @v, "*" if $x & 128;
    return join("", @v);
}

sub base_n {
    my $x = shift;
    return "-" . base_n(-$x) if $x < 0;
    my $str = "";
    do { $str .= substr($chars, $x % $base, 1) } while $x = int($x / $base);
    $str = reverse $str if $big_endian;
    return $str;
}

my %sequence_num;
my $seq_max = 1;

sub seq {
    my($op) = @_;
    return "-" if not exists $sequence_num{$$op};
    return base_n($sequence_num{$$op});
}

sub walk_topdown {
    my($op, $sub, $level) = @_;
    $sub->($op, $level);
    if ($op->flags & OPf_KIDS) {
	for (my $kid = $op->first; $$kid; $kid = $kid->sibling) {
	    walk_topdown($kid, $sub, $level + 1);
	}
    }
    if (class($op) eq "PMOP") {
	my $maybe_root = $op->pmreplroot;
	if (ref($maybe_root) and $maybe_root->isa("B::OP")) {
	    # It really is the root of the replacement, not something
	    # else stored here for lack of space elsewhere
	    walk_topdown($maybe_root, $sub, $level + 1);
	}
    }
}

sub walklines {
    my($ar, $level) = @_;
    for my $l (@$ar) {
	if (ref($l) eq "ARRAY") {
	    walklines($l, $level + 1);
	} else {
	    $l->concise($level);
	}
    }
}

sub walk_exec {
    my($top, $level) = @_;
    my %opsseen;
    my @lines;
    my @todo = ([$top, \@lines]);
    while (@todo and my($op, $targ) = @{shift @todo}) {
	for (; $$op; $op = $op->next) {
	    last if $opsseen{$$op}++;
	    push @$targ, $op;
	    my $name = $op->name;
	    if (class($op) eq "LOGOP") {
		my $ar = [];
		push @$targ, $ar;
		push @todo, [$op->other, $ar];
	    } elsif ($name eq "subst" and $ {$op->pmreplstart}) {
		my $ar = [];
		push @$targ, $ar;
		push @todo, [$op->pmreplstart, $ar];
	    } elsif ($name =~ /^enter(loop|iter)$/) {
		$labels{$op->nextop->seq} = "NEXT";
		$labels{$op->lastop->seq} = "LAST";
		$labels{$op->redoop->seq} = "REDO";		
	    }
	}
    }
    walklines(\@lines, 0);
}

# The structure of this routine is purposely modeled after op.c's peep()
sub sequence {
    my($op) = @_;
    my $oldop = 0;
    return if class($op) eq "NULL" or exists $sequence_num{$$op};
    for (; $$op; $op = $op->next) {
	last if exists $sequence_num{$$op};
	my $name = $op->name;
	if ($name =~ /^(null|scalar|lineseq|scope)$/) {
	    next if $oldop and $ {$op->next};
	} else {
	    $sequence_num{$$op} = $seq_max++;
	    if (class($op) eq "LOGOP") {
		my $other = $op->other;
		$other = $other->next while $other->name eq "null";
		sequence($other);
	    } elsif (class($op) eq "LOOP") {
		my $redoop = $op->redoop;
		$redoop = $redoop->next while $redoop->name eq "null";
		sequence($redoop);
		my $nextop = $op->nextop;
		$nextop = $nextop->next while $nextop->name eq "null";
		sequence($nextop);
		my $lastop = $op->lastop;
		$lastop = $lastop->next while $lastop->name eq "null";
		sequence($lastop);
	    } elsif ($name eq "subst" and $ {$op->pmreplstart}) {
		my $replstart = $op->pmreplstart;
		$replstart = $replstart->next while $replstart->name eq "null";
		sequence($replstart);
	    }
	}
	$oldop = $op;
    }
}

sub fmt_line {
    my($hr, $fmt, $level) = @_;
    my $text = $fmt;
    $text =~ s/\(\?\(([^\#]*?)\#(\w+)([^\#]*?)\)\?\)/
      $hr->{$2} ? $1.$hr->{$2}.$3 : ""/eg;
    $text =~ s/\(x\((.*?);(.*?)\)x\)/$order eq "exec" ? $1 : $2/egs;
    $text =~ s/\(\*\(([^;]*?)\)\*\)/$1 x $level/egs;
    $text =~ s/\(\*\((.*?);(.*?)\)\*\)/$1 x ($level - 1) . $2 x ($level>0)/egs;
    $text =~ s/#([a-zA-Z]+)(\d+)/sprintf("%-$2s", $hr->{$1})/eg;
    $text =~ s/#([a-zA-Z]+)/$hr->{$1}/eg;
    $text =~ s/[ \t]*~+[ \t]*/ /g;
    return $text;
}

my %priv;
$priv{$_}{128} = "LVINTRO"
  for ("pos", "substr", "vec", "threadsv", "gvsv", "rv2sv", "rv2hv", "rv2gv",
       "rv2av", "rv2arylen", "aelem", "helem", "aslice", "hslice", "padsv",
       "padav", "padhv", "enteriter");
$priv{$_}{64} = "REFC" for ("leave", "leavesub", "leavesublv", "leavewrite");
$priv{"aassign"}{64} = "COMMON";
$priv{"aassign"}{32} = "PHASH";
$priv{"sassign"}{64} = "BKWARD";
$priv{$_}{64} = "RTIME" for ("match", "subst", "substcont");
@{$priv{"trans"}}{1,2,4,8,16,64} = ("<UTF", ">UTF", "IDENT", "SQUASH", "DEL",
				    "COMPL", "GROWS");
$priv{"repeat"}{64} = "DOLIST";
$priv{"leaveloop"}{64} = "CONT";
@{$priv{$_}}{32,64,96} = ("DREFAV", "DREFHV", "DREFSV")
  for ("entersub", map("rv2${_}v", "a", "s", "h", "g"), "aelem", "helem");
$priv{"entersub"}{16} = "DBG";
$priv{"entersub"}{32} = "TARG";
@{$priv{$_}}{4,8,128} = ("INARGS","AMPER","NO()") for ("entersub", "rv2cv");
$priv{"gv"}{32} = "EARLYCV";
$priv{"aelem"}{16} = $priv{"helem"}{16} = "LVDEFER";
$priv{$_}{16} = "OURINTR" for ("gvsv", "rv2sv", "rv2av", "rv2hv", "r2gv",
	"enteriter");
$priv{$_}{16} = "TARGMY"
  for (map(($_,"s$_"),"chop", "chomp"),
       map(($_,"i_$_"), "postinc", "postdec", "multiply", "divide", "modulo",
	   "add", "subtract", "negate"), "pow", "concat", "stringify",
       "left_shift", "right_shift", "bit_and", "bit_xor", "bit_or",
       "complement", "atan2", "sin", "cos", "rand", "exp", "log", "sqrt",
       "int", "hex", "oct", "abs", "length", "index", "rindex", "sprintf",
       "ord", "chr", "crypt", "quotemeta", "join", "push", "unshift", "flock",
       "chdir", "chown", "chroot", "unlink", "chmod", "utime", "rename",
       "link", "symlink", "mkdir", "rmdir", "wait", "waitpid", "system",
       "exec", "kill", "getppid", "getpgrp", "setpgrp", "getpriority",
       "setpriority", "time", "sleep");
@{$priv{"const"}}{8,16,32,64,128} = ("STRICT","ENTERED", '$[', "BARE", "WARN");
$priv{"flip"}{64} = $priv{"flop"}{64} = "LINENUM";
$priv{"list"}{64} = "GUESSED";
$priv{"delete"}{64} = "SLICE";
$priv{"exists"}{64} = "SUB";
$priv{$_}{64} = "LOCALE"
  for ("sort", "prtf", "sprintf", "slt", "sle", "seq", "sne", "sgt", "sge",
       "scmp", "lc", "uc", "lcfirst", "ucfirst");
@{$priv{"sort"}}{1,2,4} = ("NUM", "INT", "REV");
$priv{"threadsv"}{64} = "SVREFd";
@{$priv{$_}}{16,32,64,128} = ("INBIN","INCR","OUTBIN","OUTCR")
  for ("open", "backtick");
$priv{"exit"}{128} = "VMS";
$priv{$_}{2} = "FTACCESS"
  for ("ftrread", "ftrwrite", "ftrexec", "fteread", "ftewrite", "fteexec");

sub private_flags {
    my($name, $x) = @_;
    my @s;
    for my $flag (128, 96, 64, 32, 16, 8, 4, 2, 1) {
	if ($priv{$name}{$flag} and $x & $flag and $x >= $flag) {
	    $x -= $flag;
	    push @s, $priv{$name}{$flag};
	}
    }
    push @s, $x if $x;
    return join(",", @s);
}

sub concise_sv {
    my($sv, $hr) = @_;
    $hr->{svclass} = class($sv);
    $hr->{svclass} = "UV"
      if $hr->{svclass} eq "IV" and $sv->FLAGS & SVf_IVisUV;
    $hr->{svaddr} = sprintf("%#x", $$sv);
    if ($hr->{svclass} eq "GV") {
	my $gv = $sv;
	my $stash = $gv->STASH->NAME;
	if ($stash eq "main") {
	    $stash = "";
	} else {
	    $stash = $stash . "::";
	}
	$hr->{svval} = "*$stash" . $gv->SAFENAME;
	return "*$stash" . $gv->SAFENAME;
    } else {
	while (class($sv) eq "RV") {
	    $hr->{svval} .= "\\";
	    $sv = $sv->RV;
	}
	if (class($sv) eq "SPECIAL") {
	    $hr->{svval} .= ["Null", "sv_undef", "sv_yes", "sv_no"]->[$$sv];
	} elsif ($sv->FLAGS & SVf_NOK) {
	    $hr->{svval} .= $sv->NV;
	} elsif ($sv->FLAGS & SVf_IOK) {
	    $hr->{svval} .= $sv->int_value;
	} elsif ($sv->FLAGS & SVf_POK) {
	    $hr->{svval} .= cstring($sv->PV);
	} elsif (class($sv) eq "HV") {
	    $hr->{svval} .= 'HASH';
	}
	return $hr->{svclass} . " " .  $hr->{svval};
    }
}

sub concise_op {
    my ($op, $level, $format) = @_;
    my %h;
    $h{exname} = $h{name} = $op->name;
    $h{NAME} = uc $h{name};
    $h{class} = class($op);
    $h{extarg} = $h{targ} = $op->targ;
    $h{extarg} = "" unless $h{extarg};
    if ($h{name} eq "null" and $h{targ}) {
	# targ holds the old type
	$h{exname} = "ex-" . substr(ppname($h{targ}), 3);
	$h{extarg} = "";
    } elsif ($op->name =~ /^leave(sub(lv)?|write)?$/) {
	# targ potentially holds a reference count
	if ($op->private & 64) {
	    my $refs = "ref" . ($h{targ} != 1 ? "s" : "");
	    $h{targarglife} = $h{targarg} = "$h{targ} $refs";
	}
    } elsif ($h{targ}) {
	my $padname = (($curcv->PADLIST->ARRAY)[0]->ARRAY)[$h{targ}];
	if (defined $padname and class($padname) ne "SPECIAL") {
	    $h{targarg}  = $padname->PVX;
	    if ($padname->FLAGS & SVf_FAKE) {
		$h{targarglife} = "$h{targarg}:FAKE";
	    }
	    else {
		my $intro = $padname->NVX - $cop_seq_base;
		my $finish = int($padname->IVX) - $cop_seq_base;
		$finish = "end" if $finish == 999999999 - $cop_seq_base;
		$h{targarglife} = "$h{targarg}:$intro,$finish";
	    }
	} else {
	    $h{targarglife} = $h{targarg} = "t" . $h{targ};
	}
    }
    $h{arg} = "";
    $h{svclass} = $h{svaddr} = $h{svval} = "";
    if ($h{class} eq "PMOP") {
	my $precomp = $op->precomp;
	if (defined $precomp) {
	    $precomp = cstring($precomp); # Escape literal control sequences
 	    $precomp = "/$precomp/";
	} else {
	    $precomp = "";
	}
	my $pmreplroot = $op->pmreplroot;
	my $pmreplstart;
	if (ref($pmreplroot) eq "B::GV") {
	    # with C<@stash_array = split(/pat/, str);>,
	    #  *stash_array is stored in /pat/'s pmreplroot.
	    $h{arg} = "($precomp => \@" . $pmreplroot->NAME . ")";
	} elsif (!ref($pmreplroot) and $pmreplroot) {
	    # same as the last case, except the value is actually a
	    # pad offset for where the GV is kept (this happens under
	    # ithreads)
	    my $gv = (($curcv->PADLIST->ARRAY)[1]->ARRAY)[$pmreplroot];
	    $h{arg} = "($precomp => \@" . $gv->NAME . ")";
	} elsif ($ {$op->pmreplstart}) {
	    undef $lastnext;
	    $pmreplstart = "replstart->" . seq($op->pmreplstart);
	    $h{arg} = "(" . join(" ", $precomp, $pmreplstart) . ")";
	} else {
	    $h{arg} = "($precomp)";
	}
    } elsif ($h{class} eq "PVOP" and $h{name} ne "trans") {
	$h{arg} = '("' . $op->pv . '")';
	$h{svval} = '"' . $op->pv . '"';
    } elsif ($h{class} eq "COP") {
	my $label = $op->label;
	$h{coplabel} = $label;
	$label = $label ? "$label: " : "";
	my $loc = $op->file;
	$loc =~ s[.*/][];
	$loc .= ":" . $op->line;
	my($stash, $cseq) = ($op->stash->NAME, $op->cop_seq - $cop_seq_base);
	my $arybase = $op->arybase;
	$arybase = $arybase ? ' $[=' . $arybase : "";
	$h{arg} = "($label$stash $cseq $loc$arybase)";
    } elsif ($h{class} eq "LOOP") {
	$h{arg} = "(next->" . seq($op->nextop) . " last->" . seq($op->lastop)
	  . " redo->" . seq($op->redoop) . ")";
    } elsif ($h{class} eq "LOGOP") {
	undef $lastnext;
	$h{arg} = "(other->" . seq($op->other) . ")";
    } elsif ($h{class} eq "SVOP") {
	if (! ${$op->sv}) {
	    my $sv = (($curcv->PADLIST->ARRAY)[1]->ARRAY)[$op->targ];
	    $h{arg} = "[" . concise_sv($sv, \%h) . "]";
	    $h{targarglife} = $h{targarg} = "";
	} else {
	    $h{arg} = "(" . concise_sv($op->sv, \%h) . ")";
	}
    } elsif ($h{class} eq "PADOP") {
	my $sv = (($curcv->PADLIST->ARRAY)[1]->ARRAY)[$op->padix];
	$h{arg} = "[" . concise_sv($sv, \%h) . "]";
    }
    $h{seq} = $h{hyphseq} = seq($op);
    $h{seq} = "" if $h{seq} eq "-";
    $h{seqnum} = $op->seq;
    $h{next} = $op->next;
    $h{next} = (class($h{next}) eq "NULL") ? "(end)" : seq($h{next});
    $h{nextaddr} = sprintf("%#x", $ {$op->next});
    $h{sibaddr} = sprintf("%#x", $ {$op->sibling});
    $h{firstaddr} = sprintf("%#x", $ {$op->first}) if $op->can("first");
    $h{lastaddr} = sprintf("%#x", $ {$op->last}) if $op->can("last");

    $h{classsym} = $opclass{$h{class}};
    $h{flagval} = $op->flags;
    $h{flags} = op_flags($op->flags);
    $h{privval} = $op->private;
    $h{private} = private_flags($h{name}, $op->private);
    $h{addr} = sprintf("%#x", $$op);
    $h{label} = $labels{$op->seq};
    $h{typenum} = $op->type;
    $h{noise} = $linenoise[$op->type];
    $_->(\%h, $op, \$format, \$level) for @callbacks;
    return fmt_line(\%h, $format, $level);
}

sub B::OP::concise {
    my($op, $level) = @_;
    if ($order eq "exec" and $lastnext and $$lastnext != $$op) {
	my $h = {"seq" => seq($lastnext), "class" => class($lastnext),
		 "addr" => sprintf("%#x", $$lastnext)};
	print fmt_line($h, $gotofmt, $level+1);
    }
    $lastnext = $op->next;
    print concise_op($op, $level, $format);
}

# B::OP::terse (see Terse.pm) now just calls this
sub b_terse {
    my($op, $level) = @_;

    # This isn't necessarily right, but there's no easy way to get
    # from an OP to the right CV. This is a limitation of the
    # ->terse() interface style, and there isn't much to do about
    # it. In particular, we can die in concise_op if the main pad
    # isn't long enough, or has the wrong kind of entries, compared to
    # the pad a sub was compiled with. The fix for that would be to
    # make a backwards compatible "terse" format that never even
    # looked at the pad, just like the old B::Terse. I don't think
    # that's worth the effort, though.
    $curcv = main_cv unless $curcv;

    if ($order eq "exec" and $lastnext and $$lastnext != $$op) {
	my $h = {"seq" => seq($lastnext), "class" => class($lastnext),
		 "addr" => sprintf("%#x", $$lastnext)};
	print fmt_line($h, $style{"terse"}[1], $level+1);
    }
    $lastnext = $op->next;
    print concise_op($op, $level, $style{"terse"}[0]);
}

sub tree {
    my $op = shift;
    my $level = shift;
    my $style = $tree_decorations[$tree_style];
    my($space, $single, $kids, $kid, $nokid, $last, $lead, $size) = @$style;
    my $name = concise_op($op, $level, $treefmt);
    if (not $op->flags & OPf_KIDS) {
	return $name . "\n";
    }
    my @lines;
    for (my $kid = $op->first; $$kid; $kid = $kid->sibling) {
	push @lines, tree($kid, $level+1);
    }
    my $i;
    for ($i = $#lines; substr($lines[$i], 0, 1) eq " "; $i--) {
	$lines[$i] = $space . $lines[$i];
    }
    if ($i > 0) {
	$lines[$i] = $last . $lines[$i];
	while ($i-- > 1) {
	    if (substr($lines[$i], 0, 1) eq " ") {
		$lines[$i] = $nokid . $lines[$i];
	    } else {
		$lines[$i] = $kid . $lines[$i];		
	    }
	}
	$lines[$i] = $kids . $lines[$i];
    } else {
	$lines[0] = $single . $lines[0];
    }
    return("$name$lead" . shift @lines,
           map(" " x (length($name)+$size) . $_, @lines));
}

# *** Warning: fragile kludge ahead ***
# Because the B::* modules run in the same interpreter as the code
# they're compiling, their presence tends to distort the view we have
# of the code we're looking at. In particular, perl gives sequence
# numbers to both OPs in general and COPs in particular. If the
# program we're looking at were run on its own, these numbers would
# start at 1. Because all of B::Concise and all the modules it uses
# are compiled first, though, by the time we get to the user's program
# the sequence numbers are alreay at pretty high numbers, which would
# be distracting if you're trying to tell OPs apart. Therefore we'd
# like to subtract an offset from all the sequence numbers we display,
# to restore the simpler view of the world. The trick is to know what
# that offset will be, when we're still compiling B::Concise!  If we
# hardcoded a value, it would have to change every time B::Concise or
# other modules we use do. To help a little, what we do here is
# compile a little code at the end of the module, and compute the base
# sequence number for the user's program as being a small offset
# later, so all we have to worry about are changes in the offset.
# (Note that we now only play this game with COP sequence numbers. OP
# sequence numbers aren't used to refer to OPs from a distance, and
# they don't have much significance, so we just generate our own
# sequence numbers which are easier to control. This way we also don't
# stand in the way of a possible future removal of OP sequence
# numbers).

# When you say "perl -MO=Concise -e '$a'", the output should look like:

# 4  <@> leave[t1] vKP/REFC ->(end)
# 1     <0> enter ->2
 #^ smallest OP sequence number should be 1
# 2     <;> nextstate(main 1 -e:1) v ->3
 #                         ^ smallest COP sequence number should be 1
# -     <1> ex-rv2sv vK/1 ->4
# 3        <$> gvsv(*a) s ->4

# If the second of the marked numbers there isn't 1, it means you need
# to update the corresponding magic number in the next line.
# Remember, this needs to stay the last things in the module.

# Why is this different for MacOS?  Does it matter?
my $cop_seq_mnum = $^O eq 'MacOS' ? 12 : 11;
$cop_seq_base = svref_2object(eval 'sub{0;}')->START->cop_seq + $cop_seq_mnum;

1;

__END__

