# REF-POSTURE

> Shared reference section. The descriptive-not-prescriptive posture, cited via
> `Reference:`. **First-class single home** for fragment A8 — and the canonical home
> for the A14 *posture sources* (the double-home resolution routes A14.5 here, not
> to a REF-THEORY sub-pin, so the six named sources live in exactly one place).
> Cited by `orient` (Mode-E router), `mine` ("characterization-not-specification"),
> and `spec`.

## REF-POSTURE.descriptive

Mast is deployed into arbitrary codebases. Some are well-factored; some are not. The
skill prose must work in both cases without editorializing. The canonical move comes
from the pattern-language and legacy-code traditions:

- **Christopher Alexander, `The Timeless Way of Building` (1979)**: "The patterns
  are not invented ... they are *discovered*." Patterns describe forces already at
  play in successful buildings; they are not rules imposed by the architect. In mast
  prose: replace "the architecture is X" with "we observed X recurring in this
  corpus."
- **Alistair Cockburn, "Hexagonal Architecture" (2005)**: "I did not invent this ...
  I just noticed people doing it and gave it a name." When documenting a repo's
  layering, *name what's there* rather than legislate.
- **Michael Feathers, `Working Effectively with Legacy Code` (2004), ch. 13 --
  characterization tests**: "A test that characterizes the actual behavior of a
  piece of code. We aren't writing it to specify what the code should do, but to
  *find out what it actually does*." First-contact with any onboarded codebase is
  characterization, not specification. The mining skill's first pass produces
  *findings*, not *prescriptions*.
- **Peter Naur, "Programming as Theory Building" (1985)**: "The death of a program
  happens when the programmer team ... is dissolved. The theory built by that team
  has been lost." Treat existing idiosyncrasies as residue of theory we don't yet
  share, not as defects. Phrase findings as "this repo treats X as Y" rather than "X
  should be Y."
- **Rich Hickey, "Simple Made Easy" (Strange Loop, 2011)**: "Simple is an objective
  notion. Easy is relative." Don't disguise "we haven't read it yet" as "this code
  is complex." Separate honest complexity reports from unfamiliarity.
- **Argyris & Schon, `Theory in Practice` (1974) -- theory-in-use vs espoused
  theory**: what practitioners *say* they do versus what their artifacts reveal. The
  mining skill must surface both and flag the divergence; assuming the README is
  accurate is a category error.

**The smell pressure-valve.** Fowler, `Refactoring` (1999, ch. 3): "A smell is
something that's quick to spot ... no set of metrics rivals informed human
intuition." Calling something a *smell* preserves the right to flag without
legislating: it says "look here," not "fix this now." Mast's bleed taxonomy is
written in this idiom -- every entry is a *symptom*, not a *violation*.

**The line not to cross.** Pure description of chaos becomes useless. Larsen & Derby
(`Agile Retrospectives`, 2006) call this "data without theme" -- readers drown. Beck
(`Smalltalk Best Practice Patterns`, 1997): "If you simply imitate what you see, you
will imitate the mistakes along with the successes." So: when describing a hairy
convention, the prose answers two questions explicitly -- *what does the corpus do
here* (theory-in-use) and *which existing spec or `AGENTS.md` sentence would tell us
whether this is intentional* (espoused theory). If neither can be answered, mark it a
smell and move on; do not paper over the gap with confident-sounding architecture
claims.
