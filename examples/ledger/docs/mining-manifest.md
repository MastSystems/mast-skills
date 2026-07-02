# Mining proposal manifest — `examples/ledger`

Scope: `examples/ledger`, depth=standard, languages=TypeScript, cap=all
Mode: characterization, not specification — harvested from observed behavior; intent unconfirmed

This manifest is the output of a worked `/mast:mine` run (Phases 1–5, 5 sub-agents:
1 Opus architecture sketch, 2 Sonnet domain extractions + 1 Sonnet type-vocabulary,
1 Opus feature inventory). It is the reference example the mast skills point at.

> **Status: LANDED.** All proposals below were approved and written to `specs/`
> via `mast spec create`/`write` (`vocabulary.mtypes` + `accounts.march` +
> `ledger.march` + `api.march` + 4 `.mspec` features). `mast lint ci examples/ledger`
> passes clean. Because the human (the approver) confirmed intent at landing, the
> harvested rules shed their provisional `open:` markers and landed as `active`.
>
> **Landing-time deviation from the mining:** Phase 1 honestly classified
> `src/http/` as *transport, not a domain*. At landing we chose to model it as a
> third `api` domain with a `handler Api` component, so the `Handles` (http,
> inbound) edge-type and the `handler` component-kind are actually exercised
> rather than declared-but-unused. The four features attach to `api.Api` via a
> `uses { component:Api } from api` import — this is the `http.api` attachment the
> feature table below anticipated. The result: 3 domains, 6 components, every
> declared edge-type and component-kind bound.

## Domains (Phase 1 + Phase 2)

- `accounts` [MEDIUM] — owns account rows and the no-overdraft guard.
  Components: 2 (`AccountService` service, `AccountStore` store)
  Internal edges: 1 (service → store)
  Cross-domain edges: 0 outbound (receives 1 inbound from ledger)
  Smells: 1 (phantom store-level credit/debit in JSDoc — see Smells)
- `ledger` [MEDIUM] — moves money via double-entry transfers, idempotently.
  Components: 3 (`TransferService` service, `EntryStore` store, `IdempotencyStore` store)
  Internal edges: 2 (transfer-service → entry-store, → idempotency-store)
  Cross-domain edges: 1 (transfer-service → `accounts.AccountService`)
  Smells: 2 (no transaction boundary; remember-after-commit race)

> Both domains are MEDIUM: a single npm package = no independently-buildable unit.
> `src/http/api.ts` is a transport handler, not a domain. `money.ts`/`db.ts` are a
> shared kernel, not domains.

## Type vocabulary (Phase 3)

Proposed edge-types (at mining time `vocabulary.mtypes` carried only the scaffolded
`ComponentTypes` and no `EdgeTypes` block; these three were added on landing):
  - `Handles`  — transport: http,        direction: inbound  (Express routes in `http/api.ts`)
  - `Calls`    — transport: in-process,  direction: directed (cross-domain method calls)
  - `Persists` — transport: in-process,  direction: directed (store → `Table` writes)
Proposed component-types: `service`, `store`, `handler` (`service`/`store` already declared; add `handler`)
Proposed default-edge-type at mining time: none (no clear majority — Persists is plurality at <70%).
On landing, `Calls` was set as `default-edge-type:` so the `ledger` e3 edge can use empty brackets `-[]->`.

## Features (Phase 4)

- `open-account` [HIGH] [S] — POST /accounts creates a zero-balance account; attaches to `accounts.AccountService`, `accounts.AccountStore` (+ `http.api`)
  Rules: R1.creates-zero-balance, R2.persists-to-store
  Anchor: Code — `AccountService.open`, `AccountStore.create`
- `get-balance` [HIGH] [S] — GET /accounts/:id/balance returns the balance, 404 if unknown; attaches to `accounts.AccountService` (+ `http.api`)
  Rules: R1.returns-current-balance, R2.unknown-account-404
  Anchor: Code — `AccountService.balanceOf`, `UnknownAccount`
- `transfer-funds` [HIGH] [M] — POST /transfers debits/credits both accounts and journals a paired entry; attaches to `ledger.TransferService`, `accounts.AccountService`, `ledger.EntryStore` (+ `http.api`)
  Rules: R1.positive-amount-required, R2.debit-before-credit, R3.overdraft-rejected, R4.currency-must-match
  Invariants: I1.no-overdraft, I2.double-entry-sums-to-zero, I3.single-currency
  Anchor: Code — `TransferService.transfer`, `AccountService.apply`, `EntryStore.append`
- `idempotent-transfer` [HIGH] [S] — a replayed Idempotency-Key returns the prior result without moving money twice; attaches to `ledger.TransferService`, `ledger.IdempotencyStore` (+ `http.api`)
  Rules: R1.replay-returns-prior-result, R2.first-call-remembers
  Invariants: I3.idempotent-money-movement
  Anchor: Code — `TransferService.transfer`, `IdempotencyStore.lookup`/`remember`

> Every harvested rule lands with an `open:` marker — these describe what the code
> does today, not a promised contract. They shed the marker only on human confirmation.

## Open questions

- Is `idempotent-transfer` its own feature or rules R5/R6 of `transfer-funds`? (same endpoint; kept separate because the idempotency invariant is README-elevated and touches a distinct store)
- Should the unused `EntryStore.forTransfer` get a "read journal" feature, or is it latent capability? (no endpoint reads it today)

## Smells (across all phases)

- [smell] Phantom store API: `AccountStore` JSDoc claims balance mutations flow through `credit`/`debit`, but neither method exists — the arithmetic lives in `AccountService.apply`. (Phase 2/4) — FIXED in source.
- [smell] No transaction boundary in `TransferService.transfer`: four separate mutations with no rollback; a mid-flight throw leaves `from` debited without a credit. (Phase 2)
- [smell] Remember-after-commit: `IdempotencyStore.remember` runs after the mutations; a crash before it lets a replay re-execute. (Phase 2)
- [smell] `RangeError` from non-integer `minor` is unmapped in `statusFor` → falls through to 500 instead of 400. (Phase 4) — FIXED in source (now mapped to 400).
- [smell] Blank `Idempotency-Key` defaulted to `""`, collapsing every keyless transfer onto one idempotency slot. (review) — FIXED in source (now rejected with 400).
- [smell] `EntryStore.forTransfer` has no caller — latent audit-trail capability with no user-visible surface. (Phase 2/4)

## Considered and rejected

_(none yet — first run)_
