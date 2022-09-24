# Ancillary Data
This directory includes ancillary data to support different project languages.

## Dictionaries
The `dict_*_default.txt` files are per-language word lists used by Spell Query.
Each word list includes its own copyright and license in `copyright_dict_*.txt`.

## Labels
The `labels_*_default.rc` files are per-language translations of words like
`Page` and `FOOTNOTES` that will be used when HTML files are generated. The
first time a text file in a particular language is opened, the relevant default
labels file will be copied to a working labels file (`labels_*.rc`). The user
may edit this label file if they wish to adjust the translations. Each labels
file also contains a section with a warning not to edit it - this section
determines the sort order and ASCII display form for characters such as `æ`.
