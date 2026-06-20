spec: get-balance
title: Read an account balance, with a 404 for unknown accounts
status: active
version: 1

uses { component:AccountService } from accounts
uses { component:Api } from api

References
  $readme @file=README.md

Targets
  $balance @file=src/accounts/service.ts#balanceOf
  $require @file=src/accounts/service.ts#require

Rule R1.returns-current-balance [active $balance accounts.AccountService.balanceOf]
  Given a client requests an existing account's balance through {api.Api}
  Then {accounts.AccountService} returns its current Money balance
    MUST returns_money: `balanceOf` MUST return the stored balance value
    MAY cache_read: a balance read MAY be served from a read-through cache

Rule R2.unknown-account-404 [active $require]
  Given no account exists for the requested id
  When a balance is requested through {api.Api}
  Then the request fails with an UnknownAccount error mapped to HTTP 404
    MUST status_404: an unknown account id MUST produce HTTP status 404
    success.unknown_404: `GET /accounts/does-not-exist/balance` returns status `404`
