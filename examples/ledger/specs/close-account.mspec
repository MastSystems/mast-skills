spec: close-account
title: Close an account once its balance reaches zero (planned)
status: draft
version: 1

uses { component:AccountService } from accounts

Boundary
  in: marking a zero-balance account closed so it rejects further transfers
  out: refunding or sweeping a non-zero balance before closure

Rule R1.zero-balance-required [pending]
  Given an account whose balance is not zero
  When closure is requested through {accounts.AccountService}
  Then the request is rejected until the balance reaches zero
    MUST nonzero_blocks: closing an account whose balance is not zero MUST be rejected
    open: whether a closed account can later be reopened is undecided

Rule R2.closed-rejects-transfers [pending]
  Given a closed account
  When a transfer names it as source or destination
  Then the transfer is rejected with an AccountClosed error
    MUST closed_blocks: a transfer touching a closed account MUST be rejected
    open: whether the rejection maps to HTTP 409 or 422 is undecided
