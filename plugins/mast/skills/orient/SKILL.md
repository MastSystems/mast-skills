---
name: orient
description: "Unified orientation skill: narrative corpus walkthrough, spec deep-dive, task routing, code-to-spec reverse lookup, and conceptual Q&A about the mast model. Use whenever a user asks to \"tour\", \"walk through\", \"explain\", \"give me the lay of the land\", \"what is this codebase\", \"where do I start\", \"show me around\", \"help me understand X\", \"explain the layered model\", \"what's the relationship between spec and arch\", \"what goes at each layer\", \"how does attachment work\", \"what does DDD say about this\", \"which spec governs this file\", \"what spec covers this code\", \"I'm looking at file X\", or asks open-ended orientation or model-level questions about a .mspec corpus. Five modes: corpus overview, spec deep-dive, task routing, file-to-spec reverse lookup, conceptual Q&A."
---

# orient

This skill orients a reader inside a mast corpus read-only: it narrates, tours,
routes, reverse-looks-up, and answers conceptual questions. It never writes — for
editing, hand off to `/mast:spec`.

Reference: REF-BINARY, REF-FILEKINDS, REF-LIFECYCLE, REF-GOVERNANCE, REF-DEPENDENCIES, REF-BLEED, REF-IDIOMS, REF-THEORY, REF-POSTURE, REF-ROUTING, REF-CONVENTIONS
*(Reference sections live in `plugins/mast/skill-reference/` — e.g. `REF-FILEKINDS` resolves to `plugins/mast/skill-reference/REF-FILEKINDS.md`.)*

## Prerequisites

Which binary to invoke is shared doctrine — see **REF-BINARY**: call `mast`
directly (the plugin puts it on Claude Code's PATH), or `./bin/mast` in a repo
that vendors the shim. If `mast` cannot be provisioned, stop and tell the user to
install it before proceeding.

## Intent routing

Route from the user's phrasing, not from mode labels. Default to **Mode A** when in
doubt.

| User says something like ... | Mode |
|---|---|
| "tour the corpus", "what is this codebase", "where do I start", "give me the lay of the land", "show me around" | **A** (corpus overview) |
| "tour checkout-flow", "explain the payments spec", "walk me through auth-middleware" | **B** (focused tour) |
| "I want to add a new linter", "where would I add a CLI subcommand", "I'm trying to fix a CI failure" | **C** (task routing) |
| "which spec governs store/src/corpus.rs", "what spec covers this file", "I'm looking at lint/src/check.rs" | **D** (reverse lookup) |
| "what's the relationship between .mspec and .march", "how does attachment work", "what does DDD say", "explain the layered model", "is this a smell" | **E** (conceptual Q&A) |
| "what governance applies here", "which constitution covers this domain", "what is a constitution in mast", "how do tiers work", "what's the compliance state" | **E** (conceptual Q&A) |

## When NOT to use

The cross-skill routing table and the bypass-gate are shared doctrine — see
**REF-ROUTING**. In particular:

- **The user already speaks the mast model and just wants spec content.** Hand off
  to `/mast:spec` — it is denser per token and round-trippable.
- **The user is editing.** Use `/mast:spec` (handles read, write, and patch). Orient
  does not write.
- **The user is debugging a lint error or cite-hash drift.** Use `/mast:check`, or
  run `mast cite list` directly (its `state` column flags `stale` / `unknown` /
  `missing-lock` citations).
- **The user wants to extract a corpus from an existing codebase.** Use `/mast:mine`.
- **The user wants a scored health check.** Use `/mast:check`.
- **The user has a complex multi-phase implementation to plan or execute**
  (dependency-ordered phases, parallel lanes, TDD cycles, graduation). Use
  `/mast:dag-plan`.

If the user's message already names a specific rule, constraint, or CLI command,
they are past orientation (the bypass-gate, REF-ROUTING). Skip the orientation and
route directly to the relevant skill.

## Read policy across all modes

Reading a corpus is goal-conditioned: every command should reduce uncertainty about
the goal at hand, and the cheapest signals get bought first because they re-price all
later reads. The sequence that works: first a thin orientation sweep —
`mast describe stats`, `mast list specs` (titles and statuses), `mast list domains` —
always, because shape signals recalibrate the value of everything else; second,
anchor the goal to 1-3 specs by matching the goal's vocabulary against titles and
IDs, falling back to dependency fan-in only when no title matches; third, walk the
goal-directed closure. For a refactor or breaking change the inbound closure is the
blast radius (`mast describe inbound <id>`, then
`mast graph <id> --edge deps --direction in` for the transitive radius). For additive
work the outbound closure carries the vocabulary and obligations to satisfy: the
`Depends on` and `extends` parents (the three dependency kinds are shared doctrine —
see **REF-DEPENDENCIES**), plus their Define vocabulary via
`mast list defines --spec <parent>`. For open-ended exploration start at the hubs.
For gap-finding query the complement: low fan-in specs, `mast list pending`,
`mast list rules --status pending`, and components with no spec attached (cross-check
`mast list components` against `mast describe attached <spec-id>` over candidate specs
— there is no single inverse command). Fourth, deepen into rule bodies, interleaving
them with header and edge reads rather than exhausting all structure before any
content — the best comprehenders cross-reference; they do not complete a structural
pass first.

**Pricing a closure before reading it.** Before deepening into a modification target,
price its one-hop closure with two commands plus one per neighbor:
`mast spec read <id> --with-blocked-by` (outbound, with status),
`mast describe inbound <id>` (inbound), then
`mast list rules --spec <neighbor> --count` for each neighbor under consideration.
Read full bodies only where price and scent justify it — a transitive closure read
whole can run to tens of thousands of tokens that a priced one-hop slice avoids.

**Stopping rules.** Three, stacked. When two consecutive reads change no decision,
stop — the marginal read is no longer paying. Enumerate the goal's questions up front
and stop when each is answered or provably unanswerable from the corpus; an
unanswerable question is itself a finding (a gap), not a reason to keep reading. And
for any goal that modifies specs or governed code, never stop before the one-hop
inbound and outbound closure of the touched specs has at least been priced (titles,
statuses, rule counts), even when scent there is weak — missed non-local interactions
are the canonical as-needed-reading failure, and the graph makes the closure cheap to
enumerate. Be systematic over the closure of the change, as-needed everywhere else.

**Landmarks: degree and status are not authority.** Shape signals lie about
importance exactly where stakes are highest. In this repo, `specs/core.mspec` is
status `draft` with 0 rules and a fan-in of 1 (from a retired spec) — and it carries
the architectural invariants AGENTS.md treats as constitutional; conversely, the
highest fan-in usually measures plumbing, not authority. Read
`mast list constitutions` and any architectural-invariant spec (here, `core`) in
every exploration regardless of what their shape signals say. There is no
machine-readable importance signal independent of topology yet; the AGENTS.md push
channel and this paragraph are the workaround.

**Search semantics and their workarounds.** `mast list specs --search` matches spec
ID and title only — rule bodies, constraint keys, and Given/When/Then text are not
searchable from the CLI, and `mast list rules` prints IDs, statuses, and constraint
counts, not text. `mast list defines --search` DOES search define bodies and is the
best lexical probe for a vocabulary term. Plain `rg` over the specs directory is
sanctioned for surveys, with one caveat: the corpus may spell a concept differently
from the user's phrasing or a lint finding's name, so a zero-hit grep proves
vocabulary mismatch, not absence. `mast describe inbound` lists retired dependents
undifferentiated from live ones — check the status of every listed dependent before
pricing a blast radius. Finally, a `fresh` row in `mast cite list` certifies the
upstream rule's text is unchanged since it was pinned, so a fresh cite substitutes
for re-reading the upstream rule; a `stale` row is a scheduled re-read.

## Modes / playbooks

### Mode A -- Corpus overview

Use when the user says any of: "tour the corpus", "what is this codebase", "where do
I start", "give me the lay of the land", "show me around this repo".

> Mast is the orchestrating tool, not the subject. The corpus belongs to whatever
> repo `mast` is running in — it could be `mast-spec` itself, or `acme/widget`, or
> any other project using `.mspec`. Discover the repo's identity from its own corpus
> and AGENTS.md; never assume it is mast-spec.

**Gather** (the calls below are sufficient — do not fan out per-spec):

```bash
mast list specs
mast describe stats
mast list deps
mast list extends
mast list invariants --count   # corpus-wide `Invariant I<n>` count (cross-cutting assertions live in the rules section, not a preamble block)
mast list patterns --count     # structural motif count (0 = skip patterns in narrative)
```

If the corpus carries architecture content (any `.march` files), add
`mast list domains`, `mast list components`, and `mast list edge-types` (surfaces the
project's `.mtypes` vocabulary). The three file kinds and how features attach to
architecture are shared doctrine — see **REF-FILEKINDS**. Skip these calls entirely
when the corpus has no `.march` files — there is no signal to surface.

If `mast list patterns --count` returns > 0, add `mast list patterns` (full inventory
with kinds, participants, confidence). If `mast list constitutions` returns rows, add
it (governance constitutions with tier counts and certification status); the
constitution / tiers / Compliance / ratchet model is shared doctrine — see
**REF-GOVERNANCE**.

Read the root `AGENTS.md` if it exists — it is the canonical anchor for the repo's
own architectural narrative. Also read any nested `*/AGENTS.md` files under top-level
directories. If no `AGENTS.md` exists anywhere, derive the architectural framing from
the spec set itself: look for specs whose IDs imply architectural concerns (common
names include `core`, `architecture`, `layers`, `topology`, but the repo may use any
naming) and read those via `mast spec read <id> --no-inbound`. If still nothing, work
directly from the Targets blocks of the highest-fan-in specs.

Compute load-bearing specs in memory: parse the tab-separated `mast list deps`
output, count how often each spec appears as a dependency target (column 3), take the
top 5 by fan-in. Fan-in identifies load-bearing plumbing, not authority: apply the
landmark correction from the read-policy section and include the constitutions plus
any architectural-invariant spec in the narrative even when their shape signals say
to skip them.

**Render** in this order, **~350 words total**:

1. **One paragraph: what this repo is and its top-level shape.** Name the repo (from
   `AGENTS.md` heading or the working directory) and describe its layering as the
   corpus itself reveals it. Different corpora have different shapes — read it from
   the Targets and AGENTS.md, do not assume. Surface one or two cross-cutting
   invariants if any architectural spec carries them.
2. **The corpus at a glance.** Status counts from `describe stats`. Two sentences max.
3. **Three to five load-bearing specs** by inbound dep count. For each: one sentence
   on what it owns, one on who depends on it.
4. **One paragraph grouping the rest of the corpus** by topic prefix or area. Two or
   three specs per group max. If the corpus has fewer than 15 specs, skip the
   grouping and list every spec in one sentence each.
5. **The author's loop.** Two sentences. `mast spec read` to view,
   `mast spec write` / `mast spec patch` to change, `mast cite ack` (after editing a
   rule body other specs cite) and `mast lint check` to verify. Direct file edits on
   `.mspec` are blocked by the PreToolUse hook.
6. **Three concrete next moves**, each one sentence: a `/mast:orient <spec>` for the
   most likely starting spec, a `mast` command for the most likely next task, and a
   doc pointer (the relevant `AGENTS.md`, otherwise the highest-fan-in spec).

If patterns were detected, add one short paragraph summarizing the most notable
structural motifs — up to 3 high-confidence healthy patterns as strengths, and flag
any anti-patterns (e.g. `circular-dependency`, `boundary-breach`,
`articulation-point`) with one sentence each, suggesting `/mast:check` for the full
audit. Do not list all kinds — surface only patterns the engine actually found. If
`mast list constitutions` returned rows, add one paragraph on the governance layer
(name each constitution and status, how many domains are fully certified vs.
certifying, the tier names); use `mast describe constitution <id>` only if there are
two or fewer constitutions.

**Budget.** ~350 words. Restraint matters more than completeness — the goal is
orientation, not coverage.

### Mode B -- Focused tour of one spec

Use when the user names a spec: "tour the checkout flow spec", "explain the
payments-contract spec", "walk me through the auth-middleware".

**Gather** (minimal — the spec body already carries outbound deps):

```bash
mast spec read <id> --with-rules
mast describe inbound <id>
mast list cites --to <id>          # rule-level citers (which describe inbound omits)
mast cite list                     # filter to <id> client-side; the state column flags drift
mast describe attached <id>        # architecture components this spec attaches to (when .march files exist)
mast list patterns --format json   # filter client-side for patterns where <id> appears in participants
```

If the spec has a non-empty `extends`, run
`mast graph <id> --edge extends --direction out` to walk the full chain — don't stop
at depth 1 (the dependency-kind semantics are shared doctrine — see
**REF-DEPENDENCIES**). If `mast describe attached` returns a non-empty set, mention
the architecture components by name — that is the spec's architectural footprint, and
it is the signal that prevents `.mspec` prose from drifting into untethered
behavioral claims (the bleed detector — see **REF-BLEED**).

When listing the spec's Targets and References, note the **anchor kind** of each
entry using the six-variant AnchorKind taxonomy and the `blocks_graduation()`
predicate (Design and Plan only) — shared doctrine, see **REF-LIFECYCLE**. Surface
the spec's `design:` and `plan:` extension headers as links in the narrative. For a
New/Draft spec the presence of those links is healthy and expected; for an Active
spec the opposite holds — a remaining Design/Plan anchor or `design:`/`plan:` header
is a lifecycle smell, because `graduate()` should have superseded those design-phase
artifacts.

Filter the `mast list patterns` output for entries whose `participants` list includes
`<id>`; weave matches into the narrative (sections 2 or 6). If you need a rule's
citers, use `mast describe cited-by <spec-id> R<n>` (or `I<n>.name`). If the spec's
Targets overlap a governed domain, run `mast describe governance-for <target-path>`
to surface the domain, constitution, tier, and compliance state (the governance model
is shared doctrine — see **REF-GOVERNANCE**).

**Render**, **~400 words total**:

1. **One-paragraph "what this spec is for"** — distill title, Boundary `in`, and the
   rule set into prose. State the spec's single responsibility in your own words.
2. **Where it sits.** Which crate(s) it targets, which layer those crates occupy, and
   how it relates to its `Depends on` parents. If `extends` is set, name the parent
   and what is inherited.
3. **Who depends on it.** One sentence per inbound spec: "X depends on this because it
   needs Y." Check each dependent's status first — `describe inbound` does not
   distinguish retired dependents. Add a sentence on rule-level citers if notable.
4. **Rule-by-rule narrative.** One sentence per active rule. Skip `[retired]` rules
   unless they explain history that affects the current model. Translate `MUST`
   constraints into prose.
5. **Boundary callouts.** What is explicitly excluded (`Boundary out:`) and which
   sibling specs own those concerns. The most under-used signal for orientation.
6. **Common pitfalls** (three or fewer, sourced from observable corpus state):
   filename drift (compare `file_path` to `<spec-id>.mspec`); cite-hash drift (rows
   in `mast cite list` involving `<id>` whose `state` is not `fresh`); retired rules
   with non-empty bodies still resolving placeholders.
7. **Next moves.** Two or three. End with the most likely next `mast` command
   verbatim so the user can paste it.

**Budget.** ~400 words.

### Mode C -- Task routing

Use when the user describes an intent: "I want to add a new linter", "I'm trying to
fix a CI failure", "I need to write a spec for X", "where would I add a new CLI
subcommand".

**Gather.** Parse the intent into 2-4 keywords. Run:

```bash
mast list specs | grep -i "<keyword>"
```

Filter the tab-separated spec listing for keywords in titles or IDs — this listing
and `--search` cover ID and title only, never rule bodies. For vocabulary terms,
`mast list defines --search "<keyword>"` searches define bodies and is the best
lexical probe; `rg "<keyword>" specs/` is fine for a survey, but treat zero hits as
inconclusive (the search-semantics caveat in the read policy). For each candidate
spec, run `mast describe inbound <id>` to map the neighborhood.

**Render**, **~300 words total**, in this order:

1. **The routing, up front.** "To do X, edit Y via `/mast:spec`." Name the 2-4 specs
   that govern the task. The user wants to act — open with the routing, then justify.
2. **Two-or-three sentences per spec** explaining what each owns and which rules will
   likely change.
3. **Order of operations** if multiple specs need edits — touch the contract spec
   first; touch consumers after. Call out cross-spec risks: shared Defines, cite-hash
   invalidations, layered dep chains.
4. **Pre-flight hook.** Recommend `/mast:check` (pre-flight mode) before starting any
   multi-step edit.
5. **Implementation handoff.** If the task is implementing spec rules in code (rather
   than editing specs), hand off to `/mast:dag-plan` — it plans the
   dependency-ordered phases, drives the TDD cycle, and manages graduation.

**Budget.** ~300 words. Open with the routing; the user wants to act.

### Mode D -- Reverse lookup ("what spec governs this file?")

Use when the user points at a source file: "which spec governs store/src/corpus.rs",
"what spec covers this code", "I'm looking at lint/src/check.rs — what should I read
first?".

**Gather.** Extract the file path from the user's message. Normalize it relative to
the repo root.

```bash
# Step 1: search spec Targets for the file's crate or path prefix
mast list targets
# Filter the tab-separated output for entries whose target paths
# overlap the queried file's directory or crate

# Step 2: search architecture components for the enclosing module
mast list components
# Match by crate/directory -- e.g. store/src/corpus.rs belongs to
# whichever component's path set includes store/

# Step 3: find attachment relationships, for each candidate spec from step 1
mast describe attached <spec-id>
```

If `mast list targets` returns no match, fall back to the directory-based heuristic:
walk up from the file's directory to the nearest crate root or module boundary, then
search for specs whose Targets reference that crate. If still nothing, the file is
ungoverned — say so explicitly and suggest `/mast:mine` to draft coverage.
Additionally run `mast describe governance-for <file-path>`: governance binds through
domain `roots:` prefix matching, not spec-level Targets (shared doctrine — see
**REF-GOVERNANCE**). When the queried path is a `.md` doc under `docs_dir`, the lookup
is different — a design/plan doc is rarely a Target; instead a spec points *at* it
through a `design:`/`plan:` extension header. Filter `mast list specs` to New/Draft
specs and scan their printed headers for one whose `design:`/`plan:` value matches the
queried doc; report that spec as the answer, or say the doc is unlinked if none does.
(The AnchorKind suffix-decides-kind rule behind this is shared doctrine — see
**REF-LIFECYCLE**.)

**Render**, **~200 words total**:

1. **The answer, up front.** "This file is governed by `<spec-id>` (and optionally
   `<spec-id-2>`)." Name every spec whose Targets block covers the file.
2. **Architecture context.** If the file belongs to a `.march` component, name the
   component and its domain. One sentence. If the file is in a governed domain, report
   the domain, constitution, tier, and compliance state here.
3. **Attachment map.** Which features attach to the component this file lives in. One
   sentence per feature, max three.
4. **Entry point.** The single `mast spec read <id> --with-rules` command to run next.
   If multiple specs govern, recommend the narrowest-Targets-scope spec first.

**Budget.** ~200 words.

### Mode E -- Conceptual Q&A (thin router)

Use when the user asks a model-level question about mast: "what's the relationship
between .mspec and .march", "how does attachment work", "what does DDD say about
this", "is this a smell", "explain the layered model", "what goes at each layer". This
mode is knowledge-only — it does not author, read, or run anything against the live
corpus. For questions that need live corpus data, combine with Mode A or Mode B.

**Gather.** None against the corpus. Mode E is a **router**: classify the question,
then answer *from* the cited reference section rather than restating a textbook here.
The conceptual library is sub-pinned in the reference layer so each answer cites a
named, individually-addressable source.

| Question is about ... | Answer from |
|---|---|
| how mast relationships are shaped (1:N, N:1, M:N; optionality/identification) | **REF-THEORY.cardinality** (Chen / Halpin) |
| how the layers couple; "what goes in `.march` vs `.mspec` vs `.mtypes`"; ubiquitous language | **REF-THEORY.context-maps** (DDD context maps; Evans/Vernon) |
| which architecture framework's vocabulary fits; multi-view modeling | **REF-THEORY.framework-crosswalk** (C4 / arc42 / 4+1 / 42010 / SEI) |
| why detection is run rather than asserted; "what does green lint actually prove" | **REF-THEORY.fitness-functions** (Ford-Parsons-Kua + the conformance trap) |
| mast's *own* theory of specification (what a spec is, how a corpus ages) | **REF-THEORY.spec-theory-pointer** → `docs/spec-theory/` |
| "is this a smell?", describe-don't-prescribe, characterization vs specification | **REF-POSTURE.descriptive** (Alexander / Cockburn / Feathers / Naur / Hickey / Argyris-Schön) |
| the load-bearing `.mspec` idioms (pipe-block, `When`, `Cites`, `Invariant`, `success.`); `invariant.<name>` vs `Invariant I<n>`; march-typing | **REF-IDIOMS** (A9 / A10 / E4) |
| the three file kinds and derived attachment | **REF-FILEKINDS** |
| spec/rule lifecycle, the anchor ratchet, the six AnchorKind variants | **REF-LIFECYCLE** |
| each-fact-one-layer; symptom→layer→fix | **REF-BLEED** |
| constitutions, tiers, compliance, the ratchet | **REF-GOVERNANCE** |

Cite the named sources in the section when making claims — the citations give the
answer intellectual authority and let the user follow up. Cite `docs/spec-theory/`
alongside the general literature when the question concerns mast's *design rationale*
rather than the broader field. For actually creating, editing, reading, or mining
files, hand off to `/mast:spec` or `/mast:mine`.

**Render.** Answer the question in prose, anchored to the cited section's named
sources. Do **not** restate the textbook in-body — point at the section and answer
from it. Keep it tight: a focused conceptual answer, not a survey. End with a concrete
next move (a `mast` command if the question has a live-corpus dimension, or a
`/mast:spec` / `/mast:mine` hand-off if it is about authoring).

**Budget.** Proportional to the question — one tight conceptual answer, not a tour of
every cited section.

## Style rules across all modes

The no-emoji rule is a project convention — see **REF-CONVENTIONS**. The rest are
orient-specific:

- **Prose, not bullets.** Use bullets only for three or fewer items where order does
  not matter.
- **Quote IDs verbatim.** `checkout-flow.R2`, not "the second rule of the checkout
  flow spec".
- **Anchor architectural claims to a spec or file** — but the opening paragraph in
  each mode can be plain English. Don't lard every sentence with brackets.
- **Don't paraphrase normative prefixes.** Summarize the rule's intent in your own
  words instead.
- **No emoji, no headers below H2.** One continuous narrative with at most H2 section
  breaks.
- **End with a concrete next command** the user can paste.

## Worked example

The `examples/ledger/` corpus is the practice fixture for these modes (pass
`--root examples/ledger` to every command); its full shape — three domains, the
`transfer-funds` deep spec, the `src/ledger/transfer-service.ts` file→spec example,
and the `api`-domain posture case — lives in **REF-THEORY.ledger-fixture**.
