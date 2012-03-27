
require 5;
package HTML::Tagset;   # Time-stamp: "2000-10-20 19:35:06 MDT"
use strict;
use vars qw(
 $VERSION
 %emptyElement %optionalEndTag %linkElements %boolean_attr
 %isHeadElement %isBodyElement %isPhraseMarkup
 %is_Possible_Strict_P_Content
 %isHeadOrBodyElement
 %isList %isTableElement %isFormElement
 %isKnown %canTighten
 @p_closure_barriers
 %isCDATA_Parent
);

$VERSION = '3.03';

#==========================================================================

%emptyElement   = map {; $_ => 1 } qw(base link meta isindex
                                     img br hr wbr
                                     input area param
                                     embed bgsound spacer
                                     basefont col frame
                                     ~comment ~literal
                                     ~declaration ~pi
                                    );
 # The "~"-initial names are for pseudo-elements used by HTML::Entities
 #  and TreeBuilder

#---------------------------------------------------------------------------

%optionalEndTag = map {; $_ => 1 } qw(p li dt dd); # option th tr td);

#---------------------------------------------------------------------------

%linkElements =
(
 'a'       => ['href'],
 'applet'  => ['archive', 'codebase', 'code'],
 'area'    => ['href'],
 'base'    => ['href'],
 'bgsound' => ['src'],
 'blockquote' => ['cite'],
 'body'    => ['background'],
 'del'     => ['cite'],
 'embed'   => ['pluginspage', 'src'],
 'form'    => ['action'],
 'frame'   => ['src', 'longdesc'],
 'iframe'  => ['src', 'longdesc'],
 'ilayer'  => ['background'],
 'img'     => ['src', 'lowsrc', 'longdesc', 'usemap'],
 'input'   => ['src', 'usemap'],
 'ins'     => ['cite'],
 'isindex' => ['action'],
 'head'    => ['profile'],
 'layer'   => ['background', 'src'],
 'link'    => ['href'],
 'object'  => ['classid', 'codebase', 'data', 'archive', 'usemap'],
 'q'       => ['cite'],
 'script'  => ['src', 'for'],
 'table'   => ['background'],
 'td'      => ['background'],
 'th'      => ['background'],
 'tr'      => ['background'],
 'xmp'     => ['href'],
);

#---------------------------------------------------------------------------

%boolean_attr = (
# TODO: make these all hashes
  'area'   => 'nohref',
  'dir'    => 'compact',
  'dl'     => 'compact',
  'hr'     => 'noshade',
  'img'    => 'ismap',
  'input'  => { 'checked' => 1, 'readonly' => 1, 'disabled' => 1 },
  'menu'   => 'compact',
  'ol'     => 'compact',
  'option' => 'selected',
  'select' => 'multiple',
  'td'     => 'nowrap',
  'th'     => 'nowrap',
  'ul'     => 'compact',
);

#==========================================================================
# List of all elements from Extensible HTML version 1.0 Transitional DTD:
#
#   a abbr acronym address applet area b base basefont bdo big
#   blockquote body br button caption center cite code col colgroup
#   dd del dfn dir div dl dt em fieldset font form h1 h2 h3 h4 h5 h6
#   head hr html i iframe img input ins isindex kbd label legend li
#   link map menu meta noframes noscript object ol optgroup option p
#   param pre q s samp script select small span strike strong style
#   sub sup table tbody td textarea tfoot th thead title tr tt u ul
#   var
#
# Varia from Mozilla source internal table of tags:
#   Implemented:
#     xmp listing wbr nobr frame frameset noframes ilayer
#     layer nolayer spacer embed multicol
#   But these are unimplemented:
#     sound??  keygen??  server??
# Also seen here and there:
#     marquee??  app??  (both unimplemented)
#==========================================================================

%isPhraseMarkup = map {; $_ => 1 } qw(
  span abbr acronym q sub sup
  cite code em kbd samp strong var dfn strike
  b i u s tt small big 
  a img br
  wbr nobr blink
  font basefont bdo
  spacer embed noembed
);  # had: center, hr, table


%is_Possible_Strict_P_Content = (
 %isPhraseMarkup,
 %isFormElement,
 map {; $_ => 1} qw( object script map )
  # I've no idea why there's these latter exceptions.
  # I'm just following the HTML4.01 DTD.
);

#from html4 strict:
#<!ENTITY % fontstyle "TT | I | B | BIG | SMALL">
#
#<!ENTITY % phrase "EM | STRONG | DFN | CODE |
#                   SAMP | KBD | VAR | CITE | ABBR | ACRONYM" >
#
#<!ENTITY % special
#   "A | IMG | OBJECT | BR | SCRIPT | MAP | Q | SUB | SUP | SPAN | BDO">
#
#<!ENTITY % formctrl "INPUT | SELECT | TEXTAREA | LABEL | BUTTON">
#
#<!-- %inline; covers inline or "text-level" elements -->
#<!ENTITY % inline "#PCDATA | %fontstyle; | %phrase; | %special; | %formctrl;">

%isHeadElement = map {; $_ => 1 }
 qw(title base link meta isindex script style object bgsound);

%isList         = map {; $_ => 1 } qw(ul ol dir menu);

%isTableElement = map {; $_ => 1 }
 qw(tr td th thead tbody tfoot caption col colgroup);

%isFormElement  = map {; $_ => 1 }
 qw(input select option optgroup textarea button label);

%isBodyElement = map {; $_ => 1 } qw(
  h1 h2 h3 h4 h5 h6
  p div pre plaintext address blockquote
  xmp listing
  center

  multicol
  iframe ilayer nolayer
  bgsound

  hr
  ol ul dir menu li
  dl dt dd
  ins del
  
  fieldset legend
  
  map area
  applet param object
  isindex script noscript
  table
  center
  form
 ),
 keys %isFormElement,
 keys %isPhraseMarkup,   # And everything phrasal
 keys %isTableElement,
;


%isHeadOrBodyElement = map {; $_ => 1 }
  qw(script isindex style object map area param noscript bgsound);
  # i.e., if we find 'script' in the 'body' or the 'head', don't freak out.


%isKnown = (%isHeadElement, %isBodyElement,
  map{; $_=>1 }
   qw( head body html
       frame frameset noframes
       ~comment ~pi ~directive ~literal
));
 # that should be all known tags ever ever


%canTighten = %isKnown;
delete @canTighten{
  keys(%isPhraseMarkup), 'input', 'select',
  'xmp', 'listing', 'plaintext', 'pre',
};
  # xmp, listing, plaintext, and pre  are untightenable, and
  #   in a really special way.
@canTighten{'hr','br'} = (1,1);
 # exceptional 'phrasal' things that ARE subject to tightening.

# The one case where I can think of my tightening rules failing is:
#  <p>foo bar<center> <em>baz quux</em> ...
#                    ^-- that would get deleted.
# But that's pretty gruesome code anyhow.  You gets what you pays for.

#==========================================================================

@p_closure_barriers = qw(
  li blockquote
  ul ol menu dir
  dl dt dd
  td th tr table caption
 );

# In an ideal world (i.e., XHTML) we wouldn't have to bother with any of this
# monkey business of barriers to minimization!

###########################################################################

%isCDATA_Parent = map {; $_ => 1 }
  qw(script style  xmp listing plaintext);

# TODO: there's nothing else that takes CDATA children, right?

# As the HTML3 DTD (Raggett 1995-04-24) noted:
#   The XMP, LISTING and PLAINTEXT tags are incompatible with SGML
#   and derive from very early versions of HTML. They require non-
#   standard parsers and will cause problems for processing
#   documents with standard SGML tools.



###########################################################################

1;
