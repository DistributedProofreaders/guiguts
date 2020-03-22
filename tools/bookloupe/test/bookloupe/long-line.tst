**************** INPUT ****************
Lines up to seventy five columns should be acceptable and shouldn't trigger
any kind of warning. At seventy six columns, however, one warning is issued.

Les élèves ont mangés leur petit déjeuner avant le commencement de l'école.
Les pains au chocolat et les petit brioches sont le choix le plus délicieux.

Unfortunately, with two long lines, we need to drivel on for at least
twenty lines so that more than ninety per cent of the text consists of
non-long lines so that the warnings are not switched off in a misguided
attempt at being helpful.

“I love to sail the briny deep!
  The briny deep for me!
I love to watch the sunlit waves
  That brighten up the sea!
I love to listen to the wind
  That fills the snowy sails!
I love to roam around the deck----”

  “And eat the fishes’ tails!”
**************** WARNINGS ****************
<expected>
  <error>
    <at line="2" column="76"/>
    <text>Long line 76</text>
  </error>
  <error>
    <at line="5" column="76"/>
    <text>Long line 76</text>
  </error>
  <false-positive>
    <at line="5" column="9"/>
    <at line="5" column="10"/>
    <text>Query word au - not reporting duplicates</text>
  </false-positive>
</expected>
