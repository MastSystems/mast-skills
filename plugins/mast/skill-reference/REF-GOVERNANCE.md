# REF-GOVERNANCE

> Shared reference section. The **generic** governance model only, cited via
> `Reference:`. Single home for fragment A6's generic model. The **check-specific
> audit judgments** (the blanket-cert "indistinguishable from ceremony" smell, the
> severity-modulation truth table, stats-vs-constitution reconciliation) are NOT
> generic and are NOT here — they stay absorbed by the `check` skill (RT-2
> BLOCKER-2, no-false-merge invariant I3). Merging them here would either drop them
> or pollute the reference the `start` / `mine` skills cite.

## Constitutions and tiers (A6)

A **constitution** is a special `.mspec` file declared with `kind: constitution`.
It declares governance rules organized into **tiers**:

- Tiers form a **total order**, from least to most restrictive.
- Each tier is a **monotonic superset** of the one below it.
- Tiers list **rules only** — never invariants.

Concrete example: the bundled `examples/ledger` corpus's `ledger-governance`
constitution declares a `baseline` tier (`R1, R2`), a `standard` tier
extending it (`baseline + R3, R4`), and a `strict` tier (`R*`, the every-rule
wildcard) — each tier a superset of the one below.

## Compliance (A6)

Domains (`.march` files) opt into governance by declaring:

- **`roots:`** — the directories the domain owns.
- A **`Compliance <constitution>`** block — names the tier it enforces (via
  `enforces:`) and lists the per-rule certification state.

Compliance is tracked **per rule**, in one of three states:

| State | Meaning | Violation severity |
|-------|---------|--------------------|
| **certified** | the rule is enforced here | **error** |
| **pending**   | the rule is acknowledged but not yet enforced | **warning** |
| **waived**    | the rule is intentionally not enforced (with justification) | **info** |

## The ratchet (A6)

Governance ratchets **forward**: once a domain certifies a rule, it cannot
uncertify it. Certification is monotone — the corpus can only become more governed
over time, never less.

## Governance as fitness functions (A6, conceptual)

The governance model maps onto the Ford-Parsons-Kua fitness-function taxonomy (see
`REF-THEORY.fitness-functions`): each constitution rule is an **atomic, triggered,
structural** fitness function; the constitution itself is a **holistic** fitness
function composing its rule set; and the tier mechanism adds a **graduation path** —
a domain adopts the least-restrictive tier first and ratchets upward.

**Severity modulation** is a pure **3-axis** function of *compliance state ×
constitution status × rule chip*: certified is always **error**, waived always
**info**, pending depends on lifecycle caps. (The full modulation truth table and
the blanket-certification "indistinguishable from ceremony" smell are
**check-specific audit doctrine** and live in the `check` skill, not here — RT-2
no-false-merge carve-out.)
