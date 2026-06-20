spec: idempotent-transfer
title: Replaying an idempotency key never moves money twice
status: active
version: 1

uses { component:TransferService, component:IdempotencyStore } from ledger
uses { component:Api } from api

Targets
  $lookup @file=src/ledger/idempotency.ts#lookup
  $remember @file=src/ledger/idempotency.ts#remember

Depends on
  transfer-funds >= 1

Invariant I1.exactly-once [active]
  a transfer replayed with the same Idempotency-Key moves money exactly once

Rule R1.replay-returns-prior-result [active $lookup ledger.IdempotencyStore.lookup ledger.TransferService.transfer]
  Cites transfer-funds.R2
  Given a transfer has already completed for an Idempotency-Key submitted through {api.Api}
  When the same key is submitted again
  Then {ledger.TransferService} returns the original result without mutating any balance
    MUST replay_noop: a replayed key MUST NOT change any account balance
    success.replay_same_id: two POSTs with the same `Idempotency-Key` return the same `transferId`

Rule R2.first-call-remembers [active $remember ledger.IdempotencyStore.remember]
  Given a transfer completes for a fresh Idempotency-Key
  Then {ledger.IdempotencyStore} stores the result under that key
    MUST stored: a completed transfer MUST persist its result keyed by the Idempotency-Key
