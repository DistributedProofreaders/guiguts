# Changelog


## Version 1.5.1

- HTML5 `figure` and `figcaption` elements now used for illos
- Page break code inserted in HTML whenever 4 blank lines are seen
- Further improvement to word selection, e.g. by double clicking
- Ebookmaker version 0.12.23 included - handles `&NoBreak;` character; warns
  about empty img alt tags; improved cover handling; miscellaneous bug fixes
- Default extension when importing TIA OCR is now `.gz`

### Bug Fixes

- Uninitialized variable error could occur running ebookmaker
- Aborting epub creation prematurely left busy cursor showing


## Version 1.5.0

- New Spell Query tool checks spelling, reporting queries in similar way to
  jeebies, bookloupe, etc. Similar buttons to old spell check dialog allow
  each query to be handled. Hover over buttons to see which combination of
  Shift/Ctrl with Left/Right click can be used as shortcut. If spelling
  occurs more often than the threshold (default 3), it is not reported.
  Use Alt+Left click to pop the Search dialog to search for the queried word.
- Spell Query also handles multiple languages - set the language to a list
  of language names using the status bar, or the `File/Project` menu.
  English, French and German dictionaries are included with the release.
- Word Frequency's Check Spelling button now uses Spell Query instead of
  Aspell.
- New W3C EPUBCheck tool added to HTML menu. User selects the epub to be
  checked, and results are shown in standard errorcheck dialog
- Generated HTML5 does not use XML serialization, i.e. void elements are not
  closed
- The `Nu XHTML Checker` entry in the HTML menu has been removed
- New `Copy Errors` button in tool dialogs (EPUBCheck, bookloupe, etc.)
  copies the contents of the errors list to the copy/paste clipboard
- Combining Characters now available in Compose Sequences, e.g. `+~` for 
  combining tilde above; `_~` for combining tilde below
- Additional compose sequences added for precomposed vowels with macron and
  long ess character.
- Help dialog descriptions clarify easily-confused compose sequences
- New Character Tool menu entry to convert the selected text to 
  Unicode Normalization Form C, which is necessary for HTML to validate
- New `\IP` extension added to regex syntax which is replaced with the
  current page label
- New `Rejoin Rows` button in ASCII Table Effects dialog takes a table with
  one cell per line and a blank line to mark rows, and converts it to a
  table with double space separators for cells, and all the cells from each
  table row on a single text line
- Latest ebookmaker version (0.12.20) included - now creates epub3 and kf8
  files in addition to epub2 and mobi files
- Latest Nu validator version (22.9.29) included - reports closed void elements
- `Next Occurrence` button in Stealth Scannos dialog now searches backward
  if clicked while holding down `Shift` key, just like `Search` button in
  Search & Replace dialog
- Shortcuts and regex help now links to manual pages
- Minor wording improvements for some highlighting buttons
- Improvement to CSS for centered poetry using `display:flex`
- Minor improvement to `pagenum` CSS in default header
- File Open dialog now displays files with `.xhtml` extension
- Improvements to installation procedure and instructions for Mac users
- Use Command key in place of Alt key in keyboard shortcuts on Macs
- Cmd-up/down key bindings added to match usual Mac behavior
- Optional command line argument `--home` added to specify the directory
  where persistent data files, such as `setting.rc`, will be stored,
  instead of under the release. If `--home` is not specified, and the
  default home directory exists, data files from there will be used.
  If default home directory does not exist, historical file locations
  under the release are used. Default home directory is in
  `HOME/Documents/GGprefs` on Windows/Mac systems and `HOME/.GGprefs`
  on Linux.
- New `Copy Settings From A Release` button added to the
  `Preferences/File Paths` menu to facilitate setup of default home
  directory. Normally used just once, this copies settings files from
  the chosen release into the default home directory location, from
  where they will be used by the current and all future releases.
- Optional command line argument `--nohome` added to force usage of
  `setting.rc` and similar files from under the release, rather than
  the default or specified home directory (primarily for testing)
- If `header_user.txt` exists, then instead of including `header.txt`
  at the top of an HTML file, `headerdefault.txt` is included, with
  the contents of `header_user.txt` inserted at the end of the CSS
  section. A user's customization can therefore be retained from one
  release to another, as well as any changes in `headerdefault.txt`
- Mac `Command` key can be used in place of `Alt` key in keyboard
  shortcuts

### Bug Fixes

- Word Frequency was failing for Mac users
- Several issues hindered running of jeebies on a Mac
- HTML generation could loop forever converting footnotes
- HTML generation could misplace the closing `<\div>` for a group of footnotes
  if footnote contained blockquotes
- Some ampersands were not converted to HTML entities during HTML generation
- Navigating, selecting and deleting by whole words was inconsistent:
    - Apostrophes now considered part of a word
    - Use keyboard Ctrl+Left/Right arrow for move; add Shift to select
    - Use double Mouse-1 to select words; drag or Shift+double Mouse-1 to
      extend selection
    - Use Ctrl+Delete/Backspace to delete word forward/backward
- Ctrl-Alt-s scratchpad shortcut did not work - removed feature entirely
- Using `Save` instead of `Save As` to save a new file could cause a crash
- Filename was not displayed correctly in `Save a Copy As` dialog
- `Import Prep Text Files` did not import files with a space in their names
- User's customized scannos folder location got reset when Guiguts was 
  restarted if the name of the folder ended in `scannos`, e.g. `myscannos`
  Such names are now retained, though the exact name `scannos` must still
  not be used
- Default locations for Aspell and XnView were unsuitable for Mac systems
- `Set File Paths/Locate Scannos` button failed on Mac systems
- Right-clicking to configure buttons at top of HTML markup dialog could
  generate multiple errors


## Version 1.4.0

- HTML generation now generates HTML5 with XML serialization
- Convert user's customized `header.txt` file to HTML5 if it has HTML4 header
- W3C Nu HTML checker is bundled instead of the old HTML validator
- Bundled version of W3C CSS validator updated to latest release
- Linux/Mac users - note that Guiguts now always outputs DP-style line endings
  (CRLF) when saving the main text file, even on non-Windows platforms
- Text and HTML files always use utf-8 encoding
- Unicode Character Search dialog shows decimal ordinal as well as hex
- Respect non-breaking spaces when wrapping text file
- New `Import TIA Abbyy OCR File` to enable PMs to use TIA scans without
  needing to purchase OCR software
- New `/C...C/` markup centers lines during rewrapping and HTML generation
- New `/R...R/` markup shifts block of lines to right margin (preserving
  indentation) during rewrapping and HTML generation
- PPVimage checks against the new recommended cover image size (1600x2560)
- `Find Next/Previous ... Block` entries removed from Search menu

### Bug Fixes

- Install documentation had out-of-date list of perl modules
- MacOS installation was failing due to change in homebrew install syntax
- Uninitialized variable error was output when trying to add words to project
  dictionary for an unsaved file
- Uninitialized variable error sometimes output when joining footnotes
- Bookloupe error `endquote missing punctuation` was wrongly capitalised
- Missing colon in footnote could cause uninitialised variable errors
- DP subscript and superscript markup inside block markup might not be
  converted during HTML generation
- Pagenums could misalign due to different `text-indent` values in the
  containing paragraphs
- Bookloupe only ignored `/*`, `/#`, `/$`, reporting `forward slash` warnings
  for other rewrap markup
- Conversion of fractions such as 1/2,000 failed
- Inserting the same image twice from the HTML dialogs would cause duplicate
  HTML ids to be used - a suffix is now added to avoid this
- Authors' names containing `F` or `f` were not extracted in the HTML
  generation if the name was on the same line as `By`
- `View in Browser` button in HTML generation dialog did not display the 
  recently-generated HTML - button removed, but identical option remains
  in Custom menu


## Version 1.3.3

- New Character Fill and Restore options added to ASCII Table dialog. These
  simplify some complex alignments, e.g. numbers aligned on decimal point and
  centered within a table column.
- Undo/Redo feature improved in ASCII Table dialog
- Latest production version of ebookmaker included (0.11.30). Epub and mobi
  filenames are now based on the HTML filename, not the book title.
- Curly quote search operations now wrap on reaching end of file
- Wording on Footnote Check dialog clarified
- Goto Label dialog is now case insensitive, so accepts uppercase Roman
  numerals
- The pphtml tool now outputs the first line number where CSS was used if it
  is warning about it potentially being undefined.

### Bug Fixes
- Under Linux, a missing tool, e.g. bookloupe, caused a crash
- When Word Frequency spellcheck was re-run, previously misspelled words were
  still reported, even though they had been corrected
- Square brackets within sidenotes could cause HTML conversion to fail
- Jeebies would hang if a word was longer than 50 characters
- Newlines were not consistently included when `.` was used in a regex and
  `$1` was used to indicate a parenthesised group
- Index rewrapping could fail to include the first character on the first line
  of a page
- Attempting to tidy inline footnotes caused them to be corrupted
- An extra spacer line was added after the `*/` table markup when Space Out
  feature was used in the ASCII Table dialog
- Markup `/*[4]` could be misinterpreted as a footnote anchor during First Pass
- Unicode Character Search tool could error if `^`, `*` or `+` were typed
- Caret is now spelled correctly in bookloupe checks
- Certain footnote layouts could cause HTML generation to loop forever
- Custom Commands dialog added blank commands when cancelled
- Occasional `uninitialised variable` errors were output by Custom Commands
- Thought breaks at end of page could get rewrapped


## Version 1.3.2

- New auto-correction features added to error check dialog, primarily for
  Load Checkfile (to support OCRfixr output), but some features can be used
  for other error checks. 
  - Ctrl+Mouse-1 makes the change suggested by the query/error (for Jeebies,
    this swaps he/be; for OCRfixr it makes the suggested correction). 
  - Ctrl+Mouse-2/3 does the same, but also removes the query from the list
    (as Mouse-2/3 currently do). 
  - Ctrl+Shift+Mouse-2/3 discards all queries that are identical to the
    clicked one but on a different line number. This is to quickly get rid of
    multiple wrong suggestions, and may be useful for other tools, such as
    Bookloupe. Note it does not remove all errors of that type, just the ones
    that match exactly, e.g. it can remove all occurrences of "Query digit in
    4to", but retain other digit queries.
- Regex scannos now clear the case insensitive flag by default
- The pphtml tool now outputs the line number where CSS was defined if it is
  warning about it potentially being unused.
- The Common Character dialog now has a small border to make it easier to click
  on and pop it to the front without inserting a character
- The Surround and Flood dialogs are now wider to allow them to be picked up
  and moved
- The Surround and Flood dialogs now accept input from the Common Character and
  Compose Character dialogs
- The display of match variants in the Spell Check dialog has been made clearer
  by adding additional words to the label instead of just a list of numbers,
  e.g. `3 exact, 2 case, 1 possessive, 4 hyphen in text.` instead of
  `3, 2, 1, 4 hyphens in text.`
- Check Orphaned Brackets can now check `/X X/`, `/F F/`, `/I I/` and `/L L/`.
- The default CSS header file has improved support for indexes, indenting
  wrapped lines more clearly
- The Preferences->Enable Quotes Highlighting option has been moved to the
  Search menu with the other highlighting options. Ctrl+semicolon toggles the
  highlighting of quotes and brackets that surround the cursor, rather than
  the previous behavior where it was necessary to edit the text to make the
  highlighting show. Also, quotes no longer need to be on the same line, and
  curly single and double quotes are supported
- A new right-click menu has been added, containing Cut, Copy and Paste options
  as well as the Bookmarks submenu. In addition, the location of the
  right-click is used for the bookmark, the Paste position, and whether to
  overwrite previously selected text
- Basic Fixup options to "Fix up spaces around hyphens" and "Format ellipses
  correctly" are now unchecked by default. "Fix up spaces around hyphens" only
  affects single hyphens, not longer dashes. "Remove space before periods"
  only affects single periods, not ellipses.  Correction of ellipses is also
  more conservative in its approach, not adding a space before if there is
  one already, or if there are adjacent quotes or sentence-ending punctuation.
- Quick Count feature added to Search menu, with Shift+Ctrl+b shortcut, that
  reports the number of occurrences of the currently selected word.

### Bug Fixes
- Search/Replace dialog did not remember its position correctly under Linux
- When smallcaps tools popped the Search/Replace dialog, they did not
  completely clear existing search/replace strings
- Running Stealth Scannos for a second time while the Hints dialog was popped
  would generate an error
- Check for Updates dialog did not expand to show all its contents if the font
  size was increased
- Basic Fixup checks were not skipped for /F markup as they were for /X
- An opening /X caused Basic Fixup checks to be skipped for the rest of the
  file, rather than resuming at X/
- Spacing before poetry line numbers inside /P markup was removed by Basic
  Fixup
- Scannos directory selection could generate an error if the directory name
  was too short
- Duplicate errors output by Bookloupe could cause an error when the user
  attempted to remove them both from the list
- When using Common Characters or Compose Character, an error could be
  generated if the dialog accepting input was dismissed leaving the focus in
  another dialog that could not accept that input
- The Spell Check dialog did not display the different types of matching
  (case, possessive or hyphen variants) for the first word found
- For the /P check, the Check Orphaned Brackets dialog displayed the raw regex
  string `/[Pp]|[Pp]/` instead of a friendly version `/P P/`
- The line length check in pptext did not count multibyte characters correctly,
  such as emdashes. The shortest line determination was also incorrect
- Right-clicking the text window over 100 times would cause an error, and
  eventually the program would exit
- Checkbox backgrounds on Windows changed color instead of remaining white when
  Preferences->Appearance->Set Button Highlight Color was used, even if the
  color choosing was cancelled


## Version 1.3.1

### Changes
- New option in File-->Content Providing menu to replace tabs, curly quotes
  and emdashes with acceptable equivalents.
- Content-providing option to highlight characters in WF Character Count that
  are not in a list of enabled DP character suites. Also, ability to manage
  which charsuites are enabled/disabled. Characters in WF dialog can be 
  Control-clicked to rapidly enable the appropriate character suite.
- 99% Auto page separator fixup now waits for the user to click Refresh
  before beginning processing.
- Guiguts and Bookloupe Test files removed from release package.
- User can now copy information from the Software Versions dialog.
- Image width type: percent, em or px is now saved between runs of the program.

### Bug Fixes
- Word Frequency Check Accents was not checking Latin-1 characters
- Queries from ppvimage were not counted correctly
- If the path to an image contained parentheses, the wrong path was entered in
  the HTML file.
- The `a` shortcut to jump to words beginning with `a` in Word Frequency failed
  when there were also words beginning with `æ`.
- The Help->About dialog could not be resized if the font size was changed.
- Adding illustration markup to the HTML file caused the cursor to jump to the
  CSS section.
- Typo in regex scanno file added a space when correcting a period followed by
  a lowercase letter on the following line.
- An error could be caused by using Manual Smallcaps conversion when the Search
  dialog had only two replacement fields.
- Some files could cause the update of the status bar to take so long that the
  program became unresponsive.
- Some e-readers showed illustrations with widths in pixels at 100% width.
- Block wrap markup with custom margins failed to rewrap correctly if nested
  within no-wrap markup.
- Page numbers could be combined or skipped in HTML output if page contained
  only one line of main text, e.g. due to long footnote.
- Joining lines could cause a page boundary to appear mid-word, leading to
  pagenum spans appearing mid-word in HTML, and spaces appearing mid-word in
  epub versions.
- Word Frequency searching could fail when a MiXeD-CasE word had underscore
  markup surrounding it.
- Bookloupe View Options dialog failed to resize when font was changed.
- Error check files with line:column at start of line did not get interpreted
  correctly.


## Version 1.3.0

### Changes
- Configure Page Labels has been redesigned and can now cope with thousands of
  pages. Label can be selected and edited in the dialog, or by using the
  following shortcuts: Shift+Mouse-1 cycles Arabic/Roman/ditto; Control+Mouse-1
  cycles Start@/+1/No Count; Double-click show page image. An Auto-Img button
  enables automatic page image display when a page is selected. Click and drag
  in the list to select and scroll, or use middle button drag for rapid scroll.
- Indent/Hanging Indent rewrapping is now supported in ASCII Tables. Also other
  minor bug fixes and improvements. Shortcut keys in the ASCII Table Effects
  dialog have been changed: instead of arrow keys, use the first character of
  Next, Previous, Left and Right.
- Straight to curly quote conversion has been added to the Txt menu and is only
  intended for use on text files, not HTML files. This uses an enhanced version
  of the ppsmq algorithm: it detects ditto marks if they have double spaces
  before and after; quotes at start and end of line are always selected
  correctly. A Curly Quote Correction submenu has been added, which can be
  torn off to make a mini-dialog. It allows selection of the next @ line,
  flipping all double quotes in selection, rechoosing double quotes based solely
  on spacing, removal of @ signs, selection and conversion of unconverted single
  quotes, and insertion of four types of quote.
- The font used in the menus, for labels, checkboxes, radio buttons, etc., can
  now be configured in Preferences-->Appearance-->Set Fonts. The default is to
  continue to use the system default. Note that it is not possible to change
  the font for the top menu bar.
- A fraction conversion submenu has been added to the Tools menu, allowing
  conversion to Unicode fractions only, superscript/subscript form, or a
  mixture (Unicode fraction if it exists, otherwise superscript/subscript form)
- Auto Illus Search now has the option to insert code for the current
  illustration and automatically load the next image file alphabetically,
  speeding up the insert of illustration code.
- Error checks, e.g. Bookloupe, Jeebies, Tidy, etc. have a live count of the
  number of queries remaining in the list displayed in the top left corner.
- Insert Page Labels (as opposed to markers) added to the Adjust Page Markers
  dialog and the Txt menu.
- Import and Export Prep Text Files now remember the most recent folder used
- After Import Prep Text Files, the Save As dialog is popped to allow the user
  to load the full file prior to beginning checks.
- Improved icon shipped with release to be used for desktop shortcuts, etc.
- 99% Auto Page Separator Fixup removes adjacent consecutive page separators
- Packaging and installation for Mac platforms improved to avoid issues running
  unsigned binaries. Mac users can now easily build their own Jeebies binary.
- The stickiness of Case, Regex, Whole word and Reverse can now be turned off
  in the Preferences menu.
- When ebookmaker is run, Guiguts now displays the busy cursor until it is
  completed. Any messages output by ebookmaker will be stored in the message
  log. If there are errors, the message log will be popped, but not if the
  conversion is successful.
- Check Accents in the Word Frequency dialog now includes all accented
  characters from the Latin Extended A and B, and Latin Extended Additional
  Unicode blocks.
- The Regex entry field in Word Frequency has been made wider
- Book title and author are passed to ebookmaker, so that they are
  included in the epub/Kindle files created.
- The Auto level used during Page Separator Fixup now defaults to 99%,
  and the last-used setting is saved between runs of the program.
- Wrapping of indexes enclosed in `/I...I/` markup now assumes the text
  is formatted according to DP guidelines.
- A Highlight Alignment Column feature has been added to the Search menu,
  with shortcut Ctrl+Shift+a toggling it on and off. This displays a
  highlighted vertical line at the cursor for use when aligning
  frontmatter, tables, etc.
- Greek characters with and without accents and breathing can be typed with
  Compose Key. All Greek letters are composed with `=`, followed by breathing,
  accent, subscript, letter if applicable, e.g. Compose=a for alpha,
  Compose=(a for alpha with breathing, etc. Betacode-style polytonic Greek
  entry also implemented. The introducing character is hyphen/minus instead
  of equal sign.
- Compose Sequence has been added to the Tools->Character Tools menu.
- Paths to tools and scannos are preserved better if the settings are copied
  from a previous release.
- Right-Align Numbers in Selection will now right align several numbers
  separated by commas, hyphens and ndashes.
- Quote and arbitrary highlighting now uses the same colour as scannos
  highlighting, and is therefore configurable.
- `Program Files (x86)` and `Program Files` will be checked automatically
  as default folders on Windows systems to find Aspell and XnView.
- Version 0.10.5 of ebookmaker is now included with Guiguts.
- Kindlegen is no longer bundled with the release. Instead, the user can
  either just create epub, not mobi, files when using ebookmaker locally,
  or can use Set File Paths to locate kindlegen which is included when
  Kindle Previewer 3 is installed. If no kindlegen is set up, an message
  is output to the log informing the user how they can get mobi files if
  they want them.
- Alt-up/down text moving feature removed.
- Remote W3C Validation has been removed.

### Bug Fixes
- If user increased font size, Compose and Goto dialogs didn't resize, causing
  clipping of OK button
- Auto Img sometimes output an error message about "undefined" widget
- Undo failed to remove all inserted code after inserting HTML illo markup
- Right-align Numbers failed if the line length already exceeded the wrap
  length
- Index page numbers were not linked if the text entry ended in quotes.
- Auto-Index tried to convert some numbers to page links that it should not.
- An error was output if an ASCII table column shrank smaller than zero width.
- Scanno highlighting was not turned on when a scannos file was loaded, nor if
  the program was restarted, despite appearing to be enabled in the status bar.
- The line of CSS that handled overriding the image width on handheld devices
  was duplicated for every image with the same width dimensions.
- Cancelling Save As caused undefined variable errors.
- Several minor bugs could occur when moving footnotes inline.
- Running Auto Table HTML conversion used to lose page marker positions.
- ASCII table operations used to lose page marker positions.
- A dollar sign in matched search and replace text was sometimes deleted.
- Hyphens were not treated as word boundaries in entry fields, unlike in the
  main window.
- HTML page numbering was occasionally wrong when two page numbers were
  adjacent due to a blank page.
- Text such as `I/` could be mistakenly interpreted as markup.
- The FOOTNOTES heading was not translated according to the language rc file.
- Ndashes were not treated as hyphens when converting indexes to HTML.
- Ampersand could not be included in Custom URLs.
- Guiguts lost focus when the Image Viewer was used.
- Regex replace for `^` or `$` did not work.
- Footnotes without closing `]` were not always flagged.
- `$t` in the Custom Menu couldn't handle utf-8 characters.
- Word Frequency Ligatures did not respect Suspects Only flag.
- Footnotes were not always placed correctly in chapter landing zones.
- Using Count on a regex of `^` would cause an infinite loop.
- Unhelpful error message when using non-ascii characters in filenames.
- Searching and replacing with a multi-line string terminating in a
  newline caused a subsequent Undo to lose text.
- Search and Replace dialog could not have its width resized.
- Bookloupe said it would not report some things and then did report them.
- If a 2-blank-line section heading inside block markup followed a page break,
  99% Auto Page Separator Fixup lost one of the blank lines.
- Auto Img button could appear on when it had been turned off.
- If a page marker followed immediately after a replaced string, it would
  jump to the start of the string.
- Joining footnotes to previous could fail if text was edited after First Pass.
- Unicode Character Search caused an infinite loop under Perl 5.32.
- A zero-width non-breaking space or BOM could cause an error when scrolling.


## Version 1.2.4

### Changes
- restored the Find Some Orphaned Markup button to the HTML Markup dialog

### Bug Fixes
- illow class CSS had an unwanted space character before class name
- length and frequency sorting in Word Frequency were reversed
- error when popping Page Separator dialog on some platforms
- pasting utf8 characters into the Search & Replace dialog failed on
  some platforms
- orphaned brackets might not be reported and could generate error
- closing footnote divs were badly placed
- file paths with quotes caused errors when saving
- error when searching for "0" from Word Frequency dialog
- spaces at the start of a paragraph were wrongly preserved, leading to an
  indented first line after rewrap
- 80% auto mode in Fixup Page Separators could get stuck in a loop

## Version 1.2.3

### Bug Fixes
- faulty bin file could be created, depending on page label setup
- `/P...P/` poetry was not always rewrapped correctly
- search and replace dialog was too wide

## Version 1.2.2

### Changes
- user can specify HTML image size in pixels, not just ems or percentage,
  by enabling the feature in the Preferences-->Processing Menu
- Post-Processing Workbench added to the Custom Menu
- underscores are preserved when filename is used to create an image id

### Bug Fixes
- error messages could be output when saving after checking curly quotes
- line numbers were hidden if rewrap was attempted on an empty selection
- selecting a word or using Ctrl+arrow keys to move by word could cause
  "Malformed UTF-8 character" errors
- pasting moderate to large amounts of text could make the program crash

## Version 1.2.1

### Changes
- user can now choose which key to use to start a Compose Sequence
  via Processing in the Preferences Menu

### Bug Fixes
- saving a project without page labels generated many errors
- error messages were being output too slowly
- if Aspell was not set up, Software Versions generated an error

## Version 1.2.0

### Improved HTML and epub generation
- redesigned HTML Markup dialog includes buttons configurable via `ctrl-click`
- readability of HTML pagenum and blockquote markup is improved
- latest version of ebookmaker is bundled with the Windows release
- `@media handheld` is no longer used in generated HTML files
- Best Practices code is used for floated images
- chapter separator horizontal rules are hidden on paged devices

### Unicode characters
- compose key (`Right-Alt`/`ctrl+m`) allows entry of characters via a
  sequence of keystrokes - list available via the Help menu
- Commonly-Used Characters chart replaces the Latin-1 chart, with spare
  buttons that the user can configure via `ctrl-click`
- Unicode Character Entry can be popped by right-clicking status bar
  ordinal label, and remembers previous use
- Unicode dialog is faster and more streamlined
- Greek transliteration dialog buttons show the correct character to be
  inserted in the current font, and it remembers type of input used

### Usability
- using F1 key in any dialog will display the relevant manual page
- fonts may now be configured and displayed instantly for the main text window,
  Greek and Unicode dialogs, and text entry fields
- shift-clicking on search buttons temporarily reverses the search direction
- warnings and errors that used to only appear in the command window are
  saved and displayed in a message log
- word count threshold for Word Frequency's Ital/Bold/SC/etc button is saved,
  overriding default maximum of 4 words detected within those markup tags
- the Word Frequency Ital/Bold/SC/etc button also checks cite, em, strong, f, g & u
- auto-advance is now on by default for Stealth Scannos
- view options are remembered when the bookloupe dialog is closed,
  and the user's default settings are loaded when guiguts starts
- options relating to content providing are now in a submenu of the File menu
- items on the status bar have been reordered to support narrow windows

### Operations sped up by factor of 3 or more
- Basic Fixup
- rewrapping
- Replace All with regular expressions
- several footnote operations
- HTML autogeneration

### Removed in this version
- old menu layout
- old spellcheck layout
- old rewrap algorithm
- gutcheck tool (replaced by bookloupe)
- bookloupe run options dialog
- functionality relating to proofers' names
- debug button in multilingual spelling

### Bug fixes
- Search/replace failed when text substituted for $1 contained literal $2
- goto dialogs forgot their screen position
- Greek dialog failed to resize correctly
- certain unicode strings were pasted as garbage
- image viewer was opened twice on first use
- bad text index errors occurred during sidenote fixup
- project dictionary filename could not cope with more than 9 volumes
- alphabetical sorting was incorrect in Word Frequency lists
- save and export Word Frequency lists were not utf8-safe
- a search term that was also an invalid regex caused a Replace All loop
- "Start at Beginning" setting was cleared when using Count in S&R dialog
- pphtml reported a lack of space in self-closing tag, e.g. `<br/>`
- Find Previous Proofer Comment failed when already at a comment
- Undo/Redo buttons were unreliable on the Page Separators dialog - the
  main undo/redo mechanism now also works for page separator changes
- converting inline sidenotes to HTML sometimes deleted text incorrectly

## Version 1.1.1

### Changes
- Variation Selectors Unicode block is now available. These combining
  characters are generally not visible, but are in order VS1 to VS16.
  Hovering over the small squares or spaces where the characters are
  should also show you which is which. 
- Improvements made to Check for Updates dialog

### Bug Fixes
- Bundled CSS validator reported wrong line numbers
- Draw ascii boxes failed when text was rewrapped
- Clicking in an error list window jumped to previous error's line number
- Undo/redo in Page Separator dialog sometimes output error messages
- Poetry in footnotes was enclosed in `<p>` markup during HTML generation
- Save My View in Bookloupe View Options output error messages
- Three or more hyphens at start/end of line not converted to HTML emdashes
- `Save` did not prompt for a filename if file was unnamed and not edited
- Enable/disable Autosave output error messages
- `No count` pages in Roman style gave errors in Configure Page Labels
- Incorrect error message displayed when running Jeebies on file without he/be

## Version 1.1.0

### Improved HTML generation
- poetry HTML generation matches DP Best Practices document
- illustration code generated by Auto Illus Search or Markup Image
   - adds id to the fig div based on the image filename
   - uses CSS classes instead of styles on image divs
   - width of image may be specified in percent or em
   - calculates max width for image to fit portrait or landscape screens
   - restricts max width to image's natural size
   - optional override for percent width to 100% on handheld devices
- `/I...I/` or `/i...i/` markup is used to generate an index
- HTML/CSS for chapter headings works well for ePub formats
- default `<hr>` CSS defines margins to center correctly in ePub
- uses id instead of `<a>` element for anchors where possible
- uses improved CSS for pagenums within bold/italic/sc markup
- autotable uses CSS rather than HTML attributes
- all-small-caps are detected and coded during HTML generation
- HTML title wording puts book title first
- HTML header updated with code for including cover

### Improved Search & Replace functionality
- a Count button (`ctrl+b`) counts how many times the current search
  settings would find a match
- number of replacement terms can be changed by the user
- search & replace preserves the position of page markers
- search & replace histories are now updated by all search, replace
  and count operations

### Better utf-8 support
- bookloupe tool is used as a replacement for gutcheck by default
- HTML generation defaults to keep utf-8 chars and use CSS for blockquote
- files are now treated as utf-8 by default, rather than varying treatment
  depending on contents
  
### Major packaging changes
- instructions are given for installing and use on modern macOS
- uses Strawberry Perl rather than old bundled version
- includes latest version of EBookMaker, runnable from HTML menu
- Jeebies tool is updated to latest version (0.15a - 2009)
- ppvimage tool is updated to match new image size guidance
- local CSS validation tool is updated to validate CSS3 or CSS2.1
- `DPCustomMono2` font replaced with instructions on getting `DP Sans Mono`
- git checkout can be used as a live release (developers/testers)

### Other Changes
- Tony Browne's regex and Greek patches (aka 1.0.28) are included
- new Keyboard Shortcuts are included:
   - `ctrl+o` - open file
   - `ctrl+shift+s` - save as...
   - `ctrl+j` - goto line
   - `ctrl+b` - count number of search/replace matches
   - `ctrl+w` - rewrap selection
   - `ctrl+shift+w` - block rewrap selection
   - `ctrl+m` - indent +1
   - `ctrl+shift+m` - indent -1
   - `ctrl+alt+m` - indent +4
   - `ctrl+alt+shift+m` - indent -4
   - `ctrl+e` instead of `ctrl+o` - flood fill
- highlight quotes now includes curly quotes
- output from external tools such as online ppcomp, pptext, etc., can be
  loaded into error check dialog and used for navigation
- any number of External Operations can be defined
- Goto Line/Page dialogs can be closed with Escape key or close button
- RST/PGTEI support and `EPub friendly` check are removed

### Bug Fixes
- Word Frequency harmonics failed to spot single letter change
- `'.' not in @INC` error from newer versions of Perl
- italic markup across line breaks in poetry
- Word Frequency, Character Count could not search for backslash
- rewrapping changed y-umlaut character to space
- changes to HTML conversion settings lost when dialog dismissed
- inconsistency in menu, shortcuts and documentation with Column Copy/Cut
- close block rewrap failed when not followed by a blank line
- right-clicking in gutcheck error dialog could corrupt error listing
- file permissions now retained on file save
- `[foot` caused footnote code to fail
- adding good words to project dictionary failed under Linux

## Version 1.0.25
- bug fix: newly opened file displays as edited
- bug fix: gutcheck popup background
- bug fix: missing had/bad option in gutcheck
- bug fix: rewrap problems around page markers
- updated urls to sourceforge trackers
- updated default indent values
- bug fix: double `</p>` at `*/#/`
- bug fix: orphan brackets accepts mixed French and German guillemets
- bug fix: no return to GG dir after adding GWL
- default menu layout updated, old layout left as option
- unmaintained wizard menu layout removed
- shortcut keys cleaned up and updated (see Help -> Shortcuts)
- buggy bookmark shortcuts made opt-in and marked beta
- some cmd shortcuts added for mac
- footnote popup layout updated, auto-launch of Check FNs
- better joining of footnotes
- better separation of WF and S&R
- minor update of WF layout and behaviour
- spellcheck popup layout updated (with a pref for the old one)
- spellcheck use project language dictionary
- basic support for enchant (beta)
- better support for LOTE views in GC
- clearer warning when Windows Preview bug locks a file

## Version 1.0.24
- bug fix: auto-run Word Frequency before Stealth Scannos.
- bug fix: better file name suggestion in save as dialog.
- bug fix: tweaking spell check for non-ascii.
- bug fix: fixed a few issues with the new rewrap.

## Version 1.0.23
- bug fix: html page numbers being placed one line too early in poetry
- bug fix: Remove Markup from Selection removing markup not in selection
- updated rewrap algorithm
- updated Fix Page Separators dialog and added 99% auto mode
- updated display of 'edited' marker
- Operations History now stores January as 01, not 00, etc.
- HTML generate image captions as div instead of span, enclose in p
- some tweaking of aspell interaction
- various minor tweaks and cleanup

## Version 1.0.22
- updating ppvimage to 1.06.
- guiguts.bat renamed to run_guiguts.bat
- DP urls user-editable
- bug fix: indenting `/# #/` blocks with more than one paragraph
- bug fix: Link Checker with spaces in path
- bug fix: some issues with reading page markers when opening a file
- bug fix: proofer bar is now working
- bug fix: .bin file getting out of sync (saved too often)
- bug fix: file names with apostrophe making file history explode
- various minor bug fixes and menu cleanups

## Version 1.0.21
- HTML Fixup split in two: HTML Markup and HTML Generator.
- Rewrap margins made consistent.
- Added Txt Conversion popup.
- Centering and right-aligning of txt added.
- Orphaned brackets made less confusing.
- minor cleanup of menus and some popups.
- positionhash added as a supplement to geometryhash.
- Various bug fixes, including:
  - sentence-ending punctuation eaten by footnote markers.
  - $t in extops with no selection.
  - Save As while Page Markers visible.
  - bom is gone.
  - tidy handles unicode better.
  - some html page numbers inserted in a wrong place.
  - undo and redo will move the window to show the edited position.
  - some "undefined subroutine"s fixed.
  - some user settings would be ignored and overwritten by the default.
  - inserting from character popups didn't overwrite selection.

## Version 1.0.20
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

## Version 1.0.19
Fixed highlighting of newly selected wordlist. Fixed
undefined subroutine reference when choosing 'Enable Scanno Highlighting'.
Reset 'edited' flag after "Save As'. Fixed missing `<hr class="chap" />`
before a chapter heading in the middle of a page. Removed duplicate
insertion of footnote landing zone (FOOTNOTE) at end of file. Retained `*`
in word frequency list only if preceded by a hyphen. Set
'edited' flag after generating HTML.

## Version 1.0.18
Fixed removal of too many lines when moving
footnotes to landing zone.

## Version 1.0.17
Fixed error from hitting down arrow twice
after startup. Ignore tags in word frequency popup; ignore
away `*` characters (the way it used to be) except for `-*`
(not the way it used to be). Added spell check in multiple
languages to old menus and PP Wizard (actually done in 1.0.16).
Write setting.rc to guiguts home directory. Fixed problem
changing font sizes. Made check for two words (flash light
vs. flashlight vs. flash-light) optional.

## Version 1.0.16
Made Do All into a button rather than a checkbox.
Radiobuttons for menu structure selection. Fixed undefined
subroutine for Auto Save Interval and fontsize. Made choice of menus
a Radiobutton. Added warning for headers (`<h2>`) with four or more
lines through the invalid tag `<Warning: long header>`. Made
HTML labels and sorting language dependent with plugin files
for English (default) and Danish.

## Version 1.0.15.
In the PP Wizard menu structure, moved pptxt from
Source Check to the Text Version(s) menu. Fixed undefined subroutine
error for hyperlinkpagenumbers. Handled headers of 3 or more lines.
Removed upper case for &amp; in author. Fixed problem with flood fill
popup. Fixed problem with Draw Boxes. Corrected space in replace string
after regex search for `.` lower.

## Version 1.0.14
Added 'Do All (beta)' feature to Page Separator popup that
handles all page separators in one pass, assuming the file has been
proofread and footnotes handled with no extra or missing blank lines.
Possible soft hyphens `-*` are not rejoined. Fixed highlighting of
quotes.

## Version 1.0.13
Fixed Replace All where the search term has a regexp
metacharacter such as '['. Made the "div" and "span" entries on the
HTML Fixup popup sticky. Marked PP Wizard as beta and not
the default menu structure.

## Version 1.0.12
Provided message when current version is up to date, reset
the update clock when a new version is run, and added a "Working" message
while it is checking. Remove extra line before footnote being moved.
Further fix to Search and Replace All undefined subroutine error and
a handful of similar errors.

## Version 1.0.11
Rejoin footnotes no longer leaves an extra new line
where the rejoined footnote used to be. Search and Replace All no
longer produces undefined subroutine error.

## Version 1.0.10
Page markers are centered in Adjust Page Marker dialog with
an option "Do No Center Page Markers". Fixed an error "Undefined subroutine
b2scroll".

## Version 1.0.9
After "Find Next ... Block" screen is centered on what is
found. Size/location of main window and font are sticky again (broken
after 1.0.5).

## Version 1.0.8
In HTML generation, fixed pileup of page numbers at a
thought break (a fix for this in an earlier version was lost). Improved
placement of closing markup for a block of footnotes.

## Version 1.0.7
Poetry converted to HTML has an indent of one em for
every two spaces. Conversion does not assume poetry is already rewrapped
so all lines begin with four spaces. If all lines are indented by four
spaces, then measure indentation relative to the four spaces. If some
lines are not indented by four spaces, measure indentation relative to
the beginning of the line. Check Footnotes popup is clickable to jump
to the footnote; the popup is destroyed if "First Pass" is selected.
Added File, Export to two formats (page separators, or page markup
like `<Pg23>`).

## Version 1.0.6
Fixed problem with scannos highlighting taking forever to
turn on; default scannos file en-common.txt is selected. Handle spaces in
gutcheck path (mentioned in #3434768). In guiguts.bat, put tools\perl
higher on the path than the existing path; fixed path for ENCFONTS used
by the Gnutenberg Press. Made highlighting of scannos sticky. Set default
path for gutcheck and jeebies on non-Windows systems. `<g>gesperrt text</g>`
is converted to `<em class="gesperrt">gesperrt text</em>`. Added second
alternative menu structure for comment. Altered Fixup 'thought break'
response. Updated Greek transliteration of punctuation.

## Version 1.0.5
Introduced a PP Wizard, an alternative menu structure,
that steps PPers through the GG checklist, which is not the default
option. Added a rudimentary check of whether HTML is "Epub friendly".
Changed `<p>` css in headerdefault.txt to work better on mobi devices:
margin-top: .51em; margin-bottom: .49em;. Reorganized the Preference
menu. Fixed bug with Gutcheck hanging on rerun. Added check for whether
the string entered in the RegExp field in the Word Frequency popup is a
valid regular expression. Added PP Process Checklist to Help menu.
Copied headerdefault.txt to header.txt on startup if header.txt does not
exist. Spellcheck no longer double counts occurrences of a word if run a
second time. Tidy Up Footnotes works if there is only one footnote.
Autogenerate HTML no longer uses `/*` or captions as the title. Auto Illus
Search no longer doubles tags in figleft and figright. Import Prep Text
allows letters in png filenames. Additional external operations added.
Search at beginning works again (broken in 1.0.4) but search will not
find the very first text in a file (fixed in 1.0.4). Problem with spaces
in gutcheck and other paths fixed.

## Version 1.0.4
Hyphen check now also checks for "flash light" not only
"flash-light", "flash--light", and "flashlight". A regular expression
search over line breaks now respects the ignore case flag. Fixed path
and extension so EpubMaker will take .html files as input. PPV TXT and
PP HTML labeled more accurately as pptxt and pphtml. Only README.TXT
appears in the prepopulated recently used file list. Search can find the
first word in the file. Word frequency rerun after typing words in empty
file reports now works and bug with unresponsive save as dialog fixed.
Guiguts.bat calls perl in a way that should (may) ignore preexisting
installations of perl.

## Version 1.0.3
Relocated HTML page number outside an open `<span>` eg for a line
of poetry so page numbers align vertically. Auto List on HTML palette no
longer removes spaces before markup in multiline mode. HTML anchors for
chapter headings are no longer empty but surround the chapter title
text. Join Lines removes `*/ /*` `</i>` `<i>` etc. markup only if it matches. Fixed
Undo button on Fix Page Separator popup and added Redo button. Fixed
Find Greek on the Fixup menu to find all [Greek: ] occurrences.
Unicode->beta no longer converts \x{1FA7} and certain other characters
into %{HASH(0x4f10ff8)}. Added beta code for Greek character stigma.
Fixed bug if user tries to highlight scannos using the scannos list in
the scannos directory rather than a word list in the word list
directory.

## Version 1.0.2
Fixed problem in which a regex replace with \G in the
found text led to characters being converted to Greek. Added message to
run final W3C markup validation at validator.w3.org. Improved conversion
of `<` and `>` characters when autogenerating HTML.

## Version 1.0.1
Revamped spell checker including in Word Frequency popup
to handle UTF-8. Fixed "wide character in print" error by running
utf8::encode. Improved regexp to search for orphaned markup per
RoryConnor. Cleared undo cache after HTML autogenerate. Set command to
open browser for non-Windows OS and use it for external operations.
Dictionary search on the external operations menu now passes the
selection as a search argument. Made ASCII Boxes popup resizable.
Removed trailing space on last line of `/# #/` block after rewrap. Respect
preference to leave space after end of line hyphen during rewrap if Join
Lines Keep Hyphen is chosen. Removed period on "Set margins for rewrap."
Changed "Check Errors" box to "Run Checks". Run fixup ignores /X X/ (as
well as `/* */` and `/$ $/`) blocks if the first option is checked. Fixed
ordering of page numbers anchored inside HTML `<h1>` or `<h2>` tags. Add gutcheck
and jeebies directories without the .exe files to the guiguts-n.n.n.zip
file.

## Version 1.0.0
Relative to version 0.2.10, the main changes in version 1.0 are

1. One click installation on Windows and Macintosh/OSX computers with no need
   to install perl separately (see guiguts-win and guiguts-mac zip files)
2. Several major new features, including running all HTML checks with one
   button, side by side viewing of text and images, and support for RST
   and PGTEI
3. Fixes to many long-standing bugs


### Major New Features

All the HTML checks can be run with a  single click, and the output is
clickable in most cases. Second, HTML and CSS  validation can now be done on
your own computer (and PGTEI as well) and there are checks for unused CSS and
image issues (using the pphtml and ppimage scripts). Third, there is now an
option to view text and images side-by-side without having to click on "See
Image" for each page. For instance you move forward or back one page for both
text and image with the "<" and ">" buttons on the status bar. Also, the Auto
Show Images option lets you see the image for instance for the page you are
spellchecking or for each search hit.

### Other New Features

A "View in Browser" and Hyperlink page numbers buttons on the HTML palette,
tearoff of the Unicode menu, listing small caps in the Word Frequency popup,
automatic checking for updates (which can be turned off), horizontal rules as
css, an option if nothing is found to return to the starting point, better
ability to find executables automatically, GutWrench scanno files are
included, a warning to use human readable filenames, option to include
goodwords in spellcheck project dictionary, a text processing menu to ease
conversion of bold/italics/small caps, the label Image #nnn in Configure Page
Labels is clickable, added Find Transliterations and Find Orphaned Markup
(before it only searched for unmatched brackets) to Search menu, Adjust Page
Markers menu is accessible from the File menu. Most popups now remember if
they have been moved or resized. Unless the user has previously set the size
of the main screen, it is maximized (nearly) on the first run. Added to Word
Frequency buttons to check for ligatures and for an arbitrary regular
expression. For developers, there are internal improvements, including partial
refactoring of functionality into perl  modules and a unit testing framework.

### Bug Fixes

Dash or periods in the proofer's name no longer messes up display of proofers
or removal of page separators. Fixed moving of page markers. The default for
word search from the Word Frequency menu is now "Whole Word". Unicode menu is
now broken into two pieces so it does not run off the screen where Mac users
cannot see it. Also, the Unicode popup has a pulldown list to change UTF
blocks. Replace All now replaces all and is a factor of 10 faster (but not for
regexes). Double click in Word Frequency does whole word search by default.
"--" on a line by itself gets converted to an emdash. Fixed regex editor for
scannos, Ctrl-S saves the file. There is a much higher likelihood that this
version generates valid HTML. Page anchors are no longer placed at the end of
the previous paragraph or before the horizontal rule. Fixed
misplacement/overlapping of HTML page numbers, superscripts are converted to
HTML correctly (Philad^a) without curly brackets. Fixed multiple page markers
at a single location so they do not  overlap but stack vertically like `[Pg
32]<br />[Pg 33]`. Fixed problem with  moving mark left (entry for initial page
number was blank) or up (code was  garbled). Fixed bugs with small caps
conversion; replace all with regex and $1 backreferences, stripping markup
from captions in HTML. Changing the pngs path saves the .bin file immediately.
Multi term searching is sticky even after guiguts is closed and reopened.
Search history keeps track of searches more reliably (but still does not
include scanno searches). Tk TextEdit's FindAndReplaceAll native function goes
into an endless loop if the search term is in the replacement term (replace
"C" with "CC". In such cases, guiguts now reverts to the old very slow method.
Fixed missing space before close of img tag. Gutcheck or HTML Autogenerate on
empty window produces a warning. Fixed Export as Prep Text which left the page
headers if the header did not have enough -'s at the end. In PP HTML, fixed
0:1 report for double blanks. Project dictionary not ignored on restart even
if longer than 8 characters. Reversed order of "Title" and "Caption" in HTML
image popup. Word frequency count is run before any spell check. Toolbar font
is no longer italic for readability. Default poetry left rewrap margin set to
4. Fixed case sensitivity of searches from Word Frequency Popup. Made "Stay on
Top"  preference apply to most popups except Word Frequency. Fixed double
click search on Word Frequency popup to work for strings with nonalphanumeric
characters (',-,--) while searching from Character Cnts does not do a whole
word search. Word search from Word Frequency popup works if the word contains
an apostrophe. Allow search from Word Frequency popup for expressions with
regex metacharacters such as `\`. Made default sort order for the word
frequency list sticky. Made choice of poetry left margin sticky. Made all top
level menus tearoff. More revisions to accommodate non-numeric page markers.
Fixed page numbers when pngs begin with a letter such as "a001.png". Leave out
alt and title tags from `<img ...>` if blank.

### Configuring Side-by-Side Viewing of Text and Images

The side by side image viewing works best if the window for the viewer is
sized to match the image (in XnView, choose View, Auto Image Size, Fit Image
to Window) and only one instance of the viewer is allowed to avoid having one
instance for every page viewed (in XnView, choose Tools, Options, General,
Only One Instance; in Irfanview Options -> Properties/Setting -> Start/Exit
Options, or Options -> Properties/Setting -> Misc.1 Check "Only 1 instance of
IrfanView is active). To page through images, use the "<" and ">" buttons on
the status bar. To Auto Show Page Images, use the "Auto Img" button on the
status bar, use the option on the Prefs menu, or checkboxes in the various
search/spellcheck dialogs.
