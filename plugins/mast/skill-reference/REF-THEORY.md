# REF-THEORY

> Shared reference section. The **conceptual library** behind the mast model — the
> theory `orient`'s Mode-E router points at and answers from. Single home for
> fragment A14, **sub-pinned** into individually-addressable anchors so a
> doctrine-preservation eval can check each one independently (a dropped
> sub-section is a coverage failure). Also the home for A15 (the `examples/ledger`
> worked-example fixture).
>
> **Scope boundary (double-home resolution, RT-2 no-false-merge invariant I3):**
> the A14 *posture sources* (Alexander / Cockburn / Feathers / Naur / Hickey /
> Argyris-Schön) live ONLY in **REF-POSTURE**, and the A14 *`.mspec` idioms* (the
> five load-bearing idioms + lint warnings) live ONLY in **REF-IDIOMS**. This
> section cross-references those two homes where the theory touches them but does
> **not** duplicate them. REF-THEORY's own sub-pins are **five conceptual
> sections** — `cardinality`, `context-maps`, `framework-crosswalk`,
> `fitness-functions`, `spec-theory-pointer` — **plus** the `ledger-fixture`
> (six addressable anchors total).

## REF-THEORY.cardinality

The relationships between mast entities are not all the same shape. The 1976
Entity-Relationship paper (Chen, ACM TODS) calls these *mapping cardinalities*;
modern data-modeling literature splits each cardinality into three orthogonal axes
-- uniqueness, participation, and identification -- and conflating them silently
misleads readers (Halpin, *Information Modeling and Relational Databases*, 2001,
S3.5).

| Relationship | Cardinality (Chen) | Participation (Chen / Elmasri-Navathe) | Identification (IDEF1X / Hay, *Data Model Patterns*, 1996) |
|---|---|---|---|
| feature <-> component (derived from `uses` imports + rule chip refs) | 1:N | **partial** on the feature side (a feature *may* attach to zero components) | non-identifying -- a feature's identity does not depend on any component |
| component <-> domain | N:1 | **total** on the component side (every component belongs to exactly one domain) | **identifying** -- a component is a weak entity whose identity is qualified by `<domain>.<component>` |
| domain <-> domain (via `uses { component: } from`) | M:N | partial both sides | non-identifying -- domains are independent |
| edge <-> edge-type | N:1 | partial on the edge side (empty brackets `-[]->` defer to `default-edge-type`); total when the bracket names a type | non-identifying |
| feature <-> feature (via `extends`) | 1:1 chain (single-parent supertype, per Hay 1996 ch. 2 and Fowler, *Analysis Patterns*, 1997 "Generalization") | partial on both sides | non-identifying |
| project <-> `.mtypes` | uniqueness constraint over a singleton role (ORM, Halpin 2001 S4) -- *not* a 1:1 relationship | total | n/a |

**The trap.** Halpin (2001, S3.5): cardinality glyphs like "1:N" "are notoriously
ambiguous because they conflate uniqueness with mandatoriness." Writing "feature ->
component is 1:N" silently hides three orthogonal facts -- *optionality on the
feature side, mandatoriness on the component side, and the fact that component
identity is independent of the feature attaching to it*. When you describe a mast
relationship in prose, surface each axis separately or accept that the reader will
fill in the wrong defaults.

## REF-THEORY.context-maps

The closed wiring surfaces (`uses { component: } from` imports, rule status-chip
component refs, typed `.march` edges, and `extends`) map onto specific DDD
context-map patterns. Evans, ch. 14, names these relationship shapes; Vernon
(*Implementing DDD*, 2013, ch. 3) restates them with examples.

| mast mechanism | DDD pattern | What it captures |
|---|---|---|
| `uses { component:Name } from <spec>` | **Anti-Corruption Layer** | Evans: "an isolating layer to provide clients with functionality in terms of their own domain model" -- the import is the rebinding boundary. The importing file talks to the named component on its own terms, not whatever the exporting file calls its internal name. |
| `.march` consumed by many other `.march` files | **Open Host Service** | Evans: "Define a protocol that gives access to your subsystem as a set of services. Open the protocol so that all who need to integrate with you can use it." |
| `.mtypes` (project-wide edge alphabet) | **Published Language** | Evans: "Use a well-documented shared language that can express the necessary domain information as a common medium of communication." |
| `extends` on `.mspec` | **Shared Kernel** | Evans: "Designate some subset of the domain model that the two teams agree to share ... this explicitly shared stuff has special status." |
| derived attachment (downstream feature on upstream component, via `uses` + rule chip refs) | **Customer-Supplier** | Evans: "Establish a clear customer/supplier relationship between the two teams. The downstream team plays the customer role to the upstream team." |

**The "what goes at each layer" answer.** Eric Evans (*Domain-Driven Design*,
2003, ch. 2): "Use the model as the backbone of a language. Commit the team to
exercising that language relentlessly in all communication within the team and in
the code." Khononov sharpens it (*Learning DDD*, 2021, ch. 1): ubiquitous language
is *bounded* -- "each bounded context has its own ubiquitous language." Canonical
answer to "should X live in the architecture file or the feature file?": **nouns +
their static relationships -> `.march`; verbs and conditional claims about those
nouns -> `.mspec`; the alphabet of edge kinds -> `.mtypes`**. A term that is not
anchored in some `.march` should not be load-bearing in a `.mspec` -- if a rule
references e.g. `PaymentGateway` and no `.march` declares it, the language has
drifted and the rule's claim is unmoored.

**The caveat that matters for `/mast:mine`.** DDD presumes contexts are already
discoverable -- the team can name them. Evans concedes the **Big Ball of Mud**
pattern (ch. 14) for systems where "models ... are mixed and boundaries are
inconsistent," and his advice there is mostly defensive: draw a boundary around the
mud rather than extending the ubiquitous language into it. For legacy corpora
without coherent domains, prescribing ACL/OHS terminology can manufacture false
structure. The mining skill must mark such regions and quarantine them, not paint
them with DDD labels they have not earned. (This is the DDD-shaped statement of the
descriptive-not-prescriptive posture — the named-source treatment is
**REF-POSTURE.descriptive**.)

## REF-THEORY.framework-crosswalk

The three file kinds parallel level-splits from several canonical multi-view
frameworks. None of them maps perfectly; each contributes a useful word.

- **C4 model (Simon Brown).** `.march`'s Components block corresponds to a C4
  **Component diagram** -- "a grouping of related functionality encapsulated behind
  a well-defined interface" (c4model.com). `.mspec` has no direct C4 analogue; the
  closest is the supplementary use-case / user-story narrative that lives outside
  the four-level core.
- **arc42 (arc42.org).** The `.march` Components block is arc42 S5 *Building Block
  View*: "the static decomposition of the system into building blocks (modules,
  components, subsystems) as well as their dependencies." `.mspec` content lives
  across S3 (Context & Scope) and S10 (Quality Requirements). `.mtypes` is S8
  (Crosscutting Concepts): vocabulary shared across building blocks.
- **Kruchten's 4+1 view (IEEE Software, Nov 1995).** `.mspec` rules are the
  **scenarios (+1)** that bind and validate the other views; `.march` is the
  **Logical view** plus elements of the **Development view**.
- **ISO/IEC/IEEE 42010 (2011).** `.mspec`/`.march`/`.mtypes` are three
  **architecture views**; `.mtypes` is closest to a **viewpoint** -- "the
  conventions for the construction, interpretation and use of architecture views"
  (S3.8). The standard's notion of **correspondence rules** (S5.7) is exactly what
  the derived attachment relation and `uses { component: } from` imports encode.
- **`Documenting Software Architectures` (Bass/Clements/Kazman, SEI).** `.mtypes`
  corresponds to a **style** -- "a specialization of element and relationship
  types, together with constraints on how they may be used."
- **`Software Systems Architecture` (Rozanski & Woods).** `.march` Components map
  to **Functional view** elements: "responsibilities, interfaces, and primary
  interactions" (ch. 17). That triple is the right rubric for a Component's body.

**The unanimous warning.** Every framework above independently cautions against
producing views the stakeholders never asked for. Rozanski & Woods phrase it
sharpest (ch. 19): "Do not force a layered structure on a system that doesn't have
one -- the resulting view will mislead rather than inform." Brown (C4 FAQ): "The C4
model is **not prescriptive** -- if your software system isn't made up of
containers and components, the C4 model isn't going to be a good fit." Kruchten:
"Not all software architecture needs all the views." This is the field's strongest
collective objection to over-formalizing -- and it is the reason mast's three kinds
are *kinds*, not *required tiers*.

## REF-THEORY.fitness-functions

Ford, Parsons & Kua (*Building Evolutionary Architectures*, 2017; 2nd ed. 2023)
coined the working vocabulary for architectures whose conformance is *checked, not
asserted*. The book distinguishes:

- **Atomic vs holistic fitness functions** -- atomic exercises one aspect; holistic
  combines several. `mast lint check .` running per-file lint plus linker verify is
  a holistic composite; an individual diagnostic like `imports/unresolved` is the
  atomic case.
- **Triggered vs continual** -- triggered runs at gate-time; continual runs
  constantly in production. mast's checks are triggered (CI gate via
  `mast lint ci`).
- **Structural vs behavioral** -- structural describes shape (Lakos's "physical"
  design in `Large-Scale C++ Software Design`, ch. 4); behavioral describes runtime
  invariants. `.march` content + `mast graph --edge connects` are structural
  fitness; `.mspec` rules + per-file lint enforce behavioral fitness. The split
  parallels Lakos's physical/logical line exactly.

Other named ideas:

- **Levelization (Lakos, *LSCSSD* S4).** Acyclic, layered physical dependency.
  `mast graph <id> --edge deps --direction out` is a levelization check;
  `edge-type-undeclared` (mast's diagnostic when a `.march` references an edge-type
  not in the project's `.mtypes`) is the "no implicit physical edges" rule applied
  to typed connections.
- **Allowed-edge policies (ArchUnit; dependency-cruiser `forbidden` rules;
  Structure101 architectural slicing).** `mast describe attached <spec-id>` and the
  `connects` graph walker are the mast analogue. ArchUnit's tagline -- "architecture
  as code" -- is the slogan that justifies the whole approach: prose specs drift,
  commands don't.
- **Documentation as code** (the Pragmatic / DevOps lineage) and **executable
  specifications** (Adzic, `Specification by Example`, 2011). This is why the skills
  tell users to *run* `mast describe attached` rather than read the file: the
  command's output is the ground truth; the file is the source the command reads.

**The conformance trap.** Ford et al. themselves (2nd ed., ch. 9): "Fitness
functions can create a false sense of security if they test the easy things and
ignore the hard ones." Three failure modes from the literature:

1. **Coverage illusion** -- green ArchUnit suites can coexist with bad designs;
   rules only catch what was articulated.
2. **Cementing bad structure** (Lakos) -- levelization checks pinned to today's
   component graph make refactoring *harder*, not easier.
3. **Broken-windows inversion** (Hunt & Thomas, `The Pragmatic Programmer`) -- once
   teams trust the gate, they stop reading the code; drift hides inside conforming
   structure.

For mast specifically: `mast lint check` greenness means "no declared rule
violated," not "architecture is sound." The skills repeat this because it is easy to
forget.

## REF-THEORY.spec-theory-pointer

For questions about this project's *own* theory of specification -- what a spec is,
what belongs in one, how a corpus should be read and how it ages -- the explicit
treatment lives in **`docs/spec-theory/`** (the numbered pillar series
`01-excavation.md` … `10-roadmap.md`; the series is the eight-pillar synthesis of
mast's design rationale). Cite it alongside the general-literature sections above
when the question concerns mast's *design rationale* rather than the broader
architecture/data-modeling literature. The general literature (Chen, Halpin, Evans,
Ford-Parsons-Kua, the framework crosswalk) gives an answer intellectual authority;
`docs/spec-theory/` gives the mast-specific stance.

## REF-THEORY.ledger-fixture

[`examples/ledger/`](../../examples/ledger) is a small, self-contained corpus that
lints clean under `mast lint ci` and serves as the worked-example anchor for the
orientation modes (pass `--root examples/ledger` to every command). It is the
golden fixture the differential evals run against (A15). Its shape:

- **Three domains** -- `accounts`, `ledger`, `api` -- with `ledger` as the
  load-bearing one (it both `uses` `accounts` and is governed by a constitution).
- **A deep spec** -- `transfer-funds` carries Define/Exports/Boundary, two
  invariants, a `Cites`, and an `!overreach` debt edge in its domain.
- **A file-to-spec example** -- `src/ledger/transfer-service.ts` is anchored by
  `transfer-funds` and the `ledger-governance` constitution; `mast describe attached
  transfer-funds` shows the derived component set.
- **A posture example** -- the `api` domain is a deliberate, documented departure
  from what mining proposed (mining called `src/http/` "transport, not a domain") --
  a concrete case for the descriptive-not-prescriptive discussion
  (**REF-POSTURE.descriptive**).
