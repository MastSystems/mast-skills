# REF-BLEED

> Shared reference section. The bleed taxonomy — "each fact lives in exactly one
> layer" plus the symptom→layer→fix table, cited via `Reference:`. Single home for
> fragment A7. Cited by `spec` (the full table is its de-bleed authority) and
> `orient` (referenced from Mode E and the reverse-lookup mode).
>
> **Posture note:** every row is a *symptom*, not a *violation* — the table is
> written in the smell idiom. The named-source treatment of why findings are framed
> descriptively (Alexander / Cockburn / Feathers / Naur / Hickey / Argyris-Schön +
> the Fowler smell pressure-valve) lives in **REF-POSTURE.descriptive**; this
> section does not duplicate it.

## Each fact lives in exactly one layer (A7)

In a well-factored corpus, **each fact lives in exactly one layer**. When a fact
leaks across the `.mspec` / `.march` / `.mtypes` boundary, the symptoms below
appear. Treat them as observations, not defects — newly-onboarded codebases
routinely exhibit several, and the right disposition is often to *name the smell*
and move on, not to legislate an immediate fix.

| Symptom in the file | Where the content actually belongs | Fix |
|---|---|---|
| `.mspec` rule paragraph describes runtime topology ("X calls Y over HTTP via the gateway") | `.march` (edge declaration with explicit edge-type) | Move topology to a `.march` edge; reference the component from the rule via `{alias.Component}` |
| `.mspec` rule body redefines a component's port set inline | `.march` (the `port:` lines on the component) | Add the port to the component in the `.march`; rule cites `{alias.Component.port-name}` |
| `.march` carries a `Given`/`When`/`Then` block or `MUST` constraint | `.mspec` (a feature attached to the component) | Create a `.mspec` whose rule references `{<domain>.<Component>}` (attachment is derived, not declared); move the constraint there |
| `.march` declares per-domain protocol variant ("billing-domain uses its own flavor of gRPC") | `.mtypes` (a distinct named edge-type) | Add a new edge-type entry to the project `.mtypes` (e.g. `gRPC-billing`); reference it from the edge |
| `.mtypes` carries transport details that vary by deployment | the future `.minfra` infrastructure layer (L5, not yet built) | Keep the type abstract in `.mtypes`; defer deployment specifics |
| Two `.mspec` files describe overlapping behavior on the same component | spec scope leak — use `Depends on` or `extends` to factor | One spec owns the contract, the other depends on or extends it; do NOT restate |
| `.mspec` rule references a component the spec never imports | unresolved cross-layer ref | Add a `uses { component:Component } from <domain>` line near the top; reference via `{<domain>.Component}` |
| `.march` references an edge-type name not in `.mtypes` | open-registry warning (`edge-type-undeclared`) | Either add the type to `.mtypes`, or accept the warning (open registry is allowed) |

**The bleed detector.** `mast describe attached <spec-id>` surfaces the resolved
attachment set computed from a spec's `uses` imports plus the `{domain.Component}`
component refs in rule chips and rule text. Attachment is derived, never declared —
there is no `attached_to:` header in mast/3. An empty result for an active feature
spec is itself a smell worth investigating.
