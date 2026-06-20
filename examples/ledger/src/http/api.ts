import express, { type Express, type Request, type Response } from "express";
import { AccountService, InsufficientFunds, UnknownAccount } from "../accounts/service.js";
import { TransferService, InvalidAmount } from "../ledger/transfer-service.js";
import { CurrencyMismatch } from "../money.js";

/**
 * The inbound transport — the only `http` edge in the system.
 *
 * api is a thin Handler: it parses requests, calls into the two domain
 * services, and maps domain errors onto HTTP status codes. It holds no
 * business logic of its own.
 */
export function buildApi(accounts: AccountService, transfers: TransferService): Express {
  const app = express();
  app.use(express.json());

  // Open a new account.
  app.post("/accounts", (req: Request, res: Response) => {
    const { owner, currency } = req.body;
    const account = accounts.open(owner, currency);
    res.status(201).json({ id: account.id, balance: account.balance });
  });

  // Read a balance.
  app.get("/accounts/:id/balance", (req: Request, res: Response) => {
    try {
      res.json(accounts.balanceOf(req.params.id));
    } catch (err) {
      res.status(statusFor(err)).json({ error: message(err) });
    }
  });

  // Move money. The idempotency key rides in a header and is required —
  // a blank key would otherwise collapse every keyless request onto one
  // idempotency slot and dedupe unrelated transfers to the first result.
  app.post("/transfers", (req: Request, res: Response) => {
    const key = (req.header("Idempotency-Key") ?? "").trim();
    if (key === "") {
      return res.status(400).json({ error: "Idempotency-Key header is required" });
    }
    const { from, to, currency, minor } = req.body;
    try {
      const result = transfers.transfer(key, from, to, currency, minor);
      res.status(201).json(result);
    } catch (err) {
      res.status(statusFor(err)).json({ error: message(err) });
    }
  });

  return app;
}

function statusFor(err: unknown): number {
  if (err instanceof UnknownAccount) return 404;
  if (err instanceof InsufficientFunds) return 422;
  // RangeError comes from `money()` rejecting a non-integer minor amount —
  // that is bad client input, not a server fault.
  if (err instanceof InvalidAmount || err instanceof CurrencyMismatch || err instanceof RangeError) {
    return 400;
  }
  return 500;
}

function message(err: unknown): string {
  return err instanceof Error ? err.message : "internal error";
}
