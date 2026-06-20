/**
 * The persistence boundary for the whole service.
 *
 * In a real deployment this is Postgres; here it is an in-memory map so the
 * example runs with no external services. Stores in each domain are built on
 * top of this primitive — they are the only code that touches it.
 */
export class Table<V> {
  private readonly rows = new Map<string, V>();

  get(id: string): V | undefined {
    return this.rows.get(id);
  }

  put(id: string, value: V): void {
    this.rows.set(id, value);
  }

  has(id: string): boolean {
    return this.rows.has(id);
  }

  all(): V[] {
    return [...this.rows.values()];
  }
}
