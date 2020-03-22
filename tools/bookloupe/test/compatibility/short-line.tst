**************** INPUT ****************
The second line of a paragraph isn't usually short at all
and should be flagged as a warning by gutcheck as long
as there are sufficient numbers of lines in the file to
stop it deciding that there are too many short lines to bother
reporting, which means that I have to waffle on until we have
at least 10 lines of text.

The last line of a paragraph, however many lines it contains,
is usually short.

Even the last line of a paragraph shouldn't consist of only a single
character, since that tends to indicate that the line wrapping may
be fault
y

Contrawise, digits and characters which might be roman numbers are fine:

2

9

I

V

X

L

**************** EXPECTED ****************

and should be flagged as a warning by gutcheck as long
    Line 2 column 54 - Short line 54?

y
    Line 14 column 1 - Query single character line
