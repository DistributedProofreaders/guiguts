See http://www.pgdp.net/wiki/Guiguts_new_features_and_bug_fixes for a
description of new features and bug fixes in Version 1.0.0. Detailed
release notes for subsequent versions are added below.

WINDOWS:

guiguts-win-1.0.nn.zip is the easiest download for Windows users. It
includes guiguts.pl and supporting files and helper applications,
including those for working with RST and PGTEI files, excluding image
viewer and spellchecker. It should work out of the box by running
guiguts.bat (it includes copies of perl and Python languages).

MAC:

guiguts-mac-1.0.nn (if available) should work out of the box for Mac
users; it includes a few helper applications.

OTHER:

guiguts-1.0.nn.zip is the basic guiguts version with no helper
applications; it includes compilable source code for GutCheck and
Jeebies.

RELEASE NOTES:

Version 1.0.20.
- Display and set language added to statusbar (+ some adjustments of
  language behaviour, which has been partially available since 1.0.16).
- BOOKLANG included in headerdefault.txt.
- Short footnote anchors option added to html popup.
- Move footnotes to containing para added to footnote popup.
- Added line breaks to improve readability of generated html.
- Added 'replace [::] with incremental counter'.
- Bug fix: escaping of single and double quotes around images in html
  cleaned up.
- Bug fix: External commands containing several commands
  separated by semicolon was broken since 1.0.5. Non-Windows only.

Version 1.0.19. Fixed highlighting of newly selected wordlist. Fixed
undefined subroutine reference when choosing 'Enable Scanno Highlighting'.
Reset 'edited' flag after "Save As'. Fixed missing <hr class="chap" />
before a chapter heading in the middle of a page. Removed duplicate
insertion of footnote landing zone (FOOTNOTE) at end of file. Retained *
in word frequency list only if preceded by a hyphen. Set
'edited' flag after generating HTML.

Version 1.0.18. Fixed removal of too many lines when moving
footnotes to landing zone.

Version 1.0.17. Fixed error from hitting down arrow twice
after startup. Ignore tags in word frequency popup; ignore
away '*' characters (the way it used to be) except for '-*'
(not the way it used to be). Added spell check in multiple
languages to old menus and PP Wizard (actually done in 1.0.16).
Write setting.rc to guiguts home directory. Fixed problem
changing font sizes. Made check for two words (flash light
vs. flashlight vs. flash-light) optional.

Version 1.0.16. Made Do All into a button rather than a checkbox.
Radiobuttons for menu structure selection. Fixed undefined
subroutine for Auto Save Interval and fontsize. Made choice of menus
a Radiobutton. Added warning for headers (<h2>) with four or more
lines through the invalid tag '<Warning: long header>'. Made
HTML labels and sorting language dependent with plugin files
for English (default) and Danish.

Version 1.0.15. In the PP Wizard menu structure, moved pptxt from
Source Check to the Text Version(s) menu. Fixed undefined subroutine
error for hyperlinkpagenumbers. Handled headers of 3 or more lines.
Removed upper case for &amp; in author. Fixed problem with flood fill
popup. Fixed problem with Draw Boxes. Corrected space in replace string
after regex search for . lower.

Version 1.0.14. Added 'Do All (beta)' feature to Page Separator popup that
handles all page separators in one pass, assuming the file has been
proofread and footnotes handled with no extra or missing blank lines.
Possible soft hyphens -* are not rejoined. Fixed highlighting of
quotes.

Version 1.0.13. Fixed Replace All where the search term has a regexp
metacharacter such as '['. Made the "div" and "span" entries on the
HTML Fixup popup sticky. Marked PP Wizard as beta and not
the default menu structure.

Version 1.0.12. Provided message when current version is up to date, reset
the update clock when a new version is run, and added a "Working" message
while it is checking. Remove extra line before footnote being moved.
Further fix to Search and Replace All undefined subroutine error and
a handful of similar errors.

Version 1.0.11. Rejoin footnotes no longer leaves an extra new line
where the rejoined footnote used to be. Search and Replace All no
longer produces undefined subroutine error.

Version 1.0.10. Page markers are centered in Adjust Page Marker dialog with
an option "Do No Center Page Markers". Fixed an error "Undefined subroutine
b2scroll".

Version 1.0.9. After "Find Next ... Block" screen is centered on what is
found. Size/location of main window and font are sticky again (broken
after 1.0.5).

Version 1.0.8. In HTML generation, fixed pileup of page numbers at a
thought break (a fix for this in an earlier version was lost). Improved
placement of closing markup for a block of footnotes.

Version 1.0.7. Poetry converted to HTML has an indent of one em for
every two spaces. Conversion does not assume poetry is already rewrapped
so all lines begin with four spaces. If all lines are indented by four
spaces, then measure indentation relative to the four spaces. If some
lines are not indented by four spaces, measure indentation relative to
the beginning of the line. Check Footnotes popup is clickable to jump
to the footnote; the popup is destroyed if "First Pass" is selected.
Added File, Export to two formats (page separators, or page markup
like <Pg23>).

Version 1.0.6. Fixed problem with scannos highlighting taking forever to
turn on; default scannos file en-common.txt is selected. Handle spaces in
gutcheck path (mentioned in #3434768). In guiguts.bat, put tools\perl
higher on the path than the existing path; fixed path for ENCFONTS used
by the Gnutenberg Press. Made highlighting of scannos sticky. Set default
path for gutcheck and jeebies on non-Windows systems. <g>gesperrt text</g>
is converted to <em class="gesperrt">gesperrt text</em>. Added second
alternative menu structure for comment. Altered Fixup 'thought break'
response. Updated Greek transliteration of punctuation.

Version 1.0.5. Introduced a PP Wizard, an alternative menu structure,
that steps PPers through the GG checklist, which is not the default
option. Added a rudimentary check of whether HTML is "Epub friendly".
Changed <p> css in headerdefault.txt to work better on mobi devices:
margin-top: .51em; margin-bottom: .49em;. Reorganized the Preference
menu. Fixed bug with Gutcheck hanging on rerun. Added check for whether
the string entered in the RegExp field in the Word Frequency popup is a
valid regular expression. Added PP Process Checklist to Help menu.
Copied headerdefault.txt to header.txt on startup if header.txt does not
exist. Spellcheck no longer double counts occurrences of a word if run a
second time. Tidy Up Footnotes works if there is only one footnote.
Autogenerate HTML no longer uses /* or captions as the title. Auto Illus
Search no longer doubles tags in figleft and figright. Import Prep Text
allows letters in png filenames. Additional external operations added.
Search at beginning works again (broken in 1.0.4) but search will not
find the very first text in a file (fixed in 1.0.4). Problem with spaces
in gutcheck and other paths fixed.

Version 1.0.4. Hyphen check now also checks for "flash light" not only
"flash-light", "flash--light", and "flashlight". A regular expression
search over line breaks now respects the ignore case flag. Fixed path
and extension so EpubMaker will take .html files as input. PPV TXT and
PP HTML labeled more accurately as pptxt and pphtml. Only README.TXT
appears in the prepopulated recently used file list. Search can find the
first word in the file. Word frequency rerun after typing words in empty
file reports now works and bug with unresponsive save as dialog fixed.
Guiguts.bat calls perl in a way that should (may) ignore preexisting
installations of perl.

Version 1.0.3. Relocated HTML page number outside an open <span> eg for a line
of poetry so page numbers align vertically. Auto List on HTML palette no
longer removes spaces before markup in multiline mode. HTML anchors for
chapter headings are no longer empty but surround the chapter title
text. Join Lines removes */ /* </i> <i> etc. markup only if it matches. Fixed
Undo button on Fix Page Separator popup and added Redo button. Fixed
Find Greek on the Fixup menu to find all [Greek: ] occurrences.
Unicode->beta no longer converts \x{1FA7} and certain other characters
into %{HASH(0x4f10ff8)}. Added beta code for Greek character stigma.
Fixed bug if user tries to highlight scannos using the scannos list in
the scannos directory rather than a word list in the word list
directory.

Version 1.0.2. Fixed problem in which a regex replace with \G in the
found text led to characters being converted to Greek. Added message to
run final W3C markup validation at validator.w3.org. Improved conversion
of < and > characters when autogenerating HTML.

Version 1.0.1. Revamped spell checker including in Word Frequency popup
to handle UTF-8. Fixed "wide character in print" error by running
utf8::encode. Improved regexp to search for orphaned markup per
RoryConnor. Cleared undo cache after HTML autogenerate. Set command to
open browser for non-Windows OS and use it for external operations.
Dictionary search on the external operations menu now passes the
selection as a search argument. Made ASCII Boxes popup resizable.
Removed trailing space on last line of /# #/ block after rewrap. Respect
preference to leave space after end of line hyphen during rewrap if Join
Lines Keep Hyphen is chosen. Removed period on "Set margins for rewrap."
Changed "Check Errors" box to "Run Checks". Run fixup ignores /X X/ (as
well as /* */ and /$ $/) blocks if the first option is checked. Fixed
ordering of page numbers anchored inside HTML <h1> or <h2> tags. Add gutcheck
and jeebies directories without the .exe files to the guiguts-n.n.n.zip
file.

