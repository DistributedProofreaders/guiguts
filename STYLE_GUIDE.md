# Style Guide

When adding or changing user interface elements in Guiguts, use this style
guide as a reference. Guiguts was developed by numerous people over many years
and this style guide is very recent, so not all parts adhere to this (yet).

## Dialog buttons

Most Guiguts users are on Windows, so we use the
[Windows UX guide](https://docs.microsoft.com/en-us/windows/win32/uxguide/win-dialog-box)
for dialog button styles.

### Ordering

Dialog buttons are in left-to-right order following the Windows convention:

* OK / Cancel
* Yes / No / Cancel

Note that "OK" should be capitalized.

### OK vs Close

If a button closes a dialog and persists data within it, the button label
should be OK (all uppercase).

If a button closes a dialog but there is not data within it to persist, the
button label should be Close.