spec: ledger-governance
title: Ledger governance: money-handling invariants every domain must uphold
status: active
version: 1
kind: constitution

Targets
  $money @file=src/money.ts#money
  $apply @file=src/accounts/service.ts#apply
  $transfer @file=src/ledger/transfer-service.ts#transfer
  $remember @file=src/ledger/idempotency.ts#remember

Tiers
  baseline: R1, R2
  standard: baseline + R3, R4
  strict: R*

Rule R1.integer-money [active $money]
  Given any monetary amount in the system
  Then it is represented in integer minor units
    MUST integer_only: a non-integer minor amount MUST be rejected by `money()`

Rule R2.no-overdraft [active $apply]
  Given a debit applied to an account
  Then the resulting balance is never negative
    MUST nonneg: `AccountService.apply` MUST reject a debit that overdraws the account

Rule R3.double-entry [active $transfer]
  Given a completed transfer
  Then it records a debit and a credit whose minor units sum to zero
    MUST balanced: the two journal entries for a transfer MUST sum to 0 minor units

Rule R4.idempotent [active $remember]
  Given a transfer carrying an Idempotency-Key
  Then replaying the key never moves money twice
    MUST once: a replayed key MUST return the stored result without a second mutation
