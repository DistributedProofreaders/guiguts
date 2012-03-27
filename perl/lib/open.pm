package open;
use warnings;
use Carp;
$open::hint_bits = 0x20000; # HINT_LOCALIZE_HH

our $VERSION = '1.02';

my $locale_encoding;

sub in_locale { $^H & ($locale::hint_bits || 0)}

sub _get_locale_encoding {
    unless (defined $locale_encoding) {
	# I18N::Langinfo isn't available everywhere
	eval {
	    require I18N::Langinfo;
	    I18N::Langinfo->import(qw(langinfo CODESET));
	    $locale_encoding = langinfo(CODESET());
	};
	my $country_language;

	no warnings 'uninitialized';

        if (not $locale_encoding && in_locale()) {
	    if ($ENV{LC_ALL} =~ /^([^.]+)\.([^.]+)$/) {
		($country_language, $locale_encoding) = ($1, $2);
	    } elsif ($ENV{LANG} =~ /^([^.]+)\.([^.]+)$/) {
		($country_language, $locale_encoding) = ($1, $2);
	    }
	    # LANGUAGE affects only LC_MESSAGES only on glibc
	} elsif (not $locale_encoding) {
	    if ($ENV{LC_ALL} =~ /\butf-?8\b/i ||
		$ENV{LANG}   =~ /\butf-?8\b/i) {
		$locale_encoding = 'utf8';
	    }
	    # Could do more heuristics based on the country and language
	    # parts of LC_ALL and LANG (the parts before the dot (if any)),
	    # since we have Locale::Country and Locale::Language available.
	    # TODO: get a database of Language -> Encoding mappings
	    # (the Estonian database at http://www.eki.ee/letter/
	    # would be excellent!) --jhi
	}
	if (defined $locale_encoding &&
	    $locale_encoding eq 'euc' &&
	    defined $country_language) {
	    if ($country_language =~ /^ja_JP|japan(?:ese)?$/i) {
		$locale_encoding = 'euc-jp';
	    } elsif ($country_language =~ /^ko_KR|korean?$/i) {
		$locale_encoding = 'euc-kr';
	    } elsif ($country_language =~ /^zh_CN|chin(?:a|ese)?$/i) {
		$locale_encoding = 'euc-cn';
	    } elsif ($country_language =~ /^zh_TW|taiwan(?:ese)?$/i) {
		$locale_encoding = 'euc-tw';
	    }
	    croak "Locale encoding 'euc' too ambiguous"
		if $locale_encoding eq 'euc';
	}
    }
}

sub import {
    my ($class,@args) = @_;
    croak("`use open' needs explicit list of PerlIO layers") unless @args;
    my $std;
    $^H |= $open::hint_bits;
    my ($in,$out) = split(/\0/,(${^OPEN} || "\0"), -1);
    while (@args) {
	my $type = shift(@args);
	my $dscp;
	if ($type =~ /^:?(utf8|locale|encoding\(.+\))$/) {
	    $type = 'IO';
	    $dscp = ":$1";
	} elsif ($type eq ':std') {
	    $std = 1;
	    next;
	} else {
	    $dscp = shift(@args) || '';
	}
	my @val;
	foreach my $layer (split(/\s+/,$dscp)) {
            $layer =~ s/^://;
	    if ($layer eq 'locale') {
		require Encode;
		_get_locale_encoding()
		    unless defined $locale_encoding;
		(warnings::warnif("layer", "Cannot figure out an encoding to use"), last)
		    unless defined $locale_encoding;
		if ($locale_encoding =~ /^utf-?8$/i) {
		    $layer = "utf8";
		} else {
		    $layer = "encoding($locale_encoding)";
		}
		$std = 1;
	    } else {
		my $target = $layer;		# the layer name itself
		$target =~ s/^(\w+)\(.+\)$/$1/;	# strip parameters

		unless(PerlIO::Layer::->find($target,1)) {
		    warnings::warnif("layer", "Unknown PerlIO layer '$target'");
		}
	    }
	    push(@val,":$layer");
	    if ($layer =~ /^(crlf|raw)$/) {
		$^H{"open_$type"} = $layer;
	    }
	}
	if ($type eq 'IN') {
	    $in  = join(' ',@val);
	}
	elsif ($type eq 'OUT') {
	    $out = join(' ',@val);
	}
	elsif ($type eq 'IO') {
	    $in = $out = join(' ',@val);
	}
	else {
	    croak "Unknown PerlIO layer class '$type'";
	}
    }
    ${^OPEN} = join("\0",$in,$out) if $in or $out;
    if ($std) {
	if ($in) {
	    if ($in =~ /:utf8\b/) {
		    binmode(STDIN,  ":utf8");
		} elsif ($in =~ /(\w+\(.+\))/) {
		    binmode(STDIN,  ":$1");
		}
	}
	if ($out) {
	    if ($out =~ /:utf8\b/) {
		binmode(STDOUT,  ":utf8");
		binmode(STDERR,  ":utf8");
	    } elsif ($out =~ /(\w+\(.+\))/) {
		binmode(STDOUT,  ":$1");
		binmode(STDERR,  ":$1");
	    }
	}
    }
}

1;
__END__

