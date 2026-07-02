# REF-IDIOMS

> Shared reference section. The load-bearing `.mspec` body idioms, the march-typing
> quick reference for `.march`/`.mtypes`, and the `invariant.<name>` vs
> `Invariant I<n>` distinction — cited via `Reference:`. Single home for fragments
> A9 (the five `.mspec` idioms + the three lint warnings), A10 (march-typing quick
> reference), and E4 (the rule-oracle-vs-spec-assertion callout). Cited by `orient`
> (Mode-E router) and `spec` (authoring patterns), and by `mine` for the
> march-typing surface.
>
> **Scope boundary (double-home resolution, no-false-merge invariant I3):** the
> general-literature theory that frames *why* these idioms work (Ford-Parsons-Kua
> "atomic vs holistic fitness functions") lives in **REF-THEORY.fitness-functions**;
> this section cross-references it but does not duplicate it. The idioms themselves
> live ONLY here — A14.6 (the A14 "`.mspec` idioms" sub-fragment) routes to this
> section, not to a REF-THEORY sub-pin.

## The five load-bearing `.mspec` idioms (A9)

Beyond the three file kinds, the `.mspec` body grammar carries five structural
idioms whose role is to make rules *mechanically checkable* rather than
rhetorically convincing. Each has a one-line "what it is" and a real example from
the bundled `examples/ledger` corpus.

- **Pipe-block `| ...` constraint bodies** — carry a multi-line literal (regex,
  JSON, EBNF production, CLI invocation, error message). Example from
  `transfer-funds.R2` (mast/3 syntax): `success.journal_shape:` followed by
  `| a successful transfer of 500 minor units from acct-a to acct-b appends exactly two journal entries sharing one transferId: ...`.
  The literal is grep-able; `spec read`/`spec write` keep `| ` lines verbatim, but
  a corpus-wide `mast lint fmt` word-reflows pipe bodies to the `line_width`
  budget (default 180, a `mast.toml` key) — do not rely on interior column
  alignment surviving. Idiomatically used whenever the constraint's value is
  itself a syntactic artifact.
- **`When` clause** — the optional conditional guard between `Given` (preconditions)
  and `Then` (consequence). Example from `transfer-funds.R1`:
  `Given a transfer request arrives at {api.Api} / When the amount in minor units is not positive / Then the transfer is rejected with an InvalidAmount error`.
  The three-part shape splits the trigger from the precondition; rules that pile the
  guard into `Given` are flagged by the **`conditional-given-suggest-when`** lint
  warning.
- **Per-rule `Cites <spec>.R<n>` (or `Cites <spec>.I<n>`)** — a citation line
  directly under the `Rule R<n> [...]` header pinning the upstream rule or invariant
  this rule implements; invariants are citable in mast/3, not just rules. Example
  from `idempotent-transfer.R1`: `Cites transfer-funds.R2`. The lockfile
  (`specs/mast.lock`) pins each citation with a blake3 content-hash of the cited
  entry's canonical body, so silent drift in the upstream surfaces as a linker
  diagnostic (and a non-`fresh` row in `mast cite list`).
- **First-class `Invariant I<n>[.name]` entries** — spec-wide assertions live in the
  rules section as their own headers (no Given/When/Then; prose body plus optional
  inline constraints), not in a preamble block. Example from `transfer-funds`:
  `Invariant I2.double-entry-sums-to-zero [active]` followed by "every transfer
  writes a {debit} and a {credit} whose minor units sum to zero". The `Invariants`
  preamble block is gone; the `I<n>` header provides the namespace, and
  `mast list invariants` enumerates them.
- **`success.<name>` reserved-prefix constraints** — the rule's executable oracle.
  The body MUST carry a falsifiable anchor: pipe block body, backtick code span,
  `$symbol`, double-quoted string, `@file=` path, `{placeholder}`, or numeric
  comparator. Example from `transfer-funds.R1`:
  `success.rejects_zero: a transfer of `0` minor units fails with `InvalidAmount``.
  Pure prose triggers the **`success-criterion-not-falsifiable`** warning — a
  `success.` body without an anchor is checking nothing.

The third companion lint warning, **`must-with-style-language`**, guards the
normative prefixes themselves: a `MUST`-prefixed constraint whose body hedges
with recommendation language (`prefer`, `ideally`, `where possible`, ...) is
flagged to either drop the hedge or downgrade to `SHOULD`/`MAY`.

These idioms are not stylistic preferences; they are the surface that lets
`mast lint check`, the linker, and downstream agents read the spec without
ambiguity. The Ford-Parsons-Kua "atomic vs holistic fitness functions" frame
(**REF-THEORY.fitness-functions**) applies directly: each idiom turns a prose claim
into something a fitness function can interrogate.

## Placeholder traps in prose (E7)

- **Regex brace quantifiers.** `{3}`, `{3,}`, `{3,32}` parse as placeholders
  everywhere in rule/invariant prose — backticks do NOT protect them, and the
  placeholder grammar has no escape. Pin the exact regex in a `Define` entry
  (Define values are not placeholder-parsed) and reference it as `{term}`, or
  describe the repetition in words. Never loosen a pinned regex to dodge the
  `unresolved placeholder` error.
- **`uses` imports resolve in invariants too.** `{Component}` from a
  `uses { component:Component } from <domain>` statement is valid in both rule
  clauses and `Invariant I<n>` bodies; if you don't want the cross-layer
  binding, write the component name as plain prose (no braces).

## The `invariant.<name>` vs `Invariant I<n>` distinction (E4)

These two constructs look alike and are easy to conflate, but they are different and
both still valid in mast/3:

- **`Invariant I<n>[.name]`** is a **spec-wide assertion** — a top-level header in
  the rules section, with a prose body (no Given/When/Then) and optional inline
  constraints. It is enumerated by `mast list invariants`. (Described above as the
  fourth idiom.)
- **`invariant.<name>:` (dotted constraint key)** is a **rule-LEVEL oracle** — a
  reserved-prefix constraint key (alongside `success.<name>`) that lives *inside a
  rule body*, asserting a condition local to that rule. It is **not** a spec-wide
  assertion.

The header creates a namespace; the dotted key is one constraint within a single
rule. Treat them as orthogonal: a spec may carry both.

## march-typing quick reference for `.march` specs (A10)

When working with architecture files, use the march-typing surface consistently:

- Component declarations use **keyword-position kinds**: `service UserService`,
  `gateway PublicGateway`, or generic `component Worker`. Do **not** use the
  **retired suffix form** `component UserService : HTTPService`.
- Non-generic component kinds should be declared in the project `.mtypes` file under
  `ComponentTypes`; `component` is the built-in fallback and never needs a
  declaration.
- A component may declare structural composition with one canonical `composes:` line
  after `expose:` lines, e.g. `composes: AuthMiddleware, RateLimiter`.
- `composes:` entries must resolve to local components or names imported via
  `uses { component:Name } from <domain>`; **self-references and per-domain cycles
  are lint errors.**
- The project `.mtypes` file carries both edge and component vocabularies:

```mtypes
default-edge-type: Connects

EdgeTypes
  edge-type Connects
    transport: in-process
    direction: directed
    description: a component invokes another component in the same process

ComponentTypes
  component-type service
    description: handles application requests
  component-type gateway
    description: crosses a trust or network boundary
```

Run `mast lint check .` (or `mast lint ci .` in CI) after `.march` / `.mtypes`
edits; relevant diagnostics include `edge-type-undeclared`,
`component-type-undeclared`, `composes/unresolved`, `composes/self-reference`, and
`composes/cycle`.
