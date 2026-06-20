import { Table } from "../db.js";

/**
 * ledger domain — persistence component.
 *
 * IdempotencyStore remembers the outcome of each transfer keyed by the
 * caller-supplied idempotency key. A replayed key returns the stored result
 * instead of executing the transfer a second time.
 */
export interface TransferResult {
  readonly transferId: string;
  readonly from: string;
  readonly to: string;
}

export class IdempotencyStore {
  private readonly table = new Table<TransferResult>();

  lookup(key: string): TransferResult | undefined {
    return this.table.get(key);
  }

  remember(key: string, result: TransferResult): void {
    this.table.put(key, result);
  }
}
