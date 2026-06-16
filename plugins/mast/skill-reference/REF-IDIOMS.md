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
rhetorically convincing. Each has a one-line "what it is" and a real corpus
example.

- **Pipe-block `| ...` constraint bodies** — preserve a multi-line literal (regex,
  JSON, EBNF production, CLI invocation, error message). Example (mast/3 syntax):
  `MUST sentinel_detection:` followed by
  `| after each runner invocation , `mast loop run` evaluates three conditions: ...`.
  The literal is grep-able and the formatter preserves each `| ` line as-is.
  Idiomatically used whenever the constraint's value is itself a syntactic artifact.
- **`When` clause** — the optional conditional guard between `Given` (preconditions)
  and `Then` (consequence). Example from `release-conventions.R3`:
  `Given a push to main adds commits ... / When at least one added commit is a {release_cutting_type} / Then the {release_please_gate} MUST open a release PR ...`.
  The three-part shape splits the trigger from the precondition; rules that pile the
  guard into `Given` are flagged by the **`conditional-given-suggest-when`** lint
  warning.
- **Per-rule `Cites <spec>.R<n>` (or `Cites <spec>.I<n>`)** — a citation line
  directly under the `Rule R<n> [...]` header pinning the upstream rule or invariant
  this rule implements; invariants are citable in mast/3, not just rules. Example
  from `ci-gates.R4`: `Cites release-conventions.R1`. The lockfile
  (`specs/mast.lock`) pins each citation with a blake3 content-hash of the cited
  entry's canonical body, so silent drift in the upstream surfaces as a linker
  diagnostic (and a non-`fresh` row in `mast cite list`).
- **First-class `Invariant I<n>[.name]` entries** — spec-wide assertions live in the
  rules section as their own headers (no Given/When/Then; prose body plus optional
  inline constraints), not in a preamble block. Example from `data-plane`:
  `Invariant I3.zero_deps [active]` followed by "the store/ package and every file
  within it imports only Go standard library packages and other packages within the
  ... module". The `Invariants` preamble block is gone; the `I<n>` header provides
  the namespace, and `mast list invariants` enumerates them.
- **`success.<name>` reserved-prefix constraints** — the rule's executable oracle.
  The body MUST carry a falsifiable anchor: pipe block body, backtick code span,
  `$symbol`, double-quoted string, `@file=` path, `{placeholder}`, or numeric
  comparator. Example from `release-conventions.R1`:
  `success.title_accepted: a PR titled `feat(lang): add dotted key support` passes the check`.
  Pure prose triggers the **`success-criterion-not-falsifiable`** warning — a
  `success.` body without an anchor is checking nothing.

These idioms are not stylistic preferences; they are the surface that lets
`mast lint check`, the linker, and downstream agents read the spec without
ambiguity. The Ford-Parsons-Kua "atomic vs holistic fitness functions" frame
(**REF-THEORY.fitness-functions**) applies directly: each idiom turns a prose claim
into something a fitness function can interrogate.

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
