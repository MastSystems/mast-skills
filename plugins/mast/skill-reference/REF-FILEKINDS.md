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

The `uses { <kind>:<name> } from <spec>` statement accepts a **closed kind set**:
`component | edge | edge-type | rule | define | spec`.

**Exports gate the Define vocabulary.** An `Exports` block on an `.mspec`
whitelists which of its `Define` entries other specs may reference: a
`{spec.term}` placeholder naming a defined-but-unexported term fails to resolve
(`unresolved reference`). With no `Exports` block, every `Define` entry is
exported by default.

**Placeholder resolution order.** A `{...}` placeholder is resolved in three
ordered steps; the first match wins:

1. **Step 0 — reserved prefixes.** `success` / `invariant` (the reserved dotted
   constraint-key namespaces) resolve first.
2. **Step 1 — `uses` imports.** Components brought into scope by a `uses
   {component:} from <domain>` statement.
3. **Step 2 — local `Define` table.** The spec's own `Define` entries.

The same three-step order applies to placeholders in **rule clauses
(Given/When/Then) and `Invariant I<n>` bodies alike** — a `uses`-imported
component name resolves in an invariant exactly as it does in a rule.

**Brace-quantifier trap.** `{...}` ALWAYS parses as a placeholder — even inside
a backticked literal — and there is no escape. A regex brace quantifier like
`[a-z]{3,32}` therefore lints as `unresolved placeholder: {3,32}`. Do not
weaken the regex: move the exact regex into a `Define` entry value (Define
values are not placeholder-parsed) and reference it as `{term}`, or spell the
repetition out in prose.

**Attachment is derived, not declared.** A spec's attachment to architecture
components is computed (surface it with `mast describe attached <spec-id>`), not
written by hand. The older `Imports` block and the `attached_to:` header are
**retired** — do not author them.
