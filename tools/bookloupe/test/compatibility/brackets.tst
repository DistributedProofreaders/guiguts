**************** INPUT ****************
This (excellent paragraph has one more {opening} paranthesis than closing.

On the other hand, this poor) paragraph does it backwards.

This {slightly odd paragraph has one more [opening] brace than closing.

And again, this balmy} paragraph does it backwards.

This paragraph[11 has one more (opening) bracket than closing.

Whereas this one is 12]tupsy turvey.

This _very_ important_ paragraph has an odd number of underscores.

Unspaced brackets are a[most a]ways _wrong_.
**************** EXPECTED ****************

This (excellent paragraph has one more {opening} paranthesis than closing.
    Line 2 - Mismatched round brackets?

On the other hand, this poor) paragraph does it backwards.
    Line 4 - Mismatched round brackets?

This {slightly odd paragraph has one more [opening] brace than closing.
    Line 6 - Mismatched curly brackets?

And again, this balmy} paragraph does it backwards.
    Line 8 - Mismatched curly brackets?

This paragraph[11 has one more (opening) bracket than closing.
    Line 10 - Mismatched square brackets?

Whereas this one is 12]tupsy turvey.
    Line 12 - Mismatched square brackets?

This _very_ important_ paragraph has an odd number of underscores.
    Line 14 - Mismatched underscores?

Unspaced brackets are a[most a]ways _wrong_.
    Line 15 column 23 - Unspaced bracket?

Unspaced brackets are a[most a]ways _wrong_.
    Line 15 column 30 - Unspaced bracket?
