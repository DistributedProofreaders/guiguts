<?xml version="1.0" encoding="iso-8859-1" ?>

<!--

The Gnutenberg Press - PGTEI preprocessor
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


Main functions:

  - generate standard divGen's
  - handling of some elements common to all formats
  - normalize the markup, so following stages don't need to
    test for cases

-->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:pg="http://www.gutenberg.org/tei/marcello/0.4/xslt"
                exclude-result-prefixes="pg"
                version="1.0">

  <xsl:output   method="xml" 
                encoding="utf-8"
                indent="no" />

  <!-- copy verbatim everything not handled elsewhere -->
  
  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()" />
    </xsl:copy>
  </xsl:template>

  <!-- drop TEIform attribute from xsl:copy'd elements -->

  <xsl:template match="@TEIform" priority="2" />

  <xsl:template name="copy-attributes">
    <!-- copy all attributes except TEIform from current node -->
    <xsl:for-each select="@*">
      <xsl:if test="local-name () != 'TEIform'">
	<xsl:copy/>
      </xsl:if>
    </xsl:for-each>
  </xsl:template>

  <!-- 3. The Structure of a TEI Text -->

  <!-- 4. Encoding the Body -->

  <!-- 4.1. Text Division Elements -->

  <xsl:template match="div|div0|div1|div2|div3|div4|div5|div6|div7">
    <div>
      <xsl:call-template name="copy-attributes" />
      <xsl:apply-templates/>
    </div>
  </xsl:template>

  <xsl:template match="lg|lg1|lg2|lg3|lg4|lg5">
    <lg>
      <xsl:call-template name="copy-attributes" />
      <xsl:apply-templates/>
    </lg>
  </xsl:template>

  <!-- 4.2. Headings and Closings -->

  <!-- 4.3. Prose, Verse and Drama -->

  <!-- 5. Page and Line Numbers -->

  <!-- 6. Marking Highlighted Phrases -->

  <!-- 6.1. Changes of Typeface, etc. -->

  <!-- 6.2. Quotations and Related Features -->

  <!-- 6.3. Foreign Words or Expressions -->

  <!-- 7. Notes -->

  <xsl:template match="/TEI.2/text//note[@place='foot' or @place='end']">
    <xsl:variable name="n">
      <xsl:choose>
        <xsl:when test="@n">
          <xsl:value-of select="@n"/>
          <xsl:value-of select="pg:set-var ('note', @n)" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="pg:inc-var ('note')" />
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <noteref>
      <xsl:value-of select="$n"/>
    </noteref>

    <note>
      <xsl:call-template name="copy-attributes" />
      <notelabel>
        <xsl:value-of select="$n"/>
      </notelabel>
      <notetext>
        <xsl:apply-templates />
      </notetext>
    </note>
  </xsl:template>

  <xsl:template match="/TEI.2/text//note[@place='margin' or @place='left' or @place='right']">
    <xsl:variable name="n">
      <xsl:choose>
        <xsl:when test="@n">
          <xsl:value-of select="@n"/>
          <xsl:value-of select="pg:set-var ('marginnote', @n)" />
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="pg:inc-var ('marginnote')" />
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <marginnoteref>
      <xsl:value-of select="concat ('M', $n)"/>
    </marginnoteref>

    <marginnote>
      <xsl:call-template name="copy-attributes" />
      <marginnotelabel>
        <xsl:value-of select="concat ('M', $n)"/>
      </marginnotelabel>
      <marginnotetext>
        <xsl:apply-templates />
      </marginnotetext>
    </marginnote>
  </xsl:template>

  <xsl:template match="index//note" priority="2">
    <!-- kill notes in index entries -->
  </xsl:template>

  <xsl:template match="/TEI.2/text//note" priority="0">
    <xsl:apply-templates/>
  </xsl:template>

  <!-- 8. Cross-References and Links -->

  <!-- 8.1. Simple Cross References -->

  <xsl:template match="ptr">
    <!-- reduce ptr to ref -->
    <ref>
      <xsl:call-template name="copy-attributes" />
      <xsl:value-of select="@target" />
    </ref>
  </xsl:template>

  <!-- 8.2. Extended Pointers -->

  <xsl:template match="xptr">
    <!-- reduce xptr to xref -->
    <!-- see Guidelines 14.2.4 Representation of HTML links in TEI -->
    <xref>
      <xsl:call-template name="copy-attributes" />
      <xsl:value-of select="@url" />
    </xref>
  </xsl:template>

  <xsl:template match="xref[not (@url)]">
    <!-- xref without url param -->
    <!-- see Guidelines 14.2.4 Representation of HTML links in TEI -->
    <xref>
      <xsl:attribute name="url"><xsl:apply-templates /></xsl:attribute>
      <xsl:call-template name="copy-attributes" />
      <xsl:apply-templates />
    </xref>
  </xsl:template>

  <!-- 9. Editorial interventions -->

  <xsl:template match="corr|reg">
    <xsl:copy>
      <xsl:call-template name="copy-attributes" />
      <xsl:apply-templates/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="sic">
    <xsl:copy>
      <xsl:call-template name="copy-attributes" />
      <xsl:choose>
	<xsl:when test="@corr">
	  <xsl:value-of select="@corr"/>
	</xsl:when>
	<xsl:otherwise>
	  <xsl:apply-templates/>
	</xsl:otherwise>
      </xsl:choose>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="orig">
    <xsl:copy>
      <xsl:call-template name="copy-attributes" />
      <xsl:value-of select="@reg"/>
    </xsl:copy>
  </xsl:template>

  <!-- 10. Omissions, Deletions, and Additions -->

  <xsl:template match="gap">
    <xsl:copy>
      <xsl:call-template name="copy-attributes" />
      <xsl:value-of select="@desc"/>
    </xsl:copy>
  </xsl:template>

  <!-- 12. Lists -->

  <!-- fix lists to always contain <labelitem><label/><item/></labelitem>.
       this saves a lot of testing later -->

  <xsl:template match="list/label|list/headLabel" />

  <xsl:template match="list/label|list/headLabel" mode="override">
    <xsl:copy>
      <xsl:call-template name="copy-attributes" />
      <xsl:apply-templates />
    </xsl:copy>
  </xsl:template>    

  <xsl:template match="list/item">
    <labelitem>
      <xsl:choose>
        <xsl:when test="preceding-sibling::*[position () = 1 and self::label]">
          <xsl:apply-templates 
              select="preceding-sibling::*[position () = 1 and self::label]" 
              mode="override"/>
        </xsl:when>
        <xsl:otherwise>
          <label>
            <xsl:value-of select="@n"/>
          </label>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:copy>
        <xsl:call-template name="copy-attributes" />
        <xsl:apply-templates/>
      </xsl:copy>
    </labelitem>
  </xsl:template>

  <xsl:template match="list/headItem">
    <labelitem>
      <xsl:choose>
        <xsl:when test="preceding-sibling::*[position () = 1 and self::headLabel]">
          <xsl:apply-templates 
              select="preceding-sibling::*[position () = 1 and self::headLabel]" 
              mode="override"/>
        </xsl:when>
        <xsl:otherwise>
          <headLabel>
            <xsl:value-of select="@n"/>
          </headLabel>
        </xsl:otherwise>
      </xsl:choose>
      <xsl:copy>
        <xsl:call-template name="copy-attributes" />
        <xsl:apply-templates/>
      </xsl:copy>
    </labelitem>
  </xsl:template>

  <!-- 13. Bibliographic Citations -->

  <!-- 14. Tables -->

  <!-- 15. Figures and Graphics -->

  <!-- 16. Interpretation and Analysis -->

  <!-- 16.1. Orthographic Sentences -->

  <!-- 16.2. General-Purpose Interpretation Elements -->

  <!-- 17.2. Generated Divisions -->

  <xsl:template match="divGen[@type='availability']">
    <xsl:apply-templates 
        select="/TEI.2/teiHeader/fileDesc/publicationStmt/availability/*" />
  </xsl:template>

  <xsl:template match="divGen[@type='sourceDesc']">
    <xsl:apply-templates select="/TEI.2/teiHeader/fileDesc/sourceDesc/*" />
  </xsl:template>

  <!-- the title page -->

  <xsl:template match="divGen[@type='titlepage']">
    <xsl:variable name="fd" select="/TEI.2/teiHeader/fileDesc" />

    <docTitle rend="display: block">
      <xsl:apply-templates select="$fd/titleStmt/title" mode="titlepage" />
    </docTitle>

    <xsl:variable name="author"    
                  select="pg:get-author (/TEI.2/teiHeader/fileDesc/titleStmt/author)" />
    <xsl:if test="$author">
      <byline rend="display: block; font-size: xx-large; text-align: left; margin-top: 2; margin-bottom: 2">
        <xsl:text>by </xsl:text>
        <docAuthor rend="display: inline">
          <xsl:value-of select="$author" />
        </docAuthor>
      </byline>
    </xsl:if>

    <div rend="margin-top: 2; margin-bottom: 2; font-size: x-large; text-align: left; ">
      <docEdition>
        <xsl:apply-templates select="$fd/editionStmt/edition" />
      </docEdition>
      <xsl:text>, (</xsl:text>
      <docDate>
        <xsl:apply-templates select="$fd/publicationStmt/date" />
      </docDate>
      <xsl:text>)</xsl:text>
    </div>
  </xsl:template>

  <xsl:template match="titleStmt/title" mode="titlepage">
    <titlePart rend="display: block; margin-bottom: 2; font-size: xx-large; text-align: left; hyphenate: none">
      <xsl:apply-templates />
    </titlePart>
  </xsl:template>

  <xsl:template match="titleStmt/title[@type='sub']" mode="titlepage">
    <titlePart type="sub" rend="display: block; margin-bottom: 2; font-size: x-large; text-align: left; hyphenate: none">
      <xsl:apply-templates />
    </titlePart>
  </xsl:template>

  <!-- the colophon -->

  <xsl:template match="divGen[@type='colophon']" name="colophon">
    <xsl:apply-templates select="/TEI.2/teiHeader/fileDesc/notesStmt/note"/>

    <xsl:for-each select="/TEI.2/teiHeader/revisionDesc/change">
      <xsl:sort select="date/@value" />
      <list type="gloss">
        <xsl:apply-templates select="." mode="colophon"/>
      </list>
    </xsl:for-each>
  </xsl:template>

  <xsl:template match="change" mode="colophon">
    <labelitem>
      <label>
        <xsl:value-of select="date" />
      </label>
      <item>
        <list type="simple">
          <labelitem>
            <label/><xsl:apply-templates select="item" />
          </labelitem>
          <labelitem>
            <label/><item><xsl:apply-templates select="respStmt" /></item>
          </labelitem>
        </list>
      </item>
    </labelitem>
  </xsl:template>

  <!-- 17.3. Index Generation -->

  <xsl:template match="index[@index]">
    <index>
      <xsl:call-template name="copy-attributes" />
      <xsl:choose>
        <xsl:when test="@level1">
          <xsl:value-of select="@level1" />
        </xsl:when>
        <xsl:when test="following-sibling::head[not (@type = 'sub')]">
          <xsl:apply-templates select="following-sibling::head[not (@type = 'sub')][1]/node()[local-name () != 'note']"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates select="following-sibling::figDesc[1]/node()"/>
        </xsl:otherwise>
      </xsl:choose>
    </index>
  </xsl:template>

  <!-- 18. Character Sets, Diacritics, etc. -->
  
  <!-- 19. Front and Back Matter -->

  <!-- 19.1. Front Matter -->

  <!-- 19.1.1. Title Page -->

  <!-- 19.1.2. Prefatory Matter -->

  <!-- 19.2. Back Matter -->

  <!-- 19.2.1. Structural Divisions of Back Matter -->

  <!-- 20. The Electronic Title Page -->

</xsl:stylesheet>

<!-- Local Variables: -->
<!-- mode:nxml -->
<!-- coding:iso-8859-1-unix -->
<!-- fill-column: 120 -->
<!-- End: -->
