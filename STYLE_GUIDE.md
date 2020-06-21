# Style Guide

When adding or changing user interface elements in Guiguts, use this style
guide as a reference. Guiguts was developed by numerous people over many years
and this style guide is very recent, so not all parts adhere to this (yet).

## Menus

Menu items that open up a dialog should end with "...".

## Dialogs

Most Guiguts users are on Windows, so we use the
[Windows UX guide](https://docs.microsoft.com/en-us/windows/win32/uxguide/win-dialog-box)
for dialog styles.

### Title

If a dialog is used solely to set values, the menu item or button that loads
the dialog should start with a verb, eg: "Set File Paths..." and the dialog
title should be a noun, eg: "File Paths". These dialog should have an "OK"
button (and possibly a "Cancel" button). More on this below.

Dialogs that present a tool palette for manipulating the page text should
be accessed via the menu with the name of the dialog, eg: "Spell Check...".

### Button ordering

Dialog buttons are in left-to-right order following the Windows convention:

* OK / Cancel
* Yes / No / Cancel

Note that "OK" should be capitalized.

### OK vs Cancel vs Close buttons

If a button closes a dialog and persists data within it, the button label
should be OK (all uppercase).

If a button closes a dialog with data but does not persist it, the button label
should be Cancel.

If a button closes a dialog but there is not data within it to persist, the
button label should be Close.