/**
 * Money — a currency-tagged amount in integer minor units (e.g. cents).
 *
 * Amounts are integers so arithmetic is exact; floating-point money is a bug
 * waiting to happen. Operations refuse to mix currencies.
 */
export interface Money {
  readonly currency: string;
  /** Amount in minor units (cents). May be negative for a debit entry. */
  readonly minor: number;
}

export function money(currency: string, minor: number): Money {
  if (!Number.isInteger(minor)) {
    throw new RangeError(`money minor units must be an integer, got ${minor}`);
  }
  return { currency, minor };
}

export function zero(currency: string): Money {
  return { currency, minor: 0 };
}

export function add(a: Money, b: Money): Money {
  assertSameCurrency(a, b);
  return { currency: a.currency, minor: a.minor + b.minor };
}

export function negate(a: Money): Money {
  return { currency: a.currency, minor: -a.minor };
}

export function isNegative(a: Money): boolean {
  return a.minor < 0;
}

export function assertSameCurrency(a: Money, b: Money): void {
  if (a.currency !== b.currency) {
    throw new CurrencyMismatch(a.currency, b.currency);
  }
}

export class CurrencyMismatch extends Error {
  constructor(left: string, right: string) {
    super(`currency mismatch: ${left} vs ${right}`);
    this.name = "CurrencyMismatch";
  }
}
