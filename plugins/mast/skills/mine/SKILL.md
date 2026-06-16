---
name: mine
description: Use when the user asks to extract, mine, harvest, scaffold, or seed a mast corpus from an existing codebase — typically right after `mast spec init` on a new repo, or when an existing repo needs a candidate `.march` / `.mtypes` / `.mspec` set drafted from the code as it actually is. This skill orchestrates sub-agents (it does NOT read source files in the main context) so the main thread stays uncluttered and tokens don't decay. The output is a proposal manifest with confidence levels and explicit uncertainty flags — never direct writes. Triggers on phrases like "mine this codebase for specs", "extract conventions from this repo", "scaffold mast for X", "what features does this project have", "draft .march files from the current code", "seed the corpus from source", "I just installed mast and need an initial corpus", "infer the edge-type vocabulary from the transports we use", "discover the domains in this project". For authoring a single file from a finished proposal, hand off to `/mast:spec`. For the conceptual grounding (why we mine descriptively and not prescriptively), see `/mast:orient` Mode E.
---

# mine

This skill drafts a candidate mast corpus from a codebase that does not yet have one. The orchestrator (main thread) does scoping, model selection, dispatch, and synthesis; every source-file read is delegated to a sub-agent so the main thread never sees raw bytes. If you find yourself opening a source file in the main context while running this skill, stop and re-dispatch.

Reference: REF-BINARY, REF-FILEKINDS, REF-LIFECYCLE, REF-GOVERNANCE, REF-DEPENDENCIES, REF-IDIOMS, REF-POSTURE, REF-CONVENTIONS
*(Reference sections live in `plugins/mast/skill-reference/` — e.g. `REF-FILEKINDS` resolves to `plugins/mast/skill-reference/REF-FILEKINDS.md`.)*

## Prerequisites

Which binary to invoke is shared doctrine — see **REF-BINARY**. This skill calls the `mast` binary only for the landing step (the mining pipeline itself reads source through sub-agents and emits a manifest; nothing touches the corpus until the user approves). In short: call `mast` directly (the plugin puts it on Claude Code's PATH), or `./bin/mast` in a repo that vendors the shim. If `mast` cannot be provisioned, stop and tell the user to install it before proceeding.

## Intent routing

This skill has one capability — the five-phase mining pipeline — gated by Phase 0 scoping. Use it when the goal is to *draft a corpus from source*; route elsewhere when the corpus already exists or the goal is a single file.

| Situation | Use `/mast:mine`? |
|---|---|
| Fresh `mast spec init` on an unfamiliar repo; corpus is empty | Yes |
| Existing partial corpus; user wants to discover what's missing | Yes |
| A single new feature in a repo that already has a full corpus | No — use `/mast:spec` directly |
| Surgical edit to a known rule | No — use `/mast:spec` |
| Narrative orientation on an already-populated corpus | No — use `/mast:orient` |
| Reviewing whether a specific spec attaches to the right components | No — `/mast:spec` covers it |

## When NOT to use

- It does not edit existing specs — those go through `/mast:spec`.
- It does not run linters on existing content — that is `/mast:check` or `mast lint check`.
- It does not produce a narrative tour of an already-populated corpus — that is `/mast:orient`.
- It does not enforce a layered architecture on a non-layered codebase. Per `/mast:orient` Mode E and Rozanski & Woods: "do not force a layered structure on a system that doesn't have one." If Phase 1 returns one mega-domain with everything in it, that is the honest finding.

If the user's message already names a specific spec ID, rule number, or CLI command, they are past onboarding (the bypass-gate) — route straight to the relevant skill.

## Modes / playbooks

`mine` has a single mode: the five-phase sub-agent pipeline, gated by Phase 0 scoping and closed by Phase 5 synthesis in the main thread. Each phase below is a sub-agent dispatch (or, for Phase 0 and Phase 5, a main-thread step) with its own **Gather**, **Render**, and **Budget** — the per-phase word budgets ARE the Budget. Phase 1 must finish before Phase 2 starts (it produces the domain list Phase 2 fans out over). Phases 2 and 3 can run in parallel. Phase 4 depends on Phase 2's output. Phase 5 is synthesis in the main thread.

### Mode: Phase 0 — Scoping (always do this; cannot be skipped)

**Gather.** If `docs/mining-manifest.md` exists from a previous run, read it first. Its "Considered and rejected" section is binding on Phase 5: rejected proposals are skipped unless the evidence has changed since the recorded commit.

Before any sub-agent spawn, gather four pieces of information from the user via `AskUserQuestion` (one tool call, four questions):

1. **Target path** — repo root or subdirectory to mine? Default: current working directory.
2. **Depth** — quick scan (top-level modules only), standard (modules + their public API surface), or deep (modules + APIs + tests + cross-module imports)? Affects sub-agent token budget by ~3× per tier.
3. **Languages** — restrict to specific languages, or detect automatically? Detection costs one cheap probe; restricting to known languages saves ~20%.
4. **Output volume** — produce drafts for every candidate domain/feature found, or limit to the top N by confidence? A messy 200-component repo can return a 50-component manifest; a 5-component cap keeps the review tractable. The cap is a hard budget: when it binds, the manifest must say so loudly ("N more candidates withheld by the cap") rather than exceed it.

If the user is delegating fully ("just go"), pick: target = cwd, depth = standard, languages = auto-detect, volume = top 10. State the choice in one sentence before dispatching so it is correctable.

**Render.** No corpus output. The product of Phase 0 is the four scoping decisions, stated back to the user, plus the budget proposal (below) when the user has not set one.

**Budget — the hard budget guidance.** Token cost scales roughly with surface area: count workspace members / top-level packages / build units, not lines of code. Standard depth on a repo with ~10 modules typically runs 5–8 sub-agents and ~30–60k tokens of sub-agent context; multiply roughly linearly with module count. Deep depth can 3× the same. If the user has not stated a budget, propose one and confirm before Phase 1.

### Brief conventions (apply to every phase below)

Every phase brief below opens its sub-agent with the same posture: **descriptive, not prescriptive** — report what you observe; flag what you guess. The doctrine behind that posture (Feathers' characterization tests; Naur's theory-in-use; the smell pressure-valve) is shared — see **REF-POSTURE**. Output stays under the per-phase word budget. **Model selection** is annotated per phase: Opus for judgment-heavy phases (domain identification, feature inventory) where Sonnet hedges into mediocrity; Sonnet for enumeration-heavy phases (file walking, listing imports, listing transports). Do not override these defaults without a concrete reason.

### Mode: Phase 1 — Architecture sketch (Opus, single agent)

**Gather.** Spawn one Opus sub-agent with this brief shape (customize the target path and depth):

> You are mining `<target>` to draft a candidate `.march` (architecture) and `.mtypes` (edge-type and component-kind vocabulary) layout for the mast corpus.
>
> Walk only the *top-level structure*: workspace/build manifests appropriate to the language(s) — examples include `Cargo.toml`, `go.mod`, `package.json` + `pnpm-workspace.yaml` / `lerna.json`, `pyproject.toml` / `setup.cfg`, `pom.xml`, `build.gradle` / `settings.gradle[.kts]`, `WORKSPACE` / `MODULE.bazel`, `composer.json`, `Gemfile`, `*.csproj` / `*.sln`, top-level `Dockerfile` clusters per service. If the language is unknown, probe for any of these first. Read top-level directory names and primary README headings. Do NOT read individual source files yet.
>
> Return:
> 1. Detected build system and language(s).
> 2. Candidate domains — for each: name (lowercased), evidence (which manifest / build unit / dir / README section pointed at it), and a confidence chip (`HIGH`/`MEDIUM`/`LOW`). HIGH means the candidate is backed by an independently buildable unit (its own manifest, Gradle subproject, Python package with `__init__.py` + pyproject, Maven module, Go module, service directory with its own `Dockerfile`, etc.); MEDIUM means a coherent directory cluster without an independent build unit; LOW means a guess from naming.
> 3. Candidate edge-type observations — what transports/protocols you suspect the codebase uses (HTTP, gRPC, message queue, DB, file, in-process invocation including direct calls, DI-injected service references, EventBus/MediatR-style dispatchers, actor mailboxes, language-native channels). Evidence per entry. No declarations yet — just observations.
> 4. Candidate component-kind observations — recurring architectural roles that should become `.mtypes` `ComponentTypes` entries (`service`, `gateway`, `repository`, `adapter`, `middleware`, etc.). Evidence per entry. Components in the `.march` draft should use keyword-position kinds only when the kind is observed; otherwise use generic `component`.
> 5. Smells — repos that violate their own apparent conventions (orphan modules, inverted layering, two languages competing for the same role). Tag each `[smell]` with one sentence.
> 6. Governance signals -- if any existing constitution specs exist in the corpus (`mast list constitutions`), note which `.march` domains already declare `roots:` plus a `Compliance <constitution>` block, and which proposed domains would be ungoverned. If no constitutions exist, note that governance is not yet adopted.
> 7. What you could NOT determine without reading source: an explicit list of open questions, each tagged with the cheapest evidence that would resolve it.
>
> Word budget: 600. Do not write any files. Do not propose `mast spec create` invocations yet.

**Render.** This is the cheapest phase. Its output is the **domain inventory** that Phases 2–4 fan out over.

**Budget.** 600 words (the sub-agent's hard cap, stated in the brief).

### Mode: Phase 2 — Per-domain structural extraction (Sonnet, N parallel agents)

**Gather.** For each `HIGH` and `MEDIUM` confidence domain from Phase 1 (skip `LOW` unless the user opted into deep), spawn one Sonnet sub-agent. Run them in parallel by issuing all spawn calls in a single message.

Brief shape per agent:

> You are mining the `<domain_name>` domain inside `<repo_root>`. Sources for this domain: `<paths_from_phase_1>`.
>
> List, with file paths and one-line evidence each:
> 1. **Components**: cohesive subunits inside this domain (typically: each top-level module, public-API surface, or struct/type cluster that exposes a stable interface). For each: name, suggested keyword-position kind (`service`, `gateway`, `repository`, or generic `component` when unclear), suggested `port:` entries (observed transports it accepts), suggested `expose:` entries (capability names worth surfacing), and any `composes:` dependencies among local or imported components. Mark confidence.
> 2. **Internal edges**: connections between components inside this domain. For each: source component, target component, observed edge-type-ish hint (e.g. "function call", "channel send", "HTTP route registered"). Mark confidence.
> 3. **External edges**: imports/uses from outside this domain. For each: target domain (per Phase 1's inventory), source component, hint. These become cross-domain edges wired by `uses { component:Name } from <domain>` import statements.
> 4. **Anchor candidates**: source files/symbols that look like good `Targets`/`References` for any future `.mspec` rule on this component. Classify each candidate by AnchorKind: `Code` (non-`.md`/`.txt` source), `Design` (`-design.md`, blocks graduation), `Plan` (`-plan.md`, blocks graduation), `Context` (exact match: `AGENTS.md`, `CLAUDE.md`, `copilot-instructions.md`, `.cursorrules`), `Skill` (exact match: `SKILL.md`), or `Doc` (other `.md`/`.txt`). Flag `Design` and `Plan` candidates separately since `blocks_graduation()` holds for them -- Active specs must not retain either kind.
> 5. **Smells**: anything that does not fit the domain you were given (a file that seems to belong elsewhere, a circular import, a public API used only internally). Tag each `[smell]`.
>
> Word budget: 500. Do not propose `mast spec create` invocations.

**Render.** Per-domain component, edge, and anchor lists, fanned in by the orchestrator and fed to Phase 4. The AnchorKind taxonomy the brief leans on (the six variants + `blocks_graduation()` for Design/Plan) is shared doctrine — see **REF-LIFECYCLE**; the cross-layer `uses { component:Name } from <domain>` wiring is shared doctrine — see **REF-FILEKINDS**.

**Budget.** 500 words per agent (stated in the brief). If Phase 1 returned more than ~8 domains, cap Phase 2 at the top 8 by confidence and ask the user whether to fan out further. The budget protection matters more than completeness here.

### Mode: Phase 3 — Type vocabulary inference (Sonnet, single agent)

**Gather.** Run in parallel with Phase 2. Spawn one Sonnet sub-agent:

> You are mining `<repo_root>` for the project's edge-type and component-kind alphabets — the candidate `.mtypes` vocabulary.
>
> Search across the repo for transport indicators: HTTP server frameworks, HTTP clients, gRPC server/client stubs, message-queue clients (NATS, Kafka, RabbitMQ, SQS, ActiveMQ), DB drivers, file-channel operations, in-process invocation (direct calls, DI-injected service references, EventBus/MediatR-style dispatchers, actor mailboxes, language-native channels). For each transport observed:
>
> 1. Propose an edge-type name (short, Capitalized to match the corpus convention -- `Connects`, `Imports`, `Triggers`, `Reads`, `Writes`, etc.).
> 2. List the `transport:` and `direction:` attribute values that match what the code does, plus a one-line `description:`.
> 3. Provide evidence: one file path + one symbol per attribute claim.
> 4. Mark confidence (`HIGH` = saw the explicit client/server library; `MEDIUM` = inferred from configuration; `LOW` = guess from name).
>
> Also propose a `default-edge-type:` value if (and only if) one transport is used by >= 70% of observed call sites. Otherwise return `default-edge-type: (none, no clear majority)`.
>
> Also propose `ComponentTypes` entries for the recurring component kinds observed in Phase 1/2 (`service`, `gateway`, `repository`, `adapter`, etc.). Each entry must include a non-empty `description:` that explains the architectural role. Do not invent a kind when the evidence only supports generic `component`.
>
> Word budget: 400.

**Render.** A proposed `.mtypes` alphabet: edge-type names with `transport:`/`direction:`/`description:`, an optional `default-edge-type:`, and `ComponentTypes` entries. The march-typing surface these draw on (keyword-position kinds, the retired suffix form, `composes:` rules, the `.mtypes` Edge/ComponentTypes shape) is shared doctrine — see **REF-IDIOMS**.

**Budget.** 400 words (stated in the brief).

### Mode: Phase 4 — Feature inventory (Opus, single agent)

**Gather.** After Phase 2 finishes (depends on its component list), spawn one Opus sub-agent:

> You are mining `<repo_root>` for candidate `.mspec` features.
>
> Sources to read (in this priority order): tests (locations vary by language — `tests/`, `src/test/java/`, `src/test/kotlin/`, `__tests__/`, colocated `*_test.go`, colocated `*.spec.ts` / `*.test.ts`, `tests/Unit` and `tests/Feature` for PHPUnit), top-level README features section, CHANGELOG entries, public API documentation (OpenAPI specs, CLI `--help` output if a CLI exists, GraphQL schemas, exported library symbols), user-facing `docs/`. Skip categories that do not apply to this project type. **Do not** infer features from internal function names — features must have user-visible behavior.
>
> For each candidate feature:
> 1. Proposed feature ID (kebab-case, short).
> 2. One-sentence behavior description ("when X, then Y").
> 3. Attachment candidates — which components from Phase 2's output the feature appears to touch. There is no `attached_to:` header in mast/3; attachment is derived from `uses { component:Name } from <domain>` import lines plus the component refs bound in rule status chips. Propose, in `<domain>.<component>` form, the components the feature should import and/or bind in its rule chips. If unclear, flag and list candidates.
> 4. One or two candidate Rule shapes (Given/When/Then sketches). Do not write full constraints — this is the first pass. When you sketch a candidate rule ID, model the mast/3 dotted convention (`Rule R1.short-name`), not a bare `Rule R1`.
> 5. **Invariant candidates**: spec-wide assertions that hold across every rule rather than describing one behavior (e.g. "all returns are deterministically ordered", "this layer never writes back"). These become `Invariant I<n>.short-name` entries in the rules section — a single declarative clause with no Given/When/Then. Propose them separately from rules so synthesis can promote them correctly; do not bury an invariant inside a Given/When/Then rule.
> 6. Confidence chip and evidence (which test file or README line surfaced the feature).
> 7. **Design-lifecycle signal**: note whether the feature has companion design docs (`-design.md` under `docs_dir` → `AnchorKind::Design`) or plan docs (`-plan.md` → `AnchorKind::Plan`). If so, propose `design:` or `plan:` extension headers on the candidate `.mspec` and flag that these headers and any anchors where `blocks_graduation()` holds must be removed before the spec reaches Active status.
> 8. Smells: features claimed in docs but not exercised in tests, or vice versa; unfinished intent (TODO/FIXME clusters around one theme, feature flags never rolled out, stubbed or half-built modules); stated-but-undelivered (README/docs promises with no corresponding code, CLI flags or config options that are no-ops). Tag `[smell]` per Argyris-Schön espoused-vs-theory-in-use divergence.
> 9. Direction candidates (cap 2–4): surface asymmetries (one-directional pairs — export without import, CRUD minus one), the adjacent possible (capabilities the existing architecture makes disproportionately cheap), and friction worth productizing (things users evidently do by hand around the project, visible in docs or examples). Grounding rule: a suggestion that could apply to any project in the category is noise, not a finding — every candidate cites repo evidence.
>
> Cap at the top `<N>` features by confidence (`N` from Phase 0). If two features describe the same behavior, propose a merge with the union of evidence.
>
> Word budget: 700.

**Render.** A candidate `.mspec` feature set: IDs, behavior descriptions, attachment candidates, rule/invariant sketches, design-lifecycle signals, smells, and direction candidates — fed to Phase 5 synthesis. The dependency triad a landed feature relates through (`Depends on` / `extends` / `Cites`) is shared doctrine — see **REF-DEPENDENCIES**.

**Budget.** 700 words (stated in the brief).

### Mode: Phase 5 — Synthesis (main thread)

**Gather.** Once all four sub-agents have returned, the orchestrator (main thread) assembles a single **proposal manifest** for the user. Do not write any `.mspec`/`.march`/`.mtypes` yet.

**Vet before shipping — sub-agents over-report.** Before the manifest ships, the orchestrator spot-verifies the cited evidence line of every `[HIGH]` proposal (one targeted read or grep per proposal — the single sanctioned source touch in the main thread). A `[HIGH]` whose evidence does not reproduce is downgraded to `[MEDIUM]` with a note saying why.

**Pattern validation (if corpus already has specs).** Before assembling the manifest, run `mast list patterns --format json` to check whether the existing corpus already exhibits structural motifs. Use the results to:
- Flag proposals that would introduce anti-patterns. If a proposed domain creates a `circular-dependency` with existing specs, or a proposed feature's derived attachment (its `uses` imports plus rule-chip component refs) creates a `boundary-breach`, note it in the manifest's Smells section.
- Confirm proposals that reinforce healthy patterns. If a proposed spec would extend an existing `parent-catalog` or complete a `spec-trio` for a domain, note it as a positive signal.
- Skip this step if the corpus is empty (first-time mining has nothing to validate against).

**Governance alignment (if constitutions exist).** Run `mast list constitutions` to check for existing constitutions. The constitution / tiers / Compliance / ratchet model is shared doctrine — see **REF-GOVERNANCE**. If governance is active:
- For each proposed `.march` domain, check whether it should declare a `roots:` header plus a `Compliance <constitution>` block. Propose `roots:` values matching the domain's directory scope and a `Compliance` block whose `enforces:` line names the lowest tier (start with baseline for safety) of an existing constitution. In mast/3 `enforces:` is a line inside the `Compliance` block, not a standalone header.
- Flag proposed domains that overlap existing governed domains' `roots:` -- this would trigger a `roots/overlap` linker error.
- Note in the manifest which proposed features would become governed once their Targets paths fall under a domain's roots.

**Anchor lifecycle (always do this in synthesis).** For each proposed `.mspec` feature, decide the anchor story before emitting the manifest. The anchor ratchet and the AnchorKind taxonomy behind these cases are shared doctrine — see **REF-LIFECYCLE**. There are exactly two honest cases, and neither ever proposes a broken code anchor:
- **Code exists + has companion design docs.** Propose the `Code` Targets/References surfaced by Phase 4 *and* propose a `design:` (or `plan:`) extension header on the candidate spec linking to the discovered `*-design.md` / `*-plan.md` under `docs_dir`. Note that these headers are validated for existence and warn (stale) on Active specs.
- **Code does not exist yet (feature is documented/planned but unbuilt).** Do NOT propose a code anchor to a not-yet-written path — that becomes a hard error once the spec lands (the `[pending]`-status skip for `AnchorKind::Code` was removed). Instead scaffold the feature's Targets with a `*-design.md` anchor under `docs_dir` and flag that this `Design` anchor `blocks_graduation()`, so the spec must stay non-Active until the code anchor replaces it.

In both cases, any candidate `Invariant I<n>` entries from Phase 4 carry no anchors of their own and are listed under the feature they belong to; promote them as `Invariant I<n>.short-name` entries in the spec's rules section (a single declarative clause, no Given/When/Then), never as a separate `Invariants` block.

**Render.** The manifest shape:

```
== Mining proposal manifest

Scope: <target>, depth=<depth>, languages=<langs>, cap=<N>
Mode: characterization, not specification -- harvested from observed behavior; intent unconfirmed

Domains (Phase 1 + Phase 2)
  - <domain-id> [HIGH] — <one-sentence description>
    Components: <count> proposed
    Internal edges: <count> proposed
    Cross-domain edges: <count> proposed (to <list>)
    Smells: <count>
  - ...

Type vocabulary (Phase 3 plus component-kind observations)
  Proposed types: <list>
  Proposed component-types: <list>
  Proposed default-edge-type: <name | "(none)">

Features (Phase 4)
  - <feature-id> [HIGH] [S] — <one-sentence behavior>; attaches to <domain>.<component> (via `uses` import / rule-chip ref)
    Rules: R1.<short-name>, R2.<short-name> proposed
    Invariants: I1.<short-name> proposed (spec-wide)
    Anchor: Code (target exists) | Design (`docs/<id>-design.md`, blocks graduation — code not yet built)
    design: <docs/<id>-design.md>   (only if a companion design/plan doc was discovered)
  - ...

Direction candidates (Phase 4 item 9, cap 2–4)
  - <candidate-id> [MEDIUM] [M] — <asymmetry / adjacent possible / friction>; evidence: <path or doc line>
    Anchor: Design (`docs/<id>-design.md`, blocks graduation — forward-looking, code not yet built)
  - ...

Open questions (across all phases)
  - <question> (evidence that would resolve: <path/check>)
  - ...

Smells (across all phases)
  - [smell] <description> (source phase: <N>)
  - ...
```

The bracketed second chip on each entry is Effort (S/M/L) to land the proposal. Order entries within each manifest section by impact ÷ effort, discounted by confidence — cheapest high-value proposals first. Direction candidates are forward-looking by definition: each one, if approved, scaffolds via the "code does not exist yet" anchor case above (a `*-design.md` Targets anchor under `docs_dir`, non-Active until code replaces it).

Hand the manifest to the user and ask which subsets to land. **Do not auto-land.** Then persist the manifest to `docs/mining-manifest.md`, appending a "Considered and rejected" section: one line per proposal the user declines or the vet kills (`<proposal-id> -- <one-line reason> -- <short commit hash>`). The next run's Phase 0 reads this file; a rejected candidate reappears only when its evidence has changed since the recorded commit.

**Budget.** The manifest must stay readable — keep it under ~80 lines (see Common failure modes); the per-phase sub-agent budgets above (600/500/400/700) bound the upstream context this synthesis draws on.

## Uncertainty flagging — the discipline

Every finding the sub-agents return MUST carry one of:

- `[HIGH]` — direct, unambiguous evidence (the workspace manifest names this; the test exercises this behavior; the import is explicit).
- `[MEDIUM]` — coherent indirect evidence (naming convention + cohesive directory cluster; behavior implied by README but not tested).
- `[LOW]` — a guess from a single weak signal. The skill explicitly preserves `LOW` findings rather than dropping them — invisible guesses mislead more than visible ones.

For anything `MEDIUM` or below, the finding must also state **what evidence would promote it to HIGH** (e.g. "running the test would confirm", "asking the maintainer", "reading file X"). This is Argyris & Schön's theory-in-use vs espoused theory distinction in action (shared posture doctrine — see **REF-POSTURE**): the manifest never assumes a maintainer's claim is true, and never assumes the absence of a test means absence of intent.

Smells (`[smell]`) are orthogonal to confidence — a `HIGH`-confidence smell is a clear bad-shape observation; a `LOW`-confidence smell is a hunch.

## Output: proposals, not writes

Harvested output is descriptive, never prescriptive — **characterization, not specification**. The descriptive-not-prescriptive posture is shared doctrine (see **REF-POSTURE**); what follows is mine's *application* of it. Every proposed rule body whose intent the evidence did not confirm MUST carry an `open:` marker naming the unconfirmed assumption (e.g. `open: harvested from observed test behavior; intended contract unconfirmed with maintainers`), and the manifest header states "characterization, not specification". The distinction is load-bearing downstream: an agent must never enforce, certify, or gate on a spec that was merely harvested -- mined rules describe what the code does today, not what anyone promised it would do. A harvested rule sheds its `open:` markers only when a human confirms the intent; that is the moment it crosses from description to specification.

The mining skill never calls `mast spec create` on its own. Output is the manifest above plus a per-proposal block of *exactly* the bytes the user could pipe into `mast spec create` if they approve. Example (substitute your own IDs and titles):

```
=== Proposal: domain `<your-domain-id>`

Approve with:
  mast spec create <your-domain-id> --kind march --title "<Short title>"

After scaffolding, populate via `mast spec write <your-domain-id>` with:
  <full proposed body, ready to paste>
```

For instance, a checkout flow surfaces as `mast spec create checkout-domain --kind march --title "Checkout flow"`. The user reviews, picks the proposals to keep, and either runs the commands themselves or asks `/mast:spec` to land them one by one. The mining skill stops at presentation.

## Landing approved proposals

When the user approves a subset of the manifest:

1. For each approved `.march` domain: `mast spec create <id> --kind march --title "..."` (per `/mast:spec`'s scaffold rules), then hand off to `/mast:spec` to populate via stdin heredoc. Declare `roots:`, typed components with `port:`/`expose:`/`composes:`, an `Edges` block, and any cross-domain `uses { component:Name } from <domain>` lines.
2. For the approved `.mtypes` vocabulary: `mast spec create <id> --kind mtypes --title "..."`, then populate `default-edge-type:`, the `EdgeTypes` block (Capitalized edge-type names; `default-edge-type:` must match a declared name exactly), and the `ComponentTypes` block.
3. For each approved `.mspec` feature: `mast spec create <id> --title "..."` (mspec is the default kind), then `/mast:spec` for the body. Author rules as `Rule R<n>.short-name` and any spec-wide assertions as `Invariant I<n>.short-name` entries in the rules section (no `Invariants` block). Wire attachment via `uses { component:Name } from <domain>` lines and the component refs bound in each rule's status chip -- there is no `Imports` block or `attached_to:` header in mast/3; `mast describe attached <id>` derives attachment from those. If the feature's code does not exist yet, point its Targets at a `*-design.md` anchor under `docs_dir` (never a not-yet-written code path) and add a `design:` header; if the code exists and a design doc was discovered, add the `design:` header alongside the code anchors. If the approved domain carries a `Compliance <constitution>` proposal, populate it as a `Compliance <C>` block (`.mspec`: indented `certified:`; `.march`: indented `enforces: <tier>` plus `certified:` / `pending:` / `waive:`), not as `certify-<C>:` headers. Carry the manifest's `open:` markers into the landed rule bodies — approval to land is not confirmation of intent, and the markers are what keep a harvested rule from being mistaken for a promised contract.
4. Run `mast lint check --root <repo>` after each batch — let the linker tell you what does not resolve before continuing.

Critically: do NOT chain all approved proposals into one giant write loop without checkpoints. Each `mast spec create` + `mast spec write` is a unit; after every 3–5 units, re-run lint and re-ask the user before proceeding.

After all approved proposals have landed, run `mast list patterns` as a post-landing sanity check. Report any new anti-patterns introduced by the landed specs (compare against the pre-landing pattern set if available). This catches structural issues like `circular-dependency` or `shared-target-conflict` that only emerge once the full proposal set is in the corpus.

## Common failure modes

1. **Manifest sprawl / over-scoping.** Every published failure of spec-driven-development tooling is an over-scoping failure — markdown seas nobody reads, spec-to-code ratios nobody reviews. If the manifest is longer than ~80 lines, the user will not read it. Compress: collapse low-confidence findings into a single "and N more" line and surface them on request. When the Phase 0 cap binds, fail loudly — state how many candidates were withheld and how to raise the cap — never quietly emit everything.
2. **Premature landing.** The skill is not done when it produces the manifest — landing must not happen automatically. Wait for explicit approval, per proposal.

## Style rules

The no-emoji rule is a project convention — see **REF-CONVENTIONS**. The rest are `mine`-specific:

- **Orchestrate; never read source in the main context.** Every source-file read is delegated to a sub-agent so the main thread never sees raw bytes. If you find yourself opening a source file in the main context, stop and re-dispatch. The single sanctioned exception is the Phase 5 vet (one targeted read/grep per `[HIGH]` proposal).
- **Findings, not prescriptions.** Carry every sub-agent finding with its confidence chip; preserve `LOW` findings rather than dropping them. Mark anything unconfirmed with an `open:` marker, never a confident architecture claim (REF-POSTURE).
- **No emoji.** Per project convention (REF-CONVENTIONS).
- **The march-typing surface, used consistently.** Keyword-position component kinds, the retired suffix form, and `composes:` rules are shared doctrine — see **REF-IDIOMS** — when drafting `.march` / `.mtypes` proposals.

## Worked example

A complete, real mining run lives in [`examples/ledger/`](../../../../examples/ledger) — a small double-entry money-transfer service (TypeScript) mined into a full corpus.

- **The manifest** ([`examples/ledger/docs/mining-manifest.md`](../../../../examples/ledger/docs/mining-manifest.md)) is the actual Phase 1–5 output: a 4-sub-agent run (1 Opus architecture sketch → 2 Sonnet domain extractions + 1 Sonnet type-vocabulary → 1 Opus feature inventory → main-thread synthesis). It shows the manifest shape filled in with real domains, edge-types, features, confidence chips, open questions, and smells — including a smell the mining caught in the source itself.
- **The landed corpus** (`examples/ledger/specs/`) is what those proposals became after approval: 2 architecture domains plus an `api` domain, the `.mtypes` vocabulary, and feature `.mspec`s. Read it with `mast list domains --root examples/ledger`, `mast list specs --root examples/ledger`, `mast spec read transfer-funds --with-rules --root examples/ledger`.
- **The descriptive-not-prescriptive discipline in practice:** the manifest's "Landing-time deviation" note records where the landed corpus departed from the strict mining finding (modeling `src/http/` as an `api` domain), and the harvested rules shed their `open:` markers only once the human approved at landing.
