import { Table } from "../db.js";
import type { Money } from "../money.js";

/**
 * accounts domain — persistence component.
 *
 * AccountStore owns the account rows: it is the only component that touches
 * the underlying `Table`. It exposes `create` / `find` / `save`; the balance
 * arithmetic and the no-overdraft guard live one layer up in AccountService,
 * which calls `save` to persist each new balance.
 */
export interface Account {
  readonly id: string;
  readonly owner: string;
  balance: Money;
}

export class AccountStore {
  private readonly table = new Table<Account>();

  create(account: Account): void {
    this.table.put(account.id, account);
  }

  find(id: string): Account | undefined {
    return this.table.get(id);
  }

  /** Persist a new balance for an existing account. */
  save(account: Account): void {
    this.table.put(account.id, account);
  }
}
