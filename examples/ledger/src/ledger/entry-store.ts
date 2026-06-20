import { Table } from "../db.js";
import type { Money } from "../money.js";

/**
 * ledger domain — persistence component.
 *
 * EntryStore is an append-only journal. Each transfer writes a pair of
 * entries (a debit and a credit) sharing a `transferId`. Entries are never
 * mutated or deleted — the journal is the audit trail.
 */
export interface Entry {
  readonly id: string;
  readonly transferId: string;
  readonly accountId: string;
  readonly amount: Money;
  readonly at: string;
}

export class EntryStore {
  private readonly table = new Table<Entry>();

  append(entry: Entry): void {
    this.table.put(entry.id, entry);
  }

  forTransfer(transferId: string): Entry[] {
    return this.table.all().filter((e) => e.transferId === transferId);
  }
}
