**************** ENCODING ****************
WINDOWS-1252
**************** INPUT ****************
gutcheck has only a very limited support for windows-1252, but it does
recognise some characters as letters.

Žal at the start of a paragraph would throw a warning if its first letter
wasn't recognised since the paragraph would then appear to start with
something other than a capital letter. Æsop likewise proves that ash is
seen as a letter (otherwise a warning would be given for a period not
followed by a capital letter). Œcolampadius does the same for œthel.

Ÿ-decay is something I don't even pretend to understand, but I'm quite
happy to abuse it to test that strange letter.

Contrawise, we can prove that some characters are _not_ seen as letters
since neither 2×2=4 nor 4÷2=2 produce a warning (if they had been seen
as letters, we would expect ‘Query digit’ warnings).

The trademark symbol ™ and œthel might,for whatever reason, confuse the
column numbers in warnings.

**************** EXPECTED ****************

gutcheck has only a very limited support for windows-1252, but it does
    Line 1 column 1 - Paragraph starts with lower-case

The trademark symbol ™ and œthel might,for whatever reason, confuse the
    Line 17 column 39 - Missing space?
