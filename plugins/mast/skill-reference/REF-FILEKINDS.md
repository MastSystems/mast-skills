# REF-FILEKINDS

> Shared reference section. The three mast file kinds and the cross-layer wiring
> model, cited via `Reference:`. Single home for fragments A3 (file kinds) and A4
> (cross-layer wiring + derived attachment).

## The three file kinds (A3)

A mast corpus is built from three file kinds, distinguished by extension. There is
**no `lang:` header** — the file kind is inferred from its extension.

- **`.mspec`** — a **feature specification** (the L7 layer). Describes *what
  behavior must hold* using `Given` / `When` / `Then` rules with `MUST`, `SHOULD`,
  and `MAY` constraints. Each `.mspec` owns one feature; think of them as contracts
  the code must satisfy.
- **`.march`** — an **architecture file** (the L6 layer). Describes *what
  components exist and how they connect*. Each `.march` represents one domain. Edges
  between components are typed (e.g. "A `imports` B", "A `triggers` B").
- **`.mtypes`** — the **edge-type vocabulary** (the L6 alphabet). **Exactly one per
  project.** Declares the edge-type names (Capitalized by corpus convention, e.g.
  `Connects`, `Imports`, `Triggers`, `Reads`, `Writes`) so `.march` files draw on a
  shared alphabet.

Not every project needs all three. Small projects often have only `.mspec` files.

## Cross-layer wiring and derived attachment (A4)

Two mechanisms wire the layers together:

- **`uses {component:} from`** — a `.mspec` rule references an architecture
  component it relies on.
- **`{domain.Component[.port]}` placeholders** — feature text names a component
  (optionally a port) in a domain, binding the feature to the architecture.

**Placeholder resolution order.** A `{...}` placeholder is resolved in three
ordered steps; the first match wins:

1. **Step 0 — reserved prefixes.** `success` / `invariant` (the reserved dotted
   constraint-key namespaces) resolve first.
2. **Step 1 — `uses` imports.** Components brought into scope by a `uses
   {component:} from <domain>` statement.
3. **Step 2 — local `Define` table.** The spec's own `Define` entries.

**Attachment is derived, not declared.** A spec's attachment to architecture
components is computed (surface it with `mast describe attached <spec-id>`), not
written by hand. The older `Imports` block and the `attached_to:` header are
**retired** — do not author them.
