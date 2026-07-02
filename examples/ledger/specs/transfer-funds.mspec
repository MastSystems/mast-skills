spec: transfer-funds
title: Move money between two accounts via a double-entry transfer
status: active
version: 1

uses { component:TransferService, component:EntryStore } from ledger
uses { component:AccountService } from accounts
uses { component:Api } from api

Targets
  $transfer @file=src/ledger/transfer-service.ts#transfer
  $apply @file=src/accounts/service.ts#apply
  $append @file=src/ledger/entry-store.ts#append
  $currency @file=src/money.ts#assertSameCurrency

Exports
  debit
  credit

Define
  debit: the negative leg of a transfer, subtracted from the source account
  credit: the positive leg of a transfer, added to the destination account
  transfer: the whole money movement, comprising one debit and one credit

Boundary
  in: applying a transfer's debit and credit to two accounts and journaling the paired entries
  out: currency conversion, scheduled or recurring transfers, reversing a settled transfer

Compliance ledger-governance
  certified: yes

Invariant I1.no-overdraft [active]
  no account balance is ever driven below zero by a transfer

Invariant I2.double-entry-sums-to-zero [active]
  every transfer writes a {debit} and a {credit} whose minor units sum to zero

Invariant I3.single-currency [active]
  a transfer touches accounts that share one currency; cross-currency arithmetic is refused
    success.mixed_rejected: transferring `USD` minor units into a `EUR` account fails with `CurrencyMismatch`

Invariant I4 [active]
  the journal is append-only

Rule R1.positive-amount-required [active $transfer ledger.TransferService.transfer]
  Given a transfer request arrives at {api.Api}
  When the amount in minor units is not positive
  Then the transfer is rejected with an InvalidAmount error
    MUST positive: a transfer MUST reject an amount of 0 or fewer minor units
    success.rejects_zero: a transfer of `0` minor units fails with `InvalidAmount`

Rule R2.debit-before-credit [active $transfer $append ledger.TransferService.transfer]
  Given a source account with sufficient funds
  Then {ledger.TransferService} debits the source and credits the destination, and {ledger.EntryStore} records two entries sharing one transferId
    MUST paired_entries: a successful transfer MUST append exactly two entries with the same transferId
    invariant.entries_balance: the two appended entries' minor units sum to `0`
    success.journal_shape:
      | a successful transfer of 500 minor units from acct-a to acct-b appends exactly two journal entries sharing one transferId: { account: "acct-a", minor: -500 } and { account:
      | "acct-b", minor: 500 }, and `EntryStore.forTransfer(transferId)` returns both

Rule R3.overdraft-rejected [active $apply accounts.AccountService.apply]
  Given a source account without sufficient funds
  When the debit is applied
  Then {accounts.AccountService} throws InsufficientFunds and no credit or journal entry is written
    MUST no_overdraft: a debit that would make the balance negative MUST be rejected
    SHOULD audit_log: a rejected overdraft emits a structured audit event to the audit log
    success.overdraft_422: transferring more than the source balance returns HTTP status `422`

Rule R4.currency-must-match [active $apply $currency accounts.AccountService.apply]
  Given a transfer whose amount is in a different currency than an account
  When the debit or credit is applied
  Then a CurrencyMismatch error is raised and mapped to HTTP 400
    MUST same_currency: applying an amount in a currency other than the account's MUST be rejected
    success.currency_400: transferring into an account of a different currency returns HTTP status `400`

Rule R5.single-entry-posting [retired]
  Given a settled transfer under the original single-entry design
  Then one net ledger entry was recorded for the whole movement
    MUST single_entry: the retired single-entry path recorded exactly one entry per transfer, since superseded by the double-entry rule R2

Rule R6.amounts-integer-minor-units [amended $transfer ledger.TransferService.transfer]
  Given a transfer request carries an amount
  When the amount is expressed
  Then the amount is an integer count of minor units, never a fractional major unit
    MUST integer_minor: a transfer amount MUST be an integer number of minor units
    success.rejects_fraction: constructing a `Money` value from `1.5` minor units fails
