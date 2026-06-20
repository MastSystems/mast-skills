spec: open-account
title: Open a new account with a zero balance
status: active
version: 1

uses { component:AccountService, component:AccountStore } from accounts
uses { component:Api } from api

Targets
  $open @file=src/accounts/service.ts#open
  $create @file=src/accounts/store.ts#create

Boundary
  in: creating an account with a zero opening balance in a chosen currency
  out: closing accounts, overdraft limits, interest accrual

Rule R1.creates-zero-balance [active $open accounts.AccountService.open]
  Given a client opens an account through {api.Api} for an owner in a chosen currency
  Then {accounts.AccountService} creates an account whose balance is zero in that currency
    MUST zero_start: a freshly opened account MUST have a balance of 0 minor units
    success.opened: opening with currency `USD` yields an account with balance `{ currency: "USD", minor: 0 }`

Rule R2.persists-to-store [active $create accounts.AccountStore.create]
  Given an account has just been opened
  Then {accounts.AccountStore} holds it retrievable by id
    MUST persisted: `AccountStore.find(id)` MUST return the created account
