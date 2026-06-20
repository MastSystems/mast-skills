import { randomUUID } from "node:crypto";
import { EntryStore } from "./entry-store.js";
import { IdempotencyStore, type TransferResult } from "./idempotency.js";
import { AccountService } from "../accounts/service.js";
import { money, negate } from "../money.js";

/**
 * ledger domain — service component, the heart of the system.
 *
 * TransferService moves money between two accounts. It reaches across the
 * domain boundary into the accounts domain (`AccountService`) to mutate
 * balances, and writes the matching journal entries.
 *
 * It upholds three invariants:
 *   - double-entry: it writes a debit and a credit that sum to zero;
 *   - no-overdraft: the debit is delegated to AccountService, which rejects
 *     an overdraw before any credit is written;
 *   - idempotency: a previously-seen key short-circuits to the prior result.
 */
export class TransferService {
  constructor(
    private readonly accounts: AccountService,
    private readonly entries: EntryStore,
    private readonly idempotency: IdempotencyStore,
  ) {}

  transfer(
    idempotencyKey: string,
    from: string,
    to: string,
    currency: string,
    minor: number,
  ): TransferResult {
    const seen = this.idempotency.lookup(idempotencyKey);
    if (seen) {
      return seen;
    }
    if (minor <= 0) {
      throw new InvalidAmount(minor);
    }

    const amount = money(currency, minor);
    const transferId = randomUUID();

    // No-overdraft is enforced here: if the debit fails, nothing else runs.
    this.accounts.apply(from, negate(amount));
    this.accounts.apply(to, amount);

    const at = new Date().toISOString();
    this.entries.append({ id: randomUUID(), transferId, accountId: from, amount: negate(amount), at });
    this.entries.append({ id: randomUUID(), transferId, accountId: to, amount, at });

    const result: TransferResult = { transferId, from, to };
    this.idempotency.remember(idempotencyKey, result);
    return result;
  }
}

export class InvalidAmount extends Error {
  constructor(minor: number) {
    super(`transfer amount must be positive, got ${minor}`);
    this.name = "InvalidAmount";
  }
}
