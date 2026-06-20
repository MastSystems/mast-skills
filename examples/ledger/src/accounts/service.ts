import { randomUUID } from "node:crypto";
import { AccountStore, type Account } from "./store.js";
import { add, isNegative, zero, type Money } from "../money.js";

/**
 * accounts domain — service component.
 *
 * AccountService is the domain's public surface: open an account, read a
 * balance, and apply a signed amount. It enforces the **no-overdraft**
 * invariant — a debit that would drive the balance below zero is rejected
 * before it ever reaches the store.
 */
export class AccountService {
  constructor(private readonly store: AccountStore) {}

  open(owner: string, currency: string): Account {
    const account: Account = {
      id: randomUUID(),
      owner,
      balance: zero(currency),
    };
    this.store.create(account);
    return account;
  }

  balanceOf(accountId: string): Money {
    return this.require(accountId).balance;
  }

  /**
   * Apply a signed amount to an account. Negative `delta` is a debit.
   * Throws `InsufficientFunds` rather than letting the balance go negative.
   */
  apply(accountId: string, delta: Money): void {
    const account = this.require(accountId);
    const next = add(account.balance, delta);
    if (isNegative(next)) {
      throw new InsufficientFunds(accountId);
    }
    account.balance = next;
    this.store.save(account);
  }

  private require(accountId: string): Account {
    const account = this.store.find(accountId);
    if (!account) {
      throw new UnknownAccount(accountId);
    }
    return account;
  }
}

export class UnknownAccount extends Error {
  constructor(id: string) {
    super(`unknown account: ${id}`);
    this.name = "UnknownAccount";
  }
}

export class InsufficientFunds extends Error {
  constructor(id: string) {
    super(`insufficient funds in account: ${id}`);
    this.name = "InsufficientFunds";
  }
}
