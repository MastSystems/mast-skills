# Style & Principles — Starter

A portable, codebase-agnostic distillation of working principles and code style,
adapted for a **React + TypeScript** application. Copy this file into a new repo
as `docs/STYLE-AND-PRINCIPLES.md` (or fold it into `AGENTS.md` / `CLAUDE.md`) and
trim the parts you don't need.

One idea sits above all the others: **claims about a system should be concrete,
tied to the code, and checkable — not prose that drifts the moment the code
changes.** Everything below is downstream of that. This is a guide for how to
write code and the design docs around it; it does not prescribe any particular
process for getting there.

---

## Part 1 — Theoretical principles

These are stack-independent. They govern how you write design docs, comments,
and PR descriptions — anything that makes a *claim* about the system.

### 1. Vagueness doesn't compile

Commit to concrete, falsifiable claims. Hedging words hide the absence of a
decision.

- Ban weasel words in any normative statement: *probably, roughly, some, a few,
  maybe, might, about, around, generally, often, usually, sometimes,
  approximately, reasonably, fairly, quite* — and the weak normative *should*
  when you actually mean *must*.
- Replace "the parser probably recovers" with "the parser emits a partial AST
  and continues." If you can't make it concrete, you don't yet understand it.
- Every important claim should come with an **oracle**: a way to tell whether
  it's true. A test name, an HTTP status code, a literal value, a file path, a
  type. "Returns the right thing" is not an oracle; "returns HTTP `422`" is.

> In React terms: a component's contract is "given props X, it renders Y and
> calls `onChange` with Z" — assertable in a test — not "handles the form
> nicely."

### 2. Describe before you prescribe

When you arrive at unfamiliar code, your first job is to **characterize what it
actually does**, not to legislate what it should do.

- Write findings as "this codebase treats X as Y," not "X should be Y."
- Separate *honest complexity* ("this reducer has 14 branches") from
  *unfamiliarity* ("I haven't read this yet"). Don't disguise the second as the
  first.
- Note the gap between the **espoused** theory (what the README/comments say)
  and the **theory-in-use** (what the code reveals). Flag divergence; don't
  assume the README is right.
- Use the **smell** register: "look here," not "fix this now." A smell grants
  you the right to flag something without having to legislate a fix in the same
  breath.

### 3. Each fact lives in exactly one layer

A single source of truth per fact. When the same fact appears in two places,
they drift, and now you have two facts that disagree.

- **Structure, behavior, and vocabulary** are different kinds of fact:
  - *Nouns and their relationships* → the type/domain-model layer.
  - *Verbs and conditional claims about those nouns* → the logic layer.
  - *The shared alphabet* (shared enums, constants, design tokens) → a single
    vocabulary module everyone imports.
- A term that's load-bearing in a behavioral claim must be anchored in a type.
  If a doc or a function talks about `PaymentGateway` and no type declares
  `PaymentGateway`, the language has drifted and the claim is unmoored.
- When facts leak across layers, don't restate — **reference**. Two docs
  describing overlapping behavior on the same module is a leak: one owns the
  description, the other links to it.

> In React terms: keep a single source of truth for state (lift it, or put it in
> a store/context), derive everything else. Duplicated state is the same smell
> as duplicated facts in prose.

### 4. Pin claims to evidence; make conformance checked, not asserted

A claim that isn't tied to the artifact it describes will rot silently.

- Tie a design doc to the **real code** that satisfies it (link the file or the
  exported symbol). A design doc describing code that no longer exists is worse
  than no doc — keep it current or delete it.
- Prefer **fitness functions** — automated checks — over assertions in prose:
  linters, type checks, tests, architecture-boundary rules (e.g.
  `dependency-cruiser`, ESLint import rules). "Architecture as code" beats an
  architecture diagram that no one updates.
- **But beware the conformance trap.** A green check suite means "no *declared*
  rule was violated," not "the design is sound." Three failure modes to watch:
  1. *Coverage illusion* — checks only catch what you thought to articulate.
  2. *Cementing bad structure* — boundary rules pinned to today's module graph
     can make refactoring harder, not easier.
  3. *Broken-windows inversion* — once people trust the gate, they stop reading
     the code, and drift hides inside conforming structure.

### 5. Separate what's real from what's aspirational

State plainly which parts of the system are shipped versus planned, and don't let
intentions read as guarantees.

- A design doc describes a *plan*; the code is the *fact*. When they disagree, the
  code wins — fix the doc or fix the code, but never leave a doc asserting
  behavior the code doesn't have.
- Mark a design doc's status (e.g. `draft`, `in progress`, `shipped`,
  `superseded`) so a reader knows whether to trust it as current. A `superseded`
  doc should say what replaced it.
- Move in the direction that increases rigor, not less: tighten types, add
  checks, narrow boundaries over time. Loosening a guarantee should be a
  deliberate, visible decision — not silent drift.

### 6. Don't over-formalize

The strongest collective warning from the architecture literature: **don't
produce structure the system doesn't have.**

- Layers, tiers, and categories are *kinds*, not *required tiers*. Use the one
  that fits; skip the rest. A flat app does not need a five-layer diagram.
- For a genuine "big ball of mud," draw a boundary around the mud and name it —
  don't paint clean-architecture labels onto it that it hasn't earned.
- Start with the smallest artifact that delivers value (often: just the behavior
  contracts). Add the structure layer only when you actually need to model
  relationships.

---

## Part 2 — Code style (React + TypeScript)

The reference codebase is small, strict TypeScript. The style below preserves
its spirit — *exact, immutable, fail-fast, domain-organized, self-documenting* —
and adapts it to React.

### Project shape: organize by domain, not by file type

Group code by the part of the product it belongs to, then by role within that
domain. Avoid a top-level `components/`, `hooks/`, `utils/` split that scatters
one feature across the tree.

```
src/
  money/                 # a leaf domain: pure logic + types, no React
    money.ts
    money.test.ts
  accounts/
    account-service.ts   # domain logic (framework-free)
    use-accounts.ts      # the React seam (hook) over the service
    AccountList.tsx       # presentation
  ledger/
    transfer-service.ts
    use-transfer.ts
    TransferForm.tsx
  shared/                # genuinely cross-cutting only
    api-client.ts
  app/                   # composition root: routing, providers, wiring
    App.tsx
    providers.tsx
```

Keep **domain logic framework-free**. A `transfer-service.ts` should not import
React; a hook (`use-transfer.ts`) is the thin seam that adapts it for
components. This keeps the logic testable without a renderer and makes the
behavior contracts (Part 1) pin to plain functions.

### Layer separation — the load-bearing guardrail

This is principle #3 ("each fact lives in one layer") turned into the single most
important structural rule of a React app. Three layers, and **content does not
bleed across them**:

| Layer | Knows about | Must NOT know about |
|---|---|---|
| **Presentation** (`*.tsx`) | domain types, callbacks, render | HTTP, endpoints, wire/DTO shapes, fetching |
| **API / transport** (`api-client.ts`, query fns) | endpoints, HTTP, wire/DTO shapes; maps wire ↔ domain | React, JSX, component state |
| **Domain model** (`*.ts` types + logic) | the shapes the *frontend* actually uses | the backend schema, the network, React |

Concrete guardrails — call these out in review:

- **Strong types at every boundary.** No `any`, no raw `Response`, no
  `Record<string, unknown>` crossing a layer line. If a value moves between
  layers, it moves as a named type. `strict: true` is the floor, not the goal.
- **DTOs are not domain types.** The wire shape the backend sends is a *DTO*; it
  lives in (and never escapes) the API layer. Map it explicitly to a domain type
  at the boundary — an **anti-corruption layer**. When the backend renames a
  field, exactly one mapping function changes; components don't notice.
- **The domain model reflects frontend data usage, not the database.** Model
  what the screens actually need and how they group it — not a 1:1 mirror of the
  backend table or the REST payload. If a view needs a customer's name and their
  unpaid total, that's the domain shape; it doesn't matter that those come from
  three tables and two endpoints.
- **Components import domain types only.** A `.tsx` file importing a DTO, a URL,
  or the fetch client is a layer violation — route it through a hook that returns
  domain types. Presentation receives data and emits events; it never reaches the
  network.
- **Enforce it mechanically** (principle #4). Use `dependency-cruiser` or
  `eslint-plugin-import` boundary rules: presentation → cannot import the API
  layer directly; domain → cannot import React or the API layer; the API layer is
  the only place endpoints exist. A grep for `fetch(` or `axios` outside the API
  layer should return nothing.

> Why this is the guardrail that matters: layer bleed is the failure that
> *compounds*. A vague comment is local; an API shape leaking into 40 components
> is a refactor you'll keep postponing. The boundary is cheap to hold and
> ruinous to recover.

### Type-system reflexes

A handful of habits that, once automatic, eliminate whole categories of bug
before runtime. Reach for these without being asked.

**Algebraic data types — make illegal states unrepresentable.** Model state that
has distinct shapes as a discriminated union, not a bag of optional booleans:

```ts
type RemoteData<T, E> =
  | { status: "idle" }
  | { status: "loading" }
  | { status: "error"; error: E }
  | { status: "ok"; data: T };
```

You can no longer be `loading` and have `data` at the same time, and the
compiler forces every consumer to handle each case. This is principle #1 applied
to types: no ambiguous in-between states.

**Typed IDs — never let a bare `string` stand in for an identity.** A `userId`
and an `accountId` are both strings, so the compiler will happily let you swap
them. Brand them so it won't:

```ts
type UserId = string & { readonly __brand: "UserId" };
type AccountId = string & { readonly __brand: "AccountId" };

function transfer(from: AccountId, to: AccountId): void { /* ... */ }
// transfer(userId, accountId) → compile error, as it should be
```

The same reflex applies to any value that is "a string/number that means
something specific": `Email`, `Iso8601`, `Money` (below). The unit is part of
the type.

**Purity — push side effects to the edges.** Keep the core of each module a
**pure function of its inputs**: no fetching, no clock, no `Math.random`, no
mutation of arguments. Effects live at the boundary (the API layer, a hook, the
composition root). Pure cores are trivially testable and trivially moved; in
React this is exactly why presentational components should be pure functions of
their props and effects belong in hooks.

**Exact values + immutability.** Use exact types where floats lie — the `Money`
type is a currency tag plus integer minor units, because *"floating-point money
is a bug waiting to happen."* Prefer `readonly` fields and immutable data;
construct new values rather than mutating:

```ts
export interface Money {
  readonly currency: string;
  /** Amount in minor units (cents). May be negative for a debit entry. */
  readonly minor: number;
}

export function money(currency: string, minor: number): Money {
  if (!Number.isInteger(minor)) {
    throw new RangeError(`money minor units must be an integer, got ${minor}`);
  }
  return { currency, minor };
}
```

**Single home for every invariant.** (Principle #3, restated as a type reflex:)
each rule about the data lives in exactly one place — usually a constructor or a
smart factory like `money()` above — so there's one choke point to enforce it
and one place to change it. Don't re-validate the same invariant in five call
sites; make the type impossible to construct in an invalid state.

### Fail fast, with named errors

- Validate at the boundary and **throw a named, specific error** rather than
  returning a silent default or letting a bad value flow downstream.
- Refuse to do the meaningless thing: the reference `Money` *refuses to mix
  currencies* rather than producing a nonsense sum.

```ts
export class CurrencyMismatch extends Error {
  constructor(left: string, right: string) {
    super(`currency mismatch: ${left} vs ${right}`);
    this.name = "CurrencyMismatch";
  }
}
```

- In React, surface these at a real boundary: an **error boundary** for render
  errors, and explicit error states in data hooks — never an empty render that
  hides the failure.

### Dependencies are injected, not reached for

The reference services take their collaborators via the constructor — explicit,
swappable, testable.

```ts
export class TransferService {
  constructor(
    private readonly accounts: AccountService,
    private readonly entries: EntryStore,
    private readonly idempotency: IdempotencyStore,
  ) {}
  // ...
}
```

The React analogue:

- Pass dependencies as **props** or via **context/providers** (a `providers.tsx`
  composition root), not module-level singletons imported deep in the tree.
- Keep components honest about what they need: data and callbacks in via props;
  side effects isolated in hooks. A presentational component should be a pure
  function of its props.
- This makes components trivially testable and storybook-able — the same payoff
  the services get from constructor injection.

### Comments explain role and invariants, not mechanics

Doc comments in the reference code state *which domain a unit belongs to*, *what
it's responsible for*, and *which invariants it upholds* — the things you can't
read off the code.

```ts
/**
 * ledger domain — service component, the heart of the system.
 *
 * TransferService moves money between two accounts. It upholds three invariants:
 *   - double-entry: it writes a debit and a credit that sum to zero;
 *   - no-overdraft: the debit is delegated to AccountService, which rejects an
 *     overdraw before any credit is written;
 *   - idempotency: a previously-seen key short-circuits to the prior result.
 */
```

- Comment the *why* and the *invariant*, not the *what* the code already says.
- Inline comments earn their place by flagging something non-obvious: `// No
  overdraft is enforced here: if the debit fails, nothing else runs.`

### Conventions

- **TypeScript `strict: true`.** No implicit `any`; lean on the type system as
  your first fitness function.
- **No emoji** in code, comments, commit messages, or generated output. (Keep or
  drop this one, but decide it once and apply it everywhere.)
- **Naming:** `PascalCase` components and types/classes, `camelCase` functions
  and variables, `use*` for hooks, `kebab-case` for non-component filenames and
  `PascalCase.tsx` for component files.
- **Commit/PR hygiene:** never bypass hooks (`--no-verify`); don't rewrite
  pushed history; keep commit messages concrete (principle #1 applies to them
  too — "fix stuff" is a hedge).

---

## Part 3 — A one-screen checklist

Before you call a change done:

- [ ] No hedge words in any contract, doc, or commit message.
- [ ] Every non-trivial claim has an oracle (a test, a type, a literal).
- [ ] Each fact/invariant lives in one place; nothing is restated, only referenced.
- [ ] Domain logic is framework-free and pure; React is a thin seam over it.
- [ ] Illegal states are unrepresentable (ADTs over boolean bags).
- [ ] Identities and units are typed (branded IDs, exact value types) — no bare
      `string`/`number` standing in for a meaning.
- [ ] Layers don't bleed: components import domain types only; DTOs stay in the
      API layer; the domain model reflects FE usage, not the DB schema.
- [ ] Inputs validated at the boundary; failures throw named, specific errors.
- [ ] Dependencies injected (props/context), not reached for as singletons.
- [ ] Comments explain role and invariants, not mechanics.
- [ ] You described what the code does before prescribing what it should do.
- [ ] You added structure only where the system actually has it.

---

## Lineage (further reading)

The principles above are a practitioner's distillation of a well-trodden body of
work. If you want the original arguments:

- *Describe before prescribe* — Alexander, *The Timeless Way of Building*;
  Feathers, *Working Effectively with Legacy Code* (characterization tests);
  Naur, "Programming as Theory Building"; Hickey, "Simple Made Easy."
- *One fact per layer / bounded language* — Evans, *Domain-Driven Design*;
  Khononov, *Learning DDD*.
- *Conformance checked, not asserted* — Ford, Parsons & Kua, *Building
  Evolutionary Architectures* (fitness functions).
- *Don't over-formalize* — Brown (C4 model), arc42, Kruchten (4+1),
  Rozanski & Woods — all independently warn against producing views the system
  doesn't have.
- *Smells as a pressure-valve* — Fowler, *Refactoring*, ch. 3.
