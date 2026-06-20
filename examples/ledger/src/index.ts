import { AccountStore } from "./accounts/store.js";
import { AccountService } from "./accounts/service.js";
import { EntryStore } from "./ledger/entry-store.js";
import { IdempotencyStore } from "./ledger/idempotency.js";
import { TransferService } from "./ledger/transfer-service.js";
import { buildApi } from "./http/api.js";

/**
 * Composition root. Wires the two domains together and starts the HTTP edge.
 * This is the only place where components from different domains meet.
 */
const accountStore = new AccountStore();
const accounts = new AccountService(accountStore);

const entries = new EntryStore();
const idempotency = new IdempotencyStore();
const transfers = new TransferService(accounts, entries, idempotency);

const app = buildApi(accounts, transfers);

const port = Number(process.env.PORT ?? 3000);
app.listen(port, () => {
  console.log(`ledger listening on :${port}`);
});
