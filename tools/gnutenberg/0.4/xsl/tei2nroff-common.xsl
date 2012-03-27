<?xml version="1.0" encoding="iso-8859-1" ?>

<!--

The Gnutenberg Press - TEI-lite to NROFF stylesheet
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

The output is post-processed so that:

  - "%" is translated to newline
  - multiple blank lines are stripped (use .csp n instead) 

-->

<stylesheet xmlns="http://www.w3.org/1999/XSL/Transform"
            xmlns:pg="http://www.gutenberg.org/tei/marcello/0.4/xslt"
	    version="1.0">

  <import  href="tei2common.xsl" />	    

  <variable name="hasfootnotes"  select="count (/TEI.2/text//note[@place='foot'])"/>

  <template match="text()">
    <value-of select="pg:s2-textnode (., string (../@x-id))"/>
  </template>

  <!-- 3. The Structure of a TEI Text -->

  <template match="TEI.2">
    <value-of select="pg:nroff-header ()" />

    <text><![CDATA[.cflags 0 . ? !
.de indent
.  in \\$1
..
.de hmove
\\h'\\$1'
..
.ie \nd \{    \" if diff mode
.  ll 60000
.  hy 0       \" dont hyphenate
.  nr t 0 0   \" dont indent
.  nr i 0 0
.rm indent
.de indent
..
.rm hmove
.de hmove
..
.\}
.el \{
\" .tr \(oq\(aq\(cq\(aq  \" these are not symmetrical on most fonts
.\}
.de csp     \" .csp 1 .csp 3 .csp 2 == .sp 3
.  br
.  mk vpos
.  nr vskipped ((\\n[vpos] - \\n[.h]) / 1v * 1u)
.  sp ((\\$1 - \\n[vskipped]) >? 0)
..
.ad l
]]></text>

    <apply-templates />

    <text>%.sp%***FINIS***%</text>
  </template>

  <!-- 4. Encoding the Body -->

  <!-- 4.1. Text Division Elements -->

  <template match="p">
    <call-template name="default-preamble" />
    <if test="@indent > 0">
      <text>\h'\nt'</text>
    </if>
    <apply-templates />
    <call-template name="default-postamble" />

    <!-- horrible hack to speed up libxslt -->
    <!-- libxslt joins adjacent text nodes in memory to one big string -->
    <!-- unless there are other nodes of different type in between. -->
    <!-- this prevents it. -->
    <text disable-output-escaping="yes">%</text>
  </template>

  <!-- 4.2. Headings and Closings -->

  <!-- 4.3. Prose, Verse and Drama -->

  <template match="l">
    <call-template name="default-preamble" />

    <if test="@part='M' or @part='F'">
      <text>%.hmove \n[pll]%</text>
    </if>
    
    <apply-templates/>

    <if test="@part='I' or @part='M'">
      <text>%.nr pll \n(.n*1u/1n 0%</text>
    </if>

    <call-template name="default-postamble" />
  </template>

  <!-- 5. Page and Line Numbers -->

  <template match="pb" />

  <!-- uncomment this for page numbers
      <template match="pb[@n]">
        <text> [</text><value-of select="@n" /><text>] </text>
      </template>
  -->

  <template match="milestone[@unit='tb']">
    <variable name="r" select="pg:get-props (.)" />
    <choose>
      <when test="$r/properties[@stars]">
        <text>%.csp 1%.ad c%</text>
        <value-of select="pg:str-replicate('* ', $r/properties/@stars)"/>
        <text>%.csp 1%.ad l%</text>
      </when>
      <when test="$r/properties[@rule]">
        <text>%.csp 1%.ad c%</text>
        <value-of select="pg:str-replicate ('-', pg:fix-length ($r/properties/@rule))" />
        <text>%.csp 1%.ad l%</text>
      </when>
      <otherwise>
        <text>%.csp 3%</text>
      </otherwise>
    </choose>
  </template>

  <!-- 6. Marking Highlighted Phrases -->

  <!-- 6.1. Changes of Typeface, etc. -->

  <!-- 6.2. Quotations and Related Features -->

  <!-- 6.3. Foreign Words or Expressions -->

  <!-- 7. Notes -->

  <template match="/TEI.2/text//note|marginnote">
    <!-- kill notes in normal mode -->
  </template>

  <template match="/TEI.2/text//note|marginnote" mode="footnotes">
    <variable name="dummy" select="pg:disinherit (.)" />
    <call-template name="default-all" />
  </template>

  <template match="noteref|marginnoteref">
    <call-template name="default-preamble"/>
    <text>(</text>
    <apply-templates/>
    <text>)</text>
    <call-template name="default-postamble"/>
  </template>

  <template match="notelabel|marginnotelabel">
    <value-of select="pg:push-stack ('pretext', 
                      pg:fill-nbsp (string(.), pg:fix-length (
                        pg:get-prop (.., 'text-indent'))))" />
  </template>

  <template match="notetext|marginnotetext">
    <call-template name="default-all" />
  </template>

  <!-- 8. Cross-References and Links -->

  <!-- 8.1. Simple Cross References -->

  <!-- can't do any linking inside a text file -->

  <!-- 8.2. Extended Pointers -->

  <template match="xref">
    <call-template name="default-preamble"/>
    <apply-templates />

    <!-- don't output twice if url == text -->
    <if test="pg:outband (@url) != .">
      <text> (</text><value-of select="@url" /><text>)</text>
    </if>
    <call-template name="default-postamble"/>
  </template>

  <!-- 8.3. Linking Attributes -->

  <!-- 12. Lists -->

  <template match="label" />

  <template match="list/labelitem/item|list/labelitem/headItem">
    <!-- push label in front of next text node -->
    <!-- need to do this because item has mixed contents, 
         text may be inside a p or not -->
    <variable name="dummy">
      <value-of select="pg:push-stack ('pretext', 
                          pg:fill-nbsp (string (preceding-sibling::label),
                          pg:fix-length (pg:get-prop (., 'text-indent'))))" />
    </variable>

    <call-template name="default-all" />
  </template>

  <!-- gloss -->

  <template match="list[@type='gloss']/labelitem/label|list[@type='gloss']/labelitem/headLabel">
    <call-template name="default-all"/>
  </template>

  <template match="list[@type='gloss']/labelitem/item|list[@type='gloss']/labelitem/headItem">
    <call-template name="default-all"/>
  </template>

  <!-- cast lists -->

  <template match="castItem">
    <call-template name="default-all" />
  </template>

  <template match="castGroup">
    <call-template name="default-all" />
  </template>

  <template match="castGroup/head">
    <call-template name="default-all" />
  </template>

  <!-- 14. Tables -->

  <template match="table">
    <variable name="r" select="pg:get-props (.)" />

    <text>%.TS%</text>
    <if test="$r/properties[@rules]">
      <text>allbox </text>
    </if>
    <if test="$r/properties[@boxed]">
      <text>box </text>
    </if>
    <text>;%</text>

    <apply-templates select="head" />
    <text>%</text>

    <apply-templates select="./row" />
    <text>%.TE%.csp 1%</text>
  </template>

  <template match="row">
    <call-template name="table-row-format" />
    <apply-templates />
    <text>%</text>
  </template>

  <template name="table-row-format">
    <if test="preceding-sibling::*">
      <text>.T&amp;%</text>
    </if>
    <variable name="tr" select="pg:get-props (..)" />
    <choose>
      <when test="$tr/properties[@tblcolumns]">
        <value-of select="$tr/properties/@tblcolumns" />
      </when>
      <otherwise>
        <for-each select="cell">
          <variable name="r" select="pg:get-props (.)" />
          <choose>
            <when test="$r/properties[@text-align = 'center']">
              <text>c </text>
            </when>
            <when test="$r/properties[@text-align = 'right']">
              <text>r </text>
            </when>
            <otherwise>
              <text>l </text>
            </otherwise>
          </choose>
        </for-each>
      </otherwise>
    </choose>
    <text>.%</text>
  </template>

  <template match="cell">
    <variable name="r"><apply-templates /></variable>
    <choose>
      <when test="string-length($r)=0">
        <!-- tbl needs some contents in every cell -->
        <text>T{&#x0a;T}</text>
      </when>
      <otherwise>
        <!-- make every cell a text block -->
        <text>T{&#x0a;</text>
        <value-of select="$r"/>
        <text>&#x0a;T}</text>
      </otherwise>
    </choose>
    <if test="following-sibling::cell">
      <!-- f8e3 is a whitespace eater -->
      <text>&#9;&#xf8e3;</text>
    </if>
  </template>

  <template match="table/head">
    <call-template name="table-caption-line" />
    <apply-templates />
    <text>%</text>
  </template>

  <template match="table/head[@type='continued']">
  </template>

  <template name="table-caption-line">
    <if test="preceding-sibling::row|preceding-sibling::head">
      <text>.T&amp;%</text>
    </if>
    <text>c </text>
    <for-each select="../row[1]/cell[position () &gt; 1]">
      <text>s </text>
    </for-each>
    <text>.%</text>
  </template>

  <!-- 15. Figures and Graphics -->

  <template match="figure">
    <call-template name="default-preamble" />
    <choose>
      <when test="figDesc">
        <text>%[</text>
	<apply-templates select="figDesc" />
        <text>]%</text>
      </when>
      <otherwise>
        <text>[image]</text>
      </otherwise>
    </choose>
    <if test="head|p">
      <text>%.sp%</text>
      <apply-templates select="head|p" />
      <text>%.csp 2%</text>
    </if>
    <call-template name="default-postamble" />
  </template>

  <template match="figure/head">
    <apply-templates />
  </template>

  <!-- 17. Technical Documentation -->

  <!-- 17.1. Additional Elements for Technical Documents -->

  <template match="formula[@notation='eqn']">
    <call-template name="default-all" />
  </template>

  <template match="formula[@notation='svg']">
    <text>[svg illustration]</text>
  </template>

  <!-- 17.2. Generated Divisions -->

  <template match="divGen[@type!='endnotes']" priority="1">
    <apply-templates select="/TEI.2/text//index[@index=current()/@type]" mode="toc" />
    <text>%.indent 0%.csp 5%</text>
  </template>

  <template match="divGen[@type='footnotes']" priority="2">
    <apply-templates select="/TEI.2/text//note[@place='foot']|//marginnote" mode="footnotes"/>
  </template>

  <!-- 17.3. Index Generation -->

  <template name="mk_toc_line">
    <param name="index" />
    <param name="level" />
    <param name="text" />

    <if test="$index = 'toc'">
      <text>%.indent </text>
      <number value="$level*3-3" format="1"/>
      <text>%</text>
    </if>
    <value-of select="$text"/>
    <text>%.br%</text>
  </template>

  <!-- 18. Character Sets, Diacritics, etc. -->
  
  <!-- 19. Front and Back Matter -->

  <!-- 19.1. Front Matter -->

  <!-- 19.1.1. Title Page -->

  <!-- 19.1.2. Prefatory Matter -->

  <!-- 19.2. Back Matter -->

  <!-- 19.2.1. Structural Divisions of Back Matter -->

  <!-- 20. The Electronic Title Page -->

  <!-- see divGen[@type="titlepage"] -->

  <!-- PG Extensions -->

  <!-- native script escape -->

  <!-- Named templates -->

  <template name="default-preamble">
    <variable name="x" select="pg:rend (.)"/>
    <value-of select="$x/@pre"/>
  </template>
 
  <template name="default-postamble">
    <variable name="x" select="pg:rend (.)"/>
    <value-of select="$x/@post"/>
  </template>
 
  <!-- page breaks -->

  <template name="line-break">
    <text>\ %.br%</text>
  </template>

</stylesheet>

<!-- Local Variables: -->
<!-- mode:nxml -->
<!-- coding:iso-8859-1-unix -->
<!-- fill-column: 120 -->
<!-- End: -->
