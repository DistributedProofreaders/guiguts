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


Main functions of this preprocessor:

  - include PG header and footer

-->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                version="1.0">

  <xsl:output   method="xml" 
                encoding="utf-8"
                indent="no" />

  <!-- copy verbatim everything not handled elsewhere -->
  
  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>

  <!-- 3. The Structure of a TEI Text -->

  <!-- 4. Encoding the Body -->

  <!-- 4.1. Text Division Elements -->

  <!-- 4.2. Headings and Closings -->

  <!-- 4.3. Prose, Verse and Drama -->

  <!-- 5. Page and Line Numbers -->

  <!-- 6. Marking Highlighted Phrases -->

  <!-- 6.1. Changes of Typeface, etc. -->

  <!-- 6.2. Quotations and Related Features -->

  <!-- 6.3. Foreign Words or Expressions -->

  <!-- 7. Notes -->

  <!-- 8. Cross-References and Links -->

  <!-- 8.1. Simple Cross References -->

  <!-- 8.2. Extended Pointers -->

  <!-- 9. Editorial interventions -->

  <!-- 10. Omissions, Deletions, and Additions -->

  <!-- 12. Lists -->

  <!-- 13. Bibliographic Citations -->

  <!-- 14. Tables -->

  <!-- 15. Figures and Graphics -->

  <!-- 16. Interpretation and Analysis -->

  <!-- 16.1. Orthographic Sentences -->

  <!-- 16.2. General-Purpose Interpretation Elements -->

  <!-- 17.2. Generated Divisions -->

  <xsl:template match="divGen[@type='pgheader']">
    <include xmlns="http://www.w3.org/2001/XInclude"
             href="http://www.gutenberg.org/tei/marcello/0.4/pg-license.tei#element(pgheader)"/>
  </xsl:template>


  <xsl:template match="divGen[@type='pgfooter']">
    <include xmlns="http://www.w3.org/2001/XInclude"
             href="http://www.gutenberg.org/tei/marcello/0.4/pg-license.tei#element(pgfooter)"/>
  </xsl:template>

  <!-- 17.3. Index Generation -->

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
