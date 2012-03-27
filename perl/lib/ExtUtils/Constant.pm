package ExtUtils::Constant;
use vars qw (@ISA $VERSION %XS_Constant %XS_TypeSet @EXPORT_OK %EXPORT_TAGS);
$VERSION = '0.14';

if ($] >= 5.006) {
  eval "use warnings; 1" or die $@;
}
use strict;
use vars '$is_perl56';
use Carp;

$is_perl56 = ($] < 5.007 && $] > 5.005_50);

use Exporter;
use Text::Wrap;
$Text::Wrap::huge = 'overflow';
$Text::Wrap::columns = 80;

@ISA = 'Exporter';

%EXPORT_TAGS = ( 'all' => [ qw(
	XS_constant constant_types return_clause memEQ_clause C_stringify
	C_constant autoload WriteConstants WriteMakefileSnippet
) ] );

@EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

# '' is used as a flag to indicate non-ascii macro names, and hence the need
# to pass in the utf8 on/off flag.
%XS_Constant = (
		''    => '',
		IV    => 'PUSHi(iv)',
		UV    => 'PUSHu((UV)iv)',
		NV    => 'PUSHn(nv)',
		PV    => 'PUSHp(pv, strlen(pv))',
		PVN   => 'PUSHp(pv, iv)',
		SV    => 'PUSHs(sv)',
		YES   => 'PUSHs(&PL_sv_yes)',
		NO    => 'PUSHs(&PL_sv_no)',
		UNDEF => '',	# implicit undef
);

%XS_TypeSet = (
		IV    => '*iv_return =',
		UV    => '*iv_return = (IV)',
		NV    => '*nv_return =',
		PV    => '*pv_return =',
		PVN   => ['*pv_return =', '*iv_return = (IV)'],
		SV    => '*sv_return = ',
		YES   => undef,
		NO    => undef,
		UNDEF => undef,
);


# Hopefully make a happy C identifier.
sub C_stringify {
  local $_ = shift;
  return unless defined $_;
  # grr 5.6.1
  confess "Wide character in '$_' intended as a C identifier"
    if tr/\0-\377// != length;
  # grr 5.6.1 moreso because its regexps will break on data that happens to
  # be utf8, which includes my 8 bit test cases.
  $_ = pack 'C*', unpack 'U*', $_ . pack 'U*' if $is_perl56;
  s/\\/\\\\/g;
  s/([\"\'])/\\$1/g;	# Grr. fix perl mode.
  s/\n/\\n/g;		# Ensure newlines don't end up in octal
  s/\r/\\r/g;
  s/\t/\\t/g;
  s/\f/\\f/g;
  s/\a/\\a/g;
  s/([^\0-\177])/sprintf "\\%03o", ord $1/ge;
  unless ($] < 5.006) {
    # This will elicit a warning on 5.005_03 about [: :] being reserved unless
    # I cheat
    my $cheat = '([[:^print:]])';
    s/$cheat/sprintf "\\%03o", ord $1/ge;
  } else {
    require POSIX;
    s/([^A-Za-z0-9_])/POSIX::isprint($1) ? $1 : sprintf "\\%03o", ord $1/ge;
  }
  $_;
}

# Hopefully make a happy perl identifier.
sub perl_stringify {
  local $_ = shift;
  return unless defined $_;
  s/\\/\\\\/g;
  s/([\"\'])/\\$1/g;	# Grr. fix perl mode.
  s/\n/\\n/g;		# Ensure newlines don't end up in octal
  s/\r/\\r/g;
  s/\t/\\t/g;
  s/\f/\\f/g;
  s/\a/\\a/g;
  unless ($] < 5.006) {
    if ($] > 5.007) {
      s/([^\0-\177])/sprintf "\\x{%X}", ord $1/ge;
    } else {
      # Grr 5.6.1. And I don't think I can use utf8; to force the regexp
      # because 5.005_03 will fail.
      # This is grim, but I also can't split on //
      my $copy;
      foreach my $index (0 .. length ($_) - 1) {
        my $char = substr ($_, $index, 1);
        $copy .= ($char le "\177") ? $char : sprintf "\\x{%X}", ord $char;
      }
      $_ = $copy;
    }
    # This will elicit a warning on 5.005_03 about [: :] being reserved unless
    # I cheat
    my $cheat = '([[:^print:]])';
    s/$cheat/sprintf "\\%03o", ord $1/ge;
  } else {
    # Turns out "\x{}" notation only arrived with 5.6
    s/([^\0-\177])/sprintf "\\x%02X", ord $1/ge;
    require POSIX;
    s/([^A-Za-z0-9_])/POSIX::isprint($1) ? $1 : sprintf "\\%03o", ord $1/ge;
  }
  $_;
}

sub constant_types () {
  my $start = 1;
  my @lines;
  push @lines, "#define PERL_constant_NOTFOUND\t$start\n"; $start++;
  push @lines, "#define PERL_constant_NOTDEF\t$start\n"; $start++;
  foreach (sort keys %XS_Constant) {
    next if $_ eq '';
    push @lines, "#define PERL_constant_IS$_\t$start\n"; $start++;
  }
  push @lines, << 'EOT';

#ifndef NVTYPE
typedef double NV; /* 5.6 and later define NVTYPE, and typedef NV to it.  */
#endif
#ifndef aTHX_
#define aTHX_ /* 5.6 or later define this for threading support.  */
#endif
#ifndef pTHX_
#define pTHX_ /* 5.6 or later define this for threading support.  */
#endif
EOT

  return join '', @lines;
}

sub memEQ_clause {
#    if (memEQ(name, "thingy", 6)) {
  # Which could actually be a character comparison or even ""
  my ($name, $checked_at, $indent) = @_;
  $indent = ' ' x ($indent || 4);
  my $front_chop;
  if (ref $checked_at) {
    # regexp won't work on 5.6.1 without use utf8; in turn that won't work
    # on 5.005_03.
    substr ($name, 0, length $$checked_at,) = '';
    $front_chop = C_stringify ($$checked_at);
    undef $checked_at;
  }
  my $len = length $name;

  if ($len < 2) {
    return $indent . "{\n" if (defined $checked_at and $checked_at == 0);
    # We didn't switch, drop through to the code for the 2 character string
    $checked_at = 1;
  }
  if ($len < 3 and defined $checked_at) {
    my $check;
    if ($checked_at == 1) {
      $check = 0;
    } elsif ($checked_at == 0) {
      $check = 1;
    }
    if (defined $check) {
      my $char = C_stringify (substr $name, $check, 1);
      return $indent . "if (name[$check] == '$char') {\n";
    }
  }
  if (($len == 2 and !defined $checked_at)
     or ($len == 3 and defined ($checked_at) and $checked_at == 2)) {
    my $char1 = C_stringify (substr $name, 0, 1);
    my $char2 = C_stringify (substr $name, 1, 1);
    return $indent . "if (name[0] == '$char1' && name[1] == '$char2') {\n";
  }
  if (($len == 3 and defined ($checked_at) and $checked_at == 1)) {
    my $char1 = C_stringify (substr $name, 0, 1);
    my $char2 = C_stringify (substr $name, 2, 1);
    return $indent . "if (name[0] == '$char1' && name[2] == '$char2') {\n";
  }

  my $pointer = '^';
  my $have_checked_last = defined ($checked_at) && $len == $checked_at + 1;
  if ($have_checked_last) {
    # Checked at the last character, so no need to memEQ it.
    $pointer = C_stringify (chop $name);
    $len--;
  }

  $name = C_stringify ($name);
  my $body = $indent . "if (memEQ(name, \"$name\", $len)) {\n";
  # Put a little ^ under the letter we checked at
  # Screws up for non printable and non-7 bit stuff, but that's too hard to
  # get right.
  if (defined $checked_at) {
    $body .= $indent . "/*               ". (' ' x $checked_at) . $pointer
      . (' ' x ($len - $checked_at + length $len)) . "    */\n";
  } elsif (defined $front_chop) {
    $body .= $indent . "/*              $front_chop"
      . (' ' x ($len + 1 + length $len)) . "    */\n";
  }
  return $body;
}

# Hmm. value undef to to NOTDEF? value () to do NOTFOUND?

sub assign {
  my $indent = shift;
  my $type = shift;
  my $pre = shift;
  my $post = shift || '';
  my $clause;
  my $close;
  if ($pre) {
    chomp $pre;
    $clause = $indent . "{\n$pre";
    $clause .= ";" unless $pre =~ /;$/;
    $clause .= "\n";
    $close = "$indent}\n";
    $indent .= "  ";
  }
  confess "undef \$type" unless defined $type;
  confess "Can't generate code for type $type" unless exists $XS_TypeSet{$type};
  my $typeset = $XS_TypeSet{$type};
  if (ref $typeset) {
    die "Type $type is aggregate, but only single value given"
      if @_ == 1;
    foreach (0 .. $#$typeset) {
      $clause .= $indent . "$typeset->[$_] $_[$_];\n";
    }
  } elsif (defined $typeset) {
    die "Aggregate value given for type $type"
      if @_ > 1;
    $clause .= $indent . "$typeset $_[0];\n";
  }
  chomp $post;
  if (length $post) {
    $clause .= "$post";
    $clause .= ";" unless $post =~ /;$/;
    $clause .= "\n";
  }
  $clause .= "${indent}return PERL_constant_IS$type;\n";
  $clause .= $close if $close;
  return $clause;
}

sub return_clause ($$) {
##ifdef thingy
#      *iv_return = thingy;
#      return PERL_constant_ISIV;
##else
#      return PERL_constant_NOTDEF;
##endif
  my ($item, $indent) = @_;

  my ($name, $value, $macro, $default, $pre, $post, $def_pre, $def_post, $type)
    = @$item{qw (name value macro default pre post def_pre def_post type)};
  $value = $name unless defined $value;
  $macro = $name unless defined $macro;

  $macro = $value unless defined $macro;
  $indent = ' ' x ($indent || 6);
  unless ($type) {
    # use Data::Dumper; print STDERR Dumper ($item);
    confess "undef \$type";
  }

  my $clause;

  ##ifdef thingy
  if (ref $macro) {
    $clause = $macro->[0];
  } elsif ($macro ne "1") {
    $clause = "#ifdef $macro\n";
  }

  #      *iv_return = thingy;
  #      return PERL_constant_ISIV;
  $clause .= assign ($indent, $type, $pre, $post,
                     ref $value ? @$value : $value);

  if (ref $macro or $macro ne "1") {
    ##else
    $clause .= "#else\n";

    #      return PERL_constant_NOTDEF;
    if (!defined $default) {
      $clause .= "${indent}return PERL_constant_NOTDEF;\n";
    } else {
      my @default = ref $default ? @$default : $default;
      $type = shift @default;
      $clause .= assign ($indent, $type, $def_pre, $def_post, @default);
    }

    ##endif
    if (ref $macro) {
      $clause .= $macro->[1];
    } else {
      $clause .= "#endif\n";
    }
  }
  return $clause;
}

sub match_clause {
  # $offset defined if we have checked an offset.
  my ($item, $offset, $indent) = @_;
  $indent = ' ' x ($indent || 4);
  my $body = '';
  my ($no, $yes, $either, $name, $inner_indent);
  if (ref $item eq 'ARRAY') {
    ($yes, $no) = @$item;
    $either = $yes || $no;
    confess "$item is $either expecting hashref in [0] || [1]"
      unless ref $either eq 'HASH';
    $name = $either->{name};
  } else {
    confess "$item->{name} has utf8 flag '$item->{utf8}', should be false"
      if $item->{utf8};
    $name = $item->{name};
    $inner_indent = $indent;
  }

  $body .= memEQ_clause ($name, $offset, length $indent);
  if ($yes) {
    $body .= $indent . "  if (utf8) {\n";
  } elsif ($no) {
    $body .= $indent . "  if (!utf8) {\n";
  }
  if ($either) {
    $body .= return_clause ($either, 4 + length $indent);
    if ($yes and $no) {
      $body .= $indent . "  } else {\n";
      $body .= return_clause ($no, 4 + length $indent); 
    }
    $body .= $indent . "  }\n";
  } else {
    $body .= return_clause ($item, 2 + length $indent);
  }
  $body .= $indent . "}\n";
}

sub switch_clause {
  my ($indent, $comment, $namelen, $items, @items) = @_;
  $indent = ' ' x ($indent || 2);

  my @names = sort map {$_->{name}} @items;
  my $leader = $indent . '/* ';
  my $follower = ' ' x length $leader;
  my $body = $indent . "/* Names all of length $namelen.  */\n";
  if ($comment) {
    $body = wrap ($leader, $follower, $comment) . "\n";
    $leader = $follower;
  }
  my @safe_names = @names;
  foreach (@safe_names) {
    confess sprintf "Name '$_' is length %d, not $namelen", length
      unless length == $namelen;
    # Argh. 5.6.1
    # next unless tr/A-Za-z0-9_//c;
    next if tr/A-Za-z0-9_// == length;
    $_ = '"' . perl_stringify ($_) . '"';
    # Ensure that the enclosing C comment doesn't end
    # by turning */  into *" . "/
    s!\*\/!\*"."/!gs;
    # gcc -Wall doesn't like finding /* inside a comment
    s!\/\*!/"."\*!gs;
  }
  $body .= wrap ($leader, $follower, join (" ", @safe_names) . " */") . "\n";
  # Figure out what to switch on.
  # (RMS, Spread of jump table, Position, Hashref)
  my @best = (1e38, ~0);
  # Prefer the last character over the others. (As it lets us shortern the
  # memEQ clause at no cost).
  foreach my $i ($namelen - 1, 0 .. ($namelen - 2)) {
    my ($min, $max) = (~0, 0);
    my %spread;
    if ($is_perl56) {
      # Need proper Unicode preserving hash keys for bytes in range 128-255
      # here too, for some reason. grr 5.6.1 yet again.
      tie %spread, 'ExtUtils::Constant::Aaargh56Hash';
    }
    foreach (@names) {
      my $char = substr $_, $i, 1;
      my $ord = ord $char;
      confess "char $ord is out of range" if $ord > 255;
      $max = $ord if $ord > $max;
      $min = $ord if $ord < $min;
      push @{$spread{$char}}, $_;
      # warn "$_ $char";
    }
    # I'm going to pick the character to split on that minimises the root
    # mean square of the number of names in each case. Normally this should
    # be the one with the most keys, but it may pick a 7 where the 8 has
    # one long linear search. I'm not sure if RMS or just sum of squares is
    # actually better.
    # $max and $min are for the tie-breaker if the root mean squares match.
    # Assuming that the compiler may be building a jump table for the
    # switch() then try to minimise the size of that jump table.
    # Finally use < not <= so that if it still ties the earliest part of
    # the string wins. Because if that passes but the memEQ fails, it may
    # only need the start of the string to bin the choice.
    # I think. But I'm micro-optimising. :-)
    # OK. Trump that. Now favour the last character of the string, before the
    # rest.
    my $ss;
    $ss += @$_ * @$_ foreach values %spread;
    my $rms = sqrt ($ss / keys %spread);
    if ($rms < $best[0] || ($rms == $best[0] && ($max - $min) < $best[1])) {
      @best = ($rms, $max - $min, $i, \%spread);
    }
  }
  confess "Internal error. Failed to pick a switch point for @names"
    unless defined $best[2];
  # use Data::Dumper; print Dumper (@best);
  my ($offset, $best) = @best[2,3];
  $body .= $indent . "/* Offset $offset gives the best switch position.  */\n";

  my $do_front_chop = $offset == 0 && $namelen > 2;
  if ($do_front_chop) {
    $body .= $indent . "switch (*name++) {\n";
  } else {
    $body .= $indent . "switch (name[$offset]) {\n";
  }
  foreach my $char (sort keys %$best) {
    confess sprintf "'$char' is %d bytes long, not 1", length $char
      if length ($char) != 1;
    confess sprintf "char %#X is out of range", ord $char if ord ($char) > 255;
    $body .= $indent . "case '" . C_stringify ($char) . "':\n";
    foreach my $name (sort @{$best->{$char}}) {
      my $thisone = $items->{$name};
      # warn "You are here";
      if ($do_front_chop) {
        $body .= match_clause ($thisone, \$char, 2 + length $indent);
      } else {
        $body .= match_clause ($thisone, $offset, 2 + length $indent);
      }
    }
    $body .= $indent . "  break;\n";
  }
  $body .= $indent . "}\n";
  return $body;
}

sub params {
  my $what = shift;
  foreach (sort keys %$what) {
    warn "ExtUtils::Constant doesn't know how to handle values of type $_" unless defined $XS_Constant{$_};
  }
  my $params = {};
  $params->{''} = 1 if $what->{''};
  $params->{IV} = 1 if $what->{IV} || $what->{UV} || $what->{PVN};
  $params->{NV} = 1 if $what->{NV};
  $params->{PV} = 1 if $what->{PV} || $what->{PVN};
  $params->{SV} = 1 if $what->{SV};
  return $params;
}

sub dump_names {
  my ($default_type, $what, $indent, $options, @items) = @_;
  my $declare_types = $options->{declare_types};
  $indent = ' ' x ($indent || 0);

  my $result;
  my (@simple, @complex, %used_types);
  foreach (@items) {
    my $type;
    if (ref $_) {
      $type = $_->{type} || $default_type;
      if ($_->{utf8}) {
        # For simplicity always skip the bytes case, and reconstitute this entry
        # from its utf8 twin.
        next if $_->{utf8} eq 'no';
        # Copy the hashref, as we don't want to mess with the caller's hashref.
        $_ = {%$_};
        unless ($is_perl56) {
          utf8::decode ($_->{name});
        } else {
          $_->{name} = pack 'U*', unpack 'U0U*', $_->{name};
        }
        delete $_->{utf8};
      }
    } else {
      $_ = {name=>$_};
      $type = $default_type;
    }
    $used_types{$type}++;
    if ($type eq $default_type
        # grr 5.6.1
        and length $_->{name} == ($_->{name} =~ tr/A-Za-z0-9_//)
        and !defined ($_->{macro}) and !defined ($_->{value})
        and !defined ($_->{default}) and !defined ($_->{pre})
        and !defined ($_->{post}) and !defined ($_->{def_pre})
        and !defined ($_->{def_post})) {
      # It's the default type, and the name consists only of A-Za-z0-9_
      push @simple, $_->{name};
    } else {
      push @complex, $_;
    }
  }

  if (!defined $declare_types) {
    # Do they pass in any types we weren't already using?
    foreach (keys %$what) {
      next if $used_types{$_};
      $declare_types++; # Found one in $what that wasn't used.
      last; # And one is enough to terminate this loop
    }
  }
  if ($declare_types) {
    $result = $indent . 'my $types = {map {($_, 1)} qw('
      . join (" ", sort keys %$what) . ")};\n";
  }
  $result .= wrap ($indent . "my \@names = (qw(",
		   $indent . "               ", join (" ", sort @simple) . ")");
  if (@complex) {
    foreach my $item (sort {$a->{name} cmp $b->{name}} @complex) {
      my $name = perl_stringify $item->{name};
      my $line = ",\n$indent            {name=>\"$name\"";
      $line .= ", type=>\"$item->{type}\"" if defined $item->{type};
      foreach my $thing (qw (macro value default pre post def_pre def_post)) {
        my $value = $item->{$thing};
        if (defined $value) {
          if (ref $value) {
            $line .= ", $thing=>[\""
              . join ('", "', map {perl_stringify $_} @$value) . '"]';
          } else {
            $line .= ", $thing=>\"" . perl_stringify($value) . "\"";
          }
        }
      }
      $line .= "}";
      # Ensure that the enclosing C comment doesn't end
      # by turning */  into *" . "/
      $line =~ s!\*\/!\*" . "/!gs;
      # gcc -Wall doesn't like finding /* inside a comment
      $line =~ s!\/\*!/" . "\*!gs;
      $result .= $line;
    }
  }
  $result .= ");\n";

  $result;
}


sub dogfood {
  my ($package, $subname, $default_type, $what, $indent, $breakout, @items)
    = @_;
  my $result = <<"EOT";
  /* When generated this function returned values for the list of names given
     in this section of perl code.  Rather than manually editing these functions
     to add or remove constants, which would result in this comment and section
     of code becoming inaccurate, we recommend that you edit this section of
     code, and use it to regenerate a new set of constant functions which you
     then use to replace the originals.

     Regenerate these constant functions by feeding this entire source file to
     perl -x

#!$^X -w
use ExtUtils::Constant qw (constant_types C_constant XS_constant);

EOT
  $result .= dump_names ($default_type, $what, 0, {declare_types=>1}, @items);
  $result .= <<'EOT';

print constant_types(); # macro defs
EOT
  $package = perl_stringify($package);
  $result .=
    "foreach (C_constant (\"$package\", '$subname', '$default_type', \$types, ";
  # The form of the indent parameter isn't defined. (Yet)
  if (defined $indent) {
    require Data::Dumper;
    $Data::Dumper::Terse=1;
    $Data::Dumper::Terse=1; # Not used once. :-)
    chomp ($indent = Data::Dumper::Dumper ($indent));
    $result .= $indent;
  } else {
    $result .= 'undef';
  }
  $result .= ", $breakout" . ', @names) ) {
    print $_, "\n"; # C constant subs
}
print "#### XS Section:\n";
print XS_constant ("' . $package . '", $types);
__END__
   */

';

  $result;
}

# The parameter now BREAKOUT was previously documented as:
#
# I<NAMELEN> if defined signals that all the I<name>s of the I<ITEM>s are of
# this length, and that the constant name passed in by perl is checked and
# also of this length. It is used during recursion, and should be C<undef>
# unless the caller has checked all the lengths during code generation, and
# the generated subroutine is only to be called with a name of this length.
#
# As you can see it now performs this function during recursion by being a
# scalar reference.

sub C_constant {
  my ($package, $subname, $default_type, $what, $indent, $breakout, @items)
    = @_;
  $package ||= 'Foo';
  $subname ||= 'constant';
  # I'm not using this. But a hashref could be used for full formatting without
  # breaking this API
  # $indent ||= 0;

  my ($namelen, $items);
  if (ref $breakout) {
    # We are called recursively. We trust @items to be normalised, $what to
    # be a hashref, and pinch %$items from our parent to save recalculation.
    ($namelen, $items) = @$breakout;
  } else {
    if ($is_perl56) {
      # Need proper Unicode preserving hash keys.
      $items = {};
      tie %$items, 'ExtUtils::Constant::Aaargh56Hash';
    }
    $breakout ||= 3;
    $default_type ||= 'IV';
    if (!ref $what) {
      # Convert line of the form IV,UV,NV to hash
      $what = {map {$_ => 1} split /,\s*/, ($what || '')};
      # Figure out what types we're dealing with, and assign all unknowns to the
      # default type
    }
    my @new_items;
    foreach my $orig (@items) {
      my ($name, $item);
      if (ref $orig) {
        # Make a copy which is a normalised version of the ref passed in.
        $name = $orig->{name};
        my ($type, $macro, $value) = @$orig{qw (type macro value)};
        $type ||= $default_type;
        $what->{$type} = 1;
        $item = {name=>$name, type=>$type};

        undef $macro if defined $macro and $macro eq $name;
        $item->{macro} = $macro if defined $macro;
        undef $value if defined $value and $value eq $name;
        $item->{value} = $value if defined $value;
        foreach my $key (qw(default pre post def_pre def_post)) {
          my $value = $orig->{$key};
          $item->{$key} = $value if defined $value;
          # warn "$key $value";
        }
      } else {
        $name = $orig;
        $item = {name=>$name, type=>$default_type};
        $what->{$default_type} = 1;
      }
      warn "ExtUtils::Constant doesn't know how to handle values of type $_ used in macro $name" unless defined $XS_Constant{$item->{type}};
      # tr///c is broken on 5.6.1 for utf8, so my original tr/\0-\177//c
      # doesn't work. Upgrade to 5.8
      # if ($name !~ tr/\0-\177//c || $] < 5.005_50) {
      if ($name =~ tr/\0-\177// == length $name || $] < 5.005_50) {
        # No characters outside 7 bit ASCII.
        if (exists $items->{$name}) {
          die "Multiple definitions for macro $name";
        }
        $items->{$name} = $item;
      } else {
        # No characters outside 8 bit. This is hardest.
        if (exists $items->{$name} and ref $items->{$name} ne 'ARRAY') {
          confess "Unexpected ASCII definition for macro $name";
        }
        # Again, 5.6.1 tr broken, so s/5\.6.*/5\.8\.0/;
        # if ($name !~ tr/\0-\377//c) {
        if ($name =~ tr/\0-\377// == length $name) {
#          if ($] < 5.007) {
#            $name = pack "C*", unpack "U*", $name;
#          }
          $item->{utf8} = 'no';
          $items->{$name}[1] = $item;
          push @new_items, $item;
          # Copy item, to create the utf8 variant.
          $item = {%$item};
        }
        # Encode the name as utf8 bytes.
        unless ($is_perl56) {
          utf8::encode($name);
        } else {
#          warn "Was >$name< " . length ${name};
          $name = pack 'C*', unpack 'C*', $name . pack 'U*';
#          warn "Now '${name}' " . length ${name};
        }
        if ($items->{$name}[0]) {
          die "Multiple definitions for macro $name";
        }
        $item->{utf8} = 'yes';
        $item->{name} = $name;
        $items->{$name}[0] = $item;
        # We have need for the utf8 flag.
        $what->{''} = 1;
      }
      push @new_items, $item;
    }
    @items = @new_items;
    # use Data::Dumper; print Dumper @items;
  }
  my $params = params ($what);

  my ($body, @subs) = "static int\n$subname (pTHX_ const char *name";
  $body .= ", STRLEN len" unless defined $namelen;
  $body .= ", int utf8" if $params->{''};
  $body .= ", IV *iv_return" if $params->{IV};
  $body .= ", NV *nv_return" if $params->{NV};
  $body .= ", const char **pv_return" if $params->{PV};
  $body .= ", SV **sv_return" if $params->{SV};
  $body .= ") {\n";

  if (defined $namelen) {
    # We are a child subroutine. Print the simple description
    my $comment = 'When generated this function returned values for the list'
      . ' of names given here.  However, subsequent manual editing may have'
        . ' added or removed some.';
    $body .= switch_clause (2, $comment, $namelen, $items, @items);
  } else {
    # We are the top level.
    $body .= "  /* Initially switch on the length of the name.  */\n";
    $body .= dogfood ($package, $subname, $default_type, $what, $indent,
                      $breakout, @items);
    $body .= "  switch (len) {\n";
    # Need to group names of the same length
    my @by_length;
    foreach (@items) {
      push @{$by_length[length $_->{name}]}, $_;
    }
    foreach my $i (0 .. $#by_length) {
      next unless $by_length[$i];	# None of this length
      $body .= "  case $i:\n";
      if (@{$by_length[$i]} == 1) {
        my $only_thing = $by_length[$i]->[0];
        if ($only_thing->{utf8}) {
          if ($only_thing->{utf8} eq 'yes') {
            # With utf8 on flag item is passed in element 0
            $body .= match_clause ([$only_thing]);
          } else {
            # With utf8 off flag item is passed in element 1
            $body .= match_clause ([undef, $only_thing]);
          }
        } else {
          $body .= match_clause ($only_thing);
        }
      } elsif (@{$by_length[$i]} < $breakout) {
        $body .= switch_clause (4, '', $i, $items, @{$by_length[$i]});
      } else {
        # Only use the minimal set of parameters actually needed by the types
        # of the names of this length.
        my $what = {};
        foreach (@{$by_length[$i]}) {
          $what->{$_->{type}} = 1;
          $what->{''} = 1 if $_->{utf8};
        }
        $params = params ($what);
        push @subs, C_constant ($package, "${subname}_$i", $default_type, $what,
                                $indent, [$i, $items], @{$by_length[$i]});
        $body .= "    return ${subname}_$i (aTHX_ name";
        $body .= ", utf8" if $params->{''};
        $body .= ", iv_return" if $params->{IV};
        $body .= ", nv_return" if $params->{NV};
        $body .= ", pv_return" if $params->{PV};
        $body .= ", sv_return" if $params->{SV};
        $body .= ");\n";
      }
      $body .= "    break;\n";
    }
    $body .= "  }\n";
  }
  $body .= "  return PERL_constant_NOTFOUND;\n}\n";
  return (@subs, $body);
}

sub XS_constant {
  my $package = shift;
  my $what = shift;
  my $subname = shift;
  my $C_subname = shift;
  $subname ||= 'constant';
  $C_subname ||= $subname;

  if (!ref $what) {
    # Convert line of the form IV,UV,NV to hash
    $what = {map {$_ => 1} split /,\s*/, ($what)};
  }
  my $params = params ($what);
  my $type;

  my $xs = <<"EOT";
void
$subname(sv)
    PREINIT:
#ifdef dXSTARG
	dXSTARG; /* Faster if we have it.  */
#else
	dTARGET;
#endif
	STRLEN		len;
        int		type;
EOT

  if ($params->{IV}) {
    $xs .= "	IV		iv;\n";
  } else {
    $xs .= "	/* IV\t\tiv;\tUncomment this if you need to return IVs */\n";
  }
  if ($params->{NV}) {
    $xs .= "	NV		nv;\n";
  } else {
    $xs .= "	/* NV\t\tnv;\tUncomment this if you need to return NVs */\n";
  }
  if ($params->{PV}) {
    $xs .= "	const char	*pv;\n";
  } else {
    $xs .=
      "	/* const char\t*pv;\tUncomment this if you need to return PVs */\n";
  }

  $xs .= << 'EOT';
    INPUT:
	SV *		sv;
        const char *	s = SvPV(sv, len);
EOT
  if ($params->{''}) {
  $xs .= << 'EOT';
    INPUT:
	int		utf8 = SvUTF8(sv);
EOT
  }
  $xs .= << 'EOT';
    PPCODE:
EOT

  if ($params->{IV} xor $params->{NV}) {
    $xs .= << "EOT";
        /* Change this to $C_subname(aTHX_ s, len, &iv, &nv);
           if you need to return both NVs and IVs */
EOT
  }
  $xs .= "	type = $C_subname(aTHX_ s, len";
  $xs .= ', utf8' if $params->{''};
  $xs .= ', &iv' if $params->{IV};
  $xs .= ', &nv' if $params->{NV};
  $xs .= ', &pv' if $params->{PV};
  $xs .= ', &sv' if $params->{SV};
  $xs .= ");\n";

  $xs .= << "EOT";
      /* Return 1 or 2 items. First is error message, or undef if no error.
           Second, if present, is found value */
        switch (type) {
        case PERL_constant_NOTFOUND:
          sv = sv_2mortal(newSVpvf("%s is not a valid $package macro", s));
          PUSHs(sv);
          break;
        case PERL_constant_NOTDEF:
          sv = sv_2mortal(newSVpvf(
	    "Your vendor has not defined $package macro %s, used", s));
          PUSHs(sv);
          break;
EOT

  foreach $type (sort keys %XS_Constant) {
    # '' marks utf8 flag needed.
    next if $type eq '';
    $xs .= "\t/* Uncomment this if you need to return ${type}s\n"
      unless $what->{$type};
    $xs .= "        case PERL_constant_IS$type:\n";
    if (length $XS_Constant{$type}) {
      $xs .= << "EOT";
          EXTEND(SP, 1);
          PUSHs(&PL_sv_undef);
          $XS_Constant{$type};
EOT
    } else {
      # Do nothing. return (), which will be correctly interpreted as
      # (undef, undef)
    }
    $xs .= "          break;\n";
    unless ($what->{$type}) {
      chop $xs; # Yes, another need for chop not chomp.
      $xs .= " */\n";
    }
  }
  $xs .= << "EOT";
        default:
          sv = sv_2mortal(newSVpvf(
	    "Unexpected return type %d while processing $package macro %s, used",
               type, s));
          PUSHs(sv);
        }
EOT

  return $xs;
}


# ' # Grr. syntax highlighters that don't grok pod.

sub autoload {
  my ($module, $compat_version, $autoloader) = @_;
  $compat_version ||= $];
  croak "Can't maintain compatibility back as far as version $compat_version"
    if $compat_version < 5;
  my $func = "sub AUTOLOAD {\n"
  . "    # This AUTOLOAD is used to 'autoload' constants from the constant()\n"
  . "    # XS function.";
  $func .= "  If a constant is not found then control is passed\n"
  . "    # to the AUTOLOAD in AutoLoader." if $autoloader;


  $func .= "\n\n"
  . "    my \$constname;\n";
  $func .=
    "    our \$AUTOLOAD;\n"  if ($compat_version >= 5.006);

  $func .= <<"EOT";
    (\$constname = \$AUTOLOAD) =~ s/.*:://;
    croak "&${module}::constant not defined" if \$constname eq 'constant';
    my (\$error, \$val) = constant(\$constname);
EOT

  if ($autoloader) {
    $func .= <<'EOT';
    if ($error) {
	if ($error =~  /is not a valid/) {
	    $AutoLoader::AUTOLOAD = $AUTOLOAD;
	    goto &AutoLoader::AUTOLOAD;
	} else {
	    croak $error;
	}
    }
EOT
  } else {
    $func .=
      "    if (\$error) { croak \$error; }\n";
  }

  $func .= <<'END';
    {
	no strict 'refs';
	# Fixed between 5.005_53 and 5.005_61
#XXX	if ($] >= 5.00561) {
#XXX	    *$AUTOLOAD = sub () { $val };
#XXX	}
#XXX	else {
	    *$AUTOLOAD = sub { $val };
#XXX	}
    }
    goto &$AUTOLOAD;
}

END

  return $func;
}


sub WriteMakefileSnippet {
  my %args = @_;
  my $indent = $args{INDENT} || 2;

  my $result = <<"EOT";
ExtUtils::Constant::WriteConstants(
                                   NAME         => '$args{NAME}',
                                   NAMES        => \\\@names,
                                   DEFAULT_TYPE => '$args{DEFAULT_TYPE}',
EOT
  foreach (qw (C_FILE XS_FILE)) {
    next unless exists $args{$_};
    $result .= sprintf "                                   %-12s => '%s',\n",
      $_, $args{$_};
  }
  $result .= <<'EOT';
                                );
EOT

  $result =~ s/^/' 'x$indent/gem;
  return dump_names ($args{DEFAULT_TYPE}, undef, $indent, undef,
                           @{$args{NAMES}})
          . $result;
}

sub WriteConstants {
  my %ARGS =
    ( # defaults
     C_FILE =>       'const-c.inc',
     XS_FILE =>      'const-xs.inc',
     SUBNAME =>      'constant',
     DEFAULT_TYPE => 'IV',
     @_);

  $ARGS{C_SUBNAME} ||= $ARGS{SUBNAME}; # No-one sane will have C_SUBNAME eq '0'

  croak "Module name not specified" unless length $ARGS{NAME};

  open my $c_fh, ">$ARGS{C_FILE}" or die "Can't open $ARGS{C_FILE}: $!";
  open my $xs_fh, ">$ARGS{XS_FILE}" or die "Can't open $ARGS{XS_FILE}: $!";

  # As this subroutine is intended to make code that isn't edited, there's no
  # need for the user to specify any types that aren't found in the list of
  # names.
  my $types = {};

  print $c_fh constant_types(); # macro defs
  print $c_fh "\n";

  # indent is still undef. Until anyone implements indent style rules with it.
  foreach (C_constant ($ARGS{NAME}, $ARGS{C_SUBNAME}, $ARGS{DEFAULT_TYPE},
                       $types, undef, $ARGS{BREAKOUT_AT}, @{$ARGS{NAMES}})) {
    print $c_fh $_, "\n"; # C constant subs
  }
  print $xs_fh XS_constant ($ARGS{NAME}, $types, $ARGS{XS_SUBNAME},
                            $ARGS{C_SUBNAME});

  close $c_fh or warn "Error closing $ARGS{C_FILE}: $!";
  close $xs_fh or warn "Error closing $ARGS{XS_FILE}: $!";
}

package ExtUtils::Constant::Aaargh56Hash;
# A support module (hack) to provide sane Unicode hash keys on 5.6.x perl
use strict;
require Tie::Hash if $ExtUtils::Constant::is_perl56;
use vars '@ISA';
@ISA = 'Tie::StdHash';

#my $a;
# Storing the values as concatenated BER encoded numbers is actually going to
# be terser than using UTF8 :-)
# And the tests are slightly faster. Ops are bad, m'kay
sub to_key {pack "w*", unpack "U*", ($_[0] . pack "U*")};
sub from_key {defined $_[0] ? pack "U*", unpack 'w*', $_[0] : undef};

sub STORE    { $_[0]->{to_key($_[1])} = $_[2] }
sub FETCH    { $_[0]->{to_key($_[1])} }
sub FIRSTKEY { my $a = scalar keys %{$_[0]}; from_key (each %{$_[0]}) }
sub NEXTKEY  { from_key (each %{$_[0]}) }
sub EXISTS   { exists $_[0]->{to_key($_[1])} }
sub DELETE   { delete $_[0]->{to_key($_[1])} }

#END {warn "$a accesses";}
1;
__END__

