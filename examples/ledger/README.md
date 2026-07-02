# ledger — a worked `/mast:mine` example

A deliberately small double-entry money-transfer service. It exists so the mast
skills have a **real, self-contained codebase** to point at: clone-free, frozen
in-tree, and already mined into a `.march` / `.mtypes` / `.mspec` corpus under
[`specs/`](specs/).

It is its own mast project (note the local [`mast.toml`](mast.toml)); the root
repo's `.mastignore` excludes `examples/` so this corpus never mixes with
mast's own specs.

## The domain in one paragraph

Customers open **accounts** that hold a balance in a single currency. Money
moves between accounts via **transfers**. Every transfer is recorded as two
ledger **entries** — a debit and a credit — that sum to zero (double-entry).
Transfers carry an idempotency key so a retried request never moves money
twice. An account may never go negative.

## Architecture (what mining recovers)

Three domains, three component kinds, two transports:

```
            http (inbound REST)
                  │
            ┌─────▼─────┐
            │  api      │  Handler  (src/http/api.ts)
            └─────┬─────┘
        ┌─────────┴──────────┐
   in-proc                in-proc
        │                     │
┌───────▼────────┐   ┌────────▼─────────┐
│ accounts domain │   │  ledger domain   │
│  account-service│   │  transfer-service│
│  account-store  │◄──┤  entry-store     │   in-proc (cross-domain)
└─────────────────┘   │  idempotency     │
   store (in-mem)     └──────────────────┘
                          store (in-mem)
```

- **Domains:** `accounts`, `ledger`, `api` (the inbound HTTP boundary)
- **Component types (`.mtypes`):** `service`, `store`, `handler`
- **Edge types (`.mtypes`):** `Handles` (transport `http`, inbound), `Calls` and
  `Persists` (transport `in-process`)
- **Value type:** `Money` (currency + integer minor units)

## Invariants the specs pin

1. **No overdraft** — an account balance never drops below zero.
2. **Double-entry balances** — a transfer's debit and credit sum to zero.
3. **Idempotent transfers** — replaying a key returns the original result and
   moves money exactly once.
4. **Single-currency transfers** — both accounts share a currency.

## Run it

```bash
cd examples/ledger
npm install
npm run dev      # starts the REST API on :3000
```

## Read the mined corpus

```bash
cd examples/ledger
mast list domains
mast list components
mast list specs
mast spec read transfer-funds --with-rules
```

## Language features exercised

This corpus is deliberately authored to demonstrate the **mined-from-real-code**
subset of the `.mspec` / `.march` / `.mtypes` surface, so the mast skills can
point at one worked example. The deliberately synthetic-only productions —
component `extends` in `.march`, a fully retired spec (`status: retired`),
`status: amended`, multiple `Compliance` blocks on one domain, and a
`note:`-proved `!debt` edge — live in the companion corpus
[`examples/grammar-tour/`](../grammar-tour/), which ships alongside this one.
`mast lint ci .` exits 0 (the draft and pending specs' `open:` markers surface
as advisory warnings).

- **Three file kinds** — `.mspec` features, `.march` domains, one `.mtypes`
  vocabulary.
- **Rules** — `Rule R<n>.short-name`, `Given` / `When` / `Then`, normative
  prefixes `MUST` / `MUST NOT` / `SHOULD` / `SHOULD NOT` / `MAY`.
- **Oracles** — `success.<name>` and `invariant.<name>` falsifiable keys, a
  multi-line pipe-block `| …` constraint body.
- **Spec-wide assertions** — `Invariant I<n>.short-name` entries, the bare
  `Invariant I<n>` form, and an inline `success.<name>` constraint under an
  invariant.
- **Structure** — `Define`, `Exports`, `Boundary`, `Targets`, `References`.
- **Cross-spec** — `Depends on`, `extends`, rule and invariant `Cites`
  (content-pinned in `specs/mast.lock`), `uses { component:… } from <domain>`,
  and a `uses { define:… } from <spec>` import of exported defines.
- **Lifecycle** — mostly `active`; `close-account` is a `status: draft` spec
  still carrying `open:` markers; `read-journal` is a `[pending]` planned feature
  with `design:` / `plan:` headers, Design/Plan anchors, and `open:` markers (it
  `extends` `transfer-funds`); `audit-trail` is a `status: queued` sketch with no
  rules yet (queued specs are exempt from completeness checks).
- **Architecture** — typed components (`service` / `store` / `handler`),
  `composes:`, typed + cross-domain `Edges`, an empty-bracket `-[]->` default
  edge, and an `!overreach(pending)` debt annotation with a `reason:`
  continuation on the direct-debit edge.
- **Governance** — a `kind: constitution` spec (`ledger-governance`) with a
  `Tiers` block (including the wildcard `strict: R*` tier), plus per-domain
  `roots:` headers and `Compliance` blocks (`certified` / `pending` / `waive`)
  on the `.march` files.
