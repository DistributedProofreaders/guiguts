<?xml version="1.0" encoding="iso-8859-1" ?>

<!--

The Gnutenberg Press - TEI-lite to LaTeX stylesheet
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

If you don't find the element here it is probably handled in 
tei2common.xsl or teipreprocessor.xsl.

-->

<stylesheet xmlns="http://www.w3.org/1999/XSL/Transform" 
            xmlns:pg="http://www.gutenberg.org/tei/marcello/0.4/xslt"
	    version="1.0">

  <import  href="tei2common.xsl" />	    

  <variable name="hasfootnotes"  select="count (/TEI.2/text//note[@place='end'])"/>
  <variable name="marklevels"    select="110000" />
 
  <template match="text()">
    <value-of select="pg:s2-textnode (., string (../@x-id))"/>
  </template>

  <!-- 3. The Structure of a TEI Text -->

  <template match="TEI.2">
    <value-of select="pg:pdf-header ()"/>
    <text><![CDATA[

\def\teipar{\par}
\def\teinewline{\ \teipar} % an empty line that won't vanish
\def\teibreak{\hfil\break}

\parskip=0pt plus 3pt 

\def\teibrace#1{\dimen0=#1 \setbox0=\null \ht0=0.5\dimen0 \dp0=0.5\dimen0 
\hbox{$\left.\box0\right\}\nulldelimiterspace0pt \mathsurround0pt$}}

% maximum footnotes per page
\dimen\footins=0.5\textheight
\setlength{\footnotesep}{0pt}

\def\leftindent#1{\advance\leftskip #1}
\def\rightindent#1{\advance\rightskip #1}
                                                                                
\tolerance 10000  % dont make overfull boxes
\hbadness 1000    % warn if badness exceeds 1000

\catcode`@=11     % make 'private' LaTeX variables public
\catcode`\^^J=10  % don't let empty lines end paragraphs
\catcode`\^^M=10
\catcode`\"=12    % no special "

% \tracingoutput=1 % see output on console too
\tracingpages=1

\begin{document}

% pagination
\renewcommand*{\ps@plain}{
 \renewcommand*{\@evenhead}{}
 \renewcommand*{\@oddhead}{}
 \renewcommand*{\@oddfoot}{}
 \renewcommand*{\@evenfoot}{}
}
\newcommand*{\ps@tei}{
 \renewcommand*{\@evenhead}{\thepage\hfil\teititle}
 \renewcommand*{\@oddhead}{\firstmark\hfil\thepage}
 \renewcommand*{\@oddfoot}{}
 \renewcommand*{\@evenfoot}{}
}

% redefine cleardoublepage to output a really blank page
\let\cdpage\cleardoublepage
\renewcommand*{\cleardoublepage}{
 \clearpage
 {\pagestyle{plain}\cdpage}
}

% make content table look better than in standard LaTeX :-)
\renewcommand*\l@chapter{\@dottedtocline{1}{0em}{1.4em}}
\renewcommand*\l@section{\@dottedtocline{1}{1.5em}{2.3em}}
\renewcommand*\l@subsection{\@dottedtocline{2}{3.8em}{3.2em}}
\renewcommand*\l@subsubsection{\@dottedtocline{3}{7.0em}{4.1em}}
\renewcommand*\l@paragraph{\@dottedtocline{4}{10em}{5em}}
\renewcommand*\l@subparagraph{\@dottedtocline{5}{12em}{6em}}

% headers

\def\sectiona{chapter}
\def\sectionb{section}
\def\sectionc{subsection}
\def\sectiond{subsubsection}
\def\sectione{paragraph}
\def\sectionf{subparagraph}

% make floats easier for TeX
\newskip\floatskipamount \floatskipamount=12pt plus 24pt minus 4pt
\def\floatskip{\vspace\floatskipamount}
\def\floatbreak{\teipar\ifdim\lastskip < \floatskipamount
  \removelastskip\penalty-400\floatskip\fi}

\setlength{\textfloatsep}{12pt plus 24pt minus 4pt}
\setlength{\intextsep}{12pt plus 24pt minus 4pt}

\newbox\pllbox     \global\setbox\pllbox\null
\newbox\tempboxi   \global\setbox\tempboxi\null
\newbox\tempboxii  \global\setbox\tempboxii\null
\newbox\tempboxiii \global\setbox\tempboxiii\null
\newdimen\dimwd
\newdimen\dimht
\newdimen\dimdp

\def\teimklabel#1{\noindent\hbox to 0pt{\hss#1\enspace}\ignorespaces }

\def\teivmargin#1{{\skip0=#1\ifdim\lastskip < \skip0
  \removelastskip\vskip\skip0\fi}}

\def\teileftalign{%
  \advance\rightskip by 0pt plus 1000pt
  \parfillskip 0pt plus 1fil
}

\def\teicenteralign{%
  \advance\rightskip by 0pt plus 1000pt
  \advance\leftskip  by 0pt plus 1000pt
  \parfillskip 0pt
  \def\teibreak{\break}
}

\def\teirightalign{%
  \advance\leftskip by 0pt plus 1000pt
  \parfillskip 0pt
  \def\teibreak{\break}
}

\def\teimakecaption#1{%
  \penalty 500
  \sbox\@tempboxa{#1}%
  \ifdim \wd\@tempboxa > \hsize
    #1\teipar
  \else
    \hb@xt@\hsize{\hfil\box\@tempboxa\hfil}%
  \fi}

]]></text>

<apply-templates />

<text>&#x0a;\end{document}</text>

</template>

  <template match="/TEI.2/text">  
    <text>&#x0a;\pagestyle{tei}&#x0a;</text>
    <apply-imports />
  </template>
  
  <template match="/TEI.2/text/front">  
    <text>&#x0a;\frontmatter&#x0a;\thispagestyle{plain}&#x0a;\color{black}&#x0a;</text>
    <apply-imports />
  </template>

  <template match="/TEI.2/text/body">
    <text>&#x0a;\mainmatter&#x0a;\thispagestyle{plain}&#x0a;\color{black}&#x0a;</text>
    <apply-imports />
  </template>

  <template match="/TEI.2/text/back">
    <text>&#x0a;\backmatter&#x0a;\thispagestyle{plain}&#x0a;\color{black}&#x0a;</text>
    <apply-imports />
  </template>

  <!-- 4. Encoding the Body -->

  <!-- 4.1. Text Division Elements -->

  <template match="div">
    <if test="@id">
      <text>&#x0a;\pdfdest name {</text>
      <value-of select="@id" />
      <text>} XYZ % div[@id]&#x0a;</text>
    </if>

    <call-template name="default-all" />
  </template>

  <template match="p">
    <if test="not (pg:indent-p ())">
      <value-of select="pg:set-prop (., 'text-indent', 0)" />
    </if>

    <call-template name="default-all" />

    <!-- horrible hack to speed up libxslt -->
    <!-- libxslt joins adjacent text nodes in memory to one big string -->
    <!-- unless there are other nodes of different type in between. -->
    <!-- this prevents it. -->
    <text disable-output-escaping="yes">&#x0a;</text>
  </template>

  <!-- 4.2. Headings and Closings -->

  <!-- 4.3. Prose, Verse and Drama -->

  <template match="l">
    <if test="not (@part) or @part='I'">
      <text>\global\setbox\pllbox=\null&#x0a;</text>
    </if>
    <text>\noindent\hangindent 6em</text>
    <if test="@part='M' or @part='F'">
      <text>\hskip\wd\pllbox</text>
    </if>

    <text disable-output-escaping="yes">{% l&#x0a;</text>
    <call-template name="default-all" />
    <text>}&#x0a;</text>

    <if test="@part='I' or @part='M'">
      <!-- put the same text into pllbox and add a quad spacing -->
      <text>\global\setbox\pllbox=\hbox{\unhbox\pllbox </text>
      <call-template name="default-all" />
      <text>\quad}&#x0a;</text>
    </if>
  </template>

  <!-- 5. Page and Line Numbers -->

  <template match="pb[@n]">
    <text>\marginpar{\scriptsize [% note&#x0a;</text>
    <value-of select="@n" />
    <text>]}</text>
  </template>

  <template match="milestone[@unit='tb']">
    <variable name="r" select="pg:get-props (.)" />
    <choose>
      <when test="$r/properties[@stars]">
        <text>{\smallbreak\teicenteralign </text>
        <value-of select="pg:str-replicate ('* ', $r/properties/@stars)"/>
        <text>\smallbreak}</text>
      </when>
      <when test="$r/properties[@rule]">
        <text>{\smallbreak\teicenteralign\vrule width</text>
        <value-of select="pg:fix-length ($r/properties/@rule, '\textwidth')"/>
        <text> height0.4pt depth0pt\teipar\smallbreak}</text>
      </when>
      <otherwise>
        <text>{\bigbreak}</text>
      </otherwise>
    </choose>
  </template>

  <!-- 6. Marking Highlighted Phrases -->

  <!-- 6.1. Changes of Typeface, etc. -->

  <!-- stressed or emphasized text -->
  <template match="emph">
    <text>\emph{</text>
    <call-template name="default-all" />
    <text>}</text>
  </template>

  <!-- 6.2. Quotations and Related Features -->

  <!-- 6.3. Foreign Words or Expressions -->

  <!-- 7. Notes -->

  <template match="noteref">
    <value-of select="concat ('\footnotemark[', string(.), ']')"/>
  </template>

  <template match="notelabel">
  </template>

  <template match="notetext">
    <!-- when the last command in a footnote is \par
         latex inserts a strut after the par
         which gives us an unwanted  blank line -->

    <variable name="dummy" select="pg:disinherit (.)" />
    <!-- insert a strut into each text node -->
    <value-of select="pg:set-prop (., 'x-pdf-footnote', 1)" />

    <text>\footnotetext[</text>
    <value-of select="string(preceding-sibling::notelabel[1])" />
    <text>]{</text>
    <call-template name="default-all" />
    <text>}</text>
  </template>

  <template match="/TEI.2/text//note[@place='end']">
  </template>

  <template match="/TEI.2/text//note[@place='end']" mode="footnotes">
    <variable name="dummy" select="pg:disinherit (.)" />
    <call-template name="default-all" />
  </template>

  <!-- margin notes -->

  <template match="marginnote">
    <variable name="dummy" select="pg:disinherit (.)" />
    <apply-templates/>
  </template>

  <template match="marginnoteref|marginnotelabel">
  </template>

  <template match="marginnotetext">
    <variable name="dummy" select="pg:disinherit (.)" />
    <!-- we don't obey left and right, we just put it in the outer margin
         because there's more room -->
    <text>\marginpar{\scriptsize % note&#x0a;</text>
    <call-template name="default-all" />
    <text>}</text>
  </template>

  <!-- 8. Cross-References and Links -->

  <!-- 8.1. Simple Cross References -->

  <template match="ref">
    <!-- noindent needed because pdfstartlink is not allowed in vertical mode -->
    <call-template name="default-preamble" />
    <text><![CDATA[{\noindent\pdfstartlink
    attr{/BS << /Type /Border
                /S /U
             >>
         /H  /I
         /C  [0 1 1]} goto name {]]></text>
    <value-of select="@target" />
    <text>}</text>
    <apply-templates />
    <text>\pdfendlink}</text>
    <call-template name="default-postamble" />
  </template>

  <template match="anchor|seg">
    <text>{\pdfdest name {</text>
    <value-of select="@id" />
    <text>} XYZ}</text>
  </template>

  <!-- 8.2. Extended Pointers -->

  <template match="xref">
    <!-- see Guidelines 14.2.4 Representation of HTML links in TEI -->
    <!-- noindent needed because pdfstartlink is not allowed in vertical mode -->
    <call-template name="default-preamble" />
    <text><![CDATA[{\noindent\pdfstartlink
    attr { /BS << /Type /Border
                  /S /U
               >>
           /H /I
           /C [1 0.5 0.5]
         } 
    user { /Subtype /Link
           /A << /Type /Action
                 /S /URI
                 /URI (]]></text><value-of select="@url" /><text>)
              &gt;&gt;
         }</text>
    <apply-templates />
    <text>\pdfendlink}</text>
    <call-template name="default-postamble" />
  </template>

  <!-- 8.3. Linking Attributes -->

  <!-- 12. Lists -->

  <template match="list/labelitem/label|list/labelitem/headLabel">
    <text>\teimklabel{</text>
    <call-template name="default-all"/>
    <text>}&#x0a;</text>
  </template>

  <template match="list[@type='gloss']/labelitem/label|list[@type='gloss']/labelitem/headLabel">
    <call-template name="default-all"/>
  </template>

  <!-- cast lists -->

  <template match="castList">
    <text>\begin{list}{}{\setlength\itemsep{0pt}\setlength\parsep{0pt}\setlength\itemindent{0pt}\setlength\leftmargin{0pt}}&#x0a;</text>
    <apply-templates />
    <text>\end{list}&#x0a;</text>
  </template>

  <template match="castItem">
    <text>\item </text>
    <call-template name="default-all" />
    <text>&#x0a;</text>
  </template>

  <template match="role">
    <text>{</text>
    <call-template name="default-all" />
    <text>}</text>
  </template>

  <template match="roleDesc">
    <text>{\itshape </text>
    <call-template name="default-all" />
    <text>}</text>
  </template>

  <template match="castGroup">
    <variable name="castitems" select="(count(child::castItem) - 1) div 2" />

    <text>\setbox\tempboxi=\vtop{</text>
    <apply-templates />
    <text>}
    \dimdp=\dp\tempboxi
    \dimht=\ht\tempboxi
    \advance\dimht by \dimdp
    \dimen0=</text>
    <value-of select="$castitems" />
    <text>\baselineskip&#x0a;</text>
    <text>\item\hbox{\box\tempboxi\lower\dimen0\vbox{\quad\teibrace{\dimht}\quad\itshape </text>
    <apply-templates select="head" mode="braced" />
    <text>}}&#x0a;</text>
  </template>

  <template match="castGroup/head">
  </template>

  <template match="castGroup/head" mode="braced">
    <apply-templates />
  </template>

  <template match="castGroup/castItem">
    <text>\hbox{</text>
    <call-template name="default-all" />
    <text>\vphantom{Xy}}</text> <!-- hack to get spacing equal -->
  </template>

  <!-- 14. Tables -->

  <template match="table">
    <apply-templates select="index|anchor" />

    <variable name="r" select="pg:get-props (.)" />
    <variable name="hline">
      <if test="$r/properties[@rules]">
        <text>\hline&#x0a;</text>
      </if>
    </variable>
    <variable name="vline">
      <if test="$r/properties[@rules]">
        <text>|</text>
      </if>
    </variable>

    <!-- preamble -->

    <text>\par&#x0a;\begin{longtable}{</text>
    <choose>
      <when test="$r/properties[@latexcolumns]">
        <value-of select="$r/properties/@latexcolumns" />
      </when>
      <otherwise>
        <for-each select="row[1]/cell">
          <value-of select="$vline" />
	  <choose>
            <when test="$r/properties[@text-align = 'center']">
	      <text>c</text>
	    </when>
            <when test="$r/properties[@text-align = 'right']">
	      <text>r</text>
	    </when>
            <when test="$r/properties[@width]">
	      <text>p{</text><value-of select="$r/properties/@width" /><text>}</text>
	    </when>
            <otherwise>
	      <text>l</text>
	    </otherwise>
	  </choose>
        </for-each>
        <value-of select="$vline" />
      </otherwise>
    </choose>
    <text>}&#x0a;</text>

    <!-- caption on first page -->

    <for-each select="./head[not (contains(@type,'continued'))]">
      <value-of select="$hline"/>
      <text>\multicolumn{</text><value-of select="../@cols" /><text>}{</text>
      <value-of select="$vline" /><text>c</text><value-of select="$vline" /><text>}{</text>
      <apply-templates/>
      <text>}\\&#x0a;</text>
    </for-each>

    <if test="./row[1][@role='label']">
      <apply-templates select="./row[1][@role='label']"/>
    </if>

    <text>\endfirsthead&#x0a;</text>

    <!-- caption on next pages -->

    <if test="./head[@type='continued']">
      <value-of select="$hline"/>
      <text>\multicolumn{</text><value-of select="@cols" /><text>}{</text>
      <value-of select="$vline" /><text>c</text><value-of select="$vline" /><text>}{</text>
      <apply-templates select = "./head[@type='continued']" />
      <text>}\\&#x0a;</text>
    </if>

    <if test="./row[1][@role='label']">
      <apply-templates select="./row[1][@role='label']"/>
    </if>

    <text>\endhead&#x0a;</text>

    <!-- footers (not implemented) -->

    <value-of select="$hline"/>
    <text>\endfoot&#x0a;</text>
    <value-of select="$hline"/>
    <text>\endlastfoot&#x0a;</text>

    <!-- body -->

    <apply-templates select="./row[not(@role)] | ./row[@role!='label']" />

    <text>\end{longtable}&#x0a;</text>
  </template>

  <template match="row">
    <variable name="r" select="pg:get-props (..)" />
    <if test="$r/properties[@rules]">
      <text>\hline&#x0a;</text>
    </if>
    <apply-templates />
    <text> \\&#x0a;</text>
  </template>

  <template match="cell">
    <choose>
      <when test="preceding-sibling::cell">
        <text>&amp;</text>
      </when>
    </choose>
    <if test="@colspan">
      <text>\multicolumn{</text><value-of select="@colspan" /><text>}</text>
    </if>
    <call-template name="default-all" />
  </template>

  <template match="table/head">
    <!-- disables global head template -->
    <apply-templates /><!-- <text>\cr&#x0a;</text> -->
  </template>

  <!-- 15. Figures and Graphics -->

  <!-- images -->

  <template name="include-graphics">
    <param name="r" />
    <param name="img" />
    <param name="default" select="'image'"/>

    <choose>
      <when test="$img[@url]">
        <text>{&#x0a;\setlength\linewidth{\textwidth}&#x0a;\advance\linewidth -\leftskip</text>
        <text>&#x0a;\advance\linewidth -\rightskip&#x0a;</text>

        <text>\resizebox{</text>
        <value-of select="pg:fix-length (string ($r/properties/@width), '\linewidth')"/>
        <text>}{</text>
        <value-of select="pg:fix-length (string ($r/properties/@height), '\textheight')"/>
        <text>}{&#x0a;</text>

        <text>  \includegraphics{</text>
        <value-of select="$img/@url" />
        <text>}}&#x0a;</text>

        <if test="$r/properties[@display = 'block']">
          <!-- remove vskip inserted if picturewidth=textwidth -->
          <text>\unskip&#x0a;</text>
        </if>

        <text>}&#x0a;</text>
      </when>
      <otherwise>
        <text>[</text><value-of select="$default"/><text>]</text>
      </otherwise>
    </choose>
  </template>

  <template match="figure">
    <call-template name="default-preamble" />

    <value-of select="pg:default-prop (., 'width',  '!')" />
    <value-of select="pg:default-prop (., 'height', '!')" />

    <call-template name="include-graphics">
      <with-param name="r"       select="pg:get-props (.)" />
      <with-param name="img"     select="pg:copy-image (@url)" />
      <with-param name="default" select="figDesc" />
    </call-template>

    <apply-templates/>
    <call-template name="default-postamble" />
  </template>

  <template match="figDesc" />

  <template match="figure/head">
    <text>\teimakecaption{</text>
    <apply-templates />
    <text>}&#x0a;</text>
  </template>

  <!-- 17. Technical Documentation -->

  <!-- 17.1. Additional Elements for Technical Documents -->

  <template match="formula[@notation='tex']">
    <call-template name="default-preamble" />
    <value-of select="pg:inband (.)"/>
    <call-template name="default-postamble" />
  </template>

  <template match="formula[@notation='svg']">
    <value-of select="pg:default-prop (., 'width',  '!')" />
    <value-of select="pg:default-prop (., 'height', '!')" />

    <call-template name="include-graphics">
      <with-param name="r"       select="pg:get-props (.)" />
      <with-param name="img"     select="pg:render-svg (string (.))" />
      <with-param name="default" select="formula" />
    </call-template>
  </template>

  <!-- 17.2. Generated Divisions -->

  <template match="divGen[@type!='endnotes']" priority="1">
    <text>&#x0a;\@starttoc{</text>
    <value-of select="@type"/>
    <text>}&#x0a;</text>
  </template>

  <!-- 17.3. Index Generation -->

  <template name="mk_toc_anchor">
    <param name="index" />
    <param name="n" />
    <param name="level" />
    <param name="text" />

    <variable name="section">
      <choose>
        <when test="$index = 'toc'">
          <value-of select="substring ('abcddddddd', $level, 1)" />
        </when>
        <otherwise>
          <text>a</text>
        </otherwise>
      </choose>
    </variable>

    <text>\addcontentsline{</text>
    <value-of select="$index"/>
    <text>}{\section</text>
    <value-of select="$section"/>
    <text>}{\protect{}</text>
    <value-of select="$text"/>
    <text>}&#x0a;</text>

    <if test="$index = 'toc' and substring ($marklevels, $level, 1) = '1'">
      <text>\sbox\@tempboxa{</text>
      <value-of select="$text" />
      <text>}&#x0a;\ifdim \wd\@tempboxa &lt; 0.9\hsize&#x0a;</text>
      <text>\markright{\protect{}</text>
      <value-of select="$text"/>
      <text>}&#x0a;\else&#x0a;\markright{}&#x0a;\fi&#x0a;</text>
    </if>
  </template>

  <template match="index[@index='pdf']">
    <variable name="index">
      <number from="/TEI.2/text" count="index[@index='pdf']" level="any" />
    </variable>
    <variable name="children">
      <value-of select="count(following-sibling::*[index[@index='pdf']])" />
    </variable>

    <text>\pdfdest name {index</text>
    <value-of select="$index" />
    <text>} XYZ&#x0a;</text>

    <!-- pdfoutline characters are in the `PDF document encoding vector' -->
    <text>{\catcode`\#=11\catcode`\%=11\catcode`\$=11\catcode`\^=11\catcode`\_=11\catcode`\~=11\catcode`\&amp;=11&#x0a;</text>
    <text>\pdfoutline goto name {index</text>
    <value-of select="$index" />
    <text>} count -</text>
    <value-of select="$children" />
    <text> {</text>
    <value-of select="pg:pdf-fix-outline (string (.))"/>
    <text>}}&#x0a;</text> 

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

  <template match="pgHyphenationExceptions">
    <text>&#x0A;\hyphenation {</text>
    <for-each select="item|exception">
      <value-of select="." />
      <text> </text>
    </for-each>
    <text>}&#x0A;</text>
  </template>

  <!-- INTERNALS -->

  <!-- named templates -->

  <template name="default-preamble">
    <!-- FIXME: horrible hack
         we need this to exercise the tex paragraph builder 
         if a nested block `interrupts' the parent one
    <if test="@x-is-block and preceding-sibling::text()[string-length(normalize-space()) > 0]">
      <text>\teipar % default-preamble&#x0a;</text>
    </if>
-->

    <variable name="x" select="pg:rend (.)"/>
    <value-of select="$x/@pre"/>
  </template>
 
  <template name="default-postamble">
    <variable name="x" select="pg:rend (.)"/>
    <value-of select="$x/@post"/>
  </template>
 
  <template name="line-break">
    <text>\teibreak
    </text>
  </template>

</stylesheet>

<!-- Local Variables: -->
<!-- mode:nxml -->
<!-- coding:iso-8859-1-unix -->
<!-- fill-column: 120 -->
<!-- End: -->
