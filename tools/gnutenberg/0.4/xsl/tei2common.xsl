<?xml version="1.0" encoding="iso-8859-1" ?>

<!--

The Gnutenberg Press - stylesheet for common templates
Copyright (C) 2003-2005  Marcello Perathoner

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.


Numbers in comments refer to chapters in:
TEI Lite: An Introduction to Text Encoding for Interchange
Lou Burnard C. M. Sperberg-McQueen
June 1995, revised May 2002 

-->

<stylesheet xmlns="http://www.w3.org/1999/XSL/Transform"
            xmlns:pg="http://www.gutenberg.org/tei/marcello/0.4/xslt"
            xmlns:svg="http://www.w3.org/2000/svg"
            xmlns:func="http://exslt.org/functions"
            extension-element-prefixes="func"
            exclude-result-prefixes="pg svg"
            version="1.0">

  <func:function name="pg:get-nesting-level">
    <param name="context" select="." />
    <func:result select="count(ancestor-or-self::*[child::head])" />
  </func:function>

  <template match="*">
    <!-- default handling of all element nodes -->
    <call-template name="default-all" />
  </template>

  <!-- 3. The Structure of a TEI Text -->

  <template match="teiHeader" />

  <!-- 4. Encoding the Body -->

  <!-- 4.1. Text Division Elements -->

  <func:function name="pg:indent-p">
    <!-- returns 1 if we should indent first line -->
    <variable name="prec" select="concat ('-', local-name (preceding-sibling::*[position()=1]), '-')" />
    <choose>
      <!-- alway indent in french publications -->
      <when test="/TEI.2/@lang='fr'">
        <func:result select="1"/>
      </when>
      <!-- I'm the first para in div -->
      <when test="not (preceding-sibling::p)">
        <func:result select="0"/>
      </when>
      <!-- there is one of these before me
      <when test="contains('-p-pb-opener-note-', $prec)">
        <func:result select="1"/>
      </when>
      -->
      <otherwise>
        <func:result select="1"/>
      </otherwise>
    </choose>
  </func:function>

  <!-- 4.2. Headings and Closings -->

  <template match="div/head|body/head">
    <variable name="level" select="pg:get-nesting-level (.)" />

    <value-of select="pg:set-class (., 'x-head')" />
    <value-of select="pg:set-class (., concat ('x-head', $level))" />
    <call-template name="default-all" />
  </template>

  <template match="div/head[@type='sub']|body/head[@type='sub']">
    <variable name="level" select="pg:get-nesting-level (.)" />

    <value-of select="pg:set-class (., 'x-subhead')" />
    <value-of select="pg:set-class (., concat ('x-subhead', $level))" />

    <call-template name="default-all" />
  </template>

  <!-- table/head list/head figure/head -->

  <template match="head">

    <value-of select="pg:set-class (., concat ('x-', local-name (..), '-head'))" />

    <call-template name="default-all" />
  </template>

  <!-- 4.3. Prose, Verse and Drama -->

  <!-- 5. Page and Line Numbers -->

  <!-- line break -->
  <!-- status: experimental -->
  <!-- fixme: this is semantically different:
       should just record a line break in a certain edition, not produce one
       but there ain't a tag in TEI for a forced line break
       that is not a poetry line, so I collared this one. -->

  <template match="lb">
    <call-template name="line-break"/>
  </template>

  <template match="lb[@ed]">
  </template>

  <template match="milestone" />

  <!-- 6. Marking Highlighted Phrases -->

  <!-- 6.1. Changes of Typeface, etc. -->

  <!-- 6.2. Quotations and Related Features -->

  <!-- scare quotes -->
  <template match="soCalled">
    <value-of select="pg:set-prop (., 'x-pre',  '&#x2018;')"/>
    <value-of select="pg:set-prop (., 'x-post', '&#x2019;')"/>

    <call-template name="default-all" />
  </template>

  <!-- 6.3. Foreign Words or Expressions -->

  <!-- 7. Notes -->

  <!-- 8. Cross-References and Links -->

  <!-- 8.1. Simple Cross References -->

  <!-- 8.2. Extended Pointers -->

  <!-- 9. Editorial interventions -->

  <!-- 10. Omissions, Deletions, and Additions -->

  <template match="gap">
    <text>[]</text>
  </template>

  <template match="del" />

  <!-- 11. Names, Dates, Numbers and Abbreviations -->

  <!-- 11.1. Names and Referring Strings -->

  <!-- name of a ship default rends as italic -->
  <template match="name[@type='ship']|rs[@type='ship']">
    <value-of select="pg:set-prop (., 'x-default-italic', 1)"/>
    <call-template name="default-all" />
  </template>
  
  <!-- 11.2. Dates and Times -->

  <!-- 11.3. Numbers -->

  <!-- 11.4. Abbreviations and their Expansion -->

  <!-- 11.5. Addresses -->

  <template match="addrLine">
    <call-template name="default-all" />
    <call-template name="line-break" />
  </template>

  <!-- 12. Lists -->

  <!-- 13. Bibliographic Citations -->

  <!-- 14. Tables -->

  <!-- 15. Figures and Graphics -->

  <template match="svg:svg" />

  <!-- 16. Interpretation and Analysis -->

  <!-- 16.1. Orthographic Sentences -->

  <!-- 16.2. General-Purpose Interpretation Elements -->

  <template match="interp|interpGrp" />

  <!-- 17. Technical Documentation -->

  <!-- 17.1. Additional Elements for Technical Documents -->
  <!-- note: these follow the TEI-Lite specs which differ somehow
       from the TEI specs for these elements -->

  <!-- 17.1. Additional Elements for Technical Documents -->

  <template match="formula">
    <!-- default 
         backends that do support formula should override this -->
    <text>[formula]</text>
  </template>

  <template match="tag|gi">
    <value-of select="pg:set-prop (., 'x-pre',  '&lt;')"/>
    <value-of select="pg:set-prop (., 'x-post', '&gt;')"/>

    <call-template name="default-all" />
  </template>

  <template match="entName">
    <value-of select="pg:set-prop (., 'x-pre',  '&#xf8f0;')"/>
    <value-of select="pg:set-prop (., 'x-post', ';')"/>

    <call-template name="default-all" />
  </template>

  <!-- 17.2. Generated Divisions -->

  <template match="divGen" priority="-2" />

  <template match="divGen[@type='endnotes']" priority="2">
    <choose>
      <when test="@target">
        <apply-templates select="//*[@id=current()/@target]//note[@place='end']" 
                         mode="footnotes" />
      </when>
      <otherwise>
        <apply-templates select="/TEI.2/text//note[@place='end']" 
                         mode="footnotes" />
      </otherwise>
    </choose>
  </template>

  <!-- 17.3. Index Generation -->

  <template match="index[@index]">
    <variable name="dummy" select="pg:disinherit (.)" />

    <variable name="cnt">
      <number from="/TEI.2/text" count="index[@index=current()/@index]" level="any" />
    </variable>
    <variable name="level" select="pg:get-nesting-level (.)" />
    <call-template name="mk_toc_anchor">
      <with-param name="index" select="@index"/>
      <with-param name="n" select="concat (@index, $cnt)" />
      <with-param name="level" select="$level" />
      <with-param name="text">
	<apply-templates/>
      </with-param>
    </call-template>
  </template>

  <template match="index[@index]" mode="toc">
    <variable name="dummy" select="pg:disinherit (.)" />

    <variable name="cnt">
      <number from="/TEI.2/text" count="index[@index=current()/@index]" level="any" />
    </variable>
    <variable name="level" select="pg:get-nesting-level (.)" />
    <call-template name="mk_toc_line">
      <with-param name="index" select="@index"/>
      <with-param name="n" select="concat (@index, $cnt)" />
      <with-param name="level" select="$level" />
      <with-param name="text">
	<apply-templates/>
      </with-param>
    </call-template>
  </template>

  <template match="text()|@*" mode="toc">
  </template>

  <template name="mk_toc_line">
    <!-- to override -->
  </template>

  <template name="mk_toc_anchor">
    <!-- to override -->
  </template>

  <!-- 18. Character Sets, Diacritics, etc. -->
  
  <!-- 19. Front and Back Matter -->

  <!-- 19.1. Front Matter -->

  <!-- 19.1.1. Title Page -->

  <!-- 19.1.2. Prefatory Matter -->

  <!-- 19.2. Back Matter -->

  <!-- 19.2.1. Structural Divisions of Back Matter -->

  <!-- 20. The Electronic Title Page -->

  <!-- PG Extensions -->

  <template match="pgExtensions">
    <apply-templates />
  </template>

  <template match="pgStyleSheet" />

  <template match="pgExcludeFormats" />

  <template match="pgHyphenationExceptions" />

  <template match="pgCharMap" />

  <template match="pgVar|pgIf|then|else">
    <!-- handled in transfom.pl -->
    <apply-templates />
  </template>

  <template match="processing-instruction()">
    <!-- native backend code escape -->
    <if test="pg:get-output-format () = local-name (.)">
      <value-of select="." />
    </if>
  </template>


  <!-- INTERNALS -->

  <!-- default-all provides default rendering for all elements.
       if you need more control use default-preamble and default-postamble
       (always in pairs) or write your own handler altogether -->

  <template name="default-all">
    <call-template name="default-preamble" />
    <apply-templates />
    <call-template name="default-postamble" />
  </template>

  <template match="index//note" priority="10">
    <!-- don't display note ref in toc -->
  </template>

</stylesheet>

<!-- Local Variables: -->
<!-- mode:nxml -->
<!-- coding:latin-iso8859-1-unix -->
<!-- fill-column: 120 -->
<!-- End: -->

