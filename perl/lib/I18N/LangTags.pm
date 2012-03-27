
# Time-stamp: "2003-10-10 17:43:04 ADT"
# Sean M. Burke <sburke@cpan.org>

require 5.000;
package I18N::LangTags;
use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK %EXPORT_TAGS $VERSION %Panic);
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw();
@EXPORT_OK = qw(is_language_tag same_language_tag
                extract_language_tags super_languages
                similarity_language_tag is_dialect_of
                locale2language_tag alternate_language_tags
                encode_language_tag panic_languages
               );
%EXPORT_TAGS = ('ALL' => \@EXPORT_OK);

$VERSION = "0.29";

###########################################################################

sub is_language_tag {

  ## Changes in the language tagging standards may have to be reflected here.

  my($tag) = lc($_[0]);

  return 0 if $tag eq "i" or $tag eq "x";
  # Bad degenerate cases that the following
  #  regexp would erroneously let pass

  return $tag =~ 
    /^(?:  # First subtag
         [xi] | [a-z]{2,3}
      )
      (?:  # Subtags thereafter
         -           # separator
         [a-z0-9]{1,8}  # subtag  
      )*
    $/xs ? 1 : 0;
}

###########################################################################

sub extract_language_tags {

  ## Changes in the language tagging standards may have to be reflected here.

  my($text) =
    $_[0] =~ m/(.+)/  # to make for an untainted result
    ? $1 : ''
  ;
  
  return grep(!m/^[ixIX]$/s, # 'i' and 'x' aren't good tags
    $text =~ 
    m/
      \b
      (?:  # First subtag
         [iIxX] | [a-zA-Z]{2,3}
      )
      (?:  # Subtags thereafter
         -           # separator
         [a-zA-Z0-9]{1,8}  # subtag  
      )*
      \b
    /xsg
  );
}

###########################################################################

sub same_language_tag {
  my $el1 = &encode_language_tag($_[0]);
  return 0 unless defined $el1;
   # this avoids the problem of
   # encode_language_tag($lang1) eq and encode_language_tag($lang2)
   # being true if $lang1 and $lang2 are both undef

  return $el1 eq &encode_language_tag($_[1]) ? 1 : 0;
}

###########################################################################

sub similarity_language_tag {
  my $lang1 = &encode_language_tag($_[0]);
  my $lang2 = &encode_language_tag($_[1]);
   # And encode_language_tag takes care of the whole
   #  no-nyn==nn, i-hakka==zh-hakka, etc, things
   
  # NB: (i-sil-...)?  (i-sgn-...)?

  return undef if !defined($lang1) and !defined($lang2);
  return 0 if !defined($lang1) or !defined($lang2);

  my @l1_subtags = split('-', $lang1);
  my @l2_subtags = split('-', $lang2);
  my $similarity = 0;

  while(@l1_subtags and @l2_subtags) {
    if(shift(@l1_subtags) eq shift(@l2_subtags)) {
      ++$similarity;
    } else {
      last;
    } 
  }
  return $similarity;
}

###########################################################################

sub is_dialect_of {

  my $lang1 = &encode_language_tag($_[0]);
  my $lang2 = &encode_language_tag($_[1]);

  return undef if !defined($lang1) and !defined($lang2);
  return 0 if !defined($lang1) or !defined($lang2);

  return 1 if $lang1 eq $lang2;
  return 0 if length($lang1) < length($lang2);

  $lang1 .= '-';
  $lang2 .= '-';
  return
    (substr($lang1, 0, length($lang2)) eq $lang2) ? 1 : 0;
}

###########################################################################

sub super_languages {
  my $lang1 = $_[0];
  return() unless defined($lang1) && &is_language_tag($lang1);

  # a hack for those annoying new (2001) tags:
  $lang1 =~ s/^nb\b/no-bok/i; # yes, backwards
  $lang1 =~ s/^nn\b/no-nyn/i; # yes, backwards
  $lang1 =~ s/^[ix](-hakka\b)/zh$1/i; # goes the right way
   # i-hakka-bork-bjork-bjark => zh-hakka-bork-bjork-bjark

  my @l1_subtags = split('-', $lang1);

  ## Changes in the language tagging standards may have to be reflected here.

  # NB: (i-sil-...)?

  my @supers = ();
  foreach my $bit (@l1_subtags) {
    push @supers, 
      scalar(@supers) ? ($supers[-1] . '-' . $bit) : $bit;
  }
  pop @supers if @supers;
  shift @supers if @supers && $supers[0] =~ m<^[iIxX]$>s;
  return reverse @supers;
}

###########################################################################

sub locale2language_tag {
  my $lang =
    $_[0] =~ m/(.+)/  # to make for an untainted result
    ? $1 : ''
  ;

  return $lang if &is_language_tag($lang); # like "en"

  $lang =~ tr<_><->;  # "en_US" -> en-US
  $lang =~ s<\.[-_a-zA-Z0-9\.]*><>s;  # "en_US.ISO8859-1" -> en-US

  return $lang if &is_language_tag($lang);

  return;
}

###########################################################################

sub encode_language_tag {
  # Only similarity_language_tag() is allowed to analyse encodings!

  ## Changes in the language tagging standards may have to be reflected here.

  my($tag) = $_[0] || return undef;
  return undef unless &is_language_tag($tag);

  # For the moment, these legacy variances are few enough that
  #  we can just handle them here with regexps.
  $tag =~ s/^iw\b/he/i; # Hebrew
  $tag =~ s/^in\b/id/i; # Indonesian
  $tag =~ s/^cre\b/cr/i; # Cree
  $tag =~ s/^jw\b/jv/i; # Javanese
  $tag =~ s/^[ix]-lux\b/lb/i;  # Luxemburger
  $tag =~ s/^[ix]-navajo\b/nv/i;  # Navajo
  $tag =~ s/^ji\b/yi/i;  # Yiddish
  # SMB 2003 -- Hm.  There's a bunch of new XXX->YY variances now,
  #  but maybe they're all so obscure I can ignore them.   "Obscure"
  #  meaning either that the language is obscure, and/or that the
  #  XXX form was extant so briefly that it's unlikely it was ever
  #  used.  I hope.
  #
  # These go FROM the simplex to complex form, to get
  #  similarity-comparison right.  And that's okay, since
  #  similarity_language_tag is the only thing that
  #  analyzes our output.
  $tag =~ s/^[ix]-hakka\b/zh-hakka/i;  # Hakka
  $tag =~ s/^nb\b/no-bok/i;  # BACKWARDS for Bokmal
  $tag =~ s/^nn\b/no-nyn/i;  # BACKWARDS for Nynorsk

  $tag =~ s/^[xiXI]-//s;
   # Just lop off any leading "x/i-"

  return "~" . uc($tag);
}

#--------------------------------------------------------------------------

my %alt = qw( i x   x i   I X   X I );
sub alternate_language_tags {
  my $tag = $_[0];
  return() unless &is_language_tag($tag);

  my @em; # push 'em real goood!

  # For the moment, these legacy variances are few enough that
  #  we can just handle them here with regexps.
  
  if(     $tag =~ m/^[ix]-hakka\b(.*)/i) {push @em, "zh-hakka$1";
  } elsif($tag =~ m/^zh-hakka\b(.*)/i) {  push @em, "x-hakka$1", "i-hakka$1";

  } elsif($tag =~ m/^he\b(.*)/i) { push @em, "iw$1";
  } elsif($tag =~ m/^iw\b(.*)/i) { push @em, "he$1";

  } elsif($tag =~ m/^in\b(.*)/i) { push @em, "id$1";
  } elsif($tag =~ m/^id\b(.*)/i) { push @em, "in$1";

  } elsif($tag =~ m/^[ix]-lux\b(.*)/i) { push @em, "lb$1";
  } elsif($tag =~ m/^lb\b(.*)/i) {       push @em, "i-lux$1", "x-lux$1";

  } elsif($tag =~ m/^[ix]-navajo\b(.*)/i) { push @em, "nv$1";
  } elsif($tag =~ m/^nv\b(.*)/i) {          push @em, "i-navajo$1", "x-navajo$1";

  } elsif($tag =~ m/^yi\b(.*)/i) { push @em, "ji$1";
  } elsif($tag =~ m/^ji\b(.*)/i) { push @em, "yi$1";

  } elsif($tag =~ m/^nb\b(.*)/i) {     push @em, "no-bok$1";
  } elsif($tag =~ m/^no-bok\b(.*)/i) { push @em, "nb$1";
  
  } elsif($tag =~ m/^nn\b(.*)/i) {     push @em, "no-nyn$1";
  } elsif($tag =~ m/^no-nyn\b(.*)/i) { push @em, "nn$1";
  }

  push @em, $alt{$1} . $2 if $tag =~ /^([XIxi])(-.+)/;
  return @em;
}

###########################################################################

{
  # Init %Panic...
  
  my @panic = (  # MUST all be lowercase!
   # Only large ("national") languages make it in this list.
   #  If you, as a user, are so bizarre that the /only/ language
   #  you claim to accept is Galician, then no, we won't do you
   #  the favor of providing Catalan as a panic-fallback for
   #  you.  Because if I start trying to add "little languages" in
   #  here, I'll just go crazy.

   # Scandinavian lgs.  All based on opinion and hearsay.
   'sv' => [qw(nb no da nn)],
   'da' => [qw(nb no sv nn)], # I guess
   [qw(no nn nb)], [qw(no nn nb sv da)],
   'is' => [qw(da sv no nb nn)],
   'fo' => [qw(da is no nb nn sv)], # I guess
   
   # I think this is about the extent of tolerable intelligibility
   #  among large modern Romance languages.
   'pt' => [qw(es ca it fr)], # Portuguese, Spanish, Catalan, Italian, French
   'ca' => [qw(es pt it fr)],
   'es' => [qw(ca it fr pt)],
   'it' => [qw(es fr ca pt)],
   'fr' => [qw(es it ca pt)],
   
   # Also assume that speakers of the main Indian languages prefer
   #  to read/hear Hindi over English
   [qw(
     as bn gu kn ks kok ml mni mr ne or pa sa sd te ta ur
   )] => 'hi',
    # Assamese, Bengali, Gujarati, [Hindi,] Kannada (Kanarese), Kashmiri,
    # Konkani, Malayalam, Meithei (Manipuri), Marathi, Nepali, Oriya,
    # Punjabi, Sanskrit, Sindhi, Telugu, Tamil, and Urdu.
   'hi' => [qw(bn pa as or)],
   # I welcome finer data for the other Indian languages.
   #  E.g., what should Oriya's list be, besides just Hindi?
   
   # And the panic languages for English is, of course, nil!

   # My guesses at Slavic intelligibility:
   ([qw(ru be uk)]) x 2,  # Russian, Belarusian, Ukranian
   'sr' => 'hr', 'hr' => 'sr', # Serb + Croat
   'cs' => 'sk', 'sk' => 'cs', # Czech + Slovak

   'ms' => 'id', 'id' => 'ms', # Malay + Indonesian

   'et' => 'fi', 'fi' => 'et', # Estonian + Finnish

   #?? 'lo' => 'th', 'th' => 'lo', # Lao + Thai

  );
  my($k,$v);
  while(@panic) {
    ($k,$v) = splice(@panic,0,2);
    foreach my $k (ref($k) ? @$k : $k) {
      foreach my $v (ref($v) ? @$v : $v) {
        push @{$Panic{$k} ||= []}, $v unless $k eq $v;
      }
    }
  }
}

sub panic_languages {
  # When in panic or in doubt, run in circles, scream, and shout!
  my(@out, %seen);
  foreach my $t (@_) {
    next unless $t;
    next if $seen{$t}++; # so we don't return it or hit it again
    # push @out, super_languages($t); # nah, keep that separate
    push @out, @{ $Panic{lc $t} || next };
  }
  return grep !$seen{$_}++,  @out, 'en';
}

###########################################################################
1;
__END__

