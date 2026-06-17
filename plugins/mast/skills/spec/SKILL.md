---
name: spec
description: Read, create, rewrite, or patch .mspec/.march/.mtypes files. Routes internally to read, write, or patch mode based on intent. Triggers on "read/show/inspect spec X", "what depends on/cites/extends/blocks X", "is X ready", "list domains/components/edge-types", "what's attached to X", "create/rewrite spec", "new domain/march/mtypes", "add/update/remove rule", "graduate/amend/retire R<n>", "set rule status", "add/remove boundary", "edit title/header", "declare edge type", "wire feature to component", "attach spec to component".
---

# spec

This is the daily-driver CRUD skill: every mediated read, create, rewrite, and patch of a `.mspec` / `.march` / `.mtypes` file goes through here. It routes internally to read, write, or patch mode from the user's intent. For narrative orientation or conceptual questions hand off to `/mast:orient`; for scored health audits hand off to `/mast:check`.

Reference: REF-BINARY, REF-FILEKINDS, REF-LIFECYCLE, REF-GOVERNANCE, REF-IDIOMS, REF-BLEED, REF-DEPENDENCIES, REF-POSTURE, REF-HOOKRULE, REF-CONVENTIONS, REF-ROUTING
*(Reference sections live in `plugins/mast/skill-reference/` — e.g. `REF-FILEKINDS` resolves to `plugins/mast/skill-reference/REF-FILEKINDS.md`.)*

## Prerequisites

Which binary to invoke is shared doctrine — see **REF-BINARY**: call `mast` directly (the plugin puts it on Claude Code's PATH), or `./bin/mast` in a repo that vendors the shim. Either way every write goes through the binary, so each spec is parsed, linted, and formatted before it lands. If `mast` cannot be provisioned, stop and tell the user to install it before proceeding.

Every write and patch goes through parse, per-file lint, format, then tempfile + atomic rename. If validation fails the existing file is unchanged and diagnostics are written to stderr.

Direct `Read`, `Edit`, or `Write` on `*.mspec` is blocked by a PreToolUse hook (including staged paths like `/tmp/foo.mspec`) — shared doctrine, see **REF-HOOKRULE**. `.march` and `.mtypes` are not currently hooked but should still be authored through the CLI for the same parse-lint-format guarantees. Use the commands below.

## Intent routing

Determine the mode from the user's intent:

| User intent | Mode |
|---|---|
| "read spec X", "show me X", "what's in X", "what depends on X", "what cites X", "what extends X", "what's blocking X", "is X ready to ship", "inspect X", "list domains", "show components", "what's attached to X", "list edge-types", "walk connections from X" | **Read** |
| "create a new spec", "new spec for Y", "rewrite spec X", "new .march file", "new domain", "declare edge type", "edit the title/description", "restructure X", "add a Define entry", "change Depends on", "add a `uses` import", "update extends", "wire feature to component", "make a constitution", "add/remove invariant I2", "set/remove compliance", "add a Tiers block" | **Write** |
| "add rule R5", "update rule R3", "remove rule R7", "graduate R3", "retire R5", "amend R2", "set R3 to active", "set rule status", "add boundary entry", "remove boundary in/out N" | **Patch** |

When ambiguous (e.g. "edit spec X"), prefer **patch** for single-construct mutations, **write** for structural or multi-construct changes. If truly ambiguous, ask.

## When NOT to use

- Narrative orientation ("walk me through the codebase"), or conceptual questions about the layered model — use `/mast:orient`.
- Corpus health check or scored audit — use `/mast:check`.
- Mining a corpus from source code — use `/mast:mine`.
- A complex multi-phase implementation to plan or execute against specs (dependency-ordered phases, TDD cycles, graduation) — use `/mast:dag-plan`.

The full cross-skill routing table and the bypass-gate are shared doctrine — see **REF-ROUTING**. If the user's message already names a specific spec ID, rule number, or CLI command, they are past onboarding (the bypass-gate); route straight here.

## The three file kinds (orientation before authoring)

Before authoring, identify which of the three file kinds the content belongs to — the grammar, parser, and linker are shared but the content shape differs. The three file kinds (`.mspec` feature/L7, `.march` domain/L6, `.mtypes` edge-type alphabet, exactly one per project), the absence of a `lang:` header (kind inferred from extension), and the two cross-layer wiring mechanisms (`uses { component:} from` and `{domain.Component}` placeholders, with attachment derived not declared) are all shared doctrine — see **REF-FILEKINDS**. The AnchorKind six-variant taxonomy, `blocks_graduation()`, the exact-filename literals, and the lifecycle/anchor-ratchet are shared doctrine — see **REF-LIFECYCLE**. The bleed taxonomy ("each fact lives in exactly one layer") is shared doctrine — see **REF-BLEED**; treat its rows as smells per the descriptive-not-prescriptive posture (**REF-POSTURE**), since newly-onboarded codebases routinely exhibit several.

What `spec` adds on top of that doctrine is the **authoring-side mapping** — which constructs each file kind owns, so you scaffold the right shape:

| Role | Extension | One file = one ... | Owns |
|---|---|---|---|
| **Feature** | `.mspec` | feature or sub-feature | Rules (Given/When/Then + MUST/SHOULD/MAY), `Invariant I<n>` entries, lifecycle (`status`), `Depends on`, `Compliance` blocks, code anchors via `Targets` |
| **Architecture** | `.march` | **domain** | Components (with `port:` / `expose:` / `extends`), `Edges` (typed `A -[type]-> B`), `roots:`, `Compliance` blocks |
| **Type vocabulary** | `.mtypes` | **the project's edge-type alphabet** | `EdgeTypes` (`edge-type <name>` with `transport:` / `protocol:` / `direction:` ...), `ComponentTypes`, optional `default-edge-type:` header |

**On layer numbering.** `lang-march`'s Define block labels `.mspec` content "L7" and `.march` content "L6", reserving "L5" for a future `.minfra` infrastructure layer out of scope today. The `.mtypes` file is L6's type-vocabulary companion — it lives alongside `.march` but carries no components or edges of its own.

**Constitution specs** are `.mspec` files with the header `kind: constitution`; they declare governance rules organized into **tiers** via a `Tiers` block. What a constitution / tier / Compliance block / ratchet IS — the generic governance model — is shared doctrine, see **REF-GOVERNANCE**. Non-constitution specs must not carry a `Tiers` block. The step-by-step authoring workflow (how to build a constitution and a Compliance block through the CLI) is `spec`-specific capability and lives in the **Governance authoring workflow** below.

### What belongs at each layer — worked examples

The IDs and names below (`checkout-flow`, `orders-domain`, `OrderService`, `PaymentGateway`) are illustrative placeholders from an e-commerce-style codebase. Substitute IDs from your own corpus — the structure is what matters.

**Feature (`.mspec`, L7) — answers "what behavior, and how do we know it's done?"**

```
spec: checkout-flow
title: Customer checkout flow with payment authorization
status: active
version: 2

uses { component:OrderService, component:PaymentGateway } from orders-domain

Depends on
  payments-contract >= 1

Define
  cart: the customer's current shopping cart , prior to authorization

Boundary
  in: cart submission , payment authorization , order finalization
  out: shipping , fulfillment , refunds

Invariant I1.idempotent-charge [active]
  no cart is ever authorized more than once for the same Idempotency-Key

Rule R1.authorize-charge [active $checkout_route orders.PaymentGateway.authorize]
  Given the customer submits {cart} via {orders.OrderService}
  When the cart total is non-zero
  Then {orders.PaymentGateway} authorizes the charge
    MUST status_code: the response code MUST be 200 on success
    MUST idempotency: the request MUST carry an Idempotency-Key header
    SHOULD logging: a structured event SHOULD be emitted on every authorization
```

Every claim is **behavioral**. The `{orders.OrderService}` / `{orders.PaymentGateway}` placeholders *name* architecture components without redefining their structure — that lives in the `.march`. The `uses { component:... } from <domain>` line is the only cross-layer wiring statement (no `Imports` block in mast/3 — REF-FILEKINDS). The `{domain.Component[.port]}` placeholder-resolution order (step 0 reserved `success`/`invariant` prefixes → step 1 `uses` imports → step 2 local `Define` table) is shared doctrine — see **REF-FILEKINDS**. Invariants are first-class `Invariant I<n>` entries in the rules section — there is no `Invariants` preamble block. The rule's status chip can mix component refs (`orders.PaymentGateway.authorize`) and file anchors (`$checkout_route`).

**Architecture (`.march`, L6) — answers "what's wired to what, and through what?"**

```
spec: orders-domain
title: Order management and payment authorization
status: active
version: 1
roots: orders/

library OrderService
  port: http
  expose: api.orders

gateway PaymentGateway
  port: https
  expose: api.payments

Edges
  edge e1: OrderService -[Connects]-> PaymentGateway @file=orders/service.rs#charge
  edge e2: OrderService -[Reads]-> inventory.Catalog @file=orders/service.rs#lookup
```

Zero behavior. Pure **topology** — which components exist, which ports they expose, which edges connect them under which edge-type. Component types (`library`, `gateway`) and edge-type names (`Connects`, `Reads`) refer to entries in the project's `.mtypes`; edge-type names match declared `.mtypes` entries exactly and are **Capitalized by corpus convention**. Empty brackets `-[]->` fall back to the `.mtypes` `default-edge-type`. Cross-domain edges name the foreign component directly (`inventory.Catalog`). Edges may carry an `@file=path#sym` anchor and optional debt annotations (`!bypass`, `!dep-inversion`, `!dup-path`, `!overreach`, `!debt`) with an optional `(ack|pending|resolved)` status. The march-typing surface (keyword-position component kinds, the retired suffix form, `composes:` rules) is shared doctrine — see **REF-IDIOMS**.

**Type vocabulary (`.mtypes`) — answers "what kinds of edges does this project's architecture use?"**

```
spec: project-vocab
title: Project edge-type vocabulary
status: active
version: 1
default-edge-type: Connects

EdgeTypes
  edge-type Connects
    transport: tcp
    direction: out
  edge-type Reads
    transport: in-process
  edge-type Imports
    transport: in-process

ComponentTypes
  component-type library
  component-type gateway
  component-type adapter
```

Zero edges, zero rules — just the alphabet: edge-type names (Capitalized by corpus convention) and the component-type vocabulary `.march` files draw from. **Exactly one `.mtypes` per project**; multiple files emit `imports/duplicate-mtypes` at error severity.

### Detection commands — verifying layer hygiene

Run these after any cross-layer edit to confirm nothing leaked. The bleed taxonomy these check against is shared doctrine (**REF-BLEED**); the commands are the `spec`-side verification surface:

| Command | Tells you |
|---------|-----------|
| `mast describe attached <spec-id>` | The resolved L6 component set this `.mspec` touches (derived from `uses` imports and component refs in rule chips and `{placeholder}` text). Empty result + behavioral rules = the spec has no architectural anchor. This is the **bleed detector**. |
| `mast describe domain <domain-id>` | The components in a domain, the domains it connects out to, and the domains that connect into it. Empty component list + non-empty file = content is misshaped. |
| `mast describe component <domain>.<component>` | The component's ports, exposes, inbound/outbound connections. Verifies the structural shape one component at a time. |
| `mast list domains \| components \| connections \| edge-types` | Full enumeration per facet. Use `--count` for a bare integer (CI gates). |
| `mast graph <domain>.<component> --edge connects` | Walk the typed connection graph rooted at a component; `--direction in\|out` controls traversal. Cross-domain edges name the foreign component directly. |
| `mast lint check .` | Per-file lint + linker resolve over the whole corpus. Surfaces `imports/file-not-found`, `imports/unknown-entity`, `imports/wrong-kind`, `imports/unused-alias`, `edge-type-undeclared`, and friends. |
| `mast describe governance-for <path>` | Which domain governs a file path via `roots:` prefix matching, and what constitution/tier/compliance state applies. |
| `mast list constitutions` | All constitution specs with tier counts and per-domain certification status. |

### Governance authoring workflow

What governance *is* — the constitution `kind:` + `Tiers` monotonic-superset rule, the `Compliance` block with `enforces:` / `certified:` / `pending:` / `waive:`, the certified=error / pending=warn / waive=info severities, and the forward-only ratchet — is shared doctrine, see **REF-GOVERNANCE**. What follows is the `spec`-specific *how-to-author-it*: the CLI steps, syntax, and round-trip discipline. (The mast/2 standalone `enforces:` header and the `certify-<C>:` / `pending-<C>:` / `waive-<C>:` headers are **retired** — the tier and per-rule state now live inside a `Compliance <constitution>` block, one block per constitution, multiple blocks allowed.)

**`roots:` headers** — directory prefixes the domain owns (one per line, trailing `/` required, pure string prefix matching, no globs):

```march
roots: lint/
roots: lint/export/
```

**`Compliance <constitution>` on `.march`** — names the constitution on the header line; the block body (indented one level, matching the formatter) declares the tier (`enforces: <tier>`) and the per-rule compliance partition:

```march
Compliance mast-governance
  enforces: standard
  certified: R1, R2, R3, R4, R5, R6, R7, R8
  pending: R9, R10
  waive: R11 "lang frontend predates the rule; tracked in backlog"
```

**`Compliance <constitution>` on `.mspec`** — a feature spec certifies itself against a constitution. Use `certified: yes` to certify every rule, or an explicit list `certified: R1, R2, I1` (invariants are citable and certifiable in mast/3). No `enforces:` on `.mspec`:

```
Compliance mast-governance
  certified: yes
```

There is **no typed patch op for `Compliance`** — author it through `mast spec write` (round-trip the whole file). Step-by-step, to stand up governance:

1. **Create or identify the constitution spec.** `mast spec create <id> --title "..."`, then `mast spec write <id>` adding a `kind: constitution` header and a `Tiers` block (tiers list rules only, least- to most-restrictive, each a monotonic superset of the prior):
   ```
   kind: constitution

   Tiers
     baseline: R1, R2, R3, R4, R5
     standard: baseline + R6, R7, R8, R9, R10, R11
     strict: standard + R12, R13, R14
   ```
2. **Wire domains.** Add `roots:` headers and a `Compliance <constitution>` block to each governed `.march` via `mast spec write <domain-id>`.
3. **Declare initial compliance.** Start every rule under `pending:` so violations are warnings (CI-safe).
4. **Certify incrementally.** Move rules from `pending:` to `certified:` as the domain satisfies them. The ratchet prevents regression. Use `waive:` (with a quoted justification) for rules that do not apply.
5. **Verify.** `mast lint check .` runs governance verification (roots overlap, enforces target valid, compliance block valid, severity modulation).

**Governance CLI surface.** Use these alongside the architecture detection commands when working with governed corpora:

| Command | Shows |
|---------|-------|
| `mast list constitutions` | All constitutions with tiers, certification counts, status |
| `mast describe governance <domain>` | Domain's roots, enforced constitutions, per-rule compliance breakdown |
| `mast describe governance-for <path>` | Which domain governs a file path, constitution, and tier |
| `mast describe constitution <id>` | Constitution's tiers, per-domain compliance table |

### Authoring workflow for a new feature that touches the architecture

When a new feature reaches into the architecture, author the layers in dependency order — **L6 before L7** — so the components a feature names already exist before the feature names them:

1. **Locate the domain.** `mast list domains` / `mast describe domain <id>`. If the feature touches no domain, you only need an L7 `.mspec`.
2. **Update L6 first, if needed.** New component/port/edge: `mast spec write <domain-id>` (or `mast spec create <domain-id> --kind march`). **Architecture lands before features that depend on it.**
3. **Update `.mtypes` only for genuinely new edge classifications.** Prefer reusing existing edge types.
4. **Write the feature `.mspec`.** `mast spec create <feature-id> --title "..."`, then add a `uses { component:Name } from <domain>` line near the top, express structural anchors via `{domain.Component}` placeholders, and behavioral claims via `MUST` / `SHOULD` / `MAY`. Attachment is derived from the `uses` imports plus component refs — there is no `attached_to:` header to set in mast/3.
5. **Verify.** `mast describe attached <spec-id>` (confirm the resolved component set) then `mast lint check .`.
6. **Check governance.** If the feature's Targets fall under a governed domain, run `mast describe governance-for <target-path>` to confirm the governance binding. **The domain's compliance state determines finding severity** for any lint violations on the spec (certified → error, pending → warning, waive → info).
7. **Refresh context zones.** `mast context render` and commit the regenerated `AGENTS.md` files.

## Modes / playbooks

### Mode: Read

Read a `.mspec` through the CLI. The CLI surfaces **inbound** relationships (what depends on this spec, what extends it, what shares its targets) that are invisible when you just open the file — those relationships live in *other* specs. (The three dependency kinds the inbound view traverses — `Depends on`, `extends`, `Cites` — are shared doctrine, see **REF-DEPENDENCIES**.)

**Gather.** Pick the command and flags that answer the user's question:

```bash
mast spec read <spec-id>                          # formatted body + `--- Inbound ---`
mast spec read <spec-id> --no-inbound             # raw, round-trippable (for piping to write)
```

Inbound is **on by default**: the outbound relationships (`References`, `Targets`, `Depends on`, `extends`) are already in the file, so the value-add is the reverse view — which other specs depend on, extend, or share targets with this one.

| Flag | Appends |
|------|---------|
| `--with-rules` | `--- Rules ---` — rule IDs, statuses, constraint counts |
| `--with-stats` | `--- Stats ---` — corpus-level counts |
| `--with-cited-by <name>` | `--- Cited by ---` — specs citing a named define |
| `--with-blocked-by` | `--- Blocked by ---` — transitive (`Depends on` ∪ `extends`) closure filtered to non-Active specs; empty means structurally ready to ship |
| `--no-inbound` | suppresses the default inbound section |
| `--root <path>` | repository root (default `.`); `mast.toml` `specs_dir` is honored |

Flags compose — each appends its section in declaration order. Unknown spec IDs exit 1 with a diagnostic on stderr. **"Is this spec ready to start?"** is answered directly by `--with-blocked-by` (per `projection-schema` R2 `blocked_by_semantics`): an empty list means every transitive dependency and parent is `active`; a non-empty list names each blocker with its status, so you can tell a small gap (`status=pending`, just needs graduating) from a substantial one (`status=draft`, design unresolved).

For `.march` / `.mtypes` content, query via list/describe/graph (by domain ID, component name, or edge-type name) — `spec read` is `.mspec`-only by `spec:` ID:

```bash
mast list domains | components | connections | edge-types     # each: `--count` (bare int), `--root <path>`, + cli-api-contract global flags
mast list components --domain <id>                            # components in one domain
mast describe domain <domain-id>                              # components + cross-domain connections
mast describe component <domain>.<component>                  # ports + exposes + connections
mast describe attached <spec-id>                              # L6 components an .mspec attaches to (the bleed detector)
mast graph <domain>.<component> --edge connects [--direction in|out] [--depth N]
```

Each list facet maps to a file kind — `list domains` enumerates every `.march` (one domain each), `list edge-types` the project's `.mtypes` entries, `list components` / `connections` every component and typed edge across the corpus. `--edge connects` is the architecture-layer sibling of `--edge deps|extends|cites` (which operate on `.mspec` data); an undecorated `graph` walks **outbound** by default. Cross-domain connections are followed transparently — the walk does not stop at domain boundaries. An empty list is informational (no architecture layer declared), not an error.

**Render.** Return what the user asked for. The formatted body includes the spec headers, so any `design:` / `plan:` extension headers appear at the top — read them as anchor-lifecycle signals (a spec still carrying `design:` / `plan:` is anchored to a doc rather than code; expected on `[pending]`, a stale-design warning on `active` — REF-LIFECYCLE). Four structures carry meaning the surrounding prose does not; do **not** skim past them when explaining a contract (these idioms are shared doctrine — see **REF-IDIOMS** — but call them out when reading):

- **Pipe-block `| ...` constraint bodies** are the multi-line verbatim form of a value (regex, JSON, EBNF, CLI invocation, error message). Treat the body as ground truth; surrounding prose is gloss.
- **`Cites <spec>.R<n>`** lines under a rule header pin the normative rule this rule implements. Follow with `mast describe cites <spec> R<n>` and `mast spec read <cited-spec>` before assuming the rule stands alone.
- **`When` clauses** between `Given` and `Then` are conditional guards — the rule fires only when both hold. A `Given` without a `When` is unconditional given its preconditions.
- **`success.<name>` and `invariant.<name>`** constraints are the rule's executable oracle; their bodies carry the falsifiable anchor. Read these first when verifying behavior.

**Budget.** One command per question; don't fan out per-spec when one `read` plus inbound answers it. Prefer `--no-inbound` only when piping to `write` (the default `--- Inbound ---` section would fail re-parsing).

### Mode: Write

Create or update a `.mspec`, `.march`, or `.mtypes` through the CLI. Spec IDs must match `^[a-z0-9][a-z0-9-]*$`; anything else exits 1 before any filesystem work. The unified parser handles all three kinds (inferred from extension — no `lang:` header). Use `write` for structural or multi-construct changes, and for any mast/3 construct without a typed patch op (Compliance blocks, `Invariant I<n>` entries, `uses` imports, `Tiers`) — round-trip the whole file.

**Gather.** Decide create vs. update, and assemble the full file content.

Creating scaffolds a minimal valid file:

```bash
mast spec create <spec-id> --title "Short title"     # <specs_dir>/<spec-id>.mspec (specs/ by default)
```

Flags: `--title "..."` (required); `--status draft|pending|queued|active|amended|retired` (default `draft`); `--kind mspec|march|mtypes` (default `mspec` — pick `march` for a domain file, `mtypes` for the edge-type vocabulary); `--root <path>`. The command refuses to overwrite an existing file — to replace, use `write`.

```bash
mast spec create user-domain --kind march --title "User-management domain"
# produces <specs_dir>/user-domain.march; spec: value IS the domain ID (lang-march R20)
# follow up with `mast spec write` to add roots:, typed component decls, and the Edges block

mast spec create project-vocab --kind mtypes --title "Project edge-type vocabulary"
# produces <specs_dir>/project-vocab.mtypes with an empty EdgeTypes block
# exactly ONE .mtypes per project; duplicates emit imports/duplicate-mtypes at error severity
# optional default-edge-type: <name> header lets .march edges use empty brackets -[]->
```

**Header schema.** The core fields are `spec`, `title`, `status`, `version` (the formatter emits `version`, defaulting to 1 when absent). Optional headers: `kind:` (e.g. `spec`, `constitution`), `summary:`, `design:`, `plan:`, `extends` (`extends: base-auth >= 2`), `roots:` (.march), `default-edge-type:` (.mtypes). Extension fields are project-defined in an `mspec.schema` file — locate it before writing specs that use them:

```bash
ls mspec.schema 2>/dev/null || find . -maxdepth 3 -name mspec.schema
```

Supported extension types: `text`, `integer`, `enum`, `spec-ref`, `spec-constraint`. Cardinality: `single` (default) or `multiple` (comma-split list). Extension keys must be lowercase and not collide with core keys. `design:` and `plan:` are `text`/single extension fields whose values are relative paths under `docs_dir`; the linter checks the file exists, and an active spec carrying either emits a stale-design warning.

**Anchoring a `[pending]` spec when the code does not exist yet.** mast/3 removed the `[pending]`-status skip for `Code` anchors — a `$anchor @file=...` pointing at a not-yet-written source file now produces a lint error even on a `[pending]` spec. The only way to express "not yet built" is a **Design** (or **Plan**) anchor (the anchor ratchet — REF-LIFECYCLE). Scaffold the `Targets` block with a `*-design.md` anchor under `docs_dir` and reference it from the rule chip:

```bash
mast spec write checkout-flow <<'EOF'
spec: checkout-flow
title: Customer checkout flow with payment authorization
status: pending
version: 1
design: docs/checkout-flow-design.md

Targets
  $design_ref @file=docs/checkout-flow-design.md#authorization

Rule R1.authorize-charge [new $design_ref]
  Given the customer submits a non-empty cart
  Then the charge is authorized exactly once
    MUST idempotency: the request MUST carry an Idempotency-Key header
EOF
```

When the code lands, swap the design anchor for a `Code` anchor before graduating (see patch mode `rule set-status`).

**Render.** Pipe the full replacement content to `mast spec write` on stdin. **Agents: prefer the inline heredoc form** — it avoids a separate file-write step the hook will block:

```bash
mast spec write <spec-id> <<'EOF'
spec: <spec-id>
title: Title
status: active
version: 1
...
EOF
```

From a staged file: `cat new-content.txt | mast spec write <spec-id>`. **Do not stage to a `*.mspec` path** — the hook treats `/tmp/foo.mspec` the same as `specs/foo.mspec` (REF-HOOKRULE); use a `.txt` extension instead. For edits not covered by patch mode (a Define line, a header field, a body paragraph), round-trip: `mast spec read <spec-id> --no-inbound | sed 's|old|new|' | mast spec write <spec-id>`. The `<spec-id>` argument must match the `spec: <id>` line in the content; a mismatch exits 1 without writing. `write` always applies canonical formatting — do not run `mast lint fmt` separately.

On success: parse, per-file lint (errors block; warnings to stderr), canonical format, tempfile + atomic rename, print path, exit 0. On failure: file unchanged, diagnostics on stderr, exit 1.

**Cross-spec validation with `--lint`.** Per-file lint runs on every write. Cross-spec (link) checks — unresolved `Depends on`, unknown `extends` target, broken `{foreign.ref}` placeholders — only run with `--lint`: `mast spec write <spec-id> --lint <<'EOF' ... EOF`. Any error-severity finding rolls the file back and exits 1; warnings never trigger rollback. Use `--lint` when adding/removing `Depends on`, renaming exported Define entries, changing `extends`, or moving a spec ID.

**Budget.** One round-trip per logical change. After a write that changes the corpus listing (new spec, version bump, status change, retire), run `mast context render` and commit the regenerated `AGENTS.md` files in the same commit — `mast lint ci .` (which runs `mast context render --check` internally) rejects drifted zones, but the lighter `mast lint check .` does **not** catch zone drift. Render before pushing.

### Mode: Patch

Apply a typed mutation to an existing spec **without** re-staging its full content. Each patch is a closed-sum operation — the dispatcher loads the file, detects its kind, parses it, applies the typed payload, runs per-file lint, canonical-formats, and atomic-writes. If any stage fails the file on disk is unchanged. The patch surface is a **closed typed sum**; if your edit doesn't match a branch, fall back to write mode (re-stage the whole file).

Patch is **not** `.mspec`-only. The branches split by file kind:

- `rule` and `boundary` are **`.mspec`-only** — running them on a `.march` or `.mtypes` is rejected (`patch kind "rule add" is not supported for .march files; only \`header set\`/\`header remove\` are valid for this file kind`).
- `header set` / `header remove` work on **all three kinds** (`.mspec`, `.march`, `.mtypes`) — e.g. `design:`/`plan:` on any kind, `default-edge-type:` on a `.mtypes`.
- `mask` is **kind-dispatched** across all three kinds: it reads a JSON merge-mask from stdin and routes to `patchSpec` (`.mspec`), `patchMarch` (`.march`), or `patchMtypes` (`.mtypes`). This is the agent-facing surface for editing `.march`/`.mtypes` content (components, edges, edge-types, component-types) — `rule`/`boundary` cannot touch those kinds, so `mask` is how you write them.

**Gather.** Pick the branch from the closed tree:

```
mast spec patch <SPEC_ID>
+-- rule                                 # .mspec ONLY (rejected on .march/.mtypes)
|   +-- add                              # stdin: bare `Rule R<n> [chip]` block
|   +-- update <RULE_ID>                 # stdin: bare `Rule R<n> [chip]` block (R<n> must match arg)
|   +-- remove <RULE_ID> --confirm
|   +-- set-status <RULE_ID> --status pending|active|amended|retired [--anchor SYMBOL ...]
+-- boundary                             # .mspec ONLY (rejected on .march/.mtypes)
|   +-- add                              # stdin: a `Boundary` block with one `in:` or `out:` entry
|   +-- remove <INDEX> --direction in|out --confirm
+-- header                               # ALL kinds (.mspec / .march / .mtypes)
|   +-- set <KEY> <VALUE>                # upsert one extension header (e.g. design, plan, default-edge-type)
|   +-- remove <KEY> --confirm
+-- mask [--dry-run] [--base-fingerprint <HEX>]   # ALL kinds, kind-dispatched; stdin: JSON merge-mask
```

**`rule add`** — pipe a bare `Rule R<n> [chip]` block on stdin (no `lang:`/`spec:` header needed; the parser accepts standalone rule blocks). The rule ID in the body becomes the identifier; it must not collide with an existing rule. Model the dotted `Rule R<n>.short-name [status]` convention — the `.short-name` suffix is optional but recommended (a stable mnemonic alongside the numeric ID, which is what the dispatcher keys on).

```bash
mast spec patch my-spec rule add <<'EOF'
Rule R5.validate-form [pending]
  Given a user submits the form
  Then the form data is validated
    MUST email_format: the email field MUST match /^[^@]+@[^@]+$/
    open: pending product confirmation on multi-email support
EOF
```

Exits 0 and prints the path; exits non-zero (file byte-identical to pre-patch) if the rule ID is 0, collides, or the resulting spec fails lint.

**`rule update <RULE_ID>`** — same input shape as `rule add`; the `R<n>` in the body MUST match `<RULE_ID>`. Replaces the rule in place, preserving its position. The previous body is discarded — supply the complete replacement.

```bash
mast spec patch my-spec rule update 5 <<'EOF'
Rule R5.validate-form [active]
  Given a user submits the form
  Then the form data is validated
    MUST email_format: the email field MUST match a stricter regex
    MUST length_cap: the email field MUST be 254 chars or fewer
EOF
```

**`rule remove <RULE_ID> --confirm`** — destructive; requires `--confirm`. Exits non-zero (writes nothing) if the rule doesn't exist or `--confirm` is omitted.

```bash
mast spec patch my-spec rule remove 5 --confirm
```

**`rule set-status <RULE_ID> --status ... [--anchor ...]`** — update only the rule's status chip and code anchors without touching the body. This is the typed equivalent of "graduate R<n>", "amend R<n>", "retire R<n>".

```bash
mast spec patch my-spec rule set-status 5 --status active --anchor handle_form --anchor validate_email
mast spec patch my-spec rule set-status 5 --status amended
```

When the last `[pending]` rule in a `[pending]` spec is set to `[active]` (or any non-pending status), the spec-level status **auto-flips** from `[pending]` to `[active]` in the same atomic write. Other rule mutations (add/update/remove) do NOT auto-flip — only `set-status` does, per `spec-access` R10.

**Design and Plan anchors block graduation** (the ratchet — REF-LIFECYCLE). `graduate()` rejects any rule whose targets include anchors where `blocks_graduation()` holds — `AnchorKind::Design` (`*-design.md`) or `AnchorKind::Plan` (`*-plan.md`) — via `GraduateError::DesignDocAnchors` (exit non-zero, file unchanged). `Code`, `Context`, `Skill`, and `Doc` anchors all permit graduation. So before you `set-status <id> --status active` a rule still carrying a design/plan anchor, swap in the real code anchor in the same invocation. Concretely, if asked to "graduate R3" and R3 still binds `$design_ref @file=docs/checkout-flow-design.md#authorization`:

```bash
# WRONG -- leaves the Design anchor in place; graduate() returns DesignDocAnchors and writes nothing
mast spec patch checkout-flow rule set-status 3 --status active

# RIGHT -- replace the design anchor with the landed code symbol, then graduate
mast spec patch checkout-flow rule set-status 3 --status active --anchor authorize_charge
```

When you see the `DesignDocAnchors` error on stderr, do **not** retry the bare command — treat it as a prompt to (1) confirm the code exists, (2) add the `Code` anchor (via `--anchor` here, or by editing the `Targets` block and rule chip through `write`), and (3) re-run with the code anchor attached.

**`boundary add`** — pipe a `Boundary` block with exactly one entry; the `in:` or `out:` prefix sets the direction. Multiple entries in one invocation are rejected — call repeatedly. The new entry is appended in the formatter's source order.

```bash
mast spec patch my-spec boundary add <<'EOF'
Boundary
  in: a new responsibility this spec is now in scope for
EOF
```

**`boundary remove <INDEX> --direction in|out --confirm`** — destructive; requires `--confirm` and `--direction`. The `INDEX` is the **per-direction** zero-based position (count only entries with the same direction, not absolute position). Exits non-zero if the index is out of bounds for the direction.

```bash
mast spec patch my-spec boundary remove 1 --direction in --confirm    # the second `in:` entry
mast spec patch my-spec boundary remove 0 --direction out --confirm   # the first `out:` entry
```

**`header set <KEY> <VALUE>` / `header remove <KEY> --confirm`** — typed upsert and removal of **extension** headers (notably `design:` / `plan:`) without round-tripping the whole file. Works on **all three kinds** — `.mspec`, `.march`, and `.mtypes` (this is the one patch branch that is not `.mspec`-only). `set` replaces an existing value in place; `remove` is idempotent when the key is absent but, being destructive, still requires `--confirm` (per `cli-api-contract` R13). Core headers (`spec`, `title`, `status`, `version`) are not extension headers — change those through write mode (`.mspec`) or `mask` (any kind).

```bash
mast spec patch my-spec    header set design docs/my-spec-design.md   # .mspec
mast spec patch my-march   header set design docs/my-march-design.md  # .march — same branch
mast spec patch my-mtypes  header set default-edge-type Connects      # .mtypes — sets the default edge type
mast spec patch my-spec    header remove design --confirm
```

**`mask` — kind-dispatched JSON merge-patch (write `.march`/`.mtypes`, or batch a `.mspec`).** `mask` reads a JSON merge-mask object on stdin and routes by detected kind to `patchSpec` (`PatchInput`), `patchMarch` (`MarchPatchInput`), or `patchMtypes` (`MtypesPatchInput`). Because `rule`/`boundary` are `.mspec`-only, **`mask` is the only patch path that can write `.march` and `.mtypes` content**. Every mask field carries a default, so omit what you don't touch; an all-empty mask is rejected (`EmptyMask`). Scalars wrap as `{"set": <value>}` (or `{"clear": true}`); keyed-leaf collections are arrays of `{<key>, <…>Text, delete}` entries, where the entry text is the **block-wrapped** snippet for that construct. Newlines inside JSON strings must be escaped (`\n`).

Mask field shapes per kind (camelCase, as on the wire):

| Kind | Top-level mask fields | Collection entry shape |
|------|-----------------------|------------------------|
| `.mspec` | `title`/`status`/`version` (scalars), `design`/`plan` (header scalars), `boundaryIn`/`boundaryOut` (string-lists), `rules`, `invariants`, `defines` | `rules`: `{id, ruleText, delete}` (text = a bare `Rule R<n>` block); `defines`: `{name, value, delete}` |
| `.march` | `components`, `edges` | `components`: `{id, componentText, delete}` (text = a top-level component decl, e.g. `adapter Foo\n  port: run`); `edges`: `{id, edgeText, delete}` (text = an `Edges` block with one `edge <id>: A -[Type]-> B`) |
| `.mtypes` | `edgeTypes`, `componentTypes` | `edgeTypes`: `{name, edgeTypeText, delete}` (text = an `EdgeTypes` block with one `edge-type <Name>\n  semantics: …`); `componentTypes`: `{name, componentTypeText, delete}` (text = a `ComponentTypes` block with one `component-type <name>\n  description: …`) |

Per-kind write template — `create` then `mask`-patch (the working pattern for authoring a `.march` and a `.mtypes`):

```bash
# .march: scaffold, then add two components and an edge between them in one mask
mast spec create checkout-arch --kind march --title "Checkout architecture"
printf '%s' '{"components":[
  {"id":"CheckoutSvc","componentText":"service CheckoutSvc\n  port: charge\n"},
  {"id":"LedgerDB","componentText":"repository LedgerDB\n  port: write\n"}],
 "edges":[{"id":"e1","edgeText":"Edges\n  edge e1: CheckoutSvc -[Writes]-> LedgerDB\n"}]}' \
  | mast spec patch checkout-arch mask

# .mtypes: scaffold, then declare an edge-type and a component-type
mast spec create checkout-types --kind mtypes --title "Checkout vocabulary"
printf '%s' '{"edgeTypes":[{"name":"Writes","edgeTypeText":"EdgeTypes\n  edge-type Writes\n    semantics: a data-flow write to a downstream store\n"}],
 "componentTypes":[{"name":"service","componentTypeText":"ComponentTypes\n  component-type service\n    description: long-running request/response daemon\n"}]}' \
  | mast spec patch checkout-types mask
```

A `.mspec` `mask` works the same way — use `printf '%s'` (not `echo`, whose `\n` handling varies by shell) so the escaped newlines reach the parser as JSON `\n` rather than raw control bytes:

```bash
printf '%s' '{"title":{"set":"New Title"},"rules":[{"id":7,"ruleText":"Rule R7.x [pending]\n  Given a\n  Then b\n"}]}' \
  | mast spec patch my-spec mask
```

For single-construct `.mspec` edits the `rule`/`boundary`/`header` branches above are more direct.

**CAS and dry-run.** `mask` supports compare-and-swap and preview, neither of which the typed `rule`/`boundary` branches expose:

- `--dry-run` prints the formatted post-patch preview plus a `baseFingerprint:` line **without writing** — use it to inspect the result before committing the edit.
- `--base-fingerprint <HEX>` gates the write: if the file's current fingerprint differs, the patch is rejected (`baseline mismatch -- spec changed since read (expected …, found …)`) and nothing is written — last-writer-wins protection for concurrent edits. Obtain the fingerprint from `mast spec read <id> --format json` (its `fingerprint` field). Omitting `--base-fingerprint` means last-writer-wins.

```bash
FP=$(mast spec read checkout-arch --format json | jq -r .fingerprint)
printf '%s' '{"components":[{"id":"CheckoutSvc","delete":true}]}' \
  | mast spec patch checkout-arch mask --base-fingerprint "$FP"   # rejected if the file moved since the read
```

**Render.** The patch op runs the in-memory pipeline and writes atomically. **Round-trip property:** `rule add` of R<n> followed by `rule remove` R<n> `--confirm` yields a file byte-identical to the pre-add state; same for boundary add+remove of the same per-direction index. On failure: file on disk unchanged, diagnostics on stderr, exit code non-zero (`2` for parse errors, `1` for everything else per `cli-api-contract` R7). Read stderr, fix the input, retry — the patch never leaves partial state on disk.

**Budget.** One typed op per construct mutation. When `rule add`/`rule update` introduces or rewrites a constraint, apply the authoring disciplines and high-leverage patterns below; additionally, **if the patched rule realizes a normative claim from another spec, add `Cites <spec>.R<n>`** on its own line under the rule header (the lockfile content-pins it — `Cites` is shared doctrine, see **REF-IDIOMS** / **REF-DEPENDENCIES**). `mast spec patch` runs per-file lint inline, so the diagnostic appears on stderr before the file lands.

## Authoring doctrine — what belongs in a rule

Six disciplines that decide whether a rule earns its place — `spec`-specific authoring doctrine, applying to write and patch mode alike. The high-leverage patterns in the next section are their syntax-level counterpart.

**Speak in interface phenomena.** A rule's claims must be about observable behavior at a boundary — CLI output, exit codes, file formats, on-disk artifacts, public API signatures — never about internal implementation state ("the HashMap is rebuilt") and never about unobservable intent ("the user feels confident"). `Given` carries assumptions about the world as it is (indicative mood); `Then` carries obligations on what the system must make observable (optative mood). If a constraint's key terms are not visible from outside the implementation, nothing can check the rule and it should not be written.

**Restate only what a checker diffs.** Restating structure that already lives elsewhere (a Cargo.toml dependency list, a CI workflow matrix) is good if and only if some fitness function diffs the two encodings — the restatement is then a second, independently checkable encoding of the same fact, which is exactly what makes `build-topology` this corpus's best spec. Restatement without a checker is the defect: it drifts silently. Pair this with the **deletion test**: if removing a rule would not admit an acceptable-but-wrong implementation, the rule was implementation detail — cut it.

**Prefer the slowest-rotting falsifiable anchor.** Claim forms rot at different rates. Volatile numeric snapshots ("today: `0.11.0`", "56 lines remain") rot fastest and rot silently; symbol and file anchors rot when code moves but at least rot loudly; interface prose anchored to a stable command or format rots slowest. When a number is unavoidable, phrase it as the invariant being enforced, never the snapshot: "MUST stay under the 200-line cap enforced by `grammar/tests/line_cap.rs`", not "140 lines used, 60 remain".

**Cover the unwanted-behaviour cases.** Given/When/Then biases authors toward happy paths. When drafting a rule, ask which shape the obligation actually is: unwanted behaviour ("If <trigger> occurs, the system MUST ...") or optional feature ("Where <feature> is enabled, ..."). Express the trigger in a `When` clause rather than burying it in `Given` (the `conditional-given-suggest-when` warning is the automated half of this), and write the failure-path rules explicitly — a spec whose every rule describes success has not specified the part that pages someone.

**Rationale never lives in rule bodies.** The `rationale-keys` lint warns on `rationale:`/`reason:` constraint keys, and it is right: rules are amendable, rationale is immutable, and mixing them breaks both lifecycles. Decisions go to `docs/adrs/`; open questions go to `open:` markers in the rule body. Relatedly, `success.`/`invariant.` properties carry the normative obligation; Given/When/Then scenarios are illustrative witnesses of it.

**Front-load scent.** The title and the first rules must let a reader price the spec without reading it — readers with cheap traversal leave every spec early, so a spec that buries its load-bearing rule at R9 will have it skipped. State the single responsibility in the title and put the most load-bearing rule first.

## High-leverage patterns

Four patterns measurably improve how downstream agents read the spec you write or patch. *What* these idioms are is shared doctrine — see **REF-IDIOMS** (the five `.mspec` idioms and the three lint warnings, plus the `invariant.<name>` vs `Invariant I<n>` distinction). *How to author with them* — the guidance and before/after examples below — is `spec`-specific. Author with them from the start; the lint warnings nag you about the most common omissions, but the structural patterns (`Cites`, `When`) have no automated nudge yet.

### 1. Pipe-block `|` bodies for multi-line constraint values

Any constraint value that spans multiple lines or pins a regex, a JSON shape, an EBNF production, a CLI invocation, or a literal error message belongs in a `| ...` pipe block — never paraphrased into prose. Concrete literals beat prose because the reader can grep them, the formatter preserves whitespace, and downstream tooling can lift them out byte-for-byte.

Prose form (avoid for multi-line literals):

```
MUST group_key: the concurrency group key is the workflow name plus a hyphen plus the PR number or the ref
```

Pipe-block form (preferred — mast/3 multi-line syntax):

```
MUST group_key:
  | the group key is the GitHub Actions expression:
  |   ${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}
  | so PR-scoped and branch-scoped runs do not collide
```

### 2. Per-rule `Cites <spec>.R<n>` clauses on implementation rules

When a rule realizes a normative claim from another spec, declare it: `Cites <spec>.R<n>` on its own line directly under the `Rule R<n> [...]` header. The lockfile (`specs/mast.lock`) pins the citation with a blake3 content-hash, so the agent reading the implementation sees the contract pin and the linker catches drift if the upstream rule changes.

Without the pin:

```
Rule R4.pr-title-check [active $pr_title_workflow]
  Given a pull request is opened ...
```

With the pin (modeled on `ci-gates.R4`):

```
Rule R4.pr-title-check [active $pr_title_workflow]
  Cites release-conventions.R1
  Given a pull request is opened ...
```

### 3. `When` clauses for conditional guards

If your `Given` paragraph contains "if", "once", "unless", "when", "whenever", or "while", lift the condition into a separate `When ...` line between `Given` and `Then`. The three-part rule shape (preconditions, guard, consequence) reads faster than a single conditional-laden paragraph and matches the AST the formatter expects.

Prose form (will trigger `conditional-given-suggest-when`):

```
Rule R3.release-cut [active $release_please_workflow]
  Given a push to `main` adds commits whose subjects are conventional commits and at least one is a feat or fix
  Then the release-please gate MUST open a release PR ...
```

`When` form (modeled on `release-conventions.R3`):

```
Rule R3.release-cut [active $release_please_workflow]
  Given a push to `main` adds one or more commits whose subjects are {conventional_commit} entries
  When at least one added commit is a {release_cutting_type}
  Then the {release_please_gate} MUST open a release PR ...
```

### 4. Falsifiable `success.<name>` and `invariant.<name>` bodies

Reserved dotted constraint keys (`success.X`, `invariant.X`) are the rule's executable oracle. Their bodies MUST contain a falsifiable anchor — a pipe block body, a backtick code span, a `$symbol` reference, a double-quoted literal, an `@file=` path, a `{placeholder}`, or a numeric comparator. Pure prose is a smell because nothing in the body can be mechanically checked.

Prose form (will trigger `success-criterion-not-falsifiable`):

```
success.title_accepted: a well-formed PR title passes the check
```

Anchored form (from `release-conventions.R1`):

```
success.title_accepted: a PR titled `feat(lang): add dotted key support` passes the check
success.title_rejected: a PR titled `fix stuff` fails the check
```

One step further: **shape is not execution.** The falsifiability check accepts any backtick pair or numeric comparator, so it is possible to write an anchor that satisfies the lint while checking nothing — that is a defect, not a pass. The strongest `success.` body names a command someone can actually run: pipe-block the invocation and its expected output so the criterion is a procedure, not a vibe. Prefer criteria some fitness function (a test, a CI gate) actually executes; a criterion only a human could carry out should say so explicitly.

### Lint warnings agents should respond to

These three per-file warnings fire when the patterns above are violated. Treat each as "fix unless you can articulate why the prose form is correct here." (The trigger-word lists behind each validator are catalogued in **REF-IDIOMS**.)

| Warning code | Validator | Fires when | How to fix |
|---|---|---|---|
| `conditional-given-suggest-when` | `when-suggestion` | Rule's `Given` contains `if`, `once`, `unless`, `when`, `whenever`, or `while`, and the rule has no `When` clause | Lift the condition into a `When ...` line between `Given` and `Then` |
| `success-criterion-not-falsifiable` | `success-oracle-shape` | A `success.<name>` body is prose with no anchor (no pipe block, backtick span, `$symbol`, double-quoted literal, `@file=`, `{placeholder}`, or numeric comparator) | Add one of the listed anchors — typically a concrete input value or a numeric threshold |
| `must-with-style-language` | `normative-style-mismatch` | A `MUST`-prefixed constraint contains `prefer`, `preferable`, `preferably`, `ideally`, `favor`, `encourage`, `recommend`, `where possible`, `where feasible`, `where appropriate` | Either remove the recommendation language or downgrade `MUST` to `SHOULD` (or `MAY`) |

Run `mast lint check .` to see them; they are warnings, not errors, but they identify rules an agent will misread.

## Style rules

The no-emoji rule is a project convention — see **REF-CONVENTIONS**. The rest are `spec`-specific:

- **CLI-mediated, always.** A direct `Write`/`Edit` can leave malformed content on disk until someone runs the linter. The `mast spec` subcommands (`create`, `read`, `write`, `patch`) run the parse-lint-format pipeline in memory before touching the filesystem, guaranteeing every committed `.mspec` is syntactically valid and canonically formatted; the PreToolUse hook enforces it (REF-HOOKRULE). For the full design contract see `specs/spec-access.mspec`.
- **Author the slowest-rotting anchor available**, per the authoring disciplines above — and never paraphrase a normative prefix away from the constraint it governs.
- **No emoji.** Per project convention (REF-CONVENTIONS).
- **Verify after corpus-changing writes.** `mast describe attached <spec-id>` (bleed check) then `mast lint check .`; `mast context render` + commit when the corpus listing changed.
