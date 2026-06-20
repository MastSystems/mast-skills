spec: read-journal
title: Read a transfer's journal entries (planned)
status: pending
version: 1
extends: transfer-funds >= 1

uses { component:EntryStore } from ledger
uses { component:Api } from api

References
  $readme @file=README.md
  $for_transfer @file=src/ledger/entry-store.ts:forTransfer

Targets
  $design @file=docs/read-journal-design.md
  $plan @file=docs/read-journal-plan.md

Boundary
  in: reading back the two journal entries recorded for a settled transfer
  out: mutating entries, exporting the journal to an external system

Rule R1.lists-entries-for-transfer [pending]
  Given a settled transferId
  When the journal is queried through {api.Api}
  Then {ledger.EntryStore} returns the two entries recorded for that transfer
    MUST both_entries: a read returns exactly the {transfer-funds.debit} and the {transfer-funds.credit} for the transferId
    SHOULD ordering: entries are returned debit before credit
    SHOULD NOT mutate: a journal read leaves every stored entry unchanged
    MAY pagination: a large journal is returned in fixed-size pages
    open: the page size and the default sort order are not yet decided

Rule R2.unknown-transfer-empty [pending]
  Given no entries exist for a transferId
  When the journal is queried
  Then an empty list is returned rather than an error
    MUST empty_list: an unknown transferId yields an empty journal, not a 404
    open: whether to return 200 with an empty list or 204 no-content is undecided
