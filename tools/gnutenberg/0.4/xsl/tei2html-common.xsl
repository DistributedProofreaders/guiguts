<?xml version="1.0" encoding="iso-8859-1" ?>

<!--

The Gnutenberg Press - TEI-lite to HTML stylesheet
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

If you don't find the element here it is probably handled in tei2common.xsl.

-->
<!--            xmlns="http://www.w3.org/TR/REC-html40" -->

<xsl:stylesheet xmlns="http://www.w3.org/1999/xhtml" 
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:pg="http://www.gutenberg.org/tei/marcello/0.4/xslt"
                xmlns:svg="http://www.w3.org/2000/svg"
                exclude-result-prefixes="pg svg"
                version="1.0">

  <xsl:import  href="tei2common.xsl" />

  <xsl:variable name="hasfootnotes"  select="count (/TEI.2/text//note[@place='foot'])"/>

  <xsl:variable name="copyright_notice">
    <xsl:choose>
      <xsl:when test="pg:get-copyrighted () = 1">
        <xsl:text>This text is copyrighted. See inside for details.</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>This text is in the public domain.</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>


  <!-- All text nodes -->

  <xsl:template match="text()">
    <xsl:value-of select="pg:s2-textnode (., string (../@x-id))"/>
  </xsl:template>

  <!-- 3. The Structure of a TEI Text -->

  <xsl:template match="TEI.2">
    <html lang="{@lang}" xml:lang="{@lang}" xmlns="http://www.w3.org/1999/xhtml">
      <head>
        <!-- defines what our style="" attributes are -->
        <meta http-equiv="Content-Style-Type" content="text/css" />
        <link rel="schema.DC"      href="http://purl.org/dc/elements/1.1/" />
        <meta name="DC.Creator"    content="{pg:get-author (/TEI.2/teiHeader/fileDesc/titleStmt/author)}"   />
        <meta name="DC.Title"      content="{/TEI.2/teiHeader/fileDesc/titleStmt/title[1]}" />
        <meta name="DC.Date"       content="{/TEI.2/teiHeader/fileDesc/publicationStmt/date}" />
        <meta name="DC.Language"   content="{pg:id2lang (/TEI.2/@lang)}" />
        <meta name="DC.Publisher"  content="Project Gutenberg" />
        <meta name="DC.Identifier" content="http://www.gutenberg.org/etext/{pg:get-etext-no ()}" />
        <meta name="DC.Rights"     content="{$copyright_notice}" />

        <title><xsl:value-of select="pg:get-formatted-title ()"/></title>

<!--        <link href="persistent.css" rel="stylesheet" type="text/css" /> -->
        <style type="text/css">
          <xsl:value-of select="pg:get-css ()" />
        </style>
      </head>
      <body class="tei">
        <xsl:apply-templates />
      </body>
    </html>
  </xsl:template>

  <!-- 4. Encoding the Body -->

  <!-- 4.1. Text Division Elements -->

  <!-- 4.2. Headings and Closings -->

  <!-- 4.3. Prose, Verse and Drama -->

  <!-- 5. Page and Line Numbers -->

  <!-- FIXME: experimental -->
  <xsl:template match="pb[@n]">
    <span class="tei tei-pb" id="page{@n}">[pg <xsl:value-of select="@n" />]</span>
  </xsl:template>

  <xsl:template match="milestone[@unit='tb']">
    <xsl:variable name="r" select="pg:get-props (.)" />
    <xsl:choose>
      <xsl:when test="$r/properties[@stars]">
        <div class="tei tei-tb"><xsl:value-of select="pg:str-replicate('* ', $r/properties/@stars)"/></div>
      </xsl:when>
      <xsl:when test="$r/properties[@rule]">
        <div class="tei tei-tb"><hr style="width: {$r/properties/@rule}" /></div>
      </xsl:when>
      <xsl:otherwise>
        <div class="tei tei-tb">&#160;</div>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- 6. Marking Highlighted Phrases -->

  <!-- 6.1. Changes of Typeface, etc. -->

  <!-- 6.2. Quotations and Related Features -->

  <!-- 6.3. Foreign Words or Expressions -->

  <!-- 7. Notes -->

  <xsl:template match="/TEI.2/text//note">
  </xsl:template>

  <xsl:template match="/TEI.2/text//note" mode="footnotes">
    <xsl:variable name="dummy" select="pg:disinherit (.)" />
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="noteref">
    <a id="noteref_{.}" name="noteref_{.}" href="#note_{.}">
      <xsl:call-template name="default-all" />
    </a>
  </xsl:template>

  <xsl:template match="notelabel">
    <dt class="tei tei-notelabel">
      <a id="note_{.}" name="note_{.}" href="#noteref_{.}"><xsl:value-of select="." />.</a>
    </dt>
  </xsl:template>

  <xsl:template match="notetext">
    <xsl:call-template name="default-all" />
  </xsl:template>

  <!-- margin notes -->

  <xsl:template match="marginnote">
    <xsl:variable name="dummy" select="pg:disinherit (.)" />
    <div class="tei tei-marginnote tei-marginnote-{@place}">
      <xsl:apply-templates />
    </div>    
  </xsl:template>

  <xsl:template match="marginnoteref|marginnotelabel">
  </xsl:template>

  <!-- 8. Cross-References and Links -->

  <!-- 8.1. Simple Cross References -->

  <xsl:template match="ref">
    <a href="#{@target}">
      <xsl:call-template name="default-preamble" />
      <xsl:apply-templates/>
      <xsl:call-template name="default-postamble" />
    </a>
  </xsl:template>

  <xsl:template match="anchor|seg">
    <a name="{@id}">
      <xsl:call-template name="default-preamble" />
      <xsl:apply-templates/>
      <xsl:call-template name="default-postamble" />
    </a>
  </xsl:template>

  <!-- 8.2. Extended Pointers -->

  <xsl:template match="xref">
    <!-- see Guidelines 14.2.4 Representation of HTML links in TEI -->
    <xsl:choose>
      <xsl:when test="@url">
        <a href="{@url}">
          <xsl:call-template name="default-preamble" />
          <xsl:apply-templates/>
          <xsl:call-template name="default-postamble" />
        </a>
      </xsl:when>
      <xsl:otherwise>
        <a href="{unparsed-entity-uri(@doc)}">
          <xsl:call-template name="default-preamble" />
          <xsl:apply-templates/>
          <xsl:call-template name="default-postamble" />
        </a>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- 8.3. Linking Attributes -->

  <!-- 12. Lists -->

  <xsl:template match="list">
    <xsl:apply-templates select="index|anchor" />
    <table summary="This is a list.">
      <xsl:variable name="dummy" select="pg:set-prop (., 'x-class', 'tei-list')" />
      <xsl:call-template name="default-preamble" />
      <xsl:if test="head[not (contains(@type,'continued'))]">
        <thead>
          <xsl:apply-templates select="head[not (contains(@type,'continued'))]" />
        </thead>
      </xsl:if>
      <tbody>
        <xsl:apply-templates select="labelitem"/>
      </tbody>
    </table>
    <xsl:call-template name="default-postamble" />
  </xsl:template>

  <xsl:template match="list/head">
    <tr>
      <xsl:variable name="dummy"  select="pg:set-class (., 'x-list-head')" />
      <xsl:variable name="dummy1" select="pg:set-prop  (., 'x-colspan', '2')" />
      <xsl:call-template name="default-all" />
    </tr>      
  </xsl:template>

  <!-- simple -->
  <!-- bulleted -->
  <!-- ordered -->
  <!-- gloss -->

  <xsl:template match="list[@type='gloss']/labelitem">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="list[@type='gloss']/labelitem/label">
    <tr>
      <xsl:call-template name="default-all" />
    </tr>
  </xsl:template>

  <xsl:template match="list[@type='gloss']/labelitem/item">
    <tr>
      <xsl:call-template name="default-all"/>
    </tr>
  </xsl:template>

  <xsl:template match="list[@type='gloss']/labelitem/headLabel">
    <tr>
      <xsl:call-template name="default-all" />
    </tr>
  </xsl:template>

  <xsl:template match="list[@type='gloss']/labelitem/headItem">
    <tr>
      <xsl:call-template name="default-all" />
    </tr>
  </xsl:template>

  <!-- cast lists -->

  <xsl:template match="castGroup">
    <li class="tei tei-castgroup">
      <table summary="This is a cast group." class="tei tei-castgroup">
        <caption class="tei tei-castgroup-head">
          <span class="tei tei-roledesc">
            <xsl:apply-templates select="head" mode="braced" />
          </span>
        </caption>
        <tr>
          <td>
            <xsl:variable name="dummy" select="pg:set-prop (., 'x-element', 'ul')" />
            <xsl:variable name="dummy1" select="pg:set-prop (., 'x-class', 'tei-castgroup')" />
            <xsl:call-template name="default-all" />
          </td>
        </tr>
      </table>
    </li>
  </xsl:template>

  <xsl:template match="castGroup/head">
  </xsl:template>

  <xsl:template match="castGroup/head" mode="braced">
    <xsl:call-template name="inline" />
  </xsl:template>

  <!-- 14. Tables -->

  <xsl:template match="table">
    <xsl:apply-templates select="index|anchor" />
    <table summary="This is a table" cellspacing="0">
      <xsl:call-template name="default-preamble" />
      <colgroup span="{@cols}" />
      <xsl:if test="head[not (contains(@type,'continued'))]">
        <thead>
          <xsl:apply-templates select="head[not (contains(@type,'continued'))]" />
        </thead>
      </xsl:if>
      <tbody>
        <xsl:apply-templates select="row" />
      </tbody>
      <xsl:call-template name="default-postamble" />
    </table>
  </xsl:template>

  <xsl:template match="table/head">
    <tr>
      <xsl:variable name="dummy"  select="pg:set-class (., 'x-table-head')" />
      <xsl:variable name="dummy2" select="pg:set-prop  (., 'x-colspan', ../@cols)" />
      <xsl:call-template name="default-all" />
    </tr>      
  </xsl:template>

  <xsl:template match="cell">
    <!-- should select the first ancestor with a role -->
    <!-- this does not work well because of a bug in the TEI DTD -->
    <!-- the role attribute has a default value of "data" -->
    <xsl:variable name="role" select="ancestor-or-self::*[@role][1]/@role" />

    <xsl:if test="@cols and (@cols > 1)">
      <xsl:variable name="dummy"  select="pg:set-prop (., 'x-colspan', @cols)" />
    </xsl:if>
    <xsl:if test="@rows and (@rows > 1)">
      <xsl:variable name="dummy1" select="pg:set-prop (., 'x-rowspan', @rows)" />
    </xsl:if>
    <xsl:if test="$role='label'">
      <xsl:variable name="dummy2" select="pg:set-class (., 'x-cell-label')" />
    </xsl:if>

    <xsl:call-template name="default-all" />
  </xsl:template>

  <!-- 15. Figures and Graphics -->

  <xsl:template match="figure[@url]">
    <xsl:variable name="res" select="pg:copy-image (@url)"/>
    <xsl:apply-templates select="index|anchor" />
    <div>
      <!-- img is am empty tag! figure may be inline or block -->
      <xsl:call-template name="default-preamble" />
      <xsl:call-template name="default-postamble" />
      <img src="{$res/@url}">
        <xsl:if test="$res[@width]">
          <xsl:attribute name="width"><xsl:value-of select="$res/@width" /></xsl:attribute>
        </xsl:if>
        <xsl:if test="$res[@height]">
          <xsl:attribute name="height"><xsl:value-of select="$res/@height" /></xsl:attribute>
        </xsl:if>
        <xsl:if test="figDesc">
          <xsl:attribute name="alt"><xsl:value-of select="normalize-space (figDesc)" /></xsl:attribute>
        </xsl:if>
        <xsl:if test="head">
          <xsl:attribute name="title"><xsl:value-of select="normalize-space (head)" /></xsl:attribute>
        </xsl:if>
      </img>
      <xsl:apply-templates select="head|p" />
    </div>
  </xsl:template>

  <!-- 16. Interpretation and Analysis -->

  <!-- 16.1. Orthographic Sentences -->

  <!-- 16.2. General-Purpose Interpretation Elements -->

  <!-- 17. Technical Documentation -->

  <!-- 17.1. Additional Elements for Technical Documents -->

  <xsl:template match="formula[@notation='mathml']">
    <xsl:variable name="dummy" select="pg:set-prop (., 'x-class', 'tei-formula-mathml')" />
    <xsl:call-template name="default-all" />
  </xsl:template>

  <xsl:template match="formula[@notation='tex']">
    <xsl:variable name="res" select="pg:render-tex-formula (string (.))" />
    <xsl:choose>
      <xsl:when test="$res[@url]">
        <img src="{$res/@url}" alt="[formula]">
          <xsl:if test="$res[@width]">
            <xsl:attribute name="width"><xsl:value-of select="$res/@width"/></xsl:attribute>
          </xsl:if>
          <xsl:if test="$res[@height]">
            <xsl:attribute name="height"><xsl:value-of select="$res/@height"/></xsl:attribute>
          </xsl:if>
          <xsl:variable name="dummy" select="pg:set-prop (., 'x-class', 'tei-formula-tex')" />
          <xsl:call-template name="default-preamble" />
          <xsl:call-template name="default-postamble" />
        </img>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>[formula]</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="formula[@notation='svg']">
    <xsl:variable name="res" select="pg:render-svg (string (.))" />
    <xsl:choose>
      <xsl:when test="$res[@url]">
        <!-- <object data="{$res/@url}.svg" type="image/svg+xml"> -->
          <img src="{$res/@url}.png" alt="[figure]">
            <xsl:if test="$res[@width]">
              <xsl:attribute name="width"><xsl:value-of select="$res/@width"/></xsl:attribute>
            </xsl:if>
            <xsl:if test="$res[@height]">
              <xsl:attribute name="height"><xsl:value-of select="$res/@height"/></xsl:attribute>
            </xsl:if>
            <xsl:variable name="dummy" select="pg:set-prop (., 'x-class', 'tei-formula-svg')" />
            <xsl:call-template name="default-preamble" />
            <xsl:call-template name="default-postamble" />
          </img>
        <!-- </object> -->
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>[figure]</xsl:text>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- 17.2. Generated Divisions -->

  <xsl:template match="divGen[@type]" priority="1">
    <ul class="tei tei-index tei-index-{@type}">
      <xsl:apply-templates select="/TEI.2/text//index[@index=current()/@type]" mode="toc"/>
    </ul>
  </xsl:template>

   <xsl:template match="divGen[@type='toc']" priority="2">
    <ul class="tei tei-index tei-index-toc">
      <xsl:apply-templates select="/TEI.2/text//index[@index='toc']" mode="toc"/>
    </ul>
  </xsl:template>

  <xsl:template match="divGen[@type='footnotes']" priority="2">
    <xsl:if test="$hasfootnotes > 0">
      <dl class="tei tei-list-footnotes">
        <xsl:apply-templates select="/TEI.2/text//note[@place='foot']" mode="footnotes"/>
      </dl>
    </xsl:if>
  </xsl:template>

  <xsl:template match="divGen[@type='endnotes']" priority="2">
    <dl class="tei tei-list-footnotes">
      <xsl:choose>
        <xsl:when test="@target">
          <xsl:apply-templates select="//*[@id=current()/@target]//note[@place='end']" 
                               mode="footnotes" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates select="/TEI.2/text//note[@place='end']" mode="footnotes" />
        </xsl:otherwise>
      </xsl:choose>
    </dl>
  </xsl:template>

 <!-- 17.3. Index Generation -->

  <xsl:template name="mk_toc_anchor">
    <xsl:param name="n" />

    <a name="{$n}" />
  </xsl:template>

  <xsl:template name="mk_toc_line">
    <xsl:param name="index" />
    <xsl:param name="n" />
    <xsl:param name="level" />
    <xsl:param name="text" />

    <li>
      <xsl:if test="$index = 'toc' and $level > 1">
        <xsl:attribute name="style">
          <xsl:value-of select="concat ('margin-left: ', $level*2-2, 'em')" />
        </xsl:attribute>
      </xsl:if>

      <a href="#{$n}">  
	<xsl:value-of select="$text"/>
      </a>
    </li>
  </xsl:template>

  <!-- 18. Character Sets, Diacritics, etc. -->
  
  <!-- 19. Front and Back Matter -->

  <!-- 19.1. Front Matter -->

  <!-- 19.1.1. Title Page -->

  <!-- 19.1.2. Prefatory Matter -->

  <!-- 19.2. Back Matter -->

  <!-- 19.2.1. Structural Divisions of Back Matter -->

  <!-- 20. The Electronic Title Page -->

  <!-- see divGen[@type="titlepage"] -->

  <!-- INTERNALS -->

  <!-- Named Templates -->

  <xsl:template name="copy-lang-id">
    <!-- copy id and lang attributes from current node -->
    <xsl:for-each select="@*">
      <xsl:if test="(local-name () = 'lang') or (local-name () = 'id')">
	<xsl:copy/>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>

  <!-- block -->

  <xsl:template name="default-preamble">
    <xsl:call-template name="copy-lang-id"/>

    <xsl:variable name="x" select="pg:rend (.)"/>

    <xsl:for-each select="$x/attributes/@*">
      <xsl:attribute name="{local-name ()}">
        <xsl:value-of select="."/>
      </xsl:attribute>
    </xsl:for-each>

    <xsl:value-of select="$x/@pre"/>
  </xsl:template>

  <xsl:template name="default-postamble">
    <xsl:variable name="x" select="pg:rend (.)"/>
    <xsl:value-of select="$x/@post"/>
  </xsl:template>

  <xsl:template name="default-all">
    <xsl:variable name="page-break-before" select="pg:get-prop (., 'page-break-before')"/>
    <xsl:if test="$page-break-before = 'right'">
      <hr class="doublepage" />
    </xsl:if>
    <xsl:if test="$page-break-before = 'always'">
      <hr class="page" />
    </xsl:if>

    <xsl:variable name="x-element" select="pg:get-prop (., 'x-element') "/>

    <xsl:element name="{$x-element}">
      <xsl:call-template name="default-preamble" />
      <xsl:apply-templates />
      <xsl:call-template name="default-postamble" />
    </xsl:element>

  </xsl:template>

  <!-- line breaks -->

  <xsl:template name="line-break">
    <br/>
  </xsl:template>

</xsl:stylesheet>

<!-- Local Variables: -->
<!-- mode:nxml -->
<!-- coding:iso-8859-1-unix -->
<!-- fill-column: 120 -->
<!-- End: -->
